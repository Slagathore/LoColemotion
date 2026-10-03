"""Declared body-and-limb rear placement with three stationary supports.

This counterfactual geometry/force model is not a native controller. Unloaded
rear caps may lift but cannot acquire force or establish landing by inference.
"""
import argparse
import copy
import json
import subprocess
import sys
import numpy as np
from scipy.optimize import minimize

import r10bg_supported_rear_placement as H

B, T, S, C, G, Z = H.B, H.T, H.S, H.C, H.G, H.Z
STUDY = C.ROOT/'sdk/recovery/r10bh_coupled_rear_placement_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bh_coupled_rear_placement_result_v1.json'
SUPPORT = H.SUPPORT
LOADED = [i for i, mode in enumerate(SUPPORT) if mode]
MAX_STEPS = 600
RANK_TOL = 1e-9


def equality_basis(jacobian):
    # Redundant coordinates of rigid-body anchors need not become redundant
    # SLSQP equations. Every original coordinate is still checked for admission.
    left, singular, _ = np.linalg.svd(jacobian, full_matrices=False)
    rank = int(np.sum(singular > RANK_TOL*singular[0])) if len(singular) and singular[0] else 0
    return left[:, :rank].T, singular


def guards(model, delta, reference, fraction):
    zero = np.zeros(14); points = model.contact_points(delta)
    original = np.array(reference['original_contact_markers_m']); lo, hi = S.bounds(model.joints)
    return dict(supporting_anchors=float(np.max(np.abs(points[LOADED]-original[LOADED]))),
        bounds=max(float(np.max(fraction*lo-delta)), float(np.max(delta-fraction*hi))),
        original_floor=float(np.max(np.minimum(0., reference['shape_bottom_witnesses_m'])-model.features_y(delta))),
        local_floor=float(np.max(np.minimum(0., model.features_y(zero))-model.features_y(delta))),
        original_contact_descent=float(np.max(original[:, 1]-points[:, 1])),
        original_headroom=float(np.max(np.abs(model.joints+delta[6:])-np.maximum(S.LIMITS-.02, np.abs(reference['joints_rad'])))))


def step(model, caps, reference, heading):
    zero = np.zeros(14); before = H.cost(model, zero, heading)
    original = np.array(reference['original_contact_markers_m']); lo, hi = S.bounds(model.joints)
    floor = np.maximum(np.minimum(0., reference['shape_bottom_witnesses_m']), np.minimum(0., model.features_y(zero)))
    full_equality = lambda x:(model.contact_points(x*S.MAXIMUM)[LOADED]-original[LOADED]).reshape(-1)/B.LENGTH_SCALE
    jacobian = S.derivative(full_equality, zero)
    basis, singular = equality_basis(jacobian)
    eq = lambda x:basis@full_equality(x)
    inactive = [i for i, mode in enumerate(SUPPORT) if not mode]
    inequality = lambda x:np.r_[model.features_y(x*S.MAXIMUM)-floor,
        model.contact_points(x*S.MAXIMUM)[inactive, 1]-original[inactive, 1]]/B.LENGTH_SCALE
    objective = lambda x:H.cost(model, x*S.MAXIMUM, heading)/.01
    nodes = []
    for fraction in B.FRACTIONS:
        solver = minimize(objective, zero.copy(), jac=lambda x:S.derivative(objective, x), method='SLSQP',
            bounds=list(zip(fraction*lo/S.MAXIMUM, fraction*hi/S.MAXIMUM)),
            constraints=[dict(type='eq', fun=eq, jac=lambda x:S.derivative(eq, x)),
                dict(type='ineq', fun=inequality, jac=lambda x:S.derivative(inequality, x))], options=B.OPTIONS)
        delta = solver.x*S.MAXIMUM; value = H.cost(model, delta, heading)
        node = dict(fraction=fraction, delta=delta.tolist(), guards=guards(model, delta, reference, fraction),
            placement_cost_m2=value, rear_forward_deficits_m=H.deficits(model, delta, heading).tolist(),
            optimizer=dict(success=bool(solver.success), status=int(solver.status), message=solver.message,
                iterations=int(solver.nit), objective=float(solver.fun)), admitted=False, refusal=None)
        nodes.append(node)
        if not solver.success:node['refusal'] = 'coupled_placement_optimizer_unsuccessful'; break
        if not B.geometry_allowed(node['guards']):node['refusal'] = 'full_geometry_guard'; break
        if before-value <= 1e-12*fraction:node['refusal'] = 'no_finite_rear_placement_progress'; break
        node['load'] = Z.load(model, delta, SUPPORT, caps)
        if not node['load']['feasible']:node['refusal'] = 'support_force_balance_refusal'; break
        forces = np.array(node['load']['forces_world_n'])
        assert np.max(np.abs(forces[inactive])) <= 1e-6
        node['modeled_contact_displacement_work_j'] = float(np.sum(forces*(model.contact_points(delta)-model.contact_points(zero))))
        if abs(node['modeled_contact_displacement_work_j']) > 1e-9:node['refusal'] = 'fixed_support_work_guard'; break
        node['admitted'] = True
    admitted = len(nodes) == len(B.FRACTIONS) and all(n['admitted'] for n in nodes)
    return dict(initial_cost_m2=before, equality_rank=len(basis), equality_singular_values=singular.tolist(),
        nodes=nodes, admitted=admitted, refusal=None if admitted else nodes[-1]['refusal'])


