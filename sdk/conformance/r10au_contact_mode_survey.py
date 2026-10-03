"""Exhaust all retained entry-contact subsets before selecting a motion mode.

Every result is a stationary/kinematic model result on one exposed input.
Neither a support subset nor a feasible pose is a native recovery controller.
"""
import argparse
from collections import Counter
import json
import numpy as np

import r10as_contact_motion_study as S

C, G = S.C, S.G
STUDY = C.ROOT/'sdk/recovery/r10au_contact_mode_survey_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10au_contact_mode_survey_result_v1.json'
OBJECTIVES = ('root_forward', 'torso_level', 'rear_left_retreat', 'rear_right_retreat')


def subsets(count):
    return [[i for i in range(count) if mask & (1 << i)] for mask in range(1 << count)]


def objective(model, name, delta, heading):
    poses = model.poses(delta)
    if name == 'root_forward':
        return float(poses[0]['torso']@heading)
    if name == 'torso_level':
        return float(poses[1]['torso'][1, 1])
    foot = 'rear_left' if name == 'rear_left_retreat' else 'rear_right'
    return -float(model.point(poses, foot+'_distal', model.local_caps[foot])@heading)


def test_direction(model, caps, loaded, name, heading, geometry):
    zero = np.zeros(14); initial, floor, contact_j, feature_j = geometry
    value = lambda q: objective(model, name, q, heading)
    baseline = value(zero); gradient = S.derivative(value, zero)
    error = float(np.max(np.abs(gradient-S.derivative(value, zero, 2*S.FD))))
    assert error < 1e-7
    equality = contact_j[loaded].reshape((-1, 14))
    inequality = np.vstack((-contact_j[:, 1, :], -feature_j))
    rhs = np.r_[np.zeros(len(initial)), floor-np.minimum(0., floor)]
    lo, hi = S.bounds(model.joints)
    direction, certificate = S.statics.lp(-gradient, equality, np.zeros(len(equality)), inequality, rhs, list(zip(lo, hi)))
    result = dict(objective=name, baseline=baseline, gradient_step_comparison_error=error,
        direction=direction.tolist(), direction_certificate=certificate, backtracks=[], selected=None, refusal=None)
    if -certificate['primal_objective'] <= S.PROGRESS:
        result['refusal'] = 'no_first_order_objective_progress'
        return result
    for exponent in range(11):
        scale = 2.**(-exponent); rows = []; reason = None
        for fraction in (.25, .5, .75, 1.):
            delta, iterations = S.project(model, direction*scale*fraction, loaded, initial)
            if delta is None:
                reason = 'loaded_contact_projection_failed'
                rows.append(dict(fraction=fraction, projection_iterations=iterations, reason=reason)); break
            accepted, residuals = S.guards(model, delta, initial, floor, loaded, lo, hi)
            progress = value(delta)-baseline
            row = dict(fraction=fraction, delta=delta.tolist(), projection_iterations=iterations,
                residuals=residuals, objective_progress=progress, foot_hull_gap_m=model.gap(delta))
            rows.append(row)
            if not accepted:
                reason = 'nonlinear_geometry_guard'; break
            if progress <= S.PROGRESS*fraction:
                reason = 'no_finite_objective_progress'; break
            row['load'] = model.load(delta, loaded, caps)
            if not row['load']['feasible']:
                reason = 'proposed_stationary_model_infeasible'; break
        attempt = dict(scale=scale, samples=rows, refusal=reason)
        result['backtracks'].append(attempt)
        if reason is None:
            result['selected'] = attempt
            return result
    result['refusal'] = 'all_finite_steps_refused'
    return result


def controls():
    checked = S.controls()
    modes = subsets(7)
    assert len(modes) == len(set(tuple(x) for x in modes)) == 128
    assert modes[0] == [] and modes[-1] == list(range(7))
    assert all(sum(i in mode for mode in modes) == 64 for i in range(7))
    class Manufactured:
        local_caps = dict(rear_left=np.zeros(3), rear_right=np.zeros(3))
        def poses(self, delta):
            return ({'torso': delta[:3], 'rear_left_distal': delta[6:9], 'rear_right_distal': delta[9:12]},
                {'torso': S.rotation(delta[3:6])})
        def point(self, poses, body, local):
            return poses[0][body]+local
    model = Manufactured(); heading = np.array([1., 0., 0.]); delta = np.zeros(14)
    delta[0] = .02; delta[6] = -.03; delta[9] = -.04
    assert objective(model, 'root_forward', delta, heading) == .02
    assert objective(model, 'rear_left_retreat', delta, heading) == .03
    assert objective(model, 'rear_right_retreat', delta, heading) == .04
    delta[5] = .2
    assert abs(objective(model, 'torso_level', delta, heading)-np.cos(.2)) < 1e-14
    checked['additional_exhaustive_subset_and_objective_sign_controls'] = 7
    return checked


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:
        assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy']
    assert S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls()
    descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    assert entry['semantic_step'] == 513 and entry['partial_step'] == 1
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256'])
    assert replay['ok']
    model = S.Model(packet, descriptor, entry['joint_positions_rad']); zero = np.zeros(14)
    caps = [v/G.DT for v in entry['caps']]
    assert len(model.contacts) == 7
    heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    geometry = (model.contact_points(zero), model.features_y(zero),
        S.derivative(model.contact_points, zero), S.derivative(model.features_y, zero))
    rows = []
    for mask, loaded in enumerate(subsets(7)):
        load = model.load(zero, loaded, caps)
        row = dict(mask=mask, support_indices=loaded, support_bodies=[model.contacts[i]['body_id'] for i in loaded],
            support_is_foot=[model.contacts[i]['classified_as_foot'] for i in loaded], load=load, motions=[])
        if load['feasible']:
            assert loaded
            row['motions'] = [test_direction(model, caps, loaded, name, heading, geometry) for name in OBJECTIVES]
        rows.append(row)
    by_objective = {}
    for name in OBJECTIVES:
        trials = [(r['mask'], t) for r in rows for t in r['motions'] if t['objective'] == name]
        admitted = [(mask, trial) for mask, trial in trials if trial['selected'] is not None]
        best = max(admitted, key=lambda pair: (pair[1]['selected']['samples'][-1]['objective_progress'], -pair[0])) if admitted else None
        by_objective[name] = dict(tested=len(trials), admitted=len(admitted),
            refusals=dict(Counter(t['refusal'] for _, t in trials if t['selected'] is None)),
            largest_progress_example=None if best is None else dict(mask=best[0],
                objective_progress=best[1]['selected']['samples'][-1]['objective_progress'],
                scale=best[1]['selected']['scale'],
                foot_hull_gap_m=best[1]['selected']['samples'][-1]['foot_hull_gap_m']))
    return dict(schema_version='sporespore_r10au_contact_mode_survey_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        contact_identity=[dict(index=i, body=p['body_id'], is_foot=p['classified_as_foot'], world_m=G.vector(p['position_world_m'])) for i, p in enumerate(model.contacts)],
        heading=heading.tolist(), summary=dict(subset_count=128, static_feasible=sum(r['load']['feasible'] for r in rows),
            static_refused=sum(not r['load']['feasible'] for r in rows), objectives=by_objective), rows=rows,
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
