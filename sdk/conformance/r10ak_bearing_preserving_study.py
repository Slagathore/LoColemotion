"""Execute and audit the prospectively declared R10AK geometry-only study.

No native library, solver, replay, source renewal or physical admission is used.
"""
import argparse
import json
import math
from pathlib import Path

import r10aj_hip_recenter_closure as closure
import r10aj_hip_recenter_model as model

G = closure.geometry
CONTRACT = closure.ROOT/'sdk/recovery/r10ak_bearing_preserving_geometry_study_v1.json'
RECORD = closure.ROOT/'sdk/recovery/r10ak_bearing_preserving_geometry_result_v1.json'
VARIANTS = ('preserve_qualified_bearing','preserve_positive_bearing')


def masks(observation):
    qualified = G.qualified_support(observation)
    positive = [c['presence'] is True and c['bears_support'] is True
        and b['ordinary_unilateral_contact'] is True and b['bearing_normal_impulse_ns']>0.
        for c,b in zip(observation['state']['ordered_contact_observations'],
            observation['ordered_foot_bearing_observations'],strict=True)]
    assert all(not q or p for q,p in zip(qualified,positive))
    return dict(zip(VARIANTS,([not b for b in qualified],[not b for b in positive])))


def validate_targets(measured,plan,active):
    targets=plan['targets']
    for j,(source,target) in enumerate(zip(measured,targets,strict=True)):
        limit=1.6 if j%2==0 else 1.1
        assert abs(target)<=limit and abs(target-source)<=4*model.DT+1e-12
        if j%2==1 or not active[j//2]:
            assert target==max(-limit,min(limit,source))


def fixed_body(descriptor,observation,active):
    orientation=observation['state']['base_pose_world']['orientation_xyzw']
    initial=[j['position_rad'] for j in observation['state']['ordered_joint_observations']]
    current=initial[:];updates=0;converged=False
    for _ in range(600):
        plan=model.plan(descriptor,orientation,current,active);validate_targets(current,plan,active)
        if all(not active[i] or plan['desired_hip_angles'][i] is not None
            and abs(current[2*i]-plan['desired_hip_angles'][i])<=1e-12 for i in range(4)):
            converged=True;break
        current=plan['targets'];updates+=1
    final=model.plan(descriptor,orientation,current,active)
    converged=all(not active[i] or final['desired_hip_angles'][i] is not None
        and abs(current[2*i]-final['desired_hip_angles'][i])<=1e-12 for i in range(4))
    return dict(updates=updates,converged_to_bounded_hip_goals=converged,active=active,
        initial_joints=initial,final_joints=current,
        fixed_torso_foot_displacement_m=model.displacement(descriptor,orientation,initial,current),
        final_goal_error_rad=[None if final['desired_hip_angles'][i] is None else
            abs(current[2*i]-final['desired_hip_angles'][i]) for i in range(4)],
        assumptions='Fixed torso, exact joints and frozen mask; no dynamic or contact prediction.')


def derive():
    contract=closure.read(CONTRACT);path=closure.CHILD/'worker_report.json'
    assert closure.bind(path)['raw_sha256']==contract['inputs']['source_report']['raw_sha256']==closure.REPORT_SHA
    for item in contract['dependencies']:
        actual=closure.bind(closure.ROOT/item['path']);actual['path']=item['path'];assert actual==item
    rows=[];probe=None;descriptor=None
    for packet in G.records(path,'r10aj_partial_recovery','step_packets'):
        native=packet['native_receipt'];original=native['next_load_plan']
        if original is None:continue
        observation=native['collection']['observation']
        request=json.loads(packet['call']['request']['utf8_text'])
        current_descriptor=request['collection']['descriptor']
        if descriptor is None:descriptor=current_descriptor
        assert current_descriptor==descriptor
        measured=[j['position_rad'] for j in observation['state']['ordered_joint_observations']]
        orientation=observation['state']['base_pose_world']['orientation_xyzw'];selected=masks(observation)
        result={}
        for name,active in selected.items():
            plan=model.plan(descriptor,orientation,measured,active);validate_targets(measured,plan,active)
            displacement=model.displacement(descriptor,orientation,measured,plan['targets'])
            result[name]=dict(active=active,targets=plan['targets'],
                fixed_torso_foot_dy_m=[v[1] for v in displacement],
                maximum_joint_delta_rad=max(abs(a-b) for a,b in zip(measured,plan['targets'])),
                inactive_leg_target_changes=sum(measured[j]!=plan['targets'][j]
                    for j in range(8) if not active[j//2]),hold_reason=plan['hold_reason'])
        row=dict(semantic_step=observation['semantic_step'],partial_step=native['step']['memory']['total_steps_observed'],
            original_mode=original['mode'],variants=result)
        assert row['partial_step']==len(rows)+1
        rows.append(row)
        active=selected[VARIANTS[0]]
        if probe is None and native['step']['memory']['phase']=='raise_body' and any(active) and not all(active):
            probe=dict(partial_step=row['partial_step'],semantic_step=row['semantic_step'],
                variants={name:fixed_body(descriptor,observation,mask) for name,mask in selected.items()})
    assert len(rows)==600 and probe is not None
    summary={}
    for name in VARIANTS:
        values=[r['variants'][name] for r in rows]
        summary[name]=dict(samples=600,all_inactive_samples=sum(not any(v['active']) for v in values),
            active_foot_proposals=sum(sum(v['active']) for v in values),
            active_non_downward_proposals=sum(v['fixed_torso_foot_dy_m'][i]>=0
                for v in values for i in range(4) if v['active'][i]),
            inactive_leg_target_changes=sum(v['inactive_leg_target_changes'] for v in values),
            maximum_joint_delta_rad=max(v['maximum_joint_delta_rad'] for v in values))
    return dict(schema_version='sporespore_r10ak_bearing_preserving_geometry_result_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',
            authority_mode='retained_input_model_result',question_class='development'),
        auditor=closure.bind(__file__),contract=closure.bind(CONTRACT),
        dependencies=[closure.bind(p) for p in (Path(model.__file__),Path(G.__file__),Path(model.vectors.__file__))],
        source_report=closure.bind(path),source_commit=closure.HEAD,
        original_result_regraded=False,exposed_samples=600,summary=summary,
        mask_disagreement_samples=sum(r['variants'][VARIANTS[0]]['active']!=r['variants'][VARIANTS[1]]['active'] for r in rows),
        fixed_body_probe=probe,rows=rows,
        conclusion='These masked proposals preserve bearing-leg target positions on exposed inputs. '
            'The fixed-body probe supplies geometric headroom only. Native body motion, contact loss and '
            'posture-feedback behavior remain unmodeled; no physical controller is selected.',
        **contract['claim_boundary'])


def audit():
    record=closure.read(RECORD);assert record==derive()
    return dict(ok=True,exposed_samples=600,summary=record['summary'],
        mask_disagreement_samples=record['mask_disagreement_samples'],
        fixed_body_probe=record['fixed_body_probe'],controller_selected=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    if args.create:closure.write_new(RECORD,derive())
    print(json.dumps(audit(),indent=2))
