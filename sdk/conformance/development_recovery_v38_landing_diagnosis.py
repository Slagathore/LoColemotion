"""Full retained V38 landing/stance diagnosis; no native calls or new trajectory.

Command n consumes the retained pre-command trace n-1. Its post-command foot
contact is available at trace n; the terminal next body input is not invented.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess

import development_recovery_feasible_support_observation as observation
import development_recovery_v33_support_tracking_diagnosis as tracking

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
ATTEMPT = 'db53de264ab04bc29157f8a1524e73d0'
SOURCE = '4931509b055fa0cc79012a6a3e1b868e23d02888'
CLOSURE_SHA = 'sha256:d0988c97ab0ec59be9bc3dcb1a9865104222a7322c2cb025530ee1f69d9534f7'
REPORT_SHA = 'sha256:81161ab308fe3ad1c33574dcc5d61b83de0a6a2ec8ca2cd71e10bf98892440f2'
POLICY = 'sporespore_balanced_wave_recovery_wave_velocity_v1'
ANALYSIS_PATHS = ('sdk/conformance/development_recovery_v38_landing_diagnosis.py',
    'sdk/conformance/development_recovery_feasible_support_observation.py',
    'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py',
    'sdk/conformance/development_recovery_v28_contact_geometry.py',
    'sdk/conformance/development_recovery_v32_placement_diagnosis.py')
digest = observation.digest


def proposed_rate(active, phase, presence, bearing, target, previous, dt, cap, wave_rate):
    """Unregistered V39 sketch: full reference rate only in absent-contact swing/landing.

