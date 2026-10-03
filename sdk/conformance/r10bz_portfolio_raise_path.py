"""Fresh reserved-rate lifting path with a declared bounded solver portfolio.

The velocity LP algorithm changes from R10BS. Geometry, force, work,
reserved progress objective, certificate and integration limits stay unchanged.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import numpy as np

import r10bm_entry_raise_directions as M
import r10bn_bounded_torso_raise_path as N
import r10by_certified_runtime_portfolio as W
from scipy.integrate import solve_ivp

L, C, S, G, Z, I, T = M.L, M.C, M.S, M.G, M.Z, M.I, M.T
STUDY = C.ROOT/'sdk/recovery/r10bz_portfolio_raise_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bz_portfolio_raise_path_result_v1.json'
MAX_STEPS = 120
HEADING = np.array([0., 1., 0.])
PROGRESS_FRACTION = .99
B = L.B
VelocityRefusal = L.VelocityRefusal
certified_lp = W.certified_lp
floor_jacobian = L.floor_jacobian


def secondary_problem(cost, optimum, a, u, v, bounds):
    bound = PROGRESS_FRACTION*optimum
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


def recovery_receipts(certificates, probe):
    return [dict(probe=copy.deepcopy(probe),velocity_stage=stage,record=copy.deepcopy(certificate['retained_solver_recovery']))
        for stage,certificate in certificates.items() if 'retained_solver_recovery' in certificate]


def step(base, modes, caps, heading, reference):
    calls = 0; max_certificate = 0.; probe = None; recoveries = []
    def rhs(time, q):
        nonlocal calls, max_certificate, probe
        calls += 1; probe = dict(model_interval_fraction=float(time), delta=q.tolist())
        if calls > I.MAX_RHS:raise I.IntegrationRefusal('integrator_rhs_budget')
        model = I.advance(base, q)
        if np.any(np.abs(model.joints) > S.LIMITS):raise I.IntegrationRefusal('integrator_probe_outside_hard_joint_limits')
        direction, certificates = velocity(model, modes, heading)
        recoveries.extend(recovery_receipts(certificates,probe))
        for certificate in certificates.values():
            for name in ('primal_max_residual', 'stationarity_max_residual', 'dual_sign_violation', 'complementarity_max_residual', 'objective_gap'):
                max_certificate = max(max_certificate, certificate[name])
        derivative = direction.copy(); derivative[3:6] = np.linalg.solve(I.left_jacobian(q[3:6]), direction[3:6])
        return derivative
    result = dict(nodes=[], admitted=False, refusal=None, solver_recoveries=recoveries)
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


def controls():
    checked=W.controls()
    probe=dict(model_interval_fraction=.5,delta=[0.]*14)
    certificate=dict(retained_solver_recovery=dict(stage='secondary',problem=dict(cost=[1.]),attempts=[dict(solver_status=4),dict(solver_status=0)]))
    retained=recovery_receipts(dict(secondary=certificate),probe)
    probe['delta'][0]=1.;certificate['retained_solver_recovery']['problem']['cost'][0]=2.
    assert retained[0]['probe']['delta'][0]==0. and retained[0]['record']['problem']['cost'][0]==1.
    assert recovery_receipts(dict(primary=dict(accepted=True)),probe)==[]
    checked['additional_integration_backend_recovery_retention_controls']=2
    return checked


def declare():
    old = C.read(W.P.STUDY)
    diagnosis = C.read(W.RESULT)
    assert diagnosis['summary']['all_runtime_pairs_certified']
    record = dict(schema_version='sporespore_r10bz_portfolio_raise_path_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_bounded_portfolio_reserved_lift', question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does a fresh original-entry 99%-reserved lift with the R10BY bounded portfolio complete the bounded path under unchanged physical and numerical admission limits?',
        dependencies=C.read(W.STUDY)['dependencies']+[C.bind(p) for p in [W.__file__,W.STUDY,W.RESULT,__file__]],
        population=old['population'], selected_modes=old['selected_modes'],
        design=dict(selection='R10BY certifies all five reserved-rate runtime pairs including original entry. Declare its at-most-two-call portfolio, dual simplex then interior point, both presolve disabled, unchanged R10BK limits and certificates. Each failed backend call remains retained; no physical retry.',
            objective='Same R10BS primary maximum worldY torso rise and secondary minimum L1 normalized velocity at99% of the newly certified primary optimum.',
            entry='Fresh original R10AP semantic513 measured cap model and original R10BM torso-raise modes. Entry mode verification and stationary force solver remain unchanged.',
            unchanged='R10BS full geometry, friction, force/work admission, original height/floor/headroom references, per-step speed bounds, minimum finite progress, DOP853 settings,2048 RHS per increment and120 increments. No constraint deletion or certificate relaxation.',
            retention='Exclusive fresh per-step journal, original stdout/stderr, exact refusals, all integration-probe solver recoveries and separate full cold replay. R10BS and all prior diagnostics remain immutable.'),
        numerics=dict(old['numerics'], velocity_backend_order=[dict(method=m,presolve=p) for m,p in W.BACKENDS], velocity_options=dict(W.K.OPTIONS,presolve=False)),
        checks=['169 inherited plus2 integration-recovery retention controls;171 total with shared coverage.',
            'Original entry binding, derivative comparisons, exact physical admission and full result/journal cold replay.'],
        research_sources=C.read(W.STUDY)['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY,record)


def derive(journal=None):
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = I.CapModel(packet, descriptor, entry['joint_positions_rad']); zero = np.zeros(14); caps = [v/G.DT for v in entry['caps']]
    reference = T.snapshot(model); modes = declaration['selected_modes']; material = T.advance(model, zero)
    jacobian_error = float(np.max(np.abs(I.material_jacobian(model)-S.derivative(material.contact_points, zero))))
    floor_error = float(np.max(np.abs(L.floor_jacobian(model)-S.derivative(model.features_y, zero))))
    assert jacobian_error <= 1e-7 and floor_error <= 1e-7
    problem = Z.Problem(material, caps, HEADING)
    solution, certificate = M.certify_mode(problem, modes)
    verification = dict(modes=modes, physical_solution=solution.tolist(), certificate=certificate,
        initial_load=Z.load(model, zero, modes, caps))
    def hip_heights(current):
        return {name:float(current.point(current.poses(zero), 'torso', M.target_point(current, name))[1]) for name in M.TARGETS[1:]}
    initial_hips = hip_heights(model); digest = hashlib.sha256(); count = 0
    def retain(value):
        nonlocal count
        line = L.journal_line(value); digest.update(line); count += 1
        if journal is not None:journal.write(line); journal.flush()
    retain(dict(kind='inputs', declaration=C.bind(STUDY), implementation=C.bind(__file__), verification=verification))
    trajectory = []; accepted = 0; stop = 'initial_mode_load_refusal'
    if verification['initial_load']['feasible']:
        stop = 'bounded_preparatory_model_horizon'
        for index in range(MAX_STEPS):
            row = step(model, modes, caps, HEADING, reference)
            for node in row['nodes']:node['vertical_progress_m'] = node.pop('forward_progress_m')
            row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
            if not row['admitted']:stop = row['refusal']; retain(dict(kind='model_step', value=row)); break
            accepted += 1; model = I.advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
            retain(dict(kind='model_step', value=row))
            print(f'R10BZ step {accepted}: height {model.p["torso"][1]:.9f}, gap {model.gap(zero):.9f}', file=sys.stderr, flush=True)
    final = T.snapshot(model)
    final_load = trajectory[accepted-1]['nodes'][-1]['load'] if accepted else verification['initial_load']
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        selected_modes=modes, initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        torso_vertical_translation_m=final['torso_position_m'][1]-reference['torso_position_m'][1],
        initial_hip_heights_m=initial_hips, final_hip_heights_m=hip_heights(model),
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        total_integrator_rhs_calls=sum(row['rhs_calls'] for row in trajectory),
        integration_solver_recoveries=sum(len(row['solver_recoveries']) for row in trajectory),
        minimum_sampled_progress_fraction=min((node['velocity'][1]/-node['velocity_certificates']['maximum_progress']['primal_objective']
            for row in trajectory if row['admitted'] for node in row['nodes']),default=None), complete_transfer_or_rise_proven=False)
    retain(dict(kind='terminal_summary', value=summary))
    return dict(schema_version='sporespore_r10bz_portfolio_raise_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        material_jacobian_comparison_error=jacobian_error, initial_floor_jacobian_comparison_error=floor_error,
        fixed_mode_verification=verification, initial=reference, final=final, summary=summary, trajectory=trajectory,
        journal=dict(line_count=count, raw_sha256='sha256:'+digest.hexdigest()), **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive(); return L.present(result, True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ('create', 'controls', 'declare'):parser.add_argument('--'+option, action='store_true')
    parser.add_argument('--journal'); args = parser.parse_args()
    if args.declare:declare(); print('R10BZ prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires a fresh durable --journal path')
        path = Path(args.journal).resolve(); assert path.is_relative_to(C.EVIDENCE.resolve()) and not RESULT.exists()
        with path.open('xb') as journal:result = derive(journal)
        C.write_new(RESULT, result); print(json.dumps(L.present(result, False), indent=2))
    else:print(json.dumps(audit(), indent=2))
