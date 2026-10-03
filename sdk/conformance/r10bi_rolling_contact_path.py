"""Prospective sampled quasistatic path with material-velocity foot contact.

Spherical foot sites move geometrically as caps rotate. Friction constrains the
material velocity at the current site, not the derivative of the lowest point.
This numerical kinematic integration is not native physics or a motor command.
"""
import argparse
import copy
import json
import subprocess
import sys
import numpy as np
from scipy.integrate import solve_ivp
import scipy.integrate._ivp.ivp as ivp_source
import scipy.integrate._ivp.rk as rk_source
import scipy.integrate._ivp.base as base_source
import scipy.integrate._ivp.common as common_source
import scipy.integrate._ivp.dop853_coefficients as coefficients_source

import r10bh_coupled_rear_placement as H

B, T, S, C, G, Z = H.B, H.T, H.S, H.C, H.G, H.Z
STUDY = C.ROOT/'sdk/recovery/r10bi_rolling_contact_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bi_rolling_contact_path_result_v1.json'
MAX_STEPS = 600
MAX_RHS = 2048
INTEGRATOR = dict(method='DOP853', rtol=1e-9, atol=1e-12, max_step=.25)


class CapModel(S.Model):
    def contact_points(self, delta):
        points = super().contact_points(delta); poses = self.poses(delta)
        for i, contact in enumerate(self.contacts):
            if contact['classified_as_foot']:
                foot = next(f for f in G.FEET if contact['body_id'] == f+'_distal')
                points[i] = self.point(poses, foot+'_distal', self.local_caps[foot])-np.array([0., .04*self.d['foot_radius_scale'], 0.])
        return points


def advance(model, delta):
    material = T.advance(model, delta)
    cap = CapModel(material.packet, material.d, material.joints)
    assert np.max(np.abs(cap.contact_points(np.zeros(14))-model.contact_points(delta))) < 1e-12
    assert np.max(np.abs(cap.features_y(np.zeros(14))-model.features_y(delta))) < 1e-12
    return cap


def left_jacobian(vector):
    """Map exponential-coordinate rate to world angular velocity."""
    x, y, z = vector; skew = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
    angle = float(np.linalg.norm(vector)); squared = angle*angle
    if angle < 1e-4:
        a = .5-squared/24.+squared*squared/720.
        b = 1./6.-squared/120.+squared*squared/5040.
    else:
        a = (1.-np.cos(angle))/squared; b = (angle-np.sin(angle))/(angle*squared)
    return np.eye(3)+a*skew+b*(skew@skew)


def material_jacobian(model):
    # Force and material velocity must be duals at the same geometric site.
    balance, _, _ = Z.assembly(model, np.zeros(14))
    return np.stack([balance[:, 3*i:3*i+3].T for i in range(len(model.contacts))])


def velocity(model, modes, heading):
    zero = np.zeros(14); j = material_jacobian(model)
    floor = model.features_y(zero); fj = S.derivative(model.features_y, zero)
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
    # Normalize coordinates but retain independent primal/dual certificates.
    a = a*S.MAXIMUM; u = u*S.MAXIMUM; cost = cost*S.MAXIMUM
    anorm = np.maximum(np.max(np.abs(a), axis=1), 1e-12); a /= anorm[:, None]
    unorm = np.maximum(np.max(np.abs(u), axis=1), 1e-12); u /= unorm[:, None]; v /= unorm
    bounds = list(zip(lo/S.MAXIMUM, hi/S.MAXIMUM))
    _, first = S.statics.lp(cost, a, np.zeros(len(a)), u, v, bounds)
    # Deterministically suppress unconstrained limb motion after maximizing
    # body progress. This is an explicit lexicographic development objective.
    secondary_u = np.vstack((np.c_[u, np.zeros((len(u), 14))], np.r_[cost, np.zeros(14)][None, :],
        np.c_[np.eye(14), -np.eye(14)], np.c_[-np.eye(14), -np.eye(14)]))
    secondary_v = np.r_[v, first['primal_objective']+1e-10, np.zeros(28)]
    result, second = S.statics.lp(np.r_[np.zeros(14), np.ones(14)], np.c_[a, np.zeros((len(a), 14))],
        np.zeros(len(a)), secondary_u, secondary_v, bounds+[(0., None)]*14)
    return result[:14]*S.MAXIMUM, dict(maximum_progress=first, minimum_normalized_motion=second)


