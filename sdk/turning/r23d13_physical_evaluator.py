"""Cold trace retention and physical outcome evaluation for QSDK-R23D13.

This module never constructs a physics model. It validates and retains complete
3,892-row traces before terminal entries exist, independently replays the
inherited support-and-pose-confirmed temporal handoff, validates the new
residual-pose authority against command-time observations and all eight final
commands, and applies the prospectively frozen walking, signed-yaw, safety,
and aggregate selection gates.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable, Sequence


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d13_physical_trace as design


CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
DECLARATION_PATH = ROOT / "r23d13_residual_pose_authority_preregistration_v1.json"
TEMPORAL_ORACLE_PATH = ROOT / "r23d10_quiescent_taper.py"
COMPOSITION_DECLARATION_PATH = (
    ROOT / "r23d11_stability_assisted_taper_preregistration_v1.json"
)
COMPOSITION_ORACLE_PATH = ROOT / "r23d11_stability_assisted_taper.py"
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d13_trace.ps1"

REPORT_SCHEMA = "sporespore_qsdk_r23d13_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d13_worker_failure_v1"
TRACE_ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d13_trace_retention_v1"
CELL_EVALUATION_SCHEMA = "sporespore_qsdk_r23d13_cell_evaluation_v1"
STAGE_A_EVALUATION_SCHEMA = "sporespore_qsdk_r23d13_stage_a_evaluation_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d13_complete_evaluation_v1"

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

REPORT_FIELDS = (
    "schema_version",
    "campaign_id",
    "gate_id",
    "stage_id",
    "cell_id",
    "engine_id",
    "arm_id",
    "turn_heading_offset_rad",
    "source_commit",
    "trace_artifact",
    "trace_summary",
    "execution",
    "measurements",
    "claims",
)
FAILURE_FIELDS = (
    "schema_version",
    "campaign_id",
    "gate_id",
    "stage_id",
    "cell_id",
    "engine_id",
    "arm_id",
    "turn_heading_offset_rad",
    "source_commit",
    "failure_stage",
    "failure_code",
    "world_attempt_count",
    "world_build_count",
    "trace_artifact",
    "claims",
)
TRACE_ARTIFACT_FIELDS = (
    "schema_version",
    "sha256",
    "byte_length",
    "payload_path",
    "manifest_path",
    "already_present",
    "test_only",
    "physical_acceptance_authority",
)
TRACE_SUMMARY_FIELDS = (
    "ok",
    "failure_codes",
    "row_count",
    "raw_sha256",
    "byte_length",
    "hash_projection",
    "phase_counts",
    "taper_outcome",
    "authority_outcome",
)
EXECUTION_FIELDS = (
    "integrity_passed",
    "worker_failure_code",
    "controller_semantic_step_count",
    "terminal_quiescent_taper_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "post_handoff_native_actuation_application_count",
    "portable_impulse_violation_count",
    "world_attempt_count",
    "world_build_count",
    "trace_retained_before_terminal_entry",
    "fixed_horizon_configuration_proved_before_fixture_insertion",
)
MEASUREMENT_FIELDS = (
    "final_forward_displacement_m",
    "turn_phase_yaw_delta_rad",
    "maximum_absolute_requested_steering_fraction",
    "maximum_absolute_held_steering_fraction",
    "maximum_tilt_rad",
    "minimum_torso_height_m",
    "contact_cycle_count_by_limb",
    "torso_ground_contact_step_count",
    "controller_error_count",
    "active_safe_no_actuation_count",
    "nonfinite_observation_count",
    "actuator_application_mismatch_count",
    "controller_semantic_step_count",
    "terminal_quiescent_taper_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "post_handoff_native_actuation_application_count",
    "confirmation_satisfied",
    "handoff_after_active_step",
    "first_passive_step",
    "handoff_reason",
    "active_terminal_step_count",
    "quiescent_taper_step_count",
    "passive_terminal_step_count",
    "taper_reset_count",
    "active_terminal_native_actuation_application_count",
    "quiescent_taper_gate_passed",
    "first_post_handoff_contact_loss_step",
    "post_handoff_contact_loss_step_count",
    "terminal_receipt_validation_failure_count",
    "maximum_absolute_terminal_active_joint_velocity_rad_s",
)


class R23D13PhysicalEvaluationError(RuntimeError):
    """A trace, retained artifact, terminal entry, or aggregate is invalid."""


def _exact_keys(value: Any, fields: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(fields)


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _nonnegative_int(value: Any) -> bool:
    return type(value) is int and value >= 0


def _sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_ndjson(rows: Sequence[dict[str, Any]]) -> bytes:
    return b"".join(design._canonical_row(row) for row in rows)


def _load_declaration() -> dict[str, Any]:
    try:
        declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D13PhysicalEvaluationError(
            f"R23D13_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error

    inherited = declaration.get("inherited_scientific_contract", {})
    temporal_contract = declaration.get("inherited_temporal_contract", {})
    composition_contract = declaration.get("inherited_whole_body_composition", {})
    authority_contract = declaration.get("residual_pose_authority_contract", {})
    successor = declaration.get("scientifically_distinct_successor", {})
    stage_a = declaration.get("stage_a_mujoco_screen", {})
    selector = declaration.get("stage_a_selector", {})
    stage_b = declaration.get("stage_b_three_engine_confirmation", {})
    authorization = declaration.get("stage_zero_authority", {})
    claims = declaration.get("claim_boundary", {})
    invalid = (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d13_residual_pose_authority_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("status")
        != "prospectively_frozen_stage_zero_zero_world_only"
        or inherited.get("physics_hz") != design.PHYSICS_HZ
        or inherited.get("turn_start_semantic_step") != design.TURN_START_STEP
        or inherited.get("turn_duration_steps") != design.TURN_DURATION_STEPS
        or inherited.get("turning_controller_semantic_step_count")
        != design.CONTROLLER_STEPS
        or temporal_contract.get("source_path")
        != "sdk/turning/r23d10_quiescent_taper.py"
        or temporal_contract.get("source_raw_sha256")
        != _raw_sha256(TEMPORAL_ORACLE_PATH)
        or temporal_contract.get("terminal_step_count") != design.TERMINAL_STEPS
        or temporal_contract.get("maximum_active_step_count")
        != design.temporal.MAXIMUM_ACTIVE_STEPS
        or temporal_contract.get("minimum_quiescent_taper_step_count")
        != design.temporal.MINIMUM_TAPER_STEPS
        or temporal_contract.get("minimum_passive_step_count")
        != design.temporal.MINIMUM_PASSIVE_STEPS
        or composition_contract.get("preregistration_path")
        != "sdk/turning/r23d11_stability_assisted_taper_preregistration_v1.json"
        or composition_contract.get("preregistration_raw_sha256")
        != _raw_sha256(COMPOSITION_DECLARATION_PATH)
        or composition_contract.get("oracle_path")
        != "sdk/turning/r23d11_stability_assisted_taper.py"
        or composition_contract.get("oracle_raw_sha256")
        != _raw_sha256(COMPOSITION_ORACLE_PATH)
        or composition_contract.get("ordered_actuator_count") != design.ACTUATOR_COUNT
        or composition_contract.get(
            "maximum_absolute_stability_velocity_delta_rad_s"
        )
        != design.composition.MAXIMUM_ABSOLUTE_STABILITY_VELOCITY_DELTA_RAD_S
        or composition_contract.get(
            "maximum_pre_taper_combined_velocity_magnitude_rad_s"
        )
        != design.MAXIMUM_COMBINED_VELOCITY_RAD_S
        or successor.get("new_policy_id") != design.POLICY_ID
        or successor.get("final_active_authority_scalar_changed") is not True
        or successor.get("new_tunable_gain_count") != 0
        or successor.get("new_decision_threshold_count") != 0
        or successor.get("arm_identity_or_command_sign_is_control_input")
        is not False
        or authority_contract.get("scale_denominator")
        != design.authority.SCALE_DENOMINATOR
        or authority_contract.get("minimum_supported_floor_numerator") != 1
        or authority_contract.get("maximum_floor_numerator")
        != design.authority.SCALE_DENOMINATOR
        or authority_contract.get(
            "authority_floor_may_never_reduce_inherited_temporal_authority"
        )
        is not True
        or authority_contract.get(
            "recovery_may_never_reactivate_after_passive_handoff"
        )
        is not True
        or authority_contract.get(
            "complete_combined_velocity_scaled_once_before_host_mapping"
        )
        is not True
        or authority_contract.get("arm_identity_heading_sign_or_outcome_branching")
        is not False
        or stage_a.get("stage_id") != design.STAGE_A_ID
        or stage_a.get("engine_id") != "mujoco"
        or stage_a.get("ordered_arm_ids") != list(design.STAGE_A_ARMS)
        or stage_a.get("declared_cell_count") != len(design.stage_a_cells())
        or stage_a.get("declared_world_count") != len(design.stage_a_cells())
        or selector.get("selected_policy_id_if_passing") != design.POLICY_ID
        or selector.get("selected_policy_id_if_not_passing") != "NONE"
        or stage_b.get("ordered_engine_ids") != list(design.STAGE_B_ENGINES)
        or stage_b.get("ordered_arm_ids") != list(design.STAGE_B_ARMS)
        or stage_b.get("declared_cell_count_if_launched")
        != len(design.stage_b_cells())
        or stage_b.get("declared_world_count_if_launched")
        != len(design.stage_b_cells())
        or authorization.get("physical_worker_count") != 0
        or authorization.get("evaluator_implementation_count") != 0
        or authorization.get("world_build_count") != 0
        or authorization.get("physical_execution_authorized") is not False
        or claims.get("command_conditioned_turning") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("prone_to_standing") is not False
        or claims.get("release_authorized") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D13PhysicalEvaluationError("R23D13_DECLARATION_IDENTITY_INVALID")
    return declaration

def cell_for_identity(stage_id: str, cell_id: str) -> design.Cell:
    matches = [
        cell
        for cell in design.all_cells()
        if cell.stage_id == stage_id and cell.cell_id == cell_id
    ]
    if len(matches) != 1:
        raise R23D13PhysicalEvaluationError(
            f"R23D13_CELL_IDENTITY_INVALID:{stage_id}:{cell_id}"
        )
    return matches[0]


def _path_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def _read_rows_json(path: Path) -> list[dict[str, Any]]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D13PhysicalEvaluationError(
            f"R23D13_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, list) or any(not isinstance(row, dict) for row in value):
        raise R23D13PhysicalEvaluationError("R23D13_TRACE_ROWS_NOT_OBJECT_ARRAY")
    return value


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
    if repo_root != REPO_ROOT.resolve():
        raise R23D13PhysicalEvaluationError("R23D13_REPO_ROOT_INVALID")
    if not attempt_root.exists() or not attempt_root.is_dir():
        raise R23D13PhysicalEvaluationError("R23D13_ATTEMPT_ROOT_MISSING")
    if not test_only:
        production_root = repo_root.parent / "SporeSpore_Evidence"
        if not _path_within(attempt_root, production_root):
            raise R23D13PhysicalEvaluationError(
                "R23D13_PRODUCTION_ATTEMPT_ROOT_NOT_DURABLE"
            )
        if evidence_root_override is not None:
            raise R23D13PhysicalEvaluationError(
                "R23D13_PRODUCTION_EVIDENCE_OVERRIDE_FORBIDDEN"
            )
    elif evidence_root_override is None:
        raise R23D13PhysicalEvaluationError("R23D13_TEST_EVIDENCE_ROOT_REQUIRED")

    rows = _read_rows_json(rows_json_path)
    summary = design.validate_trace(cell, rows)
    if not summary["ok"]:
        raise R23D13PhysicalEvaluationError(
            "R23D13_TRACE_INVALID:" + ",".join(summary["failure_codes"][:8])
        )
    canonical = _canonical_ndjson(rows)
    digest = "sha256:" + hashlib.sha256(canonical).hexdigest()
    if digest != summary["raw_sha256"] or len(canonical) != summary["byte_length"]:
        raise R23D13PhysicalEvaluationError("R23D13_TRACE_CANONICAL_RECEIPT_MISMATCH")

    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    canonical_path = trace_root / f"{cell.stage_id}__{cell.cell_id}.ndjson"
    try:
        with canonical_path.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D13PhysicalEvaluationError(
            "R23D13_TRACE_STAGING_PATH_EXISTS"
        ) from error
    if _raw_sha256(canonical_path) != digest:
        raise R23D13PhysicalEvaluationError("R23D13_TRACE_WRITE_MISMATCH")

    command = [
        powershell,
        "-NoLogo",
        "-NoProfile",
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
    marker = "QSDK_R23D13_TRACE_CAS "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D13PhysicalEvaluationError(
            "R23D13_TRACE_CAS_PUBLICATION_FAILED:"
            + str(process.returncode)
            + ":"
            + process.stderr[-500:]
        )
    artifact = json.loads(matches[0])
    if (
        not _exact_keys(artifact, TRACE_ARTIFACT_FIELDS)
        or artifact.get("schema_version") != TRACE_ARTIFACT_SCHEMA
        or artifact.get("sha256") != digest
        or artifact.get("byte_length") != len(canonical)
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D13PhysicalEvaluationError("R23D13_TRACE_CAS_RECEIPT_INVALID")
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


def _parse_ndjson(path: Path) -> list[dict[str, Any]]:
    try:
        raw = path.read_bytes()
        if not raw or not raw.endswith(b"\n"):
            raise R23D13PhysicalEvaluationError("R23D13_TRACE_NDJSON_TERMINATOR")
        rows = [json.loads(line.decode("utf-8")) for line in raw.splitlines()]
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D13PhysicalEvaluationError(
            f"R23D13_TRACE_NDJSON_UNREADABLE:{type(error).__name__}"
        ) from error
    if any(not isinstance(row, dict) for row in rows):
        raise R23D13PhysicalEvaluationError("R23D13_TRACE_NDJSON_ROW_TYPE")
    if _canonical_ndjson(rows) != raw:
        raise R23D13PhysicalEvaluationError("R23D13_TRACE_NDJSON_NOT_CANONICAL")
    return rows


def _validate_artifact(
    artifact: Any,
    cell: design.Cell,
    *,
    allow_test_artifacts: bool,
) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    if not _exact_keys(artifact, TRACE_ARTIFACT_FIELDS):
        return {}, ["R23D13_TRACE_ARTIFACT_FIELDS"]
    if (
        artifact.get("schema_version") != TRACE_ARTIFACT_SCHEMA
        or not _sha256(artifact.get("sha256"))
        or not _nonnegative_int(artifact.get("byte_length"))
        or artifact.get("byte_length") == 0
        or not isinstance(artifact.get("already_present"), bool)
        or not isinstance(artifact.get("test_only"), bool)
        or (artifact.get("test_only") and not allow_test_artifacts)
        or artifact.get("physical_acceptance_authority") is not False
    ):
        failures.append("R23D13_TRACE_ARTIFACT_RECEIPT")
    payload = Path(str(artifact.get("payload_path", "")))
    manifest_path = Path(str(artifact.get("manifest_path", "")))
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return {}, failures + [
            f"R23D13_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"
        ]
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    digest_hex = digest[7:]
    payload_resolved = payload.resolve()
    manifest_resolved = manifest_path.resolve()
    cas_directory = payload_resolved.parent
    cas_path_valid = (
        payload.is_absolute()
        and manifest_path.is_absolute()
        and payload_resolved.name == "payload.bin"
        and manifest_resolved.name == "manifest.json"
        and manifest_resolved.parent == cas_directory
        and cas_directory.name == digest_hex
        and cas_directory.parent.name == "sha256"
        and cas_directory.parent.parent.name == "artifacts"
    )
    if not artifact.get("test_only"):
        cas_path_valid = cas_path_valid and _path_within(
            cas_directory,
            REPO_ROOT.parent / "SporeSpore_Evidence",
        )
    if not cas_path_valid:
        failures.append("R23D13_TRACE_ARTIFACT_CAS_PATH")
    if (
        digest != artifact.get("sha256")
        or len(raw) != artifact.get("byte_length")
        or manifest
        != {
            "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
            "algorithm": "sha256",
            "sha256": digest,
            "byte_length": len(raw),
            "payload_name": "payload.bin",
            "media_type": "application/x-ndjson",
        }
    ):
        failures.append("R23D13_TRACE_ARTIFACT_BYTES")
    try:
        summary = design.validate_trace(cell, _parse_ndjson(payload))
    except R23D13PhysicalEvaluationError as error:
        return {}, failures + [str(error)]
    if not summary["ok"]:
        failures.extend(summary["failure_codes"])
    return summary, failures


def _identity_failures(
    entry: dict[str, Any],
    cell: design.Cell,
    expected_source_commit: str,
) -> list[str]:
    expected = {
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": cell.engine_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
    }
    failures = [
        f"R23D13_IDENTITY:{field}"
        for field, value in expected.items()
        if entry.get(field) != value
    ]
    if not _source_commit(entry.get("source_commit")):
        failures.append("R23D13_SOURCE_COMMIT")
    elif entry.get("source_commit") != expected_source_commit:
        failures.append("R23D13_SOURCE_COMMIT_EXPECTED")
    return failures


def _measurement_failures(measurements: Any) -> list[str]:
    if not _exact_keys(measurements, MEASUREMENT_FIELDS):
        return ["R23D13_MEASUREMENT_FIELDS"]
    failures: list[str] = []
    for field in (
        "final_forward_displacement_m",
        "turn_phase_yaw_delta_rad",
        "maximum_absolute_requested_steering_fraction",
        "maximum_absolute_held_steering_fraction",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
        "maximum_absolute_terminal_active_joint_velocity_rad_s",
    ):
        if not _finite(measurements[field]):
            failures.append(f"R23D13_MEASUREMENT_FINITE:{field}")
    for field in (
        "torso_ground_contact_step_count",
        "controller_error_count",
        "active_safe_no_actuation_count",
        "nonfinite_observation_count",
        "actuator_application_mismatch_count",
        "controller_semantic_step_count",
        "terminal_quiescent_taper_step_count",
        "validated_portable_command_count",
        "native_actuation_application_count",
        "post_handoff_native_actuation_application_count",
        "active_terminal_step_count",
        "quiescent_taper_step_count",
        "passive_terminal_step_count",
        "taper_reset_count",
        "active_terminal_native_actuation_application_count",
        "post_handoff_contact_loss_step_count",
        "terminal_receipt_validation_failure_count",
    ):
        if not _nonnegative_int(measurements[field]):
            failures.append(f"R23D13_MEASUREMENT_COUNT:{field}")
    for field in (
        "handoff_after_active_step",
        "first_passive_step",
        "first_post_handoff_contact_loss_step",
    ):
        if measurements[field] is not None and not _nonnegative_int(
            measurements[field]
        ):
            failures.append(f"R23D13_MEASUREMENT_OPTIONAL_COUNT:{field}")
    if type(measurements["confirmation_satisfied"]) is not bool:
        failures.append("R23D13_MEASUREMENT_CONFIRMATION_SATISFIED")
    if type(measurements["quiescent_taper_gate_passed"]) is not bool:
        failures.append("R23D13_MEASUREMENT_TAPER_GATE")
    if measurements["handoff_reason"] not in (
        design.temporal.CONFIRMED_REASON,
        design.temporal.DEADLINE_REASON,
    ):
        failures.append("R23D13_MEASUREMENT_HANDOFF_REASON")
    contacts = measurements["contact_cycle_count_by_limb"]
    if (
        not isinstance(contacts, dict)
        or list(contacts) != list(design.LIMB_IDS)
        or any(not _nonnegative_int(contacts.get(limb)) for limb in design.LIMB_IDS)
    ):
        failures.append("R23D13_MEASUREMENT_CONTACT_CYCLES")
    return failures


def _outcome(
    cell: design.Cell,
    measurements: dict[str, Any],
    replay: dict[str, Any],
) -> dict[str, Any]:
    declaration = _load_declaration()
    gates = declaration["inherited_scientific_contract"]
    terminal_gate = declaration["inherited_temporal_contract"]
    composition_gate = declaration["inherited_whole_body_composition"]
    failures: list[str] = []
    steering_limit = float(
        gates["maximum_absolute_requested_or_held_steering_fraction"]
    )
    if max(
        abs(float(measurements["maximum_absolute_requested_steering_fraction"])),
        abs(float(measurements["maximum_absolute_held_steering_fraction"])),
    ) > steering_limit + 1.0e-12:
        failures.append("R23D13_STEERING_LIMIT")
    if float(measurements["final_forward_displacement_m"]) < float(
        gates["minimum_final_forward_displacement_m"]
    ):
        failures.append("R23D13_FORWARD_DISPLACEMENT")
    if float(measurements["maximum_tilt_rad"]) > float(gates["maximum_tilt_rad"]):
        failures.append("R23D13_MAXIMUM_TILT")
    if float(measurements["minimum_torso_height_m"]) < float(
        gates["minimum_torso_height_m"]
    ):
        failures.append("R23D13_MINIMUM_TORSO_HEIGHT")
    minimum_cycles = int(gates["minimum_contact_cycles_per_limb"])
    for limb in design.LIMB_IDS:
        if measurements["contact_cycle_count_by_limb"][limb] < minimum_cycles:
            failures.append(f"R23D13_CONTACT_CYCLES:{limb}")
    for field, gate_id in (
        ("torso_ground_contact_step_count", "R23D13_TORSO_GROUND_CONTACT"),
        ("controller_error_count", "R23D13_CONTROLLER_ERROR"),
        ("active_safe_no_actuation_count", "R23D13_ACTIVE_SAFE_NO_ACTUATION"),
        ("nonfinite_observation_count", "R23D13_NONFINITE_OBSERVATION"),
        (
            "actuator_application_mismatch_count",
            "R23D13_ACTUATOR_APPLICATION_MISMATCH",
        ),
        (
            "post_handoff_native_actuation_application_count",
            "R23D13_POST_HANDOFF_NATIVE_APPLICATION",
        ),
        (
            "terminal_receipt_validation_failure_count",
            "R23D13_TERMINAL_RECEIPT_VALIDATION",
        ),
    ):
        if measurements[field] != 0:
            failures.append(gate_id)
    if measurements["controller_semantic_step_count"] != design.CONTROLLER_STEPS:
        failures.append("R23D13_CONTROLLER_HORIZON")
    if measurements["terminal_quiescent_taper_step_count"] != design.TERMINAL_STEPS:
        failures.append("R23D13_TERMINAL_HORIZON")
    expected_active_applications = (
        design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        + int(replay["active_native_application_count"])
    )
    if not (
        replay["active_native_application_count"]
        == replay["active_step_count"] * design.ACTUATOR_COUNT
        and 0 < replay["active_step_count"]
        <= int(terminal_gate["maximum_active_step_count"])
    ):
        failures.append("R23D13_REPLAY_ACTIVE_APPLICATION_RANGE")
    if measurements["validated_portable_command_count"] != expected_active_applications:
        failures.append("R23D13_VALIDATED_COMMAND_COUNT")
    if measurements["native_actuation_application_count"] != expected_active_applications:
        failures.append("R23D13_NATIVE_APPLICATION_COUNT")
    replay_fields = {
        "confirmation_satisfied": "confirmation_satisfied",
        "handoff_after_active_step": "handoff_after_active_step",
        "first_passive_step": "first_passive_step",
        "handoff_reason": "handoff_reason",
        "active_terminal_step_count": "active_step_count",
        "quiescent_taper_step_count": "taper_step_count",
        "passive_terminal_step_count": "passive_step_count",
        "taper_reset_count": "taper_reset_count",
        "active_terminal_native_actuation_application_count": (
            "active_native_application_count"
        ),
        "quiescent_taper_gate_passed": "quiescent_taper_gate_passed",
        "first_post_handoff_contact_loss_step": (
            "first_post_handoff_contact_loss_step"
        ),
        "post_handoff_contact_loss_step_count": (
            "post_handoff_contact_loss_step_count"
        ),
    }
    for measurement_field, replay_field in replay_fields.items():
        if measurements[measurement_field] != replay[replay_field]:
            failures.append(f"R23D13_TAPER_REPLAY:{measurement_field}")
    if replay["quiescent_taper_gate_passed"] is not True:
        failures.append("R23D13_QUIESCENT_TAPER")
    if (
        float(measurements["maximum_absolute_terminal_active_joint_velocity_rad_s"])
        > float(
            composition_gate[
                "maximum_pre_taper_combined_velocity_magnitude_rad_s"
            ]
        )
        + 1.0e-12
    ):
        failures.append("R23D13_TERMINAL_ACTIVE_JOINT_VELOCITY")

    walking_and_taper_gate_passed = not failures
    yaw_delta = float(measurements["turn_phase_yaw_delta_rad"])
    signed_yaw_response_passed = cell.arm_id == "reference_zero" or (
        abs(yaw_delta)
        >= float(gates["minimum_absolute_signed_turn_phase_yaw_delta_rad"])
        and math.copysign(1.0, yaw_delta)
        == math.copysign(1.0, cell.turn_heading_offset_rad)
    )
    outcome_failures = list(failures)
    if not signed_yaw_response_passed:
        outcome_failures.append("R23D13_SIGNED_YAW_RESPONSE")
    return {
        "walking_and_taper_gate_passed": walking_and_taper_gate_passed,
        "turn_phase_yaw_delta_rad": yaw_delta,
        "signed_yaw_response_passed": signed_yaw_response_passed,
        "outcome_gate_passed": not outcome_failures,
        "failed_gate_ids": outcome_failures,
    }


def evaluate_entry(
    entry: Any,
    cell: design.Cell,
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    if not _source_commit(expected_source_commit):
        raise R23D13PhysicalEvaluationError(
            "R23D13_EXPECTED_SOURCE_COMMIT_INVALID"
        )
    evaluation = {
        "schema_version": CELL_EVALUATION_SCHEMA,
        "cell_id": cell.cell_id,
        "engine_id": cell.engine_id,
        "entry_kind": "invalid",
        "entry_valid": False,
        "execution_integrity_passed": False,
        "outcome": None,
        "failure_codes": [],
        "world_attempt_count": 0,
        "world_build_count": 0,
        "claims": copy.deepcopy(FALSE_CLAIMS),
    }
    if not isinstance(entry, dict):
        evaluation["failure_codes"] = ["R23D13_ENTRY_TYPE"]
        return evaluation
    if entry.get("schema_version") == FAILURE_SCHEMA:
        evaluation["entry_kind"] = "worker_failure"
        failures: list[str] = []
        if not _exact_keys(entry, FAILURE_FIELDS):
            failures.append("R23D13_FAILURE_FIELDS")
        failures.extend(_identity_failures(entry, cell, expected_source_commit))
        if (
            not isinstance(entry.get("failure_stage"), str)
            or not entry.get("failure_stage")
            or not isinstance(entry.get("failure_code"), str)
            or not entry.get("failure_code")
            or not _nonnegative_int(entry.get("world_attempt_count"))
            or not _nonnegative_int(entry.get("world_build_count"))
            or entry.get("world_build_count", 1) > entry.get("world_attempt_count", 0)
            or entry.get("claims") != FALSE_CLAIMS
        ):
            failures.append("R23D13_FAILURE_RECEIPT")
        evaluation["world_attempt_count"] = (
            entry.get("world_attempt_count", 0)
            if _nonnegative_int(entry.get("world_attempt_count"))
            else 0
        )
        evaluation["world_build_count"] = (
            entry.get("world_build_count", 0)
            if _nonnegative_int(entry.get("world_build_count"))
            else 0
        )
        evaluation["failure_codes"] = failures or [entry["failure_code"]]
        return evaluation

    evaluation["entry_kind"] = "cell_report"
    failures = []
    if not _exact_keys(entry, REPORT_FIELDS):
        failures.append("R23D13_REPORT_FIELDS")
    if entry.get("schema_version") != REPORT_SCHEMA:
        failures.append("R23D13_REPORT_SCHEMA")
    failures.extend(_identity_failures(entry, cell, expected_source_commit))
    trace_summary, artifact_failures = _validate_artifact(
        entry.get("trace_artifact"),
        cell,
        allow_test_artifacts=allow_test_artifacts,
    )
    failures.extend(artifact_failures)
    if (
        not _exact_keys(entry.get("trace_summary"), TRACE_SUMMARY_FIELDS)
        or entry.get("trace_summary") != trace_summary
    ):
        failures.append("R23D13_REPORT_TRACE_SUMMARY")

    replay = trace_summary.get("taper_outcome") if trace_summary else None
    execution = entry.get("execution")
    if not _exact_keys(execution, EXECUTION_FIELDS):
        failures.append("R23D13_REPORT_EXECUTION_FIELDS")
    elif not isinstance(replay, dict):
        failures.append("R23D13_REPORT_REPLAY_MISSING")
    else:
        expected_applications = (
            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
            + int(replay["active_native_application_count"])
        )
        if (
            execution.get("integrity_passed") is not True
            or execution.get("worker_failure_code") != ""
            or execution.get("controller_semantic_step_count")
            != design.CONTROLLER_STEPS
            or execution.get("terminal_quiescent_taper_step_count")
            != design.TERMINAL_STEPS
            or execution.get("validated_portable_command_count")
            != expected_applications
            or execution.get("native_actuation_application_count")
            != expected_applications
            or execution.get("post_handoff_native_actuation_application_count") != 0
            or execution.get("portable_impulse_violation_count") != 0
            or execution.get("world_attempt_count") != 1
            or execution.get("world_build_count") != 1
            or execution.get("trace_retained_before_terminal_entry") is not True
            or execution.get(
                "fixed_horizon_configuration_proved_before_fixture_insertion"
            )
            is not True
        ):
            failures.append("R23D13_REPORT_EXECUTION")

    measurements = entry.get("measurements")
    measurement_failures = _measurement_failures(measurements)
    failures.extend(measurement_failures)
    if (
        not measurement_failures
        and isinstance(execution, dict)
        and isinstance(replay, dict)
    ):
        for field in (
            "controller_semantic_step_count",
            "terminal_quiescent_taper_step_count",
            "validated_portable_command_count",
            "native_actuation_application_count",
            "post_handoff_native_actuation_application_count",
        ):
            if measurements[field] != execution.get(field):
                failures.append(f"R23D13_REPORT_MEASUREMENT_EXECUTION:{field}")
    if entry.get("claims") != FALSE_CLAIMS:
        failures.append("R23D13_REPORT_CLAIMS")
    evaluation["world_attempt_count"] = (
        execution.get("world_attempt_count", 0) if isinstance(execution, dict) else 0
    )
    evaluation["world_build_count"] = (
        execution.get("world_build_count", 0) if isinstance(execution, dict) else 0
    )
    if failures:
        evaluation["failure_codes"] = failures
        return evaluation
    evaluation["entry_valid"] = True
    evaluation["execution_integrity_passed"] = True
    evaluation["outcome"] = _outcome(cell, measurements, replay)
    return evaluation


def evaluate_stage_a_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    if not _source_commit(expected_source_commit):
        raise R23D13PhysicalEvaluationError(
            "R23D13_EXPECTED_SOURCE_COMMIT_INVALID"
        )
    cells = design.stage_a_cells()
    evaluations: list[dict[str, Any]] = []
    failures: list[str] = []
    if len(entries) != len(cells):
        failures.append("R23D13_STAGE_A_ENTRY_COUNT")
    for index, cell in enumerate(cells):
        if index >= len(entries):
            failures.append(f"R23D13_STAGE_A_MISSING:{cell.cell_id}")
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
        failures.append("R23D13_STAGE_A_EXTRA_ENTRY")
    supplied_ids = [
        str(entry.get("cell_id", "")) if isinstance(entry, dict) else ""
        for entry in entries
    ]
    if supplied_ids != [cell.cell_id for cell in cells]:
        failures.append("R23D13_STAGE_A_ORDER_OR_IDENTITY")
    if len(set(supplied_ids)) != len(supplied_ids):
        failures.append("R23D13_STAGE_A_DUPLICATE")
    selected = bool(evaluations) and not failures and all(
        evaluation["entry_valid"]
        and evaluation["outcome"]["outcome_gate_passed"]
        for evaluation in evaluations
    )
    valid = not failures
    return {
        "schema_version": STAGE_A_EVALUATION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "valid": valid,
        "classification": (
            "invalid_or_incomplete_stage_a"
            if not valid
            else "valid_selected_stage_a"
            if selected
            else "valid_none_stage_a"
        ),
        "selected_terminal_policy_id": (
            "INVALID"
            if not valid
            else design.POLICY_ID
            if selected
            else "NONE"
        ),
        "stage_b_launch_authorized": valid and selected,
        "cell_evaluations": evaluations,
        "failure_codes": failures,
        "world_attempt_count": sum(item["world_attempt_count"] for item in evaluations),
        "world_build_count": sum(item["world_build_count"] for item in evaluations),
        "claims": copy.deepcopy(FALSE_CLAIMS),
    }


def evaluate_complete_entries(
    stage_a_entries: Sequence[dict[str, Any]],
    stage_b_entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    stage_a = evaluate_stage_a_entries(
        stage_a_entries,
        expected_source_commit=expected_source_commit,
        allow_test_artifacts=allow_test_artifacts,
    )
    stage_b: dict[str, Any] | None = None
    classification = stage_a["classification"]
    failures = list(stage_a["failure_codes"])
    if not stage_a["valid"]:
        if stage_b_entries:
            failures.append("R23D13_STAGE_B_OPENED_AFTER_INVALID_STAGE_A")
        classification = "invalid_or_incomplete_complete_campaign"
    elif not stage_a["stage_b_launch_authorized"]:
        if stage_b_entries:
            failures.append("R23D13_STAGE_B_OPENED_AFTER_VALID_NONE")
            classification = "invalid_or_incomplete_complete_campaign"
        else:
            classification = "valid_none_stage_a"
    else:
        cells = design.stage_b_cells()
        evaluations: list[dict[str, Any]] = []
        stage_b_failures: list[str] = []
        if len(stage_b_entries) != len(cells):
            stage_b_failures.append("R23D13_STAGE_B_ENTRY_COUNT")
        for index, cell in enumerate(cells):
            if index >= len(stage_b_entries):
                stage_b_failures.append(f"R23D13_STAGE_B_MISSING:{cell.cell_id}")
                continue
            evaluation = evaluate_entry(
                stage_b_entries[index],
                cell,
                expected_source_commit=expected_source_commit,
                allow_test_artifacts=allow_test_artifacts,
            )
            evaluations.append(evaluation)
            stage_b_failures.extend(
                f"{failure}:{cell.cell_id}"
                for failure in evaluation["failure_codes"]
            )
        supplied_ids = [
            str(entry.get("cell_id", "")) if isinstance(entry, dict) else ""
            for entry in stage_b_entries
        ]
        if supplied_ids != [cell.cell_id for cell in cells]:
            stage_b_failures.append("R23D13_STAGE_B_ORDER_OR_IDENTITY")
        if len(set(supplied_ids)) != len(supplied_ids):
            stage_b_failures.append("R23D13_STAGE_B_DUPLICATE")
        outcome_failures = sum(
            item["entry_valid"] and not item["outcome"]["outcome_gate_passed"]
            for item in evaluations
        )
        stage_b_valid = not stage_b_failures
        classification = (
            "invalid_or_incomplete_complete_campaign"
            if not stage_b_valid
            else "valid_complete_positive"
            if outcome_failures == 0
            else "valid_complete_negative"
        )
        stage_b = {
            "valid": stage_b_valid,
            "classification": classification,
            "outcome_failure_count": outcome_failures,
            "cell_evaluations": evaluations,
            "failure_codes": stage_b_failures,
            "world_attempt_count": sum(
                item["world_attempt_count"] for item in evaluations
            ),
            "world_build_count": sum(item["world_build_count"] for item in evaluations),
        }
        failures.extend(stage_b_failures)
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "classification": classification,
        "stage_a": stage_a,
        "stage_b": stage_b,
        "failure_codes": failures,
        "world_attempt_count": stage_a["world_attempt_count"]
        + (stage_b["world_attempt_count"] if stage_b else 0),
        "world_build_count": stage_a["world_build_count"]
        + (stage_b["world_build_count"] if stage_b else 0),
        "claims": copy.deepcopy(FALSE_CLAIMS),
    }


def _load_entries(paths: Sequence[str]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for value in paths:
        try:
            entry = json.loads(Path(value).read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise R23D13PhysicalEvaluationError(
                f"R23D13_ENTRY_UNREADABLE:{Path(value).name}:{type(error).__name__}"
            ) from error
        if not isinstance(entry, dict):
            raise R23D13PhysicalEvaluationError(
                f"R23D13_ENTRY_NOT_OBJECT:{Path(value).name}"
            )
        entries.append(entry)
    return entries


def _load_manifest(path: Path) -> list[str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D13PhysicalEvaluationError(
            f"R23D13_MANIFEST_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise R23D13PhysicalEvaluationError("R23D13_MANIFEST_NOT_STRING_ARRAY")
    return value


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
    stage_a = commands.add_parser("evaluate-stage-a")
    stage_a.add_argument("--manifest", type=Path, required=True)
    stage_a.add_argument("--expected-source-commit", required=True)
    stage_a.add_argument("--allow-test-artifacts", action="store_true")
    complete = commands.add_parser("evaluate-complete")
    complete.add_argument("--stage-a-manifest", type=Path, required=True)
    complete.add_argument("--stage-b-manifest", type=Path, required=True)
    complete.add_argument("--expected-source-commit", required=True)
    complete.add_argument("--allow-test-artifacts", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
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
        elif args.command == "evaluate-stage-a":
            result = evaluate_stage_a_entries(
                _load_entries(_load_manifest(args.manifest)),
                expected_source_commit=args.expected_source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
        else:
            result = evaluate_complete_entries(
                _load_entries(_load_manifest(args.stage_a_manifest)),
                _load_entries(_load_manifest(args.stage_b_manifest)),
                expected_source_commit=args.expected_source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        subprocess.SubprocessError,
        design.R23D13TraceError,
        R23D13PhysicalEvaluationError,
    ) as error:
        print(
            "QSDK_R23D13_EVALUATOR_FAILURE "
            + json.dumps(
                {
                    "error": str(error),
                    "physical_acceptance_authority": False,
                },
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 1
    marker = (
        "QSDK_R23D13_STAGE_A_EVALUATION "
        if args.command == "evaluate-stage-a"
        else "QSDK_R23D13_COMPLETE_EVALUATION "
        if args.command == "evaluate-complete"
        else "QSDK_R23D13_TRACE_RETENTION "
    )
    print(marker + json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
