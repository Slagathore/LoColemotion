"""Audit retained R10AB launcher and selected native interfaces; no qualification."""
import argparse
import json
from pathlib import Path

import r10ab_walking_report_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ab_launcher_component_v1.json'
CONTRACT = ROOT / 'sdk/development/r10ab_safety_stage_contract_v1.json'
KEYS = [ROOT / 'sdk/recovery/r10ab_v56_walking_entry_contract_v5.json']
WRAPPERS = [EVIDENCE / 'r10ab-launcher-check-fd9b41f07f774801956542314d2753d3']
GUARD = EVIDENCE / 'r10ab-launch-guard-5d54574f53994c2099c2421a56748f7d'
LAUNCHER = EVIDENCE / 'r10ab-launcher-f06e6bcc09d243c3acf74c8c9f1ee80c'
RETENTION = EVIDENCE / 'r10ab-retention-check-83b5be82bad44498ae79759785ed492f'
NATIVE = EVIDENCE / 'r10ab-native-safety-components-956611e6c6ed4c4c9d64ff8018bd5ce6'
BOUNDARIES = EVIDENCE / 'r10ab-native-walking-boundaries-5ec02211707a47548d6f203601979e4f'
EXTRA = [EVIDENCE / name for name in (
    'development-r10ab-runtime-fcf494e274284947bcb081cb4debccfb',
    'development-v50-godot-body-2cf87aa8f1fc4b16a580be22b02d8326')]
STAGES, TESTS = 54, 178