class IntegrationRefusal(Exception):
    pass


def check_node(base, model, delta, modes, caps, heading, reference, fraction):
    zero = np.zeros(14); points = model.contact_points(zero); original = np.array(reference['original_contact_markers_m'])
    residual = []
    for i, mode in enumerate(modes):
        if mode:
            residual.append(points[i, 1]-original[i, 1])
            if mode == 1 and not model.contacts[i]['classified_as_foot']:residual.extend(points[i, [0, 2]]-original[i, [0, 2]])
    lo, hi = S.bounds(base.joints)
    guards = dict(active_contact=float(np.max(np.abs(residual), initial=0.)),
        original_contact_descent=float(np.max(original[:, 1]-points[:, 1])),
        original_floor=float(np.max(np.minimum(0., reference['shape_bottom_witnesses_m'])-model.features_y(zero))),
        local_floor=float(np.max(np.minimum(0., base.features_y(zero))-model.features_y(zero))),
        translation_and_joint_bounds=max(float(np.max(fraction*lo[np.r_[0:3, 6:14]]-delta[np.r_[0:3, 6:14]])),
            float(np.max(delta[np.r_[0:3, 6:14]]-fraction*hi[np.r_[0:3, 6:14]]))),
        rotation_norm=float(np.linalg.norm(delta[3:6])-fraction*.6*G.DT),
        original_headroom=float(np.max(np.abs(model.joints)-np.maximum(S.LIMITS-.02, np.abs(reference['joints_rad'])))))
    node = dict(fraction=fraction, delta=delta.tolist(), guards=guards, forward_progress_m=float(delta[:3]@heading),
        foot_hull_gap_m=model.gap(zero), admitted=False, refusal=None)
    if not B.geometry_allowed(guards):node['refusal'] = 'integrated_geometry_guard'; return node
    if node['forward_progress_m'] <= 1e-9*fraction:node['refusal'] = 'no_finite_body_progress'; return node
    node['load'] = Z.load(model, zero, modes, caps)
    if not node['load']['feasible']:node['refusal'] = 'sampled_stationary_force_refusal'; return node
    direction, certificate = velocity(model, modes, heading); material = material_jacobian(model)@direction
    node['velocity'] = direction.tolist(); node['velocity_certificates'] = certificate; node['material_contact_motion_per_model_interval_m'] = material.tolist()
    forces = np.array(node['load']['forces_world_n']); checks = []
    for i, mode in enumerate(modes):
        work = float(forces[i]@material[i])
        minimum = -Z.X.MU*forces[i, 1]*float(np.max(np.abs(material[i, [0, 2]]))) if mode >= 2 else 0.
        valid = np.max(np.abs(forces[i])) <= 1e-6 if mode == 0 else Z.work_allowed(work, minimum)
        if mode == 1:valid = valid and np.max(np.abs(material[i])) <= 1e-9
        if mode >= 2:
            axis, sign = Z.MODES[mode]
            valid = valid and abs(material[i, 1]) <= 1e-9 and abs(material[i, 2-axis])-sign*material[i, axis] <= 1e-9
        checks.append(dict(contact=i, mode=mode, sampled_work_per_model_interval_j=work,
            minimum_diamond_work_j=minimum, ok=bool(valid)))
    node['sampled_material_dissipation'] = checks
    if not all(row['ok'] for row in checks):node['refusal'] = 'sampled_material_velocity_or_work_guard'; return node
    node['admitted'] = True
    return node


