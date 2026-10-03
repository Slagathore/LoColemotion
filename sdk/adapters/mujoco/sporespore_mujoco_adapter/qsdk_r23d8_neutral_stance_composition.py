"""Engine-neutral terminal neutral-stance composition for QSDK-R23D8.

The module converts the preregistered all-eight-joint neutral target into the
existing canonical velocity composition and MuJoCo host mapping. Its preflight
uses the real portable core and exact s169 descriptor but constructs no model
and starts no physics adapter.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sporespore_locomotion import LocomotionCore

from . import qsdk_r23d2_heading_response as base
from . import selected_policy_development as bridge
from . import selected_policy_pose_hold_restoration_mv6 as mv6


SDK_ROOT = Path(__file__).resolve().parents[3]
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d8_neutral_stance as design  # noqa: E402


DECLARATION_PATH = TURNING_ROOT / "r23d8_scientific_execution_contract_v1.json"
EXPECTED_DECLARATION_SHA256 = (
    "sha256:4cf6d5e318a4d0c8aa80aff34f9ba34828db71e795c33ffb4a0d15ebbbdfb638"
)
GATE_ID = design.GATE_ID
RESTORATION_POLICY_ID = design.POLICY_ID
SUPPORTED_POLICY_ID = base.POLICY_ID
PROFILE_ID = base.HOST_PROFILE_ID
FORWARD_VELOCITY_RECEIPT_MEMBER = "forward_velocity_foot_placement"
NO_FORWARD_VELOCITY_SOURCE_CONTRACT_ID = (
    "source_receipt_forbids_forward_velocity_foot_placement_v1"
)
R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID = (
    "r23d21_forward_velocity_foot_placement_receipt_v2"
)
R23D21_FORWARD_VELOCITY_RECEIPT_SCHEMA = (
    "sporespore_forward_velocity_foot_placement_receipt_v2"
)
R23D21_FORWARD_VELOCITY_MODE_ID = "forward_velocity_foot_placement_v1"
R23D21_FORWARD_VELOCITY_ERROR_ORIENTATION_ID = (
    "desired_minus_measured_forward_velocity_error_v1"
)
R23D21_MAXIMUM_HIP_TARGET_CORRECTION_RAD = 0.03
R23D21_FORWARD_VELOCITY_LIMB_IDS = (
    "front_left",
    "front_right",
    "rear_left",
    "rear_right",
)
MAXIMUM_ACQUISITION_STEPS = 180
REQUIRED_CONSECUTIVE_CONTACT_STEPS = 360
MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S = design.MAXIMUM_SPEED_RAD_S
POSE_POSITION_GAIN_PER_S = design.POSITION_GAIN_PER_S
POSE_RATE_DAMPING = design.RATE_DAMPING
TOLERANCE = 1.0e-12


@dataclass
class TerminalRestorationMemory:
    """Track the one atomic neutral-target activation transition."""

    activated: bool = False
    activation_semantic_step: int | None = None


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _close(left: Any, right: Any, tolerance: float = TOLERANCE) -> bool:
    return _finite(left) and _finite(right) and math.isclose(
        float(left), float(right), rel_tol=0.0, abs_tol=tolerance
    )


def _validate_forward_velocity_source_receipt(
    receipt: dict[str, Any],
    source_forward_velocity_contract_id: str,
) -> dict[str, Any] | None:
    """Validate the declared source-policy receipt without mutating it.

    R23D8's historical BW5R-B source contract forbids the optional member. A
    future caller may opt into the exact R23D21 V2 shape, but only by naming
    the contract explicitly; unknown or partially shaped receipts fail closed.
    """

    if (
        source_forward_velocity_contract_id
        == NO_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
    ):
        if FORWARD_VELOCITY_RECEIPT_MEMBER in receipt:
            raise RuntimeError("QSDK_R23D8_NEUTRAL_UNEXPECTED_FORWARD_RECEIPT")
        return None
    if (
        source_forward_velocity_contract_id
        != R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
    ):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_SOURCE_CONTRACT_ID")

    forward = receipt.get(FORWARD_VELOCITY_RECEIPT_MEMBER)
    expected_keys = {
        "schema_version",
        "mode_id",
        "velocity_error_orientation_id",
        "desired_forward_velocity_task_m_s",
        "measured_forward_velocity_task_m_s",
        "normalized_forward_velocity_error",
        "maximum_hip_target_correction_rad",
        "ordered_limb_corrections",
        "morphology_branch_surface_count",
        "controller_parameter",
        "walking_claim_authorized",
        "physical_acceptance_authority",
    }
    if not isinstance(forward, dict) or set(forward) != expected_keys:
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_SHAPE")
    if (
        forward.get("schema_version")
        != R23D21_FORWARD_VELOCITY_RECEIPT_SCHEMA
        or forward.get("mode_id") != R23D21_FORWARD_VELOCITY_MODE_ID
        or forward.get("velocity_error_orientation_id")
        != R23D21_FORWARD_VELOCITY_ERROR_ORIENTATION_ID
        or not _close(
            forward.get("maximum_hip_target_correction_rad"),
            R23D21_MAXIMUM_HIP_TARGET_CORRECTION_RAD,
        )
        or forward.get("morphology_branch_surface_count") != 0
        or forward.get("controller_parameter") is not True
        or forward.get("walking_claim_authorized") is not False
        or forward.get("physical_acceptance_authority") is not False
    ):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_IDENTITY")

    desired = forward.get("desired_forward_velocity_task_m_s")
    measured = forward.get("measured_forward_velocity_task_m_s")
    normalized = forward.get("normalized_forward_velocity_error")
    if not _finite(desired) or not _finite(measured) or not _finite(normalized):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_NONFINITE")
    expected_normalized = (
        max(-1.0, min(1.0, (float(desired) - float(measured)) / abs(float(desired))))
        if abs(float(desired)) > 1.0e-12
        else 0.0
    )
    if not _close(normalized, expected_normalized):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_ERROR_EQUATION")

    corrections = forward.get("ordered_limb_corrections")
    if not isinstance(corrections, list) or len(corrections) != len(
        R23D21_FORWARD_VELOCITY_LIMB_IDS
    ):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_COUNT")
    observed_ids: list[str] = []
    for correction in corrections:
        if not isinstance(correction, dict) or set(correction) != {
            "limb_id",
            "local_phase_step",
            "cycle_envelope",
            "applied_hip_target_correction_rad",
        }:
            raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_SHAPE")
        limb_id = correction.get("limb_id")
        local_phase_step = correction.get("local_phase_step")
        envelope = correction.get("cycle_envelope")
        applied = correction.get("applied_hip_target_correction_rad")
        if not isinstance(limb_id, str):
            raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_ID")
        observed_ids.append(limb_id)
        if (
            isinstance(local_phase_step, bool)
            or not isinstance(local_phase_step, int)
            or local_phase_step < 0
            or local_phase_step >= 360
            or not _finite(envelope)
            or float(envelope) < 0.0
            or float(envelope) > 1.0
            or not _finite(applied)
        ):
            raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_VALUE")
        expected_applied = (
            float(normalized)
            * R23D21_MAXIMUM_HIP_TARGET_CORRECTION_RAD
            * float(envelope)
        )
        if not _close(applied, expected_applied):
            raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_EQUATION")
    if tuple(observed_ids) != R23D21_FORWARD_VELOCITY_LIMB_IDS:
        raise RuntimeError("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_ORDER")
    return forward


def _ordered_actuators(robot: Any) -> list[dict[str, Any]]:
    spec_by_id = {
        item["actuator_id"]: item for item in robot.spec["actuators"]
    }
    return [
        {
            "actuator_id": actuator_id,
            "joint_id": spec_by_id[actuator_id]["joint_id"],
            "minimum_target_position_rad": spec_by_id[actuator_id][
                "minimum_target_position_rad"
            ],
            "maximum_target_position_rad": spec_by_id[actuator_id][
                "maximum_target_position_rad"
            ],
        }
        for actuator_id in robot.morphology["ordered_actuator_ids"]
    ]


def _validate_source_actuation(
    base_actuation: dict[str, Any],
    *,
    supported_policy_id: str = SUPPORTED_POLICY_ID,
    source_forward_velocity_contract_id: str = (
        NO_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
    ),
) -> dict[str, Any]:
    receipt = base_actuation.get("receipt")
    if not isinstance(receipt, dict):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_SOURCE_RECEIPT_SHAPE")
    if receipt.get("policy_id") != supported_policy_id:
        raise RuntimeError("QSDK_R23D8_NEUTRAL_SOURCE_POLICY_ID")
    _validate_forward_velocity_source_receipt(
        receipt,
        source_forward_velocity_contract_id,
    )
    commands = base_actuation.get("ordered_commands")
    if not isinstance(commands, list) or len(commands) != design.ACTUATOR_COUNT:
        raise RuntimeError("QSDK_R23D8_NEUTRAL_SOURCE_COMMAND_COUNT")
    return receipt


def terminal_restoration_composition(
    robot: Any,
    base_actuation: dict[str, Any],
    policy_profile: dict[str, Any],
    state: dict[str, Any],
    pre_step_contacts: dict[str, bool],
    ordered_kinematics: list[dict[str, Any]],
    memory: TerminalRestorationMemory,
    *,
    supported_policy_id: str = SUPPORTED_POLICY_ID,
    source_forward_velocity_contract_id: str = (
        NO_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
    ),
) -> dict[str, Any]:
    """Compose the exact R23D8 neutral stance without stepping physics."""

    del pre_step_contacts, ordered_kinematics
    source_receipt = _validate_source_actuation(
        base_actuation,
        supported_policy_id=supported_policy_id,
        source_forward_velocity_contract_id=source_forward_velocity_contract_id,
    )
    if policy_profile.get("policy_id") != supported_policy_id:
        raise RuntimeError("QSDK_R23D8_NEUTRAL_PROFILE_POLICY_ID")
    semantic_step = base_actuation.get("semantic_step")
    if isinstance(semantic_step, bool) or not isinstance(semantic_step, int):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_SEMANTIC_STEP")

    actuators = _ordered_actuators(robot)
    observations = state.get("ordered_joint_observations")
    if not isinstance(observations, list):
        raise RuntimeError("QSDK_R23D8_NEUTRAL_OBSERVATION_SHAPE")
    neutral_receipt = design.compose_neutral_stance(actuators, observations)
    expected_ids = list(robot.morphology["ordered_actuator_ids"])
    failures = design.receipt_failures(neutral_receipt, expected_ids)
    if failures:
        raise RuntimeError("QSDK_R23D8_NEUTRAL_RECEIPT:" + ",".join(failures))

    first_activation = not memory.activated
    if first_activation:
        memory.activated = True
        memory.activation_semantic_step = semantic_step
    neutral_receipt["semantic_step"] = semantic_step
    neutral_receipt["source_turning_policy_id"] = supported_policy_id
    source_forward = source_receipt.get(FORWARD_VELOCITY_RECEIPT_MEMBER)
    neutral_receipt["source_forward_velocity_contract_id"] = (
        source_forward_velocity_contract_id
    )
    neutral_receipt["source_receipt_forward_velocity_member_present"] = (
        source_forward is not None
    )
    neutral_receipt["source_forward_velocity_receipt_schema_version"] = (
        source_forward.get("schema_version")
        if isinstance(source_forward, dict)
        else None
    )
    neutral_receipt["source_forward_velocity_mode_id"] = (
        source_forward.get("mode_id") if isinstance(source_forward, dict) else None
    )
    neutral_receipt["source_forward_velocity_error_orientation_id"] = (
        source_forward.get("velocity_error_orientation_id")
        if isinstance(source_forward, dict)
        else None
    )
    neutral_receipt["source_forward_velocity_maximum_hip_target_correction_rad"] = (
        source_forward.get("maximum_hip_target_correction_rad")
        if isinstance(source_forward, dict)
        else None
    )
    neutral_receipt["source_held_steering_fraction"] = float(
        source_receipt["held_steering_fraction"]
    )
    neutral_receipt["atomic_activation_transition"] = first_activation
    neutral_receipt["activation_semantic_step"] = memory.activation_semantic_step
    for solution in neutral_receipt["ordered_actuator_solutions"]:
        solution["neutral_target_activated"] = True
        # Retained compatibility field: exactly eight transition events occur
        # on the first terminal step; it is not dynamic pose capture.
        solution["pose_capture_activated"] = first_activation
        solution["desired_joint_velocity_rad_s"] = solution[
            "bounded_velocity_rad_s"
        ]

    desired_by_actuator = {
        item["actuator_id"]: float(item["bounded_velocity_rad_s"])
        for item in neutral_receipt["ordered_actuator_solutions"]
    }
    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": command["actuator_id"],
            "canonical_velocity_delta_rad_s": desired_by_actuator[
                command["actuator_id"]
            ]
            - (-float(command["target_velocity_rad_s"])),
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for command in base_actuation["ordered_commands"]
    ]
    canonical = robot.core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": robot.descriptor,
            "source_actuation": base_actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    host = robot.core.canonical_velocity_host_map_v1(
        {
            "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
            "descriptor": robot.descriptor,
            "canonical_actuation": canonical,
            "host_profile": bridge._mujoco_host_profile(PROFILE_ID),
        }
    )
    for canonical_command, host_command in zip(
        canonical["ordered_commands"], host["ordered_commands"], strict=True
    ):
        desired = desired_by_actuator[canonical_command["actuator_id"]]
        if (
            not _close(
                canonical_command["combined_canonical_target_velocity_rad_s"],
                desired,
            )
            or not _close(host_command["host_target_velocity_rad_s"], desired)
            or host_command["native_target_position_rad"] is not None
        ):
            raise RuntimeError(
                "QSDK_R23D8_NEUTRAL_MAPPING:"
                + canonical_command["actuator_id"]
            )

    return {
        "canonical_actuation": canonical,
        "host_mapping": host,
        "ordered_bounded_canonical_residuals": [
            {
                "actuator_id": item["actuator_id"],
                "applied_velocity_delta_rad_s": float(
                    item["canonical_velocity_delta_rad_s"]
                ),
            }
            for item in residuals
        ],
        "terminal_receipt": neutral_receipt,
    }


def terminal_receipt_failures(
    receipt: dict[str, Any],
    canonical: dict[str, Any] | None = None,
    host: dict[str, Any] | None = None,
    *,
    supported_policy_id: str = SUPPORTED_POLICY_ID,
    source_forward_velocity_contract_id: str = (
        NO_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
    ),
) -> list[str]:
    """Verify the neutral equation, provenance, and mapped velocity identity."""

    solutions = receipt.get("ordered_actuator_solutions")
    expected_ids = (
        [item.get("actuator_id") for item in solutions]
        if isinstance(solutions, list)
        else []
    )
    failures = design.receipt_failures(receipt, expected_ids)
    if receipt.get("source_turning_policy_id") != supported_policy_id:
        failures.append("source_turning_policy_id")
    expected_forward_member = (
        source_forward_velocity_contract_id
        == R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
    )
    if (
        receipt.get("source_forward_velocity_contract_id")
        != source_forward_velocity_contract_id
    ):
        failures.append("source_forward_velocity_contract_id")
    if (
        receipt.get("source_receipt_forward_velocity_member_present")
        is not expected_forward_member
    ):
        failures.append("source_forward_velocity_member")
    if expected_forward_member:
        if (
            receipt.get("source_forward_velocity_receipt_schema_version")
            != R23D21_FORWARD_VELOCITY_RECEIPT_SCHEMA
        ):
            failures.append("source_forward_velocity_schema")
        if (
            receipt.get("source_forward_velocity_mode_id")
            != R23D21_FORWARD_VELOCITY_MODE_ID
        ):
            failures.append("source_forward_velocity_mode")
        if (
            receipt.get("source_forward_velocity_error_orientation_id")
            != R23D21_FORWARD_VELOCITY_ERROR_ORIENTATION_ID
        ):
            failures.append("source_forward_velocity_orientation")
        if not _close(
            receipt.get(
                "source_forward_velocity_maximum_hip_target_correction_rad"
            ),
            R23D21_MAXIMUM_HIP_TARGET_CORRECTION_RAD,
        ):
            failures.append("source_forward_velocity_maximum_correction")
    elif any(
        receipt.get(field) is not None
        for field in (
            "source_forward_velocity_receipt_schema_version",
            "source_forward_velocity_mode_id",
            "source_forward_velocity_error_orientation_id",
            "source_forward_velocity_maximum_hip_target_correction_rad",
        )
    ):
        failures.append("source_forward_velocity_unexpected_summary")
    if receipt.get("neutral_target_activation_count") != design.ACTUATOR_COUNT:
        failures.append("neutral_target_activation_count")
    if isinstance(solutions, list):
        for solution in solutions:
            if solution.get("neutral_target_activated") is not True:
                failures.append(
                    "neutral_target_activated:" + str(solution.get("actuator_id"))
                )
    if canonical is not None and host is not None and isinstance(solutions, list):
        desired = {
            item["actuator_id"]: item.get("bounded_velocity_rad_s")
            for item in solutions
        }
        canonical_commands = canonical.get("ordered_commands", [])
        host_commands = host.get("ordered_commands", [])
        if len(canonical_commands) != design.ACTUATOR_COUNT:
            failures.append("canonical_count")
        if len(host_commands) != design.ACTUATOR_COUNT:
            failures.append("host_count")
        for item in canonical_commands:
            if not _close(
                item.get("combined_canonical_target_velocity_rad_s"),
                desired.get(item.get("actuator_id")),
            ):
                failures.append("canonical:" + str(item.get("actuator_id")))
        for item in host_commands:
            if (
                not _close(
                    item.get("host_target_velocity_rad_s"),
                    desired.get(item.get("actuator_id")),
                )
                or item.get("native_target_position_rad") is not None
            ):
                failures.append("host:" + str(item.get("actuator_id")))
    return failures


def _terminal_pose_memory_transition_failures(
    receipt: dict[str, Any], independent_memory: dict[str, float]
) -> list[str]:
    """Prove one atomic all-actuator activation, not per-contact pose capture."""

    failures: list[str] = []
    solutions = receipt.get("ordered_actuator_solutions")
    if not isinstance(solutions, list) or len(solutions) != design.ACTUATOR_COUNT:
        return ["neutral_transition_solution_count"]
    first = not independent_memory
    if receipt.get("atomic_activation_transition") is not first:
        failures.append("neutral_atomic_activation_transition")
    for solution in solutions:
        actuator_id = solution.get("actuator_id")
        if not isinstance(actuator_id, str):
            failures.append("neutral_transition_actuator_id")
            continue
        if solution.get("pose_capture_activated") is not first:
            failures.append("neutral_transition_compatibility_flag:" + actuator_id)
        if not _close(solution.get("target_position_rad"), 0.0):
            failures.append("neutral_transition_target:" + actuator_id)
        if first:
            independent_memory[actuator_id] = 0.0
        elif actuator_id not in independent_memory:
            failures.append("neutral_transition_memory_missing:" + actuator_id)
    if len(independent_memory) != design.ACTUATOR_COUNT:
        failures.append("neutral_transition_memory_count")
    return failures


def _policy_profile_fixture() -> dict[str, Any]:
    return {
        "policy_id": SUPPORTED_POLICY_ID,
        "schema_version": "sporespore_balanced_wave_filtered_profile_v1",
    }


class _ZeroWorldRobot:
    def __init__(self, core: LocomotionCore, compiled: dict[str, Any]) -> None:
        self.core = core
        self.descriptor = bridge.s169_descriptor()
        self.morphology = compiled["morphology"]
        self.spec = self.morphology["morphology_spec"]


def run_zero_world_preflight() -> dict[str, Any]:
    """Exercise exact production-shaped composition for both signed arms."""

    if _raw_sha256(DECLARATION_PATH) != EXPECTED_DECLARATION_SHA256:
        raise RuntimeError("QSDK_R23D8_DECLARATION_HASH")
    declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    if (
        declaration.get("schema_version") != design.SCHEMA_VERSION
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("authorization", {}).get("physical_execution_authorized")
        is not False
    ):
        raise RuntimeError("QSDK_R23D8_DECLARATION_IDENTITY")
    pure = design.run_zero_world_preflight()

    # R23D6's state/command constructors are retained only as already-audited
    # zero-world production shapes for the unchanged BW5R-B turning source.
    from . import qsdk_r23d6_policy_compatible_restoration as prior_shape

    signed_arms: list[dict[str, Any]] = []
    for arm_id, measured_heading in (
        ("positive_heading", 0.2),
        ("negative_heading", -0.2),
    ):
        core = LocomotionCore()
        compiled, profile = base._compile_boundary(core)
        state = prior_shape._production_state(compiled, measured_heading)
        observations = state["ordered_joint_observations"]
        canaries = declaration["independent_oracle_canaries"]
        for index, observation in enumerate(observations):
            canary = canaries[index % len(canaries)]
            observation["position_rad"] = canary["measured_position_rad"]
            observation["velocity_rad_s"] = canary["measured_velocity_rad_s"]
        output = core.balanced_wave_policy_step(
            SUPPORTED_POLICY_ID,
            {
                "descriptor": bridge.s169_descriptor(),
                "memory": core.balanced_wave_initial_memory(),
                "state": state,
                "command": prior_shape._production_command(arm_id),
            },
        )
        actuation = output["actuation"]
        robot = _ZeroWorldRobot(core, compiled)
        memory = TerminalRestorationMemory()
        composed = terminal_restoration_composition(
            robot,
            actuation,
            profile,
            state,
            {site_id: True for site_id in compiled["morphology"]["ordered_contact_site_ids"]},
            prior_shape._production_kinematics(compiled),
            memory,
        )
        receipt = composed["terminal_receipt"]
        failures = terminal_receipt_failures(
            receipt, composed["canonical_actuation"], composed["host_mapping"]
        )
        transition_memory: dict[str, float] = {}
        failures.extend(
            _terminal_pose_memory_transition_failures(receipt, transition_memory)
        )
        if failures:
            raise RuntimeError(
                "QSDK_R23D8_PRODUCTION_COMPOSITION:" + ",".join(failures)
            )
        source_receipt = actuation["receipt"]
        signed_arms.append(
            {
                "arm_id": arm_id,
                "held_steering_fraction": float(
                    source_receipt["held_steering_fraction"]
                ),
                "source_actuator_command_count": len(actuation["ordered_commands"]),
                "terminal_solution_count": len(receipt["ordered_actuator_solutions"]),
                "canonical_command_count": len(
                    composed["canonical_actuation"]["ordered_commands"]
                ),
                "host_command_count": len(composed["host_mapping"]["ordered_commands"]),
                "source_forward_velocity_member_present": (
                    FORWARD_VELOCITY_RECEIPT_MEMBER in source_receipt
                ),
                "source_receipt_member_names": sorted(source_receipt),
                "neutral_target_activation_count": receipt[
                    "neutral_target_activation_count"
                ],
                "terminal_receipt_complete": True,
            }
        )

    mutation_ids = declaration["required_mutation_controls"]
    return {
        "schema_version": "sporespore_qsdk_r23d8_neutral_stance_composition_preflight_v1",
        "ok": True,
        "gate_id": GATE_ID,
        "policy_id": RESTORATION_POLICY_ID,
        "algebra": {
            "canary_count": pure["canary_count"],
            "mutation_control_count": pure["mutation_control_count"],
            "mutation_controls_rejected": {item: True for item in mutation_ids},
        },
        "signed_arm_count": len(signed_arms),
        "signed_arms": signed_arms,
        "production_restoration_composition_complete_count": len(signed_arms),
        "source_actuator_command_count": sum(
            item["source_actuator_command_count"] for item in signed_arms
        ),
        "terminal_solution_count": sum(
            item["terminal_solution_count"] for item in signed_arms
        ),
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "command_conditioned_turning": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    print(json.dumps(run_zero_world_preflight(), allow_nan=False, sort_keys=True))
