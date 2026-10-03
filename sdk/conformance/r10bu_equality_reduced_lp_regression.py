"""Equality-coordinate LP diagnostic with independent original-matrix certificates.

No original inequality or variable bound is discarded. Reduced solver success
alone never accepts an answer: primal and dual quantities are mapped back and
checked against every original row, bound, and objective by the existing auditor.
"""
import argparse
import json
import subprocess
from types import SimpleNamespace
import numpy as np
from scipy.optimize import linprog

import r10bt_retained_lp_regression as T

C, K = T.C, T.K
STUDY = C.ROOT/'sdk/recovery/r10bu_equality_reduced_lp_regression_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bu_equality_reduced_lp_regression_result_v1.json'


def solve(problem):
    c,a,b,u,v = [np.array(problem[key],dtype=float) for key in T.FIELDS[:5]]
    bounds = problem['bounds']; left,singular,right = np.linalg.svd(a,full_matrices=True)
    cutoff = max(a.shape)*np.finfo(float).eps*float(np.max(singular,initial=0.))
    rank = int(np.sum(singular>cutoff))
    x0 = right[:rank].T@((left[:,:rank].T@b)/singular[:rank])
    null = right[rank:].T
    equal_error = float(np.max(np.abs(a@x0-b),initial=0.))
    matrix = list(u); limits = list(v); sides = []
    for i,(lower,upper) in enumerate(bounds):
        if lower is not None:
            matrix.append(-np.eye(len(c))[i]); limits.append(-lower); sides.append((i,'lower'))
        if upper is not None:
            matrix.append(np.eye(len(c))[i]); limits.append(upper); sides.append((i,'upper'))
    matrix = np.array(matrix); limits = np.array(limits)
    projected = matrix@null; shifted = limits-matrix@x0
    # Positive row scaling conditions small projected rows without deleting
    # them. A constant row is preserved, including an infeasible constant row.
    scale = np.maximum(np.max(np.abs(projected),axis=1,initial=0.),np.abs(shifted))
    scale[scale==0.] = 1.
    reduced_u = projected/scale[:,None]; reduced_v = shifted/scale
    reduced_c = null.T@c
    record = dict(success=False,accepted=False,status=None,message=None,certificate=None,
        equality_rank=rank,equality_singular_values=singular.tolist(),rank_cutoff=cutoff,
        affine_equality_residual=equal_error,reduced_dimension=null.shape[1],
        affine_origin=x0.tolist(),null_basis=null.tolist(),row_scales=scale.tolist(),
        reduced_problem=dict(cost=reduced_c.tolist(),inequality=reduced_u.tolist(),inequality_rhs=reduced_v.tolist()),
        solver_method='highs-ipm',presolve=False)
    if equal_error>K.CERT:
        record['message']='affine equality reconstruction refused';return record
    if null.shape[1]==0:
        record['message']='zero-dimensional equality system outside this declared regression solver';return record
    result=linprog(reduced_c,A_ub=reduced_u,b_ub=reduced_v,bounds=[(None,None)]*null.shape[1],
        method='highs-ipm',options=dict(K.OPTIONS,presolve=False))
    record.update(success=bool(result.success),status=int(result.status),message=result.message,
        iterations=int(result.nit),crossover_iterations=int(getattr(result,'crossover_nit',0)))
    if not result.success:return record
    multipliers=result.ineqlin.marginals/scale
    original_inequality=multipliers[:len(u)]; lower=np.zeros(len(c)); upper=np.zeros(len(c))
    for multiplier,(index,side) in zip(multipliers[len(u):],sides,strict=True):
        if side=='lower':lower[index]=-multiplier
        else:upper[index]=multiplier
    remainder=c-u.T@original_inequality-lower-upper
    equality=left[:,:rank]@((right[:rank]@remainder)/singular[:rank])
    mapped=SimpleNamespace(x=x0+null@result.x,eqlin=SimpleNamespace(marginals=equality),
        ineqlin=SimpleNamespace(marginals=original_inequality),lower=SimpleNamespace(marginals=lower),upper=SimpleNamespace(marginals=upper))
    certificate,detail=K.certify(mapped,c,a,b,u,v,bounds)
    record.update(accepted=certificate['accepted'],certificate=certificate,detail=detail,
        reduced_solution=result.x.tolist(),reduced_inequality_marginals=result.ineqlin.marginals.tolist(),
        reduced_objective=float(reduced_c@result.x),original_objective=float(c@mapped.x))
    return record


