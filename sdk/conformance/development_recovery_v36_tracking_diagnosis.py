"""V36 retained landing/servo diagnosis; no native call or alternate rollout.

Command n reads trace n-1. Post-command joint response is available only for
commands 1..399. All original cycles and all recontact-counter increments are
included; nominal capsule geometry never replaces the native contact signal.
"""
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

import development_recovery_feasible_support_observation as observation
import development_recovery_v28_contact_geometry as geometry
from development_recovery_v33_support_tracking_diagnosis import decompose, spread

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '9959c99703944cbd80789ac00ed2d90c'
SOURCE = '77988eefde092a3ff0d618803b998d7f169ce7ba'
CLOSURE_SHA = 'sha256:950aa372d1f15d72b92245c2f3ce472d51289356fbc823759fbdd021772c6777'
REPORT_SHA = 'sha256:f290ce47e93023459a042d56ecfc253ef48e17a43c5675290ebb2a1ed5761a71'
POLICY = 'sporespore_balanced_wave_recovery_smooth_swing_v1'
ANALYSIS_PATHS = ('sdk/conformance/development_recovery_v36_tracking_diagnosis.py',
    'sdk/conformance/development_recovery_feasible_support_observation.py',
    'sdk/conformance/development_recovery_v28_contact_geometry.py',
    'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py')


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def frozen_constants():
    path = 'sdk/core/src/runtime.rs'
    raw = subprocess.check_output(['git', 'show', SOURCE + ':' + path], cwd=ROOT)
    values = dict(MOTOR_POSITION_GAIN_PER_S=8., MOTOR_RATE_DAMPING=.65,
                  CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S=3.5, MOTOR_DIRECTION_SIGN=-1.)
    for name, expected in values.items():
        match = re.search(r'const ' + name + r': [^=]+ = (-?[0-9.]+);', raw.decode())
        if match is None or float(match[1]) != expected:
            raise ValueError('V36_FROZEN_SERVO_CONSTANTS')
    return values, dict(path=path, source_commit=SOURCE, raw_sha256=digest(raw))


def bounded_reference_velocity(target, previous_target, dt, maximum_speed):
    """Prospective finite difference of the already bounded position reference.

    This is algebra on saved inputs, not a controller implementation or a
    prediction of new physical motion. Clamp division roundoff to the old cap.
    """
    if not all(math.isfinite(v) for v in (target, previous_target, dt, maximum_speed)) or dt < 0 or maximum_speed <= 0:
        raise ValueError('V36_REFERENCE_VELOCITY_DOMAIN')
    if dt == 0:
        if target != previous_target:
            raise ValueError('V36_REFERENCE_MOVED_WITHOUT_TIME')
        return 0.
    return max(-maximum_speed, min(maximum_speed, (target - previous_target) / dt))


