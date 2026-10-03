"""Fixed interior-point backend on four complete reserved-rate runtime LP pairs.

Historical face queries and old near-maximum secondary objectives remain intact.
Each new secondary problem uses 99% of its newly certified primary optimum.
"""
import argparse
import json
import subprocess
import numpy as np

import r10bt_retained_lp_regression as T

C,K,P,L = T.C,T.K,T.P,T.L
STUDY=C.ROOT/'sdk/recovery/r10bw_reserved_runtime_lp_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10bw_reserved_runtime_lp_result_v1.json'
NAMES=(T.NAMES[0],T.NAMES[1],T.NAMES[3],T.NAMES[4])


def certified_lp(stage,cost,a,b,u,v,bounds):
    problem=dict(cost=cost.tolist(),equality=a.tolist(),equality_rhs=b.tolist(),
        inequality=u.tolist(),inequality_rhs=v.tolist(),bounds=[[x for x in pair] for pair in bounds])
    result=K.solve(problem,'highs-ipm',False)
    if result['certificate'] is not None and result['certificate']['accepted']:
        return np.array(result['detail']['solution']),result['certificate']
    raise L.VelocityRefusal(dict(stage=stage,solver_status=result['status'],solver_message=result['message'],
        solver_success=result['success'],certificate=result['certificate'],solver_detail=result.get('detail'),**problem))


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
    checked['additional_reserved_runtime_known_answer_and_infeasible_controls']=4
    return checked


def declare():
    prior=C.read(T.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10bw_reserved_runtime_lp_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_fixed_backend_reserved_runtime_lp_pairs',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does presolve-disabled interior point independently certify both stages of all four reserved-rate runtime LP pairs?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [T.__file__,T.STUDY,T.RESULT,__file__]],
        population=dict(names=list(NAMES),primary_count=4,secondary_count_if_primary_passes=4,
            selection='R10BT four runtime primary/secondary contexts. Exclude only the auxiliary face-extreme query, which is not called by the path velocity solver. Exposed development data, not held out.'),
        design=dict(primary='Use saved R10BJ primary exactly; for each saved secondary, strip epigraph and objective-bound rows, recover the original primary objective using its recorded positive row scale, and retain all original geometry and variable bounds.',
            secondary='Solve each primary afresh with the declared backend, then construct the unchanged R10BS 99% progress secondary from that new certified optimum. This explicitly changes old R10BO/R10BQ objectives; their results remain immutable.',
            backend='One fixed highs-ipm, presolve false, R10BK options. No equality elimination, row deletion, retry, fallback or changed certificate limit.',
            interpretation='Both full original-problem certificates must pass for each pair. A positive finite bank supports a distinct path successor, not a general backend guarantee, native controller or acceptance.'),
        numerics=dict(numpy=np.__version__,scipy=P.S.statics.scipy.__version__,options=K.OPTIONS,method='highs-ipm',presolve=False,certificate_tolerance=K.CERT),
        checks=['163 inherited plus4 reserved-runtime known-answer and infeasible checks; shared coverage.','Complete cold replay of every primary/secondary input, solution, certificate and refusal.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and P.S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();rows=[]
    for name,original in T.population():
        if name in NAMES:rows.append(dict(name=name,result=pair(primary_problem(original))))
    assert [row['name'] for row in rows]==list(NAMES)
    accepted=[row['name'] for row in rows if row['result']['accepted']]
    return dict(schema_version='sporespore_r10bw_reserved_runtime_lp_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=rows,
        summary=dict(pair_count=len(rows),accepted_count=len(accepted),accepted_pairs=accepted,all_runtime_pairs_certified=len(accepted)==len(rows)),
        new_model_increments=0,solver_selected=False,**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10BW prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result);print(json.dumps(T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(T.present(result,True),indent=2))
