"""Prospective finite nonlinear geometry proposal with independent load checks.

The previously selected contact mode is fixed. SLSQP success is not admission:
sampled geometry, force certificates and friction work are checked separately.
This is neither a motor command nor a dynamically certified trajectory.
"""
import argparse
import json
import numpy as np
from scipy.optimize import minimize

import r10az_joint_contact_work_guard as Z

S, C, G = Z.S, Z.C, Z.G
STUDY = C.ROOT/'sdk/recovery/r10ba_nonlinear_contact_step_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10ba_nonlinear_contact_step_result_v1.json'
OPTIONS = dict(maxiter=200, ftol=1e-12, disp=False)
FRACTIONS = (.25, .5, .75, 1.)
LENGTH_SCALE = .001


def sectors(travel, modes):
    """Nonnegative values mean both sides of each sliding sector are met."""
    values = []
    for i, mode in enumerate(modes):
        if mode >= 2:
            axis, sign = Z.MODES[mode]
            values.extend(sign*travel[i, axis]+s*travel[i, 2-axis] for s in (-1., 1.))
    return np.array(values)


class Geometry:
    def __init__(self, model, modes, previous):
        self.model, self.modes, self.previous = model, modes, previous
        self.initial = model.contact_points(np.zeros(14))
        self.floor = np.minimum(0., model.features_y(np.zeros(14)))
        self.cached_x = None

    def values(self, x):
        if self.cached_x is None or not np.array_equal(x, self.cached_x):
            delta = x*S.MAXIMUM
            points = self.model.contact_points(delta)
            eq = Z.contact_residual(self.model, delta, self.modes, self.initial)
            # Active markers have an equality already; keep their non-descent
            # in independent admission but avoid duplicate optimizer rows.
            inactive = [i for i, mode in enumerate(self.modes) if mode == 0]
            inequality = np.r_[points[inactive, 1]-self.initial[inactive, 1],
                self.model.features_y(delta)-self.floor, sectors(points-self.previous, self.modes)]
            self.cached_x = x.copy()
            self.cached_values = eq/LENGTH_SCALE, inequality/LENGTH_SCALE
        return self.cached_values

    def equality(self, x):return self.values(x)[0]
    def inequality(self, x):return self.values(x)[1]

    def constraints(self):
        return [dict(type='eq', fun=self.equality, jac=lambda x:S.derivative(self.equality, x)),
            dict(type='ineq', fun=self.inequality, jac=lambda x:S.derivative(self.inequality, x))]


def geometry_allowed(checks):
    return all(np.isfinite(v) and v <= 1e-9 for v in checks.values())


def check_node(model, caps, modes, delta, heading, previous, fraction, solver_ok):
    initial = model.contact_points(np.zeros(14)); points = model.contact_points(delta)
    floor = model.features_y(np.zeros(14)); lo, hi = S.bounds(model.joints)
    eq = Z.contact_residual(model, delta, modes, initial)
    checks = dict(contact=float(np.max(np.abs(eq))),
        bounds=max(float(np.max(fraction*lo-delta)), float(np.max(delta-fraction*hi))),
        marker_descent=float(np.max(initial[:, 1]-points[:, 1])),
        floor=float(np.max(np.minimum(0., floor)-model.features_y(delta))),
        sliding_sector=float(np.max(-sectors(points-previous, modes))))
    node = dict(fraction=fraction, delta=delta.tolist(), checks=checks,
        forward_progress_m=float(delta[:3]@heading), foot_hull_gap_m=model.gap(delta),
        admitted=False, refusal=None)
    if not solver_ok:node['refusal'] = 'nonlinear_optimizer_unsuccessful'; return node
    if not geometry_allowed(checks):node['refusal'] = 'nonlinear_geometry_or_sector_guard'; return node
    if node['forward_progress_m'] <= 1e-9*fraction:node['refusal'] = 'no_finite_body_progress'; return node
    node['load'] = Z.load(model, delta, modes, caps)
    if not node['load']['feasible']:node['refusal'] = 'finite_force_balance_refusal'; return node
    node['dissipation'] = []
    for i, mode in enumerate(modes):
        if mode >= 2:
            force = np.array(node['load']['forces_world_n'][i]); travel = points[i]-previous[i]
            work = float(force[[0, 2]]@travel[[0, 2]])
            bound = -Z.X.MU*force[1]*float(np.max(np.abs(travel[[0, 2]])))
            node['dissipation'].append(dict(contact=i, work_j=work, minimum_diamond_work_j=bound, error_j=abs(work-bound)))
            if not Z.work_allowed(work, bound):node['refusal'] = 'maximum_dissipation_work_refusal'; return node
    node['admitted'] = True
    return node


