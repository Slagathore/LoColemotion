"""Independent adaptive candidate populations and scale-decision reconstruction."""
import copy
import numpy as np
from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits
from audit_predictive_sequence_v1 import verify_sequence
from predictive_sequence_v1 import rank as original_rank
from predictive_sequence_constraint_repair_v1 import rank
from sequence_constraint_repair_checks_v1 import check_metric,FLAGS
from predictive_sequence_adaptive_scale_v1 import STRATEGY


def independent_options(value,center,iteration,scale):
    p=np.array(center,dtype=float);rows=[dict(index=0,name="incumbent",knots=p.tolist())]
    for coordinate in range(32):
        for sign in (-1,1):
            x=p.copy();x.flat[coordinate]+=sign*scale
            rows.append(dict(index=len(rows),name=f"knot_{coordinate//8}_joint_{coordinate%8}_{sign}",
                knots=np.clip(x,-3.5,3.5).tolist()))
    rng=np.random.default_rng(2026102601+10000*value["command"]+iteration)
    for i in range(14):
        x=p+rng.normal(0.,scale,(4,8))
        rows.append(dict(index=len(rows),name=f"sample_{i}",knots=np.clip(x,-3.5,3.5).tolist()))
    return rows


def verify_population(records,result,value,seed,selector,*,retained_regression=False):
    center=copy.deepcopy(seed);rounds=[];legacy=[];prior=None;winner=None;count=0
    records=iter(records);scale=.4
    for iteration in range(4):
        best=old_best=None;eligible=0;initial=None
        for option in independent_options(value,center,iteration,scale):
            record=next(records,None);require(record is not None,"Adaptive missing candidate")
            require(record["iteration"]==iteration and same_bits(record["option"],option),"Adaptive candidate order/domain")
            prediction=record["result"]
            verify_sequence(prediction,value,option["knots"],66,selector)
            check_metric(prediction,selector.limits,None if retained_regression else record["constraint_violation"])
            current=rank(prediction,selector.limits)
            if option["index"]==0:initial=current
            eligible+=int(prediction["eligible"])
            if best is None or current<rank(best["result"],selector.limits):best=record
            if old_best is None or original_rank(prediction)<original_rank(old_best["result"]):old_best=record
            count+=1
        current=rank(best["result"],selector.limits)
        require(current<=initial and (prior is None or current<=prior),"Adaptive incumbent regression")
        improved=current[:4]<initial[:4]
        following=None if iteration==3 else .4/(2**(iteration+1)) if best["result"]["eligible"] else scale if improved else scale/2.
        if retained_regression:
            require(same_bits(best,old_best) and best["result"]["eligible"],"Adaptive changed accepted retained winner")
            legacy.append(dict(iteration=iteration,scale=scale,evaluated=79,eligible_candidates=eligible,
                winner_index=old_best["option"]["index"],rank=list(original_rank(old_best["result"]))))
        rounds.append(dict(iteration=iteration,scale=scale,evaluated=79,eligible_candidates=eligible,
            winner_index=best["option"]["index"],rank=list(current),incumbent_rank=list(initial),
            feasibility_improved=improved,next_scale=following))
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current;scale=following
    require(next(records,None) is None and count==result["evaluated_candidates"]==316,"Adaptive exact population")
    require(same_bits(result["best"],winner) and result["accepted"]==winner["result"]["eligible"]
        and result["horizon"]==66 and result["finite_search_only"] is True,"Adaptive final decision")
    require(result["rounds"]==(legacy if retained_regression else rounds),"Adaptive exact schedule and winners")
    require(all(result[k] is False for k in FLAGS),"Adaptive forbidden authority")
    if not retained_regression:require(result["strategy"]==STRATEGY,"Adaptive strategy identity")
    return dict(command=value["command"],evaluations=count,accepted=result["accepted"],rounds=rounds,
        retained_forecasts_only=retained_regression,new_forecasts_generated=not retained_regression,
        previous_winners_preserved=retained_regression)
