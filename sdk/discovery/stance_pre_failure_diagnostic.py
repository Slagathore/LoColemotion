"""Descriptive pre-failure counts from retained stance discovery, without physics.

The cutoff uses the original eligibility predicates. The near-straight knee
threshold is post hoc and has no ranking, acceptance or causal authority.
"""
import math

from audit_gpu_batch_execution import read_jsonl
from audit_gpu_portable_search import require


def first_violation(rows, selection):
    for row in rows:
        q = row["qpos"]
        tilt = math.acos(max(-1., min(1., 1-2*(q[4]**2+q[5]**2))))
        failures = [name for name, failed in [
            ("height", q[2] < selection["minimum_height_m"]),
            ("tilt", tilt > selection["maximum_tilt_rad"]),
            ("torso_contact", any(1 in c["geom"] for c in row["contacts"]))] if failed]
        if failures:
            return dict(internal_step=row["step"], time_s=row["time_s"], failure_codes=failures)
    raise ValueError("No original physical eligibility violation")


def control_counts(rows, cutoff):
    counts = dict(controller_rows=0, actuator_commands=0, absolute_clamped_commands=0,
        slew_clamped_commands=0, final_speed_clamped_commands=0, steps_with_absolute_clamp=0,
        maximum_absolute_proposed_rad_s=0., maximum_absolute_applied_rad_s=0.,
        supported_leg_observations=0, near_straight_supported_knees=0,
        minimum_supported_knee_rad=None, maximum_supported_knee_rad=None, feedback_statuses={})
    for row in rows:
        # Include the decision whose held target precedes the first failed
        # internal sample. Decisions at or after that completed sample are out.
        if row["outer_step"]*5 >= cutoff["internal_step"]:
            break
        require(not row["output"]["actuation"]["safe_no_actuation"],
            "Earlier controller eligibility failure needs a distinct diagnostic")
        commands = row["resolution"]["ordered_commands"]
        counts["controller_rows"] += 1
        counts["actuator_commands"] += len(commands)
        for field, source in [("absolute_clamped_commands", "absolute_correction_clamped"),
            ("slew_clamped_commands", "slew_clamped"), ("final_speed_clamped_commands", "final_speed_clamped")]:
            counts[field] += sum(c[source] for c in commands)
        counts["steps_with_absolute_clamp"] += any(c["absolute_correction_clamped"] for c in commands)
        for field, source in [("maximum_absolute_proposed_rad_s", "proposed_correction_rad_s"),
            ("maximum_absolute_applied_rad_s", "applied_correction_rad_s")]:
            counts[field] = max([counts[field]]+[abs(c[source]) for c in commands])
        status = row["feedback"]["status"]
        counts["feedback_statuses"][status] = counts["feedback_statuses"].get(status, 0)+1
        state = row["request"]["state"]
        joints = {j["joint_id"]: j["position_rad"] for j in state["ordered_joint_observations"]}
        for contact in state["ordered_contact_observations"]:
            if contact["presence"] and contact["bears_support"]:
                angle = joints[contact["contact_site_id"].removesuffix("_foot")+"_knee"]
                counts["supported_leg_observations"] += 1
                counts["near_straight_supported_knees"] += abs(math.sin(angle)) <= .1
                for key, operator in [("minimum_supported_knee_rad", min), ("maximum_supported_knee_rad", max)]:
                    counts[key] = angle if counts[key] is None else operator(counts[key], angle)
    return counts


def diagnose(physical, plans, contract):
    rows = []
    for plan in plans:
        folder = physical/plan["trial_id"]
        cutoff = first_violation(read_jsonl(folder/"trace.jsonl"), contract["selection"])
        counts = control_counts(read_jsonl(folder/"controller.jsonl"), cutoff)
        rows.append(dict(trial_id=plan["trial_id"], candidate_index=plan["candidate_indices"][0],
            first_physical_violation=cutoff, **counts))
    feedback_rows = [r for r in rows if contract["provider"]["candidates"][r["candidate_index"]]["mode"] == "feedback"]
    aggregate_fields = ["controller_rows", "actuator_commands", "absolute_clamped_commands",
        "slew_clamped_commands", "final_speed_clamped_commands", "steps_with_absolute_clamp",
        "supported_leg_observations", "near_straight_supported_knees"]
    return dict(schema_version="locolemotion_stance_pre_failure_diagnostic_v1", post_hoc=True,
        near_straight_rule="abs(sin(supported_knee_position_rad)) <= 0.1",
        cutoff_rule="prepared command outer_step*5 strictly before first failed completed internal step",
        clipping_source="original independently replayed public resolver flags",
        trials=rows, feedback_only_denominator=len(feedback_rows),
        feedback_only_totals={k: sum(r[k] for r in feedback_rows) for k in aggregate_fields},
        causal_authority=False, selection_authority=False, acceptance_authority=False)