def step(base, modes, caps, heading, reference):
    calls = 0; max_certificate = 0.
    def rhs(time, q):
        nonlocal calls, max_certificate
        calls += 1
        if calls > MAX_RHS:raise IntegrationRefusal('integrator_rhs_budget')
        model = advance(base, q)
        if np.any(np.abs(model.joints) > S.LIMITS):raise IntegrationRefusal('integrator_probe_outside_hard_joint_limits')
        direction, certificates = velocity(model, modes, heading)
        for certificate in certificates.values():
            for name in ('primal_max_residual', 'stationarity_max_residual', 'dual_sign_violation', 'complementarity_max_residual', 'objective_gap'):
                max_certificate = max(max_certificate, certificate[name])
        derivative = direction.copy(); derivative[3:6] = np.linalg.solve(left_jacobian(q[3:6]), direction[3:6])
        return derivative
    result = dict(nodes=[], admitted=False, refusal=None)
    try:
        solution = solve_ivp(rhs, (0., 1.), np.zeros(14), t_eval=B.FRACTIONS, **INTEGRATOR)
    except IntegrationRefusal as error:
        result.update(refusal=str(error), rhs_calls=calls, maximum_velocity_certificate_residual=max_certificate); return result
    result.update(rhs_calls=calls, maximum_velocity_certificate_residual=max_certificate,
        integrator=dict(success=bool(solution.success), status=int(solution.status), message=solution.message, nfev=int(solution.nfev)))
    if not solution.success or len(solution.t) != len(B.FRACTIONS):result['refusal'] = 'integrator_unsuccessful'; return result
    for fraction, delta in zip(B.FRACTIONS, solution.y.T, strict=True):
        node = check_node(base, advance(base, delta), delta, modes, caps, heading, reference, fraction); result['nodes'].append(node)
        if not node['admitted']:result['refusal'] = node['refusal']; return result
    result['admitted'] = True
    return result


def controls():
    checked = H.controls()
    radius = .04; omega = np.array([0., 0., 2.]); center_velocity = np.array([-2*radius, 0., 0.])
    assert np.max(np.abs(center_velocity+np.cross(omega, [0., -radius, 0.]))) == 0.
    assert np.linalg.norm(center_velocity) > 0.  # Lowest geometric point moves.
    assert np.cross(omega, [0., -radius, 0.])[0] > 0.
    for vector in (np.zeros(3), np.array([1e-7, -2e-7, 3e-7]), np.array([.2, -.3, .1])):
        direction = np.array([.3, -.2, .4]); eps = 1e-6
        r = S.rotation(vector); derivative = (S.rotation(vector+eps*direction)-S.rotation(vector-eps*direction))/(2*eps)
        skew = derivative@r.T; observed = np.array([skew[2, 1], skew[0, 2], skew[1, 0]])
        assert np.max(np.abs(left_jacobian(vector)@direction-observed)) < 1e-9
    answer = solve_ivp(lambda t, y:np.array([y[1], -y[0]]), (0., 1.), [1., 0.], t_eval=B.FRACTIONS, **INTEGRATOR)
    assert answer.success and np.max(np.abs(answer.y-np.array([np.cos(B.FRACTIONS), -np.sin(B.FRACTIONS)]))) < 1e-9
    j = np.arange(42, dtype=float).reshape(3, 14)/100.; force = np.array([2., 3., -1.]); v = np.arange(14)/20.
    assert abs(force@(j@v)-(j.T@force)@v) < 1e-12
    checked['additional_rolling_velocity_rotation_integration_and_power_controls'] = 8
    return checked


