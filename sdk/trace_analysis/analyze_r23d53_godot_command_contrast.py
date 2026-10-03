"""Diagnose R23D53 command/controller/yaw contrasts from immutable CAS traces.

This is a deterministic post-outcome analysis. It opens no physics model or
world, never changes the closed R23D53 verdict, and cannot select a successor.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Sequence


MANIFEST_SCHEMA = "sporespore_r23d53_godot_command_contrast_analysis_manifest_v1"
REPORT_SCHEMA = "sporespore_r23d53_godot_command_contrast_analysis_report_v1"
TRACE_SCHEMA = "sporespore_qsdk_r23d48_turning_trace_row_v1"
CAS_MANIFEST_SCHEMA = "sporespore_content_addressed_artifact_manifest_v1"
SHA256_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")


class CommandContrastError(RuntimeError):
    """Fail-closed analysis error with a stable marker."""


def _fail(code: str, detail: str = "") -> None:
    suffix = f":{detail}" if detail else ""
    raise CommandContrastError(f"R23D53_COMMAND_CONTRAST_{code}{suffix}")


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


def _load_cas(evidence_root: Path, digest: str, length: int) -> bytes:
    if SHA256_PATTERN.fullmatch(digest) is None:
        _fail("TRACE_SHA256")
    directory = evidence_root / "artifacts" / "sha256" / digest[7:]
    payload_path = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    if not payload_path.is_file() or not manifest_path.is_file():
        _fail("CAS_OBJECT_MISSING", digest)
    manifest = _load_json(manifest_path, "CAS_MANIFEST_JSON")
    if (
        manifest.get("schema_version") != CAS_MANIFEST_SCHEMA
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != digest
        or manifest.get("payload_name") != "payload.bin"
        or _integer(manifest.get("byte_length"), "CAS_MANIFEST_LENGTH") != length
    ):
        _fail("CAS_MANIFEST_IDENTITY", digest)
    try:
        payload = payload_path.read_bytes()
    except OSError as error:
        _fail("CAS_PAYLOAD_READ", type(error).__name__)
    if len(payload) != length:
        _fail("CAS_PAYLOAD_LENGTH", digest)
    if _sha256(payload) != digest:
        _fail("CAS_PAYLOAD_DIGEST", digest)
    return payload


def _parse_trace(
    payload: bytes,
    *,
    cell_id: str,
    expected_rows: int,
    required_numeric_fields: Sequence[str],
    unavailable_fields: Sequence[str],
) -> list[dict[str, Any]]:
    try:
        lines = payload.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        _fail("TRACE_UTF8", cell_id)
    if len(lines) != expected_rows:
        _fail("TRACE_ROW_COUNT", cell_id)
    rows: list[dict[str, Any]] = []
    for index, line in enumerate(lines):
        if not line:
            _fail("TRACE_EMPTY_LINE", f"{cell_id}:{index}")
        try:
            row = _object(json.loads(line), "TRACE_ROW_OBJECT")
        except json.JSONDecodeError:
            _fail("TRACE_JSON", f"{cell_id}:{index}")
        if (
            row.get("schema_version") != TRACE_SCHEMA
            or row.get("cell_id") != cell_id
            or _integer(row.get("semantic_step"), "TRACE_STEP") != index
        ):
            _fail("TRACE_IDENTITY", f"{cell_id}:{index}")
        for field in required_numeric_fields:
            if field not in row:
                _fail("TRACE_REQUIRED_FIELD", f"{cell_id}:{field}")
            _finite(row[field], f"TRACE_FINITE_{field.upper()}")
        if any(field in row for field in unavailable_fields):
            _fail("UNDECLARED_ACTUATOR_ATTRIBUTION_FIELD", cell_id)
        if not isinstance(row.get("steering_saturated"), bool):
            _fail("TRACE_STEERING_SATURATION_TYPE", f"{cell_id}:{index}")
        rows.append(row)
    return rows


def _circular_delta(left: float, right: float) -> float:
    return math.atan2(math.sin(left - right), math.cos(left - right))


def _classify(value: float, expected_sign: int, tolerance: float) -> str:
    if abs(value) <= tolerance:
        return "zero"
    return "correct" if value * expected_sign > 0.0 else "wrong"


def _runs(states: Sequence[str], start_step: int) -> list[dict[str, Any]]:
    if not states:
        return []
    result: list[dict[str, Any]] = []
    run_state = states[0]
    run_start = start_step
    for offset, state in enumerate(states[1:], start=1):
        if state != run_state:
            result.append(
                {
                    "start_semantic_step": run_start,
                    "end_semantic_step": start_step + offset - 1,
                    "state": run_state,
                }
            )
            run_state = state
            run_start = start_step + offset
    result.append(
        {
            "start_semantic_step": run_start,
            "end_semantic_step": start_step + len(states) - 1,
            "state": run_state,
        }
    )
    return result


def _state_counts(states: Sequence[str]) -> dict[str, int]:
    return {name: sum(state == name for state in states) for name in ("correct", "zero", "wrong")}


def _mean(values: Sequence[float]) -> float:
    if not values:
        _fail("EMPTY_MEAN")
    return math.fsum(values) / len(values)


def run_analysis(manifest_path: Path, evidence_root: Path) -> dict[str, Any]:
    manifest = _load_json(manifest_path, "MANIFEST_JSON")
    if manifest.get("schema_version") != MANIFEST_SCHEMA:
        _fail("MANIFEST_SCHEMA")
    if manifest.get("status") != "postclosure_outcome_exposed_descriptive_zero_world_diagnosis":
        _fail("MANIFEST_STATUS")
    exposure = _object(manifest.get("data_exposure_boundary"), "EXPOSURE_BOUNDARY")
    if (
        exposure.get("r23d53_outcomes_already_observed") is not True
        or exposure.get("projection_is_descriptive_not_confirmatory") is not True
        or exposure.get("r23d53_verdict_unchanged") is not True
        or exposure.get("r23d53_exact_policy_rejected") is not True
        or exposure.get("fresh_held_out_condition_consumed") is not False
        or exposure.get("future_successor_physical_outcome_known") is not False
    ):
        _fail("EXPOSURE_BOUNDARY")
    claim_limits = _object(manifest.get("claim_limits"), "CLAIM_LIMITS")
    if any(value is not False for value in claim_limits.values()):
        _fail("CLAIM_INFLATION")
    attribution = _object(manifest.get("attribution_boundary"), "ATTRIBUTION_BOUNDARY")
    if (
        attribution.get("origin_timing_only_successor_supported") is not False
        or attribution.get("missing_or_inverted_negative_command_hypothesis_may_be_selected") is not False
        or attribution.get("reported_steering_saturation_hypothesis_may_be_selected") is not False
        or attribution.get("actuator_or_contact_phase_mechanism_may_be_selected_from_current_trace") is not False
        or attribution.get("next_attribution_schema_requires_final_per_actuator_commands_and_declared_limits") is not True
        or attribution.get("next_attribution_schema_requires_contact_phase_alignment") is not True
        or attribution.get("schema_and_evaluator_mutation_controls_required_before_any_new_world") is not True
        or attribution.get("physical_successor_selected") is not False
    ):
        _fail("ATTRIBUTION_BOUNDARY")

    contract = _object(manifest.get("trace_contract"), "TRACE_CONTRACT")
    expected_rows = _integer(contract.get("expected_trace_row_count"), "EXPECTED_ROWS")
    warmup_end = _integer(contract.get("warmup_end_semantic_step_exclusive"), "WARMUP_END")
    turn_start = _integer(contract.get("turn_start_semantic_step"), "TURN_START")
    turn_end = _integer(contract.get("turn_end_semantic_step_exclusive"), "TURN_END")
    cycle_steps = _integer(contract.get("gait_cycle_steps"), "CYCLE_STEPS")
    tolerance = _finite(contract.get("contrast_zero_tolerance"), "ZERO_TOLERANCE")
    if not (expected_rows == 2992 and warmup_end == turn_start == 600 and turn_end == 1800 and cycle_steps == 360):
        _fail("INHERITED_SCHEDULE")
    expected_reanchors = [_integer(value, "REANCHOR_STEP") for value in _array(contract.get("expected_reanchor_steps"), "REANCHOR_STEPS")]
    if expected_reanchors != [600, 1800, 2400]:
        _fail("REANCHOR_SCHEDULE")
    warmup_fields = [_string(value, "WARMUP_FIELD") for value in _array(contract.get("warmup_equivalence_fields"), "WARMUP_FIELDS")]
    required_numeric = [_string(value, "NUMERIC_FIELD") for value in _array(contract.get("required_numeric_fields"), "NUMERIC_FIELDS")]
    unavailable_fields = [_string(value, "ATTRIBUTION_FIELD") for value in _array(contract.get("actuator_attribution_fields_absent_from_this_trace_schema"), "ATTRIBUTION_FIELDS")]

    arm_declarations = _array(manifest.get("ordered_arms"), "ORDERED_ARMS")
    if len(arm_declarations) != 3:
        _fail("ARM_COUNT")
    expected_order = ["reference_zero", "positive_heading", "negative_heading"]
    if [arm.get("arm_id") for arm in arm_declarations if isinstance(arm, dict)] != expected_order:
        _fail("ARM_ORDER")

    traces: dict[str, list[dict[str, Any]]] = {}
    trace_receipts: list[dict[str, Any]] = []
    command_signs: dict[str, int] = {}
    for declaration_value in arm_declarations:
        declaration = _object(declaration_value, "ARM_DECLARATION")
        arm_id = _string(declaration.get("arm_id"), "ARM_ID")
        sign = _integer(declaration.get("command_sign"), "COMMAND_SIGN")
        if sign not in (-1, 0, 1):
            _fail("COMMAND_SIGN", arm_id)
        offset = _finite(declaration.get("desired_heading_offset_rad"), "DECLARED_OFFSET")
        if offset != sign * 0.2:
            _fail("DECLARED_OFFSET", arm_id)
        cell_id = _string(declaration.get("cell_id"), "CELL_ID")
        digest = _string(declaration.get("trace_sha256"), "TRACE_SHA256")
        length = _integer(declaration.get("trace_byte_length"), "TRACE_LENGTH")
        payload = _load_cas(evidence_root, digest, length)
        rows = _parse_trace(
            payload,
            cell_id=cell_id,
            expected_rows=expected_rows,
            required_numeric_fields=required_numeric,
            unavailable_fields=unavailable_fields,
        )
        reanchors = [index for index, row in enumerate(rows) if row.get("task_frame_origin_reanchored_this_step") is True]
        if reanchors != expected_reanchors:
            _fail("TRACE_REANCHOR_STEPS", arm_id)
        if any(row.get("task_frame_origin_policy_id") != contract.get("task_frame_origin_policy_id") for row in rows):
            _fail("TRACE_ORIGIN_POLICY", arm_id)
        if any(
            _finite(row["desired_heading_offset_rad"], "TRACE_OFFSET")
            != (offset if turn_start <= index < turn_end else 0.0)
            for index, row in enumerate(rows)
        ):
            _fail("TRACE_COMMAND_SCHEDULE", arm_id)
        traces[arm_id] = rows
        command_signs[arm_id] = sign
        trace_receipts.append(
            {
                "arm_id": arm_id,
                "cell_id": cell_id,
                "trace_sha256": digest,
                "trace_byte_length": length,
                "trace_row_count": len(rows),
            }
        )

    reference = traces["reference_zero"]
    warmup_mismatch_fields: list[str] = []
    for arm_id in ("positive_heading", "negative_heading"):
        for field in warmup_fields:
            if any(traces[arm_id][index].get(field) != reference[index].get(field) for index in range(warmup_end)):
                warmup_mismatch_fields.append(f"{arm_id}:{field}")
    if warmup_mismatch_fields:
        _fail("WARMUP_NOT_IDENTICAL", warmup_mismatch_fields[0])

    windows = [
        ("cycle_1", 600, 960),
        ("cycle_2", 960, 1320),
        ("cycle_3", 1320, 1680),
        ("turn_tail", 1680, 1800),
    ]
    arm_results: list[dict[str, Any]] = []
    for arm_id in ("positive_heading", "negative_heading"):
        rows = traces[arm_id]
        command_sign = command_signs[arm_id]
        steering_expected_sign = -command_sign
        yaw_expected_sign = command_sign
        desired_contrasts: list[float] = []
        requested_contrasts: list[float] = []
        held_contrasts: list[float] = []
        yaw_effects: list[float] = []
        saturated_rows = 0
        for index in range(turn_start, turn_end):
            desired_contrasts.append(_finite(rows[index]["desired_heading_error_rad"], "DESIRED") - _finite(reference[index]["desired_heading_error_rad"], "REFERENCE_DESIRED"))
            requested_contrasts.append(_finite(rows[index]["requested_steering_fraction"], "REQUESTED") - _finite(reference[index]["requested_steering_fraction"], "REFERENCE_REQUESTED"))
            held_contrasts.append(_finite(rows[index]["held_steering_fraction"], "HELD") - _finite(reference[index]["held_steering_fraction"], "REFERENCE_HELD"))
            yaw_effects.append(_circular_delta(_finite(rows[index]["measured_yaw_rad"], "YAW"), _finite(reference[index]["measured_yaw_rad"], "REFERENCE_YAW")))
            saturated_rows += int(rows[index]["steering_saturated"] is True)

        desired_states = [_classify(value, command_sign, tolerance) for value in desired_contrasts]
        requested_states = [_classify(value, steering_expected_sign, tolerance) for value in requested_contrasts]
        held_states = [_classify(value, steering_expected_sign, tolerance) for value in held_contrasts]
        yaw_states = [_classify(value, yaw_expected_sign, tolerance) for value in yaw_effects]
        window_results: list[dict[str, Any]] = []
        for name, start, end in windows:
            local_start = start - turn_start
            local_end = end - turn_start
            window_results.append(
                {
                    "window_id": name,
                    "start_semantic_step": start,
                    "end_semantic_step_exclusive": end,
                    "desired_heading_contrast_mean": _mean(desired_contrasts[local_start:local_end]),
                    "requested_steering_contrast_mean": _mean(requested_contrasts[local_start:local_end]),
                    "held_steering_contrast_mean": _mean(held_contrasts[local_start:local_end]),
                    "yaw_effect_at_window_end_rad": yaw_effects[local_end - 1],
                }
            )
        arm_results.append(
            {
                "arm_id": arm_id,
                "command_sign": command_sign,
                "turn_row_count": turn_end - turn_start,
                "desired_heading_contrast": {
                    "counts": _state_counts(desired_states),
                    "runs": _runs(desired_states, turn_start),
                },
                "requested_steering_contrast": {
                    "counts": _state_counts(requested_states),
                    "runs": _runs(requested_states, turn_start),
                },
                "held_steering_contrast": {
                    "counts": _state_counts(held_states),
                    "runs": _runs(held_states, turn_start),
                },
                "yaw_effect_vs_reference": {
                    "counts": _state_counts(yaw_states),
                    "runs": _runs(yaw_states, turn_start),
                    "minimum_rad": min(yaw_effects),
                    "maximum_rad": max(yaw_effects),
                    "terminal_rad": yaw_effects[-1],
                },
                "reported_steering_saturated_row_count": saturated_rows,
                "windows": window_results,
            }
        )

    by_arm = {item["arm_id"]: item for item in arm_results}
    positive = by_arm["positive_heading"]
    negative = by_arm["negative_heading"]
    aggregate = {
        "all_600_warmup_rows_identical_across_arms": True,
        "origin_timing_confound_removed": True,
        "both_desired_heading_contrasts_correct_all_turn_rows": all(
            item["desired_heading_contrast"]["counts"]["correct"] == 1200
            for item in arm_results
        ),
        "all_turn_rows_report_steering_unsaturated": all(
            item["reported_steering_saturated_row_count"] == 0 for item in arm_results
        ) and sum(row["steering_saturated"] is True for row in reference[turn_start:turn_end]) == 0,
        "positive_held_contrast_correct_row_count": positive["held_steering_contrast"]["counts"]["correct"],
        "positive_yaw_effect_correct_row_count": positive["yaw_effect_vs_reference"]["counts"]["correct"],
        "negative_held_contrast_correct_row_count": negative["held_steering_contrast"]["counts"]["correct"],
        "negative_yaw_effect_correct_row_count": negative["yaw_effect_vs_reference"]["counts"]["correct"],
        "negative_held_contrast_majority_correct": negative["held_steering_contrast"]["counts"]["correct"] > 600,
        "negative_yaw_effect_majority_correct": negative["yaw_effect_vs_reference"]["counts"]["correct"] > 600,
        "negative_terminal_yaw_effect_direction_correct": negative["yaw_effect_vs_reference"]["terminal_rad"] < 0.0,
        "actuator_level_attribution_available": False,
        "physical_successor_selected": False,
    }
    return {
        "schema_version": REPORT_SCHEMA,
        "analysis_id": _string(manifest.get("analysis_id"), "ANALYSIS_ID"),
        "classification": "postoutcome_descriptive_zero_world_retained_trace_diagnosis",
        "source_trace_count": 3,
        "source_trace_row_count": 3 * expected_rows,
        "trace_receipts": trace_receipts,
        "arm_contrasts": arm_results,
        "aggregate_findings": aggregate,
        "supported_interpretation": {
            "origin_timing_only_explanation_supported": False,
            "missing_or_inverted_negative_command_explanation_supported": False,
            "reported_steering_saturation_explanation_supported": False,
            "controller_to_physics_directional_conversion_requires_further_attribution": True,
            "current_trace_can_choose_actuator_or_contact_phase_mechanism": False,
            "next_zero_world_boundary_is_actuator_and_contact_phase_trace_schema_plus_evaluator_controls": True,
        },
        "immutable_official_result": manifest.get("immutable_official_result"),
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
    serialized = json.dumps(report, allow_nan=False, indent=2, sort_keys=True) + "\n"
    if arguments.output is not None:
        arguments.output.write_text(serialized, encoding="utf-8", newline="\n")
    print("R23D53_COMMAND_CONTRAST_DIAGNOSIS_PASS " + json.dumps(report, allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
