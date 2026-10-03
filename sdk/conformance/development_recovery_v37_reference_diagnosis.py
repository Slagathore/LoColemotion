"""V37 saved-input reference decomposition, not a native alternate trajectory.

All 400 commands are included. Decompose each slewed reference increment into
catch-up to the preceding goal, activation, upstream wave changes, and measured
pose changes. Retain reverse-order attribution because clamps are nonlinear.
The wave inputs include upstream steering; they are NOT pure phase derivatives.
"""
import hashlib
import json
import math
from pathlib import Path
import subprocess

import development_recovery_feasible_support_observation as observation
import development_recovery_v28_contact_geometry as geometry
from development_recovery_v33_support_tracking_diagnosis import spread, decompose

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '8ceafcfb9d5c4439859aee7f959e2740'
SOURCE = '6cb28e642186bf60052a57b6875925716a2522b5'
CLOSURE_SHA = 'sha256:8ab9f404dbdeaae05b447181b0b061ad85f625963ea59db634c82300ad47c4a1'
REPORT_SHA = 'sha256:48c60a515f08c47100d28603763cf7dd2f3e049d44153703ad7436bccebe3440'
POLICY = 'sporespore_balanced_wave_recovery_reference_velocity_v1'
ANALYSIS_PATHS = ('sdk/conformance/development_recovery_v37_reference_diagnosis.py',
    'sdk/conformance/development_recovery_feasible_support_observation.py',
    'sdk/conformance/development_recovery_v28_contact_geometry.py',
    'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py',
    'sdk/conformance/development_recovery_v32_placement_diagnosis.py')


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def clamp(value, lo, hi):
    return max(lo, min(hi, value))


def goals(pose, wave, dimensions):
    """Independent reconstruction of the frozen support/height/goal algebra.

    Pose is the canonical observation quaternion plus explicit floor-relative
    height. Wave contains the retained upstream direction, knee fraction and
    phase; this function neither runs nor reconstructs upstream steering.
    """
    height, quat = pose
    upper, lower, radius, span = dimensions
    x, y, z, w = quat
    norm = math.sqrt(sum(v*v for v in quat))
    if not all(math.isfinite(v) for v in (height, *quat, *dimensions)) or norm == 0 or min(dimensions) <= 0:
        raise ValueError('V37_REFERENCE_POSE_DOMAIN')
    if type(wave['active']) is not bool or len(wave['limbs']) != 4:
        raise ValueError('V37_REFERENCE_WAVE_DOMAIN')
    x, y, z, w = (v/norm for v in quat)
    forward, up, side = 2*(y*z-w*x), 1-2*(x*x+z*z), -2*(x*y+w*z)
    rows, intervals = [], []
    for limb, (angle, fraction, phase) in zip(geometry.LIMBS, wave['limbs']):
        if not all(math.isfinite(v) for v in (angle, fraction, phase)) or not (-.72 <= angle <= .72 and 0 <= fraction <= 1 and 0 <= phase < 360):
            raise ValueError('V37_REFERENCE_WAVE_DOMAIN')
        anchor = span*((.2 if limb.startswith('front') else -.2)*forward
            + (-.18 if limb.endswith('left') else .18)*side)
        downward = up*math.cos(angle)-forward*math.sin(angle)
        if not 0 < downward <= 1:
            raise ValueError('V37_REFERENCE_DIRECTION_DOMAIN')
        beta = lambda k: math.atan2(lower*math.sin(k), upper+lower*math.cos(k))
        maximum_knee = 1.1
        if beta(maximum_knee) > angle + .72:
            lo, hi = 0., maximum_knee
            for _ in range(64):
                mid = (lo+hi)*.5
                if beta(mid) <= angle+.72:
                    lo = mid
                else:
                    hi = mid
            maximum_knee = lo
        minimum_length = math.sqrt((upper+lower*math.cos(maximum_knee))**2+(lower*math.sin(maximum_knee))**2)
        intervals.append((radius-anchor+minimum_length*downward, radius-anchor+(upper+lower)*downward))
        rows.append((angle, fraction, phase, anchor, downward))
    low, high = max(v[0] for v in intervals), min(v[1] for v in intervals)
    stance_height = min(height, high) if low <= high and height >= low else height
    result = []
    for angle, fraction, phase, anchor, downward in rows:
        h = stance_height if phase > 72 else height
        requested_length = (h+anchor-radius)/downward
        length = clamp(requested_length, abs(upper-lower), upper+lower)
        knee = 0. if requested_length >= upper+lower else math.acos(clamp((length*length-upper*upper-lower*lower)/(2*upper*lower), -1., 1.))
        knee = clamp(knee, 0., 1.1)
        hip = clamp(angle-math.atan2(lower*math.sin(knee), upper+lower*math.cos(knee)), -.72, .72)
        result.extend((hip*(1-fraction)+angle*fraction, knee+(1.1-knee)*fraction) if wave['active'] else (0., 0.))
    return result, (low, high, stance_height)