def declare():
    old = C.read(H.STUDY)
    record = dict(schema_version='sporespore_r10bi_rolling_contact_path_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_material_velocity_spherical_cap_contact_path', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Does updating spherical foot sites and integrating material-contact velocity admit a load-feasible body-forward path past the frozen-material-marker restriction?',
        dependencies=old['dependencies']+[C.bind(p) for p in [H.__file__, H.STUDY, H.RESULT, __file__,
            ivp_source.__file__, rk_source.__file__, base_source.__file__, common_source.__file__, coefficients_source.__file__]],
        population=dict(report=old['population']['report'], source_pose_count=1, held_out=False,
            selection='Original R10AP partial step1 / semantic step513 and admitted counterfactual descendants only.',
            coverage='At most600 body-forward model increments with four admitted candidate nodes each; no native timing equivalence.'),
        model=dict(contact_sites='All four classified distal feet use current authored spherical-cap center minus radius along world up. Other original contacts remain material points. Record original-to-counterfactual conversion; no new native observation.',
            modes='One R10AZ six-mode MILP on material Jacobians at current cap sites; independently rebuild and certify selected mode. Hold this mode for continuation; no retries or re-selection. Active normal heights remain original modeled heights. Inactive forces are zero.',
            velocity='At each integration probe maximize body motion along original horizontal heading subject to material no-slip/slide-sector constraints, shape-floor linearization, existing bounded pose rates and joint headroom. A second certified LP minimizes normalized absolute motion within1e-10 m of primary objective.',
            integration='DOP853 in14 pose coordinates; exponential-coordinate rates use inverse SO(3) left Jacobian. Each unit interval represents one bounded model increment, not dynamics. max_step.25 rtol1e-9 atol1e-12;2048 RHS evaluations per increment. Rebase measured-relative geometry exactly. Stop first refusal or600 increments.',
            admission='Four nodes per increment independently check global active normal heights, nonfoot sticking anchors, original contact/shape floors, local shape floors, bounded total translation/joint changes and rotation norm, original headroom<=1e-9; body progress>1e-9*fraction m; independently certified stationary forces under unchanged caps andmu1.8 inner diamond; sampled material velocity, friction sector and work<=1e-9. All four nodes must pass before propagation.',
            stopping='First refusal,600 increments, or geometric cap-hull gap<=1e-6 m. This target is not feet-only load, standing or recovery.',
            limitations='Numerically integrated kinematics with sampled stationary loads, not inertial dynamics. Internal integration probes are numerical trial states, not admitted physical poses. Four-node force/work checks do not prove continuous force feasibility, contact acquisition or continuous no-slip. Body variables are not motor commands.'),
        numerics=dict(old['numerics'], integrator=INTEGRATOR, maximum_rhs_calls=MAX_RHS),
        checks=['103 inherited controls plus8 rolling, rotation, integration and force-velocity-duality controls; inherited coverage shared.',
            'Native entry contact replay, source/runtime binding and exact cap-site rebases.',
            'Independent entry fixed-mode force/motion LP; current material Jacobian against finite-difference motion of the current material point.',
            'Independent node geometry, load, material motion and dissipation checks; full fresh-process deterministic replay.'],
        research_sources=old['research_sources']+[dict(url='https://underactuated.mit.edu/multibody.html',
            use='Contact material velocity Jv, generalized force J-transpose lambda, sticking/slide modes and maximum dissipation. Numerical kinematics does not replace dynamics.')],
        claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    native = S.Model(packet, descriptor, entry['joint_positions_rad']); packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = CapModel(packet, descriptor, entry['joint_positions_rad']); zero = np.zeros(14); caps = [v/G.DT for v in entry['caps']]
    conversion = (model.contact_points(zero)-native.contact_points(zero)).tolist()
    reference = T.snapshot(model); heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    # The material model freezes only the instantaneous points for Jacobian
    # computation. The integrated model refreshes geometric sites after motion.
    material = T.advance(model, zero)
    jacobian_error = float(np.max(np.abs(material_jacobian(model)-S.derivative(material.contact_points, zero))))
    assert jacobian_error < 1e-7
    search_problem = Z.Problem(material, caps, heading); search = search_problem.solve()
    verification = None; trajectory = []; accepted = 0; stop = 'entry_mode_search_refusal'; modes = None
    if search['proposal'] is not None:
        modes = search['proposal']['modes']; solution, certificate = search_problem.certify_mode(modes)
        assert abs(certificate['maximum_progress']['primal_objective']-search['proposal']['recomputed_objective']) <= 1e-6
        verification = dict(modes=modes, physical_solution=solution.tolist(), certificate=certificate,
            initial_load=Z.load(model, zero, modes, caps))
        stop = 'initial_mode_load_refusal'
        if verification['initial_load']['feasible']:
            stop = 'finite_model_horizon'
            for index in range(MAX_STEPS):
                row = step(model, modes, caps, heading, reference); row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
                if not row['admitted']:stop = row['refusal']; break
                accepted += 1; model = advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
                print(f'R10BI step {accepted}: gap {model.gap(zero):.9f}', file=sys.stderr, flush=True)
                if model.gap(zero) <= 1e-6:stop = 'geometric_cap_hull_model_target'; break
    final = T.snapshot(model)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        selected_modes=modes, initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        torso_forward_translation_m=float((np.array(final['torso_position_m'])-reference['torso_position_m'])@heading),
        total_integrator_rhs_calls=sum(r['rhs_calls'] for r in trajectory), model_target_reached=stop == 'geometric_cap_hull_model_target')
    return dict(schema_version='sporespore_r10bi_rolling_contact_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        cap_site_conversion_world_m=conversion, material_jacobian_comparison_error=jacobian_error,
        search=search, fixed_mode_verification=verification, initial=reference, final=final, summary=summary,
        trajectory=trajectory, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); args = parser.parse_args()
    if args.declare:declare(); print('R10BI prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
