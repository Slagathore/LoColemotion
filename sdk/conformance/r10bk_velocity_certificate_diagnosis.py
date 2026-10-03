"""Four declared numerical variants on R10BJ's exact retained failed LP.

No model path is continued, no old refusal is regraded, and no solver is selected
for a controller. Every variant is retained under the same certificate limit.
"""
import argparse
import ast
import copy
import json
import subprocess
import numpy as np
from scipy.optimize import linprog

import r10bj_retained_rolling_path as J

C, S = J.C, J.S
STUDY = C.ROOT/'sdk/recovery/r10bk_velocity_certificate_diagnosis_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bk_velocity_certificate_diagnosis_result_v1.json'
CASES = [('highs-ds', True), ('highs-ds', False), ('highs-ipm', True), ('highs-ipm', False)]
CERT = 1e-6
OPTIONS = dict(S.statics.OPTIONS, time_limit=30., maxiter=100000, ipm_optimality_tolerance=1e-12)


def certify(result, c, a, b, u, v, bounds):
    x = result.x; eq = result.eqlin.marginals; inequality = result.ineqlin.marginals
    lower = result.lower.marginals; upper = result.upper.marginals
    primal = max(float(np.max(np.abs(a@x-b), initial=0.)), float(np.max(u@x-v, initial=0.)))
    stationarity = c-a.T@eq-u.T@inequality-lower-upper
    dual = float(b@eq+v@inequality)
    complementarity = float(np.max(np.abs((v-u@x)*inequality), initial=0.)); unbounded_dual = 0.
    for i, (lo, hi) in enumerate(bounds):
        if lo is None:unbounded_dual = max(unbounded_dual, abs(lower[i]))
        else:
            primal = max(primal, lo-x[i]); dual += lo*lower[i]; complementarity = max(complementarity, abs((x[i]-lo)*lower[i]))
        if hi is None:unbounded_dual = max(unbounded_dual, abs(upper[i]))
        else:
            primal = max(primal, x[i]-hi); dual += hi*upper[i]; complementarity = max(complementarity, abs((hi-x[i])*upper[i]))
    record = dict(primal_max_residual=float(primal), stationarity_max_residual=float(np.max(np.abs(stationarity))),
        dual_sign_violation=max(float(np.max(inequality, initial=0.)), float(np.max(-lower, initial=0.)), float(np.max(upper, initial=0.))),
        complementarity_max_residual=float(complementarity), unbounded_dual_max_residual=float(unbounded_dual),
        primal_objective=float(c@x), dual_objective=float(dual), objective_gap=abs(float(c@x)-dual))
    checks = ['primal_max_residual', 'stationarity_max_residual', 'dual_sign_violation',
        'complementarity_max_residual', 'unbounded_dual_max_residual', 'objective_gap']
    record['accepted'] = all(np.isfinite(record[k]) and record[k] <= CERT for k in checks)
    coordinate = int(np.argmax(np.abs(stationarity))); contributions = []
    for name, matrix, marginal in [('equality', a, eq), ('inequality', u, inequality)]:
        for index, value in enumerate(matrix[:, coordinate]*marginal):
            if value != 0.:contributions.append(dict(kind=name, row=index, value=float(value)))
    active = list(a)
    active.extend(u[np.abs(u@x-v) <= 1e-8])
    for index, (lo, hi) in enumerate(bounds):
        if (lo is not None and abs(x[index]-lo) <= 1e-8) or (hi is not None and abs(x[index]-hi) <= 1e-8):active.append(np.eye(len(c))[index])
    detail = dict(solution=x.tolist(), equality_marginals=eq.tolist(), inequality_marginals=inequality.tolist(),
        lower_marginals=lower.tolist(), upper_marginals=upper.tolist(), stationarity_vector=stationarity.tolist(),
        worst_stationarity_coordinate=coordinate,
        largest_dual_contributions=sorted(contributions, key=lambda row:abs(row['value']), reverse=True)[:10],
        active_matrix_singular_values=np.linalg.svd(np.array(active), compute_uv=False).tolist())
    return record, detail


