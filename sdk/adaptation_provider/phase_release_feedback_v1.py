"""Release bounded stance residuals before scheduled swing through actual context.

This local, untrained successor preserves the parent's geometry and feedback.
It bounds and tapers the proposed correction; the public resolver still owns
all applied correction, slew and final-speed limits. It never changes phase.
"""
import hashlib
import json
import math
from pathlib import Path

from . import support_vertical_feedback_v1 as parent

CONTRACT = Path(__file__).with_suffix(".json")
require = parent.require
validate_geometry = parent.validate_geometry
POLICY = "sporespore_balanced_wave_bw15f_b_v1"
ORDER = ["rear_left", "front_left", "rear_right", "front_right"]
CYCLE, SWING = 360, 72
RULE = dict(phase_source="v1_controller_context_current_output_memory",
    policy_id=POLICY, phase_progression_mode="clocked", cycle_steps=CYCLE, swing_steps=SWING,
    ordered_phase_limb_ids=ORDER, taper_commands=44,
    taper_derivation="ceil(3.5_rad_s / 0.08_rad_s_per_command)",
    stance_weight="min(1, (360-local_phase_step)/44)", swing_weight=0.,
    proposal="phase_weight * clamp(parent_raw_correction, -3.5, +3.5)",
    phase_modified=False, resolver_limits_modified=False, measured_contact_forces_used=False)


def expected_candidates():
    old = parent.expected_candidates()
    return old + [dict(old[3], id="feedback_phase_release_v1", phase_release=True)]


def expected_definition():
    return dict(schema_version="locolemotion_phase_release_feedback_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="core", authority_mode="development_component",
            question_class="development"),
        parent_model=dict(path="sdk/adaptation_provider/support_vertical_feedback_v1.json",
            sha256=hashlib.sha256(CONTRACT.with_name("support_vertical_feedback_v1.json").read_bytes()).hexdigest()),
        parent_implementation=dict(path="sdk/adaptation_provider/support_vertical_feedback_v1.py",
            sha256=hashlib.sha256(CONTRACT.with_name("support_vertical_feedback_v1.py").read_bytes()).hexdigest()),
        phase_release_rule=RULE, candidate_count=5, candidates=expected_candidates(),
        envelope_selection="prospectively_declared_candidate_bound_host_envelope",
        trained=False, training_data_authority=False, physical_acceptance_authority=False,
        release_authority=False, equivalence_authority=False)


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value == expected_definition(), "Phase-release definition/parent identity")
    model = parent.definition()
    model.update(value)
    return model


def weights(context, semantic_step):
    require(type(semantic_step) is int and semantic_step >= 0 and isinstance(context, dict)
        and context.get("schema_version") == "sporespore_adaptation_controller_context_v1"
        and context.get("source_policy_id") == POLICY and context.get("engine_specific") is False
        and context.get("physical_acceptance_authority") is False,
        "Phase-release controller context domain")
    memory = context["controller_memory"]
    require(context["controller_memory_schema_version"] == memory["schema_version"]
        == "sporespore_balanced_wave_memory_v1"
        and memory["last_semantic_step"] == semantic_step
        and memory["phase_progression_mode"] == "clocked"
        and [l["limb_id"] for l in memory["ordered_limb_memory"]] == ORDER,
        "Phase-release current memory/schema/order")
    result = {}
    for index, limb in enumerate(memory["ordered_limb_memory"]):
        step = limb["gait_step"]
        require(type(step) is int and step >= 0, "Phase-release gait-step domain")
        local = (step+CYCLE-index*(CYCLE//4)) % CYCLE
        weight = 0. if local < SWING else min(1., (CYCLE-local)/RULE["taper_commands"])
        result[limb["limb_id"]] = dict(local_phase_step=local, scheduled_phase="swing" if local < SWING else "stance",
            weight=weight)
    return result


def feedback(state, command, candidate, model, baseline, context):
    require(candidate in expected_candidates(), "Phase-release candidate outside frozen family")
    enabled = candidate.get("phase_release", False)
    reference = parent.expected_candidates()[3] if enabled else candidate
    delta, detail = parent.feedback(state, command, reference, model, baseline)
    if not enabled:
        return delta, detail
    require(model["phase_release_rule"] == RULE, "Phase-release rule changed")
    cap, slew = [candidate[k] for k in ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s"]]
    require((cap, slew) == (3.5, .08) and math.ceil(cap/slew) == RULE["taper_commands"],
        "Phase-release taper/envelope derivation")
    phases = weights(context, state["semantic_step"])
    combined = []
    for i, receipt in enumerate(detail["legs"]):
        phase = phases[receipt["limb_id"]]
        bounded = [max(-cap, min(cap, v)) for v in delta[2*i:2*i+2]]
        # Exact zero during swing avoids signed-zero ambiguity in the proposal.
        proposed = [phase["weight"]*v for v in bounded] if phase["weight"] else [0., 0.]
        combined.extend(proposed)
        receipt.update(phase_release=dict(**phase, parent_raw_correction_rad_s=delta[2*i:2*i+2],
            bounded_parent_correction_rad_s=bounded, proposed_correction_rad_s=proposed))
        receipt["raw_combined_rad_s"] = proposed
    detail["phase_release"] = dict(enabled=True, rule=RULE)
    return combined, detail
