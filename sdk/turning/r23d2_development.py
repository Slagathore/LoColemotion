"""Shared evaluator for the exact-finite QSDK-R23D2 development screen.

This module is intentionally independent of the closed R23D1 evaluator.  It
preserves the unchanged nine-cell question, uses the separately preregistered
R23D2 receipt oracle, distinguishes valid physical negatives from invalid
execution, and sums worker-reported attempt/build counts.  Nothing in this
module launches physics or authorizes a physical process.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable

try:
    from . import r23d2_oracle
except ImportError:  # pragma: no cover - direct script execution
    import r23d2_oracle  # type: ignore[no-redef]


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
CONTRACT_PATH = ROOT / "r23d2_development_contract_v1.json"
SUCCESS_REPORT_SCHEMA = "sporespore_qsdk_r23d2_engine_cell_report_v1"
WORKER_FAILURE_SCHEMA = "sporespore_qsdk_r23d2_worker_failure_v1"
COMMAND_VALIDATION_SCHEMA = "sporespore_qsdk_r23d2_command_validation_v1"
EXECUTION_STAGE_SCHEMA = "sporespore_qsdk_r23d2_execution_stage_v1"
AGGREGATE_SCHEMA = "sporespore_qsdk_r23d2_aggregate_evaluation_v1"
CAMPAIGN_ID = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
GATE_ID = "QSDK-R23D2"


class R23D2DevelopmentError(RuntimeError):
    """The R23D2 contract, terminal entry, or aggregate is invalid."""


def _raw_sha256(path: Path) -> str:
    try:
        return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        raise R23D2DevelopmentError(
            f"R23D2_SOURCE_UNREADABLE:{path.name}:{type(error).__name__}"
        ) from error


def _canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def _repo_path(relative: str) -> Path:
    candidate = (REPO_ROOT / relative).resolve()
    try:
        candidate.relative_to(REPO_ROOT)
    except ValueError as error:
        raise R23D2DevelopmentError(
            f"R23D2_PATH_ESCAPES_REPOSITORY:{relative}"
        ) from error
    return candidate


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _exact_keys(value: Any, expected: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(expected)


def _oracle_evaluations_equivalent(
    supplied: Any,
    recomputed: Any,
    profile: Any,
) -> bool:
    evaluation_keys = (
        "schema_version",
        "ok",
        "failed_predicates",
        "expected_receipt",
        "world_build_count",
        "physical_acceptance_authority",
    )
    if (
        not _exact_keys(supplied, evaluation_keys)
        or not _exact_keys(recomputed, evaluation_keys)
        or not isinstance(profile, dict)
        or supplied.get("schema_version")
        != "sporespore_qsdk_r23d2_oracle_evaluation_v1"
        or supplied.get("schema_version") != recomputed.get("schema_version")
        or supplied.get("ok") is not recomputed.get("ok")
        or supplied.get("failed_predicates") != recomputed.get("failed_predicates")
        or supplied.get("world_build_count") != recomputed.get("world_build_count")
        or supplied.get("physical_acceptance_authority")
        is not recomputed.get("physical_acceptance_authority")
        or not _exact_keys(
            supplied.get("expected_receipt"), r23d2_oracle.RECEIPT_FIELDS
        )
        or not _exact_keys(
            recomputed.get("expected_receipt"), r23d2_oracle.RECEIPT_FIELDS
        )
    ):
        return False
    tolerance = profile.get("comparison_absolute_tolerance")
    if not _finite_number(tolerance) or float(tolerance) < 0.0:
        return False
    supplied_receipt = supplied["expected_receipt"]
    recomputed_receipt = recomputed["expected_receipt"]
    return all(
        _finite_number(supplied_receipt.get(field))
        and _finite_number(recomputed_receipt.get(field))
        and math.isclose(
            float(supplied_receipt[field]),
            float(recomputed_receipt[field]),
            rel_tol=0.0,
            abs_tol=float(tolerance),
        )
        for field in r23d2_oracle.RECEIPT_FIELDS
    )


def load_contract() -> dict[str, Any]:
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise R23D2DevelopmentError(
            f"R23D2_CONTRACT_UNREADABLE:{type(error).__name__}"
        ) from error

    lineage = contract.get("lineage", {})
    normalized = contract.get("normalized_entry_contract", {})
    evaluator = contract.get("production_evaluator", {})
    oracle_validation = contract.get("oracle_validation", {})
    authorization = contract.get("authorization", {})
    claims = contract.get("claim_boundary", {})
    engines = contract.get("engines", [])
    expected_engines = {
        "godot_jolt": (
            "sha256:42e24e52dad30eda8a44d052bd56be069d48cd7a78a834e027935c8dc5ddb04d",
            "sdk/run_qsdk_r23d2_godot_jolt_worker_preflight.ps1",
        ),
        "rapier_parry": (
            "sha256:15815f8fe7e167c36bed1ae9c161b5fadec9da1dbf3ddc3c5180f4e016ecdf29",
            "sdk/run_qsdk_r23d2_rapier_worker_preflight.ps1",
        ),
        "mujoco": (
            "sha256:1af7cb45c7de3af9d773701038b75b7b19f7208663eb160c9c13dbe97bcd3184",
            "sdk/run_qsdk_r23d2_mujoco_worker_preflight.ps1",
        ),
    }
    observed_engines = {
        str(engine.get("engine_id")): (
            str(engine.get("worker_contract_sha256")),
            str(engine.get("zero_world_preflight_path")),
        )
        for engine in engines
    }
    if (
        contract.get("schema_version")
        != "sporespore_qsdk_r23d2_development_contract_v1"
        or contract.get("status")
        != "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation"
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("release_gate_id") != "QSDK-R23"
        or contract.get("study_classification")
        != "exact_finite_outcome_exposed_implementation_recovery_development_screen"
        or observed_engines != expected_engines
        or any(engine.get("zero_world_commissioned") is not True for engine in engines)
        or [engine.get("physical_implementation_present") for engine in engines]
        != [True, True, True]
        or claims.get("physical_worker_implementation_count") != 3
        or normalized.get("successful_report_schema_version") != SUCCESS_REPORT_SCHEMA
        or normalized.get("worker_failure_schema_version") != WORKER_FAILURE_SCHEMA
        or normalized.get("command_validation_schema_version")
        != COMMAND_VALIDATION_SCHEMA
        or normalized.get("execution_stage_schema_version") != EXECUTION_STAGE_SCHEMA
        or normalized.get("aggregate_evaluation_schema_version") != AGGREGATE_SCHEMA
        or evaluator.get("independent_from_closed_r23d1_evaluator") is not True
        or evaluator.get("imports_closed_r23d1_evaluator") is not False
        or oracle_validation.get(
            "cross_language_evaluation_structural_fields_and_failed_predicates_exact"
        )
        is not True
        or oracle_validation.get(
            "cross_language_expected_receipt_uses_profile_absolute_tolerance"
        )
        is not True
        or oracle_validation.get(
            "rejected_projection_canonicalized_before_embedding_and_hashing"
        )
        is not True
        or authorization.get("physical_execution_authorized") is not True
        or authorization.get("physical_process_launch_count") != 0
        or authorization.get("world_attempt_count") != 0
        or authorization.get("world_build_count") != 0
        or claims.get("command_conditioned_turning") is not False
        or claims.get("q_sdk_r23_satisfied") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("physical_acceptance_authority") is not False
    ):
        raise R23D2DevelopmentError("R23D2_DEVELOPMENT_CONTRACT_IDENTITY_INVALID")

    bindings = (
        (lineage["stage_zero_oracle_path"], lineage["stage_zero_oracle_sha256"]),
        (lineage["predecessor_contract_path"], lineage["predecessor_contract_sha256"]),
        (lineage["predecessor_closure_path"], lineage["predecessor_closure_sha256"]),
        *(
            (engine["worker_contract_path"], engine["worker_contract_sha256"])
            for engine in engines
        ),
    )
    for relative, expected_sha256 in bindings:
        if _raw_sha256(_repo_path(str(relative))) != expected_sha256:
            raise R23D2DevelopmentError(f"R23D2_BOUND_SOURCE_CHANGED:{relative}")

    oracle = r23d2_oracle.load_contract()
    if (
        _raw_sha256(r23d2_oracle.CONTRACT_PATH)
        != contract["oracle_validation"]["oracle_contract_sha256"]
        or oracle["campaign_id"] != CAMPAIGN_ID
        or oracle["gate_id"] != GATE_ID
        or oracle["selected_profile_oracle"]["required_receipt_predicates"]
        != contract["oracle_validation"]["required_receipt_predicates"]
    ):
        raise R23D2DevelopmentError("R23D2_ORACLE_BINDING_INVALID")
    return contract


def contract_sha256() -> str:
    return _raw_sha256(CONTRACT_PATH)


def compile_cell_matrix(contract: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    contract = load_contract() if contract is None else contract
    matrix = [
        {
            "ordinal": ordinal,
            "cell_id": f"{engine['engine_id']}__{arm['arm_id']}",
            "engine_id": engine["engine_id"],
            "arm_id": arm["arm_id"],
            "turn_heading_offset_rad": arm["turn_heading_offset_rad"],
        }
        for ordinal, (engine, arm) in enumerate(
            (
                (engine, arm)
                for engine in contract["engines"]
                for arm in contract["arms"]
            ),
            start=1,
        )
    ]
    declared = contract["cell_matrix"]
    if (
        len(matrix) != declared["declared_cell_count"]
        or len(contract["engines"]) != declared["engine_count"]
        or len(contract["arms"]) != declared["arm_count"]
        or len({cell["cell_id"] for cell in matrix}) != len(matrix)
        or declared["execution_order"] != "engine_order_then_arm_order"
        or declared["all_cells_execute_without_early_stop"] is not True
        or declared["replacement_or_selective_rerun_permitted"] is not False
    ):
        raise R23D2DevelopmentError("R23D2_CELL_MATRIX_INVALID")
    return matrix


def _arm(arm_id: str, contract: dict[str, Any]) -> dict[str, Any]:
    matches = [arm for arm in contract["arms"] if arm["arm_id"] == arm_id]
    if len(matches) != 1:
        raise R23D2DevelopmentError(f"R23D2_ARM_UNKNOWN:{arm_id}")
    return matches[0]


def heading_offset_for_step(
    arm_id: str,
    semantic_step: int,
    contract: dict[str, Any] | None = None,
) -> tuple[str, float]:
    contract = load_contract() if contract is None else contract
    if (
        isinstance(semantic_step, bool)
        or not isinstance(semantic_step, int)
        or semantic_step < 0
    ):
        raise R23D2DevelopmentError("R23D2_SEMANTIC_STEP_INVALID")
    arm = _arm(arm_id, contract)
    for segment in contract["command_schedule"]["segments"]:
        if (
            segment["start_step_inclusive"]
            <= semantic_step
            < segment["end_step_exclusive"]
        ):
            offset = (
                0.0
                if segment["heading_offset_source"] == "zero"
                else float(arm["turn_heading_offset_rad"])
            )
            return segment["segment_id"], offset
    return "reference_continuation", 0.0


def _valid_source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def _claims() -> dict[str, bool]:
    return {
        "development_screen_only": True,
        "q_sdk_r23_satisfied": False,
        "command_conditioned_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def _cell_evaluation(
    cell_id: str,
    integrity_failures: list[str],
    outcome_failures: list[str],
) -> dict[str, Any]:
    execution_valid = not integrity_failures
    screen_cell_passed = execution_valid and not outcome_failures
    classification = (
        "invalid"
        if not execution_valid
        else "valid_positive" if screen_cell_passed else "valid_negative"
    )
    return {
        "schema_version": "sporespore_qsdk_r23d2_cell_evaluation_v1",
        "cell_id": cell_id,
        "entry_kind": "successful_report",
        "entry_valid": execution_valid,
        "execution_valid": execution_valid,
        "screen_cell_passed": screen_cell_passed,
        "result_classification": classification,
        "integrity_failure_count": len(integrity_failures),
        "integrity_failure_codes": integrity_failures,
        "outcome_failure_count": len(outcome_failures),
        "outcome_failure_codes": outcome_failures,
        "failed_gate_count": len(integrity_failures) + len(outcome_failures),
        "failure_codes": [*integrity_failures, *outcome_failures],
        "world_attempt_count": 1,
        "world_build_count": 1,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def evaluate_cell(
    report: dict[str, Any], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Cold-evaluate one complete physical report.

    Structural/controller/oracle defects are execution-integrity failures.
    Finite physical measurements that miss frozen locomotion gates are valid
    negatives and remain distinct from implementation invalidity.
    """

    contract = load_contract() if contract is None else contract
    matrix = {cell["cell_id"]: cell for cell in compile_cell_matrix(contract)}
    integrity: list[str] = []
    outcome: list[str] = []

    def require_integrity(condition: bool, code: str) -> None:
        if not condition:
            integrity.append(code)

    def require_outcome(condition: bool, code: str) -> None:
        if not condition:
            outcome.append(code)

    top_keys = (
        "schema_version",
        "campaign_id",
        "gate_id",
        "cell_id",
        "engine_id",
        "arm_id",
        "source_commit",
        "contract_sha256",
        "selected_policy_id",
        "selected_policy_digest",
        "morphology_id",
        "campaign_seed",
        "execution",
        "execution_stage",
        "command_validation",
        "schedule",
        "controller",
        "physics",
        "claims",
    )
    require_integrity(_exact_keys(report, top_keys), "R23D2_REPORT_KEYS")
    cell_id = str(report.get("cell_id", ""))
    expected = matrix.get(cell_id)
    require_integrity(expected is not None, "R23D2_CELL_ID_UNKNOWN")
    if expected is None:
        return _cell_evaluation(cell_id, integrity, outcome)

    source = contract["source_contract"]
    fixture = contract["fixture"]
    detection = contract["development_detection_gates"]
    normalized = contract["normalized_entry_contract"]
    execution = report.get("execution", {})
    stage = report.get("execution_stage", {})
    validation = report.get("command_validation", {})
    schedule = report.get("schedule", {})
    controller = report.get("controller", {})
    physics = report.get("physics", {})

    require_integrity(
        report.get("schema_version") == SUCCESS_REPORT_SCHEMA, "R23D2_SCHEMA"
    )
    require_integrity(report.get("campaign_id") == CAMPAIGN_ID, "R23D2_CAMPAIGN")
    require_integrity(report.get("gate_id") == GATE_ID, "R23D2_GATE")
    require_integrity(report.get("engine_id") == expected["engine_id"], "R23D2_ENGINE")
    require_integrity(report.get("arm_id") == expected["arm_id"], "R23D2_ARM")
    require_integrity(
        report.get("selected_policy_id") == source["selected_policy_id"], "R23D2_POLICY"
    )
    require_integrity(
        report.get("selected_policy_digest") == source["selected_policy_digest"],
        "R23D2_POLICY_DIGEST",
    )
    require_integrity(
        report.get("morphology_id") == fixture["morphology_id"], "R23D2_MORPHOLOGY"
    )
    require_integrity(
        report.get("campaign_seed") == fixture["initial_condition_seed"],
        "R23D2_CAMPAIGN_SEED",
    )
    require_integrity(
        report.get("contract_sha256") == contract_sha256(), "R23D2_CONTRACT_DIGEST"
    )
    require_integrity(
        _valid_source_commit(report.get("source_commit")), "R23D2_SOURCE_COMMIT"
    )

    execution_keys = (
        "world_attempt_count",
        "world_build_count",
        "world_reset_count",
        "direct_body_write_count",
        "controller_error_count",
        "safe_no_actuation_count",
        "nonfinite_observation_count",
        "actuator_application_mismatch_count",
        "controller_semantic_step_count",
        "validated_portable_command_count",
        "native_actuation_application_count",
    )
    require_integrity(_exact_keys(execution, execution_keys), "R23D2_EXECUTION_KEYS")
    for field, value in {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "direct_body_write_count": 0,
        "controller_error_count": 0,
        "safe_no_actuation_count": 0,
        "nonfinite_observation_count": 0,
        "actuator_application_mismatch_count": 0,
    }.items():
        require_integrity(
            execution.get(field) == value, f"R23D2_EXECUTION_{field.upper()}"
        )
    step_count = execution.get("controller_semantic_step_count")
    require_integrity(
        _nonnegative_int(step_count)
        and step_count
        >= contract["command_schedule"]["minimum_required_controller_step_count"],
        "R23D2_CONTROLLER_HORIZON",
    )
    require_integrity(
        _nonnegative_int(step_count)
        and execution.get("validated_portable_command_count") == step_count * 8,
        "R23D2_PORTABLE_COMMAND_COUNT",
    )
    require_integrity(
        _nonnegative_int(step_count)
        and execution.get("native_actuation_application_count") == step_count * 8,
        "R23D2_NATIVE_APPLICATION_COUNT",
    )

    stage_keys = (
        "schema_version",
        "stage_id",
        "world_attempt_count",
        "world_build_count",
    )
    require_integrity(_exact_keys(stage, stage_keys), "R23D2_EXECUTION_STAGE_KEYS")
    require_integrity(
        stage.get("schema_version") == EXECUTION_STAGE_SCHEMA,
        "R23D2_EXECUTION_STAGE_SCHEMA",
    )
    require_integrity(
        stage.get("stage_id") == "cell_report_complete", "R23D2_EXECUTION_STAGE"
    )
    require_integrity(
        r23d2_oracle.validate_failure_provenance(
            str(stage.get("stage_id", "")),
            stage.get("world_attempt_count", -1),
            stage.get("world_build_count", -1),
        ),
        "R23D2_EXECUTION_STAGE_COUNTS",
    )
    require_integrity(
        stage.get("world_attempt_count") == execution.get("world_attempt_count")
        and stage.get("world_build_count") == execution.get("world_build_count"),
        "R23D2_EXECUTION_STAGE_PARITY",
    )

    validation_keys = (
        "schema_version",
        "normalized_validation_mode",
        "source_validation_mode",
        "native_validation_step_count",
        "heading_command_conditioned_step_count",
        "unconditioned_step_count",
        "legacy_command_parity_applicable",
        "legacy_command_parity_checked_step_count",
        "legacy_command_parity_waived_step_count",
        "oracle_contract_sha256",
        "independent_oracle_validation_step_count",
        "accepted_receipt_count",
        "rejected_receipt_count",
        "predicate_failure_count",
        "raw_heading_offset_equality_used",
    )
    require_integrity(
        _exact_keys(validation, validation_keys), "R23D2_COMMAND_VALIDATION_KEYS"
    )
    require_integrity(
        validation.get("schema_version") == COMMAND_VALIDATION_SCHEMA,
        "R23D2_COMMAND_VALIDATION_SCHEMA",
    )
    require_integrity(
        validation.get("normalized_validation_mode")
        == normalized["normalized_validation_mode"],
        "R23D2_COMMAND_VALIDATION_MODE",
    )
    require_integrity(
        isinstance(validation.get("source_validation_mode"), str)
        and bool(validation.get("source_validation_mode")),
        "R23D2_SOURCE_VALIDATION_MODE",
    )
    for field in (
        "native_validation_step_count",
        "heading_command_conditioned_step_count",
        "independent_oracle_validation_step_count",
        "accepted_receipt_count",
    ):
        require_integrity(
            _nonnegative_int(step_count) and validation.get(field) == step_count,
            f"R23D2_{field.upper()}",
        )
    require_integrity(
        validation.get("unconditioned_step_count") == 0,
        "R23D2_UNCONDITIONED_STEP_COUNT",
    )
    require_integrity(
        validation.get("legacy_command_parity_applicable") is False
        and validation.get("legacy_command_parity_checked_step_count") == 0
        and validation.get("legacy_command_parity_waived_step_count") == 0,
        "R23D2_LEGACY_PARITY_BOUNDARY",
    )
    require_integrity(
        validation.get("oracle_contract_sha256")
        == contract["oracle_validation"]["oracle_contract_sha256"],
        "R23D2_ORACLE_DIGEST",
    )
    require_integrity(
        validation.get("rejected_receipt_count") == 0, "R23D2_REJECTED_RECEIPT_COUNT"
    )
    require_integrity(
        validation.get("predicate_failure_count") == 0, "R23D2_PREDICATE_FAILURE_COUNT"
    )
    require_integrity(
        validation.get("raw_heading_offset_equality_used") is False,
        "R23D2_LEGACY_RAW_HEADING_ORACLE",
    )

    schedule_keys = (
        "schedule_id",
        "turn_heading_offset_rad",
        "observed_segment_sample_counts",
        "reference_heading_sample_count",
        "turn_heading_sample_count",
    )
    require_integrity(_exact_keys(schedule, schedule_keys), "R23D2_SCHEDULE_KEYS")
    require_integrity(
        schedule.get("schedule_id") == contract["command_schedule"]["schedule_id"],
        "R23D2_SCHEDULE_ID",
    )
    require_integrity(
        schedule.get("observed_segment_sample_counts")
        == contract["command_schedule"]["expected_segment_sample_counts"],
        "R23D2_SEGMENT_COUNTS",
    )
    require_integrity(
        _finite_number(schedule.get("turn_heading_offset_rad"))
        and math.isclose(
            float(schedule["turn_heading_offset_rad"]),
            float(expected["turn_heading_offset_rad"]),
            rel_tol=0.0,
            abs_tol=1e-15,
        ),
        "R23D2_TURN_COMMAND",
    )
    require_integrity(
        schedule.get("reference_heading_sample_count") == 1_200,
        "R23D2_REFERENCE_SAMPLE_COUNT",
    )
    require_integrity(
        schedule.get("turn_heading_sample_count") == 1_200, "R23D2_TURN_SAMPLE_COUNT"
    )

    controller_keys = (
        "maximum_absolute_requested_steering_fraction",
        "maximum_absolute_held_steering_fraction",
        "mean_turn_held_steering_fraction",
    )
    require_integrity(_exact_keys(controller, controller_keys), "R23D2_CONTROLLER_KEYS")
    limit = detection["maximum_absolute_requested_or_held_steering_fraction"]
    requested = controller.get("maximum_absolute_requested_steering_fraction")
    held = controller.get("maximum_absolute_held_steering_fraction")
    mean_turn = controller.get("mean_turn_held_steering_fraction")
    require_integrity(
        _finite_number(requested) and 0.0 <= float(requested) <= limit,
        "R23D2_REQUESTED_STEERING_BOUND",
    )
    require_integrity(
        _finite_number(held) and 0.0 <= float(held) <= limit,
        "R23D2_HELD_STEERING_BOUND",
    )
    require_integrity(_finite_number(mean_turn), "R23D2_MEAN_TURN_STEERING")

    physics_keys = (
        "turn_phase_yaw_delta_rad",
        "final_reference_heading_error_rad",
        "final_forward_displacement_m",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
        "torso_ground_contact_step_count",
        "contact_cycles_by_limb",
        "engine_production_straight_walking_gate_passed",
        "commanded_turn_walk_gate_passed",
    )
    require_integrity(_exact_keys(physics, physics_keys), "R23D2_PHYSICS_KEYS")
    for field in (
        "turn_phase_yaw_delta_rad",
        "final_reference_heading_error_rad",
        "final_forward_displacement_m",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
    ):
        require_integrity(
            _finite_number(physics.get(field)), f"R23D2_PHYSICS_{field.upper()}_FINITE"
        )
    require_integrity(
        _nonnegative_int(physics.get("torso_ground_contact_step_count")),
        "R23D2_TORSO_GROUND_COUNT",
    )
    contacts = physics.get("contact_cycles_by_limb", {})
    contact_keys = ("front_left", "front_right", "rear_left", "rear_right")
    require_integrity(
        _exact_keys(contacts, contact_keys)
        and all(_nonnegative_int(value) for value in contacts.values()),
        "R23D2_CONTACT_CYCLE_SHAPE",
    )
    require_integrity(
        isinstance(physics.get("engine_production_straight_walking_gate_passed"), bool),
        "R23D2_ZERO_WALK_TYPE",
    )
    require_integrity(
        isinstance(physics.get("commanded_turn_walk_gate_passed"), bool),
        "R23D2_TURN_WALK_TYPE",
    )
    require_integrity(report.get("claims") == _claims(), "R23D2_CLAIM_BOUNDARY")

    require_outcome(
        physics.get("torso_ground_contact_step_count") == 0, "R23D2_TORSO_GROUND"
    )
    require_outcome(
        _finite_number(physics.get("maximum_tilt_rad"))
        and float(physics["maximum_tilt_rad"]) <= detection["maximum_tilt_rad"],
        "R23D2_TILT",
    )
    require_outcome(
        _finite_number(physics.get("minimum_torso_height_m"))
        and float(physics["minimum_torso_height_m"])
        >= detection["minimum_torso_height_m"],
        "R23D2_TORSO_HEIGHT",
    )
    require_outcome(
        _finite_number(physics.get("final_forward_displacement_m"))
        and float(physics["final_forward_displacement_m"])
        >= detection["minimum_final_forward_displacement_m"],
        "R23D2_FORWARD_PROGRESS",
    )
    require_outcome(
        isinstance(contacts, dict)
        and all(
            _nonnegative_int(value)
            and value >= detection["minimum_contact_cycles_per_limb"]
            for value in contacts.values()
        ),
        "R23D2_CONTACT_CYCLES",
    )

    offset = float(expected["turn_heading_offset_rad"])
    if offset == 0.0:
        require_outcome(
            physics.get("engine_production_straight_walking_gate_passed") is True,
            "R23D2_ZERO_STRAIGHT_WALK",
        )
    else:
        yaw_delta = physics.get("turn_phase_yaw_delta_rad")
        require_outcome(
            _finite_number(yaw_delta)
            and math.copysign(1.0, float(yaw_delta)) == math.copysign(1.0, offset)
            and abs(float(yaw_delta))
            >= detection["minimum_absolute_signed_turn_phase_yaw_delta_rad"],
            "R23D2_SIGNED_YAW_RESPONSE",
        )
        require_outcome(
            _finite_number(mean_turn)
            and math.copysign(1.0, float(mean_turn)) == -math.copysign(1.0, offset)
            and abs(float(mean_turn)) > 1e-12,
            "R23D2_SIGNED_CONTROLLER_RESPONSE",
        )
        require_outcome(
            physics.get("commanded_turn_walk_gate_passed") is True, "R23D2_TURN_WALK"
        )
    return _cell_evaluation(cell_id, integrity, outcome)


