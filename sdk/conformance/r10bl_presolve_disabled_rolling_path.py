"""Fresh rolling path with presolve disabled only in its velocity LPs.

R10BJ and R10BK remain immutable. The original entry, objectives, force solves,
geometry limits, integration budget and sampled admission remain unchanged.
"""
import argparse
import copy
import hashlib
import json
import subprocess
import sys
import numpy as np
from scipy.integrate import solve_ivp

import r10bi_rolling_contact_path as I
import r10bj_retained_rolling_path as J
import r10bk_velocity_certificate_diagnosis as K
from scipy.optimize import linprog

B, T, S, C, G, Z = I.B, I.T, I.S, I.C, I.G, I.Z
STUDY = C.ROOT/'sdk/recovery/r10bl_presolve_disabled_rolling_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bl_presolve_disabled_rolling_path_result_v1.json'
OPTIONS = dict(S.statics.OPTIONS, presolve=False)


class VelocityRefusal(Exception):
    def __init__(self, record):self.record = record; super().__init__(record['stage'])


def certified_lp(stage, cost, a, b, u, v, bounds):
    result = linprog(cost, A_eq=a, b_eq=b, A_ub=u, b_ub=v, bounds=bounds,
        method='highs-ds', options=OPTIONS)
    certificate = detail = None
    if result.success:
        certificate, detail = K.certify(result, cost, a, b, u, v, bounds)
        if certificate['accepted']:return result.x, certificate
    # Never substitute an uncertified direction or change backend after failure.
    raise VelocityRefusal(dict(stage=stage, solver_status=int(result.status), solver_message=result.message,
        solver_success=bool(result.success), certificate=certificate, solver_detail=detail,
        cost=cost.tolist(), equality=a.tolist(), equality_rhs=b.tolist(), inequality=u.tolist(), inequality_rhs=v.tolist(),
        bounds=[[None if x is None else float(x) for x in pair] for pair in bounds]))


def floor_jacobian(model):
    poses = model.poses(np.zeros(14))
    _, jacobian, _, _, _ = S.statics.frame(model.packet, model.d, model.com(poses))
    return np.array([jacobian(body, model.point(poses, body, point))[1] for body, point, _ in model.features])


def secondary_problem(cost, optimum, a, u, v, bounds):
    bound = optimum+1e-10
    scale = max(float(np.max(np.abs(cost))), abs(bound), 1e-12)
    secondary_u = np.vstack((np.c_[u, np.zeros((len(u), 14))], np.r_[cost/scale, np.zeros(14)][None, :],
        np.c_[np.eye(14), -np.eye(14)], np.c_[-np.eye(14), -np.eye(14)]))
    secondary_v = np.r_[v, bound/scale, np.zeros(28)]
    return np.c_[a, np.zeros((len(a), 14))], secondary_u, secondary_v, bounds+[(0., None)]*14, scale


def velocity(model, modes, heading):
    zero = np.zeros(14); j = I.material_jacobian(model)
    floor = model.features_y(zero); fj = floor_jacobian(model)
    equality = []; inequality = list(-fj); rhs = list(floor-np.minimum(0., floor))
    for i, mode in enumerate(modes):
        inequality.append(-j[i, 1]); rhs.append(0.)
        if mode:
            equality.append(j[i, 1])
            if mode == 1:equality.extend((j[i, 0], j[i, 2]))
            else:
                axis, sign = Z.MODES[mode]
                for other in (-1., 1.):inequality.append(other*j[i, 2-axis]-sign*j[i, axis]); rhs.append(0.)
    a = np.array(equality).reshape((-1, 14)); u = np.array(inequality); v = np.array(rhs)
    lo, hi = S.bounds(model.joints); cost = np.r_[-heading, np.zeros(11)]
    a = a*S.MAXIMUM; u = u*S.MAXIMUM; cost = cost*S.MAXIMUM
    anorm = np.maximum(np.max(np.abs(a), axis=1), 1e-12); a /= anorm[:, None]
    unorm = np.maximum(np.max(np.abs(u), axis=1), 1e-12); u /= unorm[:, None]; v /= unorm
    bounds = list(zip(lo/S.MAXIMUM, hi/S.MAXIMUM))
    first_x, first = certified_lp('primary_forward_motion', cost, a, np.zeros(len(a)), u, v, bounds)
    second_a, second_u, second_v, second_bounds, scale = secondary_problem(cost, first['primal_objective'], a, u, v, bounds)
    witness = np.r_[first_x, np.abs(first_x)]
    witness_error = max(float(np.max(np.abs(second_a@witness))), float(np.max(second_u@witness-second_v)))
    try:
        result, second = certified_lp('secondary_normalized_motion', np.r_[np.zeros(14), np.ones(14)], second_a,
            np.zeros(len(a)), second_u, second_v, second_bounds)
    except VelocityRefusal as error:
        error.record.update(primary_solution=first_x.tolist(), primary_certificate=first,
            constructed_secondary_witness=witness.tolist(), constructed_witness_max_residual=witness_error,
            objective_row_scale=scale)
        raise
    return result[:14]*S.MAXIMUM, dict(maximum_progress=first, minimum_normalized_motion=second)


