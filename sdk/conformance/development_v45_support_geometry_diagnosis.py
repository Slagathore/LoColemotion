"""Retained V45 target geometry in its measured pose, independently of contact."""
import json
import math
from pathlib import Path
import hashlib

ROOT=Path(__file__).resolve().parents[2]
ATTEMPT='49005121a2194522a9e4a080f186750b'
TRAJECTORY_SHA='sha256:b493c6798b6fe63def463f7fb3e401af4efb185d3221674a81f5f03ca934d816'
LIMBS=('front_left','front_right','rear_left','rear_right')

def require(value,code):
    if not value:raise ValueError('V45_GEOMETRY_'+code)

def read_source():
    root=ROOT.parent/'SporeSpore_Evidence'/('development-v45-mujoco-closed-loop-'+ATTEMPT)
    raw=(root/'trajectory.jsonl').read_bytes()
    require('sha256:'+hashlib.sha256(raw).hexdigest()==TRAJECTORY_SHA,'SOURCE_DIGEST')
    rows=[json.loads(line) for line in raw.splitlines()]
    value=json.loads((root/'input.json').read_text(encoding='utf-8'))
    require(len(rows)==399,'POPULATION');return rows,value

def rotate_y_projections(q):
    scale=1/(q['x']**2+q['y']**2+q['z']**2+q['w']**2)
    return (2*(q['y']*q['z']-q['w']*q['x'])*scale,
        1-2*(q['x']**2+q['z']**2)*scale,-2*(q['x']*q['y']+q['w']*q['z'])*scale)

def bottom(state,descriptor,limb,hip,knee):
    upper=.35*descriptor['upper_length_fraction'];lower=.35-upper;radius=.04*descriptor['foot_radius_scale'];span=descriptor['hip_span_scale']
    forward,up,side=rotate_y_projections(state['base_pose_world']['orientation_xyzw'])
    anchor=(.2 if limb.startswith('front') else -.2)*span*forward+(-.18 if limb.endswith('left') else .18)*span*side
    return state['base_pose_world']['position_m']['y']+anchor+forward*(upper*math.sin(hip)+lower/2*math.sin(hip+knee))-up*(upper*math.cos(hip)+lower/2*math.cos(hip+knee))-abs(up*math.cos(hip+knee)-forward*math.sin(hip+knee))*lower/2-radius

def analyze(rows,value):
    descriptor=value['descriptor'];samples=[];release=[];max_fk_error=0.
    for n,row in enumerate(rows,1):
        require(row['command']==n,'CLOCK');state=row['request']['state']
        require(state['semantic_step']==n,'STATE_CLOCK')
        support=row['output']['actuation']['receipt']['recovery_support_plane'];transfer=support['measured_support_transfer']
        if transfer['preparation_released_this_command']:
            release.append(dict(command=n,limb=transfer['planned_swing_limb_id'],margin_m=transfer['remaining_triangle_margin_m'],speed_m_s=transfer['measurement']['horizontal_com_speed_m_s']))
        upright=support['upright_stance'];bodies={b['body_id']:b for b in row['request']['measured_body_frame']['ordered_body_states']}
        lower=.35*(1-descriptor['upper_length_fraction']);radius=.04*descriptor['foot_radius_scale']
        for i,limb in enumerate(LIMBS):
            require(support['ordered_limb_proposals'][i]['limb_id']==limb,'LIMB_ORDER')
            body=bodies[limb+'_distal'];up=rotate_y_projections(body['pose_world']['orientation_xyzw'])[1]
            measured_bottom=body['pose_world']['position_m']['y']-abs(up)*lower/2-radius
            h,k=state['ordered_joint_observations'][2*i:2*i+2]
            require(h['joint_id']==limb+'_hip' and k['joint_id']==limb+'_knee','JOINT_ORDER')
            fk=bottom(state,descriptor,limb,h['position_rad'],k['position_rad'])
            error=abs(measured_bottom-fk);max_fk_error=max(max_fk_error,error)
            require(error<1e-12,'NATIVE_FK_CROSSCHECK')
            target=support['ordered_limb_proposals'][i];baseline=upright['measured_pose_baseline_proposals'][i]
            samples.append(dict(command=n,limb=limb,selected_phase=transfer['effective_selected_phases'][i],
                precommand_bearing=state['ordered_contact_observations'][i]['bears_support'],held=transfer['effective_phase_progression_held'],
                measured_bottom_m=measured_bottom,selected_target_bottom_in_measured_pose_m=bottom(state,descriptor,limb,target['goal_hip_rad'],target['goal_knee_rad']),
                measured_pose_support_target_bottom_m=bottom(state,descriptor,limb,baseline['projected_support_hip_rad'],baseline['projected_support_knee_rad']),
                selected_reference_assumes_upright=upright['ordered_limbs'][i]['upright_reference_selected'],
                selected_common_lowering_m=upright['floor_upright_reference_plan']['requested_lowering_m'],
                measured_reference_common_lowering_m=upright['measured_pose_baseline_plan']['requested_lowering_m']))
    stance=[s for s in samples if s['selected_phase']>72];absent=[s for s in stance if not s['precommand_bearing']]
    lifted=[s for s in absent if s['selected_target_bottom_in_measured_pose_m']>1e-6]
    return dict(schema_version='sporespore_v45_retained_support_geometry_diagnosis_v1',source_trajectory_sha256=TRAJECTORY_SHA,
        precommand_count=len(rows),limb_samples=len(samples),maximum_native_fk_bottom_error_m=max_fk_error,releases=release,
        absent_stance_inputs=len(absent),absent_stance_with_selected_target_above_floor=len(lifted),
        absent_stance_with_selected_target_above_floor_and_zero_measured_reference_lowering=sum(s['measured_reference_common_lowering_m']==0 for s in lifted),
        maximum_absent_stance_selected_target_gap_m=max(s['selected_target_bottom_in_measured_pose_m'] for s in absent),
        all_samples=samples,geometry_is_contact_authority=False,causal_attribution_proven=False,
        new_world_count=0,new_solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
