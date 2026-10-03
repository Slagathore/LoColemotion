"""Trace retention and finite evaluation for QSDK-R23D36."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping, Sequence

import r23d36_mujoco_bw19v_walking_restoration as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d36_mujoco_bw19v_walking_restoration_preregistration_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d34_trace.ps1"
REPORT_SCHEMA = "sporespore_qsdk_r23d36_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d36_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d36_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d36_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d36_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
MAXIMUM_RESIDUAL_RAD_S = 0.075
FALSE_CLAIMS = {
    "mujoco_r23d29_bw19v_walking_restoration": False,
    "mujoco_r23d29_unassisted_walking": False,
    "mujoco_r23d29_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D36EvaluationError(RuntimeError):
    """The declaration, retained trace, report, or matrix is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _count(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _canonical_ndjson(rows: Sequence[dict[str, Any]]) -> bytes:
    return b"".join(_canonical_bytes(row) + b"\n" for row in rows)


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D36EvaluationError(
            f"R23D36_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    candidate = value.get("candidate", {})
    gates = value.get("frozen_common_physical_gates", {})
    lineage = value.get("immutable_lineage", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d36_mujoco_bw19v_walking_restoration_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("study_classification") != "prospective_finite_development_screen"
        or candidate.get("controller_policy_id") != design.POLICY_ID
        or candidate.get("stability_policy_id") != design.STABILITY_POLICY_ID
        or candidate.get("maximum_absolute_velocity_residual_rad_s")
        != MAXIMUM_RESIDUAL_RAD_S
        or candidate.get("engine_specific_gait_logic_permitted") is not False
        or candidate.get("arm_identity_or_outcome_branching_permitted") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != [design.ENGINE_ID]
        or matrix.get("ordered_arm_ids") != [design.ARM_ID]
        or matrix.get("declared_cell_count") != 1
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("command_schedule") != "reference_walk_for_all_2992_steps"
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or matrix.get("serial_execution_required") is not True
        or gates.get("minimum_final_forward_displacement_m") != 0.030123046875
        or gates.get("maximum_tilt_rad") != 0.6
        or gates.get("minimum_torso_height_m") != 0.2499708652072946
        or gates.get("minimum_contact_cycles_per_limb") != 2
        or gates.get("minimum_nonzero_stability_residual_step_count") != 1
        or lineage.get("r23d34_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d34_native_r23d29_transfer_closure_v1.json")
        or lineage.get("mujoco_mv6_closure_raw_sha256")
        != raw_sha256(
            SDK_ROOT
            / "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
        )
        or lineage.get("r23d34_identity_consumed") is not True
        or lineage.get("r23d34_mujoco_failed_before_turn_onset") is not True
        or lineage.get("r23d34_result_reinterpreted") is not False
        or lineage.get("mv6_controller_identity_reused") is not False
    )
    if invalid:
        raise R23D36EvaluationError("R23D36_DECLARATION_IDENTITY_INVALID")
    return value


def expected_cells() -> list[str]:
    return [item.cell_id for item in design.cells()]


def _validate_residuals(row: Mapping[str, Any], step: int) -> list[str]:
    failures: list[str] = []
    residuals = row.get("ordered_stability_velocity_residuals")
    if (
        not isinstance(residuals, list)
        or len(residuals) != design.ACTUATOR_COUNT
        or [item.get("actuator_id") for item in residuals if isinstance(item, dict)]
        != list(design.ACTUATOR_IDS)
    ):
        return [f"R23D36_TRACE_RESIDUAL_ORDER:{step}"]
    values: list[float] = []
    for item in residuals:
        value = item.get("canonical_velocity_delta_rad_s")
        if not _finite(value):
            failures.append(f"R23D36_TRACE_RESIDUAL_NONFINITE:{step}")
        else:
            values.append(float(value))
    maximum = max((abs(value) for value in values), default=0.0)
    nonzero = sum(abs(value) > 1.0e-12 for value in values)
    if maximum > MAXIMUM_RESIDUAL_RAD_S + 1.0e-12:
        failures.append(f"R23D36_TRACE_RESIDUAL_BOUND:{step}")
    if (
        not _finite(row.get("stability_maximum_absolute_velocity_residual_rad_s"))
        or abs(
            float(row.get("stability_maximum_absolute_velocity_residual_rad_s", math.nan))
            - maximum
        )
        > 1.0e-12
        or row.get("stability_nonzero_residual_count") != nonzero
    ):
        failures.append(f"R23D36_TRACE_RESIDUAL_SUMMARY:{step}")
    return failures


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    matches = [item for item in design.cells() if item.cell_id == cell_id]
    if len(matches) != 1 or not isinstance(rows, list):
        raise R23D36EvaluationError("R23D36_TRACE_IDENTITY_INVALID")
    item = matches[0]
    failures: list[str] = []
    if len(rows) != design.CONTROLLER_STEPS:
        failures.append("R23D36_TRACE_ROW_COUNT")
    segment_counts = {name: 0 for name in design.expected_segment_counts(item)}
    available_steps = 0
    active_steps = 0
    nonzero_steps = 0
    maximum_residual = 0.0
    for expected_step, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"R23D36_TRACE_ROW_TYPE:{expected_step}")
            continue
        expected_segment, expected_offset = design.segment_for_step(item, expected_step)
        if (
            row.get("schema_version") != design.TRACE_ROW_SCHEMA
            or row.get("cell_id") != item.cell_id
            or row.get("semantic_step") != expected_step
            or row.get("segment_id") != expected_segment
            or not _finite(row.get("desired_heading_offset_rad"))
            or abs(float(row.get("desired_heading_offset_rad", math.nan)) - expected_offset)
            > 1.0e-12
            or not _finite(row.get("measured_yaw_rad"))
            or not _finite(row.get("torso_height_m"))
            or not _finite(row.get("torso_tilt_rad"))
            or not isinstance(row.get("torso_ground_contact"), bool)
            or not _finite(row.get("requested_steering_fraction"))
            or not _finite(row.get("held_steering_fraction"))
            or row.get("validated_portable_command_count") != design.ACTUATOR_COUNT
            or row.get("native_actuation_application_count") != design.ACTUATOR_COUNT
            or row.get("oracle_passed") is not True
            or row.get("stability_policy_id") != design.STABILITY_POLICY_ID
            or not isinstance(row.get("stability_planning_availability"), str)
            or not row.get("stability_planning_availability")
            or not isinstance(row.get("stability_planning_outcome_code"), str)
            or not row.get("stability_planning_outcome_code")
            or not isinstance(row.get("stability_plan_active"), bool)
            or row.get("stability_composition_integrity_passed") is not True
        ):
            failures.append(f"R23D36_TRACE_ROW_INVALID:{expected_step}")
        for field in ("ordered_foot_contacts_before", "ordered_foot_contacts_after"):
            contacts = row.get(field)
            if (
                not isinstance(contacts, dict)
                or set(contacts) != set(design.LIMB_IDS)
                or any(not isinstance(contacts.get(limb), bool) for limb in design.LIMB_IDS)
            ):
                failures.append(f"R23D36_TRACE_CONTACTS_INVALID:{expected_step}:{field}")
        failures.extend(_validate_residuals(row, expected_step))
        if expected_segment in segment_counts:
            segment_counts[expected_segment] += 1
        available_steps += int(row.get("stability_planning_availability") == "available")
        active_steps += int(row.get("stability_plan_active") is True)
        row_nonzero = row.get("stability_nonzero_residual_count")
        nonzero_steps += int(_count(row_nonzero) and row_nonzero > 0)
        row_maximum = row.get("stability_maximum_absolute_velocity_residual_rad_s")
        if _finite(row_maximum):
            maximum_residual = max(maximum_residual, abs(float(row_maximum)))
    if segment_counts != design.expected_segment_counts(item):
        failures.append("R23D36_TRACE_SEGMENT_COUNTS")
    try:
        canonical = _canonical_ndjson(rows)
    except (TypeError, ValueError) as error:
        raise R23D36EvaluationError(
            f"R23D36_TRACE_CANONICALIZATION_FAILED:{type(error).__name__}"
        ) from error
    return {
        "schema_version": TRACE_SUMMARY_SCHEMA,
        "ok": not failures,
        "failure_codes": failures[:32],
        "cell_id": cell_id,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hashlib.sha256(canonical).hexdigest(),
        "byte_length": len(canonical),
        "segment_counts": segment_counts,
        "stability_composition_step_count": len(rows),
        "stability_planning_available_step_count": available_steps,
        "stability_plan_active_step_count": active_steps,
        "stability_nonzero_residual_step_count": nonzero_steps,
        "maximum_absolute_stability_velocity_residual_rad_s": maximum_residual,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def retain_trace(
    *,
    stage_id: str,
    cell_id: str,
    rows_json_path: Path,
    repo_root: Path,
    attempt_root: Path,
    powershell: str,
    test_only: bool = False,
    evidence_root_override: Path | None = None,
) -> dict[str, Any]:
    load_declaration()
    if stage_id != design.STAGE_ID or repo_root.resolve() != REPO_ROOT.resolve():
        raise R23D36EvaluationError("R23D36_RETENTION_IDENTITY_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D36EvaluationError(
            f"R23D36_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    if not summary["ok"]:
        raise R23D36EvaluationError(
            "R23D36_TRACE_INVALID:" + ",".join(summary["failure_codes"][:8])
        )
    attempt_root = attempt_root.resolve()
    production_root = REPO_ROOT.parent / "SporeSpore_Evidence"
    try:
        attempt_root.relative_to(
            (evidence_root_override if test_only else production_root).resolve()
        )
    except (AttributeError, ValueError) as error:
        raise R23D36EvaluationError("R23D36_ATTEMPT_ROOT_INVALID") from error
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    output = trace_root / f"{cell_id}.ndjson"
    if output.exists():
        raise R23D36EvaluationError("R23D36_TRACE_OUTPUT_EXISTS")
    canonical = _canonical_ndjson(rows)
    output.write_bytes(canonical)
    arguments = [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-File",
        str(PUBLISHER_PATH),
        "-RepoRoot",
        str(REPO_ROOT),
        "-ArtifactPath",
        str(output),
        "-ExpectedSha256",
        summary["raw_sha256"],
        "-ExpectedByteLength",
        str(summary["byte_length"]),
    ]
    if test_only:
        if evidence_root_override is None:
            raise R23D36EvaluationError("R23D36_TEST_EVIDENCE_ROOT_REQUIRED")
        arguments.extend(
            ["-TestOnly", "-EvidenceRootOverride", str(evidence_root_override.resolve())]
        )
    process = subprocess.run(
        arguments,
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
        text=True,
        timeout=180,
    )
    prefix = "QSDK_R23D34_TRACE_CAS "
    markers = [
        line[len(prefix) :]
        for line in process.stdout.splitlines()
        if line.startswith(prefix)
    ]
    if process.returncode != 0 or len(markers) != 1:
        raise R23D36EvaluationError(
            f"R23D36_TRACE_CAS_FAILED:{process.returncode}:{process.stderr[-500:]}"
        )
    artifact = json.loads(markers[0])
    if (
        artifact.get("schema_version") != ARTIFACT_SCHEMA
        or artifact.get("sha256") != summary["raw_sha256"]
        or artifact.get("byte_length") != summary["byte_length"]
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D36EvaluationError("R23D36_TRACE_CAS_RECEIPT_INVALID")
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


def _artifact_rows(
    entry: Mapping[str, Any], item: design.Cell
) -> tuple[list[dict[str, Any]], dict[str, Any] | None, list[str]]:
    failures: list[str] = []
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return [], None, ["R23D36_TRACE_ARTIFACT_RECEIPT"]
    if artifact.get("test_only") is True:
        failures.append("R23D36_TEST_ARTIFACT_FORBIDDEN")
    path = Path(str(artifact.get("payload_path", "")))
    digest_value = str(artifact.get("sha256", ""))
    digest_hex = digest_value.removeprefix("sha256:")
    expected_directory = (
        REPO_ROOT.parent / "SporeSpore_Evidence" / "artifacts" / "sha256" / digest_hex
    ).resolve()
    expected_payload = expected_directory / "payload.bin"
    expected_manifest = expected_directory / "manifest.json"
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or path.resolve() != expected_payload
        or Path(str(artifact.get("manifest_path", ""))).resolve() != expected_manifest
    ):
        return [], None, failures + ["R23D36_TRACE_ARTIFACT_CAS_PATH"]
    try:
        raw = path.read_bytes()
        rows = [json.loads(line) for line in raw.splitlines()]
        manifest = json.loads(expected_manifest.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [], None, failures + [
            f"R23D36_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"
        ]
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    if (
        not raw.endswith(b"\n")
        or digest != artifact.get("sha256")
        or len(raw) != artifact.get("byte_length")
        or _canonical_ndjson(rows) != raw
        or manifest.get("schema_version")
        != "sporespore_content_addressed_artifact_manifest_v1"
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != digest
        or manifest.get("byte_length") != len(raw)
        or manifest.get("payload_name") != "payload.bin"
        or manifest.get("media_type") != "application/x-ndjson"
    ):
        failures.append("R23D36_TRACE_ARTIFACT_BYTES")
    for step, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        residuals = row.get("ordered_stability_velocity_residuals")
        if not isinstance(residuals, list) or len(residuals) != design.ACTUATOR_COUNT:
            continue
        by_id = {
            item.get("actuator_id"): float(item.get("canonical_velocity_delta_rad_s", 0.0))
            for item in residuals
            if isinstance(item, dict) and _finite(item.get("canonical_velocity_delta_rad_s"))
        }
        if set(by_id) != set(design.ACTUATOR_IDS):
            continue
        expected_values = [by_id[actuator_id] for actuator_id in design.ACTUATOR_IDS]
        maximum = max(abs(value) for value in expected_values)
        nonzero = sum(abs(value) > 1.0e-12 for value in expected_values)
        if (
            row.get("stability_nonzero_residual_count") != nonzero
            or not _finite(row.get("stability_maximum_absolute_velocity_residual_rad_s"))
            or abs(
                float(row["stability_maximum_absolute_velocity_residual_rad_s"])
                - maximum
            )
            > 1.0e-12
        ):
            failures.append(f"R23D36_TRACE_INDEPENDENT_RESIDUAL_REPLAY:{step}")
            break
    summary = validate_trace(item.cell_id, rows)
    if not summary["ok"]:
        failures.extend(summary["failure_codes"])
    recorded = entry.get("trace_summary")
    comparison_fields = (
        "raw_sha256",
        "byte_length",
        "row_count",
        "segment_counts",
        "stability_composition_step_count",
        "stability_planning_available_step_count",
        "stability_plan_active_step_count",
        "stability_nonzero_residual_step_count",
        "maximum_absolute_stability_velocity_residual_rad_s",
    )
    if not isinstance(recorded, dict) or any(
        recorded.get(field) != summary.get(field) for field in comparison_fields
    ):
        failures.append("R23D36_TRACE_SUMMARY_MISMATCH")
    return rows, summary, failures


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
) -> dict[str, Any]:
    result = {
        "cell_id": item.cell_id,
        "engine_id": item.engine_id,
        "arm_id": item.arm_id,
        "entry_kind": "invalid",
        "execution_valid": False,
        "walking_gate_passed": False,
        "failed_gate_ids": [],
        "world_attempt_count": 0,
        "world_build_count": 0,
    }
    if not isinstance(entry, dict):
        result["failed_gate_ids"] = ["R23D36_ENTRY_TYPE"]
        return result
    identity_valid = (
        entry.get("campaign_id") == design.CAMPAIGN_ID
        and entry.get("gate_id") == design.GATE_ID
        and entry.get("stage_id") == item.stage_id
        and entry.get("cell_id") == item.cell_id
        and entry.get("engine_id") == item.engine_id
        and entry.get("arm_id") == item.arm_id
        and entry.get("source_commit") == expected_source_commit
    )
    if entry.get("schema_version") == FAILURE_SCHEMA:
        result.update(
            entry_kind="worker_failure",
            world_attempt_count=int(entry.get("world_attempt_count", 0)),
            world_build_count=int(entry.get("world_build_count", 0)),
            failed_gate_ids=[
                "R23D36_FAILURE_IDENTITY"
                if not identity_valid
                else str(entry.get("failure_code", "R23D36_WORKER_FAILURE"))
            ],
        )
        return result
    if entry.get("schema_version") != REPORT_SCHEMA or not identity_valid:
        result["failed_gate_ids"] = ["R23D36_REPORT_IDENTITY"]
        return result
    _rows, trace_summary, failures = _artifact_rows(entry, item)
    execution = entry.get("execution")
    measurements = entry.get("measurements")
    if not isinstance(execution, dict) or not isinstance(measurements, dict):
        failures.append("R23D36_REPORT_SHAPE")
    else:
        expected_commands = design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        if (
            execution.get("integrity_passed") is not True
            or execution.get("controller_semantic_step_count") != design.CONTROLLER_STEPS
            or execution.get("validated_portable_command_count") != expected_commands
            or execution.get("native_actuation_application_count") != expected_commands
            or execution.get("portable_impulse_violation_count") != 0
            or execution.get("world_attempt_count") != 1
            or execution.get("world_build_count") != 1
            or execution.get("trace_retained_before_terminal_entry") is not True
            or execution.get("fixed_horizon_configuration_proved_before_fixture_insertion")
            is not True
            or execution.get("stability_composition_integrity_passed") is not True
        ):
            failures.append("R23D36_EXECUTION_INTEGRITY")
        numeric_fields = (
            "final_forward_displacement_m",
            "turn_phase_yaw_delta_rad",
            "maximum_absolute_requested_steering_fraction",
            "maximum_absolute_held_steering_fraction",
            "maximum_tilt_rad",
            "minimum_torso_height_m",
            "maximum_absolute_stability_velocity_residual_rad_s",
        )
        if any(not _finite(measurements.get(field)) for field in numeric_fields):
            failures.append("R23D36_MEASUREMENTS_NONFINITE")
        count_fields = (
            "torso_ground_contact_step_count",
            "controller_error_count",
            "safe_no_actuation_count",
            "nonfinite_observation_count",
            "actuator_application_mismatch_count",
            "controller_semantic_step_count",
            "validated_portable_command_count",
            "native_actuation_application_count",
            "stability_composition_step_count",
            "stability_planning_available_step_count",
            "stability_plan_active_step_count",
            "stability_nonzero_residual_step_count",
        )
        if any(not _count(measurements.get(field)) for field in count_fields):
            failures.append("R23D36_MEASUREMENT_COUNTS")
        if isinstance(trace_summary, dict):
            for field in (
                "stability_composition_step_count",
                "stability_planning_available_step_count",
                "stability_plan_active_step_count",
                "stability_nonzero_residual_step_count",
                "maximum_absolute_stability_velocity_residual_rad_s",
            ):
                if measurements.get(field) != trace_summary.get(field):
                    failures.append(f"R23D36_COMPOSITION_SUMMARY_MISMATCH:{field}")
    execution_valid = not failures
    physical_failures: list[str] = []
    if execution_valid and isinstance(measurements, dict):
        contacts = measurements.get("contact_cycle_count_by_limb")
        if float(measurements["final_forward_displacement_m"]) < 0.030123046875:
            physical_failures.append("R23D36_FORWARD_DISPLACEMENT")
        if float(measurements["maximum_tilt_rad"]) > 0.6:
            physical_failures.append("R23D36_MAXIMUM_TILT")
        if float(measurements["minimum_torso_height_m"]) < 0.2499708652072946:
            physical_failures.append("R23D36_MINIMUM_HEIGHT")
        if (
            not isinstance(contacts, dict)
            or set(contacts) != set(design.LIMB_IDS)
            or any(
                not _count(contacts.get(limb)) or contacts[limb] < 2
                for limb in design.LIMB_IDS
            )
        ):
            physical_failures.append("R23D36_CONTACT_CYCLES")
        for field, gate in (
            ("torso_ground_contact_step_count", "R23D36_TORSO_GROUND_CONTACT"),
            ("controller_error_count", "R23D36_CONTROLLER_ERROR"),
            ("safe_no_actuation_count", "R23D36_SAFE_NO_ACTUATION"),
            ("nonfinite_observation_count", "R23D36_NONFINITE_OBSERVATION"),
            ("actuator_application_mismatch_count", "R23D36_ACTUATOR_MISMATCH"),
        ):
            if measurements[field] != 0:
                physical_failures.append(gate)
        if measurements["controller_semantic_step_count"] != design.CONTROLLER_STEPS:
            physical_failures.append("R23D36_CONTROLLER_HORIZON")
        if measurements["validated_portable_command_count"] != design.CONTROLLER_STEPS * 8:
            physical_failures.append("R23D36_VALIDATED_COMMAND_COUNT")
        if measurements["native_actuation_application_count"] != design.CONTROLLER_STEPS * 8:
            physical_failures.append("R23D36_NATIVE_APPLICATION_COUNT")
        if measurements["stability_composition_step_count"] != design.CONTROLLER_STEPS:
            physical_failures.append("R23D36_COMPOSITION_HORIZON")
        if measurements["stability_planning_available_step_count"] < 1:
            physical_failures.append("R23D36_NO_AVAILABLE_STABILITY_PLAN")
        if measurements["stability_nonzero_residual_step_count"] < 1:
            physical_failures.append("R23D36_NO_NONZERO_STABILITY_RESIDUAL")
        maximum = float(measurements["maximum_absolute_stability_velocity_residual_rad_s"])
        if not 0.0 < maximum <= MAXIMUM_RESIDUAL_RAD_S + 1.0e-12:
            physical_failures.append("R23D36_STABILITY_RESIDUAL_BOUND")
    result.update(
        entry_kind="report",
        execution_valid=execution_valid,
        walking_gate_passed=execution_valid and not physical_failures,
        failed_gate_ids=failures + physical_failures,
        world_attempt_count=(
            int(execution.get("world_attempt_count", 0))
            if isinstance(execution, dict)
            else 0
        ),
        world_build_count=(
            int(execution.get("world_build_count", 0))
            if isinstance(execution, dict)
            else 0
        ),
        measurements=copy.deepcopy(measurements) if isinstance(measurements, dict) else None,
    )
    return result


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D36EvaluationError("R23D36_SOURCE_COMMIT_INVALID")
    expected = design.cells()
    if len(entries) != 1 or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D36EvaluationError("R23D36_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations = [
        evaluate_entry(entry, item, expected_source_commit=expected_source_commit)
        for entry, item in zip(entries, expected, strict=True)
    ]
    positive = evaluations[0]["walking_gate_passed"] is True
    invalid = evaluations[0]["execution_valid"] is not True
    classification = (
        "valid_complete_positive_mujoco_walking_restoration"
        if positive
        else "invalid_complete_mujoco_walking_restoration"
        if invalid
        else "valid_complete_negative_mujoco_walking_restoration"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["mujoco_r23d29_bw19v_walking_restoration"] = positive
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": 1,
        "cell_evaluations": evaluations,
        "all_declared_cells_executed_or_retained_as_failures": True,
        "terminal_restoration_or_taper_invoked": False,
        "claims": claims,
    }


def _synthetic_row(item: design.Cell, step: int) -> dict[str, Any]:
    segment, offset = design.segment_for_step(item, step)
    contacts = {limb: True for limb in design.LIMB_IDS}
    residuals = [
        {
            "actuator_id": actuator_id,
            "canonical_velocity_delta_rad_s": 0.001 if index == 0 else 0.0,
        }
        for index, actuator_id in enumerate(design.ACTUATOR_IDS)
    ]
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": item.cell_id,
        "semantic_step": step,
        "segment_id": segment,
        "desired_heading_offset_rad": offset,
        "measured_yaw_rad": 0.0,
        "desired_heading_error_rad": 0.0,
        "yaw_tracking_error_rad": 0.0,
        "requested_steering_fraction": 0.0,
        "held_steering_fraction": 0.0,
        "steering_saturated": False,
        "torso_position_world_m": [step * 0.0001, 0.4, 0.0],
        "torso_height_m": 0.4,
        "torso_tilt_rad": 0.0,
        "torso_ground_contact": False,
        "ordered_limb_phase_before": [],
        "ordered_foot_contacts_before": contacts,
        "ordered_foot_contacts_after": contacts.copy(),
        "validated_portable_command_count": 8,
        "native_actuation_application_count": 8,
        "oracle_passed": True,
        "stability_policy_id": design.STABILITY_POLICY_ID,
        "stability_planning_availability": "available",
        "stability_planning_outcome_code": "AVAILABLE",
        "stability_plan_active": False,
        "stability_nonzero_residual_count": 1,
        "stability_maximum_absolute_velocity_residual_rad_s": 0.001,
        "ordered_stability_velocity_residuals": residuals,
        "stability_composition_integrity_passed": True,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    item = design.cells()[0]
    trace = [_synthetic_row(item, step) for step in range(design.CONTROLLER_STEPS)]
    valid = validate_trace(item.cell_id, trace)
    wrong_order = copy.deepcopy(trace)
    wrong_order[0]["ordered_stability_velocity_residuals"].reverse()
    wrong_order_result = validate_trace(item.cell_id, wrong_order)
    over_bound = copy.deepcopy(trace)
    over_bound[0]["ordered_stability_velocity_residuals"][0][
        "canonical_velocity_delta_rad_s"
    ] = 0.076
    over_bound[0]["stability_maximum_absolute_velocity_residual_rad_s"] = 0.076
    over_bound_result = validate_trace(item.cell_id, over_bound)
    if not valid["ok"] or wrong_order_result["ok"] or over_bound_result["ok"]:
        raise R23D36EvaluationError("R23D36_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d36_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": 1,
        "valid_trace_canary_count": 1,
        "trace_mutation_rejection_count": 2,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--expected-source-commit", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D36_EVALUATOR_PREFLIGHT "
        elif args.command == "retain-trace":
            value = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root_override,
            )
            marker = "QSDK_R23D36_TRACE_RETAINED "
        else:
            paths = json.loads(args.manifest.read_text(encoding="utf-8"))
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries, expected_source_commit=args.expected_source_commit
            )
            marker = "QSDK_R23D36_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (R23D36EvaluationError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"QSDK_R23D36_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
