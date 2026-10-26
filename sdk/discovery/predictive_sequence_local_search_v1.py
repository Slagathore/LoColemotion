"""Bounded refinement of an exposed rejected sequence; no transfer authority."""
import copy
import numpy as np
from actuation_recovery_mechanics import array,require
from predictive_command_selection_v2 import validate
from predictive_sequence_v1 import evaluate,rank,KNOTS
from predictive_sequence_online_v2 import HORIZON

SCALES=(.4,.2,.1,.05)
SAMPLES=14
CANDIDATES=1+2*KNOTS*8+SAMPLES
SEED=2026102601


def options(value,center,iteration):
    validate(value);points=array(center,(KNOTS,8),"Local bounded control points")
    require(np.all(np.abs(points)<=3.5),"Local control point domain")
    require(type(iteration) is int and 0<=iteration<len(SCALES),"Local round domain")
    scale=SCALES[iteration];rows=[("incumbent",points.copy())]
    # Individual control points can change the shape of a joint trajectory.
    # Clipping and the inherited sequential public projection remain distinct.
    for knot in range(KNOTS):
        for joint in range(8):
            for sign in (-1,1):
                changed=points.copy();changed[knot,joint]+=sign*scale
                rows.append((f"knot_{knot}_joint_{joint}_{sign}",changed))
    rng=np.random.default_rng(SEED+10000*value["command"]+iteration)
    rows.extend((f"sample_{i}",points+rng.normal(0.,scale,points.shape)) for i in range(SAMPLES))
    require(len(rows)==CANDIDATES,"Local complete candidate population")
    return [dict(index=i,name=name,knots=np.clip(p,-3.5,3.5).tolist()) for i,(name,p) in enumerate(rows)]


def search(selector,value,seed,retain):
    validate(value);center=array(seed,(KNOTS,8),"Local initial control points").tolist()
    require(np.all(np.abs(center)<=3.5),"Local initial domain")
    before=copy.deepcopy((value,seed));rounds=[];winner=None;prior=None
    for iteration,scale in enumerate(SCALES):
        best=None;eligible=0
        for option in options(value,center,iteration):
            result=evaluate(selector,value,option["knots"],HORIZON)
            record=dict(iteration=iteration,option=option,result=result)
            retain(record);eligible+=int(result["eligible"])
            if best is None or rank(result)<rank(best["result"]):best=record
        current=rank(best["result"])
        require(prior is None or current<=prior,"Local incumbent may not regress")
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current
        rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,eligible_candidates=eligible,
            winner_index=best["option"]["index"],rank=list(current)))
    require((value,seed)==before,"Local immutable causal inputs")
    return dict(rounds=rounds,best=winner,evaluated_candidates=len(SCALES)*CANDIDATES,
        horizon=HORIZON,accepted=winner["result"]["eligible"],finite_search_only=True,
        global_infeasibility_established=False,changed_horizon=False,changed_guard=False,
        trained=False,actual_native_transfer_verified=False,recovery_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,training_data_authority=False,
        physical_acceptance_authority=False,release_authority=False)
