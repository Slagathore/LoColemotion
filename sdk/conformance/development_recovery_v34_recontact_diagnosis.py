"""All V34 landing holds from retained data: no native calls or alternate rollout."""
import hashlib
import json
from pathlib import Path

import development_recovery_v28_contact_geometry as geometry
from development_recovery_v32_placement_diagnosis import relaxed_fixed_torso_bottom
from development_recovery_v33_support_tracking_diagnosis import phase, spread

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = 'beb9c66e4c194930b6283fd227613f44'
SOURCE = 'ef4636af0eaac60a997d43547178d575ec52b1f9'
REPORT_SHA = 'sha256:caee59937ad3f6ba161c4eb2b0ccd8792cf8eedfd4865853109c73dcaa04e63d'


def digest(raw):
    return 'sha256:'+hashlib.sha256(raw).hexdigest()


def summarize(report):
    entries = report['development_walking_entry']['rows']
    assert report['source_commit']==SOURCE and len(entries)==400
    body_rows,frame_error = geometry.reconstruct(report)
    bodies = {(r['limb'],r['trace_local_step']):r for r in body_rows}
    native = {int(r['session_local_step']):r['native_source'] for r in
              report['development_native_walking_contacts']['rows'] if r['segment_id']=='walking_resume'}
    descriptor = report['configuration']['base_descriptor']
    upper = .35*descriptor['upper_length_fraction']
    dimensions = (upper,.35-upper,.04*descriptor['foot_radius_scale'],descriptor['hip_span_scale'])
    floor = entries[0]['request']['floor_reference']
    for row in entries:
        assert row['request']['floor_reference']==floor==row['development_floor_source']['floor_reference']
    floor_y = floor['height_world_m']
    by_limb,episodes,timeouts = [],[],[]
    for limb in geometry.LIMBS:
        selected,groups = [],[]
        for local,row in enumerate(entries,1):
            before = next(m for m in row['request']['memory']['ordered_limb_memory'] if m['limb_id']==limb)
            after = next(m for m in row['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id']==limb)
            if phase(row,limb)<72: selected.append(local)
            if after['recontact_hold_step_count']>before['recontact_hold_step_count']:
                assert after['recontact_hold_step_count']==before['recontact_hold_step_count']+1
                if not groups or groups[-1][-1]!=local-1: groups.append([])
                groups[-1].append(local)
            if after['gate_timeout_count']>before['gate_timeout_count']:
                timeouts.append(dict(limb=limb,command_local_step=local,
                    held_steps_before_timeout=before['current_gate_hold_steps'],
                    gait_step_before=before['gait_step'],gait_step_after=after['gait_step']))
        final = next(m for m in entries[-1]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id']==limb)
        by_limb.append(dict(limb=limb,scheduled_swing_command_count=len(selected),
            first_swing_command_local=selected[0] if selected else None,
            last_swing_command_local=selected[-1] if selected else None,
            terminal_gait_step=final['gait_step'],phase_sync_hold_step_count=final['phase_sync_hold_step_count'],
            release_hold_step_count=final['release_hold_step_count'],recontact_hold_step_count=final['recontact_hold_step_count']))
        for group in groups:
            records=[]
            for local in group:
                row = entries[local-1]
                body = bodies[limb,local-1]
                torso = native[local]['observation']['state']['base_pose_world']
                proposal = next(p for p in row['native_output']['actuation']['receipt']['recovery_support_plane']['ordered_limb_proposals'] if p['limb_id']==limb)
                old = {c['actuator_id']:c['requested_target_position_rad'] for c in entries[local-2]['native_output']['actuation']['ordered_commands']}
                records.append(dict(native_support=body['support'],
                    requested_direction_unreachable=proposal['link_reach_projection_required'],
                    unrestricted_planar_reach_lower_bound_m=relaxed_fixed_torso_bottom(torso,limb,dimensions)-floor_y,
                    nominal_actual_floor_clearance_m=body['nominal_capsule_bottom_m']-floor_y,
                    ideal_goal_floor_clearance_m=geometry.ideal_distal(torso,limb,proposal['goal_hip_rad'],proposal['goal_knee_rad'],*dimensions)[1]-floor_y,
                    postcommand_knee_reference_error_rad=body['knee_rad']-old[limb+'_knee_motor']))
            episodes.append(dict(limb=limb,first_command_local=group[0],last_command_local=group[-1],
                held_command_count=len(group),precommand_native_support_count=sum(r['native_support'] for r in records),
                requested_direction_unreachable_count=sum(r['requested_direction_unreachable'] for r in records),
                unreachable_even_with_unrestricted_planar_joint_angles_count=sum(r['unrestricted_planar_reach_lower_bound_m']>0 for r in records),
                **{key:spread(r[key] for r in records) for key in ('unrestricted_planar_reach_lower_bound_m',
                    'nominal_actual_floor_clearance_m','ideal_goal_floor_clearance_m','postcommand_knee_reference_error_rad')}))
    evaluation = next(s['evaluation'] for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
    return dict(schema_version='sporespore_development_v34_recontact_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_commit=SOURCE,selection_rule='All 400 resumed commands, every increment of every native recontact-hold counter, and every native timeout increment. No episode selection by outcome.',
        measured_body_sample_count=len(body_rows),floor_reference=floor,
        coordinate_conversion_maximum_axis_difference=frame_error,per_limb=by_limb,
        recontact_hold_episodes=episodes,native_timeouts=timeouts,
        original_false_walking_receipts=evaluation['false_walking_receipts'],
        original_contact_cycle_count_by_limb=evaluation['contact_cycle_count_by_limb'],
        original_forward_advance_m=evaluation['forward_advance_m'],
        original_terminal_four_contact_recovery=evaluation['walking_gate_receipts']['terminal_four_contact_recovery'],
        interpretation='The first landing direction exceeds link reach throughout its 120-step hold. In some samples even arbitrary planar joint angles cannot reach the floor at the measured torso pose. The second landing has a geometrically reachable goal but delayed measured tracking. This distinguishes geometric reach from tracking and explains the recorded schedule delay, not a complete physical causal model.',
        next_bounded_work='Develop a separately versioned reachable-touchdown/support-height proposal using the retained floor and pose contract. Check full leg reach and supported-body compatibility before another native candidate. Preserve joint limits, reference slew, contact rules and official gates; do not solve this negative by rethresholding or extending its consumed horizon.',
        geometry_limit='Nominal capsule surface and ideal hinges omit contact margins and measured joint compliance; positive geometric clearance is not a replacement contact rule. The unrestricted reach bound relaxes joint limits and holds the measured torso fixed. No alternative trajectory or force-aware controller is evaluated.',
        tracking_alignment='Command n uses trace n-1; measured joints at that input are compared to command n-1, not the current target. No terminal next-input pose is invented.',
        original_evaluation_changed=False,physical_cause_proven=False,alternate_physical_outcome_predicted=False,
        world_build_count=0,solver_step_count=0,native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def observe():
    path=ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw=path.read_bytes(); record=json.loads(raw)
    report_raw=Path(record['kicked_report']['path']).read_bytes()
    if record['source_snapshot']['head']!=SOURCE or digest(report_raw)!=REPORT_SHA or record['kicked_report']['raw_sha256']!=REPORT_SHA:
        raise ValueError('V34_RECONTACT_SOURCE_DRIFT')
    result=summarize(json.loads(report_raw))
    result['source_closure']=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw))
    result['source_report']=record['kicked_report']
    result['analysis_sources']=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in (
        'sdk/conformance/development_recovery_v34_recontact_diagnosis.py',
        'sdk/conformance/development_recovery_v28_contact_geometry.py',
        'sdk/conformance/development_recovery_v32_placement_diagnosis.py',
        'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py')]
    return result


if __name__=='__main__':
    print(json.dumps(observe(),indent=2,allow_nan=False))
