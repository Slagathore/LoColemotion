"""Prospective rear-foot placement with fixed torso/front configuration.

Rear support sites follow the lowest point of the modeled spherical foot cap.
They are declared counterfactual sites, not authenticated native contact samples.
"""
import argparse
import copy
import json
import subprocess
import sys
import numpy as np
from scipy.optimize import minimize

import r10bf_feasible_force_seed_path as F
import r10au_contact_mode_survey as U

B, P, T, S, C, G, Z = F.B, F.P, F.T, F.S, F.C, F.G, F.Z
STUDY = C.ROOT/'sdk/recovery/r10bg_supported_rear_placement_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bg_supported_rear_placement_result_v1.json'
REAR = ('rear_left', 'rear_right')
MOVING = np.array([10, 11, 12, 13])
SUPPORT = [1, 1, 0, 1, 0, 0, 0]
MARGIN = .02
MAX_STEPS = 600


class RearCapModel(S.Model):
    def contact_points(self, delta):
        points = super().contact_points(delta); poses = self.poses(delta)
        radius = .04*self.d['foot_radius_scale']
        for i, contact in enumerate(self.contacts):
            for foot in REAR:
                if contact['body_id'] == foot+'_distal' and contact['classified_as_foot']:
                    points[i] = self.point(poses, foot+'_distal', self.local_caps[foot])-np.array([0., radius, 0.])
        return points


def advance(model, delta):
    rebased = T.advance(model, delta)
    result = RearCapModel(rebased.packet, rebased.d, rebased.joints)
    assert np.max(np.abs(result.contact_points(np.zeros(14))-model.contact_points(delta))) < 1e-12
    assert np.max(np.abs(result.features_y(np.zeros(14))-model.features_y(delta))) < 1e-12
    return result


def rear_centers(model, delta):
    poses = model.poses(delta)
    return np.array([model.point(poses, foot+'_distal', model.local_caps[foot]) for foot in REAR])


def deficits(model, delta, heading):
    centers = rear_centers(model, delta); com = model.com(model.poses(delta))
    return np.maximum(0., (centers-com)@heading+MARGIN)


def cost(model, delta, heading):return float(deficits(model, delta, heading)@deficits(model, delta, heading))


def expand(x):
    delta = np.zeros(14); delta[MOVING] = x*S.MAXIMUM[MOVING]
    return delta


def check(model, delta, reference, heading, before_cost, fraction, caps, solver):
    zero = np.zeros(14); original_points = np.array(reference['original_contact_markers_m'])
    original_floor = np.array(reference['shape_bottom_witnesses_m']); points = model.contact_points(delta)
    lo, hi = S.bounds(model.joints)
    guards = dict(fixed_coordinates=float(np.max(np.abs(delta[:10]))),
        bounds=max(float(np.max(fraction*lo-delta)), float(np.max(delta-fraction*hi))),
        supporting_anchors=float(np.max(np.abs(points[[0, 1, 3]]-original_points[[0, 1, 3]]))),
        rear_cap_height=float(np.max(np.abs(points[[5, 6], 1]-original_points[[5, 6], 1]))),
        original_floor=float(np.max(np.minimum(0., original_floor)-model.features_y(delta))),
        local_floor=float(np.max(np.minimum(0., model.features_y(zero))-model.features_y(delta))),
        contact_site_descent=float(np.max(original_points[:, 1]-points[:, 1])),
        original_headroom=float(np.max(np.abs(model.joints+delta[6:])-np.maximum(S.LIMITS-.02, np.abs(reference['joints_rad'])))))
    value = cost(model, delta, heading)
    node = dict(fraction=fraction, delta=delta.tolist(), guards=guards, placement_cost_m2=value,
        rear_forward_deficits_m=deficits(model, delta, heading).tolist(), foot_hull_gap_m=model.gap(delta),
        optimizer=dict(success=bool(solver.success), status=int(solver.status), message=solver.message,
            iterations=int(solver.nit), objective=float(solver.fun)), admitted=False, refusal=None)
    if not solver.success:node['refusal'] = 'placement_optimizer_unsuccessful'; return node
    if not B.geometry_allowed(guards):node['refusal'] = 'placement_geometry_guard'; return node
    if before_cost-value <= 1e-12*fraction:node['refusal'] = 'no_finite_rear_placement_progress'; return node
    node['load'] = Z.load(model, delta, SUPPORT, caps)
    if not node['load']['feasible']:node['refusal'] = 'support_force_balance_refusal'; return node
    # Only fixed torso/front markers carry force. Rear sites are unloaded and
    # their modeled normal and tangential forces are explicitly zero.
    forces = np.array(node['load']['forces_world_n'])
    assert np.max(np.abs(forces[[2, 4, 5, 6]])) <= 1e-6
    work = float(np.sum(forces*(points-model.contact_points(zero))))
    node['modeled_contact_displacement_work_j'] = work
    if abs(work) > 1e-9:node['refusal'] = 'fixed_support_work_guard'; return node
    node['admitted'] = True
    return node


