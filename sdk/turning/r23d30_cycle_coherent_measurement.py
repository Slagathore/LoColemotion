"""Pure engine-neutral cycle-coherent directional-response measurement.

The oracle consumes already-observed yaw rows.  It creates no model or physics
world and has no engine identity input.  Complete 360-step scheduler cycles are
used so one gait phase cannot determine the result.
"""

from __future__ import annotations

import math
from typing import Any, Mapping, Sequence


ARMS = ("reference_zero", "positive_heading", "negative_heading")
ROW_COUNT = 2_992
BASELINE_START = 240
BASELINE_END = 600
TERMINAL_START = 1_440
TERMINAL_END = 1_800
SWING_STEPS = 72
CYCLE_STEPS = 360
SWING_COUNT = 5
MECHANISM_FLOOR_RAD = 0.01
ZERO_TOLERANCE_RAD = 1.0e-12
TWO_PI = 2.0 * math.pi


class CycleCoherentMeasurementError(RuntimeError):
    """The estimator configuration or synchronized trace rows are invalid."""


def phase_for_step(step: int) -> str:
    if step < 600:
        return "reference_warmup"
    if step < 1_800:
        return "commanded_turn"
    if step < 2_400:
        return "reference_recovery"
    return "reference_continuation"


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _validate_configuration() -> None:
    if (
        BASELINE_END - BASELINE_START != CYCLE_STEPS
        or TERMINAL_END - TERMINAL_START != CYCLE_STEPS
        or CYCLE_STEPS != SWING_STEPS * SWING_COUNT
        or not 0 <= BASELINE_START < BASELINE_END <= TERMINAL_START
        or TERMINAL_END > ROW_COUNT
        or MECHANISM_FLOOR_RAD <= 0.0
        or ZERO_TOLERANCE_RAD <= 0.0
    ):
        raise CycleCoherentMeasurementError("R23D30_WINDOW_CONFIGURATION_INVALID")


def _validated_yaw(rows: Sequence[Mapping[str, Any]], arm_id: str) -> list[float]:
    if len(rows) != ROW_COUNT:
        raise CycleCoherentMeasurementError(f"R23D30_ROW_COUNT_INVALID:{arm_id}")
    values: list[float] = []
    for expected_step, row in enumerate(rows):
        if (
            not isinstance(row, Mapping)
            or row.get("trace_step") != expected_step
            or row.get("phase_id") != phase_for_step(expected_step)
            or not _finite_number(row.get("measured_yaw_rad"))
        ):
            raise CycleCoherentMeasurementError(
                f"R23D30_SYNCHRONIZATION_INVALID:{arm_id}:{expected_step}"
            )
        values.append(float(row["measured_yaw_rad"]))
    return values


def unwrap_shortest_arc(values: Sequence[float]) -> list[float]:
    if not values or any(not _finite_number(value) for value in values):
        raise CycleCoherentMeasurementError("R23D30_YAW_SEQUENCE_INVALID")
    unwrapped = [float(values[0])]
    previous = float(values[0])
    for index, value in enumerate(values[1:], start=1):
        current = float(value)
        delta = math.remainder(current - previous, TWO_PI)
        if not math.isfinite(delta) or abs(abs(delta) - math.pi) <= ZERO_TOLERANCE_RAD:
            raise CycleCoherentMeasurementError(f"R23D30_YAW_UNWRAP_AMBIGUOUS:{index}")
        unwrapped.append(unwrapped[-1] + delta)
        previous = current
    return unwrapped


def _mean(values: Sequence[float]) -> float:
    if not values:
        raise CycleCoherentMeasurementError("R23D30_EMPTY_WINDOW")
    return math.fsum(values) / len(values)


def _arm_measurement(yaw: Sequence[float]) -> dict[str, Any]:
    unwrapped = unwrap_shortest_arc(yaw)
    baseline_mean = _mean(unwrapped[BASELINE_START:BASELINE_END])
    terminal_mean = _mean(unwrapped[TERMINAL_START:TERMINAL_END])
    swing_shifts = []
    for swing_index in range(SWING_COUNT):
        start = TERMINAL_START + swing_index * SWING_STEPS
        end = start + SWING_STEPS
        swing_shifts.append(_mean(unwrapped[start:end]) - baseline_mean)
    endpoint_delta = math.remainder(
        float(yaw[TERMINAL_END - 1]) - float(yaw[600]), TWO_PI
    )
    return {
        "baseline_cycle_mean_unwrapped_yaw_rad": baseline_mean,
        "terminal_cycle_mean_unwrapped_yaw_rad": terminal_mean,
        "cycle_shift_rad": terminal_mean - baseline_mean,
        "terminal_swing_shift_rad": swing_shifts,
        "legacy_endpoint_yaw_delta_rad": endpoint_delta,
    }


