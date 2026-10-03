"""Three prospectively named raising directions at the original rolling entry.

This is an instantaneous force/velocity study only. No finite pose, path,
support transition, motor command or physical recovery is admitted.
"""
import argparse
import copy
import json
import subprocess
import numpy as np

import r10bl_presolve_disabled_rolling_path as L

C, S, G, Z, I, T = L.C, L.S, L.G, L.Z, L.I, L.T
STUDY = C.ROOT/'sdk/recovery/r10bm_entry_raise_directions_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bm_entry_raise_directions_result_v1.json'
TARGETS = ('torso_raise', 'rear_left_hip_raise', 'rear_right_hip_raise')


def target_point(model, name):
    if name == 'torso_raise':return np.zeros(3)
    assert name in TARGETS
    return np.array([-.2, 0., -.18 if name == 'rear_left_hip_raise' else .18])*model.d['hip_span_scale']


def gradient(model, name):
    zero = np.zeros(14); poses = model.poses(zero)
    _, jacobian, _, _, _ = S.statics.frame(model.packet, model.d, model.com(poses))
    return jacobian('torso', model.point(poses, 'torso', target_point(model, name)))[1]


def certify_mode(problem, modes):
    """Rebuild force/motion constraints without binary conditional bounds.

    Use the declared presolve-disabled backend for both continuous objectives.
    Mode search remains the unchanged bounded mixed-integer proposal backend.
    """
    a, b, _ = Z.assembly(problem.model, np.zeros(14))
    eq = np.c_[np.zeros((14, 14)), a]*problem.scale
    scale = np.maximum(1., np.abs(b)); eq /= scale[:, None]; rhs = b/scale
    active = np.all(problem.ub[:, problem.base:] == 0., axis=1)
    u = list(problem.ub[active, :problem.base]); v = list(problem.limit[active])
    for i, mode in enumerate(modes):
        for row, bound in problem.mode_rows[(i, mode)]:
            norm = max(float(np.max(np.abs(row))), abs(bound), 1e-12)
            u.append(row/norm); v.append(bound/norm)
    u = np.array(u); v = np.array(v)
    bounds = list(zip(problem.lower[:problem.base], problem.upper[:problem.base]))
    first_x, first = L.certified_lp('fixed_mode_raise_objective', problem.cost[:problem.base], eq, rhs, u, v, bounds)
    identity = np.c_[np.eye(14), np.zeros((14, problem.base-14))]
    second_u = np.vstack((np.c_[u, np.zeros((len(u), 14))],
        np.r_[problem.cost[:problem.base], np.zeros(14)][None, :],
        np.c_[identity, -np.eye(14)], np.c_[-identity, -np.eye(14)]))
    # Same 1e-10 m allowance as the rolling velocity LP, in normalized units.
    second_v = np.r_[v, first['primal_objective']+1e-10/(.1*G.DT), np.zeros(28)]
    try:
        x, second = L.certified_lp('fixed_mode_minimum_motion', np.r_[np.zeros(problem.base), np.ones(14)],
            np.c_[eq, np.zeros((len(eq), 14))], rhs, second_u, second_v, bounds+[(0., None)]*14)
    except L.VelocityRefusal as error:
        error.record.update(primary_solution=first_x.tolist(), primary_certificate=first)
        raise
    return x[:problem.base]*problem.scale, dict(maximum_raise=first, minimum_normalized_motion=second)


