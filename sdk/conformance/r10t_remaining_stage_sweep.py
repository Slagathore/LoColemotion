"""Retain the full remaining-stage diagnostic, including every failed stage."""
import argparse
import ast
import json
from pathlib import Path
import re
import uuid
import r10t_route_integration_component as base

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
DESIGN = ROOT/'sdk/recovery/r10t_remaining_stage_sweep_design_v1.json'
KEY = ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v24.json'
RECORD = ROOT/'sdk/recovery/r10t_remaining_stage_sweep_component_v1.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, controller_changed=False,
    native_dll_changed=False, host_deadlines_changed=False, physical_budgets_changed=False,
    complete_smoke_safety_gate_passed=False, physical_attempt_started=False,
    physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def structure(current=False):
    design = base.read(DESIGN)
    for name in ['failed_gate', 'safety_contract', 'prior_source_component']:
        base.verify(design[name])
    failed = base.read(design['failed_gate']['path'])
    assert failed['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:r10t_finite_task'
    assert not failed['physical_attempt_started']
    assert sum(s['test_count'] for s in failed['safety_stages'] if s['passed']) == 100
    stage = failed['safety_stages'][-1]
    root = Path(design['failed_gate']['path']).parent
    for stream in ['stdout', 'stderr']:
        assert base.bind(root/stage[stream])['raw_sha256'] == 'sha256:'+stage[stream+'_sha256']
    assert "ModuleNotFoundError: No module named 'sporespore_locomotion'" in (root/stage['stderr']).read_text()
    contract = base.read(design['safety_contract']['path'])
    selected = contract['stages'][34:]
    assert len(contract['stages']) == 62 and contract['total_tests'] == 220
    assert len(selected) == 28 and sum(s['tests'] for s in selected) == 120
    assert selected[0]['id'] == 'r10t_finite_task'
    assert [s['id'] for s in selected] == design['target_stage_ids']
    if current:
        archive = base.read(design['prior_source_component']['path'])['source_archive']
        def classes(path):
            tree = ast.parse(path.read_text())
            return [ast.dump(node, include_attributes=False) for node in tree.body if isinstance(node, ast.ClassDef)]
        name = 'tests/test_r10t_finite_task_audit.py'
        assert classes(ROOT/name) == classes(Path(archive['directory'])/name)
    return design, selected


def observe(root):
    root = Path(root)
    _, selected = structure()
    assert base.read(root/'source_before.json') == base.read(root/'source_after.json')
    execution = base.read(root/'execution.json')
    assert execution['source_unchanged'] and not execution['failure_code']
    assert execution['world_build_count'] == execution['solver_step_count'] == 0
    lock = base.read(root/'operation_lock.json')
    assert lock['acquired'] and not lock['test_only'] and lock['role'] == 'conformance'
    assert not lock['abandoned_owner_recovered']
    stages = base.read(root/'stage_results.json')
    assert [s['id'] for s in stages] == [s['id'] for s in selected]
    passed = 0
    failures = []
    for stage, spec in zip(stages, selected):
        assert stage['expected_test_count'] == spec['tests']
        for stream in ['stdout', 'stderr']:
            assert base.bind(root/stage[stream])['raw_sha256'] == 'sha256:'+stage[stream+'_sha256']
        if stage['passed']:
            assert stage['exit_code'] == 0 and not stage['timed_out']
            assert stage['test_count'] == spec['tests']
            log = (root/stage['stderr']).read_text()
            assert re.findall(r'^Ran (\d+) tests? in ', log, re.M) == [str(spec['tests'])]
            assert log.rstrip().endswith('OK')
            passed += spec['tests']
        else:
            failures.append(stage['id'])
    assert execution['exit_code'] == int(bool(failures))
    return dict(selected_stages=28, selected_tests=120, passed_stages=28-len(failures),
        passed_tests=passed, failed_stage_ids=failures, all_remaining_stages_executed=True,
        source_unchanged=True, stages=stages)


def audit(record, current=False):
    assert record['claim_boundary'] == CLAIMS
    for item in [record['auditor'], record['design'], record['manifest']]:
        base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:
        base.verify(item)
    archive = record['source_archive']
    base.verify(archive['key']); base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
        if current:
            assert base.bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
    assert observe(record['run_root']) == record['observed']
    structure(current)
    return dict(ok=True, current_sources_verified=current, **record['observed'], **CLAIMS)


def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root = Path(root).resolve(); assert root.parent == EVIDENCE.resolve()
    observed = observe(root)
    design, _ = structure(True)
    directory = EVIDENCE/('r10t-remaining-stage-closure-'+uuid.uuid4().hex); directory.mkdir()
    archive = base.archive_key(directory, KEY, root/'source_before.json')
    roots = base.children(root) | {directory, Path(design['failed_gate']['path']).parent}
    manifest = directory/'manifest.json'
    files = {p for folder in roots for p in folder.rglob('*') if p.is_file()}
    base.write_new(manifest, dict(files=[base.bind(p) for p in sorted(files)]))
    record = dict(schema_version='sporespore_r10t_remaining_stage_sweep_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='collect_all_remaining_stage_diagnostic', question_class='development'),
        auditor=base.bind(__file__), design=base.bind(DESIGN), manifest=base.bind(manifest),
        source_archive=archive, run_root=str(root), observed=observed, claim_boundary=CLAIMS)
    audit(record, True); base.write_new(RECORD, record)
    return audit(record, True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--create-from'); parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('R10T_REMAINING_STAGE_SWEEP '+json.dumps(create(args.create_from) if args.create_from
        else audit(base.read(RECORD), args.current_sources)))
