"""Finite geometry/progress-objective sensitivity at the R10CN budget probe.

Counterfactual cap alignment is diagnostic only. No pose is advanced or admitted.
"""
import argparse
import json
import subprocess
import numpy as np
import r10cn_implied_row_right_rear_path as P
import r10bp_cap_geometry_diagnosis as A

F=P.F
C,S,I,T,L=P.C,P.S,P.I,P.T,P.L
STUDY=C.ROOT/'sdk/recovery/r10co_placement_field_diagnosis_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10co_placement_field_diagnosis_result_v1.json'
FRACTIONS=(.99,.95,.90)
GEOMETRIES=('original','all_distal_caps_aligned')
SCALES=(1e-8,1e-6)


def solve_problem(p,fraction):
    cost,a,b,u,v=[np.array(p[key]) for key in ('cost','equality','equality_rhs','inequality','inequality_rhs')]
    bounds=p['bounds'];record=dict(fraction=fraction,accepted=False,primary_certificate=None,quadratic_problem=None,quadratic_result=None,refusal=None)
    try:first_x,first=F.E.W.certified_lp('primary_placement_cost_reduction',cost,a,b,u,v,bounds)
    except L.VelocityRefusal as failure:record['refusal']=failure.record;return record
    bound=fraction*first['primal_objective'];scale=max(float(np.max(np.abs(cost))),abs(bound),1e-12)
    u2=np.vstack((u,cost/scale));v2=np.r_[v,bound/scale]
    record.update(primary_solution=first_x.tolist(),primary_certificate=first,
        quadratic_problem=dict(equality=a.tolist(),equality_rhs=b.tolist(),inequality=u2.tolist(),inequality_rhs=v2.tolist(),bounds=bounds,start=first_x.tolist()))
    answer=F.solve_qp(a,b,u2,v2,bounds,first_x);record['quadratic_result']=answer
    if answer['accepted']:
        x=np.array(answer['solution']);record.update(accepted=True,normalized_velocity=x.tolist(),
            achieved_progress_fraction=float(cost@x)/first['primal_objective'])
    return record


def probes():
    return [dict(name='phase_entry',coordinate=None,sign=0,scale=0.),dict(name='last_admitted',coordinate=None,sign=0,scale=0.),
        dict(name='budget_probe',coordinate=None,sign=0,scale=0.)]+[
        dict(name='near_budget_probe',coordinate=i,sign=sign,scale=scale) for scale in SCALES for i in range(14) for sign in (-1,1)]


def controls():
    checked=F.controls()
    p=dict(cost=[-1.,0.],equality=[[0.,1.]],equality_rhs=[0.],inequality=np.zeros((0,2)).tolist(),inequality_rhs=[],bounds=[(0.,1.),(None,None)])
    # Use one harmless inequality to preserve the matrix width in JSON.
    p['inequality']=[[0.,0.]];p['inequality_rhs']=[1.]
    for fraction in FRACTIONS:
        row=solve_problem(p,fraction)
        assert row['accepted'] and abs(row['normalized_velocity'][0]-fraction)<1e-9
    assert len(probes())==59 and len({(x['name'],x['coordinate'],x['sign'],x['scale']) for x in probes()})==59
    checked['additional_three_fraction_known_answers_and_probe_population_controls']=4
    checked['additional_mixed_precision_endpoint_identity_mirroring_and_variant_controls']=A.controls()['additional_mixed_precision_endpoint_identity_mirroring_and_variant_controls']
    return checked


def reconstruct():
    model,lift,replay,caps=P.reconstruct();previous=C.read(P.RESULT);assert T.snapshot(model)==previous['initial']
    entry=model;accepted=0
    for row in previous['trajectory']:
        assert T.snapshot(model)==row['before']
        if not row['admitted']:break
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));accepted+=1
        assert T.snapshot(model)==row['after']
    assert accepted==11 and T.snapshot(model)==previous['final']
    assert row['additional_model_step']==12 and row['refusal']=='integrator_rhs_budget'
    heading=np.array(lift['initial']['torso_basis_columns'])[0].copy();heading[1]=0.;heading/=np.linalg.norm(heading)
    return entry,model,previous,replay,heading


