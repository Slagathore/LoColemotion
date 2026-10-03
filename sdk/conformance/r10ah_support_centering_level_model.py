"""Distinct second AH model probe: add bounded leveling to COM centering.

The first AH translation-only results are immutable. This prospective variant
adds the original three leveling directions to its 30-candidate search (90
candidates), retaining the same margin, IK bounds and selection order.
"""
import copy
import math

import r10ah_support_centering_model as prior

geometry, rollout = prior.geometry, prior.rollout


def center_search(model):
    assert all(model.qualified)
    initial = prior.margin(model.feet, model.com)
    best, best_rank, feasible, count = None, None, 0, 0
    for scale in geometry.SCALES:
        distance = .1*geometry.DT*scale
        for dx in (-distance, distance):
            for dy in (-distance, 0., distance):
                for fraction in (-.6*geometry.DT*scale, 0., .6*geometry.DT*scale):
                    count += 1
                    translation = [dx*math.cos(model.yaw), dy, -dx*math.sin(model.yaw)]
                    position = geometry.add(model.p, translation)
                    rotation = geometry.blend(model.q, model.flat, fraction)
                    solution = model.solve(model.feet, position, rotation)
                    if solution is None:continue
                    feasible += 1
                    joints, residual = solution
                    com = geometry.add(position, geometry.rotate(rotation, model.com_local))
                    candidate_margin = prior.margin(model.feet, com)
                    if candidate_margin <= initial + 1e-12:continue
                    cost = model.cost(position, rotation, model.feet)
                    rank = (-candidate_margin, abs(dy), cost)
                    if best_rank is None or rank < best_rank:
                        best_rank = rank
                        best = dict(scale=scale, translation=translation, blend=fraction, targets=joints,
                            cost=cost, lateral_residual=residual, support_margin_m=candidate_margin)
    return dict(selected=best, candidates=count, feasible=feasible, initial_support_margin_m=initial)


def select(model):
    if prior.margin(model.feet, model.com) < .04*model.d['foot_radius_scale']:
        return dict(mode='center_body', **center_search(model))
    return prior.select(model, True)


def propagate(model, bound=600):
    model=copy.deepcopy(model);model.o=None
    history, counts=[],dict(center_body=0,raise_body=0)
    initial_feet=copy.deepcopy(model.feet);first_centered=None
    for update in range(bound):
        result=select(model)
        if update%60==0:
            history.append(dict(update=update,mode=result['mode'],support_margin_m=result['initial_support_margin_m'],
                **rollout.snapshot(model,update)))
        if result['mode']=='raise_body' and first_centered is None:first_centered=update
        if result['selected'] is None:
            stop='no_admissible_plan';break
        model=rollout.advance(model,result['selected']);counts[result['mode']]+=1
    else:stop='declared_600_update_bound'
    return dict(stop=stop,updates=sum(counts.values()),mode_counts=counts,first_centered_update=first_centered,
        final=rollout.snapshot(model,sum(counts.values())),final_support_margin_m=prior.margin(model.feet,model.com),
        snapshots=history,maximum_modeled_anchor_drift_m=max(math.dist(a,b) for a,b in zip(initial_feet,model.feet)),
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
