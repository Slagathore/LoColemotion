"""Compare four fixed backends on five retained velocity LPs, without integration.

The bank covers each retained complete velocity-LP failure in the current path
lineage and the successful R10BO center. Original matrices and limits survive.
No adaptive fallback, physical motion, or controller selection occurs here.
"""
import argparse
import json
import subprocess
import numpy as np

import r10bs_reserved_torso_raise_path as P

C, K, L = P.C, P.L.K, P.L
STUDY = C.ROOT/'sdk/recovery/r10bt_retained_lp_regression_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bt_retained_lp_regression_result_v1.json'
FIELDS = ('cost', 'equality', 'equality_rhs', 'inequality', 'inequality_rhs', 'bounds')
NAMES = ('r10bj_step98_primary', 'r10bo_center_secondary',
         'r10bo_coordinate7_lower_face', 'r10bq_step17_secondary', 'r10bs_step70_secondary')


def population():
    j = C.read(K.J.RESULT)
    o = C.read(P.R.O.RESULT)
    q = C.read(P.R.Q.RESULT)
    p = C.read(P.RESULT)
    assert j['trajectory'][-1]['model_step'] == 98
    assert q['trajectory'][-1]['additional_model_step'] == 17
    assert p['trajectory'][-1]['model_step'] == 70
    face = [row for row in o['face_extremes'] if row['coordinate'] == 7 and row['cost_sign'] == 1]
    assert len(face) == 1 and face[0]['refusal'] is not None
    return list(zip(NAMES, (j['trajectory'][-1]['velocity_refusal'], o['center_problem'],
        face[0]['refusal'], q['trajectory'][-1]['velocity_refusal'], p['trajectory'][-1]['velocity_refusal']), strict=True))


def primal_residual(problem, value):
    x = np.array(value); a = np.array(problem['equality']); b = np.array(problem['equality_rhs'])
    u = np.array(problem['inequality']); v = np.array(problem['inequality_rhs'])
    residual = max(0., float(np.max(np.abs(a@x-b), initial=0.)), float(np.max(u@x-v, initial=0.)))
    for coordinate, (lower, upper) in enumerate(problem['bounds']):
        if lower is not None:residual = max(residual, lower-x[coordinate])
        if upper is not None:residual = max(residual, x[coordinate]-upper)
    return float(residual)


def controls():
    checked = P.controls()
    problem = dict(cost=[-1.,0.], equality=[[0.,1.]], equality_rhs=[0.],
        inequality=[[1.,0.]], inequality_rhs=[1.], bounds=[[0.,1.],[None,None]])
    for x, expected in [([1.,0.],0.), ([1.1,0.],.1), ([-.1,0.],.1), ([1.,.2],.2)]:
        assert abs(primal_residual(problem,x)-expected)<1e-12
    # Every selected backend must retain infeasibility rather than a direction.
    bad = dict(problem, inequality_rhs=[-1.])
    for method, presolve in K.CASES:
        result = K.solve(bad,method,presolve)
        assert not result['success'] and result['certificate'] is None
    checked['additional_full_primal_witness_and_four_infeasible_backend_controls'] = 8
    return checked


def declare():
    prior = C.read(P.STUDY)
    record = dict(schema_version='sporespore_r10bt_retained_lp_regression_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_retained_velocity_lp_backend_regression',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does any one of the four existing fixed solver configurations certify all five retained failure/regression LPs without changing their matrices or bounds?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,__file__]],
        population=dict(names=list(NAMES), lp_count=5, variant_count=4, secondary_or_primary_solves=20,
            selection='Exact saved R10BJ primary, R10BO successful center and refused coordinate7 lower-face query, R10BQ additional-step17 secondary, and R10BS step70 secondary. No new pose, integration, or perturbation.',
            limitation='Finite exposed regression bank, not all possible LPs or native controller validation. The incomplete R10BI assertion did not retain exact LP matrices; R10BN retained an integration-budget refusal rather than a failed LP.'),
        variants=[dict(method=m,presolve=p) for m,p in K.CASES],
        numerics=dict(numpy=np.__version__,scipy=P.S.statics.scipy.__version__,options=K.OPTIONS,
            independent_certificate_tolerance=K.CERT),
        design=dict(unchanged='Exact retained objective, equality, inequality, variable bounds and independent full-matrix certificate. No dropped row, altered tolerance, new progress reserve or runtime fallback.',
            reproduction='Presolve-enabled dual simplex reproduces the R10BJ rejected certificate. Presolve-disabled dual simplex reproduces the R10BO center certificate and three retained solver refusals.',
            witnesses='For retained constructed secondary witnesses, independently check equality, inequality and every variable bound, including epigraph nonnegativity.',
            selection='Report which fixed configurations certify the entire bank. This diagnostic itself selects no backend for integration or native use.',
            retention='All twenty solver statuses, solutions, duals and certificates retained, with a complete separate cold replay.'),
        checks=['155 inherited plus8 full-primal and infeasible-backend controls; inherited coverage shared.',
            'Exact original status/certificate reproduction, all problem matrices retained, full cold replay.'],
        research_sources=C.read(K.STUDY)['research_sources'], claim_boundary=prior['claim_boundary'])
    C.write_new(STUDY,record)


def derive():
    declaration = C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy']
    assert P.S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); rows = []
    historical = C.read(K.RESULT)
    for name, original in population():
        problem = {key:original[key] for key in FIELDS}
        variants = [K.solve(problem,method,presolve) for method,presolve in K.CASES]
        if name == NAMES[0]:
            for key in ('success','status','message','certificate'):
                assert variants[0][key] == historical['variants'][0][key]
        elif name == NAMES[1]:
            assert variants[1]['certificate'] == original['secondary_certificate']
            assert variants[1]['detail']['solution'] == original['secondary_solution']
        else:
            for new, old in [('success','solver_success'),('status','solver_status'),('message','solver_message'),('certificate','certificate')]:
                assert variants[1][new] == original[old]
        witness = original.get('constructed_secondary_witness')
        rows.append(dict(name=name,problem=problem,variants=variants,
            retained_constructed_witness=witness,
            constructed_witness_full_primal_residual=None if witness is None else primal_residual(problem,witness)))
    summary = []
    for index,(method,presolve) in enumerate(K.CASES):
        accepted = [row['name'] for row in rows if row['variants'][index]['certificate'] is not None and row['variants'][index]['certificate']['accepted']]
        summary.append(dict(method=method,presolve=presolve,accepted_count=len(accepted),accepted_problems=accepted,
            certifies_entire_bank=len(accepted)==len(rows)))
    return dict(schema_version='sporespore_r10bt_retained_lp_regression_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=rows,
        summary=dict(lp_count=len(rows),variant_count=len(K.CASES),solves=len(rows)*len(K.CASES),variants=summary),
        solver_selected=False,new_model_increments=0,**declaration['claim_boundary'])


def present(result, replayed):
    return dict(ok=True,full_replay_passed=replayed,summary=result['summary'],controls=result['controls'],
        solver_selected=False,world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare(); print('R10BT prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists(); result=derive(); C.write_new(RESULT,result)
        print(json.dumps(present(result,False),indent=2))
    else:
        result=C.read(RESULT); assert result==derive(); print(json.dumps(present(result,True),indent=2))
