"""Bounded conditional command-sequence search over the verified predictor.

Only the initial observation enters a candidate rollout. Future deterministic
baseline velocities are held at their current values, an explicit approximation.
Only a future public integration could authorize applying the first command.
"""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import array,require,command_envelope,resolve_correction
from predictive_command_selection_v2 import validate,guard

KNOTS=4
CANDIDATES=34
ITERATIONS=3
SEED=20261026
SIGMA=.8
MAX_INTERVALS=66


def commands(value,knots,intervals):
    validate(value)
    require(type(intervals) is int and 1<=intervals<=MAX_INTERVALS,"Sequence bounded horizon")
    parameters=array(knots,(KNOTS,8),"Sequence correction control points")
    require(np.all(np.abs(parameters)<=3.5),"Sequence absolute parameter bounds")
    previous=np.array(value["previous_correction"]);corrections=[];targets=[]
    for i in range(intervals):
        # Linear interpolation stays within the knot bounds; sequential
        # projection separately enforces the inherited correction slew cap.
        position=0. if intervals==1 else i*(KNOTS-1)/(intervals-1)
        lo=min(int(position),KNOTS-2);alpha=position-lo
        proposed=(1.-alpha)*parameters[lo]+alpha*parameters[lo+1]
        envelope=command_envelope(value["baseline"],value["speeds"],previous,[3.5]*8,[.08]*8)
        correction,target=resolve_correction(envelope,proposed)
        corrections.append(correction.tolist());targets.append(target.tolist());previous=correction
    return corrections,targets


def parameters(value,incumbent,iteration):
    validate(value);center=array(incumbent,(KNOTS,8),"Sequence incumbent")
    require(type(iteration) is int and 0<=iteration<ITERATIONS,"Sequence iteration domain")
    require(np.all(np.abs(center)<=3.5),"Sequence bounded incumbent")
    options=[("incumbent",center.copy()),("zero_correction",np.zeros_like(center)),
        ("zero_target",np.tile(-np.array(value["baseline"]),(KNOTS,1))),
        ("velocity_brake",np.tile(-np.array(value["qvel"][6:])-value["baseline"],(KNOTS,1)))]
    for joint in range(8):
        for label,bound in (("lower",-3.5),("upper",3.5)):
            trial=center.copy();trial[:,joint]=bound;options.append((f"joint_{joint}_{label}",trial))
    rng=np.random.default_rng(SEED+10000*value["command"]+iteration)
    options.extend((f"sample_{i}",center+rng.normal(0.,SIGMA,center.shape)) for i in range(14))
    require(len(options)==CANDIDATES,"Sequence candidate population")
    return [dict(index=i,name=name,knots=np.clip(points,-3.5,3.5).tolist())
        for i,(name,points) in enumerate(options)]


def evaluate(selector,value,knots,intervals):
    corrections,targets=commands(value,knots,intervals)
    q=list(value["qpos"]);v=list(value["qvel"]);rows=[];cost=0.;good=0;completed_steps=0
    for offset,(correction,target) in enumerate(zip(corrections,targets,strict=True)):
        forecast=selector.rollout.predict(dict(qpos=q,qvel=v,target_velocity=target))
        reasons=guard(forecast,selector.limits)
        objective=selector.cost(forecast,value) if forecast["accepted"] else None
        rows.append(dict(offset=offset,correction=correction,target=target,forecast=forecast,
            guard_reasons=reasons,objective=objective))
        completed_steps+=forecast["completed_steps"]
        if objective is not None:cost+=objective["total"]
        if reasons:break
        good+=1;q=forecast["final_qpos"];v=forecast["final_qvel"]
    return dict(eligible=good==intervals,planned_intervals=intervals,valid_intervals=good,
        completed_predicted_steps=completed_steps,attempted_intervals=len(rows),
        mean_objective=cost/len(rows) if all(x["objective"] is not None for x in rows) else None,
        rejection_reasons=rows[-1]["guard_reasons"],rows=rows,
        future_baseline_assumption="current deterministic baseline held constant",
        future_observations_used=False,future_recorded_actions_used=False,
        public_future_envelope_equivalence=False,native_worlds=0,native_physics_steps=0,
        trained=False,physical_acceptance_authority=False,release_authority=False)


def rank(result):
    # Ineligible plans are optimization intermediates only. Longer admissible
    # prefixes guide the search; only an entirely admissible horizon is eligible.
    cost=result["mean_objective"]
    require(cost is None or (type(cost) is float and math.isfinite(cost) and cost>=0),"Sequence finite score")
    return (not result["eligible"],-result["valid_intervals"],1e300 if cost is None else cost)


def search(selector,value,intervals,retain):
    validate(value);incumbent=np.tile(value["nominal_correction"],(KNOTS,1)).tolist()
    rounds=[];best=None;prior_rank=None
    for iteration in range(ITERATIONS):
        winner=None;accepted=0;attempted=completed=0
        for option in parameters(value,incumbent,iteration):
            result=evaluate(selector,value,option["knots"],intervals)
            record=dict(command=value["command"],iteration=iteration,option=option,result=result)
            retain(record)
            attempted+=result["attempted_intervals"];completed+=result["completed_predicted_steps"]
            accepted+=int(result["eligible"])
            if winner is None or rank(result)<rank(winner["result"]):winner=record
        require(prior_rank is None or rank(winner["result"])<=prior_rank,"Sequence incumbent preservation")
        prior_rank=rank(winner["result"]);incumbent=copy.deepcopy(winner["option"]["knots"]);best=winner
        rounds.append(dict(iteration=iteration,evaluated=CANDIDATES,eligible_candidates=accepted,
            best_index=winner["option"]["index"],best_valid_intervals=winner["result"]["valid_intervals"],
            best_eligible=winner["result"]["eligible"],best_mean_objective=winner["result"]["mean_objective"],
            attempted_intervals=attempted,completed_predicted_steps=completed))
    return dict(starting_packet=copy.deepcopy(value),planned_intervals=intervals,rounds=rounds,best=best,
        evaluated_candidates=CANDIDATES*ITERATIONS,finite_search_only=True,global_infeasibility_established=False,
        native_recovery_established=False,trained=False,tier2_qualified=False,tier3_benefit_established=False)

