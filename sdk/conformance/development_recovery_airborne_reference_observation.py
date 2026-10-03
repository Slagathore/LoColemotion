"""Cold description of every saved airborne-reference command and contact loss.

No native calls, alternate rollout, new threshold, or replacement evaluation.
The existing original replay remains responsible for raw-response integrity and
upstream policy execution. This independently checks the target/rate selector.
"""
import argparse
import json
import math
from pathlib import Path

import development_recovery_feasible_support_observation as base
import development_recovery_v37_reference_diagnosis as algebra
from qsdk_r10f_physical_closure import canonical_number_text

POLICY = 'sporespore_balanced_wave_recovery_airborne_reference_v1'


def support_goals(pose, wave, dimensions):
    """Use the compiled hip-coordinate grouping at the full-extension branch.

    The older independent algebra factored span outside the anchor sum. Those
    real-number-equivalent expressions can straddle the exact reach branch in
    binary64. Preserve that historical helper; do not loosen its tolerances.
    """
    height, quat = pose
    upper, lower, radius, span = dimensions
    norm = math.sqrt(sum(v*v for v in quat))
    x, y, z, w = (v/norm for v in quat)
    forward, up, side = 2*(y*z-w*x), 1-2*(x*x+z*z), -2*(x*y+w*z)
    limbs, intervals = [], []
    for name, (angle, fraction, phase) in zip(algebra.geometry.LIMBS, wave['limbs']):
        # Native geometry stores these coordinates before projecting the pose.
        hip_x = (.2 if name.startswith('front') else -.2)*span
        hip_z = (-.18 if name.endswith('left') else .18)*span
        anchor = hip_x*forward + hip_z*side
        downward = up*math.cos(angle)-forward*math.sin(angle)
        beta = lambda k: math.atan2(lower*math.sin(k), upper+lower*math.cos(k))
        maximum_knee = 1.1
        if beta(maximum_knee) > angle+.72:
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
        limbs.append((angle, fraction, phase, anchor, downward))
    low, high = max(i[0] for i in intervals), min(i[1] for i in intervals)
    stance_height = min(height, high) if low <= high and height >= low else height
    result = []
    for angle, fraction, phase, anchor, downward in limbs:
        h = stance_height if phase > 72 else height
        requested_length = (h+anchor-radius)/downward
        length = algebra.clamp(requested_length, abs(upper-lower), upper+lower)
        knee = 0. if requested_length >= upper+lower else math.acos(algebra.clamp(
            (length*length-upper*upper-lower*lower)/(2*upper*lower), -1., 1.))
        knee = algebra.clamp(knee, 0., 1.1)
        hip = algebra.clamp(angle-math.atan2(lower*math.sin(knee), upper+lower*math.cos(knee)), -.72, .72)
        result.extend((hip*(1-fraction)+angle*fraction, knee+(1.1-knee)*fraction) if wave['active'] else (0., 0.))
    return result, (low, high, stance_height)


