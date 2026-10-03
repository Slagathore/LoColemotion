"""One active-face primal polish after fixed-primal dual recovery fails.

Dual support proposes equalities for a minimum-norm candidate only. Every
original constraint and the full original certificate still gate admission.
"""
import argparse
import json
import subprocess
import numpy as np
import r10cu_fixed_primal_dual_recovery as U

C,S,F,E,K,L=U.C,U.S,U.F,U.E,U.K,U.L
STUDY=C.ROOT/'sdk/recovery/r10cv_active_face_motion_polish_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cv_active_face_motion_polish_result_v1.json'
POLISHED_STATUS='CertifiedActiveFacePolish'


def polish(problem,original,recovery):
    record=dict(accepted=False,refusal=None,active_rows=[],candidate=None,dual_recovery=None)
    if not (recovery.get('dual_certificate') or {}).get('accepted') or recovery.get('dual_solution') is None:
        record['refusal']='no_certified_dual_support';return record
    a,b,u,v=[np.array(problem[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
    x=np.array(original['solution']);full_u,full_v,_=U.expanded(u,v,problem['bounds'],len(x))
    beta=np.array(recovery['dual_solution'][len(a):])
    threshold=float(np.sqrt(np.finfo(float).eps)*max(1.,float(np.max(np.abs(beta),initial=0.))))
    active=np.flatnonzero(beta>threshold)
    matrix=np.vstack((a,full_u[active]));rhs=np.r_[b,full_v[active]]
    cutoff=max(matrix.shape)*np.finfo(float).eps
    candidate,_,rank,singular=np.linalg.lstsq(matrix,rhs,rcond=cutoff)
    record.update(active_rows=active.tolist(),dual_support_threshold=threshold,relative_svd_cutoff=cutoff,
        candidate=candidate.tolist(),active_rank=int(rank),active_singular_values=singular.tolist(),
        active_max_residual=float(np.max(np.abs(matrix@candidate-rhs),initial=0.)),
        maximum_primal_change=float(np.max(np.abs(candidate-x),initial=0.)))
    if not np.all(np.isfinite(candidate)):
        record['refusal']='nonfinite_candidate';return record
    # Status eligibility applies to the original solver seed. The returned
    # polished answer has its own explicit status and a new full certificate.
    verified=U.recover_duals(problem,dict(original,solution=candidate.tolist()))
    record['dual_recovery']=verified
    record['accepted']=verified['accepted']
    record['refusal']=None if verified['accepted'] else 'polished_full_original_certificate'
    return record


def solve_qp(a,b,u,v,bounds,start):
    previous=U.solve_qp(a,b,u,v,bounds,start)
    if previous['accepted']:return previous
    if 'fixed_primal_dual_recovery' not in previous:return previous
    retained=previous['fixed_primal_dual_recovery']
    with np.errstate(over='ignore',invalid='ignore'):raw=polish(retained['problem'],retained['original'],retained['recovery'])
    nonfinite=[];candidate=F.J.safe_record(raw,nonfinite=nonfinite);candidate['nonfinite_diagnostics']=nonfinite
    if nonfinite:candidate['accepted']=False
    if not candidate['accepted']:
        answer=dict(previous,active_face_polish=candidate)
    else:
        dual=candidate['dual_recovery']
        answer=dict(success=True,status=POLISHED_STATUS,message='One minimum-norm active-face candidate passed the unchanged complete original QP certificate.',
            iterations=previous['iterations'],solution=candidate['candidate'],multipliers=dual['dual_solution'],
            certificate=dual['certificate'],detail=dual['detail'],accepted=True,
            original_solver_status=previous['status'],fixed_primal_dual_recovery=retained,active_face_polish=candidate)
    json.dumps(answer,allow_nan=False)
    return answer


def controls():
    checked=U.controls()
    p=dict(equality=[[1.,0.]],equality_rhs=[0.],inequality=[[0.,-1.]],inequality_rhs=[-.5],bounds=[[None,None],[None,None]],start=[0.,1.])
    original=dict(status='AlmostSolved',solution=[0.,1.]);dual=U.recover_duals(p,original)
    assert not dual['accepted'] and dual['dual_certificate']['accepted']
    result=polish(p,original,dual)
    assert result['accepted'] and np.max(np.abs(np.array(result['candidate'])-[0.,.5]))<1e-12
    assert result['active_rows']==[0] and original['solution']==[0.,1.]
    assert result['dual_recovery']['certificate']['objective_gap']<=1e-12
    unavailable=polish(p,original,dict(dual_certificate=None,dual_solution=None));assert not unavailable['accepted'] and unavailable['candidate'] is None
    wrong=dict(dual,dual_solution=[0.,0.]);rejected=polish(p,original,wrong)
    assert not rejected['accepted'] and rejected['dual_recovery']['refusal']=='original_primal_infeasible'
    checked['additional_active_face_known_optimum_support_nonmutation_certificate_missing_dual_and_wrong_face_controls']=6
    return checked


def declare():
    prior=C.read(U.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10cv_active_face_motion_polish_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_bounded_active_face_primal_polish',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can one explicitly bounded active-face candidate correct the R10CS secondary objective error under unchanged original constraints and certificates?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [U.__file__,U.STUDY,U.RESULT,__file__]],population=prior['population'],
        design=dict(first='Fresh unchanged R10CU: original R10CM QP, then fixed-primal dual recovery only if needed. Preserve passing answers exactly.',
            candidate='Only after failed final QP certificate with a certified dual LP, select inequality/bound indices beta > sqrt(machine epsilon)*max(1,max(abs(beta))). Combine these rows with every original equality and compute one minimum-norm candidate with numpy.linalg.lstsq, relative SVD cutoff max(matrix dimensions)*machine epsilon. This proposes a candidate; no original constraint is removed from admission.',
            verify='At the proposed primal, run the same R10CU certified dual LP and unchanged full original QP certificate. Reject infeasible/nonfinite/nonoptimal candidates. Return explicit CertifiedActiveFacePolish status, original solver status and every diagnostic; never label a polished candidate as an original backend output.',
            bound='At most one original QP, two dual-LP portfolio calls, and one small dense least-squares solve. Each LP portfolio is at most two unchanged backends. No iterative active-set search, retry, integration-budget increase, physical/progress tolerance change or objective change.',
            retention='Retain full failed original QP/duals, exact active indices, selection threshold, singular values/rank, candidate movement and full recertification. Cold replay all65 cases; require original backend records to equal retained evidence. R10CU negative stays immutable.',
            boundary='Finite numerical regression only; no integrated motion, contact, controller, native world or release authority.'),
        numerics=prior['numerics'],checks=['250 inherited plus6 active-face proposal/refusal controls;256 with shared coverage.','Full65-case regression and cold replay with unchanged original backend records.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();rows=[]
    for previous in C.read(U.RESULT)['problems']:
        p=previous['problem'];a,b,u,v=[np.array(p[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
        answer=solve_qp(a,b,u,v,p['bounds'],np.array(p['start']))
        original=answer.get('fixed_primal_dual_recovery',{}).get('original',answer)
        assert original==previous['retained_original'],previous['name']
        rows.append(dict(name=previous['name'],problem=p,retained_original=previous['retained_original'],candidate=answer))
    assert len(rows)==65
    summary=dict(problem_count=len(rows),certified_problems=sum(row['candidate']['accepted'] for row in rows),
        polished_cases=sum(row['candidate']['status']==POLISHED_STATUS for row in rows),
        prior_population_certified=sum(row['candidate']['accepted'] for row in rows[:-1]),
        r10cs_failed_runtime_certified=rows[-1]['candidate']['accepted'],new_model_increments=0)
    return dict(schema_version='sporespore_r10cv_active_face_motion_polish_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=rows,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CV prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:
            assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result)
        else:result=C.read(RESULT);assert result==derive()
        print(json.dumps(dict(ok=True,cold_replay=not args.create,summary=result['summary']),indent=2))
