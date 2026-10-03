"""Retained pre-world gate refusal and prospective native-observer integration."""
import argparse
import json
from pathlib import Path

import r10y_safety_graph_component as prior
import r10y_hold_report_component as history

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_native_observer_component_v1.json'
DESIGN = ROOT / 'sdk/development/r10y_native_observer_integration_design_v1.json'
CONTRACT = ROOT / 'sdk/development/r10y_safety_stage_contract_v3.json'
FAILED_GATE = EVIDENCE / 'development-recovery-smoke-b87670e2c1ec483a8a53b5a0ecf9a79d'
FAILED_WRAPPER = EVIDENCE / 'r10y-first-smoke-launch-1f21f807a65949969cb881bb7e517661'
FAILED_SETUP = EVIDENCE / 'l15-owned-process-identity-9e5f0e2b2b6048d3b016e0762ffa0433'
RUNS = [EVIDENCE / ('r10y-native-integration-' + suffix) for suffix in (
    '42365c616bc9414e9fe41eb5ff9fd457', 'e7c820ff5e2846edbdc057898447f8ce')]
KEYS = [ROOT / 'sdk/recovery' / f'r10y_v56_walking_entry_contract_v{i}.json' for i in (17, 18)]


def child_roots():
    roots = set()
    for folder in RUNS:
        for log in folder.glob('*.stdout.log'):
            for line in log.read_text(encoding='utf-8').splitlines():
                if ' ' not in line:
                    continue
                label, value = line.split(' ', 1)
                if label.endswith(('_ROOT', '_EVIDENCE', '_CHECK')):
                    path = Path(value.strip())
                    if path.parent == EVIDENCE and path.is_dir():
                        roots.add(path)
    return sorted(roots)


def check_logs(folder, stages):
    for stage in stages:
        for stream in ('stdout', 'stderr'):
            assert native.diagnosis.binding(folder / stage[stream])['raw_sha256'] == 'sha256:' + stage[stream + '_sha256']


def observations():
    assert prior.audit()['ok']
    gate = native.read(FAILED_GATE / 'supervisor_result.json')
    assert gate['ok'] is False and gate['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:owned_process_relationship'
    assert gate['physical_attempt_started'] is False and gate['children'] == []
    assert gate['source_snapshot'] == dict(head='36a5007cced370f2a41fc166807c4a51027bc815', dirty=False, status=[], changed_file_bindings=[])
    assert not (FAILED_GATE / 'declaration.json').exists()
    stages = gate['safety_stages']
    assert len(stages) == 13 and all(s['passed'] for s in stages[:12])
    assert sum(s['test_count'] for s in stages[:12]) == 31
    assert stages[-1]['id'] == 'owned_process_relationship' and stages[-1]['test_count'] == 0
    error = (FAILED_GATE / 'owned_process_relationship.stderr.log').read_text(encoding='utf-8')
    assert 'subprocess.TimeoutExpired' in error and 'timed out after 60 seconds' in error
    assert native.read(FAILED_WRAPPER / 'execution.json')['exit_code'] == 1
    check_logs(FAILED_GATE, stages)
    for folder, key in zip(RUNS, KEYS, strict=True):
        assert history.retained_source_key(key, folder) == 1309
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
        check_logs(folder, native.read(folder / 'result.json')['stages'])
    first, second = [native.read(p / 'result.json') for p in RUNS]
    assert first['ok'] is False and first['failure_code'] == 'R10Y_STAGE_FAILED:r10y_launch_guard'
    assert [(s['id'], s['test_count'], s['passed']) for s in first['stages']] == [
        ('owned_process_relationship', 13, True), ('r10y_launch_guard', 7, False)]
    assert 'R10Y_LAUNCH_SAFETY_CONTRACT' in (RUNS[0] / 'r10y_launch_guard.stderr.log').read_text(encoding='utf-8')
    assert second['ok'] is True and second['failure_code'] == ''
    assert [(s['id'], s['test_count']) for s in second['stages']] == [
        ('r10y_launch_guard', 7), ('r10y_launcher', 3), ('r10y_compact_retention', 1)]
    assert all(s['passed'] and not s['timed_out'] and s['exit_code'] == 0 for s in second['stages'])
    roots = child_roots()
    discovery = [native.read(p / 'stage-discovery.json') for p in roots if (p / 'stage-discovery.json').is_file()]
    assert len(discovery) == 1 and len(discovery[0]['stages']) == 49 and discovery[0]['total_tests'] == 176
    retention = next(p for p in roots if p.name.startswith('r10y-retention-check-'))
    value = native.read(retention / 'result.json')
    assert value['ok'] is True and len(value['cases']) == 9 and all(c['passed'] for c in value['cases'])
    fixed = native.read(CONTRACT)
    assert fixed['total_tests'] == sum(s['tests'] for s in fixed['stages']) == 176
    assert len(fixed['stages']) == 49
    return dict(ok=True, original_gate_passed=False, original_gate_passed_stages=12,
        original_gate_passed_tests=31, original_failed_stage_tests_run=0,
        original_gate_physical_attempt_started=False, original_fixture_failure_retained=True,
        native_ownership_tests_passed=13, additional_integration_tests_passed=11,
        retained_payload_and_selection_controls=9, declared_stages=49, declared_tests=176,
        complete_smoke_safety_gate_passed=False, physical_acceptance_authority=False,
        release_authority=False, world_build_count=0, solver_step_count=0)


def capture():
    assert not RECORD.exists()
    observed = observations()
    folders = [FAILED_GATE, FAILED_WRAPPER, FAILED_SETUP, *RUNS, *child_roots()]
    files = [p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10y_native_observer_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='retained_gate_refusal_and_prospective_integration', question_class='development'),
        dependencies=[native.diagnosis.binding(p) for p in [prior.RECORD, Path(__file__), DESIGN, CONTRACT, *KEYS]],
        retained_evidence=[native.diagnosis.binding(p) for p in files], observed=observed,
        next_action='Freeze and push the current complete source key, then execute all 49 stages freshly before any phase-248 reservation. The original failed gate and targeted component passes grant no physical authority.'))
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
    print('R10Y_NATIVE_OBSERVER_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
