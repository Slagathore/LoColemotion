"""Verify two R10T suites against their current profile with unchanged assertions."""
import argparse
import json
from pathlib import Path
import re
import uuid
import r10t_route_integration_component as base

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
DESIGN = ROOT/'sdk/recovery/r10t_settling_test_profile_repair_design_v1.json'
KEY = ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v25.json'
RECORD = ROOT/'sdk/recovery/r10t_settling_test_profile_repair_component_v1.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, controller_changed=False,
    native_dll_changed=False, native_assertions_changed=False, host_deadlines_changed=False,
    physical_budgets_changed=False, complete_smoke_safety_gate_passed=False,
    physical_attempt_started=False, physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20')


def structure(current=False):
    design = base.read(DESIGN)
    for name in ['sweep_component', 'safety_contract']:
        base.verify(design[name])
    original = base.read(design['sweep_component']['path'])
    observed = original['observed']
    assert observed['passed_tests'] == 110 and observed['selected_tests'] == 120
    assert observed['failed_stage_ids'] == design['target_stage_ids']
    if current:
        archive = Path(original['source_archive']['directory'])
        old = b'r10s-v56-extended-preparation-integrated-v1.json'
        new = b'r10t-v56-post-recovery-hold-integrated-v1.json'
        for name in design['repaired_modules']:
            raw = (archive/name).read_bytes()
            assert raw.count(old) == 1 and (ROOT/name).read_bytes() == raw.replace(old, new), name
        profiles = ROOT/'sdk/development/recovery_candidates'
        assert base.read(profiles/old.decode())['runtime_binding'] == base.read(profiles/new.decode())['runtime_binding']
    return design


def observe(root):
    root = Path(root); design = structure()
    assert base.read(root/'source_before.json') == base.read(root/'source_after.json')
    execution = base.read(root/'execution.json')
    assert execution['exit_code'] == 0 and execution['source_unchanged'] and not execution['failure_code']
    lock = base.read(root/'operation_lock.json')
    assert lock['acquired'] and lock['role'] == 'conformance' and not lock['test_only']
    stages = base.read(root/'stage_results.json')
    assert [s['id'] for s in stages] == design['target_stage_ids']
    for stage in stages:
        assert stage['passed'] and stage['exit_code'] == 0 and not stage['timed_out']
        assert stage['test_count'] == stage['expected_test_count'] == 5
        for stream in ['stdout', 'stderr']:
            assert base.bind(root/stage[stream])['raw_sha256'] == 'sha256:'+stage[stream+'_sha256']
        log = (root/stage['stderr']).read_text()
        assert re.findall(r'^Ran (\d+) tests? in ', log, re.M) == ['5'] and log.rstrip().endswith('OK')
    return dict(targeted_tests=10, source_unchanged=True, stages=stages)


def audit(record, current=False):
    assert record['claim_boundary'] == CLAIMS
    for item in [record['auditor'], record['design'], record['manifest']]: base.verify(item)
    for item in base.read(record['manifest']['path'])['files']: base.verify(item)
    archive = record['source_archive']; base.verify(archive['key']); base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
        if current: assert base.bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
    assert observe(record['run_root']) == record['observed']
    structure(current)
    return dict(ok=True, current_sources_verified=current, **record['observed'], **CLAIMS)


def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root = Path(root).resolve(); assert root.parent == EVIDENCE.resolve()
    observed = observe(root); structure(True)
    directory = EVIDENCE/('r10t-settling-profile-closure-'+uuid.uuid4().hex); directory.mkdir()
    archive = base.archive_key(directory, KEY, root/'source_before.json')
    roots = base.children(root) | {directory}
    files = {p for folder in roots for p in folder.rglob('*') if p.is_file()}
    manifest = directory/'manifest.json'; base.write_new(manifest, dict(files=[base.bind(p) for p in sorted(files)]))
    record = dict(schema_version='sporespore_r10t_settling_test_profile_repair_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='current_candidate_test_profile_repair', question_class='development'),
        auditor=base.bind(__file__), design=base.bind(DESIGN), manifest=base.bind(manifest),
        source_archive=archive, run_root=str(root), observed=observed, claim_boundary=CLAIMS)
    audit(record, True); base.write_new(RECORD, record)
    return audit(record, True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--create-from')
    parser.add_argument('--current-sources', action='store_true'); args = parser.parse_args()
    result = create(args.create_from) if args.create_from else audit(base.read(RECORD), args.current_sources)
    print(json.dumps({k:v for k,v in result.items() if k != 'stages'}))
