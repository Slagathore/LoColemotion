"""Deterministic, read-only analysis of retained locomotion trace lineages.

The implementation uses Python's standard library only. It reads exact
content-addressed payloads, validates their identities and temporal shape, and
emits mechanism projections. It never imports a physics adapter or constructs
a model or world.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable, Sequence


MANIFEST_SCHEMA = "sporespore_retained_trace_lineage_manifest_v1"
REPORT_SCHEMA = "sporespore_retained_trace_lineage_report_v1"
CAS_MANIFEST_SCHEMA = "sporespore_content_addressed_artifact_manifest_v1"
SHA256_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")

REQUIRED_ROW_FIELDS = (
    "schema_version",
    "cell_id",
    "trace_step",
    "phase_id",
    "measured_yaw_rad",
    "desired_heading_offset_rad",
    "base_angular_velocity_task_yaw_rad_s",
    "requested_steering_fraction",
    "held_steering_fraction",
    "steering_saturated",
    "torso_tilt_rad",
    "torso_height_m",
    "maximum_absolute_joint_position_error_rad",
    "ordered_foot_contacts",
    "torso_ground_contact",
    "minimum_dynamic_support_margin_availability",
    "minimum_dynamic_support_margin_m",
    "ordered_applied_stability_velocity_deltas_rad_s",
    "ordered_final_canonical_velocities_rad_s",
)


class TraceLineageError(RuntimeError):
    """Fail-closed analysis error with a stable machine-readable code."""


def _fail(code: str, detail: str = "") -> None:
    suffix = f":{detail}" if detail else ""
    raise TraceLineageError(f"TRACE_LINEAGE_{code}{suffix}")


def _require_object(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(code)
    return value


def _require_list(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(code)
    return value


def _require_string(value: Any, code: str) -> str:
    if not isinstance(value, str) or not value:
        _fail(code)
    return value


def _require_bool(value: Any, code: str) -> bool:
    if not isinstance(value, bool):
        _fail(code)
    return value


def _require_int(value: Any, code: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(code)
    return value


def _finite_float(value: Any, code: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _fail(code)
    result = float(value)
    if not math.isfinite(result):
        _fail(code)
    return result


def _sha256_bytes(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def _mean(values: Sequence[float]) -> float:
    if not values:
        _fail("EMPTY_MEAN")
    return math.fsum(values) / len(values)


def _linear_slope(values: Sequence[float]) -> float:
    """Least-squares slope over unit-spaced samples, with stable summation."""

    if len(values) < 2:
        _fail("SLOPE_WINDOW_TOO_SHORT")
    center = (len(values) - 1) / 2.0
    numerator = math.fsum(
        (index - center) * value for index, value in enumerate(values)
    )
    denominator = math.fsum(
        (index - center) ** 2 for index in range(len(values))
    )
    return numerator / denominator


def _circular_error(target: float, measured: float) -> float:
    delta = target - measured
    return math.atan2(math.sin(delta), math.cos(delta))


def _first_step(rows: Sequence[dict[str, Any]], predicate: Any) -> int | None:
    for row in rows:
        if predicate(row):
            return int(row["trace_step"])
    return None


def _longest_false_run(values: Sequence[bool]) -> int:
    longest = 0
    current = 0
    for value in values:
        if value:
            current = 0
        else:
            current += 1
            longest = max(longest, current)
    return longest


def _false_episode_count(values: Sequence[bool]) -> int:
    episodes = 0
    was_true = True
    for value in values:
        if not value and was_true:
            episodes += 1
        was_true = value
    return episodes


def _extreme_with_step(
    rows: Sequence[dict[str, Any]], field: str, *, maximum: bool
) -> tuple[float, int]:
    pairs = [
        (_finite_float(row[field], f"ROW_{field.upper()}"), int(row["trace_step"]))
        for row in rows
    ]
    selected = (max if maximum else min)(pairs, key=lambda item: item[0])
    return selected


def _validate_sha256(value: Any, code: str) -> str:
    text = _require_string(value, code)
    if SHA256_PATTERN.fullmatch(text) is None:
        _fail(code)
    return text


def _load_json_object(path: Path, code: str) -> dict[str, Any]:
    try:
        return _require_object(json.loads(path.read_text(encoding="utf-8")), code)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        _fail(code, type(error).__name__)


def _load_cas_payload(
    evidence_root: Path, expected_sha256: str, expected_length: int
) -> bytes:
    digest = expected_sha256[7:]
    directory = evidence_root / "artifacts" / "sha256" / digest
    payload_path = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    if not payload_path.is_file() or not manifest_path.is_file():
        _fail("CAS_OBJECT_MISSING", digest)
    manifest = _load_json_object(manifest_path, "CAS_MANIFEST_JSON")
    if (
        manifest.get("schema_version") != CAS_MANIFEST_SCHEMA
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != expected_sha256
        or manifest.get("payload_name") != "payload.bin"
        or _require_int(manifest.get("byte_length"), "CAS_MANIFEST_LENGTH")
        != expected_length
    ):
        _fail("CAS_MANIFEST_IDENTITY", digest)
    try:
        payload = payload_path.read_bytes()
    except OSError as error:
        _fail("CAS_PAYLOAD_READ", type(error).__name__)
    if len(payload) != expected_length:
        _fail("CAS_PAYLOAD_LENGTH", digest)
    if _sha256_bytes(payload) != expected_sha256:
        _fail("CAS_PAYLOAD_DIGEST", digest)
    return payload


def _parse_rows(
    payload: bytes,
    *,
    cell: dict[str, Any],
    trace_contract: dict[str, Any],
) -> list[dict[str, Any]]:
    cell_id = _require_string(cell.get("cell_id"), "CELL_ID")
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError:
        _fail("TRACE_UTF8", cell_id)
    if not text.endswith("\n"):
        _fail("TRACE_FINAL_NEWLINE", cell_id)
    lines = text.splitlines()
    expected_count = _require_int(
        trace_contract.get("expected_row_count"), "EXPECTED_ROW_COUNT"
    )
    if len(lines) != expected_count or any(not line for line in lines):
        _fail("TRACE_ROW_COUNT", cell_id)

    phase_order = _require_list(trace_contract.get("phase_order"), "PHASE_ORDER")
    expected_phases: list[str] = []
    for index, phase_value in enumerate(phase_order):
        phase = _require_object(phase_value, f"PHASE_{index}")
        phase_id = _require_string(phase.get("phase_id"), f"PHASE_ID_{index}")
        row_count = _require_int(
            phase.get("row_count"), f"PHASE_ROW_COUNT_{index}"
        )
        if row_count <= 0:
            _fail("PHASE_ROW_COUNT_NONPOSITIVE", phase_id)
        expected_phases.extend([phase_id] * row_count)
    if len(expected_phases) != expected_count:
        _fail("PHASE_TOTAL_ROW_COUNT")

    trace_schema = _require_string(
        trace_contract.get("trace_schema_version"), "TRACE_SCHEMA"
    )
    rows: list[dict[str, Any]] = []
    for index, line in enumerate(lines):
        try:
            row = _require_object(json.loads(line), "TRACE_ROW_JSON")
        except json.JSONDecodeError:
            _fail("TRACE_ROW_JSON", f"{cell_id}:{index}")
        missing = [field for field in REQUIRED_ROW_FIELDS if field not in row]
        if missing:
            _fail("TRACE_ROW_REQUIRED_FIELD", f"{cell_id}:{index}:{missing[0]}")
        if row["schema_version"] != trace_schema:
            _fail("TRACE_ROW_SCHEMA", f"{cell_id}:{index}")
        if row["cell_id"] != cell_id:
            _fail("TRACE_ROW_CELL", f"{cell_id}:{index}")
        if _require_int(row["trace_step"], "TRACE_STEP") != index:
            _fail("TRACE_STEP_SEQUENCE", f"{cell_id}:{index}")
        if row["phase_id"] != expected_phases[index]:
            _fail("TRACE_PHASE_SEQUENCE", f"{cell_id}:{index}")
        rows.append(row)
    return rows


def _ordered_numeric_array(
    value: Any, expected_length: int, code: str, *, allow_null: bool
) -> list[float] | None:
    if value is None and allow_null:
        return None
    values = _require_list(value, code)
    if len(values) != expected_length:
        _fail(code)
    return [_finite_float(item, code) for item in values]


def _actuator_projection(
    rows: Sequence[dict[str, Any]],
    actuator_names: Sequence[str],
    limits_value: Any,
) -> dict[str, Any]:
    count = len(actuator_names)
    stability_arrays = [
        _ordered_numeric_array(
            row["ordered_applied_stability_velocity_deltas_rad_s"],
            count,
            "STABILITY_ARRAY",
            allow_null=False,
        )
        for row in rows
    ]
    stability_maxima = [
        max(abs(array[index]) for array in stability_arrays if array is not None)
        for index in range(count)
    ]

    command_arrays = [
        _ordered_numeric_array(
            row["ordered_final_canonical_velocities_rad_s"],
            count,
            "FINAL_COMMAND_ARRAY",
            allow_null=True,
        )
        for row in rows
    ]
    command_coverage = sum(array is not None for array in command_arrays)
    if command_coverage == 0:
        command_availability = "unavailable"
    elif command_coverage == len(rows):
        command_availability = "complete"
    else:
        command_availability = "partial"

    limits: list[float] | None = None
    if limits_value is not None:
        limits = _ordered_numeric_array(
            limits_value, count, "ACTUATOR_LIMIT_ARRAY", allow_null=False
        )
        if any(limit <= 0.0 for limit in limits or []):
            _fail("ACTUATOR_LIMIT_NONPOSITIVE")

    utilization: list[float] | None = None
    limiting_index: int | None = None
    if command_availability == "complete" and limits is not None:
        utilization = [
            max(
                abs(array[index]) / limits[index]
                for array in command_arrays
                if array is not None
            )
            for index in range(count)
        ]
        limiting_index = max(range(count), key=lambda index: utilization[index])

    if command_availability != "complete":
        reason = "ordered_final_commands_not_complete"
    elif limits is None:
        reason = "ordered_velocity_limits_not_declared"
    else:
        reason = "complete"

    return {
        "ordered_actuator_names": list(actuator_names),
        "stability_correction_row_count": len(stability_arrays),
        "maximum_absolute_stability_correction_by_actuator_rad_s": stability_maxima,
        "final_command_availability": command_availability,
        "final_command_coverage_row_count": command_coverage,
        "ordered_velocity_limits_declared": limits is not None,
        "maximum_limit_utilization_by_actuator": utilization,
        "limiting_actuator_index": limiting_index,
        "limiting_actuator_name": (
            actuator_names[limiting_index] if limiting_index is not None else None
        ),
        "limiting_actuator_available": limiting_index is not None,
        "limiting_actuator_unavailable_reason": (
            None if limiting_index is not None else reason
        ),
    }


def _tilt_precursor_projection(
    rows: Sequence[dict[str, Any]],
    selected: Sequence[dict[str, Any]],
    config_value: Any,
) -> dict[str, Any] | None:
    """Project a descriptive one-horizon-ahead tilt precursor.

    This deliberately replays several declared finite-difference windows. It
    does not select one, tune a future controller, or estimate a counterfactual
    physical outcome. A successor may instead implement an independently
    derived state-frame tilt-rate observer and must validate it prospectively.
    """

    if config_value is None:
        return None
    config = _require_object(config_value, "TILT_PRECURSOR_CONFIG")
    if config.get("enabled") is not True:
        _fail("TILT_PRECURSOR_ENABLED")
    physics_hz = _require_int(config.get("physics_hz"), "TILT_PRECURSOR_PHYSICS_HZ")
    if physics_hz <= 0:
        _fail("TILT_PRECURSOR_PHYSICS_HZ")
    prediction_horizon_s = _finite_float(
        config.get("prediction_horizon_s"), "TILT_PRECURSOR_HORIZON"
    )
    full_tilt = _finite_float(
        config.get("full_authority_maximum_tilt_rad"),
        "TILT_PRECURSOR_FULL_TILT",
    )
    floor_tilt = _finite_float(
        config.get("minimum_authority_tilt_rad"),
        "TILT_PRECURSOR_FLOOR_TILT",
    )
    if (
        prediction_horizon_s <= 0.0
        or full_tilt < 0.0
        or floor_tilt <= full_tilt
    ):
        _fail("TILT_PRECURSOR_PARAMETERS")
    window_values = _require_list(
        config.get("finite_difference_window_steps"),
        "TILT_PRECURSOR_WINDOWS",
    )
    windows = [
        _require_int(value, "TILT_PRECURSOR_WINDOW") for value in window_values
    ]
    if (
        not windows
        or windows != sorted(set(windows))
        or any(window <= 0 for window in windows)
    ):
        _fail("TILT_PRECURSOR_WINDOWS")

    phase_start = _require_int(selected[0]["trace_step"], "TILT_PRECURSOR_PHASE_START")
    if any(window > phase_start for window in windows):
        _fail("TILT_PRECURSOR_WINDOW_HISTORY")

    first_actual_full_exceeded = _first_step(
        selected, lambda row: float(row["torso_tilt_rad"]) > full_tilt
    )
    first_actual_floor_reached = _first_step(
        selected, lambda row: float(row["torso_tilt_rad"]) >= floor_tilt
    )

    observed_effective: list[tuple[int, float, float, float]] = []
    for row in selected:
        receipt = _require_object(
            row.get("steering_authority_guard"), "TILT_PRECURSOR_GUARD_RECEIPT"
        )
        baseline = _finite_float(
            receipt.get("baseline_maximum_steering_fraction"),
            "TILT_PRECURSOR_GUARD_BASELINE",
        )
        expanded = _finite_float(
            receipt.get("expanded_maximum_steering_fraction"),
            "TILT_PRECURSOR_GUARD_EXPANDED",
        )
        effective = _finite_float(
            receipt.get("effective_maximum_steering_fraction"),
            "TILT_PRECURSOR_GUARD_EFFECTIVE",
        )
        if baseline <= 0.0 or expanded < baseline or not baseline <= effective <= expanded:
            _fail("TILT_PRECURSOR_GUARD_BOUNDS")
        observed_effective.append(
            (int(row["trace_step"]), baseline, expanded, effective)
        )

    epsilon = 1.0e-12
    observed_first_reduced = next(
        (
            step
            for step, _baseline, expanded, effective in observed_effective
            if effective < expanded - epsilon
        ),
        None,
    )
    observed_first_floor = next(
        (
            step
            for step, baseline, _expanded, effective in observed_effective
            if effective <= baseline + epsilon
        ),
        None,
    )

    projections: list[dict[str, Any]] = []
    for window in windows:
        samples: list[tuple[int, float, float, float]] = []
        for row in selected:
            step = int(row["trace_step"])
            prior = rows[step - window]
            tilt = _finite_float(row["torso_tilt_rad"], "TILT_PRECURSOR_TILT")
            prior_tilt = _finite_float(
                prior["torso_tilt_rad"], "TILT_PRECURSOR_PRIOR_TILT"
            )
            rate = (tilt - prior_tilt) * physics_hz / window
            projected = tilt + max(0.0, rate) * prediction_horizon_s
            if not math.isfinite(rate) or not math.isfinite(projected):
                _fail("TILT_PRECURSOR_NONFINITE")
            samples.append((step, rate, projected, tilt))

        first_projected_full = next(
            (step for step, _rate, projected, _tilt in samples if projected > full_tilt),
            None,
        )
        first_projected_floor = next(
            (
                step
                for step, _rate, projected, _tilt in samples
                if projected >= floor_tilt
            ),
            None,
        )
        projections.append(
            {
                "window_steps": window,
                "window_s": window / physics_hz,
                "maximum_positive_tilt_rate_rad_s": max(
                    max(0.0, rate) for _step, rate, _projected, _tilt in samples
                ),
                "maximum_projected_tilt_rad": max(
                    projected for _step, _rate, projected, _tilt in samples
                ),
                "first_projected_full_authority_tilt_exceeded_step": (
                    first_projected_full
                ),
                "first_projected_minimum_authority_tilt_reached_step": (
                    first_projected_floor
                ),
                "projected_floor_lead_over_observed_guard_reduction_steps": (
                    observed_first_reduced - first_projected_floor
                    if observed_first_reduced is not None
                    and first_projected_floor is not None
                    else None
                ),
                "projected_floor_lead_over_observed_guard_floor_steps": (
                    observed_first_floor - first_projected_floor
                    if observed_first_floor is not None
                    and first_projected_floor is not None
                    else None
                ),
            }
        )

    return {
        "status": "descriptive_postclosure_projection_only",
        "physics_hz": physics_hz,
        "prediction_horizon_s": prediction_horizon_s,
        "prediction_horizon_provenance": _require_string(
            config.get("prediction_horizon_provenance"),
            "TILT_PRECURSOR_HORIZON_PROVENANCE",
        ),
        "full_authority_maximum_tilt_rad": full_tilt,
        "minimum_authority_tilt_rad": floor_tilt,
        "first_actual_full_authority_tilt_exceeded_step": first_actual_full_exceeded,
        "first_actual_minimum_authority_tilt_reached_step": first_actual_floor_reached,
        "observed_first_guard_reduction_step": observed_first_reduced,
        "observed_first_guard_floor_step": observed_first_floor,
        "windows": projections,
        "window_selected_for_future_controller": None,
        "counterfactual_physical_outcome_claimed": False,
        "successor_physical_authority": False,
    }


def _count_true_episodes(values: Sequence[bool]) -> int:
    episodes = 0
    previous = False
    for value in values:
        if value and not previous:
            episodes += 1
        previous = value
    return episodes


def _steering_floor_hold_projection(
    selected: Sequence[dict[str, Any]],
    config_value: Any,
) -> dict[str, Any] | None:
    """Replay declared scheduler-derived floor-hold durations descriptively.

    The input trace remains immutable and open-loop: this projection changes
    only a bookkeeping mask over the recorded instantaneous guard receipts.
    It does not recompute commands, advance physics, or claim that a held floor
    would have changed the observed body trajectory.
    """

    if config_value is None:
        return None
    config = _require_object(config_value, "STEERING_FLOOR_HOLD_CONFIG")
    if config.get("enabled") is not True:
        _fail("STEERING_FLOOR_HOLD_ENABLED")
    swing_steps = _require_int(
        config.get("scheduler_swing_steps"), "STEERING_FLOOR_HOLD_SWING_STEPS"
    )
    if swing_steps <= 0:
        _fail("STEERING_FLOOR_HOLD_SWING_STEPS")
    cycle_steps = _require_int(
        config.get("scheduler_cycle_steps"),
        "STEERING_FLOOR_HOLD_CYCLE_STEPS",
    )
    if cycle_steps <= 0 or cycle_steps % swing_steps != 0:
        _fail("STEERING_FLOOR_HOLD_CYCLE_STEPS")
    durations_value = _require_list(
        config.get("hold_duration_steps"), "STEERING_FLOOR_HOLD_DURATIONS"
    )
    durations = [
        _require_int(value, "STEERING_FLOOR_HOLD_DURATION")
        for value in durations_value
    ]
    if (
        not durations
        or durations != sorted(set(durations))
        or durations != list(range(swing_steps, cycle_steps + 1, swing_steps))
    ):
        _fail("STEERING_FLOOR_HOLD_DURATIONS")
    full_tilt = _finite_float(
        config.get("full_authority_maximum_tilt_rad"),
        "STEERING_FLOOR_HOLD_FULL_TILT",
    )
    baseline = _finite_float(
        config.get("baseline_maximum_steering_fraction"),
        "STEERING_FLOOR_HOLD_BASELINE",
    )
    expanded = _finite_float(
        config.get("expanded_maximum_steering_fraction"),
        "STEERING_FLOOR_HOLD_EXPANDED",
    )
    if full_tilt < 0.0 or baseline <= 0.0 or expanded <= baseline:
        _fail("STEERING_FLOOR_HOLD_PARAMETERS")
    required_schema = _require_string(
        config.get("required_guard_schema_version"),
        "STEERING_FLOOR_HOLD_GUARD_SCHEMA",
    )
    required_mode = _require_string(
        config.get("required_guard_mode_id"),
        "STEERING_FLOOR_HOLD_GUARD_MODE",
    )

    epsilon = 1.0e-12
    instantaneous_floor: list[bool] = []
    instantaneous_full: list[bool] = []
    actual_tilts: list[float] = []
    steps: list[int] = []
    for row in selected:
        receipt = _require_object(
            row.get("steering_authority_guard"),
            "STEERING_FLOOR_HOLD_GUARD_RECEIPT",
        )
        if (
            receipt.get("schema_version") != required_schema
            or receipt.get("mode_id") != required_mode
        ):
            _fail("STEERING_FLOOR_HOLD_GUARD_IDENTITY")
        observed_baseline = _finite_float(
            receipt.get("baseline_maximum_steering_fraction"),
            "STEERING_FLOOR_HOLD_OBSERVED_BASELINE",
        )
        observed_expanded = _finite_float(
            receipt.get("expanded_maximum_steering_fraction"),
            "STEERING_FLOOR_HOLD_OBSERVED_EXPANDED",
        )
        effective = _finite_float(
            receipt.get("effective_maximum_steering_fraction"),
            "STEERING_FLOOR_HOLD_OBSERVED_EFFECTIVE",
        )
        actual_tilt = _finite_float(
            receipt.get("torso_tilt_rad"),
            "STEERING_FLOOR_HOLD_OBSERVED_TILT",
        )
        if (
            abs(observed_baseline - baseline) > epsilon
            or abs(observed_expanded - expanded) > epsilon
            or effective < baseline - epsilon
            or effective > expanded + epsilon
        ):
            _fail("STEERING_FLOOR_HOLD_GUARD_BOUNDS")
        steps.append(_require_int(row.get("trace_step"), "STEERING_FLOOR_HOLD_STEP"))
        actual_tilts.append(actual_tilt)
        instantaneous_floor.append(effective <= baseline + epsilon)
        instantaneous_full.append(effective >= expanded - epsilon)

    first_floor_index = next(
        (index for index, value in enumerate(instantaneous_floor) if value), None
    )
    first_actual_full_tilt_index = next(
        (index for index, tilt in enumerate(actual_tilts) if tilt > full_tilt), None
    )
    observed_floor_steps = [
        steps[index] for index, value in enumerate(instantaneous_floor) if value
    ]

    duration_reports: list[dict[str, Any]] = []
    for duration in durations:
        remaining = 0
        hold_active: list[bool] = []
        for floor in instantaneous_floor:
            if floor:
                # Every independently observed floor row refreshes the declared
                # fixed hold. This is the exact state transition a successor
                # would need to declare and test prospectively.
                remaining = duration
            active = remaining > 0
            hold_active.append(active)
            if active:
                remaining -= 1

        held_steps = [steps[index] for index, active in enumerate(hold_active) if active]
        interval_start = first_floor_index
        interval_end = (
            first_actual_full_tilt_index
            if first_actual_full_tilt_index is not None
            else len(selected)
        )
        reopened_indices = []
        if interval_start is not None:
            reopened_indices = [
                index
                for index in range(interval_start, interval_end)
                if not hold_active[index] and instantaneous_full[index]
            ]
        duration_reports.append(
            {
                "hold_duration_steps": duration,
                "hold_duration_scheduler_swing_count": duration // swing_steps,
                "hold_active_row_count": sum(hold_active),
                "hold_episode_count": _count_true_episodes(hold_active),
                "first_hold_active_step": held_steps[0] if held_steps else None,
                "last_hold_active_step": held_steps[-1] if held_steps else None,
                "expanded_authority_reopened_row_count_after_first_floor_before_actual_full_tilt_exceeded": len(
                    reopened_indices
                ),
                "last_expanded_authority_reopened_step_before_actual_full_tilt_exceeded": (
                    steps[reopened_indices[-1]] if reopened_indices else None
                ),
                "hold_active_at_first_actual_full_tilt_exceeded": (
                    hold_active[first_actual_full_tilt_index]
                    if first_actual_full_tilt_index is not None
                    else None
                ),
            }
        )

    return {
        "status": "descriptive_postclosure_open_loop_hold_projection_only",
        "scheduler_swing_steps": swing_steps,
        "scheduler_cycle_steps": cycle_steps,
        "duration_grid_provenance": _require_string(
            config.get("duration_grid_provenance"),
            "STEERING_FLOOR_HOLD_DURATION_PROVENANCE",
        ),
        "full_authority_maximum_tilt_rad": full_tilt,
        "baseline_maximum_steering_fraction": baseline,
        "expanded_maximum_steering_fraction": expanded,
        "observed_floor_row_count": sum(instantaneous_floor),
        "observed_floor_episode_count": _count_true_episodes(instantaneous_floor),
        "first_observed_floor_step": observed_floor_steps[0] if observed_floor_steps else None,
        "last_observed_floor_step": observed_floor_steps[-1] if observed_floor_steps else None,
        "first_actual_full_authority_tilt_exceeded_step": (
            steps[first_actual_full_tilt_index]
            if first_actual_full_tilt_index is not None
            else None
        ),
        "durations": duration_reports,
        "recorded_commands_recomputed": False,
        "physics_recomputed": False,
        "counterfactual_physical_outcome_claimed": False,
        "successor_physical_authority": False,
    }


def _steering_floor_hold_summary(
    cells: Sequence[dict[str, Any]], config_value: Any
) -> dict[str, Any] | None:
    if config_value is None:
        return None
    config = _require_object(config_value, "STEERING_FLOOR_HOLD_CONFIG")
    projections = [cell.get("steering_floor_hold") for cell in cells]
    if any(projection is None for projection in projections):
        _fail("STEERING_FLOOR_HOLD_PROJECTION_MISSING")
    references = [cell for cell in cells if cell["command_sign"] == 0]
    commanded = [cell for cell in cells if cell["command_sign"] != 0]
    if len(references) != 1 or len(commanded) != 2:
        _fail("STEERING_FLOOR_HOLD_ARM_SHAPE")
    reference_projection = references[0]["steering_floor_hold"]
    durations = [
        _require_int(value, "STEERING_FLOOR_HOLD_DURATION")
        for value in _require_list(
            config.get("hold_duration_steps"), "STEERING_FLOOR_HOLD_DURATIONS"
        )
    ]
    duration_summaries: list[dict[str, Any]] = []
    for duration_index, duration in enumerate(durations):
        commanded_reports = [
            cell["steering_floor_hold"]["durations"][duration_index]
            for cell in commanded
        ]
        commanded_projections = [cell["steering_floor_hold"] for cell in commanded]
        reopened = sum(
            report[
                "expanded_authority_reopened_row_count_after_first_floor_before_actual_full_tilt_exceeded"
            ]
            for report in commanded_reports
        )
        property_satisfied = (
            reference_projection["observed_floor_row_count"] == 0
            and all(
                projection["observed_floor_row_count"] > 0
                and projection["first_actual_full_authority_tilt_exceeded_step"] is not None
                for projection in commanded_projections
            )
            and reopened == 0
        )
        duration_summaries.append(
            {
                "hold_duration_steps": duration,
                "hold_duration_scheduler_swing_count": commanded_reports[0][
                    "hold_duration_scheduler_swing_count"
                ],
                "commanded_arm_count": len(commanded),
                "commanded_expanded_authority_reopened_row_count_before_actual_full_tilt_exceeded": reopened,
                "reference_observed_floor_row_count": reference_projection[
                    "observed_floor_row_count"
                ],
                "descriptive_no_reopening_property_satisfied": property_satisfied,
            }
        )
    satisfying = [
        item["hold_duration_steps"]
        for item in duration_summaries
        if item["descriptive_no_reopening_property_satisfied"]
    ]
    return {
        "status": "descriptive_postclosure_parameter_basis_only",
        "duration_property": "zero recorded expanded-authority rows after the first recorded floor and before recorded actual tilt first exceeded the inherited full-authority threshold in both commanded arms, with zero recorded floor rows in the reference arm",
        "durations": duration_summaries,
        "smallest_declared_duration_satisfying_replay_property_steps": (
            min(satisfying) if satisfying else None
        ),
        "future_controller_parameter_authorized": False,
        "candidate_selection_authorized": False,
        "counterfactual_physical_outcome_claimed": False,
        "physical_execution_authorized": False,
    }


def _analyze_cell(
    rows: Sequence[dict[str, Any]],
    *,
    cell: dict[str, Any],
    trace_contract: dict[str, Any],
) -> dict[str, Any]:
    cell_id = _require_string(cell.get("cell_id"), "CELL_ID")
    analysis_phase = _require_string(
        trace_contract.get("analysis_phase_id"), "ANALYSIS_PHASE"
    )
    selected = [row for row in rows if row["phase_id"] == analysis_phase]
    if not selected:
        _fail("ANALYSIS_PHASE_EMPTY", cell_id)
    phase_start_index = int(selected[0]["trace_step"])
    baseline_row = rows[phase_start_index - 1] if phase_start_index > 0 else selected[0]

    final_window_count = _require_int(
        trace_contract.get("final_window_row_count"), "FINAL_WINDOW_COUNT"
    )
    if final_window_count < 2 or final_window_count > len(selected):
        _fail("FINAL_WINDOW_RANGE", cell_id)
    final_window = selected[-final_window_count:]
    contact_limbs = [
        _require_string(item, "CONTACT_LIMB")
        for item in _require_list(
            trace_contract.get("ordered_contact_limbs"), "CONTACT_LIMBS"
        )
    ]
    actuator_names = [
        _require_string(item, "ACTUATOR_NAME")
        for item in _require_list(
            trace_contract.get("ordered_actuator_names"), "ACTUATOR_NAMES"
        )
    ]
    if len(set(contact_limbs)) != len(contact_limbs) or not contact_limbs:
        _fail("CONTACT_LIMB_IDENTITY")
    if len(set(actuator_names)) != len(actuator_names) or not actuator_names:
        _fail("ACTUATOR_NAME_IDENTITY")

    command_sign = _require_int(cell.get("command_sign"), "COMMAND_SIGN")
    if command_sign not in (-1, 0, 1):
        _fail("COMMAND_SIGN")
    steering_cap = _finite_float(cell.get("steering_cap"), "STEERING_CAP")
    if not 0.0 < steering_cap <= 1.0:
        _fail("STEERING_CAP")

    numeric_fields = (
        "measured_yaw_rad",
        "desired_heading_offset_rad",
        "base_angular_velocity_task_yaw_rad_s",
        "requested_steering_fraction",
        "held_steering_fraction",
        "torso_tilt_rad",
        "torso_height_m",
        "maximum_absolute_joint_position_error_rad",
    )
    for row in selected:
        for field in numeric_fields:
            _finite_float(row[field], f"ROW_{field.upper()}")
        _require_bool(row["steering_saturated"], "ROW_STEERING_SATURATED")
        _require_bool(row["torso_ground_contact"], "ROW_TORSO_CONTACT")
        availability = _require_string(
            row["minimum_dynamic_support_margin_availability"],
            "SUPPORT_AVAILABILITY",
        )
        margin = row["minimum_dynamic_support_margin_m"]
        if availability == "measured":
            _finite_float(margin, "ROW_MINIMUM_DYNAMIC_SUPPORT_MARGIN_M")
        elif margin is not None:
            _fail("ROW_UNAVAILABLE_SUPPORT_MARGIN_PRESENT")

    desired_values = [float(row["desired_heading_offset_rad"]) for row in selected]
    if any(value != desired_values[0] for value in desired_values):
        _fail("DESIRED_HEADING_NOT_CONSTANT", cell_id)
    desired = desired_values[0]
    if command_sign == 0 and desired != 0.0:
        _fail("REFERENCE_NONZERO_COMMAND", cell_id)
    if command_sign != 0 and math.copysign(1.0, desired) != float(command_sign):
        _fail("COMMAND_SIGN_MISMATCH", cell_id)

    yaws = [float(row["measured_yaw_rad"]) for row in selected]
    baseline_yaw = _finite_float(
        baseline_row["measured_yaw_rad"], "PHASE_BASELINE_MEASURED_YAW_RAD"
    )
    errors = [_circular_error(desired, yaw) for yaw in yaws]
    baseline_error = _circular_error(desired, baseline_yaw)
    angular_velocities = [
        float(row["base_angular_velocity_task_yaw_rad_s"]) for row in selected
    ]
    requested = [float(row["requested_steering_fraction"]) for row in selected]
    held = [float(row["held_steering_fraction"]) for row in selected]
    saturated = [bool(row["steering_saturated"]) for row in selected]
    reach_fraction = _finite_float(
        trace_contract.get("authority_reach_fraction"), "AUTHORITY_REACH_FRACTION"
    )
    if not 0.0 < reach_fraction <= 1.0:
        _fail("AUTHORITY_REACH_FRACTION")
    held_reach_threshold = steering_cap * reach_fraction
    nonzero_request_indices = [
        index for index, value in enumerate(requested) if abs(value) > 1.0e-12
    ]
    held_to_requested = [
        abs(held[index]) / abs(requested[index]) for index in nonzero_request_indices
    ]

    contacts_by_limb: dict[str, list[bool]] = {limb: [] for limb in contact_limbs}
    all_four_count = 0
    zero_foot_count = 0
    for row in selected:
        contacts = _require_object(row["ordered_foot_contacts"], "FOOT_CONTACTS")
        if set(contacts) != set(contact_limbs):
            _fail("FOOT_CONTACT_IDENTITY", cell_id)
        row_contacts = []
        for limb in contact_limbs:
            value = _require_bool(contacts[limb], "FOOT_CONTACT_VALUE")
            contacts_by_limb[limb].append(value)
            row_contacts.append(value)
        all_four_count += all(row_contacts)
        zero_foot_count += not any(row_contacts)
    contact_projection: dict[str, Any] = {}
    for limb in contact_limbs:
        values = contacts_by_limb[limb]
        contact_projection[limb] = {
            "contact_row_count": sum(values),
            "loss_row_count": len(values) - sum(values),
            "loss_episode_count": _false_episode_count(values),
            "longest_consecutive_loss_rows": _longest_false_run(values),
            "first_loss_step": _first_step(
                selected,
                lambda row, limb=limb: not bool(row["ordered_foot_contacts"][limb]),
            ),
        }

    availability_counts: dict[str, int] = {}
    support_margins: list[float] = []
    for row in selected:
        availability = _require_string(
            row["minimum_dynamic_support_margin_availability"],
            "SUPPORT_AVAILABILITY",
        )
        availability_counts[availability] = availability_counts.get(availability, 0) + 1
        if availability == "measured":
            support_margins.append(float(row["minimum_dynamic_support_margin_m"]))

    maximum_tilt, maximum_tilt_step = _extreme_with_step(
        selected, "torso_tilt_rad", maximum=True
    )
    minimum_height, minimum_height_step = _extreme_with_step(
        selected, "torso_height_m", maximum=False
    )
    maximum_joint_error, maximum_joint_error_step = _extreme_with_step(
        selected, "maximum_absolute_joint_position_error_rad", maximum=True
    )

    phase_yaw_delta = yaws[-1] - baseline_yaw
    return {
        "cell_id": cell_id,
        "engine_id": _require_string(cell.get("engine_id"), "ENGINE_ID"),
        "candidate_id": _require_string(cell.get("candidate_id"), "CANDIDATE_ID"),
        "arm_id": _require_string(cell.get("arm_id"), "ARM_ID"),
        "command_sign": command_sign,
        "steering_cap": steering_cap,
        "trace_sha256": _validate_sha256(cell.get("trace_sha256"), "TRACE_SHA256"),
        "trace_byte_length": _require_int(
            cell.get("trace_byte_length"), "TRACE_BYTE_LENGTH"
        ),
        "trace_row_count": len(rows),
        "analysis_phase_id": analysis_phase,
        "analysis_phase_row_count": len(selected),
        "analysis_phase_baseline_trace_step": int(baseline_row["trace_step"]),
        "analysis_phase_first_trace_step": int(selected[0]["trace_step"]),
        "analysis_phase_final_trace_step": int(selected[-1]["trace_step"]),
        "convergence": {
            "desired_heading_offset_rad": desired,
            "initial_measured_yaw_rad": baseline_yaw,
            "final_measured_yaw_rad": yaws[-1],
            "phase_yaw_delta_rad": phase_yaw_delta,
            "signed_command_progress_rad": (
                None if command_sign == 0 else command_sign * phase_yaw_delta
            ),
            "initial_heading_error_rad": baseline_error,
            "final_heading_error_rad": errors[-1],
            "minimum_absolute_heading_error_rad": min(abs(value) for value in errors),
            "final_window_heading_error_mean_rad": _mean(
                [float(value) for value in errors[-final_window_count:]]
            ),
            "final_window_yaw_slope_rad_per_step": _linear_slope(
                [float(row["measured_yaw_rad"]) for row in final_window]
            ),
            "final_window_angular_velocity_mean_rad_s": _mean(
                [
                    float(row["base_angular_velocity_task_yaw_rad_s"])
                    for row in final_window
                ]
            ),
            "maximum_absolute_angular_velocity_rad_s": max(
                abs(value) for value in angular_velocities
            ),
        },
        "authority": {
            "maximum_absolute_requested_steering_fraction": max(
                abs(value) for value in requested
            ),
            "maximum_absolute_held_steering_fraction": max(abs(value) for value in held),
            "mean_absolute_requested_steering_fraction": _mean(
                [abs(value) for value in requested]
            ),
            "mean_absolute_held_steering_fraction": _mean(
                [abs(value) for value in held]
            ),
            "steering_saturation_row_count": sum(saturated),
            "steering_saturation_fraction": sum(saturated) / len(saturated),
            "first_steering_saturation_step": _first_step(
                selected, lambda row: bool(row["steering_saturated"])
            ),
            "held_cap_reach_fraction": reach_fraction,
            "first_held_cap_reach_step": _first_step(
                selected,
                lambda row: abs(float(row["held_steering_fraction"]))
                >= held_reach_threshold,
            ),
            "held_to_requested_absolute_ratio_mean": (
                _mean(held_to_requested) if held_to_requested else None
            ),
        },
        "contacts": {
            "by_limb": contact_projection,
            "all_four_contact_row_count": all_four_count,
            "zero_foot_contact_row_count": zero_foot_count,
            "torso_ground_contact_row_count": sum(
                bool(row["torso_ground_contact"]) for row in selected
            ),
            "first_torso_ground_contact_step": _first_step(
                selected, lambda row: bool(row["torso_ground_contact"])
            ),
        },
        "support": {
            "availability_counts": dict(sorted(availability_counts.items())),
            "measured_margin_row_count": len(support_margins),
            "minimum_margin_m": min(support_margins) if support_margins else None,
            "maximum_margin_m": max(support_margins) if support_margins else None,
            "final_margin_m": (
                float(selected[-1]["minimum_dynamic_support_margin_m"])
                if selected[-1]["minimum_dynamic_support_margin_availability"]
                == "measured"
                else None
            ),
            "negative_margin_row_count": sum(value < 0.0 for value in support_margins),
            "first_negative_margin_step": _first_step(
                selected,
                lambda row: (
                    row["minimum_dynamic_support_margin_availability"] == "measured"
                    and float(row["minimum_dynamic_support_margin_m"]) < 0.0
                ),
            ),
        },
        "stability": {
            "maximum_torso_tilt_rad": maximum_tilt,
            "maximum_torso_tilt_step": maximum_tilt_step,
            "minimum_torso_height_m": minimum_height,
            "minimum_torso_height_step": minimum_height_step,
            "maximum_absolute_joint_position_error_rad": maximum_joint_error,
            "maximum_absolute_joint_position_error_step": maximum_joint_error_step,
        },
        "tilt_precursor": _tilt_precursor_projection(
            rows,
            selected,
            trace_contract.get("tilt_precursor_projection"),
        ),
        "steering_floor_hold": _steering_floor_hold_projection(
            selected,
            trace_contract.get("steering_floor_hold_projection"),
        ),
        "actuators": _actuator_projection(
            selected,
            actuator_names,
            trace_contract.get("ordered_actuator_velocity_limits_rad_s"),
        ),
    }


def _comparison_projection(
    group: dict[str, Any],
    by_cell: dict[str, dict[str, Any]],
    rows_by_cell: dict[str, Sequence[dict[str, Any]]],
    trace_contract: dict[str, Any],
    threshold: float,
) -> dict[str, Any]:
    candidate_id = _require_string(group.get("candidate_id"), "GROUP_CANDIDATE")
    reference_id = _require_string(group.get("reference_cell_id"), "GROUP_REFERENCE")
    positive_id = _require_string(group.get("positive_cell_id"), "GROUP_POSITIVE")
    negative_id = _require_string(group.get("negative_cell_id"), "GROUP_NEGATIVE")
    try:
        reference = by_cell[reference_id]
        positive = by_cell[positive_id]
        negative = by_cell[negative_id]
    except KeyError as error:
        _fail("GROUP_CELL_MISSING", str(error))
    if (
        any(item["candidate_id"] != candidate_id for item in (reference, positive, negative))
        or reference["command_sign"] != 0
        or positive["command_sign"] != 1
        or negative["command_sign"] != -1
    ):
        _fail("GROUP_IDENTITY", candidate_id)
    reference_delta = float(reference["convergence"]["phase_yaw_delta_rad"])
    positive_delta = float(positive["convergence"]["phase_yaw_delta_rad"])
    negative_delta = float(negative["convergence"]["phase_yaw_delta_rad"])
    positive_conditioned = positive_delta - reference_delta
    negative_conditioned = reference_delta - negative_delta
    bilateral = positive_delta - negative_delta
    result = {
        "candidate_id": candidate_id,
        "reference_phase_yaw_delta_rad": reference_delta,
        "positive_phase_yaw_delta_rad": positive_delta,
        "negative_phase_yaw_delta_rad": negative_delta,
        "positive_reference_conditioned_yaw_delta_rad": positive_conditioned,
        "negative_reference_conditioned_yaw_delta_rad": negative_conditioned,
        "bilateral_yaw_separation_rad": bilateral,
        "minimum_command_conditioned_yaw_separation_rad": threshold,
        "positive_margin_rad": positive_conditioned - threshold,
        "negative_margin_rad": negative_conditioned - threshold,
        "positive_conditioned_threshold_met": positive_conditioned >= threshold,
        "negative_conditioned_threshold_met": negative_conditioned >= threshold,
        "both_conditioned_thresholds_met": (
            positive_conditioned >= threshold and negative_conditioned >= threshold
        ),
        "diagnostic_only": True,
        "candidate_selection_authorized": False,
    }
    result["directional_response_measurement"] = (
        _directional_response_measurement_projection(
            reference_id=reference_id,
            positive_id=positive_id,
            negative_id=negative_id,
            by_cell=by_cell,
            rows_by_cell=rows_by_cell,
            trace_contract=trace_contract,
            threshold=threshold,
        )
    )
    return result


def _directional_response_measurement_projection(
    *,
    reference_id: str,
    positive_id: str,
    negative_id: str,
    by_cell: dict[str, dict[str, Any]],
    rows_by_cell: dict[str, Sequence[dict[str, Any]]],
    trace_contract: dict[str, Any],
    threshold: float,
) -> dict[str, Any] | None:
    """Describe onset, retention, and command delivery without replaying physics.

    Every terminal window in the manifest-bound scheduler grid is reported at
    once. The projection cannot select a replacement estimator or reinterpret
    the closed endpoint verdict; it only identifies what the retained rows
    directly show about transient response and terminal phase sensitivity.
    """

    config_value = trace_contract.get("directional_response_measurement")
    if config_value is None:
        return None
    config = _require_object(config_value, "DIRECTIONAL_RESPONSE_CONFIG")
    if config.get("enabled") is not True:
        _fail("DIRECTIONAL_RESPONSE_ENABLED")

    swing_steps = _require_int(
        config.get("scheduler_swing_steps"), "DIRECTIONAL_RESPONSE_SWING_STEPS"
    )
    cycle_steps = _require_int(
        config.get("scheduler_cycle_steps"), "DIRECTIONAL_RESPONSE_CYCLE_STEPS"
    )
    if swing_steps <= 1 or cycle_steps <= 0 or cycle_steps % swing_steps != 0:
        _fail("DIRECTIONAL_RESPONSE_SCHEDULER")
    window_values = _require_list(
        config.get("terminal_mean_window_steps"), "DIRECTIONAL_RESPONSE_WINDOWS"
    )
    windows = [
        _require_int(value, "DIRECTIONAL_RESPONSE_WINDOW")
        for value in window_values
    ]
    expected_windows = [1] + list(range(swing_steps, cycle_steps + 1, swing_steps))
    if windows != expected_windows:
        _fail("DIRECTIONAL_RESPONSE_WINDOWS")
    trajectory_baseline_steps = _require_int(
        config.get("trajectory_baseline_window_steps"),
        "DIRECTIONAL_RESPONSE_TRAJECTORY_BASELINE",
    )
    if trajectory_baseline_steps != cycle_steps:
        _fail("DIRECTIONAL_RESPONSE_TRAJECTORY_BASELINE")
    tolerance = _finite_float(
        config.get("steering_zero_tolerance"),
        "DIRECTIONAL_RESPONSE_STEERING_TOLERANCE",
    )
    if tolerance <= 0.0:
        _fail("DIRECTIONAL_RESPONSE_STEERING_TOLERANCE")

    sign_map_value = _require_object(
        config.get("expected_steering_sign_by_command_sign"),
        "DIRECTIONAL_RESPONSE_SIGN_MAP",
    )
    if set(sign_map_value) != {"-1", "1"}:
        _fail("DIRECTIONAL_RESPONSE_SIGN_MAP")
    sign_map = {
        int(key): _require_int(value, "DIRECTIONAL_RESPONSE_SIGN_MAP")
        for key, value in sign_map_value.items()
    }
    if (
        sign_map[1] not in (-1, 1)
        or sign_map[-1] not in (-1, 1)
    ):
        _fail("DIRECTIONAL_RESPONSE_SIGN_MAP")
    required_guard_schema = _require_string(
        config.get("required_guard_schema_version"),
        "DIRECTIONAL_RESPONSE_GUARD_SCHEMA",
    )
    required_guard_mode = _require_string(
        config.get("required_guard_mode_id"),
        "DIRECTIONAL_RESPONSE_GUARD_MODE",
    )
    analysis_phase = _require_string(
        trace_contract.get("analysis_phase_id"), "ANALYSIS_PHASE"
    )

    arm_ids = {
        "reference_zero": reference_id,
        "positive_heading": positive_id,
        "negative_heading": negative_id,
    }
    selected_by_arm: dict[str, list[dict[str, Any]]] = {}
    for arm_id, cell_id in arm_ids.items():
        try:
            rows = rows_by_cell[cell_id]
            analyzed = by_cell[cell_id]
        except KeyError as error:
            _fail("DIRECTIONAL_RESPONSE_CELL_MISSING", str(error))
        if analyzed["arm_id"] != arm_id:
            _fail("DIRECTIONAL_RESPONSE_ARM_IDENTITY", cell_id)
        selected = [row for row in rows if row["phase_id"] == analysis_phase]
        if not selected:
            _fail("DIRECTIONAL_RESPONSE_PHASE_EMPTY", cell_id)
        selected_by_arm[arm_id] = selected

    phase_steps = [
        int(row["trace_step"]) for row in selected_by_arm["reference_zero"]
    ]
    if any(
        [int(row["trace_step"]) for row in selected] != phase_steps
        for selected in selected_by_arm.values()
    ):
        _fail("DIRECTIONAL_RESPONSE_PHASE_ALIGNMENT")
    phase_start = phase_steps[0]
    if (
        max(windows) > len(phase_steps)
        or max(max(windows), trajectory_baseline_steps) > phase_start
    ):
        _fail("DIRECTIONAL_RESPONSE_WINDOW_RANGE")

    def yaw_values(rows: Sequence[dict[str, Any]]) -> list[float]:
        return [
            _finite_float(row["measured_yaw_rad"], "DIRECTIONAL_RESPONSE_YAW")
            for row in rows
        ]

    all_yaws = {
        arm_id: yaw_values(rows_by_cell[cell_id])
        for arm_id, cell_id in arm_ids.items()
    }
    selected_yaws = {
        arm_id: yaw_values(selected)
        for arm_id, selected in selected_by_arm.items()
    }

    window_reports: list[dict[str, Any]] = []
    for window in windows:
        shifts: dict[str, float] = {}
        baselines: dict[str, float] = {}
        terminals: dict[str, float] = {}
        for arm_id in arm_ids:
            baseline = _mean(all_yaws[arm_id][phase_start - window : phase_start])
            terminal = _mean(selected_yaws[arm_id][-window:])
            baselines[arm_id] = baseline
            terminals[arm_id] = terminal
            shifts[arm_id] = terminal - baseline
        positive_conditioned = shifts["positive_heading"] - shifts["reference_zero"]
        negative_conditioned = shifts["reference_zero"] - shifts["negative_heading"]
        window_reports.append(
            {
                "window_steps": window,
                "window_basis_id": (
                    "frozen_single_endpoint_v1"
                    if window == 1
                    else "whole_scheduler_swing_multiple_v1"
                ),
                "window_scheduler_swing_count": (
                    None if window == 1 else window // swing_steps
                ),
                "reference_baseline_mean_yaw_rad": baselines["reference_zero"],
                "positive_baseline_mean_yaw_rad": baselines["positive_heading"],
                "negative_baseline_mean_yaw_rad": baselines["negative_heading"],
                "reference_terminal_mean_yaw_rad": terminals["reference_zero"],
                "positive_terminal_mean_yaw_rad": terminals["positive_heading"],
                "negative_terminal_mean_yaw_rad": terminals["negative_heading"],
                "reference_mean_yaw_shift_rad": shifts["reference_zero"],
                "positive_mean_yaw_shift_rad": shifts["positive_heading"],
                "negative_mean_yaw_shift_rad": shifts["negative_heading"],
                "positive_reference_conditioned_mean_yaw_shift_rad": (
                    positive_conditioned
                ),
                "negative_reference_conditioned_mean_yaw_shift_rad": (
                    negative_conditioned
                ),
                "bilateral_conditioned_mean_yaw_separation_rad": (
                    shifts["positive_heading"] - shifts["negative_heading"]
                ),
                "positive_threshold_met": positive_conditioned >= threshold,
                "negative_threshold_met": negative_conditioned >= threshold,
                "both_thresholds_met": (
                    positive_conditioned >= threshold
                    and negative_conditioned >= threshold
                ),
            }
        )

    reference_all = all_yaws["reference_zero"]
    response_trajectories: dict[str, dict[str, Any]] = {}
    for arm_id in ("positive_heading", "negative_heading"):
        command_sign = int(by_cell[arm_ids[arm_id]]["command_sign"])
        commanded_all = all_yaws[arm_id]
        baseline_pairwise = _mean(
            [
                command_sign * (commanded_all[index] - reference_all[index])
                for index in range(
                    phase_start - trajectory_baseline_steps, phase_start
                )
            ]
        )
        conditioned = [
            command_sign
            * (
                selected_yaws[arm_id][index]
                - selected_yaws["reference_zero"][index]
            )
            - baseline_pairwise
            for index in range(len(phase_steps))
        ]
        peak_index = max(range(len(conditioned)), key=lambda index: conditioned[index])
        met = [value >= threshold for value in conditioned]
        first_met_index = next((index for index, value in enumerate(met) if value), None)
        peak = conditioned[peak_index]
        endpoint = conditioned[-1]
        response_trajectories[arm_id] = {
            "trajectory_baseline_pairwise_conditioned_yaw_mean_rad": baseline_pairwise,
            "first_threshold_met_step": (
                phase_steps[first_met_index] if first_met_index is not None else None
            ),
            "threshold_met_row_count": sum(met),
            "threshold_met_episode_count": _count_true_episodes(met),
            "peak_conditioned_response_rad": peak,
            "peak_conditioned_response_step": phase_steps[peak_index],
            "endpoint_conditioned_response_rad": endpoint,
            "peak_to_endpoint_regression_rad": peak - endpoint,
            "endpoint_to_peak_retention_fraction": (
                endpoint / peak if peak > 0.0 else None
            ),
            "threshold_reached_during_phase": any(met),
            "endpoint_threshold_met": endpoint >= threshold,
            "threshold_reached_then_endpoint_below": (
                any(met) and endpoint < threshold
            ),
        }

    command_delivery: dict[str, dict[str, Any]] = {}
    for arm_id, cell_id in arm_ids.items():
        selected = selected_by_arm[arm_id]
        command_sign = int(by_cell[cell_id]["command_sign"])
        expected_sign = sign_map.get(command_sign)
        requested = [
            _finite_float(
                row["requested_steering_fraction"],
                "DIRECTIONAL_RESPONSE_REQUESTED_STEERING",
            )
            for row in selected
        ]
        held = [
            _finite_float(
                row["held_steering_fraction"],
                "DIRECTIONAL_RESPONSE_HELD_STEERING",
            )
            for row in selected
        ]

        def consistent(value: float) -> bool:
            if expected_sign is None:
                _fail("DIRECTIONAL_RESPONSE_REFERENCE_SIGN_CHECK")
            return expected_sign * value > tolerance

        requested_consistent = (
            [consistent(value) for value in requested]
            if expected_sign is not None
            else None
        )
        held_consistent = (
            [consistent(value) for value in held]
            if expected_sign is not None
            else None
        )
        guard_active: list[bool] = []
        guard_triggered: list[bool] = []
        for row in selected:
            receipt = _require_object(
                row.get("steering_authority_guard"),
                "DIRECTIONAL_RESPONSE_GUARD_RECEIPT",
            )
            if (
                receipt.get("schema_version") != required_guard_schema
                or receipt.get("mode_id") != required_guard_mode
            ):
                _fail("DIRECTIONAL_RESPONSE_GUARD_IDENTITY", cell_id)
            guard_active.append(
                _require_bool(
                    receipt.get("floor_hold_active_this_step"),
                    "DIRECTIONAL_RESPONSE_GUARD_ACTIVE",
                )
            )
            guard_triggered.append(
                _require_bool(
                    receipt.get("floor_hold_triggered_this_step"),
                    "DIRECTIONAL_RESPONSE_GUARD_TRIGGERED",
                )
            )
        command_delivery[arm_id] = {
            "command_sign": command_sign,
            "expected_steering_sign": expected_sign,
            "row_count": len(selected),
            "requested_sign_consistent_row_count": (
                sum(requested_consistent)
                if requested_consistent is not None
                else None
            ),
            "held_sign_consistent_row_count": (
                sum(held_consistent) if held_consistent is not None else None
            ),
            "requested_sign_consistent_fraction": (
                sum(requested_consistent) / len(selected)
                if requested_consistent is not None
                else None
            ),
            "held_sign_consistent_fraction": (
                sum(held_consistent) / len(selected)
                if held_consistent is not None
                else None
            ),
            "mean_requested_steering_fraction": _mean(requested),
            "mean_held_steering_fraction": _mean(held),
            "mean_absolute_requested_steering_fraction": _mean(
                [abs(value) for value in requested]
            ),
            "mean_absolute_held_steering_fraction": _mean(
                [abs(value) for value in held]
            ),
            "steering_saturation_row_count": sum(
                _require_bool(
                    row["steering_saturated"],
                    "DIRECTIONAL_RESPONSE_STEERING_SATURATED",
                )
                for row in selected
            ),
            "guard_floor_hold_trigger_row_count": sum(guard_triggered),
            "guard_floor_hold_active_row_count": sum(guard_active),
        }

    endpoint_window = window_reports[0]
    full_cycle_window = window_reports[-1]
    commanded_delivery = [
        command_delivery["positive_heading"],
        command_delivery["negative_heading"],
    ]
    return {
        "status": "descriptive_postclosure_directional_response_measurement_only",
        "scheduler_swing_steps": swing_steps,
        "scheduler_cycle_steps": cycle_steps,
        "terminal_window_grid_provenance": _require_string(
            config.get("terminal_window_grid_provenance"),
            "DIRECTIONAL_RESPONSE_WINDOW_PROVENANCE",
        ),
        "trajectory_baseline_window_steps": trajectory_baseline_steps,
        "trajectory_baseline_provenance": _require_string(
            config.get("trajectory_baseline_provenance"),
            "DIRECTIONAL_RESPONSE_TRAJECTORY_BASELINE_PROVENANCE",
        ),
        "minimum_command_conditioned_yaw_separation_rad": threshold,
        "windows": window_reports,
        "response_trajectories": response_trajectories,
        "command_delivery": command_delivery,
        "direct_observations": {
            "both_commanded_arms_reached_threshold_during_phase": all(
                response_trajectories[arm_id]["threshold_reached_during_phase"]
                for arm_id in ("positive_heading", "negative_heading")
            ),
            "frozen_endpoint_both_thresholds_met": endpoint_window[
                "both_thresholds_met"
            ],
            "full_cycle_terminal_mean_both_thresholds_met": full_cycle_window[
                "both_thresholds_met"
            ],
            "negative_arm_reached_threshold_then_ended_below": (
                response_trajectories["negative_heading"][
                    "threshold_reached_then_endpoint_below"
                ]
            ),
            "both_commanded_arms_requested_sign_consistent_every_row": all(
                item["requested_sign_consistent_row_count"] == item["row_count"]
                for item in commanded_delivery
            ),
        },
        "terminal_estimator_selected_for_successor": None,
        "controller_change_selected": None,
        "closed_endpoint_verdict_changed": False,
        "counterfactual_physical_outcome_claimed": False,
        "physical_execution_authorized": False,
        "successor_physical_authority": False,
    }


def run_analysis(
    manifest_path: Path,
    evidence_root: Path,
    analyzer_source_commit: str,
) -> dict[str, Any]:
    if re.fullmatch(r"[0-9a-f]{40}", analyzer_source_commit) is None:
        _fail("ANALYZER_SOURCE_COMMIT")
    try:
        manifest_bytes = manifest_path.read_bytes()
    except OSError as error:
        _fail("MANIFEST_READ", type(error).__name__)
    try:
        manifest = _require_object(json.loads(manifest_bytes), "MANIFEST_JSON")
    except (UnicodeError, json.JSONDecodeError):
        _fail("MANIFEST_JSON")
    if manifest.get("schema_version") != MANIFEST_SCHEMA:
        _fail("MANIFEST_SCHEMA")
    if manifest.get("question_class") != "postclosure_development_diagnosis":
        _fail("QUESTION_CLASS")
    trace_contract = _require_object(manifest.get("trace_contract"), "TRACE_CONTRACT")
    cells_value = _require_list(manifest.get("cells"), "CELLS")
    if not cells_value:
        _fail("CELLS_EMPTY")

    cells: list[dict[str, Any]] = []
    rows_by_cell: dict[str, Sequence[dict[str, Any]]] = {}
    seen_ids: set[str] = set()
    total_bytes = 0
    for cell_value in cells_value:
        cell = _require_object(cell_value, "CELL")
        cell_id = _require_string(cell.get("cell_id"), "CELL_ID")
        if cell_id in seen_ids:
            _fail("CELL_DUPLICATE", cell_id)
        seen_ids.add(cell_id)
        expected_sha256 = _validate_sha256(cell.get("trace_sha256"), "TRACE_SHA256")
        expected_length = _require_int(
            cell.get("trace_byte_length"), "TRACE_BYTE_LENGTH"
        )
        if expected_length <= 0:
            _fail("TRACE_BYTE_LENGTH")
        payload = _load_cas_payload(evidence_root, expected_sha256, expected_length)
        rows = _parse_rows(payload, cell=cell, trace_contract=trace_contract)
        rows_by_cell[cell_id] = rows
        cells.append(_analyze_cell(rows, cell=cell, trace_contract=trace_contract))
        total_bytes += expected_length

    threshold_object = _require_object(
        manifest.get("replayed_thresholds"), "REPLAYED_THRESHOLDS"
    )
    threshold = _finite_float(
        threshold_object.get("minimum_command_conditioned_yaw_separation_rad"),
        "CONDITIONED_THRESHOLD",
    )
    if threshold <= 0.0 or threshold_object.get("threshold_change_authorized") is not False:
        _fail("CONDITIONED_THRESHOLD_BOUNDARY")
    by_cell = {cell["cell_id"]: cell for cell in cells}
    comparisons = [
        _comparison_projection(
            _require_object(group, "COMPARISON_GROUP"),
            by_cell,
            rows_by_cell,
            trace_contract,
            threshold,
        )
        for group in _require_list(
            manifest.get("comparison_groups"), "COMPARISON_GROUPS"
        )
    ]
    if not comparisons:
        _fail("COMPARISON_GROUPS_EMPTY")

    claim_limits = _require_object(manifest.get("claim_limits"), "CLAIM_LIMITS")
    if any(value is not False for value in claim_limits.values()):
        _fail("CLAIM_LIMITS")

    return {
        "schema_version": REPORT_SCHEMA,
        "analysis_id": _require_string(manifest.get("analysis_id"), "ANALYSIS_ID"),
        "question_class": "postclosure_development_diagnosis",
        "analyzer_source_commit": analyzer_source_commit,
        "manifest": {
            # Retain a root-independent identity. The digest and byte length below
            # bind the exact manifest bytes; an absolute checkout path would make
            # otherwise identical analysis reports differ between honest roots.
            "path": manifest_path.name,
            "sha256": _sha256_bytes(manifest_bytes),
            "byte_length": len(manifest_bytes),
        },
        "source_closure": _require_object(
            manifest.get("source_closure"), "SOURCE_CLOSURE"
        ),
        "input_summary": {
            "cell_count": len(cells),
            "trace_count": len(cells),
            "total_trace_byte_length": total_bytes,
            "total_trace_row_count": sum(cell["trace_row_count"] for cell in cells),
            "content_addressed_input_count": len(cells),
            "live_attempt_path_input_count": 0,
        },
        "cells": cells,
        "comparisons": comparisons,
        "steering_floor_hold_summary": _steering_floor_hold_summary(
            cells,
            trace_contract.get("steering_floor_hold_projection"),
        ),
        "observability": {
            "complete_limiting_actuator_cell_count": sum(
                bool(cell["actuators"]["limiting_actuator_available"])
                for cell in cells
            ),
            "limiting_actuator_unavailable_cell_count": sum(
                not bool(cell["actuators"]["limiting_actuator_available"])
                for cell in cells
            ),
            "limiting_actuator_claim_authorized": all(
                bool(cell["actuators"]["limiting_actuator_available"])
                for cell in cells
            ),
        },
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "closed_campaign_reinterpreted": False,
        "candidate_selection_authorized": False,
        "threshold_change_authorized": False,
        "physical_campaign_opened": False,
        "physical_execution_authorized": False,
        "turning_validation": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def _canonical_json(report: dict[str, Any], *, pretty: bool) -> str:
    return json.dumps(
        report,
        allow_nan=False,
        indent=2 if pretty else None,
        separators=None if pretty else (",", ":"),
        sort_keys=True,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--analyzer-source-commit", required=True)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args(argv)
    if arguments.output is not None and arguments.output.exists():
        _fail("OUTPUT_EXISTS", str(arguments.output))
    report = run_analysis(
        arguments.manifest,
        arguments.evidence_root,
        arguments.analyzer_source_commit,
    )
    if arguments.output is not None:
        arguments.output.write_text(
            _canonical_json(report, pretty=True) + "\n", encoding="utf-8", newline="\n"
        )
    print("RETAINED_TRACE_LINEAGE_PASS " + _canonical_json(report, pretty=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
