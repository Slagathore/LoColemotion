"""Retain the incomplete worker gate and verify separately bounded case coverage."""
import argparse
import json
from pathlib import Path

import r10y_native_observer_component as prior

native, ROOT, EVIDENCE = prior.native, prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_worker_scheduling_component_v1.json'
FAILED = EVIDENCE / 'development-recovery-smoke-1ce2363f59c24725847f689167f782f8'
WRAPPER = EVIDENCE / 'r10y-first-smoke-launch-5fe1fd1f375b45ce8a30838f929fe91d'
WORKER = EVIDENCE / 'r10y-worker-fbdd4622a7ea489788ef8fab169ddca1'
CHECK = EVIDENCE / 'r10y-worker-scheduling-3a05a001b8a94ac1a105301a65f10ece'
KEY = ROOT / 'sdk/recovery/r10y_v56_walking_entry_contract_v21.json'
CONTRACTS = [ROOT / 'sdk/development' / f'r10y_safety_stage_contract_v{i}.json' for i in (4, 5)]
CASES = ['new_partial', 'new_prone', 'original_partial', 'original_prone']


def child_roots():
    roots = set()
    for log in CHECK.glob('*.stdout.log'):
        for line in log.read_text(encoding='utf-8').splitlines():
            if ' ' not in line:
                continue
            label, value = line.split(' ', 1)
            if label.endswith(('_ROOT', '_EVIDENCE', '_CHECK')):
                path = Path(value.strip())
                if path.parent == EVIDENCE and path.is_dir():
                    roots.add(path)
    return sorted(roots)


def observations():
    assert prior.audit()['ok']
    gate = native.read(FAILED / 'supervisor_result.json')
    assert gate['ok'] is False and gate['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:r10y_worker'
    assert gate['physical_attempt_started'] is False and gate['children'] == []
    assert gate['source_snapshot'] == dict(head='b7165e6f0b7028947aa1beed06b691826b77d41a', dirty=False, status=[], changed_file_bindings=[])
    assert not (FAILED / 'declaration.json').exists()
    stages = gate['safety_stages']
    assert len(stages) == 25 and all(s['passed'] for s in stages[:24])
    assert sum(s['test_count'] for s in stages[:24]) == 84
    last = stages[-1]
    assert last['id'] == 'r10y_worker' and last['timed_out'] is True and last['test_count'] == 0
    assert native.read(WRAPPER / 'execution.json')['exit_code'] == 1
    prior.check_logs(FAILED, stages)
    original_times = []
    for name in ('new-partial', 'new-prone'):
        run = native.read(WORKER / (name + '.execution.json'))
        assert run['exit_code'] == 0 and run['world_build_count'] == run['solver_step_count'] == 0
        original_times.append(run['seconds'])
    assert original_times == [85.953, 19.5]
    assert not (WORKER / 'source_after.json').exists()  # Do not repair the interrupted record.
    assert prior.history.retained_source_key(KEY, CHECK) == 1316
    result = native.read(CHECK / 'result.json')
    assert result['ok'] is True and result['failure_code'] == ''
    assert [(s['id'], s['test_count']) for s in result['stages']] == [
        *[('r10y_worker_' + case, 1) for case in CASES], ('r10y_launch_guard', 7), ('r10y_launcher', 3)]
    assert all(s['passed'] and not s['timed_out'] and s['exit_code'] == 0 for s in result['stages'])
    prior.check_logs(CHECK, result['stages'])
    lock = native.read(CHECK / 'lock.json')
    assert lock['acquired'] is True and lock['test_only'] is False
    roots = child_roots()
    discovery = [native.read(p / 'stage-discovery.json') for p in roots if (p / 'stage-discovery.json').is_file()]
    assert len(discovery) == 1 and len(discovery[0]['stages']) == 52 and discovery[0]['total_tests'] == 176
    for root in roots:
        assert native.read(root / 'source_before.json') == native.read(root / 'source_after.json')
    contracts = [native.read(p) for p in CONTRACTS]
    for value in contracts:
        assert len(value['stages']) == 52 and sum(s['tests'] for s in value['stages']) == value['total_tests'] == 176
        assert set(k for names in value['coverage_by_risk'].values() for k in names) == {s['id'] for s in value['stages']}
        workers = [s for s in value['stages'] if s['id'] in {'r10y_worker_' + c for c in CASES}]
        assert len(workers) == 4 and all(s['tests'] == 1 and s['timeout_seconds'] == 240 for s in workers)
    report_ids = {'r10y_complete_report', 'r10y_upright_report', 'r10y_ready_report', 'r10y_timeout_report', 'r10y_walking_report'}
    for old, new in zip(contracts[0]['stages'], contracts[1]['stages'], strict=True):
        assert new == (dict(old, timeout_seconds=600) if old['id'] in report_ids else old)
    # Original passing suites supply budget planning only, never gate reuse.
    timing_logs = [
        ('r10y-report-launch-3c39c624a5e949fc91ecec36e87e641c', 'Ran 2 tests in 272.458s'),
        ('r10y-hold-report-launch-ccd62b6eaf674a1382170a658f62b076', 'Ran 3 tests in 737.802s'),
        ('r10y-walking-integration-launch-d049a542ea14455590289bbbcaee7306', 'Ran 2 tests in 330.605s')]
    for folder, expected in timing_logs:
        assert expected in (EVIDENCE / folder / 'stderr.log').read_text(encoding='utf-8')
    return dict(ok=True, original_gate_passed=False, original_passed_stages=24, original_passed_tests=84,
        original_worker_suite_incomplete=True, original_gate_physical_attempt_started=False,
        separate_worker_tests_passed=4, launch_guard_and_discovery_tests_passed=10,
        declared_stages=52, declared_tests=176, worker_child_deadline_seconds=180,
        worker_stage_deadline_seconds=240, complete_report_stage_deadline_seconds=600,
        complete_smoke_safety_gate_passed=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in [FAILED, WRAPPER, WORKER, CHECK, *child_roots()]
        for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10y_worker_scheduling_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='retained_pre_world_refusal_and_zero_world_scheduling', question_class='development'),
        dependencies=[native.diagnosis.binding(p) for p in [prior.RECORD, Path(__file__), KEY, *CONTRACTS]],
        retained_evidence=[native.diagnosis.binding(p) for p in files], observed=observed,
        next_action='Execute the full current 52-stage safety graph from its clean pushed source freeze before any SingleKick reservation. No stage result is reused.'))
    return observed


def audit():
    value = native.read(RECORD)
    for row in value['dependencies'] + value['retained_evidence']:
        native.verify(row)
    observed = observations()
    assert value['observed'] == observed
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10Y_WORKER_SCHEDULING_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