def _failure_evaluation(
    cell_id: str,
    failures: list[str],
    attempts: int,
    builds: int,
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r23d2_failure_evaluation_v1",
        "cell_id": cell_id,
        "entry_kind": "worker_failure",
        "entry_valid": not failures,
        "execution_valid": False,
        "screen_cell_passed": False,
        "result_classification": (
            "worker_failure" if not failures else "invalid_failure_receipt"
        ),
        "integrity_failure_count": len(failures),
        "integrity_failure_codes": failures,
        "outcome_failure_count": 0,
        "outcome_failure_codes": [],
        "failed_gate_count": len(failures),
        "failure_codes": failures,
        "world_attempt_count": attempts if _nonnegative_int(attempts) else 0,
        "world_build_count": builds if _nonnegative_int(builds) else 0,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def evaluate_failure(
    failure: dict[str, Any], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Validate a terminal worker-failure receipt without calling physics."""

    contract = load_contract() if contract is None else contract
    matrix = {cell["cell_id"]: cell for cell in compile_cell_matrix(contract)}
    failures: list[str] = []

    def require(condition: bool, code: str) -> None:
        if not condition:
            failures.append(code)

    top_keys = (
        "schema_version",
        "campaign_id",
        "gate_id",
        "cell_id",
        "engine_id",
        "arm_id",
        "source_commit",
        "contract_sha256",
        "stage_id",
        "world_attempt_count",
        "world_build_count",
        "process_failure_code",
        "rejected_controller_projection",
        "oracle_input",
        "oracle_evaluation",
        "rejected_projection_retention",
        "claims",
    )
    require(_exact_keys(failure, top_keys), "R23D2_FAILURE_KEYS")
    cell_id = str(failure.get("cell_id", ""))
    expected = matrix.get(cell_id)
    require(expected is not None, "R23D2_FAILURE_CELL_ID_UNKNOWN")
    attempts = failure.get("world_attempt_count", -1)
    builds = failure.get("world_build_count", -1)
    if expected is None:
        return _failure_evaluation(cell_id, failures, attempts, builds)

    require(
        failure.get("schema_version") == WORKER_FAILURE_SCHEMA, "R23D2_FAILURE_SCHEMA"
    )
    require(failure.get("campaign_id") == CAMPAIGN_ID, "R23D2_FAILURE_CAMPAIGN")
    require(failure.get("gate_id") == GATE_ID, "R23D2_FAILURE_GATE")
    require(failure.get("engine_id") == expected["engine_id"], "R23D2_FAILURE_ENGINE")
    require(failure.get("arm_id") == expected["arm_id"], "R23D2_FAILURE_ARM")
    require(
        _valid_source_commit(failure.get("source_commit")),
        "R23D2_FAILURE_SOURCE_COMMIT",
    )
    require(
        failure.get("contract_sha256") == contract_sha256(),
        "R23D2_FAILURE_CONTRACT_DIGEST",
    )
    require(
        isinstance(failure.get("process_failure_code"), str)
        and bool(failure.get("process_failure_code")),
        "R23D2_PROCESS_FAILURE_CODE",
    )
    require(_nonnegative_int(attempts), "R23D2_FAILURE_ATTEMPT_COUNT_TYPE")
    require(_nonnegative_int(builds), "R23D2_FAILURE_BUILD_COUNT_TYPE")
    stage_id = str(failure.get("stage_id", ""))
    require(
        _nonnegative_int(attempts)
        and _nonnegative_int(builds)
        and r23d2_oracle.validate_failure_provenance(stage_id, attempts, builds),
        "R23D2_FAILURE_STAGE_COUNTS",
    )
    require(failure.get("claims") == _claims(), "R23D2_FAILURE_CLAIM_BOUNDARY")

    projection = failure.get("rejected_controller_projection")
    oracle_input = failure.get("oracle_input")
    supplied_evaluation = failure.get("oracle_evaluation")
    retention = failure.get("rejected_projection_retention")
    retention_keys = (
        "schema_version",
        "embedded_before_exit",
        "payload_sha256",
        "content_addressed_by_supervisor_before_aggregation_required",
    )
    require(_exact_keys(retention, retention_keys), "R23D2_FAILURE_RETENTION_KEYS")
    if isinstance(retention, dict):
        require(
            retention.get("schema_version")
            == "sporespore_qsdk_r23d2_rejected_projection_retention_v1",
            "R23D2_FAILURE_RETENTION_SCHEMA",
        )
        require(
            retention.get("content_addressed_by_supervisor_before_aggregation_required")
            is True,
            "R23D2_FAILURE_SUPERVISOR_CAS_REQUIREMENT",
        )

    if stage_id == "controller_validation_failed":
        require(
            _exact_keys(projection, r23d2_oracle.RECEIPT_FIELDS),
            "R23D2_REJECTED_PROJECTION_FIELDS",
        )
        require(
            _exact_keys(oracle_input, ("state", "command", "profile")),
            "R23D2_FAILURE_ORACLE_INPUT_KEYS",
        )
        recomputed: dict[str, Any] | None = None
        if isinstance(projection, dict) and isinstance(oracle_input, dict):
            try:
                recomputed = r23d2_oracle.validate_receipt(
                    projection,
                    oracle_input.get("state", {}),
                    oracle_input.get("command", {}),
                    oracle_input.get("profile", {}),
                )
            except (r23d2_oracle.R23D2OracleError, TypeError, ValueError, KeyError):
                require(False, "R23D2_FAILURE_ORACLE_RECOMPUTATION")
        require(
            recomputed is not None and recomputed.get("ok") is False,
            "R23D2_FAILURE_REJECTED_PROJECTION_WOULD_PASS",
        )
        require(
            _oracle_evaluations_equivalent(
                supplied_evaluation,
                recomputed,
                (
                    oracle_input.get("profile", {})
                    if isinstance(oracle_input, dict)
                    else {}
                ),
            ),
            "R23D2_FAILURE_ORACLE_EVALUATION_PARITY",
        )
        require(
            isinstance(recomputed, dict) and bool(recomputed.get("failed_predicates")),
            "R23D2_FAILURE_PREDICATE_IDS_MISSING",
        )
        require(
            isinstance(retention, dict)
            and retention.get("embedded_before_exit") is True,
            "R23D2_FAILURE_NOT_EMBEDDED_BEFORE_EXIT",
        )
        require(
            isinstance(retention, dict)
            and isinstance(projection, dict)
            and retention.get("payload_sha256") == _canonical_sha256(projection),
            "R23D2_FAILURE_REJECTED_PROJECTION_DIGEST",
        )
    else:
        require(projection is None, "R23D2_NONCONTROLLER_REJECTED_PROJECTION")
        require(oracle_input is None, "R23D2_NONCONTROLLER_ORACLE_INPUT")
        require(supplied_evaluation is None, "R23D2_NONCONTROLLER_ORACLE_EVALUATION")
        require(
            isinstance(retention, dict)
            and retention.get("embedded_before_exit") is False,
            "R23D2_NONCONTROLLER_RETENTION_STATE",
        )
        require(
            isinstance(retention, dict) and retention.get("payload_sha256") is None,
            "R23D2_NONCONTROLLER_RETENTION_DIGEST",
        )
    return _failure_evaluation(cell_id, failures, attempts, builds)


def evaluate_entry(
    entry: dict[str, Any], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    schema = entry.get("schema_version") if isinstance(entry, dict) else None
    if schema == SUCCESS_REPORT_SCHEMA:
        return evaluate_cell(entry, contract)
    if schema == WORKER_FAILURE_SCHEMA:
        return evaluate_failure(entry, contract)
    cell_id = str(entry.get("cell_id", "")) if isinstance(entry, dict) else ""
    return _failure_evaluation(cell_id, ["R23D2_ENTRY_SCHEMA_UNKNOWN"], 0, 0)


def evaluate_aggregate(
    entries: list[dict[str, Any]], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    contract = load_contract() if contract is None else contract
    expected_ids = [cell["cell_id"] for cell in compile_cell_matrix(contract)]
    observed_ids = [str(entry.get("cell_id", "")) for entry in entries]
    failures: list[str] = []
    if len(entries) != len(expected_ids):
        failures.append("R23D2_AGGREGATE_ENTRY_COUNT")
    if observed_ids != expected_ids:
        failures.append("R23D2_AGGREGATE_ORDER_OR_COMPLETENESS")
    if len(set(observed_ids)) != len(observed_ids):
        failures.append("R23D2_AGGREGATE_DUPLICATE_CELL")

    evaluations = [evaluate_entry(entry, contract) for entry in entries]
    report_count = sum(
        item["entry_kind"] == "successful_report" for item in evaluations
    )
    worker_failure_count = sum(
        item["entry_kind"] == "worker_failure" for item in evaluations
    )
    if worker_failure_count:
        failures.append("R23D2_AGGREGATE_WORKER_FAILURE_PRESENT")
    if any(not item["entry_valid"] for item in evaluations):
        failures.append("R23D2_AGGREGATE_ENTRY_INVALID")
    if report_count != len(expected_ids):
        failures.append("R23D2_AGGREGATE_COMPLETE_REPORT_COUNT")

    aggregate_valid = not failures
    cell_positive_count = sum(
        item["result_classification"] == "valid_positive" for item in evaluations
    )
    cell_negative_count = sum(
        item["result_classification"] == "valid_negative" for item in evaluations
    )
    development_screen_passed = aggregate_valid and cell_positive_count == len(
        expected_ids
    )
    classification = (
        "invalid_or_incomplete"
        if not aggregate_valid
        else "valid_positive" if development_screen_passed else "valid_negative"
    )
    return {
        "schema_version": AGGREGATE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "entry_count": len(entries),
        "report_count": report_count,
        "worker_failure_count": worker_failure_count,
        "cell_evaluations": evaluations,
        "aggregate_valid": aggregate_valid,
        "development_screen_valid": aggregate_valid,
        "development_screen_passed": development_screen_passed,
        "result_classification": classification,
        "valid_positive_cell_count": cell_positive_count,
        "valid_negative_cell_count": cell_negative_count,
        "failed_gate_count": len(failures),
        "failure_codes": failures,
        "world_attempt_count": sum(item["world_attempt_count"] for item in evaluations),
        "world_build_count": sum(item["world_build_count"] for item in evaluations),
        "q_sdk_r23_satisfied": False,
        "command_conditioned_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def perfect_report(
    cell: dict[str, Any], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Create a real-shaped synthetic positive without opening a world."""

    contract = load_contract() if contract is None else contract
    offset = float(cell["turn_heading_offset_rad"])
    step_count = 2_400
    return {
        "schema_version": SUCCESS_REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "cell_id": cell["cell_id"],
        "engine_id": cell["engine_id"],
        "arm_id": cell["arm_id"],
        "source_commit": "a" * 40,
        "contract_sha256": contract_sha256(),
        "selected_policy_id": contract["source_contract"]["selected_policy_id"],
        "selected_policy_digest": contract["source_contract"]["selected_policy_digest"],
        "morphology_id": contract["fixture"]["morphology_id"],
        "campaign_seed": contract["fixture"]["initial_condition_seed"],
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": step_count,
            "validated_portable_command_count": step_count * 8,
            "native_actuation_application_count": step_count * 8,
        },
        "execution_stage": {
            "schema_version": EXECUTION_STAGE_SCHEMA,
            "stage_id": "cell_report_complete",
            "world_attempt_count": 1,
            "world_build_count": 1,
        },
        "command_validation": {
            "schema_version": COMMAND_VALIDATION_SCHEMA,
            "normalized_validation_mode": contract["normalized_entry_contract"][
                "normalized_validation_mode"
            ],
            "source_validation_mode": "synthetic_native_adapter_and_independent_oracle_v1",
            "native_validation_step_count": step_count,
            "heading_command_conditioned_step_count": step_count,
            "unconditioned_step_count": 0,
            "legacy_command_parity_applicable": False,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
            "oracle_contract_sha256": contract["oracle_validation"][
                "oracle_contract_sha256"
            ],
            "independent_oracle_validation_step_count": step_count,
            "accepted_receipt_count": step_count,
            "rejected_receipt_count": 0,
            "predicate_failure_count": 0,
            "raw_heading_offset_equality_used": False,
        },
        "schedule": {
            "schedule_id": contract["command_schedule"]["schedule_id"],
            "turn_heading_offset_rad": offset,
            "observed_segment_sample_counts": copy.deepcopy(
                contract["command_schedule"]["expected_segment_sample_counts"]
            ),
            "reference_heading_sample_count": 1_200,
            "turn_heading_sample_count": 1_200,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction": 0.3,
            "maximum_absolute_held_steering_fraction": 0.25,
            "mean_turn_held_steering_fraction": (
                0.0 if offset == 0.0 else -math.copysign(0.2, offset)
            ),
        },
        "physics": {
            "turn_phase_yaw_delta_rad": (
                0.0 if offset == 0.0 else math.copysign(0.1, offset)
            ),
            "final_reference_heading_error_rad": 0.02,
            "final_forward_displacement_m": 0.5,
            "maximum_tilt_rad": 0.2,
            "minimum_torso_height_m": 0.4,
            "torso_ground_contact_step_count": 0,
            "contact_cycles_by_limb": {
                "front_left": 3,
                "front_right": 3,
                "rear_left": 3,
                "rear_right": 3,
            },
            "engine_production_straight_walking_gate_passed": offset == 0.0,
            "commanded_turn_walk_gate_passed": offset != 0.0,
        },
        "claims": _claims(),
    }


def perfect_failure(
    cell: dict[str, Any],
    stage_id: str,
    contract: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a stage-truthful synthetic failure receipt for controls."""

    contract = load_contract() if contract is None else contract
    counts = {
        "before_world": (0, 0),
        "world_construction_failed": (1, 0),
        "world_constructed": (1, 1),
        "settlement_complete": (1, 1),
        "controller_validation_failed": (1, 1),
        "cell_report_complete": (1, 1),
    }
    if stage_id not in counts:
        raise R23D2DevelopmentError(f"R23D2_FAILURE_STAGE_UNKNOWN:{stage_id}")
    attempts, builds = counts[stage_id]
    projection: dict[str, float] | None = None
    oracle_input: dict[str, Any] | None = None
    evaluation: dict[str, Any] | None = None
    embedded = False
    payload_sha256: str | None = None
    if stage_id == "controller_validation_failed":
        oracle_contract = r23d2_oracle.load_contract()
        canary = oracle_contract["oracle_canaries"][1]
        state = r23d2_oracle.canary_state(canary)
        command = {"desired_heading_rad": canary["desired_heading_rad"]}
        profile = copy.deepcopy(oracle_contract["selected_profile_oracle"])
        projection = r23d2_oracle.recompute_oracle(state, command, profile)
        projection["desired_heading_error_rad"] += 1e-6
        evaluation = r23d2_oracle.validate_receipt(projection, state, command, profile)
        oracle_input = {"state": state, "command": command, "profile": profile}
        embedded = True
        payload_sha256 = _canonical_sha256(projection)
    return {
        "schema_version": WORKER_FAILURE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "cell_id": cell["cell_id"],
        "engine_id": cell["engine_id"],
        "arm_id": cell["arm_id"],
        "source_commit": "a" * 40,
        "contract_sha256": contract_sha256(),
        "stage_id": stage_id,
        "world_attempt_count": attempts,
        "world_build_count": builds,
        "process_failure_code": f"SYNTHETIC_{stage_id.upper()}",
        "rejected_controller_projection": projection,
        "oracle_input": oracle_input,
        "oracle_evaluation": evaluation,
        "rejected_projection_retention": {
            "schema_version": "sporespore_qsdk_r23d2_rejected_projection_retention_v1",
            "embedded_before_exit": embedded,
            "payload_sha256": payload_sha256,
            "content_addressed_by_supervisor_before_aggregation_required": True,
        },
        "claims": _claims(),
    }


def _mutated(
    source: dict[str, Any], path: tuple[str, ...], value: Any
) -> dict[str, Any]:
    candidate = copy.deepcopy(source)
    target = candidate
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    return candidate


def run_zero_world_preflight() -> dict[str, Any]:
    contract = load_contract()
    matrix = compile_cell_matrix(contract)
    schedule_checks = 0
    for arm in contract["arms"]:
        expected_boundaries = (
            (0, "reference_warmup", 0.0),
            (599, "reference_warmup", 0.0),
            (600, "commanded_turn", float(arm["turn_heading_offset_rad"])),
            (1799, "commanded_turn", float(arm["turn_heading_offset_rad"])),
            (1800, "reference_recovery", 0.0),
            (2399, "reference_recovery", 0.0),
            (2400, "reference_continuation", 0.0),
        )
        for step, segment, offset in expected_boundaries:
            if heading_offset_for_step(arm["arm_id"], step, contract) != (
                segment,
                offset,
            ):
                raise R23D2DevelopmentError(
                    f"R23D2_SCHEDULE_BOUNDARY:{arm['arm_id']}:{step}"
                )
            schedule_checks += 1

    reports = [perfect_report(cell, contract) for cell in matrix]
    positive = evaluate_aggregate(reports, contract)
    if (
        positive["result_classification"] != "valid_positive"
        or positive["valid_positive_cell_count"] != 9
        or positive["world_attempt_count"] != 9
        or positive["world_build_count"] != 9
    ):
        raise R23D2DevelopmentError("R23D2_PERFECT_AGGREGATE_REJECTED")

    negative_reports = copy.deepcopy(reports)
    negative_reports[1]["physics"]["final_forward_displacement_m"] = 0.0
    negative = evaluate_aggregate(negative_reports, contract)
    if (
        not negative["aggregate_valid"]
        or negative["result_classification"] != "valid_negative"
        or negative["valid_negative_cell_count"] != 1
        or negative["cell_evaluations"][1]["integrity_failure_count"] != 0
        or negative["cell_evaluations"][1]["outcome_failure_codes"]
        != ["R23D2_FORWARD_PROGRESS"]
    ):
        raise R23D2DevelopmentError("R23D2_VALID_NEGATIVE_CLASSIFICATION_FAILED")

    base_turn = reports[1]
    structural_mutations = (
        _mutated(base_turn, ("schema_version",), "wrong"),
        _mutated(base_turn, ("selected_policy_id",), "wrong"),
        _mutated(base_turn, ("morphology_id",), "wrong"),
        _mutated(base_turn, ("campaign_seed",), 21502),
        _mutated(base_turn, ("contract_sha256",), "sha256:00"),
        _mutated(base_turn, ("execution", "world_attempt_count"), 0),
        _mutated(base_turn, ("execution_stage", "world_build_count"), 0),
        _mutated(base_turn, ("execution", "controller_error_count"), 1),
        _mutated(base_turn, ("execution", "validated_portable_command_count"), 1),
        _mutated(
            base_turn,
            ("command_validation", "independent_oracle_validation_step_count"),
            2399,
        ),
        _mutated(base_turn, ("command_validation", "accepted_receipt_count"), 2399),
        _mutated(base_turn, ("command_validation", "rejected_receipt_count"), 1),
        _mutated(base_turn, ("command_validation", "predicate_failure_count"), 1),
        _mutated(
            base_turn, ("command_validation", "raw_heading_offset_equality_used"), True
        ),
        _mutated(
            base_turn, ("command_validation", "oracle_contract_sha256"), "sha256:00"
        ),
        _mutated(base_turn, ("schedule", "turn_heading_offset_rad"), -0.2),
        _mutated(
            base_turn, ("controller", "maximum_absolute_held_steering_fraction"), 0.41
        ),
        _mutated(base_turn, ("claims", "q_sdk_r23_satisfied"), True),
    )
    structural_rejections = sum(
        not evaluate_cell(report, contract)["execution_valid"]
        for report in structural_mutations
    )
    if structural_rejections != len(structural_mutations):
        raise R23D2DevelopmentError("R23D2_STRUCTURAL_NEGATIVE_CONTROL_ACCEPTED")

    outcome_mutations = (
        _mutated(base_turn, ("controller", "mean_turn_held_steering_fraction"), 0.2),
        _mutated(base_turn, ("physics", "turn_phase_yaw_delta_rad"), -0.1),
        _mutated(base_turn, ("physics", "turn_phase_yaw_delta_rad"), 0.001),
        _mutated(base_turn, ("physics", "torso_ground_contact_step_count"), 1),
        _mutated(base_turn, ("physics", "maximum_tilt_rad"), 0.61),
        _mutated(base_turn, ("physics", "minimum_torso_height_m"), 0.1),
        _mutated(base_turn, ("physics", "final_forward_displacement_m"), 0.0),
        _mutated(base_turn, ("physics", "contact_cycles_by_limb", "front_left"), 1),
        _mutated(base_turn, ("physics", "commanded_turn_walk_gate_passed"), False),
    )
    valid_negative_controls = sum(
        evaluation["execution_valid"]
        and evaluation["result_classification"] == "valid_negative"
        for evaluation in (
            evaluate_cell(report, contract) for report in outcome_mutations
        )
    )
    if valid_negative_controls != len(outcome_mutations):
        raise R23D2DevelopmentError("R23D2_OUTCOME_NEGATIVE_MISCLASSIFIED")

    aggregate_mutations = (
        reports[:-1],
        [*reports[:-1], copy.deepcopy(reports[0])],
        list(reversed(reports)),
        [structural_mutations[0], *reports[1:]],
    )
    aggregate_rejections = sum(
        evaluate_aggregate(entries, contract)["result_classification"]
        == "invalid_or_incomplete"
        for entries in aggregate_mutations
    )
    if aggregate_rejections != len(aggregate_mutations):
        raise R23D2DevelopmentError("R23D2_AGGREGATE_NEGATIVE_CONTROL_ACCEPTED")

    stage_ids = contract["failure_provenance"]["required_stage_ids"]
    failure_receipts = [
        perfect_failure(matrix[0], stage, contract) for stage in stage_ids
    ]
    failure_receipt_passes = sum(
        evaluate_failure(receipt, contract)["entry_valid"]
        for receipt in failure_receipts
    )
    if failure_receipt_passes != len(stage_ids):
        raise R23D2DevelopmentError("R23D2_FAILURE_RECEIPT_CONTROL_REJECTED")
    stage_aggregate_counts: dict[str, list[int]] = {}
    for receipt in failure_receipts:
        aggregate = evaluate_aggregate([receipt, *reports[1:]], contract)
        if aggregate["result_classification"] != "invalid_or_incomplete":
            raise R23D2DevelopmentError("R23D2_WORKER_FAILURE_AGGREGATE_ACCEPTED")
        stage_aggregate_counts[receipt["stage_id"]] = [
            aggregate["world_attempt_count"],
            aggregate["world_build_count"],
        ]
    if (
        stage_aggregate_counts["before_world"] != [8, 8]
        or stage_aggregate_counts["world_construction_failed"] != [9, 8]
        or stage_aggregate_counts["controller_validation_failed"] != [9, 9]
    ):
        raise R23D2DevelopmentError("R23D2_AGGREGATE_STAGE_COUNT_SUM_INVALID")

    controller_failure = next(
        item
        for item in failure_receipts
        if item["stage_id"] == "controller_validation_failed"
    )
    failure_mutations = (
        _mutated(controller_failure, ("world_attempt_count",), 0),
        _mutated(controller_failure, ("world_build_count",), 0),
        _mutated(
            controller_failure,
            ("rejected_projection_retention", "payload_sha256"),
            "sha256:00",
        ),
        _mutated(
            controller_failure,
            ("rejected_projection_retention", "embedded_before_exit"),
            False,
        ),
        _mutated(controller_failure, ("oracle_evaluation", "failed_predicates"), []),
    )
    failure_mutation_rejections = sum(
        not evaluate_failure(receipt, contract)["entry_valid"]
        for receipt in failure_mutations
    )
    if failure_mutation_rejections != len(failure_mutations):
        raise R23D2DevelopmentError("R23D2_FAILURE_PROVENANCE_MUTATION_ACCEPTED")

    return {
        "schema_version": "sporespore_qsdk_r23d2_development_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "contract_sha256": contract_sha256(),
        "declared_engine_count": 3,
        "declared_arm_count": 3,
        "declared_cell_count": 9,
        "schedule_boundary_check_count": schedule_checks,
        "synthetic_positive_cell_count": positive["valid_positive_cell_count"],
        "synthetic_positive_aggregate_pass_count": int(
            positive["development_screen_passed"]
        ),
        "synthetic_valid_negative_aggregate_count": int(
            negative["result_classification"] == "valid_negative"
        ),
        "structural_negative_control_count": len(structural_mutations),
        "structural_negative_control_rejection_count": structural_rejections,
        "valid_outcome_negative_control_count": valid_negative_controls,
        "aggregate_negative_control_count": len(aggregate_mutations),
        "aggregate_negative_control_rejection_count": aggregate_rejections,
        "failure_stage_control_count": len(failure_receipts),
        "failure_stage_control_pass_count": failure_receipt_passes,
        "failure_provenance_mutation_count": len(failure_mutations),
        "failure_provenance_mutation_rejection_count": failure_mutation_rejections,
        "stage_aggregate_projected_counts": stage_aggregate_counts,
        "synthetic_projected_world_attempt_count": positive["world_attempt_count"],
        "synthetic_projected_world_build_count": positive["world_build_count"],
        "actual_physical_process_launch_count": 0,
        "actual_world_attempt_count": 0,
        "actual_world_build_count": 0,
        "physical_execution_authorized": True,
        "q_sdk_r23_satisfied": False,
        "command_conditioned_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def write_synthetic_matrix(output_root: Path) -> dict[str, Any]:
    contract = load_contract()
    matrix = compile_cell_matrix(contract)
    output_root.mkdir(parents=True, exist_ok=False)
    paths: list[str] = []
    for cell in matrix:
        path = output_root / f"{cell['ordinal']:02d}-{cell['cell_id']}.json"
        payload = json.dumps(
            perfect_report(cell, contract),
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        path.write_text(payload + "\n", encoding="utf-8", newline="\n")
        paths.append(str(path.resolve()))
    return {
        "schema_version": "sporespore_qsdk_r23d2_synthetic_matrix_manifest_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "ordered_report_paths": paths,
        "report_count": len(paths),
        "synthetic_projected_world_count": len(paths),
        "actual_world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def write_synthetic_failure(
    cell_id: str, stage_id: str, output_path: Path
) -> dict[str, Any]:
    contract = load_contract()
    matches = [
        cell for cell in compile_cell_matrix(contract) if cell["cell_id"] == cell_id
    ]
    if len(matches) != 1:
        raise R23D2DevelopmentError(f"R23D2_FAILURE_CELL_UNKNOWN:{cell_id}")
    if output_path.exists():
        raise R23D2DevelopmentError("R23D2_FAILURE_OUTPUT_ALREADY_EXISTS")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    receipt = perfect_failure(matches[0], stage_id, contract)
    payload = json.dumps(
        receipt,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )
    output_path.write_text(payload + "\n", encoding="utf-8", newline="\n")
    return {
        "schema_version": "sporespore_qsdk_r23d2_synthetic_failure_manifest_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "cell_id": cell_id,
        "stage_id": stage_id,
        "failure_path": str(output_path.resolve()),
        "world_attempt_count": receipt["world_attempt_count"],
        "world_build_count": receipt["world_build_count"],
        "actual_world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _load_entry(path: str) -> dict[str, Any]:
    try:
        value = json.loads(Path(path).resolve().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise R23D2DevelopmentError(
            f"R23D2_ENTRY_UNREADABLE:{Path(path).name}:{type(error).__name__}"
        ) from error
    if not isinstance(value, dict):
        raise R23D2DevelopmentError("R23D2_ENTRY_NOT_OBJECT")
    return value


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    try:
        if arguments == ["preflight"]:
            receipt = run_zero_world_preflight()
            print(
                "QSDK_R23D2_DEVELOPMENT_PREFLIGHT "
                + json.dumps(receipt, sort_keys=True)
            )
            return 0
        if len(arguments) == 2 and arguments[0] == "emit-synthetic-matrix":
            manifest = write_synthetic_matrix(Path(arguments[1]).resolve())
            print("QSDK_R23D2_SYNTHETIC_MATRIX " + json.dumps(manifest, sort_keys=True))
            return 0
        if len(arguments) == 4 and arguments[0] == "emit-synthetic-failure":
            manifest = write_synthetic_failure(
                arguments[1], arguments[2], Path(arguments[3]).resolve()
            )
            print(
                "QSDK_R23D2_SYNTHETIC_FAILURE " + json.dumps(manifest, sort_keys=True)
            )
            return 0
        if len(arguments) == 2 and arguments[0] == "evaluate-entry":
            evaluation = evaluate_entry(_load_entry(arguments[1]))
            print(
                "QSDK_R23D2_ENTRY_EVALUATION " + json.dumps(evaluation, sort_keys=True)
            )
            return 0 if evaluation["entry_valid"] else 1
        if len(arguments) >= 2 and arguments[0] == "evaluate-aggregate":
            evaluation = evaluate_aggregate(
                [_load_entry(path) for path in arguments[1:]]
            )
            print(
                "QSDK_R23D2_AGGREGATE_EVALUATION "
                + json.dumps(evaluation, sort_keys=True)
            )
            return 0 if evaluation["aggregate_valid"] else 1
        print(
            "usage: r23d2_development.py preflight | emit-synthetic-matrix <dir> | "
            "emit-synthetic-failure <cell> <stage> <file> | "
            "evaluate-entry <entry.json> | evaluate-aggregate <entry.json>...",
            file=sys.stderr,
        )
        return 2
    except (
        R23D2DevelopmentError,
        r23d2_oracle.R23D2OracleError,
        KeyError,
        TypeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D2_DEVELOPMENT_FAILURE {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
