"""Verify both the original search and every retained refinement candidate."""
import copy
from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits
from predictive_sequence_selection_audit_v2 import verify_selection as verify_original
from audit_sequence_local_search_v1 import independent_options,SCALES,CANDIDATES
from audit_predictive_sequence_v1 import verify_sequence
from predictive_sequence_v1 import rank,evaluate
from audit_predictive_numeric_backend import compare
from predictive_sequence_refinement_v1 import STRATEGY


def verify_selection(selection,value,plan,selector,reference=None):
    if "original" not in selection:
        require("refinement" not in selection and "strategy" not in selection,
            "Refinement incomplete composition")
        return verify_original(selection,value,plan,selector,reference)
    require(set(selection)=={"strategy","original","refinement","accepted","best","reason","horizon","replan_interval",
        "evaluated_candidates","selected_correction","selected_target","future_baseline_assumption",
        "public_future_envelope_equivalence","future_observations_used","future_recorded_actions_used",
        "planning_memory_is_learning","trained","tier2_qualified","tier3_benefit_established",
        "physical_acceptance_authority","release_authority"} and selection["strategy"]==STRATEGY,
        "Refinement bound strategy and fields")
    require(set(selection["refinement"])=={"result","evaluations"},"Refinement exact payload")
    original=selection["original"];prior_comparison=verify_original(original,value,plan,selector,reference)
    require(original["accepted"] is False,"Refinement cannot replace an accepted search")
    refined=selection["refinement"];result=refined["result"];records=refined["evaluations"]
    center=copy.deepcopy(original["best"]["option"]["knots"]);cursor=0;rounds=[];prior=None;winner=None
    for iteration,scale in enumerate(SCALES):
        group=records[cursor:cursor+CANDIDATES]
        require(len(group)==CANDIDATES,"Refinement complete candidate denominator")
        eligible=0;best=None
        for option,record in zip(independent_options(value,center,iteration),group,strict=True):
            require(record["iteration"]==iteration and same_bits(record["option"],option),"Refinement exact candidate order/domain")
            verify_sequence(record["result"],value,option["knots"],66,selector)
            eligible+=int(record["result"]["eligible"])
            if best is None or rank(record["result"])<rank(best["result"]):best=record
        current=rank(best["result"])
        require(prior is None or current<=prior,"Refinement preserved incumbent")
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current;cursor+=CANDIDATES
        rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,eligible_candidates=eligible,
            winner_index=best["option"]["index"],rank=list(current)))
    require(cursor==len(records)==result["evaluated_candidates"]==316 and result["rounds"]==rounds
        and same_bits(result["best"],winner) and result["accepted"]==winner["result"]["eligible"]
        and result["horizon"]==66 and result["finite_search_only"] is True,"Refinement exact final decision")
    require(all(result[k] is False for k in ("global_infeasibility_established","changed_horizon","changed_guard",
        "trained","actual_native_transfer_verified","recovery_benefit_established","tier2_qualified",
        "tier3_benefit_established","training_data_authority","physical_acceptance_authority","release_authority")),
        "Refinement forbidden component authority")
    accepted=result["accepted"];first=winner["result"]["rows"][0]
    require(selection["accepted"]==accepted and same_bits(selection["best"],winner)
        and selection["reason"]=="local_refinement" and selection["horizon"]==66 and selection["replan_interval"]==12
        and selection["evaluated_candidates"]==original["evaluated_candidates"]+316
        and selection["selected_correction"]==(first["correction"] if accepted else None)
        and selection["selected_target"]==(first["target"] if accepted else None),"Refinement exact selected first command")
    require(all(selection[k] is False for k in ("public_future_envelope_equivalence","future_observations_used",
        "future_recorded_actions_used","planning_memory_is_learning","trained","tier2_qualified",
        "tier3_benefit_established","physical_acceptance_authority","release_authority")),"Refinement forbidden public authority")
    if reference is None:return None
    final=compare(evaluate(reference,value,winner["option"]["knots"],66),winner["result"])
    return {k:(final[k]+prior_comparison[k] if k=="changed_iteration_counts" else max(final[k],prior_comparison[k]))
        for k in final}
