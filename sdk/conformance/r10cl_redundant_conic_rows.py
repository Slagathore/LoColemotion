"""Conic equality-coordinate solve with explicit roundoff-redundant row handling.

Omit only projected roundoff rows with nonnegative shifted RHS from the backend;
restore zero duals and require the unchanged complete original certificate.
"""
import argparse
import json
import subprocess
import numpy as np
from scipy import sparse
import r10ci_serializable_conic_motion as J
import r10ck_portfolio_right_rear_path as P
H=J.H
F,E,C,K,S,L,D=H.F,H.E,H.C,H.K,H.S,H.L,H.D
STUDY=C.ROOT/'sdk/recovery/r10cl_redundant_conic_rows_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cl_redundant_conic_rows_result_v1.json'


def raw_solve_qp(a,b,u,v,bounds,start):
    rows=list(u);limits=list(v);sides=[]
    for i,(lower,upper) in enumerate(bounds):
        if lower is not None:rows.append(-np.eye(len(start))[i]);limits.append(-lower);sides.append((i,'lower'))
        if upper is not None:rows.append(np.eye(len(start))[i]);limits.append(upper);sides.append((i,'upper'))
    full_u=np.array(rows).reshape((-1,len(start)));full_v=np.array(limits)
    left,singular,right=np.linalg.svd(a,full_matrices=True)
    cutoff=max(a.shape)*np.finfo(float).eps*float(np.max(singular,initial=0.))
    rank=int(np.sum(singular>cutoff))
    x0=right[:rank].T@((left[:,:rank].T@b)/singular[:rank]);null=right[rank:].T
    projected=full_u@null;shifted=full_v-full_u@x0
    scales,tiny=D.projection_scales(full_u,projected,shifted,a.shape)
    reduced_u=projected/scales[:,None];reduced_v=shifted/scales
    omitted=[i for i in tiny if shifted[i]>=0.]
    keep=np.ones(len(full_u),dtype=bool);keep[omitted]=False
    record=dict(success=False,status=None,message=None,iterations=0,solution=None,multipliers=None,
        certificate=None,detail=None,accepted=False,equality_rank=rank,equality_singular_values=singular.tolist(),
        rank_cutoff=cutoff,affine_origin=x0.tolist(),null_basis=null.tolist(),original_row_scales=scales.tolist(),
        unamplified_roundoff_rows=tiny,backend_omitted_rows=omitted,
        omitted_row_projected_max=[float(np.max(np.abs(projected[i]),initial=0.)) for i in omitted],
        omitted_row_shifted_rhs=[float(shifted[i]) for i in omitted])
    if np.max(np.abs(a@x0-b),initial=0.)>K.CERT or null.shape[1]==0:
        record['message']='affine equality reconstruction or zero-dimensional refusal';return record
    settings=E.clarabel.DefaultSettings()
    for key,value in E.QP_OPTIONS.items():setattr(settings,key,value)
    # Preserve the exact transformed objective, including any floating-point
    # departure of the SVD basis from perfect orthonormality.
    hessian=null.T@null;linear=null.T@x0
    answer=E.clarabel.DefaultSolver(sparse.csc_matrix(np.triu(hessian)),linear,
        sparse.csc_matrix(reduced_u[keep]),reduced_v[keep],[E.clarabel.NonnegativeConeT(int(np.sum(keep)))],settings).solve()
    x=x0+null@np.array(answer.x);beta=np.zeros(len(full_u));beta[keep]=np.array(answer.z)/scales[keep]
    record.update(success=answer.status==E.clarabel.SolverStatus.Solved,status=str(answer.status),message=str(answer.status),
        iterations=int(answer.iterations),solution=E.finite_numbers(x),reduced_solution=E.finite_numbers(answer.x),
        reduced_multipliers=E.finite_numbers(answer.z))
    if np.all(np.isfinite(x)) and np.all(np.isfinite(beta)):
        remainder=x+full_u.T@beta
        equality=left[:,:rank]@((right[:rank]@remainder)/singular[:rank])
        multipliers=np.r_[equality,beta];record['multipliers']=E.finite_numbers(multipliers)
        record['certificate'],record['detail']=E.E.certificate(x,multipliers,a,b,u,v,bounds,sides)
        record['accepted']=F.eligible(record['status'],record['certificate'])
    return record

def solve_qp(a,b,u,v,bounds,start):
    with np.errstate(over='ignore',invalid='ignore'):raw=raw_solve_qp(a,b,u,v,bounds,start)
    nonfinite=[];record=J.safe_record(raw,nonfinite=nonfinite);record['nonfinite_diagnostics']=nonfinite
    if nonfinite:record['accepted']=False
    json.dumps(record,allow_nan=False)
    return record


