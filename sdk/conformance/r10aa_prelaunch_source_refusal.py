"""Audit the immutable R10AA pre-admission refusal; no launch or qualification."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10aa_prelaunch_source_refusal_v1.json'

def audit():
    value = json.loads(RECORD.read_text(encoding='utf-8'))
    for row in value['retained_evidence']:
        raw = Path(row['path']).read_bytes()
        assert len(raw) == row['byte_length']
        assert 'sha256:' + hashlib.sha256(raw).hexdigest() == row['raw_sha256']
    files = {Path(r['path']).name: Path(r['path']) for r in value['retained_evidence']}
    assert json.loads(files['execution.json'].read_text())['exit_code'] == 1
    assert files['stdout.log'].read_bytes() == b''
    assert value['error_code'] in files['stderr.log'].read_text(encoding='utf-8')
    invocation = json.loads(files['invocation.json'].read_text(encoding='utf-8'))
    assert invocation['source_commit'] == value['source_commit']
    key = json.loads((ROOT / value['refused_key']).read_text(encoding='utf-8'))
    changed = []
    for row in key['bound_source_files']:
        raw = subprocess.check_output(['git', 'show', value['source_commit'] + ':' + row['path']], cwd=ROOT)
        variants = (raw, raw.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
        if not any(len(candidate) == row['byte_length'] and 'sha256:' + hashlib.sha256(candidate).hexdigest() == row['raw_sha256'] for candidate in variants):
            changed.append(row['path'])
            assert row['path'] == '.gitattributes'
            prior = raw.removesuffix(b'sdk/recovery/r10aa_v56_walking_entry_contract_v5.json text eol=lf\n')
            assert len(prior) == row['byte_length']
            assert 'sha256:' + hashlib.sha256(prior).hexdigest() == row['raw_sha256']
    assert changed == ['.gitattributes']
    assert value['world_build_count'] == value['solver_step_count'] == value['completed_safety_stages'] == 0
    assert value['physical_population_consumed'] is value['physical_acceptance_authority'] is value['release_authority'] is False
    return dict(ok=True, changed_input='.gitattributes', refused_before_gate=True,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)

if __name__ == '__main__':
    print(json.dumps(audit()))
