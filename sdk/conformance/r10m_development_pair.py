"""Reopen R10M's consumed pair and reconstruct its bounded stop commands."""
import copy
import json

import development_recovery_smoke as smoke
import r10m_development as development
from r10l_development_pair import stop_diagnosis
from v52_extended_support_transfer import ROOT, read, verify

RECORD = ROOT / 'sdk/recovery/r10m_phase241_development_pair_closure_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('R10M_PAIR_' + code)


def command_diagnosis(report):
    """Reconstruct every stop command from its original measured input.

    This verifies that the cap was applied. It does not infer the cause of the
    disturbance or predict a different controller's future measurements.
    """
    start = report['development_cycle_stop']['final_memory']['cycle_end_command']
    rows = report['development_walking_entry']['rows'][start:]
    require(len(rows) == 120, 'COMMAND_POPULATION')
    first = rows[0]['native_output']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
    commands = []
    for index, row in enumerate(rows, 1):
        require(row['session_local_step'] == start + index
                and row['development_cycle_stopping'] is True, 'COMMAND_CLOCK')
        require(row['request']['command']['gait_amplitude'] == 0, 'ZERO_AMPLITUDE')
        actuation = row['native_output']['actuation']
        plane = actuation['receipt']['recovery_support_plane']
        require(all(rate == 0 for rate in plane['ordered_reference_velocity_rad_s']), 'REFERENCE_RATE')
        pose = plane['anchored_body_pose']
        require(all(pose[key] == first[key] for key in ['desired_body_position_world_m',
            'ordered_foot_targets_world_m', 'ordered_joint_goals_rad']), 'STATIC_TARGETS')
        guard = pose['zero_amplitude_velocity_guard']
        require(guard['schema_version'] == 'sporespore_bounded_zero_amplitude_velocity_receipt_v1'
                and guard['maximum_absolute_velocity_rad_s'] == .25
                and guard['physical_acceptance_authority'] is False, 'GUARD')
        measured = row['request']['state']['ordered_joint_observations']
        motors, receipts = actuation['ordered_commands'], guard['ordered_commands']
        require(len(measured) == len(motors) == len(receipts) == 8, 'MOTOR_POPULATION')
        joints = []
        for joint, motor, receipt in zip(measured, motors, receipts):
            identity = joint['joint_id'] + '_motor'
            require(motor['actuator_id'] == receipt['actuator_id'] == identity, 'MOTOR_IDENTITY')
            error = motor['clamped_target_position_rad'] - joint['position_rad']
            raw = 8.0 * error - .65 * joint['velocity_rad_s']
            limit = motor['maximum_target_speed_rad_s']
            original = -max(-limit, min(limit, raw))
            bounded_limit = min(.25, limit)
            bounded = max(-bounded_limit, min(bounded_limit, original))
            require(abs(receipt['original_velocity_rad_s'] - original) < 1e-12, 'ORIGINAL_COMMAND')
            require(receipt['effective_limit_rad_s'] == bounded_limit, 'EFFECTIVE_LIMIT')
            require(abs(receipt['bounded_velocity_rad_s'] - bounded) < 1e-12
                    and abs(motor['target_velocity_rad_s'] - bounded) < 1e-12, 'APPLIED_CAP')
            require(type(receipt['clipped']) is bool and receipt['clipped'] == (bounded != original), 'CLIPPED_FLAG')
            joints.append(dict(actuator_id=identity, position_rad=joint['position_rad'],
                position_error_rad=error, measured_velocity_rad_s=joint['velocity_rad_s'],
                original_velocity_rad_s=original, bounded_velocity_rad_s=bounded,
                clipped=receipt['clipped']))
        commands.append(dict(stopping_command=index, walking_command=start + index, joints=joints))
    return dict(static_targets=True, zero_reference_velocity=True, controller_gain_per_s=8.0,
        measured_velocity_damping=.65, maximum_absolute_velocity_rad_s=.25,
        affected_stopping_commands=[c['stopping_command'] for c in commands if any(j['clipped'] for j in c['joints'])],
        maximum_original_velocity_rad_s=max(abs(j['original_velocity_rad_s']) for c in commands for j in c['joints']),
        maximum_applied_velocity_rad_s=max(abs(j['bounded_velocity_rad_s']) for c in commands for j in c['joints']),
        commands=commands, causal_attribution_proven=False, changed_measurements_simulated=False,
        physical_acceptance_authority=False, release_authority=False)


