"""Pinned dedicated QP solver on the original R10CC motion-field population.

All geometry rows, variable bounds, progress requirements and independent
certificate limits remain unchanged. This is model-only numerical diagnosis.
"""
import argparse
import json
import subprocess
import sys
import numpy as np
from scipy import sparse

import r10cc_quadratic_motion_field as E
import r10cd_reduced_quadratic_motion_field as D

C,B,S,K,W,L = E.C,E.B,E.S,E.K,E.W,E.L
DEPENDENCY=C.EVIDENCE/'dependencies/clarabel-0.11.1-260f7ff0104045598838bdf8d54559b4'
sys.path.insert(0,str(DEPENDENCY/'site-packages'))
import clarabel

assert clarabel.__version__=='0.11.1'
STUDY=C.ROOT/'sdk/recovery/r10ce_clarabel_motion_field_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10ce_clarabel_motion_field_result_v1.json'
QP_OPTIONS=dict(max_iter=200,time_limit=30.,verbose=False,max_threads=1,direct_solve_method='qdldl',
    presolve_enable=False,tol_gap_abs=1e-12,tol_gap_rel=1e-12,tol_feas=1e-12)


def finite_numbers(values):
    return [float(value) if np.isfinite(value) else None for value in values]


def solve_qp(a,b,u,v,bounds,start):
    rows=list(u);limits=list(v);sides=[]
    for i,(lower,upper) in enumerate(bounds):
        if lower is not None:rows.append(-np.eye(len(start))[i]);limits.append(-lower);sides.append((i,'lower'))
        if upper is not None:rows.append(np.eye(len(start))[i]);limits.append(upper);sides.append((i,'upper'))
    full_u=np.array(rows).reshape((-1,len(start)));full_v=np.array(limits)
    settings=clarabel.DefaultSettings()
    for key,value in QP_OPTIONS.items():setattr(settings,key,value)
    cones=[clarabel.ZeroConeT(len(a)),clarabel.NonnegativeConeT(len(full_u))]
    result=clarabel.DefaultSolver(sparse.eye(len(start),format='csc'),np.zeros(len(start)),
        sparse.csc_matrix(np.vstack((a,full_u))),np.r_[b,full_v],cones,settings).solve()
    x=np.array(result.x);z=np.array(result.z)
    # Clarabel uses gradient + A.T z = 0 with nonnegative inequality z.
    # The original auditor uses equality lambda=-z_eq, inequality beta=z.
    multipliers=np.r_[-z[:len(a)],z[len(a):]]
    record=dict(success=result.status==clarabel.SolverStatus.Solved,status=str(result.status),message=str(result.status),
        iterations=int(result.iterations),solution=finite_numbers(x),multipliers=finite_numbers(multipliers),
        certificate=None,detail=None,accepted=False)
    if np.all(np.isfinite(x)) and np.all(np.isfinite(multipliers)):
        record['certificate'],record['detail']=E.certificate(x,multipliers,a,b,u,v,bounds,sides)
        record['accepted']=bool(record['success'] and record['certificate']['accepted'])
    return record


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
    record=quadratic_direction(E.problem(model,modes,heading))
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
    sides=[(0,'lower'),(0,'upper'),(1,'lower'),(1,'upper')]
    multipliers=np.array(first['multipliers']);multipliers[0]+=.1
    assert not E.certificate(np.array(first['solution']),multipliers,a,b,u,v,[(0.,1.),(0.,1.)],sides)[0]['accepted']
    assert not E.certificate(np.array([.8,.8]),np.array(first['multipliers']),a,b,u,v,[(0.,1.),(0.,1.)],sides)[0]['accepted']
    assert abs(first['certificate']['primal_objective']-.25)<1e-10
    assert abs(first['certificate']['dual_objective']-.25)<1e-10
    assert clarabel.__version__=='0.11.1' and QP_OPTIONS['max_threads']==1
    checked['additional_dedicated_qp_known_answer_bound_dual_infeasible_corruption_and_pin_controls']=10
    return checked


