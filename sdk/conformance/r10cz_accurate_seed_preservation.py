"""Preserve a tightly certified original seed only after consistent polish fails.

The original full physical/QP certificate remains unchanged. This fallback has
an additional, stricter numerical-quality requirement; passing polish is kept.
"""
import argparse
import copy
import json
import subprocess
import numpy as np
import r10cy_consistent_ground_approach_path as Y

X=Y.V
C,S,F,E,K,L=X.C,X.S,X.F,X.E,X.K,X.L
R,I,T=Y.R,Y.I,Y.T
STUDY=C.ROOT/'sdk/recovery/r10cz_accurate_seed_preservation_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cz_accurate_seed_preservation_result_v1.json'
STATUS='CertifiedAccurateOriginalSeed'
QUALITY=1e-9
CHECKS=('primal_max_residual','stationarity_max_residual','dual_sign_violation','complementarity_max_residual','unbounded_dual_max_residual','objective_gap')


def eligible_seed(original):
    certificate=original.get('certificate') or {}
    return bool(original.get('accepted') and original.get('status') in F.F.STATUSES and certificate.get('accepted')
        and all(isinstance(certificate.get(key),(int,float)) and np.isfinite(certificate[key]) and certificate[key]<=QUALITY for key in CHECKS))


def choose(consistent):
    if consistent['accepted']:return consistent
    original=consistent['consistent_face_polish']['original']
    eligible=eligible_seed(original)
    receipt=dict(quality_limit=QUALITY,quality_checks=list(CHECKS),eligible_original=eligible,consistent_attempt=consistent)
    if not eligible:return dict(consistent,accurate_seed_preservation=receipt)
    return dict(success=True,status=STATUS,message='Consistent polish refused; unchanged original seed passes full certificate and stricter numerical-quality checks.',
        iterations=original['iterations'],accepted=True,solution=original['solution'],multipliers=original['multipliers'],
        certificate=original['certificate'],detail=original['detail'],original_solver_status=original['status'],accurate_seed_preservation=receipt)


def solve_qp(a,b,u,v,bounds,start):
    return choose(X.solve_qp(a,b,u,v,bounds,start))


def controls():
    checked=X.controls();cert={key:QUALITY for key in CHECKS};cert['accepted']=True
    original=dict(accepted=True,status='Solved',certificate=cert,iterations=1,solution=[0.],multipliers=[0.],detail={})
    fixture=dict(accepted=False,consistent_face_polish=dict(original=original))
    assert eligible_seed(original) and choose(fixture)['solution']==original['solution']
    too_loose=copy.deepcopy(original);too_loose['certificate']['objective_gap']=QUALITY*1.01
    assert not eligible_seed(too_loose) and not choose(dict(fixture,consistent_face_polish=dict(original=too_loose)))['accepted']
    for key in CHECKS:
        bad=copy.deepcopy(original);bad['certificate'][key]=float('nan');assert not eligible_seed(bad)
    assert not eligible_seed(dict(original,status='MaxIterations'))
    assert not eligible_seed(dict(original,accepted=False))
    passed=dict(accepted=True,marker='preserve_exact_record');assert choose(passed) is passed
    checked['additional_strict_seed_boundary_loose_refusal_six_nonfinite_status_failed_seed_and_passing_identity_controls']=11
    return checked


def declare():
    prior=C.read(Y.STUDY);bindings={}
    for b in prior['dependencies']+[C.bind(p) for p in [Y.__file__,Y.STUDY,Y.RESULT,__file__]]:
        if b['path'] in bindings:assert bindings[b['path']]==b
        bindings[b['path']]=b
    C.write_new(STUDY,dict(schema_version='sporespore_r10cz_accurate_seed_preservation_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_strict_quality_seed_preservation',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can strictly accurate original seeds survive failed correction without changing the passing consistent field or reintroducing local switching at either exposed barrier?',
        dependencies=list(bindings.values()),population=dict(prior['population'],coverage='65 exact R10CX regression QPs,57 exact R10CX local-field QPs, and57 poses at/around the unadmitted R10CY failed probe;179 problems. Every old consistent result is freshly reproduced.'),
        design=dict(algorithm='Run unchanged R10CX consistent correction first. Return every passing result exactly. Only after refusal, preserve the identical original R10CM answer if its original full certificate passes, its original status is Solved/AlmostSolved, and EACH of the six original certificate errors is finite and <=1e-9. Otherwise retain refusal. No extra numerical backend call.',
            quality='1e-9 is an additional numerical-quality restriction, three orders stricter than the unchanged1e-6 full original certificate, chosen to exclude the approximate seeds implicated in the earlier switching barrier. It does not relax any physical or admission threshold. Local smoothness is measured, not inferred from this number.',
            retention='Explicit CertifiedAccurateOriginalSeed status, original backend status, quality checks and complete failed consistent attempt. Never modify the original primal or multiplier values. All prior failures stay immutable.',
            field='At the new unadmitted R10CY probe, independently rebase all14 coordinates at both signs and1e-8/1e-6 scales. Compare unchanged consistent versus preserved-seed directions on identical fresh95% primary/secondary problems. Also exactly replay the old57-pose field and65-case bank.',
            boundary='Finite numerical qualification only. No admitted path, new contact, native controller/world, recovery or release authority.'),
        numerics=dict(prior['numerics'],accurate_seed_quality=QUALITY,perturbation_scales=list(X.SCALES)),
        checks=['259 inherited plus11 strict-seed boundary/refusal controls;270 with shared coverage.','All179 problems and complete cold replay; no omitted failed field points.'],research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def new_probe():
    model,_,_,_,heading=R.reconstruct();previous=C.read(Y.RESULT)
    assert T.snapshot(model)==previous['initial']
    for row in previous['trajectory']:
        assert T.snapshot(model)==row['before']
        if not row['admitted']:break
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));assert T.snapshot(model)==row['after']
    assert T.snapshot(model)==previous['final']
    return I.advance(model,np.array(previous['trajectory'][-1]['last_integration_probe']['delta'])),previous['summary']['selected_modes'],heading


