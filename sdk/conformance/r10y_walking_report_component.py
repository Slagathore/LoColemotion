"""Audit retained R10Y kicked walking and task checks, without native execution.

Historical failures remain failures. This consumer verifies their original
bytes and the successful successor receipts; it does not qualify a launcher.
"""
import argparse
import json
from pathlib import Path

import r10y_hold_report_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_walking_report_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10y_v56_walking_entry_contract_v12.json'
WRAPPERS = [EVIDENCE / name for name in (
    'r10y-task-deadline-check-14f4f9713895446fb362cd705160250b',
    'r10y-walking-integration-launch-9881bbdc2b4f49f8b7df56a2b26dfbb6',
    'r10y-walking-integration-launch-b57d02e2cfa0425da11e312e1ac9b31d',
    'r10y-walking-integration-launch-96931769455842099929646638d9e2ef',
    'r10y-walking-integration-launch-096e492d4b5d4bb4bb46d29c32435063',
    'r10y-walking-integration-launch-44df9519a52d4290bfcdd66dfeb961d6',
    'r10y-walking-integration-launch-d049a542ea14455590289bbbcaee7306')]
REPORTS = [EVIDENCE / ('r10y-complete-walking-report-' + suffix) for suffix in (
    '1413733fda244eb5818914c100c6a4f8',
    '9ce2dd65776f43039c69e7944b6cc065',
    '6faf5a928d474876bc87ed11da85a78f',
    'ec893c88e6ae49eb89dae8ab3c020bb1',
    '933ae212b0054bab8c131c0d6bf337a6')]
REFUSALS = dict(shutdown='R10Y_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
    memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    motor='DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK')
FAILURES = [
    'Test compared complete readiness metadata despite separately declared successor policy bindings.',
    'Test incorrectly compared an immutable historical entry dependency with current file bytes.',
    'Synthetic Godot fixture omitted an explicit Dictionary type; producer refused before native work.',
    'Synthetic first walking sample crossed the final hold source; cold reader refused trace source.',
    'Native replay passed but Python walking measurement omitted the R10Y horizon schema and raised KeyError.',
    'Positive report and task checks passed; shutdown negative test expected a general code instead of the exact R10Y finalization refusal.']


def observations():
    assert prior.audit()['ok']
    final = REPORTS[-1]
    assert prior.retained_source_key(KEY, final) == 1283
    assert native.read(final / 'source_before.json') == native.read(final / 'setup_source_after.json')
    for index, folder in enumerate(WRAPPERS):
        assert native.read(folder / 'execution.json')['exit_code'] == (0 if index == 6 else 1)
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    for name, count in (('task-deadline-result.json', 23), ('walking-result.json', 2)):
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
    assert measured['schema_version'] == 'sporespore_r10y_finite_task_measurement_v1'
    assert measured['finite_task_predicates_passed'] is False
    assert measured['predicates']['declared_entry_kind'] is False
    assert measured['predicates']['planned_cycles'] is False
    assert native.read(final / 'refusals.json') == REFUSALS
    for variant, code in REFUSALS.items():
        result = prior.prior.retained_replay(final / variant, expected_exit=1)
        assert result['ok'] is False and result['failure_code'] == code
    assert 'Cannot infer the type of "cycle"' in (REPORTS[0] / 'stderr.log').read_text(encoding='utf-8')
    assert prior.prior.retained_replay(REPORTS[1] / 'walking', 1)['failure_code'] == 'R10Y_ENTRY_REPLAY_TRACE_SOURCE'
    assert prior.prior.retained_replay(REPORTS[2] / 'walking')['transition_count'] == 607
    assert "KeyError: 'maximum_v50_walking_commands'" in (WRAPPERS[4] / 'stderr.log').read_text(encoding='utf-8')
    assert native.read(REPORTS[3] / 'walking/result.json')['ok'] is True
    assert prior.prior.retained_replay(REPORTS[3] / 'shutdown', 1)['failure_code'] == REFUSALS['shutdown']
    return dict(ok=True, preliminary_tests=23, complete_report_tests=2, retained_failed_attempts=6,
        tested_source_key_inputs=1283, transitions=607, hold_commands=30, walking_commands=2,
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
    native.write(RECORD, dict(schema_version='sporespore_r10y_walking_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_kicked_walking_report_and_task_checks', question_class='development'),
        prior_hold_component=native.diagnosis.binding(prior.RECORD),
        source_key=native.diagnosis.binding(KEY), auditor=native.diagnosis.binding(Path(__file__)),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' /
            f'r10y_v56_walking_entry_contract_v{i}.json') for i in range(6, 13)],
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
    print('R10Y_WALKING_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