def check_node(base, model, delta, modes, caps, heading, reference, fraction):
    # Reproduce original geometry/load/material-work admission without changing
    # its tolerances. Use this successor's velocity LP explicitly, not mutation
    # of the imported historical module's globals.
    zero = np.zeros(14); points = model.contact_points(zero); original = np.array(reference['original_contact_markers_m'])
    residual = []
    for i, mode in enumerate(modes):
        if mode:
            residual.append(points[i, 1]-original[i, 1])
            if mode == 1 and not model.contacts[i]['classified_as_foot']:residual.extend(points[i, [0, 2]]-original[i, [0, 2]])
    lo, hi = S.bounds(base.joints); bounded = np.r_[0:3, 6:14]
    guards = dict(active_contact=float(np.max(np.abs(residual), initial=0.)),
        original_contact_descent=float(np.max(original[:, 1]-points[:, 1])),
        original_floor=float(np.max(np.minimum(0., reference['shape_bottom_witnesses_m'])-model.features_y(zero))),
        local_floor=float(np.max(np.minimum(0., base.features_y(zero))-model.features_y(zero))),
        translation_and_joint_bounds=max(float(np.max(fraction*lo[bounded]-delta[bounded])),float(np.max(delta[bounded]-fraction*hi[bounded]))),
        rotation_norm=float(np.linalg.norm(delta[3:6])-fraction*.6*G.DT),
        original_headroom=float(np.max(np.abs(model.joints)-np.maximum(S.LIMITS-.02, np.abs(reference['joints_rad'])))))
    node = dict(fraction=fraction, delta=delta.tolist(), guards=guards, forward_progress_m=float(delta[:3]@heading),
        foot_hull_gap_m=model.gap(zero), admitted=False, refusal=None)
    if not B.geometry_allowed(guards):node['refusal'] = 'integrated_geometry_guard'; return node
    if node['forward_progress_m'] <= 1e-9*fraction:node['refusal'] = 'no_finite_body_progress'; return node
    node['floor_jacobian_comparison_error'] = float(np.max(np.abs(floor_jacobian(model)-S.derivative(model.features_y, zero))))
    if node['floor_jacobian_comparison_error'] > 1e-7:node['refusal'] = 'analytic_floor_jacobian_guard'; return node
    node['load'] = Z.load(model, zero, modes, caps)
    if not node['load']['feasible']:node['refusal'] = 'sampled_stationary_force_refusal'; return node
    try:direction, certificate = velocity(model, modes, heading)
    except VelocityRefusal as error:node.update(refusal='sampled_velocity_lp_refusal', velocity_refusal=error.record); return node
    material = I.material_jacobian(model)@direction
    node['velocity'] = direction.tolist(); node['velocity_certificates'] = certificate; node['material_contact_motion_per_model_interval_m'] = material.tolist()
    forces = np.array(node['load']['forces_world_n']); checks = []
    for i, mode in enumerate(modes):
        work = float(forces[i]@material[i]); minimum = -Z.X.MU*forces[i, 1]*float(np.max(np.abs(material[i, [0, 2]]))) if mode >= 2 else 0.
        valid = np.max(np.abs(forces[i])) <= 1e-6 if mode == 0 else Z.work_allowed(work, minimum)
        if mode == 1:valid = valid and np.max(np.abs(material[i])) <= 1e-9
        if mode >= 2:
            axis, sign = Z.MODES[mode]; valid = valid and abs(material[i, 1]) <= 1e-9 and abs(material[i, 2-axis])-sign*material[i, axis] <= 1e-9
        checks.append(dict(contact=i, mode=mode, sampled_work_per_model_interval_j=work, minimum_diamond_work_j=minimum, ok=bool(valid)))
    node['sampled_material_dissipation'] = checks
    if not all(row['ok'] for row in checks):node['refusal'] = 'sampled_material_velocity_or_work_guard'; return node
    node['admitted'] = True
    return node