def step(model, caps, reference, heading):
    zero = np.zeros(14); before_cost = cost(model, zero, heading); original_y = np.array(reference['original_contact_markers_m'])[[5, 6], 1]
    lo, hi = S.bounds(model.joints); floor = np.maximum(np.minimum(0., np.array(reference['shape_bottom_witnesses_m'])), np.minimum(0., model.features_y(zero)))
    nodes = []
    for fraction in B.FRACTIONS:
        objective = lambda x:cost(model, expand(x), heading)/.01
        equality = lambda x:(model.contact_points(expand(x))[[5, 6], 1]-original_y)/B.LENGTH_SCALE
        inequality = lambda x:(model.features_y(expand(x))-floor)/B.LENGTH_SCALE
        solver = minimize(objective, np.zeros(4), jac=lambda x:S.derivative(objective, x), method='SLSQP',
            bounds=list(zip(fraction*lo[MOVING]/S.MAXIMUM[MOVING], fraction*hi[MOVING]/S.MAXIMUM[MOVING])),
            constraints=[dict(type='eq', fun=equality, jac=lambda x:S.derivative(equality, x)),
                dict(type='ineq', fun=inequality, jac=lambda x:S.derivative(inequality, x))], options=B.OPTIONS)
        node = check(model, expand(solver.x), reference, heading, before_cost, fraction, caps, solver); nodes.append(node)
        if not node['admitted']:break
    admitted = len(nodes) == len(B.FRACTIONS) and all(n['admitted'] for n in nodes)
    return dict(initial_cost_m2=before_cost, nodes=nodes, admitted=admitted, refusal=None if admitted else nodes[-1]['refusal'])


def controls():
    checked = F.controls()
    # Sphere-bottom height is independent of material orientation. A rotating
    # material marker is not the same object as a rolling sphere support site.
    radius = .04; center = np.array([.2, .1, -.1]); rotation = S.rotation(np.array([0., 0., .2]))
    bottom = center-np.array([0., radius, 0.]); material = center+rotation@np.array([0., -radius, 0.])
    assert abs(bottom[1]-(.1-radius)) < 1e-14 and material[1] > bottom[1]
    delta = expand(np.array([1., -1., .5, -.5]))
    assert np.all(delta[:10] == 0.) and np.max(np.abs(delta[MOVING])) <= 4*G.DT
    assert abs(float(np.maximum(0., np.array([.1, -.1])+.02)@np.maximum(0., np.array([.1, -.1])+.02))-.0144) < 1e-14
    checked['additional_rolling_site_reduced_coordinate_and_placement_sign_controls'] = 3
    return checked