def declare():
    prior=C.read(P.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10co_placement_field_diagnosis_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_placement_geometry_and_progress_field_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='At the retained R10CN integration refusal, do coherent distal-cap endpoint representation or a5%/10% progress reserve reduce local certified velocity sensitivity?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,A.__file__,A.STUDY,A.RESULT,__file__]],
        population=dict(prior['population'],coverage='59 exposed diagnostic poses: original placement entry, last admitted R10CN pose, retained refused probe, and56 neighbors. Six predeclared geometry/fraction combinations,354 direction solves. No integration.'),
        geometries=list(GEOMETRIES),progress_fractions=list(FRACTIONS),
        design=dict(reconstruction='Replay only69 saved lift deltas and11 admitted R10CN deltas, requiring exact snapshots. No reintegration and no refused probe propagation.',
            probes='Each normalized coordinate at each sign of1e-8 and1e-6 around the saved unadmitted probe, plus entry/last/center. No threshold-defined continuity or global claim.',
            geometry='Original geometry versus the already declared R10BP all-distal-cap alignment: use +/- configured cap centers for distal floor endpoints. Contact sites, poses, radii and all other geometry remain unchanged. This is a coherent counterfactual, not verified native collision rounding or production selection.',
            objectives='For each geometry, independently certify the primary placement optimum and require99%,95% or90% in the quadratic secondary. Only this development objective-bound RHS changes. All original physical constraints, limits, solver settings and complete independent certificates remain unchanged.',
            verification='Original geometry at99% must equal the production R10CM selector at entry, last admitted pose and saved budget center in primary certificate, QP inputs, outputs and velocity. Aligned variants preserve contact sites exactly.',
            retention='Full inputs, output certificates and refusals; per-variant local velocity changes, primary rate changes and cap/floor offsets. Complete cold replay. No variant selection or physical authority.'),
        numerics=dict(C.read(F.STUDY)['numerics'],perturbation_scales=list(SCALES)),checks=['220 inherited plus4 reserve/population and4 endpoint controls;228 with overlapping inherited coverage.','Exact admitted-prefix reconstruction, baseline agreement and complete354-result cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    checked=controls();entry,last,previous,replay,heading=reconstruct();modes=previous['summary']['selected_modes']
    center=np.array(previous['trajectory'][-1]['last_integration_probe']['delta']);cases=[]
    for geometry in GEOMETRIES:
        for fraction in FRACTIONS:
            rows=[]
            for specification in probes():
                if specification['name']=='phase_entry':base=entry;delta=np.zeros(14)
                elif specification['name']=='last_admitted':base=last;delta=np.zeros(14)
                else:
                    delta=center.copy()
                    if specification['coordinate'] is not None:delta[specification['coordinate']]+=specification['sign']*specification['scale']*S.MAXIMUM[specification['coordinate']]
                    base=I.advance(last,delta)
                model=A.AlignedModel(base,geometry)
                assert np.array_equal(model.contact_points(np.zeros(14)),base.contact_points(np.zeros(14)))
                p=F.E.E.problem(model,modes,heading);answer=solve_problem(p,fraction)
                if geometry=='original' and fraction==.99 and specification['name']!='near_budget_probe':
                    original=F.quadratic_direction(p)
                    for key in ('accepted','primary_certificate','quadratic_problem','quadratic_result','normalized_velocity'):assert answer.get(key)==original.get(key)
                rows.append(dict(specification=specification,delta=delta.tolist(),problem=p,result=answer))
            sensitivity=[];reference=rows[2]['result']
            if reference['accepted']:
                x=np.array(reference['normalized_velocity'])
                for scale in SCALES:
                    changes=[dict(specification=row['specification'],maximum_normalized_velocity_change=float(np.max(np.abs(np.array(row['result']['normalized_velocity'])-x))),primary_objective_change=row['result']['primary_certificate']['primal_objective']-reference['primary_certificate']['primal_objective'])
                        for row in rows[3:] if row['specification']['scale']==scale and row['result']['accepted']]
                    sensitivity.append(dict(scale=scale,certified_probes=len(changes),largest_change=max(changes,key=lambda row:row['maximum_normalized_velocity_change']) if changes else None))
            cases.append(dict(geometry=geometry,fraction=fraction,center_geometry=A.geometry(A.AlignedModel(I.advance(last,center),geometry)),probes=rows,
                summary=dict(certified_poses=sum(row['result']['accepted'] for row in rows),sensitivity=sensitivity)))
    summary=dict(pose_count=59,variant_count=6,direction_count=354,cases=[dict(geometry=c['geometry'],fraction=c['fraction'],**c['summary']) for c in cases])
    return dict(schema_version='sporespore_r10co_placement_field_diagnosis_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),
        controls=checked,entry_contact_replay=replay,cases=cases,summary=summary,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CO prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result);print(json.dumps(F.E.W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(F.E.W.T.present(result,True),indent=2))