def pair(p):
    a,b,u,v=[np.array(p[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
    consistent=X.solve_qp(a,b,u,v,p['bounds'],np.array(p['start']))
    return consistent,choose(consistent)


def field_summary(rows,site):
    result=[]
    for method in ('consistent','candidate'):
        center=rows[0][method]
        for scale in X.SCALES:
            selected=[r for r in rows if r['scale']==scale];admitted=[r for r in selected if r[method] and r[method]['accepted']]
            changes=[float(np.max(np.abs(np.array(r[method]['solution'])-center['solution']))) for r in admitted] if center and center['accepted'] else []
            result.append(dict(site=site,method=method,scale=scale,central_certified=bool(center and center['accepted']),perturbations=28,certified_perturbations=len(admitted),maximum_normalized_velocity_change=max(changes) if changes else None))
    return result


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();previous=C.read(X.RESULT);bank=[];old_field=[]
    for row in previous['regression']:
        baseline,candidate=pair(row['problem']);assert baseline==row['consistent']
        bank.append(dict(name=row['name'],problem=row['problem'],consistent=baseline,candidate=candidate))
    for row in previous['field']:
        p=row['primary_result']['quadratic_problem'];baseline,candidate=pair(p);assert baseline==row['consistent']
        old_field.append(dict(name=row['name'],scale=row['scale'],problem=p,consistent=baseline,candidate=candidate))
    model,modes,heading=new_probe();poses=[('central',model,0.)]
    for scale in X.SCALES:
        for coordinate in range(14):
            for sign in (-1.,1.):
                delta=np.zeros(14);delta[coordinate]=sign*scale
                poses.append((f'coordinate{coordinate}_{sign:+g}_{scale:g}',I.advance(model,delta),scale))
    field=[]
    for name,pose,scale in poses:
        primary=Y.solve_problem(R.problem(pose,modes,heading,'right_rear_only')[0],.95)
        baseline=primary['quadratic_result'];candidate=choose(baseline) if baseline else None
        if name=='central':assert primary==C.read(Y.RESULT)['trajectory'][-1]['velocity_refusal']['diagnostic']
        field.append(dict(name=name,scale=scale,snapshot=T.snapshot(pose),primary=primary,consistent=baseline,candidate=candidate))
    all_rows=bank+old_field+field;assert len(all_rows)==179
    summary=dict(problem_count=179,certified_problems=sum(bool(r['candidate'] and r['candidate']['accepted']) for r in all_rows),
        preserved_seed_cases=sum(bool(r['candidate'] and r['candidate']['status']==STATUS) for r in all_rows),
        regression_certified=sum(r['candidate']['accepted'] for r in bank),old_field_certified=sum(r['candidate']['accepted'] for r in old_field),
        new_field_certified=sum(bool(r['candidate'] and r['candidate']['accepted']) for r in field),
        new_probe_certified=bool(field[0]['candidate'] and field[0]['candidate']['accepted']),
        sensitivity=field_summary(old_field,'R10CW_budget_probe')+field_summary(field,'R10CY_refused_probe'),new_model_increments=0,unadmitted_probe_promoted=False)
    return dict(schema_version='sporespore_r10cz_accurate_seed_preservation_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,regression=bank,old_field=old_field,new_field=field,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CZ prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:
            assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result)
        else:result=C.read(RESULT);assert result==derive()
        print(json.dumps(dict(ok=True,cold_replay=not args.create,summary=result['summary']),indent=2))
