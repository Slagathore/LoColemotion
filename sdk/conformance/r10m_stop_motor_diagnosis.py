"""Read-only motor readback and load history of the consumed R10M stop."""
import copy
import json
import math
import struct

from v52_extended_support_transfer import ROOT, read, verify

RECORD = ROOT / 'sdk/recovery/r10m_stop_motor_diagnosis_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10M_STOP_MOTOR_' + code)


def analyze(report):
    """Keep precommand motion separate from post-solver impulse/contact loads."""
    start = report['development_cycle_stop']['final_memory']['cycle_end_command']
    commands = report['development_walking_entry']['rows'][start:]
    samples = report['development_cycle_stop']['rows'][start:]
    require(len(commands) == len(samples) == 120, 'STOP_POPULATION')
    rows = []
    for index, (command, sample) in enumerate(zip(commands, samples), 1):
        require(command['session_local_step'] == sample['session_local_step'] == start + index, 'CLOCK')
        require(command['development_cycle_stopping'] is True
                and command['request']['command']['gait_amplitude'] == 0, 'STOP_COMMAND')
        post = sample['post_native_source']['observation']
        require(post['applied_actuation']['source_measurement'] is True, 'MEASURED_IMPULSE')
        require(command['commanded_global_step'] == post['applied_actuation']['source_semantic_step'], 'IMPULSE_CLOCK')
        motors = command['native_output']['actuation']['ordered_commands']
        joints = command['request']['state']['ordered_joint_observations']
        applications = command['ordered_motor_applications']
        impulses = post['applied_actuation']['ordered_applied_impulses']
        require(len(motors) == len(joints) == len(applications) == len(impulses) == 8, 'ACTUATOR_POPULATION')
        measured = []
        for motor, joint, application, impulse in zip(motors, joints, applications, impulses):
            identity = joint['joint_id'] + '_motor'
            require(motor['actuator_id'] == application['actuator_id'] == impulse['actuator_id'] == identity, 'ACTUATOR_IDENTITY')
            target = motor['target_velocity_rad_s']
            require(application['controller_target_velocity_rad_s'] == target
                    and application['host_applied_target_velocity_rad_s'] == target
                    and application['host_additional_clamp_applied'] is False, 'COMMAND_LINK')
            realized = struct.unpack('<f', struct.pack('<f', target))[0]
            require(application['motor_target_velocity_readback_rad_s'] == realized, 'BINARY32_READBACK')
            cap = application['declared_maximum_impulse_nms']
            require(type(cap) in (int, float) and math.isfinite(cap) and cap > 0
                    and application['motor_maximum_impulse_readback_nms'] == cap, 'IMPULSE_CAP')
            applied = impulse['applied_angular_impulse_nms']
            require(type(applied) in (int, float) and math.isfinite(applied)
                    and abs(applied) <= cap + 1e-6, 'MEASURED_IMPULSE_BOUND')
            measured.append(dict(actuator_id=identity, precommand_position_rad=joint['position_rad'],
                precommand_velocity_rad_s=joint['velocity_rad_s'],
                target_position_error_rad=motor['clamped_target_position_rad'] - joint['position_rad'],
                requested_velocity_rad_s=target, realized_velocity_rad_s=realized,
                realized_velocity_quantization_error_rad_s=realized - target,
                post_solver_signed_impulse_nms=applied, published_impulse_cap_nms=cap,
                absolute_net_impulse_fraction_of_cap=abs(applied) / cap))
        loads = post['ordered_foot_bearing_observations']
        require(len(loads) == 4 and len({row['contact_site_id'] for row in loads}) == 4
                and all(row['source_measurement'] is True for row in loads), 'MEASURED_FOOT_POPULATION')
        feet = {row['contact_site_id']: row['bearing_normal_impulse_ns'] for row in loads}
        require(all(type(v) in (int, float) and math.isfinite(v) and v >= 0 for v in feet.values()), 'FOOT_LOAD_DOMAIN')
        rows.append(dict(stopping_command=index, walking_command=start + index,
            commanded_global_step=command['commanded_global_step'], joints=measured,
            post_solver_foot_normal_impulses_ns=feet))
    return rows