def direction_check(model, caps, modes, solution):
    velocity = solution[:14]; forces = solution[14:14+3*len(modes)].reshape((-1, 3)); torque = solution[-8:]
    a, rhs, _ = Z.assembly(model, np.zeros(14)); material = I.material_jacobian(model)@velocity
    force_residual = float(np.max(np.abs(a@solution[14:]-rhs)))
    rows = []
    for i, mode in enumerate(modes):
        force = forces[i]; motion = material[i]; work = float(force@motion)
        minimum = -Z.X.MU*force[1]*float(np.max(np.abs(motion[[0, 2]]))) if mode >= 2 else 0.
        ok = np.max(np.abs(force)) <= 1e-6 if mode == 0 else Z.work_allowed(work, minimum)
        if mode == 1:ok = ok and np.max(np.abs(motion)) <= 1e-9
        if mode >= 2:
            axis, sign = Z.MODES[mode]
            ok = ok and abs(motion[1]) <= 1e-9 and abs(motion[2-axis])-sign*motion[axis] <= 1e-9
        ok = ok and motion[1] >= -1e-9 and force[1] >= -1e-6 and abs(force[0])+abs(force[2])-Z.X.MU*force[1] <= 1e-6
        rows.append(dict(contact=i, mode=mode, force_world_n=force.tolist(), material_motion_per_interval_m=motion.tolist(),
            work_per_interval_j=work, minimum_work_j=minimum, ok=bool(ok)))
    floor = model.features_y(np.zeros(14)); lo, hi = S.bounds(model.joints)
    geometry = max(float(np.max(np.minimum(0., floor)-floor-L.floor_jacobian(model)@velocity)),
        float(np.max(lo-velocity)), float(np.max(velocity-hi)))
    return dict(admitted=bool(force_residual <= 1e-6 and geometry <= 1e-9 and
        np.max(np.abs(torque)-caps) <= 1e-6 and all(row['ok'] for row in rows)),
        force_balance_residual_n_or_nm=force_residual, linear_geometry_residual=geometry,
        material_checks=rows, nonfoot_normal_fraction=float(sum(forces[i, 1] for i, p in enumerate(model.contacts)
            if not p['classified_as_foot'])/sum(forces[:, 1])),
        finite_motion_admitted=False)


def controls():
    checked = L.controls()
    class Manufactured:
        d = dict(hip_span_scale=1.)
    fake = Manufactured()
    assert target_point(fake, 'torso_raise').tolist() == [0., 0., 0.]
    for name, sign in [('rear_left_hip_raise', -1.), ('rear_right_hip_raise', 1.)]:
        p = target_point(fake, name)
        # Rotation about +X lowers positive-Z and raises negative-Z hip.
        analytic = np.cross(np.array([1., 0., 0.]), p)[1]
        fd = ((S.rotation(np.array([1e-6, 0., 0.]))@p)[1]-(S.rotation(np.array([-1e-6, 0., 0.]))@p)[1])/2e-6
        assert abs(analytic-fd) < 1e-10 and analytic*sign < 0.
    assert 1e-10/(.1*G.DT)*(.1*G.DT) == 1e-10
    assert len(TARGETS) == len(set(TARGETS)) == 3
    checked['additional_hip_geometry_rotation_derivative_objective_units_and_population_controls'] = 7
    return checked


