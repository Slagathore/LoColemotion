"""Read-only cross-seed diagnosis for the R23D43 Rapier turning lineage.

This program reads only exact content-addressed trace payloads.  It compares
three already-exposed no-startup-ramp triplets with three already-exposed
startup-ramped triplets under one cycle-integrated estimator.  It constructs
no model or physics world, changes no closed verdict, estimates no causal or
population effect, and authorizes no threshold, candidate, or physical run.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Sequence


MANIFEST_SCHEMA = (
    "sporespore_r23d43_rapier_startup_transform_analysis_manifest_v1"
)
REPORT_SCHEMA = "sporespore_r23d43_rapier_startup_transform_analysis_report_v1"
CAS_MANIFEST_SCHEMA = "sporespore_content_addressed_artifact_manifest_v1"
SHA256_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")


class StartupTransformAnalysisError(RuntimeError):
    """Fail-closed diagnostic error with a stable machine-readable code."""


def _fail(code: str, detail: str = "") -> None:
    suffix = f":{detail}" if detail else ""
    raise StartupTransformAnalysisError(f"R23D43_STARTUP_DIAG_{code}{suffix}")


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


def _boolean(value: Any, code: str) -> bool:
    if not isinstance(value, bool):
        _fail(code)
    return value


def _number(value: Any, code: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _fail(code)
    result = float(value)
    if not math.isfinite(result):
        _fail(code)
    return result


def _sha256_bytes(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def _sha256(value: Any, code: str) -> str:
    result = _string(value, code)
    if SHA256_PATTERN.fullmatch(result) is None:
        _fail(code)
    return result


def _mean(values: Sequence[float]) -> float:
    if not values:
        _fail("EMPTY_MEAN")
    return math.fsum(values) / len(values)


def _load_json_object(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        _fail(code, type(error).__name__)
    return _object(value, code)


def _load_cas_payload(
    evidence_root: Path,
    expected_sha256: str,
    expected_length: int,
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
    if _sha256_bytes(payload) != expected_sha256:
        _fail("CAS_PAYLOAD_DIGEST", digest)
    return payload


def _phase_vector(contract: dict[str, Any]) -> list[str]:
    phases: list[str] = []
    for index, item_value in enumerate(_array(contract.get("phase_order"), "PHASES")):
        item = _object(item_value, f"PHASE_{index}")
        phase_id = _string(item.get("phase_id"), f"PHASE_ID_{index}")
        count = _integer(item.get("row_count"), f"PHASE_COUNT_{index}")
        if count <= 0:
            _fail("PHASE_COUNT_NONPOSITIVE", phase_id)
        phases.extend([phase_id] * count)
    expected = _integer(
        contract.get("expected_row_count_per_cell"), "EXPECTED_ROW_COUNT"
    )
    if len(phases) != expected:
        _fail("PHASE_TOTAL")
    return phases


def _parse_payload(payload: bytes, encoding: str, code: str) -> list[dict[str, Any]]:
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError:
        _fail("TRACE_UTF8", code)
    rows_value: Any
    if encoding == "jsonl":
        if not text.endswith("\n"):
            _fail("TRACE_FINAL_NEWLINE", code)
        lines = text.splitlines()
        if any(not line for line in lines):
            _fail("TRACE_EMPTY_LINE", code)
        try:
            rows_value = [json.loads(line) for line in lines]
        except json.JSONDecodeError:
            _fail("TRACE_JSONL", code)
    elif encoding == "json_array":
        try:
            rows_value = json.loads(text)
        except json.JSONDecodeError:
            _fail("TRACE_JSON_ARRAY", code)
    else:
        _fail("TRACE_ENCODING", encoding)
    rows = _array(rows_value, "TRACE_ROWS")
    return [_object(row, f"TRACE_ROW_{index}") for index, row in enumerate(rows)]


def _smoothstep_scale(step: int, ramp_last_step: int) -> float:
    if step >= ramp_last_step:
        return 1.0
    progress = step / ramp_last_step
    return progress * progress * (3.0 - 2.0 * progress)


def _unwrap_yaw(rows: Sequence[dict[str, Any]], code: str) -> list[float]:
    raw = [_number(row.get("measured_yaw_rad"), "MEASURED_YAW") for row in rows]
    if not raw:
        _fail("EMPTY_YAW", code)
    result = [raw[0]]
    for index in range(1, len(raw)):
        delta = math.remainder(raw[index] - raw[index - 1], 2.0 * math.pi)
        if not math.isfinite(delta) or math.isclose(
            abs(delta), math.pi, abs_tol=1.0e-12
        ):
            _fail("YAW_UNWRAP", f"{code}:{index}")
        result.append(result[-1] + delta)
    return result


def _sign_consistent(value: float, expected_sign: int, tolerance: float) -> bool:
    if expected_sign > 0:
        return value > tolerance
    if expected_sign < 0:
        return value < -tolerance
    return abs(value) <= tolerance


def _analyze_cell(
    payload: bytes,
    *,
    campaign: dict[str, Any],
    cell: dict[str, Any],
    contract: dict[str, Any],
    expected_phases: Sequence[str],
) -> tuple[dict[str, Any], list[float]]:
    campaign_key = _string(campaign.get("campaign_key"), "CAMPAIGN_KEY")
    arm_id = _string(cell.get("arm_id"), "ARM_ID")
    cell_id = _string(cell.get("cell_id"), "CELL_ID")
    rows = _parse_payload(
        payload,
        _string(campaign.get("trace_encoding"), "TRACE_ENCODING"),
        f"{campaign_key}:{arm_id}",
    )
    expected_count = _integer(
        contract.get("expected_row_count_per_cell"), "EXPECTED_ROW_COUNT"
    )
    if len(rows) != expected_count:
        _fail("TRACE_ROW_COUNT", f"{campaign_key}:{arm_id}")
    schema = _string(campaign.get("trace_schema_version"), "TRACE_SCHEMA")
    seed = _integer(campaign.get("seed"), "CAMPAIGN_SEED")
    ramped = _boolean(campaign.get("startup_ramp_applied"), "RAMP_APPLIED")
    offsets = _object(contract.get("heading_offset_rad_by_arm"), "OFFSETS")
    if arm_id not in offsets:
        _fail("ARM_OFFSET", arm_id)
    command_offset = _number(offsets[arm_id], "ARM_OFFSET")
    ramp = _object(contract.get("startup_ramp"), "RAMP_CONTRACT")
    ramp_id = _string(ramp.get("ramp_id"), "RAMP_ID")
    ramp_steps = _integer(ramp.get("ramp_step_count"), "RAMP_STEPS")
    ramp_last_step = ramp_steps - 1
    ramp_active_count = 0
    ramp_zero_count = 0
    ramp_unity_count = 0
    maximum_ramp_error = 0.0
    maximum_tilt = 0.0
    minimum_height = math.inf
    maximum_joint_error = 0.0
    torso_contact_count = 0
    command_rows: list[dict[str, Any]] = []

    forbidden_ramp_fields = (
        "startup_ramp_id",
        "startup_velocity_scale",
        "startup_ramp_active",
        "startup_ramp_residual_count",
        "startup_ramp_maximum_absolute_residual_rad_s",
    )
    for index, row in enumerate(rows):
        row_code = f"{campaign_key}:{arm_id}:{index}"
        if row.get("schema_version") != schema:
            _fail("TRACE_SCHEMA", row_code)
        if row.get("cell_id") != cell_id:
            _fail("TRACE_CELL", row_code)
        if _integer(row.get("trace_step"), "TRACE_STEP") != index:
            _fail("TRACE_STEP", row_code)
        if row.get("phase_id") != expected_phases[index]:
            _fail("TRACE_PHASE", row_code)
        if _integer(row.get("campaign_seed"), "ROW_CAMPAIGN_SEED") != seed:
            _fail("TRACE_SEED", row_code)
        expected_offset = command_offset if expected_phases[index] == "commanded_turn" else 0.0
        if not math.isclose(
            _number(row.get("desired_heading_offset_rad"), "ROW_HEADING_OFFSET"),
            expected_offset,
            abs_tol=1.0e-15,
        ):
            _fail("TRACE_HEADING_OFFSET", row_code)
        if _integer(row.get("actuator_command_count"), "ACTUATOR_COUNT") != 8:
            _fail("TRACE_ACTUATOR_COUNT", row_code)
        if _integer(
            row.get("native_actuation_application_count"), "APPLICATION_COUNT"
        ) != 8:
            _fail("TRACE_APPLICATION_COUNT", row_code)
        contacts = row.get("ordered_foot_contacts")
        if (
            not isinstance(contacts, dict)
            or list(contacts) != [
                "front_left",
                "front_right",
                "rear_left",
                "rear_right",
            ]
            or any(not isinstance(value, bool) for value in contacts.values())
        ):
            _fail("TRACE_FOOT_CONTACTS", row_code)
        torso_contact = _boolean(row.get("torso_ground_contact"), "TORSO_CONTACT")
        torso_contact_count += int(torso_contact)
        maximum_tilt = max(
            maximum_tilt, _number(row.get("torso_tilt_rad"), "TORSO_TILT")
        )
        minimum_height = min(
            minimum_height, _number(row.get("torso_height_m"), "TORSO_HEIGHT")
        )
        maximum_joint_error = max(
            maximum_joint_error,
            _number(
                row.get("maximum_absolute_joint_position_error_rad"),
                "JOINT_ERROR",
            ),
        )
        _number(row.get("requested_steering_fraction"), "REQUESTED_STEERING")
        _number(row.get("held_steering_fraction"), "HELD_STEERING")
        _boolean(row.get("steering_saturated"), "STEERING_SATURATED")
        if expected_phases[index] == "commanded_turn":
            command_rows.append(row)

        if ramped:
            if row.get("startup_ramp_id") != ramp_id:
                _fail("TRACE_RAMP_ID", row_code)
            expected_scale = _smoothstep_scale(index, ramp_last_step)
            observed_scale = _number(
                row.get("startup_velocity_scale"), "RAMP_SCALE"
            )
            error = abs(observed_scale - expected_scale)
            maximum_ramp_error = max(maximum_ramp_error, error)
            if error > 1.0e-12:
                _fail("TRACE_RAMP_SCALE", row_code)
            expected_active = expected_scale < 1.0
            if _boolean(row.get("startup_ramp_active"), "RAMP_ACTIVE") != expected_active:
                _fail("TRACE_RAMP_ACTIVE", row_code)
            if _integer(row.get("startup_ramp_residual_count"), "RAMP_RESIDUALS") != 8:
                _fail("TRACE_RAMP_RESIDUAL_COUNT", row_code)
            reported_residual = _number(
                row.get("startup_ramp_maximum_absolute_residual_rad_s"),
                "RAMP_RESIDUAL",
            )
            if reported_residual < 0.0 or (
                expected_scale == 1.0 and abs(reported_residual) > 1.0e-12
            ):
                _fail("TRACE_RAMP_RESIDUAL", row_code)
            ramp_active_count += int(expected_active)
            ramp_zero_count += int(expected_scale == 0.0)
            ramp_unity_count += int(expected_scale == 1.0)
        elif any(field in row for field in forbidden_ramp_fields):
            _fail("TRACE_UNDECLARED_RAMP_FIELD", row_code)

    if ramped and (
        ramp_active_count != _integer(ramp.get("active_step_count"), "RAMP_ACTIVE_COUNT")
        or ramp_zero_count != 1
        or ramp_unity_count != expected_count - ramp_active_count
    ):
        _fail("TRACE_RAMP_COUNTS", f"{campaign_key}:{arm_id}")

    unwrapped = _unwrap_yaw(rows, f"{campaign_key}:{arm_id}")
    baseline = [_integer(value, "BASELINE_WINDOW") for value in _array(contract.get("baseline_window"), "BASELINE_WINDOW")]
    terminal = [_integer(value, "TERMINAL_WINDOW") for value in _array(contract.get("terminal_window"), "TERMINAL_WINDOW")]
    if (
        len(baseline) != 2
        or len(terminal) != 2
        or not (0 <= baseline[0] < baseline[1] <= terminal[0] < terminal[1] <= len(rows))
    ):
        _fail("MEASUREMENT_WINDOWS")
    baseline_mean = _mean(unwrapped[baseline[0] : baseline[1]])
    terminal_mean = _mean(unwrapped[terminal[0] : terminal[1]])
    cycle_shift = terminal_mean - baseline_mean

    delivery: dict[str, Any] | None = None
    if arm_id != "reference_zero":
        signs = _object(contract.get("expected_steering_sign_by_arm"), "STEERING_SIGNS")
        expected_sign = _integer(signs.get(arm_id), "STEERING_SIGN")
        tolerance = _number(contract.get("steering_zero_tolerance"), "STEERING_TOLERANCE")
        requested = [
            _number(row["requested_steering_fraction"], "REQUESTED_STEERING")
            for row in command_rows
        ]
        held = [
            _number(row["held_steering_fraction"], "HELD_STEERING")
            for row in command_rows
        ]
        delivery = {
            "expected_steering_sign": expected_sign,
            "row_count": len(command_rows),
            "requested_sign_consistent_row_count": sum(
                _sign_consistent(value, expected_sign, tolerance)
                for value in requested
            ),
            "held_sign_consistent_row_count": sum(
                _sign_consistent(value, expected_sign, tolerance) for value in held
            ),
            "mean_absolute_requested_steering_fraction": _mean(
                [abs(value) for value in requested]
            ),
            "mean_absolute_held_steering_fraction": _mean(
                [abs(value) for value in held]
            ),
            "steering_saturation_row_count": sum(
                _boolean(row["steering_saturated"], "STEERING_SATURATED")
                for row in command_rows
            ),
        }

    return (
        {
            "arm_id": arm_id,
            "cell_id": cell_id,
            "trace_sha256": _sha256(cell.get("trace_sha256"), "TRACE_SHA256"),
            "trace_byte_length": _integer(
                cell.get("trace_byte_length"), "TRACE_LENGTH"
            ),
            "trace_row_count": len(rows),
            "baseline_yaw_mean_rad": baseline_mean,
            "terminal_yaw_mean_rad": terminal_mean,
            "cycle_shift_rad": cycle_shift,
            "maximum_torso_tilt_rad": maximum_tilt,
            "minimum_torso_height_m": minimum_height,
            "maximum_absolute_joint_position_error_rad": maximum_joint_error,
            "torso_ground_contact_row_count": torso_contact_count,
            "command_delivery": delivery,
            "startup_ramp_validation": {
                "startup_ramp_applied": ramped,
                "active_step_count": ramp_active_count if ramped else 0,
                "exact_zero_scale_step_count": ramp_zero_count if ramped else 0,
                "exact_unity_scale_step_count": ramp_unity_count if ramped else 0,
                "maximum_absolute_scale_error": maximum_ramp_error,
                "undeclared_ramp_field_count": 0,
            },
        },
        unwrapped,
    )


def _campaign_projection(
    campaign: dict[str, Any],
    cells: Sequence[dict[str, Any]],
    unwrapped_by_arm: dict[str, Sequence[float]],
    threshold: float,
    contract: dict[str, Any],
) -> dict[str, Any]:
    by_arm = {cell["arm_id"]: cell for cell in cells}
    expected_arms = [
        _string(value, "ORDERED_ARM")
        for value in _array(contract.get("ordered_arm_ids"), "ORDERED_ARMS")
    ]
    if list(by_arm) != expected_arms or set(unwrapped_by_arm) != set(expected_arms):
        _fail("CAMPAIGN_ARM_SET", _string(campaign.get("campaign_key"), "CAMPAIGN_KEY"))
    reference = by_arm["reference_zero"]["cycle_shift_rad"]
    positive = by_arm["positive_heading"]["cycle_shift_rad"]
    negative = by_arm["negative_heading"]["cycle_shift_rad"]
    positive_conditioned = positive - reference
    negative_conditioned = reference - negative
    raw_pass = positive >= threshold and negative <= -threshold
    conditioned_pass = (
        positive_conditioned >= threshold and negative_conditioned >= threshold
    )

    baseline = [_integer(value, "BASELINE_WINDOW") for value in _array(contract.get("baseline_window"), "BASELINE_WINDOW")]
    turn_start = sum(
        _integer(item.get("row_count"), "PHASE_COUNT")
        for item in [
            _object(value, "PHASE")
            for value in _array(contract.get("phase_order"), "PHASES")
        ][:1]
    )
    turn_count = _integer(
        _object(_array(contract.get("phase_order"), "PHASES")[1], "TURN_PHASE").get(
            "row_count"
        ),
        "TURN_COUNT",
    )
    reference_yaw = unwrapped_by_arm["reference_zero"]
    response_summary: dict[str, Any] = {}
    for arm_id, sign in (("positive_heading", 1), ("negative_heading", -1)):
        arm_yaw = unwrapped_by_arm[arm_id]
        baseline_difference = _mean(
            [
                arm_yaw[index] - reference_yaw[index]
                for index in range(baseline[0], baseline[1])
            ]
        )
        signed_response = [
            sign
            * (
                arm_yaw[index]
                - reference_yaw[index]
                - baseline_difference
            )
            for index in range(turn_start, turn_start + turn_count)
        ]
        peak = max(signed_response)
        peak_index = signed_response.index(peak)
        met = [value >= threshold for value in signed_response]
        response_summary[arm_id] = {
            "peak_conditioned_response_rad": peak,
            "peak_conditioned_response_step": turn_start + peak_index,
            "threshold_met_row_count": sum(met),
            "first_threshold_met_step": (
                turn_start + met.index(True) if any(met) else None
            ),
        }

    return {
        "campaign_key": _string(campaign.get("campaign_key"), "CAMPAIGN_KEY"),
        "seed": _integer(campaign.get("seed"), "CAMPAIGN_SEED"),
        "gait_phase_offset_ticks": _integer(
            campaign.get("gait_phase_offset_ticks"), "GAIT_PHASE_OFFSET"
        ),
        "startup_ramp_applied": _boolean(
            campaign.get("startup_ramp_applied"), "RAMP_APPLIED"
        ),
        "historical_authority": _string(
            campaign.get("historical_authority"), "HISTORICAL_AUTHORITY"
        ),
        "closure": _object(campaign.get("closure"), "CLOSURE"),
        "source_physical_commit": _string(
            campaign.get("source_physical_commit"), "SOURCE_COMMIT"
        ),
        "cells": list(cells),
        "cycle_integrated_measurement": {
            "minimum_cycle_shift_rad": threshold,
            "raw_reference_cycle_shift_rad": reference,
            "raw_positive_cycle_shift_rad": positive,
            "raw_negative_cycle_shift_rad": negative,
            "positive_reference_conditioned_cycle_shift_rad": positive_conditioned,
            "negative_reference_conditioned_cycle_shift_rad": negative_conditioned,
            "bilateral_reference_conditioned_cycle_separation_rad": (
                positive_conditioned + negative_conditioned
            ),
            "raw_signed_cycle_shift_gate_passed": raw_pass,
            "reference_conditioned_cycle_shift_gate_passed": conditioned_pass,
            "positive_conditioned_gate_passed": positive_conditioned >= threshold,
            "negative_conditioned_gate_passed": negative_conditioned >= threshold,
        },
        "commanded_phase_response": response_summary,
    }


def _range(values: Sequence[float]) -> dict[str, float]:
    return {"minimum": min(values), "maximum": max(values), "mean": _mean(values)}


def _group_projection(
    group: dict[str, Any],
    campaign_by_key: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    keys = [
        _string(value, "GROUP_CAMPAIGN_KEY")
        for value in _array(group.get("ordered_campaign_keys"), "GROUP_CAMPAIGNS")
    ]
    if len(keys) != len(set(keys)) or any(key not in campaign_by_key for key in keys):
        _fail("GROUP_CAMPAIGNS", _string(group.get("group_id"), "GROUP_ID"))
    campaigns = [campaign_by_key[key] for key in keys]
    ramped = _boolean(group.get("startup_ramp_applied"), "GROUP_RAMP")
    if any(campaign["startup_ramp_applied"] is not ramped for campaign in campaigns):
        _fail("GROUP_RAMP_MISMATCH", _string(group.get("group_id"), "GROUP_ID"))
    measurements = [campaign["cycle_integrated_measurement"] for campaign in campaigns]
    return {
        "group_id": _string(group.get("group_id"), "GROUP_ID"),
        "startup_ramp_applied": ramped,
        "ordered_campaign_keys": keys,
        "seed_count": len(campaigns),
        "seeds": [campaign["seed"] for campaign in campaigns],
        "gait_phase_offset_ticks": [
            campaign["gait_phase_offset_ticks"] for campaign in campaigns
        ],
        "raw_signed_gate_pass_count": sum(
            measurement["raw_signed_cycle_shift_gate_passed"]
            for measurement in measurements
        ),
        "conditioned_gate_pass_count": sum(
            measurement["reference_conditioned_cycle_shift_gate_passed"]
            for measurement in measurements
        ),
        "reference_raw_cycle_shift_rad": _range(
            [measurement["raw_reference_cycle_shift_rad"] for measurement in measurements]
        ),
        "positive_raw_cycle_shift_rad": _range(
            [measurement["raw_positive_cycle_shift_rad"] for measurement in measurements]
        ),
        "negative_raw_cycle_shift_rad": _range(
            [measurement["raw_negative_cycle_shift_rad"] for measurement in measurements]
        ),
        "positive_reference_conditioned_cycle_shift_rad": _range(
            [
                measurement["positive_reference_conditioned_cycle_shift_rad"]
                for measurement in measurements
            ]
        ),
        "negative_reference_conditioned_cycle_shift_rad": _range(
            [
                measurement["negative_reference_conditioned_cycle_shift_rad"]
                for measurement in measurements
            ]
        ),
        "bilateral_reference_conditioned_cycle_separation_rad": _range(
            [
                measurement[
                    "bilateral_reference_conditioned_cycle_separation_rad"
                ]
                for measurement in measurements
            ]
        ),
    }


def run_analysis(
    manifest_path: Path,
    evidence_root: Path,
    analyzer_source_commit: str,
) -> dict[str, Any]:
    if COMMIT_PATTERN.fullmatch(analyzer_source_commit) is None:
        _fail("ANALYZER_SOURCE_COMMIT")
    try:
        manifest_bytes = manifest_path.read_bytes()
    except OSError as error:
        _fail("MANIFEST_READ", type(error).__name__)
    try:
        manifest = _object(json.loads(manifest_bytes), "MANIFEST_JSON")
    except (UnicodeError, json.JSONDecodeError):
        _fail("MANIFEST_JSON")
    if manifest.get("schema_version") != MANIFEST_SCHEMA:
        _fail("MANIFEST_SCHEMA")
    if manifest.get("question_class") != "postclosure_development_diagnosis":
        _fail("QUESTION_CLASS")

    exposure = _object(manifest.get("data_exposure_boundary"), "EXPOSURE_BOUNDARY")
    expected_exposure = {
        "all_six_campaign_outcomes_already_observed": True,
        "projection_is_descriptive_not_confirmatory": True,
        "closed_campaign_verdicts_remain_unchanged": True,
        "r23d41_r23d42_r23d43_rapier_rows_are_postclosure_diagnostic_inputs": True,
        "startup_transform_and_seed_are_confounded": True,
        "causal_startup_transform_effect_identified": False,
        "candidate_or_parameter_selected_by_this_analysis": False,
        "future_physical_identity_opened": False,
    }
    if exposure != expected_exposure:
        _fail("EXPOSURE_BOUNDARY")

    contract = _object(manifest.get("analysis_contract"), "ANALYSIS_CONTRACT")
    expected_contract = {
        "engine_id": "rapier_parry",
        "controller_policy_id": (
            "sporespore_balanced_wave_r23d29_two_swing_persistent_"
            "predictive_stability_guarded_steering_v1"
        ),
        "morphology_id": "qsdk_r05_generated_s169",
        "physics_hz": 120,
        "expected_row_count_per_cell": 2992,
        "ordered_arm_ids": [
            "reference_zero",
            "positive_heading",
            "negative_heading",
        ],
        "heading_offset_rad_by_arm": {
            "reference_zero": 0.0,
            "positive_heading": 0.2,
            "negative_heading": -0.2,
        },
        "phase_order": [
            {"phase_id": "reference_warmup", "row_count": 600},
            {"phase_id": "commanded_turn", "row_count": 1200},
            {"phase_id": "reference_recovery", "row_count": 600},
            {"phase_id": "reference_continuation", "row_count": 592},
        ],
        "baseline_window": [240, 600],
        "terminal_window": [1440, 1800],
        "scheduler_swing_steps": 72,
        "scheduler_cycle_steps": 360,
        "expected_steering_sign_by_arm": {
            "positive_heading": -1,
            "negative_heading": 1,
        },
        "steering_zero_tolerance": 1.0e-12,
        "startup_ramp": {
            "ramp_id": "canonical_velocity_smoothstep_one_gait_cycle_v1",
            "ramp_step_count": 360,
            "active_step_count": 359,
            "law": (
                "scale(step)=smoothstep(step/359) for steps 0 through 358; "
                "exact 1.0 from step 359 onward"
            ),
            "gait_phase_memory_advances_unchanged": True,
            "ramp_fields_must_be_absent_from_no_ramp_traces": True,
            "ramp_fields_must_match_the_complete_law_in_ramped_traces": True,
        },
    }
    if contract != expected_contract:
        _fail("ANALYSIS_CONTRACT_IDENTITY")
    expected_phases = _phase_vector(contract)

    provenance = _object(manifest.get("threshold_provenance"), "THRESHOLD")
    command = _number(provenance.get("heading_command_magnitude_rad"), "COMMAND")
    threshold = _number(provenance.get("minimum_cycle_shift_rad"), "THRESHOLD")
    fraction = _number(provenance.get("command_fraction"), "COMMAND_FRACTION")
    if (
        not math.isclose(command, 0.2, abs_tol=1.0e-15)
        or not math.isclose(threshold, 0.01, abs_tol=1.0e-15)
        or not math.isclose(threshold / command, fraction, abs_tol=1.0e-15)
        or provenance.get("calibrated_release_acceptance_margin") is not False
        or provenance.get("calibrated_population_margin") is not False
        or provenance.get("calibrated_cross_engine_equivalence_margin") is not False
        or provenance.get("threshold_change_authorized") is not False
    ):
        _fail("THRESHOLD_PROVENANCE")

    campaign_values = _array(manifest.get("campaigns"), "CAMPAIGNS")
    if len(campaign_values) != 6:
        _fail("CAMPAIGN_COUNT")
    expected_campaign_metadata = {
        "r23d30": (21504, -1, False, "jsonl"),
        "r23d31": (21505, 2, False, "jsonl"),
        "r23d32": (21506, 0, False, "jsonl"),
        "r23d41": (21509, -1, True, "json_array"),
        "r23d42": (21510, -3, True, "jsonl"),
        "r23d43": (21511, -1, True, "jsonl"),
    }
    campaigns: list[dict[str, Any]] = []
    seen_keys: set[str] = set()
    campaign_order: list[str] = []
    total_bytes = 0
    total_rows = 0
    for campaign_value in campaign_values:
        campaign = _object(campaign_value, "CAMPAIGN")
        campaign_key = _string(campaign.get("campaign_key"), "CAMPAIGN_KEY")
        if campaign_key in seen_keys:
            _fail("CAMPAIGN_DUPLICATE", campaign_key)
        seen_keys.add(campaign_key)
        campaign_order.append(campaign_key)
        expected_metadata = expected_campaign_metadata.get(campaign_key)
        observed_metadata = (
            campaign.get("seed"),
            campaign.get("gait_phase_offset_ticks"),
            campaign.get("startup_ramp_applied"),
            campaign.get("trace_encoding"),
        )
        if expected_metadata is None or observed_metadata != expected_metadata:
            _fail("CAMPAIGN_IDENTITY", campaign_key)
        if COMMIT_PATTERN.fullmatch(
            _string(campaign.get("source_physical_commit"), "SOURCE_COMMIT")
        ) is None:
            _fail("SOURCE_COMMIT", campaign_key)
        closure = _object(campaign.get("closure"), "CLOSURE")
        if (
            COMMIT_PATTERN.fullmatch(_string(closure.get("git_commit"), "CLOSURE_COMMIT"))
            is None
            or re.fullmatch(r"[0-9a-f]{40}", _string(closure.get("git_blob_oid"), "CLOSURE_BLOB"))
            is None
        ):
            _fail("CLOSURE_IDENTITY", campaign_key)
        _sha256(closure.get("raw_sha256"), "CLOSURE_SHA256")

        cells_value = _array(campaign.get("cells"), "CAMPAIGN_CELLS")
        if len(cells_value) != 3:
            _fail("CAMPAIGN_CELL_COUNT", campaign_key)
        analyzed_cells: list[dict[str, Any]] = []
        unwrapped_by_arm: dict[str, Sequence[float]] = {}
        for cell_value in cells_value:
            cell = _object(cell_value, "CELL")
            arm_id = _string(cell.get("arm_id"), "ARM_ID")
            if arm_id in unwrapped_by_arm:
                _fail("ARM_DUPLICATE", f"{campaign_key}:{arm_id}")
            digest = _sha256(cell.get("trace_sha256"), "TRACE_SHA256")
            length = _integer(cell.get("trace_byte_length"), "TRACE_LENGTH")
            if length <= 0:
                _fail("TRACE_LENGTH", f"{campaign_key}:{arm_id}")
            payload = _load_cas_payload(evidence_root, digest, length)
            analyzed, unwrapped = _analyze_cell(
                payload,
                campaign=campaign,
                cell=cell,
                contract=contract,
                expected_phases=expected_phases,
            )
            analyzed_cells.append(analyzed)
            unwrapped_by_arm[arm_id] = unwrapped
            total_bytes += length
            total_rows += analyzed["trace_row_count"]
        campaigns.append(
            _campaign_projection(
                campaign,
                analyzed_cells,
                unwrapped_by_arm,
                threshold,
                contract,
            )
        )

    if campaign_order != list(expected_campaign_metadata):
        _fail("CAMPAIGN_ORDER")
    by_key = {campaign["campaign_key"]: campaign for campaign in campaigns}
    group_values = _array(manifest.get("groups"), "GROUPS")
    expected_groups = [
        {
            "group_id": "no_startup_ramp",
            "startup_ramp_applied": False,
            "ordered_campaign_keys": ["r23d30", "r23d31", "r23d32"],
        },
        {
            "group_id": "canonical_startup_ramp",
            "startup_ramp_applied": True,
            "ordered_campaign_keys": ["r23d41", "r23d42", "r23d43"],
        },
    ]
    if group_values != expected_groups:
        _fail("GROUP_IDENTITY")
    groups = [
        _group_projection(_object(value, "GROUP"), by_key) for value in group_values
    ]
    if {group["group_id"] for group in groups} != {
        "no_startup_ramp",
        "canonical_startup_ramp",
    }:
        _fail("GROUP_IDS")
    by_group = {group["group_id"]: group for group in groups}
    no_ramp = by_group["no_startup_ramp"]
    ramped = by_group["canonical_startup_ramp"]

    decision = _object(manifest.get("decision_boundary"), "DECISION_BOUNDARY")
    if (
        decision.get(
            "verifier_only_successor_is_sufficient_only_if_retained_r23d43_turning_passes_after_path_identity_projection"
        )
        is not True
        or decision.get("retained_r23d43_turning_passes_after_path_identity_projection")
        is not False
        or decision.get("verifier_only_successor_sufficient") is not False
        or decision.get(
            "paired_outcome_exposed_startup_transform_development_is_the_next_testable_question"
        )
        is not True
        or decision.get("paired_screen_must_include_both_transform_states_on_the_same_declared_exposed_seeds")
        is not True
        or decision.get("paired_screen_can_satisfy_qsdk_r23") is not False
        or decision.get("paired_screen_can_consume_a_new_held_out_validation_seed")
        is not False
        or decision.get("later_validation_requires_a_frozen_candidate_and_fresh_held_out_native_conditions")
        is not True
    ):
        _fail("DECISION_BOUNDARY")

    claims = _object(manifest.get("claim_limits"), "CLAIMS")
    if not claims or any(value is not False for value in claims.values()):
        _fail("CLAIM_LIMITS")

    r43 = by_key["r23d43"]["cycle_integrated_measurement"]
    direct_observations = {
        "all_three_no_ramp_triplets_pass_raw_signed_cycle_gate": (
            no_ramp["raw_signed_gate_pass_count"] == no_ramp["seed_count"]
        ),
        "all_three_no_ramp_triplets_pass_conditioned_cycle_gate": (
            no_ramp["conditioned_gate_pass_count"] == no_ramp["seed_count"]
        ),
        "all_three_ramped_triplets_pass_raw_signed_cycle_gate": (
            ramped["raw_signed_gate_pass_count"] == ramped["seed_count"]
        ),
        "all_three_ramped_triplets_fail_only_the_positive_conditioned_floor": all(
            not campaign["cycle_integrated_measurement"][
                "positive_conditioned_gate_passed"
            ]
            and campaign["cycle_integrated_measurement"][
                "negative_conditioned_gate_passed"
            ]
            for campaign in campaigns
            if campaign["startup_ramp_applied"]
        ),
        "ramped_positive_conditioned_range_below_development_floor": (
            ramped["positive_reference_conditioned_cycle_shift_rad"]["maximum"]
            < threshold
        ),
        "ramped_negative_conditioned_range_above_development_floor": (
            ramped["negative_reference_conditioned_cycle_shift_rad"]["minimum"]
            >= threshold
        ),
        "r23d43_verifier_projection_would_remain_turning_negative": not (
            r43["reference_conditioned_cycle_shift_gate_passed"]
        ),
        "phase_minus_one_exists_in_both_transform_groups": (
            -1 in no_ramp["gait_phase_offset_ticks"]
            and -1 in ramped["gait_phase_offset_ticks"]
        ),
        "startup_transform_and_seed_remain_confounded": True,
        "causal_effect_or_population_inference_permitted": False,
    }
    if not all(
        direct_observations[key]
        for key in (
            "all_three_no_ramp_triplets_pass_raw_signed_cycle_gate",
            "all_three_no_ramp_triplets_pass_conditioned_cycle_gate",
            "all_three_ramped_triplets_pass_raw_signed_cycle_gate",
            "all_three_ramped_triplets_fail_only_the_positive_conditioned_floor",
            "ramped_positive_conditioned_range_below_development_floor",
            "ramped_negative_conditioned_range_above_development_floor",
            "r23d43_verifier_projection_would_remain_turning_negative",
            "phase_minus_one_exists_in_both_transform_groups",
            "startup_transform_and_seed_remain_confounded",
        )
    ) or direct_observations["causal_effect_or_population_inference_permitted"]:
        _fail("OBSERVED_PATTERN")

    contrast = {
        "ramped_minus_no_ramp_mean_reference_raw_cycle_shift_rad": (
            ramped["reference_raw_cycle_shift_rad"]["mean"]
            - no_ramp["reference_raw_cycle_shift_rad"]["mean"]
        ),
        "ramped_minus_no_ramp_mean_positive_raw_cycle_shift_rad": (
            ramped["positive_raw_cycle_shift_rad"]["mean"]
            - no_ramp["positive_raw_cycle_shift_rad"]["mean"]
        ),
        "ramped_minus_no_ramp_mean_negative_raw_cycle_shift_rad": (
            ramped["negative_raw_cycle_shift_rad"]["mean"]
            - no_ramp["negative_raw_cycle_shift_rad"]["mean"]
        ),
        "ramped_minus_no_ramp_mean_positive_conditioned_cycle_shift_rad": (
            ramped["positive_reference_conditioned_cycle_shift_rad"]["mean"]
            - no_ramp["positive_reference_conditioned_cycle_shift_rad"]["mean"]
        ),
        "ramped_minus_no_ramp_mean_negative_conditioned_cycle_shift_rad": (
            ramped["negative_reference_conditioned_cycle_shift_rad"]["mean"]
            - no_ramp["negative_reference_conditioned_cycle_shift_rad"]["mean"]
        ),
        "causal_interpretation_authorized": False,
    }

    return {
        "schema_version": REPORT_SCHEMA,
        "analysis_id": _string(manifest.get("analysis_id"), "ANALYSIS_ID"),
        "question_class": "postclosure_development_diagnosis",
        "analyzer_source_commit": analyzer_source_commit,
        "manifest": {
            "path": manifest_path.name,
            "sha256": _sha256_bytes(manifest_bytes),
            "byte_length": len(manifest_bytes),
        },
        "input_summary": {
            "campaign_count": len(campaigns),
            "group_count": len(groups),
            "cell_count": sum(len(campaign["cells"]) for campaign in campaigns),
            "trace_count": sum(len(campaign["cells"]) for campaign in campaigns),
            "total_trace_byte_length": total_bytes,
            "total_trace_row_count": total_rows,
            "content_addressed_input_count": sum(
                len(campaign["cells"]) for campaign in campaigns
            ),
            "live_attempt_path_input_count": 0,
        },
        "threshold_provenance": provenance,
        "campaigns": campaigns,
        "groups": groups,
        "descriptive_group_contrast": contrast,
        "direct_observations": direct_observations,
        "decision_boundary": decision,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        **claims,
    }


def _canonical_json(value: dict[str, Any], *, pretty: bool) -> str:
    return json.dumps(
        value,
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
            _canonical_json(report, pretty=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    print("R23D43_STARTUP_TRANSFORM_ANALYSIS_PASS " + _canonical_json(report, pretty=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
