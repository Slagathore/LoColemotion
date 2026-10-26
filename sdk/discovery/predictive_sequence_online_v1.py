"""Causal receding-horizon search with bounded, revalidated warm starts."""
import copy
import numpy as np
from actuation_recovery_mechanics import array,require
from predictive_command_selection_v2 import validate
from predictive_sequence_v1 import KNOTS,CANDIDATES,ITERATIONS,evaluate,parameters,rank,commands

HORIZON=66
REPLAN_INTERVAL=12
PLAN_FIELDS={"command","baseline","speeds","correction","targets","request_sha256"}


def validate_plan(plan,value):
    if value["command"]==60:
        require(plan is None,"Sequence handoff has no prior plan")
        return
    require(type(plan) is dict and set(plan)==PLAN_FIELDS
        and type(plan["command"]) is int and plan["command"]==value["command"]-1,
        "Sequence preceding plan clock/domain")
    baseline=array(plan["baseline"],(8,),"Sequence prior baseline")
    speeds=array(plan["speeds"],(8,),"Sequence prior speeds")
    correction=array(plan["correction"],(8,),"Sequence prior correction")
    targets=array(plan["targets"],(HORIZON,8),"Sequence prior targets")
    require(np.all(speeds>0) and np.all(speeds<=3.5) and np.all(np.abs(correction)<=3.5)
        and np.all(np.abs(targets)<=speeds+1e-12)
        and np.allclose(baseline+correction,targets[0],rtol=0,atol=1e-12)
        and correction.tolist()==value["previous_correction"],"Sequence plan actual preceding command")
    identity=plan["request_sha256"]
    require(type(identity) is str and len(identity)==64 and all(c in "0123456789abcdef" for c in identity),
        "Sequence prior request digest")


def warm_knots(value,plan):
    validate(value);validate_plan(plan,value)
    if plan is None:return np.tile(value["nominal_correction"],(KNOTS,1)).tolist()
    # Shift the prior projected target schedule, then express it relative to
    # the current baseline. Four samples approximate that shifted schedule.
    # Every command is projected and predicted again before it may be applied.
    targets=np.array(plan["targets"]);positions=np.minimum(1+np.linspace(0,HORIZON-1,KNOTS),HORIZON-1)
    sampled=np.stack([np.interp(positions,np.arange(HORIZON),targets[:,j]) for j in range(8)],axis=1)
    return np.clip(sampled-np.array(value["baseline"]),-3.5,3.5).tolist()


def select(selector,value,plan):
    validate(value);incumbent=warm_knots(value,plan);evaluations=[];rounds=[];winner=None
    reason="handoff" if plan is None else "scheduled" if (value["command"]-60)%REPLAN_INTERVAL==0 else "warm_valid"
    if plan is not None:
        result=evaluate(selector,value,incumbent,HORIZON)
        winner=dict(iteration=-1,option=dict(index=0,name="shifted_projected_targets",knots=copy.deepcopy(incumbent)),result=result)
        evaluations.append(winner)
        if reason=="warm_valid" and not result["eligible"]:reason="warm_refused"
    if reason!="warm_valid":
        prior=None if winner is None else rank(winner["result"])
        for iteration in range(ITERATIONS):
            best=None
            for option in parameters(value,incumbent,iteration):
                result=evaluate(selector,value,option["knots"],HORIZON)
                record=dict(iteration=iteration,option=option,result=result);evaluations.append(record)
                if best is None or rank(result)<rank(best["result"]):best=record
            require(prior is None or rank(best["result"])<=prior,"Sequence replan preserves incumbent")
            winner=best;incumbent=copy.deepcopy(best["option"]["knots"]);prior=rank(best["result"])
            rounds.append(dict(iteration=iteration,winner_index=best["option"]["index"],rank=list(prior)))
    accepted=winner["result"]["eligible"];first=winner["result"]["rows"][0]
    return dict(accepted=accepted,reason=reason,horizon=HORIZON,replan_interval=REPLAN_INTERVAL,
        evaluated_candidates=len(evaluations),evaluations=evaluations,rounds=rounds,best=winner,
        selected_correction=first["correction"] if accepted else None,selected_target=first["target"] if accepted else None,
        future_baseline_assumption="current baseline and speed limits held constant",
        warm_start_approximation="shift projected targets one interval, sample four linear knots, reconcile current baseline",
        public_future_envelope_equivalence=False,future_observations_used=False,future_recorded_actions_used=False,
        planning_memory_is_learning=False,trained=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False)


def next_plan(value,selection,request_sha256):
    require(selection["accepted"] is True,"Sequence refused plan cannot enter memory")
    _,targets=commands(value,selection["best"]["option"]["knots"],HORIZON)
    require(targets[0]==selection["selected_target"],"Sequence remembered first target")
    return dict(command=value["command"],baseline=copy.deepcopy(value["baseline"]),speeds=copy.deepcopy(value["speeds"]),
        correction=copy.deepcopy(selection["selected_correction"]),targets=targets,request_sha256=request_sha256)
