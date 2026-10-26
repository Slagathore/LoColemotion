"""Independent scalar constraint accounting and complete search reconstruction."""
import copy
import math
from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits
from audit_sequence_local_search_v1 import independent_options,SCALES,CANDIDATES
from audit_predictive_sequence_v1 import verify_sequence
from predictive_sequence_v1 import rank as original_rank
from predictive_sequence_constraint_repair_v1 import rank,violation,STRATEGY

FLAGS=("global_infeasibility_established","changed_horizon","changed_guard","trained",
    "actual_native_transfer_verified","recovery_benefit_established","tier2_qualified",
    "tier3_benefit_established","training_data_authority","physical_acceptance_authority","release_authority")


def scalar_violation(result,limits):
    """Recompute normalization with scalar arithmetic and explicit guard constants."""
    forecast=result["rows"][-1]["forecast"]
    if not forecast["accepted"]:
        require(not result["eligible"],"Repair scalar refused predictor cannot be eligible")
        return dict(numerical_refusal=True,normalized_violation=None,per_step=None)
    steps=[]
    for row in forecast["rows"]:
        position=velocity=0.
        for j,(lo,hi) in enumerate(limits):
            lo=float(lo);hi=float(hi);q=row["qpos"][7+j];v=row["qvel"][6+j]
            require(hi>lo,"Repair scalar positive range")
            low=lo+3.5/600.-2e-6;high=hi-3.5/600.+2e-6
            position+=(max(0.,low-q)+max(0.,q-high))/(hi-lo)
            velocity+=max(0.,abs(v)-(3.5+2e-6))/3.5
        q=row["qpos"];angle=math.acos(max(-1.,min(1.,1.-2.*(q[4]**2+q[5]**2))))
        steps.append(dict(joint_position=position,joint_speed=velocity,
            height=max(0.,.25-q[2])/.25,tilt=max(0.,angle-.6)/.6,
            torso_contact=1. if any(1 in c["geom"] for c in row["contacts"]) else 0.))
    require(len(steps)==5,"Repair scalar complete failed interval")
    return dict(numerical_refusal=False,normalized_violation=sum(sum(s.values()) for s in steps)/5.,
        per_step=steps)


def check_metric(result,limits,recorded=None):
    expected=scalar_violation(result,limits);actual=violation(result,limits)
    require(actual["numerical_refusal"]==expected["numerical_refusal"],"Repair numerical severity category")
    if expected["numerical_refusal"]:
        require(actual==expected,"Repair missing severity must remain unavailable")
    else:
        for left,right in zip(actual["per_step"],expected["per_step"],strict=True):
            require(set(left)==set(right) and all(math.isclose(left[k],right[k],rel_tol=1e-12,abs_tol=1e-14)
                for k in left),"Repair independently reconstructed violation components")
        require(math.isclose(actual["normalized_violation"],expected["normalized_violation"],
            rel_tol=1e-12,abs_tol=1e-14),"Repair independently reconstructed severity")
        require((expected["normalized_violation"]==0.)==result["eligible"],"Repair scalar admission identity")
    if recorded is not None:require(same_bits(actual,recorded),"Repair retained metric identity")
    return actual


def verify_population(records,result,value,seed,selector,*,retained_regression=False):
    """Consume exactly four rounds; inherited forecasts stay immutable.

    Regression mode reorders a complete hash-bound old candidate population.
    Fresh mode verifies all new forecast guards, objective and projection.
    Neither mode generates a native observation.
    """
    center=copy.deepcopy(seed);rounds=[];prior=None;winner=None;count=0;records=iter(records)
    old_rounds=[];old_prior=None
    for iteration,scale in enumerate(SCALES):
        best=old_best=None;eligible=0
        for option in independent_options(value,center,iteration):
            record=next(records,None);require(record is not None,"Repair missing candidate")
            require(record["iteration"]==iteration and same_bits(record["option"],option),"Repair candidate order/domain")
            forecast=record["result"]
            verify_sequence(forecast,value,option["knots"],66,selector)
            check_metric(forecast,selector.limits,None if retained_regression else record["constraint_violation"])
            eligible+=int(forecast["eligible"])
            if best is None or rank(forecast,selector.limits)<rank(best["result"],selector.limits):best=record
            if old_best is None or original_rank(forecast)<original_rank(old_best["result"]):old_best=record
            count+=1
        current=rank(best["result"],selector.limits)
        require(prior is None or current<=prior,"Repair retained incumbent regression")
        if retained_regression:
            require(same_bits(best,old_best) and best["result"]["eligible"],"Repair changed accepted retained winner")
            old_current=original_rank(old_best["result"])
            require(old_prior is None or old_current<=old_prior,"Repair original incumbent regression")
            old_rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,
                eligible_candidates=eligible,winner_index=old_best["option"]["index"],rank=list(old_current)))
            old_prior=old_current
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current
        rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,
            eligible_candidates=eligible,winner_index=best["option"]["index"],rank=list(current)))
    require(next(records,None) is None and count==result["evaluated_candidates"]==316,"Repair exact population")
    require(same_bits(result["best"],winner) and result["accepted"]==winner["result"]["eligible"]
        and result["horizon"]==66 and result["finite_search_only"] is True,"Repair final decision")
    require(result["rounds"]==(old_rounds if retained_regression else rounds),"Repair exact round winners")
    require(all(result[k] is False for k in FLAGS),"Repair forbidden authority")
    if not retained_regression:require(result["strategy"]==STRATEGY,"Repair strategy identity")
    return dict(command=value["command"],evaluations=count,accepted=result["accepted"],rounds=rounds,
        retained_forecasts_only=retained_regression,new_forecasts_generated=not retained_regression,
        previous_winners_preserved=retained_regression)
