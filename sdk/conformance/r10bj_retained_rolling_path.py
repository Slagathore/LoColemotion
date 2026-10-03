"""Distinct scaled velocity LP and incrementally retained rolling path.

The original R10BI failure remains immutable. Objective, geometry/force limits,
integration budget and sampled admission remain the same in this successor.
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
import r10bi_incomplete_execution_closure as closure

B, T, S, C, G, Z = I.B, I.T, I.S, I.C, I.G, I.Z
STUDY = C.ROOT/'sdk/recovery/r10bj_retained_rolling_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bj_retained_rolling_path_result_v1.json'


class VelocityRefusal(Exception):
    def __init__(self, record):self.record = record; super().__init__(record['stage'])


def certified_lp(stage, cost, a, b, u, v, bounds):
    try:return S.statics.lp(cost, a, b, u, v, bounds)
    except AssertionError as error:
        # A refused status or certificate is never replaced by a best-effort
        # direction. Preserve exact inputs so numerical failure is diagnosable.
        raise VelocityRefusal(dict(stage=stage, error=repr(error), cost=cost.tolist(),
            equality=a.tolist(), equality_rhs=b.tolist(), inequality=u.tolist(), inequality_rhs=v.tolist(),
            bounds=[[None if x is None else float(x) for x in pair] for pair in bounds])) from error


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
    checked = I.controls()
    cost = np.r_[-.0004, np.zeros(13)]; a = np.zeros((1, 14)); u = np.zeros((1, 14)); v = np.zeros(1)
    _, scaled_u, scaled_v, _, scale = secondary_problem(cost, -.0003, a, u, v, [(-1., 1.)]*14)
    for x in (.749999, .75, .750001):
        witness = np.r_[x, np.zeros(13), abs(x), np.zeros(13)]
        assert (cost@witness[:14] <= -.0003+1e-10) == (scaled_u[1]@witness <= scaled_v[1])
        assert abs((scaled_u[1]@witness-scaled_v[1])*scale-(cost@witness[:14]+.0003-1e-10)) < 1e-18
    try:certified_lp('manufactured_infeasible', np.array([1.]), np.array([[1.], [1.]]), np.array([0., 1.]), np.zeros((0, 1)), np.zeros(0), [(None, None)])
    except VelocityRefusal as error:assert error.record['stage'] == 'manufactured_infeasible' and error.record['equality_rhs'] == [0., 1.]
    else:raise AssertionError('infeasible LP was accepted')
    assert journal_line(dict(value=1)) == b'{"value":1}\n'
    checked['additional_scaled_row_equivalence_failed_problem_and_journal_controls'] = 8
    return checked


def declare():
    old = C.read(I.STUDY); closure.audit()
    record = dict(schema_version='sporespore_r10bj_retained_rolling_path_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_scaled_velocity_lp_and_retained_rolling_path', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Can the unchanged rolling-path objective be evaluated completely using a scaled secondary constraint and retained solver failures, with analytic geometry derivatives independently checked?',
        dependencies=old['dependencies']+[C.bind(p) for p in [I.__file__, I.STUDY, closure.__file__, closure.RECORD, __file__]],
        population=old['population'], model=copy.deepcopy(old['model']), numerics=old['numerics'],
        changes=dict(secondary_row='Divide only the secondary LP near-optimum row and RHS by max(abs(cost),abs(bound),1e-12). The physical bound remains primary optimum+1e-10 m; no tolerance, objective or budget relaxation.',
            derivative='Use the existing analytic body-point Jacobian for shape-floor velocity rows; compare against central finite differences at original entry and every admitted candidate node, error<=1e-7.',
            retention='Append and flush each completed or refused model-step record to a new exclusive JSONL journal. Preserve exact failed LP matrices, bounds, primary witness/certificate and integration probe when present. Numerical refusal never proves physical infeasibility.',
            execution='Fresh original entry and fresh identity; never recover or promote the93 progress lines from incomplete R10BI. Creation performs one full derivation; a separate fresh-process audit performs the complete deterministic replay.'),
        checks=['111 inherited plus8 row-equivalence, exact failed-problem and journal controls; inherited coverage shared.',
            'Native replay, exact bindings, analytic floor Jacobian comparison and unchanged sampled admission.',
            'Journal content hash is recomputed by a full fresh-process replay with no journal mutation.'],
        research_sources=old['research_sources'], claim_boundary=old['claim_boundary'])
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
                print(f'R10BJ step {accepted}: gap {model.gap(zero):.9f}', file=sys.stderr, flush=True)
                if model.gap(zero) <= 1e-6:stop = 'geometric_cap_hull_model_target'; break
    final = T.snapshot(model)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop, selected_modes=modes,
        initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        torso_forward_translation_m=float((np.array(final['torso_position_m'])-reference['torso_position_m'])@heading),
        total_integrator_rhs_calls=sum(r['rhs_calls'] for r in trajectory), model_target_reached=stop == 'geometric_cap_hull_model_target')
    retain(dict(kind='terminal_summary', value=summary))
    return dict(schema_version='sporespore_r10bj_retained_rolling_path_result_v1', ledger_scope=declaration['ledger_scope'],
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
    if args.declare:declare(); print('R10BJ prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires a fresh durable --journal path')
        from pathlib import Path
        journal_path = Path(args.journal).resolve(); assert journal_path.is_relative_to(C.EVIDENCE.resolve())
        assert not RESULT.exists()
        with journal_path.open('xb') as journal:result = derive(journal)
        C.write_new(RESULT, result); print(json.dumps(present(result, False), indent=2))
    else:print(json.dumps(audit(), indent=2))
