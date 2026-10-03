"""Evaluator and retained-trace gate for QSDK-R23D56."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d34_native_r23d29_transfer_evaluator as inherited
import r23d56_godot_valid_route_actuator_phase_characterization as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d48_trace.ps1"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
REPORT_SCHEMA = "sporespore_qsdk_r23d56_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d56_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d56_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d56_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d56_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "live_fixture_actuator_cap_binding_verified": False,
    "actuator_phase_characterization_complete": False,
    "turning_mechanism_selected": False,
    "godot_jolt_r23d29_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D56EvaluationError(RuntimeError):
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


def _same_existing_file(left: Path, right: Path) -> bool:
    """Compare existing filesystem identity, not Windows namespace spelling."""

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


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D56EvaluationError(
            f"R23D56_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    lineage = value.get("immutable_lineage", {})
    successor = value.get("scientifically_distinct_successor", {})
    matrix = value.get("frozen_matrix", {})
    observation = value.get("required_observation", {})
    cap_binding = value.get("required_live_fixture_cap_binding", {})
    characterization = value.get("predeclared_characterization", {})
    contextual_gates = value.get("contextual_common_physical_gates", {})
    threshold_provenance = value.get("threshold_provenance", {})
    adequacy = value.get("adequacy", {})
    evidence = value.get("evidence_integrity", {})
    claims = value.get("claims", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("question_class") != "development"
        or value.get("physical_question_declared") is not True
        or value.get("physical_campaign_opened") is not False
        or value.get("study_classification")
        != "exact_outcome_exposed_same_seed_godot_jolt_post_r23d55_valid_route_actuator_phase_contact_characterization_development"
        or lineage.get("development_parent_commit")
        != "169671734bd9d9fa7cdb837262aa6d5a0d911c6c"
        or lineage.get("r23d54_closure_raw_sha256")
        != raw_sha256(
            ROOT / "r23d54_godot_actuator_phase_characterization_closure_v1.json"
        )
        or lineage.get("r23d54_identity_consumed") is not True
        or lineage.get("r23d54_result")
        != "invalid_complete_outcome_exposed_godot_actuator_phase_characterization_development"
        or lineage.get("r23d54_observed_failure_code")
        != "SDK_ACTUATOR_PHASE_APPLICATION_MISMATCH:front_left_hip_motor"
        or lineage.get("r23d54_valid_observation_row_count") != 0
        or lineage.get("r23d54_same_identity_rerun_permitted") is not False
        or lineage.get("r23d54_result_reinterpreted") is not False
        or lineage.get("r23d55_contract_raw_sha256")
        != raw_sha256(
            ROOT / "r23d55_godot_live_fixture_actuator_cap_conformance_v1.json"
        )
        or lineage.get("r23d55_audit_compatibility_raw_sha256")
        != raw_sha256(ROOT / "r23d55_post_rc7_audit_compatibility_v1.json")
        or lineage.get("r23d55_zero_world_result_passed") is not True
        or lineage.get("r23d55_physical_world_count") != 0
        or lineage.get("lca1_rc7_closure_raw_sha256")
        != raw_sha256(
            SDK_ROOT
            / "locomotion_campaign_attestation_v1_recommissioning_rc7_closure.json"
        )
        or lineage.get(
            "lca1_rc7_campaign_local_executor_implementation_commissioned"
        )
        is not True
        or lineage.get("r23d53_closure_raw_sha256")
        != raw_sha256(
            ROOT / "r23d53_godot_warmup_preserving_origin_reanchor_closure_v1.json"
        )
        or lineage.get("r23d53_command_contrast_diagnosis_closure_raw_sha256")
        != raw_sha256(
            ROOT.parent
            / "trace_analysis"
            / "r23d53_godot_command_contrast_diagnosis_closure_v1.json"
        )
        or lineage.get("actuator_phase_observation_contract_raw_sha256")
        != raw_sha256(
            ROOT.parent
            / "trace_analysis"
            / "godot_actuator_phase_observation_contract_v1.json"
        )
        or lineage.get("r23d53_identity_consumed") is not True
        or lineage.get("r23d53_turning_positive") is not False
        or lineage.get("r23d53_result_reinterpreted") is not False
        or lineage.get("r23d53_world_reused_as_r23d56_cell") is not False
        or lineage.get("r23d53_same_identity_rerun_permitted") is not False
        or successor.get("comparator_campaign_id")
        != "QSDK-R23D54-GODOT-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
        or successor.get("same_outcome_exposed_seed_as_comparator") is not True
        or successor.get("same_initial_perturbation_as_comparator") is not True
        or successor.get(
            "same_morphology_controller_startup_transform_material_solver_schedule_horizon_task_origin_policy_and_contextual_gates_as_comparator"
        )
        is not True
        or successor.get("declared_physics_model_change_count") != 0
        or successor.get("declared_controller_change_count") != 0
        or successor.get("declared_measurement_change_count") != 0
        or successor.get("declared_live_host_parameter_binding_change_count")
        != 1
        or successor.get("same_actuator_phase_observation_as_r23d54") is not True
        or successor.get("complete_three_cell_matrix_must_be_run") is not True
        or successor.get("historical_world_reused_as_r23d56_cell") is not False
        or successor.get("r23d54_terminal_or_trace_reused_as_r23d56_cell")
        is not False
        or successor.get("controller_source_or_gain_changed") is not False
        or successor.get("engine_identity_input_permitted") is not False
        or successor.get("arm_identity_input_permitted") is not False
        or successor.get("outcome_branching_permitted") is not False
        or successor.get("threshold_changed") is not False
        or successor.get("fresh_held_out_condition_consumed") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.ENGINE_IDS)
        or matrix.get("ordered_candidate_ids") != [design.CANDIDATE_ID]
        or matrix.get("ordered_arm_ids") != list(design.ARM_OFFSETS)
        or matrix.get("ordered_heading_offsets_rad")
        != list(design.ARM_OFFSETS.values())
        or matrix.get("declared_cell_count") != len(design.cells())
        or matrix.get("declared_world_count") != len(design.cells())
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("morphology_id") != design.MORPHOLOGY_ID
        or matrix.get("controller_policy_id") != design.POLICY_ID
        or matrix.get("task_frame_origin_policy_id")
        != design.TASK_FRAME_ORIGIN_POLICY_ID
        or matrix.get("initial_schedule_bind_semantic_step")
        != design.INITIAL_SCHEDULE_BIND_STEP
        or matrix.get("fixed_origin_last_semantic_step")
        != design.FIXED_ORIGIN_LAST_SEMANTIC_STEP
        or matrix.get("expected_reanchor_semantic_steps")
        != list(design.EXPECTED_REANCHOR_STEPS)
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive")
        != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("recovery_duration_steps")
        != design.RECOVERY_DURATION_STEPS
        or matrix.get("startup_transform_id") != design.STARTUP_TRANSFORM_ID
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome")
        is not True
        or observation.get("schema_version")
        != design.ACTUATOR_PHASE_OBSERVATION_SCHEMA
        or observation.get("application_receipt_schema_version")
        != design.APPLICATION_RECEIPT_SCHEMA
        or observation.get("required_trace_row_count_per_cell")
        != design.CONTROLLER_STEPS
        or observation.get("required_application_count_per_trace_row")
        != design.ACTUATOR_COUNT
        or observation.get("required_application_count_per_cell")
        != design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        or observation.get("required_total_trace_row_count")
        != design.CONTROLLER_STEPS * len(design.cells())
        or observation.get("required_total_application_count")
        != design.CONTROLLER_STEPS * design.ACTUATOR_COUNT * len(design.cells())
        or observation.get("configured_parameter_readback_only") is not True
        or observation.get("measured_motor_torque_available") is not False
        or observation.get("measured_motor_impulse_available") is not False
        or cap_binding.get("policy_id")
        != design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
        or cap_binding.get("fixture_composition_schema_version")
        != design.LIVE_FIXTURE_COMPOSITION_SCHEMA
        or cap_binding.get("binding_receipt_schema_version")
        != design.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA
        or cap_binding.get("validation_receipt_schema_version")
        != design.LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA
        or cap_binding.get("required_before_first_authoritative_controller_step")
        is not True
        or cap_binding.get("expected_actuator_count") != design.ACTUATOR_COUNT
        or cap_binding.get("exact_write_count") != design.ACTUATOR_COUNT
        or cap_binding.get("exact_readback_count") != design.ACTUATOR_COUNT
        or cap_binding.get("maximum_readback_error_nms")
        != design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        or cap_binding.get("configured_parameter_readback_only") is not True
        or cap_binding.get("measured_motor_torque_available") is not False
        or cap_binding.get("measured_motor_impulse_available") is not False
        or characterization.get(
            "classification_depends_only_on_complete_execution_and_observation_integrity"
        )
        is not True
        or characterization.get(
            "common_physical_gates_are_contextual_not_characterization_acceptance_thresholds"
        )
        is not True
        or characterization.get("turning_gate_invoked") is not False
        or characterization.get("mechanism_selection_rule_count") != 0
        or characterization.get("postoutcome_threshold_creation_permitted")
        is not False
        or contextual_gates.get("inherited_unchanged_from_r23d54_and_r23d53")
        is not True
        or contextual_gates.get("minimum_final_forward_displacement_m")
        != 0.030123046875
        or contextual_gates.get("maximum_tilt_rad") != 0.6
        or contextual_gates.get("minimum_torso_height_m")
        != 0.2499708652072946
        or contextual_gates.get("minimum_contact_cycles_per_limb") != 2
        or threshold_provenance.get(
            "observed_r23d53_or_r23d54_values_used_to_set_characterization_thresholds"
        )
        is not False
        or threshold_provenance.get("empirical_characterization_threshold_count")
        != 0
        or threshold_provenance.get("observation_numeric_tolerance") != 2.5e-7
        or threshold_provenance.get("population_margin") is not False
        or threshold_provenance.get("cross_engine_equivalence_margin") is not False
        or threshold_provenance.get("threshold_change_count") != 0
        or adequacy.get("outcome_exposed_development_characterization") is not True
        or adequacy.get("all_three_arms_required") is not True
        or adequacy.get("causal_mechanism_selection_attempted") is not False
        or adequacy.get("turning_acceptance_attempted") is not False
        or adequacy.get("population_inference_attempted") is not False
        or adequacy.get("cross_engine_equivalence_attempted") is not False
        or adequacy.get("fresh_held_out_validation_attempted") is not False
        or evidence.get("complete_observation_required_before_terminal_entry")
        is not True
        or evidence.get("content_addressed_trace_retention_required") is not True
        or evidence.get("authority_repo_root_required_for_complete_evaluation")
        is not True
        or evidence.get("shared_terminal_execution_projection_required") is not True
        or evidence.get("success_schema_reads_nested_execution_counts") is not True
        or evidence.get("failure_schemas_read_root_counts") is not True
        or evidence.get("ambiguous_or_malformed_terminal_shapes_rejected")
        is not True
        or claims.get("physical_world_opened") is not False
        or claims.get("actuator_phase_characterization_complete") is not False
        or claims.get("turning_mechanism_selected") is not False
        or claims.get("godot_jolt_turning_validation") is not False
        or claims.get("finite_three_engine_turning") is not False
        or claims.get("portable_basic_turning") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D56EvaluationError("R23D56_DECLARATION_IDENTITY_INVALID")
    return value

# Reuse the accepted R23D34 fixed-horizon trace/CAS implementation, rebound to
# this one-engine post-R23D55 valid-route development characterization. The
# matrix, controller, observation, common walking gates, and directional
# measurement stay unchanged; only the declared live-fixture cap binding differs.
inherited.design = design
inherited.DECLARATION_PATH = DECLARATION_PATH
inherited.PUBLISHER_PATH = PUBLISHER_PATH
inherited.PUBLISHER_MARKER = PUBLISHER_MARKER
inherited.REPORT_SCHEMA = REPORT_SCHEMA
inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
inherited.FALSE_CLAIMS = FALSE_CLAIMS
inherited.load_declaration = load_declaration

_BASE_VALIDATE_TRACE = inherited.validate_trace


OBSERVATION_KEYS = frozenset(
    {
        "schema_version",
        "semantic_step",
        "controller_step_receipt_sha256",
        "application_receipt_schema_version",
        "ordered_actuator_ids",
        "ordered_limb_ids",
        "readback_tolerance",
        "ordered_applications",
        "after_contact_observation_complete",
        "configured_motor_parameters_only",
        "measured_motor_torque_available",
        "measured_motor_impulse_available",
        "world_build_count",
        "physical_acceptance_authority",
    }
)
APPLICATION_KEYS = frozenset(
    {
        "actuator_id",
        "joint_id",
        "host_joint_id",
        "limb_id",
        "limb_joint_index",
        "requested_target_position_rad",
        "clamped_target_position_rad",
        "controller_target_velocity_rad_s",
        "maximum_target_speed_rad_s",
        "host_applied_target_velocity_rad_s",
        "motor_target_velocity_readback_rad_s",
        "motor_target_velocity_readback_error_rad_s",
        "declared_maximum_impulse_nms",
        "motor_maximum_impulse_readback_nms",
        "motor_maximum_impulse_readback_error_nms",
        "position_saturated",
        "velocity_saturated",
        "slew_limited",
        "host_additional_clamp_applied",
        "target_velocity_readback_matches",
        "maximum_impulse_readback_matches",
        "local_phase_step_before",
        "gait_step_before",
        "release_hold_step_count_before",
        "foot_contact_before",
        "foot_contact_after",
    }
)


def _sha256_digest(value: Any) -> bool:
    return (
        isinstance(value, str)
        and value.startswith("sha256:")
        and len(value) == 71
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _cap_binding_projection_failures(
    entry: Mapping[str, Any], rows: Sequence[Mapping[str, Any]]
) -> list[str]:
    predicates = entry.get("godot_execution_predicates")
    if not isinstance(predicates, dict):
        return ["R23D56_CAP_BINDING_PREDICATE_PROJECTION_MISSING"]
    raw_summary = predicates.get("raw_sdk_authority_summary")
    if not isinstance(raw_summary, dict):
        return ["R23D56_CAP_BINDING_SDK_SUMMARY_MISSING"]
    receipt = raw_summary.get("r23d56_live_fixture_actuator_cap_binding_receipt")
    if not isinstance(receipt, dict):
        return ["R23D56_CAP_BINDING_RECEIPT_MISSING"]
    if not rows or not isinstance(rows[0], Mapping):
        return ["R23D56_CAP_BINDING_TRACE_MISSING"]
    observation = rows[0].get("actuator_phase_observation")
    if not isinstance(observation, dict):
        return ["R23D56_CAP_BINDING_TRACE_OBSERVATION_MISSING"]
    applications = observation.get("ordered_applications")
    actuator_ids = observation.get("ordered_actuator_ids")
    ordered_bindings = receipt.get("ordered_bindings")
    receipt_actuator_ids = receipt.get("ordered_actuator_ids")
    invalid = (
        raw_summary.get("r23d56_live_fixture_actuator_cap_binding_policy_id")
        != design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
        or raw_summary.get(
            "r23d56_live_fixture_actuator_cap_binding_integrity_passed"
        )
        is not True
        or receipt.get("schema_version")
        != design.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA
        or receipt.get("ok") is not True
        or receipt.get("failure_code") != ""
        or receipt.get("policy_id") != design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
        or receipt.get("fixture_composition_schema_version")
        != design.LIVE_FIXTURE_COMPOSITION_SCHEMA
        or receipt.get("validated_actuator_count") != design.ACTUATOR_COUNT
        or receipt.get("validated_limb_count") != len(design.LIMB_IDS)
        or receipt.get("unique_host_joint_object_count") != design.ACTUATOR_COUNT
        or receipt.get("write_count") != design.ACTUATOR_COUNT
        or receipt.get("readback_count") != design.ACTUATOR_COUNT
        or not _finite(receipt.get("maximum_postbinding_readback_error_nms"))
        or float(receipt.get("maximum_postbinding_readback_error_nms", math.inf))
        > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        or receipt.get("all_fixture_composition_markers_valid") is not True
        or receipt.get("all_host_joint_names_valid") is not True
        or receipt.get("all_postbinding_readbacks_match") is not True
        or receipt.get("configured_parameter_readback_only") is not True
        or receipt.get("measured_motor_torque_available") is not False
        or receipt.get("measured_motor_impulse_available") is not False
        or receipt.get("world_attempt_count") != 0
        or receipt.get("world_build_count") != 0
        or receipt.get("physics_state_modified") is not False
        or receipt.get("physical_acceptance_authority") is not False
        or not isinstance(applications, list)
        or not isinstance(actuator_ids, list)
        or not isinstance(ordered_bindings, list)
        or not isinstance(receipt_actuator_ids, list)
        or receipt_actuator_ids != actuator_ids
        or len(ordered_bindings) != design.ACTUATOR_COUNT
        or len(applications) != design.ACTUATOR_COUNT
    )
    if invalid:
        return ["R23D56_CAP_BINDING_RECEIPT_INVALID"]
    for binding, application, actuator_id in zip(
        ordered_bindings, applications, actuator_ids, strict=True
    ):
        if not isinstance(binding, dict) or not isinstance(application, dict):
            return ["R23D56_CAP_BINDING_APPLICATION_SHAPE_INVALID"]
        binding_error = binding.get("readback_error_nms")
        if (
            binding.get("actuator_id") != actuator_id
            or binding.get("actuator_id") != application.get("actuator_id")
            or binding.get("joint_id") != application.get("joint_id")
            or binding.get("host_joint_id") != application.get("host_joint_id")
            or binding.get("limb_id") != application.get("limb_id")
            or not _finite(binding.get("declared_maximum_impulse_nms"))
            or not _finite(binding.get("motor_maximum_impulse_readback_nms"))
            or not _finite(binding_error)
            or not _finite(application.get("declared_maximum_impulse_nms"))
            or not _finite(application.get("motor_maximum_impulse_readback_nms"))
            or float(binding.get("declared_maximum_impulse_nms"))
            != float(application.get("declared_maximum_impulse_nms"))
            or abs(
                float(binding.get("motor_maximum_impulse_readback_nms"))
                - float(application.get("motor_maximum_impulse_readback_nms"))
            )
            > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
            or float(binding_error)
            > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
            or binding.get("readback_matches") is not True
        ):
            return ["R23D56_CAP_BINDING_APPLICATION_IDENTITY_INVALID"]
    return []


def _observation_failures(
    row: Mapping[str, Any], semantic_step: int
) -> tuple[list[str], tuple[Any, ...] | None]:
    failures: list[str] = []
    observation = row.get("actuator_phase_observation")
    if not isinstance(observation, dict):
        return ["OBSERVATION_MISSING"], None
    applications = observation.get("ordered_applications")
    actuator_ids = observation.get("ordered_actuator_ids")
    limb_ids = observation.get("ordered_limb_ids")
    tolerance = observation.get("readback_tolerance")
    header_valid = (
        set(observation) == OBSERVATION_KEYS
        and observation.get("schema_version")
        == design.ACTUATOR_PHASE_OBSERVATION_SCHEMA
        and observation.get("application_receipt_schema_version")
        == design.APPLICATION_RECEIPT_SCHEMA
        and observation.get("semantic_step") == semantic_step
        and _sha256_digest(observation.get("controller_step_receipt_sha256"))
        and observation.get("after_contact_observation_complete") is True
        and observation.get("configured_motor_parameters_only") is True
        and observation.get("measured_motor_torque_available") is False
        and observation.get("measured_motor_impulse_available") is False
        and observation.get("world_build_count") == 0
        and observation.get("physical_acceptance_authority") is False
        and _finite(tolerance)
        and float(tolerance) == 2.5e-7
        and isinstance(applications, list)
        and isinstance(actuator_ids, list)
        and isinstance(limb_ids, list)
        and len(applications) == design.ACTUATOR_COUNT
        and len(actuator_ids) == design.ACTUATOR_COUNT
        and len(limb_ids) == len(design.LIMB_IDS)
        and all(isinstance(value, str) and value for value in actuator_ids)
        and len(set(actuator_ids)) == len(actuator_ids)
        and all(isinstance(value, str) and value for value in limb_ids)
        and len(set(limb_ids)) == len(limb_ids)
    )
    if not header_valid:
        return ["OBSERVATION_HEADER"], None
    phase_rows = row.get("ordered_limb_phase_before")
    contacts_before = row.get("ordered_foot_contacts_before")
    contacts_after = row.get("ordered_foot_contacts_after")
    if (
        not isinstance(phase_rows, list)
        or not isinstance(contacts_before, dict)
        or not isinstance(contacts_after, dict)
        or len(phase_rows) != len(limb_ids)
        or set(contacts_before) != set(limb_ids)
        or set(contacts_after) != set(limb_ids)
        or any(type(value) is not bool for value in contacts_before.values())
        or any(type(value) is not bool for value in contacts_after.values())
    ):
        return ["OBSERVATION_CONTACT_CONTAINER"], None
    phases: dict[str, Mapping[str, Any]] = {}
    observed_limb_order: list[str] = []
    for phase in phase_rows:
        if not isinstance(phase, dict):
            return ["OBSERVATION_PHASE_ROW"], None
        limb_id = phase.get("limb_id")
        if (
            not isinstance(limb_id, str)
            or not limb_id
            or limb_id in phases
            or not _integer(phase.get("local_phase_step"))
            or not _integer(phase.get("gait_step"))
            or not _integer(phase.get("release_hold_step_count"))
        ):
            return ["OBSERVATION_PHASE_LINK"], None
        phases[limb_id] = phase
        observed_limb_order.append(limb_id)
    if observed_limb_order != limb_ids:
        return ["OBSERVATION_LIMB_ORDER"], None

    links: list[tuple[Any, ...]] = []
    limb_joint_indexes: dict[str, list[int]] = {limb_id: [] for limb_id in limb_ids}
    for index, application in enumerate(applications):
        if not isinstance(application, dict) or set(application) != APPLICATION_KEYS:
            failures.append(f"OBSERVATION_APPLICATION_SHAPE:{index}")
            continue
        actuator_id = application.get("actuator_id")
        limb_id = application.get("limb_id")
        numeric_fields = (
            "requested_target_position_rad",
            "clamped_target_position_rad",
            "controller_target_velocity_rad_s",
            "maximum_target_speed_rad_s",
            "host_applied_target_velocity_rad_s",
            "motor_target_velocity_readback_rad_s",
            "motor_target_velocity_readback_error_rad_s",
            "declared_maximum_impulse_nms",
            "motor_maximum_impulse_readback_nms",
            "motor_maximum_impulse_readback_error_nms",
        )
        boolean_fields = (
            "position_saturated",
            "velocity_saturated",
            "slew_limited",
            "host_additional_clamp_applied",
            "target_velocity_readback_matches",
            "maximum_impulse_readback_matches",
            "foot_contact_before",
            "foot_contact_after",
        )
        if (
            actuator_id != actuator_ids[index]
            or not isinstance(application.get("joint_id"), str)
            or not application.get("joint_id")
            or not isinstance(application.get("host_joint_id"), str)
            or not application.get("host_joint_id")
            or limb_id not in phases
            or not _integer(application.get("limb_joint_index"))
            or application.get("limb_joint_index") not in (0, 1)
            or any(not _finite(application.get(field)) for field in numeric_fields)
            or any(type(application.get(field)) is not bool for field in boolean_fields)
            or not _integer(application.get("local_phase_step_before"))
            or not _integer(application.get("gait_step_before"))
            or not _integer(application.get("release_hold_step_count_before"))
        ):
            failures.append(f"OBSERVATION_APPLICATION_IDENTITY:{index}")
            continue
        phase = phases[str(limb_id)]
        controller = float(application["controller_target_velocity_rad_s"])
        maximum_speed = float(application["maximum_target_speed_rad_s"])
        applied = float(application["host_applied_target_velocity_rad_s"])
        target_readback = float(application["motor_target_velocity_readback_rad_s"])
        target_error = float(
            application["motor_target_velocity_readback_error_rad_s"]
        )
        declared_impulse = float(application["declared_maximum_impulse_nms"])
        impulse_readback = float(application["motor_maximum_impulse_readback_nms"])
        impulse_error = float(
            application["motor_maximum_impulse_readback_error_nms"]
        )
        linked = (
            application["local_phase_step_before"] == phase["local_phase_step"]
            and application["gait_step_before"] == phase["gait_step"]
            and application["release_hold_step_count_before"]
            == phase["release_hold_step_count"]
            and application["foot_contact_before"] is contacts_before[str(limb_id)]
            and application["foot_contact_after"] is contacts_after[str(limb_id)]
            and maximum_speed > 0.0
            and declared_impulse > 0.0
            and abs(controller) <= maximum_speed + float(tolerance)
            and abs(applied - controller) <= float(tolerance)
            and abs(target_readback - applied) <= float(tolerance)
            and abs(target_error - abs(target_readback - applied)) <= 1.0e-15
            and abs(impulse_error - abs(impulse_readback - declared_impulse))
            <= 1.0e-15
            and target_error <= float(tolerance)
            and impulse_error <= float(tolerance)
            and application["host_additional_clamp_applied"] is False
            and application["target_velocity_readback_matches"] is True
            and application["maximum_impulse_readback_matches"] is True
        )
        if not linked:
            failures.append(f"OBSERVATION_APPLICATION_LINK:{index}")
            continue
        limb_joint_indexes[str(limb_id)].append(
            int(application["limb_joint_index"])
        )
        links.append(
            (
                actuator_id,
                application["joint_id"],
                application["host_joint_id"],
                limb_id,
                application["limb_joint_index"],
            )
        )
    if any(sorted(indexes) != [0, 1] for indexes in limb_joint_indexes.values()):
        failures.append("OBSERVATION_LIMB_JOINT_CARDINALITY")
    return failures, (
        tuple(actuator_ids),
        tuple(limb_ids),
        tuple(links),
        observation["controller_step_receipt_sha256"],
    )


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    summary = _BASE_VALIDATE_TRACE(cell_id, rows)
    failures = list(summary.get("failure_codes", []))
    governor = design.SupportLossConditionedStartup()
    active_count = 0
    zero_count = 0
    unity_count = 0
    observed_transition_steps: list[int] = []
    expected_origin: list[float] | None = None
    expected_segment = ""
    expected_reanchor_count = 0
    expected_actuator_ids: tuple[Any, ...] | None = None
    expected_limb_ids: tuple[Any, ...] | None = None
    expected_links: tuple[Any, ...] | None = None
    receipt_digests: set[str] = set()
    observation_row_count = 0
    application_count = 0
    maximum_target_error = 0.0
    maximum_impulse_error = 0.0
    if isinstance(rows, list):
        for semantic_step, row in enumerate(rows):
            if not isinstance(row, dict):
                continue
            contacts = row.get("ordered_foot_contacts_before")
            try:
                startup = governor.step(semantic_step, contacts)
            except (design.StartupTransformError, TypeError):
                failures.append(f"R23D56_STARTUP_CONTACTS_INVALID:{semantic_step}")
                continue
            expected_scale = float(startup["startup_velocity_scale"])
            startup_valid = (
                row.get("startup_ramp_id") == design.STARTUP_RAMP_ID
                and row.get("startup_transform_id") == design.STARTUP_TRANSFORM_ID
                and _finite(row.get("startup_velocity_scale"))
                and abs(float(row["startup_velocity_scale"]) - expected_scale)
                <= 1.0e-15
                and row.get("startup_ramp_active") == (expected_scale < 1.0)
                and row.get("startup_ramp_residual_count") == design.ACTUATOR_COUNT
                and row.get("startup_transform_residual_count")
                == design.ACTUATOR_COUNT
                and all(row.get(field) == expected for field, expected in startup.items())
                and _finite(row.get("startup_ramp_maximum_absolute_residual_rad_s"))
                and float(row["startup_ramp_maximum_absolute_residual_rad_s"]) >= 0.0
            )
            if not startup_valid:
                failures.append(f"R23D56_STARTUP_TRANSFORM_INVALID:{semantic_step}")
            active_count += int(expected_scale < 1.0)
            zero_count += int(expected_scale == 0.0)
            unity_count += int(expected_scale == 1.0)

            try:
                item = design.cell(
                    design.STAGE_ID,
                    "godot_jolt",
                    str(row.get("cell_id", "")).rsplit("__", 1)[-1],
                )
                segment, _ = design.segment_for_step(item, semantic_step)
            except (design.StartupTransformError, TypeError):
                failures.append(f"R23D56_SEGMENT_INVALID:{semantic_step}")
                segment = ""
            origin = row.get("task_frame_origin_world_m")
            position = row.get("torso_position_world_m")
            transition = semantic_step in design.EXPECTED_REANCHOR_STEPS
            if semantic_step == design.INITIAL_SCHEDULE_BIND_STEP:
                expected_segment = segment
                expected_origin = (
                    [float(component) for component in origin]
                    if isinstance(origin, list)
                    and len(origin) == 3
                    and all(_finite(component) for component in origin)
                    else None
                )
            elif segment != expected_segment:
                expected_segment = segment
                expected_reanchor_count += 1
                expected_origin = (
                    [float(component) for component in position]
                    if isinstance(position, list)
                    and len(position) == 3
                    and all(_finite(component) for component in position)
                    else None
                )
            origin_valid = (
                row.get("task_frame_origin_policy_id")
                == design.TASK_FRAME_ORIGIN_POLICY_ID
                and isinstance(origin, list)
                and len(origin) == 3
                and all(_finite(component) for component in origin)
                and expected_origin is not None
                and all(
                    abs(float(observed) - expected) <= 1.0e-12
                    for observed, expected in zip(origin, expected_origin, strict=True)
                )
                and row.get("task_frame_origin_reanchored_this_step") is transition
                and row.get("task_frame_origin_reanchor_count")
                == expected_reanchor_count
            )
            if not origin_valid:
                failures.append(f"R23D56_TASK_FRAME_ORIGIN_INVALID:{semantic_step}")
            if row.get("task_frame_origin_reanchored_this_step") is True:
                observed_transition_steps.append(semantic_step)

            observation_failures, identity = _observation_failures(row, semantic_step)
            failures.extend(
                f"R23D56_{code}:{semantic_step}" for code in observation_failures
            )
            if identity is not None:
                actuator_ids, limb_ids, links, digest = identity
                if expected_actuator_ids is None:
                    expected_actuator_ids = actuator_ids
                    expected_limb_ids = limb_ids
                    expected_links = links
                elif (
                    actuator_ids != expected_actuator_ids
                    or limb_ids != expected_limb_ids
                    or links != expected_links
                ):
                    failures.append(
                        f"R23D56_OBSERVATION_IDENTITY_DRIFT:{semantic_step}"
                    )
                if digest in receipt_digests:
                    failures.append(
                        f"R23D56_OBSERVATION_RECEIPT_DIGEST_REUSED:{semantic_step}"
                    )
                receipt_digests.add(str(digest))
                observation = row["actuator_phase_observation"]
                applications = observation["ordered_applications"]
                observation_row_count += 1
                application_count += len(applications)
                maximum_target_error = max(
                    maximum_target_error,
                    max(
                        float(application[
                            "motor_target_velocity_readback_error_rad_s"
                        ])
                        for application in applications
                    ),
                )
                maximum_impulse_error = max(
                    maximum_impulse_error,
                    max(
                        float(application[
                            "motor_maximum_impulse_readback_error_nms"
                        ])
                        for application in applications
                    ),
                )
    if observed_transition_steps != list(design.EXPECTED_REANCHOR_STEPS):
        failures.append("R23D56_TASK_FRAME_ORIGIN_TRANSITION_STEPS")
    if observation_row_count != design.CONTROLLER_STEPS:
        failures.append("R23D56_OBSERVATION_ROW_COUNT")
    if application_count != design.CONTROLLER_STEPS * design.ACTUATOR_COUNT:
        failures.append("R23D56_OBSERVATION_APPLICATION_COUNT")
    summary.update(
        schema_version=TRACE_SUMMARY_SCHEMA,
        ok=not failures,
        failure_codes=failures[:32],
        startup_ramp_active_step_count=active_count,
        startup_ramp_exact_zero_scale_step_count=zero_count,
        startup_ramp_exact_unity_scale_step_count=unity_count,
        startup_transform_id=design.STARTUP_TRANSFORM_ID,
        startup_ramp_triggered=governor.trigger_step is not None,
        startup_ramp_trigger_step=governor.trigger_step,
        startup_probe_minimum_support_count=governor.minimum_probe_support_count,
        task_frame_origin_policy_id=design.TASK_FRAME_ORIGIN_POLICY_ID,
        task_frame_origin_transition_steps=observed_transition_steps,
        task_frame_origin_transition_count=len(observed_transition_steps),
        actuator_phase_observation_schema_version=(
            design.ACTUATOR_PHASE_OBSERVATION_SCHEMA
        ),
        observation_row_count=observation_row_count,
        observation_application_count=application_count,
        ordered_actuator_ids=(
            list(expected_actuator_ids) if expected_actuator_ids is not None else []
        ),
        ordered_limb_ids=(
            list(expected_limb_ids) if expected_limb_ids is not None else []
        ),
        unique_controller_step_receipt_digest_count=len(receipt_digests),
        maximum_target_velocity_readback_error_rad_s=maximum_target_error,
        maximum_impulse_readback_error_nms=maximum_impulse_error,
        configured_motor_parameters_only=True,
        measured_motor_torque_available=False,
        measured_motor_impulse_available=False,
    )
    return summary


inherited.validate_trace = validate_trace


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    return inherited.retain_trace(**kwargs)


def _cas_binding_failures(
    entry: Mapping[str, Any], *, authority_repo_root: Path | None = None
) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D56_TRACE_ARTIFACT_RECEIPT"]
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D56_TRACE_ARTIFACT_IDENTITY"]
    authority_root = (
        REPO_ROOT if authority_repo_root is None else authority_repo_root.resolve()
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
        return ["R23D56_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D56_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
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
        return ["R23D56_TRACE_ARTIFACT_BYTES"]
    return []


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    evaluation, rows = inherited.evaluate_entry(
        entry, item, expected_source_commit=expected_source_commit
    )
    if isinstance(entry, dict) and evaluation.get("entry_kind") == "report":
        failures = _cas_binding_failures(
            entry,
            authority_repo_root=authority_repo_root,
        )
        measurements = entry.get("measurements")
        trace_summary = validate_trace(item.cell_id, rows)
        if not isinstance(measurements, dict) or (
            measurements.get("startup_ramp_id") != design.STARTUP_RAMP_ID
            or measurements.get("startup_ramp_step_count")
            != design.STARTUP_RAMP_STEPS
            or measurements.get("startup_ramp_composition_step_count")
            != design.CONTROLLER_STEPS
            or measurements.get("startup_ramp_active_step_count")
            != trace_summary.get("startup_ramp_active_step_count")
            or measurements.get("startup_ramp_exact_zero_scale_step_count")
            != trace_summary.get("startup_ramp_exact_zero_scale_step_count")
            or measurements.get("startup_ramp_exact_unity_scale_step_count")
            != trace_summary.get("startup_ramp_exact_unity_scale_step_count")
            or measurements.get("startup_ramp_composition_integrity_passed") is not True
            or measurements.get("startup_transform_id")
            != design.STARTUP_TRANSFORM_ID
            or measurements.get("startup_ramp_triggered")
            != trace_summary.get("startup_ramp_triggered")
            or measurements.get("startup_ramp_trigger_step")
            != trace_summary.get("startup_ramp_trigger_step")
            or measurements.get("startup_probe_minimum_support_count")
            != trace_summary.get("startup_probe_minimum_support_count")
            or measurements.get("startup_transform_composition_integrity_passed")
            is not True
        ):
            failures.append("R23D56_STARTUP_REPORT_INTEGRITY")
        if trace_summary.get("task_frame_origin_transition_steps") != list(
            design.EXPECTED_REANCHOR_STEPS
        ):
            failures.append("R23D56_TASK_FRAME_ORIGIN_REPORT_INTEGRITY")
        failures.extend(_cap_binding_projection_failures(entry, rows))
        if failures:
            evaluation["execution_valid"] = False
            evaluation["common_physical_gate_passed"] = False
            evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + failures
    return evaluation, rows


def _new_window_accumulator() -> dict[str, Any]:
    return {
        "application_count": 0,
        "_controller_targets": [],
        "_absolute_controller_targets": [],
        "_requested_positions": [],
        "_clamped_positions": [],
        "position_saturated_count": 0,
        "velocity_saturated_count": 0,
        "slew_limited_count": 0,
        "foot_contact_before_true_count": 0,
        "foot_contact_after_true_count": 0,
        "contact_false_to_true_count": 0,
        "contact_true_to_false_count": 0,
    }


def _finalize_window_accumulator(value: dict[str, Any]) -> dict[str, Any]:
    result = {
        key: item
        for key, item in value.items()
        if not key.startswith("_")
    }
    result.update(
        controller_target_velocity_sum_rad_s=math.fsum(
            value["_controller_targets"]
        ),
        controller_target_velocity_absolute_sum_rad_s=math.fsum(
            value["_absolute_controller_targets"]
        ),
        requested_target_position_sum_rad=math.fsum(
            value["_requested_positions"]
        ),
        clamped_target_position_sum_rad=math.fsum(
            value["_clamped_positions"]
        ),
    )
    return result


def characterize_rows(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    if len(rows) != design.CONTROLLER_STEPS:
        raise R23D56EvaluationError("R23D56_CHARACTERIZATION_ROW_COUNT_INVALID")
    first_observation = rows[0]["actuator_phase_observation"]
    actuator_ids = list(first_observation["ordered_actuator_ids"])
    limb_ids = list(first_observation["ordered_limb_ids"])
    windows = (
        ("full_horizon", 0, design.CONTROLLER_STEPS),
        (
            "commanded_turn",
            design.TURN_START_STEP,
            design.TURN_END_STEP_EXCLUSIVE,
        ),
    )
    accumulators = {
        window_id: {
            actuator_id: _new_window_accumulator()
            for actuator_id in actuator_ids
        }
        for window_id, _, _ in windows
    }
    transitions = {
        limb_id: {
            "false_to_true": 0,
            "true_to_false": 0,
            "unchanged_false": 0,
            "unchanged_true": 0,
        }
        for limb_id in limb_ids
    }
    maximum_target_error = 0.0
    maximum_impulse_error = 0.0
    total_position_saturated = 0
    total_velocity_saturated = 0
    total_slew_limited = 0
    for row in rows:
        before = row["ordered_foot_contacts_before"]
        after = row["ordered_foot_contacts_after"]
        for limb_id in limb_ids:
            state = (
                "false_to_true"
                if not before[limb_id] and after[limb_id]
                else "true_to_false"
                if before[limb_id] and not after[limb_id]
                else "unchanged_true"
                if before[limb_id]
                else "unchanged_false"
            )
            transitions[limb_id][state] += 1
        step = int(row["semantic_step"])
        applications = row["actuator_phase_observation"]["ordered_applications"]
        for application in applications:
            actuator_id = str(application["actuator_id"])
            maximum_target_error = max(
                maximum_target_error,
                float(application[
                    "motor_target_velocity_readback_error_rad_s"
                ]),
            )
            maximum_impulse_error = max(
                maximum_impulse_error,
                float(application["motor_maximum_impulse_readback_error_nms"]),
            )
            total_position_saturated += int(application["position_saturated"])
            total_velocity_saturated += int(application["velocity_saturated"])
            total_slew_limited += int(application["slew_limited"])
            for window_id, start, end in windows:
                if not start <= step < end:
                    continue
                accumulator = accumulators[window_id][actuator_id]
                controller = float(
                    application["controller_target_velocity_rad_s"]
                )
                accumulator["application_count"] += 1
                accumulator["_controller_targets"].append(controller)
                accumulator["_absolute_controller_targets"].append(abs(controller))
                accumulator["_requested_positions"].append(
                    float(application["requested_target_position_rad"])
                )
                accumulator["_clamped_positions"].append(
                    float(application["clamped_target_position_rad"])
                )
                accumulator["position_saturated_count"] += int(
                    application["position_saturated"]
                )
                accumulator["velocity_saturated_count"] += int(
                    application["velocity_saturated"]
                )
                accumulator["slew_limited_count"] += int(
                    application["slew_limited"]
                )
                accumulator["foot_contact_before_true_count"] += int(
                    application["foot_contact_before"]
                )
                accumulator["foot_contact_after_true_count"] += int(
                    application["foot_contact_after"]
                )
                accumulator["contact_false_to_true_count"] += int(
                    not application["foot_contact_before"]
                    and application["foot_contact_after"]
                )
                accumulator["contact_true_to_false_count"] += int(
                    application["foot_contact_before"]
                    and not application["foot_contact_after"]
                )
    return {
        "schema_version": "sporespore_qsdk_r23d56_actuator_phase_characterization_v1",
        "observation_schema_version": design.ACTUATOR_PHASE_OBSERVATION_SCHEMA,
        "observation_row_count": len(rows),
        "application_count": len(rows) * design.ACTUATOR_COUNT,
        "ordered_actuator_ids": actuator_ids,
        "ordered_limb_ids": limb_ids,
        "maximum_target_velocity_readback_error_rad_s": maximum_target_error,
        "maximum_impulse_readback_error_nms": maximum_impulse_error,
        "position_saturated_application_count": total_position_saturated,
        "velocity_saturated_application_count": total_velocity_saturated,
        "slew_limited_application_count": total_slew_limited,
        "contact_transition_count_by_limb": transitions,
        "ordered_windows": [
            {
                "window_id": window_id,
                "start_semantic_step": start,
                "end_semantic_step_exclusive": end,
                "ordered_actuator_statistics": [
                    {
                        "actuator_id": actuator_id,
                        **_finalize_window_accumulator(
                            accumulators[window_id][actuator_id]
                        ),
                    }
                    for actuator_id in actuator_ids
                ],
            }
            for window_id, start, end in windows
        ],
        "configured_motor_parameters_only": True,
        "measured_motor_torque_available": False,
        "measured_motor_impulse_available": False,
        "turning_gate_invoked": False,
        "mechanism_selected": False,
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
        raise R23D56EvaluationError("R23D56_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    if not (authority_root / ".git").exists():
        raise R23D56EvaluationError("R23D56_AUTHORITY_REPO_ROOT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D56EvaluationError("R23D56_COMPLETE_ENTRY_ORDER_INVALID")
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
    all_execution_valid = all(row["execution_valid"] for row in evaluations)
    all_contextual_physical_gates_passed = all(
        row["common_physical_gate_passed"] for row in evaluations
    )
    characterization_by_arm: dict[str, Any] = {}
    if all_execution_valid:
        characterization_by_arm = {
            item.arm_id: characterize_rows(rows_by_cell[item.cell_id])
            for item in expected
        }
    classification = (
        "valid_complete_outcome_exposed_godot_valid_route_actuator_phase_characterization_development"
        if all_execution_valid
        else "invalid_complete_outcome_exposed_godot_valid_route_actuator_phase_characterization_development"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["live_fixture_actuator_cap_binding_verified"] = all_execution_valid
    claims["actuator_phase_characterization_complete"] = all_execution_valid
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "engine_result": {
            "engine_id": "godot_jolt",
            "all_cells_execution_valid": all_execution_valid,
            "all_contextual_common_physical_gates_passed": (
                all_contextual_physical_gates_passed
            ),
            "contextual_common_physical_gates_are_acceptance_authority": False,
            "live_fixture_actuator_cap_binding_verified": all_execution_valid,
            "actuator_phase_characterization_complete": all_execution_valid,
            "characterization_by_arm": characterization_by_arm,
            "turning_gate_invoked": False,
            "turning_mechanism_selected": False,
        },
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_held_out_condition_consumed": False,
        "outcome_exposed_before_preregistration": True,
        "terminal_restoration_or_taper_invoked": False,
        "cross_engine_equivalence_test_invoked": False,
        "population_inference_attempted": False,
        "claims": claims,
    }

def _synthetic_observation(
    item: design.Cell,
    step: int,
    row: dict[str, Any],
) -> dict[str, Any]:
    limb_ids = list(design.LIMB_IDS)
    phase_rows = [
        {
            "limb_id": limb_id,
            "local_phase_step": step % design.GAIT_CYCLE_STEPS,
            "gait_step": step,
            "release_hold_step_count": 0,
        }
        for limb_id in limb_ids
    ]
    row["ordered_limb_phase_before"] = phase_rows
    actuator_ids = [
        f"{limb_id}_joint_{joint_index}"
        for limb_id in limb_ids
        for joint_index in range(2)
    ]
    applications: list[dict[str, Any]] = []
    for index, actuator_id in enumerate(actuator_ids):
        limb_id = limb_ids[index // 2]
        joint_index = index % 2
        directional = (
            item.turn_heading_offset_rad
            if design.TURN_START_STEP
            <= step
            < design.TURN_END_STEP_EXCLUSIVE
            else 0.0
        )
        target = (index + 1) * 0.01 + directional * (
            -1.0 if "left" in limb_id else 1.0
        )
        requested_position = target * 0.02
        applications.append(
            {
                "actuator_id": actuator_id,
                "joint_id": f"portable_{actuator_id}",
                "host_joint_id": f"host_{actuator_id}",
                "limb_id": limb_id,
                "limb_joint_index": joint_index,
                "requested_target_position_rad": requested_position,
                "clamped_target_position_rad": requested_position,
                "controller_target_velocity_rad_s": target,
                "maximum_target_speed_rad_s": 10.0,
                "host_applied_target_velocity_rad_s": target,
                "motor_target_velocity_readback_rad_s": target,
                "motor_target_velocity_readback_error_rad_s": 0.0,
                "declared_maximum_impulse_nms": 0.5,
                "motor_maximum_impulse_readback_nms": 0.5,
                "motor_maximum_impulse_readback_error_nms": 0.0,
                "position_saturated": False,
                "velocity_saturated": False,
                "slew_limited": False,
                "host_additional_clamp_applied": False,
                "target_velocity_readback_matches": True,
                "maximum_impulse_readback_matches": True,
                "local_phase_step_before": step % design.GAIT_CYCLE_STEPS,
                "gait_step_before": step,
                "release_hold_step_count_before": 0,
                "foot_contact_before": row["ordered_foot_contacts_before"][
                    limb_id
                ],
                "foot_contact_after": row["ordered_foot_contacts_after"][limb_id],
            }
        )
    return {
        "schema_version": design.ACTUATOR_PHASE_OBSERVATION_SCHEMA,
        "semantic_step": step,
        "controller_step_receipt_sha256": (
            "sha256:"
            + hashlib.sha256(
                f"{item.cell_id}:{step}".encode("utf-8")
            ).hexdigest()
        ),
        "application_receipt_schema_version": design.APPLICATION_RECEIPT_SCHEMA,
        "ordered_actuator_ids": actuator_ids,
        "ordered_limb_ids": limb_ids,
        "readback_tolerance": 2.5e-7,
        "ordered_applications": applications,
        "after_contact_observation_complete": True,
        "configured_motor_parameters_only": True,
        "measured_motor_torque_available": False,
        "measured_motor_impulse_available": False,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _synthetic_rows(item: design.Cell) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    governor = design.SupportLossConditionedStartup()
    latched_origin = [0.0, 0.4, 0.0]
    reanchor_count = 0
    for step in range(design.CONTROLLER_STEPS):
        row = inherited._synthetic_row(item, step)
        contacts = row["ordered_foot_contacts_before"]
        startup = governor.step(step, contacts)
        scale = float(startup["startup_velocity_scale"])
        row.update(startup)
        row.update(
            startup_ramp_id=design.STARTUP_RAMP_ID,
            startup_transform_id=design.STARTUP_TRANSFORM_ID,
            startup_ramp_active=scale < 1.0,
            startup_ramp_residual_count=design.ACTUATOR_COUNT,
            startup_transform_residual_count=design.ACTUATOR_COUNT,
            startup_ramp_maximum_absolute_residual_rad_s=0.0,
        )
        if step in design.EXPECTED_REANCHOR_STEPS:
            latched_origin = [float(value) for value in row["torso_position_world_m"]]
            reanchor_count += 1
        row.update(
            task_frame_origin_policy_id=design.TASK_FRAME_ORIGIN_POLICY_ID,
            task_frame_origin_world_m=latched_origin.copy(),
            task_frame_origin_reanchored_this_step=(
                step in design.EXPECTED_REANCHOR_STEPS
            ),
            task_frame_origin_reanchor_count=reanchor_count,
        )
        row["actuator_phase_observation"] = _synthetic_observation(
            item, step, row
        )
        rows.append(row)
    return rows


def _synthetic_cap_binding_projection(
    rows: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    observation = rows[0]["actuator_phase_observation"]
    applications = observation["ordered_applications"]
    actuator_ids = list(observation["ordered_actuator_ids"])
    ordered_bindings = [
        {
            "actuator_id": application["actuator_id"],
            "joint_id": application["joint_id"],
            "host_joint_id": application["host_joint_id"],
            "limb_id": application["limb_id"],
            "declared_maximum_impulse_nms": application[
                "declared_maximum_impulse_nms"
            ],
            "motor_maximum_impulse_readback_nms": application[
                "motor_maximum_impulse_readback_nms"
            ],
            "readback_error_nms": application[
                "motor_maximum_impulse_readback_error_nms"
            ],
            "readback_matches": True,
        }
        for application in applications
    ]
    receipt = {
        "schema_version": design.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA,
        "ok": True,
        "failure_code": "",
        "policy_id": design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID,
        "fixture_composition_schema_version": design.LIVE_FIXTURE_COMPOSITION_SCHEMA,
        "ordered_actuator_ids": actuator_ids,
        "ordered_bindings": ordered_bindings,
        "validated_actuator_count": design.ACTUATOR_COUNT,
        "validated_limb_count": len(design.LIMB_IDS),
        "unique_host_joint_object_count": design.ACTUATOR_COUNT,
        "write_count": design.ACTUATOR_COUNT,
        "readback_count": design.ACTUATOR_COUNT,
        "maximum_postbinding_readback_error_nms": 0.0,
        "all_fixture_composition_markers_valid": True,
        "all_host_joint_names_valid": True,
        "all_postbinding_readbacks_match": True,
        "configured_parameter_readback_only": True,
        "measured_motor_torque_available": False,
        "measured_motor_impulse_available": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }
    return {
        "godot_execution_predicates": {
            "raw_sdk_authority_summary": {
                "r23d56_live_fixture_actuator_cap_binding_policy_id": (
                    design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
                ),
                "r23d56_live_fixture_actuator_cap_binding_receipt": receipt,
                "r23d56_live_fixture_actuator_cap_binding_integrity_passed": True,
            }
        }
    }


def _cap_projection_mutation(value: dict[str, Any], mutation_id: str) -> None:
    predicates = value["godot_execution_predicates"]
    raw_summary = predicates["raw_sdk_authority_summary"]
    receipt = raw_summary["r23d56_live_fixture_actuator_cap_binding_receipt"]
    if mutation_id == "missing_projection":
        value.pop("godot_execution_predicates")
    elif mutation_id == "missing_summary":
        predicates.pop("raw_sdk_authority_summary")
    elif mutation_id == "wrong_projected_policy":
        raw_summary["r23d56_live_fixture_actuator_cap_binding_policy_id"] += "_mutated"
    elif mutation_id == "integrity_false":
        raw_summary["r23d56_live_fixture_actuator_cap_binding_integrity_passed"] = False
    elif mutation_id == "missing_receipt":
        raw_summary.pop("r23d56_live_fixture_actuator_cap_binding_receipt")
    elif mutation_id == "receipt_schema":
        receipt["schema_version"] += "_mutated"
    elif mutation_id == "receipt_policy":
        receipt["policy_id"] += "_mutated"
    elif mutation_id == "validated_count":
        receipt["validated_actuator_count"] -= 1
    elif mutation_id == "write_count":
        receipt["write_count"] -= 1
    elif mutation_id == "readback_count":
        receipt["readback_count"] -= 1
    elif mutation_id == "excessive_readback_error":
        receipt["maximum_postbinding_readback_error_nms"] = 1.0e-3
    elif mutation_id == "readback_flag":
        receipt["all_postbinding_readbacks_match"] = False
    elif mutation_id == "actuator_order":
        receipt["ordered_actuator_ids"][0], receipt["ordered_actuator_ids"][1] = (
            receipt["ordered_actuator_ids"][1],
            receipt["ordered_actuator_ids"][0],
        )
    elif mutation_id == "binding_cap":
        receipt["ordered_bindings"][0]["declared_maximum_impulse_nms"] += 0.01
    else:
        raise AssertionError(mutation_id)


def _manifest_paths_value(value: Any) -> list[str]:
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise R23D56EvaluationError("R23D56_TERMINAL_MANIFEST_INVALID")
    return value


def _base_mutation(trace: list[dict[str, Any]], mutation_id: str) -> None:
    if mutation_id == "missing_origin":
        trace[design.TURN_START_STEP].pop("task_frame_origin_world_m")
    elif mutation_id == "wrong_origin":
        trace[design.TURN_START_STEP]["task_frame_origin_world_m"][0] += 0.01
    elif mutation_id == "missing_transition":
        trace[design.TURN_START_STEP][
            "task_frame_origin_reanchored_this_step"
        ] = False
    elif mutation_id == "extra_transition":
        trace[design.TURN_START_STEP + 1][
            "task_frame_origin_reanchored_this_step"
        ] = True
    elif mutation_id == "wrong_count":
        trace[design.TURN_START_STEP]["task_frame_origin_reanchor_count"] = 99
    elif mutation_id == "wrong_policy":
        trace[0]["task_frame_origin_policy_id"] = "fixed_initial_origin_v1"
    elif mutation_id == "initial_reanchor":
        trace[0]["task_frame_origin_reanchored_this_step"] = True
        trace[0]["task_frame_origin_reanchor_count"] = 1
    elif mutation_id == "warmup_origin_drift":
        trace[design.FIXED_ORIGIN_LAST_SEMANTIC_STEP][
            "task_frame_origin_world_m"
        ][0] += 0.01
    elif mutation_id == "startup":
        trace[179]["startup_velocity_scale"] += 0.001
    elif mutation_id == "segment":
        trace[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
    else:
        raise AssertionError(mutation_id)


def _observation_mutation(trace: list[dict[str, Any]], mutation_id: str) -> None:
    row = trace[design.TURN_START_STEP]
    observation = row["actuator_phase_observation"]
    applications = observation["ordered_applications"]
    first = applications[0]
    if mutation_id == "missing":
        row.pop("actuator_phase_observation")
    elif mutation_id == "schema":
        observation["schema_version"] += "_mutated"
    elif mutation_id == "semantic_step":
        observation["semantic_step"] += 1
    elif mutation_id == "digest":
        observation["controller_step_receipt_sha256"] = "sha256:bad"
    elif mutation_id == "application_schema":
        observation["application_receipt_schema_version"] += "_mutated"
    elif mutation_id == "actuator_order":
        observation["ordered_actuator_ids"][0], observation["ordered_actuator_ids"][1] = (
            observation["ordered_actuator_ids"][1],
            observation["ordered_actuator_ids"][0],
        )
    elif mutation_id == "actuator_identity":
        first["actuator_id"] += "_mutated"
    elif mutation_id == "limb_identity":
        first["limb_id"] = "missing_limb"
    elif mutation_id == "phase":
        first["local_phase_step_before"] += 1
    elif mutation_id == "contact_before":
        first["foot_contact_before"] = not first["foot_contact_before"]
    elif mutation_id == "contact_after":
        first["foot_contact_after"] = not first["foot_contact_after"]
    elif mutation_id == "target_readback":
        first["motor_target_velocity_readback_rad_s"] += 0.01
    elif mutation_id == "impulse_readback":
        first["motor_maximum_impulse_readback_nms"] += 0.01
    elif mutation_id == "configured_nonclaim":
        observation["configured_motor_parameters_only"] = False
    elif mutation_id == "torque_nonclaim":
        observation["measured_motor_torque_available"] = True
    elif mutation_id == "cardinality":
        applications.pop()
    elif mutation_id == "tolerance":
        observation["readback_tolerance"] = 1.0e-4
    elif mutation_id == "host_clamp":
        first["host_additional_clamp_applied"] = True
    elif mutation_id == "match_flag":
        first["target_velocity_readback_matches"] = False
    elif mutation_id == "nonfinite":
        first["controller_target_velocity_rad_s"] = float("nan")
    else:
        raise AssertionError(mutation_id)


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    traces = {item.cell_id: _synthetic_rows(item) for item in design.cells()}
    validations = [
        validate_trace(item.cell_id, traces[item.cell_id])
        for item in design.cells()
    ]
    characterizations = [
        characterize_rows(traces[item.cell_id]) for item in design.cells()
    ]
    first = design.cells()[0]
    base_mutation_ids = (
        "missing_origin",
        "wrong_origin",
        "missing_transition",
        "extra_transition",
        "wrong_count",
        "wrong_policy",
        "initial_reanchor",
        "warmup_origin_drift",
        "startup",
        "segment",
    )
    base_rejections = 0
    for mutation_id in base_mutation_ids:
        mutated = copy.deepcopy(traces[first.cell_id])
        _base_mutation(mutated, mutation_id)
        base_rejections += int(not validate_trace(first.cell_id, mutated)["ok"])
    observation_mutation_ids = (
        "missing",
        "schema",
        "semantic_step",
        "digest",
        "application_schema",
        "actuator_order",
        "actuator_identity",
        "limb_identity",
        "phase",
        "contact_before",
        "contact_after",
        "target_readback",
        "impulse_readback",
        "configured_nonclaim",
        "torque_nonclaim",
        "cardinality",
        "tolerance",
        "host_clamp",
        "match_flag",
        "nonfinite",
    )
    observation_rejections = 0
    for mutation_id in observation_mutation_ids:
        mutated = copy.deepcopy(traces[first.cell_id])
        _observation_mutation(mutated, mutation_id)
        try:
            rejected = not validate_trace(first.cell_id, mutated)["ok"]
        except (inherited.R23D34EvaluationError, ValueError):
            # A non-finite retained value can fail at canonicalization before
            # the observation-specific projection.  That is still the exact
            # fail-closed behavior this mutation is required to prove.
            rejected = True
        observation_rejections += int(rejected)
    cap_projection_mutation_ids = (
        "missing_projection",
        "missing_summary",
        "wrong_projected_policy",
        "integrity_false",
        "missing_receipt",
        "receipt_schema",
        "receipt_policy",
        "validated_count",
        "write_count",
        "readback_count",
        "excessive_readback_error",
        "readback_flag",
        "actuator_order",
        "binding_cap",
    )
    cap_trace_mutation_ids = (
        "application_declared_cap_type",
        "application_readback_type",
    )
    cap_projection = _synthetic_cap_binding_projection(traces[first.cell_id])
    if _cap_binding_projection_failures(cap_projection, traces[first.cell_id]):
        raise R23D56EvaluationError("R23D56_CAP_BINDING_POSITIVE_CANARY_INVALID")
    cap_projection_rejections = 0
    for mutation_id in cap_projection_mutation_ids:
        mutated = copy.deepcopy(cap_projection)
        _cap_projection_mutation(mutated, mutation_id)
        cap_projection_rejections += int(
            bool(_cap_binding_projection_failures(mutated, traces[first.cell_id]))
        )
    for mutation_id in cap_trace_mutation_ids:
        mutated_rows = copy.deepcopy(traces[first.cell_id])
        first_application = mutated_rows[0]["actuator_phase_observation"][
            "ordered_applications"
        ][0]
        if mutation_id == "application_declared_cap_type":
            first_application["declared_maximum_impulse_nms"] = "0.5"
        else:
            first_application["motor_maximum_impulse_readback_nms"] = "0.5"
        cap_projection_rejections += int(
            bool(_cap_binding_projection_failures(cap_projection, mutated_rows))
        )
    invalid_manifest_count = 0
    for value in ("one", {"path": "one"}, [""], [1]):
        try:
            _manifest_paths_value(value)
        except R23D56EvaluationError:
            invalid_manifest_count += 1
    alternate = _alternate_windows_spelling(DECLARATION_PATH)
    same_file_alias_accepted = _same_existing_file(DECLARATION_PATH, alternate)
    wrong_existing_file_rejected = not _same_existing_file(
        DECLARATION_PATH,
        ROOT / "r23d56_godot_valid_route_actuator_phase_characterization.py",
    )
    complete_arguments = _arguments(
        [
            "evaluate-complete",
            "--manifest",
            str(DECLARATION_PATH),
            "--expected-source-commit",
            "0" * 40,
            "--repo-root",
            str(REPO_ROOT),
        ]
    )
    characterization_exact = all(
        value["observation_row_count"] == design.CONTROLLER_STEPS
        and value["application_count"]
        == design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        and len(value["ordered_windows"]) == 2
        and value["turning_gate_invoked"] is False
        and value["mechanism_selected"] is False
        for value in characterizations
    )
    if (
        not all(validation["ok"] for validation in validations)
        or base_rejections != len(base_mutation_ids)
        or observation_rejections != len(observation_mutation_ids)
        or cap_projection_rejections
        != len(cap_projection_mutation_ids) + len(cap_trace_mutation_ids)
        or not characterization_exact
        or [len(_manifest_paths_value(value)) for value in ([], ["one"], ["one", "two", "three"])]
        != [0, 1, 3]
        or invalid_manifest_count != 4
        or not same_file_alias_accepted
        or not wrong_existing_file_rejected
        or complete_arguments.repo_root != REPO_ROOT
    ):
        raise R23D56EvaluationError("R23D56_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d56_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": len(design.cells()),
        "valid_trace_canary_count": len(validations),
        "trace_mutation_rejection_count": (
            base_rejections + observation_rejections
        ),
        "origin_policy_mutation_rejection_count": 8,
        "startup_transform_mutation_rejection_count": 1,
        "segment_mutation_rejection_count": 1,
        "observation_mutation_rejection_count": observation_rejections,
        "live_fixture_cap_binding_projection_positive_control_count": 1,
        "live_fixture_cap_binding_projection_mutation_rejection_count": (
            cap_projection_rejections
        ),
        "descriptive_characterization_canary_count": len(characterizations),
        "observation_row_count_per_trace": design.CONTROLLER_STEPS,
        "observation_application_count_per_trace": (
            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        ),
        "initial_schedule_bind_semantic_step": design.INITIAL_SCHEDULE_BIND_STEP,
        "fixed_origin_last_semantic_step": (
            design.FIXED_ORIGIN_LAST_SEMANTIC_STEP
        ),
        "expected_reanchor_semantic_steps": list(design.EXPECTED_REANCHOR_STEPS),
        "valid_manifest_shape_canary_count": 3,
        "invalid_manifest_shape_rejection_count": invalid_manifest_count,
        "same_file_path_spelling_positive_control_count": 1,
        "wrong_file_path_rejection_count": 1,
        "production_cas_binding_uses_existing_file_identity": True,
        "complete_evaluation_authority_root_cli_canary_count": 1,
        "turning_gate_invoked": False,
        "mechanism_selection_rule_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
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
    evaluate.add_argument("--repo-root", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D56_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D56_TRACE_RETAINED "
        else:
            manifest_value = json.loads(args.manifest.read_text(encoding="utf-8"))
            paths = _manifest_paths_value(manifest_value)
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.expected_source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D56_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D56EvaluationError,
        inherited.R23D34EvaluationError,
        inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D56_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
