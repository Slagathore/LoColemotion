"""Bounded certificate-gated solver portfolio on five reserved-rate runtime pairs.

Historical face queries and old near-maximum secondary objectives remain intact.
Each new secondary problem uses 99% of its newly certified primary optimum.
"""
import argparse
import json
import subprocess
import numpy as np

import r10bt_retained_lp_regression as T
import r10bw_reserved_runtime_lp as W
import r10bx_interior_point_raise_path as X

C,K,P,L = T.C,T.K,T.P,T.L
STUDY=C.ROOT/'sdk/recovery/r10by_certified_runtime_portfolio_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10by_certified_runtime_portfolio_result_v1.json'
NAMES=(*W.NAMES,'r10bx_original_entry_secondary')
BACKENDS=(('highs-ds',False),('highs-ipm',False))


def certified_lp(stage,cost,a,b,u,v,bounds):
    problem=dict(cost=cost.tolist(),equality=a.tolist(),equality_rhs=b.tolist(),
        inequality=u.tolist(),inequality_rhs=v.tolist(),bounds=[[x for x in pair] for pair in bounds])
    attempts=[]
    for method,presolve in BACKENDS:
        result=K.solve(problem,method,presolve)
        # All unsuccessful attempts are retained with their full solver detail.
        # A successful certificate alone authorizes returning a direction.
        attempts.append(dict(method=method,presolve=presolve,solver_status=result['status'],
            solver_message=result['message'],solver_success=result['success'],certificate=result['certificate'],
            solver_detail=result.get('detail') if not (result['certificate'] or {}).get('accepted') else None))
        if result['certificate'] is not None and result['certificate']['accepted']:
            certificate=dict(result['certificate'],backend_attempt_count=len(attempts),selected_method=method)
            if len(attempts)>1:certificate['retained_solver_recovery']=dict(stage=stage,problem=problem,attempts=attempts)
            return np.array(result['detail']['solution']),certificate
    raise L.VelocityRefusal(dict(stage=stage,solver_status=result['status'],solver_message=result['message'],
        solver_success=result['success'],certificate=result['certificate'],solver_detail=result.get('detail'),
        backend_attempts=attempts,**problem))


def primary_problem(original):
    if len(original['cost'])==14:return {key:original[key] for key in T.FIELDS}
    assert len(original['cost'])==28
    a=np.array(original['equality']);u=np.array(original['inequality']);v=np.array(original['inequality_rhs'])
    row=len(v)-29;scale=original['objective_row_scale']
    assert np.array_equal(original['cost'],np.r_[np.zeros(14),np.ones(14)])
    assert np.max(np.abs(a[:,14:]),initial=0.)==0. and np.max(np.abs(u[:row,14:]),initial=0.)==0.
    return dict(cost=(u[row,:14]*scale).tolist(),equality=a[:,:14].tolist(),equality_rhs=original['equality_rhs'],
        inequality=u[:row,:14].tolist(),inequality_rhs=v[:row].tolist(),bounds=original['bounds'][:14])


def pair(problem):
    c,a,b,u,v=[np.array(problem[key]) for key in T.FIELDS[:5]];bounds=[tuple(x) for x in problem['bounds']]
    record=dict(primary_problem=problem,primary_certificate=None,secondary_problem=None,secondary_certificate=None,accepted=False,refusal=None)
    try:
        x,first=certified_lp('primary',c,a,b,u,v,bounds)
        record.update(primary_solution=x.tolist(),primary_certificate=first)
        assert first['primal_objective']<0.
        a2,u2,v2,bounds2,scale=P.secondary_problem(c,first['primal_objective'],a,u,v,bounds)
        second=dict(cost=np.r_[np.zeros(14),np.ones(14)].tolist(),equality=a2.tolist(),equality_rhs=b.tolist(),
            inequality=u2.tolist(),inequality_rhs=v2.tolist(),bounds=[list(p) for p in bounds2])
        record['secondary_problem']=second
        x2,certificate=certified_lp('secondary',np.array(second['cost']),a2,b,u2,v2,bounds2)
        record.update(accepted=True,secondary_certificate=certificate,secondary_solution=x2.tolist(),
            achieved_progress_fraction=float(c@x2[:14])/first['primal_objective'])
    except L.VelocityRefusal as error:record['refusal']=error.record
    return record


