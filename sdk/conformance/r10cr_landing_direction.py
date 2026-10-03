"""Supported landing-direction diagnosis at the completed placement endpoint.

Three declared descent-permission variants retain every original floor witness,
the achieved horizontal placement, fixed contact modes and zero unloaded force.
This checks instantaneous feasibility only; it creates no path or new contact.
"""
import argparse
import json
import subprocess
import numpy as np
import r10cq_goal_safe_placement_path as P

C,S,I,T,L,Z,H=P.C,P.S,P.I,P.T,P.L,P.Z,P.H
STUDY=C.ROOT/'sdk/recovery/r10cr_landing_direction_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cr_landing_direction_result_v1.json'
VARIANTS=('no_descent','right_rear_only','all_inactive')


def target_index(model):
    indices=[i for i,p in enumerate(model.contacts) if p['body_id']=='rear_right_distal' and p['classified_as_foot']]
    assert len(indices)==1
    return indices[0]


def released_indices(modes,target,variant):
    assert variant in VARIANTS and modes[target]==0
    if variant=='no_descent':return []
    if variant=='right_rear_only':return [target]
    return [i for i,mode in enumerate(modes) if mode==0]


def signed_placement(model,delta,heading):
    return float((H.rear_centers(model,delta)[1]-model.com(model.poses(delta)))@heading+H.MARGIN)


def signed_placement_gradient(model,heading):
    zero=np.zeros(14);poses=model.poses(zero)
    _,jacobian,_,_,_=S.statics.frame(model.packet,model.d,model.com(poses))
    com_j=sum(state['mass_kg']*jacobian(state['body_id'],model.point(poses,state['body_id'],model.local_com[state['body_id']])) for state in model.states)/model.mass
    foot_j=jacobian('rear_right_distal',model.point(poses,'rear_right_distal',model.local_caps['rear_right']))
    return heading@(foot_j-com_j)


def problem(model,modes,heading,variant):
    zero=np.zeros(14);target=target_index(model);released=released_indices(modes,target,variant)
    material=I.material_jacobian(model);floor=model.features_y(zero);fj=P.floor_jacobian(model)
    equality=[];inequality=list(-fj);rhs=list(floor-np.minimum(0.,floor))
    for i,mode in enumerate(modes):
        if i not in released:inequality.append(-material[i,1]);rhs.append(0.)
        if mode:
            equality.append(material[i,1])
            if mode==1:equality.extend((material[i,0],material[i,2]))
            else:
                axis,sign=Z.MODES[mode]
                for other in (-1.,1.):inequality.append(other*material[i,2-axis]-sign*material[i,axis]);rhs.append(0.)
    # The descending cap must stay above the world floor, while its signed
    # horizontal placement margin remains nonpositive. These rows are separate
    # from all existing shape-floor witnesses.
    inequality.append(-material[target,1]);rhs.append(float(model.contact_points(zero)[target,1]))
    inequality.append(signed_placement_gradient(model,heading));rhs.append(-signed_placement(model,zero,heading))
    a=np.array(equality).reshape((-1,14));u=np.array(inequality);v=np.array(rhs);cost=material[target,1].copy()
    a*=S.MAXIMUM;u*=S.MAXIMUM;cost*=S.MAXIMUM
    a/=np.maximum(np.max(np.abs(a),axis=1),1e-12)[:,None]
    scales=np.maximum(np.max(np.abs(u),axis=1),1e-12);u/=scales[:,None];v/=scales
    lo,hi=S.bounds(model.joints)
    return dict(cost=cost.tolist(),equality=a.tolist(),equality_rhs=np.zeros(len(a)).tolist(),inequality=u.tolist(),inequality_rhs=v.tolist(),
        bounds=list(map(list,zip(lo/S.MAXIMUM,hi/S.MAXIMUM)))),released


def direction_check(model,modes,caps,direction):
    zero=np.zeros(14);load=Z.load(model,zero,modes,caps);material=I.material_jacobian(model)@direction;checks=[]
    if not load['feasible']:return dict(admitted=False,load=load,material=material.tolist(),work_checks=[])
    forces=np.array(load['forces_world_n'])
    for i,mode in enumerate(modes):
        work=float(forces[i]@material[i]);minimum=-Z.X.MU*forces[i,1]*float(np.max(np.abs(material[i,[0,2]]))) if mode>=2 else 0.
        valid=np.max(np.abs(forces[i]))<=1e-6 if mode==0 else Z.work_allowed(work,minimum)
        if mode==1:valid=valid and np.max(np.abs(material[i]))<=1e-9
        if mode>=2:
            axis,sign=Z.MODES[mode];valid=valid and abs(material[i,1])<=1e-9 and abs(material[i,2-axis])-sign*material[i,axis]<=1e-9
        checks.append(dict(contact=i,mode=mode,work_j=work,minimum_work_j=minimum,ok=bool(valid)))
    return dict(admitted=all(row['ok'] for row in checks),load=load,material=material.tolist(),work_checks=checks)


