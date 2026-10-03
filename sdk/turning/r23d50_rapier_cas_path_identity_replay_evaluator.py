"""R23D50 exact Rapier replay with filesystem-identity CAS verification."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping, Sequence

import r23d49_rapier_retention_repair_replay_evaluator as predecessor
import r23d50_rapier_cas_path_identity_replay as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = ROOT / "r23d50_rapier_cas_path_identity_replay_preregistration_v1.json"
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d50_trace.ps1"
REPORT_SCHEMA = "sporespore_qsdk_r23d50_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d50_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d50_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d50_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d50_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "finite_outcome_exposed_rapier_cas_path_identity_replay": False,
    "fresh_rapier_turning_replication": False,
    "portable_basic_turning": False,
    "finite_three_engine_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D50EvaluationError(RuntimeError):
    """The replay declaration, retained evidence, or result is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def _same_existing_file(left: Path, right: Path) -> bool:
    """Compare existing filesystem identity, not Windows path spelling."""

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
        raise R23D50EvaluationError(
            f"R23D50_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    lineage = value.get("immutable_lineage", {})
    repair = value.get("implementation_repair_boundary", {})
    candidate = value.get("candidate", {})
    matrix = value.get("frozen_matrix", {})
    measurement = value.get("cycle_integrated_measurement", {})
    physical = value.get("frozen_common_physical_gates", {})
    retention = value.get("production_trace_retention_gate", {})
    evidence = value.get("evidence", {})
    claims = value.get("claims", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d50_rapier_cas_path_identity_replay_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("release_gate_id") != design.RELEASE_GATE_ID
        or value.get("study_classification")
        != "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay"
        or lineage.get("r23d49_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d49_rapier_retention_repair_replay_closure_v1.json")
        or lineage.get("r23d49_identity_consumed") is not True
        or lineage.get("r23d49_same_identity_rerun_permitted") is not False
        or lineage.get("r23d49_rapier_worlds_completed_and_traces_retained") is not True
        or lineage.get("r23d49_outcomes_exposed_before_this_preregistration") is not True
        or lineage.get("r23d49_postfailure_diagnostic_reinterpreted_as_official")
        is not False
        or lineage.get("historical_world_reused_as_a_new_cell") is not False
        or lineage.get("same_identity_rerun_permitted") is not False
        or repair.get("single_permitted_change")
        != "Compare each existing CAS payload and manifest path with os.path.samefile instead of textual Path equality."
        or repair.get("complete_cas_binding_verifier_required_before_first_world")
        is not True
        or repair.get(
            "ordinary_and_windows_extended_same_file_positive_control_required"
        )
        is not True
        or repair.get("wrong_existing_file_negative_control_required") is not True
        or repair.get(
            "exact_rust_to_python_to_powershell_to_cas_canary_required_before_first_world"
        )
        is not True
        or repair.get("synthetic_trace_row_count") != design.CONTROLLER_STEPS
        or repair.get("controller_behavior_changed") is not False
        or repair.get("physics_or_adapter_actuation_changed") is not False
        or repair.get("startup_transform_changed") is not False
        or repair.get("fixture_or_seed_changed") is not False
        or repair.get("command_schedule_changed") is not False
        or repair.get("measurement_changed") is not False
        or repair.get("physical_threshold_changed") is not False
        or repair.get("other_implementation_changes_permitted") is not False
        or candidate.get("candidate_id") != design.CANDIDATE_ID
        or candidate.get("controller_policy_id") != design.POLICY_ID
        or candidate.get("minimum_steering_fraction") != 0.2
        or candidate.get("maximum_steering_fraction") != 0.28
        or candidate.get("steering_guard_floor_hold_steps") != 144
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.ENGINE_IDS)
        or matrix.get("ordered_candidate_ids") != [design.CANDIDATE_ID]
        or matrix.get("ordered_arm_ids") != list(design.ARM_OFFSETS)
        or matrix.get("ordered_heading_offsets_rad")
        != list(design.ARM_OFFSETS.values())
        or matrix.get("declared_cell_count") != len(design.cells())
        or matrix.get("declared_world_count") != len(design.cells())
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("seed_was_outcome_exposed_before_preregistration") is not True
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("recovery_duration_steps") != design.RECOVERY_DURATION_STEPS
        or matrix.get("startup_transform_id") != design.STARTUP_TRANSFORM_ID
        or matrix.get("startup_probe_step_count")
        != design.PROBE_LAST_SEMANTIC_STEP + 1
        or matrix.get("conditional_ramp_step_count_if_triggered")
        != design.STARTUP_RAMP_STEPS
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad") != 0.01
        or measurement.get("both_signed_arms_required") is not True
        or measurement.get("reference_arm_required") is not True
        or measurement.get("threshold_changed_from_r23d49") is not False
        or physical.get("minimum_final_forward_displacement_m") != 0.030123046875
        or physical.get("maximum_tilt_rad") != 0.6
        or physical.get("minimum_torso_height_m") != 0.2499708652072946
        or physical.get("minimum_contact_cycles_per_limb") != 2
        or physical.get("exact_startup_transform_composition_required") is not True
        or physical.get("terminal_quiescent_taper_required") is not False
        or retention.get("required_before_first_world") is not True
        or retention.get("model_construction_count") != 0
        or retention.get("world_build_count") != 0
        or retention.get("synthetic_trace_row_count") != design.CONTROLLER_STEPS
        or retention.get(
            "exact_rust_to_python_to_powershell_to_artifact_store_route_required"
        )
        is not True
        or retention.get("process_scoped_execution_policy_bypass_required") is not True
        or retention.get("complete_cas_binding_verifier_exercised_required") is not True
        or retention.get("ordinary_and_windows_extended_path_positive_control_count")
        != 1
        or retention.get("wrong_existing_file_rejection_count") != 1
        or evidence.get("clean_pushed_live_source_required") is not True
        or evidence.get("campaign_local_lca1_qualification_required") is not True
        or evidence.get("positive_production_authorization_preflight_required_per_cell")
        is not True
        or evidence.get("authorization_preflight_must_return_before_model_or_world")
        is not True
        or evidence.get("same_identity_rerun_allowed") is not False
        or claims.get("finite_outcome_exposed_rapier_cas_path_identity_replay")
        is not False
        or claims.get("fresh_rapier_turning_replication") is not False
        or claims.get("finite_three_engine_turning") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("release_authorized") is not False
    )
    if invalid:
        raise R23D50EvaluationError("R23D50_DECLARATION_IDENTITY_INVALID")
    return value