def summarize(rows):
    focus = [dict(stopping_command=row['stopping_command'], **row['joints'][5],
        rear_left_foot_normal_impulse_ns=row['post_solver_foot_normal_impulses_ns']['rear_left_foot'])
        for row in rows if 85 <= row['stopping_command'] <= 105]
    return dict(stop_commands=len(rows), motor_commands=sum(len(row['joints']) for row in rows),
        nonzero_requested_motor_commands=sum(j['requested_velocity_rad_s'] != 0 for row in rows for j in row['joints']),
        maximum_absolute_quantization_error_rad_s=max(abs(j['realized_velocity_quantization_error_rad_s']) for row in rows for j in row['joints']),
        maximum_recorded_net_impulse_fraction_of_cap=max(j['absolute_net_impulse_fraction_of_cap'] for row in rows for j in row['joints']),
        rear_left_knee_late_window_maximum_net_impulse_fraction_of_cap=max(row['absolute_net_impulse_fraction_of_cap'] for row in focus),
        rear_left_knee_late_window=focus,
        interpretation_limit='The retained net impulse is not a trace of every internal solver iteration. Readback agreement proves configuration, not the cause of motion. The selected late window is descriptive development diagnosis, not an acceptance window.',
        causal_attribution_proven=False, physical_acceptance_authority=False, release_authority=False)


def negative_controls(report):
    start = report['development_cycle_stop']['final_memory']['cycle_end_command']
    compact = dict(development_cycle_stop=dict(final_memory=copy.deepcopy(report['development_cycle_stop']['final_memory']),
        rows=[None] * start + report['development_cycle_stop']['rows'][start:]),
        development_walking_entry=dict(rows=[None] * start + report['development_walking_entry']['rows'][start:]))
    results = []
    for name in ['readback', 'cap', 'impulse_source', 'impulse_clock', 'motor_identity', 'foot_source']:
        value = copy.deepcopy(compact)
        command = value['development_walking_entry']['rows'][start + 93]
        post = value['development_cycle_stop']['rows'][start + 93]['post_native_source']['observation']
        if name == 'readback': command['ordered_motor_applications'][5]['motor_target_velocity_readback_rad_s'] += .1
        elif name == 'cap': command['ordered_motor_applications'][5]['motor_maximum_impulse_readback_nms'] *= 2
        elif name == 'impulse_source': post['applied_actuation']['source_measurement'] = False
        elif name == 'impulse_clock': post['applied_actuation']['source_semantic_step'] += 1
        elif name == 'motor_identity': post['applied_actuation']['ordered_applied_impulses'][5]['actuator_id'] = 'front_left_knee_motor'
        else: post['ordered_foot_bearing_observations'][2]['source_measurement'] = False
        try:
            analyze(value)
        except ValueError as error:
            results.append(dict(case=name, refused=True, error=str(error)))
        else:
            raise ValueError('R10M_STOP_MOTOR_CONTROL_ACCEPTED:' + name)
    return results


def audit():
    record = read(RECORD)
    verify(record['auditor'])
    closure = read(verify(record['pair_closure']))
    require(closure['status'] == 'valid_development_pair_no_kick_positive_kicked_settled_stop_negative', 'PARENT_OUTCOME')
    count = 0
    for item in record['reports']:
        report = read(verify(item['report']))
        role = report['arm_id']
        require(item['report'] in closure['retained_evidence'], 'PARENT_REPORT_BINDING')
        rows = analyze(report)
        require(rows == read(verify(item['measurements'])) and summarize(rows) == record['summaries'][role], 'MEASUREMENTS')
        count += sum(len(row['joints']) for row in rows)
        if role == 'kick_passive_recovery_resume':
            require(negative_controls(report) == record['negative_controls'], 'NEGATIVE_CONTROLS')
    require(count == 1920 and record['claim_boundary'] == dict(new_world_count=0, new_solver_step_count=0,
        causal_attribution_proven=False, physical_acceptance_authority=False, release_authority=False), 'CLAIMS')
    return dict(ok=True, stop_commands=240, motor_commands=count, negative_controls=6,
        new_world_count=0, new_solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(audit(), sort_keys=True))
