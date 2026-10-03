"""Audit retained R10Z kicked walking and task checks, without native execution.

This consumer verifies retained native replays and their exact source snapshot;
it does not qualify a launcher or assert physical recovery.
"""
import argparse
import json
from pathlib import Path

import r10z_hold_report_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10z_walking_report_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10z_v56_walking_entry_contract_v4.json'
WRAPPERS = [EVIDENCE / 'r10z-walking-report-check-80363e1504314e1ab9eed15447ec5413']
REPORTS = [EVIDENCE / 'r10z-complete-walking-report-e14cd255c27a4f71b30f86bfab99cf77']
REFUSALS = dict(shutdown='R10Z_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
    memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    motor='DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK')
FAILURES = []


def observations():
    assert prior.audit()['ok']
    final = REPORTS[-1]
    assert prior.retained_source_key(KEY, final) == 1406
    assert native.read(final / 'source_before.json') == native.read(final / 'setup_source_after.json')
    for index, folder in enumerate(WRAPPERS):
        assert native.read(folder / 'execution.json')['exit_code'] == 0
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    for name, count in (('test_r10z_finite_task_audit.py.result.json', 11), ('test_r10z_host_deadline.py.result.json', 5), ('test_r10z_complete_walking_report.py.result.json', 2)):
        result = native.read(WRAPPERS[-1] / name)
        assert result == dict(ok=True, tests=count, failures=0, errors=0,
            world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False)
    execution = native.read(final / 'execution.json')
    assert execution['exit_code'] == 0
    assert execution['world_build_count'] == execution['solver_step_count'] == 0
    assert (final / 'stderr.log').read_bytes() == b''
    for result in (prior.prior.retained_replay(final / 'walking'), native.read(final / 'walking/result.json')):
        assert result['ok'] is True and result['complete_report_timeline_replayed'] is True
        assert result['initial_global_semantic_step'] == 0 and result['transition_count'] == 607
        assert result['stance_entry_replay']['replayed_post_recovery_hold_commands'] == 30
        assert result['stance_entry_replay']['post_recovery_ready_dwell'] == 30
        assert result['walking_control_replay']['replayed_walking_steps'] == 2
        assert result['walking_contact_validation']['validated_native_contact_steps'] == 2
        assert result['finite_recovery_task']['cycle_and_stop_boundary_reached'] is False
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
    measured = native.read(final / 'finite-task.json')
    assert measured['schema_version'] == 'sporespore_r10z_finite_task_measurement_v1'
    assert measured['finite_task_predicates_passed'] is False
    assert measured['predicates']['declared_entry_kind'] is False
    assert measured['predicates']['planned_cycles'] is False
    assert native.read(final / 'refusals.json') == REFUSALS
    for variant, code in REFUSALS.items():
        result = prior.prior.retained_replay(final / variant, expected_exit=1)
        assert result['ok'] is False and result['failure_code'] == code
    return dict(ok=True, preliminary_tests=16, complete_report_tests=2, retained_failed_attempts=0,
        tested_source_key_inputs=1406, transitions=607, hold_commands=30, walking_commands=2,
        crossed_record_refusals=3, kicked_recovery_hold_walking_report_checked=True,
        host_deadline_declaration_checked=True, finite_task_component_checked=True,
        shared_walking_horizon_schema_dispatch_repaired=True,
        no_kick_preparation_report_checked=False, launcher_supervision_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        current_checkout_qualified=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in (*WRAPPERS, *REPORTS) for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10z_walking_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_kicked_walking_report_and_task_checks', question_class='development'),
        prior_hold_component=native.diagnosis.binding(prior.RECORD),
        source_key=native.diagnosis.binding(KEY), auditor=native.diagnosis.binding(Path(__file__)),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' /
            f'r10z_v56_walking_entry_contract_v{i}.json') for i in (4,)],
        retained_evidence=[native.diagnosis.binding(p) for p in files],
        retained_failure_reasons=FAILURES,
        evidence_scope='Supplied synthetic upright poses, ready hold and two fresh native walking commands. No physical recovery or complete planned cycles are asserted.',
        coverage_adequacy='First declared population is SingleKick: no-kick preparation is unreachable here and remains required before a paired successor. Two walking commands cover construction, memory, motor retention and finalization; they do not cover full-horizon behavior.',
        observed=observed))
    return observed


def audit():
    value = native.read(RECORD)
    for row in [value['prior_hold_component'], value['source_key'], value['auditor'],
                *value['retained_source_key_revisions'], *value['retained_evidence']]:
        native.verify(row)
    observed = observations()
    assert observed == value['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10Z_WALKING_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
