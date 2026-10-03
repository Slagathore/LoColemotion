"""Portable recovery-to-stance control composition.

This module owns no engine object and never applies actuation.  It validates the
already-accepted observation-V2 collection and supervisor step that transfer
ownership out of recovery, then emits the existing canonical recovery-control
receipt with the frozen stance pose and actuator caps.
"""

from __future__ import annotations

from copy import deepcopy
import math
from typing import Any, Mapping


REQUEST_SCHEMA = "sporespore_recovery_stance_control_request_v1"
CONTROLLER_PROFILE_SCHEMA = "sporespore_recovery_stance_controller_profile_v1"
CONTROL_RECEIPT_SCHEMA = "sporespore_recovery_control_receipt_v1"
CONTROL_COMMAND_SCHEMA = "sporespore_recovery_control_command_v1"
STANCE_CONTROLLER_ID = "sporespore_exact_s169_stance_handoff_controller_v1"
COLLECTION_SCHEMA = "sporespore_recovery_native_collection_request_v3"
STEP_RECEIPT_SCHEMA = "sporespore_recovery_step_receipt_v1"
RECOVERY_PROFILE_ID = "sporespore_qsdk_r24d17_exact_s169_recovery_development_v1"
ACTUATOR_PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
STANCE_POSE_ID = "exact_s169_zero_joint_stance_pose_v1"
ORDERED_ACTUATOR_IDS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
ORDERED_JOINT_IDS = tuple(
    value.removesuffix("_motor") for value in ORDERED_ACTUATOR_IDS
)
STANCE_TARGET_POSITIONS_RAD = (0.0,) * 8
MAXIMUM_STANCE_TARGET_SPEED_RAD_S = 0.75

_REQUEST_KEYS = {
    "schema_version",
    "controller_id",
    "collection",
    "handoff_or_stance_step",
}
_ALLOWED_STEP_EDGES = {
    ("raise_body", "stance_handoff", True),
    ("stance_handoff", "stance_dwell", True),
    ("stance_dwell", "stance_dwell", False),
}


