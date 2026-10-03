"""Cold trace retention and direct three-cell evaluation for QSDK-R23D21.

The module constructs no physics model.  It binds the qualified R23D13 cell
report validator to the R23D21 trace and declaration identities, retains every
complete trace in content-addressed storage before a terminal entry can exist,
and evaluates exactly the prospectively declared Godot/Jolt development screen.
R23D21 has no selector and exposes no cross-engine or release decision route.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
from types import ModuleType
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d21_physical_trace as design
import r23d15_physical_evaluator as inherited_evaluator


CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
DECLARATION_PATH = ROOT / "r23d21_reduced_yaw_authority_preregistration_v1.json"
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d21_trace.ps1"

REPORT_SCHEMA = "sporespore_qsdk_r23d21_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d21_worker_failure_v1"
TRACE_ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d21_trace_retention_v1"
CELL_EVALUATION_SCHEMA = "sporespore_qsdk_r23d21_cell_evaluation_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d21_complete_evaluation_v1"

FALSE_CLAIMS = {
    "command_conditioned_turning": False,
    "bilateral_signed_turning": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "q_sdk_r23_satisfied": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D21PhysicalEvaluationError(RuntimeError):
    """A trace, retained artifact, terminal entry, or aggregate is invalid."""


def _load_private_core() -> ModuleType:
    source = ROOT / "r23d13_physical_evaluator.py"
    specification = importlib.util.spec_from_file_location(
        "_sporespore_r23d21_inherited_evaluator_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise R23D21PhysicalEvaluationError(
            "R23D21_INHERITED_EVALUATOR_CORE_UNAVAILABLE"
        )
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_core()
_core.design = design
_core.CAMPAIGN_ID = CAMPAIGN_ID
_core.GATE_ID = GATE_ID
_core.DECLARATION_PATH = DECLARATION_PATH
_core.TRACE_PUBLISHER_PATH = TRACE_PUBLISHER_PATH
_core.REPORT_SCHEMA = REPORT_SCHEMA
_core.FAILURE_SCHEMA = FAILURE_SCHEMA
_core.TRACE_ARTIFACT_SCHEMA = TRACE_ARTIFACT_SCHEMA
_core.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
_core.CELL_EVALUATION_SCHEMA = CELL_EVALUATION_SCHEMA
_core.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
_core.FALSE_CLAIMS = FALSE_CLAIMS

REPORT_FIELDS = _core.REPORT_FIELDS
FAILURE_FIELDS = _core.FAILURE_FIELDS
TRACE_ARTIFACT_FIELDS = _core.TRACE_ARTIFACT_FIELDS
TRACE_SUMMARY_FIELDS = _core.TRACE_SUMMARY_FIELDS
EXECUTION_FIELDS = _core.EXECUTION_FIELDS
MEASUREMENT_FIELDS = _core.MEASUREMENT_FIELDS


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _translate(value: Any) -> Any:
    if isinstance(value, str):
        return value.replace("R23D13", "R23D21").replace("QSDK-R23D13", "QSDK-R23D21")
    if isinstance(value, list):
        return [_translate(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_translate(item) for item in value)
    if isinstance(value, dict):
        return {key: _translate(item) for key, item in value.items()}
    return value


def _load_declaration() -> dict[str, Any]:
    try:
        declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D21PhysicalEvaluationError(
            f"R23D21_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error

    try:
        inherited_projection = inherited_evaluator._load_declaration()
    except Exception as error:
        raise R23D21PhysicalEvaluationError(
            f"R23D21_INHERITED_SCIENTIFIC_CONTRACT_INVALID:{type(error).__name__}"
        ) from error

    lineage = declaration.get("immutable_lineage", {})
    mechanism = declaration.get("retained_mechanism_observation", {})
    successor = declaration.get("scientifically_distinct_successor", {})
    inherited = declaration.get("inherited_physical_contract", {})
    matrix = declaration.get("prospective_screen", {})
    qualification = declaration.get("zero_world_entry_gate", {})
    claims = declaration.get("claims", {})
    invalid = (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d21_reduced_yaw_authority_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("status")
        != "prospectively_frozen_stage_zero_zero_world_only"
        or lineage.get("predecessor_gate_id") != "QSDK-R23D20"
        or lineage.get("predecessor_same_identity_rerun_forbidden") is not True
        or lineage.get("predecessor_closure_raw_sha256")
        != "sha256:6ba59e452cbb6ef5f12bae32ae3c068733717020e9bf29781eba3edd5d751982"
        or mechanism.get("all_three_warmup_trajectories_identical_through_step") != 599
        or mechanism.get("divergence_begins_only_at_commanded_turn_step") != 600
        or mechanism.get("reference_commanded_phase_yaw_sign_crossing_count") != 12
        or mechanism.get("reference_requested_steering_saturation_step_count") != 331
        or successor.get("new_policy_id") != design.CONTROLLER_POLICY_ID
        or successor.get("parent_policy_id")
        != "sporespore_balanced_wave_r23d19_heading_aligned_path_v1"
        or successor.get("only_controller_parameter_change")
        != "yaw_error_stride_gain_per_rad"
        or successor.get("parent_yaw_error_stride_gain_per_rad") != 1.3
        or successor.get("candidate_yaw_error_stride_gain_per_rad") != 1.0
        or successor.get("cross_track_frame_mode_id") != design.CROSS_TRACK_FRAME_MODE_ID
        or any(
            successor.get(field) is not False
            for field in (
                "cross_track_frame_changed",
                "steering_filter_changed",
                "stride_transform_changed",
                "forward_velocity_mechanism_changed",
                "fixture_changed",
                "morphology_changed",
                "actuation_mode_changed",
                "material_profile_changed",
                "threshold_changed",
                "horizon_changed",
                "terminal_policy_changed",
                "engine_specific_gait_logic_permitted",
                "arm_identity_or_outcome_branching_permitted",
            )
        )
        or inherited.get("engine_id") != "godot_jolt"
        or inherited.get("controller_step_count") != design.CONTROLLER_STEPS
        or inherited.get("terminal_step_count") != design.TERMINAL_STEPS
        or inherited.get("total_trace_row_count_per_cell") != design.TOTAL_TRACE_STEPS
        or inherited.get("maximum_active_neutral_acquisition_step_count")
        != design.temporal.MAXIMUM_ACTIVE_STEPS
        or inherited.get("minimum_confirmed_taper_step_count")
        != design.temporal.MINIMUM_TAPER_STEPS
        or inherited.get("minimum_post_handoff_zero_actuation_step_count")
        != design.temporal.MINIMUM_PASSIVE_STEPS
        or inherited.get("tight_maximum_torso_tilt_rad")
        != design.temporal.TIGHT_MAXIMUM_TILT_RAD
        or inherited.get("tight_maximum_joint_position_error_rad")
        != design.temporal.TIGHT_MAXIMUM_JOINT_ERROR_RAD
        or inherited.get("minimum_absolute_signed_turn_phase_yaw_delta_rad") != 0.01
        or inherited.get("minimum_command_conditioned_yaw_separation_rad") != 0.01
        or matrix.get("stage_id") != design.MATRIX_STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.MATRIX_ENGINES)
        or matrix.get("ordered_arm_ids") != list(design.MATRIX_ARMS)
        or matrix.get("declared_cell_count") != len(design.matrix_cells())
        or matrix.get("declared_world_count") != len(design.matrix_cells())
        or matrix.get("serialized_execution_required") is not True
        or matrix.get("all_cells_run_without_outcome_early_stop") is not True
        or matrix.get("selective_replacement_or_rerun_permitted") is not False
        or qualification.get("exact_selected_policy_adapter_start_required") is not True
        or qualification.get("actual_diagnostics_composition_path_required") is not True
        or qualification.get("exact_profile_delta_and_policy_digest_required") is not True
        or qualification.get("worker_failure_terminal_controls_required") is not True
        or qualification.get("clean_pushed_live_source_required_before_physics")
        is not True
        or qualification.get("commissioned_lca1_adoption_required_before_physics")
        is not True
        or qualification.get("content_addressed_retention_required") is not True
        or qualification.get("single_use_attempt_required") is not True
        or qualification.get("physical_execution_authorized") is not False
        or claims.get("finite_godot_command_conditioned_turning") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("release_authorized") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D21PhysicalEvaluationError("R23D21_DECLARATION_IDENTITY_INVALID")

    # The inherited evaluator consumes the exact R23D15 semantic projection;
    # only campaign, stage, trace, report, and failure identities are rebound.
    return inherited_projection


_core._load_declaration = _load_declaration


def cell_for_identity(stage_id: str, cell_id: str) -> design.Cell:
    return design.cell_for_identity(stage_id, cell_id)


def retain_trace(
    *,
    stage_id: str,
    cell_id: str,
    rows_json_path: Path,
    repo_root: Path,
    attempt_root: Path,
    powershell: str,
    test_only: bool,
    evidence_root_override: Path | None,
) -> dict[str, Any]:
    """Validate and content-address a complete trace before terminal entry."""

    _load_declaration()
    cell = cell_for_identity(stage_id, cell_id)
    repo_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    try:
        same_repo_identity = os.path.samefile(repo_root, REPO_ROOT)
    except OSError:
        same_repo_identity = False
    if not same_repo_identity:
        raise R23D21PhysicalEvaluationError("R23D21_REPO_ROOT_INVALID")
    if not attempt_root.exists() or not attempt_root.is_dir():
        raise R23D21PhysicalEvaluationError("R23D21_ATTEMPT_ROOT_MISSING")
    if not test_only:
        production_root = repo_root.parent / "SporeSpore_Evidence"
        if not _core._path_within(attempt_root, production_root):
            raise R23D21PhysicalEvaluationError(
                "R23D21_PRODUCTION_ATTEMPT_ROOT_NOT_DURABLE"
            )
        if evidence_root_override is not None:
            raise R23D21PhysicalEvaluationError(
                "R23D21_PRODUCTION_EVIDENCE_OVERRIDE_FORBIDDEN"
            )
    elif evidence_root_override is None:
        raise R23D21PhysicalEvaluationError("R23D21_TEST_EVIDENCE_ROOT_REQUIRED")

    try:
        rows = _core._read_rows_json(rows_json_path)
    except Exception as error:
        raise R23D21PhysicalEvaluationError(str(_translate(str(error)))) from error
    summary = design.validate_trace(cell, rows)
    if not summary["ok"]:
        raise R23D21PhysicalEvaluationError(
            "R23D21_TRACE_INVALID:" + ",".join(summary["failure_codes"][:8])
        )
    canonical = design.canonical_ndjson(rows)
    digest = "sha256:" + hashlib.sha256(canonical).hexdigest()
    if digest != summary["raw_sha256"] or len(canonical) != summary["byte_length"]:
        raise R23D21PhysicalEvaluationError("R23D21_TRACE_CANONICAL_RECEIPT_MISMATCH")

    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    canonical_path = trace_root / f"{cell.stage_id}__{cell.cell_id}.ndjson"
    try:
        with canonical_path.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D21PhysicalEvaluationError(
            "R23D21_TRACE_STAGING_PATH_EXISTS"
        ) from error
    if _raw_sha256(canonical_path) != digest:
        raise R23D21PhysicalEvaluationError("R23D21_TRACE_WRITE_MISMATCH")

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
        digest,
        "-ExpectedByteLength",
        str(len(canonical)),
    ]
    if test_only:
        command.extend(
            [
                "-TestOnly",
                "-EvidenceRootOverride",
                str(evidence_root_override.resolve()),
            ]
        )
    process = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        check=False,
        text=True,
        timeout=120,
    )
    marker = "QSDK_R23D21_TRACE_CAS "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D21PhysicalEvaluationError(
            "R23D21_TRACE_CAS_PUBLICATION_FAILED:"
            + str(process.returncode)
            + ":"
            + process.stderr[-500:]
        )
    artifact = json.loads(matches[0])
    if (
        not _core._exact_keys(artifact, TRACE_ARTIFACT_FIELDS)
        or artifact.get("schema_version") != TRACE_ARTIFACT_SCHEMA
        or artifact.get("sha256") != digest
        or artifact.get("byte_length") != len(canonical)
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D21PhysicalEvaluationError("R23D21_TRACE_CAS_RECEIPT_INVALID")
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "trace_artifact": artifact,
        "trace_summary": summary,
        "retained_before_terminal_entry": True,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def evaluate_entry(
    entry: Any,
    cell: design.Cell,
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    try:
        result = _core.evaluate_entry(
            entry,
            cell,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
    except Exception as error:
        raise R23D21PhysicalEvaluationError(str(_translate(str(error)))) from error
    return _translate(result)


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    """Evaluate the exact direct matrix without selector or outcome early-stop."""

    if not _source_commit(expected_source_commit):
        raise R23D21PhysicalEvaluationError("R23D21_EXPECTED_SOURCE_COMMIT_INVALID")
    cells = design.matrix_cells()
    evaluations: list[dict[str, Any]] = []
    failures: list[str] = []
    if len(entries) != len(cells):
        failures.append("R23D21_MATRIX_ENTRY_COUNT")
    for index, cell in enumerate(cells):
        if index >= len(entries):
            failures.append(f"R23D21_MATRIX_MISSING:{cell.cell_id}")
            continue
        evaluation = evaluate_entry(
            entries[index],
            cell,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
        evaluations.append(evaluation)
        failures.extend(
            f"{failure}:{cell.cell_id}" for failure in evaluation["failure_codes"]
        )
    if len(entries) > len(cells):
        failures.append("R23D21_MATRIX_EXTRA_ENTRY")
    supplied_ids = [
        str(entry.get("cell_id", "")) if isinstance(entry, dict) else ""
        for entry in entries
    ]
    expected_ids = [cell.cell_id for cell in cells]
    if supplied_ids != expected_ids:
        failures.append("R23D21_MATRIX_ORDER_OR_IDENTITY")
    if len(set(supplied_ids)) != len(supplied_ids):
        failures.append("R23D21_MATRIX_DUPLICATE")

    matrix_valid = not failures
    cell_outcome_failure_count = sum(
        evaluation["entry_valid"] and not evaluation["outcome"]["outcome_gate_passed"]
        for evaluation in evaluations
    )
    conditioned = {
        "reference_turn_phase_yaw_delta_rad": None,
        "positive_turn_phase_yaw_delta_rad": None,
        "negative_turn_phase_yaw_delta_rad": None,
        "positive_minus_reference_rad": None,
        "negative_minus_reference_rad": None,
        "positive_conditioned_gate_passed": False,
        "negative_conditioned_gate_passed": False,
        "conditioned_response_gate_passed": False,
        "failure_codes": [],
    }
    if matrix_valid and len(evaluations) == 3:
        yaw_by_arm = {
            cell.arm_id: float(evaluation["outcome"]["turn_phase_yaw_delta_rad"])
            for cell, evaluation in zip(cells, evaluations, strict=True)
        }
        reference_yaw = yaw_by_arm["reference_zero"]
        positive_yaw = yaw_by_arm["positive_heading"]
        negative_yaw = yaw_by_arm["negative_heading"]
        positive_separation = positive_yaw - reference_yaw
        negative_separation = negative_yaw - reference_yaw
        positive_passed = positive_separation >= 0.01
        negative_passed = negative_separation <= -0.01
        conditioned.update(
            {
                "reference_turn_phase_yaw_delta_rad": reference_yaw,
                "positive_turn_phase_yaw_delta_rad": positive_yaw,
                "negative_turn_phase_yaw_delta_rad": negative_yaw,
                "positive_minus_reference_rad": positive_separation,
                "negative_minus_reference_rad": negative_separation,
                "positive_conditioned_gate_passed": positive_passed,
                "negative_conditioned_gate_passed": negative_passed,
                "conditioned_response_gate_passed": positive_passed and negative_passed,
                "failure_codes": [
                    code
                    for code, passed in (
                        ("R23D21_POSITIVE_COMMAND_CONDITIONED_YAW", positive_passed),
                        ("R23D21_NEGATIVE_COMMAND_CONDITIONED_YAW", negative_passed),
                    )
                    if not passed
                ],
            }
        )
    conditioned_failure_count = len(conditioned["failure_codes"])
    outcome_failure_count = cell_outcome_failure_count + conditioned_failure_count
    classification = (
        "invalid_or_incomplete_complete_matrix"
        if not matrix_valid
        else (
            "valid_complete_positive"
            if outcome_failure_count == 0
            else "valid_complete_negative"
        )
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "policy_id": design.POLICY_ID,
        "classification": classification,
        "matrix_valid": matrix_valid,
        "outcome_failure_count": outcome_failure_count,
        "cell_outcome_failure_count": cell_outcome_failure_count,
        "command_conditioned_response": conditioned,
        "cell_evaluations": evaluations,
        "failure_codes": failures,
        "world_attempt_count": sum(item["world_attempt_count"] for item in evaluations),
        "world_build_count": sum(item["world_build_count"] for item in evaluations),
        "claims": copy.deepcopy(FALSE_CLAIMS),
    }


def _load_manifest(path: Path) -> list[str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D21PhysicalEvaluationError(
            f"R23D21_MANIFEST_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise R23D21PhysicalEvaluationError("R23D21_MANIFEST_NOT_STRING_ARRAY")
    return value


def _load_entries(paths: Sequence[str]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for value in paths:
        try:
            entry = json.loads(Path(value).read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise R23D21PhysicalEvaluationError(
                f"R23D21_ENTRY_UNREADABLE:{Path(value).name}:{type(error).__name__}"
            ) from error
        if not isinstance(entry, dict):
            raise R23D21PhysicalEvaluationError(
                f"R23D21_ENTRY_NOT_OBJECT:{Path(value).name}"
            )
        entries.append(entry)
    return entries


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root", type=Path)
    complete = commands.add_parser("evaluate-complete")
    complete.add_argument("--manifest", type=Path, required=True)
    complete.add_argument("--expected-source-commit", required=True)
    complete.add_argument("--allow-test-artifacts", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(list(sys.argv[1:] if argv is None else argv))
    try:
        if args.command == "retain-trace":
            result = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root,
            )
            marker = "QSDK_R23D21_TRACE_RETENTION "
        else:
            result = evaluate_complete_entries(
                _load_entries(_load_manifest(args.manifest)),
                expected_source_commit=args.expected_source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
            marker = "QSDK_R23D21_COMPLETE_EVALUATION "
    except (R23D21PhysicalEvaluationError, design.R23D21TraceError) as error:
        print("QSDK_R23D21_EVALUATOR_FAILURE " + str(error), file=sys.stderr)
        return 1
    print(marker + json.dumps(result, allow_nan=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
