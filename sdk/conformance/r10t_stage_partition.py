"""Audit the prospective partition of unchanged R10T full-report tests."""
import argparse
import json
from pathlib import Path
import re
import unittest
import uuid
import r10t_route_integration_component as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
DESIGN=ROOT/'sdk/recovery/r10t_report_stage_partition_design_v1.json'
GRAPH=ROOT/'sdk/development/r10t_safety_stage_contract_v2.json'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v15.json'
RECORD=ROOT/'sdk/recovery/r10t_report_stage_partition_component_v1.json'
CLAIMS=dict(world_build_count=0,solver_step_count=0,assertions_changed=False,
    native_core_changed=False,native_dll_changed=False,physical_budgets_changed=False,
    complete_smoke_safety_gate_passed=False,physical_attempt_started=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')

def ids(suite):
    return [item for case in suite for item in (ids(case) if isinstance(case,unittest.TestSuite) else [case.id()])]

def structure():
    design=base.read(DESIGN);old=base.read(ROOT/design['old_graph']['path']);new=base.read(GRAPH)
    for item in [design['previous_gate'],design['old_graph'],design['new_graph']]:base.verify(item)
    previous=base.read(design['previous_gate']['path'])
    assert previous['physical_attempt_started'] is False and previous['failure_code']=='SMOKE_SAFETY_GATE_FAILED:r10t_branch_reports'
    assert len(previous['safety_stages'])==25 and all(s['passed'] for s in previous['safety_stages'][:-1])
    failed=previous['safety_stages'][-1];assert failed['timed_out'] and failed['expected_test_count']==2 and failed['seconds']>=600
    groups={g['old_id']:g for g in design['groups']};expected=[]
    for stage in old['stages']:
        if stage['id'] not in groups:expected.append(stage);continue
        group=groups[stage['id']]
        assert stage['tests']==2 and old['stage_timeout_overrides_seconds'][stage['id']]==group['timeout_seconds']
        for case in group['cases']:
            expected.append(dict(id=case['stage_id'],pattern=case['wrapper'],tests=1))
            assert new['stage_timeout_overrides_seconds'][case['stage_id']]==group['timeout_seconds']
    assert new['stages']==expected and len(expected)==51
    assert sum(s['tests'] for s in expected)==old['total_tests']==new['total_tests']==220
    assert old['component_coverage_reuse']==new['component_coverage_reuse']
    return design

def check_design():
    design=structure();observed=[]
    for group in design['groups']:
        base.verify(group['source_file'])
        loader=unittest.TestLoader();old=ids(loader.discover(str(ROOT/'tests'),pattern=group['source_module']+'.py'))
        selected=[]
        for case in group['cases']:
            found=ids(loader.discover(str(ROOT/'tests'),pattern=case['wrapper']))
            assert found==[case['test_id']],found;selected.extend(found)
        assert not loader.errors and sorted(old)==sorted(selected)
        observed.append(dict(original_stage=group['old_id'],identical_test_ids=selected,timeout_seconds_per_stage=group['timeout_seconds']))
    return dict(stages=51,tests=220,populations=observed,**CLAIMS)

def observe(root):
    root=Path(root);before=base.read(root/'source_before.json');after=base.read(root/'source_after.json')
    assert before==after
    lock=base.read(root/'operation_lock.json');assert lock['acquired'] and lock['role']=='conformance' and not lock['test_only']
    assert lock['mutex_name']=='Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'
    execution=base.read(root/'execution.json');assert execution['exit_code']==0 and execution['source_unchanged']
    stages=base.read(root/'stage_results.json');assert [s['id'] for s in stages]==['r10t_partition_launcher_checks','r10t_partial_report']
    for count,stage in zip([13,1],stages,strict=True):
        assert stage['passed'] and not stage['timed_out'] and stage['exit_code']==0
        assert stage['test_count']==stage['expected_test_count']==count
        for stream in ['stdout','stderr']:
            assert base.bind(root/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(root/stage['stderr']).read_text(encoding='utf-8')
        assert re.findall(r'^Ran (\d+) tests? in ',log,flags=re.M)==[str(count)] and log.rstrip().endswith('OK')
    log=(root/stages[-1]['stderr']).read_text(encoding='utf-8')
    assert 'test_b_complete_partial_report_without_walking (test_development_r10t_branch_complete_report.R10TBranchCompleteReport.test_b_complete_partial_report_without_walking) ... ok' in log
    return dict(targeted_tests=14,launcher_and_authority_tests=13,fresh_complete_partial_reports=1,source_unchanged=True,
        stages=[dict(id=s['id'],tests=s['test_count'],seconds=s['seconds']) for s in stages])

def audit(record,current_sources=False):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['design'],record['manifest']]:base.verify(item)
    structure()
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    base.verify(record['prior_failed_partition_check'])
    prior=record['prior_source_archive'];base.verify(prior['key']);base.verify(prior['snapshot'])
    for item in base.read(prior['key']['path'])['bound_source_files']:
        assert base.bind(Path(prior['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
        if current_sources:assert base.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
    assert observe(record['run_root'])==record['observed']
    if current_sources:assert check_design()==record['unchanged_population_check']
    return dict(ok=True,current_sources_verified=current_sources,**record['observed'],**CLAIMS)

def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root=Path(root).resolve();assert root.parent==EVIDENCE.resolve();observed=observe(root);checked=check_design()
    directory=EVIDENCE/('r10t-stage-partition-closure-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,root/'source_before.json')
    failed_root=EVIDENCE/'r10t-stage-partition-check-6a05dd4cffb14904a81ab192b4f5398f'
    failed=base.read(failed_root/'execution.json')
    assert failed['exit_code']==1 and failed['source_unchanged']
    failed_archive=base.archive_key(directory,ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v13.json',failed_root/'source_before.json')
    roots=base.children(root)|base.children(failed_root)|{directory}
    previous=Path(base.read(DESIGN)['previous_gate']['path']).parent
    roots.add(previous)
    for log in previous.glob('*.stdout.log'):
        for value in re.findall(r'^[A-Z0-9_]+ (C:[^\r\n]+)$',log.read_text(encoding='utf-8',errors='replace'),flags=re.M):
            child=Path(value.strip())
            if child.is_dir() and child.parent.resolve()==EVIDENCE.resolve():roots.add(child)
    manifest=directory/'manifest.json'
    files={p for folder in roots for p in folder.rglob('*') if p.is_file()}
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_report_stage_partition_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_independent_report_test_stages',question_class='development'),
        auditor=base.bind(__file__),design=base.bind(DESIGN),manifest=base.bind(manifest),source_archive=archive,
        prior_failed_partition_check=base.bind(failed_root/'execution.json'),prior_source_archive=failed_archive,
        run_root=str(root),observed=observed,unchanged_population_check=checked,claim_boundary=CLAIMS)
    audit(record,True);base.write_new(RECORD,record);return audit(record,True)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    result=check_design() if args.check else create(args.create_from) if args.create_from else audit(base.read(RECORD),args.current_sources)
    print('R10T_REPORT_STAGE_PARTITION '+json.dumps(result))
