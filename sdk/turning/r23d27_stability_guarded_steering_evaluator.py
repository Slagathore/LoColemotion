"""Zero-world trace retention and finite evaluation for QSDK-R23D27.

This module never constructs a physics model.  The Rust worker supplies the
complete fixed-horizon observations; this process validates and retains those
bytes before the worker emits its terminal report, then evaluates all three
prospectively declared cells without outcome-dependent early stopping.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
VARIANT = os.environ.get("SPORESPORE_QSDK_R23_PREDICTIVE_VARIANT", "r23d27")
R23D31 = VARIANT == "r23d31"
CYCLE_COHERENT = VARIANT in {"r23d30", "r23d31"}
PERSISTENT = VARIANT in {"r23d29", "r23d30", "r23d31"}
PREDICTIVE = VARIANT in {"r23d28", "r23d29", "r23d30", "r23d31"}
if VARIANT not in {"r23d27", "r23d28", "r23d29", "r23d30", "r23d31"}:
    raise RuntimeError("R23D27_VARIANT_INVALID")

DECLARATION_PATH = ROOT / (
    "r23d31_cycle_integrated_directional_response_preregistration_v1.json"
    if R23D31
    else "r23d30_cycle_coherent_directional_response_preregistration_v1.json"
    if CYCLE_COHERENT
    else "r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1.json"
    if PERSISTENT
    else "r23d28_predictive_stability_guarded_steering_preregistration_v1.json"
    if PREDICTIVE
    else "r23d27_stability_guarded_steering_preregistration_v1.json"
)
TRACE_PUBLISHER_PATH = SDK_ROOT / (
    "publish_qsdk_r23d31_trace.ps1"
    if R23D31
    else "publish_qsdk_r23d30_trace.ps1"
    if CYCLE_COHERENT
    else "publish_qsdk_r23d29_trace.ps1"
    if PERSISTENT
    else "publish_qsdk_r23d28_trace.ps1"
    if PREDICTIVE
    else "publish_qsdk_r23d27_trace.ps1"
)

CAMPAIGN_ID = (
    "QSDK-R23D31-RAPIER-CYCLE-INTEGRATED-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION"
    if R23D31
    else "QSDK-R23D30-RAPIER-CYCLE-COHERENT-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION"
    if CYCLE_COHERENT
    else "QSDK-R23D29-RAPIER-TWO-SWING-PERSISTENT-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT"
    if PERSISTENT
    else "QSDK-R23D28-RAPIER-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT"
    if PREDICTIVE
    else "QSDK-R23D27-RAPIER-STABILITY-GUARDED-STEERING-VALIDATION"
)
GATE_ID = (
    "QSDK-R23D31"
    if R23D31
    else "QSDK-R23D30"
    if CYCLE_COHERENT
    else "QSDK-R23D29"
    if PERSISTENT
    else "QSDK-R23D28"
    if PREDICTIVE
    else "QSDK-R23D27"
)
STAGE_ID = (
    "rapier_cycle_integrated_directional_response_measurement_validation"
    if R23D31
    else "rapier_cycle_coherent_directional_response_measurement_validation"
    if CYCLE_COHERENT
    else "rapier_two_swing_persistent_predictive_stability_guarded_steering_development"
    if PERSISTENT
    else "rapier_predictive_stability_guarded_steering_development"
    if PREDICTIVE
    else "rapier_stability_guarded_steering_validation"
)
ENGINE_ID = "rapier_parry"
SCHEMA_STEM = VARIANT
REPORT_SCHEMA = f"sporespore_qsdk_{SCHEMA_STEM}_engine_cell_report_v1"
FAILURE_SCHEMA = f"sporespore_qsdk_{SCHEMA_STEM}_worker_failure_v1"
TRACE_ROW_SCHEMA = f"sporespore_qsdk_{SCHEMA_STEM}_physical_trace_row_v1"
TRACE_RETENTION_SCHEMA = f"sporespore_qsdk_{SCHEMA_STEM}_trace_retention_v1"
COMPLETE_EVALUATION_SCHEMA = f"sporespore_qsdk_{SCHEMA_STEM}_complete_evaluation_v1"
TRACE_SUMMARY_SCHEMA = f"sporespore_qsdk_{SCHEMA_STEM}_trace_summary_v1"
DECLARATION_SCHEMA = (
    "sporespore_qsdk_r23d31_cycle_integrated_directional_response_preregistration_v1"
    if R23D31
    else "sporespore_qsdk_r23d30_cycle_coherent_directional_response_preregistration_v1"
    if CYCLE_COHERENT
    else "sporespore_qsdk_r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1"
    if PERSISTENT
    else "sporespore_qsdk_r23d28_predictive_stability_guarded_steering_preregistration_v1"
    if PREDICTIVE
    else "sporespore_qsdk_r23d27_stability_guarded_steering_preregistration_v1"
)
TRACE_ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
TOLERANCE = 1.0e-12
CAMPAIGN_SEED = 21_505 if R23D31 else 21_504 if CYCLE_COHERENT else 21_501

CANDIDATES = {
    (
        "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28"
        if PERSISTENT
        else "predictive_stability_guarded_0p20_to_0p28"
        if PREDICTIVE
        else "stability_guarded_0p20_to_0p28"
    ): {
        "policy_id": (
            "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1"
            if PERSISTENT
            else "sporespore_balanced_wave_r23d28_predictive_stability_guarded_steering_v1"
            if PREDICTIVE
            else "sporespore_balanced_wave_r23d27_stability_guarded_steering_v1"
        ),
        "cap": 0.28,
    },
}
BEHAVIORAL_CHANGE_SET = (
    []
    if CYCLE_COHERENT
    else [
        "steering_authority_guard_mode_id:predicted_tilt_and_contact_v1_to_persistent_predicted_tilt_and_contact_v1",
        "versioned_controller_memory:144_step_two_swing_floor_hold_countdown",
        "floor_reach_transition:every_instantaneous_floor_row_refreshes_hold_before_current_step_decrement",
        "guard_receipt:v2_to_v3_with_instantaneous_authority_and_complete_hold_transition_fields",
    ]
    if PERSISTENT
    else
    [
        "steering_authority_guard_mode_id:tilt_and_contact_v1_to_predicted_tilt_and_contact_v1",
        "torso_tilt_rate_source:canonical_state_frame_base_twist_world_angular_velocity",
        "prediction_horizon:one_72_step_scheduler_swing_at_120_hz_equals_0.6_s",
        "authority_evaluation_tilt:actual_to_actual_plus_max_zero_signed_tilt_rate_times_horizon",
    ]
    if PREDICTIVE
    else [
        "maximum_steering_fraction:0.20_to_0.28",
        "minimum_steering_fraction:0.20",
        "steering_authority_guard_mode_id:tilt_and_contact_steering_authority_guard_v1",
        "full_authority_maximum_tilt_rad:0.10",
        "minimum_authority_tilt_rad:0.20",
        "minimum_support_contact_count:2",
    ]
)
GUARD_SCHEMA = (
    "sporespore_steering_authority_guard_receipt_v3"
    if PERSISTENT
    else "sporespore_steering_authority_guard_receipt_v2"
    if PREDICTIVE
    else "sporespore_steering_authority_guard_receipt_v1"
)
GUARD_MODE_ID = (
    "persistent_predicted_tilt_and_contact_steering_authority_guard_v1"
    if PERSISTENT
    else "predicted_tilt_and_contact_steering_authority_guard_v1"
    if PREDICTIVE
    else "tilt_and_contact_steering_authority_guard_v1"
)
MARKER_STEM = f"QSDK_{VARIANT.upper()}"
ARMS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}


class R23D27EvaluationError(RuntimeError):
    """The frozen declaration, trace, terminal entry, or matrix is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def valid_source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def expected_cells() -> list[str]:
    return [
        f"{ENGINE_ID}__{candidate_id}__{arm_id}"
        for candidate_id in CANDIDATES
        for arm_id in ARMS
    ]


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D27EvaluationError(
            f"R23D27_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    family = value.get("candidate_family", {})
    candidates = family.get("ordered_candidates", [])
    invalid = (
        value.get("schema_version") != DECLARATION_SCHEMA
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != CAMPAIGN_ID
        or value.get("gate_id") != GATE_ID
        or family.get("behavioral_controller_change_set") != BEHAVIORAL_CHANGE_SET
        or family.get("engine_specific_gait_logic_permitted") is not False
        or family.get("candidate_or_outcome_branching_permitted") is not False
        or [row.get("candidate_id") for row in candidates] != list(CANDIDATES)
        or [row.get("controller_policy_id") for row in candidates]
        != [item["policy_id"] for item in CANDIDATES.values()]
        or [row.get("maximum_steering_fraction") for row in candidates]
        != [item["cap"] for item in CANDIDATES.values()]
        or (
            PERSISTENT
            and (
                len(candidates) != 1
                or candidates[0].get("floor_hold_duration_steps") != 144
                or candidates[0].get("floor_hold_scheduler_swing_count") != 2
                or candidates[0].get("floor_hold_refresh_trigger")
                != "instantaneous_effective_authority_reaches_baseline"
                or candidates[0].get("controller_memory_schema")
                != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
                or candidates[0].get("guard_receipt_schema")
                != "sporespore_steering_authority_guard_receipt_v3"
            )
        )
        or matrix.get("stage_id") != STAGE_ID
        or matrix.get("ordered_candidate_ids") != list(CANDIDATES)
        or matrix.get("ordered_arm_ids") != list(ARMS)
        or matrix.get("declared_cell_count") != 3
        or matrix.get("controller_step_count") != CONTROLLER_STEPS
        or matrix.get("turn_start_step") != TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != TURN_END_STEP_EXCLUSIVE
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or (
            CYCLE_COHERENT
            and (
                matrix.get("seed") != CAMPAIGN_SEED
                or value.get("cycle_coherent_measurement", {}).get(
                    "baseline_start_step_inclusive"
                )
                != 240
                or value.get("cycle_coherent_measurement", {}).get(
                    "baseline_end_step_exclusive"
                )
                != 600
                or value.get("cycle_coherent_measurement", {}).get(
                    "terminal_start_step_inclusive"
                )
                != 1_440
                or value.get("cycle_coherent_measurement", {}).get(
                    "terminal_end_step_exclusive"
                )
                != 1_800
                or value.get("cycle_coherent_measurement", {}).get(
                    "scheduler_swing_steps"
                )
                != 72
                or value.get("cycle_coherent_measurement", {}).get(
                    "scheduler_cycle_steps"
                )
                != 360
            )
        )
        or value.get("selector", {}).get("selected_candidate_is_validation")
        is not (not PREDICTIVE)
        or value.get("claims", {}).get("turning_validation") is not False
        or value.get("claims", {}).get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D27EvaluationError("R23D27_DECLARATION_IDENTITY_INVALID")
    return value


def identity(cell_id: str) -> tuple[str, str, float]:
    parts = cell_id.split("__")
    if len(parts) != 3 or parts[0] != ENGINE_ID:
        raise R23D27EvaluationError("R23D27_CELL_ID_INVALID")
    candidate_id, arm_id = parts[1], parts[2]
    if candidate_id not in CANDIDATES or arm_id not in ARMS:
        raise R23D27EvaluationError("R23D27_CELL_ID_UNKNOWN")
    return candidate_id, arm_id, CANDIDATES[candidate_id]["cap"]


def canonical_ndjson(rows: Sequence[dict[str, Any]]) -> bytes:
    return b"".join(
        (
            json.dumps(
                row,
                ensure_ascii=False,
                allow_nan=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")
        for row in rows
    )


def finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    candidate_id, arm_id, cap = identity(cell_id)
    failures: list[str] = []
    if not isinstance(rows, list) or len(rows) != CONTROLLER_STEPS:
        raise R23D27EvaluationError("R23D27_TRACE_ROW_COUNT_INVALID")
    maximum_tilt = 0.0
    minimum_height = math.inf
    torso_contacts = 0
    saturation_steps = 0
    turn_start_yaw: float | None = None
    turn_end_yaw: float | None = None
    previous_contacts: dict[str, bool] | None = None
    cycles = {limb: 0 for limb in ("front_left", "front_right", "rear_left", "rear_right")}
    expected_floor_remaining = 0
    floor_trigger_steps = 0
    floor_active_steps = 0
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"ROW_NOT_OBJECT:{index}")
            continue
        requested = row.get("requested_steering_fraction")
        held = row.get("held_steering_fraction")
        yaw = row.get("measured_yaw_rad")
        tilt = row.get("torso_tilt_rad")
        height = row.get("torso_height_m")
        contacts = row.get("ordered_foot_contacts")
        guard = row.get("steering_authority_guard")
        commands = row.get("ordered_final_canonical_velocities_rad_s")
        limits = row.get("ordered_actuator_velocity_limits_rad_s")
        predictive_guard_valid = True
        if PREDICTIVE and isinstance(guard, dict):
            actual_tilt = guard.get("torso_tilt_rad")
            tilt_rate = guard.get("torso_tilt_rate_rad_s")
            worsening_rate = guard.get("worsening_torso_tilt_rate_rad_s")
            predicted_tilt = guard.get("predicted_torso_tilt_rad")
            predictive_guard_valid = (
                all(
                    finite_number(value)
                    for value in (actual_tilt, tilt_rate, worsening_rate, predicted_tilt)
                )
                and abs(float(worsening_rate) - max(0.0, float(tilt_rate))) <= TOLERANCE
                and abs(
                    float(predicted_tilt)
                    - min(math.pi, float(actual_tilt) + 0.6 * float(worsening_rate))
                )
                <= TOLERANCE
                and guard.get("prediction_horizon_s") == 0.6
                and guard.get("prediction_horizon_scheduler_swing_steps") == 72
                and guard.get("tilt_rate_source_id")
                == "state_frame_base_twist_world_angular_velocity_v1"
                and guard.get("prediction_horizon_basis_id")
                == "one_balanced_wave_scheduler_swing_v1"
            )
        elif not PREDICTIVE and isinstance(guard, dict):
            predictive_guard_valid = all(
                guard.get(field) is None
                for field in (
                    "torso_tilt_rate_rad_s",
                    "worsening_torso_tilt_rate_rad_s",
                    "prediction_horizon_s",
                    "prediction_horizon_scheduler_swing_steps",
                    "predicted_torso_tilt_rad",
                    "tilt_rate_source_id",
                    "prediction_horizon_basis_id",
                )
            )
        persistent_guard_valid = True
        if PERSISTENT and isinstance(guard, dict):
            predicted_tilt = guard.get("predicted_torso_tilt_rad")
            support_count = guard.get("support_contact_count")
            contact_permitted = guard.get("contact_authority_permitted")
            instantaneous_fraction = guard.get("instantaneous_tilt_authority_fraction")
            instantaneous_effective = guard.get(
                "instantaneous_effective_maximum_steering_fraction"
            )
            if (
                finite_number(predicted_tilt)
                and isinstance(support_count, int)
                and not isinstance(support_count, bool)
                and isinstance(contact_permitted, bool)
                and finite_number(instantaneous_fraction)
                and finite_number(instantaneous_effective)
            ):
                expected_contact_permitted = support_count >= 2
                expected_instantaneous_fraction = (
                    0.0
                    if not expected_contact_permitted or float(predicted_tilt) >= 0.20
                    else 1.0
                    if float(predicted_tilt) <= 0.10
                    else (0.20 - float(predicted_tilt)) / 0.10
                )
                expected_instantaneous_effective = (
                    0.20 + 0.08 * expected_instantaneous_fraction
                )
                expected_triggered = expected_instantaneous_effective <= 0.20 + TOLERANCE
                refreshed_remaining = 144 if expected_triggered else expected_floor_remaining
                expected_active = refreshed_remaining > 0
                expected_remaining_after = (
                    refreshed_remaining - 1 if expected_active else 0
                )
                expected_final_fraction = (
                    0.0 if expected_active else expected_instantaneous_fraction
                )
                expected_final_effective = (
                    0.20 if expected_active else expected_instantaneous_effective
                )
                persistent_guard_valid = (
                    contact_permitted is expected_contact_permitted
                    and abs(
                        float(instantaneous_fraction)
                        - expected_instantaneous_fraction
                    )
                    <= TOLERANCE
                    and abs(
                        float(instantaneous_effective)
                        - expected_instantaneous_effective
                    )
                    <= TOLERANCE
                    and guard.get("floor_hold_duration_steps") == 144
                    and guard.get("floor_hold_scheduler_swing_count") == 2
                    and guard.get("floor_hold_steps_remaining_before_step")
                    == expected_floor_remaining
                    and guard.get("floor_hold_steps_remaining_after_step")
                    == expected_remaining_after
                    and guard.get("floor_hold_triggered_this_step")
                    is expected_triggered
                    and guard.get("floor_hold_active_this_step") is expected_active
                    and guard.get("floor_hold_basis_id")
                    == "two_balanced_wave_scheduler_swings_v1"
                    and finite_number(guard.get("tilt_authority_fraction"))
                    and abs(
                        float(guard.get("tilt_authority_fraction"))
                        - expected_final_fraction
                    )
                    <= TOLERANCE
                    and abs(
                        float(guard.get("effective_maximum_steering_fraction"))
                        - expected_final_effective
                    )
                    <= TOLERANCE
                )
                if expected_triggered:
                    floor_trigger_steps += 1
                if expected_active:
                    floor_active_steps += 1
                expected_floor_remaining = expected_remaining_after
            else:
                persistent_guard_valid = False
        elif isinstance(guard, dict):
            persistent_guard_valid = all(
                guard.get(field) is None
                for field in (
                    "instantaneous_tilt_authority_fraction",
                    "instantaneous_effective_maximum_steering_fraction",
                    "floor_hold_duration_steps",
                    "floor_hold_scheduler_swing_count",
                    "floor_hold_steps_remaining_before_step",
                    "floor_hold_steps_remaining_after_step",
                    "floor_hold_triggered_this_step",
                    "floor_hold_active_this_step",
                    "floor_hold_basis_id",
                )
            )
        if (
            row.get("schema_version") != TRACE_ROW_SCHEMA
            or row.get("cell_id") != cell_id
            or (CYCLE_COHERENT and row.get("campaign_seed") != CAMPAIGN_SEED)
            or row.get("trace_step") != index
            or row.get("controller_semantic_step") != index
            or not all(finite_number(value) for value in (requested, held, yaw, tilt, height))
            or abs(float(requested)) > cap + TOLERANCE
            or abs(float(held)) > cap + TOLERANCE
            or not isinstance(row.get("steering_saturated"), bool)
            or not isinstance(row.get("torso_ground_contact"), bool)
            or not isinstance(contacts, dict)
            or set(contacts) != set(cycles)
            or any(not isinstance(value, bool) for value in contacts.values())
            or not isinstance(guard, dict)
            or guard.get("schema_version") != GUARD_SCHEMA
            or guard.get("mode_id") != GUARD_MODE_ID
            or not predictive_guard_valid
            or not persistent_guard_valid
            or guard.get("direction_neutral") is not True
            or guard.get("engine_identity_input_count") != 0
            or guard.get("minimum_support_contact_count") != 2
            or not finite_number(guard.get("effective_maximum_steering_fraction"))
            or not 0.20 - TOLERANCE
            <= float(guard.get("effective_maximum_steering_fraction", math.nan))
            <= 0.28 + TOLERANCE
            or abs(float(requested))
            > float(guard.get("effective_maximum_steering_fraction", -math.inf)) + TOLERANCE
            or abs(float(held))
            > float(guard.get("effective_maximum_steering_fraction", -math.inf)) + TOLERANCE
            or not isinstance(commands, list)
            or len(commands) != 8
            or not all(finite_number(value) for value in commands)
            or not isinstance(limits, list)
            or len(limits) != 8
            or not all(finite_number(value) and value > 0.0 for value in limits)
            or any(abs(float(command)) > float(limit) + TOLERANCE for command, limit in zip(commands, limits, strict=True))
        ):
            failures.append(f"ROW_INVALID:{index}")
            continue
        maximum_tilt = max(maximum_tilt, float(tilt))
        minimum_height = min(minimum_height, float(height))
        torso_contacts += int(row["torso_ground_contact"])
        saturation_steps += int(row["steering_saturated"])
        if index == TURN_START_STEP:
            turn_start_yaw = float(yaw)
        if index + 1 == TURN_END_STEP_EXCLUSIVE:
            turn_end_yaw = float(yaw)
        if index >= 472 and previous_contacts is not None:
            for limb in cycles:
                if not previous_contacts[limb] and contacts[limb]:
                    cycles[limb] += 1
        previous_contacts = contacts
    if failures:
        raise R23D27EvaluationError(
            "R23D27_TRACE_INVALID:" + ",".join(failures[:8])
        )
    canonical = canonical_ndjson(rows)
    return {
        "schema_version": TRACE_SUMMARY_SCHEMA,
        "cell_id": cell_id,
        "candidate_id": candidate_id,
        "arm_id": arm_id,
        "campaign_seed": CAMPAIGN_SEED,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hashlib.sha256(canonical).hexdigest(),
        "byte_length": len(canonical),
        "maximum_tilt_rad": maximum_tilt,
        "minimum_torso_height_m": minimum_height,
        "torso_ground_contact_step_count": torso_contacts,
        "steering_saturation_step_count": saturation_steps,
        "floor_hold_trigger_step_count": floor_trigger_steps if PERSISTENT else None,
        "floor_hold_active_step_count": floor_active_steps if PERSISTENT else None,
        "floor_hold_steps_remaining_after_trace": (
            expected_floor_remaining if PERSISTENT else None
        ),
        "contact_cycle_count_by_limb": cycles,
        "turn_phase_yaw_delta_rad": (
            None
            if turn_start_yaw is None or turn_end_yaw is None
            else math.remainder(turn_end_yaw - turn_start_yaw, 2.0 * math.pi)
        ),
        "ok": True,
        "failure_codes": [],
        "physical_acceptance_authority": False,
    }


def path_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def retain_trace(
    *,
    stage_id: str,
    cell_id: str,
    rows_json_path: Path,
    source_root: Path,
    repo_root: Path,
    attempt_root: Path,
    powershell: str,
    test_only: bool,
    evidence_root_override: Path | None,
) -> dict[str, Any]:
    load_declaration()
    if stage_id != STAGE_ID:
        raise R23D27EvaluationError("R23D27_STAGE_ID_INVALID")
    identity(cell_id)
    source_root = source_root.resolve()
    repo_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    try:
        same_source = os.path.samefile(source_root, REPO_ROOT)
    except OSError:
        same_source = False
    if not same_source or not attempt_root.is_dir():
        raise R23D27EvaluationError("R23D27_RETENTION_ROOT_INVALID")
    if test_only:
        if evidence_root_override is None:
            raise R23D27EvaluationError("R23D27_TEST_EVIDENCE_ROOT_REQUIRED")
    elif evidence_root_override is not None or not path_within(
        attempt_root, repo_root.parent / "SporeSpore_Evidence"
    ):
        raise R23D27EvaluationError("R23D27_PRODUCTION_RETENTION_ROOT_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D27EvaluationError(
            f"R23D27_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    canonical = canonical_ndjson(rows)
    if (
        summary["raw_sha256"] != "sha256:" + hashlib.sha256(canonical).hexdigest()
        or summary["byte_length"] != len(canonical)
    ):
        raise R23D27EvaluationError("R23D27_TRACE_CANONICAL_RECEIPT_MISMATCH")
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    canonical_path = trace_root / f"{stage_id}__{cell_id}.ndjson"
    try:
        with canonical_path.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D27EvaluationError("R23D27_TRACE_STAGING_PATH_EXISTS") from error
    command = [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(TRACE_PUBLISHER_PATH),
        "-RepoRoot",
        str(repo_root),
        "-ArtifactPath",
        str(canonical_path),
        "-ExpectedSha256",
        summary["raw_sha256"],
        "-ExpectedByteLength",
        str(summary["byte_length"]),
    ]
    if test_only:
        command.extend(
            ["-TestOnly", "-EvidenceRootOverride", str(evidence_root_override.resolve())]
        )
    process = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        check=False,
        text=True,
        timeout=120,
    )
    marker = MARKER_STEM + "_TRACE_CAS "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D27EvaluationError(
            f"R23D27_TRACE_CAS_PUBLICATION_FAILED:{process.returncode}:{process.stderr[-500:]}"
        )
    artifact = json.loads(matches[0])
    if (
        artifact.get("schema_version") != TRACE_ARTIFACT_SCHEMA
        or artifact.get("sha256") != summary["raw_sha256"]
        or artifact.get("byte_length") != summary["byte_length"]
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D27EvaluationError("R23D27_TRACE_CAS_RECEIPT_INVALID")
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "stage_id": stage_id,
        "cell_id": cell_id,
        "trace_artifact": artifact,
        "trace_summary": summary,
        "retained_before_terminal_entry": True,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def evaluate_entry(
    entry: Any,
    *,
    expected_cell_id: str,
    expected_source_commit: str,
    allow_test_artifacts: bool,
) -> dict[str, Any]:
    candidate_id, arm_id, cap = identity(expected_cell_id)
    if not isinstance(entry, dict):
        raise R23D27EvaluationError("R23D27_TERMINAL_ENTRY_INVALID")
    if entry.get("schema_version") == FAILURE_SCHEMA:
        if (
            entry.get("campaign_id") != CAMPAIGN_ID
            or entry.get("gate_id") != GATE_ID
            or entry.get("source_commit") != expected_source_commit
        ):
            raise R23D27EvaluationError("R23D27_FAILURE_IDENTITY_INVALID")
        return {
            "cell_id": expected_cell_id,
            "candidate_id": candidate_id,
            "arm_id": arm_id,
            "execution_valid": False,
            "gate_passed": False,
            "failure_codes": [entry.get("failure_code", "WORKER_FAILURE")],
        }
    execution = entry.get("execution", {})
    measurements = entry.get("measurements", {})
    artifact = entry.get("trace_artifact", {})
    summary = entry.get("trace_summary", {})
    identity_valid = (
        entry.get("schema_version") == REPORT_SCHEMA
        and entry.get("campaign_id") == CAMPAIGN_ID
        and entry.get("gate_id") == GATE_ID
        and entry.get("stage_id") == STAGE_ID
        and entry.get("cell_id") == expected_cell_id
        and entry.get("engine_id") == ENGINE_ID
        and entry.get("candidate_id") == candidate_id
        and entry.get("controller_policy_id") == CANDIDATES[candidate_id]["policy_id"]
        and entry.get("maximum_steering_fraction") == cap
        and entry.get("arm_id") == arm_id
        and (not CYCLE_COHERENT or entry.get("campaign_seed") == CAMPAIGN_SEED)
        and entry.get("source_commit") == expected_source_commit
        and entry.get("claims", {}).get("physical_acceptance_authority") is False
    )
    artifact_valid = (
        isinstance(artifact, dict)
        and artifact.get("schema_version") == TRACE_ARTIFACT_SCHEMA
        and isinstance(artifact.get("payload_path"), str)
        and Path(artifact.get("payload_path", "")).is_file()
        and raw_sha256(Path(artifact["payload_path"])) == artifact.get("sha256")
        and Path(artifact["payload_path"]).stat().st_size == artifact.get("byte_length")
        and (allow_test_artifacts or artifact.get("test_only") is False)
        and summary.get("raw_sha256") == artifact.get("sha256")
        and summary.get("byte_length") == artifact.get("byte_length")
        and summary.get("row_count") == CONTROLLER_STEPS
    )
    common_gates = {
        "identity": identity_valid,
        "trace_artifact": artifact_valid,
        "execution_integrity": (
            execution.get("integrity_passed") is True
            and execution.get("world_attempt_count") == 1
            and execution.get("world_build_count") == 1
            and execution.get("controller_semantic_step_count") == CONTROLLER_STEPS
            and execution.get("terminal_quiescent_taper_step_count") == 0
        ),
        "forward_displacement": (
            finite_number(measurements.get("final_forward_displacement_m"))
            and measurements["final_forward_displacement_m"] >= 0.030123046875
        ),
        "tilt": (
            finite_number(measurements.get("maximum_tilt_rad"))
            and measurements["maximum_tilt_rad"] <= 0.6
        ),
        "height": (
            finite_number(measurements.get("minimum_torso_height_m"))
            and measurements["minimum_torso_height_m"] >= 0.2499708652072946
        ),
        "contacts": (
            isinstance(measurements.get("contact_cycle_count_by_limb"), dict)
            and set(measurements["contact_cycle_count_by_limb"]) == set(ARMS)  # replaced below
        ),
        "zero_failures": all(
            measurements.get(field) == 0
            for field in (
                "torso_ground_contact_step_count",
                "controller_error_count",
                "active_safe_no_actuation_count",
                "nonfinite_observation_count",
                "actuator_application_mismatch_count",
            )
        ),
        "steering_cap": (
            finite_number(measurements.get("maximum_absolute_requested_steering_fraction"))
            and finite_number(measurements.get("maximum_absolute_held_steering_fraction"))
            and measurements["maximum_absolute_requested_steering_fraction"] <= cap + TOLERANCE
            and measurements["maximum_absolute_held_steering_fraction"] <= cap + TOLERANCE
        ),
    }
    cycles = measurements.get("contact_cycle_count_by_limb", {})
    common_gates["contacts"] = (
        isinstance(cycles, dict)
        and set(cycles) == {"front_left", "front_right", "rear_left", "rear_right"}
        and all(isinstance(value, int) and value >= 2 for value in cycles.values())
    )
    yaw_delta = measurements.get("turn_phase_yaw_delta_rad")
    direction_gate = (
        CYCLE_COHERENT
        or arm_id == "reference_zero"
        or (
            finite_number(yaw_delta)
            and abs(yaw_delta) >= 0.01
            and math.copysign(1.0, yaw_delta) == math.copysign(1.0, ARMS[arm_id])
        )
    )
    common_gates["signed_turn_response"] = direction_gate
    failures = [name for name, passed in common_gates.items() if not passed]
    return {
        "cell_id": expected_cell_id,
        "candidate_id": candidate_id,
        "arm_id": arm_id,
        "execution_valid": identity_valid and artifact_valid and common_gates["execution_integrity"],
        "gate_passed": not failures,
        "failure_codes": failures,
        "turn_phase_yaw_delta_rad": yaw_delta,
        "final_forward_displacement_m": measurements.get("final_forward_displacement_m"),
        "maximum_tilt_rad": measurements.get("maximum_tilt_rad"),
        "minimum_torso_height_m": measurements.get("minimum_torso_height_m"),
    }


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    declaration = load_declaration()
    if not valid_source_commit(expected_source_commit):
        raise R23D27EvaluationError("R23D27_SOURCE_COMMIT_INVALID")
    cells = expected_cells()
    if len(entries) != len(cells):
        raise R23D27EvaluationError("R23D27_COMPLETE_ENTRY_COUNT_INVALID")
    evaluations = [
        evaluate_entry(
            entry,
            expected_cell_id=cell_id,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
        for entry, cell_id in zip(entries, cells, strict=True)
    ]
    eligible: list[str] = []
    candidate_summaries: list[dict[str, Any]] = []
    for candidate_id in CANDIDATES:
        rows = [row for row in evaluations if row["candidate_id"] == candidate_id]
        reference = next(row for row in rows if row["arm_id"] == "reference_zero")
        positive = next(row for row in rows if row["arm_id"] == "positive_heading")
        negative = next(row for row in rows if row["arm_id"] == "negative_heading")
        bilateral_separation = (
            positive.get("turn_phase_yaw_delta_rad") - negative.get("turn_phase_yaw_delta_rad")
            if finite_number(positive.get("turn_phase_yaw_delta_rad"))
            and finite_number(negative.get("turn_phase_yaw_delta_rad"))
            else None
        )
        positive_conditioned = (
            positive.get("turn_phase_yaw_delta_rad")
            - reference.get("turn_phase_yaw_delta_rad")
            if finite_number(positive.get("turn_phase_yaw_delta_rad"))
            and finite_number(reference.get("turn_phase_yaw_delta_rad"))
            else None
        )
        negative_conditioned = (
            reference.get("turn_phase_yaw_delta_rad")
            - negative.get("turn_phase_yaw_delta_rad")
            if finite_number(reference.get("turn_phase_yaw_delta_rad"))
            and finite_number(negative.get("turn_phase_yaw_delta_rad"))
            else None
        )
        passed = (
            all(row["gate_passed"] for row in rows)
            and finite_number(bilateral_separation)
            and finite_number(positive_conditioned)
            and finite_number(negative_conditioned)
            and bilateral_separation >= 0.01
            and positive_conditioned >= 0.01
            and negative_conditioned >= 0.01
        )
        if passed:
            eligible.append(candidate_id)
        candidate_summaries.append(
            {
                "candidate_id": candidate_id,
                "maximum_steering_fraction": CANDIDATES[candidate_id]["cap"],
                "all_three_cells_passed": all(row["gate_passed"] for row in rows),
                "bilateral_yaw_separation_rad": bilateral_separation,
                "positive_reference_conditioned_yaw_delta_rad": positive_conditioned,
                "negative_reference_conditioned_yaw_delta_rad": negative_conditioned,
                "eligible": passed,
            }
        )
    selected = eligible[-1] if eligible else None
    classification = (
        (
            "valid_complete_positive_development_candidate"
            if selected
            else "valid_complete_negative_no_development_candidate"
        )
        if PREDICTIVE
        else ("valid_complete_positive" if selected else "valid_complete_negative")
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "candidate_summaries": candidate_summaries,
        "eligible_candidate_ids": eligible,
        "selected_candidate_id": selected,
        "selected_maximum_steering_fraction": (
            None if selected is None else CANDIDATES[selected]["cap"]
        ),
        "selection_is_validation": not PREDICTIVE,
        "distinct_prospective_validation_required": PREDICTIVE and selected is not None,
        "all_cells_run_regardless_of_intermediate_outcome": (
            declaration["frozen_matrix"]["all_cells_run_regardless_of_intermediate_outcome"]
        ),
        "claims": {
            "development_screen_only": PREDICTIVE,
            "finite_rapier_development_candidate": PREDICTIVE and selected is not None,
            "finite_rapier_turning_validation": (not PREDICTIVE) and selected is not None,
            "turning_validation": (not PREDICTIVE) and selected is not None,
            "portable_basic_turning": False,
            "finite_three_engine_turning": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--source-root", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--source-commit", required=True)
    evaluate.add_argument("--allow-test-artifacts", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "retain-trace":
            receipt = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                source_root=args.source_root,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root_override,
            )
            print(
                MARKER_STEM + "_TRACE_RETENTION "
                + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            )
        else:
            manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
            if not isinstance(manifest, list):
                raise R23D27EvaluationError("R23D27_MANIFEST_INVALID")
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8")) for path in manifest
            ]
            result = evaluate_complete_entries(
                entries,
                expected_source_commit=args.source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
            print(
                MARKER_STEM + "_COMPLETE_EVALUATION "
                + json.dumps(result, sort_keys=True, separators=(",", ":"))
            )
        return 0
    except (R23D27EvaluationError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"{MARKER_STEM}_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
