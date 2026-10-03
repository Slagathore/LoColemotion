"""BW5R-B-compatible terminal restoration composition for QSDK-R23D6.

R23D5 correctly supplied a BW5R-B actuation receipt to a restorer originally
derived for BW15F-B.  That restorer unconditionally consumed BW15F-B's
``forward_velocity_foot_placement`` receipt member, so both Stage A workers
failed before producing a restoration receipt.  This module leaves the frozen
MV6 implementation untouched and derives the heading-preserving hip delta from
BW5R-B's registered linear bilateral stride transform.

The implementation accepts only the exact BW5R-B policy/profile pair.  An
unexpected forward-placement receipt member, a non-default stride transform,
or any non-finite/bounds defect fails closed.  It never constructs a MuJoCo
model or mutates native physics state.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import numpy as np

from . import selected_policy_development as bridge
from . import selected_policy_pose_hold_restoration_mv6 as mv6


SUPPORTED_POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
SUPPORTED_PROFILE_SCHEMA = "sporespore_balanced_wave_filtered_profile_v1"
REGISTERED_STEERING_STRIDE_TRANSFORM_ID: None = None
REGISTERED_TRANSFORM_NAME = "linear_bilateral_hip_stride_scale_v1"
FORWARD_VELOCITY_RECEIPT_MEMBER = "forward_velocity_foot_placement"
MAXIMUM_ABSOLUTE_STEERING_FRACTION = 0.4
MINIMUM_POSSIBLE_SCALE = 0.6
MAXIMUM_POSSIBLE_SCALE = 1.4
INDEPENDENT_ORACLE_TOLERANCE_RAD = 1.0e-12

RESTORATION_POLICY_ID = mv6.RESTORATION_POLICY_ID
DOWNWARD_SPEED_M_S = mv6.DOWNWARD_SPEED_M_S
DLS_LAMBDA_M = mv6.DLS_LAMBDA_M
MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S = (
    mv6.MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
)
POSE_POSITION_GAIN_PER_S = mv6.POSE_POSITION_GAIN_PER_S
POSE_RATE_DAMPING = mv6.POSE_RATE_DAMPING
PROFILE_ID = mv6.PROFILE_ID
MAXIMUM_ACQUISITION_STEPS = mv6.MAXIMUM_ACQUISITION_STEPS
REQUIRED_CONSECUTIVE_CONTACT_STEPS = mv6.REQUIRED_CONSECUTIVE_CONTACT_STEPS
TerminalRestorationMemory = mv6.TerminalRestorationMemory
_terminal_pose_memory_transition_failures = (
    mv6._terminal_pose_memory_transition_failures
)

SDK_ROOT = Path(__file__).resolve().parents[3]
DECLARATION_PATH = (
    SDK_ROOT / "turning" / "r23d6_policy_compatible_restoration_preregistration_v1.json"
)
EXPECTED_DECLARATION_SHA256 = (
    "sha256:14a7b6dd82a2642bb2f86b4caffdf87573d138e8410855619628c36f2eb63503"
)


def _finite_number(value: Any, code: str) -> float:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(float(value))
    ):
        raise RuntimeError(code)
    return float(value)


def _lateral_side_sign(limb_id: str) -> float:
    if limb_id in {"front_left", "rear_left"}:
        return -1.0
    if limb_id in {"front_right", "rear_right"}:
        return 1.0
    raise RuntimeError(f"QSDK_R23D6_BW5R_B_LIMB_ID:{limb_id}")


def _validate_policy_boundary(
    base_actuation: dict[str, Any],
    policy_profile: dict[str, Any],
    activation_held_steering_fraction: float,
) -> float:
    receipt = base_actuation.get("receipt")
    if not isinstance(receipt, dict):
        raise RuntimeError("QSDK_R23D6_BW5R_B_RECEIPT_SHAPE")
    if receipt.get("policy_id") != SUPPORTED_POLICY_ID:
        raise RuntimeError("QSDK_R23D6_BW5R_B_POLICY_ID")
    if FORWARD_VELOCITY_RECEIPT_MEMBER in receipt:
        raise RuntimeError("QSDK_R23D6_BW5R_B_UNEXPECTED_FORWARD_RECEIPT")
    if (
        not isinstance(policy_profile, dict)
        or policy_profile.get("schema_version") != SUPPORTED_PROFILE_SCHEMA
        or policy_profile.get("policy_id") != SUPPORTED_POLICY_ID
    ):
        raise RuntimeError("QSDK_R23D6_BW5R_B_PROFILE_IDENTITY")
    if policy_profile.get("steering_stride_transform_id") is not None:
        raise RuntimeError("QSDK_R23D6_BW5R_B_STRIDE_TRANSFORM")
    if policy_profile.get("forward_velocity_foot_placement_mode_id") is not None:
        raise RuntimeError("QSDK_R23D6_BW5R_B_FORWARD_MODE")

    current_held = _finite_number(
        receipt.get("held_steering_fraction"),
        "QSDK_R23D6_BW5R_B_CURRENT_HELD",
    )
    activation_held = _finite_number(
        activation_held_steering_fraction,
        "QSDK_R23D6_BW5R_B_ACTIVATION_HELD",
    )
    if (
        abs(current_held) > MAXIMUM_ABSOLUTE_STEERING_FRACTION
        or abs(activation_held) > MAXIMUM_ABSOLUTE_STEERING_FRACTION
    ):
        raise RuntimeError("QSDK_R23D6_BW5R_B_STEERING_FRACTION")
    return current_held


def independent_heading_target_delta_oracle(
    requested_target_position_rad: float,
    lateral_side_sign: float,
    current_held_steering_fraction: float,
    activation_held_steering_fraction: float,
) -> float:
    """Independent ratio-form oracle frozen by the R23D6 declaration."""

    requested = _finite_number(
        requested_target_position_rad,
        "QSDK_R23D6_BW5R_B_ORACLE_REQUESTED",
    )
    side_sign = _finite_number(
        lateral_side_sign,
        "QSDK_R23D6_BW5R_B_ORACLE_SIDE",
    )
    current_held = _finite_number(
        current_held_steering_fraction,
        "QSDK_R23D6_BW5R_B_ORACLE_CURRENT",
    )
    activation_held = _finite_number(
        activation_held_steering_fraction,
        "QSDK_R23D6_BW5R_B_ORACLE_ACTIVATION",
    )
    if side_sign not in {-1.0, 1.0}:
        raise RuntimeError("QSDK_R23D6_BW5R_B_ORACLE_SIDE")
    current_scale = 1.0 + side_sign * current_held
    activation_scale = 1.0 + side_sign * activation_held
    if (
        not math.isfinite(current_scale)
        or not math.isfinite(activation_scale)
        or not MINIMUM_POSSIBLE_SCALE <= current_scale <= MAXIMUM_POSSIBLE_SCALE
        or not MINIMUM_POSSIBLE_SCALE
        <= activation_scale
        <= MAXIMUM_POSSIBLE_SCALE
        or current_scale <= 0.0
    ):
        raise RuntimeError("QSDK_R23D6_BW5R_B_ORACLE_SCALE")
    result = requested * (1.0 - activation_scale / current_scale)
    if not math.isfinite(result):
        raise RuntimeError("QSDK_R23D6_BW5R_B_ORACLE_NONFINITE")
    return result


def portable_heading_target_delta(
    base_actuation: dict[str, Any],
    command: dict[str, Any],
    policy_profile: dict[str, Any],
    limb_id: str,
    joint_id: str,
    activation_held_steering_fraction: float,
) -> dict[str, float | None]:
    """Derive the BW5R-B hip delta without inventing a missing receipt field."""

    current_held = _validate_policy_boundary(
        base_actuation,
        policy_profile,
        activation_held_steering_fraction,
    )
    if not joint_id.endswith("_hip"):
        return {
            "delta_rad": 0.0,
            "lateral_side_sign": None,
            "forward_velocity_correction_rad": None,
            "nominal_unsteered_hip_target_rad": None,
            "independent_oracle_delta_rad": 0.0,
        }

    side_sign = _lateral_side_sign(limb_id)
    current_scale = 1.0 + side_sign * current_held
    if (
        not math.isfinite(current_scale)
        or not MINIMUM_POSSIBLE_SCALE <= current_scale <= MAXIMUM_POSSIBLE_SCALE
        or current_scale <= 0.0
    ):
        raise RuntimeError(f"QSDK_R23D6_BW5R_B_CURRENT_SCALE:{limb_id}")
    requested = _finite_number(
        command.get("requested_target_position_rad"),
        f"QSDK_R23D6_BW5R_B_REQUESTED_TARGET:{limb_id}",
    )
    nominal = requested / current_scale
    delta = nominal * side_sign * (
        current_held - float(activation_held_steering_fraction)
    )
    oracle = independent_heading_target_delta_oracle(
        requested,
        side_sign,
        current_held,
        activation_held_steering_fraction,
    )
    if (
        not math.isfinite(nominal)
        or not math.isfinite(delta)
        or abs(delta - oracle) > INDEPENDENT_ORACLE_TOLERANCE_RAD
    ):
        raise RuntimeError(f"QSDK_R23D6_BW5R_B_HEADING_ORACLE:{limb_id}")
    return {
        "delta_rad": delta,
        "lateral_side_sign": side_sign,
        # This is a derived policy fact, not a defaulted source-receipt value.
        "forward_velocity_correction_rad": 0.0,
        "nominal_unsteered_hip_target_rad": nominal,
        "independent_oracle_delta_rad": oracle,
    }


def terminal_restoration_composition(
    robot: Any,
    base_actuation: dict[str, Any],
    policy_profile: dict[str, Any],
    state: dict[str, Any],
    pre_step_contacts: dict[str, bool],
    ordered_kinematics: list[dict[str, Any]],
    memory: TerminalRestorationMemory,
) -> dict[str, Any]:
    """Compose the exact R23D6 restoration command without stepping physics."""

    actuator_ids = list(robot.morphology["ordered_actuator_ids"])
    if [item["actuator_id"] for item in ordered_kinematics] != actuator_ids:
        raise RuntimeError("QSDK_R23D6_RESTORATION_KINEMATIC_ORDER")
    receipt = base_actuation.get("receipt")
    if not isinstance(receipt, dict):
        raise RuntimeError("QSDK_R23D6_RESTORATION_RECEIPT_SHAPE")
    current_held = _validate_policy_boundary(
        base_actuation,
        policy_profile,
        (
            float(receipt["held_steering_fraction"])
            if memory.activation_held_steering_fraction is None
            else memory.activation_held_steering_fraction
        ),
    )
    if memory.activation_held_steering_fraction is None:
        memory.activation_held_steering_fraction = current_held
    activation_held = memory.activation_held_steering_fraction
    if activation_held is None:
        raise RuntimeError("QSDK_R23D6_RESTORATION_ACTIVATION_HELD")

    joint_by_id = {
        item["joint_id"]: item for item in state["ordered_joint_observations"]
    }
    command_by_actuator = {
        item["actuator_id"]: item for item in base_actuation["ordered_commands"]
    }
    actuator_by_id = {
        item["actuator_id"]: item for item in robot.spec["actuators"]
    }
    if set(command_by_actuator) != set(actuator_ids):
        raise RuntimeError("QSDK_R23D6_RESTORATION_COMMAND_IDENTITY")

    desired_foot_velocity = np.asarray(
        [0.0, -DOWNWARD_SPEED_M_S, 0.0], dtype=np.float64
    )
    desired_by_actuator: dict[str, float] = {}
    ordered_limb_solutions: list[dict[str, Any]] = []

    for limb in robot.spec["limbs"]:
        if len(limb["ordered_joint_ids"]) != 2 or len(
            limb["ordered_contact_site_ids"]
        ) != 1:
            raise RuntimeError(
                f"QSDK_R23D6_RESTORATION_LIMB_CARDINALITY:{limb['limb_id']}"
            )
        site_id = limb["ordered_contact_site_ids"][0]
        if site_id not in pre_step_contacts:
            raise RuntimeError(f"QSDK_R23D6_RESTORATION_CONTACT_SITE:{site_id}")
        contact = bool(pre_step_contacts[site_id])
        limb_kinematics = [
            item for item in ordered_kinematics if item["contact_site_id"] == site_id
        ]
        if len(limb_kinematics) != 2:
            raise RuntimeError(
                f"QSDK_R23D6_RESTORATION_KINEMATIC_CARDINALITY:{limb['limb_id']}"
            )
        columns = [
            np.cross(
                mv6._canonical_vector3(
                    item["joint_axis_world_unit"], "joint_axis_world_unit"
                ),
                mv6._canonical_vector3(item["endpoint_world_m"], "endpoint_world_m")
                - mv6._canonical_vector3(
                    item["joint_anchor_world_m"], "joint_anchor_world_m"
                ),
            )
            for item in limb_kinematics
        ]
        raw_missing: np.ndarray | None = None
        if not contact:
            jacobian = np.column_stack(columns)
            normal = jacobian.T @ jacobian + (DLS_LAMBDA_M**2) * np.eye(2)
            rhs = jacobian.T @ desired_foot_velocity
            raw_missing = np.linalg.solve(normal, rhs)
            if not np.all(np.isfinite(raw_missing)):
                raise RuntimeError(
                    f"QSDK_R23D6_RESTORATION_DLS_NONFINITE:{limb['limb_id']}"
                )

        actuator_solutions: list[dict[str, Any]] = []
        for index, kinematics in enumerate(limb_kinematics):
            actuator_id = kinematics["actuator_id"]
            actuator = actuator_by_id[actuator_id]
            observation = joint_by_id[actuator["joint_id"]]
            measured_position = _finite_number(
                observation.get("position_rad"),
                f"QSDK_R23D6_RESTORATION_POSITION:{actuator_id}",
            )
            measured_velocity = _finite_number(
                observation.get("velocity_rad_s"),
                f"QSDK_R23D6_RESTORATION_VELOCITY:{actuator_id}",
            )
            command = command_by_actuator[actuator_id]
            heading = portable_heading_target_delta(
                base_actuation,
                command,
                policy_profile,
                limb["limb_id"],
                actuator["joint_id"],
                activation_held,
            )
            if raw_missing is not None:
                memory.neutral_joint_position_by_actuator.pop(actuator_id, None)
                raw_velocity = float(raw_missing[index])
                desired_velocity = float(
                    np.clip(
                        raw_velocity,
                        -MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                        MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                    )
                )
                pose_capture = False
                neutral = requested = clamped = None
            else:
                pose_capture = (
                    actuator_id not in memory.neutral_joint_position_by_actuator
                )
                if pose_capture:
                    memory.neutral_joint_position_by_actuator[actuator_id] = (
                        measured_position - float(heading["delta_rad"])
                    )
                neutral = memory.neutral_joint_position_by_actuator[actuator_id]
                requested = neutral + float(heading["delta_rad"])
                clamped = float(
                    np.clip(
                        requested,
                        float(actuator["minimum_target_position_rad"]),
                        float(actuator["maximum_target_position_rad"]),
                    )
                )
                raw_velocity = POSE_POSITION_GAIN_PER_S * (
                    clamped - measured_position
                ) - POSE_RATE_DAMPING * measured_velocity
                desired_velocity = float(
                    np.clip(
                        raw_velocity,
                        -MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                        MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                    )
                )
            desired_by_actuator[actuator_id] = desired_velocity
            actuator_solutions.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": actuator["joint_id"],
                    "linear_jacobian_column_world_m": columns[index].tolist(),
                    "kinematics": copy.deepcopy(kinematics),
                    "measured_joint_position_rad": measured_position,
                    "measured_joint_velocity_rad_s": measured_velocity,
                    "minimum_target_position_rad": float(
                        actuator["minimum_target_position_rad"]
                    ),
                    "maximum_target_position_rad": float(
                        actuator["maximum_target_position_rad"]
                    ),
                    "pose_capture_activated": pose_capture,
                    "neutral_joint_position_rad": neutral,
                    "portable_lateral_side_sign": heading["lateral_side_sign"],
                    "portable_forward_velocity_hip_target_correction_rad": heading[
                        "forward_velocity_correction_rad"
                    ],
                    "portable_nominal_unsteered_hip_target_rad": heading[
                        "nominal_unsteered_hip_target_rad"
                    ],
                    "portable_heading_target_delta_rad": heading["delta_rad"],
                    "portable_independent_oracle_delta_rad": heading[
                        "independent_oracle_delta_rad"
                    ],
                    "requested_pose_target_position_rad": requested,
                    "clamped_pose_target_position_rad": clamped,
                    "unbounded_joint_velocity_rad_s": raw_velocity,
                    "desired_joint_velocity_rad_s": desired_velocity,
                }
            )
        ordered_limb_solutions.append(
            {
                "limb_id": limb["limb_id"],
                "contact_site_id": site_id,
                "pre_step_contact": contact,
                "desired_foot_velocity_world_m_s": (
                    [0.0, 0.0, 0.0]
                    if contact
                    else desired_foot_velocity.tolist()
                ),
                "ordered_actuator_solutions": actuator_solutions,
            }
        )

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
            not mv6._close(
                canonical_command["combined_canonical_target_velocity_rad_s"],
                desired,
                1.0e-12,
            )
            or not mv6._close(
                host_command["host_target_velocity_rad_s"], desired, 1.0e-12
            )
            or host_command["native_target_position_rad"] is not None
        ):
            raise RuntimeError(
                "QSDK_R23D6_RESTORATION_MAPPING:"
                f"{canonical_command['actuator_id']}"
            )

    terminal_receipt = {
        "schema_version": (
            "sporespore_contact_state_gated_pose_hold_heading_preserving_"
            "vertical_search_receipt_v1"
        ),
        "semantic_step": int(base_actuation["semantic_step"]),
        "policy_id": RESTORATION_POLICY_ID,
        "source_turning_policy_id": SUPPORTED_POLICY_ID,
        "source_receipt_forward_velocity_member_present": False,
        "missing_limb_desired_foot_velocity_world_m_s": [
            0.0,
            -DOWNWARD_SPEED_M_S,
            0.0,
        ],
        "contacting_limb_target_joint_velocity_mode": (
            "captured_pose_proportional_derivative_velocity_v1"
        ),
        "pose_hold_position_gain_per_s": POSE_POSITION_GAIN_PER_S,
        "pose_hold_rate_damping": POSE_RATE_DAMPING,
        "maximum_absolute_pose_hold_joint_velocity_rad_s": (
            MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        ),
        "heading_correction_mode": (
            "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        ),
        "heading_delta_derivation": REGISTERED_TRANSFORM_NAME,
        "activation_held_steering_fraction": activation_held,
        "current_held_steering_fraction": current_held,
        "registered_steering_stride_transform_id": (
            REGISTERED_STEERING_STRIDE_TRANSFORM_ID
        ),
        "damped_least_squares_lambda_m": DLS_LAMBDA_M,
        "maximum_absolute_search_joint_velocity_rad_s": (
            MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        ),
        "ordered_limb_solutions": ordered_limb_solutions,
        "pose_memory_actuator_count": len(
            memory.neutral_joint_position_by_actuator
        ),
        "world_build_count": 0,
        "physics_state_modified": False,
        "command_not_measurement": True,
        "physical_acceptance_authority": False,
    }
    bounded = [
        {
            "actuator_id": item["actuator_id"],
            "applied_velocity_delta_rad_s": float(
                item["canonical_velocity_delta_rad_s"]
            ),
        }
        for item in residuals
    ]
    return {
        "canonical_actuation": canonical,
        "host_mapping": host,
        "ordered_bounded_canonical_residuals": bounded,
        "terminal_receipt": terminal_receipt,
    }


def terminal_receipt_failures(
    receipt: dict[str, Any],
    canonical: dict[str, Any] | None = None,
    host: dict[str, Any] | None = None,
) -> list[str]:
    """Reuse MV6's structural verifier, then require R23D6 policy provenance."""

    failures = list(mv6._terminal_receipt_failures(receipt, canonical, host))
    if receipt.get("source_turning_policy_id") != SUPPORTED_POLICY_ID:
        failures.append("r23d6_source_turning_policy_id")
    if receipt.get("source_receipt_forward_velocity_member_present") is not False:
        failures.append("r23d6_forward_velocity_member_absence")
    if receipt.get("heading_delta_derivation") != REGISTERED_TRANSFORM_NAME:
        failures.append("r23d6_heading_delta_derivation")
    for limb in receipt.get("ordered_limb_solutions", []):
        for solution in limb.get("ordered_actuator_solutions", []):
            delta = solution.get("portable_heading_target_delta_rad")
            oracle = solution.get("portable_independent_oracle_delta_rad")
            if (
                not mv6._finite(delta)
                or not mv6._finite(oracle)
                or not mv6._close(delta, oracle, INDEPENDENT_ORACLE_TOLERANCE_RAD)
            ):
                failures.append(
                    "r23d6_independent_oracle:"
                    f"{solution.get('actuator_id', 'unknown')}"
                )
    return list(dict.fromkeys(failures))


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _policy_profile_fixture() -> dict[str, Any]:
    return {
        "schema_version": SUPPORTED_PROFILE_SCHEMA,
        "policy_id": SUPPORTED_POLICY_ID,
        "steering_stride_transform_id": None,
        "forward_velocity_foot_placement_mode_id": None,
        "physical_acceptance_authority": False,
    }


