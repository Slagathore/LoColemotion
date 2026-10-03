"""Consistent active-face polishing and finite descent-field sensitivity.

Polish every eligible original QP answer, including ones already certified, to
test whether certificate-triggered switching causes integration chatter.
"""
import argparse
import json
import subprocess
import numpy as np
import r10cv_active_face_motion_polish as V
import r10cw_polished_ground_approach_path as W

U,C,S,F,E,K,L=V.U,V.C,V.S,V.F,V.E,V.K,V.L
R,I,T=W.R,W.I,W.T
STUDY=C.ROOT/'sdk/recovery/r10cx_consistent_polish_field_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cx_consistent_polish_field_result_v1.json'
STATUS='CertifiedConsistentFacePolish'
SCALES=(1e-8,1e-6)


def from_original(problem,original):
    with np.errstate(over='ignore',invalid='ignore'):
        dual=U.recover_duals(problem,original)
        face=V.polish(problem,original,dual)
    nonfinite=[];dual=F.J.safe_record(dual,nonfinite=nonfinite);face=F.J.safe_record(face,nonfinite=nonfinite)
    accepted=bool(face['accepted'] and not nonfinite)
    answer=dict(success=accepted,status=STATUS if accepted else 'RefusedConsistentFacePolish',
        message='Every eligible seed receives one active-face proposal and full original recertification.',
        iterations=original['iterations'],accepted=accepted,solution=face.get('candidate'),certificate=None,detail=None,
        consistent_face_polish=dict(problem=problem,original=original,dual_recovery=dual,active_face_polish=face),nonfinite_diagnostics=nonfinite)
    if accepted:
        check=face['dual_recovery'];answer.update(certificate=check['certificate'],detail=check['detail'],multipliers=check['dual_solution'])
    json.dumps(answer,allow_nan=False)
    return answer


def solve_qp(a,b,u,v,bounds,start):
    original=F.solve_qp(a,b,u,v,bounds,start)
    p=dict(equality=a.tolist(),equality_rhs=b.tolist(),inequality=u.tolist(),inequality_rhs=v.tolist(),bounds=bounds,start=start.tolist())
    return from_original(p,original)


def controls():
    checked=V.controls()
    a=np.array([[1.,0.]]);b=np.zeros(1);u=np.array([[0.,-1.]]);v=np.array([-.5])
    result=solve_qp(a,b,u,v,[(None,None),(None,None)],np.array([0.,.5]))
    assert result['accepted'] and result['status']==STATUS
    assert result['consistent_face_polish']['original']['accepted']
    assert result['consistent_face_polish']['active_face_polish']['accepted'] and np.max(np.abs(np.array(result['solution'])-[0.,.5]))<1e-12
    checked['additional_already_certified_seed_always_polished_status_and_exact_optimum_controls']=3
    return checked


