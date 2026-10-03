"""Finite local velocity and secondary-optimum-face diagnosis at R10BN step65.

Perturbed probes are numerical diagnostics, never admitted poses or new path
increments. The observed integration budget and result remain immutable.
"""
import argparse
import copy
import json
import subprocess
import numpy as np

import r10bn_bounded_torso_raise_path as N

L, C, S, G, Z, I, T = N.L, N.C, N.S, N.G, N.Z, N.I, N.T
STUDY = C.ROOT/'sdk/recovery/r10bo_velocity_field_diagnosis_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bo_velocity_field_diagnosis_result_v1.json'
SCALES = (1e-8, 1e-6)
FACE_ALLOWANCE = 1e-10


def probes():
    return [dict(coordinate=None, sign=0, scale=0.)]+[
        dict(coordinate=i, sign=sign, scale=scale) for scale in SCALES for i in range(14) for sign in (-1, 1)]


def problem(model, modes):
    # Rebuild the exact L.velocity constraints, exposing the secondary face for
    # diagnostics. A direct original-function comparison is required at center.
    zero = np.zeros(14); j = I.material_jacobian(model)
    floor = model.features_y(zero); fj = L.floor_jacobian(model)
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
    lo, hi = S.bounds(model.joints); cost = np.r_[-N.HEADING, np.zeros(11)]
    a = a*S.MAXIMUM; u = u*S.MAXIMUM; cost = cost*S.MAXIMUM
    a /= np.maximum(np.max(np.abs(a), axis=1), 1e-12)[:, None]
    unorm = np.maximum(np.max(np.abs(u), axis=1), 1e-12); u /= unorm[:, None]; v /= unorm
    bounds = list(zip(lo/S.MAXIMUM, hi/S.MAXIMUM))
    _, first = L.certified_lp('diagnostic_primary_raise', cost, a, np.zeros(len(a)), u, v, bounds)
    a2, u2, v2, bounds2, row_scale = L.secondary_problem(cost, first['primal_objective'], a, u, v, bounds)
    cost2 = np.r_[np.zeros(14), np.ones(14)]
    x, second = L.certified_lp('diagnostic_secondary_motion', cost2, a2, np.zeros(len(a2)), u2, v2, bounds2)
    record = dict(normalized_velocity=x[:14].tolist(), velocity=(x[:14]*S.MAXIMUM).tolist(),
        primary_certificate=first, secondary_certificate=second,
        secondary_solution=x.tolist(), objective_row_scale=row_scale,
        equality=a2.tolist(), equality_rhs=np.zeros(len(a2)).tolist(), inequality=u2.tolist(),
        inequality_rhs=v2.tolist(), bounds=[[None if x is None else float(x) for x in pair] for pair in bounds2], cost=cost2.tolist())
    return record


def face_extreme(center, coordinate, sign):
    a = np.array(center['equality']); b = np.array(center['equality_rhs'])
    u = np.vstack((center['inequality'], center['cost']))
    v = np.r_[center['inequality_rhs'], center['secondary_certificate']['primal_objective']+FACE_ALLOWANCE]
    cost = np.zeros(28); cost[coordinate] = sign
    x, certificate = L.certified_lp('secondary_face_coordinate_extreme', cost, a, b, u, v, center['bounds'])
    return dict(coordinate=coordinate, cost_sign=sign, normalized_velocity=x[:14].tolist(),
        secondary_objective=float(np.array(center['cost'])@x),
        secondary_objective_excess=float(np.array(center['cost'])@x-center['secondary_certificate']['primal_objective']),
        certificate=certificate)


def controls():
    checked = N.M.controls()
    population = probes()
    assert len(population) == len({tuple(row.values()) for row in population}) == 57
    # Flat minimum-L1 face: x+y=1 with x,y>=0 has four known coordinate extrema.
    a = np.array([[1., 1.]]); b = np.array([1.]); u = np.array([[1., 1.]]); v = np.array([1.])
    for coordinate in range(2):
        for sign in (-1., 1.):
            cost = np.zeros(2); cost[coordinate] = sign
            x, certificate = L.certified_lp('manufactured_flat_face', cost, a, b, u, v, [(0., 1.)]*2)
            assert certificate['accepted'] and abs(x[coordinate]-(1. if sign < 0 else 0.)) <= 1e-12
    try:L.certified_lp('manufactured_empty_face', np.zeros(2), a, b, u, np.array([.9]), [(0., 1.)]*2)
    except L.VelocityRefusal as failure:assert not failure.record['solver_success']
    else:raise AssertionError('empty face accepted')
    checked['additional_probe_population_flat_face_extremes_and_empty_face_controls'] = 6
    return checked