def _algebra_preflight(declaration: dict[str, Any]) -> dict[str, Any]:
    canary_results: list[dict[str, Any]] = []
    for canary in declaration["independent_oracle_canaries"]:
        side_sign = float(canary["lateral_side_sign"])
        limb_id = "front_right" if side_sign > 0.0 else "front_left"
        current = float(canary["current_held_steering_fraction"])
        activation = float(canary["activation_held_steering_fraction"])
        requested = float(canary["requested_target_position_rad"])
        expected = float(canary["expected_heading_target_delta_rad"])
        base_actuation = {
            "receipt": {
                "policy_id": SUPPORTED_POLICY_ID,
                "held_steering_fraction": current,
            }
        }
        observed = portable_heading_target_delta(
            base_actuation,
            {"requested_target_position_rad": requested},
            _policy_profile_fixture(),
            limb_id,
            f"{limb_id}_hip",
            activation,
        )
        knee = portable_heading_target_delta(
            base_actuation,
            {"requested_target_position_rad": 0.0},
            _policy_profile_fixture(),
            limb_id,
            f"{limb_id}_knee",
            activation,
        )
        if (
            abs(float(observed["delta_rad"]) - expected)
            > INDEPENDENT_ORACLE_TOLERANCE_RAD
            or abs(float(observed["independent_oracle_delta_rad"]) - expected)
            > INDEPENDENT_ORACLE_TOLERANCE_RAD
            or knee != {
                "delta_rad": 0.0,
                "lateral_side_sign": None,
                "forward_velocity_correction_rad": None,
                "nominal_unsteered_hip_target_rad": None,
                "independent_oracle_delta_rad": 0.0,
            }
        ):
            raise RuntimeError(f"QSDK_R23D6_ALGEBRA_CANARY:{canary['canary_id']}")
        canary_results.append(
            {
                "canary_id": canary["canary_id"],
                "observed_heading_target_delta_rad": observed["delta_rad"],
                "independent_oracle_delta_rad": observed[
                    "independent_oracle_delta_rad"
                ],
                "expected_heading_target_delta_rad": expected,
                "knee_heading_target_delta_rad": knee["delta_rad"],
                "passed": True,
            }
        )

    nonzero = next(
        canary
        for canary in declaration["independent_oracle_canaries"]
        if abs(float(canary["expected_heading_target_delta_rad"])) > 0.0
    )
    side = float(nonzero["lateral_side_sign"])
    current = float(nonzero["current_held_steering_fraction"])
    activation = float(nonzero["activation_held_steering_fraction"])
    requested = float(nonzero["requested_target_position_rad"])
    expected = float(nonzero["expected_heading_target_delta_rad"])
    nominal = float(nonzero["nominal_unsteered_hip_target_rad"])
    mutation_rejected = {
        "reversed_current_activation_difference": abs(
            nominal * side * (activation - current) - expected
        )
        > INDEPENDENT_ORACLE_TOLERANCE_RAD,
        "swapped_lateral_side_sign": abs(
            requested
            / (1.0 - side * current)
            * (-side)
            * (current - activation)
            - expected
        )
        > INDEPENDENT_ORACLE_TOLERANCE_RAD,
        "skipped_current_scale_inverse": abs(
            requested * side * (current - activation) - expected
        )
        > INDEPENDENT_ORACLE_TOLERANCE_RAD,
        "used_activation_scale_as_inverse_denominator": abs(
            requested
            / (1.0 + side * activation)
            * side
            * (current - activation)
            - expected
        )
        > INDEPENDENT_ORACLE_TOLERANCE_RAD,
        "applied_heading_delta_to_knee": abs(expected) > 0.0,
    }

    valid_actuation = {
        "receipt": {
            "policy_id": SUPPORTED_POLICY_ID,
            "held_steering_fraction": current,
        }
    }
    unexpected_forward = copy.deepcopy(valid_actuation)
    unexpected_forward["receipt"][FORWARD_VELOCITY_RECEIPT_MEMBER] = {
        "ordered_limb_corrections": []
    }
    wrong_policy = copy.deepcopy(valid_actuation)
    wrong_policy["receipt"]["policy_id"] = "sporespore_balanced_wave_bw15f_b_v1"
    wrong_transform = _policy_profile_fixture()
    wrong_transform["steering_stride_transform_id"] = "mutated_transform"
    structural_controls = {
        "read_or_defaulted_forward_velocity_foot_placement": (
            unexpected_forward,
            _policy_profile_fixture(),
        ),
        "accepted_non_bw5r_b_policy_identity": (
            wrong_policy,
            _policy_profile_fixture(),
        ),
        "accepted_unregistered_stride_transform": (
            valid_actuation,
            wrong_transform,
        ),
    }
    for control_id, (actuation, profile) in structural_controls.items():
        try:
            portable_heading_target_delta(
                actuation,
                {"requested_target_position_rad": requested},
                profile,
                "front_right" if side > 0.0 else "front_left",
                "front_right_hip" if side > 0.0 else "front_left_hip",
                activation,
            )
            mutation_rejected[control_id] = False
        except RuntimeError:
            mutation_rejected[control_id] = True

    required = declaration["required_oracle_mutation_controls"]
    if list(mutation_rejected) != required or not all(mutation_rejected.values()):
        raise RuntimeError("QSDK_R23D6_MUTATION_CONTROL")
    return {
        "canaries": canary_results,
        "canary_count": len(canary_results),
        "mutation_controls_rejected": mutation_rejected,
        "mutation_control_count": len(mutation_rejected),
    }


