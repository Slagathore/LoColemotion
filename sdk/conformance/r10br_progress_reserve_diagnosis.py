"""Four declared secondary progress requirements on retained velocity problems.

This diagnoses development objective conditioning. Physical admission limits,
old results and integration budgets remain unchanged; no path is propagated.
"""
import argparse
import json
import subprocess
import numpy as np

import r10bo_velocity_field_diagnosis as O
import r10bq_eligible_raise_reselection as Q

L, C, S, G, I, N = O.L, O.C, O.S, O.G, O.I, O.N
STUDY = C.ROOT/'sdk/recovery/r10br_progress_reserve_diagnosis_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10br_progress_reserve_diagnosis_result_v1.json'
FRACTIONS = (None, .99, .95, .90)


def solve(problem, fraction):
    a = np.array(problem['equality']); b = np.array(problem['equality_rhs'])
    u = np.array(problem['inequality']); v = np.array(problem['inequality_rhs']); cost = np.array(problem['cost'])
    row = len(v)-29; optimum = problem['primary_certificate']['primal_objective']; scale = problem['objective_row_scale']
    assert optimum < 0. and np.array_equal(cost, np.r_[np.zeros(14),np.ones(14)])
    assert np.max(np.abs(u[row,14:])) == 0.
    if fraction is not None:v[row] = fraction*optimum/scale
    result = dict(fraction=fraction, physical_progress_lower_bound_m=-v[row]*scale,
        success=False, normalized_velocity=None, certificate=None, refusal=None)
    try:x,certificate=L.certified_lp('declared_progress_reserve',cost,a,b,u,v,problem['bounds'])
    except L.VelocityRefusal as failure:result['refusal']=failure.record;return result
    result.update(success=True,normalized_velocity=x[:14].tolist(),certificate=certificate,
        achieved_physical_progress_m=-float(u[row]@x)*scale,
        achieved_fraction_of_primary_optimum=float(u[row]@x)*scale/optimum)
    return result


def controls():
    checked=O.controls()
    # Manufactured primary optimum x=1. Each reserve changes only the requested
    # progress, never the x<=1 capacity; minimum absolute motion attains it.
    a=np.zeros((1,28));u=np.vstack((np.c_[np.eye(14),-np.eye(14)],np.c_[-np.eye(14),-np.eye(14)]))
    u=np.vstack((np.r_[-1.,np.zeros(27)],u));v=np.r_[-1.+1e-10,np.zeros(28)]
    problem=dict(equality=a.tolist(),equality_rhs=[0.],inequality=u.tolist(),inequality_rhs=v.tolist(),
        cost=np.r_[np.zeros(14),np.ones(14)].tolist(),bounds=[(0.,1.)]+[(0.,0.)]*13+[(0.,None)]*14,
        primary_certificate=dict(primal_objective=-1.),objective_row_scale=1.)
    for fraction in FRACTIONS:
        result=solve(problem,fraction);expected=1.-1e-10 if fraction is None else fraction
        assert result['success'] and abs(result['normalized_velocity'][0]-expected)<1e-9
        assert result['normalized_velocity'][0]<=1.
    checked['additional_four_progress_reserve_known_answer_controls']=4
    return checked


def declare():
    old=C.read(Q.STUDY)
    record=dict(schema_version='sporespore_r10br_progress_reserve_diagnosis_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_secondary_progress_requirement_diagnosis',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does explicitly reserving1%,5% or10% of the maximum instantaneous lift rate reduce local sensitivity and admit the exact retained R10BQ secondary LP?',
        dependencies=old['dependencies']+[C.bind(p) for p in [Q.__file__,Q.STUDY,Q.RESULT,__file__]],
        population=old['population'],fractions=list(FRACTIONS),
        design=dict(inputs='R10BO exact57 probe problems plus the exact failed secondary LP from R10BQ additional step17. No other pose population or path.',
            variants='Retain original primary optimum+1e-10 m requirement and three distinct requirements:99%,95%,90% of certified maximum rise. Only secondary objective-bound RHS changes; all equality/inequality coefficients, variable bounds, objective, backend and certificates are unchanged.',
            interpretation='The reserve changes a prospective development command objective, not a physical acceptance threshold. No reserve is selected for a controller or old run; all outcomes retained. Report actual achieved progress and sensitivity.',
            verification='Original57 solves reproduce R10BO physical velocities and secondary certificates exactly. The unmodified R10BQ problem reproduces its solver status/message; original failure remains immutable.',
            boundary='No integration, new model increment, native step, altered physical guard, accepted recovery or numerical budget change. Full cold replay.'),
        numerics=old['numerics'],checks=['148 inherited plus4 progress-reserve known answers; shared coverage not additive.',
            'Exact unchanged-problem reproduction before comparing counterfactual progress requirements.'],
        research_sources=old['research_sources'],claim_boundary=old['claim_boundary'])
    C.write_new(STUDY,record)


