"""Paired same-seed startup-transform evaluation for QSDK-R23D44."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping, Sequence

import r23d34_native_r23d29_transfer_evaluator as inherited
import r23d44_rapier_paired_startup_transform as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d44_rapier_paired_startup_transform_preregistration_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d44_trace.ps1"
REPORT_SCHEMA = "sporespore_qsdk_r23d44_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d44_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d44_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d44_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d44_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "paired_same_seed_startup_transform_effect_characterized": False,
    "finite_rapier_turning_validation": False,
    "portable_basic_turning": False,
    "finite_three_engine_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D44EvaluationError(RuntimeError):
    """The paired declaration, evidence route, or result is invalid."""


_BASE_VALIDATE_TRACE = inherited.validate_trace
_BASE_EVALUATE_ENTRY = inherited.evaluate_entry
_BASE_SYNTHETIC_ROW = inherited._synthetic_row


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def _same_existing_path(left: Path, right: Path) -> bool:
    """Compare file identity, not Windows namespace spelling."""

    try:
        return os.path.samefile(os.fspath(left), os.fspath(right))
    except OSError:
        return False


def _alternate_windows_spelling(path: Path) -> Path:
    absolute = os.path.abspath(os.fspath(path))
    if os.name != "nt":
        return Path(absolute)
    if absolute.startswith("\\\\?\\UNC\\"):
        return Path("\\\\" + absolute[8:])
    if absolute.startswith("\\\\?\\"):
        return Path(absolute[4:])
    if absolute.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + absolute[2:])
    return Path("\\\\?\\" + absolute)


def _excerpt(value: str, maximum: int = 2_000) -> str:
    return value.replace("\x00", "\\0")[-maximum:]


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D44EvaluationError(
            f"R23D44_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    lineage = value.get("immutable_lineage", {})
    paired = value.get("paired_causal_development", {})
    repair = value.get("implementation_repair_boundary", {})
    matrix = value.get("frozen_matrix", {})
    measurement = value.get("cycle_integrated_measurement", {})
    physical = value.get("frozen_common_physical_gates", {})
    retention = value.get("production_trace_retention_gate", {})
    selector = value.get("selector", {})
    evidence = value.get("evidence", {})
    claims = value.get("claims", {})
    lineage_bindings = {
        "r23d30_physical_closure_raw_sha256": (
            ROOT / "r23d30_cycle_coherent_directional_response_closure_v1.json"
        ),
        "r23d43_physical_closure_raw_sha256": (
            ROOT / "r23d43_rapier_retention_hardened_turning_closure_v1.json"
        ),
        "r23d43_startup_transform_diagnosis_closure_raw_sha256": (
            SDK_ROOT
            / "trace_analysis"
            / "r23d43_rapier_startup_transform_diagnosis_closure_v1.json"
        ),
    }
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d44_rapier_paired_startup_transform_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("release_gate_id") != design.RELEASE_GATE_ID
        or value.get("study_classification")
        != "prospective_outcome_exposed_paired_same_seed_rapier_startup_transform_development"
        or any(lineage.get(field) != raw_sha256(path) for field, path in lineage_bindings.items())
        or lineage.get("r23d30_identity_consumed") is not True
        or lineage.get("r23d43_identity_consumed") is not True
        or lineage.get("same_identity_rerun_permitted") is not False
        or lineage.get("historical_result_reinterpreted") is not False
        or lineage.get("historical_world_reused_as_new_cell") is not False
        or lineage.get("diagnosis_found_seed_and_transform_confounded") is not True
        or lineage.get("diagnosis_authorized_only_a_paired_same_seed_development_successor")
        is not True
        or paired.get("campaign_seed") != design.CAMPAIGN_SEED
        or paired.get("seed_was_outcome_exposed_before_preregistration") is not True
        or paired.get("fresh_or_held_out_condition") is not False
        or paired.get("validation_or_replication_study") is not False
        or paired.get("same_initial_perturbation_across_candidates") is not True
        or paired.get("sole_declared_candidate_difference") != "startup_velocity_transform"
        or paired.get("ordered_candidate_ids") != list(design.CANDIDATE_IDS)
        or paired.get("identity_transform_id") != design.NO_RAMP_ID
        or paired.get("canonical_startup_ramp_id") != design.STARTUP_RAMP_ID
        or paired.get("canonical_startup_ramp_step_count") != design.STARTUP_RAMP_STEPS
        or paired.get("controller_policy_id") != design.POLICY_ID
        or any(
            paired.get(field) is not False
            for field in (
                "controller_behavior_changed",
                "measurement_changed",
                "threshold_changed",
                "physics_changed",
                "morphology_changed",
                "command_schedule_changed",
                "engine_specific_gait_logic_permitted",
                "engine_identity_input_to_controller_permitted",
                "command_sign_branching_permitted",
                "population_or_cross_seed_inference_permitted",
            )
        )
        or paired.get("causal_scope") != "exact_deterministic_seed_21504_only"
        or repair.get("windows_same_file_cas_verifier_repair") is not True
        or repair.get("path_text_equality_for_file_identity_forbidden") is not True
        or repair.get("ordinary_and_extended_windows_namespace_positive_control_required")
        is not True
        or repair.get("wrong_existing_file_negative_control_required") is not True
        or repair.get(
            "complete_evaluator_cas_binding_function_exercised_before_first_world"
        )
        is not True
        or repair.get("old_r23d43_official_result_repaired_or_reclassified") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.ENGINE_IDS)
        or matrix.get("ordered_candidate_ids") != list(design.CANDIDATE_IDS)
        or matrix.get("ordered_arm_ids") != list(design.ARM_OFFSETS)
        or matrix.get("ordered_heading_offsets_rad") != list(design.ARM_OFFSETS.values())
        or matrix.get("declared_cell_count") != len(design.cells())
        or matrix.get("declared_world_count") != len(design.cells())
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("recovery_duration_steps") != design.RECOVERY_DURATION_STEPS
        or matrix.get("startup_ramp_step_count") != design.STARTUP_RAMP_STEPS
        or matrix.get("startup_ramp_active_step_count") != design.STARTUP_RAMP_STEPS - 1
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad") != 0.01
        or measurement.get("both_signed_arms_required") is not True
        or measurement.get("reference_arm_required") is not True
        or measurement.get("threshold_changed_after_diagnosis") is not False
        or physical.get("minimum_final_forward_displacement_m") != 0.030123046875
        or physical.get("maximum_tilt_rad") != 0.6
        or physical.get("minimum_torso_height_m") != 0.2499708652072946
        or physical.get("minimum_contact_cycles_per_limb") != 2
        or physical.get("exact_candidate_startup_transform_composition_required")
        is not True
        or retention.get("required_before_first_world") is not True
        or retention.get("synthetic_trace_count") != len(design.CANDIDATE_IDS)
        or retention.get("synthetic_trace_row_count")
        != len(design.CANDIDATE_IDS) * design.CONTROLLER_STEPS
        or retention.get("one_trace_per_candidate_required") is not True
        or retention.get("complete_cas_binding_verifier_required") is not True
        or retention.get("world_build_count") != 0
        or retention.get("model_construction_count") != 0
        or selector.get("classification_uses_each_candidates_full_three_arm_gate") is not True
        or selector.get("candidate_selection_or_release_promotion_permitted") is not False
        or evidence.get("clean_pushed_source_required") is not True
        or evidence.get("campaign_local_lca1_qualification_required") is not True
        or evidence.get("positive_production_authorization_preflight_required_per_cell")
        is not True
        or evidence.get("same_identity_rerun_allowed") is not False
        or any(claims.get(field) is not False for field in FALSE_CLAIMS)
    )
    if invalid:
        raise R23D44EvaluationError("R23D44_DECLARATION_IDENTITY_INVALID")
    return value


# Rebind the frozen generic R34 trace/report semantics to the R44 identity.
inherited.design = design
inherited.DECLARATION_PATH = DECLARATION_PATH
inherited.REPORT_SCHEMA = REPORT_SCHEMA
inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
inherited.FALSE_CLAIMS = FALSE_CLAIMS
inherited.load_declaration = load_declaration


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    summary = _BASE_VALIDATE_TRACE(cell_id, rows)
    matches = [item for item in design.cells() if item.cell_id == cell_id]
    if len(matches) != 1:
        raise R23D44EvaluationError("R23D44_TRACE_IDENTITY_INVALID")
    item = matches[0]
    failures = list(summary.get("failure_codes", []))
    active_count = 0
    zero_count = 0
    unity_count = 0
    for step, row in enumerate(rows if isinstance(rows, list) else []):
        if not isinstance(row, dict):
            continue
        expected_scale = design.startup_velocity_scale(step) if item.startup_ramp_applied else 1.0
        expected_id = design.STARTUP_RAMP_ID if item.startup_ramp_applied else design.NO_RAMP_ID
        residual = row.get("startup_ramp_maximum_absolute_residual_rad_s")
        exact = (
            row.get("startup_ramp_id") == expected_id
            and _finite(row.get("startup_velocity_scale"))
            and float(row.get("startup_velocity_scale", math.nan)) == expected_scale
            and row.get("startup_ramp_active")
            is (item.startup_ramp_applied and expected_scale < 1.0)
            and row.get("startup_ramp_residual_count") == design.ACTUATOR_COUNT
            and _finite(residual)
            and float(residual) >= 0.0
            and (item.startup_ramp_applied or float(residual) == 0.0)
        )
        if not exact:
            failures.append(f"R23D44_STARTUP_TRANSFORM_ROW_INVALID:{step}")
        active_count += int(row.get("startup_ramp_active") is True)
        zero_count += int(row.get("startup_velocity_scale") == 0.0)
        unity_count += int(row.get("startup_velocity_scale") == 1.0)
    expected_counts = (
        (design.STARTUP_RAMP_STEPS - 1, 1, design.CONTROLLER_STEPS - (design.STARTUP_RAMP_STEPS - 1))
        if item.startup_ramp_applied
        else (0, 0, design.CONTROLLER_STEPS)
    )
    if (active_count, zero_count, unity_count) != expected_counts:
        failures.append("R23D44_STARTUP_TRANSFORM_COUNTS")
    summary["ok"] = not failures
    summary["failure_codes"] = failures[:32]
    summary["candidate_id"] = item.candidate_id
    summary["startup_velocity_ramp_enabled"] = item.startup_ramp_applied
    summary["startup_ramp_id"] = (
        design.STARTUP_RAMP_ID if item.startup_ramp_applied else design.NO_RAMP_ID
    )
    summary["startup_transform_receipt_step_count"] = len(rows) if isinstance(rows, list) else 0
    summary["startup_ramp_active_step_count"] = active_count
    summary["startup_ramp_exact_zero_scale_step_count"] = zero_count
    summary["startup_ramp_exact_unity_scale_step_count"] = unity_count
    return summary


inherited.validate_trace = validate_trace


def _cas_binding_failures(
    artifact: Any, *, authority_repo_root: Path
) -> list[str]:
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D44_TRACE_ARTIFACT_RECEIPT"]
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D44_TRACE_ARTIFACT_IDENTITY"]
    directory = (
        authority_repo_root.parent
        / "SporeSpore_Evidence"
        / "artifacts"
        / "sha256"
        / digest_hex
    )
    payload = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    recorded_payload = Path(str(artifact.get("payload_path", "")))
    recorded_manifest = Path(str(artifact.get("manifest_path", "")))
    if not _same_existing_path(recorded_payload, payload) or not _same_existing_path(
        recorded_manifest, manifest_path
    ):
        return ["R23D44_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D44_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
    observed = "sha256:" + hashlib.sha256(raw).hexdigest()
    if (
        observed != digest
        or len(raw) != artifact.get("byte_length")
        or manifest.get("schema_version")
        != "sporespore_content_addressed_artifact_manifest_v1"
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != digest
        or manifest.get("byte_length") != len(raw)
        or manifest.get("payload_name") != "payload.bin"
        or manifest.get("media_type") != "application/x-ndjson"
    ):
        return ["R23D44_TRACE_ARTIFACT_BYTES"]
    return []


def retain_trace(
    *,
    stage_id: str,
    cell_id: str,
    rows_json_path: Path,
    source_root: Path,
    repo_root: Path,
    attempt_root: Path,
    powershell: str,
    test_only: bool = False,
    evidence_root_override: Path | None = None,
) -> dict[str, Any]:
    load_declaration()
    if stage_id != design.STAGE_ID or cell_id not in {item.cell_id for item in design.cells()}:
        raise R23D44EvaluationError("R23D44_RETENTION_IDENTITY_INVALID")
    source_root = source_root.resolve()
    authority_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    if not _same_existing_path(source_root, REPO_ROOT):
        raise R23D44EvaluationError("R23D44_SOURCE_ROOT_INVALID")
    production_root = authority_root.parent / "SporeSpore_Evidence"
    allowed_root = (
        evidence_root_override.resolve()
        if test_only and evidence_root_override is not None
        else production_root
    )
    if not attempt_root.is_dir() or not _within(attempt_root, allowed_root):
        raise R23D44EvaluationError("R23D44_ATTEMPT_ROOT_INVALID")
    if test_only != (evidence_root_override is not None):
        raise R23D44EvaluationError("R23D44_TEST_ROOT_MODE_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D44EvaluationError(
            f"R23D44_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    if summary.get("ok") is not True:
        raise R23D44EvaluationError(
            "R23D44_TRACE_INVALID:" + ",".join(summary.get("failure_codes", [])[:8])
        )
    canonical = inherited._canonical_ndjson(rows)
    if (
        summary.get("raw_sha256") != "sha256:" + hashlib.sha256(canonical).hexdigest()
        or summary.get("byte_length") != len(canonical)
    ):
        raise R23D44EvaluationError("R23D44_TRACE_CANONICAL_RECEIPT_MISMATCH")
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    output = trace_root / f"{cell_id}.ndjson"
    try:
        with output.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D44EvaluationError("R23D44_TRACE_OUTPUT_EXISTS") from error
    arguments = [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(PUBLISHER_PATH),
        "-RepoRoot",
        str(authority_root),
        "-ArtifactPath",
        str(output),
        "-ExpectedSha256",
        str(summary["raw_sha256"]),
        "-ExpectedByteLength",
        str(summary["byte_length"]),
    ]
    if test_only:
        arguments.extend(
            ["-TestOnly", "-EvidenceRootOverride", str(evidence_root_override.resolve())]
        )
    process = subprocess.run(
        arguments,
        cwd=source_root,
        capture_output=True,
        check=False,
        text=True,
        timeout=180,
    )
    prefix = "QSDK_R23D44_TRACE_CAS "
    markers = [
        line[len(prefix) :]
        for line in process.stdout.splitlines()
        if line.startswith(prefix)
    ]
    if process.returncode != 0 or len(markers) != 1:
        raise R23D44EvaluationError(
            "R23D44_TRACE_CAS_FAILED:"
            f"exit={process.returncode}:markers={len(markers)}:"
            f"stdout={_excerpt(process.stdout)}:stderr={_excerpt(process.stderr)}"
        )
    artifact = json.loads(markers[0])
    if (
        artifact.get("schema_version") != ARTIFACT_SCHEMA
        or artifact.get("sha256") != summary["raw_sha256"]
        or artifact.get("byte_length") != summary["byte_length"]
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D44EvaluationError("R23D44_TRACE_CAS_RECEIPT_INVALID")
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "stage_id": stage_id,
        "cell_id": cell_id,
        "trace_artifact": artifact,
        "trace_summary": summary,
        "retained_before_terminal_entry": True,
        "failed_child_stdout_and_stderr_bounded": True,
        "publisher_maximum_attempt_count": 3,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    evaluation, rows = _BASE_EVALUATE_ENTRY(
        entry, item, expected_source_commit=expected_source_commit
    )
    evaluation["candidate_id"] = item.candidate_id
    evaluation["startup_velocity_ramp_enabled"] = item.startup_ramp_applied
    if not isinstance(entry, dict) or evaluation.get("entry_kind") != "report":
        return evaluation, rows
    failures = _cas_binding_failures(
        entry.get("trace_artifact"), authority_repo_root=authority_repo_root
    )
    measurements = entry.get("measurements")
    summary = entry.get("trace_summary")
    expected_id: Any = design.STARTUP_RAMP_ID if item.startup_ramp_applied else None
    expected_counts = (
        (design.CONTROLLER_STEPS, design.STARTUP_RAMP_STEPS - 1, 1, design.CONTROLLER_STEPS - (design.STARTUP_RAMP_STEPS - 1))
        if item.startup_ramp_applied
        else (design.CONTROLLER_STEPS, 0, 0, design.CONTROLLER_STEPS)
    )
    if (
        entry.get("candidate_id") != item.candidate_id
        or not isinstance(measurements, dict)
        or measurements.get("startup_velocity_ramp_enabled") is not item.startup_ramp_applied
        or measurements.get("startup_ramp_id") != expected_id
        or measurements.get("startup_ramp_step_count")
        != (design.STARTUP_RAMP_STEPS if item.startup_ramp_applied else None)
        or (
            measurements.get("startup_ramp_composition_step_count"),
            measurements.get("startup_ramp_active_step_count"),
            measurements.get("startup_ramp_exact_zero_scale_step_count"),
            measurements.get("startup_ramp_exact_unity_scale_step_count"),
        )
        != expected_counts
        or measurements.get("startup_ramp_composition_integrity_passed") is not True
        or not _finite(measurements.get("maximum_absolute_startup_ramp_residual_rad_s"))
        or not isinstance(summary, dict)
        or summary.get("candidate_id") != item.candidate_id
        or summary.get("startup_velocity_ramp_enabled") is not item.startup_ramp_applied
        or summary.get("startup_ramp_id")
        != (design.STARTUP_RAMP_ID if item.startup_ramp_applied else design.NO_RAMP_ID)
        or summary.get("startup_transform_receipt_step_count") != design.CONTROLLER_STEPS
    ):
        failures.append("R23D44_STARTUP_TRANSFORM_REPORT_INTEGRITY")
    if failures:
        evaluation["execution_valid"] = False
        evaluation["common_physical_gate_passed"] = False
        evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + failures
    return evaluation, rows


def _measurement_for_candidate(
    item_cells: Sequence[design.Cell], rows_by_cell: Mapping[str, list[dict[str, Any]]]
) -> dict[str, Any]:
    return inherited.measure_cycle_integrated_response(
        {
            item.arm_id: inherited._measurement_rows(rows_by_cell[item.cell_id])
            for item in item_cells
        }
    )


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path | None = None,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D44EvaluationError("R23D44_SOURCE_COMMIT_INVALID")
    authority_root = (
        REPO_ROOT if authority_repo_root is None else authority_repo_root.resolve()
    )
    if not (authority_root / ".git").exists():
        raise R23D44EvaluationError("R23D44_AUTHORITY_REPO_ROOT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D44EvaluationError("R23D44_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, expected, strict=True):
        evaluation, rows = evaluate_entry(
            entry,
            item,
            expected_source_commit=expected_source_commit,
            authority_repo_root=authority_root,
        )
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows
    candidate_results: dict[str, Any] = {}
    for candidate_id in design.CANDIDATE_IDS:
        candidate_cells = [item for item in expected if item.candidate_id == candidate_id]
        candidate_evaluations = [
            item for item in evaluations if item["candidate_id"] == candidate_id
        ]
        execution_valid = all(item["execution_valid"] for item in candidate_evaluations)
        physical_passed = all(
            item["common_physical_gate_passed"] for item in candidate_evaluations
        )
        measurement: dict[str, Any] | None = None
        measurement_failures: list[str] = []
        if execution_valid:
            measurement = _measurement_for_candidate(candidate_cells, rows_by_cell)
            measurement_failures = [
                gate for gate, passed in measurement["gates"].items() if not passed
            ]
        passed = (
            execution_valid
            and physical_passed
            and bool(measurement and measurement.get("passed") is True)
        )
        candidate_results[candidate_id] = {
            "startup_velocity_ramp_enabled": candidate_cells[0].startup_ramp_applied,
            "all_cells_execution_valid": execution_valid,
            "all_common_physical_gates_passed": physical_passed,
            "cycle_integrated_measurement": measurement,
            "measurement_failure_codes": measurement_failures,
            "passed_full_three_arm_gate": passed,
        }
    all_execution_valid = all(
        result["all_cells_execution_valid"] for result in candidate_results.values()
    )
    no_ramp_passed = candidate_results[design.NO_RAMP_CANDIDATE_ID][
        "passed_full_three_arm_gate"
    ]
    ramp_passed = candidate_results[design.RAMP_CANDIDATE_ID][
        "passed_full_three_arm_gate"
    ]
    if not all_execution_valid:
        classification = "invalid_or_incomplete_paired_startup_transform_development"
    elif no_ramp_passed and not ramp_passed:
        classification = "valid_complete_ramp_induced_turning_gate_regression_at_seed_21504"
    elif ramp_passed and not no_ramp_passed:
        classification = "valid_complete_ramp_induced_turning_gate_improvement_at_seed_21504"
    elif no_ramp_passed and ramp_passed:
        classification = "valid_complete_both_startup_transforms_pass_at_seed_21504"
    else:
        classification = "valid_complete_both_startup_transforms_fail_at_seed_21504"
    contrasts: dict[str, float] | None = None
    if all_execution_valid:
        no_ramp_measurement = candidate_results[design.NO_RAMP_CANDIDATE_ID][
            "cycle_integrated_measurement"
        ]
        ramp_measurement = candidate_results[design.RAMP_CANDIDATE_ID][
            "cycle_integrated_measurement"
        ]
        fields = (
            "positive_reference_conditioned_cycle_shift_rad",
            "negative_reference_conditioned_cycle_shift_rad",
            "bilateral_reference_conditioned_cycle_separation_rad",
        )
        contrasts = {
            f"ramp_minus_no_ramp_{field}": float(ramp_measurement[field])
            - float(no_ramp_measurement[field])
            for field in fields
        }
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["paired_same_seed_startup_transform_effect_characterized"] = all_execution_valid
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "candidate_results": candidate_results,
        "paired_continuous_contrasts": contrasts,
        "all_cells_execution_valid": all_execution_valid,
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "outcome_exposed_seed_consumed": True,
        "fresh_or_held_out_condition_consumed": False,
        "causal_scope": "exact_deterministic_seed_21504_only",
        "candidate_selection_invoked": False,
        "cross_engine_equivalence_test_invoked": False,
        "claims": claims,
    }


def _synthetic_row(item: design.Cell, step: int) -> dict[str, Any]:
    row = _BASE_SYNTHETIC_ROW(item, step)
    scale = design.startup_velocity_scale(step) if item.startup_ramp_applied else 1.0
    row.update(
        startup_ramp_id=(
            design.STARTUP_RAMP_ID if item.startup_ramp_applied else design.NO_RAMP_ID
        ),
        startup_velocity_scale=scale,
        startup_ramp_active=item.startup_ramp_applied and scale < 1.0,
        startup_ramp_residual_count=design.ACTUATOR_COUNT,
        startup_ramp_maximum_absolute_residual_rad_s=0.0,
    )
    return row


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    rows_by_cell = {
        item.cell_id: [_synthetic_row(item, step) for step in range(design.CONTROLLER_STEPS)]
        for item in design.cells()
    }
    validations = [
        validate_trace(item.cell_id, rows_by_cell[item.cell_id]) for item in design.cells()
    ]
    measurements = {
        candidate_id: _measurement_for_candidate(
            [item for item in design.cells() if item.candidate_id == candidate_id],
            rows_by_cell,
        )
        for candidate_id in design.CANDIDATE_IDS
    }
    ramp_item = next(item for item in design.cells() if item.startup_ramp_applied)
    no_ramp_item = next(item for item in design.cells() if not item.startup_ramp_applied)
    wrong_ramp = copy.deepcopy(rows_by_cell[ramp_item.cell_id])
    wrong_ramp[0]["startup_ramp_id"] = design.NO_RAMP_ID
    wrong_identity = copy.deepcopy(rows_by_cell[no_ramp_item.cell_id])
    wrong_identity[0]["startup_velocity_scale"] = 0.0
    wrong_segment = copy.deepcopy(rows_by_cell[no_ramp_item.cell_id])
    wrong_segment[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
    rejected = [
        validate_trace(ramp_item.cell_id, wrong_ramp),
        validate_trace(no_ramp_item.cell_id, wrong_identity),
        validate_trace(no_ramp_item.cell_id, wrong_segment),
    ]
    ordinary = DECLARATION_PATH
    alternate = _alternate_windows_spelling(ordinary)
    if (
        not all(item.get("ok") is True for item in validations)
        or not all(item.get("passed") is True for item in measurements.values())
        or not all(item.get("ok") is False for item in rejected)
        or not _same_existing_path(ordinary, alternate)
        or _same_existing_path(ordinary, PUBLISHER_PATH)
    ):
        raise R23D44EvaluationError("R23D44_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d44_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "valid_trace_canary_count": len(validations),
        "cycle_integrated_positive_canary_count": len(measurements),
        "trace_mutation_rejection_count": len(rejected),
        "same_file_path_spelling_positive_control_count": 1,
        "wrong_file_path_rejection_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def run_production_retention_preflight(
    *, source_root: Path, repo_root: Path, attempt_root: Path, powershell: str
) -> dict[str, Any]:
    load_declaration()
    attempt_root = attempt_root.resolve()
    attempt_root.mkdir(parents=True, exist_ok=False)
    pending = attempt_root / "pending-traces"
    pending.mkdir()
    receipts: list[dict[str, Any]] = []
    for candidate_id in design.CANDIDATE_IDS:
        item = design.cell(
            design.STAGE_ID, "rapier_parry", "reference_zero", candidate_id
        )
        rows = [_synthetic_row(item, step) for step in range(design.CONTROLLER_STEPS)]
        rows_path = pending / f"{candidate_id}.rows.json"
        with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(rows, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
        receipts.append(
            retain_trace(
                stage_id=design.STAGE_ID,
                cell_id=item.cell_id,
                rows_json_path=rows_path,
                source_root=source_root,
                repo_root=repo_root,
                attempt_root=attempt_root,
                powershell=powershell,
            )
        )
    path_positive_count = 0
    for receipt in receipts:
        artifact = receipt["trace_artifact"]
        if _cas_binding_failures(artifact, authority_repo_root=repo_root.resolve()):
            raise R23D44EvaluationError("R23D44_PRODUCTION_CAS_BINDING_INVALID")
        alternate = copy.deepcopy(artifact)
        alternate["payload_path"] = str(
            _alternate_windows_spelling(Path(str(artifact["payload_path"])))
        )
        alternate["manifest_path"] = str(
            _alternate_windows_spelling(Path(str(artifact["manifest_path"])))
        )
        if _cas_binding_failures(alternate, authority_repo_root=repo_root.resolve()):
            raise R23D44EvaluationError("R23D44_ALTERNATE_PATH_SPELLING_REJECTED")
        path_positive_count += 1
    wrong = copy.deepcopy(receipts[0]["trace_artifact"])
    wrong["payload_path"] = str(DECLARATION_PATH)
    wrong_rejected = bool(
        _cas_binding_failures(wrong, authority_repo_root=repo_root.resolve())
    )
    if (
        len(receipts) != len(design.CANDIDATE_IDS)
        or any(receipt["trace_artifact"]["test_only"] is not False for receipt in receipts)
        or any(receipt["world_attempt_count"] != 0 for receipt in receipts)
        or any(receipt["world_build_count"] != 0 for receipt in receipts)
        or not wrong_rejected
    ):
        raise R23D44EvaluationError("R23D44_PRODUCTION_RETENTION_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d44_production_retention_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "trace_retentions": receipts,
        "exact_production_cas_path_exercised": True,
        "complete_cas_binding_verifier_exercised": True,
        "ordinary_and_windows_extended_path_spelling_positive_control_count": path_positive_count,
        "wrong_existing_file_rejection_count": 1,
        "synthetic_trace_count": len(receipts),
        "synthetic_trace_row_count": len(receipts) * design.CONTROLLER_STEPS,
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
    production = commands.add_parser("production-retention-preflight")
    for command in (retain, production):
        command.add_argument("--source-root", type=Path, required=True)
        command.add_argument("--repo-root", type=Path, required=True)
        command.add_argument("--attempt-root", type=Path, required=True)
        command.add_argument("--powershell", required=True)
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--source-commit", required=True)
    evaluate.add_argument("--repo-root", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D44_EVALUATOR_PREFLIGHT "
        elif args.command == "retain-trace":
            value = retain_trace(
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
            marker = "QSDK_R23D44_TRACE_RETENTION "
        elif args.command == "production-retention-preflight":
            value = run_production_retention_preflight(
                source_root=args.source_root,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
            )
            marker = "QSDK_R23D44_PRODUCTION_RETENTION_PREFLIGHT "
        else:
            paths = json.loads(args.manifest.read_text(encoding="utf-8"))
            if not isinstance(paths, list) or not all(
                isinstance(path, str) and path for path in paths
            ):
                raise R23D44EvaluationError("R23D44_TERMINAL_MANIFEST_INVALID")
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8")) for path in paths
            ]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D44_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D44EvaluationError,
        inherited.R23D34EvaluationError,
        inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            f"QSDK_R23D44_EVALUATOR_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
