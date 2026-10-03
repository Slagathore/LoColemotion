"""Cold V40 command/contact description. No native execution or regrading.

This distinct selector audit preserves the frozen V39 audit and its source
fingerprints. Shared geometry, full-population contact timing and the original
walking evaluator remain unchanged; only the declared V40 identity/selection
is audited here.
"""
import argparse
import json
import math
from pathlib import Path

import development_recovery_airborne_reference_observation as parent
from qsdk_r10f_physical_closure import canonical_number_text

base = parent.base
algebra = parent.algebra
support_goals = parent.support_goals
POLICY = 'sporespore_balanced_wave_recovery_absent_contact_reference_v1'


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
    selected_stance_count = selected_stance_saturated = 0
    max_target_error = max_comparison_error = max_motor_error = 0.

    def wave(snapshot):
        return dict(active=snapshot['active'], limbs=[(p['nominal_leg_direction_rad'],
            p['walking_knee_fraction'], p['scheduled_phase_step']) for p in snapshot['ordered_limbs']])

    for local, row in enumerate(rows, 1):
        request, output = row['request'], row['native_output']
        state, memory = request['state'], request['memory']
        act = output['actuation']; receipt = act['receipt']['recovery_support_plane']
        assert act['receipt']['schema_version'] == 'sporespore_recovery_absent_contact_reference_controller_step_receipt_v1'
        assert receipt['reference_velocity_mode_id'] == 'contact_selected_absent_contact_reference_velocity_tracking_v1'
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
            selected = active and dt > 0 and 0 <= phase < 360 and contact['presence'] is False and contact['bears_support'] is False
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
            selected_stance_count += selected and phase > 72
            selected_stance_saturated += selected and phase > 72 and command['velocity_saturated']
            max_target_error = max(max_target_error, target_error)
            max_comparison_error = max(max_comparison_error, comparison_error)
            max_motor_error = max(max_motor_error, motor_error)
    return dict(command_count=len(rows), joint_commands=count, lift_goals=lift_count,
        selected_joint_commands=selected_count, fallback_joint_commands=count-selected_count,
        selected_stance_joint_commands=selected_stance_count,
        selected_stance_saturated_joint_commands=selected_stance_saturated,
        saturated_joint_commands=saturated, selected_saturated_joint_commands=selected_saturated,
        fallback_saturated_joint_commands=saturated-selected_saturated,
        maximum_target_error_rad=max_target_error, maximum_comparison_error_rad=max_comparison_error,
        maximum_motor_error_rad_s=max_motor_error,
        arithmetic_allowances='Existing V38 cold arithmetic allowances only; no behavioral threshold changes.')


def observe(path):
    result = base.observe(path)
    report = json.loads(Path(result['source_report']['path']).read_bytes())
    result['schema_version'] = 'sporespore_development_absent_contact_reference_observation_v1'
    result['command_audit'] = command_audit(report)
    result['contact_timing'] = parent.contact_timing(report)
    result['additional_analysis_sources'] = [dict(path=p, raw_sha256=base.digest(Path(p).read_bytes())) for p in (
        'sdk/conformance/development_recovery_absent_contact_reference_observation.py',
        'sdk/conformance/development_recovery_airborne_reference_observation.py',
        'sdk/conformance/development_recovery_v37_reference_diagnosis.py',
        'sdk/conformance/qsdk_r10f_physical_closure.py')]
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('closure', type=Path)
    print(json.dumps(observe(parser.parse_args().closure), indent=2, allow_nan=False))
