"""Independent MuJoCo/Python zero-world mirror of the frozen R23D13 law.

This source contains no MuJoCo model, world, controller, selector, heading
command, or outcome input. It deliberately does not import the stage-zero
reference oracle. A future physical route must be implemented and qualified
under a later prospective boundary.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
import argparse
import json
import math
from typing import Any, Sequence


GATE_ID = "QSDK-R23D13"
CAMPAIGN_ID = (
    "QSDK-R23D13-RESIDUAL-POSE-AUTHORITY-QUIESCENT-TAPER-"
    "BILATERAL-TURN-DEVELOPMENT"
)
POLICY_ID = "sporespore_residual_pose_authority_quiescent_taper_v1"
ENGINE_ID = "mujoco"

ACTIVE_MODE = "active_neutral_acquisition"
TAPER_MODE = "active_quiescent_taper"
PASSIVE_MODE = "irreversible_zero_actuation_stability"
ACTUATOR_COUNT = 8
SCALE_DENOMINATOR = 120
TIGHT_MAXIMUM_TILT_RAD = 0.01
COARSE_MAXIMUM_TILT_RAD = 0.035
TIGHT_MAXIMUM_JOINT_ERROR_RAD = 0.2
COARSE_MAXIMUM_JOINT_ERROR_RAD = 0.32
MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S = 0.425
NUMERICAL_CEILING_TOLERANCE = 1.0e-12

EXPECTED_MUTATION_CODES = (
    "R23D13_CONTACT_SHAPE_INVALID",
    "R23D13_CONTACT_TYPE_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_MODE_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_ACTUATOR_ORDER_INVALID",
    "R23D13_ACTUATOR_ORDER_INVALID",
    "R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID",
    "R23D13_ACTIVE_VELOCITY_INVALID",
    "R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND",
    "R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT",
)


class NativeAuthorityError(ValueError):
    """Raised before any physical boundary on a native contract violation."""


@dataclass(frozen=True)
class NativeAuthorityInput:
    mode: Any
    temporal_scale_numerator: Any
    temporal_scale_denominator: Any
    contacts: tuple[Any, ...]
    torso_tilt_rad: Any
    maximum_absolute_joint_position_error_rad: Any
    actuator_ids: tuple[Any, ...]
    combined_pre_taper_velocities_rad_s: tuple[Any, ...]


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _channel_floor(value: float, tight: float, coarse: float) -> int:
    normalized = min(1.0, max(0.0, (value - tight) / (coarse - tight)))
    return int(
        math.ceil(
            float(SCALE_DENOMINATOR) * normalized
            - NUMERICAL_CEILING_TOLERANCE
        )
    )


def pose_authority_floor(value: NativeAuthorityInput) -> dict[str, Any]:
    if len(value.contacts) != 4:
        raise NativeAuthorityError("R23D13_CONTACT_SHAPE_INVALID")
    if not all(isinstance(item, bool) for item in value.contacts):
        raise NativeAuthorityError("R23D13_CONTACT_TYPE_INVALID")
    measurements = (
        value.torso_tilt_rad,
        value.maximum_absolute_joint_position_error_rad,
    )
    if not all(_finite(item) and float(item) >= 0.0 for item in measurements):
        raise NativeAuthorityError("R23D13_POSE_MEASUREMENT_INVALID")

    all_four = all(value.contacts)
    if all_four:
        tilt = _channel_floor(
            float(value.torso_tilt_rad),
            TIGHT_MAXIMUM_TILT_RAD,
            COARSE_MAXIMUM_TILT_RAD,
        )
        joint = _channel_floor(
            float(value.maximum_absolute_joint_position_error_rad),
            TIGHT_MAXIMUM_JOINT_ERROR_RAD,
            COARSE_MAXIMUM_JOINT_ERROR_RAD,
        )
        floor = max(1, tilt, joint)
        if tilt > joint:
            controlling = "torso_tilt"
        elif joint > tilt:
            controlling = "maximum_joint_position_error"
        elif floor == 1:
            controlling = "tight_pose_minimum"
        else:
            controlling = "equal_pose_channels"
    else:
        tilt = 0
        joint = 0
        floor = SCALE_DENOMINATOR
        controlling = "incomplete_support_full_authority"
    return {
        "tilt_floor_numerator": tilt,
        "joint_error_floor_numerator": joint,
        "pose_authority_floor_numerator": floor,
        "controlling_input": controlling,
        "all_four_contacts": all_four,
    }


def apply_residual_pose_authority(value: NativeAuthorityInput) -> dict[str, Any]:
    floor_receipt = pose_authority_floor(value)
    if value.mode not in (ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE):
        raise NativeAuthorityError("R23D13_MODE_INVALID")
    if (
        isinstance(value.temporal_scale_numerator, bool)
        or not isinstance(value.temporal_scale_numerator, int)
        or isinstance(value.temporal_scale_denominator, bool)
        or not isinstance(value.temporal_scale_denominator, int)
        or value.temporal_scale_denominator != SCALE_DENOMINATOR
    ):
        raise NativeAuthorityError("R23D13_TEMPORAL_FRACTION_INVALID")
    temporal_valid = (
        (value.mode == ACTIVE_MODE and value.temporal_scale_numerator == 120)
        or (
            value.mode == TAPER_MODE
            and 1 <= value.temporal_scale_numerator <= 120
        )
        or (value.mode == PASSIVE_MODE and value.temporal_scale_numerator == 0)
    )
    if not temporal_valid:
        raise NativeAuthorityError("R23D13_TEMPORAL_FRACTION_INVALID")
    if (
        len(value.actuator_ids) != ACTUATOR_COUNT
        or any(not isinstance(item, str) or not item for item in value.actuator_ids)
        or len(set(value.actuator_ids)) != ACTUATOR_COUNT
    ):
        raise NativeAuthorityError("R23D13_ACTUATOR_ORDER_INVALID")
    if len(value.combined_pre_taper_velocities_rad_s) != ACTUATOR_COUNT:
        raise NativeAuthorityError("R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID")

    if value.mode == PASSIVE_MODE:
        if any(
            item is not None
            for item in value.combined_pre_taper_velocities_rad_s
        ):
            raise NativeAuthorityError(
                "R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT"
            )
        floor = 0
        applied = 0
        outputs = (0.0,) * ACTUATOR_COUNT
        invoked = False
    else:
        if not all(
            _finite(item)
            for item in value.combined_pre_taper_velocities_rad_s
        ):
            raise NativeAuthorityError("R23D13_ACTIVE_VELOCITY_INVALID")
        numeric = tuple(
            float(item) for item in value.combined_pre_taper_velocities_rad_s
        )
        if any(
            abs(item) > MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S
            for item in numeric
        ):
            raise NativeAuthorityError("R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND")
        floor = int(floor_receipt["pose_authority_floor_numerator"])
        applied = max(value.temporal_scale_numerator, floor)
        outputs = tuple(item * applied / SCALE_DENOMINATOR for item in numeric)
        invoked = True
    return {
        "pose_feedback": floor_receipt if invoked else None,
        "pose_authority_floor_numerator": floor,
        "temporal_scale_numerator": value.temporal_scale_numerator,
        "applied_scale_numerator": applied,
        "final_canonical_velocities_rad_s": outputs,
        "residual_pose_recovery_invoked": invoked,
        "passive_mode_exact_zero_actuation": value.mode == PASSIVE_MODE,
    }


def _baseline() -> NativeAuthorityInput:
    return NativeAuthorityInput(
        mode=TAPER_MODE,
        temporal_scale_numerator=2,
        temporal_scale_denominator=120,
        contacts=(True, True, True, True),
        torso_tilt_rad=0.005,
        maximum_absolute_joint_position_error_rad=0.1,
        actuator_ids=tuple(f"actuator_{index}" for index in range(ACTUATOR_COUNT)),
        combined_pre_taper_velocities_rad_s=(
            0.2,
            -0.1,
            0.3,
            -0.2,
            0.1,
            -0.3,
            0.4,
            -0.4,
        ),
    )


def _canary_vector() -> tuple[str, dict[str, Any]]:
    base = _baseline()
    floor_inputs = (
        ("tight", base),
        ("halfway_tilt", replace(base, torso_tilt_rad=0.0225)),
        (
            "halfway_joint",
            replace(base, maximum_absolute_joint_position_error_rad=0.26),
        ),
        (
            "joint_dominant",
            replace(
                base,
                torso_tilt_rad=0.015,
                maximum_absolute_joint_position_error_rad=0.29,
            ),
        ),
        (
            "incomplete",
            replace(base, contacts=(True, True, False, True)),
        ),
    )
    lines: list[str] = []
    floors: dict[str, dict[str, Any]] = {}
    for label, item in floor_inputs:
        receipt = pose_authority_floor(item)
        floors[label] = receipt
        lines.append(
            "|".join(
                (
                    label,
                    str(receipt["tilt_floor_numerator"]),
                    str(receipt["joint_error_floor_numerator"]),
                    str(receipt["pose_authority_floor_numerator"]),
                    str(receipt["controlling_input"]),
                )
            )
        )

    negative_best = replace(
        base,
        torso_tilt_rad=0.02039827933466296,
        maximum_absolute_joint_position_error_rad=0.2375508558310486,
    )
    negative_final = replace(
        base,
        torso_tilt_rad=0.027166660831829642,
        maximum_absolute_joint_position_error_rad=0.2706423272295883,
    )
    active = apply_residual_pose_authority(
        replace(base, mode=ACTIVE_MODE, temporal_scale_numerator=120)
    )
    raised = apply_residual_pose_authority(negative_best)
    temporal = apply_residual_pose_authority(
        replace(negative_best, temporal_scale_numerator=100)
    )
    final_floor = pose_authority_floor(negative_final)
    passive = apply_residual_pose_authority(
        replace(
            negative_final,
            mode=PASSIVE_MODE,
            temporal_scale_numerator=0,
            combined_pre_taper_velocities_rad_s=(None,) * ACTUATOR_COUNT,
        )
    )
    lines.extend(
        (
            f"active|{active['pose_authority_floor_numerator']}|120|"
            f"{active['applied_scale_numerator']}",
            f"raised|{raised['pose_authority_floor_numerator']}|2|"
            f"{raised['applied_scale_numerator']}",
            f"temporal_dominant|{temporal['pose_authority_floor_numerator']}|100|"
            f"{temporal['applied_scale_numerator']}",
            "negative_final|"
            f"{final_floor['tilt_floor_numerator']}|"
            f"{final_floor['joint_error_floor_numerator']}|"
            f"{final_floor['pose_authority_floor_numerator']}|"
            f"{final_floor['controlling_input']}",
            f"passive|{passive['pose_authority_floor_numerator']}|0|"
            f"{passive['applied_scale_numerator']}",
        )
    )
    context = {
        "base": base,
        "floors": floors,
        "active": active,
        "raised": raised,
        "temporal": temporal,
        "final_floor": final_floor,
        "passive": passive,
    }
    return "\n".join(lines), context


def _mutations() -> tuple[NativeAuthorityInput, ...]:
    base = _baseline()
    return (
        replace(base, contacts=(True, True, True)),
        replace(base, contacts=(True, True, True, 1)),
        replace(base, torso_tilt_rad=math.nan),
        replace(base, torso_tilt_rad=-0.001),
        replace(base, maximum_absolute_joint_position_error_rad=math.inf),
        replace(base, maximum_absolute_joint_position_error_rad=-0.001),
        replace(base, mode="negative_heading_recovery"),
        replace(base, mode=ACTIVE_MODE, temporal_scale_numerator=119),
        replace(base, temporal_scale_numerator=0),
        replace(base, temporal_scale_numerator=121),
        replace(base, temporal_scale_numerator=True),
        replace(base, temporal_scale_denominator=119),
        replace(base, temporal_scale_denominator=True),
        replace(
            base,
            mode=PASSIVE_MODE,
            temporal_scale_numerator=1,
            combined_pre_taper_velocities_rad_s=(None,) * ACTUATOR_COUNT,
        ),
        replace(base, actuator_ids=base.actuator_ids[:-1]),
        replace(base, actuator_ids=base.actuator_ids[:-1] + (base.actuator_ids[0],)),
        replace(
            base,
            combined_pre_taper_velocities_rad_s=(
                base.combined_pre_taper_velocities_rad_s[:-1]
            ),
        ),
        replace(
            base,
            combined_pre_taper_velocities_rad_s=(math.nan,)
            + base.combined_pre_taper_velocities_rad_s[1:],
        ),
        replace(
            base,
            combined_pre_taper_velocities_rad_s=(0.426,)
            + base.combined_pre_taper_velocities_rad_s[1:],
        ),
        replace(
            base,
            mode=PASSIVE_MODE,
            temporal_scale_numerator=0,
            combined_pre_taper_velocities_rad_s=(0.0,) * ACTUATOR_COUNT,
        ),
    )


def preflight() -> dict[str, Any]:
    vector, context = _canary_vector()
    codes: list[str] = []
    for mutation in _mutations():
        try:
            apply_residual_pose_authority(mutation)
        except NativeAuthorityError as error:
            codes.append(str(error))
        else:
            raise NativeAuthorityError("R23D13_MUTATION_UNEXPECTEDLY_ACCEPTED")
    if tuple(codes) != EXPECTED_MUTATION_CODES:
        raise NativeAuthorityError("R23D13_MUTATION_FAILURE_CODES_CHANGED")

    base = context["base"]
    active = context["active"]
    raised = context["raised"]
    passive = context["passive"]
    positive_regression = (
        context["floors"]["tight"]["pose_authority_floor_numerator"] == 1
        and all(
            math.isclose(actual, float(expected), abs_tol=1.0e-15)
            for actual, expected in zip(
                active["final_canonical_velocities_rad_s"],
                base.combined_pre_taper_velocities_rad_s,
                strict=True,
            )
        )
    )
    critical = (
        raised["pose_authority_floor_numerator"] == 50
        and raised["applied_scale_numerator"] == 50
        and context["final_floor"]["pose_authority_floor_numerator"] == 83
    )
    passive_zero = (
        passive["applied_scale_numerator"] == 0
        and not passive["residual_pose_recovery_invoked"]
        and all(item == 0.0 for item in passive["final_canonical_velocities_rad_s"])
    )
    if not (positive_regression and critical and passive_zero):
        raise NativeAuthorityError("R23D13_NATIVE_CANARY_FAILED")
    return {
        "schema_version": "sporespore_qsdk_r23d13_native_authority_preflight_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "policy_id": POLICY_ID,
        "engine_id": ENGINE_ID,
        "language": "python",
        "valid_canary_count": 10,
        "mutation_control_count": len(codes),
        "valid_canary_vector": vector,
        "mutation_failure_codes": codes,
        "critical_r23d12_negative_shape_passed": critical,
        "positive_tight_pose_no_regression_canary_passed": positive_regression,
        "passive_exact_zero_actuation_canary_passed": passive_zero,
        "reference_oracle_imported": False,
        "physical_worker_implemented": False,
        "physical_execution_authorized": False,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _failure(code: str) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r23d13_native_authority_failure_v1",
        "engine_id": ENGINE_ID,
        "failure_stage": "before_model",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight", "physical"))
    args = parser.parse_args(argv)
    if args.command == "physical":
        print(
            "QSDK_R23D13_MUJOCO_AUTHORITY_FAILURE ",
            json.dumps(
                _failure("QSDK_R23D13_MJC_PHYSICAL_ROUTE_NOT_IMPLEMENTED"),
                sort_keys=True,
                separators=(",", ":"),
            ),
            sep="",
        )
        return 1
    try:
        receipt = preflight()
    except NativeAuthorityError as error:
        print(
            "QSDK_R23D13_MUJOCO_AUTHORITY_FAILURE ",
            json.dumps(_failure(str(error)), sort_keys=True, separators=(",", ":")),
            sep="",
        )
        return 1
    print(
        "QSDK_R23D13_MUJOCO_AUTHORITY_PREFLIGHT ",
        json.dumps(receipt, sort_keys=True, separators=(",", ":")),
        sep="",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
