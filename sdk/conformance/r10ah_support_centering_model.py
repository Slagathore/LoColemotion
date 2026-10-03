"""Prospective bounded centering-before-rise geometry, never a physics model.

Compare horizontal-only centering with coupled horizontal/vertical centering.
Neither moves a native body: a plan contains only mathematical joint targets.
"""
import copy
import math

import r10ab_loaded_rise_diagnosis as geometry
import r10af_rise_model_rollout as rollout


def cross(a, b, p):
    return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])


def hull(points):
    points = sorted(set(tuple(p) for p in points))
    if len(points) < 3:
        raise ValueError('DEGENERATE_SUPPORT_POLYGON')
    lower, upper = [], []
    for source, target in ((points, lower), (reversed(points), upper)):
        for point in source:
            while len(target) >= 2 and cross(target[-2], target[-1], point) <= 0.:
                target.pop()
            target.append(point)
    result = lower[:-1] + upper[:-1]
    if len(result) < 3:
        raise ValueError('DEGENERATE_SUPPORT_POLYGON')
    return result


def margin(feet, com):
    """Minimum signed distance to convex-hull edge lines in world XZ.

    Positive means inside all edges. Outside, this is the worst half-plane
    violation, not Euclidean distance to the polygon. No force prediction.
    """
    polygon = hull([[f[0], f[2]] for f in feet])
    point = [com[0], com[2]]
    return min(cross(a, b, point)/math.dist(a, b)
        for a, b in zip(polygon, polygon[1:] + polygon[:1]))


def center_search(model, coupled):
    assert all(model.qualified)
    initial = margin(model.feet, model.com)
    best, best_rank, feasible, count = None, None, 0, 0
    for scale in geometry.SCALES:
        distance = .1*geometry.DT*scale
        for dx in (-distance, distance):
            for dy in ((-distance, 0., distance) if coupled else (0.,)):
                count += 1
                translation = [dx*math.cos(model.yaw), dy, -dx*math.sin(model.yaw)]
                position = geometry.add(model.p, translation)
                solution = model.solve(model.feet, position, model.q)
                if solution is None:
                    continue
                feasible += 1
                joints, residual = solution
                com = geometry.add(position, geometry.rotate(model.q, model.com_local))
                candidate_margin = margin(model.feet, com)
                if candidate_margin <= initial + 1e-12:
                    continue
                # Improve horizontal support margin first; prefer no vertical
                # movement, then the original geometry cost on an exact tie.
                cost = model.cost(position, model.q, model.feet)
                rank = (-candidate_margin, abs(dy), cost)
                if best_rank is None or rank < best_rank:
                    best_rank = rank
                    best = dict(scale=scale, translation=translation, blend=0., targets=joints,
                        cost=cost, lateral_residual=residual, support_margin_m=candidate_margin)
    return dict(selected=best, candidates=count, feasible=feasible, initial_support_margin_m=initial)


def select(model, coupled=True):
    current = margin(model.feet, model.com)
    # One authored foot radius is a model design margin, not a task threshold.
    desired = .04*model.d['foot_radius_scale']
    if current < desired:
        return dict(mode='center_body', **center_search(model, coupled))
    search = model.search()
    eligible = []
    for candidate in search['candidates']:
        position = geometry.add(model.p, candidate['translation'])
        q = geometry.blend(model.q, model.flat, candidate['blend'])
        com = geometry.add(position, geometry.rotate(q, model.com_local))
        if margin(model.feet, com) >= desired:
            eligible.append(candidate)
    return dict(mode='raise_body', selected=min(eligible, key=lambda c:c['cost']) if eligible else None,
        candidates=135, feasible=search['feasible'], initial_support_margin_m=current)


def propagate(model, coupled, bound=600):
    # Deep-copy only mathematical state; never reinterpret a predicted state as
    # an observation, native contact, controller receipt, or physical result.
    model = copy.deepcopy(model); model.o = None
    history, mode_counts = [], dict(center_body=0, raise_body=0)
    initial_feet = copy.deepcopy(model.feet)
    first_centered = None
    for update in range(bound):
        result = select(model, coupled)
        if update % 60 == 0:
            history.append(dict(update=update, mode=result['mode'],
                support_margin_m=result['initial_support_margin_m'], **rollout.snapshot(model, update)))
        if result['mode'] == 'raise_body' and first_centered is None:
            first_centered = update
        if result['selected'] is None:
            stop = 'no_admissible_plan'
            break
        model = rollout.advance(model, result['selected'])
        mode_counts[result['mode']] += 1
    else:
        stop = 'declared_600_update_bound'
    return dict(stop=stop, updates=sum(mode_counts.values()), mode_counts=mode_counts,
        first_centered_update=first_centered, final=rollout.snapshot(model,sum(mode_counts.values())),
        final_support_margin_m=margin(model.feet,model.com), snapshots=history,
        maximum_modeled_anchor_drift_m=max(math.dist(a,b) for a,b in zip(initial_feet,model.feet)),
        assumptions='Exact joint and torso tracking, all four contacts qualified, fixed torso-local COM. Rigid ideal forward kinematics; no dynamics, friction, contact force or native gate prediction.',
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