def declare():
    prior=C.read(W.STUDY)
    assert C.read(W.RESULT)['summary']['stop_reason']=='integrator_rhs_budget'
    C.write_new(STUDY,dict(schema_version='sporespore_r10cx_consistent_polish_field_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_consistent_polish_and_local_field_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does consistently polishing every eligible seed preserve the65-case regression and reduce local velocity variation at the R10CW budget probe?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [W.__file__,W.STUDY,W.RESULT,__file__]],
        population=dict(prior['population'],coverage='All65 R10CV exact QPs plus the unadmitted R10CW budget probe and56 perturbations:14 coordinates x2 signs x2 scales. Compare conditional and consistent polish on the same fresh primary/secondary problems.'),
        design=dict(algorithm='Fresh unchanged R10CM QP, then R10CU fixed-primal dual recovery and R10CV single active-face candidate on EVERY eligible finite seed, including already certified seeds. All original objectives/constraints and full1e-6 admission certificates remain. No conditional fallback to a less accurate seed if polishing refuses.',
            bound='One original QP, at most two certified dual-LP portfolios and one minimum-norm dense solve per direction, exactly as the worst-case R10CV bound. Explicit CertifiedConsistentFacePolish status and complete original/dual/face receipts.',
            sensitivity='Reconstruct only admitted R10CQ/R10CS snapshots, then the separate R10CW unadmitted budget probe. Independently rebase each +/−1e-8 and1e-6 coordinate perturbation. Fresh same95% primary progress objective for each; compare maximum normalized-velocity change from central pose separately by scale for conditional and consistent algorithms. Retain failures rather than dropping them.',
            boundary='Finite local numerical diagnosis only. No global smoothness, finite integration, contact acquisition, native world, controller or release authority.'),
        numerics=dict(prior['numerics'],perturbation_scales=list(SCALES)),checks=['256 inherited plus3 always-polish controls;259 with shared coverage.','65-case exact baseline regression,57-pose paired sensitivity and full cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def reconstruct_probe():
    model,_,replay,caps,heading=R.reconstruct();previous=C.read(W.RESULT)
    assert T.snapshot(model)==previous['initial']
    for row in previous['trajectory']:
        assert T.snapshot(model)==row['before']
        if not row['admitted']:break
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));assert T.snapshot(model)==row['after']
    assert T.snapshot(model)==previous['final']
    probe=I.advance(model,np.array(previous['trajectory'][-1]['last_integration_probe']['delta']))
    return probe,previous['summary']['selected_modes'],heading


def compare(problem):
    a,b,u,v=[np.array(problem[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
    conditional=V.solve_qp(a,b,u,v,problem['bounds'],np.array(problem['start']))
    original=conditional.get('fixed_primal_dual_recovery',{}).get('original',conditional)
    return conditional,from_original(problem,original)


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();bank=[]
    for prior in C.read(V.RESULT)['problems']:
        conditional,consistent=compare(prior['problem']);assert conditional==prior['candidate']
        bank.append(dict(name=prior['name'],problem=prior['problem'],conditional=conditional,consistent=consistent))
    probe,modes,heading=reconstruct_probe();poses=[('central',probe,0.,None,None)]
    for scale in SCALES:
        for coordinate in range(14):
            for sign in (-1.,1.):
                delta=np.zeros(14);delta[coordinate]=sign*scale
                poses.append((f'coordinate{coordinate}_{sign:+g}_{scale:g}',I.advance(probe,delta),scale,coordinate,sign))
    rows=[]
    for name,model,scale,coordinate,sign in poses:
        primary=R.P.solve_problem(R.problem(model,modes,heading,'right_rear_only')[0],.95)
        row=dict(name=name,scale=scale,coordinate=coordinate,sign=sign,snapshot=T.snapshot(model),primary_result=primary,conditional=None,consistent=None)
        if primary['quadratic_problem'] is not None:
            row['conditional'],row['consistent']=compare(primary['quadratic_problem'])
            seed=row['conditional'].get('fixed_primal_dual_recovery',{}).get('original',row['conditional'])
            assert seed==primary['quadratic_result']
        rows.append(row)
    sensitivity=[]
    for method in ('conditional','consistent'):
        for scale in SCALES:
            selected=[row for row in rows if row['scale']==scale];center=rows[0][method]
            admitted=[row for row in selected if row[method] and row[method]['accepted']]
            changes=[float(np.max(np.abs(np.array(row[method]['solution'])-center['solution']))) for row in admitted] if center and center['accepted'] else []
            sensitivity.append(dict(method=method,scale=scale,central_certified=bool(center and center['accepted']),perturbations=28,certified_perturbations=len(admitted),maximum_normalized_velocity_change=max(changes) if changes else None))
    assert len(bank)==65 and len(rows)==57
    summary=dict(regression_problems=65,consistent_regression_certified=sum(row['consistent']['accepted'] for row in bank),
        field_poses=57,conditional_field_certified=sum(bool(row['conditional'] and row['conditional']['accepted']) for row in rows),
        consistent_field_certified=sum(bool(row['consistent'] and row['consistent']['accepted']) for row in rows),sensitivity=sensitivity,
        new_model_increments=0,unadmitted_probe_promoted=False)
    return dict(schema_version='sporespore_r10cx_consistent_polish_field_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,regression=bank,field=rows,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CX prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:
            assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result)
        else:result=C.read(RESULT);assert result==derive()
        print(json.dumps(dict(ok=True,cold_replay=not args.create,summary=result['summary']),indent=2))
