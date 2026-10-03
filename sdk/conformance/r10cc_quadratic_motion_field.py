"""Prospective squared-motion selector and local field diagnosis after R10CB.

The primary progress requirement and all feasible-motion constraints survive.
The secondary objective becomes one half the squared normalized velocity norm.
Every answer needs a full original-problem convex-QP certificate. No integration
or native motion occurs in this diagnostic.
"""
import argparse
import copy
import json
import subprocess
from types import SimpleNamespace
import numpy as np
from scipy.optimize import minimize

import r10cb_right_rear_placement as B

C,S,I,T,L,W = B.C,B.S,B.I,B.T,B.L,B.W
K=W.K
STUDY=C.ROOT/'sdk/recovery/r10cc_quadratic_motion_field_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cc_quadratic_motion_field_result_v1.json'
QP_OPTIONS=dict(maxiter=200,ftol=1e-12,disp=False)
SCALES=(1e-8,1e-6)


def certificate(x,multipliers,a,b,u,v,bounds,sides):
    eq=multipliers[:len(a)];inequality=-multipliers[len(a):len(a)+len(u)]
    lower=np.zeros(len(x));upper=np.zeros(len(x))
    for value,(index,side) in zip(multipliers[len(a)+len(u):],sides,strict=True):
        if side=='lower':lower[index]=value
        else:upper[index]=-value
    mapped=SimpleNamespace(x=x,eqlin=SimpleNamespace(marginals=eq),ineqlin=SimpleNamespace(marginals=inequality),
        lower=SimpleNamespace(marginals=lower),upper=SimpleNamespace(marginals=upper))
    # The linear auditor checks stationarity with c=gradient f(x)=x, plus all
    # original primal rows, bounds, dual signs and complementary slackness.
    record,detail=K.certify(mapped,x,a,b,u,v,bounds)
    linearized_gap=record['objective_gap'];linearized_dual=record['dual_objective']
    dual_gradient=a.T@eq+u.T@inequality+lower+upper
    primal=.5*float(x@x);dual=linearized_dual-.5*float(dual_gradient@dual_gradient)
    record.update(primal_objective=primal,dual_objective=dual,objective_gap=abs(primal-dual),
        linearized_objective_gap=linearized_gap,objective='half_squared_normalized_velocity')
    checks=('primal_max_residual','stationarity_max_residual','dual_sign_violation',
        'complementarity_max_residual','unbounded_dual_max_residual','objective_gap')
    record['accepted']=all(np.isfinite(record[k]) and record[k]<=K.CERT for k in checks)
    return record,detail


def solve_qp(a,b,u,v,bounds,start):
    rows=list(u);limits=list(v);sides=[]
    for i,(lower,upper) in enumerate(bounds):
        if lower is not None:rows.append(-np.eye(len(start))[i]);limits.append(-lower);sides.append((i,'lower'))
        if upper is not None:rows.append(np.eye(len(start))[i]);limits.append(upper);sides.append((i,'upper'))
    full_u=np.array(rows).reshape((-1,len(start)));full_v=np.array(limits)
    constraints=[]
    if len(a):constraints.append(dict(type='eq',fun=lambda x:a@x-b,jac=lambda x:a))
    if len(full_u):constraints.append(dict(type='ineq',fun=lambda x:full_v-full_u@x,jac=lambda x:-full_u))
    result=minimize(lambda x:.5*float(x@x),np.array(start),jac=lambda x:x,method='SLSQP',constraints=constraints,options=QP_OPTIONS)
    record=dict(success=bool(result.success),status=int(result.status),message=result.message,iterations=int(result.nit),
        solution=[float(x) if np.isfinite(x) else None for x in result.x],
        multipliers=[float(x) if np.isfinite(x) else None for x in np.asarray(getattr(result,'multipliers',[]))],certificate=None,detail=None,accepted=False)
    if len(record['multipliers'])==len(a)+len(full_u) and all(x is not None for x in record['multipliers']) and np.all(np.isfinite(result.x)):
        record['certificate'],record['detail']=certificate(result.x,np.array(record['multipliers']),a,b,u,v,bounds,sides)
        record['accepted']=bool(result.success and record['certificate']['accepted'])
    return record


