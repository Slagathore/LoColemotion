"""V35 retained step diagnosis; no native call, new world, or alternate rollout.

Command n reads trace n-1. Contact transitions are compared at adjacent inputs;
the effect of changing only the lift formula is algebra, not a physical result.
All original dwell-qualified cycles and all 400 commands are included.
"""
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

import development_recovery_feasible_support_observation as observation
import development_recovery_v28_contact_geometry as geometry
from development_recovery_v33_support_tracking_diagnosis import decompose, spread

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '2d88c07d2ae0497a8fe9bc1fb60832e5'
SOURCE = '6a14d37a0d6d187a3453ad687534d9b004162eb1'
CLOSURE_SHA = 'sha256:882e958b97d9d44e7ba992dd32dd0baeebb09e5331bd12d0855b610a3801fe5a'
REPORT_SHA = 'sha256:1fc36eecd5b662e532aef2d8a66c99f515fe914830d4ddf197b29ff1995f3eb6'
ANALYSIS_PATHS = (
    'sdk/conformance/development_recovery_v35_step_diagnosis.py',
    'sdk/conformance/development_recovery_feasible_support_observation.py',
    'sdk/conformance/development_recovery_v28_contact_geometry.py',
    'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py',
)


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def frozen_coefficients():
    # Read the observed source, never infer its constants from a newer runtime.
    path = 'sdk/core/src/runtime.rs'
    raw = subprocess.check_output(['git', 'show', SOURCE + ':' + path], cwd=ROOT)
    expected = dict(SWING_STEPS=72, KNEE_SWING_FLEXION_RAD=.82,
                    KNEE_FLEXION_SCALE=1.75, CONTACT_CLEARANCE_ASSIST_RAD=.4)
    for name, value in expected.items():
        match = re.search(r'const ' + name + r': [^=]+ = ([0-9.]+);', raw.decode())
        if match is None or float(match[1]) != value:
            raise ValueError('V35_FROZEN_LIFT_COEFFICIENTS')
    return dict(path=path, source_commit=SOURCE, raw_sha256=digest(raw)), expected


def smooth_lift(amplitude, phase, coefficients):
    """Prospective phase-only proposal; existing loaded peak, zero endpoints.

    This is NOT a registered controller and does not apply commands. A new
    native candidate must reproduce it before an authorized fresh experiment.
    """
    peak = (coefficients['KNEE_SWING_FLEXION_RAD'] * coefficients['KNEE_FLEXION_SCALE']
            + coefficients['CONTACT_CLEARANCE_ASSIST_RAD'])
    duration = coefficients['SWING_STEPS']
    if (not math.isfinite(amplitude) or not math.isfinite(phase)
            or amplitude < 0 or not 0 <= phase < 360):
        raise ValueError('V35_PROPOSED_LIFT_DOMAIN')
    return amplitude * peak * math.sin(math.pi * phase / duration) if phase < duration else 0.


