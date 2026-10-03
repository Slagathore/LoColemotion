"""Independent MuJoCo/Python composition mirror for QSDK-R23D11.

This module implements only canonical neutral-plus-stability composition and
reuses the already-frozen R23D10 temporal mirror as an inherited zero-world
canary. It imports no MuJoCo package and cannot construct a model or world.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import math
from typing import Any, Callable, Sequence

from . import qsdk_r23d10_quiescent_taper as temporal


CAMPAIGN_ID = (
    "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-"
    "BILATERAL-TURN-DEVELOPMENT"
)
GATE_ID = "QSDK-R23D11"
POLICY_ID = "sporespore_support_centroid_assisted_quiescent_taper_v1"
ACTUATOR_COUNT = 8
AVAILABLE = "available"
OBSERVATION_UNAVAILABLE = "observation_unavailable"
PLANNING_INFEASIBLE = "planning_infeasible"
AVAILABILITY_VALUES = (AVAILABLE, OBSERVATION_UNAVAILABLE, PLANNING_INFEASIBLE)
GLOBAL_SCALE = 0.5
MAXIMUM_STABILITY_DELTA = 0.075
MAXIMUM_STABILITY_SLEW = 0.010
MAXIMUM_NEUTRAL_VELOCITY = 0.35
MAXIMUM_COMBINED_VELOCITY = 0.425
TAPER_DENOMINATOR = 120
TOLERANCE = 1.0e-12


class NativeContractError(ValueError):
    """Raised before any physical boundary when composition is malformed."""


@dataclass(frozen=True)
class CompositionMemory:
    previous_semantic_step: int | None = None
    ordered_actuator_ids: tuple[str, ...] | None = None
    previous_applied_velocity_deltas: tuple[float, ...] | None = None


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))


def _ids(values: Sequence[str]) -> tuple[str, ...]:
    result = tuple(values)
    if (
        len(result) != ACTUATOR_COUNT
        or len(set(result)) != ACTUATOR_COUNT
        or any(not isinstance(value, str) or not value for value in result)
    ):
        raise NativeContractError("R23D11_ACTUATOR_ORDER_INVALID")
    return result


def _vector(values: Sequence[float], code: str) -> tuple[float, ...]:
    result = tuple(values)
    if len(result) != ACTUATOR_COUNT or not all(_finite(value) for value in result):
        raise NativeContractError(code)
    return tuple(float(value) for value in result)


def _previous(
    memory: CompositionMemory,
    semantic_step: int,
    actuator_ids: tuple[str, ...],
) -> tuple[float, ...]:
    parts = (
        memory.previous_semantic_step,
        memory.ordered_actuator_ids,
        memory.previous_applied_velocity_deltas,
    )
    if parts == (None, None, None):
        return (0.0,) * ACTUATOR_COUNT
    if any(value is None for value in parts):
        raise NativeContractError("R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE")
    assert memory.previous_semantic_step is not None
    assert memory.ordered_actuator_ids is not None
    assert memory.previous_applied_velocity_deltas is not None
    if memory.previous_semantic_step >= semantic_step:
        raise NativeContractError("R23D11_PREVIOUS_STEP_NOT_PREVIOUS")
    if memory.ordered_actuator_ids != actuator_ids:
        raise NativeContractError("R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID")
    return _vector(
        memory.previous_applied_velocity_deltas,
        "R23D11_PREVIOUS_CORRECTION_INVALID",
    )


def compose_active_step(
    *,
    semantic_step: int,
    actuator_ids: Sequence[str],
    neutral_velocities: Sequence[float],
    raw_stability_deltas: Sequence[float | None],
    availability: str,
    taper_numerator: int,
    taper_denominator: int,
    memory: CompositionMemory = CompositionMemory(),
) -> tuple[CompositionMemory, dict[str, Any]]:
    if isinstance(semantic_step, bool) or not isinstance(semantic_step, int) or semantic_step < 0:
        raise NativeContractError("R23D11_SEMANTIC_STEP_INVALID")
    ordered_ids = _ids(actuator_ids)
    neutral = _vector(neutral_velocities, "R23D11_NEUTRAL_VELOCITY_INVALID")
    if any(abs(value) > MAXIMUM_NEUTRAL_VELOCITY for value in neutral):
        raise NativeContractError("R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND")
    if availability not in AVAILABILITY_VALUES:
        raise NativeContractError("R23D11_AVAILABILITY_INVALID")
    raw = tuple(raw_stability_deltas)
    if len(raw) != ACTUATOR_COUNT:
        raise NativeContractError("R23D11_STABILITY_CORRECTION_COUNT_INVALID")
    available = availability == AVAILABLE
    if available:
        if not all(_finite(value) for value in raw):
            raise NativeContractError("R23D11_AVAILABLE_CORRECTION_INVALID")
        numeric_raw = tuple(float(value) for value in raw)  # type: ignore[arg-type]
    else:
        if any(value is not None for value in raw):
            raise NativeContractError("R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE")
        numeric_raw = (0.0,) * ACTUATOR_COUNT
    if (
        isinstance(taper_numerator, bool)
        or not isinstance(taper_numerator, int)
        or taper_numerator < 1
        or taper_numerator > TAPER_DENOMINATOR
        or taper_denominator != TAPER_DENOMINATOR
    ):
        raise NativeContractError("R23D11_TAPER_FRACTION_INVALID")

    previous = _previous(memory, semantic_step, ordered_ids)
    taper_scale = float(taper_numerator) / float(taper_denominator)
    applied_values: list[float] = []
    final_values: list[float] = []
    rows: list[dict[str, Any]] = []
    for actuator_id, neutral_value, raw_value, previous_value in zip(
        ordered_ids, neutral, numeric_raw, previous, strict=True
    ):
        if available:
            scaled = raw_value * GLOBAL_SCALE
            magnitude = _clamp(scaled, -MAXIMUM_STABILITY_DELTA, MAXIMUM_STABILITY_DELTA)
            applied = _clamp(
                magnitude,
                previous_value - MAXIMUM_STABILITY_SLEW,
                previous_value + MAXIMUM_STABILITY_SLEW,
            )
        else:
            scaled = None
            magnitude = 0.0
            applied = 0.0
        combined = neutral_value + applied
        if abs(combined) > MAXIMUM_COMBINED_VELOCITY + TOLERANCE:
            raise NativeContractError("R23D11_COMBINED_VELOCITY_OUTSIDE_DERIVED_BOUND")
        final = combined * taper_scale
        applied_values.append(applied)
        final_values.append(final)
        rows.append(
            {
                "actuator_id": actuator_id,
                "neutral_velocity_rad_s": neutral_value,
                "raw_stability_velocity_delta_rad_s": raw_value if available else None,
                "scaled_stability_velocity_delta_rad_s": scaled,
                "magnitude_bounded_stability_velocity_delta_rad_s": magnitude,
                "applied_stability_velocity_delta_rad_s": applied,
                "combined_pre_taper_velocity_rad_s": combined,
                "final_tapered_canonical_velocity_rad_s": final,
                "fallback_zeroed": not available,
            }
        )
    return (
        CompositionMemory(semantic_step, ordered_ids, tuple(applied_values)),
        {
            "schema_version": "sporespore_qsdk_r23d11_mujoco_composition_receipt_v1",
            "semantic_step": semantic_step,
            "availability": availability,
            "ordered_actuator_composition": rows,
            "ordered_final_canonical_velocities_rad_s": final_values,
            "fallback_applied": not available,
            "host_mapping_applied": False,
            "model_construction_count": 0,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
    )


def compose_passive_step(actuator_ids: Sequence[str]) -> dict[str, Any]:
    return {
        "ordered_actuator_commands": [
            {"actuator_id": actuator_id, "canonical_velocity_rad_s": 0.0}
            for actuator_id in _ids(actuator_ids)
        ],
        "neutral_composition_invoked": False,
        "stability_composition_invoked": False,
        "native_actuation_application_count": 0,
        "physical_acceptance_authority": False,
    }


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise NativeContractError(code)


def _raises(code: str, action: Callable[[], object]) -> bool:
    try:
        action()
    except NativeContractError as error:
        return str(error) == code
    return False


def _call(**changes: object) -> tuple[CompositionMemory, dict[str, Any]]:
    values: dict[str, object] = {
        "semantic_step": 0,
        "actuator_ids": tuple(f"actuator_{index}" for index in range(8)),
        "neutral_velocities": (0.1,) * 8,
        "raw_stability_deltas": (1.0,) * 8,
        "availability": AVAILABLE,
        "taper_numerator": 120,
        "taper_denominator": 120,
    }
    values.update(changes)
    return compose_active_step(**values)  # type: ignore[arg-type]


def run_zero_world_preflight() -> tuple[int, int]:
    ids = tuple(f"actuator_{index}" for index in range(8))
    memory, first = _call()
    second_memory, second = _call(semantic_step=1, memory=memory)
    _, fallback = _call(
        semantic_step=2,
        memory=second_memory,
        availability=OBSERVATION_UNAVAILABLE,
        raw_stability_deltas=(None,) * 8,
    )
    _, half = _call(raw_stability_deltas=(0.02,) * 8, taper_numerator=60)
    _, mirrored = _call(
        neutral_velocities=(-0.1,) * 8,
        raw_stability_deltas=(-1.0,) * 8,
    )
    passive = compose_passive_step(ids)
    temporal_canaries, temporal_mutations = temporal.run_zero_world_preflight()
    first_rows = first["ordered_actuator_composition"]
    checks = (
        all(row["applied_stability_velocity_delta_rad_s"] == 0.01 for row in first_rows),
        all(
            row["applied_stability_velocity_delta_rad_s"] == 0.02
            for row in second["ordered_actuator_composition"]
        ),
        fallback["fallback_applied"]
        and all(row["fallback_zeroed"] for row in fallback["ordered_actuator_composition"]),
        all(
            math.isclose(
                row["final_tapered_canonical_velocity_rad_s"],
                row["combined_pre_taper_velocity_rad_s"] * 0.5,
                rel_tol=0.0,
                abs_tol=TOLERANCE,
            )
            for row in half["ordered_actuator_composition"]
        ),
        all(
            math.isclose(
                left["final_tapered_canonical_velocity_rad_s"],
                -right["final_tapered_canonical_velocity_rad_s"],
                rel_tol=0.0,
                abs_tol=TOLERANCE,
            )
            for left, right in zip(
                first_rows, mirrored["ordered_actuator_composition"], strict=True
            )
        ),
        passive["native_actuation_application_count"] == 0,
        temporal_canaries == 5 and temporal_mutations == 16,
    )
    _require(all(checks), "R23D11_MJC_CANARY_FAILED")

    reverse_ids = tuple(reversed(ids))
    mutations = (
        ("R23D11_ACTUATOR_ORDER_INVALID", lambda: _call(actuator_ids=ids[:-1])),
        ("R23D11_ACTUATOR_ORDER_INVALID", lambda: _call(actuator_ids=ids[:-1] + (ids[0],))),
        ("R23D11_NEUTRAL_VELOCITY_INVALID", lambda: _call(neutral_velocities=(0.1,) * 7)),
        ("R23D11_NEUTRAL_VELOCITY_INVALID", lambda: _call(neutral_velocities=(math.nan,) + (0.1,) * 7)),
        ("R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND", lambda: _call(neutral_velocities=(0.351,) + (0.1,) * 7)),
        ("R23D11_STABILITY_CORRECTION_COUNT_INVALID", lambda: _call(raw_stability_deltas=(1.0,) * 7)),
        ("R23D11_AVAILABLE_CORRECTION_INVALID", lambda: _call(raw_stability_deltas=(math.inf,) + (1.0,) * 7)),
        ("R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE", lambda: _call(availability=OBSERVATION_UNAVAILABLE)),
        ("R23D11_AVAILABILITY_INVALID", lambda: _call(availability="arm_specific")),
        ("R23D11_SEMANTIC_STEP_INVALID", lambda: _call(semantic_step=-1)),
        ("R23D11_TAPER_FRACTION_INVALID", lambda: _call(taper_numerator=0)),
        ("R23D11_TAPER_FRACTION_INVALID", lambda: _call(taper_numerator=121)),
        ("R23D11_TAPER_FRACTION_INVALID", lambda: _call(taper_denominator=119)),
        ("R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE", lambda: _call(memory=CompositionMemory(previous_semantic_step=0))),
        ("R23D11_PREVIOUS_STEP_NOT_PREVIOUS", lambda: _call(memory=CompositionMemory(0, ids, (0.0,) * 8))),
        ("R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID", lambda: _call(semantic_step=1, memory=CompositionMemory(0, reverse_ids, (0.0,) * 8))),
        ("R23D11_PREVIOUS_CORRECTION_INVALID", lambda: _call(semantic_step=1, memory=CompositionMemory(0, ids, (0.0,) * 7))),
        ("R23D11_PREVIOUS_CORRECTION_INVALID", lambda: _call(semantic_step=1, memory=CompositionMemory(0, ids, (math.nan,) + (0.0,) * 7))),
    )
    for code, action in mutations:
        _require(_raises(code, action), f"R23D11_MJC_MUTATION_FAILED_{code}")
    return len(checks), len(mutations)


def _validate_cell(stage_id: str, arm_id: str) -> None:
    valid = (
        stage_id == "mujoco_stability_assisted_taper_screen"
        and arm_id in ("positive_heading", "negative_heading")
    ) or (
        stage_id == "three_engine_confirmation"
        and arm_id in ("reference_zero", "positive_heading", "negative_heading")
    )
    _require(valid, "R23D11_MJC_CELL_IDENTITY_INVALID")


def preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    _validate_cell(stage_id, arm_id)
    canaries, mutations = run_zero_world_preflight()
    return {
        "schema_version": "sporespore_qsdk_r23d11_mujoco_composition_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": "mujoco",
        "stage_id": stage_id,
        "arm_id": arm_id,
        "composition_canary_count": canaries,
        "mutation_control_count": mutations,
        "inherited_temporal_canary_count": 5,
        "native_composition_mirror": True,
        "physical_worker_implemented": True,
        "physical_worker_dormant_behind_supervisor_authorization": True,
        "physical_execution_authorized": False,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    preflight_parser = commands.add_parser("preflight")
    for command_parser in (
        preflight_parser,
        commands.add_parser("authorization-preflight"),
        commands.add_parser("physical"),
    ):
        command_parser.add_argument("--stage-id", required=True)
        command_parser.add_argument("--arm-id", required=True)
        command_parser.add_argument("--source-commit", default="")
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "preflight":
            print(
                "QSDK_R23D11_MUJOCO_PREFLIGHT "
                + json.dumps(
                    preflight(arguments.stage_id, arguments.arm_id),
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
            return 0
        from . import qsdk_r23d11_stability_assisted_taper_physical as physical

        if arguments.command == "authorization-preflight":
            receipt = physical.authorization_preflight(
                arguments.stage_id,
                arguments.arm_id,
                arguments.source_commit,
            )
            print(
                "QSDK_R23D11_MUJOCO_AUTHORIZATION_PREFLIGHT "
                + json.dumps(
                    receipt,
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
            return 0
        report = physical.run_physical(
            arguments.stage_id,
            arguments.arm_id,
            arguments.source_commit,
        )
        print(
            "QSDK_R23D11_TERMINAL "
            + json.dumps(
                report,
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0
    except NativeContractError as error:
        print(
            "QSDK_R23D11_MUJOCO_FAILURE "
            + json.dumps({"failure_code": str(error)}, sort_keys=True)
        )
        return 1
    except Exception as error:
        try:
            from . import qsdk_r23d11_stability_assisted_taper_physical as physical

            if isinstance(error, physical.R23D11MujocoPhysicalError):
                if error.terminal_receipt is not None:
                    print(
                        "QSDK_R23D11_TERMINAL "
                        + json.dumps(
                            error.terminal_receipt,
                            allow_nan=False,
                            separators=(",", ":"),
                            sort_keys=True,
                        )
                    )
                else:
                    print(
                        "QSDK_R23D11_MUJOCO_FAILURE "
                        + json.dumps({"failure_code": str(error)}, sort_keys=True)
                    )
                return 1
        except Exception:
            pass
        raise


if __name__ == "__main__":
    raise SystemExit(main())
