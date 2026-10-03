"""One declared, nonphysical contact-preserving motion at R10AP entry.

Floating-base motions are model variables, not commands the motor interface can
apply. Five checked poses are not continuous collision or dynamic authority.
"""
import argparse
import copy
import itertools
import json
import math
import numpy as np

import r10ar_multicontact_statics as statics
import r10an_support_transfer_study as envelope

C, G = statics.C, statics.G
STUDY = C.ROOT/'sdk/recovery/r10as_contact_motion_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10as_contact_motion_result_v1.json'
FD = 1e-6
GEOMETRY_TOL = 1e-9
PROGRESS = 1e-9
LIMITS = np.array([1.6, 1.1]*4)
MAXIMUM = np.array([.1/math.sqrt(3)*G.DT]*3 + [.6/math.sqrt(3)*G.DT]*3 + [4*G.DT]*8)


def rotation(vector):
    """World-axis exponential rotation; exact identity at the zero update."""
    angle = np.linalg.norm(vector)
    if angle == 0:
        return np.eye(3)
    x, y, z = vector/angle
    skew = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
    return np.eye(3)+math.sin(angle)*skew+(1-math.cos(angle))*(skew@skew)


def derivative(function, value, step=FD):
    return np.stack([(np.asarray(function(value+np.eye(len(value))[i]*step))-
        np.asarray(function(value-np.eye(len(value))[i]*step)))/(2*step)
        for i in range(len(value))], axis=-1)


class Model:
    def __init__(self, packet, descriptor, joints):
        self.packet = packet
        self.d = descriptor
        self.joints = np.array(joints)
        self.names = ['torso']+[f+s for f in G.FEET for s in ('_upper', '_distal')]
        bodies = {b['body_id']: b for b in packet['callback_bodies']}
        self.p = {n: np.array(G.vector(bodies[n]['pose']['origin'])) for n in self.names}
        self.r = {n: np.array(bodies[n]['pose']['basis_columns']).T for n in self.names}
        self.inverse = {n: np.linalg.inv(self.r[n]) for n in self.names}
        self.upper = .35*descriptor['upper_length_fraction']
        self.lower = .35-self.upper
        self.contacts = [p for p in packet['contact_source_receipt']['ordered_contact_samples']
            if p['normal_impulse_ns'] > 0]
        self.local_contacts = [self.local(p['body_id'], G.vector(p['position_world_m'])) for p in self.contacts]
        self.states = packet['direct_state_source']['ordered_body_states']
        self.local_com = {s['body_id']: self.local(s['body_id'], G.vector(s['position_world_m'])) for s in self.states}
        self.mass = sum(s['mass_kg'] for s in self.states)
        self.local_caps = {f: np.array(G.vector(packet['contact_sites_by_body'][f+'_distal']['local_center_m']), dtype=np.float32).astype(float) for f in G.FEET}
        half = [.25*descriptor['torso_length_scale'], .06, .16*descriptor['torso_width_scale']]
        self.features = [('torso', np.array(v)*half, 0.) for v in itertools.product((-1., 1.), repeat=3)]
        for foot in G.FEET:
            for suffix, length, radius in (('_upper', self.upper, .0225), ('_distal', self.lower, .04*descriptor['foot_radius_scale'])):
                self.features.extend((foot+suffix, np.array([0., sign*length/2, 0.]), radius) for sign in (-1., 1.))

    def local(self, body, world):
        return self.inverse[body]@(np.asarray(world)-self.p[body])

    def poses(self, delta):
        """Preserve measured relative transforms and native constraint drift.

        Rotate descendants about measured parent-side hinges. Do not silently
        replace the callback pose with perfect nominal forward kinematics.
        """
        p = {'torso': self.p['torso']+delta[:3]}
        r = {'torso': rotation(delta[3:6])@self.r['torso']}
        for i, foot in enumerate(G.FEET):
            for k, suffix in enumerate(('_upper', '_distal')):
                parent = 'torso' if k == 0 else foot+'_upper'
                child = foot+suffix
                offset = np.array([(.2 if i < 2 else -.2)*self.d['hip_span_scale'], 0.,
                    (-.18 if i % 2 == 0 else .18)*self.d['hip_span_scale']]) if k == 0 else np.array([0., -self.upper/2, 0.])
                inherited = r[parent]@self.inverse[parent]
                anchor = p[parent]+r[parent]@offset
                axis = r[parent][:, 2]/np.linalg.norm(r[parent][:, 2])
                joint = rotation(axis*delta[6+2*i+k])
                p[child] = anchor+joint@(p[parent]+inherited@(self.p[child]-self.p[parent])-anchor)
                r[child] = joint@inherited@self.r[child]
        return p, r

    def point(self, poses, body, local):
        return poses[0][body]+poses[1][body]@local

    def contact_points(self, delta):
        poses = self.poses(delta)
        return np.array([self.point(poses, p['body_id'], local) for p, local in zip(self.contacts, self.local_contacts)])

    def features_y(self, delta):
        poses = self.poses(delta)
        return np.array([self.point(poses, body, local)[1]-radius for body, local, radius in self.features])

    def com(self, poses):
        return sum((s['mass_kg']*self.point(poses, s['body_id'], self.local_com[s['body_id']]) for s in self.states))/self.mass

    def gap(self, delta):
        poses = self.poses(delta)
        feet = [self.point(poses, f+'_distal', self.local_caps[f]) for f in G.FEET]
        return envelope.envelope(self.com(poses), feet)['distance_m']

    def load(self, delta, indices, caps):
        packet = copy.deepcopy(self.packet)
        poses = self.poses(delta)
        for b in packet['callback_bodies']:
            n = b['body_id']
            b['pose']['origin'] = poses[0][n].tolist()
            b['pose']['basis_columns'] = poses[1][n].T.tolist()
        for s in packet['direct_state_source']['ordered_body_states']:
            s['position_world_m'] = self.point(poses, s['body_id'], self.local_com[s['body_id']]).tolist()
        points = self.contact_points(delta)
        chosen = []
        for i in indices:
            contact = copy.deepcopy(self.contacts[i])
            contact['position_world_m'] = points[i].tolist()
            chosen.append(contact)
        packet['contact_source_receipt']['ordered_contact_samples'] = chosen
        contacts, jacobian, rhs, weight, _ = statics.frame(packet, self.d, self.com(poses))
        a = np.zeros((14, 3*len(contacts)+8)); a[6:, 3*len(contacts):] = np.eye(8)
        for i, p in enumerate(contacts):
            a[:, 3*i:3*i+3] = jacobian(p['body_id'], G.vector(p['position_world_m'])).T
        return statics.solve(a, rhs, [p['classified_as_foot'] for p in contacts], caps, 1.8, weight)


