"""Prospective same-start height-enabled contrasts; failed survival never selects."""
import math
from audit_gpu_portable_search import require
from posture_factorial_diagnostic import physical_violation,control_activity


def height_pairs(contract,plans,trials):
    require(len(trials)==len(plans)==6
        and all(all(t[k]==v for k,v in p.items()) for p,t in zip(plans,trials,strict=True)),"Height pair population")
    rows={(t["start_id"],t["candidate_indices"][0]):t for t in trials};require(len(rows)==6,"Duplicate height trial")
    pairs=[]
    for start in contract["challenge"]["starts"]:
        a,b=[rows[start["id"],i] for i in [1,2]]
        ea,eb=[t["episodes"][0] for t in [a,b]];fa,fb=[t["metrics"][0]["first_physical_violation"] for t in [a,b]]
        qa,qb=[e["metrics"]["quality_m_s"] for e in [ea,eb]]
        complete=all(e["outcome"]=="positive" for e in [ea,eb]) and all(type(q) in (int,float) and math.isfinite(q) for q in [qa,qb])
        pairs.append(dict(start_id=start["id"],reference_trial=a["trial_id"],height_trial=b["trial_id"],
            reference_outcome=ea["outcome"],height_outcome=eb["outcome"],
            eligibility_change=int(eb["outcome"]=="positive")-int(ea["outcome"]=="positive"),
            quality_change_if_both_eligible_m_s=qb-qa if complete else None,
            reference_first_physical_violation=fa,height_first_physical_violation=fb,
            physical_violation_time_change_if_both_observed_s=fb["time_s"]-fa["time_s"] if fa is not None and fb is not None else None))
    return dict(pair_count=2,pairs=pairs,prospective=True,scope="same_declared_start_height_enabled_finite_contrast",
        failure_timing_used_for_selection=False,population_inference=False,causal_generalization_authority=False,
        adaptation_benefit_established=False,qualification_or_release_authority=False)