def controls():
    checked=T.controls()
    problem=dict(cost=[-1.]+[0.]*13,equality=[[0.]*14],equality_rhs=[0.],
        inequality=[[1.]+[0.]*13],inequality_rhs=[1.],bounds=[[0.,1.]]+[[0.,0.]]*13)
    result=pair(problem)
    assert result['accepted'] and abs(result['achieved_progress_fraction']-.99)<1e-12
    assert abs(result['secondary_solution'][0]-.99)<1e-12
    problem['inequality_rhs']=[-1.]
    refused=pair(problem);assert not refused['accepted'] and refused['refusal']['stage']=='primary'
    assert refused['secondary_problem'] is None
    assert len(refused['refusal']['backend_attempts'])==2
    assert [x['method'] for x in refused['refusal']['backend_attempts']]==['highs-ds','highs-ipm']
    checked['additional_reserved_runtime_known_answer_infeasible_order_and_bound_controls']=6
    return checked


def declare():
    prior=C.read(X.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10by_certified_runtime_portfolio_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_bounded_certificate_gated_solver_portfolio',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does a fixed at-most-two-backend algorithm certify all five complete reserved-rate runtime pairs, including the original-entry R10BX refusal?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [X.__file__,X.STUDY,X.RESULT,__file__]],
        population=dict(names=list(NAMES),primary_count=5,secondary_count_if_primary_passes=5,
            selection='The four R10BW runtime contexts plus R10BX original-entry secondary failure. Exposed development bank. The diagnostic-only face query remains outside runtime scope and immutable.'),
        design=dict(primary='Same R10BW primary reconstruction with all original physical coefficients and bounds. Solve every primary afresh.',
            secondary='Same R10BS 99% of newly certified primary optimum and minimum normalized L1 motion.',
            algorithm='Prospectively ordered highs-ds presolve false, then highs-ipm presolve false only on solver refusal or failed independent certificate. Maximum two backend calls per LP, each with R10BK time/iteration limits. This is a new declared numerical algorithm, not a repair or retry of R10BX.',
            admission='Unchanged complete original-matrix1e-6 certificate and later physical guards. Never choose a failed answer, perturb a row, widen a tolerance or retry a physical attempt.',
            retention='Retain exact failed LP and every attempted backend status/certificate/detail when a second backend is used. On exhaustion retain both refusals. A path successor must retain such recoveries at integration probes, not just sampled nodes.',
            interpretation='Finite regression supports only a distinct model path. No native controller, contact transition, recovery or acceptance authority.'),
        numerics=dict(numpy=np.__version__,scipy=P.S.statics.scipy.__version__,options=K.OPTIONS,
            backend_order=[dict(method=m,presolve=p) for m,p in BACKENDS],certificate_tolerance=K.CERT),
        checks=['163 inherited plus6 runtime known-answer, two-attempt exhaustion and order/bound checks; shared coverage.',
            'Full cold replay of every pair and retained backend failure.'],
        research_sources=C.read(W.STUDY)['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and P.S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();rows=[]
    population=T.population()+[(NAMES[-1],C.read(X.RESULT)['trajectory'][0]['velocity_refusal'])]
    for name,original in population:
        if name in NAMES:rows.append(dict(name=name,result=pair(primary_problem(original))))
    assert [row['name'] for row in rows]==list(NAMES)
    accepted=[row['name'] for row in rows if row['result']['accepted']]
    return dict(schema_version='sporespore_r10by_certified_runtime_portfolio_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=rows,
        summary=dict(pair_count=len(rows),accepted_count=len(accepted),accepted_pairs=accepted,all_runtime_pairs_certified=len(accepted)==len(rows),
            second_backend_uses=sum(row['result'][key]['backend_attempt_count']>1 for row in rows for key in ['primary_certificate','secondary_certificate'] if row['result'][key] is not None)),
        new_model_increments=0,solver_selected=False,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10BY prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result);print(json.dumps(T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(T.present(result,True),indent=2))