def solve(problem, method, presolve):
    c, a, b, u, v = [np.array(problem[k], dtype=float) for k in ['cost', 'equality', 'equality_rhs', 'inequality', 'inequality_rhs']]
    result = linprog(c, A_eq=a, b_eq=b, A_ub=u, b_ub=v, bounds=problem['bounds'], method=method,
        options=dict(OPTIONS, presolve=presolve))
    record = dict(method=method, presolve=presolve, success=bool(result.success), status=int(result.status),
        message=result.message, iterations=int(result.nit), crossover_iterations=int(getattr(result, 'crossover_nit', 0)), certificate=None)
    if result.success:record['certificate'], record['detail'] = certify(result, c, a, b, u, v, problem['bounds'])
    return record


def controls():
    checked = J.controls()
    problem = dict(cost=[-1., 0.], equality=[[0., 1.]], equality_rhs=[0.],
        inequality=[[1., 0.]], inequality_rhs=[1.], bounds=[[0., None], [None, None]])
    for method, presolve in CASES:
        result = solve(problem, method, presolve)
        assert result['success'] and result['certificate']['accepted']
        assert abs(result['certificate']['primal_objective']+1.) < 1e-12
    c = np.array([-1., 0.]); a = np.array([[0., 1.]]); b = np.zeros(1); u = np.array([[1., 0.]]); v = np.ones(1)
    result = linprog(c, A_eq=a, b_eq=b, A_ub=u, b_ub=v, bounds=problem['bounds'], method='highs-ds', options=OPTIONS)
    result = copy.deepcopy(result); result.ineqlin.marginals += .1
    assert not certify(result, c, a, b, u, v, problem['bounds'])[0]['accepted']
    assert np.linalg.svd(np.array([[1., 1.], [1., 1.+1e-10]]), compute_uv=False)[-1] < 1e-9
    checked['additional_four_solver_known_answers_bad_dual_and_near_dependency_controls'] = 10
    return checked


def declare():
    old = C.read(J.STUDY)
    record = dict(schema_version='sporespore_r10bk_velocity_certificate_diagnosis_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_exact_retained_lp_numerical_diagnosis', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Does R10BJ step98 primary LP admit an independently verified certificate under each of four declared solver settings, and do large cancelling dual terms accompany failure?',
        dependencies=old['dependencies']+[C.bind(p) for p in [J.__file__, J.STUDY, J.RESULT, __file__]],
        population=dict(source_result=C.bind(J.RESULT), selection='Exact velocity_refusal matrices, bounds and cost from the final retained R10BJ row only.',
            held_out=False, lp_count=1, variants=[dict(method=m, presolve=p) for m, p in CASES]),
        numerics=dict(numpy=np.__version__, scipy=S.statics.scipy.__version__, options=OPTIONS,
            certificate_tolerance=CERT, active_row_diagnostic_tolerance=1e-8),
        checks=['119 inherited plus10 solver known-answer, corrupted-dual and near-dependency controls; inherited coverage shared.',
            'All four results retained, including failed statuses and failed independent certificates.',
            'Full cold replay; no selected backend, propagated step or regraded R10BJ result.'],
        research_sources=[dict(url='https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.linprog-highs-ds.html',
            use='Installed-version dual simplex, presolve, solver status and marginal conventions.'),
            dict(url='https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.linprog-highs-ipm.html',
            use='Installed-version interior point and crossover numerical comparison, not a physical validation.')],
        claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def derive():
    declaration = C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); previous = C.read(J.RESULT); row = previous['trajectory'][-1]; problem = row['velocity_refusal']
    assert row['model_step'] == 98 and problem['stage'] == 'primary_forward_motion'
    original_certificate = ast.literal_eval(problem['error'][len('AssertionError('):-1])
    rows = [solve(problem, method, presolve) for method, presolve in CASES]
    accepted = [r for r in rows if r['certificate'] is not None and r['certificate']['accepted']]
    return dict(schema_version='sporespore_r10bk_velocity_certificate_diagnosis_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, original_refusal=problem,
        original_certificate=original_certificate, variants=rows,
        summary=dict(variants_tested=len(rows), solver_successes=sum(r['success'] for r in rows), certificates_accepted=len(accepted),
            original_stationarity_residual=original_certificate['stationarity_max_residual'],
            current_default_stationarity_residual=rows[0]['certificate']['stationarity_max_residual'] if rows[0]['certificate'] else None,
            accepted_objectives=[r['certificate']['primal_objective'] for r in accepted]),
        solver_selected=False, model_steps_propagated=0, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], solver_selected=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); args = parser.parse_args()
    if args.declare:declare(); print('R10BK prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
