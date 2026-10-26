"""Repair equally long rejected plans by constraint violation, never acceptance."""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import array,require
from contact_priority_component import parameters as guard_parameters
from predictive_command_selection_v2 import guard,validate,SELECTION
from predictive_sequence_v1 import evaluate,rank as original_rank,KNOTS
from predictive_sequence_local_search_v1 import options,SCALES,CANDIDATES
from predictive_sequence_online_v2 import HORIZON

TOLERANCE=2e-6
STRATEGY="eligible_prefix_then_normalized_failed_interval_violation"


def violation(result,limits):
    """Score only the first rejected interval; later intervals are unobserved.

    The inherited guard remains the sole admission predicate. Normalization
    supplies an optimization ordering, not relaxed thresholds or safety proof.
    A numerical refusal has no usable severity and is ranked separately.
    """
    bounds=array(limits,(8,2),"Repair joint limits");width=bounds[:,1]-bounds[:,0]
    require(np.all(width>0),"Repair positive joint ranges")
    rows=result["rows"];require(rows and result["attempted_intervals"]==len(rows),"Repair retained intervals")
    good=result["valid_intervals"];planned=result["planned_intervals"]
    require(type(good) is int and type(planned) is int and 0<=good<=planned==HORIZON,
        "Repair unchanged full horizon")
    require(type(result["eligible"]) is bool and result["eligible"]==(good==planned) and len(rows)==min(good+1,planned),
        "Repair eligibility and truncated prefix")
    last=rows[-1];forecast=last["forecast"];reasons=guard(forecast,bounds)
    require(last["guard_reasons"]==result["rejection_reasons"]==reasons,"Repair unchanged guard")
    if not forecast["accepted"]:
        require(not result["eligible"] and reasons==["numerical_refusal"],"Repair numerical refusal")
        return dict(numerical_refusal=True,normalized_violation=None,per_step=None)
    p=guard_parameters();margin=p["joint_position_margin_rad"];speed=p["joint_speed_planning_cap_rad_s"]
    lower=bounds[:,0]+margin-TOLERANCE;upper=bounds[:,1]-margin+TOLERANCE
    require(np.all(lower<upper) and speed==3.5,"Repair existing planning guard domain")
    terms=[]
    for row in forecast["rows"]:
        q=array(row["qpos"],(15,),"Repair predicted position")
        v=array(row["qvel"],(14,),"Repair predicted velocity")
        raw_q=row["qpos"]
        tilt=math.acos(max(-1.,min(1.,1.-2.*(raw_q[4]**2+raw_q[5]**2))))
        terms.append(dict(
            joint_position=float(np.sum((np.maximum(lower-q[7:],0.)+np.maximum(q[7:]-upper,0.))/width)),
            joint_speed=float(np.sum(np.maximum(np.abs(v[6:])-(speed+TOLERANCE),0.)/speed)),
            height=max(0.,SELECTION["minimum_height_m"]-float(q[2]))/SELECTION["minimum_height_m"],
            tilt=max(0.,tilt-SELECTION["maximum_tilt_rad"])/SELECTION["maximum_tilt_rad"],
            torso_contact=float(any(1 in c["geom"] for c in row["contacts"]))))
    score=sum(sum(step.values()) for step in terms)/5.
    require(len(terms)==5 and math.isfinite(score) and score>=0.,"Repair finite complete interval severity")
    require((score==0.)==(not reasons) and result["eligible"]==(not reasons),"Repair score cannot change admission")
    return dict(numerical_refusal=False,normalized_violation=score,per_step=terms)


def rank(result,limits):
    old=original_rank(result);metric=violation(result,limits)
    numeric=metric["numerical_refusal"]
    return (*old[:2],numeric,0. if numeric else metric["normalized_violation"],old[2])


def search(selector,value,seed,retain):
    validate(value);center=array(seed,(KNOTS,8),"Repair initial control points").tolist()
    require(np.all(np.abs(center)<=3.5),"Repair initial domain")
    before=copy.deepcopy((value,seed));rounds=[];winner=None;prior=None
    for iteration,scale in enumerate(SCALES):
        best=None;eligible=0
        for option in options(value,center,iteration):
            result=evaluate(selector,value,option["knots"],HORIZON)
            record=dict(iteration=iteration,option=option,result=result,
                constraint_violation=violation(result,selector.limits))
            retain(record);eligible+=int(result["eligible"])
            if best is None or rank(result,selector.limits)<rank(best["result"],selector.limits):best=record
        current=rank(best["result"],selector.limits)
        require(prior is None or current<=prior,"Repair incumbent may not regress")
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current
        rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,
            eligible_candidates=eligible,winner_index=best["option"]["index"],rank=list(current)))
    require((value,seed)==before,"Repair immutable causal inputs")
    return dict(strategy=STRATEGY,rounds=rounds,best=winner,evaluated_candidates=len(SCALES)*CANDIDATES,
        horizon=HORIZON,accepted=winner["result"]["eligible"],finite_search_only=True,
        global_infeasibility_established=False,changed_horizon=False,changed_guard=False,
        trained=False,actual_native_transfer_verified=False,recovery_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,training_data_authority=False,
        physical_acceptance_authority=False,release_authority=False)