def summarize(report, coefficients):
    if report['source_commit'] != SOURCE:
        raise ValueError('V35_STEP_SOURCE_CROSSED')
    entries = report['development_walking_entry']['rows']
    assert len(entries) == 400
    original = observation.summarize(report)  # Rechecks alignment, floor and original cycle totals.
    measured, frame_error = geometry.reconstruct(report)
    bodies = {(r['limb'], r['trace_local_step']): r for r in measured}
    native = {int(r['session_local_step'])-1: r['native_source'] for r in
              report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume'}
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    descriptor = report['configuration']['base_descriptor']
    upper = .35 * descriptor['upper_length_fraction']
    dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    duration = coefficients['SWING_STEPS']
    base = coefficients['KNEE_SWING_FLEXION_RAD'] * coefficients['KNEE_FLEXION_SCALE']
    assist = coefficients['CONTACT_CLEARANCE_ASSIST_RAD']
    # Existing bound, independently checked against every saved command.
    knee_max = 1.1
    rows, conflicts, toggles = {}, [], []
    fraction_errors, proposal_values = [], []
    for local, entry in enumerate(entries, 1):
        receipt = entry['native_output']['actuation']['receipt']['recovery_support_plane']
        plan = receipt['feasible_support_plan']
        floor = entry['request']['floor_reference']['height_world_m']
        torso = native[local-1]['observation']['state']['base_pose_world']
        amplitude = entry['request']['command']['gait_amplitude']
        assert 0 <= amplitude <= knee_max/(base+assist)
        contacts = {c['contact_site_id'].removesuffix('_foot'): c['bears_support']
                    for c in entry['request']['state']['ordered_contact_observations']}
        phases = {p['limb_id']: p['scheduled_phase_step'] for p in receipt['ordered_limb_proposals']}
        for i, proposal in enumerate(receipt['ordered_limb_proposals']):
            limb = proposal['limb_id']
            phase = phases[limb]
            assert limb == geometry.LIMBS[i] and phase == int(phase)
            expected = amplitude*(base*math.sin(math.pi*phase/duration) + (assist if contacts[limb] else 0.)) if phase < duration else 0.
            fraction_errors.append(abs(proposal['walking_knee_fraction'] - expected/knee_max))
            assert fraction_errors[-1] <= 1e-14  # Arithmetic cross-check, not a contact tolerance.
            proposed = smooth_lift(amplitude, phase, coefficients)
            assert 0. <= proposed <= knee_max
            proposal_values.append(proposed)
            command = entry['native_output']['actuation']['ordered_commands'][2*i+1]
            assert 0 <= command['requested_target_position_rad'] <= knee_max
            row = dict(command_local=local, measured_trace_local=local-1, limb=limb,
                phase=phase, amplitude=amplitude, native_contact=contacts[limb],
                walking_knee_fraction=proposal['walking_knee_fraction'],
                goal_knee_rad=proposal['goal_knee_rad'],
                reference_knee_rad=command['requested_target_position_rad'],
                ideal_goal_floor_clearance_m=geometry.ideal_distal(torso, limb,
                    proposal['goal_hip_rad'], proposal['goal_knee_rad'], *dimensions)[1]-floor,
                requested_lowering_participant=limb in plan['ordered_lowering_participant_limb_ids'],
                nominal_measured_floor_clearance_m=bodies[limb, local-1]['nominal_capsule_bottom_m']-floor,
                raw_native_contact_count=bodies[limb, local-1]['raw_contact_count'])
            rows[limb, local] = row
            before = rows.get((limb, local-1))
            if (before and before['phase'] < duration and phase < duration
                    and before['native_contact'] != contacts[limb]):
                # Exact same-input branch sensitivity isolates the formula;
                # observed adjacent rows also differ in pose, phase and amplitude.
                jump = (knee_max-proposal['projected_support_knee_rad']) * amplitude*assist/knee_max
                toggles.append(dict(limb=limb, input_command_local=local,
                    contact_before=before['native_contact'], contact_after=contacts[limb],
                    phase_before=before['phase'], phase_after=phase,
                    amplitude_before=before['amplitude'], amplitude_after=amplitude,
                    walking_knee_fraction_before=before['walking_knee_fraction'],
                    walking_knee_fraction_after=row['walking_knee_fraction'],
                    observed_goal_knee_change_rad=row['goal_knee_rad']-before['goal_knee_rad'],
                    observed_reference_knee_change_rad=row['reference_knee_rad']-before['reference_knee_rad'],
                    same_input_loaded_minus_unloaded_goal_knee_rad=jump,
                    proposed_same_input_contact_only_lift_difference_rad=0.))
        intervals = plan['ordered_limb_intervals']
        lo = max(intervals, key=lambda x: x['minimum_torso_height_m'])
        hi = min(intervals, key=lambda x: x['maximum_torso_height_m'])
        assert lo['minimum_torso_height_m'] == plan['common_minimum_torso_height_m']
        assert hi['maximum_torso_height_m'] == plan['common_maximum_torso_height_m']
        if not plan['common_height_interval_nonempty']:
            stance = [x for x in intervals if phases[x['limb_id']] > duration]
            assert stance
            stance_gap = max(x['minimum_torso_height_m'] for x in stance)-min(x['maximum_torso_height_m'] for x in stance)
            conflicts.append(dict(command_local=local, minimum_limiting_limb=lo['limb_id'],
                maximum_limiting_limb=hi['limb_id'], minimum_limiter_phase=phases[lo['limb_id']],
                maximum_limiter_phase=phases[hi['limb_id']],
                interval_gap_m=lo['minimum_torso_height_m']-hi['maximum_torso_height_m'],
                measured_height_below_common_minimum=plan['measured_torso_height_m']<lo['minimum_torso_height_m'],
                stance_only_interval_nonempty=stance_gap <= 0, stance_only_signed_gap_m=stance_gap))
    cycles = []
    for item in original['per_limb']:
        limb = item['limb']
        for cycle in item['contact_cycles']:
            a, b = cycle['liftoff_local_step'], cycle['touchdown_local_step']
            # Goals of commands a..b-1; measured airborne poses trace a..b-1.
            commands = [rows[limb, n] for n in range(a, b)]
            responses = [rows[limb, n+1] for n in range(a, b)]
            cycles.append(dict(limb=limb, **cycle,
                applied_command_first=a, applied_command_last=b-1,
                measured_airborne_trace_first=a, measured_airborne_trace_last=b-1,
                lowering_participant_command_count=sum(r['requested_lowering_participant'] for r in commands),
                applied_goal_at_precommand_pose_floor_clearance_m=spread(r['ideal_goal_floor_clearance_m'] for r in commands),
                measured_airborne_floor_clearance_m=spread(r['nominal_measured_floor_clearance_m'] for r in responses),
                raw_native_contact_samples_during_airborne=sum(r['raw_native_contact_count'] for r in responses),
                decomposition=decompose(limb, a, b, native, bodies, dimensions, axis)))
    return dict(command_count=len(entries), limb_command_count=len(rows),
        measured_body_sample_count=len(measured), coordinate_axis_maximum_difference=frame_error,
        existing_lift_fraction_reconstruction_maximum_error=max(fraction_errors),
        prospective_phase_only_lift_on_saved_inputs_rad=spread(proposal_values),
        prospective_lift_peak_rule='amplitude * (0.82 * 1.75 + 0.40); existing peak and amplitude cap',
        contact_transitions_during_swing=toggles, all_original_contact_cycles=cycles,
        empty_height_intervals=conflicts,
        empty_height_intervals_summary=dict(count=len(conflicts),
            limiting_limb_pairs=[list(pair) for pair in sorted({(c['minimum_limiting_limb'], c['maximum_limiting_limb']) for c in conflicts})],
            interval_gap_m=spread(c['interval_gap_m'] for c in conflicts),
            stance_only_nonempty_count=sum(c['stance_only_interval_nonempty'] for c in conflicts),
            stance_only_still_empty_count=sum(not c['stance_only_interval_nonempty'] for c in conflicts),
            measured_height_below_common_minimum_count=sum(c['measured_height_below_common_minimum'] for c in conflicts)),
        original_walking_evaluation=session['evaluation'])


def observe():
    path = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT+'.json')
    raw = path.read_bytes()
    if digest(raw) != CLOSURE_SHA:
        raise ValueError('V35_STEP_CLOSURE_DRIFT')
    closure = json.loads(raw)
    source = closure['kicked_report']
    report_raw = Path(source['path']).read_bytes()
    if (digest(report_raw) != source['raw_sha256'] or source['raw_sha256'] != REPORT_SHA
            or len(report_raw) != source['byte_length']):
        raise ValueError('V35_STEP_REPORT_DRIFT')
    runtime, coefficients = frozen_coefficients()
    return dict(schema_version='sporespore_development_v35_step_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(), raw_sha256=CLOSURE_SHA),
        source_report=source, frozen_runtime_source=runtime, frozen_lift_coefficients=coefficients,
        analysis_source_bindings=[dict(path=p, raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        selection_rule='All 400 commands, all 1600 precommand limb samples, every original dwell-qualified cycle, every within-swing input contact toggle, and every empty height interval.',
        diagnosis=summarize(json.loads(report_raw), coefficients),
        limits='Forward decomposition is ordered translation, rotation with initial joints, then joint change at final pose, with ideal-constraint residual. It is not unique causal attribution. Nominal capsule clearance is not a native contact predicate. Same-input lift algebra is not an alternate trajectory; the scheduler and motor limits still depend on native contact. Removing swinging limbs from a saved height intersection does not predict another physical result. No trace-400 joint/body sample is invented.',
        new_world_build_count=0, new_solver_step_count=0, new_native_physics_read_count=0,
        native_controller_call_count=0, original_evaluation_changed=False, physical_cause_proven=False,
        alternative_physical_outcome_predicted=False, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