def reconstruct():
    model,lift,replay,caps=P.reconstruct();previous=C.read(P.RESULT);assert T.snapshot(model)==previous['initial']
    assert previous['summary']['placement_target_reached'] is True
    for row in previous['trajectory']:
        assert row['admitted'] and T.snapshot(model)==row['before']
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));assert T.snapshot(model)==row['after']
    assert len(previous['trajectory'])==24 and T.snapshot(model)==previous['final']
    heading=np.array(lift['initial']['torso_basis_columns'])[0].copy();heading[1]=0.;heading/=np.linalg.norm(heading)
    return model,previous,replay,caps,heading


def controls():
    checked=P.controls();modes=[1,0,2,0]
    assert released_indices(modes,3,'no_descent')==[]
    assert released_indices(modes,3,'right_rear_only')==[3]
    assert released_indices(modes,3,'all_inactive')==[1,3]
    try:released_indices(modes,2,'all_inactive')
    except AssertionError:pass
    else:raise AssertionError('loaded target released')
    heading=np.array([1.,0.,0.]);shared=np.c_[np.eye(3),np.zeros((3,11))];foot=shared.copy();foot[0,6]=2.
    gradient=heading@(foot-shared)
    assert np.all(gradient[:3]==0.) and gradient[6]==2.
    checked['additional_descent_permission_loaded_exclusion_and_relative_gradient_controls']=5
    return checked


def declare():
    prior=C.read(P.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10cr_landing_direction_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_unloaded_foot_landing_direction_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='At the completed right-rear placement endpoint, which declared unloaded-contact descent permissions admit a supported downward direction while preserving horizontal placement?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,__file__]],
        population=dict(prior['population'],coverage='One exactly reconstructed admitted R10CQ endpoint; three fixed-mode instantaneous direction variants. No new integration or contact.'),
        variants=list(VARIANTS),
        design=dict(start='Replay only the69 admitted lift increments and24 admitted placement increments, requiring every saved snapshot. Retain original global heading and exact fixed mode vector.',
            permissions='Baseline retains all-contact non-descent. Right-rear-only releases only the unloaded right-rear cap normal row. All-inactive releases only mode0 normal rows. Every loaded normal/tangential/sector row and every shape-floor row remains unchanged; no new support is assigned.',
            objective='Minimize right-rear cap height rate, then minimize half squared normalized motion at95% of the certified maximum descent. Use the unchanged primary portfolio and R10CM full original QP certificate, including its declared redundant-row preprocessing.',
            extra_guards='Add cap-above-world-floor and signed horizontal cap/COM placement <=0 linear rows. Keep original rate/headroom bounds. Check analytic height and signed relative-placement gradients against finite differences at the one endpoint.',
            force='Independently certify stationary load/actuator/friction limits in the same fixed modes, including zero right-rear support, then check material sticking/sliding and friction work for each candidate direction.',
            boundary='Instantaneous tangent feasibility only. No finite descent, landing, contact acquisition, load transfer, controller selection, native world or release authority. Preserve all variants, including zero-progress or refused results, and complete cold replay.'),
        numerics=dict(prior['numerics'],progress_fraction=.95),checks=['231 inherited plus5 descent-permission and relative-gradient controls;236 with shared coverage.','Exact endpoint reconstruction, analytic/FD gradients, original full certificates and independent load/work checks; full cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();model,previous,replay,caps,heading=reconstruct();modes=previous['summary']['selected_modes'];zero=np.zeros(14);target=target_index(model)
    material=I.material_jacobian(model);height_error=float(np.max(np.abs(material[target,1]-S.derivative(lambda q:model.contact_points(q)[target,1],zero))))
    placement_error=float(np.max(np.abs(signed_placement_gradient(model,heading)-S.derivative(lambda q:signed_placement(model,q,heading),zero))))
    assert height_error<=1e-7 and placement_error<=1e-7 and signed_placement(model,zero,heading)<=1e-9
    rows=[]
    for variant in VARIANTS:
        p,released=problem(model,modes,heading,variant);result=P.solve_problem(p,.95);check=None;descent=None
        if result['accepted']:
            direction=np.array(result['normalized_velocity'])*S.MAXIMUM;check=direction_check(model,modes,caps,direction);descent=-float(material[target,1]@direction)
        rows.append(dict(variant=variant,released_contact_indices=released,problem=p,result=result,physical_check=check,descent_m_per_interval=descent,
            supported_positive_descent=bool(result['accepted'] and check['admitted'] and descent>1e-12)))
    summary=dict(variant_count=3,cases=[dict(variant=r['variant'],certified=r['result']['accepted'],supported_positive_descent=r['supported_positive_descent'],descent_m_per_interval=r['descent_m_per_interval']) for r in rows],new_model_increments=0)
    return dict(schema_version='sporespore_r10cr_landing_direction_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,
        entry_contact_replay=replay,initial=T.snapshot(model),heading=heading.tolist(),selected_modes=modes,right_rear_contact_index=target,
        height_gradient_comparison_error=height_error,placement_gradient_comparison_error=placement_error,cases=rows,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CR prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result);print(json.dumps(P.L.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(P.L.present(result,True),indent=2))
