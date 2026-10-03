"""Diagnostic constraint omissions for R10AV's geometric lock, never admission.

Omitted guards stay required in production and in every existing study. The
counterfactual LPs identify which constraint families limit the model only.
"""
import argparse
import json
import numpy as np

import r10av_sliding_support_study as V

S, C, G = V.S, V.C, V.G
STUDY = C.ROOT/'sdk/recovery/r10aw_contact_constraint_diagnosis_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10aw_contact_constraint_diagnosis_result_v1.json'
VARIANTS = ('full', 'omit_shape_floor', 'omit_marker_nondescent',
    'omit_floor_and_marker', 'omit_sticking_tangent', 'omit_nontorso_contact_equalities')


def problem(model, selected, heading, axis, sign, variant):
    zero = np.zeros(14); points = model.contact_points(zero); floor = model.features_y(zero)
    contact_j = S.derivative(model.contact_points, zero); floor_j = S.derivative(model.features_y, zero)
    equality = []; equal_names = []; inequality = []; limits = []; names = []
    for i in selected:
        torso = model.contacts[i]['body_id'] == 'torso'
        if not torso and variant == 'omit_nontorso_contact_equalities':
            continue
        axes = [1] if torso or variant == 'omit_sticking_tangent' else [0, 1, 2]
        for coordinate in axes:
            equality.append(contact_j[i, coordinate]); equal_names.append(f'contact_{i}_axis_{coordinate}')
    for i in range(len(points)):
        if variant not in ('omit_marker_nondescent', 'omit_floor_and_marker'):
            inequality.append(-contact_j[i, 1]); limits.append(0.); names.append(f'marker_{i}_nondescent')
    for i in range(len(floor)):
        if variant not in ('omit_shape_floor', 'omit_floor_and_marker'):
            inequality.append(-floor_j[i]); limits.append(floor[i]-min(0., floor[i])); names.append(f'shape_witness_{i}_floor')
    for i in selected:
        if model.contacts[i]['body_id'] == 'torso':
            for transverse in (-1., 1.):
                inequality.append(transverse*contact_j[i, 2-axis]-sign*contact_j[i, axis])
                limits.append(0.); names.append(f'contact_{i}_slide_sector_{transverse}')
    a = np.array(equality).reshape((-1, 14)); u = np.array(inequality).reshape((-1, 14))
    return (a, np.zeros(len(a)), u, np.array(limits), equal_names, names)


def solve(model, selected, heading, axis, sign, variant, full):
    a, b, u, v, equal_names, names = problem(model, selected, heading, axis, sign, variant)
    lo, hi = S.bounds(model.joints); cost = np.r_[-heading, np.zeros(11)]
    delta, certificate = S.statics.lp(cost, a, b, u, v, list(zip(lo, hi)))
    full_a, full_b, full_u, full_v, full_equal_names, full_names = full
    equal_residual = np.abs(full_a@delta-full_b); inequality_residual = full_u@delta-full_v
    omitted_violations = [dict(constraint=n, residual=float(r)) for n, r in zip(full_equal_names, equal_residual) if n not in equal_names and r > 1e-9]
    omitted_violations.extend(dict(constraint=n, residual=float(r)) for n, r in zip(full_names, inequality_residual) if n not in names and r > 1e-9)
    return dict(variant=variant, forward_linear_progress_m=float(delta[:3]@heading), delta=delta.tolist(),
        certificate=certificate, full_constraint_violations=omitted_violations,
        nonlinear_step_admitted=False, controller_selected=False, relaxed_guard_has_authority=False)


def controls():
    checked = S.controls(); count = 0
    # A positive objective is blocked by either an equality or an inequality,
    # and removing the relevant row recovers the analytic bounded optimum.
    cost = np.array([-1., 0.]); bounds = [(0., 1.), (0., 1.)]
    for a, u, expected in (([[1., 0.]], [[0., 0.]], 0.),
        ([[0., 1.]], [[1., 0.]], 0.), ([[0., 1.]], [[0., 0.]], 1.)):
        x, receipt = S.statics.lp(cost, np.array(a), np.array([0.]), np.array(u), np.array([0.]), bounds)
        assert abs(x[0]-expected) < 1e-10; count += 1
        assert abs(receipt['primal_objective']+expected) < 1e-10; count += 1
    checked['additional_known_constraint_omission_controls'] = count
    return checked


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:
        assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    assert entry['semantic_step'] == 513 and entry['partial_step'] == 1
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet,513,packet['model_instance_id'],packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet,descriptor,entry['joint_positions_rad']); source = C.read(V.RESULT)
    heading = np.array(source['heading']); axis = source['sector_axis']; sign = source['sector_sign']
    rows = []
    for record in source['survey']:
        original = record['result']
        if not original.get('initial_load', {}).get('feasible', False):
            continue
        selected = record['support_indices']; full = problem(model, selected, heading, axis, sign, 'full')
        variants = [solve(model, selected, heading, axis, sign, name, full) for name in VARIANTS]
        assert abs(variants[0]['certificate']['primal_objective']-original['direction_certificates']['maximum_progress']['primal_objective']) < 1e-10
        rows.append(dict(mask=record['mask'], support_indices=selected, variants=variants))
    assert len(rows) == 17
    zero = np.zeros(14); points = model.contact_points(zero); floor = model.features_y(zero)
    contact_geometry = []
    for i, contact in enumerate(model.contacts):
        body = contact['body_id']; local = model.local_contacts[i]
        if body == 'torso':
            half = np.array([.25*descriptor['torso_length_scale'], .06, .16*descriptor['torso_width_scale']])
            distance = float(np.linalg.norm(np.maximum(np.abs(local)-half, 0.)))
            signed_distance = distance+min(float(np.max(np.abs(local)-half)), 0.)
            shape = 'box'; extra = dict(outside_box_distance_m=distance, signed_box_surface_distance_m=signed_distance)
        else:
            length = model.upper if body.endswith('_upper') else model.lower
            radius = .0225 if body.endswith('_upper') else .04*descriptor['foot_radius_scale']
            axis_point = np.array([0., np.clip(local[1], -length/2, length/2), 0.])
            signed_distance = float(np.linalg.norm(local-axis_point)-radius)
            shape = 'capsule'; extra = dict(signed_capsule_surface_distance_m=signed_distance)
        contact_geometry.append(dict(index=i, body=body, is_foot=contact['classified_as_foot'], world_y_m=float(points[i, 1]),
            callback_local_point_m=local.tolist(), compiled_shape=shape, **extra))
    summary = {name:dict(positive_linear_progress=sum(r['variants'][j]['forward_linear_progress_m'] > 1e-9 for r in rows),
        maximum_linear_progress_m=max(r['variants'][j]['forward_linear_progress_m'] for r in rows)) for j, name in enumerate(VARIANTS)}
    return dict(schema_version='sporespore_r10aw_contact_constraint_diagnosis_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, original_entry_contact_replay=replay,
        summary=summary, contact_geometry=contact_geometry,
        shape_witnesses=[dict(index=i,body=f[0],local_center_m=f[1].tolist(),radius_m=f[2],floor_height_m=float(floor[i])) for i, f in enumerate(model.features)],
        rows=rows, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True,controls=result['controls'],summary=result['summary'],world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create',action='store_true'); parser.add_argument('--controls',action='store_true')
    args = parser.parse_args()
    if args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:C.write_new(RESULT,derive())
        print(json.dumps(audit(),indent=2))
