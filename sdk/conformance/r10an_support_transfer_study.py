"""Finite retained-input contact-envelope and support-transfer geometry study.

This does not run a world, choose a physical controller, or predict body forces.
Every counterfactual is a one-step geometric proposal on already exposed data.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

import r10am_support_tracking_diagnosis as tracking
import r10af_contact_frame_replay as contact_replay

C = tracking.closed
M = tracking.model
G = tracking.G
STUDY = C.ROOT/'sdk/recovery/r10an_support_transfer_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10an_support_transfer_result_v1.json'
VARIANTS = [('original', False, 0.), ('raise_partial', True, 0.),
    ('interior_only', False, .02), ('raise_partial_interior', True, .02)]


def cross(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def hull(points):
    """Monotone-chain horizontal hull, including degenerate populations."""
    points = sorted(set(tuple(p) for p in points))
    if len(points) < 2:
        return points
    def half(sequence):
        result = []
        for p in sequence:
            while len(result) >= 2 and cross(result[-2], result[-1], p) <= 0:
                result.pop()
            result.append(p)
        return result
    return half(points)[:-1]+half(reversed(points))[:-1]


def envelope(com, points):
    polygon = hull([[p[0], p[2]] for p in points])
    p = [com[0], com[2]]
    if not polygon:
        return dict(vertices=[], distance_m=None, inside=False)
    if len(polygon) == 1:
        distance = math.dist(p, polygon[0])
    elif len(polygon) > 2 and all(cross(a, b, p) >= 0 for a, b in
            zip(polygon, polygon[1:]+polygon[:1])):
        distance = 0.
    else:
        distances = []
        for a, b in zip(polygon, polygon[1:]+polygon[:1]):
            delta = [b[i]-a[i] for i in range(2)]
            length2 = sum(v*v for v in delta)
            t = max(0., min(1., sum((p[i]-a[i])*delta[i] for i in range(2))/length2))
            distances.append(math.dist(p, [a[i]+t*delta[i] for i in range(2)]))
        distance = min(distances)
    return dict(vertices=[list(v) for v in polygon], distance_m=distance, inside=distance <= 1e-12)


def cost(m, position, rotation, endpoints, raise_partial):
    value = M.cost(m, position, rotation, endpoints)
    if raise_partial and not all(m.bearing):
        value += (position[1]-m.goal_y)**2-(position[1]-m.p[1])**2
    return value


def search(m, raise_partial, margin):
    if m.floor is None:
        return dict(candidates=0, geometric_feasible=0, margin_feasible=0,
            selected=None, refusal='no_positive_bearing_plane')
    initial = best = cost(m, m.p, m.q, m.feet, raise_partial)
    count = geometric = interior = 0
    selected = None
    for scale in M.SCALES:
        distance = .1*G.DT*scale
        for dx in (-distance, 0., distance):
            for dy in (-distance, 0., distance):
                for blend in (0., .6*G.DT*scale):
                    count += 1
                    translation = [dx*math.cos(m.yaw), dy, -dx*math.sin(m.yaw)]
                    position = M.G.add(m.p, translation)
                    rotation = M.G.blend(m.q, m.flat, blend)
                    if G.rotate(rotation, [0., 1., 0.])[1] < G.rotate(m.q, [0., 1., 0.])[1]-1e-12:
                        continue
                    targets = []
                    for i, bearing in enumerate(m.bearing):
                        target = M.anchor(m, i, position, rotation) if bearing else M.placement(m, i, position, rotation, distance)
                        if target is None:
                            break
                        targets.extend(target)
                    if len(targets) != 8:
                        continue
                    geometric += 1
                    if any(abs(q) > limit-margin for q, limit in zip(targets, tracking.LIMITS)):
                        continue
                    interior += 1
                    endpoints = [M.world_foot(m, i, targets[2*i:2*i+2], position, rotation) for i in range(4)]
                    value = cost(m, position, rotation, endpoints, raise_partial)
                    if value < best-1e-12:
                        best = value
                        selected = dict(scale=scale, translation=translation, blend=blend, targets=targets, cost=value)
    reason = None if selected else ('no_margin_feasible_candidate' if geometric and not interior
        else 'no_geometric_candidate' if not geometric else 'no_improving_candidate')
    return dict(candidates=count, geometric_feasible=geometric, margin_feasible=interior,
        initial_cost=initial, selected=selected, refusal=reason)


def verify(m, result, raise_partial, margin):
    plan = result['selected']
    if plan is None:
        return None
    position = M.G.add(m.p, plan['translation'])
    rotation = M.G.blend(m.q, m.flat, plan['blend'])
    targets = plan['targets']
    assert all(abs(v) <= limit-margin and abs(v-q) <= 4*G.DT+1e-12
        for v, q, limit in zip(targets, m.measured, tracking.LIMITS))
    # Independent FK path, separate from candidate construction.
    endpoints = [M.G.add(position, G.rotate(rotation, foot)) for foot in G.fk(m.d, targets)]
    anchor_error = []
    free_dy = []
    for i, bearing in enumerate(m.bearing):
        if bearing:
            error = math.dist(endpoints[i], m.feet[i])
            assert error <= M.LATERAL+1e-12
            anchor_error.append(error)
        else:
            assert endpoints[i][1] <= m.feet[i][1]+1e-12
            assert math.dist(G.fk(m.d, targets)[i], G.fk(m.d, m.measured)[i]) <= .1*G.DT+1e-12
            free_dy.append(endpoints[i][1]-m.feet[i][1])
    assert G.rotate(rotation, [0., 1., 0.])[1] >= G.rotate(m.q, [0., 1., 0.])[1]-1e-12
    value = cost(m, position, rotation, endpoints, raise_partial)
    assert math.isclose(value, plan['cost'], abs_tol=1e-12)
    assert value < result['initial_cost']-1e-12
    return dict(maximum_anchor_error_m=max(anchor_error, default=0.),
        unsupported_world_dy_m=free_dy, minimum_joint_margin_rad=min(limit-abs(q)
            for q, limit in zip(targets, tracking.LIMITS)))


def controls():
    cases = [([0., 0., 0.], [], None), ([0., 0., 0.], [[3., 0., 4.]], 5.),
        ([1., 0., 1.], [[0., 0., 0.], [2., 0., 0.]], 1.),
        ([1., 0., 0.], [[0., 0., 0.], [2., 0., 0.]], 0.),
        ([1., 0., 1.], [[0., 0., 0.], [2., 0., 0.], [0., 0., 2.]], 0.),
        ([2., 0., 2.], [[0., 0., 0.], [2., 0., 0.], [0., 0., 2.]], math.sqrt(2.)),
        ([1., 0., 1.], [[0., 0., 0.], [1., 0., 0.], [2., 0., 0.], [1., 0., 0.]], 1.)]
    for com, points, expected in cases:
        value = envelope(com, points)['distance_m']
        assert value is None if expected is None else math.isclose(value, expected, abs_tol=1e-12)
        moved = envelope([com[0]+10., com[1], com[2]-7.],
            [[p[0]+10., p[1], p[2]-7.] for p in reversed(points)])['distance_m']
        assert moved is None if expected is None else math.isclose(moved, expected, abs_tol=1e-12)
    return dict(hull_known_answer_and_translation_controls=14)


def derive():
    study = C.read(STUDY)
    for binding in [*study['dependencies'], study['population']['report']]:
        assert C.bind(binding['path']) == binding
    assert study['model_variants'] == [dict(name=n, height_goal=h, interior_margin_rad=m) for n, h, m in VARIANTS]
    failed = C.EVIDENCE/'r10an-support-transfer-5a16183ea2524acdb7c76a675edc3892'
    prior = C.read(failed/'invocation.json')
    assert C.read(failed/'execution.json')['exit_code'] == 1
    assert C.bind(failed/'original_study_source.py')['raw_sha256'] == prior['bindings'][0]['raw_sha256']
    assert (failed/'original_study_declaration.json').read_bytes() == STUDY.read_bytes()
    checked = controls()
    descriptor, samples, parity = tracking.rows()
    indexed = {r['semantic_step']: r for r in samples}
    source = C.CHILD/'worker_report.json'
    contact_rows = []
    replay_count = 0
    for record in G.records(source, 'r10af_contact_frames', 'records'):
        packet = record['packet']
        row = indexed.get(packet['semantic_step'])
        if row is None:
            continue
        replayed = contact_replay.replay(packet, packet['semantic_step'], packet['model_instance_id'], packet['body_population_instance_sha256'])
        assert replayed['ok']
        replay_count += replayed['matched_source_contacts']
        points = packet['contact_source_receipt']['ordered_contact_samples']
        positive = [p for p in points if p['normal_impulse_ns'] > 0]
        total = sum(p['normal_impulse_ns'] for p in positive)
        nonfoot = sum(p['normal_impulse_ns'] for p in positive if not p['classified_as_foot'])
        by_body = Counter()
        for p in positive:
            by_body[p['body_id']] += p['normal_impulse_ns']
        cap = row['measured_cap_centers']
        sets = dict(all_cap_centers=cap,
            positive_cap_centers=[p for p, bearing in zip(cap, row['positive_bearing']) if bearing],
            qualified_cap_centers=[p for p, qualified in zip(cap, row['qualified_support']) if qualified],
            actual_foot_contacts=[G.vector(p['position_world_m']) for p in positive if p['classified_as_foot']],
            actual_all_body_contacts=[G.vector(p['position_world_m']) for p in positive])
        contact_rows.append(dict(partial_step=row['partial_step'], semantic_step=row['semantic_step'],
            com_world_m=row['com'], envelopes={name: envelope(row['com'], values) for name, values in sets.items()},
            nonfoot_impulse_fraction=nonfoot/total if total else None,
            total_normal_impulse_ns=total, nonfoot_normal_impulse_ns=nonfoot,
            normal_impulse_ns_by_body=dict(by_body)))
    assert len(contact_rows) == 601
    variants = {name: [] for name, _, _ in VARIANTS}
    for packet in G.records(source, 'r10am_partial_recovery', 'step_packets'):
        native = packet['native_receipt']
        if native['next_load_plan'] is None:
            continue
        m = M.G.Model(native['collection']['observation'], descriptor)
        for name, height, margin in VARIANTS:
            result = search(m, height, margin)
            result['verification'] = verify(m, result, height, margin)
            if name == 'original':
                original = M.search(m)
                assert result['candidates'] == original['candidates']
                assert result['geometric_feasible'] == original['feasible']
                expected = None if original['selected'] is None else {k: v for k, v in original['selected'].items() if k != 'verification'}
                assert result['selected'] == expected
            variants[name].append(result)
    assert all(len(rows) == 600 for rows in variants.values())
    variant_summary = {}
    for name, rows in variants.items():
        chosen = [r['selected'] for r in rows if r['selected'] is not None]
        variant_summary[name] = dict(selected=len(chosen), refusals=dict(Counter(r['refusal'] for r in rows if r['refusal'])),
            upward_proposals=sum(r['translation'][1] > 0 for r in chosen),
            downward_proposals=sum(r['translation'][1] < 0 for r in chosen),
            vertical_proposal_m=G.stats([r['translation'][1] for r in chosen]),
            target_margin_rad=G.stats([r['verification']['minimum_joint_margin_rad'] for r in rows if r['verification']]),
            maximum_anchor_error_m=max((r['verification']['maximum_anchor_error_m'] for r in rows if r['verification']), default=None),
            candidates_before_margin=sum(r['geometric_feasible'] for r in rows),
            candidates_after_margin=sum(r['margin_feasible'] for r in rows))
    envelope_summary = {name: dict(inside_samples=sum(r['envelopes'][name]['inside'] for r in contact_rows),
        empty_samples=sum(r['envelopes'][name]['distance_m'] is None for r in contact_rows),
        distance_m=G.stats([r['envelopes'][name]['distance_m'] for r in contact_rows if r['envelopes'][name]['distance_m'] is not None]))
        for name in contact_rows[0]['envelopes']}
    return dict(schema_version='sporespore_r10an_support_transfer_result_v1', ledger_scope=study['ledger_scope'],
        study=C.bind(STUDY), bindings=[C.bind(p) for p in (Path(__file__), Path(contact_replay.__file__), Path(tracking.__file__))],
        source_report=study['population']['report'], controls=checked,
        retained_prior_harness_failure=[C.bind(p) for p in sorted(failed.iterdir()) if p.is_file()],
        original_native_geometry_parity=parity, independently_replayed_source_contacts=replay_count,
        contact_summary=dict(envelopes=envelope_summary,
            nonfoot_impulse_fraction=G.stats([r['nonfoot_impulse_fraction'] for r in contact_rows if r['nonfoot_impulse_fraction'] is not None])),
        net_measured_torso_translation_m=M.G.sub(samples[-1]['position'], samples[0]['position']),
        sum_original_virtual_proposals_m=[sum(r['selected']['translation'][a] for r in variants['original'] if r['selected']) for a in range(3)],
        variant_summary=variant_summary, contacts=contact_rows, variants=variants,
        limitations=study['model_algorithm']['exclusions'], **study['claim_boundary'])


def audit():
    record = C.read(RESULT)
    assert record == derive()
    return {k: record[k] for k in ('controls', 'contact_summary', 'variant_summary',
        'net_measured_torso_translation_m', 'sum_original_virtual_proposals_m',
        'controller_selected', 'world_build_count', 'solver_step_count', 'physical_acceptance_authority', 'release_authority')}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    if args.create:
        C.write_new(RESULT, derive())
    print(json.dumps(dict(ok=True, **audit()), indent=2))
