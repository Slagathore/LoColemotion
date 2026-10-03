"""Retain R10AA's interrupted gate without upgrading or resuming its receipts."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RUN = EVIDENCE / 'development-recovery-smoke-2d9b38cec72a4a37b6bf95dafe68eff6'
WRAPPER = EVIDENCE / 'r10aa-first-smoke-launch-2c5305b28033467bafee46e6f7945f94'
PENDING = EVIDENCE / 'r10aa-complete-hold-report-1e2e47b53a3841c7bc2f00f8ff4e1696'
OBSERVATION = EVIDENCE / 'r10aa-interrupted-gate-observation-89ded2e9a3194d4cb9db59daacc899ac/observation.json'
KEY = ROOT / 'sdk/recovery/r10aa_v56_walking_entry_contract_v7.json'
CONTRACT = ROOT / 'sdk/development/r10aa_safety_stage_contract_v1.json'
RECORD = ROOT / 'sdk/recovery/r10aa_interrupted_gate_v1.json'
HEAD = '12ab021765261ff4335da3b2a25440f689d1e867'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))

def binding(path):
    raw = path.read_bytes()
    return dict(path=path.as_posix(), byte_length=len(raw), raw_sha256='sha256:' + hashlib.sha256(raw).hexdigest())

def observations():
    assert read(WRAPPER / 'invocation.json')['source_commit'] == HEAD
    assert not (WRAPPER / 'execution.json').exists()
    assert not any((RUN / name).exists() for name in ('supervisor_result.json', 'declaration.json', 'children', 'r10aa_development_launch.json'))
    rows = [json.loads(line.split(' ', 1)[1]) for line in (WRAPPER / 'stdout.log').read_text(encoding='utf-8').splitlines() if line.startswith('DEVELOPMENT_SMOKE_STAGE ')]
    stages = read(CONTRACT)['stages']
    assert len(rows) == 35 and sum(r['test_count'] for r in rows) == 99
    for actual, declared in zip(rows, stages[:35], strict=True):
        assert actual['id'] == declared['id'] and actual['test_count'] == declared['tests'] and actual['passed'] is True
    assert (WRAPPER / 'stderr.log').read_bytes() == b''
    assert (RUN / 'r10aa_ready_report.stdout.log').read_bytes() == b''
    assert (RUN / 'r10aa_ready_report.stderr.log').read_bytes() == b''
    assert read(PENDING / 'ready/execution.json')['exit_code'] == 0
    assert read(PENDING / 'ready/passive_entry_replay/execution.json')['returncode'] == 0
    assert not (PENDING / 'ready/replay.json').exists()
    observer = read(OBSERVATION)
    assert not any(observer['process_presence'].values())
    assert observer['host_boot_utc'] > read(WRAPPER / 'invocation.json')['started_utc']
    assert observer['physical_reservation_present'] is False
    # Verify the frozen input population with one batch; preserve Windows text bytes.
    inputs = read(KEY)['bound_source_files']; assert len(inputs) == 1539
    request = ''.join(HEAD + ':' + row['path'] + '\n' for row in inputs).encode()
    result = subprocess.run(['git','cat-file','--batch'], input=request, capture_output=True, cwd=ROOT, check=True, timeout=60)
    assert not result.stderr
    raw, cursor = result.stdout, 0
    for row in inputs:
        end = raw.index(b'\n', cursor); header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob'
        length = int(header[2]); content = raw[end+1:end+1+length]; cursor=end+2+length
        candidates = (content, content.replace(b'\n', b'\r\n')) if b'\r\n' not in content else (content,)
        assert any(len(c) == row['byte_length'] and 'sha256:' + hashlib.sha256(c).hexdigest() == row['raw_sha256'] for c in candidates), row['path']
    assert cursor == len(raw)
    return dict(ok=True, outcome='incomplete_zero_world_gate', completed_stages=35, completed_tests=99,
        pending_stage='r10aa_ready_report', pending_publisher_and_reader_exited_zero=True,
        pending_stage_passed=False, terminal_supervisor_receipt_missing=True, whole_gate_passed=False,
        physical_population_consumed=False, world_build_count=0, solver_step_count=0,
        cause_of_original_stop_proven=False, physical_acceptance_authority=False, release_authority=False)

def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in (RUN, WRAPPER, PENDING) for p in sorted(folder.rglob('*')) if p.is_file()]
    value = dict(schema_version='sporespore_r10aa_interrupted_gate_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='incomplete_zero_world_gate_closure',question_class='development'),
        dependencies=[binding(p) for p in (Path(__file__), KEY, CONTRACT, OBSERVATION)],
        retained_evidence=[binding(p) for p in files], observed=observed,
        source_commit=HEAD, next_action='Fresh complete gate from a clean pushed freeze; do not resume, repair, or reuse this incomplete qualification.',
        source_or_physics_changed=False, physical_acceptance_authority=False, release_authority=False)
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:stream.write(json.dumps(value,indent=2)+'\n')
    return observed

def audit():
    value=read(RECORD)
    for row in value['dependencies']+value['retained_evidence']:assert binding(Path(row['path']))==row,row['path']
    result=observations();assert result==value['observed'];return result

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--capture',action='store_true')
    print(json.dumps(capture() if parser.parse_args().capture else audit()))
