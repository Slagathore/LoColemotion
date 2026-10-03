"""Reconstruct R10L's static-stop feedback; hypothetical clipping is not physics."""
import json
from pathlib import Path
from v52_extended_support_transfer import ROOT, read, binding, verify

RECORD = ROOT / 'sdk/recovery/r10l_stop_velocity_diagnosis_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('R10L_STOP_VELOCITY_' + code)


def analyze(report):
    start = report['development_cycle_stop']['final_memory']['cycle_end_command']
    rows = report['development_walking_entry']['rows'][start:]
    require(len(rows) == 120, 'STOP_POPULATION')
    first = rows[0]['native_output']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
    observations = []
    for n, row in enumerate(rows, 1):
        require(row['session_local_step'] == start + n and row['development_cycle_stopping'] is True,
                'STOP_CLOCK')
        command = row['request']['command']
        require(command['gait_amplitude'] == 0, 'ZERO_AMPLITUDE')
        plane = row['native_output']['actuation']['receipt']['recovery_support_plane']
        require(all(rate == 0 for rate in plane['ordered_reference_velocity_rad_s']), 'ZERO_REFERENCE_RATE')
        pose = plane['anchored_body_pose']
        require(all(pose[key] == first[key] for key in ['desired_body_position_world_m',
                'ordered_foot_targets_world_m', 'ordered_joint_goals_rad']), 'STATIC_TARGETS')
        actuators = row['native_output']['actuation']['ordered_commands']
        measured = row['request']['state']['ordered_joint_observations']
        require(len(actuators) == len(measured) == 8, 'JOINT_POPULATION')
        joints = []
        for motor, joint in zip(actuators, measured):
            require(motor['actuator_id'] == joint['joint_id'] + '_motor', 'JOINT_IDENTITY')
            error = motor['clamped_target_position_rad'] - joint['position_rad']
            raw = 8.0 * error - 0.65 * joint['velocity_rad_s']
            limit = motor['maximum_target_speed_rad_s']
            expected = -max(-limit, min(limit, raw))
            require(abs(expected - motor['target_velocity_rad_s']) < 1e-12, 'FEEDBACK_RECONSTRUCTION')
            proposed = max(-min(limit, .25), min(min(limit, .25), expected))
            joints.append(dict(actuator_id=motor['actuator_id'], position_error_rad=error,
                measured_velocity_rad_s=joint['velocity_rad_s'], original_velocity_rad_s=expected,
                hypothetical_velocity_rad_s=proposed, clipped=proposed != expected))
        observations.append(dict(stopping_command=n, walking_command=start+n, joints=joints))
    affected = [r['stopping_command'] for r in observations if any(j['clipped'] for j in r['joints'])]
    return dict(static_targets=True, zero_reference_velocity=True, controller_gain_per_s=8.0,
        measured_velocity_damping=.65, proposed_zero_amplitude_velocity_limit_rad_s=.25,
        maximum_original_velocity_rad_s=max(abs(j['original_velocity_rad_s']) for r in observations for j in r['joints']),
        affected_stopping_commands=affected, commands=observations,
        changed_measurements_simulated=False, causal_attribution_proven=False,
        new_world_count=0, new_solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def audit():
    r = read(RECORD)
    for key in ['auditor', 'pair_closure']:
        verify(r[key])
    for item in r['reports']:
        report = read(verify(item))
        require(analyze(report) == r['observations'][report['arm_id']], 'OBSERVATIONS')
    require(r['observations']['matched_no_kick_continuation']['affected_stopping_commands'] == [], 'NO_KICK')
    require(r['observations']['kick_passive_recovery_resume']['affected_stopping_commands'] == [94,95,96], 'KICKED')
    return dict(ok=True, original_stop_commands=240, original_feedback_commands=1920,
        hypothetical_affected_kicked_commands=[94,95,96], new_world_count=0, new_solver_step_count=0)


if __name__ == '__main__':
    print(json.dumps(audit(), sort_keys=True))