def finite(model, caps, modes, proposal, heading):
    previous = model.contact_points(np.zeros(14)); lo, hi = S.bounds(model.joints)
    cost = np.r_[-heading*S.MAXIMUM[:3]/(.1*G.DT), np.zeros(11)]
    nodes = []
    for fraction in FRACTIONS:
        geometry = Geometry(model, modes, previous)
        initial = proposal*fraction/S.MAXIMUM
        result = minimize(lambda x:float(cost@x), initial, jac=lambda x:cost,
            method='SLSQP', bounds=list(zip(fraction*lo/S.MAXIMUM, fraction*hi/S.MAXIMUM)),
            constraints=geometry.constraints(), options=OPTIONS)
        delta = result.x*S.MAXIMUM
        node = check_node(model, caps, modes, delta, heading, previous, fraction, bool(result.success))
        node['optimizer'] = dict(success=bool(result.success), status=int(result.status), message=result.message,
            iterations=int(result.nit), function_evaluations=int(result.nfev), objective=float(result.fun),
            independently_certified_global_optimum=False)
        nodes.append(node)
        if not node['admitted']:break
        previous = model.contact_points(delta)
    return nodes


def controls():
    checked = Z.controls()
    # Known nonlinear optimum: largest x+y inside a unit circle is sqrt(2).
    result = minimize(lambda x:float(-sum(x)), np.array([.5, .5]), jac=lambda x:-np.ones(2),
        method='SLSQP', constraints=[dict(type='ineq', fun=lambda x:1.-x@x, jac=lambda x:-2*x)], options=OPTIONS)
    assert result.success and np.max(np.abs(result.x-np.sqrt(.5))) < 1e-7
    assert abs(result.x@result.x-1.) < 1e-9
    assert geometry_allowed(dict(contact=0., floor=-1e-5, sliding_sector=0.))
    for key in ('contact', 'bounds', 'marker_descent', 'floor', 'sliding_sector'):
        assert not geometry_allowed({key:1.01e-9})
    assert not geometry_allowed(dict(floor=float('nan')))
    for mode in range(2, 6):
        axis, sign = Z.MODES[mode]; travel = np.zeros((1, 3)); travel[0, axis] = sign*.01
        assert np.min(sectors(travel, [mode])) == .01
        travel[0, 2-axis] = .011
        assert np.min(sectors(travel, [mode])) < 0.
    checked['additional_nonlinear_known_answer_geometry_and_sector_controls'] = 12
    return checked


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    assert entry['semantic_step'] == 513 and entry['partial_step'] == 1
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet, descriptor, entry['joint_positions_rad']); caps = [v/G.DT for v in entry['caps']]
    prior = C.read(Z.RESULT); modes = declaration['model']['selected_contact_modes']
    assert modes == prior['summary']['selected_modes']
    proposal = np.array(prior['fixed_mode_verification']['physical_solution'][:14])
    heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    nodes = finite(model, caps, modes, proposal, heading)
    passed = len(nodes) == len(FRACTIONS) and all(node['admitted'] for node in nodes)
    summary = dict(finite_step_admitted=passed, checked_nodes=len(nodes), admitted_nodes=sum(n['admitted'] for n in nodes),
        refusal=nodes[-1]['refusal'], initial_gap_m=model.gap(np.zeros(14)),
        final_gap_m=nodes[-1]['foot_hull_gap_m'] if passed else None,
        torso_forward_translation_m=nodes[-1]['forward_progress_m'] if passed else None)
    return dict(schema_version='sporespore_r10ba_nonlinear_contact_step_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        summary=summary, nodes=nodes, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); args = parser.parse_args()
    if args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
