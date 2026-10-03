"""Zero-world trace retention and finite evaluation for QSDK-R23D35."""

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

from r23d31_cycle_integrated_measurement import (
    CycleIntegratedMeasurementError,
    measure_cycle_integrated_response,
)
import r23d35_godot_trace_recovery as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = ROOT / "r23d35_godot_trace_recovery_preregistration_v1.json"
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d35_trace.ps1"
REPORT_SCHEMA = "sporespore_qsdk_r23d35_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d35_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d35_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d35_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d35_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "godot_jolt_r23d29_turning": False,
    "mujoco_r23d29_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D35EvaluationError(RuntimeError):
    """The prospective declaration, trace, report, or matrix is invalid."""


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
        raise R23D35EvaluationError(
            f"R23D35_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    candidate = value.get("candidate", {})
    measurement = value.get("cycle_integrated_measurement", {})
    gates = value.get("frozen_common_physical_gates", {})
    lineage = value.get("immutable_lineage", {})
    repair = value.get("implementation_repair_boundary", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d35_godot_trace_recovery_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or candidate.get("controller_policy_id") != design.POLICY_ID
        or candidate.get("controller_memory_schema")
        != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or candidate.get("guard_receipt_schema")
        != "sporespore_steering_authority_guard_receipt_v3"
        or candidate.get("engine_specific_gait_logic_permitted") is not False
        or candidate.get("arm_identity_or_outcome_branching_permitted") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.ENGINE_IDS)
        or matrix.get("ordered_arm_ids") != list(design.ARM_OFFSETS)
        or matrix.get("declared_cell_count") != 3
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad") != 0.01
        or gates.get("minimum_final_forward_displacement_m") != 0.030123046875
        or gates.get("maximum_tilt_rad") != 0.6
        or gates.get("minimum_torso_height_m") != 0.2499708652072946
        or gates.get("minimum_contact_cycles_per_limb") != 2
        or lineage.get("r23d31_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d31_cycle_integrated_directional_response_closure_v1.json")
        or lineage.get("r23d32_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d32_finite_rapier_turning_replication_closure_v1.json")
        or lineage.get("r23d34_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d34_native_r23d29_transfer_closure_v1.json")
        or lineage.get("r23d34_identity_consumed") is not True
        or lineage.get("r23d34_same_identity_or_selective_rerun_forbidden") is not True
        or lineage.get("r23d34_godot_walking_outcome_observed") is not False
        or lineage.get("r23d34_godot_turning_outcome_observed") is not False
        or lineage.get("r23d34_mujoco_outcome_is_not_replayed_or_reinterpreted") is not True
        or repair.get("closed_predecessor_raw_sha256")
        != raw_sha256(ROOT / "r23d34_native_r23d29_transfer_closure_v1.json")
        or repair.get("full_horizon_live_trace_composition_preflight_required")
        is not True
        or repair.get("preflight_controller_step_count") != design.CONTROLLER_STEPS
        or repair.get("preflight_native_controller_command_count")
        != design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        or repair.get("integral_float_acceptance_required") is not True
        or repair.get("fractional_float_rejection_required") is not True
        or repair.get("same_unresolved_godot_estimand_retained_because_r23d34_exposed_no_godot_locomotion_outcome")
        is not True
        or repair.get("scientific_controller_change") is not False
        or repair.get("physics_or_adapter_actuation_changed_from_r23d34") is not False
        or repair.get("fixture_changed_from_r23d34") is not False
        or repair.get("campaign_seed_changed_from_r23d34") is not False
        or repair.get("command_schedule_changed_from_r23d34") is not False
        or repair.get("mujoco_world_permitted") is not False
        or repair.get("other_implementation_changes_permitted") is not False
    )
    if invalid:
        raise R23D35EvaluationError("R23D35_DECLARATION_IDENTITY_INVALID")
    return value