def step(base, modes, caps, heading, reference):
    calls = 0; max_certificate = 0.; probe = None
    def rhs(time, q):
        nonlocal calls, max_certificate, probe
        calls += 1; probe = dict(model_interval_fraction=float(time), delta=q.tolist())
        if calls > I.MAX_RHS:raise I.IntegrationRefusal('integrator_rhs_budget')
        model = I.advance(base, q)
        if np.any(np.abs(model.joints) > S.LIMITS):raise I.IntegrationRefusal('integrator_probe_outside_hard_joint_limits')
        direction, certificates = velocity(model, modes, heading)
        for certificate in certificates.values():
            for name in ('primal_max_residual', 'stationarity_max_residual', 'dual_sign_violation', 'complementarity_max_residual', 'objective_gap'):
                max_certificate = max(max_certificate, certificate[name])
        derivative = direction.copy(); derivative[3:6] = np.linalg.solve(I.left_jacobian(q[3:6]), direction[3:6])
        return derivative
    result = dict(nodes=[], admitted=False, refusal=None)
    try:solution = solve_ivp(rhs, (0., 1.), np.zeros(14), t_eval=B.FRACTIONS, **I.INTEGRATOR)
    except (I.IntegrationRefusal, VelocityRefusal) as error:
        result.update(refusal='integration_velocity_lp_refusal' if isinstance(error, VelocityRefusal) else str(error),
            rhs_calls=calls, maximum_velocity_certificate_residual=max_certificate, last_integration_probe=probe)
        if isinstance(error, VelocityRefusal):result['velocity_refusal'] = error.record
        return result
    result.update(rhs_calls=calls, maximum_velocity_certificate_residual=max_certificate,
        integrator=dict(success=bool(solution.success), status=int(solution.status), message=solution.message, nfev=int(solution.nfev)))
    if not solution.success or len(solution.t) != len(B.FRACTIONS):result['refusal'] = 'integrator_unsuccessful'; return result
    for fraction, delta in zip(B.FRACTIONS, solution.y.T, strict=True):
        node = check_node(base, I.advance(base, delta), delta, modes, caps, heading, reference, fraction); result['nodes'].append(node)
        if not node['admitted']:result['refusal'] = node['refusal']; return result
    result['admitted'] = True
    return result


def journal_line(value):return (json.dumps(value, separators=(',', ':'), allow_nan=False)+'\n').encode('utf-8')


def controls():
    checked = K.controls()
    problem = C.read(J.RESULT)['trajectory'][-1]['velocity_refusal']
    c, a, b, u, v = [np.array(problem[k], dtype=float) for k in
        ['cost', 'equality', 'equality_rhs', 'inequality', 'inequality_rhs']]
    solution, certificate = certified_lp('retained_r10bj_problem', c, a, b, u, v, problem['bounds'])
    assert certificate['accepted'] and certificate['stationarity_max_residual'] <= K.CERT
    assert abs(c@solution+1.2357972573680568e-5) < 1e-12
    try:
        certified_lp('manufactured_infeasible', np.array([1.]), np.array([[1.], [1.]]), np.array([0., 1.]),
            np.zeros((0, 1)), np.zeros(0), [(None, None)])
    except VelocityRefusal as error:
        assert error.record['stage'] == 'manufactured_infeasible'
        assert error.record['equality_rhs'] == [0., 1.] and not error.record['solver_success']
    else:raise AssertionError('infeasible LP was accepted')
    assert OPTIONS == dict(S.statics.OPTIONS, presolve=False) and K.CERT == 1e-6
    checked['additional_selected_backend_saved_problem_and_infeasible_retention_controls'] = 6
    return checked


