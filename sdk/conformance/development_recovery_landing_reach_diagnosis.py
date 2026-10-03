"""Complete V40 saved landing/reach diagnosis; no native or physical execution.

Reuse the existing command audit, measured-frame reconstruction and ordered
motion decomposition. Constraint omissions below are algebraic diagnostics,
not controller proposals or predictions of contact after another command.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import subprocess

import development_recovery_absent_contact_reference_observation as cold
import development_recovery_v33_support_tracking_diagnosis as tracking

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent/'SporeSpore_Evidence'
ATTEMPT = '9791149066cc43e2b42df2f1def7adc1'
SOURCE = '07fe6a9cf853136cca1ddaa2591c6537b85e0a4d'
CLOSURE_SHA = 'sha256:7782fc657984a17f426fc63bf0e66d88bb0422237607ec3949e12c89f717827c'
REPORT_SHA = 'sha256:a1872bd14d79a844e48577bc5338fe7b46f1141d7a1c97460f84d52cb9c915bc'
digest = cold.base.digest
ANALYSIS_PATHS = (
    'sdk/conformance/development_recovery_landing_reach_diagnosis.py',
    'sdk/conformance/development_recovery_absent_contact_reference_observation.py',
    'sdk/conformance/development_recovery_airborne_reference_observation.py',
    'sdk/conformance/development_recovery_feasible_support_observation.py',
    'sdk/conformance/development_recovery_v33_support_tracking_diagnosis.py',
    'sdk/conformance/development_recovery_v37_reference_diagnosis.py',
    'sdk/conformance/development_recovery_v28_contact_geometry.py',
    'sdk/conformance/development_recovery_v32_placement_diagnosis.py',
    'sdk/conformance/qsdk_r10f_physical_closure.py')


def spread(values):
    values = list(values)
    return tracking.spread(values) if values else None


def intervals(pose, wave, dimensions):
    """Reconstruct each direction-preserving interval, including hip limits."""
    height, quat = pose
    upper, lower, radius, span = dimensions
    if (not all(math.isfinite(v) for v in (height, *quat, *dimensions))
            or min(dimensions) <= 0 or len(wave['limbs']) != 4):
        raise ValueError('LANDING_REACH_GEOMETRY_DOMAIN')
    norm = math.sqrt(sum(v*v for v in quat))
    if norm == 0:
        raise ValueError('LANDING_REACH_QUATERNION_DOMAIN')
    x, y, z, w = (v/norm for v in quat)
    forward, up, side = 2*(y*z-w*x), 1-2*(x*x+z*z), -2*(x*y+w*z)
    result = []
    for limb, (angle, fraction, phase) in zip(tracking.geometry.LIMBS, wave['limbs']):
        if (not all(math.isfinite(v) for v in (angle, fraction, phase))
                or not -.72 <= angle <= .72 or not 0 <= fraction <= 1
                or phase != int(phase) or not 0 <= phase < 360):
            raise ValueError('LANDING_REACH_WAVE_DOMAIN')
        anchor = ((.2 if limb.startswith('front') else -.2)*span)*forward + ((-.18 if limb.endswith('left') else .18)*span)*side
        down = up*math.cos(angle)-forward*math.sin(angle)
        if not 0 < down <= 1:
            raise ValueError('LANDING_REACH_DIRECTION_DOMAIN')
        beta = lambda k: math.atan2(lower*math.sin(k), upper+lower*math.cos(k))
        knee = 1.1
        if beta(knee) > angle+.72:
            lo, hi = 0., knee
            for _ in range(64):
                mid = (lo+hi)*.5
                if beta(mid) <= angle+.72: lo = mid
                else: hi = mid
            knee = lo
        length = math.hypot(upper+lower*math.cos(knee), lower*math.sin(knee))
        result.append(dict(limb_id=limb,
            minimum_torso_height_m=radius-anchor+length*down,
            maximum_torso_height_m=radius-anchor+(upper+lower)*down,
            maximum_direction_preserving_knee_rad=knee))
    return result


def intersection(rows):
    if not rows:
        return None
    low = max(r['minimum_torso_height_m'] for r in rows)
    high = min(r['maximum_torso_height_m'] for r in rows)
    return dict(minimum_m=low, maximum_m=high, nonempty=low <= high,
        signed_gap_m=low-high,
        minimum_owners=[r['limb_id'] for r in rows if r['minimum_torso_height_m']==low],
        maximum_owners=[r['limb_id'] for r in rows if r['maximum_torso_height_m']==high])


def windows(commands):
    groups = []
    for n in commands:
        if groups and groups[-1]['last'] == n-1:
            groups[-1]['last'] = n; groups[-1]['count'] += 1
        else:
            groups.append(dict(first=n, last=n, count=1))
    return groups


def summarize(report):
    if report['source_commit'] != SOURCE:
        raise ValueError('LANDING_REACH_SOURCE_CROSSED')
    original = cold.base.summarize(report)
    audit = cold.command_audit(report)
    timing = cold.parent.contact_timing(report)
    rows, entries, native, bodies, dimensions, frame_error = tracking.samples(report)
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
    floor = session['start_receipt']['development_floor_source']['floor_reference']
    assert floor['height_world_m'] == 0.  # Exact authored fixture, never inferred.
    trace = {r['walking_session_local_step']:r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id')==session['session_id']}
    assert set(entries) == set(trace) == set(range(1, 401))
    plans = []; maximum_interval_error = maximum_lowering_error = 0.
    for n, entry in entries.items():
        support = entry['native_output']['actuation']['receipt']['recovery_support_plane']
        plan = support['feasible_support_plan']
        pose, wave = cold.algebra.inputs(entry)
        computed = intervals(pose, wave, dimensions)
        saved = plan['ordered_limb_intervals']
        assert len(saved) == 4
        for a,b in zip(computed,saved):
            assert a['limb_id'] == b['limb_id']
            for key in a.keys()-{'limb_id'}:
                error = abs(a[key]-b[key]); maximum_interval_error = max(maximum_interval_error,error)
                assert error < 1e-12  # Existing cold geometry arithmetic allowance.
        common = intersection(saved)
        assert common['minimum_m'] == plan['common_minimum_torso_height_m']
        assert common['maximum_m'] == plan['common_maximum_torso_height_m']
        assert common['nonempty'] == plan['common_height_interval_nonempty']
        assert plan['lowering_permitted'] == (common['nonempty'] and pose[0]>=common['minimum_m'])
        lowering_error = abs(plan['requested_lowering_m']-(pose[0]-plan['requested_stance_torso_height_m']))
        maximum_lowering_error = max(maximum_lowering_error, lowering_error)
        assert lowering_error < 1e-12  # Same existing cold arithmetic allowance.
        phases = {p['limb_id']:p['scheduled_phase_step'] for p in support['ordered_limb_proposals']}
        plans.append(dict(command_local=n, phases=phases, original_plan=plan, intersection=common,
            leave_one_limb_out={limb:intersection([r for r in saved if r['limb_id']!=limb]) for limb in phases},
            stance_only_intersection=intersection([r for r in saved if phases[r['limb_id']]>72])))
    timeline = []
    for row in rows:
        n,limb = row['command_local'],row['limb']; index = tracking.geometry.LIMBS.index(limb)
        entry = entries[n]; request, output = entry['request'],entry['native_output']
        support = output['actuation']['receipt']['recovery_support_plane']
        proposal = support['ordered_limb_proposals'][index]
        phase = proposal['scheduled_phase_step']
        assert phase == row['command_phase'] and proposal['limb_id'] == limb
        contact = request['state']['ordered_contact_observations'][index]
        assert contact['presence'] == contact['bears_support'] == row['native_contact']
        motors = []
        for j in (2*index,2*index+1):
            command = output['actuation']['ordered_commands'][j]
            application = entry['ordered_motor_applications'][j]
            assert application['actuator_id'] == command['actuator_id']
            assert not application['host_additional_clamp_applied']
            assert application['host_applied_target_velocity_rad_s'] == command['target_velocity_rad_s']
            assert struct.unpack('f',struct.pack('f',command['target_velocity_rad_s']))[0] == application['motor_target_velocity_readback_rad_s']
            motors.append(dict(actuator_id=command['actuator_id'], velocity_rad_s=command['target_velocity_rad_s'],
                measured_velocity_rad_s=request['state']['ordered_joint_observations'][j]['velocity_rad_s'],
                saturated=command['velocity_saturated'],cap_rad_s=command['maximum_target_speed_rad_s'],
                full_reference_selected=support['airborne_reference']['ordered_limbs'][index]['full_reference_rate_selected'],
                maximum_impulse_slot_nms=application['motor_maximum_impulse_readback_nms']))
        prior = row['preceding_reference_rad']
        timeline.append(dict(row, phase=phase, pre_contact=row['native_contact'],post_contact=trace[n]['contact_by_limb'][limb],
            nominal_leg_direction_rad=proposal['nominal_leg_direction_rad'],
            link_projection_at_planned_height=proposal['link_reach_projection_required'],
            joint_projection=proposal['support_joint_projection_required'],
            support_reference_height_m=proposal['support_reference_torso_height_m'],
            requested_body_lowering_m=support['feasible_support_plan']['requested_lowering_m'],
            common_height_interval_nonempty=support['feasible_support_plan']['common_height_interval_nonempty'],
            precommand_error_against_preceding_reference_rad=[q-r for q,r in zip(row['measured_joint_rad'],prior)] if prior is not None else None,
            motors=motors))
    per_limb = []
    for limb in tracking.geometry.LIMBS:
        selected = [r for r in timeline if r['limb']==limb]
        phases = {}
        for name,predicate in (('swing',lambda p:p<72),('landing',lambda p:p==72),('stance',lambda p:p>72)):
            phase_rows = [r for r in selected if predicate(r['phase'])]
            absent = [r for r in phase_rows if not r['pre_contact']]
            phases[name] = dict(command_count=len(phase_rows),unsupported_command_count=len(absent),
                unsupported_no_raw_contact_count=sum(r['raw_contact_count']==0 for r in absent),
                unsupported_saturated_joint_commands=sum(m['saturated'] for r in absent for m in r['motors']),
                unsupported_current_pose_unreachable_relaxed_count=sum(r['unrestricted_planar_reach_lower_bound_m']>0 for r in absent),
                unsupported_geometry={key:spread(r[key] for r in absent) for key in (
                    'nominal_actual_bottom_m','ideal_current_reference_bottom_m','ideal_goal_bottom_m',
                    'requested_body_lowering_m','unrestricted_planar_reach_lower_bound_m')},
                unsupported_reference_error_rad={joint:spread(r['precommand_error_against_preceding_reference_rad'][i] for r in absent if r['preceding_reference_rad'] is not None) for i,joint in enumerate(('hip','knee'))})
        per_limb.append(dict(limb=limb,phases=phases,terminal_precommand_sample=selected[-1]))
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    cycles = [dict(limb=p['limb'],**c,decomposition=tracking.decompose(p['limb'],c['liftoff_local_step'],c['touchdown_local_step'],native,bodies,dimensions,axis)) for p in original['per_limb'] for c in p['contact_cycles']]
    conflicts = [p for p in plans if not p['intersection']['nonempty']]
    conflict_pairs = {}
    for p in conflicts:
        key = ','.join(p['intersection']['minimum_owners'])+' / '+','.join(p['intersection']['maximum_owners'])
        conflict_pairs[key] = conflict_pairs.get(key,0)+1
    return dict(command_count=len(entries),limb_command_count=len(timeline),joint_command_count=2*len(timeline),
        original_walking_evaluation=session['evaluation'],original_contact_cycles=cycles,
        original_contact_timing=timing,original_command_audit=audit,original_observation=original,per_limb=per_limb,
        coordinate_conversion_maximum_axis_difference=frame_error,maximum_reconstructed_interval_error_m=maximum_interval_error,
        maximum_lowering_identity_error_m=maximum_lowering_error,
        height_conflicts=dict(count=len(conflicts),windows=windows(p['command_local'] for p in conflicts),
            signed_gap_m=spread(p['intersection']['signed_gap_m'] for p in conflicts),
            minimum_owner_slash_maximum_owner_counts=conflict_pairs,
            stance_only_nonempty_count=sum(p['stance_only_intersection'] is not None and p['stance_only_intersection']['nonempty'] for p in conflicts),
            resolved_by_omitting_each_limb={limb:sum(p['leave_one_limb_out'][limb]['nonempty'] for p in conflicts) for limb in tracking.geometry.LIMBS},
            all_conflicts_disable_lowering=all(not p['original_plan']['lowering_permitted'] and p['original_plan']['requested_lowering_m']==0 for p in conflicts)),
        all_command_height_plans=plans,all_limb_command_timeline=timeline)


def observe():
    path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw = path.read_bytes()
    if digest(raw) != CLOSURE_SHA: raise ValueError('LANDING_REACH_CLOSURE_DRIFT')
    closure = json.loads(raw); report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if digest(report_raw) != REPORT_SHA or len(report_raw)!=closure['kicked_report']['byte_length'] or closure['source_snapshot']['head']!=SOURCE:
        raise ValueError('LANDING_REACH_REPORT_DRIFT')
    return dict(schema_version='sporespore_development_landing_reach_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw)),source_report=closure['kicked_report'],
        frozen_sources=[dict(path=p,source_commit=SOURCE,raw_sha256=digest(subprocess.check_output(['git','show',SOURCE+':'+p],cwd=ROOT))) for p in
            ('sdk/core/src/recovery_support_plane.rs','sdk/core/src/recovery_feasible_support.rs','sdk/core/src/quadruped.rs')],
        analysis_sources=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw)),
        selection_rule='All 400 commands, all 1600 limb samples, every original dwell-qualified cycle and every contact loss. Each original four-limb height plan, all four leave-one-out intersections and the scheduled-stance-only intersection are retained. No outcome-selected fitting window.',
        limits='Constraint omission is diagnostic arithmetic, not permission to drop a supporting foot or a prospective controller. Positive unrestricted reach lower bounds apply only to the fixed measured torso and ideal planar links, not a future pose. Nominal capsule bottom is not native contact truth; reference errors and impulse caps do not establish delivered force. No native body pose is invented for terminal trace 400. Original evaluation and thresholds remain exact.',
        original_evaluation_changed=False,physical_cause_proven=False,alternate_physical_outcome_predicted=False,
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def compact(full, output):
    raw = output.read_bytes()
    return dict(full,diagnosis={k:v for k,v in full['diagnosis'].items() if k not in ('all_command_height_plans','all_limb_command_timeline')},
        complete_diagnosis=dict(path=output.as_posix(),byte_length=len(raw),raw_sha256=digest(raw)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    output=parser.parse_args().output.resolve()
    if not output.is_relative_to(EVIDENCE.resolve()): raise ValueError('LANDING_REACH_DURABLE_OUTPUT_REQUIRED')
    full=observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(compact(full,output),indent=2,allow_nan=False))