def declare():
    prior = C.read(F.STUDY)
    record = dict(schema_version='sporespore_r10bg_supported_rear_placement_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_fixed_body_front_supported_rear_cap_placement', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Can rear feet be repositioned behind the COM while torso and front-left foot support the fixed body, using declared rolling cap sites and unchanged floor/force/joint limits?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [F.__file__, F.STUDY, F.RESULT, U.__file__, U.STUDY, U.RESULT]],
        population=dict(report=prior['population']['report'], source_pose_count=1, held_out=False,
            selection='Original R10AP partial step1 / semantic step513 and admitted counterfactual descendants only.',
            coverage='At most600 rear-placement model increments with four fractional nodes each. Complete placement is required; no native timing equivalence.'),
        model=dict(support_modes=SUPPORT, moving_coordinates=MOVING.tolist(), fixed_coordinates='Torso6 and all four front-leg coordinates stay exactly zero per increment.',
            contact_sites='Rear foot sites are the current modeled distal spherical cap center minus authored radius in world up. Other original source markers remain material points. Record initial change from native samples. Sites are counterfactual, not authenticated new observations or native rolling calibration.',
            placement='Minimize squared positive deficits of each rear cap center relative to COM along original heading, with20 mm rearward model placement margin. Keep rear cap-bottom heights at their initial modeled values. Original collision-shape floor minima and initial headroom persist globally; moving caps do not obtain force.',
            numerics='Four scaled rear-joint variables; SLSQP maxiter200 ftol1e-12; central normalized derivatives1e-6. Each fraction starts from zero; retain failure, no retries or changed bounds.',
            admission='All four nodes need solver success, original and local shape-floor/anchor/height/joint guards<=1e-9, placement cost decrease>1e-12*fraction m2, independently certified supporting force balance under original caps and mu1.8 inner diamond, and absolute contact displacement work<=1e-9 J.',
            stopping='Stop at first refusal,600-step limit, or both rear-forward deficits<=1e-6 m. Final feet-only stationary feasibility is independently evaluated even if placement stops early; it is not standing/raising/recovery.',
            limitations='Fixed-body strategy, sampled geometry, original penetration and callback drift remain restrictions. Rear cap sites model new surface points without native impact/rolling validation. No continuous collision, dynamic force allocation or controller transport proof.'),
        numerics=prior['numerics'], checks=['95 inherited controls plus3 sphere-site, reduced-coordinate and placement-sign controls; inherited coverage is shared.',
            'Original native contact replay followed by explicit counterfactual site conversion.', 'Independent source-bound floor/force/cap/headroom checks for all sampled poses and exact rebases.', 'Full deterministic fresh-process replay.'],
        research_sources=prior['research_sources'], claim_boundary=prior['claim_boundary'])
    C.write_new(STUDY, record)


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    native_model = S.Model(packet, descriptor, entry['joint_positions_rad']); modeled_packet = copy.deepcopy(packet)
    modeled_packet['counterfactual_model_only'] = True
    model = RearCapModel(modeled_packet, descriptor, entry['joint_positions_rad'])
    zero = np.zeros(14); conversion = (model.contact_points(zero)-native_model.contact_points(zero)).tolist()
    caps = [v/G.DT for v in entry['caps']]; reference = T.snapshot(model)
    heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    baseline = Z.load(model, zero, SUPPORT, caps); trajectory = []; accepted = 0
    stop = 'finite_model_horizon' if baseline['feasible'] else 'initial_support_force_balance_refusal'
    if baseline['feasible']:
        for index in range(MAX_STEPS):
            row = step(model, caps, reference, heading); row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
            if not row['admitted']:stop = row['refusal']; break
            accepted += 1; model = advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
            if np.max(deficits(model, zero, heading)) <= 1e-6:stop = 'rear_cap_placement_model_target'; break
            print(f'R10BG step {accepted}: rear deficits {deficits(model, zero, heading).tolist()}', file=sys.stderr, flush=True)
    final = T.snapshot(model); feet_only = Z.load(model, zero, [1 if p['classified_as_foot'] else 0 for p in model.contacts], caps)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        initial_rear_forward_deficits_m=deficits(native_model, zero, heading).tolist(), final_rear_forward_deficits_m=deficits(model, zero, heading).tolist(),
        initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        final_feet_only_stationary_feasible=feet_only['feasible'], placement_target_reached=stop == 'rear_cap_placement_model_target')
    return dict(schema_version='sporespore_r10bg_supported_rear_placement_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        rear_site_conversion_world_m=conversion, initial=reference, initial_support_load=baseline, final=final,
        final_feet_only_load=feet_only, summary=summary, trajectory=trajectory, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); args = parser.parse_args()
    if args.declare:declare(); print('R10BG prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
