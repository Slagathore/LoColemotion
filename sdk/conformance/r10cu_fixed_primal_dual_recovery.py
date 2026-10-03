"""Bounded fixed-primal dual recovery under the unchanged full QP certificate.

After a failed original certificate, preserve the exact candidate velocity and
solve only for dual multipliers. No physical row, objective or limit changes.
"""
import argparse
import copy
import json
import subprocess
import numpy as np
import r10ct_landing_headroom_diagnosis as T

C,S=T.C,T.S
F=T.R.P.F
E,K,L=F.E,F.K,F.L
STUDY=C.ROOT/'sdk/recovery/r10cu_fixed_primal_dual_recovery_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cu_fixed_primal_dual_recovery_result_v1.json'


def expanded(u,v,bounds,n):
    rows=list(u);limits=list(v);sides=[]
    for i,(lower,upper) in enumerate(bounds):
        if lower is not None:rows.append(-np.eye(n)[i]);limits.append(-lower);sides.append((i,'lower'))
        if upper is not None:rows.append(np.eye(n)[i]);limits.append(upper);sides.append((i,'upper'))
    return np.array(rows).reshape((-1,n)),np.array(limits),sides


def recover_duals(problem,original):
    record=dict(accepted=False,refusal=None,solution=original.get('solution'),certificate=None,detail=None,
        dual_problem=None,dual_solution=None,dual_certificate=None,primal_changed=False)
    if original.get('status') not in F.F.STATUSES:
        record['refusal']='ineligible_original_status';return record
    raw=original.get('solution')
    if raw is None or any(not isinstance(value,(int,float)) or not np.isfinite(value) for value in raw):
        record['refusal']='missing_or_nonfinite_primal';return record
    x=np.array(raw);a,b,u,v=[np.array(problem[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
    full_u,full_v,sides=expanded(u,v,problem['bounds'],len(x))
    zero,_=E.E.certificate(x,np.zeros(len(a)+len(full_u)),a,b,u,v,problem['bounds'],sides)
    if zero['primal_max_residual']>K.CERT:
        record['refusal']='original_primal_infeasible';return record
    # Stationarity is linear in the duals at a FIXED primal: -A.T*lambda +
    # U.T*beta = -x, beta >= 0. Absolute slacks keep this diagnostic LP bounded
    # below even when the candidate has roundoff-sized negative slack. The final
    # original certificate still checks signed feasibility, gap and all rows.
    slack=full_v-full_u@x
    cost=np.r_[np.zeros(len(a)),np.abs(slack)]
    dual_a=np.column_stack((-a.T,full_u.T));dual_b=-x
    dual_u=np.zeros((1,len(cost)));dual_v=np.zeros(1)
    dual_bounds=[(None,None)]*len(a)+[(0.,None)]*len(full_u)
    record['dual_problem']=dict(cost=cost.tolist(),equality=dual_a.tolist(),equality_rhs=dual_b.tolist(),
        inequality=dual_u.tolist(),inequality_rhs=dual_v.tolist(),bounds=list(map(list,dual_bounds)))
    try:dual,certificate=E.W.certified_lp('fixed_primal_dual_recovery',cost,dual_a,dual_b,dual_u,dual_v,dual_bounds)
    except L.VelocityRefusal as error:record['refusal']=error.record;return record
    final,detail=E.E.certificate(x,dual,a,b,u,v,problem['bounds'],sides)
    record.update(dual_solution=dual.tolist(),dual_certificate=certificate,certificate=final,detail=detail,
        accepted=F.F.eligible(original['status'],final),refusal=None if final['accepted'] else 'full_original_qp_certificate')
    assert record['solution']==original['solution']
    return record


def solve_qp(a,b,u,v,bounds,start):
    original=F.solve_qp(a,b,u,v,bounds,start)
    if original['accepted']:return original
    problem=dict(equality=a.tolist(),equality_rhs=b.tolist(),inequality=u.tolist(),inequality_rhs=v.tolist(),bounds=bounds,start=start.tolist())
    with np.errstate(over='ignore',invalid='ignore'):recovery=recover_duals(problem,original)
    nonfinite=[];recovery=F.J.safe_record(recovery,nonfinite=nonfinite);recovery['nonfinite_diagnostics']=nonfinite
    if nonfinite:recovery['accepted']=False
    answer=dict(original,accepted=recovery['accepted'],fixed_primal_dual_recovery=dict(original=original,recovery=recovery,problem=problem))
    if recovery['accepted']:
        answer.update(certificate=recovery['certificate'],detail=recovery['detail'],multipliers=recovery['dual_solution'])
    json.dumps(answer,allow_nan=False)
    return answer


def controls():
    checked=T.controls()
    p=dict(equality=[[1.,0.]],equality_rhs=[0.],inequality=[[0.,-1.]],inequality_rhs=[-.5],bounds=[[None,None],[None,None]],start=[0.,.5])
    original=dict(status='AlmostSolved',solution=[0.,.5]);snapshot=copy.deepcopy(original)
    good=recover_duals(p,original)
    assert good['accepted'] and good['certificate']['objective_gap']<=1e-12
    assert good['solution']==original['solution'] and original==snapshot and not good['primal_changed']
    suboptimal=recover_duals(p,dict(original,solution=[0.,1.]))
    assert not suboptimal['accepted'] and suboptimal['refusal']=='full_original_qp_certificate'
    infeasible=recover_duals(p,dict(original,solution=[0.,.4]));assert not infeasible['accepted'] and infeasible['dual_problem'] is None
    nonfinite=recover_duals(p,dict(original,solution=[0.,float('nan')]));assert not nonfinite['accepted'] and nonfinite['dual_problem'] is None
    status=recover_duals(p,dict(original,status='MaxIterations'));assert not status['accepted'] and status['dual_problem'] is None
    corrupt=copy.deepcopy(good);corrupt['dual_solution'][1]=-.5
    _,_,sides=expanded(np.array(p['inequality']),np.array(p['inequality_rhs']),p['bounds'],2)
    cert,_=E.E.certificate(np.array(original['solution']),np.array(corrupt['dual_solution']),np.array(p['equality']),np.array(p['equality_rhs']),np.array(p['inequality']),np.array(p['inequality_rhs']),p['bounds'],sides)
    assert not cert['accepted']
    checked['additional_fixed_primal_known_answer_nonmutation_suboptimal_infeasible_nonfinite_status_and_bad_dual_controls']=7
    return checked


def declare():
    prior=C.read(T.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10cu_fixed_primal_dual_recovery_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_fixed_primal_dual_recovery_regression',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can a bounded dual-only recovery certify the same candidate primal on the exact R10CS refused QP while preserving all64 previously certified placement/landing problems?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [T.__file__,T.STUDY,T.RESULT,F.RESULT,__file__]],
        population=dict(prior['population'],coverage='The61 exact R10CM QPs, three R10CR landing-direction QPs and the R10CS failed runtime QP:65 exposed problems, no integration.'),
        design=dict(first='Fresh unchanged R10CM QP solve on every exact problem. If it passes, return its exact record without recovery. Require baseline results to match their retained originals.',
            recovery='Only on a failed certificate with eligible Solved/AlmostSolved finite primal, solve one certified LP portfolio for equality multipliers and nonnegative inequality/bound multipliers. Exact stationarity matrix[-A.T,Ufull.T], RHS -x; minimize sum(abs(original slack)*beta). Equality duals are unrestricted. All original inequalities and finite bounds are included; no active-row selection or threshold omission.',
            bound='One unchanged Clarabel call, then at most two unchanged primary LP backends for dual recovery. Original backend iteration/time limits remain. No repeated QP, primal update, altered objective, physical constraint, progression requirement, or acceptance tolerance.',
            admission='Recompute the existing complete original QP primal/stationarity/sign/complementarity/duality-gap certificate at the identical primal. Require every check <=1e-6 and eligible original status. A dual-LP certificate alone never admits the QP.',
            retention='On every recovery retain the original refused record, exact QP, dual LP, complete dual solution, LP certificate and final original QP certificate. Nonfinite records are tagged and refused. Full regression and cold replay; old refusals never regraded.',
            boundary='Finite numerical algorithm qualification only. No integrated path, contact acquisition, controller selection, native actuation or physical/release authority.'),
        numerics=prior['numerics'],checks=['243 inherited plus7 fixed-primal recovery controls;250 with shared coverage.','Fresh65-problem regression, baseline identity and complete cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();prior=C.read(F.RESULT)
    rows=[dict(name=row['name'],problem=row['problem'],retained_original=row['candidate']) for row in prior['problems']]
    for row in C.read(T.R.RESULT)['cases']:
        result=row['result'];rows.append(dict(name='R10CR_'+row['variant'],problem=result['quadratic_problem'],retained_original=result['quadratic_result']))
    failed=C.read(T.P.RESULT)['trajectory'][-1]['velocity_refusal']['diagnostic']
    rows.append(dict(name='R10CS_failed_runtime',problem=failed['quadratic_problem'],retained_original=failed['quadratic_result']))
    assert len(rows)==65
    for row in rows:
        p=row['problem'];a,b,u,v=[np.array(p[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
        answer=solve_qp(a,b,u,v,p['bounds'],np.array(p['start']));row['candidate']=answer
        original=answer.get('fixed_primal_dual_recovery',{}).get('original',answer)
        assert original==row['retained_original'],row['name']
        if answer['accepted']:assert answer['solution']==original['solution']
    summary=dict(problem_count=len(rows),certified_problems=sum(row['candidate']['accepted'] for row in rows),
        recovery_calls=sum('fixed_primal_dual_recovery' in row['candidate'] for row in rows),
        prior_population_certified=sum(row['candidate']['accepted'] for row in rows[:-1]),
        r10cs_failed_runtime_certified=rows[-1]['candidate']['accepted'],primal_answers_changed=0,new_model_increments=0)
    return dict(schema_version='sporespore_r10cu_fixed_primal_dual_recovery_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=rows,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CU prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:
            assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result)
        else:result=C.read(RESULT);assert result==derive()
        print(json.dumps(dict(ok=True,cold_replay=not args.create,summary=result['summary']),indent=2))
