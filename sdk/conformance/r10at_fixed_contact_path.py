"""Prospective continuation of R10AS in one fixed contact mode, without physics.

Synthetic poses retain the source geometry but are never native observations.
Unloaded points may move; they can never acquire force merely by being retained
in the original contact list. Only the declared three supports enter any LP.
"""
import argparse
import copy
import json
import numpy as np

import r10as_contact_motion_study as S

C, G = S.C, S.G
STUDY = C.ROOT/'sdk/recovery/r10at_fixed_contact_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10at_fixed_contact_path_result_v1.json'
MAX_STEPS = 600


def advance(model, delta):
    """Rebase the counterfactual model without snapping away constraint drift."""
    packet = copy.deepcopy(model.packet)
    packet['counterfactual_model_only'] = True
    poses = model.poses(delta)
    for body in packet['callback_bodies']:
        name = body['body_id']
        body['pose']['origin'] = poses[0][name].tolist()
        body['pose']['basis_columns'] = poses[1][name].T.tolist()
    for body in packet['direct_state_source']['ordered_body_states']:
        name = body['body_id']
        body['position_world_m'] = model.point(poses, name, model.local_com[name]).tolist()
    positive = [p for p in packet['contact_source_receipt']['ordered_contact_samples'] if p['normal_impulse_ns'] > 0]
    for point, moved in zip(positive, model.contact_points(delta), strict=True):
        point['position_world_m'] = moved.tolist()
    result = S.Model(packet, model.d, model.joints+delta[6:])
    # Body-space point identities and measured-relative transforms survive.
    zero = np.zeros(14)
    assert np.max(np.abs(result.contact_points(zero)-model.contact_points(delta))) < 1e-12
    assert np.max(np.abs(result.features_y(zero)-model.features_y(delta))) < 1e-12
    assert np.max(np.abs(result.com(result.poses(zero))-model.com(poses))) < 1e-12
    return result


def global_guards(model, delta, contacts, floor, loaded):
    points = model.contact_points(delta)
    residual = dict(original_support_drift=float(np.max(np.abs(points[loaded]-contacts[loaded]))),
        original_contact_descent=float(np.max(contacts[:, 1]-points[:, 1])),
        original_floor=float(np.max(np.minimum(0., floor)-model.features_y(delta))))
    return all(v <= S.GEOMETRY_TOL for v in residual.values()), residual


def step(model, caps, loaded, reference_contacts, reference_floor):
    zero = np.zeros(14); contacts = model.contact_points(zero); floor = model.features_y(zero)
    load = model.load(zero, loaded, caps)
    result = dict(initial_gap_m=model.gap(zero), initial_load=load, selected=None, refusal=None, backtracks=[])
    if not load['feasible']:
        result['refusal'] = 'fixed_support_static_model_infeasible'
        return result
    gradient = S.derivative(model.gap, zero)
    gradient_error = float(np.max(np.abs(gradient-S.derivative(model.gap, zero, 2*S.FD))))
    assert gradient_error < 1e-7
    contact_j = S.derivative(model.contact_points, zero)
    feature_j = S.derivative(model.features_y, zero)
    equality = contact_j[loaded].reshape((-1, 14))
    inequality = np.vstack((-contact_j[:, 1, :], -feature_j))
    rhs = np.r_[np.zeros(len(contacts)), floor-np.minimum(0., floor)]
    lo, hi = S.bounds(model.joints)
    delta, certificate = S.statics.lp(gradient, equality, np.zeros(len(equality)), inequality, rhs, list(zip(lo, hi)))
    result.update(direction=delta.tolist(), direction_certificate=certificate,
        gap_gradient=gradient.tolist(), gradient_step_comparison_error=gradient_error)
    if certificate['primal_objective'] >= -S.PROGRESS:
        result['refusal'] = 'no_first_order_support_progress'
        return result
    for exponent in range(11):
        scale = 2.**(-exponent); samples = []; reason = None
        for fraction in (.25, .5, .75, 1.):
            candidate, iterations = S.project(model, delta*scale*fraction, loaded, contacts)
            if candidate is None:
                reason = 'loaded_contact_projection_failed'
                samples.append(dict(fraction=fraction, reason=reason, projection_iterations=iterations)); break
            local_ok, local = S.guards(model, candidate, contacts, floor, loaded, lo, hi)
            global_ok, global_ = global_guards(model, candidate, reference_contacts, reference_floor, loaded)
            gap = model.gap(candidate)
            sample = dict(fraction=fraction, delta=candidate.tolist(), projection_iterations=iterations,
                residuals=local, global_residuals=global_, gap_m=gap)
            samples.append(sample)
            if not local_ok or not global_ok:
                reason = 'nonlinear_geometry_guard'; break
            if not gap < result['initial_gap_m']-S.PROGRESS*fraction:
                reason = 'no_finite_support_progress'; break
            sample['load'] = model.load(candidate, loaded, caps)
            if not sample['load']['feasible']:
                reason = 'fixed_support_static_model_infeasible'; break
        attempt = dict(scale=scale, samples=samples, refusal=reason)
        result['backtracks'].append(attempt)
        if reason is None:
            result['selected'] = attempt
            return result
    result['refusal'] = 'all_finite_steps_refused'
    return result


