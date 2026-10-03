"""Equality-coordinate conic QP with unchanged original-matrix certificates.

The 59 retained R10CF QPs and exact R10CG failed runtime QP form a finite
development regression bank. No integration or native world is performed.
"""
import argparse
import json
import subprocess
import numpy as np
from scipy import sparse

import r10cf_certificate_admitted_motion_field as F
import r10cg_quadratic_right_rear_path as P

E=F.E
C,K,S,L=F.C,F.K,F.S,F.L
D=E.D
STUDY=C.ROOT/'sdk/recovery/r10ch_reduced_conic_motion_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10ch_reduced_conic_motion_result_v1.json'


def solve_qp(a,b,u,v,bounds,start):
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
    record=dict(success=False,status=None,message=None,iterations=0,solution=None,multipliers=None,
        certificate=None,detail=None,accepted=False,equality_rank=rank,equality_singular_values=singular.tolist(),
        rank_cutoff=cutoff,affine_origin=x0.tolist(),null_basis=null.tolist(),original_row_scales=scales.tolist(),
        unamplified_roundoff_rows=tiny)
    if np.max(np.abs(a@x0-b),initial=0.)>K.CERT or null.shape[1]==0:
        record['message']='affine equality reconstruction or zero-dimensional refusal';return record
    settings=E.clarabel.DefaultSettings()
    for key,value in E.QP_OPTIONS.items():setattr(settings,key,value)
    # Preserve the exact transformed objective, including any floating-point
    # departure of the SVD basis from perfect orthonormality.
    hessian=null.T@null;linear=null.T@x0
    answer=E.clarabel.DefaultSolver(sparse.csc_matrix(np.triu(hessian)),linear,
        sparse.csc_matrix(reduced_u),reduced_v,[E.clarabel.NonnegativeConeT(len(full_u))],settings).solve()
    x=x0+null@np.array(answer.x);beta=np.array(answer.z)/scales
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
    if not record['accepted']:raise L.VelocityRefusal(dict(stage='reduced_conic_motion',diagnostic=record))
    certificate=dict(record['quadratic_result']['certificate'],qp_status=record['quadratic_result']['status'],
        qp_status_rule='solved_or_almost_solved_with_full_original_certificate')
    return np.array(record['velocity']),dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=certificate)


def controls():
    checked=F.controls();a=np.array([[1.,1.]]);b=np.array([1.]);u=np.zeros((0,2));v=np.zeros(0)
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
    assert not E.E.certificate(np.array(first['solution']),multipliers,a,b,u,v,[(0.,1.),(0.,1.)],sides)[0]['accepted']
    assert not E.E.certificate(np.array([.8,.8]),np.array(first['multipliers']),a,b,u,v,[(0.,1.),(0.,1.)],sides)[0]['accepted']
    assert abs(first['certificate']['primal_objective']-.25)<1e-10
    assert abs(first['certificate']['dual_objective']-.25)<1e-10
    assert len(first['original_row_scales'])==4 and first['equality_rank']==1
    checked['additional_reduced_conic_known_answer_bound_dual_infeasible_corruption_and_mapping_controls']=9
    return checked


def declare():
    prior=C.read(P.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10ch_reduced_conic_motion_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_equality_coordinate_conic_regression',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does equality-coordinate Clarabel with original-row dual reconstruction certify the59 prior QPs and exact R10CG complementarity refusal without changing any original constraint or certificate?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,__file__]],population=dict(prior['population'],
            coverage='60 exact retained QPs: all59 R10CF diagnostic QPs and one R10CG failed runtime QP. No integration or new pose population.'),
        design=dict(coordinates='SVD equality affine origin and null basis with the existing R10CD machine-precision rank rule. Refuse inconsistent affine origin or zero-dimensional null space. Transform half squared original velocity exactly, with N.T*N Hessian and N.T*x0 linear term.',
            rows='Retain every original inequality and every finite variable bound. Use R10CD projected-row scaling, preserving original scale for roundoff-sized projected rows. No row deletion, feasibility widening or solver fallback.',
            solver='Pinned R10CE Clarabel binary and exact settings; new reduced-coordinate problem. No warm start or retry. R10CF Solved/AlmostSolved plus original full independent certificate.',
            duals='Undo row scales, reconstruct original equality multipliers via SVD, and check all original rows/bounds plus full QP KKT and objective gap at unchanged1e-6.',
            bank='Read exact saved QP inputs and retain original outputs as historical references. Freshly solve each transformed QP and preserve every refusal. Do not regrade original results.',
            boundary='Finite numerical regression only. No path, physical execution, controller selection or release authority.'),
        numerics=dict(C.read(F.STUDY)['numerics']),checks=['202 inherited plus9 reduced-coordinate known-answer and mapping checks.','All60 exact problems and candidate outcomes retained; full cold replay.'],
        research_sources=C.read(F.STUDY)['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();previous=C.read(F.RESULT);path=C.read(P.RESULT)
    bank=[dict(name='R10CF_'+str(i),specification=row['specification'],source=C.bind(F.RESULT),problem=row['quadratic']['quadratic_problem'],
        retained_original=row['quadratic']['quadratic_result']) for i,row in enumerate(previous['probes'])]
    failed=path['trajectory'][-1]['velocity_refusal']['diagnostic']
    bank.append(dict(name='R10CG_failed_runtime',source=C.bind(P.RESULT),problem=failed['quadratic_problem'],retained_original=failed['quadratic_result']))
    for row in bank:
        p=row['problem'];a,b,u,v=[np.array(p[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
        row['candidate']=solve_qp(a,b,u,v,p['bounds'],np.array(p['start']))
    assert len(bank)==60
    summary=dict(problem_count=len(bank),certified_problems=sum(row['candidate']['accepted'] for row in bank),
        prior_population_certified=sum(row['candidate']['accepted'] for row in bank[:-1]),new_runtime_failure_certified=bank[-1]['candidate']['accepted'])
    return dict(schema_version='sporespore_r10ch_reduced_conic_motion_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=bank,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CH prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result);print(json.dumps(E.W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(E.W.T.present(result,True),indent=2))