def bounds(joints):
    # Keep existing margin where available; do not force a discontinuous jump
    # if an observed coordinate is already within 0.02 rad of its hard limit.
    extent = np.maximum(LIMITS-.02, np.abs(joints))
    assert np.all(np.abs(joints) <= LIMITS)
    lo, hi = -MAXIMUM.copy(), MAXIMUM.copy()
    lo[6:] = np.maximum(lo[6:], -extent-joints)
    hi[6:] = np.minimum(hi[6:], extent-joints)
    return lo, hi


def project(model, delta, loaded, initial):
    value = delta.copy()
    for iteration in range(11):
        residual = (model.contact_points(value)[loaded]-initial[loaded]).reshape(-1)
        if np.max(np.abs(residual)) <= 1e-11:
            return value, iteration
        if iteration == 10:
            return None, iteration
        jacobian = derivative(lambda q: model.contact_points(q)[loaded].reshape(-1), value)
        correction = np.linalg.lstsq(jacobian*MAXIMUM, -residual, rcond=1e-12)[0]*MAXIMUM
        value += correction
    raise AssertionError('unreachable')


def guards(model, delta, initial, floor, loaded, lo, hi):
    points = model.contact_points(delta)
    deficits = np.maximum(0., .02-LIMITS+np.abs(model.joints+delta[6:]))
    before = np.maximum(0., .02-LIMITS+np.abs(model.joints))
    residuals = dict(bounds=max(float(np.max(lo-delta)), float(np.max(delta-hi))),
        loaded_contact=float(np.max(np.abs(points[loaded]-initial[loaded]))),
        contact_descent=float(np.max(initial[:, 1]-points[:, 1])),
        floor=float(np.max(np.minimum(0., floor)-model.features_y(delta))),
        headroom=float(np.max(deficits-before)))
    return all(v <= GEOMETRY_TOL for v in residuals.values()), residuals


