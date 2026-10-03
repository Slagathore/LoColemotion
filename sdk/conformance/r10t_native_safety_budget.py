"""Audit R10T's distinct timeout wrapper for unchanged native safety tests."""
import argparse
import json
from pathlib import Path
import re
import unittest
import uuid
import r10t_route_integration_component as base

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
DESIGN = ROOT/'sdk/recovery/r10t_native_safety_budget_design_v1.json'
KEY = ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v16.json'
RECORD = ROOT/'sdk/recovery/r10t_native_safety_budget_component_v1.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, assertions_changed=False,
    native_core_changed=False, native_dll_changed=False, physical_budgets_changed=False,
    original_failed_gate_reclassified=False, complete_smoke_safety_gate_passed=False,
    physical_attempt_started=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20')


def ids(suite):
    return [item for case in suite for item in
        (ids(case) if isinstance(case, unittest.TestSuite) else [case.id()])]


def check():
    design=base.read(DESIGN)
    for key in ['old_graph','new_graph','failed_gate','timing_diagnostic_execution',
                'original_python_test','original_native_fixture']:
        base.verify(design[key])
    old=base.read(ROOT/design['old_graph']['path']);new=base.read(ROOT/design['new_graph']['path'])
    expected=json.loads(json.dumps(old['stages']))
    [stage for stage in expected if stage['id']=='smoke_native_safety'][0]['pattern']='test_development_r10t_native_safety.py'
    assert new['stages']==expected and len(expected)==51
    assert sum(s['tests'] for s in expected)==old['total_tests']==new['total_tests']==220
    timeouts=dict(old['stage_timeout_overrides_seconds'],smoke_native_safety=360)
    assert new['stage_timeout_overrides_seconds']==timeouts
    assert old['component_coverage_reuse']==new['component_coverage_reuse']
    loader=unittest.TestLoader()
    previous=ids(loader.discover(str(ROOT/'tests'),pattern='test_development_recovery_smoke.py'))
    selected=ids(loader.discover(str(ROOT/'tests'),pattern='test_development_r10t_native_safety.py'))
    assert not loader.errors and previous==selected and len(selected)==3
    failed=base.read(design['failed_gate']['path'])
    assert failed['physical_attempt_started'] is False and failed['failure_code']=='SMOKE_SAFETY_GATE_FAILED:smoke_native_safety'
    stages=failed['safety_stages'];assert len(stages)==8 and all(s['passed'] for s in stages[:-1])
    assert not stages[-1]['passed'] and stages[-1]['test_count']==0
    log=(Path(design['failed_gate']['path']).parent/'smoke_native_safety.stderr.log').read_text()
    assert 'timed out after 150 seconds' in log and 'Ran 0 tests' in log
    diagnostic=Path(design['timing_diagnostic_root'])
    execution=base.read(diagnostic/'execution.json')
    assert execution['exit_code']==0 and execution['source_unchanged'] and execution['production_gate_passed'] is False
    assert base.read(diagnostic/'source_before.json')==base.read(diagnostic/'source_after.json')
    log=(diagnostic/'tests.stderr.txt').read_text()
    assert re.findall(r'^Ran (\d+) tests in ',log,re.M)==['3'] and log.rstrip().endswith('OK')
    return dict(stages=51,tests=220,identical_native_safety_test_ids=selected,
        timing_diagnostic_seconds=execution['seconds'],fixture_timeout_seconds=300,worker_refusal_timeout_seconds=20,outer_stage_timeout_seconds=360)


def observe(root):
    root=Path(root)
    assert base.read(root/'source_before.json')==base.read(root/'source_after.json')
    execution=base.read(root/'execution.json');assert execution['exit_code']==0 and execution['source_unchanged']
    lock=base.read(root/'operation_lock.json')
    assert lock['acquired'] and lock['role']=='conformance' and not lock['test_only']
    stages=base.read(root/'stage_results.json')
    assert [s['id'] for s in stages]==['r10t_budget_launcher_checks','smoke_native_safety']
    for count,stage in zip([13,3],stages,strict=True):
        assert stage['passed'] and not stage['timed_out'] and stage['exit_code']==0
        assert stage['test_count']==stage['expected_test_count']==count
        for stream in ['stdout','stderr']:
            assert base.bind(root/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(root/stage['stderr']).read_text()
        assert re.findall(r'^Ran (\d+) tests in ',log,re.M)==[str(count)] and log.rstrip().endswith('OK')
    return dict(targeted_tests=16,source_unchanged=True,stages=[dict(id=s['id'],tests=s['test_count'],seconds=s['seconds']) for s in stages])


def audit(record,current_sources=False):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['design'],record['manifest']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
        if current_sources:assert base.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
    assert observe(record['run_root'])==record['observed']
    if current_sources:assert check()==record['population_check']
    return dict(ok=True,current_sources_verified=current_sources,**record['observed'],**CLAIMS)


def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root=Path(root).resolve();assert root.parent==EVIDENCE.resolve()
    observed=observe(root);checked=check();design=base.read(DESIGN)
    directory=EVIDENCE/('r10t-native-safety-budget-closure-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,root/'source_before.json')
    roots=base.children(root)|{directory,Path(design['timing_diagnostic_root']),Path(design['failed_gate']['path']).parent,
        EVIDENCE/'r10t-partitioned-gate-invocation-52036b2278074496a14c7467f4b9ab3f'}
    manifest=directory/'manifest.json'
    files={p for folder in roots for p in folder.rglob('*') if p.is_file()}
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_native_safety_budget_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='bounded_zero_world_native_safety_test_budget',question_class='development'),
        auditor=base.bind(__file__),design=base.bind(DESIGN),manifest=base.bind(manifest),source_archive=archive,
        run_root=str(root),observed=observed,population_check=checked,claim_boundary=CLAIMS)
    audit(record,True);base.write_new(RECORD,record);return audit(record,True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    result=check() if args.check else create(args.create_from) if args.create_from else audit(base.read(RECORD),args.current_sources)
    print('R10T_NATIVE_SAFETY_BUDGET '+json.dumps(result))