def negative_controls(report, task):
    """Corrupt compact copies of original stop inputs, never retained reports."""
    original = report['development_cycle_stop']
    start = original['final_memory']['cycle_end_command']
    compact_rows = []
    for row in original['rows'][start:]:
        src = row['post_native_source']
        obs = src['observation']
        compact_rows.append(dict(session_local_step=row['session_local_step'], post_native_source=dict(
            observation=dict(center_of_mass=copy.deepcopy(obs['center_of_mass']), state=dict(
                ordered_contact_observations=copy.deepcopy(obs['state']['ordered_contact_observations']),
                base_twist_world=copy.deepcopy(obs['state']['base_twist_world']))),
            precommand_trace=dict(torso_tilt_rad=src['precommand_trace']['torso_tilt_rad']))))
    compact = dict(development_cycle_stop=dict(final_memory=copy.deepcopy(original['final_memory']),
        rows=[None] * start + compact_rows))
    require(stop_diagnosis(compact, task) == stop_diagnosis(report, task), 'COMPACT_DIAGNOSIS')
    cases = []
    for name in ['missing_row', 'crossed_clock', 'unknown_contact', 'nonfinite_velocity',
                 'unmeasured_com', 'forged_settled_count']:
        value = copy.deepcopy(compact)
        retention = value['development_cycle_stop']
        row = retention['rows'][-1]
        obs = row['post_native_source']['observation']
        if name == 'missing_row': retention['rows'].pop()
        elif name == 'crossed_clock': row['session_local_step'] += 1
        elif name == 'unknown_contact': obs['state']['ordered_contact_observations'][0]['presence'] = None
        elif name == 'nonfinite_velocity': obs['center_of_mass']['linear_velocity_world_m_s']['x'] = float('nan')
        elif name == 'unmeasured_com': obs['center_of_mass']['source_measurement'] = False
        else: retention['final_memory']['consecutive_settled_commands'] = 30
        try:
            stop_diagnosis(value, task)
        except ValueError as error:
            cases.append(dict(case=name, refused=True, error=str(error)))
        else:
            raise ValueError('R10M_PAIR_NEGATIVE_CONTROL_ACCEPTED:' + name)
    # These copies keep the full native command fields, so the actual command
    # reconstruction must reject a forged guard or applied motor command.
    command_view = dict(development_cycle_stop=dict(final_memory=copy.deepcopy(original['final_memory'])),
        development_walking_entry=dict(rows=[None] * start + report['development_walking_entry']['rows'][start:]))
    for name in ['forged_applied_cap', 'forged_original_command', 'forged_clipped_flag', 'crossed_actuator']:
        value = copy.deepcopy(command_view)
        row = value['development_walking_entry']['rows'][start + 93]
        actuation = row['native_output']['actuation']
        guard = actuation['receipt']['recovery_support_plane']['anchored_body_pose']['zero_amplitude_velocity_guard']
        if name == 'forged_applied_cap': actuation['ordered_commands'][5]['target_velocity_rad_s'] = -.5
        elif name == 'forged_original_command': guard['ordered_commands'][5]['original_velocity_rad_s'] += .1
        elif name == 'forged_clipped_flag': guard['ordered_commands'][5]['clipped'] = False
        else: guard['ordered_commands'][5]['actuator_id'] = 'front_left_knee_motor'
        try:
            command_diagnosis(value)
        except ValueError as error:
            cases.append(dict(case=name, refused=True, error=str(error)))
        else:
            raise ValueError('R10M_PAIR_NEGATIVE_CONTROL_ACCEPTED:' + name)
    return cases


def audit():
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10m_phase241_development_pair_closure_v1', 'SCHEMA')
    for key in ['auditor', 'stop_diagnosis_helper', 'checkpoint', 'entry_contract', 'candidate_profile', 'task_contract', 'runtime_binding']:
        verify(record[key])
    for item in record['retained_evidence']:
        verify(item)
    root = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + record['attempt_id'])
    require(root.as_posix() == record['evidence_root'], 'EVIDENCE_ROOT')
    checkpoint = smoke.retained_checkpoint(root)
    require(checkpoint == read(verify(record['checkpoint'])), 'CHECKPOINT')
    require(checkpoint['source_snapshot']['head'] == record['source_commit']
            and checkpoint['source_snapshot']['dirty'] is False, 'PHYSICAL_SOURCE')
    original = read(root / 'supervisor_result.json')
    require(original['ok'] is True and original['failure_code'] == '', 'VALID_DEVELOPMENT')
    stages = original['safety_stages']
    require(len(stages) == 41 and sum(s['test_count'] for s in stages) == 201
            and all(s['passed'] is True and s['timed_out'] is False and s['exit_code'] == 0 for s in stages), 'FULL_GATE')
    observed = checkpoint['observed']
    result = observed['r10m_finite_development']
    require(result == record['finite_results'], 'FINITE_RESULTS')
    require(observed['total_solver_steps'] == record['completed_solver_steps'] == 3945
            and record['physical_world_count'] == 2, 'PHYSICAL_POPULATION')
    require([c['finite_task_predicates_passed'] for c in result['cells']] == [True, False], 'ROLE_RESULTS')
    require(result['cells'][1]['measurement']['predicates'] == dict(entry_ready=True, planned_cycles=True,
        forward_advance=True, settled_stop=False, whole_walking_envelope=True, recovery_completed=True), 'KICKED_PREDICATES')
    require(not development.positive_pair_result(result, result['candidate_profile']), 'PRONE_REMAINS_CLOSED')
    task = read(verify(record['task_contract']))
    for role in smoke.ROLES:
        report = read(root / 'children' / role / 'worker_report.json')
        require(stop_diagnosis(report, task) == record['stop_diagnosis'][role], 'STOP_DIAGNOSIS:' + role)
        require(command_diagnosis(report) == record['command_diagnosis'][role], 'COMMAND_DIAGNOSIS:' + role)
        if role == smoke.ROLES[1]:
            require(negative_controls(report, task) == record['diagnostic_negative_controls'], 'NEGATIVE_CONTROLS')
    require(record['claim_boundary'] == dict(valid_development_pair=True, all_tasks_positive=False,
        phase243_prerequisite_satisfied=False, physical_acceptance_authority=False,
        release_authority=False, original_attempt_reclassified=False, sdk1_score='14/20'), 'CLAIMS')
    return dict(ok=True, safety_tests=201, safety_stages=41, physical_worlds=2, completed_solver_steps=3945,
        finite_positive_roles=1, finite_negative_roles=1, kicked_final_consecutive_settled_commands=11,
        required_final_settled_commands=30, diagnostic_negative_controls=10, phase243_prerequisite_satisfied=False,
        new_world_count=0, new_solver_step_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    print(json.dumps(audit(), sort_keys=True))
