"""Complete saved V39 stance diagnosis and non-native lost-contact rate sketch.

Command n consumes trace n-1. Original contacts/evaluation remain authoritative;
ideal geometry, velocity derivatives and the sketch are not physical outcomes.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import subprocess

import development_recovery_airborne_reference_observation as cold
import development_recovery_v33_support_tracking_diagnosis as tracking

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent/'SporeSpore_Evidence'
ATTEMPT = '681e45b2b4784caba4018cac4e6c2b61'
SOURCE = '529682476a3865aa928368bd73f6a96e28e2cacb'
CLOSURE_SHA = 'sha256:514c9331dd7117890a2f83141d9b88cbca83ffd431dceb92b28c2618a591f185'
REPORT_SHA = 'sha256:65c27b92134702e1af871a899e6cec5be796cad5ebc30b42ff81f87e6a8db612'
digest = cold.base.digest
ANALYSIS_PATHS = (
    'sdk/conformance/development_recovery_absent_stance_diagnosis.py',
    'sdk/conformance/development_recovery_airborne_reference_observation.py',
    'sdk/conformance/development_recovery_feasible_support_observation.py',
    'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py',
    'sdk/conformance/development_recovery_v37_reference_diagnosis.py',
    'sdk/conformance/development_recovery_v28_contact_geometry.py',
    'sdk/conformance/development_recovery_v32_placement_diagnosis.py',
    'sdk/conformance/qsdk_r10f_physical_closure.py')


def proposed_rate(active, phase, presence, bearing, dt, cap, full_rate, original_rate):
    """Only extend V39 to explicitly absent-contact stance; no fitted gain."""
    if (any(type(v) is not bool for v in (active, presence, bearing))
            or type(phase) not in (int, float) or not math.isfinite(phase)
            or phase != int(phase) or not 0 <= phase < 360
            or not all(math.isfinite(v) for v in (dt, cap, full_rate, original_rate))
            or dt < 0 or cap <= 0 or abs(full_rate) > cap or abs(original_rate) > cap
            or (bearing and not presence)):
        raise ValueError('ABSENT_STANCE_SKETCH_DOMAIN')
    selected = active and dt > 0 and phase > 72 and not presence and not bearing
    return selected, full_rate if selected else original_rate


def vertical_joint_derivatives(torso, hip, knee, dimensions):
    """Exact derivative of the existing ideal distal capsule bottom.

    This is an instantaneous kinematic calculation at a fixed measured torso,
    not an achieved motor velocity or a contact/force prediction.
    """
    forward, up = (tracking.geometry.rotate(torso['orientation_xyzw'], v)[1]
                   for v in ([1,0,0], [0,1,0]))
    axis_y = up*math.cos(hip+knee)-forward*math.sin(hip+knee)
    if axis_y == 0:
        raise ValueError('ABSENT_STANCE_CAPSULE_DERIVATIVE_CUSP')
    distal = dimensions[1]*.5*(1+math.copysign(1.,axis_y))
    knee_derivative = distal*(up*math.sin(hip+knee)+forward*math.cos(hip+knee))
    return dimensions[0]*(up*math.sin(hip)+forward*math.cos(hip))+knee_derivative, knee_derivative


def spread(values):
    values = list(values)
    return tracking.spread(values) if values else None


def summarize(report):
    if report['source_commit'] != SOURCE:
        raise ValueError('ABSENT_STANCE_SOURCE_CROSSED')
    original = cold.base.summarize(report)
    command_audit = cold.command_audit(report)
    contact_timing = cold.contact_timing(report)
    rows, entries, native, bodies, dimensions, frame_error = tracking.samples(report)
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
    floor = session['start_receipt']['development_floor_source']['floor_reference']
    assert floor['height_world_m'] == 0.  # Exact bound fixture, not inferred world origin.
    trace = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id')==session['session_id']]
    assert len(entries) == len(trace) == 400 and len(rows) == 1600
    timeline = []
    for row in rows:
        n, limb = row['command_local'], row['limb']
        entry = entries[n]; request, output = entry['request'], entry['native_output']
        support = output['actuation']['receipt']['recovery_support_plane']
        index = tracking.geometry.LIMBS.index(limb)
        p = support['ordered_limb_proposals'][index]; phase = p['scheduled_phase_step']
        assert p['limb_id'] == limb and phase == row['command_phase']
        contact = request['state']['ordered_contact_observations'][index]
        assert contact['contact_site_id'] == limb+'_foot'
        assert contact['presence'] == contact['bears_support'] == row['native_contact']
        torso = native[n-1]['observation']['state']['base_pose_world']
        derivatives = vertical_joint_derivatives(torso, *row['measured_joint_rad'], dimensions)
        motors = []
        for j in (2*index,2*index+1):
            command = output['actuation']['ordered_commands'][j]
            joint = request['state']['ordered_joint_observations'][j]
            application = entry['ordered_motor_applications'][j]
            assert application['actuator_id'] == command['actuator_id']
            assert not application['host_additional_clamp_applied']
            assert application['host_applied_target_velocity_rad_s'] == command['target_velocity_rad_s']
            # Readback is the engine's binary32 slot, not a second binary64 command.
            expected_slot = struct.unpack('f',struct.pack('f',command['target_velocity_rad_s']))[0]
            assert expected_slot == application['motor_target_velocity_readback_rad_s']
            cap = command['maximum_target_speed_rad_s']
            original_rate = support['ordered_reference_velocity_rad_s'][j]
            full = support['airborne_reference']['ordered_full_reference_velocity_rad_s'][j]
            selected, rate = proposed_rate(support['wave_velocity']['feedforward_active'],phase,
                contact['presence'],contact['bears_support'],support['reference_step_duration_s'],cap,full,original_rate)
            feedback = 8*(command['requested_target_position_rad']-joint['position_rad'])-.65*joint['velocity_rad_s']
            raw = feedback+1.65*rate
            proposed_velocity = -max(-cap,min(cap,raw)) if selected else command['target_velocity_rad_s']
            original_velocity = command['target_velocity_rad_s']
            motors.append(dict(actuator_id=command['actuator_id'],new_stance_selection=selected,
                original_reference_rate_rad_s=original_rate,full_reference_rate_rad_s=full,
                original_velocity_rad_s=original_velocity,proposed_velocity_rad_s=proposed_velocity,
                proposed_minus_original_geometric_velocity_rad_s=original_velocity-proposed_velocity,
                command_difference_exceeds_existing_1e_12_arithmetic_allowance=abs(proposed_velocity-original_velocity)>1e-12,
                original_saturated=command['velocity_saturated'],
                proposed_saturated=abs(raw)>cap if selected else command['velocity_saturated'],
                cap_rad_s=cap,maximum_impulse_slot_nms=application['motor_maximum_impulse_readback_nms']))
        prior = row['preceding_reference_rad']
        timeline.append(dict(row, phase=phase, pre_contact=row['native_contact'],
            post_contact=trace[n-1]['contact_by_limb'][limb],
            link_projection_at_planned_height=p['link_reach_projection_required'],
            joint_projection=p['support_joint_projection_required'],
            support_reference_height_m=p['support_reference_torso_height_m'],
            requested_body_lowering_m=support['feasible_support_plan']['requested_lowering_m'],
            precommand_error_against_preceding_reference_rad=[q-r for q,r in zip(row['measured_joint_rad'],prior)] if prior is not None else None,
            ideal_bottom_joint_derivatives_m_per_rad=list(derivatives),
            proposed_minus_original_ideal_vertical_rate_m_s=sum(d*m['proposed_minus_original_geometric_velocity_rad_s'] for d,m in zip(derivatives,motors)),
            motors=motors))
    per_limb = []
    metrics = ('nominal_actual_bottom_m','ideal_current_reference_bottom_m','ideal_goal_bottom_m',
               'requested_body_lowering_m','unrestricted_planar_reach_lower_bound_m')
    for limb in tracking.geometry.LIMBS:
        stance = [r for r in timeline if r['limb']==limb and r['phase']>72]
        absent = [r for r in stance if not r['pre_contact']]
        per_limb.append(dict(limb=limb,stance_command_count=len(stance),unsupported_stance_command_count=len(absent),
            stance_link_projection_at_planned_height_count=sum(r['link_projection_at_planned_height'] for r in stance),
            stance_joint_projection_count=sum(r['joint_projection'] for r in stance),
            unsupported_stance_saturated_joint_commands=sum(m['original_saturated'] for r in absent for m in r['motors']),
            unsupported_stance_no_raw_contact_count=sum(r['raw_contact_count']==0 for r in absent),
            unsupported_stance_geometry={k:spread(r[k] for r in absent) for k in metrics},
            unsupported_stance_reference_error_rad={joint:spread(r['precommand_error_against_preceding_reference_rad'][i] for r in absent) for i,joint in enumerate(('hip','knee'))}))
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    cycles = [dict(limb=p['limb'],**c,decomposition=tracking.decompose(p['limb'],c['liftoff_local_step'],
        c['touchdown_local_step'],native,bodies,dimensions,axis)) for p in original['per_limb'] for c in p['contact_cycles']]
    changed_rows = [r for r in timeline if r['motors'][0]['new_stance_selection']]
    all_motors = [m for r in timeline for m in r['motors']]
    return dict(command_count=len(entries),limb_command_count=len(timeline),joint_command_count=len(all_motors),
        original_walking_evaluation=session['evaluation'],original_contact_cycles=cycles,
        original_contact_timing=contact_timing,original_command_audit=command_audit,per_limb=per_limb,
        coordinate_conversion_maximum_axis_difference=frame_error,
        proposed_stance_rate_sketch=dict(new_limb_selections=len(changed_rows),new_joint_selections=2*len(changed_rows),
            changed_joint_commands=sum(m['command_difference_exceeds_existing_1e_12_arithmetic_allowance'] for m in all_motors),
            proposed_saturated_joint_commands=sum(m['proposed_saturated'] for m in all_motors),
            selected_stance_proposed_saturated_joint_commands=sum(m['proposed_saturated'] for r in changed_rows for m in r['motors']),
            all_unselected_velocities_exact=all(m['original_velocity_rad_s']==m['proposed_velocity_rad_s'] for m in all_motors if not m['new_stance_selection']),
            all_proposed_velocities_inside_existing_caps=all(abs(m['proposed_velocity_rad_s'])<=m['cap_rad_s'] for m in all_motors),
            fixed_pose_ideal_vertical_rate_change=spread(r['proposed_minus_original_ideal_vertical_rate_m_s'] for r in changed_rows),
            instantaneous_kinematic_prediction_only=True,native_component_implemented=False,alternate_physical_trajectory_evaluated=False),
        all_limb_command_timeline=timeline)


def observe():
    path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw = path.read_bytes()
    if digest(raw) != CLOSURE_SHA:
        raise ValueError('ABSENT_STANCE_CLOSURE_DRIFT')
    closure = json.loads(raw); report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if digest(report_raw) != REPORT_SHA or closure['source_snapshot']['head'] != SOURCE:
        raise ValueError('ABSENT_STANCE_REPORT_DRIFT')
    return dict(schema_version='sporespore_development_absent_stance_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw)),source_report=closure['kicked_report'],
        frozen_sources=[dict(path=p,source_commit=SOURCE,raw_sha256=digest(subprocess.check_output(['git','show',SOURCE+':'+p],cwd=ROOT))) for p in
            ('sdk/core/src/recovery_support_plane.rs','sdk/core/src/recovery_feasible_support.rs','sdk/core/src/quadruped.rs')],
        analysis_sources=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw)),
        selection_rule='All 400 commands, all 1600 limb samples, all 19 original dwell-qualified cycles and all 24 contact losses. Stance means the existing phase >72. Unsupported means both original contact booleans false. No outcome-selected control window.',
        limits='A plan computed at a lower prospective body height is not a reachable foot target at the current body height. Ideal kinematics omit constraint compliance and do not define contact. The sketch tracks a moving target; it is not a downward-only correction and may harm posture/contact. Recorded speed-cap absence does not establish force/impulse adequacy; maximum impulse slots are not delivered impulse measurements. No next-command body pose exists for terminal trace 400. Existing original evaluations, thresholds and failures remain unchanged.',
        original_evaluation_changed=False,physical_cause_proven=False,alternate_physical_outcome_predicted=False,
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def compact(full,output):
    raw=output.read_bytes()
    return dict(full,diagnosis={k:v for k,v in full['diagnosis'].items() if k!='all_limb_command_timeline'},
        complete_diagnosis=dict(path=output.as_posix(),byte_length=len(raw),raw_sha256=digest(raw)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    output=parser.parse_args().output.resolve()
    if not output.is_relative_to(EVIDENCE.resolve()):
        raise ValueError('ABSENT_STANCE_DURABLE_OUTPUT_REQUIRED')
    full=observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(compact(full,output),indent=2,allow_nan=False))
