"""Reconstruct seed selection, all contact candidates, and selected public action."""
from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits
from predictive_sequence_refinement_audit_v1 import verify_selection as verify_original
from contact_sequence_checks_v1 import verify_population
from predictive_contact_sequence_v1 import ClearanceMetric
from predictive_contact_sequence_online_v1 import STRATEGY
from predictive_sequence_v1 import evaluate
from audit_predictive_numeric_backend import compare


def verify_selection(selection,value,plan,selector,reference=None):
    if "seed_selection" not in selection:
        require(selection.get("reason")=="warm_valid" and "contact_search" not in selection
            and "strategy" not in selection,"Contact only warm continuation may bypass search")
        return verify_original(selection,value,plan,selector,reference)
    require(set(selection)=={"strategy","seed_selection","contact_search","accepted","best","reason","horizon","replan_interval",
        "evaluated_candidates","selected_correction","selected_target","future_baseline_assumption",
        "public_future_envelope_equivalence","future_observations_used","future_recorded_actions_used",
        "planning_memory_is_learning","trained","tier2_qualified","tier3_benefit_established",
        "physical_acceptance_authority","release_authority"} and selection["strategy"]==STRATEGY,
        "Contact exact public strategy and fields")
    require(set(selection["contact_search"])=={"result","evaluations"},"Contact exact public search payload")
    original=selection["seed_selection"]
    require(original["reason"]!="warm_valid","Contact full replan trigger")
    prior_comparison=verify_original(original,value,plan,selector,reference)
    payload=selection["contact_search"];result=payload["result"]
    verify_population(payload["evaluations"],result,value,original["best"]["option"]["knots"],selector,
        ClearanceMetric(selector.prepared),original["best"]["result"])
    best=result["best"];accepted=result["accepted"];first=best["result"]["rows"][0]
    require(selection["accepted"]==accepted and same_bits(selection["best"],best)
        and selection["reason"]=="contact_priority" and selection["horizon"]==66 and selection["replan_interval"]==12
        and selection["evaluated_candidates"]==original["evaluated_candidates"]+102
        and selection["selected_correction"]==(first["correction"] if accepted else None)
        and selection["selected_target"]==(first["target"] if accepted else None)
        and selection["future_baseline_assumption"]=="current baseline and speed limits held constant",
        "Contact exact selected first command and denominator")
    require(all(selection[k] is False for k in ("public_future_envelope_equivalence","future_observations_used",
        "future_recorded_actions_used","planning_memory_is_learning","trained","tier2_qualified",
        "tier3_benefit_established","physical_acceptance_authority","release_authority")),"Contact forbidden public authority")
    if reference is None:return None
    final=compare(evaluate(reference,value,best["option"]["knots"],66),best["result"])
    return {k:(final[k]+prior_comparison[k] if k=="changed_iteration_counts" else max(final[k],prior_comparison[k]))
        for k in final}
