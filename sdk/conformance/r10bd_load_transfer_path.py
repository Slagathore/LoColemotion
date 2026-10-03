"""Prospective bounded path minimizing required non-foot stationary support.

Contact modes are proposed with a first-order equilibrium model, then actual
finite poses and forces are optimized jointly and checked by independent LPs.
No native world, controller selection or dynamic recovery claim follows.
"""
import argparse
import json
import sys
import subprocess
import numpy as np
from scipy.optimize import minimize

import r10bc_terminal_contact_replan as R

B, P, T, S, C, G, Z = R.B, R.P, R.T, R.S, R.C, R.G, R.Z
STUDY = C.ROOT/'sdk/recovery/r10bd_load_transfer_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bd_load_transfer_path_result_v1.json'
MAX_STEPS = 600
LOAD_PROGRESS = 1e-9


def declare():
    """Create the prospective record once; never replace an observed record."""
    old = C.read(R.STUDY)
    record = dict(schema_version='sporespore_r10bd_load_transfer_path_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_joint_pose_force_nonfoot_support_descent_path', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Can direct reduction of required nonfoot stationary support produce a bounded contact-consistent transfer path from the original R10AP recovery entry?')
    record['dependencies'] = old['dependencies']+[C.bind(p) for p in [R.__file__, R.STUDY, R.RESULT]]
    record['population'] = dict(report=old['population']['report'], source_pose_count=1, held_out=False,
        selection='Only original R10AP partial step1 / semantic step513 and admitted counterfactual descendants. Start at original entry, not R10BB terminal state. No perturbed, held-out or new native input.',
        coverage='At most600 increments and four nonzero nodes each, stopping at first refusal.600 is the existing development raise horizon used solely as a numerical bound, with no dynamic or timing equivalence.')
    record['model'] = dict(maximum_model_steps=MAX_STEPS, fractional_nodes=list(B.FRACTIONS),
        objective='Minimize total nonfoot normal force divided by measured total weight. No forward-body or foot-hull-gap descent requirement. Retain geometry measurements as descriptive results. This is a development objective, not an acceptance threshold change.',
        baseline='Independently minimize nonfoot support using friction-cone forces at markers within1e-9 m of original contact heights; all other forces are zero. Sticking here is a stationary force model, not a commanded transition.',
        linearization='For A(q)f=b(q), use A(0)f + derivative[A(q)f0-b(q)]*dq = b(0), with certified baseline f0. Central physical-coordinate differences1e-6 and2e-6 must agree within1e-6. Normalize as R10AZ. This tangent is only a proposal.',
        mode_search='Six R10AZ modes per eligible marker with derived conditional bounds. Minimize predicted nonfoot fraction using one MILP per step:60-second/100000-node limits and requested gap0. Independently rebuild chosen continuous LP without big-M; certify and match objective within1e-6. No secondary objective.',
        nonlinear='Joint SLSQP optimization of14 bounded pose increments and reduced force/torque variables, maxiter200 ftol1e-12. Eliminate inactive forces, parameterize each sliding force by its normal component at its diamond vertex, retain three variables per sticking contact and eight bounded torques. Enforce full nonlinear14-coordinate force balance, contact geometry, sectors and cones. Each fraction starts from the tangent proposal; no retries.',
        admission='Require solver success, geometry/sector/floor/headroom<=1e-9, proposed raw equilibrium residual<=1e-6, independent R10AR force certificates under original caps and mu1.8 inner diamond, work<=1e-9 J and abs(work-minimum)<=1e-9 J. Independent nonfoot fraction must improve over current eligible baseline by>1e-9*fraction. All four nodes must pass before propagation.',
        global_and_transition='Sticking anchors persist across adjacent sticking modes; reset to current marker position only on a switch into sticking. Active normal positions retain original heights; marker floors, shape-floor minima and initial headroom remain global. R10AT rebase preserves body-space point identities. Height eligibility is a quasistatic guard, not native collision/impact validation.',
        termination='Stop at first load/search/linear-progress/optimizer/geometry/independent-force/work/nonlinear-progress refusal or600-step bound. Admitted nonfoot fraction<=1e-6 is a model unloading target only, not standing/settling/walking or recovery.',
        limitations='Greedy descent may reject necessary temporary load increase or stop locally. Marker non-descent, sampled penetrating callback poses, inner friction diamond and vertex-only sliding remain restrictions. No completeness, dynamics, continuous collision or global nonlinear/MIP optimality claim.')
    record['numerics'] = dict(old['numerics'], load_progress_fraction=LOAD_PROGRESS,
        force_balance_tangent_step=S.FD, force_balance_tangent_comparison_tolerance=1e-6)
    record['checks'] = [
        '80 inherited controls plus9 tangent, nonlinear known-answer, false linear-feasibility and reduced-force controls; inherited coverage is shared.',
        'Exact dependencies, runtime bindings and original native contact replay.',
        'Independent selected-mode LP certificates and actual nonlinear pose/force reconstruction; independent load certificates and friction-work checks at every node.',
        'Persistent sticking/normal/floor/headroom references and exact rebase checks.',
        'Complete fresh-process deterministic replay; solver success alone never grants admission.']
    record['research_sources'] = old['research_sources']+[dict(url='https://underactuated.mit.edu/contact.html',
        use='Explicit contact modes and transition guards; this quasistatic study does not implement impact dynamics.')]
    record['claim_boundary'] = old['claim_boundary']
    C.write_new(STUDY, record)


def physical_load(load):
    return np.r_[np.array(load['forces_world_n']).reshape(-1), load['joint_torques_nm']]


def balance_tangent(model, reference, step=S.FD):
    def residual(q):
        a, b, _ = Z.assembly(model, q)
        return a@reference-b
    return S.derivative(residual, np.zeros(14), step)


class Problem(Z.Problem):
    def __init__(self, model, caps, reference, eligible):
        super().__init__(model, caps, np.array([1., 0., 0.]))
        self.reference = reference
        self.tangent = balance_tangent(model, reference)
        self.tangent_error = float(np.max(np.abs(self.tangent-balance_tangent(model, reference, 2*S.FD))))
        assert self.tangent_error < 1e-6
        _, b, _ = Z.assembly(model, np.zeros(14))
        self.eq[:14, :14] = self.tangent*S.MAXIMUM/np.maximum(1., np.abs(b))[:, None]
        self.cost[:] = 0.
        for i, contact in enumerate(model.contacts):
            if not contact['classified_as_foot']:self.cost[14+3*i+1] = 1.
        R.restrict(self, eligible)

    def certify_mode(self, modes):
        # Rebuild the continuous model without binary conditional bounds.
        a, b, _ = Z.assembly(self.model, np.zeros(14))
        tangent = balance_tangent(self.model, self.reference)
        eq = np.c_[tangent, a]*self.scale/np.maximum(1., np.abs(b))[:, None]
        rhs = b/np.maximum(1., np.abs(b))
        active = np.all(self.ub[:, self.base:] == 0., axis=1)
        u, v = list(self.ub[active, :self.base]), list(self.limit[active])
        for i, mode in enumerate(modes):
            for row, bound in self.mode_rows[(i, mode)]:
                norm = max(float(np.max(np.abs(row))), abs(bound), 1e-12)
                u.append(row/norm); v.append(bound/norm)
        u, v = np.array(u), np.array(v); bounds = list(zip(self.lower[:self.base], self.upper[:self.base]))
        x, certificate = S.statics.lp(self.cost[:self.base], eq, rhs, u, v, bounds)
        return x*self.scale, certificate


def force_map(modes, caps, weight):
    """Eliminate inactive forces and parameterize sliding vertices exactly."""
    n = len(modes); columns = []; lower = []; upper = []; sticking = []
    for i, mode in enumerate(modes):
        if mode == 1:
            sticking.append((i, len(columns)))
            for axis in range(3):
                col = np.zeros(3*n+8); col[3*i+axis] = weight; columns.append(col)
                lower.append(0. if axis == 1 else -Z.X.MU); upper.append(1. if axis == 1 else Z.X.MU)
        elif mode >= 2:
            axis, sign = Z.MODES[mode]; col = np.zeros(3*n+8)
            col[3*i+1] = weight; col[3*i+axis] = -sign*Z.X.MU*weight
            columns.append(col); lower.append(0.); upper.append(1.)
    for j, cap in enumerate(caps):
        col = np.zeros(3*n+8); col[3*n+j] = cap; columns.append(col); lower.append(-1.); upper.append(1.)
    return np.array(columns).T, np.array(lower), np.array(upper), sticking


class FiniteProblem:
    def __init__(self, model, caps, modes, previous):
        self.model = model; self.geometry = B.Geometry(model, modes, previous)
        _, rhs, weight = Z.assembly(model, np.zeros(14))
        self.matrix, self.lower, self.upper, self.sticking = force_map(modes, caps, weight)
        self.row_scale = np.maximum(1., np.abs(rhs))
        physical_cost = np.zeros(self.matrix.shape[0])
        for i, contact in enumerate(model.contacts):
            if not contact['classified_as_foot']:physical_cost[3*i+1] = 1./weight
        self.cost = np.r_[np.zeros(14), physical_cost@self.matrix]
        self.cached_q = None

    def data(self, x):
        q = x[:14]
        if self.cached_q is None or not np.array_equal(q, self.cached_q):
            a, rhs, _ = Z.assembly(self.model, q*S.MAXIMUM)
            self.cached_data = a@self.matrix, rhs, self.geometry.values(q)
            self.cached_q = q.copy()
        return self.cached_data

    def equality(self, x):
        a, rhs, geometry = self.data(x)
        return np.r_[geometry[0], (a@x[14:]-rhs)/self.row_scale]

    def inequality(self, x):
        _, _, geometry = self.data(x); cone = []
        for _, offset in self.sticking:
            fx, fy, fz = x[14+offset:17+offset]
            cone.extend(Z.X.MU*fy-sx*fx-sz*fz for sx, sz in ((-1.,-1.),(-1.,1.),(1.,-1.),(1.,1.)))
        return np.r_[geometry[1], cone]

    def solve(self, proposal, fraction):
        lo, hi = S.bounds(self.model.joints)
        guess_force = np.linalg.lstsq(self.matrix, proposal[14:], rcond=1e-12)[0]
        guess = np.r_[proposal[:14]*fraction/S.MAXIMUM, guess_force]
        bounds = list(zip(np.r_[fraction*lo/S.MAXIMUM, self.lower], np.r_[fraction*hi/S.MAXIMUM, self.upper]))
        result = minimize(lambda x:float(self.cost@x), guess, jac=lambda x:self.cost,
            method='SLSQP', bounds=bounds,
            constraints=[dict(type='eq', fun=self.equality, jac=lambda x:S.derivative(self.equality, x)),
                dict(type='ineq', fun=self.inequality, jac=lambda x:S.derivative(self.inequality, x))], options=B.OPTIONS)
        return result, result.x[:14]*S.MAXIMUM, self.matrix@result.x[14:]


def check_node(model, caps, modes, delta, force, previous, fraction, baseline, original, anchors, solver):
    points = model.contact_points(delta); zero = np.zeros(14); initial = model.contact_points(zero)
    floor = model.features_y(zero); lo, hi = S.bounds(model.joints)
    checks = dict(contact=float(np.max(np.abs(Z.contact_residual(model, delta, modes, initial)))),
        bounds=max(float(np.max(fraction*lo-delta)), float(np.max(delta-fraction*hi))),
        marker_descent=float(np.max(initial[:, 1]-points[:, 1])),
        floor=float(np.max(np.minimum(0., floor)-model.features_y(delta))),
        sector=float(np.max(-B.sectors(points-previous, modes), initial=0.)))
    global_ = P.global_guards(model, delta, anchors, np.array(original['shape_bottom_witnesses_m']),
        np.array(original['joints_rad']), modes)
    global_['residuals']['source_marker_descent'] = float(np.max(np.array(original['original_contact_markers_m'])[:, 1]-points[:, 1]))
    global_['ok'] = B.geometry_allowed(global_['residuals'])
    a, rhs, _ = Z.assembly(model, delta)
    node = dict(fraction=fraction, delta=delta.tolist(), checks=checks, global_checks=global_,
        proposed_force_equilibrium_max_residual=float(np.max(np.abs(a@force-rhs))),
        proposed_forces_and_torques=force.tolist(), foot_hull_gap_m=model.gap(delta),
        optimizer=dict(success=bool(solver.success), status=int(solver.status), message=solver.message,
            iterations=int(solver.nit), objective=float(solver.fun)), admitted=False, refusal=None)
    if not solver.success:node['refusal'] = 'nonlinear_optimizer_unsuccessful'; return node
    if not B.geometry_allowed(checks) or not global_['ok']:node['refusal'] = 'geometry_guard'; return node
    if node['proposed_force_equilibrium_max_residual'] > 1e-6:node['refusal'] = 'nonlinear_force_equilibrium_guard'; return node
    node['load'] = Z.load(model, delta, modes, caps)
    if not node['load']['feasible']:node['refusal'] = 'independent_force_balance_refusal'; return node
    node['dissipation'] = []
    for i, mode in enumerate(modes):
        if mode >= 2:
            actual = np.array(node['load']['forces_world_n'][i]); travel = points[i]-previous[i]
            work = float(actual[[0, 2]]@travel[[0, 2]]); minimum = -Z.X.MU*actual[1]*float(np.max(np.abs(travel[[0, 2]])))
            node['dissipation'].append(dict(contact=i, work_j=work, minimum_diamond_work_j=minimum, error_j=abs(work-minimum)))
            if not Z.work_allowed(work, minimum):node['refusal'] = 'maximum_dissipation_work_refusal'; return node
    if node['load']['minimum_nonfoot_weight_fraction'] >= baseline-LOAD_PROGRESS*fraction:
        node['refusal'] = 'no_independent_nonfoot_load_reduction'; return node
    node['admitted'] = True
    return node


def step(model, caps, original, previous_modes, anchors):
    contacts = model.contact_points(np.zeros(14)); eligible = R.eligible_contacts(np.array(original['original_contact_markers_m']), contacts)
    baseline = Z.load(model, np.zeros(14), [1 if i in eligible else 0 for i in range(len(contacts))], caps)
    row = dict(eligible_contact_indices=eligible, baseline=baseline, nodes=[], admitted=False, refusal=None)
    if not baseline['feasible']:row['refusal'] = 'initial_eligible_force_balance_refusal'; return row
    problem = Problem(model, caps, physical_load(baseline), eligible); row['tangent_step_comparison_error'] = problem.tangent_error
    search = problem.solve(); row['search'] = search
    if search['proposal'] is None:row['refusal'] = 'mode_search_unsuccessful'; return row
    modes = search['proposal']['modes']; assert all(mode == 0 or i in eligible for i, mode in enumerate(modes))
    anchors = anchors.copy()
    for i, mode in enumerate(modes):
        if mode == 1 and previous_modes[i] != 1:anchors[i] = contacts[i]
    anchors[:, 1] = np.array(original['original_contact_markers_m'])[:, 1]
    row['phase_anchors_m'] = anchors.tolist()
    proposal, certificate = problem.certify_mode(modes)
    assert abs(certificate['primal_objective']-search['proposal']['recomputed_objective']) <= 1e-6
    row['fixed_mode_verification'] = dict(modes=modes, physical_solution=proposal.tolist(), certificate=certificate)
    if certificate['primal_objective'] >= baseline['minimum_nonfoot_weight_fraction']-LOAD_PROGRESS:
        row['refusal'] = 'no_first_order_nonfoot_load_reduction'; return row
    previous = contacts
    for fraction in B.FRACTIONS:
        solver, delta, force = FiniteProblem(model, caps, modes, previous).solve(proposal, fraction)
        node = check_node(model, caps, modes, delta, force, previous, fraction,
            baseline['minimum_nonfoot_weight_fraction'], original, anchors, solver)
        row['nodes'].append(node)
        if not node['admitted']:row['refusal'] = node['refusal']; return row
        previous = model.contact_points(delta)
    row['admitted'] = True
    return row


def controls():
    checked = R.controls()
    # Manufactured balance: f*q=1 has derivative f; increasing lever q lowers required f.
    derivative = S.derivative(lambda q:np.array([2.*q[0]-1.]), np.array([.5]))
    assert abs(derivative[0, 0]-2.) < 1e-9
    nonlinear = minimize(lambda x:float(x[1]), np.array([.5, 2.]), jac=lambda x:np.array([0., 1.]),
        method='SLSQP', bounds=[(.5, .6), (0., 3.)],
        constraints=[dict(type='eq', fun=lambda x:x[0]*x[1]-1., jac=lambda x:np.array([x[1], x[0]]))], options=B.OPTIONS)
    assert nonlinear.success and np.max(np.abs(nonlinear.x-[.6, 1./.6])) < 1e-8
    # A tangent prediction can be feasible linearly and fail actual equilibrium.
    assert abs(.5*1.6+2.*.1-1.) < 1e-12 and abs(.6*1.6-1.) > 1e-6
    matrix, lo, hi, sticking = force_map([0, 1, 2, 3, 4, 5], [2.]*8, 10.)
    x = np.zeros(matrix.shape[1]); x[1] = .2; x[3:7] = .3
    force = matrix@x
    assert np.all(force[:3] == 0.) and sticking == [(1, 0)]
    for i, mode in enumerate([2, 3, 4, 5], start=2):
        axis, sign = Z.MODES[mode]; assert force[3*i+1] == 3.
        assert abs(force[3*i+axis]+sign*Z.X.MU*3.) < 1e-12
    assert np.all(x >= lo) and np.all(x <= hi)
    checked['additional_equilibrium_tangent_nonlinear_balance_and_reduced_force_controls'] = 9
    return checked


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet, descriptor, entry['joint_positions_rad']); caps = [v/G.DT for v in entry['caps']]
    original = T.snapshot(model); trajectory = []; accepted = 0; stop = 'finite_model_horizon'
    previous_modes = [0]*len(model.contacts); anchors = model.contact_points(np.zeros(14))
    for index in range(MAX_STEPS):
        row = step(model, caps, original, previous_modes, anchors); row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
        if not row['admitted']:stop = row['refusal']; break
        accepted += 1; model = T.advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
        previous_modes = row['fixed_mode_verification']['modes']; anchors = np.array(row['phase_anchors_m'])
        assert abs(row['after']['foot_hull_gap_m']-row['nodes'][-1]['foot_hull_gap_m']) < 1e-12
        if row['nodes'][-1]['load']['minimum_nonfoot_weight_fraction'] <= 1e-6:
            stop = 'independent_nonfoot_support_fraction_within_1ppm_model_only'; break
        print(f'R10BD step {accepted}: nonfoot fraction {row["nodes"][-1]["load"]["minimum_nonfoot_weight_fraction"]:.9f}', file=sys.stderr, flush=True)
    final = T.snapshot(model); eligible = R.eligible_contacts(np.array(original['original_contact_markers_m']), model.contact_points(np.zeros(14)))
    final_load = Z.load(model, np.zeros(14), [1 if i in eligible else 0 for i in range(len(model.contacts))], caps)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        initial_minimum_nonfoot_weight_fraction=trajectory[0]['baseline'].get('minimum_nonfoot_weight_fraction'),
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        initial_gap_m=original['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'], model_target_reached=stop.startswith('independent_nonfoot_support'))
    return dict(schema_version='sporespore_r10bd_load_transfer_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        initial=original, final=final, final_load=final_load, summary=summary, trajectory=trajectory, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); args = parser.parse_args()
    if args.declare:declare(); print('R10BD prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
