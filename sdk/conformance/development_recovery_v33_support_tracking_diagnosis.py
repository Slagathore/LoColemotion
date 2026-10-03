"""V33 retained command/contact diagnosis and explicit-floor geometry precheck.

Command n reads trace n-1. Measured response to command n is available only
through n=399; trace 400 has foot positions/contacts but no next body input.
No model, native library, simulation, alternative rollout or gate is invoked.
"""
import hashlib
import json
import math
import statistics
import subprocess
from pathlib import Path

import development_recovery_v28_contact_geometry as geometry
from development_recovery_v32_placement_diagnosis import relaxed_fixed_torso_bottom

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '4e5cacbc49e64ceab61fff2762217804'
SOURCE = '320668509058bfadcb31d66b4e83d67fbb783202'
CLOSURE_SHA = 'sha256:42aa3ca80ec16a8c8f7fae1a592d64375cc0e7c163ee236973c8ea2d08a52651'
LIMBS = ('rear_left', 'front_left', 'rear_right', 'front_right')


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def spread(values):
    values = list(values)
    return dict(count=len(values), minimum=min(values), mean=statistics.mean(values),
                maximum=max(values), rms=math.sqrt(statistics.mean(x*x for x in values)))


def phase(entry, limb, output=True):
    memory = entry['native_output']['next_memory'] if output else entry['request']['memory']
    clock = next(m['gait_step'] for m in memory['ordered_limb_memory'] if m['limb_id'] == limb)
    return int((clock + 360 - LIMBS.index(limb)*90) % 360)


def floor_referenced_target(torso, limb, direction, dimensions, floor_y_m):
    """Feasibility only: preserve direction, use supplied floor, retain limits.

    The caller MUST supply a plane in the same native coordinate frame. There
    is no inferred floor at world zero, force estimate, or contact assertion.
    This function has no startup, phase, feedback, or runtime registration.
    """
    upper, lower, radius, span = dimensions
    values = [*dimensions, direction, floor_y_m, *torso['position_m'].values(),
              *torso['orientation_xyzw'].values()]
    if (limb not in LIMBS or not all(math.isfinite(v) for v in values)
            or min(dimensions) <= 0 or sum(v*v for v in torso['orientation_xyzw'].values()) == 0):
        raise ValueError('V33_FLOOR_PROPOSAL_DOMAIN')
    forward, up, side = (geometry.rotate(torso['orientation_xyzw'], a)
                         for a in ([1,0,0], [0,1,0], [0,0,1]))
    anchor = span*((.2 if limb.startswith('front') else -.2)*forward[1]
                  + (-.18 if limb.endswith('left') else .18)*side[1])
    downward = up[1]*math.cos(direction)-forward[1]*math.sin(direction)
    if downward <= 0:
        raise ValueError('V33_FLOOR_PROPOSAL_DIRECTION')
    requested_length = (torso['position_m']['y']-floor_y_m+anchor-radius)/downward
    length = max(abs(upper-lower), min(upper+lower, requested_length))
    cosine = (length*length-upper*upper-lower*lower)/(2*upper*lower)
    knee_unbounded = math.acos(max(-1.,min(1.,cosine)))
    knee = min(1.1, knee_unbounded)
    hip_unbounded = direction-math.atan2(lower*math.sin(knee), upper+lower*math.cos(knee))
    hip = max(-.72,min(.72,hip_unbounded))
    return dict(hip_rad=hip, knee_rad=knee, requested_length_m=requested_length,
        link_reach_projection_required=requested_length != length,
        joint_projection_required=knee != knee_unbounded or hip != hip_unbounded,
        nominal_floor_residual_m=geometry.ideal_distal(torso,limb,hip,knee,*dimensions)[1]-floor_y_m)