No fitted gains or time window. Current scheduled phase 0..72 is the existing
swing/landing range; both native contact booleans must explicitly be false.
"""
    if (any(type(v) is not bool for v in (active, presence, bearing))
            or not isinstance(phase, (int, float)) or not math.isfinite(phase)
            or phase != int(phase) or not 0 <= phase < 360
            or not all(math.isfinite(v) for v in (target, previous, dt, cap, wave_rate))
            or dt < 0 or cap <= 0 or abs(wave_rate) > cap):
        raise ValueError('V38_LANDING_PROPOSAL_DOMAIN')
    selected = active and phase <= 72 and not presence and not bearing and dt > 0
    rate = max(-cap, min(cap, (target-previous)/dt)) if selected else wave_rate
    return selected, rate


def summarize(report):
    if report['source_commit'] != SOURCE:
        raise ValueError('V38_LANDING_SOURCE_CROSSED')
    original = observation.summarize(report)
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    assert session['start_receipt']['selected_policy_id'] == POLICY
    floor = session['start_receipt']['development_floor_source']['floor_reference']
    assert floor['height_world_m'] == 0.  # Explicit frozen fixture, not a guessed runtime floor.
    rows, entries, native, bodies, dimensions, frame_error = tracking.samples(report)
    trace = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id') == session['session_id']]
    assert len(entries) == len(trace) == 400 and len(rows) == 1600
    by_key = {(r['limb'], r['command_local']): r for r in rows}
    timeline, losses, motors = [], [], []
    velocity_error = 0.
    for n, e in entries.items():
        request, output = e['request'], e['native_output']
        receipt = output['actuation']['receipt']['recovery_support_plane']
        assert receipt['reference_velocity_mode_id'] == 'bounded_pose_separated_wave_velocity_tracking_v1'
        assert trace[n-1]['walking_session_local_step'] == n
        if n > 1:
            assert entries[n-1]['native_output']['next_memory'] == request['memory']
        for i, p in enumerate(receipt['ordered_limb_proposals']):
            limb = p['limb_id']; row = by_key[limb, n]
            phase = p['scheduled_phase_step']
            assert phase == row['command_phase']
            pre = native[n-1]['precommand_trace']['contact_by_limb'][limb]
            post = trace[n-1]['contact_by_limb'][limb]
            contact = next(c for c in request['state']['ordered_contact_observations'] if c['contact_site_id'] == limb+'_foot')
            assert contact['presence'] == contact['bears_support'] == pre == row['native_contact']
            if pre and not post:
                losses.append(dict(command_local=n, limb=limb, applied_phase=phase,
                    scheduled_stance=phase > 72, precommand_nominal_bottom_m=row['nominal_actual_bottom_m']))
            before = next(m for m in request['memory']['ordered_limb_memory'] if m['limb_id'] == limb)
            after = next(m for m in output['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)
            gate_delta = after['recontact_hold_step_count']-before['recontact_hold_step_count']
            sync_delta = after['phase_sync_hold_step_count']-before['phase_sync_hold_step_count']
            assert gate_delta in (0, 1) and sync_delta in (0, 1)
            pair = []
            for j in (2*i, 2*i+1):
                command = output['actuation']['ordered_commands'][j]
                joint = request['state']['ordered_joint_observations'][j]
                cap, target = command['maximum_target_speed_rad_s'], command['requested_target_position_rad']
                previous = request['memory']['support_reference']['ordered_target_positions_rad'][j]
                rate = receipt['ordered_reference_velocity_rad_s'][j]
                feedback = 8*(target-joint['position_rad'])-.65*joint['velocity_rad_s']
                actual_raw = feedback+1.65*rate
                actual = -max(-cap, min(cap, actual_raw))
                velocity_error = max(velocity_error, abs(actual-command['target_velocity_rad_s']))
                assert (abs(actual_raw) > cap) == command['velocity_saturated']
                selected, candidate_rate = proposed_rate(receipt['wave_velocity']['feedforward_active'],
                    phase, contact['presence'], contact['bears_support'], target, previous,
                    receipt['reference_step_duration_s'], cap, rate)
                proposed_raw = feedback+1.65*candidate_rate
                proposed = -max(-cap, min(cap, proposed_raw))
                motor = dict(command_local=n, limb=limb, joint=joint['joint_id'], selected=selected,
                    current_velocity=actual, proposed_velocity=proposed, current_rate=rate,
                    proposed_rate=candidate_rate, original_saturated=command['velocity_saturated'],
                    proposed_saturated=abs(proposed_raw) > cap, cap=cap,
                    changed=abs(proposed-actual) > 1e-12)
                motors.append(motor); pair.append(motor)
            timeline.append(dict(command_local=n, limb=limb, measured_trace_local=n-1,
                phase=phase, prior_applied_phase=row['applied_phase'], pre_contact=pre, post_contact=post,
                raw_contact_count=row['raw_contact_count'], gate_hold_delta=gate_delta, sync_hold_delta=sync_delta,
                measured_joint_rad=row['measured_joint_rad'], preceding_reference_rad=row['preceding_reference_rad'],
                current_reference_rad=row['current_reference_rad'], goal_joint_rad=row['goal_joint_rad'],
                nominal_actual_bottom_m=row['nominal_actual_bottom_m'],
                ideal_measured_bottom_m=row['ideal_measured_bottom_m'],
                ideal_current_reference_bottom_m=row['ideal_current_reference_bottom_m'],
                ideal_goal_bottom_m=row['ideal_goal_bottom_m'],
                body_height_m=row['body_height_m'], support_reference_height_m=p['support_reference_torso_height_m'],
                common_height_interval_nonempty=receipt['feasible_support_plan']['common_height_interval_nonempty'],
                link_reach_projection_required=p['link_reach_projection_required'],
                joint_projection_required=p['support_joint_projection_required'], motors=pair))
    if velocity_error > 1e-12:
        raise ValueError('V38_LANDING_MOTOR_RECONSTRUCTION')
    per_limb = []
    for limb in tracking.geometry.LIMBS:
        selected = [r for r in timeline if r['limb'] == limb]
        holds = [r for r in selected if r['gate_hold_delta']]
        stance = [r for r in selected if r['phase'] > 72]
        per_limb.append(dict(limb=limb, recontact_hold_commands=len(holds),
            recontact_hold_no_raw_contact_commands=sum(r['raw_contact_count'] == 0 for r in holds),
            recontact_hold_saturated_commands=sum(m['original_saturated'] for r in holds for m in r['motors']),
            recontact_hold_joint_slew_limited_commands=sum(abs(a-b) > 1e-12 for r in holds for a,b in zip(r['current_reference_rad'],r['goal_joint_rad'])),
            hold_geometry={k: tracking.spread(r[k] for r in holds) if holds else None for k in
                ('nominal_actual_bottom_m','ideal_current_reference_bottom_m','ideal_goal_bottom_m')},
            phase_sync_hold_commands=sum(r['sync_hold_delta'] for r in selected),
            phase_sync_hold_during_rear_right_landing=sum(r['sync_hold_delta'] for r in selected if 166 <= r['command_local'] <= 255),
            stance_missing_contact_commands=sum(not r['pre_contact'] for r in stance),
            stance_unreachable_goal_commands=sum(r['link_reach_projection_required'] for r in stance),
            maximum_stance_goal_bottom_m=max(r['ideal_goal_bottom_m'] for r in stance),
            contact_loss_commands=[r['command_local'] for r in losses if r['limb'] == limb]))
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    cycles = [dict(limb=p['limb'], **c, decomposition=tracking.decompose(p['limb'],c['liftoff_local_step'],
        c['touchdown_local_step'],native,bodies,dimensions,axis)) for p in original['per_limb'] for c in p['contact_cycles']]
    return dict(command_count=400, limb_command_count=len(timeline), joint_command_count=len(motors),
        original_walking_evaluation=session['evaluation'], original_per_limb_cycles=original['per_limb'],
        original_contact_cycles=cycles, all_contact_losses=losses, per_limb=per_limb,
        coordinate_conversion_maximum_axis_difference=frame_error, maximum_motor_velocity_error_rad_s=velocity_error,
        original_saturated_commands=sum(m['original_saturated'] for m in motors),
        prospective_airborne_reference_sketch=dict(selected_joint_commands=sum(m['selected'] for m in motors),
            changed_joint_commands=sum(m['changed'] for m in motors),
            velocity_saturated_commands=sum(m['proposed_saturated'] for m in motors),
            all_unselected_velocities_exact=all(m['current_velocity'] == m['proposed_velocity'] for m in motors if not m['selected']),
            all_rates_and_velocities_inside_existing_caps=all(abs(m['proposed_rate']) <= m['cap'] and abs(m['proposed_velocity']) <= m['cap'] for m in motors),
            native_component_implemented=False, alternate_physical_trajectory_evaluated=False),
        all_limb_command_timeline=timeline)


def observe():
    path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw = path.read_bytes()
    if digest(raw) != CLOSURE_SHA:
        raise ValueError('V38_LANDING_CLOSURE_DRIFT')
    closure = json.loads(raw); report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if digest(report_raw) != REPORT_SHA or closure['kicked_report']['raw_sha256'] != REPORT_SHA or closure['source_snapshot']['head'] != SOURCE:
        raise ValueError('V38_LANDING_REPORT_DRIFT')
    return dict(schema_version='sporespore_development_v38_landing_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw)),source_report=closure['kicked_report'],
        frozen_sources=[dict(path=p,source_commit=SOURCE,raw_sha256=digest(subprocess.check_output(['git','show',SOURCE+':'+p],cwd=ROOT))) for p in
            ('sdk/core/src/runtime.rs','sdk/core/src/recovery_support_plane.rs','sdk/core/src/recovery_feasible_support.rs')],
        analysis_sources=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw)),
        selection_rule='Every retained resumed command, all four limbs and every original dwell-qualified cycle. Illustrative landing interval 166-255 is the original rear-right recontact hold, not a tuned controller condition.',
        limits='Canonical/native quaternion frame residuals are retained. Ideal kinematics omit constraint compliance; nominal capsule bottom is not a contact predicate. Endpoint decomposition is descriptive and order-dependent, not isolated causation. No trace-400 next body pose is invented. The proposed branch uses only existing active-wave state, phase and explicit absent-contact booleans, never time-window membership or measured outcome success. Unreachable stance geometry remains a separate risk; the sketch does not fix or predict it.',
        original_evaluation_changed=False,physical_cause_proven=False,alternate_physical_outcome_predicted=False,
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def compact(full, output):
    diagnosis = {k:v for k,v in full['diagnosis'].items() if k != 'all_limb_command_timeline'}
    raw = output.read_bytes()
    return dict(full,diagnosis=diagnosis,complete_diagnosis=dict(path=output.as_posix(),byte_length=len(raw),raw_sha256=digest(raw)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    output = parser.parse_args().output.resolve()
    if not output.is_relative_to(EVIDENCE.resolve()):
        raise ValueError('V38_LANDING_DURABLE_OUTPUT_REQUIRED')
    full = observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False); stream.write('\n')
    print(json.dumps(compact(full,output),indent=2,allow_nan=False))
