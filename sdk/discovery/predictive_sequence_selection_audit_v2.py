"""Independent retained-plan structure, bounds, guards and winner checks."""
import copy
import numpy as np
from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits
from audit_predictive_sequence_v1 import verify_sequence
from audit_predictive_numeric_backend import compare
from predictive_sequence_v1 import parameters,rank,evaluate,KNOTS,CANDIDATES,ITERATIONS
from predictive_sequence_online_v2 import HORIZON,REPLAN_INTERVAL,validate_plan


def verify_selection(selection,value,plan,selector,reference=None):
    validate_plan(plan,value)
    if plan is None:
        center=np.tile(value["nominal_correction"],(KNOTS,1)).tolist()
    else:
        # Reconstruct the shifted schedule from the stored projected targets.
        center=[]
        for i in range(KNOTS):
            position=min(1+i*(HORIZON-1)/(KNOTS-1),HORIZON-1)
            lo=int(position);hi=min(lo+1,HORIZON-1);alpha=position-lo
            target=(1-alpha)*np.array(plan["targets"][lo])+alpha*np.array(plan["targets"][hi])
            center.append(np.clip(target-value["baseline"],-3.5,3.5).tolist())
        # np.interp's rounding is bound by the original exact candidate knots;
        # reconstruct its arithmetic to compare the declared runtime bytes.
        x=np.minimum(1+np.linspace(0,HORIZON-1,KNOTS),HORIZON-1);raw=np.array(plan["targets"])
        precise=np.clip(np.stack([np.interp(x,np.arange(HORIZON),raw[:,j]) for j in range(8)],axis=1)-value["baseline"],-3.5,3.5)
        require(np.allclose(center,precise,rtol=0,atol=1e-14),"Sequence warm interpolation reconstruction")
        center=precise.tolist()
    records=selection["evaluations"];cursor=0;winner=None;rounds=[]
    reason="handoff" if plan is None else "scheduled" if (value["command"]-60)%REPLAN_INTERVAL==0 else "warm_valid"
    if plan is not None:
        winner=records[0];cursor=1
        require(winner["iteration"]==-1 and winner["option"]==dict(index=0,name="shifted_projected_targets",knots=center),
            "Sequence audit preceding target warm start")
        verify_sequence(winner["result"],value,center,HORIZON,selector)
        if reason=="warm_valid" and not winner["result"]["eligible"]:reason="warm_refused"
    if reason!="warm_valid":
        prior=None if winner is None else rank(winner["result"])
        for iteration in range(ITERATIONS):
            options=parameters(value,center,iteration);group=records[cursor:cursor+CANDIDATES]
            require(len(group)==CANDIDATES,"Sequence audit candidate denominator")
            for option,record in zip(options,group,strict=True):
                require(record["iteration"]==iteration and same_bits(record["option"],option),"Sequence audit deterministic candidate")
                verify_sequence(record["result"],value,option["knots"],HORIZON,selector)
            winner=min(group,key=lambda r:rank(r["result"]));current=rank(winner["result"])
            require(prior is None or current<=prior,"Sequence audit monotone incumbent")
            center=copy.deepcopy(winner["option"]["knots"]);prior=current;cursor+=CANDIDATES
            rounds.append(dict(iteration=iteration,winner_index=winner["option"]["index"],rank=list(current)))
    accepted=winner["result"]["eligible"];first=winner["result"]["rows"][0]
    require(cursor==len(records)==selection["evaluated_candidates"] and same_bits(selection["best"],winner)
        and selection["reason"]==reason and selection["rounds"]==rounds
        and selection["accepted"]==accepted and selection["horizon"]==HORIZON and selection["replan_interval"]==REPLAN_INTERVAL
        and selection["selected_correction"]==(first["correction"] if accepted else None)
        and selection["selected_target"]==(first["target"] if accepted else None),"Sequence audit complete selection")
    require(all(selection[k] is False for k in ("public_future_envelope_equivalence","future_observations_used",
        "future_recorded_actions_used","planning_memory_is_learning","trained","tier2_qualified",
        "tier3_benefit_established","physical_acceptance_authority","release_authority")),"Sequence audit authority")
    return compare(evaluate(reference,value,winner["option"]["knots"],HORIZON),winner["result"]) if reference is not None else None
