"""Prospective two-factor body-gain contrasts; no selection on failure timing."""
import math
from audit_gpu_portable_search import require
from posture_factorial_diagnostic import physical_violation, control_activity


def factorial_pairs(contract, plans, trials):
    require(len(trials) == len(plans) == 10
        and all(all(t[k] == v for k,v in p.items()) for p,t in zip(plans,trials,strict=True)), "Factorial pair population")
    axes = contract["challenge"]["factorial_axes"]
    candidates = contract["provider"]["candidates"]
    rows = {(t["start_id"],t["candidate_indices"][0]):t for t in trials}
    require(len(rows) == 10, "Duplicate factorial trial")
    pairs = []
    for start in contract["challenge"]["starts"]:
        for axis, levels in axes.items():
            for i, low in enumerate(candidates):
                if low["mode"] != "feedback" or low[axis] != levels[0]:
                    continue
                high = [j for j,c in enumerate(candidates) if c["mode"] == "feedback" and c[axis] == levels[1]
                    and all(c[k] == low[k] for k in axes if k != axis)]
                require(len(high) == 1, "Missing/crossed factorial neighbor")
                a,b = [rows[start["id"],j] for j in [i,high[0]]]
                ea,eb = [t["episodes"][0] for t in [a,b]]
                fa,fb = [t["metrics"][0]["first_physical_violation"] for t in [a,b]]
                qa,qb = [e["metrics"]["quality_m_s"] for e in [ea,eb]]
                complete = all(e["outcome"] == "positive" for e in [ea,eb]) \
                    and all(type(q) in (int,float) and math.isfinite(q) for q in [qa,qb])
                pairs.append(dict(start_id=start["id"],axis=axis,low_setting=levels[0],high_setting=levels[1],
                    unchanged_axes={k:low[k] for k in axes if k != axis},
                    low_trial=a["trial_id"],high_trial=b["trial_id"],low_outcome=ea["outcome"],high_outcome=eb["outcome"],
                    eligibility_change=int(eb["outcome"] == "positive")-int(ea["outcome"] == "positive"),
                    quality_change_if_both_eligible_m_s=qb-qa if complete else None,
                    low_first_physical_violation=fa,high_first_physical_violation=fb,
                    physical_violation_time_change_if_both_observed_s=fb["time_s"]-fa["time_s"] if fa is not None and fb is not None else None))
    require(len(pairs) == 8, "Factorial contrast denominator")
    return dict(pair_count=len(pairs), pairs=pairs, prospective=True,
        scope="same_declared_start_single_factor_finite_contrast", failure_timing_used_for_selection=False,
        population_inference=False, causal_generalization_authority=False,
        adaptation_benefit_established=False, qualification_or_release_authority=False)
