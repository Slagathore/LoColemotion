"""New R10AP source admission key; never refresh a consumed population/key."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
EVIDENCE=ROOT.parent/'SporeSpore_Evidence'
BASE=ROOT/'sdk/recovery/r10am_v56_walking_entry_contract_v11.json'
SELECTORS=[ROOT/'sdk/conformance/development_recovery_candidate.py',
    ROOT/'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd']

def sha(path): return 'sha256:'+hashlib.sha256(Path(path).read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()

def declare(reason):
    assert Path(git('rev-parse','--show-toplevel')).resolve()==ROOT
    assert git('remote','get-url','origin')=='https://github.com/Slagathore/sporespore.git'
    assert reason.strip()
    assert not list(EVIDENCE.glob('r10ap*consumption*.json')), 'R10AP population consumed'
    for declaration in EVIDENCE.glob('development-recovery-smoke-*/declaration.json'):
        if 'r10ap_development' in json.loads(declaration.read_text(encoding='utf-8-sig')):
            from r10ap_report_fixtures import registered_declaration
            assert registered_declaration(declaration), 'R10AP execution population already declared'
    versions=list((ROOT/'sdk/recovery').glob('r10ap_v56_walking_entry_contract_v*.json'))
    # The initial nonqualified placeholder is not an observed admission key.
    complete=[p for p in versions if json.loads(p.read_text()).get('source_key_complete') is True]
    revision=1+max([int(re.search(r'_v(\d+)\.json$',p.name)[1]) for p in complete],default=0)
    target=ROOT/'sdk/recovery'/f'r10ap_v56_walking_entry_contract_v{revision}.json'
    if target.exists():
        assert json.loads(target.read_text()).get('source_key_complete') is False
    for p in SELECTORS:
        s,n=re.subn(r'r10ap_v56_walking_entry_contract_v\d+\.json',target.name,p.read_text(encoding='utf-8'))
        assert n==1
        p.write_text(s,encoding='utf-8',newline='\n')
    value=json.loads(BASE.read_text(encoding='utf-8'))
    paths={row['path'] for row in value['bound_source_files']}
    paths.add(BASE.relative_to(ROOT).as_posix())
    runtime=json.loads((ROOT/'sdk/development/recovery_candidates/r10ap-progressive-headroom-core-v1.runtime.json').read_text())
    paths.update(Path(row['path']).relative_to(ROOT).as_posix() if Path(row['path']).is_absolute() else row['path']
        for row in runtime['source_files'])

    paths.update(['sdk/adapters/godot/gdscript/recovery_detection_frame_contacts_v1.gd',
        'sdk/conformance/detection_frame_contact_source_v1.py'])
    paths.update(['sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd',
        'sdk/adapters/godot/gdscript/recovery_runtime.gd',
        'sdk/conformance/content_addressed_zero_world_closure.py',
        'sdk/trace_analysis/godot_authoritative_json_transport.gd'])
    paths.update(p for p in git('ls-files','--cached','--others','--exclude-standard').splitlines()
        if 'r10ap' in p and Path(p).suffix in ('.py','.gd','.ps1','.json','.gdextension')
        and not re.search(r'r10ap_v56_walking_entry_contract_v\d+\.json$',p))
    value['diagnostic_basis'] = json.loads((ROOT/'sdk/recovery/r10ap_v56_walking_entry_contract_v1.json').read_text())['diagnostic_basis']
    value.update(schema_version=f'sporespore_r10ap_v56_walking_entry_contract_v{revision}',
        profile_id='r10ap_v56_joint_bounded_contact_gated_v1',
        required_start_profile_id='r10ap_v56_front_left_first_post_interaction_v1',
        required_walking_policy_id='r10ap_progressive_headroom_route_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='prospective_diagnostic_source_binding',question_class='development'),
        compatibility_scope='R10AP progressive joint headroom diagnostic only. Consumed R10AM and all previous keys remain unchanged.',
        rationale='Distinct admission identity and fresh source bindings for selected V28 and unchanged V56 control with explicit detection-frame distal contact classification.',
        source_key_complete=True,predecessor_contract=BASE.relative_to(ROOT).as_posix(),predecessor_contract_sha256=sha(BASE),
        source_revision_reason=reason,
        dependency_coverage='Conservative consumed R10AM runtime/source dependency population at current bytes plus all R10AP source, profiles and controls present at declaration. This is admission, not complete safety qualification or launch authority.',
        bound_source_files=[dict(path=p,byte_length=(ROOT/p).stat().st_size,raw_sha256=sha(ROOT/p)) for p in sorted(paths)])
    with target.open('w' if target.exists() else 'x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2);stream.write('\n')
    return dict(path=target.relative_to(ROOT).as_posix(),raw_sha256=sha(target),source_files=len(paths),
        physical_execution_authorized=False,physical_acceptance_authority=False,release_authority=False)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reason',required=True)
    print(json.dumps(declare(parser.parse_args().reason)))
