"""Prospective activity counts and single-factor contrasts; no selection rule."""
import math
from audit_gpu_portable_search import require


def physical_violation(row, selection):
    require(selection["maximum_torso_contact_steps"] == 0, "Diagnostic contact predicate")
    q = row["qpos"]
    tilt = math.acos(max(-1., min(1., 1-2*(q[4]**2+q[5]**2))))
    failed = [name for name, bad in [
        ("height", q[2] < selection["minimum_height_m"]),
        ("tilt", tilt > selection["maximum_tilt_rad"]),
        ("torso_contact", any(1 in c["geom"] for c in row["contacts"]))] if bad]
    return dict(internal_step=row["step"], time_s=row["time_s"], failure_codes=failed) if failed else None


def control_activity(rows, first_violation):
    out = dict(controller_rows=0, actuator_commands=0, absolute_clamped_commands=0,
        slew_clamped_commands=0, final_speed_clamped_commands=0, steps_with_absolute_clamp=0,
        safe_no_actuation_decisions=0, supported_leg_observations=0, near_straight_supported_knees=0,
        nonzero_posture_supported_leg_observations=0, minimum_supported_knee_rad=None,
        maximum_supported_knee_rad=None, maximum_absolute_proposed_rad_s=0., feedback_statuses={})
    for row in rows:
        if first_violation is not None and row["outer_step"]*5 >= first_violation["internal_step"]:
            break
        out["controller_rows"] += 1
        out["safe_no_actuation_decisions"] += row["output"]["actuation"]["safe_no_actuation"]
        commands = row["resolution"]["ordered_commands"]
        out["actuator_commands"] += len(commands)
        for target, source in [("absolute_clamped_commands","absolute_correction_clamped"),
            ("slew_clamped_commands","slew_clamped"), ("final_speed_clamped_commands","final_speed_clamped")]:
            out[target] += sum(c[source] for c in commands)
        out["steps_with_absolute_clamp"] += any(c["absolute_correction_clamped"] for c in commands)
        out["maximum_absolute_proposed_rad_s"] = max([out["maximum_absolute_proposed_rad_s"]]
            +[abs(c["proposed_correction_rad_s"]) for c in commands])
        status = row["feedback"]["status"]
        out["feedback_statuses"][status] = out["feedback_statuses"].get(status,0)+1
        state = row["request"]["state"]
        joints = {j["joint_id"]:j["position_rad"] for j in state["ordered_joint_observations"]}
        for contact in state["ordered_contact_observations"]:
            if contact["presence"] and contact["bears_support"]:
                angle = joints[contact["contact_site_id"].removesuffix("_foot")+"_knee"]
                out["supported_leg_observations"] += 1
                out["near_straight_supported_knees"] += abs(math.sin(angle)) <= .1
                for key, op in [("minimum_supported_knee_rad",min),("maximum_supported_knee_rad",max)]:
                    out[key] = angle if out[key] is None else op(out[key],angle)
        out["nonzero_posture_supported_leg_observations"] += sum(
            leg["support"] and any(v != 0. for v in leg["posture_regularization_delta_rad_s"])
            for leg in row["feedback"].get("legs",[]))
    return out


def factorial_pairs(contract, plans, trials):
    require(len(trials) == len(plans) == 18
        and all(all(t[k] == v for k,v in p.items()) for p,t in zip(plans,trials,strict=True)), "Factorial pair population")
    axes = contract["challenge"]["factorial_axes"]
    candidates = contract["provider"]["candidates"]
    rows = {(t["start_id"],t["candidate_indices"][0]):t for t in trials}
    require(len(rows) == 18, "Duplicate factorial trial")
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
    require(len(pairs) == 24, "Factorial contrast denominator")
    return dict(pair_count=len(pairs), pairs=pairs, prospective=True,
        scope="same_declared_start_single_factor_finite_contrast", failure_timing_used_for_selection=False,
        population_inference=False, causal_generalization_authority=False,
        adaptation_benefit_established=False, qualification_or_release_authority=False)
