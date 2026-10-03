"""Audit retained R10S launcher and runtime interfaces; never authorize physics."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RECORD = ROOT / 'sdk/recovery/r10s_launch_component_v1.json'
RUN = EVIDENCE / 'r10s-launcher-verification-fb21d56b92f14e4f9baad64d99af38af'
SOURCE = ROOT / 'sdk/recovery/r10s_v56_walking_entry_contract_v7.json'
CONTRACT = ROOT / 'sdk/development/r10s_safety_stage_contract_v1.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, complete_smoke_safety_gate_passed=False,
    physical_attempt_started=False, physical_acceptance_authority=False, release_authority=False,
    held_out_population_declared=False, sdk1_score='14/20')


def read(path):
    return json.loads(Path(path).read_bytes())


def bind(path):
    path = Path(path)
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=digest)


def verify(item):
    assert bind(item['path']) == item, item['path']


def roots():
    found = [Path(line.split(' ', 1)[1]) for line in (RUN/'stdout.log').read_text(encoding='utf-8').splitlines()
        if re.match(r'^[A-Z0-9_]+ (?:C:)', line)]
    assert len(found) == len(set(found)) == 10
    assert all(path.parent == EVIDENCE for path in found)
    return found


def audit(record, current_sources=False):
    assert record['schema_version'] == 'sporespore_r10s_launch_component_v1'
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings'] + [record['auditor'], record['evidence_manifest']]:
        verify(item)
    manifest = read(record['evidence_manifest']['path'])
    for item in manifest['files']:
        verify(item)
    assert read(RUN/'result.json') == {'returncode': 0}
    invocation = read(RUN/'invocation.json')
    assert invocation['world_build_count'] == invocation['solver_step_count'] == 0
    log = (RUN/'stderr.log').read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ', log, flags=re.M) == ['60']
    assert log.rstrip().endswith('OK') and len(re.findall(r'^test_.* \.\.\. ok$', log, flags=re.M)) == 60
    source = read(SOURCE)
    archive = RUN/'source-v7'
    archived = read(archive/'source-archive.json')
    assert len(archived['files']) == len(source['bound_source_files']) + 2
    for item in source['bound_source_files']:
        assert bind(archive/item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
        if current_sources:
            assert bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
    assert (archive/SOURCE.relative_to(ROOT)).read_bytes() == SOURCE.read_bytes()
    evidence_roots = roots()
    for root in evidence_roots:
        before = root/'source_before.json'
        if before.exists():
            assert before.read_bytes() == (root/'source_after.json').read_bytes(), root
    contract = read(CONTRACT)
    assert len(contract['stages']) == 41 and sum(s['tests'] for s in contract['stages']) == contract['total_tests'] == 192
    selected = read(evidence_roots[0]/'selected-stages.json')
    assert selected['test_count'] == 192 and selected['world_build_count'] == selected['solver_step_count'] == 0
    for actual, expected in zip(selected['stages'], contract['stages'], strict=True):
        assert {k: actual[k] for k in ['id', 'pattern', 'tests']} == expected
    declaration = read(evidence_roots[0]/'paired-declaration.json')
    assert declaration['development_execution_mode'] == 'single_kick_controller_diagnostic_v1'
    assert declaration['r10s_development']['stage'] == 'initial_single_diagnostic'
    assert declaration['seed'] == 41046 and declaration['r10s_development']['seed']['prefix_phase'] == 246
    assert [c['role'] for c in declaration['children']] == ['kick_passive_recovery_resume']
    assert declaration['maximum_steps_per_child'] == 3512
    reservations = list(evidence_roots[1].rglob('r10s_*consumption_v1.json'))
    assert len(reservations) == 6 and all(p.parent.parent == evidence_roots[1] for p in reservations)
    startup = read(ROOT/'sdk/recovery/r10s_startup_review_v1.json')
    for item in [startup['component']] + startup['retained_execution_files']:
        target = dict(item, path=(ROOT/item['path']).as_posix()) if not Path(item['path']).is_absolute() else item
        verify(target)
    assert startup['observed']['fresh_v56_startup_cases'] == 1800
    assert startup['observed']['refused_startup_cases'] == 0
    return dict(ok=True, targeted_tests=60, launcher_tests=5, launch_guard_tests=7,
        selected_stages=41, selected_tests=192, source_key_files=len(source['bound_source_files']),
        retained_files=len(manifest['files']), current_sources_verified=current_sources, **CLAIMS)


def create():
    assert not RECORD.exists()
    manifest_path = RUN/'retained-evidence-manifest.json'
    manifest = dict(schema_version='sporespore_r10s_launch_retention_manifest_v1',
        files=[bind(p) for root in [RUN, *roots()] for p in sorted(root.rglob('*')) if p.is_file()])
    with manifest_path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(manifest, stream, indent=2); stream.write('\n')
    record = dict(schema_version='sporespore_r10s_launch_component_v1',
        status='targeted_production_launcher_and_runtime_interfaces_passed_complete_gate_next',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='prospective_development_launcher_interfaces', question_class='development'),
        auditor=bind(__file__), bindings=[bind(p) for p in [SOURCE, CONTRACT,
            ROOT/'sdk/recovery/r10s_startup_component_v1.json', ROOT/'sdk/recovery/r10s_startup_review_v1.json']],
        evidence_manifest=bind(manifest_path), claim_boundary=CLAIMS)
    record['observed'] = audit(record, current_sources=True)
    with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(record, stream, indent=2); stream.write('\n')
    return record['observed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--create', action='store_true')
    parser.add_argument('--current-sources', action='store_true'); args = parser.parse_args()
    print('R10S_LAUNCH_COMPONENT ' + json.dumps(create() if args.create else audit(read(RECORD), args.current_sources)))
