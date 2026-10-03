"""Pure zero-world authority-floor oracle for prospective QSDK-R23D13.

R23D13 preserves R23D10's temporal state machine and R23D11's complete
eight-actuator neutral-plus-stability command. It changes only the final
active scalar: the command may not taper below a deterministic floor derived
from command-time support, torso tilt, and maximum joint-position error.

This module constructs no adapter, model, controller, selector, or physics
world. It never receives an arm identity, heading command, or outcome label.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Sequence

try:  # Support both package tests and direct zero-world invocation.
    from . import r23d10_quiescent_taper as temporal
except ImportError:  # pragma: no cover - direct invocation route
    import r23d10_quiescent_taper as temporal


GATE_ID = "QSDK-R23D13"
POLICY_ID = "sporespore_residual_pose_authority_quiescent_taper_v1"
INHERITED_COMPOSITION_POLICY_ID = (
    "sporespore_support_centroid_assisted_quiescent_taper_v1"
)

ACTUATOR_COUNT = temporal.ACTUATOR_COUNT
SCALE_DENOMINATOR = temporal.SCALE_DENOMINATOR
MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S = 0.425
NUMERICAL_CEILING_TOLERANCE = 1.0e-12


class ContractError(ValueError):
    """Raised when an input violates the prospective R23D13 contract."""


@dataclass(frozen=True)
class PoseFeedback:
    """State measured at the active command-composition boundary."""

    contacts: tuple[bool, bool, bool, bool]
    torso_tilt_rad: float
    maximum_absolute_joint_position_error_rad: float


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))


def _validate_feedback(feedback: PoseFeedback) -> None:
    if len(feedback.contacts) != 4:
        raise ContractError("R23D13_CONTACT_SHAPE_INVALID")
    if not all(isinstance(value, bool) for value in feedback.contacts):
        raise ContractError("R23D13_CONTACT_TYPE_INVALID")
    measurements = (
        feedback.torso_tilt_rad,
        feedback.maximum_absolute_joint_position_error_rad,
    )
    if not all(_finite(value) and float(value) >= 0.0 for value in measurements):
        raise ContractError("R23D13_POSE_MEASUREMENT_INVALID")


def _channel_floor_numerator(
    value: float,
    tight_limit: float,
    coarse_limit: float,
) -> int:
    normalized_excess = _clamp(
        (value - tight_limit) / (coarse_limit - tight_limit),
        0.0,
        1.0,
    )
    scaled = float(SCALE_DENOMINATOR) * normalized_excess
    return int(math.ceil(scaled - NUMERICAL_CEILING_TOLERANCE))


def pose_authority_floor(feedback: PoseFeedback) -> dict[str, Any]:
    """Derive the bounded residual-pose authority floor without physics."""

    _validate_feedback(feedback)
    all_four_contacts = all(feedback.contacts)
    if all_four_contacts:
        tilt_numerator = _channel_floor_numerator(
            float(feedback.torso_tilt_rad),
            temporal.TIGHT_MAXIMUM_TILT_RAD,
            temporal.COARSE_MAXIMUM_TILT_RAD,
        )
        joint_numerator = _channel_floor_numerator(
            float(feedback.maximum_absolute_joint_position_error_rad),
            temporal.TIGHT_MAXIMUM_JOINT_ERROR_RAD,
            temporal.COARSE_MAXIMUM_JOINT_ERROR_RAD,
        )
        floor_numerator = max(1, tilt_numerator, joint_numerator)
        if tilt_numerator > joint_numerator:
            controlling_input = "torso_tilt"
        elif joint_numerator > tilt_numerator:
            controlling_input = "maximum_joint_position_error"
        elif floor_numerator == 1:
            controlling_input = "tight_pose_minimum"
        else:
            controlling_input = "equal_pose_channels"
    else:
        tilt_numerator = 0
        joint_numerator = 0
        floor_numerator = SCALE_DENOMINATOR
        controlling_input = "incomplete_support_full_authority"

    return {
        "schema_version": "sporespore_qsdk_r23d13_pose_authority_floor_v1",
        "gate_id": GATE_ID,
        "policy_id": POLICY_ID,
        "all_four_contacts": all_four_contacts,
        "command_time_torso_tilt_rad": float(feedback.torso_tilt_rad),
        "command_time_maximum_absolute_joint_position_error_rad": float(
            feedback.maximum_absolute_joint_position_error_rad
        ),
        "tilt_floor_numerator": tilt_numerator,
        "joint_error_floor_numerator": joint_numerator,
        "pose_authority_floor_numerator": floor_numerator,
        "pose_authority_floor_denominator": SCALE_DENOMINATOR,
        "controlling_input": controlling_input,
        "arm_identity_or_heading_sign_used": False,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def _ordered_ids(actuator_ids: Sequence[str]) -> tuple[str, ...]:
    ordered = tuple(actuator_ids)
    if (
        len(ordered) != ACTUATOR_COUNT
        or any(not isinstance(value, str) or not value for value in ordered)
        or len(set(ordered)) != ACTUATOR_COUNT
    ):
        raise ContractError("R23D13_ACTUATOR_ORDER_INVALID")
    return ordered


def _validate_temporal_fraction(
    mode: str,
    numerator: int,
    denominator: int,
) -> None:
    if mode not in (
        temporal.ACTIVE_MODE,
        temporal.TAPER_MODE,
        temporal.PASSIVE_MODE,
    ):
        raise ContractError("R23D13_MODE_INVALID")
    if (
        isinstance(numerator, bool)
        or not isinstance(numerator, int)
        or isinstance(denominator, bool)
        or not isinstance(denominator, int)
        or denominator != SCALE_DENOMINATOR
    ):
        raise ContractError("R23D13_TEMPORAL_FRACTION_INVALID")
    valid = (
        (mode == temporal.ACTIVE_MODE and numerator == SCALE_DENOMINATOR)
        or (mode == temporal.TAPER_MODE and 1 <= numerator <= SCALE_DENOMINATOR)
        or (mode == temporal.PASSIVE_MODE and numerator == 0)
    )
    if not valid:
        raise ContractError("R23D13_TEMPORAL_FRACTION_INVALID")


def apply_residual_pose_authority(
    *,
    mode: str,
    temporal_scale_numerator: int,
    temporal_scale_denominator: int,
    feedback: PoseFeedback,
    actuator_ids: Sequence[str],
    combined_pre_taper_velocities_rad_s: Sequence[float | None],
) -> dict[str, Any]:
    """Apply the feedback floor once to the complete whole-body command."""

    _validate_feedback(feedback)
    ordered_ids = _ordered_ids(actuator_ids)
    _validate_temporal_fraction(
        mode,
        temporal_scale_numerator,
        temporal_scale_denominator,
    )
    combined = tuple(combined_pre_taper_velocities_rad_s)
    if len(combined) != ACTUATOR_COUNT:
        raise ContractError("R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID")

    if mode == temporal.PASSIVE_MODE:
        if any(value is not None for value in combined):
            raise ContractError("R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT")
        floor_receipt: dict[str, Any] | None = None
        floor_numerator = 0
        applied_numerator = 0
        output_velocities = (0.0,) * ACTUATOR_COUNT
        recovery_invoked = False
    else:
        if not all(_finite(value) for value in combined):
            raise ContractError("R23D13_ACTIVE_VELOCITY_INVALID")
        numeric = tuple(float(value) for value in combined)  # type: ignore[arg-type]
        if any(
            abs(value) > MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S
            for value in numeric
        ):
            raise ContractError("R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND")
        floor_receipt = pose_authority_floor(feedback)
        floor_numerator = int(floor_receipt["pose_authority_floor_numerator"])
        applied_numerator = max(temporal_scale_numerator, floor_numerator)
        scale = float(applied_numerator) / float(SCALE_DENOMINATOR)
        output_velocities = tuple(value * scale for value in numeric)
        recovery_invoked = True

    return {
        "schema_version": "sporespore_qsdk_r23d13_residual_pose_authority_receipt_v1",
        "gate_id": GATE_ID,
        "policy_id": POLICY_ID,
        "inherited_composition_policy_id": INHERITED_COMPOSITION_POLICY_ID,
        "mode": mode,
        "temporal_scale_numerator": temporal_scale_numerator,
        "temporal_scale_denominator": temporal_scale_denominator,
        "pose_authority_floor_numerator": floor_numerator,
        "applied_scale_numerator": applied_numerator,
        "applied_scale_denominator": SCALE_DENOMINATOR,
        "pose_feedback": floor_receipt,
        "ordered_actuator_commands": [
            {
                "actuator_id": actuator_id,
                "combined_pre_taper_velocity_rad_s": (
                    float(source) if source is not None else None
                ),
                "final_canonical_velocity_rad_s": final,
            }
            for actuator_id, source, final in zip(
                ordered_ids, combined, output_velocities, strict=True
            )
        ],
        "residual_pose_recovery_invoked": recovery_invoked,
        "complete_combined_velocity_scaled_once_before_host_mapping": True,
        "authority_floor_never_reduces_temporal_authority": (
            applied_numerator >= temporal_scale_numerator
        ),
        "passive_mode_exact_zero_actuation": mode == temporal.PASSIVE_MODE,
        "arm_identity_or_heading_sign_used": False,
        "adapter_actuation_applied": False,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    """Exercise ten declared algebra, symmetry, and passivity canaries."""

    ids = tuple(f"actuator_{index}" for index in range(ACTUATOR_COUNT))
    velocities = (0.2, -0.1, 0.3, -0.2, 0.1, -0.3, 0.4, -0.4)
    tight = PoseFeedback((True, True, True, True), 0.005, 0.1)
    halfway_tilt = PoseFeedback((True, True, True, True), 0.0225, 0.1)
    halfway_joint = PoseFeedback((True, True, True, True), 0.005, 0.26)
    joint_dominant = PoseFeedback((True, True, True, True), 0.015, 0.29)
    incomplete = PoseFeedback((True, True, False, True), 0.005, 0.1)
    negative_best = PoseFeedback(
        (True, True, True, True),
        0.02039827933466296,
        0.2375508558310486,
    )
    negative_final = PoseFeedback(
        (True, True, True, True),
        0.027166660831829642,
        0.2706423272295883,
    )

    active = apply_residual_pose_authority(
        mode=temporal.ACTIVE_MODE,
        temporal_scale_numerator=120,
        temporal_scale_denominator=120,
        feedback=tight,
        actuator_ids=ids,
        combined_pre_taper_velocities_rad_s=velocities,
    )
    raised = apply_residual_pose_authority(
        mode=temporal.TAPER_MODE,
        temporal_scale_numerator=2,
        temporal_scale_denominator=120,
        feedback=negative_best,
        actuator_ids=ids,
        combined_pre_taper_velocities_rad_s=velocities,
    )
    temporal_dominant = apply_residual_pose_authority(
        mode=temporal.TAPER_MODE,
        temporal_scale_numerator=100,
        temporal_scale_denominator=120,
        feedback=negative_best,
        actuator_ids=ids,
        combined_pre_taper_velocities_rad_s=velocities,
    )
    passive = apply_residual_pose_authority(
        mode=temporal.PASSIVE_MODE,
        temporal_scale_numerator=0,
        temporal_scale_denominator=120,
        feedback=negative_final,
        actuator_ids=ids,
        combined_pre_taper_velocities_rad_s=(None,) * ACTUATOR_COUNT,
    )

    checks = [
        pose_authority_floor(tight)["pose_authority_floor_numerator"] == 1,
        pose_authority_floor(halfway_tilt)["pose_authority_floor_numerator"] == 60,
        pose_authority_floor(halfway_joint)["pose_authority_floor_numerator"] == 60,
        pose_authority_floor(joint_dominant)["pose_authority_floor_numerator"] == 90,
        pose_authority_floor(incomplete)["pose_authority_floor_numerator"] == 120,
        active["applied_scale_numerator"] == 120
        and all(
            math.isclose(
                row["final_canonical_velocity_rad_s"], source, abs_tol=1.0e-15
            )
            for row, source in zip(
                active["ordered_actuator_commands"], velocities, strict=True
            )
        ),
        raised["pose_authority_floor_numerator"] == 50
        and raised["applied_scale_numerator"] == 50,
        temporal_dominant["applied_scale_numerator"] == 100,
        pose_authority_floor(negative_final)["pose_authority_floor_numerator"] == 83,
        passive["applied_scale_numerator"] == 0
        and not passive["residual_pose_recovery_invoked"]
        and all(
            row["final_canonical_velocity_rad_s"] == 0.0
            for row in passive["ordered_actuator_commands"]
        ),
    ]
    if not all(checks):
        raise ContractError("R23D13_ZERO_WORLD_CANARY_FAILED")
    return {
        "schema_version": "sporespore_qsdk_r23d13_zero_world_preflight_v1",
        "ok": True,
        "canary_count": len(checks),
        "new_tunable_gain_count": 0,
        "native_engine_route_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
    }


if __name__ == "__main__":
    import json

    print(json.dumps(run_zero_world_preflight(), allow_nan=False, sort_keys=True))
