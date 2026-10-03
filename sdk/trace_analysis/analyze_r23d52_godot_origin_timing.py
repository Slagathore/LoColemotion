"""Diagnose R23D52 task-origin timing from immutable R48/R52 traces.

This is a deterministic, read-only, post-outcome analysis.  It verifies six
content-addressed Godot/Jolt traces, compares the same-seed R48 fixed-origin
worlds with the R52 segment-origin worlds, and reports when controller and
physical trajectories first diverge.  It never imports an adapter, constructs
a model, or opens a physics world.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable, Sequence


MANIFEST_SCHEMA = "sporespore_r23d52_godot_origin_timing_analysis_manifest_v1"
REPORT_SCHEMA = "sporespore_r23d52_godot_origin_timing_analysis_report_v1"
CAS_MANIFEST_SCHEMA = "sporespore_content_addressed_artifact_manifest_v1"
TRACE_SCHEMA = "sporespore_qsdk_r23d48_turning_trace_row_v1"
SHA256_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")


class OriginTimingError(RuntimeError):
    """Fail-closed analysis error with a stable code."""


def _fail(code: str, detail: str = "") -> None:
    suffix = f":{detail}" if detail else ""
    raise OriginTimingError(f"R23D52_ORIGIN_TIMING_{code}{suffix}")


def _object(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(code)
    return value


def _array(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(code)
    return value


def _string(value: Any, code: str) -> str:
    if not isinstance(value, str) or not value:
        _fail(code)
    return value


def _integer(value: Any, code: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(code)
    return value


def _finite(value: Any, code: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _fail(code)
    result = float(value)
    if not math.isfinite(result):
        _fail(code)
    return result


def _sha256(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def _load_json(path: Path, code: str) -> dict[str, Any]:
    try:
        return _object(json.loads(path.read_text(encoding="utf-8")), code)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        _fail(code, type(error).__name__)


def _load_cas(
    evidence_root: Path, expected_sha256: str, expected_length: int
) -> bytes:
    if SHA256_PATTERN.fullmatch(expected_sha256) is None:
        _fail("TRACE_SHA256")
    digest = expected_sha256[7:]
    directory = evidence_root / "artifacts" / "sha256" / digest
    payload_path = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    if not payload_path.is_file() or not manifest_path.is_file():
        _fail("CAS_OBJECT_MISSING", digest)
    manifest = _load_json(manifest_path, "CAS_MANIFEST_JSON")
    if (
        manifest.get("schema_version") != CAS_MANIFEST_SCHEMA
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != expected_sha256
        or manifest.get("payload_name") != "payload.bin"
        or _integer(manifest.get("byte_length"), "CAS_MANIFEST_LENGTH")
        != expected_length
    ):
        _fail("CAS_MANIFEST_IDENTITY", digest)
    try:
        payload = payload_path.read_bytes()
    except OSError as error:
        _fail("CAS_PAYLOAD_READ", type(error).__name__)
    if len(payload) != expected_length:
        _fail("CAS_PAYLOAD_LENGTH", digest)
    if _sha256(payload) != expected_sha256:
        _fail("CAS_PAYLOAD_DIGEST", digest)
    return payload


def _parse_trace(
    payload: bytes,
    *,
    expected_cell_id: str,
    expected_rows: int,
) -> list[dict[str, Any]]:
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError:
        _fail("TRACE_UTF8", expected_cell_id)
    rows: list[dict[str, Any]] = []
    for line_index, line in enumerate(text.splitlines()):
        if not line:
            _fail("TRACE_EMPTY_LINE", f"{expected_cell_id}:{line_index}")
        try:
            row = _object(json.loads(line), "TRACE_ROW_OBJECT")
        except json.JSONDecodeError:
            _fail("TRACE_JSON", f"{expected_cell_id}:{line_index}")
        if (
            row.get("schema_version") != TRACE_SCHEMA
            or row.get("cell_id") != expected_cell_id
            or _integer(row.get("semantic_step"), "TRACE_STEP") != line_index
        ):
            _fail("TRACE_IDENTITY", f"{expected_cell_id}:{line_index}")
        rows.append(row)
    if len(rows) != expected_rows:
        _fail("TRACE_ROW_COUNT", expected_cell_id)
    return rows


def _first_difference(
    left: Sequence[dict[str, Any]],
    right: Sequence[dict[str, Any]],
    fields: Iterable[str],
    end_exclusive: int,
) -> int | None:
    for index in range(end_exclusive):
        if any(left[index].get(field) != right[index].get(field) for field in fields):
            return index
    return None


def _circular_delta(final: float, initial: float) -> float:
    delta = final - initial
    return math.atan2(math.sin(delta), math.cos(delta))


def _vector_distance(left: Any, right: Any, code: str) -> float:
    left_values = _array(left, code)
    right_values = _array(right, code)
    if len(left_values) != 3 or len(right_values) != 3:
        _fail(code)
    deltas = [
        _finite(left_value, code) - _finite(right_value, code)
        for left_value, right_value in zip(left_values, right_values, strict=True)
    ]
    return math.sqrt(math.fsum(delta * delta for delta in deltas))


def _cycle_endpoint_deltas(
    rows: Sequence[dict[str, Any]], turn_start: int, cycle_steps: int
) -> list[float]:
    return [
        _circular_delta(
            _finite(rows[start + cycle_steps - 1]["measured_yaw_rad"], "CYCLE_YAW"),
            _finite(rows[start]["measured_yaw_rad"], "CYCLE_YAW"),
        )
        for start in (turn_start, turn_start + cycle_steps, turn_start + 2 * cycle_steps)
    ]


def _pair_projection(
    pair: dict[str, Any],
    evidence_root: Path,
    contract: dict[str, Any],
) -> dict[str, Any]:
    expected_rows = _integer(contract.get("expected_trace_row_count"), "EXPECTED_ROWS")
    turn_start = _integer(contract.get("turn_start_semantic_step"), "TURN_START")
    turn_end = _integer(contract.get("turn_end_semantic_step_exclusive"), "TURN_END")
    cycle_steps = _integer(contract.get("gait_cycle_steps"), "CYCLE_STEPS")
    if not (0 < turn_start < turn_end <= expected_rows):
        _fail("TURN_WINDOW")
    if turn_end - turn_start != 1200 or cycle_steps != 360:
        _fail("INHERITED_SCHEDULE")

    arm_id = _string(pair.get("arm_id"), "ARM_ID")
    command_sign = _integer(pair.get("command_sign"), "COMMAND_SIGN")
    if command_sign not in (-1, 0, 1):
        _fail("COMMAND_SIGN", arm_id)

    traces: dict[str, list[dict[str, Any]]] = {}
    trace_receipts: dict[str, dict[str, Any]] = {}
    for lineage_id in ("r23d48", "r23d52"):
        binding = _object(pair.get(lineage_id), f"{lineage_id.upper()}_BINDING")
        cell_id = _string(binding.get("cell_id"), f"{lineage_id.upper()}_CELL")
        digest = _string(binding.get("trace_sha256"), f"{lineage_id.upper()}_SHA")
        length = _integer(binding.get("trace_byte_length"), f"{lineage_id.upper()}_LENGTH")
        payload = _load_cas(evidence_root, digest, length)
        traces[lineage_id] = _parse_trace(
            payload,
            expected_cell_id=cell_id,
            expected_rows=expected_rows,
        )
        trace_receipts[lineage_id] = {
            "cell_id": cell_id,
            "trace_sha256": digest,
            "trace_byte_length": length,
            "trace_row_count": len(traces[lineage_id]),
        }

    r48 = traces["r23d48"]
    r52 = traces["r23d52"]
    physical_observation_fields = tuple(
        _string(value, "PHYSICAL_FIELD")
        for value in _array(contract.get("physical_observation_fields"), "PHYSICAL_FIELDS")
    )
    controller_fields = tuple(
        _string(value, "CONTROLLER_FIELD")
        for value in _array(contract.get("controller_projection_fields"), "CONTROLLER_FIELDS")
    )
    required_fields = set(physical_observation_fields + controller_fields)
    required_fields.update(
        {
            "desired_heading_offset_rad",
            "segment_id",
            "task_frame_origin_policy_id",
            "task_frame_origin_reanchor_count",
            "task_frame_origin_reanchored_this_step",
            "task_frame_origin_world_m",
            "torso_position_world_m",
            "measured_yaw_rad",
            "requested_steering_fraction",
            "held_steering_fraction",
        }
    )
    for lineage_id, rows in traces.items():
        for field in physical_observation_fields + controller_fields:
            if any(field not in row for row in rows):
                _fail("TRACE_REQUIRED_FIELD", f"{lineage_id}:{arm_id}:{field}")
    for field in required_fields - {
        "task_frame_origin_policy_id",
        "task_frame_origin_reanchor_count",
        "task_frame_origin_reanchored_this_step",
        "task_frame_origin_world_m",
    }:
        if any(field not in row for row in r52):
            _fail("R52_REQUIRED_FIELD", f"{arm_id}:{field}")

    if any(
        r48[index]["segment_id"] != r52[index]["segment_id"]
        or _finite(r48[index]["desired_heading_offset_rad"], "R48_OFFSET")
        != _finite(r52[index]["desired_heading_offset_rad"], "R52_OFFSET")
        for index in range(expected_rows)
    ):
        _fail("SCHEDULE_MISMATCH", arm_id)
    expected_offset = 0.2 * command_sign
    if any(
        _finite(r52[index]["desired_heading_offset_rad"], "OFFSET")
        != (expected_offset if turn_start <= index < turn_end else 0.0)
        for index in range(expected_rows)
    ):
        _fail("COMMAND_TRANSPORT", arm_id)

    reanchor_steps = [
        index
        for index, row in enumerate(r52)
        if row.get("task_frame_origin_reanchored_this_step") is True
    ]
    expected_reanchor_steps = [
        _integer(value, "EXPECTED_REANCHOR_STEP")
        for value in _array(contract.get("r23d52_expected_reanchor_steps"), "REANCHOR_STEPS")
    ]
    if reanchor_steps != expected_reanchor_steps:
        _fail("R52_REANCHOR_STEPS", arm_id)
    if any(
        row.get("task_frame_origin_policy_id")
        != contract.get("r23d52_task_frame_origin_policy_id")
        for row in r52
    ):
        _fail("R52_POLICY_ID", arm_id)
    if r52[0].get("task_frame_origin_world_m") != r52[0].get("torso_position_world_m"):
        _fail("R52_INITIAL_REANCHOR_VALUE", arm_id)
    if r52[turn_start].get("task_frame_origin_world_m") != r52[turn_start].get(
        "torso_position_world_m"
    ):
        _fail("R52_TURN_REANCHOR_VALUE", arm_id)

    step_zero_physical_equal = all(
        r48[0].get(field) == r52[0].get(field) for field in physical_observation_fields
    )
    if not step_zero_physical_equal:
        _fail("STEP_ZERO_PHYSICAL_PRECONDITION", arm_id)

    first_controller_difference = _first_difference(
        r48, r52, controller_fields, turn_start
    )
    first_position_difference = _first_difference(
        r48, r52, ("torso_position_world_m",), turn_start
    )
    first_yaw_difference = _first_difference(
        r48, r52, ("measured_yaw_rad",), turn_start
    )
    if (
        first_controller_difference is None
        or first_position_difference is None
        or first_yaw_difference is None
    ):
        _fail("EXPECTED_PRETURN_DIVERGENCE_MISSING", arm_id)

    turn_rows = r52[turn_start:turn_end]
    requested_expected_sign = -command_sign
    requested_sign_consistent_rows = 0
    held_sign_consistent_rows = 0
    if command_sign != 0:
        requested_sign_consistent_rows = sum(
            1
            for row in turn_rows
            if _finite(row["requested_steering_fraction"], "REQUESTED_STEERING")
            * requested_expected_sign
            > 1.0e-12
        )
        held_sign_consistent_rows = sum(
            1
            for row in turn_rows
            if _finite(row["held_steering_fraction"], "HELD_STEERING")
            * requested_expected_sign
            > 1.0e-12
        )

    cycle_deltas = _cycle_endpoint_deltas(r52, turn_start, cycle_steps)
    signed_cycle_responses = [command_sign * value for value in cycle_deltas]
    return {
        "arm_id": arm_id,
        "command_sign": command_sign,
        "traces": trace_receipts,
        "step_zero_physical_observations_equal": step_zero_physical_equal,
        "r48_step_zero_cross_track_error_m": _finite(
            r48[0]["cross_track_error_m"], "R48_STEP_ZERO_CROSS_TRACK"
        ),
        "r52_step_zero_cross_track_error_m": _finite(
            r52[0]["cross_track_error_m"], "R52_STEP_ZERO_CROSS_TRACK"
        ),
        "step_zero_cross_track_difference_m": _finite(
            r52[0]["cross_track_error_m"], "R52_STEP_ZERO_CROSS_TRACK"
        )
        - _finite(r48[0]["cross_track_error_m"], "R48_STEP_ZERO_CROSS_TRACK"),
        "r48_step_zero_requested_steering_fraction": _finite(
            r48[0]["requested_steering_fraction"], "R48_STEP_ZERO_REQUESTED"
        ),
        "r52_step_zero_requested_steering_fraction": _finite(
            r52[0]["requested_steering_fraction"], "R52_STEP_ZERO_REQUESTED"
        ),
        "first_controller_projection_difference_step": first_controller_difference,
        "first_torso_position_difference_step": first_position_difference,
        "first_measured_yaw_difference_step": first_yaw_difference,
        "warmup_terminal_position_distance_m": _vector_distance(
            r48[turn_start - 1]["torso_position_world_m"],
            r52[turn_start - 1]["torso_position_world_m"],
            "WARMUP_POSITION",
        ),
        "warmup_terminal_absolute_yaw_difference_rad": abs(
            _circular_delta(
                _finite(r52[turn_start - 1]["measured_yaw_rad"], "R52_WARMUP_YAW"),
                _finite(r48[turn_start - 1]["measured_yaw_rad"], "R48_WARMUP_YAW"),
            )
        ),
        "r23d52_reanchor_steps": reanchor_steps,
        "r23d52_turn_command_row_count": len(turn_rows),
        "r23d52_requested_expected_sign_row_count": requested_sign_consistent_rows,
        "r23d52_held_expected_sign_row_count": held_sign_consistent_rows,
        "r23d52_cycle_endpoint_yaw_deltas_rad": cycle_deltas,
        "r23d52_signed_cycle_endpoint_responses_rad": signed_cycle_responses,
        "r23d52_first_cycle_command_direction_correct": (
            signed_cycle_responses[0] > 0.0 if command_sign != 0 else None
        ),
        "r23d52_later_cycles_both_command_direction_wrong": (
            all(value < 0.0 for value in signed_cycle_responses[1:])
            if command_sign != 0
            else None
        ),
    }


def run_analysis(manifest_path: Path, evidence_root: Path) -> dict[str, Any]:
    manifest = _load_json(manifest_path, "MANIFEST_JSON")
    if manifest.get("schema_version") != MANIFEST_SCHEMA:
        _fail("MANIFEST_SCHEMA")
    contract = _object(manifest.get("trace_contract"), "TRACE_CONTRACT")
    pairs = _array(manifest.get("pairs"), "PAIRS")
    if len(pairs) != 3:
        _fail("PAIR_COUNT")
    projections = [
        _pair_projection(_object(pair, "PAIR"), evidence_root, contract)
        for pair in pairs
    ]
    if [item["arm_id"] for item in projections] != [
        "reference_zero",
        "positive_heading",
        "negative_heading",
    ]:
        _fail("PAIR_ORDER")
    commanded = [item for item in projections if item["command_sign"] != 0]
    aggregate = {
        "all_step_zero_physical_observations_equal": all(
            item["step_zero_physical_observations_equal"] for item in projections
        ),
        "all_pairs_controller_changed_at_step_zero": all(
            item["first_controller_projection_difference_step"] == 0
            for item in projections
        ),
        "earliest_torso_position_difference_step": min(
            item["first_torso_position_difference_step"] for item in projections
        ),
        "earliest_measured_yaw_difference_step": min(
            item["first_measured_yaw_difference_step"] for item in projections
        ),
        "all_r23d52_initial_segments_reanchored": all(
            item["r23d52_reanchor_steps"][0] == 0 for item in projections
        ),
        "warmup_trajectory_isolated_from_origin_policy": False,
        "both_commanded_arms_first_cycle_direction_correct": all(
            item["r23d52_first_cycle_command_direction_correct"] for item in commanded
        ),
        "both_commanded_arms_later_cycles_reverse_direction": all(
            item["r23d52_later_cycles_both_command_direction_wrong"]
            for item in commanded
        ),
        "negative_arm_requested_sign_consistent_every_turn_row": (
            projections[2]["r23d52_requested_expected_sign_row_count"]
            == projections[2]["r23d52_turn_command_row_count"]
        ),
        "r52_exact_policy_rejected_by_closed_result": True,
        "turn_onset_only_reanchor_result_observed": False,
    }
    return {
        "schema_version": REPORT_SCHEMA,
        "analysis_id": _string(manifest.get("analysis_id"), "ANALYSIS_ID"),
        "classification": "postoutcome_descriptive_zero_world_retained_trace_diagnosis",
        "source_trace_count": 6,
        "source_trace_row_count": sum(
            receipt["trace_row_count"]
            for item in projections
            for receipt in item["traces"].values()
        ),
        "pairs": projections,
        "aggregate_findings": aggregate,
        "supported_successor_constraint": (
            "Any further origin-timing development must preserve the fixed-initial "
            "task frame through semantic step 599 and may first reanchor at the "
            "declared commanded-turn onset, so the warmup trajectory is not changed."
        ),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "historical_result_reinterpreted": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args(argv)
    report = run_analysis(arguments.manifest, arguments.evidence_root)
    serialized = json.dumps(
        report,
        allow_nan=False,
        indent=2,
        sort_keys=True,
    ) + "\n"
    if arguments.output is not None:
        arguments.output.write_text(serialized, encoding="utf-8", newline="\n")
    print(
        "R23D52_ORIGIN_TIMING_DIAGNOSIS_PASS "
        + json.dumps(report, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
