"""R23D49 exact Rapier replay and repaired production trace retention."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence

import r23d48_support_loss_conditioned_three_engine_turning_evaluator as parent
import r23d49_rapier_retention_repair_replay as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = ROOT / "r23d49_rapier_retention_repair_replay_preregistration_v1.json"
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d49_trace.ps1"
REPORT_SCHEMA = "sporespore_qsdk_r23d49_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d49_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d49_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d49_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d49_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "finite_outcome_exposed_rapier_retention_repair_replay": False,
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


class R23D49EvaluationError(RuntimeError):
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
    except ValueError:
        return False


def _same_path(left: Path, right: Path) -> bool:
    try:
        return os.path.samefile(left.resolve(), right.resolve())
    except OSError:
        return False


def _excerpt(value: str, maximum: int = 2_000) -> str:
    return value.replace("\x00", "\\0")[-maximum:]


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D49EvaluationError(
            f"R23D49_DECLARATION_UNREADABLE:{type(error).__name__}"
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
        != "sporespore_qsdk_r23d49_rapier_retention_repair_replay_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("release_gate_id") != design.RELEASE_GATE_ID
        or value.get("study_classification")
        != "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay"
        or lineage.get("r23d48_closure_raw_sha256")
        != raw_sha256(
            ROOT
            / "r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
        )
        or lineage.get("r23d48_identity_consumed") is not True
        or lineage.get("r23d48_same_identity_rerun_permitted") is not False
        or lineage.get("r23d48_rapier_worlds_completed_before_publication_failure")
        is not True
        or lineage.get("r23d48_rapier_outcomes_exposed_before_this_preregistration")
        is not True
        or lineage.get("historical_world_reused_as_a_new_cell") is not False
        or lineage.get("same_identity_rerun_permitted") is not False
        or repair.get("single_permitted_change")
        != "Invoke the exact pinned publisher with -ExecutionPolicy Bypass in that child process only."
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
        or matrix.get("startup_probe_step_count") != design.PROBE_LAST_SEMANTIC_STEP + 1
        or matrix.get("conditional_ramp_step_count_if_triggered")
        != design.STARTUP_RAMP_STEPS
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad")
        != 0.01
        or measurement.get("both_signed_arms_required") is not True
        or measurement.get("reference_arm_required") is not True
        or measurement.get("threshold_changed_from_r23d48") is not False
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
        or retention.get("pinned_publisher_source_required") is not True
        or retention.get("expected_digest_and_byte_length_verification_required")
        is not True
        or retention.get("production_evidence_root_required") is not True
        or retention.get("test_only_artifact_forbidden") is not True
        or retention.get("publisher_maximum_attempt_count") != 3
        or evidence.get("clean_pushed_live_source_required") is not True
        or evidence.get("campaign_local_lca1_qualification_required") is not True
        or evidence.get("positive_production_authorization_preflight_required_per_cell")
        is not True
        or evidence.get("authorization_preflight_must_return_before_model_or_world")
        is not True
        or evidence.get("same_identity_rerun_allowed") is not False
        or claims.get("finite_outcome_exposed_rapier_retention_repair_replay")
        is not False
        or claims.get("fresh_rapier_turning_replication") is not False
        or claims.get("finite_three_engine_turning") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("release_authorized") is not False
    )
    if invalid:
        raise R23D49EvaluationError("R23D49_DECLARATION_IDENTITY_INVALID")
    return value


# Rebind the already frozen R48 row semantics and physical evaluator to the
# R49 identity. The only replacement below is trace publication transport.
parent.design = design
parent.DECLARATION_PATH = DECLARATION_PATH
parent.REPORT_SCHEMA = REPORT_SCHEMA
parent.FAILURE_SCHEMA = FAILURE_SCHEMA
parent.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
parent.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
parent.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
parent.FALSE_CLAIMS = FALSE_CLAIMS
parent.load_declaration = load_declaration
parent.inherited.design = design
parent.inherited.DECLARATION_PATH = DECLARATION_PATH
parent.inherited.PUBLISHER_PATH = PUBLISHER_PATH
parent.inherited.PUBLISHER_MARKER = "QSDK_R23D49_TRACE_CAS "
parent.inherited.REPORT_SCHEMA = REPORT_SCHEMA
parent.inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
parent.inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
parent.inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
parent.inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
parent.inherited.FALSE_CLAIMS = FALSE_CLAIMS
parent.inherited.load_declaration = load_declaration


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    return parent.validate_trace(cell_id, rows)


parent.inherited.validate_trace = validate_trace


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
        raise R23D49EvaluationError("R23D49_RETENTION_IDENTITY_INVALID")
    source_root = source_root.resolve()
    authority_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    if not _same_path(source_root, REPO_ROOT):
        raise R23D49EvaluationError("R23D49_SOURCE_ROOT_INVALID")
    if not (authority_root / ".git").exists():
        raise R23D49EvaluationError("R23D49_AUTHORITY_REPO_ROOT_INVALID")
    production_root = authority_root.parent / "SporeSpore_Evidence"
    allowed_root = (
        evidence_root_override.resolve()
        if test_only and evidence_root_override is not None
        else production_root.resolve()
    )
    if not attempt_root.is_dir() or not _within(attempt_root, allowed_root):
        raise R23D49EvaluationError("R23D49_ATTEMPT_ROOT_INVALID")
    if test_only != (evidence_root_override is not None):
        raise R23D49EvaluationError("R23D49_TEST_ROOT_MODE_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D49EvaluationError(
            f"R23D49_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    if summary.get("ok") is not True:
        raise R23D49EvaluationError(
            "R23D49_TRACE_INVALID:"
            + ",".join(str(code) for code in summary.get("failure_codes", [])[:8])
        )
    canonical = parent.inherited._canonical_ndjson(rows)
    if (
        summary.get("raw_sha256")
        != "sha256:" + hashlib.sha256(canonical).hexdigest()
        or summary.get("byte_length") != len(canonical)
    ):
        raise R23D49EvaluationError("R23D49_TRACE_CANONICAL_RECEIPT_MISMATCH")
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    output = trace_root / f"{cell_id}.ndjson"
    try:
        with output.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D49EvaluationError("R23D49_TRACE_OUTPUT_EXISTS") from error
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
    prefix = "QSDK_R23D49_TRACE_CAS "
    markers = [
        line[len(prefix) :]
        for line in process.stdout.splitlines()
        if line.startswith(prefix)
    ]
    if process.returncode != 0 or len(markers) != 1:
        raise R23D49EvaluationError(
            "R23D49_TRACE_CAS_FAILED:"
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
        raise R23D49EvaluationError("R23D49_TRACE_CAS_RECEIPT_INVALID")
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


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D49EvaluationError("R23D49_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    if not (authority_root / ".git").exists():
        raise R23D49EvaluationError("R23D49_AUTHORITY_REPO_ROOT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D49EvaluationError("R23D49_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_arm: dict[str, list[dict[str, Any]]] = {}
    parent_root = parent.REPO_ROOT
    inherited_root = parent.inherited.REPO_ROOT
    try:
        parent.REPO_ROOT = authority_root
        parent.inherited.REPO_ROOT = authority_root
        for entry, item in zip(entries, expected, strict=True):
            evaluation, rows = parent.evaluate_entry(
                entry, item, expected_source_commit=expected_source_commit
            )
            evaluations.append(evaluation)
            rows_by_arm[item.arm_id] = parent.inherited._measurement_rows(rows)
    finally:
        parent.REPO_ROOT = parent_root
        parent.inherited.REPO_ROOT = inherited_root
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
        measurement = parent.inherited.measure_cycle_integrated_response(rows_by_arm)
        measurement_failures = [
            gate for gate, passed in measurement["gates"].items() if not passed
        ]
    measurement_passed = bool(measurement and measurement.get("passed") is True)
    positive = all_execution_valid and all_physical_passed and measurement_passed
    classification = (
        "valid_complete_positive_outcome_exposed_rapier_retention_repair_replay"
        if positive
        else "invalid_or_incomplete_outcome_exposed_rapier_retention_repair_replay"
        if not all_execution_valid
        else "valid_complete_negative_outcome_exposed_rapier_retention_repair_replay"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["finite_outcome_exposed_rapier_retention_repair_replay"] = positive
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
        item.cell_id: parent._synthetic_rows(item, trigger=False)
        for item in design.cells()
    }
    validations = [
        validate_trace(item.cell_id, traces[item.cell_id]) for item in design.cells()
    ]
    measurement = parent.inherited.measure_cycle_integrated_response(
        {
            item.arm_id: parent.inherited._measurement_rows(traces[item.cell_id])
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
    if (
        not all(validation.get("ok") is True for validation in validations)
        or measurement.get("passed") is not True
        or rejected_segment.get("ok") is not False
        or rejected_scale.get("ok") is not False
    ):
        raise R23D49EvaluationError("R23D49_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d49_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "valid_trace_canary_count": len(validations),
        "cycle_integrated_positive_canary_count": 1,
        "trace_mutation_rejection_count": 2,
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
    rows = parent._synthetic_rows(item, trigger=False)
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
    if (
        receipt["trace_summary"]["row_count"] != design.CONTROLLER_STEPS
        or receipt["trace_artifact"]["test_only"] is not False
        or receipt["process_scoped_execution_policy"] != "Bypass"
        or receipt["world_attempt_count"] != 0
        or receipt["world_build_count"] != 0
    ):
        raise R23D49EvaluationError("R23D49_PRODUCTION_RETENTION_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d49_production_retention_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "trace_retention": receipt,
        "exact_production_cas_path_exercised": True,
        "exact_python_to_powershell_to_artifact_store_route_exercised": True,
        "process_scoped_execution_policy_bypass_exercised": True,
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
            marker = "QSDK_R23D49_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D49_TRACE_RETENTION "
        elif args.command == "production-retention-preflight":
            value = run_production_retention_preflight(
                source_root=args.source_root,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
            )
            marker = "QSDK_R23D49_PRODUCTION_RETENTION_PREFLIGHT "
        else:
            paths = json.loads(args.manifest.read_text(encoding="utf-8"))
            if not isinstance(paths, list) or not all(
                isinstance(path, str) and path for path in paths
            ):
                raise R23D49EvaluationError("R23D49_TERMINAL_MANIFEST_INVALID")
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8")) for path in paths
            ]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D49_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D49EvaluationError,
        parent.R23D48EvaluationError,
        parent.inherited.R23D34EvaluationError,
        parent.inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            f"QSDK_R23D49_EVALUATOR_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