def _cas_binding_failures(
    entry: Mapping[str, Any], *, authority_repo_root: Path | None = None
) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D50_TRACE_ARTIFACT_RECEIPT"]
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D50_TRACE_ARTIFACT_IDENTITY"]
    authority_root = (
        predecessor.parent.REPO_ROOT
        if authority_repo_root is None
        else authority_repo_root.resolve()
    )
    directory = (
        authority_root.parent
        / "SporeSpore_Evidence"
        / "artifacts"
        / "sha256"
        / digest_hex
    )
    payload = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    recorded_payload = Path(str(artifact.get("payload_path", "")))
    recorded_manifest = Path(str(artifact.get("manifest_path", "")))
    if not _same_existing_file(recorded_payload, payload) or not _same_existing_file(
        recorded_manifest, manifest_path
    ):
        return ["R23D50_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D50_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
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
        return ["R23D50_TRACE_ARTIFACT_BYTES"]
    return []


# Rebind the frozen R49/R48 evaluation stack to the new immutable identity.
predecessor.design = design
predecessor.DECLARATION_PATH = DECLARATION_PATH
predecessor.PUBLISHER_PATH = PUBLISHER_PATH
predecessor.REPORT_SCHEMA = REPORT_SCHEMA
predecessor.FAILURE_SCHEMA = FAILURE_SCHEMA
predecessor.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
predecessor.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
predecessor.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
predecessor.FALSE_CLAIMS = FALSE_CLAIMS
predecessor.load_declaration = load_declaration
predecessor.parent.design = design
predecessor.parent.DECLARATION_PATH = DECLARATION_PATH
predecessor.parent.REPORT_SCHEMA = REPORT_SCHEMA
predecessor.parent.FAILURE_SCHEMA = FAILURE_SCHEMA
predecessor.parent.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
predecessor.parent.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
predecessor.parent.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
predecessor.parent.FALSE_CLAIMS = FALSE_CLAIMS
predecessor.parent.load_declaration = load_declaration
predecessor.parent._cas_binding_failures = _cas_binding_failures
predecessor.parent.inherited.design = design
predecessor.parent.inherited.DECLARATION_PATH = DECLARATION_PATH
predecessor.parent.inherited.PUBLISHER_PATH = PUBLISHER_PATH
predecessor.parent.inherited.PUBLISHER_MARKER = "QSDK_R23D50_TRACE_CAS "
predecessor.parent.inherited.REPORT_SCHEMA = REPORT_SCHEMA
predecessor.parent.inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
predecessor.parent.inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
predecessor.parent.inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
predecessor.parent.inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
predecessor.parent.inherited.FALSE_CLAIMS = FALSE_CLAIMS
predecessor.parent.inherited.load_declaration = load_declaration


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    return predecessor.parent.validate_trace(cell_id, rows)


predecessor.validate_trace = validate_trace
predecessor.parent.inherited.validate_trace = validate_trace


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
    if stage_id != design.STAGE_ID or cell_id not in {
        item.cell_id for item in design.cells()
    }:
        raise R23D50EvaluationError("R23D50_RETENTION_IDENTITY_INVALID")
    source_root = source_root.resolve()
    authority_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    if not _same_existing_file(source_root, REPO_ROOT):
        raise R23D50EvaluationError("R23D50_SOURCE_ROOT_INVALID")
    if not (authority_root / ".git").exists():
        raise R23D50EvaluationError("R23D50_AUTHORITY_REPO_ROOT_INVALID")
    production_root = authority_root.parent / "SporeSpore_Evidence"
    allowed_root = (
        evidence_root_override.resolve()
        if test_only and evidence_root_override is not None
        else production_root.resolve()
    )
    if not attempt_root.is_dir() or not _within(attempt_root, allowed_root):
        raise R23D50EvaluationError("R23D50_ATTEMPT_ROOT_INVALID")
    if test_only != (evidence_root_override is not None):
        raise R23D50EvaluationError("R23D50_TEST_ROOT_MODE_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D50EvaluationError(
            f"R23D50_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    if summary.get("ok") is not True:
        raise R23D50EvaluationError(
            "R23D50_TRACE_INVALID:"
            + ",".join(str(code) for code in summary.get("failure_codes", [])[:8])
        )
    canonical = predecessor.parent.inherited._canonical_ndjson(rows)
    if (
        summary.get("raw_sha256")
        != "sha256:" + hashlib.sha256(canonical).hexdigest()
        or summary.get("byte_length") != len(canonical)
    ):
        raise R23D50EvaluationError("R23D50_TRACE_CANONICAL_RECEIPT_MISMATCH")
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    output = trace_root / f"{cell_id}.ndjson"
    try:
        with output.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D50EvaluationError("R23D50_TRACE_OUTPUT_EXISTS") from error
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
    prefix = "QSDK_R23D50_TRACE_CAS "
    markers = [
        line[len(prefix) :]
        for line in process.stdout.splitlines()
        if line.startswith(prefix)
    ]
    if process.returncode != 0 or len(markers) != 1:
        raise R23D50EvaluationError(
            "R23D50_TRACE_CAS_FAILED:"
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
        raise R23D50EvaluationError("R23D50_TRACE_CAS_RECEIPT_INVALID")
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "stage_id": stage_id,
        "cell_id": cell_id,
        "trace_artifact": artifact,
        "trace_summary": summary,
        "retained_before_terminal_entry": True,
        "process_scoped_execution_policy": "Bypass",
        "pinned_publisher_source_invoked": True,
        "expected_digest_and_byte_length_verified": True,
        "failed_child_stdout_and_stderr_bounded": True,
        "publisher_maximum_attempt_count": 3,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


predecessor.retain_trace = retain_trace


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D50EvaluationError("R23D50_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    if not (authority_root / ".git").exists():
        raise R23D50EvaluationError("R23D50_AUTHORITY_REPO_ROOT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D50EvaluationError("R23D50_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_arm: dict[str, list[dict[str, Any]]] = {}
    r48_root = predecessor.parent.REPO_ROOT
    r34_root = predecessor.parent.inherited.REPO_ROOT
    try:
        predecessor.parent.REPO_ROOT = authority_root
        predecessor.parent.inherited.REPO_ROOT = authority_root
        for entry, item in zip(entries, expected, strict=True):
            evaluation, rows = predecessor.parent.evaluate_entry(
                entry, item, expected_source_commit=expected_source_commit
            )
            evaluations.append(evaluation)
            rows_by_arm[item.arm_id] = predecessor.parent.inherited._measurement_rows(rows)
    finally:
        predecessor.parent.REPO_ROOT = r48_root
        predecessor.parent.inherited.REPO_ROOT = r34_root
    all_execution_valid = all(
        evaluation.get("execution_valid") is True for evaluation in evaluations
    )
    all_physical_passed = all(
        evaluation.get("common_physical_gate_passed") is True
        for evaluation in evaluations
    )
    measurement: dict[str, Any] | None = None
    measurement_failures: list[str] = []
    if all_execution_valid:
        measurement = predecessor.parent.inherited.measure_cycle_integrated_response(
            rows_by_arm
        )
        measurement_failures = [
            gate for gate, passed in measurement["gates"].items() if not passed
        ]
    measurement_passed = bool(measurement and measurement.get("passed") is True)
    positive = all_execution_valid and all_physical_passed and measurement_passed
    classification = (
        "valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay"
        if positive
        else "invalid_or_incomplete_outcome_exposed_rapier_cas_path_identity_replay"
        if not all_execution_valid
        else "valid_complete_negative_outcome_exposed_rapier_cas_path_identity_replay"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["finite_outcome_exposed_rapier_cas_path_identity_replay"] = positive
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "all_cells_execution_valid": all_execution_valid,
        "all_common_physical_gates_passed": all_physical_passed,
        "cycle_integrated_measurement": measurement,
        "measurement_failure_codes": measurement_failures,
        "turning_measurement_passed": measurement_passed,
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "outcome_exposed_replay": True,
        "fresh_held_out_condition_consumed": False,
        "startup_transform_id": design.STARTUP_TRANSFORM_ID,
        "terminal_restoration_or_taper_invoked": False,
        "cross_engine_equivalence_test_invoked": False,
        "claims": claims,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    traces = {
        item.cell_id: predecessor.parent._synthetic_rows(item, trigger=False)
        for item in design.cells()
    }
    validations = [
        validate_trace(item.cell_id, traces[item.cell_id]) for item in design.cells()
    ]
    measurement = predecessor.parent.inherited.measure_cycle_integrated_response(
        {
            item.arm_id: predecessor.parent.inherited._measurement_rows(
                traces[item.cell_id]
            )
            for item in design.cells()
        }
    )
    first = design.cells()[0]
    mutated_segment = copy.deepcopy(traces[first.cell_id])
    mutated_segment[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
    rejected_segment = validate_trace(first.cell_id, mutated_segment)
    mutated_scale = copy.deepcopy(traces[first.cell_id])
    mutated_scale[1]["startup_velocity_scale"] = 0.5
    rejected_scale = validate_trace(first.cell_id, mutated_scale)
    alternate = _alternate_windows_spelling(DECLARATION_PATH)
    same_file_alias_accepted = _same_existing_file(DECLARATION_PATH, alternate)
    wrong_existing_file_rejected = not _same_existing_file(
        DECLARATION_PATH,
        ROOT / "r23d50_rapier_cas_path_identity_replay_implementation_v1.json",
    )
    if (
        not all(validation.get("ok") is True for validation in validations)
        or measurement.get("passed") is not True
        or rejected_segment.get("ok") is not False
        or rejected_scale.get("ok") is not False
        or not same_file_alias_accepted
        or not wrong_existing_file_rejected
        or predecessor.parent._cas_binding_failures is not _cas_binding_failures
    ):
        raise R23D50EvaluationError("R23D50_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d50_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "valid_trace_canary_count": len(validations),
        "cycle_integrated_positive_canary_count": 1,
        "trace_mutation_rejection_count": 2,
        "same_file_path_spelling_positive_control_count": 1,
        "wrong_file_path_rejection_count": 1,
        "production_cas_binding_override_wired": True,
        "process_scoped_execution_policy_bypass_wiring_present": True,
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
    item = design.cells()[0]
    rows = predecessor.parent._synthetic_rows(item, trigger=False)
    rows_path = pending / "production-canary.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(rows, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
    receipt = retain_trace(
        stage_id=design.STAGE_ID,
        cell_id=item.cell_id,
        rows_json_path=rows_path,
        source_root=source_root,
        repo_root=repo_root,
        attempt_root=attempt_root,
        powershell=powershell,
    )
    entry = {"trace_artifact": receipt["trace_artifact"]}
    authority_root = repo_root.resolve()
    if _cas_binding_failures(entry, authority_repo_root=authority_root):
        raise R23D50EvaluationError("R23D50_PRODUCTION_CAS_BINDING_INVALID")
    alternate_entry = copy.deepcopy(entry)
    alternate_artifact = alternate_entry["trace_artifact"]
    alternate_artifact["payload_path"] = str(
        _alternate_windows_spelling(Path(str(alternate_artifact["payload_path"])))
    )
    alternate_artifact["manifest_path"] = str(
        _alternate_windows_spelling(Path(str(alternate_artifact["manifest_path"])))
    )
    if _cas_binding_failures(
        alternate_entry, authority_repo_root=authority_root
    ):
        raise R23D50EvaluationError("R23D50_ALTERNATE_PATH_SPELLING_REJECTED")
    wrong_entry = copy.deepcopy(entry)
    wrong_entry["trace_artifact"]["payload_path"] = str(DECLARATION_PATH)
    wrong_failures = _cas_binding_failures(
        wrong_entry, authority_repo_root=authority_root
    )
    if wrong_failures != ["R23D50_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]:
        raise R23D50EvaluationError("R23D50_WRONG_EXISTING_FILE_ACCEPTED")
    if (
        receipt["trace_summary"]["row_count"] != design.CONTROLLER_STEPS
        or receipt["trace_artifact"]["test_only"] is not False
        or receipt["process_scoped_execution_policy"] != "Bypass"
        or receipt["world_attempt_count"] != 0
        or receipt["world_build_count"] != 0
    ):
        raise R23D50EvaluationError("R23D50_PRODUCTION_RETENTION_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d50_production_retention_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "trace_retention": receipt,
        "exact_production_cas_path_exercised": True,
        "exact_python_to_powershell_to_artifact_store_route_exercised": True,
        "process_scoped_execution_policy_bypass_exercised": True,
        "complete_cas_binding_verifier_exercised": True,
        "ordinary_and_windows_extended_path_spelling_positive_control_count": 1,
        "wrong_existing_file_rejection_count": 1,
        "synthetic_trace_row_count": design.CONTROLLER_STEPS,
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
            marker = "QSDK_R23D50_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D50_TRACE_RETENTION "
        elif args.command == "production-retention-preflight":
            value = run_production_retention_preflight(
                source_root=args.source_root,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
            )
            marker = "QSDK_R23D50_PRODUCTION_RETENTION_PREFLIGHT "
        else:
            paths = json.loads(args.manifest.read_text(encoding="utf-8"))
            if not isinstance(paths, list) or not all(
                isinstance(path, str) and path for path in paths
            ):
                raise R23D50EvaluationError("R23D50_TERMINAL_MANIFEST_INVALID")
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8")) for path in paths
            ]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D50_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D50EvaluationError,
        predecessor.R23D49EvaluationError,
        predecessor.parent.R23D48EvaluationError,
        predecessor.parent.inherited.R23D34EvaluationError,
        predecessor.parent.inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            f"QSDK_R23D50_EVALUATOR_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