def derive():
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();base,previous,replay=O.reconstruct();old=C.read(O.RESULT)
    modes=previous['summary']['selected_modes'];center_delta=np.array(previous['trajectory'][-1]['last_integration_probe']['delta'])
    rows=[]
    for index,specification in enumerate(O.probes()):
        delta=center_delta.copy()
        if specification['coordinate'] is not None:
            i=specification['coordinate'];delta[i]+=specification['sign']*specification['scale']*S.MAXIMUM[i]
        problem=O.problem(I.advance(base,delta),modes)
        variants=[solve(problem,fraction) for fraction in FRACTIONS]
        assert variants[0]['normalized_velocity']==old['probes'][index]['result']['normalized_velocity']
        assert variants[0]['certificate']==old['probes'][index]['result']['secondary_certificate']
        rows.append(dict(specification=specification,variants=variants))
    q=C.read(Q.RESULT);refusal=q['trajectory'][-1]['velocity_refusal']
    assert q['trajectory'][-1]['additional_model_step']==17 and refusal['stage']=='secondary_normalized_motion'
    exact_variants=[solve(refusal,fraction) for fraction in FRACTIONS]
    original=exact_variants[0]['refusal'];assert original is not None
    for key in ['solver_status','solver_message','solver_success','certificate']:assert original[key]==refusal[key]
    summaries=[]
    for variant_index,fraction in enumerate(FRACTIONS):
        center=rows[0]['variants'][variant_index];sensitivity=[]
        if center['success']:
            reference=np.array(center['normalized_velocity'])
            for scale in O.SCALES:
                changes=[dict(specification=row['specification'],maximum_normalized_velocity_change=float(np.max(np.abs(np.array(row['variants'][variant_index]['normalized_velocity'])-reference))))
                    for row in rows if row['specification']['scale']==scale and row['variants'][variant_index]['success']]
                sensitivity.append(dict(scale=scale,successful_probes=len(changes),largest_change=max(changes,key=lambda row:row['maximum_normalized_velocity_change']) if changes else None))
        successful=[row['variants'][variant_index] for row in rows if row['variants'][variant_index]['success']]
        summaries.append(dict(fraction=fraction,successful_local_probes=len(successful),sensitivity=sensitivity,
            minimum_achieved_fraction=min((row['achieved_fraction_of_primary_optimum'] for row in successful),default=None),
            retained_r10bq_secondary_accepted=exact_variants[variant_index]['success']))
    return dict(schema_version='sporespore_r10br_progress_reserve_diagnosis_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,entry_contact_replay=replay,
        local_probes=rows,retained_r10bq_problem=refusal,retained_r10bq_variants=exact_variants,
        summary=dict(variant_count=4,local_probe_count=57,secondary_solves=232,variants=summaries,new_model_increments=0),
        **declaration['claim_boundary'])


def audit():
    result=C.read(RESULT);assert result==derive()
    return dict(ok=True,full_replay_passed=True,controls=result['controls'],summary=result['summary'],
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for option in ('create','controls','declare'):parser.add_argument('--'+option,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10BR prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result)
        print(json.dumps(dict(ok=True,full_replay_passed=False,controls=result['controls'],summary=result['summary']),indent=2))
    else:print(json.dumps(audit(),indent=2))