def samples(report):
    measured, frame_error = geometry.reconstruct(report)
    bodies = {(r['limb'],r['trace_local_step']):r for r in measured}
    entries = {int(r['session_local_step']):r for r in report['development_walking_entry']['rows']}
    native = {int(r['session_local_step'])-1:r['native_source']
              for r in report['development_native_walking_contacts']['rows'] if r['segment_id']=='walking_resume'}
    d = report['configuration']['base_descriptor']
    upper = .35*d['upper_length_fraction']
    dimensions = (upper,.35-upper,.04*d['foot_radius_scale'],d['hip_span_scale'])
    rows = []
    for n,e in entries.items():
        t = n-1
        torso = native[t]['observation']['state']['base_pose_world']
        receipt = e['native_output']['actuation']['receipt']['recovery_support_plane']
        joints = {j['joint_id']:j for j in e['request']['state']['ordered_joint_observations']}
        commands = {c['actuator_id']:c for c in e['native_output']['actuation']['ordered_commands']}
        for p in receipt['ordered_limb_proposals']:
            limb = p['limb_id']
            q = [joints[limb+'_'+j]['position_rad'] for j in ('hip','knee')]
            selected = [commands[limb+'_'+j+'_motor'] for j in ('hip','knee')]
            target = [c['requested_target_position_rad'] for c in selected]
            goal = [p['goal_hip_rad'],p['goal_knee_rad']]
            support = [p['projected_support_hip_rad'],p['projected_support_knee_rad']]
            prior_target = None if t==0 else [c['requested_target_position_rad']
                for c in entries[t]['native_output']['actuation']['ordered_commands']
                if c['actuator_id'].startswith(limb+'_')]
            # Explicitly scoped to this retained flat-floor fixture, not a new
            # production observation contract or a world-origin assumption.
            alternative = floor_referenced_target(torso,limb,p['nominal_leg_direction_rad'],dimensions,0.)
            row = dict(command_local=n, measured_trace_local=t, limb=limb,
                command_phase=phase(e,limb), input_phase=phase(e,limb,False),
                applied_phase=None if t==0 else phase(entries[t],limb),
                native_contact=bodies[limb,t]['support'], raw_contact_count=bodies[limb,t]['raw_contact_count'],
                measured_joint_rad=q, current_reference_rad=target, goal_joint_rad=goal,
                preceding_reference_rad=prior_target,
                body_height_m=torso['position_m']['y'], proposed_height_m=receipt['proposed_torso_height_m'],
                nominal_actual_bottom_m=bodies[limb,t]['nominal_capsule_bottom_m'],
                ideal_measured_bottom_m=geometry.ideal_distal(torso,limb,*q,*dimensions)[1],
                ideal_current_reference_bottom_m=geometry.ideal_distal(torso,limb,*target,*dimensions)[1],
                ideal_goal_bottom_m=geometry.ideal_distal(torso,limb,*goal,*dimensions)[1],
                ideal_support_bottom_m=geometry.ideal_distal(torso,limb,*support,*dimensions)[1],
                retained_plane_residual_m=p['projected_support_nominal_plane_residual_m'],
                unrestricted_planar_reach_lower_bound_m=relaxed_fixed_torso_bottom(torso,limb,dimensions),
                floor_proposal=alternative, velocity_saturated_count=sum(c['velocity_saturated'] for c in selected))
            rows.append(row)
    return rows, entries, native, bodies, dimensions, frame_error


def decompose(limb, start, end, native, bodies, dimensions, axis):
    if end not in native:
        return dict(available=False, reason='No retained next-command body pose at trace 400; no endpoint invented.')
    a,b = (bodies[limb,t] for t in (start,end))
    pa,pb = (native[t]['observation']['state']['base_pose_world'] for t in (start,end))
    aa,ab = geometry.ideal_distal(pa,limb,a['hip_rad'],a['knee_rad'],*dimensions)
    ba,bb = geometry.ideal_distal(pb,limb,a['hip_rad'],a['knee_rad'],*dimensions)
    ca,cb = geometry.ideal_distal(pb,limb,b['hip_rad'],b['knee_rad'],*dimensions)
    translation = [pb['position_m'][k]-pa['position_m'][k] for k in 'xyz']
    rotation = [ba[i]-aa[i]-translation[i] for i in range(3)]
    joints = [ca[i]-ba[i] for i in range(3)]
    actual = [native[end]['precommand_trace']['foot_position_world_m_by_limb'][limb][i]
              -native[start]['precommand_trace']['foot_position_world_m_by_limb'][limb][i] for i in range(3)]
    parts = dict(actual=actual,torso_translation=translation,torso_rotation_at_initial_joints=rotation,
                 joint_change_at_final_pose=joints)
    forward = {name:sum(v[i]*axis[i] for i in range(3)) for name,v in parts.items()}
    forward['ideal_constraint_residual'] = forward['actual']-sum(v for k,v in forward.items() if k!='actual')
    clearance = dict(actual=b['nominal_capsule_bottom_m']-a['nominal_capsule_bottom_m'],
        torso_translation=translation[1],torso_rotation_at_initial_joints=bb-ab-translation[1],
        joint_change_at_final_pose=cb-bb)
    clearance['ideal_constraint_residual'] = clearance['actual']-sum(v for k,v in clearance.items() if k!='actual')
    return dict(available=True,forward_components_m=forward,clearance_change_components_m=clearance,
                measured_hip_start_end_rad=[a['hip_rad'],b['hip_rad']],measured_knee_start_end_rad=[a['knee_rad'],b['knee_rad']])


