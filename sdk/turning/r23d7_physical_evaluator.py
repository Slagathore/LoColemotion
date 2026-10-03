
"""Cold trace retention and physical outcome evaluation for QSDK-R23D7.

The stage-zero module freezes the scientific question and supplies synthetic
design canaries.  This module is the separate production authority boundary:
it consumes content-addressed traces and terminal entries, recomputes every
execution/outcome gate, and never constructs a physics world.
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

import r23d7_terminal_stance as design


CAMPAIGN_ID = "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT"
GATE_ID = "QSDK-R23D7"
PREREGISTRATION_PATH = (
    ROOT / "r23d7_neutral_stance_preregistration_v1.json"
)
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d7_trace.ps1"

REPORT_SCHEMA = "sporespore_qsdk_r23d7_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d7_worker_failure_v1"
TRACE_ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d7_trace_retention_v1"
CELL_EVALUATION_SCHEMA = "sporespore_qsdk_r23d7_cell_evaluation_v1"
STAGE_A_EVALUATION_SCHEMA = "sporespore_qsdk_r23d7_stage_a_evaluation_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d7_complete_evaluation_v1"
GODOT_PREDICATE_SCHEMA = "sporespore_qsdk_r23d7_godot_execution_predicates_v1"

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
    "godot_execution_predicates",
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
    "raw_sdk_authority_summary",
    "godot_execution_predicates",
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
)
EXECUTION_FIELDS = (
    "integrity_passed",
    "worker_failure_code",
    "controller_semantic_step_count",
    "terminal_stance_step_count",
    "passive_settle_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "passive_native_actuation_application_count",
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
    "terminal_stance_step_count",
    "passive_settle_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "passive_native_actuation_application_count",
    "neutral_stance_receipt_count",
    "terminal_receipt_validation_failure_count",
    "first_all_four_contact_terminal_stance_step",
    "consecutive_all_four_contact_hold_step_count",
    "neutral_target_activation_command_count",
    "neutral_target_activation_failure_count",
    "neutral_target_transition_count",
    "neutral_target_transition_failure_count",
    "maximum_absolute_terminal_stance_joint_velocity_rad_s",
    "passive_settle_trace_row_count",
)
GODOT_RAW_FIELDS = (
    "engine_id",
    "world_attempt_count",
    "world_build_count",
    "controller_semantic_step_count",
    "terminal_stance_step_count",
    "passive_settle_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "passive_native_actuation_application_count",
    "trace_row_count",
    "fixed_horizon_configuration_proved_before_fixture_insertion",
)


class R23D7PhysicalEvaluationError(RuntimeError):
    """A terminal entry, trace, manifest, or aggregate is invalid."""


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


def _load_preregistration() -> dict[str, Any]:
    try:
        declaration = json.loads(PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D7PhysicalEvaluationError(
            f"R23D7_PREREGISTRATION_UNREADABLE:{type(error).__name__}"
        ) from error
    inheritance = declaration.get("inherited_unchanged_scientific_contract", {})
    if (
        declaration.get("schema_version")
        != "sporespore_qsdk_r23d7_neutral_stance_preregistration_v1"
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or declaration.get("authorization", {}).get("physical_execution_authorized")
        is not False
        or inheritance.get("fixture_changed") is not False
        or inheritance.get("turning_controller_policy_changed") is not False
        or inheritance.get("outcome_numeric_thresholds_changed") is not False
        or inheritance.get("stage_a_selector_changed") is not False
    ):
        raise R23D7PhysicalEvaluationError("R23D7_PREREGISTRATION_INVALID")
    return design.load_contract()


def _all_known_cells() -> list[design.Cell]:
    return design.all_cells()


def cell_for_identity(stage_id: str, cell_id: str) -> design.Cell:
    matches = [
        cell
        for cell in _all_known_cells()
        if cell.stage_id == stage_id and cell.cell_id == cell_id
    ]
    if len(matches) != 1:
        raise R23D7PhysicalEvaluationError(
            f"R23D7_CELL_IDENTITY_INVALID:{stage_id}:{cell_id}"
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
        raise R23D7PhysicalEvaluationError(
            f"R23D7_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, list):
        raise R23D7PhysicalEvaluationError("R23D7_TRACE_ROWS_NOT_ARRAY")
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
    """Validate and CAS-publish a complete trace before terminal entry."""

    _load_preregistration()
    cell = cell_for_identity(stage_id, cell_id)
    repo_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    if repo_root != REPO_ROOT.resolve():
        raise R23D7PhysicalEvaluationError("R23D7_REPO_ROOT_INVALID")
    if not attempt_root.exists() or not attempt_root.is_dir():
        raise R23D7PhysicalEvaluationError("R23D7_ATTEMPT_ROOT_MISSING")
    if not test_only:
        production_root = repo_root.parent / "SporeSpore_Evidence"
        if not _path_within(attempt_root, production_root):
            raise R23D7PhysicalEvaluationError(
                "R23D7_PRODUCTION_ATTEMPT_ROOT_NOT_DURABLE"
            )
        if evidence_root_override is not None:
            raise R23D7PhysicalEvaluationError(
                "R23D7_PRODUCTION_EVIDENCE_OVERRIDE_FORBIDDEN"
            )
    elif evidence_root_override is None:
        raise R23D7PhysicalEvaluationError("R23D7_TEST_EVIDENCE_ROOT_REQUIRED")

    rows = _read_rows_json(rows_json_path)
    summary = design.validate_trace(cell, rows)
    if not summary["ok"]:
        raise R23D7PhysicalEvaluationError(
            "R23D7_TRACE_INVALID:" + ",".join(summary["failure_codes"][:8])
        )
    canonical = _canonical_ndjson(rows)
    digest = "sha256:" + hashlib.sha256(canonical).hexdigest()
    if digest != summary["raw_sha256"] or len(canonical) != summary["byte_length"]:
        raise R23D7PhysicalEvaluationError("R23D7_TRACE_CANONICAL_RECEIPT_MISMATCH")

    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    canonical_path = trace_root / f"{cell.stage_id}__{cell.cell_id}.ndjson"
    canonical_path.write_bytes(canonical)
    if _raw_sha256(canonical_path) != digest:
        raise R23D7PhysicalEvaluationError("R23D7_TRACE_WRITE_MISMATCH")

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
    marker = "QSDK_R23D7_TRACE_CAS "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D7PhysicalEvaluationError(
            "R23D7_TRACE_CAS_PUBLICATION_FAILED:"
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
        raise R23D7PhysicalEvaluationError("R23D7_TRACE_CAS_RECEIPT_INVALID")
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
            raise R23D7PhysicalEvaluationError("R23D7_TRACE_NDJSON_TERMINATOR")
        rows = [json.loads(line.decode("utf-8")) for line in raw.splitlines()]
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D7PhysicalEvaluationError(
            f"R23D7_TRACE_NDJSON_UNREADABLE:{type(error).__name__}"
        ) from error
    if _canonical_ndjson(rows) != raw:
        raise R23D7PhysicalEvaluationError("R23D7_TRACE_NDJSON_NOT_CANONICAL")
    return rows


def _validate_artifact(
    artifact: Any,
    cell: design.Cell,
    *,
    allow_test_artifacts: bool,
) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    if not _exact_keys(artifact, TRACE_ARTIFACT_FIELDS):
        return {}, ["R23D7_TRACE_ARTIFACT_FIELDS"]
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
        failures.append("R23D7_TRACE_ARTIFACT_RECEIPT")
    payload = Path(str(artifact.get("payload_path", "")))
    manifest_path = Path(str(artifact.get("manifest_path", "")))
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return {}, failures + [
            f"R23D7_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"
        ]
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
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
        failures.append("R23D7_TRACE_ARTIFACT_BYTES")
    try:
        summary = design.validate_trace(cell, _parse_ndjson(payload))
    except R23D7PhysicalEvaluationError as error:
        failures.append(str(error))
        return {}, failures
    if not summary["ok"]:
        failures.extend(summary["failure_codes"])
    return summary, failures


def project_godot_execution_predicates(summary: Any) -> dict[str, Any]:
    """Project exact Godot/Jolt execution claims from raw worker counters."""

    raw = copy.deepcopy(summary) if isinstance(summary, dict) else {}
    exact_fields = _exact_keys(raw, GODOT_RAW_FIELDS)
    expected_commands = design.ACTIVE_STEPS * design.ACTUATOR_COUNT
    checks = {
        "raw_fields_exact": exact_fields,
        "engine_identity": raw.get("engine_id") == "godot_jolt",
        "one_world": raw.get("world_attempt_count") == 1
        and raw.get("world_build_count") == 1,
        "controller_horizon": raw.get("controller_semantic_step_count")
        == design.CONTROLLER_STEPS,
        "restoration_horizon": raw.get("terminal_stance_step_count")
        == design.RESTORATION_STEPS,
        "passive_horizon": raw.get("passive_settle_step_count")
        == design.PASSIVE_SETTLE_STEPS,
        "portable_command_count": raw.get("validated_portable_command_count")
        == expected_commands,
        "native_application_count": raw.get("native_actuation_application_count")
        == expected_commands,
        "passive_zero_application": raw.get(
            "passive_native_actuation_application_count"
        )
        == 0,
        "trace_horizon": raw.get("trace_row_count") == design.TOTAL_TRACE_STEPS,
        "fixed_horizon_preinsertion": raw.get(
            "fixed_horizon_configuration_proved_before_fixture_insertion"
        )
        is True,
    }
    return {
        "schema_version": GODOT_PREDICATE_SCHEMA,
        "raw_sdk_authority_summary": raw,
        "checks": checks,
        "ok": all(checks.values()),
        "physical_acceptance_authority": False,
    }


def _identity_failures(entry: dict[str, Any], cell: design.Cell) -> list[str]:

    if (
        entry.get("campaign_id") != CAMPAIGN_ID
        or entry.get("gate_id") != GATE_ID
        or entry.get("stage_id") != cell.stage_id
        or entry.get("cell_id") != cell.cell_id
        or entry.get("engine_id") != cell.engine_id
        or entry.get("arm_id") != cell.arm_id
        or not _finite(entry.get("turn_heading_offset_rad"))
        or not math.isclose(
            float(entry.get("turn_heading_offset_rad", math.nan)),
            cell.turn_heading_offset_rad,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        )
        or not _source_commit(entry.get("source_commit"))
    ):
        return ["R23D7_ENTRY_IDENTITY"]
    return []


def _measurement_failures(measurements: Any) -> list[str]:
    if not _exact_keys(measurements, MEASUREMENT_FIELDS):
        return ["R23D7_MEASUREMENT_FIELDS"]

    failures: list[str] = []
    for field in (
        "final_forward_displacement_m",
        "turn_phase_yaw_delta_rad",
        "maximum_absolute_requested_steering_fraction",
        "maximum_absolute_held_steering_fraction",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
        "maximum_absolute_terminal_stance_joint_velocity_rad_s",
    ):
        if not _finite(measurements[field]):
            failures.append(f"R23D7_MEASUREMENT_FINITE:{field}")
    for field in (
        "torso_ground_contact_step_count",
        "controller_error_count",
        "active_safe_no_actuation_count",
        "nonfinite_observation_count",
        "actuator_application_mismatch_count",
        "controller_semantic_step_count",
        "terminal_stance_step_count",
        "passive_settle_step_count",
        "validated_portable_command_count",
        "native_actuation_application_count",
        "passive_native_actuation_application_count",
        "neutral_stance_receipt_count",
        "terminal_receipt_validation_failure_count",
        "first_all_four_contact_terminal_stance_step",
        "consecutive_all_four_contact_hold_step_count",
        "neutral_target_activation_command_count",
        "neutral_target_activation_failure_count",
        "neutral_target_transition_count",
        "neutral_target_transition_failure_count",
        "passive_settle_trace_row_count",
    ):
        if not _nonnegative_int(measurements[field]):
            failures.append(f"R23D7_MEASUREMENT_COUNT:{field}")
    contacts = measurements["contact_cycle_count_by_limb"]
    if (
        not isinstance(contacts, dict)
        # Reports cross a canonical JSON boundary. Object keys therefore
        # arrive in lexical order even when scheduler order differs.
        or list(contacts) != sorted(design.LIMB_IDS)
        or any(not _nonnegative_int(contacts.get(limb)) for limb in design.LIMB_IDS)
    ):
        failures.append("R23D7_MEASUREMENT_CONTACT_CYCLES")
    return failures


def _outcome(cell: design.Cell, measurements: dict[str, Any]) -> dict[str, Any]:
    contract = _load_preregistration()
    gates = contract["frozen_schedule_and_gate_snapshot"]
    failures: list[str] = []
    steering_limit = float(
        gates["maximum_absolute_requested_or_held_steering_fraction"]
    )
    if max(
        abs(float(measurements["maximum_absolute_requested_steering_fraction"])),
        abs(float(measurements["maximum_absolute_held_steering_fraction"])),
    ) > steering_limit + 1.0e-12:
        failures.append("R23D7_STEERING_LIMIT")
    if float(measurements["final_forward_displacement_m"]) < float(
        gates["minimum_final_forward_displacement_m"]
    ):
        failures.append("R23D7_FORWARD_DISPLACEMENT")
    if float(measurements["maximum_tilt_rad"]) > float(gates["maximum_tilt_rad"]):
        failures.append("R23D7_MAXIMUM_TILT")
    if float(measurements["minimum_torso_height_m"]) < float(
        gates["minimum_torso_height_m"]
    ):
        failures.append("R23D7_MINIMUM_TORSO_HEIGHT")
    minimum_cycles = int(gates["minimum_contact_cycles_per_limb"])
    for limb in design.LIMB_IDS:
        if measurements["contact_cycle_count_by_limb"][limb] < minimum_cycles:
            failures.append(f"R23D7_CONTACT_CYCLES:{limb}")

    expected_active_commands = design.ACTIVE_STEPS * design.ACTUATOR_COUNT
    count_gates = (
        ("torso_ground_contact_step_count", 0, "R23D7_TORSO_GROUND_CONTACT"),
        ("controller_error_count", 0, "R23D7_CONTROLLER_ERROR"),
        ("active_safe_no_actuation_count", 0, "R23D7_ACTIVE_SAFE_NO_ACTUATION"),
        ("nonfinite_observation_count", 0, "R23D7_NONFINITE_OBSERVATION"),
        (
            "actuator_application_mismatch_count",
            0,
            "R23D7_ACTUATOR_APPLICATION_MISMATCH",
        ),
        ("controller_semantic_step_count", design.CONTROLLER_STEPS, "R23D7_CONTROLLER_HORIZON"),
        ("terminal_stance_step_count", design.RESTORATION_STEPS, "R23D7_TERMINAL_STANCE_HORIZON"),
        ("passive_settle_step_count", design.PASSIVE_SETTLE_STEPS, "R23D7_PASSIVE_HORIZON"),
        ("validated_portable_command_count", expected_active_commands, "R23D7_VALIDATED_COMMAND_COUNT"),
        ("native_actuation_application_count", expected_active_commands, "R23D7_NATIVE_APPLICATION_COUNT"),
        ("passive_native_actuation_application_count", 0, "R23D7_PASSIVE_NATIVE_APPLICATION"),
        ("neutral_stance_receipt_count", design.RESTORATION_STEPS, "R23D7_NEUTRAL_STANCE_RECEIPT_COUNT"),
        ("terminal_receipt_validation_failure_count", 0, "R23D7_RESTORATION_RECEIPT_VALIDATION"),
        ("neutral_target_activation_command_count", design.RESTORATION_STEPS * design.ACTUATOR_COUNT, "R23D7_NEUTRAL_TARGET_COMMAND_COUNT"),
        ("neutral_target_activation_failure_count", 0, "R23D7_NEUTRAL_TARGET_ACTIVATION_VALIDATION"),
        ("neutral_target_transition_failure_count", 0, "R23D7_NEUTRAL_TARGET_TRANSITION_VALIDATION"),
        ("passive_settle_trace_row_count", design.PASSIVE_SETTLE_STEPS, "R23D7_PASSIVE_TRACE_ROWS"),
    )
    for field, expected, gate_id in count_gates:
        if measurements[field] != expected:
            failures.append(gate_id)
    first_contact = measurements["first_all_four_contact_terminal_stance_step"]
    if not (0 <= first_contact < design.CONTACT_ACQUISITION_STEPS):
        failures.append("R23D7_CONTACT_ACQUISITION")
    if measurements["consecutive_all_four_contact_hold_step_count"] < int(
        gates["required_consecutive_all_four_contact_hold_steps"]
    ):
        failures.append("R23D7_CONTACT_HOLD")
    if measurements["neutral_target_transition_count"] != design.ACTUATOR_COUNT:
        failures.append("R23D7_NEUTRAL_TARGET_TRANSITIONS")
    max_joint_speed = float(
        contract["frozen_schedule_and_gate_snapshot"][
            "maximum_absolute_terminal_stance_joint_velocity_rad_s"
        ]
    )
    if (
        float(measurements["maximum_absolute_terminal_stance_joint_velocity_rad_s"])
        > max_joint_speed + 1.0e-12
    ):
        failures.append("R23D7_TERMINAL_STANCE_JOINT_VELOCITY")

    walking_and_restoration_gate_passed = not failures
    yaw_delta = float(measurements["turn_phase_yaw_delta_rad"])
    signed_yaw_response_passed = cell.arm_id == "reference_zero" or (
        abs(yaw_delta)
        >= float(gates["minimum_absolute_signed_turn_phase_yaw_delta_rad"])
        and math.copysign(1.0, yaw_delta)
        == math.copysign(1.0, cell.turn_heading_offset_rad)
    )
    outcome_failures = list(failures)
    if not signed_yaw_response_passed:
        outcome_failures.append("R23D7_SIGNED_YAW_RESPONSE")
    return {
        "walking_and_restoration_gate_passed": walking_and_restoration_gate_passed,
        "turn_phase_yaw_delta_rad": yaw_delta,
        "signed_yaw_response_passed": signed_yaw_response_passed,
        "outcome_gate_passed": not outcome_failures,
        "failed_gate_ids": outcome_failures,
    }


def evaluate_entry(
    entry: Any,
    cell: design.Cell,
    *,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
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
        evaluation["failure_codes"] = ["R23D7_ENTRY_TYPE"]
        return evaluation
    if entry.get("schema_version") == FAILURE_SCHEMA:
        evaluation["entry_kind"] = "worker_failure"
        failures: list[str] = []
        if not _exact_keys(entry, FAILURE_FIELDS):
            failures.append("R23D7_FAILURE_FIELDS")
        failures.extend(_identity_failures(entry, cell))
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
            failures.append("R23D7_FAILURE_RECEIPT")

        if cell.engine_id == "godot_jolt" and entry.get("world_build_count") == 1:
            projected = project_godot_execution_predicates(
                entry.get("raw_sdk_authority_summary")
            )
            if entry.get("godot_execution_predicates") != projected:
                failures.append("R23D7_FAILURE_GODOT_PREDICATES")
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
        failures.append("R23D7_REPORT_FIELDS")
    if entry.get("schema_version") != REPORT_SCHEMA:
        failures.append("R23D7_REPORT_SCHEMA")
    failures.extend(_identity_failures(entry, cell))
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
        failures.append("R23D7_REPORT_TRACE_SUMMARY")

    execution = entry.get("execution")
    expected_active_commands = design.ACTIVE_STEPS * design.ACTUATOR_COUNT
    if not _exact_keys(execution, EXECUTION_FIELDS):
        failures.append("R23D7_REPORT_EXECUTION_FIELDS")
    elif (
        execution.get("integrity_passed") is not True
        or execution.get("worker_failure_code") != ""
        or execution.get("controller_semantic_step_count") != design.CONTROLLER_STEPS
        or execution.get("terminal_stance_step_count") != design.RESTORATION_STEPS

        or execution.get("passive_settle_step_count") != design.PASSIVE_SETTLE_STEPS
        or execution.get("validated_portable_command_count") != expected_active_commands
        or execution.get("native_actuation_application_count") != expected_active_commands
        or execution.get("passive_native_actuation_application_count") != 0
        or execution.get("portable_impulse_violation_count") != 0
        or execution.get("world_attempt_count") != 1
        or execution.get("world_build_count") != 1
        or execution.get("trace_retained_before_terminal_entry") is not True
        or execution.get("fixed_horizon_configuration_proved_before_fixture_insertion")
        is not True
    ):
        failures.append("R23D7_REPORT_EXECUTION")

    measurements = entry.get("measurements")
    measurement_failures = _measurement_failures(measurements)
    failures.extend(measurement_failures)
    if not measurement_failures and isinstance(execution, dict):
        for field in (
            "controller_semantic_step_count",
            "terminal_stance_step_count",
            "passive_settle_step_count",
            "validated_portable_command_count",
            "native_actuation_application_count",
            "passive_native_actuation_application_count",
        ):
            if measurements[field] != execution.get(field):
                failures.append(f"R23D7_REPORT_MEASUREMENT_EXECUTION:{field}")
        if measurements["neutral_stance_receipt_count"] != design.RESTORATION_STEPS:
            failures.append("R23D7_REPORT_NEUTRAL_STANCE_RECEIPTS")

    if cell.engine_id == "godot_jolt":
        predicates = entry.get("godot_execution_predicates")
        if (
            not isinstance(predicates, dict)
            or predicates
            != project_godot_execution_predicates(
                predicates.get("raw_sdk_authority_summary")
            )
            or predicates.get("ok") is not True
        ):
            failures.append("R23D7_REPORT_GODOT_PREDICATES")
    elif entry.get("godot_execution_predicates") is not None:
        failures.append("R23D7_REPORT_UNEXPECTED_GODOT_PREDICATES")
    if entry.get("claims") != FALSE_CLAIMS:
        failures.append("R23D7_REPORT_CLAIMS")

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
    evaluation["outcome"] = _outcome(cell, measurements)
    return evaluation


def evaluate_stage_a_entries(
    entries: Sequence[dict[str, Any]],
    *,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    cells = design.stage_a_cells()
    evaluations: list[dict[str, Any]] = []
    failures: list[str] = []
    if len(entries) != len(cells):
        failures.append("R23D7_STAGE_A_ENTRY_COUNT")
    for index, cell in enumerate(cells):
        if index >= len(entries):
            failures.append(f"R23D7_STAGE_A_MISSING:{cell.cell_id}")
            continue
        evaluation = evaluate_entry(
            entries[index], cell, allow_test_artifacts=allow_test_artifacts
        )
        evaluations.append(evaluation)
        failures.extend(
            f"{failure}:{cell.cell_id}" for failure in evaluation["failure_codes"]
        )
    if len(entries) > len(cells):
        failures.append("R23D7_STAGE_A_EXTRA_ENTRY")
    supplied_ids = [
        str(entry.get("cell_id", "")) if isinstance(entry, dict) else ""
        for entry in entries
    ]
    if supplied_ids != [cell.cell_id for cell in cells]:
        failures.append("R23D7_STAGE_A_ORDER_OR_IDENTITY")
    if len(set(supplied_ids)) != len(supplied_ids):
        failures.append("R23D7_STAGE_A_DUPLICATE")

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
        "selected_terminal_restoration_policy_id": (
            "INVALID"
            if not valid
            else design.RESTORATION_POLICY_ID
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
    allow_test_artifacts: bool = False,

) -> dict[str, Any]:
    stage_a = evaluate_stage_a_entries(
        stage_a_entries, allow_test_artifacts=allow_test_artifacts
    )
    stage_b: dict[str, Any] | None = None
    classification = stage_a["classification"]
    failures = list(stage_a["failure_codes"])
    if not stage_a["valid"]:
        if stage_b_entries:
            failures.append("R23D7_STAGE_B_OPENED_AFTER_INVALID_STAGE_A")
        classification = "invalid_or_incomplete_complete_campaign"
    elif not stage_a["stage_b_launch_authorized"]:
        if stage_b_entries:
            failures.append("R23D7_STAGE_B_OPENED_AFTER_VALID_NONE")
            classification = "invalid_or_incomplete_complete_campaign"
        else:
            classification = "valid_none_stage_a"
    else:
        cells = design.stage_b_cells()
        evaluations: list[dict[str, Any]] = []
        stage_b_failures: list[str] = []
        if len(stage_b_entries) != len(cells):
            stage_b_failures.append("R23D7_STAGE_B_ENTRY_COUNT")
        for index, cell in enumerate(cells):
            if index >= len(stage_b_entries):
                stage_b_failures.append(f"R23D7_STAGE_B_MISSING:{cell.cell_id}")
                continue
            evaluation = evaluate_entry(
                stage_b_entries[index],
                cell,
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
            stage_b_failures.append("R23D7_STAGE_B_ORDER_OR_IDENTITY")
        if len(set(supplied_ids)) != len(supplied_ids):
            stage_b_failures.append("R23D7_STAGE_B_DUPLICATE")
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
            "world_build_count": sum(
                item["world_build_count"] for item in evaluations
            ),
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
            raise R23D7PhysicalEvaluationError(
                f"R23D7_ENTRY_UNREADABLE:{Path(value).name}:{type(error).__name__}"
            ) from error
        if not isinstance(entry, dict):
            raise R23D7PhysicalEvaluationError(
                f"R23D7_ENTRY_NOT_OBJECT:{Path(value).name}"
            )
        entries.append(entry)
    return entries


def _load_manifest(path: Path) -> list[str]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D7PhysicalEvaluationError(
            f"R23D7_EVALUATION_MANIFEST_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise R23D7PhysicalEvaluationError("R23D7_EVALUATION_MANIFEST_INVALID")
    if not value and raw != b"[]\n":
        raise R23D7PhysicalEvaluationError("R23D7_EMPTY_MANIFEST_BYTES_INVALID")

    return value


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", required=True)
    retain.add_argument("--repo-root", required=True)
    retain.add_argument("--attempt-root", required=True)
    retain.add_argument("--powershell", default="pwsh")
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override")
    stage_a = commands.add_parser("evaluate-stage-a")
    stage_a.add_argument("--manifest", required=True)
    stage_a.add_argument("--allow-test-artifacts", action="store_true")
    complete = commands.add_parser("evaluate-complete")
    complete.add_argument("--stage-a-manifest", required=True)
    complete.add_argument("--stage-b-manifest", required=True)
    complete.add_argument("--allow-test-artifacts", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(list(sys.argv[1:] if argv is None else argv))
    try:
        if args.command == "retain-trace":
            receipt = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=Path(args.rows_json),
                repo_root=Path(args.repo_root),
                attempt_root=Path(args.attempt_root),
                powershell=args.powershell,
                test_only=bool(args.test_only),
                evidence_root_override=(
                    Path(args.evidence_root_override)
                    if args.evidence_root_override
                    else None
                ),
            )
            print(
                "QSDK_R23D7_TRACE_RETAINED "
                + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        if args.command == "evaluate-stage-a":
            result = evaluate_stage_a_entries(
                _load_entries(_load_manifest(Path(args.manifest))),
                allow_test_artifacts=bool(args.allow_test_artifacts),
            )
            print(
                "QSDK_R23D7_STAGE_A_EVALUATION "
                + json.dumps(result, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0 if result["valid"] else 1
        stage_a_paths = _load_manifest(Path(args.stage_a_manifest))
        stage_b_paths = _load_manifest(Path(args.stage_b_manifest))
        result = evaluate_complete_entries(

            _load_entries(stage_a_paths),
            _load_entries(stage_b_paths),
            allow_test_artifacts=bool(args.allow_test_artifacts),
        )
        print(
            "QSDK_R23D7_COMPLETE_EVALUATION "
            + json.dumps(result, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return (
            0
            if not result["classification"].startswith("invalid_or_incomplete")
            else 1
        )
    except (
        R23D7PhysicalEvaluationError,
        design.R23D7Error,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        TypeError,
        ValueError,
        OverflowError,
        subprocess.SubprocessError,
    ) as error:
        print(
            f"QSDK_R23D7_PHYSICAL_EVALUATOR_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
