"""Apply contact-priority search at full replans; revalidate warm plans unchanged."""
from actuation_recovery_mechanics import require
from predictive_sequence_refinement_v1 import select as original_select
from predictive_sequence_online_v2 import HORIZON,REPLAN_INTERVAL
from predictive_contact_sequence_v1 import ClearanceMetric,search

STRATEGY="contact_priority_on_full_replans_with_revalidated_warm_continuation"


def select(selector,value,plan):
    original=original_select(selector,value,plan)
    if original["reason"]=="warm_valid":
        require(original["accepted"] is True,"Contact warm continuation must be admissible")
        return original
    require(original["horizon"]==HORIZON,"Contact full replan horizon")
    records=[];metric=ClearanceMetric(selector.prepared)
    result=search(selector,metric,value,original["best"]["option"]["knots"],records.append)
    best=result["best"];accepted=result["accepted"];first=best["result"]["rows"][0]
    return dict(strategy=STRATEGY,seed_selection=original,contact_search=dict(result=result,evaluations=records),
        accepted=accepted,best=best,reason="contact_priority",horizon=HORIZON,replan_interval=REPLAN_INTERVAL,
        evaluated_candidates=original["evaluated_candidates"]+result["evaluated_candidates"],
        selected_correction=first["correction"] if accepted else None,
        selected_target=first["target"] if accepted else None,
        future_baseline_assumption="current baseline and speed limits held constant",
        public_future_envelope_equivalence=False,future_observations_used=False,future_recorded_actions_used=False,
        planning_memory_is_learning=False,trained=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False)