def problem(model,modes,heading):
    # Exact R10CB primary construction, without its secondary L1 epigraph.
    zero=np.zeros(14);j=I.material_jacobian(model);floor=model.features_y(zero);fj=B.floor_jacobian(model)
    equality=[];inequality=list(-fj);rhs=list(floor-np.minimum(0.,floor))
    for i,mode in enumerate(modes):
        inequality.append(-j[i,1]);rhs.append(0.)
        if mode:
            equality.append(j[i,1])
            if mode==1:equality.extend((j[i,0],j[i,2]))
            else:
                axis,sign=B.Z.MODES[mode]
                for other in (-1.,1.):inequality.append(other*j[i,2-axis]-sign*j[i,axis]);rhs.append(0.)
    a=np.array(equality).reshape((-1,14));u=np.array(inequality);v=np.array(rhs)
    lo,hi=S.bounds(model.joints);cost=B.placement_gradient(model,heading)
    a=a*S.MAXIMUM;u=u*S.MAXIMUM;cost=cost*S.MAXIMUM
    a/=np.maximum(np.max(np.abs(a),axis=1),1e-12)[:,None]
    norm=np.maximum(np.max(np.abs(u),axis=1),1e-12);u/=norm[:,None];v/=norm
    return dict(cost=cost.tolist(),equality=a.tolist(),equality_rhs=np.zeros(len(a)).tolist(),
        inequality=u.tolist(),inequality_rhs=v.tolist(),bounds=list(map(list,zip(lo/S.MAXIMUM,hi/S.MAXIMUM))))


def quadratic_direction(p):
    cost,a,b,u,v=[np.array(p[key]) for key in ('cost','equality','equality_rhs','inequality','inequality_rhs')]
    bounds=p['bounds'];record=dict(accepted=False,primary_certificate=None,quadratic_problem=None,quadratic_result=None,refusal=None)
    try:first_x,first=W.certified_lp('primary_placement_cost_reduction',cost,a,b,u,v,bounds)
    except L.VelocityRefusal as failure:record['refusal']=failure.record;return record
    bound=.99*first['primal_objective'];scale=max(float(np.max(np.abs(cost))),abs(bound),1e-12)
    u2=np.vstack((u,cost/scale));v2=np.r_[v,bound/scale]
    record.update(primary_solution=first_x.tolist(),primary_certificate=first,
        quadratic_problem=dict(equality=a.tolist(),equality_rhs=b.tolist(),inequality=u2.tolist(),inequality_rhs=v2.tolist(),bounds=bounds,start=first_x.tolist()))
    answer=solve_qp(a,b,u2,v2,bounds,first_x);record['quadratic_result']=answer
    if answer['accepted']:
        x=np.array(answer['solution']);record.update(accepted=True,normalized_velocity=x.tolist(),velocity=(x*S.MAXIMUM).tolist(),
            achieved_progress_fraction=float(cost@x)/first['primal_objective'])
    return record


def velocity(model,modes,heading):
    record=quadratic_direction(problem(model,modes,heading))
    if not record['accepted']:raise L.VelocityRefusal(dict(stage='quadratic_normalized_motion',diagnostic=record))
    return np.array(record['velocity']),dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=record['quadratic_result']['certificate'])


def controls():
    checked=B.controls();a=np.array([[1.,1.]]);b=np.array([1.]);u=np.zeros((0,2));v=np.zeros(0)
    first=solve_qp(a,b,u,v,[(0.,1.),(0.,1.)],np.array([1.,0.]))
    assert first['accepted'] and np.max(np.abs(np.array(first['solution'])-.5))<1e-10
    lower=solve_qp(a,b,u,v,[(.8,1.),(0.,1.)],np.array([1.,0.]))
    assert lower['accepted'] and np.max(np.abs(np.array(lower['solution'])-[.8,.2]))<1e-10
    upper=solve_qp(np.array([[0.,1.]]),np.array([0.]),u,v,[(None,-.7),(None,None)],np.array([-.7,0.]))
    assert upper['accepted'] and abs(upper['certificate']['primal_objective']-.245)<1e-10
    bad=solve_qp(a,b,u,v,[(1.,2.),(1.,2.)],np.array([1.,1.]))
    assert not bad['accepted']
    # Reject both a corrupted dual and a primal point outside the original
    # constraints, regardless of any optimizer-success flag.
    sides=[(0,'lower'),(0,'upper'),(1,'lower'),(1,'upper')]
    multipliers=np.array(first['multipliers']);multipliers[0]+=.1
    assert not certificate(np.array(first['solution']),multipliers,a,b,u,v,[(0.,1.),(0.,1.)],sides)[0]['accepted']
    assert not certificate(np.array([.8,.8]),np.array(first['multipliers']),a,b,u,v,[(0.,1.),(0.,1.)],sides)[0]['accepted']
    assert abs(first['certificate']['primal_objective']-.25)<1e-10
    assert abs(first['certificate']['dual_objective']-.25)<1e-10
    checked['additional_quadratic_known_answer_bound_dual_infeasible_and_corruption_controls']=8
    return checked


def reconstruct():
    model,lift,replay,caps=B.reconstruct();retained=C.read(B.RESULT);assert T.snapshot(model)==retained['initial']
    entry=model;accepted=0
    for row in retained['trajectory']:
        assert T.snapshot(model)==row['before']
        if not row['admitted']:break
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));accepted+=1
        assert T.snapshot(model)==row['after']
    assert accepted==5 and T.snapshot(model)==retained['final']
    assert row['additional_model_step']==6 and row['refusal']=='integrator_rhs_budget'
    heading=np.array(lift['initial']['torso_basis_columns'])[0].copy();heading[1]=0.;heading/=np.linalg.norm(heading)
    return entry,model,retained,replay,heading