def motion(model, caps):
    zero = np.zeros(14); initial = model.contact_points(zero); floor = model.features_y(zero)
    original = model.load(zero, list(range(len(initial))), caps)
    if not original['feasible']:
        return dict(selected=None, refusal='initial_stationary_model_infeasible', original_load=original)
    loaded = [i for i, force in enumerate(original['forces_world_n']) if force[1] > 1e-6]
    restricted = model.load(zero, loaded, caps)
    assert restricted['feasible'], 'Discarding near-zero force contacts changed feasibility'
    gradient = derivative(model.gap, zero)
    gradient_error = float(np.max(np.abs(gradient-derivative(model.gap, zero, 2*FD))))
    assert gradient_error < 1e-7
    contact_j = derivative(model.contact_points, zero)
    feature_j = derivative(model.features_y, zero)
    equality = contact_j[loaded].reshape((-1, 14))
    inequality = np.vstack((-contact_j[:, 1, :], -feature_j))
    rhs = np.r_[np.zeros(len(initial)), floor-np.minimum(0., floor)]
    lo, hi = bounds(model.joints)
    direction, certificate = statics.lp(gradient, equality, np.zeros(len(equality)), inequality, rhs, list(zip(lo, hi)))
    result = dict(original_load=original, restricted_load=restricted, loaded_contact_indices=loaded,
        loaded_contact_bodies=[model.contacts[i]['body_id'] for i in loaded],
        initial_gap_m=model.gap(zero), gap_gradient=gradient.tolist(), gradient_step_comparison_error=gradient_error,
        direction=direction.tolist(), direction_certificate=certificate, backtracks=[], selected=None, refusal=None)
    if certificate['primal_objective'] >= -PROGRESS:
        result['refusal'] = 'no_first_order_support_progress'
        return result
    for exponent in range(11):
        scale = 2.**(-exponent)
        rows = []; reason = None
        for fraction in (.25, .5, .75, 1.):
            delta, iterations = project(model, direction*scale*fraction, loaded, initial)
            if delta is None:
                reason = 'loaded_contact_projection_failed'
                rows.append(dict(fraction=fraction, projection_iterations=iterations, reason=reason)); break
            accepted, residuals = guards(model, delta, initial, floor, loaded, lo, hi)
            gap = model.gap(delta)
            row = dict(fraction=fraction, delta=delta.tolist(), projection_iterations=iterations,
                residuals=residuals, gap_m=gap)
            rows.append(row)
            if not accepted:
                reason = 'nonlinear_geometry_guard'; break
            if not gap < result['initial_gap_m']-PROGRESS*fraction:
                reason = 'no_finite_support_progress'; break
            row['load'] = model.load(delta, loaded, caps)
            if not row['load']['feasible']:
                reason = 'proposed_stationary_model_infeasible'; break
        attempt = dict(scale=scale, samples=rows, refusal=reason)
        result['backtracks'].append(attempt)
        if reason is None:
            result['selected'] = attempt
            break
    if result['selected'] is None:
        result['refusal'] = 'all_finite_steps_refused'
    return result


