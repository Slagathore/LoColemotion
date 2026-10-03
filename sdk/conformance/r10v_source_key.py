"""Declare a complete distinct R10V dependency key before any consumption.

Every revision is a new file. The predecessor keys and their exposed results
remain immutable, and any R10V reservation closes this development helper.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent/'SporeSpore_Evidence'
BASE = ROOT/'sdk/recovery/r10u_v56_walking_entry_contract_v14.json'
SELECTORS = [ROOT/'sdk/conformance/development_recovery_candidate.py',
    ROOT/'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd']


def sha(path):
    return 'sha256:'+hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()


def declare(reason):
    assert Path(git('rev-parse','--show-toplevel')).resolve() == ROOT
    assert git('remote','get-url','origin') == 'https://github.com/Slagathore/sporespore.git'
    assert not list(EVIDENCE.glob('r10v_*consumption_v1.json')), 'R10V population already consumed'
    previous = max((ROOT/'sdk/recovery').glob('r10v_v56_walking_entry_contract_v*.json'),
        key=lambda p:int(re.search(r'_v(\d+)\.json$',p.name)[1]))
    revision = int(re.search(r'_v(\d+)\.json$',previous.name)[1])+1
    target = previous.with_name('r10v_v56_walking_entry_contract_v'+str(revision)+'.json')
    assert not target.exists()
    # Finish selectors before hashing. They must reference exactly this new key.
    for path in SELECTORS:
        text = path.read_bytes().decode('utf-8')
        text,count = re.subn(r'r10v_v56_walking_entry_contract_v\d+\.json',target.name,text)
        assert count == 1,(path,count)
        path.write_bytes(text.encode('utf-8'))
    files = {x['path'] for x in json.loads(BASE.read_bytes())['bound_source_files']}
    files.add(BASE.relative_to(ROOT).as_posix())
    files.update(name for name in git('ls-files','--cached','--others','--exclude-standard').splitlines()
        if 'r10v' in name and Path(name).suffix in ('.py','.gd','.ps1','.json'))
    files.update(['sdk/conformance/development_passive_entry_profile.py',
        'sdk/conformance/development_recovery_smoke.py', 'sdk/run_development_interfaces.ps1',
        'sdk/run_development_recovery_smoke.ps1'])
    value = json.loads(previous.read_bytes())
    value.update(schema_version='sporespore_r10v_v56_walking_entry_contract_v'+str(revision),
        source_key_complete=True,predecessor_contract=previous.relative_to(ROOT).as_posix(),
        predecessor_contract_sha256=sha(previous),source_revision_reason=reason,
        dependency_coverage='Complete R10U v14 dependency population plus every R10V source, contract, test, launch and source-key file; current shared-source bytes. Qualification is required separately. No R10V population is reserved.',
        bound_source_files=[dict(path=name,raw_sha256=sha(ROOT/name)) for name in sorted(files)])
    with target.open('x',encoding='utf-8',newline='\r\n') as stream:
        json.dump(value,stream,indent=2);stream.write('\n')
    return dict(ok=True,contract=target.relative_to(ROOT).as_posix(),raw_sha256=sha(target),
        source_files=len(files),world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--reason',required=True)
    print(json.dumps(declare(parser.parse_args().reason)))