def controls():
    checked=J.controls();a=np.array([[1.,0.]]);b=np.array([0.]);u=np.array([[1.,0.],[-1.,0.],[0.,-1.]])
    first=solve_qp(a,b,u,np.array([0.,0.,-.5]),[(-1.,1.),(-1.,1.)],np.array([0.,.5]))
    assert first['accepted'] and np.max(np.abs(np.array(first['solution'])-[0.,.5]))<1e-10
    assert first['backend_omitted_rows']==[0,1]
    assert np.all(np.array(first['detail']['inequality_marginals'])[:2]==0.)
    bad=solve_qp(a,b,u,np.array([-1.,0.,-.5]),[(-1.,1.),(-1.,1.)],np.array([0.,.5]))
    assert 0 not in bad['backend_omitted_rows'] and not bad['accepted']
    near=u.copy();near[0,1]=1e-8
    kept=solve_qp(a,b,near,np.array([0.,0.,0.]),[(-1.,1.),(-1.,1.)],np.zeros(2))
    assert 0 not in kept['backend_omitted_rows'] and kept['accepted']
    assert first['certificate']['stationarity_max_residual']<=K.CERT
    checked['additional_implied_row_zero_dual_negative_rhs_and_nonredundant_row_controls']=6
    return checked


def declare():
    prior=C.read(P.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10cl_redundant_conic_rows_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_roundoff_redundant_conic_row_preprocessing',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can explicit roundoff-redundant inequality handling avoid oversized cancelling duals and certify the61 exact exposed QPs?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,__file__]],
        population=dict(prior['population'],coverage='All60 R10CI/R10CJ exact QPs plus the new R10CK failed runtime QP;61 problems, no integration.'),
        design=dict(coordinates='Exactly R10CH SVD affine equality coordinates, Hessian and projected-row scales.',
            preprocessing='Only in the reduced backend, omit rows whose projected coefficient norm is no greater than the existing max(matrix dimensions)*machine epsilon*original row norm AND whose shifted RHS is nonnegative. Retain row indices, projected residual sizes and shifted RHS. Keep all other rows and bounds. No physical tolerance change.',
            duals='Restore zero duals for omitted rows and unscale remaining duals. Reconstruct equality multipliers exactly as before. Admission still requires every original row and bound, original full KKT and quadratic objective-gap certificate <=1e-6. Approximate redundancy does not bypass original checks.',
            solver='Same isolated pinned Clarabel, settings and Solved/AlmostSolved policy. One reduced solve; no retry or fallback. Nonfinite diagnostics are tagged and refused.',
            retention='All61 exact inputs, historical reference outputs and candidate results retained with complete cold replay. Prior failures and incomplete R10CH remain immutable.',
            boundary='Finite numerical regression, not physical feasibility proof, a path, native recovery, controller adoption or release authority.'),
        numerics=C.read(F.STUDY)['numerics'],checks=['214 inherited plus6 row implication, zero-dual, negative-RHS and nonredundant-row controls.','Complete61-problem cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();prior=C.read(J.RESULT);path=C.read(P.RESULT)
    bank=[dict(name=row['name'],source=C.bind(J.RESULT),problem=row['problem'],retained_original=row['candidate']) for row in prior['problems']]
    failed=path['trajectory'][-1]['velocity_refusal']['diagnostic']
    bank.append(dict(name='R10CK_failed_runtime',source=C.bind(P.RESULT),problem=failed['quadratic_problem'],retained_original=failed['quadratic_result']))
    for row in bank:
        p=row['problem'];a,b,u,v=[np.array(p[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
        row['candidate']=solve_qp(a,b,u,v,p['bounds'],np.array(p['start']))
    assert len(bank)==61
    summary=dict(problem_count=len(bank),certified_problems=sum(row['candidate']['accepted'] for row in bank),
        prior_population_certified=sum(row['candidate']['accepted'] for row in bank[:59]),
        r10cg_runtime_certified=bank[-2]['candidate']['accepted'],r10ck_runtime_certified=bank[-1]['candidate']['accepted'])
    return dict(schema_version='sporespore_r10cl_redundant_conic_rows_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=bank,summary=summary,**declaration['claim_boundary'])


def quadratic_direction(p):
    cost,a,b,u,v=[np.array(p[key]) for key in ('cost','equality','equality_rhs','inequality','inequality_rhs')]
    bounds=p['bounds'];record=dict(accepted=False,primary_certificate=None,quadratic_problem=None,quadratic_result=None,refusal=None)
    try:first_x,first=E.W.certified_lp('primary_placement_cost_reduction',cost,a,b,u,v,bounds)
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
    record=quadratic_direction(E.E.problem(model,modes,heading))
    if not record['accepted']:raise L.VelocityRefusal(dict(stage='redundant_conic_rows',diagnostic=record))
    certificate=dict(record['quadratic_result']['certificate'],qp_status=record['quadratic_result']['status'],
        qp_status_rule='solved_or_almost_solved_with_full_original_certificate')
    return np.array(record['velocity']),dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=certificate)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CL prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result);print(json.dumps(E.W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(E.W.T.present(result,True),indent=2))
