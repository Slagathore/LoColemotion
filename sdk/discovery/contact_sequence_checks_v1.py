"""Scalar capsule geometry, prospective proposals and complete decision accounting."""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits
from audit_predictive_sequence_v1 import verify_sequence
from sequence_constraint_repair_checks_v1 import check_metric
from predictive_sequence_constraint_repair_v1 import rank as feasibility_rank
from predictive_contact_sequence_v1 import STRATEGY,FOOT_NAMES


def scalar_score(metric,result):
    heights=[]
    for interval in result["rows"]:
        for row in interval["forecast"]["rows"]:
            if "qpos" not in row:continue
            frame=metric.frame(row["qpos"]);values=[]
            for index,name,endpoints,radius in metric.feet:
                p=frame["positions"][index];r=frame["rotations"][index]
                values.append(min(float(p[1])+sum(float(r[1,j])*float(e[j]) for j in range(3))
                    for e in endpoints)-float(radius))
            heights.append(values)
    count=len(heights);require(count==result["completed_predicted_steps"],"Contact scalar complete states")
    return dict(completed_states=count,
        mean_squared_clearance_m2=sum(max(0.,h)**2 for row in heights for h in row)/(4*count) if count else None,
        mean_positive_clearance_m=[sum(max(0.,row[j]) for row in heights)/count for j in range(4)] if count else None,
        maximum_positive_clearance_m=[max(max(0.,row[j]) for row in heights) for j in range(4)] if count else None,
        nonpositive_clearance_states=[sum(row[j]<=0. for row in heights) for j in range(4)],
        ordered_distal_bodies=list(FOOT_NAMES),clearance_m=heights,
        geometry_is_loaded_contact=False,training_data_authority=False)


def check_score(metric,result,recorded):
    expected=scalar_score(metric,result)
    require(set(recorded)==set(expected),"Contact exact metric fields")
    for key in expected:
        if key in ("mean_squared_clearance_m2","mean_positive_clearance_m","maximum_positive_clearance_m","clearance_m"):
            require((recorded[key] is None)==(expected[key] is None),"Contact unavailable metric")
            if expected[key] is not None:
                require(np.allclose(recorded[key],expected[key],rtol=1e-12,atol=1e-12),"Contact independent geometry metric")
        else:require(recorded[key]==expected[key],"Contact exact metric metadata")
    return expected


def independent_options(value,center,iteration):
    points=np.array(center);choices=[("incumbent",points.copy()),("zero_correction",np.zeros((4,8))),
        ("zero_target",np.tile(-np.array(value["baseline"]),(4,1))),
        ("velocity_brake",np.tile(-np.array(value["qvel"][6:])-np.array(value["baseline"]),(4,1)))]
    for j in range(8):
        for name,bound in (("lower",-3.5),("upper",3.5)):
            x=points.copy();x[:,j]=bound;choices.append((f"joint_{j}_{name}",x))
    rng=np.random.default_rng(20261026+10000*value["command"]+iteration)
    choices.extend((f"sample_{i}",points+rng.normal(0.,.8,(4,8))) for i in range(14))
    return [dict(index=i,name=name,knots=np.clip(x,-3.5,3.5).tolist()) for i,(name,x) in enumerate(choices)]


def verify_population(records,result,value,seed,selector,metric,baseline=None):
    records=iter(records);center=copy.deepcopy(seed);rounds=[];prior=None;initial=None;count=0;winner=None
    for iteration in range(3):
        best=None;eligible=0
        for option in independent_options(value,center,iteration):
            record=next(records,None);require(record is not None,"Contact missing candidate")
            require(record["iteration"]==iteration and same_bits(record["option"],option),"Contact proposal population")
            prediction=record["result"];verify_sequence(prediction,value,option["knots"],66,selector)
            check_metric(prediction,selector.limits)
            score=check_score(metric,prediction,record["contact_metric"])
            # Use the recorded vector metric for exact tie-breaking; the
            # independent scalar geometry above must agree to declared roundoff.
            base=feasibility_rank(prediction,selector.limits);cost=record["contact_metric"]["mean_squared_clearance_m2"]
            current=(*base[:4],1e300 if cost is None else cost,base[4])
            if initial is None:
                initial=record
                if baseline is not None:require(same_bits(prediction,baseline),"Contact freshly reproduced baseline")
            eligible+=int(prediction["eligible"]);count+=1
            if best is None or current<best_rank:best=record;best_rank=current
        require(prior is None or best_rank<=prior,"Contact audit incumbent preservation")
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=best_rank
        rounds.append(dict(iteration=iteration,evaluated=34,eligible_candidates=eligible,
            winner_index=best["option"]["index"],rank=list(best_rank)))
    require(next(records,None) is None and count==result["evaluated_candidates"]==102,"Contact exact candidate denominator")
    require(result["strategy"]==STRATEGY and result["rounds"]==rounds
        and same_bits(result["best"],winner) and same_bits(result["initial_metric"],initial["contact_metric"])
        and result["initial_eligible"]==initial["result"]["eligible"]
        and result["accepted"]==winner["result"]["eligible"] and result["horizon"]==66
        and result["finite_search_only"] is True,"Contact exact final result")
    require(not initial["result"]["eligible"] or result["accepted"],"Contact preserved eligible seed")
    require(all(result[k] is False for k in ("original_decision_ordering_preserved","guard_predicates_changed",
        "actuator_caps_changed","trained","actual_native_transfer_verified","recovery_benefit_established",
        "tier2_qualified","tier3_benefit_established","training_data_authority","physical_acceptance_authority",
        "release_authority","global_infeasibility_established")),"Contact forbidden authority")
    return dict(command=value["command"],evaluations=count,accepted=result["accepted"],
        initial_eligible=result["initial_eligible"],initial_clearance_m2=result["initial_metric"]["mean_squared_clearance_m2"],
        final_clearance_m2=winner["contact_metric"]["mean_squared_clearance_m2"],rounds=rounds)
