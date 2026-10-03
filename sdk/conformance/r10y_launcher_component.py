"""Retained R10Y launcher/reservation/header checks; no launch qualification."""
import argparse
import json
from pathlib import Path

import r10y_walking_report_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_launcher_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10y_v56_walking_entry_contract_v13.json'
WRAPPER = EVIDENCE / 'r10y-launcher-check-d6781d2f15cf4159ad4a127b7aef1680'
GUARD = EVIDENCE / 'r10y-launch-guard-a8a3aa7eddb2451aa8984e64fb1e6dd3'
LAUNCHER = EVIDENCE / 'r10y-launcher-fa8a267aafa045e2918dc58bda8bda1d'


def observations():
    assert prior.audit()['ok']
    assert prior.prior.retained_source_key(KEY, WRAPPER) == 1289
    for folder in (WRAPPER, GUARD, LAUNCHER):
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
    assert native.read(WRAPPER / 'execution.json')['exit_code'] == 0
    lock = native.read(WRAPPER / 'lock.json')
    assert lock['acquired'] is True and lock['test_only'] is False
    assert native.read(WRAPPER / 'result.json') == dict(ok=True, tests=21, failures=0, errors=0,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    log = (WRAPPER / 'stderr.log').read_text(encoding='utf-8')
    assert 'Ran 21 tests' in log and log.rstrip().endswith('OK')
    selected = json.loads((LAUNCHER / 'single.stdout.txt').read_text(encoding='utf-8'))
    assert selected['roles'] == ['kick_passive_recovery_resume'] and selected['seed'] == 51008
    assert selected['timeout'] == selected['fields']['timeout_seconds_per_child'] == 1740
    assert selected['fields']['independent_replay_timeout_seconds'] == 900
    assert selected['fields']['r10y_development']['seed']['prefix_phase'] == 248
    for label, code in (('single', None), ('paired', 'R10Y_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK'),
        ('old-seed', 'R10V_OPTIONS_REQUIRE_R10V_ROUTE'), ('old-host', 'R10V_HOST_OPTIONS_REQUIRE_R10V_ROUTE'),
        ('campaign', 'R10X_CAMPAIGN_LIBRARY_ONLY'), ('pending-gate', 'R10Y_COMPLETE_SAFETY_CONTRACT_PENDING')):
        run = native.read(LAUNCHER / (label + '.execution.json'))
        assert run['returncode'] == (0 if code is None else 1)
        assert run['world_build_count'] == run['solver_step_count'] == 0
        error = (LAUNCHER / (label + '.stderr.txt')).read_text(encoding='utf-8')
        assert error == '' if code is None else code in error
    tokens = list(GUARD.rglob('r10y_first_support_diagnostic_51008_consumption_v1.json'))
    assert len(tokens) == 3
    assert {p.parent.name for p in tokens} == {
        'test_exact_once_reservation_and_read_only_verification',
        'test_partial_publication_failure_still_consumes_population', 'test_crossed_receipts_refused_without_writes'}
    return dict(ok=True, tests=21, launch_guard_tests=7, actual_powershell_launcher_tests=3,
        r10y_header_tests=3, legacy_reader_tests=3, deadline_regression_tests=5,
        source_key_inputs=1289, single_kick_declaration_integrated=True,
        one_use_reservation_checked_in_isolated_namespace=True,
        shared_final_auditor_dispatch_integrated=True, full_final_auditor_execution_checked=False,
        complete_smoke_safety_gate_declared=False, complete_smoke_safety_gate_passed=False,
        launcher_supervision_physically_verified=False, successor_physics_observed=False,
        current_checkout_qualified=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (WRAPPER, GUARD, LAUNCHER) for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10y_launcher_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_launcher_and_reservation_interfaces', question_class='development'),
        prior_walking_component=native.diagnosis.binding(prior.RECORD),
        source_key=native.diagnosis.binding(KEY), auditor=native.diagnosis.binding(Path(__file__)),
        retained_evidence=[native.diagnosis.binding(p) for p in files],
        evidence_scope='Actual PowerShell library and pre-execution refusals, synthetic headers and isolated synthetic gate logs. No safety stages, physical children, held-out cells or real population reservations ran.',
        next_required='Declare and execute the complete applicable R10Y safety graph, verify final publication and native launch ownership, then run the prospective phase-248 diagnostic.',
        observed=result))
    return result


def audit():
    value = native.read(RECORD)
    for row in [value['prior_walking_component'], value['source_key'], value['auditor'], *value['retained_evidence']]:
        native.verify(row)
    result = observations()
    assert result == value['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10Y_LAUNCHER_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
