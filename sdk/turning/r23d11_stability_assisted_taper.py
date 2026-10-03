"""Pure zero-world composition oracle for prospective QSDK-R23D11.

The successor retains R23D10's temporal handoff policy and changes only the
active terminal actuation composition.  It combines a bounded neutral stance
velocity with the already-versioned portable stability contribution, then
tapers that complete canonical velocity before host mapping.  No adapter,
model, physics world, arm identity, or heading sign enters this module.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Sequence

import r23d10_quiescent_taper as temporal


GATE_ID = "QSDK-R23D11"
POLICY_ID = "sporespore_support_centroid_assisted_quiescent_taper_v1"
STABILITY_POLICY_ID = "sporespore_scheduled_load_transfer_bw13p_a_v3"

ACTUATOR_COUNT = 8
AVAILABLE = "available"
OBSERVATION_UNAVAILABLE = "observation_unavailable"
PLANNING_INFEASIBLE = "planning_infeasible"
AVAILABILITY_VALUES = (AVAILABLE, OBSERVATION_UNAVAILABLE, PLANNING_INFEASIBLE)

GLOBAL_REQUESTED_CORRECTION_SCALE = 0.5
MAXIMUM_ABSOLUTE_STABILITY_VELOCITY_DELTA_RAD_S = 0.075
MAXIMUM_STABILITY_VELOCITY_SLEW_PER_STEP_RAD_S = 0.010
MAXIMUM_ABSOLUTE_NEUTRAL_VELOCITY_RAD_S = 0.35
MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S = 0.425
TAPER_DENOMINATOR = temporal.SCALE_DENOMINATOR
TOLERANCE = 1.0e-12


class ContractError(ValueError):
    """Raised when a caller violates the prospective composition contract."""


@dataclass(frozen=True)
class CompositionMemory:
    previous_semantic_step: int | None = None
    ordered_actuator_ids: tuple[str, ...] | None = None
    ordered_previous_applied_velocity_deltas_rad_s: tuple[float, ...] | None = None


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))


def _ordered_ids(actuator_ids: Sequence[str]) -> tuple[str, ...]:
    ordered = tuple(actuator_ids)
    if (
        len(ordered) != ACTUATOR_COUNT
        or any(not isinstance(value, str) or not value for value in ordered)
        or len(set(ordered)) != ACTUATOR_COUNT
    ):
        raise ContractError("R23D11_ACTUATOR_ORDER_INVALID")
    return ordered


def _numeric_vector(
    values: Sequence[float],
    *,
    count: int,
    code: str,
) -> tuple[float, ...]:
    result = tuple(values)
    if len(result) != count or not all(_finite(value) for value in result):
        raise ContractError(code)
    return tuple(float(value) for value in result)


def _previous(
    memory: CompositionMemory,
    semantic_step: int,
    ordered_ids: tuple[str, ...],
) -> tuple[float, ...]:
    parts = (
        memory.previous_semantic_step,
        memory.ordered_actuator_ids,
        memory.ordered_previous_applied_velocity_deltas_rad_s,
    )
    if parts == (None, None, None):
        return (0.0,) * ACTUATOR_COUNT
    if any(value is None for value in parts):
        raise ContractError("R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE")
    assert memory.previous_semantic_step is not None
    assert memory.ordered_actuator_ids is not None
    assert memory.ordered_previous_applied_velocity_deltas_rad_s is not None
    if memory.previous_semantic_step >= semantic_step:
        raise ContractError("R23D11_PREVIOUS_STEP_NOT_PREVIOUS")
    if memory.ordered_actuator_ids != ordered_ids:
        raise ContractError("R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID")
    return _numeric_vector(
        memory.ordered_previous_applied_velocity_deltas_rad_s,
        count=ACTUATOR_COUNT,
        code="R23D11_PREVIOUS_CORRECTION_INVALID",
    )


def compose_active_step(
    *,
    semantic_step: int,
    actuator_ids: Sequence[str],
    neutral_velocities_rad_s: Sequence[float],
    raw_stability_velocity_deltas_rad_s: Sequence[float | None],
    availability: str,
    taper_numerator: int,
    taper_denominator: int,
    memory: CompositionMemory = CompositionMemory(),
) -> tuple[CompositionMemory, dict[str, Any]]:
    """Compose one active neutral-plus-stability step without physics."""

    if isinstance(semantic_step, bool) or not isinstance(semantic_step, int) or semantic_step < 0:
        raise ContractError("R23D11_SEMANTIC_STEP_INVALID")
    ordered_ids = _ordered_ids(actuator_ids)
    neutral = _numeric_vector(
        neutral_velocities_rad_s,
        count=ACTUATOR_COUNT,
        code="R23D11_NEUTRAL_VELOCITY_INVALID",
    )
    if any(abs(value) > MAXIMUM_ABSOLUTE_NEUTRAL_VELOCITY_RAD_S for value in neutral):
        raise ContractError("R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND")
    if availability not in AVAILABILITY_VALUES:
        raise ContractError("R23D11_AVAILABILITY_INVALID")
    raw = tuple(raw_stability_velocity_deltas_rad_s)
    if len(raw) != ACTUATOR_COUNT:
        raise ContractError("R23D11_STABILITY_CORRECTION_COUNT_INVALID")
    available = availability == AVAILABLE
    if available:
        if not all(_finite(value) for value in raw):
            raise ContractError("R23D11_AVAILABLE_CORRECTION_INVALID")
        numeric_raw = tuple(float(value) for value in raw)  # type: ignore[arg-type]
    else:
        if any(value is not None for value in raw):
            raise ContractError("R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE")
        numeric_raw = (0.0,) * ACTUATOR_COUNT
    if (
        isinstance(taper_numerator, bool)
        or not isinstance(taper_numerator, int)
        or taper_numerator < 1
        or taper_numerator > TAPER_DENOMINATOR
        or taper_denominator != TAPER_DENOMINATOR
    ):
        raise ContractError("R23D11_TAPER_FRACTION_INVALID")

    previous = _previous(memory, semantic_step, ordered_ids)
    scale = float(taper_numerator) / float(taper_denominator)
    corrections: list[dict[str, Any]] = []
    applied_values: list[float] = []
    for actuator_id, neutral_value, raw_value, previous_value in zip(
        ordered_ids, neutral, numeric_raw, previous, strict=True
    ):
        if available:
            scaled_requested = raw_value * GLOBAL_REQUESTED_CORRECTION_SCALE
            magnitude_bounded = _clamp(
                scaled_requested,
                -MAXIMUM_ABSOLUTE_STABILITY_VELOCITY_DELTA_RAD_S,
                MAXIMUM_ABSOLUTE_STABILITY_VELOCITY_DELTA_RAD_S,
            )
            applied = _clamp(
                magnitude_bounded,
                previous_value - MAXIMUM_STABILITY_VELOCITY_SLEW_PER_STEP_RAD_S,
                previous_value + MAXIMUM_STABILITY_VELOCITY_SLEW_PER_STEP_RAD_S,
            )
            fallback_zeroed = False
        else:
            scaled_requested = None
            magnitude_bounded = 0.0
            applied = 0.0
            fallback_zeroed = True
        combined = neutral_value + applied
        if abs(combined) > MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S + TOLERANCE:
            raise ContractError("R23D11_COMBINED_VELOCITY_OUTSIDE_DERIVED_BOUND")
        tapered = combined * scale
        applied_values.append(applied)
        corrections.append(
            {
                "actuator_id": actuator_id,
                "neutral_velocity_rad_s": neutral_value,
                "raw_requested_stability_velocity_delta_rad_s": (
                    raw_value if available else None
                ),
                "scaled_requested_stability_velocity_delta_rad_s": scaled_requested,
                "magnitude_bounded_stability_velocity_delta_rad_s": magnitude_bounded,
                "applied_stability_velocity_delta_rad_s": applied,
                "combined_pre_taper_velocity_rad_s": combined,
                "final_tapered_canonical_velocity_rad_s": tapered,
                "magnitude_saturated": available and magnitude_bounded != scaled_requested,
                "slew_limited": available and applied != magnitude_bounded,
                "fallback_zeroed": fallback_zeroed,
            }
        )

    next_memory = CompositionMemory(
        previous_semantic_step=semantic_step,
        ordered_actuator_ids=ordered_ids,
        ordered_previous_applied_velocity_deltas_rad_s=tuple(applied_values),
    )
    return next_memory, {
        "schema_version": "sporespore_qsdk_r23d11_active_composition_receipt_v1",
        "gate_id": GATE_ID,
        "policy_id": POLICY_ID,
        "stability_policy_id": STABILITY_POLICY_ID,
        "semantic_step": semantic_step,
        "availability": availability,
        "global_requested_correction_scale": GLOBAL_REQUESTED_CORRECTION_SCALE,
        "taper_scale_numerator": taper_numerator,
        "taper_scale_denominator": taper_denominator,
        "ordered_actuator_composition": corrections,
        "fallback_applied": not available,
        "complete_combined_velocity_tapered_before_host_mapping": True,
        "arm_identity_or_heading_sign_used": False,
        "adapter_actuation_applied": False,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def compose_passive_step(actuator_ids: Sequence[str]) -> dict[str, Any]:
    """Return the exact irreversible passive receipt."""

    ordered_ids = _ordered_ids(actuator_ids)
    return {
        "schema_version": "sporespore_qsdk_r23d11_passive_composition_receipt_v1",
        "gate_id": GATE_ID,
        "policy_id": POLICY_ID,
        "ordered_actuator_commands": [
            {"actuator_id": actuator_id, "canonical_velocity_rad_s": 0.0}
            for actuator_id in ordered_ids
        ],
        "neutral_composition_invoked": False,
        "stability_composition_invoked": False,
        "native_actuation_application_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    """Exercise seven independent algebra/temporal canaries."""

    ids = tuple(f"actuator_{index}" for index in range(ACTUATOR_COUNT))
    neutral = (0.1,) * ACTUATOR_COUNT
    raw = (1.0,) * ACTUATOR_COUNT
    memory, first = compose_active_step(
        semantic_step=0,
        actuator_ids=ids,
        neutral_velocities_rad_s=neutral,
        raw_stability_velocity_deltas_rad_s=raw,
        availability=AVAILABLE,
        taper_numerator=120,
        taper_denominator=120,
    )
    second_memory, second = compose_active_step(
        semantic_step=1,
        actuator_ids=ids,
        neutral_velocities_rad_s=neutral,
        raw_stability_velocity_deltas_rad_s=raw,
        availability=AVAILABLE,
        taper_numerator=120,
        taper_denominator=120,
        memory=memory,
    )
    _, fallback = compose_active_step(
        semantic_step=2,
        actuator_ids=ids,
        neutral_velocities_rad_s=neutral,
        raw_stability_velocity_deltas_rad_s=(None,) * ACTUATOR_COUNT,
        availability=OBSERVATION_UNAVAILABLE,
        taper_numerator=120,
        taper_denominator=120,
        memory=second_memory,
    )
    _, half = compose_active_step(
        semantic_step=0,
        actuator_ids=ids,
        neutral_velocities_rad_s=neutral,
        raw_stability_velocity_deltas_rad_s=(0.02,) * ACTUATOR_COUNT,
        availability=AVAILABLE,
        taper_numerator=60,
        taper_denominator=120,
    )
    _, mirrored = compose_active_step(
        semantic_step=0,
        actuator_ids=ids,
        neutral_velocities_rad_s=tuple(-value for value in neutral),
        raw_stability_velocity_deltas_rad_s=tuple(-value for value in raw),
        availability=AVAILABLE,
        taper_numerator=120,
        taper_denominator=120,
    )
    passive = compose_passive_step(ids)
    tight = temporal.Observation((True, True, True, True), 0.005, 0.1)
    temporal_outcome = temporal.simulate([tight] * temporal.TERMINAL_STEPS)["outcome"]

    first_rows = first["ordered_actuator_composition"]
    second_rows = second["ordered_actuator_composition"]
    fallback_rows = fallback["ordered_actuator_composition"]
    half_rows = half["ordered_actuator_composition"]
    mirrored_rows = mirrored["ordered_actuator_composition"]
    checks = [
        all(row["applied_stability_velocity_delta_rad_s"] == 0.01 for row in first_rows),
        all(row["applied_stability_velocity_delta_rad_s"] == 0.02 for row in second_rows),
        fallback["fallback_applied"] and all(row["fallback_zeroed"] for row in fallback_rows),
        all(
            math.isclose(
                row["final_tapered_canonical_velocity_rad_s"],
                row["combined_pre_taper_velocity_rad_s"] * 0.5,
                rel_tol=0.0,
                abs_tol=TOLERANCE,
            )
            for row in half_rows
        ),
        all(
            math.isclose(
                left["final_tapered_canonical_velocity_rad_s"],
                -right["final_tapered_canonical_velocity_rad_s"],
                rel_tol=0.0,
                abs_tol=TOLERANCE,
            )
            for left, right in zip(first_rows, mirrored_rows, strict=True)
        ),
        passive["native_actuation_application_count"] == 0
        and all(row["canonical_velocity_rad_s"] == 0.0 for row in passive["ordered_actuator_commands"]),
        temporal_outcome["quiescent_taper_gate_passed"],
    ]
    if not all(checks):
        raise ContractError("R23D11_ZERO_WORLD_CANARY_FAILED")
    return {
        "schema_version": "sporespore_qsdk_r23d11_zero_world_preflight_v1",
        "ok": True,
        "canary_count": len(checks),
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
