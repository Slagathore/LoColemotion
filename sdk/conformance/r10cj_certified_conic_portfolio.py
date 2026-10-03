"""Bounded full-then-reduced conic portfolio with original certificates.

At most two numerical QP solves; identical physical constraints and objective.
Every refused formulation survives in the returned diagnostic record.
"""
import argparse
import copy
import json
import subprocess
import numpy as np
import r10ci_serializable_conic_motion as J
H=J.H
F,P,E,C,K,S,L=J.F,J.P,J.E,J.C,J.K,J.S,J.L
STUDY=C.ROOT/'sdk/recovery/r10cj_certified_conic_portfolio_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cj_certified_conic_portfolio_result_v1.json'


def solve_qp(a,b,u,v,bounds,start):
    with np.errstate(over='ignore',invalid='ignore'):
        raw=E.solve_qp(a,b,u,v,bounds,start)
    nonfinite=[];first=J.safe_record(raw,nonfinite=nonfinite)
    first['nonfinite_diagnostics']=nonfinite
    first['accepted']=bool(not nonfinite and F.eligible(first['status'],first['certificate']))
    attempts=[dict(formulation='full_coordinates',result=first)]
    if not first['accepted']:
        second=J.solve_qp(a,b,u,v,bounds,start)
        attempts.append(dict(formulation='equality_coordinates',result=second))
    selected=copy.deepcopy(attempts[-1]['result'])
    selected.update(formulation_attempts=attempts,selected_formulation=attempts[-1]['formulation'] if selected['accepted'] else None,
        formulation_attempt_count=len(attempts))
    return selected


def controls():
    checked=J.controls();a=np.array([[1.,1.]]);b=np.array([1.]);u=np.zeros((0,2));v=np.zeros(0)
    first=solve_qp(a,b,u,v,[(0.,1.),(0.,1.)],np.array([1.,0.]))
    assert first['accepted'] and first['formulation_attempt_count']==1
    assert first['selected_formulation']=='full_coordinates' and np.max(np.abs(np.array(first['solution'])-.5))<1e-10
    bad=solve_qp(a,b,u,v,[(1.,2.),(1.,2.)],np.array([1.,1.]))
    assert not bad['accepted'] and bad['formulation_attempt_count']==2
    assert [r['formulation'] for r in bad['formulation_attempts']]==['full_coordinates','equality_coordinates']
    assert bad['selected_formulation'] is None
    json.dumps(bad,allow_nan=False)
    checked['additional_bounded_conic_portfolio_order_success_exhaustion_and_retention_controls']=6
    return checked


def declare():
    prior=C.read(J.STUDY)
    C.write_new(STUDY,dict(prior,schema_version='sporespore_r10cj_certified_conic_portfolio_study_v1',
        ledger_scope=dict(prior['ledger_scope'],authority_mode='prospective_bounded_conic_formulation_portfolio'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does a fixed full-coordinate then equality-coordinate QP portfolio certify all60 exact regression problems?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [J.__file__,J.STUDY,J.RESULT,__file__]],
        design=dict(prior['design'],solver='At most two QP solves, each with the same pinned binary and existing200-iteration/30-second limits. Try full coordinates first; only after status or original-certificate refusal try equality coordinates. Preserve both complete attempts, nonfinite tags, selected formulation and attempt count. The first independently certified eligible result is returned. No objective, row, bound or independent tolerance changes.'),
        checks=['214 inherited plus6 portfolio known-answer, ordering, exhaustion and retention checks.','All60 exact QPs and full cold replay.']))


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
    if not record['accepted']:raise L.VelocityRefusal(dict(stage='certified_conic_portfolio',diagnostic=record))
    certificate=dict(record['quadratic_result']['certificate'],qp_status=record['quadratic_result']['status'],
        qp_status_rule='solved_or_almost_solved_with_full_original_certificate')
    certificate['formulation_attempt_count']=record['quadratic_result']['formulation_attempt_count']
    certificate['selected_formulation']=record['quadratic_result']['selected_formulation']
    if certificate['formulation_attempt_count']>1:
        certificate['retained_solver_recovery']=dict(problem=record['quadratic_problem'],attempts=record['quadratic_result']['formulation_attempts'])
    return np.array(record['velocity']),dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=certificate)

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
        prior_population_certified=sum(row['candidate']['accepted'] for row in bank[:-1]),new_runtime_failure_certified=bank[-1]['candidate']['accepted'],second_formulation_uses=sum(row['candidate']['formulation_attempt_count']>1 for row in bank))
    return dict(schema_version='sporespore_r10cj_certified_conic_portfolio_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=bank,summary=summary,**declaration['claim_boundary'])

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CJ prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result);print(json.dumps(E.W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(E.W.T.present(result,True),indent=2))