def declare():
    prior=C.read(D.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10ce_clarabel_motion_field_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_dedicated_quadratic_solver_local_field_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does pinned Clarabel certify the full original-coordinate squared-motion QP at all59 poses, including phase entry, without relaxing the original certificate?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [D.__file__,D.STUDY,D.RESULT,__file__]]+
            [C.bind(p) for p in sorted(DEPENDENCY.rglob('*')) if p.is_file()],population=prior['population'],
        design=dict(inputs='Same R10CC/R10CD phase entry, last admitted pose and57 local probes. Exact reproduction of all original L1 results; no integration.',
            unchanged='R10CC full original-coordinate half-squared normalized velocity objective, primary portfolio,99% certified progress requirement, geometry/rate/normal/sector rows and every variable bound. No equality elimination or row deletion.',
            optimizer='Pinned isolated Clarabel0.11.1 Windows wheel, single thread, QDLDL, presolve false, max_iter200, time_limit30s, gap_abs/gap_rel/feas1e-12. Hessian identity, zero linear objective; equality zero cones and inequality nonnegative cones include every finite bound. Clarabel constructs its own start; no warm start or retry.',
            certificate='Require status Solved and unchanged full original-matrix QP certificate: primal, stationarity, dual signs, complementarity, unbounded-side dual and primal-dual objective gap <=1e-6. AlmostSolved and failed independent checks are retained refusals.',
            dependency='Downloaded wheel digest checked against retained version-specific PyPI metadata; isolated --no-deps installation in durable evidence. Bind metadata, wheel, installed binary/code/metadata and install receipts. No global environment or production dependency adoption.',
            boundary='Finite exposed numerical diagnostic, not a path, global smoothness proof, native actuation, recovery or release. All results and separate full cold replay retained.'),
        numerics=dict(numpy=np.__version__,scipy=S.statics.scipy.__version__,clarabel=clarabel.__version__,qp_options=QP_OPTIONS,certificate_tolerance=K.CERT,perturbation_scales=list(E.SCALES)),
        checks=['180 inherited plus10 dedicated-QP known-answer, dual, infeasibility, corruption and dependency/thread checks;190 with shared coverage.',
            'All59 original and candidate results retained; complete separate cold replay.'],
        research_sources=prior['research_sources']+[dict(url='https://clarabel.org/stable/python/getting_started_py/',use='Quadratic objective, cone representation and primal/dual interface.'),
            dict(url='https://pypi.org/project/clarabel/0.11.1/',use='Pinned version-specific wheel metadata and binary provenance.')],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    assert clarabel.__version__==declaration['numerics']['clarabel']
    checked=controls();entry,last,previous,replay,heading=E.reconstruct();modes=previous['summary']['selected_modes'];prior=C.read(D.RESULT)
    center=np.array(previous['trajectory'][-1]['last_integration_probe']['delta']);rows=[]
    for specification in E.probes():
        if specification['name']=='phase_entry':model=entry;delta=np.zeros(14)
        elif specification['name']=='last_admitted':model=last;delta=np.zeros(14)
        else:
            delta=center.copy()
            if specification['coordinate'] is not None:delta[specification['coordinate']]+=specification['sign']*specification['scale']*S.MAXIMUM[specification['coordinate']]
            model=E.I.advance(last,delta)
        original=dict(accepted=False,refusal=None)
        try:
            direction,certificates=B.velocity(model,modes,heading);original.update(accepted=True,normalized_velocity=(direction/S.MAXIMUM).tolist(),certificates=certificates)
        except L.VelocityRefusal as failure:original['refusal']=failure.record
        assert original==prior['probes'][len(rows)]['original']
        candidate=quadratic_direction(E.problem(model,modes,heading))
        if original['accepted'] and candidate['primary_certificate'] is not None:assert original['certificates']['maximum_progress']==candidate['primary_certificate']
        rows.append(dict(specification=specification,delta=delta.tolist(),original=original,quadratic=candidate))
    summaries={}
    for variant in ('original','quadratic'):
        reference=rows[2][variant];sensitivity=[]
        if reference['accepted']:
            x=np.array(reference['normalized_velocity'])
            for scale in E.SCALES:
                passing=[row for row in rows[3:] if row['specification']['scale']==scale and row[variant]['accepted']]
                sensitivity.append(dict(scale=scale,certified_probes=len(passing),maximum_normalized_velocity_change=max((float(np.max(np.abs(np.array(row[variant]['normalized_velocity'])-x))) for row in passing),default=None)))
        summaries[variant]=dict(certified_poses=sum(row[variant]['accepted'] for row in rows),sensitivity=sensitivity)
    return dict(schema_version='sporespore_r10ce_clarabel_motion_field_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),
        controls=checked,entry_contact_replay=replay,probes=rows,summary=dict(pose_count=len(rows),variants=summaries),new_model_increments=0,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CE prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result);print(json.dumps(W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(W.T.present(result,True),indent=2))