def declare():
    old = C.read(J.STUDY)
    record = dict(schema_version='sporespore_r10bl_presolve_disabled_rolling_path_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_presolve_disabled_velocity_lp_rolling_path', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Can a fresh original-entry rolling path continue beyond the numerical refusal using presolve-disabled velocity LPs under the unchanged objective and admission limits?',
        dependencies=old['dependencies']+[C.bind(p) for p in [J.__file__, J.STUDY, J.RESULT, K.__file__, K.STUDY, K.RESULT, __file__]],
        population=old['population'], model=copy.deepcopy(old['model']),
        numerics=dict(old['numerics'], velocity_lp_method='highs-ds', velocity_lp_options=OPTIONS,
            independent_certificate_tolerance=K.CERT),
        changes=dict(velocity_solver='Disable presolve only in primary and secondary velocity LPs. No fallback. Retain failed solver status or exact certificate, marginals, matrices, bounds and integration probe.',
            certificate='Use R10BK independent primal/dual certificate, all residuals <=1e-6, including zero marginal for unbounded variable sides.',
            unchanged='R10BJ objective, scaled secondary bound, analytic floor Jacobian, integration and horizon budgets, mode selection, stationary-force solvers, geometry, headroom and material-work admission remain unchanged.',
            execution='Fresh original entry, fixed entry-selected modes and fresh identity. No continuation or regrading of R10BJ. Incremental durable journal and separate complete cold replay.'),
        checks=['129 inherited plus6 selected-backend saved-problem and infeasible-retention controls; inherited coverage shared.',
            'Native replay, exact bindings, analytic floor Jacobian comparison and unchanged sampled admission.',
            'Journal content hash recomputed by complete fresh-process replay.'],
        research_sources=C.read(K.STUDY)['research_sources']+old['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def derive(journal=None):
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    native = S.Model(packet, descriptor, entry['joint_positions_rad']); packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = I.CapModel(packet, descriptor, entry['joint_positions_rad']); zero = np.zeros(14); caps = [v/G.DT for v in entry['caps']]
    conversion = (model.contact_points(zero)-native.contact_points(zero)).tolist(); reference = T.snapshot(model)
    heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    material = T.advance(model, zero)
    jacobian_error = float(np.max(np.abs(I.material_jacobian(model)-S.derivative(material.contact_points, zero))))
    floor_error = float(np.max(np.abs(floor_jacobian(model)-S.derivative(model.features_y, zero))))
    assert jacobian_error < 1e-7 and floor_error < 1e-7
    search_problem = Z.Problem(material, caps, heading); search = search_problem.solve()
    verification = None; trajectory = []; accepted = 0; stop = 'entry_mode_search_refusal'; modes = None
    digest = hashlib.sha256(); journal_count = 0
    def retain(value):
        nonlocal journal_count
        line = journal_line(value); digest.update(line); journal_count += 1
        if journal is not None:journal.write(line); journal.flush()
    retain(dict(kind='inputs', declaration=C.bind(STUDY), implementation=C.bind(__file__), search=search))
    if search['proposal'] is not None:
        modes = search['proposal']['modes']; solution, certificate = search_problem.certify_mode(modes)
        assert abs(certificate['maximum_progress']['primal_objective']-search['proposal']['recomputed_objective']) <= 1e-6
        verification = dict(modes=modes, physical_solution=solution.tolist(), certificate=certificate, initial_load=Z.load(model, zero, modes, caps))
        stop = 'initial_mode_load_refusal'
        if verification['initial_load']['feasible']:
            stop = 'finite_model_horizon'
            for index in range(I.MAX_STEPS):
                row = step(model, modes, caps, heading, reference); row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
                if not row['admitted']:stop = row['refusal']; retain(dict(kind='model_step', value=row)); break
                accepted += 1; model = I.advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
                retain(dict(kind='model_step', value=row))
                print(f'R10BL step {accepted}: gap {model.gap(zero):.9f}', file=sys.stderr, flush=True)
                if model.gap(zero) <= 1e-6:stop = 'geometric_cap_hull_model_target'; break
    final = T.snapshot(model)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop, selected_modes=modes,
        initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        torso_forward_translation_m=float((np.array(final['torso_position_m'])-reference['torso_position_m'])@heading),
        total_integrator_rhs_calls=sum(r['rhs_calls'] for r in trajectory), model_target_reached=stop == 'geometric_cap_hull_model_target')
    retain(dict(kind='terminal_summary', value=summary))
    return dict(schema_version='sporespore_r10bl_presolve_disabled_rolling_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        cap_site_conversion_world_m=conversion, material_jacobian_comparison_error=jacobian_error,
        initial_floor_jacobian_comparison_error=floor_error, search=search, fixed_mode_verification=verification,
        initial=reference, final=final, summary=summary, trajectory=trajectory,
        journal=dict(line_count=journal_count, raw_sha256='sha256:'+digest.hexdigest()), **declaration['claim_boundary'])


def present(result, replayed):
    return dict(ok=True, full_replay_passed=replayed, controls=result['controls'], summary=result['summary'], journal=result['journal'],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def audit():
    result = C.read(RESULT); assert result == derive(); return present(result, True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); parser.add_argument('--journal'); args = parser.parse_args()
    if args.declare:declare(); print('R10BL prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires a fresh durable --journal path')
        from pathlib import Path
        journal_path = Path(args.journal).resolve(); assert journal_path.is_relative_to(C.EVIDENCE.resolve())
        assert not RESULT.exists()
        with journal_path.open('xb') as journal:result = derive(journal)
        C.write_new(RESULT, result); print(json.dumps(present(result, False), indent=2))
    else:print(json.dumps(audit(), indent=2))
