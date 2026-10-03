"""Close the R10T executor timeout correction after actual PowerShell boundary checks."""
import argparse
import json
from pathlib import Path
import uuid
import r10t_route_integration_component as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10t_launcher_timeout_component_v1.json'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v11.json'
FAILED=EVIDENCE/'r10t-launcher-timeout-check-bbae5a161870421fa82f95e8e15225af'
CLAIMS=dict(base.CLAIMS,selected_stage_timeout_boundaries_checked=True)

def audit(record,current_sources=False):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['integration_component'],record['manifest']]:base.verify(item)
    base.audit(base.read(base.RECORD))
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
        if current_sources:assert base.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
    assert base.inspect_run(record['run_root'],5,0)==record['observed']
    child=Path(record['launcher_root'])
    boundaries=base.read(child/'timeout-boundaries.json')
    assert boundaries['world_build_count']==boundaries['test_process_start_count']==0
    assert len(boundaries['cases'])==11 and sum(c['accepted'] for c in boundaries['cases'])==2
    assert [c['id'] for c in boundaries['cases'] if c['accepted']]==['accepted-preparation','accepted-hold']
    assert all(c['boundary']==('exclusive_log' if c['accepted'] else 'timeout_validation') for c in boundaries['cases'])
    assert base.read(child/'timeout-boundaries.execution.json')['returncode']==0
    assert not (child/'timeout-boundaries.stderr.txt').read_bytes()
    for case in base.read(child/'timeout-cases.json'):
        directory=Path(case['directory']);stage=case['stage']['id']
        assert (directory/(stage+'.stdout.log')).read_bytes()==b'preexisting exclusive log\n'
        assert not (directory/(stage+'.stderr.log')).exists()
    stages=base.read(child/'selected-stages.json')
    assert len(stages['stages'])==48 and stages['test_count']==220
    return dict(ok=True,current_sources_verified=current_sources,tests=5,stages=48,declared_tests=220,**CLAIMS)

def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root=Path(root).resolve();assert root.parent==EVIDENCE.resolve()
    observed=base.inspect_run(root,5,0);children=base.children(root)-{root};assert len(children)==1
    child=next(iter(children));directory=EVIDENCE/('r10t-launcher-timeout-closure-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,root/'source_before.json')
    manifest=directory/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for folder in [root,child,directory,*base.children(FAILED)] for p in sorted(folder.rglob('*')) if p.is_file()]))
    record=dict(schema_version='sporespore_r10t_launcher_timeout_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_executor_timeout_correction',question_class='development'),
        auditor=base.bind(__file__),integration_component=base.bind(base.RECORD),manifest=base.bind(manifest),
        source_archive=archive,prior_invalid_retention_root=str(FAILED),run_root=str(root),launcher_root=str(child),observed=observed,claim_boundary=CLAIMS,
        correction='Final source review found the two R10T 900-second report allowances nested under the R10S stage ID. Each exact R10T ID/pattern/two-test tuple now has its declared cap. Actual executor calls prove 900 passes timeout validation and then refuse a pre-existing exclusive log before process start; 901 and crossed IDs/patterns/counts refuse at timeout validation. An initial check passed the accepted caps but reused a later output label and failed retention; that invalid attempt and its source snapshot remain retained. Cases now have unique directories and exclusive log writes. One PowerShell session evaluates all eleven timeout cases, avoiding repeated startup cost without changing their boundaries. Physical command budgets and the 48-stage/220-test safety population are unchanged. The full gate remains pending.')
    audit(record,True);base.write_new(RECORD,record);return audit(record,True)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print('R10T_LAUNCHER_TIMEOUT_COMPONENT '+json.dumps(create(args.create_from) if args.create_from else audit(base.read(RECORD),args.current_sources)))