class RecoveryStanceControlError(ValueError):
    """Stable fail-closed error for the portable stance composer."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryStanceControlError(code)


def _mapping(value: object, code: str) -> Mapping[str, Any]:
    _require(isinstance(value, Mapping), code)
    assert isinstance(value, Mapping)
    return value


def _canonical_sha256(core: Any, value: object, code: str) -> str:
    receipt = core.canonicalize_json(deepcopy(value))
    digest = receipt.get("sha256")
    _require(
        isinstance(digest, str) and digest.startswith("sha256:") and len(digest) == 71,
        code,
    )
    return digest


def plan_recovery_stance_control_v1(
    core: Any,
    request: Mapping[str, Any],
) -> dict[str, Any]:
    """Plan one exact-s169 stance-owned command without touching physics.

    The request carries the observation-V2 collection that was accepted for the
    just-finished outer step and that step's supervisor receipt.  The composer
    therefore cannot seize ownership without a content-bound recovery handoff
    or continue after terminal completion.
    """

    _require(set(request) == _REQUEST_KEYS, "STANCE_REQUEST_KEYS")
    _require(request.get("schema_version") == REQUEST_SCHEMA, "STANCE_REQUEST_SCHEMA")
    _require(
        request.get("controller_id") == STANCE_CONTROLLER_ID, "STANCE_CONTROLLER_ID"
    )

    collection = _mapping(request.get("collection"), "STANCE_COLLECTION")
    step = _mapping(request.get("handoff_or_stance_step"), "STANCE_STEP")
    _require(
        collection.get("schema_version") == COLLECTION_SCHEMA,
        "STANCE_COLLECTION_SCHEMA",
    )
    _require(collection.get("arm_kind") == "candidate_command", "STANCE_CANDIDATE_ARM")
    _require(step.get("schema_version") == STEP_RECEIPT_SCHEMA, "STANCE_STEP_SCHEMA")
    _require(
        step.get("support_status") == "supported_exact"
        and step.get("refusal_reason") is None
        and step.get("post_step_observation_only") is True,
        "STANCE_STEP_SUPPORT",
    )

    collected = core.recovery_collect_native_v3(deepcopy(dict(collection)))
    _require(
        collected.get("support_status") == "supported_exact"
        and collected.get("supplied_native_post_step_observation_validated") is True,
        "STANCE_COLLECTION_REFUSED",
    )
    observation_sha256 = collected.get("observation_sha256")
    _require(
        isinstance(observation_sha256, str)
        and step.get("observation_sha256") == observation_sha256,
        "STANCE_STEP_OBSERVATION_BINDING",
    )

    memory = _mapping(step.get("memory"), "STANCE_STEP_MEMORY")
    prior_phase = step.get("prior_phase")
    next_phase = step.get("next_phase")
    transitioned = step.get("transitioned")
    _require(
        isinstance(prior_phase, str)
        and isinstance(next_phase, str)
        and type(transitioned) is bool
        and collection.get("phase") == prior_phase
        and memory.get("phase") == next_phase
        and (prior_phase, next_phase, transitioned) in _ALLOWED_STEP_EDGES,
        "STANCE_STEP_EDGE",
    )
    _require(memory.get("terminal_failure_code") is None, "STANCE_TERMINAL_MEMORY")
    phase_step = memory.get("phase_steps_observed")
    _require(
        isinstance(phase_step, int)
        and not isinstance(phase_step, bool)
        and phase_step >= 0,
        "STANCE_PHASE_STEP",
    )
    classification = _mapping(step.get("classification"), "STANCE_CLASSIFICATION")
    if prior_phase == "raise_body":
        _require(
            classification.get("raised_body_gate") is True
            and classification.get("safety_gate") is True,
            "STANCE_HANDOFF_GATES",
        )
    if prior_phase == "stance_handoff":
        _require(
            classification.get("exclusive_stance_handoff_gate") is True,
            "STANCE_OWNERSHIP_GATE",
        )

    profile = core.recovery_development_profile_v1()
    _require(
        profile.get("schema_version") == "sporespore_recovery_development_profile_v1"
        and profile.get("profile_id") == RECOVERY_PROFILE_ID
        and profile.get("actuator_profile_id") == ACTUATOR_PROFILE_ID
        and profile.get("physical_execution_authorized") is False
        and profile.get("physical_acceptance_authority") is False
        and profile.get("release_authority") is False,
        "STANCE_RECOVERY_PROFILE",
    )
    pose = _mapping(profile.get("stance_pose"), "STANCE_POSE")
    actuator_ids = pose.get("ordered_actuator_ids")
    joint_ids = pose.get("ordered_joint_ids")
    targets = pose.get("ordered_target_positions_rad")
    maximum_speed = pose.get("maximum_target_speed_rad_s")
    _require(
        isinstance(actuator_ids, list)
        and isinstance(joint_ids, list)
        and isinstance(targets, list)
        and len(actuator_ids) == len(joint_ids) == len(targets) == 8
        and len(set(actuator_ids)) == len(set(joint_ids)) == 8
        and isinstance(maximum_speed, (int, float))
        and not isinstance(maximum_speed, bool)
        and math.isfinite(float(maximum_speed))
        and float(maximum_speed) > 0.0,
        "STANCE_POSE_SHAPE",
    )
    _require(
        pose.get("pose_id") == STANCE_POSE_ID
        and tuple(actuator_ids) == ORDERED_ACTUATOR_IDS
        and tuple(joint_ids) == ORDERED_JOINT_IDS
        and tuple(float(value) for value in targets) == STANCE_TARGET_POSITIONS_RAD
        and float(maximum_speed) == MAXIMUM_STANCE_TARGET_SPEED_RAD_S,
        "STANCE_POSE_IDENTITY",
    )
    _require(
        all(
            isinstance(value, (int, float))
            and not isinstance(value, bool)
            and math.isfinite(float(value))
            for value in targets
        ),
        "STANCE_POSE_TARGET",
    )

    descriptor = _mapping(collection.get("descriptor"), "STANCE_DESCRIPTOR")
    caps = core.resolve_actuator_cap_profile_v1(
        str(profile["actuator_profile_id"]),
        deepcopy(dict(descriptor)),
    )
    cap_profile = _mapping(caps.get("profile"), "STANCE_CAP_PROFILE")
    ordered_caps = cap_profile.get("ordered_caps")
    _require(
        caps.get("support_status") == "supported_exact"
        and caps.get("profile_sha256") == profile.get("actuator_profile_sha256")
        and isinstance(ordered_caps, list)
        and len(ordered_caps) == 8,
        "STANCE_CAPS",
    )

    commands: list[dict[str, Any]] = []
    for index, (actuator_id, joint_id, target, cap_value) in enumerate(
        zip(actuator_ids, joint_ids, targets, ordered_caps, strict=True)
    ):
        cap = _mapping(cap_value, f"STANCE_CAP:{index}")
        impulse = cap.get("maximum_outer_step_impulse_nms")
        _require(
            cap.get("actuator_id") == actuator_id
            and cap.get("joint_id") == joint_id
            and isinstance(impulse, (int, float))
            and not isinstance(impulse, bool)
            and math.isfinite(float(impulse))
            and float(impulse) > 0.0,
            f"STANCE_CAP_IDENTITY:{index}",
        )
        commands.append(
            {
                "schema_version": CONTROL_COMMAND_SCHEMA,
                "actuator_id": actuator_id,
                "joint_id": joint_id,
                "mode": "position_velocity",
                "target_position_rad": float(target),
                "target_velocity_rad_s": 0.0,
                "maximum_target_speed_rad_s": float(maximum_speed),
                "maximum_outer_step_impulse_nms": float(impulse),
            }
        )

    profile_sha256 = _canonical_sha256(core, profile, "STANCE_PROFILE_SHA256")
    controller_profile = {
        "schema_version": CONTROLLER_PROFILE_SCHEMA,
        "controller_id": STANCE_CONTROLLER_ID,
        "source_recovery_profile_id": profile["profile_id"],
        "source_recovery_profile_sha256": profile_sha256,
        "source_actuator_profile_id": profile["actuator_profile_id"],
        "source_actuator_profile_sha256": profile["actuator_profile_sha256"],
        "stance_pose": deepcopy(dict(pose)),
        "accepted_next_phases": ["stance_handoff", "stance_dwell"],
        "recovery_controller_overlap_permitted": False,
        "engine_identity_input_count": 0,
        "engine_specific_policy_branch_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    semantic_step = collection.get("observation", {}).get("semantic_step")
    _require(
        isinstance(semantic_step, int)
        and not isinstance(semantic_step, bool)
        and semantic_step >= 0,
        "STANCE_SEMANTIC_STEP",
    )
    return {
        "schema_version": CONTROL_RECEIPT_SCHEMA,
        "support_status": "supported_exact",
        "refusal_reason": None,
        "controller_id": STANCE_CONTROLLER_ID,
        "controller_profile_sha256": _canonical_sha256(
            core,
            controller_profile,
            "STANCE_CONTROLLER_PROFILE_SHA256",
        ),
        "observation_sha256": observation_sha256,
        "semantic_step": semantic_step,
        "phase": next_phase,
        "phase_step": phase_step,
        "owner": "stance",
        "recovery_controller_active": False,
        "stance_handoff_requested": next_phase == "stance_handoff",
        "matched_zero_command": False,
        "no_actuation_requested": False,
        "ordered_commands": commands,
        "command_sha256": _canonical_sha256(core, commands, "STANCE_COMMAND_SHA256"),
        "controller_implemented": True,
        "deterministic": True,
        "engine_identity_input_count": 0,
        "engine_specific_policy_branch_count": 0,
        "fallback_controller_active": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