def controls():
    checked=T.controls()
    # Equality forces x+y=1; bounds and an inequality cap x at .75.
    base=dict(cost=[-1.,0.,0.],equality=[[1.,1.,0.]],equality_rhs=[1.],
        inequality=[[1.,0.,0.]],inequality_rhs=[.75],bounds=[[0.,1.],[0.,1.],[0.,0.]])
    first=solve(base)
    assert first['accepted'] and abs(first['original_objective']+.75)<1e-12
    redundant=dict(base,equality=[[1.,1.,0.],[2.,2.,0.]],equality_rhs=[1.,2.])
    duplicate=solve(redundant)
    assert duplicate['accepted'] and duplicate['equality_rank']==1
    assert abs(duplicate['original_objective']+.75)<1e-12
    infeasible=dict(base,inequality_rhs=[-1.])
    assert not solve(infeasible)['accepted']
    inconsistent=dict(redundant,equality_rhs=[1.,3.])
    assert solve(inconsistent)['message']=='affine equality reconstruction refused'
    # The same answer survives a positive row rescaling across many orders.
    scaled=dict(base,inequality=[[1e-12,0.,0.]],inequality_rhs=[.75e-12])
    answer=solve(scaled)
    assert answer['accepted'] and abs(answer['original_objective']+.75)<1e-12
    # Nonzero equality RHS must reach the original dual objective, not just
    # the reduced objective. Here c@x0 is a nonzero affine objective offset.
    assert abs(first['certificate']['primal_objective']-first['certificate']['dual_objective'])<1e-12
    assert abs(first['original_objective']-first['reduced_objective']+.5)<1e-12
    checked['additional_equality_reduction_original_dual_and_scaled_row_controls']=7
    return checked


def declare():
    prior=C.read(T.STUDY)
    record=dict(schema_version='sporespore_r10bu_equality_reduced_lp_regression_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_equality_coordinate_lp_regression',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does one equality-coordinate interior-point formulation certify the complete five-problem R10BT bank against the unchanged original matrices?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [T.__file__,T.STUDY,T.RESULT,__file__]],
        population=prior['population'],
        design=dict(coordinates='SVD of original equality matrix; numerical rank cutoff max(shape)*binary64_epsilon*maximum singular value. x=x0+N*z. Retain singular values, basis and affine equality residual.',
            constraints='Keep every original inequality and finite variable bound. Project into null coordinates and scale each row by max(abs(projected coefficients),abs(shifted RHS)); exact-zero scale is replaced with1. No row is discarded.',
            solver='One fixed highs-ipm backend with presolve disabled and R10BK numerical options. No retry or fallback.',
            certificate='Map reduced inequality duals back through positive row scales; map bound dual signs and reconstruct equality multipliers. The unchanged R10BK auditor checks every original primal row and bound, stationarity, dual signs, complementarity, unbounded-side duals and objective gap at1e-6.',
            refusal='Retain solver refusal or rejected original certificate. Reduced optimality alone gives no accepted direction. Zero-dimensional equality systems explicitly refuse and are outside the present bank.',
            boundary='Exactly the five saved LPs; no integration or perturbed pose. A positive bank is finite numerical evidence, not native recovery, broad solver reliability or controller selection.'),
        numerics=dict(numpy=np.__version__,scipy=T.P.S.statics.scipy.__version__,options=K.OPTIONS,
            method='highs-ipm',presolve=False,original_certificate_tolerance=K.CERT),
        checks=['163 inherited plus7 equality, rank, infeasibility, row-scale and affine-objective controls; shared coverage.',
            'All original-matrix certificates and reduced inputs retained; complete separate cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary'])
    # This successor runs one formulation per LP, not the parent's four.
    record['population']=dict(record['population'],variant_count=1,secondary_or_primary_solves=5)
    C.write_new(STUDY,record)


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy']
    assert T.P.S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();prior=C.read(T.RESULT);rows=[]
    for saved in prior['problems']:
        rows.append(dict(name=saved['name'],problem=saved['problem'],result=solve(saved['problem'])))
    accepted=[row['name'] for row in rows if row['result']['accepted']]
    return dict(schema_version='sporespore_r10bu_equality_reduced_lp_regression_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=rows,
        summary=dict(lp_count=len(rows),accepted_count=len(accepted),accepted_problems=accepted,certifies_entire_bank=len(accepted)==len(rows)),
        solver_selected=False,new_model_increments=0,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10BU prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result)
        print(json.dumps(T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(T.present(result,True),indent=2))