def controls():
    checked = H.controls()
    matrix = np.array([[1., 0.], [2., 0.], [0., 1.]])
    basis, singular = equality_basis(matrix)
    assert basis.shape == (2, 3) and np.max(np.abs(basis@basis.T-np.eye(2))) < 1e-12
    assert np.max(np.abs(matrix-basis.T@basis@matrix)) < 1e-12
    # A discarded nonlinear residual can satisfy projected equations. The full
    # admission check must reject it even when the local equality solve passes.
    residual = np.array([2., -1., 0.])*1e-6
    assert np.max(np.abs(basis@residual)) < 1e-12
    assert not B.geometry_allowed(dict(supporting_anchors=float(np.max(np.abs(residual)))))
    assert B.geometry_allowed(dict(original_contact_descent=-.01))
    assert not B.geometry_allowed(dict(original_contact_descent=.01))
    checked['additional_redundant_anchor_full_residual_and_lift_controls'] = 5
    return checked


def declare():
    prior = C.read(H.STUDY)
    record = dict(schema_version='sporespore_r10bh_coupled_rear_placement_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_coupled_body_limb_unloaded_rear_placement', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Can coordinated body and limb motion place unloaded rear caps behind the COM while the original torso pair and front-left contact remain fixed?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [H.__file__, H.STUDY, H.RESULT, __file__]],
        population=prior['population'],
        model=dict(support_modes=SUPPORT, coordinates='All fourteen measured-relative body/joint coordinates; unchanged per-step bounds, actuator caps and joint headroom.',
            contact_sites=prior['model']['contact_sites'],
            placement='Same squared rear-placement deficits and20 mm margin as R10BG. Rear cap heights may rise above original modeled heights, never descend below them; raised caps remain unloaded. Original torso pair and front-left material contact remain stationary globally.',
            numerics='SLSQP maxiter200 ftol1e-12; all fractions start at zero. Project nine anchor equations onto left singular vectors with singular value>1e-9 times largest, evaluated at each step start. Independently check all nine original nonlinear residuals<=1e-9 m before admission; no dropped residual is accepted by projection.',
            admission='All four sampled nodes need optimizer success, complete original/local floor, original contact heights, anchors, bounds and headroom<=1e-9; placement cost decrease>1e-12*fraction m2; independent stationary force certificate under original caps, mu1.8 inner diamond; zero inactive force and absolute fixed-support displacement work<=1e-9 J.',
            stopping='First refusal,600 admitted steps, or both deficits<=1e-6 m. Placement is only a preparation phase; landing, load transfer, body raise and native dynamics are not established.',
            limitations='Sampled counterfactual geometry and stationary forces only. Body coordinates are not motor commands. No contact acquisition, continuous collision, dynamic path or successful recovery claim.'),
        numerics=dict(prior['numerics'], anchor_rank_relative_tolerance=RANK_TOL),
        checks=['98 inherited controls plus5 redundant-anchor, full-residual and lift controls; inherited coverage shared.',
            'Native entry replay, exact counterfactual rebases and independent all-coordinate geometry and force checks.', 'Complete fresh-process deterministic replay.'],
        research_sources=prior['research_sources'], claim_boundary=prior['claim_boundary'])
    C.write_new(STUDY, record)


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    native = S.Model(packet, descriptor, entry['joint_positions_rad']); packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = H.RearCapModel(packet, descriptor, entry['joint_positions_rad']); zero = np.zeros(14)
    conversion = (model.contact_points(zero)-native.contact_points(zero)).tolist()
    caps = [v/G.DT for v in entry['caps']]; reference = T.snapshot(model)
    heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    baseline = Z.load(model, zero, SUPPORT, caps); trajectory = []; accepted = 0
    stop = 'finite_model_horizon' if baseline['feasible'] else 'initial_support_force_balance_refusal'
    if baseline['feasible']:
        for index in range(MAX_STEPS):
            row = step(model, caps, reference, heading); row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
            if not row['admitted']:stop = row['refusal']; break
            accepted += 1; model = H.advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
            print(f'R10BH step {accepted}: rear deficits {H.deficits(model, zero, heading).tolist()}', file=sys.stderr, flush=True)
            if np.max(H.deficits(model, zero, heading)) <= 1e-6:stop = 'rear_cap_placement_model_target'; break
    final = T.snapshot(model)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        initial_rear_forward_deficits_m=H.deficits(native, zero, heading).tolist(), final_rear_forward_deficits_m=H.deficits(model, zero, heading).tolist(),
        initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        rear_cap_height_change_m=(model.contact_points(zero)[[5, 6], 1]-np.array(reference['original_contact_markers_m'])[[5, 6], 1]).tolist(),
        placement_target_reached=stop == 'rear_cap_placement_model_target', landing_proven=False)
    return dict(schema_version='sporespore_r10bh_coupled_rear_placement_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        rear_site_conversion_world_m=conversion, initial=reference, initial_support_load=baseline, final=final,
        summary=summary, trajectory=trajectory, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); args = parser.parse_args()
    if args.declare:declare(); print('R10BH prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
