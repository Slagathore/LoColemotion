"""Finite tangent diagnosis of right-rear knee headroom during ground approach.

Keep every original constraint; compare the original knee bounds with zero knee
velocity. This is primary-LP feasibility, not a replacement path selector.
"""
import argparse
import copy
import json
import subprocess
import numpy as np
import r10cs_ground_approach_path as P

R,C,S,I,T=P.R,P.C,P.S,P.I,P.T
STUDY=C.ROOT/'sdk/recovery/r10ct_landing_headroom_diagnosis_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10ct_landing_headroom_diagnosis_result_v1.json'
VARIANTS=('original_bounds','right_rear_knee_fixed')


def restrict(problem,variant):
    assert variant in VARIANTS
    value=copy.deepcopy(problem)
    if variant=='right_rear_knee_fixed':
        lower,upper=value['bounds'][13]
        assert lower<=0.<=upper
        value['bounds'][13]=[0.,0.]
    return value


def primary(problem):
    cost,a,b,u,v=[np.array(problem[key]) for key in ('cost','equality','equality_rhs','inequality','inequality_rhs')]
    try:
        x,certificate=R.P.F.E.W.certified_lp('landing_headroom_primary_diagnosis',cost,a,b,u,v,problem['bounds'])
    except P.VelocityRefusal as failure:
        return dict(accepted=False,refusal=failure.record)
    return dict(accepted=True,normalized_velocity=x.tolist(),certificate=certificate)


def controls():
    checked=P.controls()
    fixture=dict(cost=[0.]*13+[-1.],equality=[([0.]*14)],equality_rhs=[0.],inequality=[([0.]*14)],inequality_rhs=[1.],bounds=[[-1.,1.] for _ in range(14)])
    before=copy.deepcopy(fixture);frozen=restrict(fixture,VARIANTS[1])
    assert fixture==before and frozen['bounds'][:13]==fixture['bounds'][:13] and frozen['bounds'][13]==[0.,0.]
    assert restrict(fixture,VARIANTS[0])==fixture
    moving=primary(fixture);stationary=primary(frozen)
    assert moving['accepted'] and moving['certificate']['primal_objective']==-1.
    assert stationary['accepted'] and stationary['certificate']['primal_objective']==0. and stationary['normalized_velocity'][13]==0.
    checked['additional_knee_restriction_nonmutation_original_identity_and_known_optima_controls']=4
    return checked


def declare():
    prior=C.read(P.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10ct_landing_headroom_diagnosis_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_finite_knee_headroom_tangent_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does certified positive instantaneous descent remain when right-rear knee velocity is fixed to zero at approach entry, last admitted pose and the unadmitted failed solver probe?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,__file__]],
        population=dict(prior['population'],coverage='Three exact exposed model poses crossed with two bound variants; six primary LPs. The failed probe remains unadmitted and is never propagated into a path.'),
        variants=list(VARIANTS),
        design=dict(reconstruction='Replay R10CQ and the eight admitted R10CS deltas with exact saved snapshots. Reconstruct the failed probe separately from the last admitted pose using its retained delta.',
            bounds='Original R10CR right-rear-only problem versus only coordinate13 bound replaced by[0,0]. All floor, placement, material contact, friction-sector, speed and headroom constraints remain; no limit relaxation.',
            numerics='Unchanged certified primary LP portfolio and complete original certificate <=1e-6. Do not solve or replace the secondary QP, integrate motion, add contact, or use a primary direction as an adopted controller.',
            force='Independently check original fixed-mode stationary load, zero target-foot force, material sticking/sliding and friction work for each direction. Report cap height, knee angle/headroom and descent rate.',
            interpretation='Positive tangent with zero knee motion rules out immediate knee-only tangent blockage at that one pose. It does not prove any finite landing route, rate away from the pose, new support, native execution or eventual recovery.',
            retention='Retain all six original problems and primary certificates, including refusals. Complete cold replay; preserve the original failed QP and R10CS outcome unchanged.'),
        numerics=prior['numerics'],checks=['239 inherited plus4 bound isolation and manufactured optimum checks.','Exact snapshot reconstruction and six full original primary certificates/load checks; complete cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();model,_,replay,caps,heading=R.reconstruct();previous=C.read(P.RESULT)
    assert T.snapshot(model)==previous['initial']
    poses=[('approach_entry',model,True)]
    for row in previous['trajectory']:
        assert T.snapshot(model)==row['before']
        if not row['admitted']:break
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));assert T.snapshot(model)==row['after']
    assert T.snapshot(model)==previous['final'] and previous['summary']['accepted_additional_increments']==8
    failed=previous['trajectory'][-1];assert not failed['admitted']
    poses.append(('last_admitted_approach_pose',model,True))
    poses.append(('unadmitted_failed_solver_probe',I.advance(model,np.array(failed['last_integration_probe']['delta'])),False))
    modes=previous['summary']['selected_modes'];rows=[]
    for name,pose,admitted in poses:
        base,_=R.problem(pose,modes,heading,'right_rear_only');zero=np.zeros(14)
        for variant in VARIANTS:
            p=restrict(base,variant);answer=primary(p);check=None;descent=None
            if answer['accepted']:
                velocity=np.array(answer['normalized_velocity'])*S.MAXIMUM
                check=R.direction_check(pose,modes,caps,velocity);descent=-float(np.array(p['cost'])@answer['normalized_velocity'])
                if variant==VARIANTS[1]:assert abs(velocity[13])<=1e-12
            if name=='unadmitted_failed_solver_probe' and variant==VARIANTS[0]:
                saved=failed['velocity_refusal']['diagnostic']
                assert answer['certificate']==saved['primary_certificate'] and answer['normalized_velocity']==saved['primary_solution']
            rows.append(dict(pose=name,original_path_pose_admitted=admitted,variant=variant,snapshot=T.snapshot(pose),
                cap_height_m=float(pose.contact_points(zero)[R.target_index(pose),1]),right_rear_knee_rad=float(pose.joints[7]),
                right_rear_knee_headroom_rad=float(S.LIMITS[7]-.02-abs(pose.joints[7])),problem=p,result=answer,
                physical_check=check,descent_m_per_interval=descent,supported_positive_tangent=bool(answer['accepted'] and check['admitted'] and descent>1e-12)))
    summary=dict(pose_count=3,case_count=6,certified_cases=sum(row['result']['accepted'] for row in rows),
        supported_positive_tangents=sum(row['supported_positive_tangent'] for row in rows),
        cases=[{k:row[k] for k in ('pose','variant','descent_m_per_interval','supported_positive_tangent','right_rear_knee_headroom_rad')} for row in rows],
        new_model_increments=0,original_failed_probe_admitted=False,landing_proven=False)
    return dict(schema_version='sporespore_r10ct_landing_headroom_diagnosis_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,entry_contact_replay=replay,cases=rows,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CT prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:
            assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result)
        else:result=C.read(RESULT);assert result==derive()
        print(json.dumps(dict(ok=True,cold_replay=not args.create,summary=result['summary']),indent=2))