def bounded_targets(goal, previous, caps, dt):
    if (not math.isfinite(dt) or dt < 0 or len(goal) != len(previous) or len(caps) != len(goal)
            or not all(math.isfinite(v) for v in (*goal,*previous,*caps)) or any(v<=0 for v in caps)):
        raise ValueError('V37_REFERENCE_SLEW_DOMAIN')
    return [old+clamp(g-old, -cap*dt, cap*dt) for g, old, cap in zip(goal, previous, caps)]


def split_rates(prior_pose, pose, prior_wave, wave, dimensions, previous, caps, dt):
    """Ordered algebra, not causal intervention in a physical simulation."""
    active_prior_wave = dict(prior_wave, active=wave['active'])
    states = ((prior_pose, prior_wave), (prior_pose, active_prior_wave),
              (prior_pose, wave), (pose, wave), (pose, active_prior_wave))
    targets = [bounded_targets(goals(p, w, dimensions)[0], previous, caps, dt) for p, w in states]
    before, activated, waved, actual, posed_first = targets
    if dt == 0:
        return [dict(catch_up=0., activation=0., wave=0., pose=0., pose_first=0., wave_last=0., total=0.) for _ in previous]
    return [dict(catch_up=(before[i]-old)/dt, activation=(activated[i]-before[i])/dt,
        wave=(waved[i]-activated[i])/dt, pose=(actual[i]-waved[i])/dt,
        pose_first=(posed_first[i]-activated[i])/dt, wave_last=(actual[i]-posed_first[i])/dt,
        total=(actual[i]-old)/dt) for i, old in enumerate(previous)]


def proposed_wave_rates(pose, prior_wave, wave, dimensions, previous, caps, dt):
    """V38 sketch: same current pose and slew origin for BOTH wave snapshots.

    No feedforward on initialization or zero/nonzero activation changes. Static
    wave inputs give exactly zero even while body pose or reference lag changes.
    This is saved-input arithmetic, not a registered native controller.
    """
    if prior_wave is None or not prior_wave['active'] or not wave['active'] or dt == 0:
        return [0.]*len(previous)
    old = bounded_targets(goals(pose, prior_wave, dimensions)[0], previous, caps, dt)
    new = bounded_targets(goals(pose, wave, dimensions)[0], previous, caps, dt)
    return [clamp((n-o)/dt,-cap,cap) for n,o,cap in zip(new,old,caps)]


def inputs(entry):
    request = entry['request']; state = request['state']
    p = entry['native_output']['actuation']['receipt']['recovery_support_plane']
    return (state['base_pose_world']['position_m']['y']-request['floor_reference']['height_world_m'],
        tuple(state['base_pose_world']['orientation_xyzw'][k] for k in 'xyzw')), dict(
        active=request['command']['gait_amplitude'] != 0., limbs=[(q['nominal_leg_direction_rad'],
            q['walking_knee_fraction'], q['scheduled_phase_step']) for q in p['ordered_limb_proposals']])


