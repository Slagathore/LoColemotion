"""Refine only an explicitly refused original sequence search."""
from actuation_recovery_mechanics import require
from predictive_sequence_online_v2 import select as original_select,HORIZON,REPLAN_INTERVAL
from predictive_sequence_local_search_v1 import search

STRATEGY="bounded_local_refinement_after_original_search_refusal"


def select(selector,value,plan):
    original=original_select(selector,value,plan)
    if original["accepted"]:return original
    require(original["best"]["result"]["eligible"] is False
        and original["horizon"]==HORIZON,"Refinement explicit original refusal")
    records=[];result=search(selector,value,original["best"]["option"]["knots"],records.append)
    best=result["best"];accepted=result["accepted"];first=best["result"]["rows"][0]
    return dict(strategy=STRATEGY,original=original,refinement=dict(result=result,evaluations=records),
        accepted=accepted,best=best,reason="local_refinement",horizon=HORIZON,replan_interval=REPLAN_INTERVAL,
        evaluated_candidates=original["evaluated_candidates"]+result["evaluated_candidates"],
        selected_correction=first["correction"] if accepted else None,
        selected_target=first["target"] if accepted else None,
        future_baseline_assumption="current baseline and speed limits held constant",
        public_future_envelope_equivalence=False,future_observations_used=False,future_recorded_actions_used=False,
        planning_memory_is_learning=False,trained=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False)