def snapshot(model):
    zero = np.zeros(14); poses = model.poses(zero)
    return dict(joints_rad=model.joints.tolist(), torso_position_m=poses[0]['torso'].tolist(),
        torso_basis_columns=poses[1]['torso'].T.tolist(), com_m=model.com(poses).tolist(),
        foot_hull_gap_m=model.gap(zero), shape_bottom_witnesses_m=model.features_y(zero).tolist(),
        original_contact_markers_m=model.contact_points(zero).tolist(),
        joint_headroom_remaining_rad=(S.LIMITS-.02-np.abs(model.joints)).tolist())


def controls():
    result = S.controls()
    class Manufactured:
        def contact_points(self, delta):
            return np.array([[0., 0., 0.], [1., 0., 0.]])+delta[:3]
        def features_y(self, delta):
            return np.array([-.002, .01])+delta[1]
    model = Manufactured(); zero = np.zeros(14)
    points = model.contact_points(zero); floor = model.features_y(zero)
    assert global_guards(model, zero, points, floor, [0])[0]
    down = zero.copy(); down[1] = -2e-9
    assert not global_guards(model, down, points, floor, [0])[0]
    sideways = zero.copy(); sideways[0] = 2e-9
    assert not global_guards(model, sideways, points, floor, [0])[0]
    # A ratchet within each step's tolerance must not bypass original anchors.
    first = zero.copy(); first[0] = .75e-9
    assert global_guards(model, first, points, floor, [0])[0]
    assert not global_guards(model, 2*first, points, floor, [0])[0]
    result['additional_global_anchor_floor_and_drift_controls'] = 5
    return result


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:
        assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy']
    assert S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls()
    descriptor, rows = S.statics.tracking.rows()
    entry = rows[0]; assert entry['semantic_step'] == 513 and entry['partial_step'] == 1
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256'])
    assert replay['ok']
    source = C.read(S.RESULT)['motion']; loaded = source['loaded_contact_indices']
    model = S.Model(packet, descriptor, entry['joint_positions_rad'])
    assert [model.contacts[i]['body_id'] for i in loaded] == ['torso', 'rear_left_distal', 'rear_right_distal']
    caps = [v/G.DT for v in entry['caps']]
    initial = snapshot(model); contacts = model.contact_points(np.zeros(14)); floor = model.features_y(np.zeros(14))
    trajectory = []; stop = 'finite_model_horizon'
    for index in range(MAX_STEPS):
        result = step(model, caps, loaded, contacts, floor)
        if index == 0:
            assert result['selected'] is not None
            a = result['selected']['samples'][-1]; b = source['selected']['samples'][-1]
            assert np.max(np.abs(np.array(a['delta'])-b['delta'])) < 1e-10
            assert abs(a['gap_m']-b['gap_m']) < 1e-10
        row = dict(model_step=index+1, before=snapshot(model), result=result)
        trajectory.append(row)
        if result['selected'] is None:
            stop = result['refusal']; break
        delta = np.array(result['selected']['samples'][-1]['delta'])
        model = advance(model, delta)
        row['after'] = snapshot(model)
        assert row['after']['foot_hull_gap_m'] < row['before']['foot_hull_gap_m']-S.PROGRESS
        if row['after']['foot_hull_gap_m'] <= 1e-6:
            stop = 'all_cap_hull_gap_within_1um_model_only'; break
    final = snapshot(model)
    selected = [r for r in trajectory if r['result']['selected'] is not None]
    summary = dict(stop_reason=stop, accepted_model_steps=len(selected), attempted_model_steps=len(trajectory),
        initial_gap_m=initial['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        gap_reduction_m=initial['foot_hull_gap_m']-final['foot_hull_gap_m'],
        final_joint_headroom_remaining_rad=final['joint_headroom_remaining_rad'],
        torso_translation_m=(np.array(final['torso_position_m'])-initial['torso_position_m']).tolist(),
        torso_basis_max_change=float(np.max(np.abs(np.array(final['torso_basis_columns'])-initial['torso_basis_columns']))),
        final_minimum_nonfoot_weight_fraction=model.load(np.zeros(14), loaded, caps)['minimum_nonfoot_weight_fraction'])
    return dict(schema_version='sporespore_r10at_fixed_contact_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        loaded_contact_indices=loaded, initial=initial, final=final, summary=summary, trajectory=trajectory,
        **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true')
    parser.add_argument('--controls', action='store_true')
    args = parser.parse_args()
    if args.controls:
        print(json.dumps(controls(), indent=2))
    else:
        if args.create:
            C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