def command_audit(report):
    rows = report['development_walking_entry']['rows']
    session = next(s for s in report['retained_arm']['walking_sessions']
                   if s['evaluation_segment_id'] == 'walking_resume')
    assert session['start_receipt']['selected_policy_id'] == POLICY
    floor = session['start_receipt']['development_floor_source']
    assert floor['geometry']['model_instance_id'] == report['retained_arm']['model_instance_id']
    descriptor = report['configuration']['base_descriptor']
    upper = .35 * descriptor['upper_length_fraction']
    dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    count = selected_count = saturated = selected_saturated = lift_count = 0
    max_target_error = max_comparison_error = max_motor_error = 0.

    def wave(snapshot):
        return dict(active=snapshot['active'], limbs=[(p['nominal_leg_direction_rad'],
            p['walking_knee_fraction'], p['scheduled_phase_step']) for p in snapshot['ordered_limbs']])

    for local, row in enumerate(rows, 1):
        request, output = row['request'], row['native_output']
        state, memory = request['state'], request['memory']
        act = output['actuation']; receipt = act['receipt']['recovery_support_plane']
        assert act['receipt']['schema_version'] == 'sporespore_recovery_airborne_reference_controller_step_receipt_v1'
        assert receipt['reference_velocity_mode_id'] == 'contact_selected_airborne_reference_velocity_tracking_v1'
        assert receipt['swing_lift_mode_id'] == 'phase_only_existing_loaded_peak_swing_lift_v1'
        assert not receipt['all_limb_contact_claim']
        assert row['development_floor_source'] == floor
        assert request['floor_reference'] == receipt['floor_reference'] == floor['floor_reference']
        if local > 1:
            assert rows[local-2]['native_output']['next_memory'] == memory
        else:
            assert receipt['first_step_holds_neutral_reference']
        wr, ar = receipt['wave_velocity'], receipt['airborne_reference']
        assert memory['support_reference'].get('previous_wave') == wr['previous_wave']
        assert output['next_memory']['support_reference']['previous_wave'] == wr['current_wave']
        assert state['semantic_step'] == ar['source_semantic_step']
        # Reuse the existing number policy for Godot's parsed timestamp only.
        assert canonical_number_text(float(state['sample_time_s'])) == canonical_number_text(float(ar['source_sample_time_s']))
        assert state['adapter_capability_sha256'] == ar['source_adapter_capability_sha256']
        pose, current = algebra.inputs(row)
        assert current == wave(wr['current_wave'])
        previous = wave(wr['previous_wave']) if wr['previous_wave'] is not None else None
        active = previous is not None and previous['active'] and current['active']
        assert active == wr['feedforward_active']
        commands = act['ordered_commands']
        caps = [c['maximum_target_speed_rad_s'] for c in commands]
        refs = memory['support_reference']['ordered_target_positions_rad']
        dt = receipt['reference_step_duration_s']
        goals, (lo, hi, target_height) = support_goals(pose, current, dimensions)
        actual = algebra.bounded_targets(goals, refs, caps, dt)
        comparison = algebra.bounded_targets(support_goals(pose, previous, dimensions)[0], refs, caps, dt) if active else actual
        plan = receipt['feasible_support_plan']
        for expected, key in ((lo, 'common_minimum_torso_height_m'), (hi, 'common_maximum_torso_height_m'),
                              (target_height, 'requested_stance_torso_height_m')):
            assert abs(expected-plan[key]) < 1e-12
        assert (lo <= hi) == plan['common_height_interval_nonempty']
        assert len(commands) == len(receipt['ordered_reference_velocity_rad_s']) == len(ar['ordered_full_reference_velocity_rad_s']) == 8
        assert len(ar['ordered_limbs']) == len(receipt['ordered_limb_proposals']) == 4
        for proposal in receipt['ordered_limb_proposals']:
            phase = proposal['scheduled_phase_step']
            expected = request['command']['gait_amplitude'] * (.82*1.75+.4) * math.sin(math.pi*phase/72)/1.1 if phase < 72 else 0.
            assert abs(expected-proposal['walking_knee_fraction']) <= 1e-14
            assert abs(proposal['support_reference_torso_height_m']-(target_height if phase > 72 else pose[0])) < 1e-12
            lift_count += 1
        for i, command in enumerate(commands):
            cap, target = caps[i], command['requested_target_position_rad']
            contact = state['ordered_contact_observations'][i//2]
            limb = wr['current_wave']['ordered_limbs'][i//2]; phase = limb['scheduled_phase_step']
            selected = active and dt > 0 and 0 <= phase <= 72 and contact['presence'] is False and contact['bears_support'] is False
            assert ar['ordered_limbs'][i//2] == dict(limb_id=limb['limb_id'], scheduled_phase_step=phase,
                full_reference_rate_selected=selected, precommand_contact=contact)
            bounds = (-.72, .72) if i % 2 == 0 else (0., 1.1)
            assert bounds[0] <= target <= bounds[1]
            assert target == command['clamped_target_position_rad']
            assert abs(target-refs[i]) <= cap*dt+1e-14
            target_error = abs(actual[i]-target)
            comparison_error = abs(comparison[i]-wr['ordered_comparison_reference_rad'][i])
            assert target_error < 1e-12 and comparison_error < 1e-12
            full = algebra.clamp((target-refs[i])/dt, -cap, cap) if dt > 0 else 0.
            fallback = algebra.clamp((target-comparison[i])/dt, -cap, cap) if active and dt > 0 else 0.
            rate = full if selected else fallback
            assert abs(full-ar['ordered_full_reference_velocity_rad_s'][i]) < 1e-10
            assert abs(rate-receipt['ordered_reference_velocity_rad_s'][i]) < 1e-10
            assert abs(receipt['ordered_reference_velocity_rad_s'][i]) <= cap
            joint = state['ordered_joint_observations'][i]
            raw = 8.*(target-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
            motor_error = abs(-algebra.clamp(raw, -cap, cap)-command['target_velocity_rad_s'])
            assert motor_error < 1e-10
            assert (abs(raw) > cap) == command['velocity_saturated']
            assert abs(command['target_velocity_rad_s']) <= cap
            assert command['residual_contribution_rad_s'] == 0.
            if local <= 2:
                assert rate == 0. and not selected
            count += 1; selected_count += selected; saturated += command['velocity_saturated']
            selected_saturated += selected and command['velocity_saturated']
            max_target_error = max(max_target_error, target_error)
            max_comparison_error = max(max_comparison_error, comparison_error)
            max_motor_error = max(max_motor_error, motor_error)
    return dict(command_count=len(rows), joint_commands=count, lift_goals=lift_count,
        selected_joint_commands=selected_count, fallback_joint_commands=count-selected_count,
        saturated_joint_commands=saturated, selected_saturated_joint_commands=selected_saturated,
        fallback_saturated_joint_commands=saturated-selected_saturated,
        maximum_target_error_rad=max_target_error, maximum_comparison_error_rad=max_comparison_error,
        maximum_motor_error_rad_s=max_motor_error,
        arithmetic_allowances='Existing V38 cold arithmetic allowances only; no behavioral threshold changes.')


def contact_timing(report):
    rows = report['development_walking_entry']['rows']
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    trace = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id') == session['session_id']]
    assert len(rows) == len(trace)
    per_limb = []
    for limb in session['start_receipt']['initial_gait_steps']:
        phases = [next(p['scheduled_phase_step'] for p in r['native_output']['actuation']['receipt']
            ['recovery_support_plane']['ordered_limb_proposals'] if p['limb_id'] == limb) for r in rows]
        losses, windows = [], []
        # Entry four-foot support is verified by the original replay and cold closure.
        bearing, release = True, None
        for local, measured in enumerate(trace, 1):
            present = measured['contact_by_limb'][limb]
            if bearing and not present:
                release = dict(liftoff_local_step=local, requested_phase_at_liftoff=phases[local-1],
                    touchdown_local_step=None, open_at_end=True)
                losses.append(release)
            elif not bearing and present:
                assert release is not None
                release.update(touchdown_local_step=local, open_at_end=False)
            bearing = present
            if phases[local-1] < 72:
                if not windows or windows[-1]['last_command'] != local-1:
                    windows.append(dict(first_command=local, last_command=local))
                else:
                    windows[-1]['last_command'] = local
        for window in windows:
            end = window['last_command']
            window['followed_by_landing_phase'] = end < len(rows) and phases[end] == 72
            window['open_at_end'] = end == len(rows)
        per_limb.append(dict(limb=limb, scheduled_swing_windows=windows, contact_losses=losses,
            terminal_contact=bearing, terminal_requested_phase=phases[-1],
            terminal_requested_activity='swing' if phases[-1] < 72 else 'landing' if phases[-1] == 72 else 'stance'))
    amplitudes = [r['request']['command']['gait_amplitude'] for r in rows]
    losses = [event for limb in per_limb for event in limb['contact_losses']]
    return dict(per_limb=per_limb, contact_loss_count=len(losses),
        contact_losses_starting_in_scheduled_stance=sum(e['requested_phase_at_liftoff'] > 72 for e in losses),
        initial_gait_amplitude=amplitudes[0], terminal_gait_amplitude=amplitudes[-1],
        maximum_gait_amplitude=max(amplitudes),
        amplitude_decrease_command_count=sum(b < a for a, b in zip(amplitudes, amplitudes[1:])),
        terminal_still_requests_maximum_walking_amplitude=amplitudes[-1] == max(amplitudes) and amplitudes[-1] > 0.,
        limits='Every loss is retained, including short and open flights. Planned phase windows are not proof of successful steps. Scheduled stance loss is not a causal diagnosis. No terminal failure is removed.')


def observe(path):
    result = base.observe(path)
    report = json.loads(Path(result['source_report']['path']).read_bytes())
    result['schema_version'] = 'sporespore_development_airborne_reference_observation_v1'
    result['command_audit'] = command_audit(report)
    result['contact_timing'] = contact_timing(report)
    result['additional_analysis_sources'] = [dict(path=p, raw_sha256=base.digest(Path(p).read_bytes())) for p in (
        'sdk/conformance/development_recovery_airborne_reference_observation.py',
        'sdk/conformance/development_recovery_v37_reference_diagnosis.py',
        'sdk/conformance/qsdk_r10f_physical_closure.py')]
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('closure', type=Path)
    print(json.dumps(observe(parser.parse_args().closure), indent=2, allow_nan=False))