def declare():
    old = C.read(L.STUDY)
    record = dict(schema_version='sporespore_r10bm_entry_raise_directions_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_instantaneous_raise_direction_survey', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Which of three named torso/rear-hip raising objectives admits a verified instantaneous direction under joint contact-mode, gravity, actuator and material-work constraints at original entry?',
        dependencies=old['dependencies']+[C.bind(p) for p in [L.__file__, L.STUDY, __file__]],
        population=old['population'], targets=list(TARGETS),
        design=dict(entry='Original exposed R10AP semantic513 only. R10BI cap model and instantaneous material contact Jacobian. No use of a later R10BL state.',
            objectives='World-Y rise of torso origin, authored rear-left parent hip anchor, and authored rear-right parent hip anchor. Analytic body-point gradients checked against central finite differences <=1e-7.',
            search='One independent six-mode-per-contact mixed-integer search per named objective, original Z.Problem bounds and options. Replace only cost[:14] with -gradient*MAXIMUM/(0.1*DT). Retain all three searches; no fallback or selected controller.',
            verification='Rebuild continuous fixed-mode force/motion LP without binary conditional bounds; presolve-disabled highs-ds and independent1e-6 certificate. Match first objective to search within1e-6 normalized units. Minimize normalized absolute motion within1e-10 m of first optimum.',
            admission='Independently check instantaneous force balance, original floor/rate/headroom linear bounds, actuator caps, positive normal force, inner friction diamond, normal/material velocity and maximum-dissipation work. No integration, nonlinear pose admission, new contact, transition or finite-path claim.',
            retention='Retain every search and certificate failure; exact failed continuous-LP inputs and outputs survive. Full fresh-process replay. No ranking across targets or extrapolation to later poses.'),
        numerics=dict(numpy=np.__version__, scipy=S.statics.scipy.__version__, mode_search_options=Z.OPTIONS,
            continuous_lp_options=L.OPTIONS, certificate_tolerance=1e-6),
        checks=['135 inherited plus7 hip geometry, analytic rotation derivative, objective units and target-population controls; inherited coverage shared.',
            'Original native contact replay; exact dependency binding; independent objective gradient and direction checks.'],
        research_sources=old['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = I.CapModel(packet, descriptor, entry['joint_positions_rad']); caps = [v/G.DT for v in entry['caps']]
    material = T.advance(model, np.zeros(14)); rows = []
    for name in TARGETS:
        grad = gradient(model, name)
        fd = S.derivative(lambda q:model.point(model.poses(q), 'torso', target_point(model, name))[1], np.zeros(14))
        error = float(np.max(np.abs(grad-fd))); assert error <= 1e-7
        problem = Z.Problem(material, caps, np.zeros(3)); problem.cost[:14] = -grad*S.MAXIMUM/(.1*G.DT)
        row = dict(target=name, gradient=grad.tolist(), gradient_comparison_error=error, search=None, verification=None, refusal=None)
        rows.append(row)
        try:row['search'] = problem.solve()
        except AssertionError as failure:row['refusal'] = dict(stage='mode_search_verification', error=repr(failure)); continue
        if row['search']['proposal'] is None:row['refusal'] = dict(stage='mode_search_status'); continue
        modes = row['search']['proposal']['modes']
        try:solution, certificate = certify_mode(problem, modes)
        except L.VelocityRefusal as failure:row['refusal'] = failure.record; continue
        mismatch = abs(certificate['maximum_raise']['primal_objective']-row['search']['proposal']['recomputed_objective'])
        checks = direction_check(model, caps, modes, solution)
        row['verification'] = dict(modes=modes, physical_solution=solution.tolist(), certificates=certificate,
            search_objective_difference=mismatch, target_raise_per_model_interval_m=float(grad@solution[:14]),
            all_target_rates_m={target:float(gradient(model, target)@solution[:14]) for target in TARGETS}, checks=checks)
        if mismatch > 1e-6:row['refusal'] = dict(stage='search_and_continuous_objective_disagreement')
        elif not checks['admitted']:row['refusal'] = dict(stage='instantaneous_physical_model_checks')
        elif grad@solution[:14] <= 1e-9:row['refusal'] = dict(stage='no_positive_instantaneous_raise')
    return dict(schema_version='sporespore_r10bm_entry_raise_directions_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        initial=T.snapshot(model), cases=rows, summary=dict(targets_tested=len(rows),
            positive_verified_directions=sum(row['refusal'] is None for row in rows), finite_steps_propagated=0),
        **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, full_replay_passed=True, controls=result['controls'], summary=result['summary'],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ('create', 'controls', 'declare'):parser.add_argument('--'+option, action='store_true')
    args = parser.parse_args()
    if args.declare:declare(); print('R10BM prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    elif args.create:
        assert not RESULT.exists(); result = derive(); C.write_new(RESULT, result)
        print(json.dumps(dict(ok=True, full_replay_passed=False, controls=result['controls'], summary=result['summary']), indent=2))
    else:print(json.dumps(audit(), indent=2))