def expected_cells() -> list[str]:
    return [item.cell_id for item in design.cells()]


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    matches = [item for item in design.cells() if item.cell_id == cell_id]
    if len(matches) != 1 or not isinstance(rows, list):
        raise R23D35EvaluationError("R23D35_TRACE_IDENTITY_INVALID")
    item = matches[0]
    failures: list[str] = []
    if len(rows) != design.CONTROLLER_STEPS:
        failures.append("R23D35_TRACE_ROW_COUNT")
    segment_counts = {name: 0 for name in design.expected_segment_counts(item)}
    for expected_step, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"R23D35_TRACE_ROW_TYPE:{expected_step}")
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
        ):
            failures.append(f"R23D35_TRACE_ROW_INVALID:{expected_step}")
        for field in ("ordered_foot_contacts_before", "ordered_foot_contacts_after"):
            contacts = row.get(field)
            if (
                not isinstance(contacts, dict)
                or set(contacts) != set(design.LIMB_IDS)
                or any(not isinstance(contacts.get(limb), bool) for limb in design.LIMB_IDS)
            ):
                failures.append(f"R23D35_TRACE_CONTACTS_INVALID:{expected_step}:{field}")
        if expected_segment in segment_counts:
            segment_counts[expected_segment] += 1
    if segment_counts != design.expected_segment_counts(item):
        failures.append("R23D35_TRACE_SEGMENT_COUNTS")
    try:
        canonical = _canonical_ndjson(rows)
    except (TypeError, ValueError) as error:
        raise R23D35EvaluationError(
            f"R23D35_TRACE_CANONICALIZATION_FAILED:{type(error).__name__}"
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
        raise R23D35EvaluationError("R23D35_RETENTION_IDENTITY_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D35EvaluationError(
            f"R23D35_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    if not summary["ok"]:
        raise R23D35EvaluationError(
            "R23D35_TRACE_INVALID:" + ",".join(summary["failure_codes"][:8])
        )
    attempt_root = attempt_root.resolve()
    production_root = REPO_ROOT.parent / "SporeSpore_Evidence"
    try:
        attempt_root.relative_to(
            (evidence_root_override if test_only else production_root).resolve()
        )
    except (AttributeError, ValueError) as error:
        raise R23D35EvaluationError("R23D35_ATTEMPT_ROOT_INVALID") from error
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    output = trace_root / f"{cell_id}.ndjson"
    if output.exists():
        raise R23D35EvaluationError("R23D35_TRACE_OUTPUT_EXISTS")
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
            raise R23D35EvaluationError("R23D35_TEST_EVIDENCE_ROOT_REQUIRED")
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
    prefix = "QSDK_R23D35_EVIDENCE_CAS "
    markers = [line[len(prefix) :] for line in process.stdout.splitlines() if line.startswith(prefix)]
    if process.returncode != 0 or len(markers) != 1:
        raise R23D35EvaluationError(
            f"R23D35_TRACE_CAS_FAILED:{process.returncode}:{process.stderr[-500:]}"
        )
    artifact = json.loads(markers[0])
    if (
        artifact.get("schema_version") != ARTIFACT_SCHEMA
        or artifact.get("sha256") != summary["raw_sha256"]
        or artifact.get("byte_length") != summary["byte_length"]
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D35EvaluationError("R23D35_TRACE_CAS_RECEIPT_INVALID")
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


def _artifact_rows(entry: Mapping[str, Any], item: design.Cell) -> tuple[list[dict[str, Any]], list[str]]:
    failures: list[str] = []
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return [], ["R23D35_TRACE_ARTIFACT_RECEIPT"]
    if artifact.get("test_only") is True:
        failures.append("R23D35_TEST_ARTIFACT_FORBIDDEN")
    path = Path(str(artifact.get("payload_path", "")))
    try:
        raw = path.read_bytes()
        rows = [json.loads(line) for line in raw.splitlines()]
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [], failures + [f"R23D35_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    if (
        not raw.endswith(b"\n")
        or digest != artifact.get("sha256")
        or len(raw) != artifact.get("byte_length")
        or _canonical_ndjson(rows) != raw
    ):
        failures.append("R23D35_TRACE_ARTIFACT_BYTES")
    summary = validate_trace(item.cell_id, rows)
    if not summary["ok"]:
        failures.extend(summary["failure_codes"])
    recorded = entry.get("trace_summary")
    if not isinstance(recorded, dict) or any(
        recorded.get(field) != summary.get(field)
        for field in ("raw_sha256", "byte_length", "row_count", "segment_counts")
    ):
        failures.append("R23D35_TRACE_SUMMARY_MISMATCH")
    return rows, failures


def _incomplete_trace_diagnostic_failures(
    entry: Mapping[str, Any], item: design.Cell
) -> list[str]:
    """Verify that a post-world incomplete trace remained inspectable in CAS."""

    diagnostic = entry.get("trace_diagnostic")
    artifact = entry.get("trace_diagnostic_artifact")
    if not isinstance(diagnostic, dict) or not isinstance(artifact, dict):
        return ["R23D35_INCOMPLETE_TRACE_DIAGNOSTIC_MISSING"]
    if artifact.get("schema_version") != ARTIFACT_SCHEMA or artifact.get("test_only") is True:
        return ["R23D35_INCOMPLETE_TRACE_DIAGNOSTIC_RECEIPT"]
    path = Path(str(artifact.get("payload_path", "")))
    try:
        raw = path.read_bytes()
        retained = json.loads(raw)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D35_INCOMPLETE_TRACE_DIAGNOSTIC_UNREADABLE:{type(error).__name__}"]
    failures: list[str] = []
    retained_summary = dict(retained) if isinstance(retained, dict) else {}
    retained_summary.pop("rows", None)
    if (
        "sha256:" + hashlib.sha256(raw).hexdigest() != artifact.get("sha256")
        or len(raw) != artifact.get("byte_length")
        or retained_summary != diagnostic
    ):
        failures.append("R23D35_INCOMPLETE_TRACE_DIAGNOSTIC_BYTES")
    rows = retained.get("rows") if isinstance(retained, dict) else None
    if (
        diagnostic.get("schema_version")
        != "sporespore_qsdk_r23d35_trace_diagnostic_v1"
        or diagnostic.get("cell_id") != item.cell_id
        or diagnostic.get("complete") is not False
        or not isinstance(rows, list)
        or diagnostic.get("actual_row_count") != len(rows)
        or not _count(diagnostic.get("declared_row_count"))
        or diagnostic.get("declared_row_count") != design.CONTROLLER_STEPS
        or diagnostic.get("reported_row_count") != len(rows)
        or not isinstance(diagnostic.get("failure_codes"), list)
        or not all(isinstance(code, str) and code for code in diagnostic["failure_codes"])
        or diagnostic.get("partial_rows_retained") is not True
        or diagnostic.get("retained_before_terminal_entry") is not True
    ):
        failures.append("R23D35_INCOMPLETE_TRACE_DIAGNOSTIC_SHAPE")
    return failures


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    result = {
        "cell_id": item.cell_id,
        "engine_id": item.engine_id,
        "arm_id": item.arm_id,
        "entry_kind": "invalid",
        "execution_valid": False,
        "common_physical_gate_passed": False,
        "failed_gate_ids": [],
        "world_attempt_count": 0,
        "world_build_count": 0,
    }
    if not isinstance(entry, dict):
        result["failed_gate_ids"] = ["R23D35_ENTRY_TYPE"]
        return result, []
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
        failure_ids = [
            "R23D35_FAILURE_IDENTITY"
            if not identity_valid
            else str(entry.get("failure_code", "R23D35_WORKER_FAILURE"))
        ]
        if (
            identity_valid
            and entry.get("failure_code") == "QSDK_R23D35_GJT_TRACE_INCOMPLETE"
            and entry.get("world_attempt_count") == 1
        ):
            failure_ids.extend(_incomplete_trace_diagnostic_failures(entry, item))
        result.update(
            entry_kind="worker_failure",
            world_attempt_count=int(entry.get("world_attempt_count", 0)),
            world_build_count=int(entry.get("world_build_count", 0)),
            failed_gate_ids=failure_ids,
        )
        return result, []
    if entry.get("schema_version") != REPORT_SCHEMA or not identity_valid:
        result["failed_gate_ids"] = ["R23D35_REPORT_IDENTITY"]
        return result, []
    rows, failures = _artifact_rows(entry, item)
    execution = entry.get("execution")
    measurements = entry.get("measurements")
    if not isinstance(execution, dict) or not isinstance(measurements, dict):
        failures.append("R23D35_REPORT_SHAPE")
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
            or execution.get("fixed_horizon_configuration_proved_before_fixture_insertion") is not True
        ):
            failures.append("R23D35_EXECUTION_INTEGRITY")
        numeric_fields = (
            "final_forward_displacement_m",
            "turn_phase_yaw_delta_rad",
            "maximum_absolute_requested_steering_fraction",
            "maximum_absolute_held_steering_fraction",
            "maximum_tilt_rad",
            "minimum_torso_height_m",
        )
        if any(not _finite(measurements.get(field)) for field in numeric_fields):
            failures.append("R23D35_MEASUREMENTS_NONFINITE")
        count_fields = (
            "torso_ground_contact_step_count",
            "controller_error_count",
            "safe_no_actuation_count",
            "nonfinite_observation_count",
            "actuator_application_mismatch_count",
            "controller_semantic_step_count",
            "validated_portable_command_count",
            "native_actuation_application_count",
        )
        if any(not _count(measurements.get(field)) for field in count_fields):
            failures.append("R23D35_MEASUREMENT_COUNTS")
    execution_valid = not failures
    physical_failures: list[str] = []
    if execution_valid and isinstance(measurements, dict):
        contacts = measurements.get("contact_cycle_count_by_limb")
        if float(measurements["final_forward_displacement_m"]) < 0.030123046875:
            physical_failures.append("R23D35_FORWARD_DISPLACEMENT")
        if float(measurements["maximum_tilt_rad"]) > 0.6:
            physical_failures.append("R23D35_MAXIMUM_TILT")
        if float(measurements["minimum_torso_height_m"]) < 0.2499708652072946:
            physical_failures.append("R23D35_MINIMUM_HEIGHT")
        if (
            not isinstance(contacts, dict)
            or set(contacts) != set(design.LIMB_IDS)
            or any(not _count(contacts.get(limb)) or contacts[limb] < 2 for limb in design.LIMB_IDS)
        ):
            physical_failures.append("R23D35_CONTACT_CYCLES")
        for field, gate in (
            ("torso_ground_contact_step_count", "R23D35_TORSO_GROUND_CONTACT"),
            ("controller_error_count", "R23D35_CONTROLLER_ERROR"),
            ("safe_no_actuation_count", "R23D35_SAFE_NO_ACTUATION"),
            ("nonfinite_observation_count", "R23D35_NONFINITE_OBSERVATION"),
            ("actuator_application_mismatch_count", "R23D35_ACTUATOR_MISMATCH"),
        ):
            if measurements[field] != 0:
                physical_failures.append(gate)
        if measurements["controller_semantic_step_count"] != design.CONTROLLER_STEPS:
            physical_failures.append("R23D35_CONTROLLER_HORIZON")
        if measurements["validated_portable_command_count"] != design.CONTROLLER_STEPS * 8:
            physical_failures.append("R23D35_VALIDATED_COMMAND_COUNT")
        if measurements["native_actuation_application_count"] != design.CONTROLLER_STEPS * 8:
            physical_failures.append("R23D35_NATIVE_APPLICATION_COUNT")
    result.update(
        entry_kind="report",
        execution_valid=execution_valid,
        common_physical_gate_passed=execution_valid and not physical_failures,
        failed_gate_ids=failures + physical_failures,
        world_attempt_count=int(execution.get("world_attempt_count", 0)) if isinstance(execution, dict) else 0,
        world_build_count=int(execution.get("world_build_count", 0)) if isinstance(execution, dict) else 0,
    )
    return result, rows


def _measurement_rows(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "trace_step": row.get("semantic_step"),
            # Preserve the engine trace's inherited R23D3 segment vocabulary
            # during validation and retention.  Only this pure measurement
            # boundary translates the post-schedule interval into the frozen
            # R23D31 estimator vocabulary.
            "phase_id": (
                "reference_continuation"
                if row.get("segment_id") == "after_declared_schedule"
                else row.get("segment_id")
            ),
            "measured_yaw_rad": row.get("measured_yaw_rad"),
        }
        for row in rows
    ]


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D35EvaluationError("R23D35_SOURCE_COMMIT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D35EvaluationError("R23D35_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, expected, strict=True):
        evaluation, rows = evaluate_entry(
            entry, item, expected_source_commit=expected_source_commit
        )
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows
    engine_results: dict[str, Any] = {}
    for engine_id in design.ENGINE_IDS:
        engine_cells = [item for item in expected if item.engine_id == engine_id]
        engine_evaluations = [
            evaluation for evaluation in evaluations if evaluation["engine_id"] == engine_id
        ]
        all_execution_valid = all(row["execution_valid"] for row in engine_evaluations)
        all_physical_passed = all(
            row["common_physical_gate_passed"] for row in engine_evaluations
        )
        measurement = None
        measurement_failures: list[str] = []
        if all_execution_valid:
            measurement = measure_cycle_integrated_response(
                {
                    item.arm_id: _measurement_rows(rows_by_cell[item.cell_id])
                    for item in engine_cells
                }
            )
            measurement_failures = [
                gate for gate, passed in measurement["gates"].items() if not passed
            ]
        passed = all_execution_valid and all_physical_passed and bool(
            measurement and measurement.get("passed") is True
        )
        engine_results[engine_id] = {
            "all_cells_execution_valid": all_execution_valid,
            "all_common_physical_gates_passed": all_physical_passed,
            "cycle_integrated_measurement": measurement,
            "measurement_failure_codes": measurement_failures,
            "passed": passed,
        }
    complete = len(evaluations) == 3
    positive = complete and all(result["passed"] for result in engine_results.values())
    any_invalid = any(not row["execution_valid"] for row in evaluations)
    classification = (
        "valid_complete_positive_godot_trace_recovery"
        if positive
        else "invalid_complete_godot_trace_recovery"
        if any_invalid
        else "valid_complete_negative_godot_trace_recovery"
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "engine_results": engine_results,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "terminal_restoration_or_taper_invoked": False,
        "claims": {
            "godot_jolt_r23d29_turning": bool(engine_results["godot_jolt"]["passed"]),
            "mujoco_r23d29_turning": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "cross_engine_equivalence": False,
            "population_robustness": False,
            "prone_to_standing": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def _synthetic_row(item: design.Cell, step: int) -> dict[str, Any]:
    segment, offset = design.segment_for_step(item, step)
    signed = 0.0
    if item.arm_id != "reference_zero" and step >= design.TURN_START_STEP:
        signed = math.copysign(
            min(0.15, (step - design.TURN_START_STEP) * 0.0002),
            item.turn_heading_offset_rad,
        )
    contacts = {limb: True for limb in design.LIMB_IDS}
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": item.cell_id,
        "semantic_step": step,
        "segment_id": segment,
        "desired_heading_offset_rad": offset,
        "measured_yaw_rad": signed,
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
    }


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    first = design.cells()[0]
    trace = [_synthetic_row(first, step) for step in range(design.CONTROLLER_STEPS)]
    valid = validate_trace(first.cell_id, trace)
    mutated = copy.deepcopy(trace)
    mutated[600]["segment_id"] = "reference_warmup"
    mutation = validate_trace(first.cell_id, mutated)
    rows_by_arm = {}
    for arm_id in design.ARM_OFFSETS:
        item = design.cell(design.STAGE_ID, "godot_jolt", arm_id)
        rows_by_arm[arm_id] = _measurement_rows(
            [_synthetic_row(item, step) for step in range(design.CONTROLLER_STEPS)]
        )
    measurement = measure_cycle_integrated_response(rows_by_arm)
    if not valid["ok"] or mutation["ok"] or measurement.get("passed") is not True:
        raise R23D35EvaluationError("R23D35_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d35_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": 3,
        "valid_trace_canary_count": 1,
        "trace_mutation_rejection_count": 1,
        "cycle_integrated_measurement_canary_count": 1,
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
            marker = "QSDK_R23D35_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D35_TRACE_RETAINED "
        else:
            paths = json.loads(args.manifest.read_text(encoding="utf-8"))
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries, expected_source_commit=args.expected_source_commit
            )
            marker = "QSDK_R23D35_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D35EvaluationError,
        CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D35_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
