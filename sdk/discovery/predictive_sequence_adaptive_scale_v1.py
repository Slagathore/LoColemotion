"""Bounded adaptive exploration scale; unchanged feasibility rank and guards."""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import array,require
from predictive_command_selection_v2 import validate
from predictive_sequence_v1 import evaluate,KNOTS
from predictive_sequence_online_v2 import HORIZON
from predictive_sequence_local_search_v1 import SCALES,CANDIDATES,SEED,SAMPLES
from predictive_sequence_constraint_repair_v1 import rank,violation

STRATEGY="retain_rejected_search_scale_after_feasibility_improvement"


def options(value,center,iteration,scale):
    validate(value);points=array(center,(KNOTS,8),"Adaptive control points")
    require(np.all(np.abs(points)<=3.5),"Adaptive control point domain")
    require(type(iteration) is int and 0<=iteration<4,"Adaptive round domain")
    require(type(scale) is float and math.isfinite(scale) and 0.<scale<=.4,"Adaptive scale domain")
    choices=[("incumbent",points.copy())]
    for knot in range(KNOTS):
        for joint in range(8):
            for sign in (-1,1):
                trial=points.copy();trial[knot,joint]+=sign*scale
                choices.append((f"knot_{knot}_joint_{joint}_{sign}",trial))
    rng=np.random.default_rng(SEED+10000*value["command"]+iteration)
    choices.extend((f"sample_{i}",points+rng.normal(0.,scale,points.shape)) for i in range(SAMPLES))
    require(len(choices)==CANDIDATES,"Adaptive same candidate denominator")
    return [dict(index=i,name=name,knots=np.clip(points,-3.5,3.5).tolist())
        for i,(name,points) in enumerate(choices)]


def next_scale(iteration,scale,incumbent_rank,winner_rank):
    require(type(iteration) is int and 0<=iteration<4,"Adaptive schedule round")
    require(type(scale) is float and math.isfinite(scale) and 0.<scale<=.4,"Adaptive schedule scale")
    require(type(incumbent_rank) is tuple and type(winner_rank) is tuple
        and len(incumbent_rank)==len(winner_rank)==5,"Adaptive schedule rank shape")
    require(winner_rank<=incumbent_rank,"Adaptive incumbent preservation")
    improved=winner_rank[:4]<incumbent_rank[:4]
    if iteration==3:return None,improved
    if not winner_rank[0]:return SCALES[iteration+1],improved
    # Cost-only gains cannot postpone contraction of an unchanged violation.
    return (scale if improved else .5*scale),improved


def search(selector,value,seed,retain):
    validate(value);center=array(seed,(KNOTS,8),"Adaptive initial control points").tolist()
    require(np.all(np.abs(center)<=3.5),"Adaptive initial domain")
    before=copy.deepcopy((value,seed));rounds=[];winner=None;prior=None;scale=SCALES[0]
    for iteration in range(4):
        best=None;eligible=0;incumbent_rank=None
        for option in options(value,center,iteration,scale):
            result=evaluate(selector,value,option["knots"],HORIZON)
            record=dict(iteration=iteration,option=option,result=result,
                constraint_violation=violation(result,selector.limits))
            retain(record);eligible+=int(result["eligible"])
            current=rank(result,selector.limits)
            if option["index"]==0:incumbent_rank=current
            if best is None or current<rank(best["result"],selector.limits):best=record
        current=rank(best["result"],selector.limits)
        require(prior is None or current<=prior,"Adaptive incumbent may not regress")
        following,improved=next_scale(iteration,scale,incumbent_rank,current)
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current
        rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,
            eligible_candidates=eligible,winner_index=best["option"]["index"],rank=list(current),
            incumbent_rank=list(incumbent_rank),feasibility_improved=improved,next_scale=following))
        scale=following
    require((value,seed)==before,"Adaptive immutable causal inputs")
    return dict(strategy=STRATEGY,rounds=rounds,best=winner,evaluated_candidates=4*CANDIDATES,
        horizon=HORIZON,accepted=winner["result"]["eligible"],finite_search_only=True,
        global_infeasibility_established=False,changed_horizon=False,changed_guard=False,
        trained=False,actual_native_transfer_verified=False,recovery_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,training_data_authority=False,
        physical_acceptance_authority=False,release_authority=False)
