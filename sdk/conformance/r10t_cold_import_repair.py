"""Retain fresh-process import repair and its exact affected-stage checks."""
import argparse
import ast
import json
from pathlib import Path
import re
import uuid
import r10t_route_integration_component as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
DESIGN=ROOT/'sdk/recovery/r10t_cold_import_repair_design_v2.json'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v23.json'
RECORD=ROOT/'sdk/recovery/r10t_cold_import_repair_component_v1.json'
CLAIMS=dict(world_build_count=0,solver_step_count=0,controller_changed=False,native_dll_changed=False,
    host_deadlines_changed=False,physical_budgets_changed=False,original_failures_reclassified=False,
    complete_smoke_safety_gate_passed=False,physical_attempt_started=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def structure(current=False):
    d=base.read(DESIGN)
    for name in ['failed_gate','cold_discovery','prior_host_component','safety_contract']:base.verify(d[name])
    failed=base.read(d['failed_gate']['path'])
    assert failed['failure_code']=='SMOKE_SAFETY_GATE_FAILED:r10t_native_control' and not failed['physical_attempt_started']
    assert sum(s['test_count'] for s in failed['safety_stages'] if s['passed'])==80
    probe=base.read(d['cold_discovery']['path'])
    assert [s['id'] for s in probe if s['errors']]==d['expected_failed_import_stages']
    base.verify(d['startup_history_binding'])
    for item in d['failed_import_repair_attempt'].values():base.verify(item)
    contract=base.read(d['safety_contract']['path'])
    assert len(contract['stages'])==62 and sum(s['tests'] for s in contract['stages'])==220
    if current:
        prior=base.read(d['prior_host_component']['path'])
        archive=next(a for a in prior['source_archives'] if a['key']['path'].endswith('_v21.json'))
        for name in d['repaired_modules']:
            # Only imports change in these modules: all original test bodies remain exact.
            def classes(p):
                tree=ast.parse(p.read_text())
                # Normalize the declared historical-path bridge; every native
                # assertion and all remaining test logic must still be exact.
                for node in ast.walk(tree):
                    if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute) and node.func.attr=='audit' and isinstance(node.func.value,ast.Name) and node.func.value.id=='history':
                        node.func.value.id='component'
                return [ast.dump(n,include_attributes=False) for n in tree.body if isinstance(n,ast.ClassDef)]
            assert classes(ROOT/name)==classes(Path(archive['directory'])/name),name
    return d,contract


def observe(root):
    root=Path(root);d,contract=structure()
    assert base.read(root/'source_before.json')==base.read(root/'source_after.json')
    execution=base.read(root/'execution.json');assert execution['exit_code']==0 and execution['source_unchanged']
    lock=base.read(root/'operation_lock.json');assert lock['acquired'] and lock['role']=='conformance' and not lock['test_only']
    stages=base.read(root/'stage_results.json');assert [s['id'] for s in stages]==d['target_stage_ids']
    counts={s['id']:s['tests'] for s in contract['stages']}
    for stage in stages:
        assert stage['passed'] and not stage['timed_out'] and stage['exit_code']==0
        assert stage['test_count']==stage['expected_test_count']==counts[stage['id']]
        for stream in ['stdout','stderr']:assert base.bind(root/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(root/stage['stderr']).read_text()
        assert re.findall(r'^Ran (\d+) tests? in ',log,re.M)==[str(stage['test_count'])] and log.rstrip().endswith('OK')
    output=(root/stages[0]['stdout']).read_text()
    [child]=re.findall(r'^R10T_LAUNCHER_EVIDENCE (C:[^\r\n]+)$',output,re.M)
    child=Path(child.strip());assert child.parent.resolve()==EVIDENCE.resolve()
    for spec in contract['stages']:
        result=base.read(child/('discovery-'+spec['id']+'.stdout.txt'))
        assert result==dict(count=spec['tests'],errors=[]),spec['id']
    negative=base.read(child/'discovery-negative-control.stdout.txt')
    assert negative['count']==1 and len(negative['errors'])==1 and 'R10T_DISCOVERY_NEGATIVE_CONTROL' in negative['errors'][0]
    return dict(targeted_tests=sum(s['test_count'] for s in stages),fresh_import_stages=62,discovered_tests=220,
        failed_import_negative_control_rejected=True,source_unchanged=True,
        stages=[dict(id=s['id'],tests=s['test_count'],seconds=s['seconds']) for s in stages])


def audit(record,current=False):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['design'],record['manifest']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
        if current:assert base.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
    prior=record['failed_source_archive'];base.verify(prior['key']);base.verify(prior['snapshot'])
    for item in base.read(prior['key']['path'])['bound_source_files']:
        assert base.bind(Path(prior['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert observe(record['run_root'])==record['observed']
    if current:structure(True)
    return dict(ok=True,current_sources_verified=current,**record['observed'],**CLAIMS)


def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root=Path(root).resolve();assert root.parent==EVIDENCE.resolve()
    observed=observe(root);assert observed['targeted_tests']==13
    d,_=structure(True);directory=EVIDENCE/('r10t-cold-import-closure-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,root/'source_before.json')
    failed_root=Path(d['failed_import_repair_attempt']['execution']['path']).parent
    failed_archive=base.archive_key(directory,ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v22.json',failed_root/'source_before.json')
    roots=base.children(root)|base.children(failed_root)|{directory,Path(d['failed_gate']['path']).parent,Path(d['cold_discovery']['path']).parent}
    manifest=directory/'manifest.json';files={p for folder in roots for p in folder.rglob('*') if p.is_file()}
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_cold_import_repair_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='fresh_interpreter_test_import_verification',question_class='development'),
        auditor=base.bind(__file__),design=base.bind(DESIGN),manifest=base.bind(manifest),source_archive=archive,failed_source_archive=failed_archive,
        run_root=str(root),observed=observed,claim_boundary=CLAIMS)
    audit(record,True);base.write_new(RECORD,record);return audit(record,True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print('R10T_COLD_IMPORT_REPAIR '+json.dumps(create(args.create_from) if args.create_from else audit(base.read(RECORD),args.current_sources)))