def _production_state(compiled: dict[str, Any], measured_heading_rad: float) -> dict[str, Any]:
    from . import qsdk_r23d2_heading_response as base

    state = base._state_for_canary(
        compiled,
        {
            "task_lateral_axis_world_unit": [0.0, 0.0, 1.0],
            "base_position_world_m": [0.0, 0.5, 0.0],
            "measured_heading_world_rad": measured_heading_rad,
            "base_linear_velocity_world_m_s": [0.0, 0.0, 0.0],
            "task_origin_world_m": [0.0, 0.5, 0.0],
            "reference_yaw_rad": 0.0,
        },
    )
    state["semantic_step"] = 2_992
    state["sample_time_s"] = 2_992 / 120.0
    return state


def _production_command(arm_id: str) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": f"qsdk_r23d6_zero_world_{arm_id}_terminal_restoration",
        "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
        "desired_heading_rad": 0.0,
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": "contact_gated",
        "valid_from_step": 2_992,
        "valid_through_step": 2_992,
        "authority": "test_fixture",
    }


def _production_kinematics(compiled: dict[str, Any]) -> list[dict[str, Any]]:
    spec = compiled["morphology"]["morphology_spec"]
    limb_by_joint = {
        joint_id: limb
        for limb in spec["limbs"]
        for joint_id in limb["ordered_joint_ids"]
    }
    actuator_by_id = {item["actuator_id"]: item for item in spec["actuators"]}
    ordered: list[dict[str, Any]] = []
    for index, actuator_id in enumerate(compiled["morphology"]["ordered_actuator_ids"]):
        actuator = actuator_by_id[actuator_id]
        limb = limb_by_joint[actuator["joint_id"]]
        is_hip = actuator["joint_id"].endswith("_hip")
        ordered.append(
            {
                "actuator_id": actuator_id,
                "contact_site_id": limb["ordered_contact_site_ids"][0],
                "joint_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                "endpoint_world_m": {
                    "x": 0.2 + 0.01 * index,
                    "y": -0.2,
                    "z": 0.0,
                },
                "joint_anchor_world_m": {
                    "x": 0.0 if is_hip else 0.1,
                    "y": 0.0 if is_hip else -0.1,
                    "z": 0.0,
                },
            }
        )
    return ordered


