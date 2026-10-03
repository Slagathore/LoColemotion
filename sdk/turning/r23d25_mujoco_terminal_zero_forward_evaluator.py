"""Cold trace retention and three-cell MuJoCo evaluation for QSDK-R23D25.

The module constructs no physics model.  It binds the qualified R23D13 cell
report validator to the R23D25 trace and declaration identities, retains every
complete trace in content-addressed storage before a terminal entry can exist,
and evaluates exactly the prospectively declared three-cell matrix. R23D25 has
no development selector and therefore exposes no Stage-A decision route.
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

import r23d25_mujoco_terminal_zero_forward_trace as design  # noqa: E402
import r23d15_physical_evaluator as inherited_evaluator  # noqa: E402


CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
DECLARATION_PATH = ROOT / "r23d25_mujoco_terminal_zero_forward_preregistration_v1.json"
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d25_trace.ps1"
R23D21_CLOSURE_PATH = ROOT / "r23d21_physical_closure_v1.json"
R23D21_CLOSURE_SHA256 = (
    "sha256:d4f941c6de221f3ce2689a137bd07ed64a13ff9e3b63b23e225a153abbedbd4c"
)
R23D22_CLOSURE_PATH = ROOT / "r23d22_physical_closure_v1.json"
R23D22_CLOSURE_SHA256 = (
    "sha256:4534a3912079687846fb4fa3cade870fd0a4c784f5cdd632e21fa1da01dca9ec"
)
R23D23_CLOSURE_PATH = ROOT / "r23d23_physical_closure_v1.json"
R23D23_CLOSURE_SHA256 = (
    "sha256:47c5be6c974fcefdbf971bf1e316ee8029bb232f3bd8b9f2dfdf0b520896dd51"
)
R23D24_CLOSURE_PATH = ROOT / "r23d24_mujoco_receipt_recovery_closure_v1.json"
R23D24_CLOSURE_SHA256 = (
    "sha256:f2bb23251919e07f326b53dea0226d00491d014a405f207d82d3b7fc08e0e1f2"
)

REPORT_SCHEMA = "sporespore_qsdk_r23d25_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d25_worker_failure_v1"
TRACE_ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d25_trace_retention_v1"
CELL_EVALUATION_SCHEMA = "sporespore_qsdk_r23d25_cell_evaluation_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d25_complete_evaluation_v1"

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


class R23D25PhysicalEvaluationError(RuntimeError):
    """A trace, retained artifact, terminal entry, or aggregate is invalid."""


def _load_private_core() -> ModuleType:
    source = ROOT / "r23d13_physical_evaluator.py"
    specification = importlib.util.spec_from_file_location(
        "_sporespore_r23d25_inherited_evaluator_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise R23D25PhysicalEvaluationError(
            "R23D25_INHERITED_EVALUATOR_CORE_UNAVAILABLE"
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
TERMINAL_ZERO_FORWARD_MEASUREMENT_FIELDS = (
    "terminal_zero_forward_command_count",
    "terminal_zero_forward_receipt_count",
    "terminal_nonzero_forward_command_count",
    "terminal_forward_receipt_violation_count",
    "maximum_absolute_terminal_desired_forward_velocity_m_s",
    "maximum_absolute_terminal_normalized_forward_velocity_error",
    "maximum_absolute_terminal_forward_hip_correction_rad",
)
MEASUREMENT_FIELDS = (
    *_core.MEASUREMENT_FIELDS,
    *TERMINAL_ZERO_FORWARD_MEASUREMENT_FIELDS,
)
_core.MEASUREMENT_FIELDS = MEASUREMENT_FIELDS


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
        return value.replace("R23D13", "R23D25").replace(
            "QSDK-R23D13", "QSDK-R23D25"
        )
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
        raise R23D25PhysicalEvaluationError(
            f"R23D25_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error

    try:
        inherited_projection = inherited_evaluator._load_declaration()
    except Exception as error:
        raise R23D25PhysicalEvaluationError(
            f"R23D25_INHERITED_SCIENTIFIC_CONTRACT_INVALID:{type(error).__name__}"
        ) from error

    lineage = declaration.get("immutable_godot_lineage", {})
    invalid_predecessor = declaration.get("immutable_invalid_predecessor_lineage", {})
    recovery = declaration.get("implementation_recovery", {})
    controller = declaration.get("controller_transfer", {})
    physical = declaration.get("inherited_physical_contract", {})
    matrix = declaration.get("prospective_matrix", {})
    decision = declaration.get("decision_rule", {})
    qualification = declaration.get("zero_world_entry_gate", {})
    claims = declaration.get("claims", {})
    try:
        historical_closure = json.loads(R23D21_CLOSURE_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D25PhysicalEvaluationError(
            f"R23D25_R23D21_CLOSURE_UNREADABLE:{type(error).__name__}"
        ) from error
    try:
        invalid_predecessor_closure = json.loads(
            R23D22_CLOSURE_PATH.read_text(encoding="utf-8")
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D25PhysicalEvaluationError(
            f"R23D25_R23D22_CLOSURE_UNREADABLE:{type(error).__name__}"
        ) from error
    historical_cells = historical_closure.get("cells", [])
    declared_historical_cells = lineage.get("cells", [])
    historical_projection = [
        {
            "cell_id": cell.get("cell_id"),
            "arm_id": cell.get("arm_id"),
            "turn_heading_offset_rad": cell.get("turn_heading_offset_rad"),
            "terminal_cas_sha256": cell.get("terminal_cas_sha256"),
            "trace_cas_sha256": cell.get("trace_cas_sha256"),
            "trace_byte_length": cell.get("trace_byte_length"),
            "turn_phase_yaw_delta_rad": cell.get("turn_phase_yaw_delta_rad"),
            "walking_and_taper_gate_passed": cell.get("walking_and_taper_gate_passed"),
        }
        for cell in historical_cells
    ]
    invalid = (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d25_reduced_yaw_transfer_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("status")
        != "prospectively_frozen_zero_world_only"
        or declaration.get("study_classification")
        != "prospective_exact_finite_implementation_recovery_three_engine_transfer_conformance"
        or _raw_sha256(R23D21_CLOSURE_PATH) != R23D21_CLOSURE_SHA256
        or lineage.get("closure_raw_sha256") != R23D21_CLOSURE_SHA256
        or lineage.get("same_identity_rerun_forbidden") is not True
        or lineage.get("scientific_positive") is not True
        or lineage.get("independent_validation") is not False
        or historical_closure.get("campaign_id")
        != "QSDK-R23D21-REDUCED-YAW-AUTHORITY-GODOT-DEVELOPMENT"
        or historical_closure.get("status")
        != "closed_consumed_valid_complete_positive_finite_godot_turning_candidate"
        or historical_closure.get("immutable_completion_record", {}).get(
            "campaign_result_classification"
        ) != "valid_complete_positive"
        or _raw_sha256(R23D22_CLOSURE_PATH) != R23D22_CLOSURE_SHA256
        or invalid_predecessor.get("closure_raw_sha256") != R23D22_CLOSURE_SHA256
        or invalid_predecessor.get("status")
        != "closed_consumed_invalid_complete_matrix_runtime_receipt_mismatches"
        or invalid_predecessor.get("same_identity_rerun_forbidden") is not True
        or invalid_predecessor.get("outcomes_reused_or_reinterpreted") is not False
        or invalid_predecessor_closure.get("status") != invalid_predecessor.get("status")
        or invalid_predecessor_closure.get("attempt", {}).get("actual_world_attempt_count") != 6
        or invalid_predecessor_closure.get("attempt", {}).get("actual_world_build_count") != 6
        or recovery.get("scientifically_distinct_successor_required") is not True
        or recovery.get("controller_or_physics_semantics_changed") is not False
        or recovery.get("adapter_receipt_oracle_corrected") is not True
        or recovery.get("mujoco_terminal_policy_binding_corrected") is not True
        or recovery.get("receipt_field_mutation_rejection_count_per_engine") != 5
        or recovery.get("model_construction_permitted_during_recovery_canaries") is not False
        or historical_projection != declared_historical_cells
        or controller.get("controller_policy_id") != design.CONTROLLER_POLICY_ID
        or controller.get("yaw_error_stride_gain_per_rad") != 1.0
        or controller.get("cross_track_frame_mode_id")
        != design.CROSS_TRACK_FRAME_MODE_ID
        or controller.get("controller_changed_from_r23d21") is not False
        or controller.get("engine_specific_gait_logic_permitted") is not False
        or controller.get("arm_identity_or_observed_outcome_branching_permitted")
        is not False
        or any(
            controller.get(field) is not False
            for field in (
                "fixture_changed",
                "morphology_changed",
                "actuation_mode_changed",
                "material_profile_changed",
                "threshold_changed",
                "horizon_changed",
                "terminal_policy_changed",
            )
        )
        or physical.get("controller_step_count") != design.CONTROLLER_STEPS
        or physical.get("terminal_step_count") != design.TERMINAL_STEPS
        or physical.get("total_trace_row_count_per_cell")
        != design.TOTAL_TRACE_STEPS
        or physical.get("maximum_active_neutral_acquisition_step_count")
        != design.temporal.MAXIMUM_ACTIVE_STEPS
        or physical.get("minimum_confirmed_taper_step_count")
        != design.temporal.MINIMUM_TAPER_STEPS
        or physical.get("minimum_post_handoff_zero_actuation_step_count")
        != design.temporal.MINIMUM_PASSIVE_STEPS
        or physical.get("coarse_maximum_torso_tilt_rad")
        != design.temporal.COARSE_MAXIMUM_TILT_RAD
        or physical.get("coarse_maximum_joint_position_error_rad")
        != design.temporal.COARSE_MAXIMUM_JOINT_ERROR_RAD
        or physical.get("tight_maximum_torso_tilt_rad")
        != design.temporal.TIGHT_MAXIMUM_TILT_RAD
        or physical.get("tight_maximum_joint_position_error_rad")
        != design.temporal.TIGHT_MAXIMUM_JOINT_ERROR_RAD
        or physical.get("minimum_command_conditioned_yaw_separation_rad") != 0.01
        or matrix.get("stage_id") != design.MATRIX_STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.MATRIX_ENGINES)
        or matrix.get("ordered_arm_ids") != list(design.MATRIX_ARMS)
        or matrix.get("declared_new_cell_count") != len(design.matrix_cells())
        or matrix.get("declared_new_world_count") != len(design.matrix_cells())
        or matrix.get("declared_composite_cell_count") != 9
        or matrix.get("declared_composite_engine_count") != 3
        or matrix.get("serialized_execution_required") is not True
        or matrix.get("all_cells_run_without_outcome_early_stop") is not True
        or matrix.get("all_cells_must_be_execution_valid") is not True
        or matrix.get("selective_replacement_or_rerun_permitted") is not False
        or matrix.get("formal_cross_engine_equivalence_study") is not False
        or matrix.get("same_engine_reference_conditioning_required") is not True
        or decision.get("positive_establishes_only_finite_three_engine_candidate")
        is not True
        or decision.get("positive_satisfies_qsdk_r23") is not False
        or decision.get("positive_establishes_cross_engine_equivalence") is not False
        or qualification.get("world_build_count") != 0
        or qualification.get("physical_execution_authorized") is not False
        or qualification.get("campaign_local_gates_plus_cep1_required") is not True
        or qualification.get("full_historical_cold_sweep_required_per_campaign")
        is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("release_authorized") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D25PhysicalEvaluationError("R23D25_DECLARATION_IDENTITY_INVALID")

    # The inherited evaluator consumes the already-qualified R23D15 semantic
    # projection. R23D25 only rebinds campaign, matrix, trace, and worker ids.
    return inherited_projection


_core._load_declaration = _load_declaration


def _load_r23d25_declaration() -> dict[str, Any]:
    """Validate the narrow successor without reinterpreting R23D24."""

    try:
        declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
        godot_closure = json.loads(R23D21_CLOSURE_PATH.read_text(encoding="utf-8"))
        predecessor_closure = json.loads(
            R23D24_CLOSURE_PATH.read_text(encoding="utf-8")
        )
        inherited_projection = inherited_evaluator._load_declaration()
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D25PhysicalEvaluationError(
            f"R23D25_DECLARATION_INPUT_UNREADABLE:{type(error).__name__}"
        ) from error

    godot = declaration.get("immutable_godot_lineage", {})
    predecessor = declaration.get("immutable_r23d24_lineage", {})
    rapier = declaration.get("immutable_rapier_lineage", {})
    repair = declaration.get("terminal_zero_forward_repair", {})
    controller = declaration.get("controller_transfer", {})
    physical = declaration.get("inherited_physical_contract", {})
    matrix = declaration.get("prospective_matrix", {})
    decision = declaration.get("decision_rule", {})
    qualification = declaration.get("zero_world_entry_gate", {})
    claims = declaration.get("claims", {})
    invalid = (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d25_mujoco_terminal_zero_forward_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("status") != "prospectively_frozen_zero_world_only"
        or declaration.get("study_classification")
        != "prospective_exact_finite_mujoco_terminal_command_semantic_successor"
        or _raw_sha256(R23D21_CLOSURE_PATH) != R23D21_CLOSURE_SHA256
        or godot.get("closure_raw_sha256") != R23D21_CLOSURE_SHA256
        or godot.get("same_identity_rerun_forbidden") is not True
        or godot_closure.get("status")
        != "closed_consumed_valid_complete_positive_finite_godot_turning_candidate"
        or _raw_sha256(R23D24_CLOSURE_PATH) != R23D24_CLOSURE_SHA256
        or predecessor.get("closure_raw_sha256") != R23D24_CLOSURE_SHA256
        or predecessor.get("same_identity_rerun_forbidden") is not True
        or predecessor.get("result_reinterpreted") is not False
        or predecessor_closure.get("status")
        != "closed_consumed_valid_complete_negative_reference_post_handoff_contact_loss"
        or predecessor_closure.get("attempt", {}).get("world_attempt_count") != 3
        or predecessor_closure.get("attempt", {}).get("world_build_count") != 3
        or _raw_sha256(R23D23_CLOSURE_PATH) != R23D23_CLOSURE_SHA256
        or rapier.get("closure_raw_sha256") != R23D23_CLOSURE_SHA256
        or rapier.get("execution_valid_cell_count") != 3
        or rapier.get("outcome_positive_cell_count") != 0
        or rapier.get("same_identity_rerun_forbidden") is not True
        or rapier.get("rerun_performed") is not False
        or repair.get("source_contract_id")
        != "r23d21_forward_velocity_foot_placement_receipt_v2"
        or repair.get("predecessor_terminal_desired_forward_velocity_m_s") != 0.2
        or repair.get("successor_terminal_desired_forward_velocity_m_s") != 0.0
        or repair.get("terminal_command_semantics_changed") is not True
        or repair.get("physics_semantics_changed") is not False
        or repair.get("threshold_or_horizon_changed") is not False
        or repair.get("r23d24_receipt_compatibility_preserved") is not True
        or repair.get("real_controller_arm_count") != 3
        or repair.get("inherited_receipt_mutation_control_count") != 22
        or repair.get("terminal_zero_forward_mutation_control_count") != 4
        or controller.get("controller_policy_id") != design.CONTROLLER_POLICY_ID
        or controller.get("yaw_error_stride_gain_per_rad") != 1.0
        or controller.get("cross_track_frame_mode_id")
        != design.CROSS_TRACK_FRAME_MODE_ID
        or controller.get("controller_changed_from_r23d21") is not False
        or controller.get("terminal_command_role_changed_from_r23d24") is not True
        or controller.get("engine_specific_gait_logic_permitted") is not False
        or any(
            controller.get(field) is not False
            for field in (
                "fixture_changed",
                "morphology_changed",
                "actuation_mode_changed",
                "material_profile_changed",
                "threshold_changed",
                "horizon_changed",
                "terminal_policy_changed",
            )
        )
        or physical.get("controller_step_count") != design.CONTROLLER_STEPS
        or physical.get("terminal_step_count") != design.TERMINAL_STEPS
        or physical.get("total_trace_row_count_per_cell")
        != design.TOTAL_TRACE_STEPS
        or physical.get("tight_maximum_torso_tilt_rad")
        != design.temporal.TIGHT_MAXIMUM_TILT_RAD
        or physical.get("tight_maximum_joint_position_error_rad")
        != design.temporal.TIGHT_MAXIMUM_JOINT_ERROR_RAD
        or matrix.get("stage_id") != design.MATRIX_STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.MATRIX_ENGINES)
        or matrix.get("ordered_arm_ids") != list(design.MATRIX_ARMS)
        or matrix.get("ordered_cell_ids")
        != [cell.cell_id for cell in design.matrix_cells()]
        or matrix.get("declared_new_cell_count") != 3
        or matrix.get("declared_new_world_count") != 3
        or matrix.get("serialized_execution_required") is not True
        or matrix.get("all_cells_run_without_outcome_early_stop") is not True
        or matrix.get("selective_replacement_or_rerun_permitted") is not False
        or decision.get("positive_establishes_only_finite_mujoco_candidate")
        is not True
        or decision.get("positive_establishes_finite_three_engine_candidate")
        is not False
        or qualification.get("campaign_local_gates_plus_cep1_required") is not True
        or qualification.get("full_historical_cold_sweep_required_per_campaign")
        is not False
        or qualification.get("physical_execution_authorized") is not False
        or qualification.get("world_build_count") != 0
        or claims.get("finite_three_engine_turning_candidate") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("release_authorized") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D25PhysicalEvaluationError("R23D25_DECLARATION_IDENTITY_INVALID")
    return inherited_projection


_load_declaration = _load_r23d25_declaration
_core._load_declaration = _load_r23d25_declaration


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
        raise R23D25PhysicalEvaluationError("R23D25_REPO_ROOT_INVALID")
    if not attempt_root.exists() or not attempt_root.is_dir():
        raise R23D25PhysicalEvaluationError("R23D25_ATTEMPT_ROOT_MISSING")
    if not test_only:
        production_root = repo_root.parent / "SporeSpore_Evidence"
        if not _core._path_within(attempt_root, production_root):
            raise R23D25PhysicalEvaluationError(
                "R23D25_PRODUCTION_ATTEMPT_ROOT_NOT_DURABLE"
            )
        if evidence_root_override is not None:
            raise R23D25PhysicalEvaluationError(
                "R23D25_PRODUCTION_EVIDENCE_OVERRIDE_FORBIDDEN"
            )
    elif evidence_root_override is None:
        raise R23D25PhysicalEvaluationError("R23D25_TEST_EVIDENCE_ROOT_REQUIRED")

    try:
        rows = _core._read_rows_json(rows_json_path)
    except Exception as error:
        raise R23D25PhysicalEvaluationError(str(_translate(str(error)))) from error
    summary = design.validate_trace(cell, rows)
    if not summary["ok"]:
        raise R23D25PhysicalEvaluationError(
            "R23D25_TRACE_INVALID:" + ",".join(summary["failure_codes"][:8])
        )
    canonical = design.canonical_ndjson(rows)
    digest = "sha256:" + hashlib.sha256(canonical).hexdigest()
    if digest != summary["raw_sha256"] or len(canonical) != summary["byte_length"]:
        raise R23D25PhysicalEvaluationError(
            "R23D25_TRACE_CANONICAL_RECEIPT_MISMATCH"
        )

    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    canonical_path = trace_root / f"{cell.stage_id}__{cell.cell_id}.ndjson"
    try:
        with canonical_path.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D25PhysicalEvaluationError(
            "R23D25_TRACE_STAGING_PATH_EXISTS"
        ) from error
    if _raw_sha256(canonical_path) != digest:
        raise R23D25PhysicalEvaluationError("R23D25_TRACE_WRITE_MISMATCH")

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
    marker = "QSDK_R23D25_TRACE_CAS "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D25PhysicalEvaluationError(
            "R23D25_TRACE_CAS_PUBLICATION_FAILED:"
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
        raise R23D25PhysicalEvaluationError("R23D25_TRACE_CAS_RECEIPT_INVALID")
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
    if isinstance(entry, dict) and entry.get("schema_version") == REPORT_SCHEMA:
        measurements = entry.get("measurements")
        if not isinstance(measurements, dict):
            raise R23D25PhysicalEvaluationError(
                "R23D25_TERMINAL_ZERO_FORWARD_MEASUREMENTS_MISSING"
            )
        active_count = measurements.get("active_terminal_step_count")
        integer_fields = (
            "terminal_zero_forward_command_count",
            "terminal_zero_forward_receipt_count",
            "terminal_nonzero_forward_command_count",
            "terminal_forward_receipt_violation_count",
        )
        zero_fields = (
            "maximum_absolute_terminal_desired_forward_velocity_m_s",
            "maximum_absolute_terminal_normalized_forward_velocity_error",
            "maximum_absolute_terminal_forward_hip_correction_rad",
        )
        if (
            isinstance(active_count, bool)
            or not isinstance(active_count, int)
            or any(
                isinstance(measurements.get(field), bool)
                or not isinstance(measurements.get(field), int)
                for field in integer_fields
            )
            or measurements.get("terminal_zero_forward_command_count")
            != active_count
            or measurements.get("terminal_zero_forward_receipt_count")
            != active_count
            or measurements.get("terminal_nonzero_forward_command_count") != 0
            or measurements.get("terminal_forward_receipt_violation_count") != 0
            or any(
                isinstance(measurements.get(field), bool)
                or not isinstance(measurements.get(field), (int, float))
                or float(measurements.get(field)) != 0.0
                for field in zero_fields
            )
        ):
            raise R23D25PhysicalEvaluationError(
                "R23D25_TERMINAL_ZERO_FORWARD_MEASUREMENTS_INVALID"
            )
    try:
        result = _core.evaluate_entry(
            entry,
            cell,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
    except Exception as error:
        raise R23D25PhysicalEvaluationError(str(_translate(str(error)))) from error
    return _translate(result)


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    """Evaluate the exact direct matrix without selector or outcome early-stop."""

    if not _source_commit(expected_source_commit):
        raise R23D25PhysicalEvaluationError(
            "R23D25_EXPECTED_SOURCE_COMMIT_INVALID"
        )
    cells = design.matrix_cells()
    evaluations: list[dict[str, Any]] = []
    failures: list[str] = []
    if len(entries) != len(cells):
        failures.append("R23D25_MATRIX_ENTRY_COUNT")
    for index, cell in enumerate(cells):
        if index >= len(entries):
            failures.append(f"R23D25_MATRIX_MISSING:{cell.cell_id}")
            continue
        evaluation = evaluate_entry(
            entries[index],
            cell,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
        evaluations.append(evaluation)
        failures.extend(
            f"{failure}:{cell.cell_id}"
            for failure in evaluation["failure_codes"]
        )
    if len(entries) > len(cells):
        failures.append("R23D25_MATRIX_EXTRA_ENTRY")
    supplied_ids = [
        str(entry.get("cell_id", "")) if isinstance(entry, dict) else ""
        for entry in entries
    ]
    expected_ids = [cell.cell_id for cell in cells]
    if supplied_ids != expected_ids:
        failures.append("R23D25_MATRIX_ORDER_OR_IDENTITY")
    if len(set(supplied_ids)) != len(supplied_ids):
        failures.append("R23D25_MATRIX_DUPLICATE")

    conditioned_response: dict[str, dict[str, Any]] = {}
    conditioned_failure_count = 0
    minimum_separation = 0.01
    for engine_id in design.MATRIX_ENGINES:
        by_arm = {
            evaluation["cell_id"].rsplit("__", 1)[-1]: evaluation
            for evaluation in evaluations
            if evaluation["engine_id"] == engine_id and evaluation["entry_valid"]
        }
        if set(by_arm) != set(design.MATRIX_ARMS):
            failures.append(f"R23D25_CONDITIONED_RESPONSE_INCOMPLETE:{engine_id}")
            continue
        reference = float(by_arm["reference_zero"]["outcome"]["turn_phase_yaw_delta_rad"])
        positive = float(by_arm["positive_heading"]["outcome"]["turn_phase_yaw_delta_rad"])
        negative = float(by_arm["negative_heading"]["outcome"]["turn_phase_yaw_delta_rad"])
        positive_delta = positive - reference
        negative_delta = negative - reference
        positive_passed = positive_delta >= minimum_separation
        negative_passed = negative_delta <= -minimum_separation
        conditioned_response[engine_id] = {
            "reference_turn_phase_yaw_delta_rad": reference,
            "positive_turn_phase_yaw_delta_rad": positive,
            "negative_turn_phase_yaw_delta_rad": negative,
            "positive_minus_reference_rad": positive_delta,
            "negative_minus_reference_rad": negative_delta,
            "positive_conditioned_gate_passed": positive_passed,
            "negative_conditioned_gate_passed": negative_passed,
            "conditioned_response_gate_passed": positive_passed and negative_passed,
        }
        if not positive_passed:
            conditioned_failure_count += 1
        if not negative_passed:
            conditioned_failure_count += 1

    matrix_valid = not failures
    outcome_failure_count = sum(
        evaluation["entry_valid"]
        and not evaluation["outcome"]["outcome_gate_passed"]
        for evaluation in evaluations
    ) + conditioned_failure_count
    classification = (
        "invalid_or_incomplete_complete_matrix"
        if not matrix_valid
        else "valid_complete_positive"
        if outcome_failure_count == 0
        else "valid_complete_negative"
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "policy_id": design.POLICY_ID,
        "classification": classification,
        "matrix_valid": matrix_valid,
        "outcome_failure_count": outcome_failure_count,
        "cell_evaluations": evaluations,
        "same_engine_command_conditioned_response": conditioned_response,
        "historical_godot_binding": {
            "closure_raw_sha256": R23D21_CLOSURE_SHA256,
            "cell_count": 3,
            "scientific_positive": True,
            "rerun_performed": False,
        },
        "historical_rapier_binding": {
            "closure_raw_sha256": R23D23_CLOSURE_SHA256,
            "cell_count": 3,
            "scientific_positive": False,
            "execution_valid": True,
            "rerun_performed": False,
        },
        "composite_engine_count": 3,
        "composite_cell_count": len(evaluations) + 6,
        "failure_codes": failures,
        "world_attempt_count": sum(
            item["world_attempt_count"] for item in evaluations
        ),
        "world_build_count": sum(item["world_build_count"] for item in evaluations),
        "claims": copy.deepcopy(FALSE_CLAIMS),
    }


def _load_manifest(path: Path) -> list[str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D25PhysicalEvaluationError(
            f"R23D25_MANIFEST_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise R23D25PhysicalEvaluationError("R23D25_MANIFEST_NOT_STRING_ARRAY")
    return value


def _load_entries(paths: Sequence[str]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for value in paths:
        try:
            entry = json.loads(Path(value).read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise R23D25PhysicalEvaluationError(
                f"R23D25_ENTRY_UNREADABLE:{Path(value).name}:{type(error).__name__}"
            ) from error
        if not isinstance(entry, dict):
            raise R23D25PhysicalEvaluationError(
                f"R23D25_ENTRY_NOT_OBJECT:{Path(value).name}"
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
            marker = "QSDK_R23D25_TRACE_RETENTION "
        else:
            result = evaluate_complete_entries(
                _load_entries(_load_manifest(args.manifest)),
                expected_source_commit=args.expected_source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
            marker = "QSDK_R23D25_COMPLETE_EVALUATION "
    except (R23D25PhysicalEvaluationError, design.R23D25TraceError) as error:
        print("QSDK_R23D25_EVALUATOR_FAILURE " + str(error), file=sys.stderr)
        return 1
    print(marker + json.dumps(result, allow_nan=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
