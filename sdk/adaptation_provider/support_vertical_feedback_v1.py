"""Compensate opposing baseline vertical foot motion during observed support.

This local successor retains the parent's body, posture and height objectives.
It changes only the composition with the actual canonical baseline command.
The bounded public resolver remains the sole authority for the applied residual.
"""
import hashlib
import json
import math
from pathlib import Path

from . import body_height_feedback_v1 as parent
from . import stance_feedback_v1 as geometry

CONTRACT = Path(__file__).with_suffix(".json")
require = parent.require
validate_geometry = parent.validate_geometry
RULE = dict(coordinate_frame="foot_center_relative_to_torso_canonical_xy",
    support_rule="observed_presence_and_bears_support",
    activation_rule="baseline_vertical_times_requested_body_vertical_strictly_negative",
    target_xy_m_s="[0, -baseline_foot_velocity_y]",
    inverse="existing_damped_J_transpose_JJ_transpose_inverse",
    no_support_or_no_opposition="zero_added_correction",
    measured_contact_forces_used=False, baseline_gait_replaced=False)


def expected_candidates():
    old = parent.expected_candidates()
    return old + [dict(old[2], id="feedback_support_vertical_v1", support_vertical_compensation=True)]


def expected_definition():
    return dict(schema_version="locolemotion_support_vertical_feedback_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="core", authority_mode="development_component",
            question_class="development"),
        parent_model=dict(path="sdk/adaptation_provider/body_height_feedback_v1.json",
            sha256=hashlib.sha256(CONTRACT.with_name("body_height_feedback_v1.json").read_bytes()).hexdigest()),
        parent_implementation=dict(path="sdk/adaptation_provider/body_height_feedback_v1.py",
            sha256=hashlib.sha256(CONTRACT.with_name("body_height_feedback_v1.py").read_bytes()).hexdigest()),
        composition_rule=RULE, candidate_count=4, candidates=expected_candidates(),
        envelope_selection="prospectively_declared_candidate_bound_host_envelope",
        trained=False, training_data_authority=False, physical_acceptance_authority=False,
        release_authority=False, equivalence_authority=False)


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value == expected_definition(), "Support-vertical definition/parent identity")
    model = parent.definition()
    model.update(value)
    return model


def validate_candidate(candidate):
    require(candidate in expected_candidates(), "Support-vertical candidate outside frozen family")


def feedback(state, command, candidate, model, baseline):
    validate_candidate(candidate)
    enabled = candidate.get("support_vertical_compensation", False)
    reference = parent.expected_candidates()[2] if enabled else candidate
    delta, detail = parent.feedback(state, command, reference, model)
    # Reference roles preserve their exact original equations and receipts.
    if not enabled:
        return delta, detail
    require(model["composition_rule"] == RULE, "Support-vertical composition rule")
    require(isinstance(baseline, dict) and isinstance(baseline.get("ordered_commands"), list),
        "Support-vertical canonical baseline shape")
    commands = baseline["ordered_commands"]
    require([row.get("actuator_id") for row in commands] == [name+"_motor" for name in geometry.JOINTS],
        "Support-vertical canonical baseline identity")
    base = [geometry.number(row["combined_canonical_target_velocity_rad_s"]) for row in commands]
    angles = {row["joint_id"]: row["position_rad"] for row in state["ordered_joint_observations"]}
    translation = detail["height_control"]["requested_foot_velocity_body_m_s"]
    combined = list(delta)
    for i, (leg, receipt) in enumerate(zip(model["legs"], detail["legs"], strict=True)):
        _, jacobian = geometry.foot_geometry(leg, angles[leg["id"]+"_hip"], angles[leg["id"]+"_knee"])
        local_base = base[2*i:2*i+2]
        baseline_velocity = [sum(a*b for a, b in zip(row, local_base, strict=True)) for row in jacobian]
        requested = [a+b for a, b in zip(receipt["requested_foot_velocity_xy_m_s"], translation[:2], strict=True)]
        opposing = receipt["support"] and baseline_velocity[1]*requested[1] < 0.
        target = [0., -baseline_velocity[1]] if opposing else [0., 0.]
        extra = geometry.inverse_velocity(jacobian, target, model["jacobian_damping_m"]) if opposing else [0., 0.]
        combined[2*i:2*i+2] = [a+b for a, b in zip(delta[2*i:2*i+2], extra, strict=True)]
        receipt.update(baseline_foot_velocity_xy_m_s=baseline_velocity, requested_body_motion_xy_m_s=requested,
            vertical_opposition=opposing, vertical_compensation_target_xy_m_s=target,
            vertical_compensation_delta_rad_s=extra, uncompensated_raw_combined_rad_s=delta[2*i:2*i+2],
            raw_combined_rad_s=combined[2*i:2*i+2])
    require(all(math.isfinite(v) for v in combined), "Nonfinite support-vertical correction")
    detail["vertical_composition"] = dict(enabled=True, rule=RULE)
    return combined, detail