def controls():
    count = 0
    assert np.array_equal(rotation(np.zeros(3)), np.eye(3)); count += 1
    assert np.max(np.abs(rotation(np.array([0., 0., math.pi/2]))@np.array([1., 0., 0.])-np.array([0., 1., 0.]))) < 1e-14; count += 1
    r = rotation(np.array([.2, -.3, .7])); assert np.max(np.abs(r.T@r-np.eye(3))) < 1e-14; count += 1
    lo, hi = bounds(np.array([1.59, 0.]*4)); assert np.all(hi[6::2] == 0.); count += 1
    assert np.all(lo <= 0.) and np.all(hi >= 0.); count += 1
    # Manufactured nonsymmetric body frames exercise both ancestor joints and
    # preserve an intentional child/parent positional constraint offset.
    d = dict(upper_length_fraction=.5, hip_span_scale=1., torso_length_scale=1., torso_width_scale=1., foot_radius_scale=1.)
    bodies = []; states = []
    for i, n in enumerate(['torso']+[f+s for f in G.FEET for s in ('_upper', '_distal')]):
        p = np.array([i*.07, .5-i*.013, -.11+i*.019]); b = rotation(np.array([.03*i, -.02*i, .1*i]))
        bodies.append(dict(body_id=n, pose=dict(origin=p.tolist(), basis_columns=b.T.tolist())))
        states.append(dict(body_id=n, mass_kg=1., position_world_m=p.tolist()))
    contacts = [dict(body_id=b['body_id'], position_world_m=(np.array(b['pose']['origin'])+np.array([.02, -.03, .04])).tolist(), normal_impulse_ns=1., classified_as_foot=b['body_id'].endswith('_distal')) for b in bodies]
    packet = dict(callback_bodies=bodies, direct_state_source=dict(ordered_body_states=states, gravity_world_m_s2=[0., -9.8, 0.]),
        contact_source_receipt=dict(ordered_contact_samples=contacts),
        contact_sites_by_body={f+'_distal': dict(local_center_m=[0., -.0875, 0.]) for f in G.FEET})
    model = Model(packet, d, [0.]*8); zero = np.zeros(14)
    p, r = model.poses(zero)
    assert max(np.max(np.abs(p[n]-model.p[n])) for n in model.names) < 1e-14; count += 1
    assert max(np.max(np.abs(r[n]-model.r[n])) for n in model.names) < 1e-14; count += 1
    _, jacobian, _, _, _ = statics.frame(packet, d, model.com((p, r)))
    numerical = derivative(model.contact_points, zero)
    error = max(np.max(np.abs(numerical[i]-jacobian(c['body_id'], G.vector(c['position_world_m'])))) for i, c in enumerate(contacts))
    assert error < 1e-8; count += len(contacts)
    # Deliberate downward motion violates the contact and floor guard.
    down = zero.copy(); down[1] = -.001
    lo, hi = bounds(model.joints)
    assert not guards(model, down, model.contact_points(zero), model.features_y(zero), [0], lo, hi)[0]; count += 1
    return dict(known_answer_and_jacobian_controls=count, maximum_manufactured_jacobian_error=error)


def derive():
    declaration = C.read(STUDY)
    for b in [*declaration['dependencies'], declaration['population']['report']]:
        assert C.bind(b['path']) == b
    assert np.__version__ == declaration['numerics']['numpy']
    assert statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls()
    descriptor, samples = statics.tracking.rows()
    row = samples[0]; assert row['partial_step'] == 1 and row['semantic_step'] == 513
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == row['semantic_step'])
    replay = statics.replay.replay(packet, packet['semantic_step'], packet['model_instance_id'], packet['body_population_instance_sha256'])
    assert replay['ok']
    model = Model(packet, descriptor, row['joint_positions_rad'])
    points, jacobian, _, _, _ = statics.frame(packet, descriptor, row['com'])
    numerical = derivative(model.contact_points, np.zeros(14))
    error = max(np.max(np.abs(numerical[i]-jacobian(p['body_id'], G.vector(p['position_world_m'])))) for i, p in enumerate(points))
    assert error < 1e-8
    result = motion(model, [v/G.DT for v in row['caps']])
    original = C.read(statics.RESULT)['rows'][0]['variants']['all_contacts_capped']
    assert result['original_load']['feasible'] == original['feasible']
    assert abs(result['original_load']['minimum_nonfoot_weight_fraction']-original['minimum_nonfoot_weight_fraction']) < 1e-8
    return dict(schema_version='sporespore_r10as_contact_motion_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked,
        semantic_step=row['semantic_step'], contact_replay=replay, measured_jacobian_maximum_error=float(error),
        motion=result, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    motion = result['motion']
    return dict(ok=True, controls=result['controls'], selected=motion['selected'] is not None,
        refusal=motion['refusal'], initial_gap_m=motion.get('initial_gap_m'),
        selected_gap_m=None if motion['selected'] is None else motion['selected']['samples'][-1]['gap_m'],
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