def summarize(report):
    rows,entries,native,bodies,dimensions,frame_error = samples(report)
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
    trace = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id')==session['session_id']]
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    indexed = {(r['limb'],r['measured_trace_local']):r for r in rows}
    summaries = []
    for limb in geometry.LIMBS:
        outgoing = [r for r in rows if r['limb']==limb and r['command_phase']>=72]
        response = [r for r in rows if r['limb']==limb and r['applied_phase'] is not None and r['applied_phase']>=72]
        summaries.append(dict(limb=limb, scheduled_stance_command_count=len(outgoing),
            stance_goal_above_floor_count=sum(r['ideal_goal_bottom_m']>0 for r in outgoing),
            stance_goal_bottom_m=spread(r['ideal_goal_bottom_m'] for r in outgoing),
            stance_precommand_missing_contact_count=sum(not r['native_contact'] for r in outgoing),
            stance_response_sample_count=len(response),
            stance_response_hip_reference_error_rad=spread(r['measured_joint_rad'][0]-r['preceding_reference_rad'][0] for r in response),
            stance_response_knee_reference_error_rad=spread(r['measured_joint_rad'][1]-r['preceding_reference_rad'][1] for r in response),
            floor_proposal_stance_residual_m=spread(r['floor_proposal']['nominal_floor_residual_m'] for r in outgoing),
            floor_proposal_stance_unreachable_count=sum(r['floor_proposal']['link_reach_projection_required'] for r in outgoing),
            floor_proposal_stance_joint_projection_count=sum(r['floor_proposal']['joint_projection_required'] for r in outgoing),
            stance_fixed_torso_unreachable_even_with_unrestricted_angles_count=sum(r['unrestricted_planar_reach_lower_bound_m']>0 for r in outgoing),
            stance_unrestricted_planar_reach_lower_bound_m=spread(r['unrestricted_planar_reach_lower_bound_m'] for r in outgoing)))
    cycles,gaps = [],{}
    for limb in LIMBS:
        previous,start = True,None
        for row in trace:
            contact,local = row['contact_by_limb'][limb],row['walking_session_local_step']
            if previous and not contact:
                start = local
            elif not previous and contact and start is not None:
                if local-start>=session['evaluation']['fixed_thresholds']['minimum_airborne_dwell_steps']:
                    delta = sum((row['foot_position_world_m_by_limb'][limb][i]-trace[start-1]['foot_position_world_m_by_limb'][limb][i])*axis[i] for i in range(3))
                    span = [indexed[limb,t] for t in range(start,local) if (limb,t) in indexed]
                    cycles.append(dict(limb=limb,release_trace_local=start,touchdown_trace_local=local,
                        forward_m=delta,forward_passed=delta>=session['evaluation']['fixed_thresholds']['minimum_foot_relocation_m'],
                        release_applied_command_phase=phase(entries[start],limb),
                        original_closure_input_phase=phase(entries[start],limb,False),
                        raw_contact_sample_count_during_gap=sum(r['raw_contact_count'] for r in span),
                        airborne_nominal_bottom_m=spread(r['nominal_actual_bottom_m'] for r in span),
                        release_sample=indexed[limb,start],
                        decomposition=decompose(limb,start,local,native,bodies,dimensions,axis)))
                start = None
            previous = contact
        gaps[limb] = None if start is None else dict(release_trace_local=start,observed_contact_samples=401-start,
            reconstructed_body_samples=400-start,release_sample=indexed[limb,start])
    failed = [c for c in cycles if not c['forward_passed']]
    plane_errors = [abs(r['ideal_support_bottom_m']-(r['body_height_m']-r['proposed_height_m']+r['retained_plane_residual_m'])) for r in rows]
    response = [r for r in rows if r['preceding_reference_rad'] is not None]
    worst = max(response,key=lambda r:abs(r['measured_joint_rad'][1]-r['preceding_reference_rad'][1]))
    return dict(schema_version='sporespore_development_v33_support_tracking_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_commit=SOURCE, measured_body_sample_count=len(rows), measured_response_joint_count=2*len(response),
        coordinate_conversion_maximum_axis_difference=frame_error,
        support_height_identity_maximum_error_m=max(plane_errors),
        support_height_identity='Ideal support bottom at actual torso = actual height - proposed height + retained joint-projection residual; sample frame roundoff retained.',
        per_limb=summaries, counted_cycles=cycles, failed_cycle_count=len(failed),
        failed_cycles_released_outside_commanded_swing=sum(c['release_applied_command_phase']>=72 for c in failed),
        terminal_contact_gaps=gaps, maximum_knee_response_error_sample=worst,
        velocity_saturated_command_count=sum(r['velocity_saturated_count'] for r in rows),
        original_false_walking_receipts=session['evaluation']['false_walking_receipts'],
        geometric_proposal=dict(rule='Use supplied floor height and measured torso height, preserve each nominal leg direction, project link reach and existing hip/knee limits, retain residual.',
            supplied_floor_y_m=0., floor_scope='Authored floor of this exact retained native fixture only.',
            sample_count=len(rows), link_reach_projection_count=sum(r['floor_proposal']['link_reach_projection_required'] for r in rows),
            joint_projection_count=sum(r['floor_proposal']['joint_projection_required'] for r in rows),
            controller_ready=False, runtime_plane_observation_contract_exists=False,
            decision='Select an explicitly plane-referenced, joint-bounded successor for development, retaining unreachable residuals and existing reference slew. Establish plane/frame provenance before runtime integration. This is a testable mechanism, not a complete fix or predicted physical success.'),
        interpretation_limit='All 15 observed cycles retained; 14 endpoint decompositions available. Algebraic order is not isolated causation. Precommand/current-target error differs from postcommand/preceding-target error. Nominal capsule geometry is not native contact truth. Explicit-floor proposals are fixed-pose geometry, not predictions of another rollout.',
        physical_cause_proven=False, alternate_physical_outcome_predicted=False, original_evaluation_changed=False,
        world_build_count=0,solver_step_count=0,additional_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def observe():
    path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw = path.read_bytes()
    if digest(raw)!=CLOSURE_SHA:
        raise ValueError('V33_TRACKING_CLOSURE_DRIFT')
    closure = json.loads(raw)
    report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if digest(report_raw)!=closure['kicked_report']['raw_sha256'] or closure['source_snapshot']['head']!=SOURCE:
        raise ValueError('V33_TRACKING_REPORT_DRIFT')
    result = summarize(json.loads(report_raw))
    result['source_closure'] = dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw))
    result['source_report'] = closure['kicked_report']
    result['frozen_sources'] = [dict(path=p,raw_sha256=digest(subprocess.check_output(['git','show',SOURCE+':'+p],cwd=ROOT))) for p in (
        'sdk/core/src/runtime.rs','sdk/core/src/recovery_support_plane.rs','sdk/core/src/quadruped.rs')]
    result['analysis_sources'] = [dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in (
        'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py',
        'sdk/conformance/development_recovery_v28_contact_geometry.py',
        'sdk/conformance/development_recovery_v32_placement_diagnosis.py',
        'tests/test_development_v33_support_tracking_diagnosis.py')]
    return result


if __name__=='__main__':
    print(json.dumps(observe(),indent=2,allow_nan=False))
