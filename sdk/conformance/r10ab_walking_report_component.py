"""Audit the retained R10AB kicked hold, fresh walking and finite-task checks.

This consumer verifies retained native replays against their exact source
snapshot. It qualifies no launcher, no full walking horizon, no matched
comparison and no physical recovery behavior.
"""
import argparse
import json
from pathlib import Path

import r10ab_hold_report_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
replay = prior.prior.retained_replay
RECORD = ROOT / 'sdk/recovery/r10ab_walking_report_component_v1.json'
KEY = prior.KEY
REPORTS = EVIDENCE / 'r10ab-complete-walking-report-b120e13025934338aa1f0b324b2ed09c'
WRAPPERS = list(prior.WRAPPERS)
REFUSALS = dict(shutdown='R10AB_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
    memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    motor='DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK')
FAILURES = []
MEASUREMENT = 'sporespore_r10ab_finite_task_measurement_v1'
SEGMENTS = ['v50_post_recovery_settling', 'walking_resume']
TRANSITIONS = 607
HOLD_COMMANDS = 30
WALKING_COMMANDS = 2


def observations():
    held = prior.audit()
    assert held['ok'] is True
    inputs = prior.retained_source_key(KEY, REPORTS)
    assert native.read(REPORTS / 'source_before.json') == native.read(REPORTS / 'setup_source_after.json')
    execution = native.read(REPORTS / 'execution.json')
    assert execution['exit_code'] == 0
    assert execution['world_build_count'] == execution['solver_step_count'] == 0
    assert (REPORTS / 'stderr.log').read_bytes() == b''
    report = native.read(REPORTS / 'walking/worker_report.json')
    sessions = report['retained_arm']['walking_sessions']
    assert [s['evaluation_segment_id'] for s in sessions] == SEGMENTS
    assert [len(s['step_receipt_sha256s']) for s in sessions] == [HOLD_COMMANDS, WALKING_COMMANDS]
    assert len({s['session_id'] for s in sessions}) == len(SEGMENTS)
    for session in sessions:
        assert session['completion_receipt']['adapter_shutdown_receipt'][
            'native_controller_session_destroy_count'] == 1
    for result in (replay(REPORTS / 'walking'), native.read(REPORTS / 'walking/result.json')):
        assert result['ok'] is True and result['complete_report_timeline_replayed'] is True
        assert result['initial_global_semantic_step'] == 0
        assert result['transition_count'] == TRANSITIONS
        assert result['stance_entry_replay']['replayed_post_recovery_hold_commands'] == HOLD_COMMANDS
        assert result['stance_entry_replay']['post_recovery_ready_dwell'] == HOLD_COMMANDS
        assert result['walking_control_replay']['replayed_walking_steps'] == WALKING_COMMANDS
        assert result['walking_contact_validation']['validated_native_contact_steps'] == WALKING_COMMANDS
        assert result['finite_recovery_task']['cycle_and_stop_boundary_reached'] is False
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
    measured = native.read(REPORTS / 'finite-task.json')
    assert measured['schema_version'] == MEASUREMENT
    assert measured['finite_task_predicates_passed'] is False
    assert measured['predicates']['declared_entry_kind'] is False
    assert measured['predicates']['planned_cycles'] is False
    assert native.read(REPORTS / 'refusals.json') == REFUSALS
    for variant, code in REFUSALS.items():
        refused = replay(REPORTS / variant, expected_exit=1)
        assert refused['ok'] is False and refused['failure_code'] == code
    for folder in WRAPPERS:
        assert native.read(folder / 'execution.json')['exit_code'] == 0
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
        prior.retained_group(folder, 'walking', 2)
    return dict(ok=True, preliminary_tests=held['preliminary_tests'],
        complete_report_tests=2, retained_failed_attempts=len(FAILURES),
        tested_source_key_inputs=inputs, transitions=TRANSITIONS, hold_commands=HOLD_COMMANDS,
        walking_commands=WALKING_COMMANDS, crossed_record_refusals=len(REFUSALS),
        kicked_recovery_hold_walking_report_checked=True, finite_task_component_checked=True,
        host_deadline_declaration_checked=True,
        no_kick_preparation_report_checked=False, launcher_supervision_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        current_checkout_qualified=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in (REPORTS, *WRAPPERS) for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10ab_walking_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_kicked_walking_report_and_task_checks', question_class='development'),
        prior_hold_component=native.diagnosis.binding(prior.RECORD),
        source_key=native.diagnosis.binding(KEY), auditor=native.diagnosis.binding(Path(__file__)),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' /
            f'r10ab_v56_walking_entry_contract_v{i}.json') for i in (4,)],
        retained_evidence=[native.diagnosis.binding(p) for p in files],
        retained_failure_reasons=FAILURES,
        evidence_scope='Supplied synthetic kicked poses, a ready hold and two fresh native walking commands. No physical recovery, planned cycle horizon or matched comparison is asserted.',
        coverage_adequacy='Two walking commands cover session construction, initial memory, motor retention and finalization; they do not cover full-horizon walking behavior. The declared population is SingleKick, so no-kick preparation remains unreachable here and is still required before a paired successor.',
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
    print('R10AB_WALKING_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