def passed(folder, module, count):
    assert native.read(folder / (module + '.py.result.json')) == dict(
        ok=True, tests=count, failures=0, errors=0, world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def observations():
    assert prior.audit()['ok']
    inputs = len(native.read(KEYS[0])['bound_source_files'])
    for folder in WRAPPERS:
        assert prior.prior.retained_source_key(KEYS[0], folder) == inputs
        assert native.read(folder / 'execution.json')['exit_code'] == 0
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    for name, count in (('launch_guard', 7), ('smoke_reader', 3), ('retention_gate', 1), ('launcher', 3)):
        passed(WRAPPERS[0], 'test_r10ab_' + name, count)
    passed(WRAPPERS[0], 'test_development_recovery_smoke_reader', 3)
    for name, count in (('runtime', 4), ('native_safety_components', 2), ('measured_body_adapter', 14), ('native_walking_boundaries', 1)):
        passed(WRAPPERS[0], 'test_r10ab_' + name, count)
    for folder in (GUARD, LAUNCHER, RETENTION, NATIVE, BOUNDARIES):
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
    selected = json.loads((LAUNCHER / 'single.stdout.txt').read_text(encoding='utf-8'))
    assert selected['roles'] == ['kick_passive_recovery_resume'] and selected['seed'] == 51008
    assert selected['timeout'] == selected['fields']['timeout_seconds_per_child'] == 1740
    assert selected['fields']['independent_replay_timeout_seconds'] == 900
    assert selected['fields']['r10ab_development']['seed']['prefix_phase'] == 248
    for label, code in (('single', None), ('stage-selection', None),
        ('paired', 'R10AB_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK'),
        ('old-seed', 'R10V_OPTIONS_REQUIRE_R10V_ROUTE'), ('old-host', 'R10V_HOST_OPTIONS_REQUIRE_R10V_ROUTE'),
        ('campaign', 'R10X_CAMPAIGN_LIBRARY_ONLY')):
        run = native.read(LAUNCHER / (label + '.execution.json'))
        assert run['returncode'] == (0 if code is None else 1)
        assert run['world_build_count'] == run['solver_step_count'] == 0
        error = (LAUNCHER / (label + '.stderr.txt')).read_text(encoding='utf-8')
        assert error == '' if code is None else code in error
    discovered, contract = native.read(LAUNCHER / 'stage-discovery.json'), native.read(CONTRACT)
    assert len(discovered['stages']) == len(contract['stages']) == STAGES
    assert discovered['total_tests'] == contract['total_tests'] == TESTS
    assert discovered['discovered_tests'] == {s['id']: s['tests'] for s in contract['stages']}
    for declared, actual in zip(contract['stages'], discovered['stages'], strict=True):
        assert all(declared[k] == actual[k] for k in ('id', 'pattern', 'tests'))
        assert declared.get('timeout_seconds') == actual.get('timeout_seconds')
    tokens = list(GUARD.rglob('r10ab_first_support_diagnostic_51008_consumption_v1.json'))
    assert {p.parent.name for p in tokens} == {
        'test_exact_once_reservation_and_read_only_verification',
        'test_partial_publication_failure_still_consumes_population', 'test_crossed_receipts_refused_without_writes'}
    assert len(tokens) == 3
    assert not (EVIDENCE / 'r10ab_first_support_diagnostic_51008_consumption_v1.json').exists()
    retention = native.read(RETENTION / 'result.json')
    assert retention['ok'] is True and len(retention['cases']) == 9
    assert all(c['passed'] is True for c in retention['cases'])
    calls = native.read(NATIVE / 'native-result.json')
    assert calls['ok'] is True and (calls['cold_replayed'], calls['negative_controls'], calls['original_partial_calls']) == (47, 18, 24)
    orchestrator = native.read(NATIVE / 'orchestrator.json')
    assert orchestrator['ok'] is True and len(orchestrator['checks']) == 61 and all(orchestrator['checks'].values())
    boundaries = native.read(BOUNDARIES / 'cold-replay.json')
    assert boundaries['source_unchanged'] is True and len(boundaries['rows']) == 15
    assert all(row['response_byte_exact'] is True for row in boundaries['rows'])
    return dict(ok=True, passed_interface_tests=38, launcher_tests=14, legacy_reader_tests=3,
        selected_native_tests=21, retained_failed_attempts=0, tested_source_key_inputs=inputs,
        safety_stages_discovered=STAGES, safety_tests_discovered=TESTS, compact_retention_controls=9,
        fresh_native_calls=47, native_negative_controls=18, original_phase_boundary_calls=24,
        orchestrator_checks=61, walking_boundary_cases=15,
        single_kick_declaration_integrated=True, one_use_reservation_checked_in_isolated_namespace=True,
        shared_final_auditor_dispatch_integrated=True, full_final_auditor_execution_checked=False,
        complete_smoke_safety_gate_declared=True, complete_smoke_safety_gate_passed=False,
        launcher_supervision_physically_verified=False, successor_physics_observed=False,
        current_checkout_qualified=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    assert not (EVIDENCE / 'r10ab_first_support_diagnostic_51008_consumption_v1.json').exists()
    result = observations()
    folders = [*WRAPPERS, GUARD, LAUNCHER, RETENTION, NATIVE, BOUNDARIES, *EXTRA]
    files = [p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10ab_launcher_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_launcher_and_native_route_interfaces', question_class='development'),
        prior_walking_component=native.diagnosis.binding(prior.RECORD),
        safety_contract=native.diagnosis.binding(CONTRACT),
        source_keys=[native.diagnosis.binding(p) for p in KEYS],
        auditor=native.diagnosis.binding(Path(__file__)), retained_evidence=[native.diagnosis.binding(p) for p in files],
        evidence_scope='Actual PowerShell declaration, discovery, retention and refusal interfaces; isolated synthetic reservations and native calls. No full safety graph or physical child ran.',
        next_required='Clean pushed freeze and fresh complete 54-stage/178-test safety gate before the single-use phase-248 diagnostic.',
        observed=result))
    return result


def audit():
    record = native.read(RECORD)
    for row in [record['prior_walking_component'], record['safety_contract'], record['auditor'], *record['source_keys'], *record['retained_evidence']]:
        native.verify(row)
    result = observations()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10AB_LAUNCHER_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