def sample_rows(report, constants):
    if report['source_commit'] != SOURCE:
        raise ValueError('V36_TRACKING_SOURCE_CROSSED')
    entries = report['development_walking_entry']['rows']
    assert len(entries) == 400
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    assert session['start_receipt']['selected_policy_id'] == POLICY
    original = observation.summarize(report)
    reconstructed, frame_error = geometry.reconstruct(report)
    bodies = {(r['limb'], r['trace_local_step']): r for r in reconstructed}
    native = {int(r['session_local_step']) - 1: r['native_source'] for r in
              report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume'}
    descriptor = report['configuration']['base_descriptor']
    upper = .35 * descriptor['upper_length_fraction']
    dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    gain, damping, sign = (constants[k] for k in ('MOTOR_POSITION_GAIN_PER_S', 'MOTOR_RATE_DAMPING', 'MOTOR_DIRECTION_SIGN'))
    samples, motors = [], []
    for n, entry in enumerate(entries, 1):
        request, output = entry['request'], entry['native_output']
        receipt = output['actuation']['receipt']['recovery_support_plane']
        assert receipt['swing_lift_mode_id'] == 'phase_only_existing_loaded_peak_swing_lift_v1'
        torso = native[n-1]['observation']['state']['base_pose_world']
        floor_y = request['floor_reference']['height_world_m']
        before = {m['limb_id']: m for m in request['memory']['ordered_limb_memory']}
        after = {m['limb_id']: m for m in output['next_memory']['ordered_limb_memory']}
        for index, command in enumerate(output['actuation']['ordered_commands']):
            joint = request['state']['ordered_joint_observations'][index]
            target = command['requested_target_position_rad']
            previous = request['memory']['support_reference']['ordered_target_positions_rad'][index]
            cap = command['maximum_target_speed_rad_s']
            rate = bounded_reference_velocity(target, previous, receipt['reference_step_duration_s'], cap)
            feedback = gain*(target-joint['position_rad']) - damping*joint['velocity_rad_s']
            old_velocity = max(-cap, min(cap, feedback))
            # A velocity-output servo needs unity feedforward as well as damping
            # relative to the reference rate: v_ref + Kp*e - Kd*(v-v_ref).
            proposed = feedback + (1+damping)*rate
            proposed_bounded = max(-cap, min(cap, proposed))
            response = entries[n]['request']['state']['ordered_joint_observations'][index] if n < 400 else None
            motors.append(dict(command_local=n, actuator=command['actuator_id'],
                existing_velocity_reconstruction_error_rad_s=abs(sign*old_velocity-command['target_velocity_rad_s']),
                reference_rate_rad_s=rate, existing_speed_cap_rad_s=cap,
                proposed_geometric_velocity_rad_s=proposed_bounded,
                proposed_command_changed=proposed_bounded != old_velocity,
                proposed_velocity_saturated=abs(proposed)>cap,
                existing_velocity_saturated=command['velocity_saturated'],
                position_response_error_rad=response['position_rad']-target if response else None,
                motor_velocity_response_error_rad_s=response['velocity_rad_s']-sign*command['target_velocity_rad_s'] if response else None))
        for index, proposal in enumerate(receipt['ordered_limb_proposals']):
            limb = proposal['limb_id']; body = bodies[limb, n-1]
            assert limb == geometry.LIMBS[index]
            target = [c['requested_target_position_rad'] for c in output['actuation']['ordered_commands'][2*index:2*index+2]]
            previous_target = ([c['requested_target_position_rad'] for c in entries[n-2]['native_output']['actuation']['ordered_commands'][2*index:2*index+2]] if n > 1 else None)
            hold_increment = after[limb]['recontact_hold_step_count'] - before[limb]['recontact_hold_step_count']
            assert hold_increment in (0, 1)
            goal = [proposal['goal_hip_rad'], proposal['goal_knee_rad']]
            samples.append(dict(command_local=n, measured_trace_local=n-1, limb=limb,
                scheduled_phase=proposal['scheduled_phase_step'], recontact_counter_increment=hold_increment,
                native_support=body['support'], raw_contact_count=body['raw_contact_count'],
                link_reach_projection_required=proposal['link_reach_projection_required'],
                joint_projection_required=proposal['support_joint_projection_required'],
                nominal_actual_clearance_m=body['nominal_capsule_bottom_m']-floor_y,
                ideal_goal_clearance_m=geometry.ideal_distal(torso, limb, *goal, *dimensions)[1]-floor_y,
                ideal_current_reference_clearance_m=geometry.ideal_distal(torso, limb, *target, *dimensions)[1]-floor_y,
                ideal_preceding_reference_clearance_m=geometry.ideal_distal(torso, limb, *previous_target, *dimensions)[1]-floor_y if previous_target else None,
                hip_response_error_rad=body['hip_rad']-previous_target[0] if previous_target else None,
                knee_response_error_rad=body['knee_rad']-previous_target[1] if previous_target else None,
                requested_stance_lowering_m=receipt['feasible_support_plan']['requested_lowering_m'],
                measured_torso_height_m=torso['position_m']['y']-floor_y,
                measured_joint_rad=[body['hip_rad'], body['knee_rad']], goal_joint_rad=goal,
                reference_joint_rad=target))
    assert max(r['existing_velocity_reconstruction_error_rad_s'] for r in motors) < 1e-14
    return original, samples, motors, native, bodies, dimensions, frame_error, session


def summarize(report, constants):
    original, samples, motors, native, bodies, dimensions, frame_error, session = sample_rows(report, constants)
    episodes, stance = [], []
    for limb in geometry.LIMBS:
        selected = [r for r in samples if r['limb'] == limb]
        groups = []
        for row in selected:
            if row['recontact_counter_increment']:
                if not groups or groups[-1][-1]['command_local'] != row['command_local']-1:
                    groups.append([])
                groups[-1].append(row)
        for group in groups:
            episodes.append(dict(limb=limb, first_command=group[0]['command_local'], last_command=group[-1]['command_local'],
                count=len(group), first_sample=group[0], last_sample=group[-1],
                link_reach_projection_count=sum(r['link_reach_projection_required'] for r in group),
                joint_projection_count=sum(r['joint_projection_required'] for r in group),
                raw_contact_sample_count=sum(r['raw_contact_count'] for r in group),
                native_support_sample_count=sum(r['native_support'] for r in group),
                **{k: spread(r[k] for r in group) for k in ('nominal_actual_clearance_m', 'ideal_goal_clearance_m',
                    'ideal_preceding_reference_clearance_m', 'hip_response_error_rad', 'knee_response_error_rad')}))
        selected = [r for r in selected if r['scheduled_phase'] > 72]
        stance.append(dict(limb=limb, command_count=len(selected), missing_precommand_native_support_count=sum(not r['native_support'] for r in selected),
            raw_contact_sample_count=sum(r['raw_contact_count'] for r in selected),
            nominal_actual_clearance_m=spread(r['nominal_actual_clearance_m'] for r in selected),
            ideal_goal_clearance_m=spread(r['ideal_goal_clearance_m'] for r in selected)))
    cycles = []
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    for limb in original['per_limb']:
        for cycle in limb['contact_cycles']:
            cycles.append(dict(limb=limb['limb'], **cycle,
                decomposition=decompose(limb['limb'], cycle['liftoff_local_step'], cycle['touchdown_local_step'], native, bodies, dimensions, axis)))
    joints = []
    for actuator in dict.fromkeys(m['actuator'] for m in motors):
        selected = [m for m in motors if m['actuator'] == actuator]
        response = [m for m in selected if m['position_response_error_rad'] is not None]
        joints.append(dict(actuator=actuator, position_response_error_rad=spread(m['position_response_error_rad'] for m in response),
            motor_velocity_response_error_rad_s=spread(m['motor_velocity_response_error_rad_s'] for m in response),
            reference_rate_rad_s=spread(m['reference_rate_rad_s'] for m in selected),
            proposed_command_changed_count=sum(m['proposed_command_changed'] for m in selected),
            proposed_velocity_saturated_count=sum(m['proposed_velocity_saturated'] for m in selected)))
    return dict(command_count=400, precommand_limb_sample_count=len(samples), command_joint_count=len(motors),
        postcommand_joint_response_count=sum(m['position_response_error_rad'] is not None for m in motors),
        coordinate_conversion_maximum_axis_difference=frame_error, landing_episodes=episodes,
        scheduled_stance=stance, original_contact_cycles=cycles, original_walking_evaluation=session['evaluation'],
        per_joint=joints, existing_velocity_law_reconstruction_maximum_error_rad_s=max(m['existing_velocity_reconstruction_error_rad_s'] for m in motors),
        prospective_reference_velocity_sketch=dict(input_command_count=3200,
            changed_from_reconstructed_baseline_count=sum(m['proposed_command_changed'] for m in motors),
            unchanged_first_command_count=sum(not m['proposed_command_changed'] for m in motors if m['command_local']==1),
            existing_velocity_saturated_count=sum(m['existing_velocity_saturated'] for m in motors),
            proposed_velocity_saturated_count=sum(m['proposed_velocity_saturated'] for m in motors),
            all_proposed_velocities_inside_existing_caps=all(abs(m['proposed_geometric_velocity_rad_s']) <= m['existing_speed_cap_rad_s'] for m in motors),
            coefficient_derivation='1 + existing MOTOR_RATE_DAMPING = 1.65; no fitted gain or outcome-derived threshold.',
            old_law='u = Kp*(q_ref-q) - Kd*q_dot; u is geometric angular velocity before motor sign.',
            proposed_law='u = q_ref_dot + Kp*(q_ref-q) - Kd*(q_dot-q_ref_dot), then the unchanged speed clamp and motor sign.',
            reference_rate='Bounded finite difference of the existing slewed position references using their saved sample-time interval; zero on the first command.',
            ideal_velocity_servo_argument='If physical q_dot=u and no clamp is active, the old moving-reference error obeys e_dot=q_ref_dot-Kp*e/(1+Kd); the proposed law removes that reference-rate term. This idealized algebra is not a model of the full native constrained system.',
            native_component_implemented=False, alternate_physical_trajectory_evaluated=False))


def observe():
    path = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json')
    raw = path.read_bytes()
    if digest(raw) != CLOSURE_SHA:
        raise ValueError('V36_TRACKING_CLOSURE_DRIFT')
    closure = json.loads(raw); report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if closure['source_snapshot']['head'] != SOURCE or digest(report_raw) != REPORT_SHA or closure['kicked_report']['raw_sha256'] != REPORT_SHA:
        raise ValueError('V36_TRACKING_REPORT_DRIFT')
    constants, frozen = frozen_constants()
    return dict(schema_version='sporespore_development_v36_landing_tracking_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(), raw_sha256=digest(raw)), source_report=closure['kicked_report'],
        frozen_servo_constants=constants, frozen_runtime_source=frozen,
        analysis_sources=[dict(path=p, raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw), constants),
        selection_rule='All 400 resumed commands, all 3200 joint commands, every native recontact-counter increment, every scheduled stance input and every original dwell-qualified contact cycle.',
        limits='Reachability is nominal fixed-pose geometry, not native contact truth. Joint tracking and body motion are both retained; no unique physical cause is proved. Decomposition is ordered algebra, not isolated causation. Post-command pose for command 400 is absent and never invented. Proposed commands on saved states are not another trajectory.',
        original_evaluation_changed=False, physical_cause_proven=False, alternate_physical_outcome_predicted=False,
        native_controller_call_count=0, new_world_build_count=0, new_solver_step_count=0, new_native_physics_read_count=0,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