def summarize(report):
    if report['source_commit'] != SOURCE:
        raise ValueError('V37_REFERENCE_SOURCE_CROSSED')
    entries = report['development_walking_entry']['rows']
    original = observation.summarize(report)  # Includes floor/time/cycle checks.
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
    assert session['start_receipt']['selected_policy_id'] == POLICY
    trace = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id')==session['session_id']]
    assert len(entries) == len(trace) == 400
    descriptor = report['configuration']['base_descriptor']
    upper = .35*descriptor['upper_length_fraction']
    dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    native = {int(r['session_local_step'])-1:r['native_source'] for r in report['development_native_walking_contacts']['rows'] if r['segment_id']=='walking_resume'}
    measured, frame_error = geometry.reconstruct(report)
    bodies = {(r['limb'],r['trace_local_step']):r for r in measured}
    origin = native[0]['precommand_trace']['torso_position_world_m']
    motors, timeline, losses = [], [], []
    goal_error = interval_error = velocity_error = decomposition_error = 0.
    for local, (entry, post) in enumerate(zip(entries, trace), 1):
        request, output = entry['request'], entry['native_output']
        receipt = output['actuation']['receipt']['recovery_support_plane']
        assert receipt['reference_velocity_mode_id']=='bounded_slewed_reference_velocity_tracking_v1'
        pose, wave = inputs(entry)
        prior_pose, prior_wave = inputs(entries[local-2]) if local > 1 else (pose, wave)
        reconstructed, heights = goals(pose, wave, dimensions)
        saved_goals = [p[k] for p in receipt['ordered_limb_proposals'] for k in ('goal_hip_rad','goal_knee_rad')]
        goal_error = max(goal_error, max(abs(a-b) for a,b in zip(reconstructed, saved_goals)))
        plan = receipt['feasible_support_plan']
        saved_heights = [plan[k] for k in ('common_minimum_torso_height_m','common_maximum_torso_height_m','requested_stance_torso_height_m')]
        interval_error = max(interval_error, max(abs(a-b) for a,b in zip(heights, saved_heights)))
        commands = output['actuation']['ordered_commands']
        previous = request['memory']['support_reference']['ordered_target_positions_rad']
        caps = [c['maximum_target_speed_rad_s'] for c in commands]
        dt = receipt['reference_step_duration_s']
        parts = split_rates(prior_pose, pose, prior_wave, wave, dimensions, previous, caps, dt)
        proposed_rates = proposed_wave_rates(pose, prior_wave if local>1 else None, wave, dimensions, previous, caps, dt)
        pre = native[local-1]['precommand_trace']
        for limb, (_, _, phase) in zip(geometry.LIMBS, wave['limbs']):
            if pre['contact_by_limb'][limb] and not post['contact_by_limb'][limb]:
                losses.append(dict(command_local=local, limb=limb, scheduled_phase=phase,
                    scheduled_stance=phase>72, measured_precommand_clearance_m=bodies[limb,local-1]['nominal_capsule_bottom_m']-request['floor_reference']['height_world_m']))
        for index, (command, part) in enumerate(zip(commands, parts)):
            joint = request['state']['ordered_joint_observations'][index]
            saved_rate = receipt['ordered_reference_velocity_rad_s'][index]
            feedback = 8*(command['requested_target_position_rad']-joint['position_rad'])-.65*joint['velocity_rad_s']
            raw = feedback+1.65*saved_rate
            proposed_raw = feedback+1.65*proposed_rates[index]
            velocity_error = max(velocity_error, abs(-clamp(raw,-caps[index],caps[index])-command['target_velocity_rad_s']))
            decomposition_error = max(decomposition_error, abs(part['total']-saved_rate),
                abs(part['total']-sum(part[k] for k in ('catch_up','activation','wave','pose'))),
                abs(part['total']-sum(part[k] for k in ('catch_up','activation','pose_first','wave_last'))))
            motors.append(dict(local=local, actuator=command['actuator_id'], phase=wave['limbs'][index//2][2],
                parts=part, feedback=feedback, feedforward=1.65*saved_rate,
                saturated=command['velocity_saturated'], cap=caps[index],
                feedforward_reverses_feedback=raw*feedback < 0,
                measured_velocity_rad_s=joint['velocity_rad_s'],
                reference_error_rad=command['requested_target_position_rad']-joint['position_rad']))
            motors[-1].update(proposed_reference_rate_rad_s=proposed_rates[index],
                proposed_velocity_saturated=abs(proposed_raw)>caps[index],
                proposed_motor_velocity_rad_s=-clamp(proposed_raw,-caps[index],caps[index]),
                proposed_motor_changed=abs(-clamp(proposed_raw,-caps[index],caps[index])-command['target_velocity_rad_s'])>1e-12)
        forward = sum((post['torso_position_world_m'][i]-origin[i])*axis[i] for i in range(3))
        timeline.append([local, forward, post['torso_tilt_rad'], post['torso_position_world_m'][1],
            ''.join('1' if post['contact_by_limb'][limb] else '0' for limb in geometry.LIMBS),
            plan['common_height_interval_nonempty'], sum(c['velocity_saturated'] for c in commands),
            *[sum(abs(p[k]) for p in parts) for k in ('catch_up','activation','wave','pose','pose_first','wave_last')]])
    if max(goal_error,interval_error) > 1e-12 or velocity_error > 1e-12 or decomposition_error > 1e-10:
        raise ValueError('V37_REFERENCE_RECONSTRUCTION')
    groups = []
    for label, selected in [('all',motors),('activation', [m for m in motors if m['local']==2]),
                           ('after_activation',[m for m in motors if m['local']>2]),
                           ('scheduled_stance_after_activation',[m for m in motors if m['local']>2 and m['phase']>72])]:
        groups.append(dict(group=label, count=len(selected), velocity_saturated_count=sum(m['saturated'] for m in selected),
            feedforward_reverses_feedback_count=sum(m['feedforward_reverses_feedback'] for m in selected),
            reference_rate_components={k:spread(m['parts'][k] for m in selected) for k in ('catch_up','activation','wave','pose','pose_first','wave_last','total')},
            feedforward_magnitude_exceeds_feedback_count=sum(abs(m['feedforward'])>abs(m['feedback']) for m in selected)))
    cycles = [dict(limb=row['limb'], **cycle, decomposition=decompose(row['limb'],cycle['liftoff_local_step'],
        cycle['touchdown_local_step'],native,bodies,dimensions,axis)) for row in original['per_limb'] for cycle in row['contact_cycles']]
    return dict(command_count=400, joint_command_count=len(motors), original_walking_evaluation=session['evaluation'],
        maximum_goal_error_rad=goal_error, maximum_height_interval_error_m=interval_error,
        maximum_motor_velocity_error_rad_s=velocity_error, maximum_rate_decomposition_error_rad_s=decomposition_error,
        coordinate_conversion_maximum_axis_difference=frame_error, rate_groups=groups,
        per_joint=[dict(actuator=a, reference_error_rad=spread(m['reference_error_rad'] for m in motors if m['actuator']==a),
            saturated_count=sum(m['saturated'] for m in motors if m['actuator']==a)) for a in dict.fromkeys(m['actuator'] for m in motors)],
        initial_eight_commands=motors[:64], all_contact_losses=losses, original_contact_cycles=cycles,
        first_empty_height_interval_command=next((t[0] for t in timeline if not t[5]),None),
        first_original_tilt_failure_command=next((t[0] for t in timeline if t[2]>session['evaluation']['fixed_thresholds']['maximum_tilt_rad']),None),
        prospective_wave_rate_sketch=dict(joint_commands=len(motors),
            changed_command_count_above_arithmetic_allowance=sum(m['proposed_motor_changed'] for m in motors),
            command_comparison_allowance_rad_s=1e-12,
            velocity_saturated_count=sum(m['proposed_velocity_saturated'] for m in motors),
            unchanged_initial_command_count=sum(not m['proposed_motor_changed'] for m in motors if m['local']==1),
            activation_reference_rate_zero_count=sum(m['proposed_reference_rate_rad_s']==0. for m in motors if m['local']==2),
            activation_velocity_saturated_count=sum(m['proposed_velocity_saturated'] for m in motors if m['local']==2),
            all_rates_and_velocities_inside_existing_caps=all(abs(m['proposed_reference_rate_rad_s'])<=m['cap'] and abs(m['proposed_motor_velocity_rad_s'])<=m['cap'] for m in motors),
            native_component_implemented=False,alternate_physical_trajectory_evaluated=False),
        timeline_columns=['command_local','forward_from_entry_m','postcommand_tilt_rad','postcommand_torso_y_m',
            'postcommand_contacts_FL_FR_RL_RR','common_height_interval_nonempty','saturated_joint_count',
            'catch_up_rate_L1_rad_s','activation_rate_L1_rad_s','wave_first_rate_L1_rad_s','pose_last_rate_L1_rad_s',
            'pose_first_rate_L1_rad_s','wave_last_rate_L1_rad_s'], all_command_timeline=timeline)


def observe():
    path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw = path.read_bytes()
    if digest(raw) != CLOSURE_SHA:
        raise ValueError('V37_REFERENCE_CLOSURE_DRIFT')
    closure = json.loads(raw); report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if digest(report_raw) != REPORT_SHA or closure['kicked_report']['raw_sha256'] != REPORT_SHA or closure['source_snapshot']['head'] != SOURCE:
        raise ValueError('V37_REFERENCE_REPORT_DRIFT')
    frozen = []
    for p in ('sdk/core/src/recovery_support_plane.rs','sdk/core/src/recovery_feasible_support.rs','sdk/core/src/runtime.rs'):
        source = subprocess.check_output(['git','show',SOURCE+':'+p],cwd=ROOT)
        frozen.append(dict(path=p,source_commit=SOURCE,raw_sha256=digest(source)))
    return dict(schema_version='sporespore_development_v37_reference_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw)), source_report=closure['kicked_report'],
        frozen_sources=frozen, analysis_sources=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw)),
        selection_rule='All 400 resumed commands, all 3200 joint commands, every true-to-false native contact transition and every original dwell-qualified contact cycle.',
        decomposition_rule='At the same preceding position reference, current dt and current speed cap, telescope the bounded target through prior goal, activation, new upstream wave inputs, then new measured pose. Also retain pose-first/wave-last attribution; nonlinear clamps make attribution order-dependent.',
        limits='Saved-input algebra is not an alternative physical trajectory. Wave inputs include upstream steering feedback as well as phase and amplitude; they are not a pure planned-phase derivative. Activation is the zero-to-nonzero amplitude branch, not a fitted interval. Component magnitudes can cancel and are not causal percentages. Nominal geometry is not native contact truth. Original terminal evaluation is unchanged. No unrecorded next input is invented.',
        original_evaluation_changed=False,physical_cause_proven=False,alternate_physical_outcome_predicted=False,
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    print(json.dumps(observe(),indent=2,allow_nan=False))
