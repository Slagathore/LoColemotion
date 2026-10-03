"""Trace retention and finite startup-ramp evaluation for QSDK-R23D40."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d34_native_r23d29_transfer_evaluator as inherited
import r23d40_three_engine_startup_ramp_turning as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = ROOT / "r23d40_three_engine_startup_ramp_turning_preregistration_v1.json"
REPORT_SCHEMA = "sporespore_qsdk_r23d40_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d40_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d40_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d40_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d40_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "rapier_parry_r23d29_turning": False,
    "godot_jolt_r23d29_turning": False,
    "mujoco_r23d29_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D40EvaluationError(RuntimeError):
    """The declaration, retained evidence, or three-cell result is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D40EvaluationError(
            f"R23D40_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    successor = value.get("scientifically_distinct_successor", {})
    gates = value.get("frozen_common_physical_gates", {})
    lineage = value.get("immutable_lineage", {})
    measurement = value.get("cycle_integrated_measurement", {})
    entry = value.get("zero_world_entry_gate", {})
    claims = value.get("claims", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d40_three_engine_startup_ramp_turning_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("study_classification")
        != "prospective_exact_finite_outcome_exposed_mujoco_startup_ramp_turning_development_screen"
        or successor.get("screened_policy_id") != design.POLICY_ID
        or successor.get("comparator_policy_id") != design.POLICY_ID
        or successor.get("same_outcome_exposed_seed_as_comparator") is not True
        or successor.get("same_initial_perturbation_as_comparator") is not True
        or successor.get(
            "same_morphology_host_material_horizon_and_worker_physics_as_comparator"
        )
        is not True
        or successor.get("reference_command_only") is not False
        or successor.get("reference_positive_and_negative_heading_arms_required")
        is not True
        or successor.get("bw19v_stability_residual_composition_invoked") is not False
        or successor.get("canonical_startup_residual_transform_invoked") is not True
        or successor.get("controller_source_changed") is not False
        or successor.get("portable_canonical_startup_transform_created") is not False
        or successor.get(
            "portable_canonical_startup_transform_inherited_exactly_from_r23d38"
        )
        is not True
        or successor.get("startup_ramp_id") != design.STARTUP_RAMP_ID
        or successor.get("startup_ramp_step_count") != design.STARTUP_RAMP_STEPS
        or successor.get("fresh_held_out_condition_consumed") is not False
        or successor.get("threshold_changed") is not False
        or successor.get("turning_tested") is not True
        or successor.get("engine_specific_gait_logic_permitted") is not False
        or successor.get("arm_identity_or_outcome_branching_permitted") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != [design.ENGINE_ID]
        or matrix.get("ordered_candidate_ids") != [design.CANDIDATE_ID]
        or matrix.get("ordered_arm_ids") != list(design.ARM_OFFSETS)
        or matrix.get("ordered_heading_offsets_rad")
        != list(design.ARM_OFFSETS.values())
        or matrix.get("declared_cell_count") != len(design.cells())
        or matrix.get("declared_world_count") != len(design.cells())
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("startup_ramp_id") != design.STARTUP_RAMP_ID
        or matrix.get("startup_ramp_step_count") != design.STARTUP_RAMP_STEPS
        or matrix.get("startup_ramp_active_step_count")
        != design.STARTUP_RAMP_STEPS - 1
        or matrix.get("command_schedule")
        != "reference_warmup_600_then_role_heading_1200_then_reference_recovery_600_then_reference_continuation_592"
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("recovery_duration_steps") != design.RECOVERY_DURATION_STEPS
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or matrix.get("serial_execution_required") is not True
        or gates.get("minimum_final_forward_displacement_m") != 0.030123046875
        or gates.get("maximum_tilt_rad") != 0.6
        or gates.get("minimum_torso_height_m") != 0.2499708652072946
        or gates.get("minimum_contact_cycles_per_limb") != 2
        or lineage.get("r23d21_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d21_physical_closure_v1.json")
        or lineage.get("r23d25_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d25_mujoco_terminal_zero_forward_closure_v1.json")
        or lineage.get("r23d34_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d34_native_r23d29_transfer_closure_v1.json")
        or lineage.get("r23d35_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d35_godot_trace_recovery_closure_v1.json")
        or lineage.get("r23d36_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d36_mujoco_bw19v_walking_restoration_closure_v1.json")
        or lineage.get("r23d37_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d37_mujoco_policy_seed_isolation_closure_v1.json")
        or lineage.get("r23d38_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d38_mujoco_startup_ramp_stabilization_closure_v1.json")
        or lineage.get("r23d31_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d31_cycle_integrated_directional_response_closure_v1.json")
        or lineage.get("r23d32_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d32_finite_rapier_turning_replication_closure_v1.json")
        or lineage.get("r23d34_identity_consumed") is not True
        or lineage.get("r23d36_identity_consumed") is not True
        or lineage.get("r23d37_identity_consumed") is not True
        or lineage.get("r23d38_identity_consumed") is not True
        or lineage.get("historical_result_reinterpreted") is not False
        or lineage.get("historical_world_reused_as_a_new_cell") is not False
        or lineage.get("same_identity_rerun_permitted") is not False
        or entry.get("terminal_manifest_writer_path")
        != "sdk/strict_json_array_document.ps1"
        or entry.get("terminal_manifest_must_be_a_json_array_for_zero_one_and_many_items")
        is not True
        or entry.get("campaign_local_gates_only") is not True
        or entry.get("physical_execution_authorized") is not False
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad")
        != 0.01
        or measurement.get("both_signed_arms_required") is not True
        or measurement.get("reference_arm_required") is not True
        or claims.get(
            "finite_mujoco_r23d29_seed_21507_startup_ramp_walking"
        )
        is not True
        or claims.get(
            "finite_mujoco_r23d29_seed_21507_startup_ramp_turning"
        )
        is not False
    )
    if invalid:
        raise R23D40EvaluationError("R23D40_DECLARATION_IDENTITY_INVALID")
    return value


# Reuse the already accepted R23D34 fixed-horizon trace validator and CAS
# publisher, but bind every identity-bearing global to this new campaign. The
# R23D40 wrapper adds ramp-law and exact CAS path/manifest checks below.
inherited.design = design
inherited.DECLARATION_PATH = DECLARATION_PATH
inherited.PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d40_trace.ps1"
inherited.PUBLISHER_MARKER = "QSDK_R23D40_EVIDENCE_CAS "
inherited.REPORT_SCHEMA = REPORT_SCHEMA
inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
inherited.FALSE_CLAIMS = FALSE_CLAIMS
inherited.load_declaration = load_declaration


def expected_cells() -> list[str]:
    return [item.cell_id for item in design.cells()]


_BASE_VALIDATE_TRACE = inherited.validate_trace


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    summary = _BASE_VALIDATE_TRACE(cell_id, rows)
    failures = list(summary.get("failure_codes", []))
    active_count = 0
    zero_count = 0
    unity_count = 0
    if isinstance(rows, list):
        for semantic_step, row in enumerate(rows):
            if not isinstance(row, dict):
                continue
            expected_scale = design.startup_velocity_scale(semantic_step)
            observed_scale = row.get("startup_velocity_scale")
            valid = (
                row.get("startup_ramp_id") == design.STARTUP_RAMP_ID
                and _finite(observed_scale)
                and abs(float(observed_scale) - expected_scale) <= 1.0e-15
                and row.get("startup_ramp_active") == (expected_scale < 1.0)
                and row.get("startup_ramp_residual_count") == design.ACTUATOR_COUNT
                and _finite(
                    row.get("startup_ramp_maximum_absolute_residual_rad_s")
                )
                and float(
                    row.get(
                        "startup_ramp_maximum_absolute_residual_rad_s",
                        math.nan,
                    )
                )
                >= 0.0
            )
            if not valid:
                failures.append(f"R23D40_TRACE_STARTUP_RAMP_INVALID:{semantic_step}")
            active_count += int(expected_scale < 1.0)
            zero_count += int(expected_scale == 0.0)
            unity_count += int(expected_scale == 1.0)
    summary["ok"] = not failures
    summary["failure_codes"] = failures[:32]
    summary["startup_ramp_active_step_count"] = active_count
    summary["startup_ramp_exact_zero_scale_step_count"] = zero_count
    summary["startup_ramp_exact_unity_scale_step_count"] = unity_count
    return summary


# The inherited publisher and evaluator resolve this name from their own
# module globals. Rebind it only for this successor instance.
inherited.validate_trace = validate_trace


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    return inherited.retain_trace(**kwargs)


def _cas_binding_failures(entry: Mapping[str, Any]) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D40_TRACE_ARTIFACT_RECEIPT"]
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D40_TRACE_ARTIFACT_IDENTITY"]
    directory = (
        REPO_ROOT.parent / "SporeSpore_Evidence" / "artifacts" / "sha256" / digest_hex
    ).resolve()
    payload = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    if (
        Path(str(artifact.get("payload_path", ""))).resolve() != payload
        or Path(str(artifact.get("manifest_path", ""))).resolve() != manifest_path
    ):
        return ["R23D40_TRACE_ARTIFACT_CAS_PATH"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D40_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
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
        return ["R23D40_TRACE_ARTIFACT_BYTES"]
    return []


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    evaluation, rows = inherited.evaluate_entry(
        entry, item, expected_source_commit=expected_source_commit
    )
    if isinstance(entry, dict) and evaluation.get("entry_kind") == "report":
        failures = _cas_binding_failures(entry)
        measurements = entry.get("measurements")
        if not isinstance(measurements, dict) or (
            measurements.get("startup_ramp_id") != design.STARTUP_RAMP_ID
            or measurements.get("startup_ramp_step_count")
            != design.STARTUP_RAMP_STEPS
            or measurements.get("startup_ramp_composition_step_count")
            != design.CONTROLLER_STEPS
            or measurements.get("startup_ramp_active_step_count")
            != design.STARTUP_RAMP_STEPS - 1
            or measurements.get("startup_ramp_exact_zero_scale_step_count") != 1
            or measurements.get("startup_ramp_exact_unity_scale_step_count")
            != design.CONTROLLER_STEPS - (design.STARTUP_RAMP_STEPS - 1)
            or measurements.get("startup_ramp_composition_integrity_passed")
            is not True
            or not _finite(
                measurements.get(
                    "maximum_absolute_startup_ramp_residual_rad_s"
                )
            )
        ):
            failures.append("R23D40_STARTUP_RAMP_REPORT_INTEGRITY")
        if failures:
            evaluation["execution_valid"] = False
            evaluation["common_physical_gate_passed"] = False
            evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + failures
    return evaluation, rows


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D40EvaluationError("R23D40_SOURCE_COMMIT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D40EvaluationError("R23D40_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_arm: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, expected, strict=True):
        evaluation, rows = evaluate_entry(
            entry, item, expected_source_commit=expected_source_commit
        )
        evaluations.append(evaluation)
        rows_by_arm[item.arm_id] = inherited._measurement_rows(rows)
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
        measurement = inherited.measure_cycle_integrated_response(rows_by_arm)
        measurement_failures = [
            gate for gate, passed in measurement["gates"].items() if not passed
        ]
    measurement_passed = bool(measurement and measurement.get("passed") is True)
    positive = all_execution_valid and all_physical_passed and measurement_passed
    invalid = not all_execution_valid
    classification = (
        "valid_complete_positive_mujoco_startup_ramp_turning_development"
        if positive
        else "invalid_complete_mujoco_startup_ramp_turning_development"
        if invalid
        else "valid_complete_negative_mujoco_startup_ramp_turning_development"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["finite_mujoco_r23d29_seed_21507_startup_ramp_walking"] = True
    claims[
        "finite_mujoco_r23d29_seed_21507_startup_ramp_turning"
    ] = positive
    claims["mujoco_r23d29_turning"] = positive
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
        "outcome_exposed_development_screen": True,
        "startup_ramp_id": design.STARTUP_RAMP_ID,
        "fresh_held_out_condition_consumed": False,
        "terminal_restoration_or_taper_invoked": False,
        "turning_tested": True,
        "distinct_same_policy_three_engine_validation_required": positive,
        "claims": claims,
    }


def _synthetic_row(item: design.Cell, step: int) -> dict[str, Any]:
    segment, offset = design.segment_for_step(item, step)
    signed_yaw = 0.0
    if item.arm_id != "reference_zero" and step >= design.TURN_START_STEP:
        signed_yaw = math.copysign(
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
        "measured_yaw_rad": signed_yaw,
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
        "validated_portable_command_count": design.ACTUATOR_COUNT,
        "native_actuation_application_count": design.ACTUATOR_COUNT,
        "oracle_passed": True,
        "startup_ramp_id": design.STARTUP_RAMP_ID,
        "startup_velocity_scale": design.startup_velocity_scale(step),
        "startup_ramp_active": design.startup_velocity_scale(step) < 1.0,
        "startup_ramp_residual_count": design.ACTUATOR_COUNT,
        "startup_ramp_maximum_absolute_residual_rad_s": 0.0,
    }


def _manifest_paths_value(value: Any) -> list[str]:
    if (
        not isinstance(value, list)
        or any(not isinstance(path, str) or not path for path in value)
    ):
        raise R23D40EvaluationError("R23D40_TERMINAL_MANIFEST_NOT_STRING_ARRAY")
    return value


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    traces_by_arm = {
        item.arm_id: [
            _synthetic_row(item, step) for step in range(design.CONTROLLER_STEPS)
        ]
        for item in design.cells()
    }
    validations = [
        validate_trace(item.cell_id, traces_by_arm[item.arm_id])
        for item in design.cells()
    ]
    first = design.cells()[0]
    mutated = copy.deepcopy(traces_by_arm[first.arm_id])
    mutated[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
    rejected = validate_trace(first.cell_id, mutated)
    mutated_scale = copy.deepcopy(traces_by_arm["positive_heading"])
    mutated_scale[179]["startup_velocity_scale"] = float(
        mutated_scale[179]["startup_velocity_scale"]
    ) + 0.001
    positive = design.cell(design.STAGE_ID, design.ENGINE_ID, "positive_heading")
    rejected_scale = validate_trace(positive.cell_id, mutated_scale)
    mutated_identity = copy.deepcopy(traces_by_arm["negative_heading"])
    mutated_identity[0]["startup_ramp_id"] = "wrong"
    negative = design.cell(design.STAGE_ID, design.ENGINE_ID, "negative_heading")
    rejected_identity = validate_trace(negative.cell_id, mutated_identity)
    measurement_rows = {
        arm_id: inherited._measurement_rows(rows)
        for arm_id, rows in traces_by_arm.items()
    }
    measurement = inherited.measure_cycle_integrated_response(measurement_rows)
    zero_yaw_rows = copy.deepcopy(measurement_rows)
    for rows in zero_yaw_rows.values():
        for row in rows:
            row["measured_yaw_rad"] = 0.0
    rejected_measurement = inherited.measure_cycle_integrated_response(zero_yaw_rows)
    valid_manifest_shapes = [
        _manifest_paths_value([]),
        _manifest_paths_value(["one"]),
        _manifest_paths_value(["one", "two", "three"]),
    ]
    invalid_manifest_count = 0
    for value in ("one", {"path": "one"}, [""], [1]):
        try:
            _manifest_paths_value(value)
        except R23D40EvaluationError:
            invalid_manifest_count += 1
    if (
        not all(validation["ok"] for validation in validations)
        or rejected["ok"]
        or rejected_scale["ok"]
        or rejected_identity["ok"]
        or measurement.get("passed") is not True
        or rejected_measurement.get("passed") is not False
        or [len(value) for value in valid_manifest_shapes] != [0, 1, 3]
        or invalid_manifest_count != 4
    ):
        raise R23D40EvaluationError("R23D40_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d40_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": len(design.cells()),
        "valid_trace_canary_count": len(validations),
        "trace_mutation_rejection_count": 3,
        "startup_ramp_mutation_rejection_count": 2,
        "cycle_integrated_positive_canary_count": 1,
        "cycle_integrated_negative_control_count": 1,
        "valid_manifest_shape_canary_count": 3,
        "invalid_manifest_shape_rejection_count": 4,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def load_declaration() -> dict[str, Any]:
    """Validate only the live R40 contract and its immediate frozen lineage."""

    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D40EvaluationError(
            f"R23D40_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    successor = value.get("scientifically_distinct_successor", {})
    gates = value.get("frozen_common_physical_gates", {})
    lineage = value.get("immutable_lineage", {})
    measurement = value.get("cycle_integrated_measurement", {})
    selector = value.get("selector", {})
    entry = value.get("zero_world_entry_gate", {})
    claims = value.get("claims", {})
    lineage_bindings = {
        "rapier_validation_closure_raw_sha256":
            ROOT / "r23d32_finite_rapier_turning_replication_closure_v1.json",
        "godot_validation_closure_raw_sha256":
            ROOT / "r23d35_godot_trace_recovery_closure_v1.json",
        "mujoco_development_closure_raw_sha256":
            ROOT / "r23d39_mujoco_startup_ramp_turning_closure_v1.json",
        "measurement_closure_raw_sha256":
            ROOT / "r23d31_cycle_integrated_directional_response_closure_v1.json",
    }
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d40_three_engine_startup_ramp_turning_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("release_gate_id") != design.RELEASE_GATE_ID
        or value.get("study_classification")
        != "prospective_exact_finite_three_engine_portable_turning_validation"
        or successor.get("fresh_held_out_seed") != design.CAMPAIGN_SEED
        or successor.get("controller_policy_id") != design.POLICY_ID
        or successor.get("controller_behavior_changed") is not False
        or successor.get("measurement_changed") is not False
        or successor.get("threshold_changed") is not False
        or successor.get("canonical_startup_transform_inherited_unchanged")
        is not True
        or successor.get("startup_ramp_id") != design.STARTUP_RAMP_ID
        or successor.get("startup_ramp_step_count") != design.STARTUP_RAMP_STEPS
        or successor.get("startup_ramp_applied_to_all_engines") is not True
        or successor.get("gait_phase_memory_advances_unchanged") is not True
        or successor.get("engine_specific_gait_logic_permitted") is not False
        or successor.get("engine_identity_input_to_controller_permitted") is not False
        or successor.get("command_sign_branching_permitted") is not False
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
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("startup_ramp_id") != design.STARTUP_RAMP_ID
        or matrix.get("startup_ramp_step_count") != design.STARTUP_RAMP_STEPS
        or matrix.get("startup_ramp_active_step_count")
        != design.STARTUP_RAMP_STEPS - 1
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("recovery_duration_steps") != design.RECOVERY_DURATION_STEPS
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or gates.get("minimum_final_forward_displacement_m") != 0.030123046875
        or gates.get("maximum_tilt_rad") != 0.6
        or gates.get("minimum_torso_height_m") != 0.2499708652072946
        or gates.get("minimum_contact_cycles_per_limb") != 2
        or gates.get("exact_startup_ramp_composition_required") is not True
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad")
        != 0.01
        or measurement.get("both_signed_arms_required") is not True
        or measurement.get("reference_arm_required") is not True
        or selector.get("positive_qsdk_r23_satisfied") is not True
        or selector.get("positive_cross_engine_equivalence") is not False
        or entry.get("campaign_local_gates_only") is not True
        or entry.get("physical_execution_authorized") is not False
        or claims.get("finite_three_engine_turning") is not False
        or claims.get("q_sdk_r23_satisfied") is not False
        or lineage.get("historical_result_reinterpreted") is not False
        or lineage.get("historical_world_reused_as_a_new_cell") is not False
        or lineage.get("same_identity_rerun_permitted") is not False
        or any(
            lineage.get(field) != raw_sha256(path)
            for field, path in lineage_bindings.items()
        )
    )
    if invalid:
        raise R23D40EvaluationError("R23D40_DECLARATION_IDENTITY_INVALID")
    return value


# The retained R34 trace/CAS implementation is generic across engine IDs.
# Rebind its declaration hook after replacing the R39 single-engine contract.
inherited.load_declaration = load_declaration


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D40EvaluationError("R23D40_SOURCE_COMMIT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D40EvaluationError("R23D40_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, expected, strict=True):
        evaluation, rows = evaluate_entry(
            entry,
            item,
            expected_source_commit=expected_source_commit,
        )
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows
    engine_results: dict[str, Any] = {}
    for engine_id in design.ENGINE_IDS:
        engine_cells = [item for item in expected if item.engine_id == engine_id]
        engine_evaluations = [
            evaluation
            for evaluation in evaluations
            if evaluation["engine_id"] == engine_id
        ]
        all_execution_valid = all(
            row["execution_valid"] for row in engine_evaluations
        )
        all_physical_passed = all(
            row["common_physical_gate_passed"] for row in engine_evaluations
        )
        measurement: dict[str, Any] | None = None
        measurement_failures: list[str] = []
        if all_execution_valid:
            measurement = inherited.measure_cycle_integrated_response(
                {
                    item.arm_id: inherited._measurement_rows(
                        rows_by_cell[item.cell_id]
                    )
                    for item in engine_cells
                }
            )
            measurement_failures = [
                gate
                for gate, passed in measurement["gates"].items()
                if not passed
            ]
        passed = (
            all_execution_valid
            and all_physical_passed
            and bool(measurement and measurement.get("passed") is True)
        )
        engine_results[engine_id] = {
            "all_cells_execution_valid": all_execution_valid,
            "all_common_physical_gates_passed": all_physical_passed,
            "cycle_integrated_measurement": measurement,
            "measurement_failure_codes": measurement_failures,
            "passed": passed,
        }
    complete = len(evaluations) == len(expected)
    positive = complete and all(
        result["passed"] for result in engine_results.values()
    )
    any_invalid = any(not row["execution_valid"] for row in evaluations)
    classification = (
        "valid_complete_positive_finite_three_engine_portable_turning_validation"
        if positive
        else "invalid_or_incomplete_three_engine_portable_turning_validation"
        if any_invalid
        else "valid_complete_negative_finite_three_engine_portable_turning_validation"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["rapier_parry_r23d29_turning"] = bool(
        engine_results["rapier_parry"]["passed"]
    )
    claims["godot_jolt_r23d29_turning"] = bool(
        engine_results["godot_jolt"]["passed"]
    )
    claims["mujoco_r23d29_turning"] = bool(engine_results["mujoco"]["passed"])
    claims["finite_three_engine_turning"] = positive
    claims["portable_basic_turning"] = positive
    claims["q_sdk_r23_satisfied"] = positive
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
        "all_declared_cells_executed_or_retained_as_failures": complete,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_held_out_condition_consumed": True,
        "startup_ramp_id": design.STARTUP_RAMP_ID,
        "terminal_restoration_or_taper_invoked": False,
        "cross_engine_equivalence_test_invoked": False,
        "claims": claims,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    traces_by_cell = {
        item.cell_id: [
            _synthetic_row(item, step)
            for step in range(design.CONTROLLER_STEPS)
        ]
        for item in design.cells()
    }
    validations = [
        validate_trace(item.cell_id, traces_by_cell[item.cell_id])
        for item in design.cells()
    ]
    first = design.cells()[0]
    mutated_segment = copy.deepcopy(traces_by_cell[first.cell_id])
    mutated_segment[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
    rejected_segment = validate_trace(first.cell_id, mutated_segment)
    mutated_scale = copy.deepcopy(traces_by_cell[first.cell_id])
    mutated_scale[179]["startup_velocity_scale"] = float(
        mutated_scale[179]["startup_velocity_scale"]
    ) + 0.001
    rejected_scale = validate_trace(first.cell_id, mutated_scale)
    engine_measurements = {}
    for engine_id in design.ENGINE_IDS:
        engine_measurements[engine_id] = inherited.measure_cycle_integrated_response(
            {
                item.arm_id: inherited._measurement_rows(
                    traces_by_cell[item.cell_id]
                )
                for item in design.cells()
                if item.engine_id == engine_id
            }
        )
    valid_manifest_shapes = [
        _manifest_paths_value([]),
        _manifest_paths_value(["one"]),
        _manifest_paths_value(["one", "two", "three"]),
    ]
    invalid_manifest_count = 0
    for value in ("one", {"path": "one"}, [""], [1]):
        try:
            _manifest_paths_value(value)
        except R23D40EvaluationError:
            invalid_manifest_count += 1
    if (
        not all(validation["ok"] for validation in validations)
        or rejected_segment["ok"]
        or rejected_scale["ok"]
        or not all(
            measurement.get("passed") is True
            for measurement in engine_measurements.values()
        )
        or [len(value) for value in valid_manifest_shapes] != [0, 1, 3]
        or invalid_manifest_count != 4
    ):
        raise R23D40EvaluationError("R23D40_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d40_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": len(design.cells()),
        "valid_trace_canary_count": len(validations),
        "trace_mutation_rejection_count": 2,
        "startup_ramp_mutation_rejection_count": 1,
        "cycle_integrated_positive_canary_count": len(engine_measurements),
        "valid_manifest_shape_canary_count": 3,
        "invalid_manifest_shape_rejection_count": invalid_manifest_count,
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
            marker = "QSDK_R23D40_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D40_TRACE_RETAINED "
        else:
            manifest_value = json.loads(args.manifest.read_text(encoding="utf-8"))
            paths = _manifest_paths_value(manifest_value)
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries, expected_source_commit=args.expected_source_commit
            )
            marker = "QSDK_R23D40_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D40EvaluationError,
        inherited.R23D34EvaluationError,
        inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D40_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
