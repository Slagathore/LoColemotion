"""Prospective finite comparison and measured influence, without promotion."""
import math

from audit_gpu_batch_execution import same_bits
from gpu_quadruped_model import f32
from retrieval_shadow_control import learner


def influence_vectors(row):
    commands = row["resolution"]["ordered_commands"]
    return dict(
        resolver=[r["applied_correction_rad_s"] for r in commands],
        canonical=[r["final_canonical_target_velocity_rad_s"] - r["baseline_canonical_target_velocity_rad_s"] for r in commands],
        solver=[f32(a) - f32(b) for a, b in zip(row["native_targets"], row["baseline_native_targets"], strict=True)])


def exposure(rows, dt):
    vectors = [influence_vectors(row) for row in rows]
    result = {}
    for kind in ["resolver", "canonical", "solver"]:
        values = [v[kind] for v in vectors]
        per_actuator = [math.fsum(abs(v[i]) * dt for v in values) for i in range(8)]
        result[kind] = dict(nonzero_outer_steps=[i for i, v in enumerate(values) if any(x != 0. for x in v)],
            nonzero_actuator_steps=sum(x != 0. for v in values for x in v),
            per_actuator_absolute_integral_rad=per_actuator,
            total_absolute_integral_rad=math.fsum(per_actuator))
    return result


def exposure_pair(left, right, dt):
    learner.require(len(left) == len(right) and len(left) > 0, "Influence comparison denominator")
    a, b = exposure(left, dt), exposure(right, dt)
    av, bv = [influence_vectors(r) for r in left], [influence_vectors(r) for r in right]
    result = {}
    for kind in a:
        matched = same_bits([[abs(v) for v in row[kind]] for row in av],
                            [[abs(v) for v in row[kind]] for row in bv])
        difference = a[kind]["total_absolute_integral_rad"] - b[kind]["total_absolute_integral_rad"]
        denominator = max(a[kind]["total_absolute_integral_rad"], b[kind]["total_absolute_integral_rad"])
        result[kind] = dict(trigger_steps_matched=a[kind]["nonzero_outer_steps"] == b[kind]["nonzero_outer_steps"],
            absolute_corrections_matched=matched, absolute_integral_difference_rad=difference,
            relative_integral_difference=0. if denominator == 0. else difference / denominator)
    result["matched_influence"] = all(result[k]["trigger_steps_matched"] and result[k]["absolute_corrections_matched"]
                                      for k in ["resolver", "canonical", "solver"])
    return result


def window_quality(positions, plan):
    """Positions include the initial and final boundary, even the last window."""
    width = plan["decision_window_steps"]
    learner.require(len(positions) > 1 and (len(positions)-1) % width == 0, "Quality window denominator")
    return [learner.quality(positions[i], positions[i+width], width * plan["controller_dt_s"], plan)
            for i in range(0, len(positions)-1, width)]


def eligible(metric, provider, c):
    return (metric["minimum_height_m"] >= c["selection"]["minimum_height_m"]
        and metric["maximum_tilt_rad"] <= c["selection"]["maximum_tilt_rad"]
        and metric["torso_contact_steps"] == metric["safe_no_actuation_steps"] == 0
        and provider["provider_errors"] == provider["unexpected_fallbacks"] == 0)


def comparisons(metrics, providers, rows, c):
    modes = list(metrics)
    dt = learner.contract()["controller_dt_s"]
    margin = c["comparison"]["development_quality_gain_floor_m_s"]
    arms = {m: dict(eligible=eligible(metrics[m], providers[m], c),
                    quality_m_s=metrics[m]["mean_window_quality_m_s"], exposure=exposure(rows[m], dt)) for m in modes}
    pairs = {}
    for a, b in [("frozen", "baseline"), ("frozen", "disabled"), ("frozen", "shuffled"),
                 ("episodic", "frozen"), ("episodic", "episodic_shuffled"), ("baseline", "disabled")]:
        gain = arms[a]["quality_m_s"] - arms[b]["quality_m_s"]
        pairs[a + "_versus_" + b] = dict(quality_gain_m_s=gain,
            both_eligible=arms[a]["eligible"] and arms[b]["eligible"],
            finite_gain_floor_met=arms[a]["eligible"] and arms[b]["eligible"] and gain >= margin,
            influence=exposure_pair(rows[a], rows[b], dt))
    tier2 = all(pairs["frozen_versus_" + m]["finite_gain_floor_met"] for m in ["baseline", "disabled"])
    tier3 = all(pairs["episodic_versus_" + m]["finite_gain_floor_met"] for m in ["frozen", "episodic_shuffled"])
    return dict(arms=arms, pairs=pairs, frozen_favorable_in_this_group=tier2,
        episodic_favorable_in_this_group=tier3,
        matched_influence_memory_benefit=tier3 and all(pairs["episodic_versus_" + m]["influence"]["matched_influence"]
            for m in ["frozen", "episodic_shuffled"]),
        statistical_superiority_authority=False, noninferiority_authority=False,
        interpretation="Finite development comparisons only. Eligibility failures stay in the denominator. Unequal trigger timing or magnitude prevents a matched-influence memory claim.")