def measure_cycle_coherent_response(
    rows_by_arm: Mapping[str, Sequence[Mapping[str, Any]]],
) -> dict[str, Any]:
    """Measure and gate one synchronized reference/positive/negative triplet."""

    _validate_configuration()
    if set(rows_by_arm) != set(ARMS):
        raise CycleCoherentMeasurementError("R23D30_ARM_SET_INVALID")
    arms = {
        arm_id: _arm_measurement(_validated_yaw(rows_by_arm[arm_id], arm_id))
        for arm_id in ARMS
    }
    reference = arms["reference_zero"]
    positive = arms["positive_heading"]
    negative = arms["negative_heading"]
    positive_conditioned = (
        positive["cycle_shift_rad"] - reference["cycle_shift_rad"]
    )
    negative_conditioned = (
        reference["cycle_shift_rad"] - negative["cycle_shift_rad"]
    )
    positive_swing_conditioned = [
        positive["terminal_swing_shift_rad"][index]
        - reference["terminal_swing_shift_rad"][index]
        for index in range(SWING_COUNT)
    ]
    negative_swing_conditioned = [
        reference["terminal_swing_shift_rad"][index]
        - negative["terminal_swing_shift_rad"][index]
        for index in range(SWING_COUNT)
    ]
    raw_cycle_gate = (
        positive["cycle_shift_rad"] >= MECHANISM_FLOOR_RAD
        and negative["cycle_shift_rad"] <= -MECHANISM_FLOOR_RAD
    )
    conditioned_cycle_gate = (
        positive_conditioned >= MECHANISM_FLOOR_RAD
        and negative_conditioned >= MECHANISM_FLOOR_RAD
    )
    raw_swing_direction_gate = (
        all(
            value > ZERO_TOLERANCE_RAD
            for value in positive["terminal_swing_shift_rad"]
        )
        and all(
            value < -ZERO_TOLERANCE_RAD
            for value in negative["terminal_swing_shift_rad"]
        )
    )
    conditioned_swing_direction_gate = (
        all(value > ZERO_TOLERANCE_RAD for value in positive_swing_conditioned)
        and all(value > ZERO_TOLERANCE_RAD for value in negative_swing_conditioned)
    )
    gates = {
        "raw_signed_cycle_shift": raw_cycle_gate,
        "reference_conditioned_cycle_shift": conditioned_cycle_gate,
        "every_terminal_swing_raw_direction": raw_swing_direction_gate,
        "every_terminal_swing_reference_conditioned_direction": (
            conditioned_swing_direction_gate
        ),
    }
    return {
        "schema_version": "sporespore_qsdk_r23d30_cycle_coherent_measurement_v1",
        "measurement_configuration": {
            "yaw_unwrap_mode": "shortest_arc_continuous_v1",
            "baseline_start_step_inclusive": BASELINE_START,
            "baseline_end_step_exclusive": BASELINE_END,
            "terminal_start_step_inclusive": TERMINAL_START,
            "terminal_end_step_exclusive": TERMINAL_END,
            "scheduler_swing_steps": SWING_STEPS,
            "scheduler_cycle_steps": CYCLE_STEPS,
            "terminal_swing_count": SWING_COUNT,
            "minimum_cycle_shift_rad": MECHANISM_FLOOR_RAD,
            "swing_sign_zero_tolerance_rad": ZERO_TOLERANCE_RAD,
        },
        "arms": arms,
        "positive_reference_conditioned_cycle_shift_rad": positive_conditioned,
        "negative_reference_conditioned_cycle_shift_rad": negative_conditioned,
        "bilateral_reference_conditioned_cycle_separation_rad": (
            positive_conditioned + negative_conditioned
        ),
        "positive_terminal_swing_conditioned_shift_rad": positive_swing_conditioned,
        "negative_terminal_swing_conditioned_shift_rad": negative_swing_conditioned,
        "gates": gates,
        "passed": all(gates.values()),
        "engine_identity_input_count": 0,
        "physical_acceptance_authority": False,
    }
