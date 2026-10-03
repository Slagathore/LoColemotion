"""One declared progressive-headroom law on exposed R10AM observations only."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

import r10an_support_transfer_study as prior

C, M, G = prior.C, prior.M, prior.G
STUDY = C.ROOT/'sdk/recovery/r10ao_progressive_headroom_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10ao_progressive_headroom_result_v1.json'
LIMITS = prior.tracking.LIMITS
HEADROOM = .02
EPS = 1e-12


def deficits(joints):
    return [max(0., HEADROOM-limit+abs(q)) for q, limit in zip(joints, LIMITS, strict=True)]


def less(a, b):
    for x, y in zip(a, b, strict=True):
        if x < y-EPS:
            return True
        if x > y+EPS:
            return False
    return False


def allowed(before, after):
    nonworsening = all(a <= b+EPS for a, b in zip(after, before, strict=True))
    progress = sum(after) < sum(before)-EPS if any(before) else True
    return nonworsening, progress


def candidates(m):
    for scale in M.SCALES:
        distance = .1*G.DT*scale
        for dx in (-distance, 0., distance):
            for dy in (-distance, 0., distance):
                for blend in (0., .6*G.DT*scale):
                    translation = [dx*math.cos(m.yaw), dy, -dx*math.sin(m.yaw)]
                    position = M.G.add(m.p, translation)
                    rotation = M.G.blend(m.q, m.flat, blend)
                    if G.rotate(rotation, [0., 1., 0.])[1] < G.rotate(m.q, [0., 1., 0.])[1]-EPS:
                        yield None
                        continue
                    targets = []
                    for i, bearing in enumerate(m.bearing):
                        target = M.anchor(m, i, position, rotation) if bearing else M.placement(m, i, position, rotation, distance)
                        if target is None:
                            break
                        targets.extend(target)
                    if len(targets) != 8:
                        yield None
                        continue
                    endpoints = [M.world_foot(m, i, targets[2*i:2*i+2], position, rotation) for i in range(4)]
                    yield dict(scale=scale, translation=translation, blend=blend, targets=targets,
                        cost=prior.cost(m, position, rotation, endpoints, True))


def verify(m, plan, before, initial_cost):
    targets = plan['targets']
    assert all(abs(q) <= limit and abs(q-source) <= 4*G.DT+EPS
        for q, source, limit in zip(targets, m.measured, LIMITS, strict=True))
    after = deficits(targets)
    assert all(allowed(before, after))
    assert less((max(after), sum(after), plan['cost']), (max(before), sum(before), initial_cost))
    position = M.G.add(m.p, plan['translation'])
    rotation = M.G.blend(m.q, m.flat, plan['blend'])
    # Independently reconstruct endpoints using the retained tracking FK.
    local_before, local_after = G.fk(m.d, m.measured), G.fk(m.d, targets)
    endpoints = [M.G.add(position, G.rotate(rotation, point)) for point in local_after]
    errors = []
    free_dy = []
    for i, bearing in enumerate(m.bearing):
        if bearing:
            error = math.dist(endpoints[i], m.feet[i])
            assert error <= M.LATERAL+EPS
            errors.append(error)
        else:
            assert endpoints[i][1] <= m.feet[i][1]+EPS
            assert math.dist(local_before[i], local_after[i]) <= .1*G.DT+EPS
            free_dy.append(endpoints[i][1]-m.feet[i][1])
    assert G.rotate(rotation, [0., 1., 0.])[1] >= G.rotate(m.q, [0., 1., 0.])[1]-EPS
    assert math.isclose(prior.cost(m, position, rotation, endpoints, True), plan['cost'], abs_tol=EPS)
    return dict(maximum_anchor_error_m=max(errors, default=0.), unsupported_world_dy_m=free_dy,
        deficits_before_rad=before, deficits_after_rad=after,
        maximum_deficit_reduction_rad=max(before)-max(after), total_deficit_reduction_rad=sum(before)-sum(after),
        minimum_target_margin_rad=min(limit-abs(q) for q, limit in zip(targets, LIMITS)),
        geometry_cost_change=plan['cost']-initial_cost)


def search(m):
    before = deficits(m.measured)
    if m.floor is None:
        return dict(candidates=0, geometric=0, nonworsening=0, progress=0, selected=None,
            refusal='no_positive_bearing_plane', deficits_before_rad=before)
    initial_cost = prior.cost(m, m.p, m.q, m.feet, True)
    best = (max(before), sum(before), initial_cost)
    counts = dict(candidates=0, geometric=0, nonworsening=0, progress=0)
    selected = None
    for plan in candidates(m):
        counts['candidates'] += 1
        if plan is None:
            continue
        counts['geometric'] += 1
        after = deficits(plan['targets'])
        nonworsening, progress = allowed(before, after)
        if not nonworsening:
            continue
        counts['nonworsening'] += 1
        if not progress:
            continue
        counts['progress'] += 1
        rank = (max(after), sum(after), plan['cost'])
        if less(rank, best):
            best, selected = rank, plan
    assert counts['candidates'] == 90
    reason = None
    if selected is not None:
        selected['verification'] = verify(m, selected, before, initial_cost)
        selected['mode'] = 'recover_joint_headroom' if any(before) else 'raise_with_headroom'
    else:
        reason = ('no_geometric_candidate' if not counts['geometric'] else
            'no_nonworsening_headroom_candidate' if not counts['nonworsening'] else
            'no_headroom_progress_candidate' if not counts['progress'] else 'no_improving_candidate')
    return dict(**counts, selected=selected, refusal=reason, deficits_before_rad=before, initial_cost=initial_cost)


def controls():
    checks = [deficits([0.]*8) == [0.]*8,
        max(abs(a-.02) for a in deficits(LIMITS)) < EPS,
        max(deficits([v-.02 for v in LIMITS])) < EPS,
        max(abs(a-.03) for a in deficits([v+.01 for v in LIMITS])) < EPS,
        less((.01, 1., 100.), (.02, 0., 0.)),
        not less((.02, 0., 0.), (.01, 1., 100.)),
        less((0., 0., 1.), (0., 0., 2.)),
        not less((0., 0., 2.), (0., 0., 2.)),
        allowed([.02, .01], [.019, .01]) == (True, True),
        allowed([.02, .01], [.01, .011]) == (False, True),
        allowed([.02, .01], [.02, .01]) == (True, False),
        allowed([0., 0.], [0., 0.]) == (True, True)]
    assert all(checks)
    return dict(deficit_and_lexicographic_controls=len(checks))


def derive():
    study = C.read(STUDY)
    assert study['algorithm']['headroom_rad'] == HEADROOM
    for binding in [*study['dependencies'], study['population']['report']]:
        assert C.bind(binding['path']) == binding
    checked = controls()
    source = C.CHILD/'worker_report.json'
    descriptor = C.streams.small_fields(source)['configuration']['base_descriptor']
    rows = []
    for packet in G.records(source, 'r10am_partial_recovery', 'step_packets'):
        native = packet['native_receipt']
        if native['next_load_plan'] is None:
            continue
        m = M.G.Model(native['collection']['observation'], descriptor)
        result = search(m)
        rows.append(dict(semantic_step=native['collection']['observation']['semantic_step'],
            input_joints=m.measured, positive_bearing=m.bearing, **result))
    assert len(rows) == study['population']['command_samples'] == 600
    selected = [r['selected'] for r in rows if r['selected']]
    summary = dict(selected=len(selected), refusals=dict(Counter(r['refusal'] for r in rows if r['refusal'])),
        modes=dict(Counter(p['mode'] for p in selected)),
        upward_proposals=sum(p['translation'][1] > 0 for p in selected),
        zero_vertical_proposals=sum(p['translation'][1] == 0 for p in selected),
        downward_proposals=sum(p['translation'][1] < 0 for p in selected),
        geometry_cost_increases=sum(p['verification']['geometry_cost_change'] > EPS for p in selected),
        maximum_anchor_error_m=max((p['verification']['maximum_anchor_error_m'] for p in selected), default=None),
        total_deficit_reduction_rad=G.stats([p['verification']['total_deficit_reduction_rad'] for p in selected]),
        target_margin_rad=G.stats([p['verification']['minimum_target_margin_rad'] for p in selected]),
        counts={k: sum(r[k] for r in rows) for k in ('candidates', 'geometric', 'nonworsening', 'progress')})
    return dict(schema_version='sporespore_r10ao_progressive_headroom_result_v1', ledger_scope=study['ledger_scope'],
        study=C.bind(STUDY), implementation=C.bind(Path(__file__)), source_report=study['population']['report'],
        controls=checked, summary=summary, rows=rows, **study['claim_boundary'])


def audit():
    record = C.read(RESULT)
    assert record == derive()
    return dict(ok=True, controls=record['controls'], summary=record['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    if args.create:
        C.write_new(RESULT, derive())
    print(json.dumps(audit(), indent=2))