def run_zero_world_preflight() -> dict[str, Any]:
    """Exercise both signed production-shaped step-zero compositions."""

    if _raw_sha256(DECLARATION_PATH) != EXPECTED_DECLARATION_SHA256:
        raise RuntimeError("QSDK_R23D6_DECLARATION_HASH")
    declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    if (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d6_policy_compatible_restoration_preregistration_v1"
        or declaration.get("gate_id") != "QSDK-R23D6"
        or declaration.get("authorization", {}).get("physical_execution_authorized")
        is not False
    ):
        raise RuntimeError("QSDK_R23D6_DECLARATION_IDENTITY")
    algebra = _algebra_preflight(declaration)

    from sporespore_locomotion import LocomotionCore

    from . import qsdk_r23d2_heading_response as base

    signed_results: list[dict[str, Any]] = []
    for arm_id, measured_heading in (
        ("positive_heading", 0.2),
        ("negative_heading", -0.2),
    ):
        core = LocomotionCore()
        compiled, profile = base._compile_boundary(core)
        state = _production_state(compiled, measured_heading)
        output = core.balanced_wave_policy_step(
            SUPPORTED_POLICY_ID,
            {
                "descriptor": bridge.s169_descriptor(),
                "memory": core.balanced_wave_initial_memory(),
                "state": state,
                "command": _production_command(arm_id),
            },
        )
        actuation = output["actuation"]
        receipt = actuation["receipt"]
        if (
            actuation.get("safe_no_actuation") is not False
            or actuation.get("failure_codes") != []
            or receipt.get("controller_error") is not None
            or receipt.get("policy_id") != SUPPORTED_POLICY_ID
            or FORWARD_VELOCITY_RECEIPT_MEMBER in receipt
            or len(actuation.get("ordered_commands", [])) != 8
            or abs(float(receipt.get("held_steering_fraction", 0.0))) <= 0.0
        ):
            raise RuntimeError(f"QSDK_R23D6_PRODUCTION_ACTUATION:{arm_id}")

        spec = compiled["morphology"]["morphology_spec"]
        robot = SimpleNamespace(
            morphology=compiled["morphology"],
            spec=spec,
            descriptor=bridge.s169_descriptor(),
            core=core,
        )
        contacts = {
            contact_id: True
            for contact_id in compiled["morphology"]["ordered_contact_site_ids"]
        }
        composed = terminal_restoration_composition(
            robot,
            actuation,
            profile,
            state,
            contacts,
            _production_kinematics(compiled),
            TerminalRestorationMemory(),
        )
        terminal_receipt = composed["terminal_receipt"]
        failures = terminal_receipt_failures(
            terminal_receipt,
            composed["canonical_actuation"],
            composed["host_mapping"],
        )
        if failures:
            raise RuntimeError(
                f"QSDK_R23D6_PRODUCTION_TERMINAL_RECEIPT:{arm_id}:{failures}"
            )
        solutions = [
            solution
            for limb in terminal_receipt["ordered_limb_solutions"]
            for solution in limb["ordered_actuator_solutions"]
        ]
        if (
            len(solutions) != 8
            or len(composed["canonical_actuation"]["ordered_commands"]) != 8
            or len(composed["host_mapping"]["ordered_commands"]) != 8
            or any(
                abs(
                    float(solution["portable_heading_target_delta_rad"])
                    - float(solution["portable_independent_oracle_delta_rad"])
                )
                > INDEPENDENT_ORACLE_TOLERANCE_RAD
                for solution in solutions
            )
            or any(
                float(solution["portable_heading_target_delta_rad"]) != 0.0
                for solution in solutions
                if solution["joint_id"].endswith("_knee")
            )
        ):
            raise RuntimeError(f"QSDK_R23D6_PRODUCTION_SOLUTION:{arm_id}")
        signed_results.append(
            {
                "arm_id": arm_id,
                "measured_heading_rad": measured_heading,
                "requested_steering_fraction": receipt[
                    "requested_steering_fraction"
                ],
                "held_steering_fraction": receipt["held_steering_fraction"],
                "source_receipt_member_names": sorted(receipt),
                "source_forward_velocity_member_present": False,
                "source_actuator_command_count": len(actuation["ordered_commands"]),
                "terminal_solution_count": len(solutions),
                "canonical_command_count": len(
                    composed["canonical_actuation"]["ordered_commands"]
                ),
                "host_command_count": len(
                    composed["host_mapping"]["ordered_commands"]
                ),
                "terminal_receipt_complete": True,
            }
        )

    held = [float(result["held_steering_fraction"]) for result in signed_results]
    if not (held[0] > 0.0 and held[1] < 0.0):
        raise RuntimeError("QSDK_R23D6_SIGNED_HELD_STEERING")
    return {
        "schema_version": "sporespore_qsdk_r23d6_restoration_zero_world_preflight_v1",
        "gate_id": "QSDK-R23D6",
        "selected_policy_id": SUPPORTED_POLICY_ID,
        "morphology_id": "qsdk_r05_generated_s169",
        "declaration_sha256": EXPECTED_DECLARATION_SHA256,
        "algebra": algebra,
        "signed_arms": signed_results,
        "signed_arm_count": len(signed_results),
        "release_core_entrypoint": "LocomotionCore.balanced_wave_policy_step",
        "production_restoration_composition_complete_count": len(signed_results),
        "source_actuator_command_count": sum(
            result["source_actuator_command_count"] for result in signed_results
        ),
        "terminal_solution_count": sum(
            result["terminal_solution_count"] for result in signed_results
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
    print(json.dumps(run_zero_world_preflight(), sort_keys=True, allow_nan=False))