def declare():
    old = C.read(N.STUDY)
    record = dict(schema_version='sporespore_r10bo_velocity_field_diagnosis_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_retained_probe_velocity_field_diagnosis', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='How sensitive is the certified velocity near the exact retained R10BN budget-refusal probe, and how wide is its near-optimal secondary L1 face?',
        dependencies=old['dependencies']+[C.bind(p) for p in [N.__file__, N.STUDY, N.RESULT, __file__]],
        population=old['population'],
        design=dict(reconstruction='Rebuild original entry and replay only the64 recorded admitted deltas. Require exact before/after snapshots and original final snapshot. Do not integrate or rerun R10BN.',
            center='Exact last_integration_probe.delta from R10BN step65. This probe was not admitted and remains unadmitted.',
            probes='Center plus each of14 coordinates perturbed by each sign of1e-8 and1e-6 times its original MAXIMUM:57 calls. Keep all statuses/certificates. No threshold-defined continuity or global claim.',
            verification='Expose an exact copy of L.velocity LP construction; require center physical velocity and both certificates to equal direct L.velocity. Use unchanged presolve-disabled backend and1e-6 independent certificate.',
            face='At the center, minimize and maximize each normalized velocity coordinate with original secondary constraints plus secondary sum-absolute epigraph cost <= observed optimum+1e-10 normalized units. Retain28 solves and actual objective excess. This allowance and LP tolerances must accompany any range interpretation.',
            retention='Retain every numerical refusal and exact failed-LP inputs. No pose, direction or solver successor is selected for a controller. Full cold replay.'),
        numerics=dict(old['numerics'], perturbation_scales=list(SCALES), secondary_face_allowance=FACE_ALLOWANCE),
        checks=['142 inherited plus6 finite population, flat-face extreme and empty-face controls; inherited coverage shared.',
            'Exact retained-delta reconstruction and center implementation agreement before interpretation.'],
        research_sources=old['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def reconstruct():
    retained = C.read(N.RESULT); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = I.CapModel(packet, descriptor, entry['joint_positions_rad'])
    assert T.snapshot(model) == retained['initial']
    accepted = 0
    for row in retained['trajectory']:
        assert T.snapshot(model) == row['before']
        if not row['admitted']:break
        model = I.advance(model, np.array(row['nodes'][-1]['delta'])); accepted += 1
        assert T.snapshot(model) == row['after']
    assert accepted == 64 and T.snapshot(model) == retained['final']
    assert row['model_step'] == 65 and row['refusal'] == 'integrator_rhs_budget'
    return model, retained, replay


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); base, previous, replay = reconstruct(); modes = previous['summary']['selected_modes']
    original = np.array(previous['trajectory'][-1]['last_integration_probe']['delta']); rows = []; center = None
    for specification in probes():
        delta = original.copy()
        if specification['coordinate'] is not None:
            i = specification['coordinate']; delta[i] += specification['sign']*specification['scale']*S.MAXIMUM[i]
        model = I.advance(base, delta); row = dict(specification=specification, delta=delta.tolist(), result=None, refusal=None)
        rows.append(row)
        try:computed = problem(model, modes)
        except L.VelocityRefusal as failure:row['refusal'] = failure.record; continue
        if specification['coordinate'] is None:
            center = computed
            direct, certificate = L.velocity(model, modes, N.HEADING)
            assert direct.tolist() == center['velocity']
            assert certificate == dict(maximum_progress=center['primary_certificate'], minimum_normalized_motion=center['secondary_certificate'])
        # Full center LP is enough to reconstruct its face; perturbations keep
        # solutions and certificates, with exact matrices on any refused LP.
        row['result'] = {k:v for k,v in computed.items() if k not in ['equality', 'equality_rhs', 'inequality', 'inequality_rhs', 'bounds', 'cost']}
    extremes = []
    if center is not None:
        for coordinate in range(14):
            for sign in (-1, 1):
                row = dict(coordinate=coordinate, cost_sign=sign, result=None, refusal=None); extremes.append(row)
                try:row['result'] = face_extreme(center, coordinate, sign)
                except L.VelocityRefusal as failure:row['refusal'] = failure.record
    sensitivity = []
    if center is not None:
        reference = np.array(center['normalized_velocity'])
        for scale in SCALES:
            candidates = [row for row in rows if row['specification']['scale'] == scale and row['result'] is not None]
            changes = [dict(specification=row['specification'], maximum_normalized_velocity_change=float(np.max(np.abs(np.array(row['result']['normalized_velocity'])-reference))),
                primary_objective_change_m=row['result']['primary_certificate']['primal_objective']-center['primary_certificate']['primal_objective']) for row in candidates]
            sensitivity.append(dict(scale=scale, successful_probes=len(changes), largest_change=max(changes,key=lambda row:row['maximum_normalized_velocity_change']) if changes else None))
    ranges = []
    for coordinate in range(14):
        pair = [row['result'] for row in extremes if row['coordinate'] == coordinate]
        if len(pair) == 2 and all(row is not None for row in pair):
            high, low = pair
            ranges.append(dict(coordinate=coordinate, normalized_min=low['normalized_velocity'][coordinate], normalized_max=high['normalized_velocity'][coordinate],
                normalized_width=high['normalized_velocity'][coordinate]-low['normalized_velocity'][coordinate],
                maximum_secondary_objective_excess=max(low['secondary_objective_excess'],high['secondary_objective_excess'])))
    return dict(schema_version='sporespore_r10bo_velocity_field_diagnosis_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        retained_increments_reconstructed=64, center_problem=center, probes=rows, face_extremes=extremes,
        summary=dict(velocity_probes=len(rows), successful_velocity_probes=sum(row['result'] is not None for row in rows),
            face_probes=len(extremes), successful_face_probes=sum(row['result'] is not None for row in extremes),
            sensitivity=sensitivity, secondary_face_ranges=ranges, new_model_increments=0), **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, full_replay_passed=True, controls=result['controls'], summary=result['summary'],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ('create', 'controls', 'declare'):parser.add_argument('--'+option, action='store_true')
    args = parser.parse_args()
    if args.declare:declare(); print('R10BO prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    elif args.create:
        assert not RESULT.exists(); result = derive(); C.write_new(RESULT, result)
        print(json.dumps(dict(ok=True, full_replay_passed=False, controls=result['controls'], summary=result['summary']), indent=2))
    else:print(json.dumps(audit(), indent=2))