def probes():
    return [dict(name='phase_entry',coordinate=None,sign=0,scale=0.),dict(name='last_admitted',coordinate=None,sign=0,scale=0.),
        dict(name='budget_probe',coordinate=None,sign=0,scale=0.)]+[
        dict(name='near_budget_probe',coordinate=i,sign=sign,scale=scale) for scale in SCALES for i in range(14) for sign in (-1,1)]


def declare():
    prior=C.read(B.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10cc_quadratic_motion_field_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_quadratic_secondary_local_field_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does a strictly convex squared-motion secondary certify and reduce observed local direction sensitivity near the retained R10CB integration refusal?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [B.__file__,B.STUDY,B.RESULT,__file__]],population=prior['population'],
        design=dict(inputs='Exact phase entry, last admitted pose, retained unevaluated budget-refusal probe, and14 coordinates times2 signs times2 normalized scales:59 poses. Replay admitted deltas only; no integration.',
            original='Run unchanged R10CB primary/secondary portfolio at each pose, retain every refusal and direction. This does not regrade the old result or admit the original untested probe.',
            changed='Same primary geometry/normal/work-sector/rate/headroom constraints and99% certified progress. Replace only secondary L1 velocity norm with half squared Euclidean norm of the14 normalized velocities. No constraint deletion or equality projection.',
            optimizer='SLSQP maxiter200 ftol1e-12 with exact gradient and linear Jacobians, initialized at certified primary solution. Convert every finite variable bound to a linear inequality so all multipliers are returned; no retry or alternative QP backend.',
            certificate='Map equality/inequality/bound multipliers to the original problem. Check full primal feasibility, stationarity with gradient=x, dual signs, complementarity, zero unbounded-side duals, and convex QP primal-dual objective gap, all <=1e-6. Solver success alone is insufficient.',
            boundary='Finite exposed local-field comparison, not continuity proof, a path, native actuation or recovery. Full cold replay of all statuses and certificates.'),
        numerics=dict(numpy=np.__version__,scipy=S.statics.scipy.__version__,qp_options=QP_OPTIONS,certificate_tolerance=K.CERT,perturbation_scales=list(SCALES)),
        checks=['180 inherited plus8 QP known-answer, bound-dual, infeasibility and corrupted-certificate controls; shared coverage.','All59 point results retained with independent original-problem certificates and complete cold replay.'],
        research_sources=prior['research_sources']+[dict(url='https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.minimize-slsqp.html',use='Installed-version SLSQP options and multiplier ordering; bounds explicitly expanded because ordinary bound multipliers are omitted.')],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();entry,last,previous,replay,heading=reconstruct();modes=previous['summary']['selected_modes']
    center=np.array(previous['trajectory'][-1]['last_integration_probe']['delta']);rows=[]
    for specification in probes():
        if specification['name']=='phase_entry':model=entry;delta=np.zeros(14)
        elif specification['name']=='last_admitted':model=last;delta=np.zeros(14)
        else:
            delta=center.copy()
            if specification['coordinate'] is not None:delta[specification['coordinate']]+=specification['sign']*specification['scale']*S.MAXIMUM[specification['coordinate']]
            model=I.advance(last,delta)
        original=dict(accepted=False,refusal=None)
        try:
            direction,certificates=B.velocity(model,modes,heading);original.update(accepted=True,normalized_velocity=(direction/S.MAXIMUM).tolist(),certificates=certificates)
        except L.VelocityRefusal as failure:original['refusal']=failure.record
        candidate=quadratic_direction(problem(model,modes,heading))
        if original['accepted'] and candidate['primary_certificate'] is not None:assert original['certificates']['maximum_progress']==candidate['primary_certificate']
        rows.append(dict(specification=specification,delta=delta.tolist(),original=original,quadratic=candidate))
    summaries={}
    for variant in ('original','quadratic'):
        reference=rows[2][variant];sensitivity=[]
        if reference['accepted']:
            x=np.array(reference['normalized_velocity'])
            for scale in SCALES:
                passing=[row for row in rows[3:] if row['specification']['scale']==scale and row[variant]['accepted']]
                sensitivity.append(dict(scale=scale,certified_probes=len(passing),maximum_normalized_velocity_change=max((float(np.max(np.abs(np.array(row[variant]['normalized_velocity'])-x))) for row in passing),default=None)))
        summaries[variant]=dict(certified_poses=sum(row[variant]['accepted'] for row in rows),sensitivity=sensitivity)
    return dict(schema_version='sporespore_r10cc_quadratic_motion_field_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),
        controls=checked,entry_contact_replay=replay,probes=rows,summary=dict(pose_count=len(rows),variants=summaries),new_model_increments=0,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CC prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result);print(json.dumps(W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(W.T.present(result,True),indent=2))
