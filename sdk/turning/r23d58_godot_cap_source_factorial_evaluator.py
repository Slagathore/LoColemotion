"""Evaluator and retained-trace gate for QSDK-R23D58."""

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
import r23d58_godot_cap_source_factorial as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d48_trace.ps1"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
REPORT_SCHEMA = "sporespore_qsdk_r23d58_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d58_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d58_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d58_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d58_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "live_fixture_actuator_cap_binding_verified": False,
    "actuator_phase_characterization_complete": False,
    "cap_source_factorial_characterization_complete": False,
    "rear_contact_mechanism_selected": False,
    "compiled_cap_causality_established": False,
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


class R23D58EvaluationError(RuntimeError):
    """The declaration, retained evidence, or four-cell result is invalid."""


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
        raise R23D58EvaluationError(
            f"R23D58_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error

    parent = value.get("immutable_parent", {})
    successor = value.get("scientifically_distinct_successor", {})
    transport = value.get("authoritative_json_transport", {})
    frozen = value.get("frozen_future_physical_design", {})
    factor_adequacy = value.get("factor_level_provenance_and_adequacy", {})
    thresholds = value.get("threshold_provenance", {})
    zero_world = value.get("observed_local_zero_world_result", {})
    production_route = value.get("production_route_zero_world_integration", {})
    regression = value.get(
        "ordinary_candidate35_full_authority_regression_observation", {}
    )
    campaign = value.get("prospective_campaign_execution_boundary", {})
    claims = value.get("claims", {})
    next_boundary = value.get("next_boundary", {})

    expected_contrasts = {
        "knee_source_at_portable_hip": (
            "portable_hip__fixture_knee minus "
            "portable_hip__portable_knee"
        ),
        "knee_source_at_fixture_hip": (
            "fixture_hip__fixture_knee minus "
            "fixture_hip__portable_knee"
        ),
        "hip_source_at_portable_knee": (
            "fixture_hip__portable_knee minus "
            "portable_hip__portable_knee"
        ),
        "hip_source_at_fixture_knee": (
            "fixture_hip__fixture_knee minus "
            "portable_hip__fixture_knee"
        ),
        "interaction": (
            "knee_source_at_fixture_hip minus "
            "knee_source_at_portable_hip"
        ),
    }
    expected_outcomes = [
        "per_limb_contact_boolean_sequence",
        "per_limb_contact_loss_transition_count",
        "per_limb_contact_gain_transition_count",
        "per_limb_complete_contact_cycle_count",
        "per_limb_first_contact_loss_semantic_step_or_null",
        "per_limb_contact_true_step_count",
        "per_actuator_target_and_readback_sequence",
        "per_actuator_selected_cap_source_and_value",
        "torso_contact_sequence",
        "torso_pose_and_displacement_context",
    ]
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d58_godot_terminal_trace_cap_factorial_zero_world_contract_v1"
        or value.get("status")
        != "prospective_campaign_machinery_implemented_complete_zero_world_gates_passed_physical_campaign_not_opened"
        or value.get("gate_id") != design.GATE_ID
        or value.get("work_id")
        != "QSDK-R23D58-GODOT-TERMINAL-TRACE-IDENTITY-AND-CAP-SOURCE-FACTORIAL-DEVELOPMENT"
        or value.get("question_class") != "development"
        or value.get("physical_question_declared") is not True
        or value.get("physical_campaign_opened") is not False
        or parent.get("gate_id") != "QSDK-R23D57"
        or parent.get("campaign_id")
        != "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
        or parent.get("parent_world_count") != 3
        or parent.get("parent_rerun_allowed") is not False
        or parent.get("parent_result_reinterpreted") is not False
        or successor.get("distinct_campaign_identity_required") is not True
        or successor.get("r23d57_rerun_forbidden") is not True
        or successor.get("cap_source_factor_count") != 2
        or successor.get("cap_source_factor_names")
        != ["hip_cap_source", "knee_cap_source"]
        or successor.get("cap_source_level_count_per_factor") != 2
        or successor.get("controller_change_count") != 0
        or successor.get("morphology_change_count") != 0
        or successor.get("contact_cycle_threshold_change_count") != 0
        or successor.get("configured_readback_tolerance_change_count") != 0
        or successor.get("turning_threshold_declared") is not False
        or successor.get("mechanism_selected_before_result") is not False
        or successor.get("physical_result_exists") is not False
        or transport.get("transport_id") != design.TRACE_TRANSPORT_ID
        or transport.get("selected_godot_invocation")
        != 'JSON.stringify(value, "", true, true)'
        or transport.get("sorted_keys_required") is not True
        or transport.get("full_precision_required") is not True
        or transport.get("terminal_and_trace_must_use_same_helper") is not True
        or transport.get("numeric_identity_margin") != 0.0
        or transport.get("configured_readback_tolerance_nms")
        != design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        or frozen.get("stage_id") != design.STAGE_ID
        or frozen.get("engine_id") != "godot_jolt"
        or frozen.get("morphology_id") != design.MORPHOLOGY_ID
        or frozen.get("controller_policy_id") != design.POLICY_ID
        or frozen.get("task_frame_origin_policy_id")
        != design.TASK_FRAME_ORIGIN_POLICY_ID
        or frozen.get("startup_transform_id") != design.STARTUP_TRANSFORM_ID
        or frozen.get("seed") != design.CAMPAIGN_SEED
        or frozen.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or frozen.get("heading_offset_rad") != 0.0
        or frozen.get("heading_arm_id") != "reference_zero"
        or frozen.get("controller_step_count") != design.CONTROLLER_STEPS
        or frozen.get("ordered_profile_ids") != list(design.ORDERED_PROFILE_IDS)
        or frozen.get("profile_definitions") != design.PROFILE_DEFINITIONS
        or frozen.get("declared_cell_count") != len(design.cells())
        or frozen.get("declared_world_count") != len(design.cells())
        or frozen.get("serial_execution_required") is not True
        or frozen.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or frozen.get("fresh_world_required_per_cell") is not True
        or frozen.get("profile_bound_once_before_first_authoritative_controller_step")
        is not True
        or frozen.get("same_terminal_and_trace_transport_required_in_every_cell")
        is not True
        or frozen.get("predeclared_factorial_contrasts") != expected_contrasts
        or frozen.get("required_descriptive_outcomes") != expected_outcomes
        or frozen.get("turning_evaluator_invoked") is not False
        or frozen.get("turning_acceptance_authority") is not False
        or frozen.get("mechanism_selection_rule_declared") is not False
        or frozen.get("physical_execution_authorized") is not False
        or factor_adequacy.get("finite_population_boundary")
        != "One morphology, one host/runtime, one initial condition, one reference-heading command, and four factor profiles only."
        or factor_adequacy.get("held_out_validation_performed") is not False
        or factor_adequacy.get("population_sampling_performed") is not False
        or thresholds.get("configured_readback_tolerance_nms")
        != design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        or thresholds.get("contact_cycle_minimum_per_limb") != 2
        or thresholds.get("contact_cycle_threshold_role")
        != "Contextual observation only; it grants no turning or walking acceptance in R23D58."
        or thresholds.get("binary64_identity_margin") != 0.0
        or thresholds.get("new_outcome_threshold_count") != 0
        or thresholds.get("superiority_margin_declared") is not False
        or thresholds.get("equivalence_or_non_inferiority_margin_declared")
        is not False
        or zero_world.get("ordered_profile_count") != len(design.cells())
        or zero_world.get("world_attempt_count") != 0
        or zero_world.get("world_build_count") != 0
        or zero_world.get("physical_acceptance_authority") is not False
        or production_route.get("ordered_profile_count") != len(design.cells())
        or production_route.get("world_attempt_count") != 0
        or production_route.get("world_build_count") != 0
        or production_route.get("physical_campaign_opened") is not False
        or production_route.get("physical_acceptance_authority") is not False
        or regression.get("serialized_execution_count") != 3
        or regression.get("world_attempt_count") != 3
        or regression.get("world_build_count") != 3
        or regression.get("walking_result") != "negative"
        or regression.get("failure_code")
        != "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED"
        or regression.get("sole_failed_walking_gate") != "bounded_anchor_error"
        or regression.get("threshold_changed_after_observation") is not False
        or regression.get("threshold_reinterpreted_after_observation") is not False
        or regression.get("turning_evaluator_invoked") is not False
        or regression.get("turning_claimed") is not False
        or regression.get("prone_to_standing_claimed") is not False
        or campaign.get("campaign_id") != design.CAMPAIGN_ID
        or campaign.get("question_class") != "development"
        or campaign.get("ordered_profile_ids") != list(design.ORDERED_PROFILE_IDS)
        or campaign.get("declared_cell_count") != len(design.cells())
        or campaign.get("declared_world_count") != len(design.cells())
        or campaign.get("serial_execution_required") is not True
        or campaign.get("fresh_world_required_per_cell") is not True
        or campaign.get("all_cells_run_regardless_of_intermediate_outcome")
        is not True
        or campaign.get("outcome_exposed_parent_condition") is not True
        or campaign.get("fresh_held_out_validation") is not False
        or campaign.get("turning_evaluator_invoked") is not False
        or campaign.get("mechanism_selection_rule_declared") is not False
        or campaign.get("physical_execution_authorized") is not False
        or campaign.get("qualification_and_adoption_required_before_physics")
        is not True
        or claims.get("prospective_campaign_identity_reserved") is not True
        or claims.get("prospective_campaign_machinery_implemented") is not True
        or claims.get("complete_campaign_zero_world_gate_passed") is not True
        or claims.get("fresh_clean_pushed_source_qualification_passed") is not False
        or claims.get("campaign_attestation_adoption_passed") is not False
        or claims.get("physical_campaign_opened") is not False
        or claims.get("physical_world_opened") is not False
        or claims.get("rear_contact_mechanism_selected") is not False
        or claims.get("compiled_cap_causality_established") is not False
        or claims.get("godot_jolt_turning") is not False
        or claims.get("prone_to_standing") is not False
        or claims.get("physical_acceptance_authority") is not False
        or claims.get("release_authority") is not False
        or next_boundary.get("prospective_physical_campaign_id_reserved") is not True
        or next_boundary.get("future_worker_evaluator_supervisor_and_manifest_required")
        is not False
        or next_boundary.get(
            "future_evaluator_must_preserve_all_four_cells_regardless_of_intermediate_outcome"
        )
        is not True
        or next_boundary.get(
            "future_evaluator_must_report_predeclared_factorial_contrasts_without_posthoc_mechanism_selection"
        )
        is not True
        or next_boundary.get(
            "complete_zero_world_campaign_gate_and_negative_controls_passed"
        )
        is not True
        or next_boundary.get("r23d58_physical_execution_authorized") is not False
        or next_boundary.get("turning_successor_authorized") is not False
        or next_boundary.get("prone_to_standing_successor_authorized") is not False
    )
    if invalid:
        raise R23D58EvaluationError("R23D58_DECLARATION_IDENTITY_INVALID")

    source_policy = value.get("source_binding_policy", {})
    bindings = source_policy.get("bindings")
    if (
        source_policy.get("algorithm") != "sha256_exact_checkout_bytes"
        or source_policy.get("binding_count") != 15
        or source_policy.get("duplicate_paths_forbidden") is not True
        or source_policy.get("all_declared_paths_required") is not True
        or not isinstance(bindings, list)
        or len(bindings) != 15
    ):
        raise R23D58EvaluationError("R23D58_DECLARATION_BINDING_POLICY_INVALID")
    seen: set[str] = set()
    for binding in bindings:
        if not isinstance(binding, dict):
            raise R23D58EvaluationError("R23D58_DECLARATION_BINDING_INVALID")
        relative = binding.get("path")
        digest = binding.get("raw_sha256")
        if (
            not isinstance(relative, str)
            or not relative
            or relative in seen
            or not _sha256_digest(digest)
        ):
            raise R23D58EvaluationError(
                "R23D58_DECLARATION_BINDING_IDENTITY_INVALID"
            )
        target = (REPO_ROOT / relative).resolve()
        try:
            target.relative_to(REPO_ROOT.resolve())
        except ValueError as error:
            raise R23D58EvaluationError(
                "R23D58_DECLARATION_BINDING_ESCAPES_REPOSITORY"
            ) from error
        if not target.is_file() or raw_sha256(target) != digest:
            raise R23D58EvaluationError(
                f"R23D58_DECLARATION_BINDING_DRIFT:{relative}"
            )
        seen.add(relative)
    return value

# Reuse the accepted R23D34 fixed-horizon trace/CAS implementation, rebound to
# this one-engine post-R23D56 development characterization. The matrix,
# controller, observation, cap route, common walking gates, directional
# measurement, and evaluator tolerances stay unchanged. Only the declared
# full-precision trace transport differs.
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
    entry: Mapping[str, Any],
    rows: Sequence[Mapping[str, Any]],
    item: design.Cell,
) -> list[str]:
    predicates = entry.get("godot_execution_predicates")
    if not isinstance(predicates, dict):
        return ["R23D58_CAP_BINDING_PREDICATE_PROJECTION_MISSING"]
    raw_summary = predicates.get("raw_sdk_authority_summary")
    if not isinstance(raw_summary, dict):
        return ["R23D58_CAP_BINDING_SDK_SUMMARY_MISSING"]
    receipt = raw_summary.get(
        "r23d58_live_fixture_actuator_cap_factorial_binding_receipt"
    )
    if not isinstance(receipt, dict):
        return ["R23D58_CAP_BINDING_RECEIPT_MISSING"]
    if not rows or not isinstance(rows[0], Mapping):
        return ["R23D58_CAP_BINDING_TRACE_MISSING"]
    observation = rows[0].get("actuator_phase_observation")
    if not isinstance(observation, dict):
        return ["R23D58_CAP_BINDING_TRACE_OBSERVATION_MISSING"]
    applications = observation.get("ordered_applications")
    actuator_ids = observation.get("ordered_actuator_ids")
    ordered_bindings = receipt.get("ordered_bindings")
    receipt_actuator_ids = receipt.get("ordered_actuator_ids")
    invalid = (
        raw_summary.get(
            "r23d58_live_fixture_actuator_cap_factorial_binding_policy_id"
        )
        != design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
        or raw_summary.get(
            "r23d58_live_fixture_actuator_cap_factorial_binding_profile_id"
        )
        != item.profile_id
        or raw_summary.get(
            "r23d58_live_fixture_actuator_cap_factorial_binding_integrity_passed"
        )
        is not True
        or receipt.get("schema_version")
        != design.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA
        or receipt.get("ok") is not True
        or receipt.get("failure_code") != ""
        or receipt.get("policy_id") != design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
        or receipt.get("profile_id") != item.profile_id
        or receipt.get("hip_cap_source") != item.hip_cap_source
        or receipt.get("knee_cap_source") != item.knee_cap_source
        or receipt.get("factorial_design")
        != "two_by_two_hip_source_x_knee_source"
        or receipt.get("fixture_composition_schema_version")
        != design.LIVE_FIXTURE_COMPOSITION_SCHEMA
        or receipt.get("validated_actuator_count") != design.ACTUATOR_COUNT
        or receipt.get("validated_limb_count") != len(design.LIMB_IDS)
        or receipt.get("unique_host_joint_object_count") != design.ACTUATOR_COUNT
        or not _integer(receipt.get("portable_fixture_distinct_actuator_count"))
        or not 0
        <= int(receipt.get("portable_fixture_distinct_actuator_count", -1))
        <= design.ACTUATOR_COUNT
        or not _finite(
            receipt.get("maximum_portable_fixture_absolute_delta_nms")
        )
        or float(receipt.get("maximum_portable_fixture_absolute_delta_nms", -1.0))
        < 0.0
        or receipt.get("write_count") != design.ACTUATOR_COUNT
        or receipt.get("readback_count") != design.ACTUATOR_COUNT
        or receipt.get("readback_tolerance_nms")
        != design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        or not _finite(receipt.get("maximum_postbinding_readback_error_nms"))
        or float(receipt.get("maximum_postbinding_readback_error_nms", math.inf))
        > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        or receipt.get("all_fixture_composition_markers_valid") is not True
        or receipt.get("all_host_joint_names_valid") is not True
        or receipt.get("all_postbinding_readbacks_match") is not True
        or receipt.get("complete_surface_validated_before_first_write") is not True
        or receipt.get("scene_tree_insertion_count") != design.ACTUATOR_COUNT
        or receipt.get("configured_parameter_readback_only") is not True
        or receipt.get("measured_motor_torque_available") is not False
        or receipt.get("measured_motor_impulse_available") is not False
        or receipt.get("model_construction_count") != 0
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
        return ["R23D58_CAP_BINDING_RECEIPT_INVALID"]

    observed_maximum_delta = 0.0
    observed_distinct_count = 0
    for binding, application, actuator_id in zip(
        ordered_bindings, applications, actuator_ids, strict=True
    ):
        if not isinstance(binding, dict) or not isinstance(application, dict):
            return ["R23D58_CAP_BINDING_APPLICATION_SHAPE_INVALID"]
        expected_role = (
            "hip_pitch"
            if application.get("limb_joint_index") == 0
            else "knee_pitch"
        )
        expected_source = (
            item.hip_cap_source
            if expected_role == "hip_pitch"
            else item.knee_cap_source
        )
        portable = binding.get("portable_compiled_maximum_impulse_nms")
        fixture = binding.get("fixture_prebinding_maximum_impulse_nms")
        selected = binding.get("selected_maximum_impulse_nms")
        readback = binding.get("motor_maximum_impulse_readback_nms")
        source_delta = binding.get("portable_fixture_absolute_delta_nms")
        binding_error = binding.get("readback_error_nms")
        if any(
            not _finite(value)
            for value in (
                portable,
                fixture,
                selected,
                readback,
                source_delta,
                binding_error,
                application.get("declared_maximum_impulse_nms"),
                application.get("motor_maximum_impulse_readback_nms"),
            )
        ):
            return ["R23D58_CAP_BINDING_APPLICATION_NUMERIC_INVALID"]
        expected_selected = (
            float(portable)
            if expected_source == design.CAP_SOURCE_PORTABLE_COMPILED
            else float(fixture)
        )
        recomputed_delta = abs(float(portable) - float(fixture))
        if (
            binding.get("actuator_id") != actuator_id
            or binding.get("actuator_id") != application.get("actuator_id")
            or binding.get("joint_id") != application.get("joint_id")
            or binding.get("host_joint_id") != application.get("host_joint_id")
            or binding.get("limb_id") != application.get("limb_id")
            or binding.get("joint_role") != expected_role
            or binding.get("selected_cap_source") != expected_source
            or float(selected) != expected_selected
            or float(selected)
            != float(application.get("declared_maximum_impulse_nms"))
            or float(readback)
            != float(application.get("motor_maximum_impulse_readback_nms"))
            or abs(float(source_delta) - recomputed_delta) > 1.0e-15
            or abs(float(binding_error) - abs(float(readback) - float(selected)))
            > 1.0e-15
            or float(binding_error)
            > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
            or binding.get("readback_matches") is not True
        ):
            return ["R23D58_CAP_BINDING_APPLICATION_IDENTITY_INVALID"]
        observed_maximum_delta = max(observed_maximum_delta, recomputed_delta)
        observed_distinct_count += int(
            recomputed_delta > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        )
    if (
        receipt.get("portable_fixture_distinct_actuator_count")
        != observed_distinct_count
        or abs(
            float(receipt["maximum_portable_fixture_absolute_delta_nms"])
            - observed_maximum_delta
        )
        > 1.0e-15
    ):
        return ["R23D58_CAP_BINDING_FACTORIAL_SOURCE_DELTA_INVALID"]
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
    campaign_item = design.cell_by_id(cell_id)
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
                failures.append(f"R23D58_STARTUP_CONTACTS_INVALID:{semantic_step}")
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
                failures.append(f"R23D58_STARTUP_TRANSFORM_INVALID:{semantic_step}")
            active_count += int(expected_scale < 1.0)
            zero_count += int(expected_scale == 0.0)
            unity_count += int(expected_scale == 1.0)

            try:
                segment, _ = design.segment_for_step(
                    campaign_item, semantic_step
                )
            except (design.StartupTransformError, TypeError):
                failures.append(f"R23D58_SEGMENT_INVALID:{semantic_step}")
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
                failures.append(f"R23D58_TASK_FRAME_ORIGIN_INVALID:{semantic_step}")
            if row.get("task_frame_origin_reanchored_this_step") is True:
                observed_transition_steps.append(semantic_step)

            observation_failures, identity = _observation_failures(row, semantic_step)
            failures.extend(
                f"R23D58_{code}:{semantic_step}" for code in observation_failures
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
                        f"R23D58_OBSERVATION_IDENTITY_DRIFT:{semantic_step}"
                    )
                if digest in receipt_digests:
                    failures.append(
                        f"R23D58_OBSERVATION_RECEIPT_DIGEST_REUSED:{semantic_step}"
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
        failures.append("R23D58_TASK_FRAME_ORIGIN_TRANSITION_STEPS")
    if observation_row_count != design.CONTROLLER_STEPS:
        failures.append("R23D58_OBSERVATION_ROW_COUNT")
    if application_count != design.CONTROLLER_STEPS * design.ACTUATOR_COUNT:
        failures.append("R23D58_OBSERVATION_APPLICATION_COUNT")
    summary.update(
        schema_version=TRACE_SUMMARY_SCHEMA,
        ok=not failures,
        failure_codes=failures[:32],
        profile_id=campaign_item.profile_id,
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


def _trace_transport_metadata_failures(artifact: Any) -> list[str]:
    if not isinstance(artifact, Mapping):
        return ["R23D58_TRACE_TRANSPORT_METADATA"]
    failures = []
    if artifact.get("trace_transport_id") != design.TRACE_TRANSPORT_ID:
        failures.append("R23D58_TRACE_TRANSPORT_ID")
    if artifact.get("godot_runtime_version") != "4.7-stable (official)":
        failures.append("R23D58_TRACE_TRANSPORT_RUNTIME")
    if artifact.get("selected_godot_invocation") != 'JSON.stringify(value, "", true, true)':
        failures.append("R23D58_TRACE_TRANSPORT_INVOCATION")
    if artifact.get("godot_json_sorted_keys") is not True:
        failures.append("R23D58_TRACE_TRANSPORT_SORTED_KEYS")
    if artifact.get("godot_json_full_precision") is not True:
        failures.append("R23D58_TRACE_TRANSPORT_FULL_PRECISION")
    if (
        artifact.get("reported_error_recomputation_consistency_tolerance")
        != design.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
    ):
        failures.append("R23D58_TRACE_TRANSPORT_CONSISTENCY_TOLERANCE")
    return failures


def _cas_binding_failures(
    entry: Mapping[str, Any], *, authority_repo_root: Path | None = None
) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D58_TRACE_ARTIFACT_RECEIPT"]
    transport_failures = _trace_transport_metadata_failures(artifact)
    if transport_failures:
        return transport_failures
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D58_TRACE_ARTIFACT_IDENTITY"]
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
        return ["R23D58_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D58_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
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
        return ["R23D58_TRACE_ARTIFACT_BYTES"]
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
        if entry.get("profile_id") != item.profile_id:
            failures.append("R23D58_REPORT_PROFILE_IDENTITY")
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
            failures.append("R23D58_STARTUP_REPORT_INTEGRITY")
        if trace_summary.get("task_frame_origin_transition_steps") != list(
            design.EXPECTED_REANCHOR_STEPS
        ):
            failures.append("R23D58_TASK_FRAME_ORIGIN_REPORT_INTEGRITY")
        failures.extend(_cap_binding_projection_failures(entry, rows, item))
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


def _sequence_sha256(values: Sequence[Any]) -> str:
    payload = json.dumps(
        values,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def characterize_rows(
    rows: Sequence[Mapping[str, Any]],
    item: design.Cell,
) -> dict[str, Any]:
    if len(rows) != design.CONTROLLER_STEPS:
        raise R23D58EvaluationError("R23D58_CHARACTERIZATION_ROW_COUNT_INVALID")
    first_observation = rows[0]["actuator_phase_observation"]
    actuator_ids = list(first_observation["ordered_actuator_ids"])
    limb_ids = list(first_observation["ordered_limb_ids"])
    windows = (
        ("full_horizon", 0, design.CONTROLLER_STEPS),
        (
            "reference_heading_command_window",
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
    contact_sequences: dict[str, list[bool]] = {
        limb_id: [] for limb_id in limb_ids
    }
    previous_contacts = {
        limb_id: bool(rows[0]["ordered_foot_contacts_before"][limb_id])
        for limb_id in limb_ids
    }
    contact_outcomes = {
        limb_id: {
            "contact_loss_transition_count": 0,
            "contact_gain_transition_count": 0,
            "complete_contact_cycle_count": 0,
            "first_contact_loss_semantic_step_or_null": None,
            "contact_true_step_count": 0,
            "_awaiting_gain_after_loss": False,
        }
        for limb_id in limb_ids
    }
    within_step_transitions = {
        limb_id: {
            "false_to_true": 0,
            "true_to_false": 0,
            "unchanged_false": 0,
            "unchanged_true": 0,
        }
        for limb_id in limb_ids
    }
    target_readback_sequences: dict[str, list[list[float]]] = {
        actuator_id: [] for actuator_id in actuator_ids
    }
    selected_cap_by_actuator: dict[str, float] = {}
    source_by_actuator: dict[str, str] = {}
    maximum_target_error = 0.0
    maximum_impulse_error = 0.0
    total_position_saturated = 0
    total_velocity_saturated = 0
    total_slew_limited = 0
    torso_contacts: list[bool] = []
    torso_positions: list[list[float]] = []
    torso_yaws: list[float] = []
    torso_heights: list[float] = []
    torso_tilts: list[float] = []

    for row in rows:
        step = int(row["semantic_step"])
        before = row["ordered_foot_contacts_before"]
        after = row["ordered_foot_contacts_after"]
        for limb_id in limb_ids:
            current = bool(after[limb_id])
            previous = previous_contacts[limb_id]
            outcome = contact_outcomes[limb_id]
            if previous and not current:
                outcome["contact_loss_transition_count"] += 1
                outcome["_awaiting_gain_after_loss"] = True
                if outcome["first_contact_loss_semantic_step_or_null"] is None:
                    outcome["first_contact_loss_semantic_step_or_null"] = step
            elif not previous and current:
                outcome["contact_gain_transition_count"] += 1
                if outcome["_awaiting_gain_after_loss"]:
                    outcome["complete_contact_cycle_count"] += 1
                    outcome["_awaiting_gain_after_loss"] = False
            outcome["contact_true_step_count"] += int(current)
            contact_sequences[limb_id].append(current)
            previous_contacts[limb_id] = current
            within_state = (
                "false_to_true"
                if not before[limb_id] and after[limb_id]
                else "true_to_false"
                if before[limb_id] and not after[limb_id]
                else "unchanged_true"
                if before[limb_id]
                else "unchanged_false"
            )
            within_step_transitions[limb_id][within_state] += 1

        position = row.get("torso_position_world_m")
        yaw = row.get("measured_yaw_rad")
        height = row.get("torso_height_m")
        tilt = row.get("torso_tilt_rad")
        if (
            not isinstance(position, list)
            or len(position) != 3
            or any(not _finite(value) for value in position)
            or not _finite(yaw)
            or not _finite(height)
            or not _finite(tilt)
            or type(row.get("torso_ground_contact")) is not bool
        ):
            raise R23D58EvaluationError(
                f"R23D58_TORSO_CHARACTERIZATION_INVALID:{step}"
            )
        torso_positions.append([float(value) for value in position])
        torso_yaws.append(float(yaw))
        torso_heights.append(float(height))
        torso_tilts.append(float(tilt))
        torso_contacts.append(bool(row["torso_ground_contact"]))

        applications = row["actuator_phase_observation"]["ordered_applications"]
        for application in applications:
            actuator_id = str(application["actuator_id"])
            joint_index = int(application["limb_joint_index"])
            expected_source = (
                item.hip_cap_source if joint_index == 0 else item.knee_cap_source
            )
            controller = float(application["controller_target_velocity_rad_s"])
            target_readback = float(
                application["motor_target_velocity_readback_rad_s"]
            )
            declared_cap = float(application["declared_maximum_impulse_nms"])
            cap_readback = float(
                application["motor_maximum_impulse_readback_nms"]
            )
            prior_cap = selected_cap_by_actuator.setdefault(
                actuator_id, declared_cap
            )
            prior_source = source_by_actuator.setdefault(
                actuator_id, expected_source
            )
            if prior_cap != declared_cap or prior_source != expected_source:
                raise R23D58EvaluationError(
                    f"R23D58_SELECTED_CAP_IDENTITY_DRIFT:{actuator_id}:{step}"
                )
            target_readback_sequences[actuator_id].append(
                [controller, target_readback, declared_cap, cap_readback]
            )
            maximum_target_error = max(
                maximum_target_error,
                float(
                    application[
                        "motor_target_velocity_readback_error_rad_s"
                    ]
                ),
            )
            maximum_impulse_error = max(
                maximum_impulse_error,
                float(
                    application[
                        "motor_maximum_impulse_readback_error_nms"
                    ]
                ),
            )
            total_position_saturated += int(application["position_saturated"])
            total_velocity_saturated += int(application["velocity_saturated"])
            total_slew_limited += int(application["slew_limited"])
            for window_id, start, end in windows:
                if not start <= step < end:
                    continue
                accumulator = accumulators[window_id][actuator_id]
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

    initial_position = torso_positions[0]
    final_position = torso_positions[-1]
    displacement = [
        final - initial
        for initial, final in zip(
            initial_position, final_position, strict=True
        )
    ]
    per_limb = []
    for limb_id in limb_ids:
        outcome = {
            key: value
            for key, value in contact_outcomes[limb_id].items()
            if not key.startswith("_")
        }
        per_limb.append(
            {
                "limb_id": limb_id,
                "contact_boolean_sequence_sample_point": (
                    "ordered_foot_contacts_after"
                ),
                "contact_boolean_sequence_sample_count": len(
                    contact_sequences[limb_id]
                ),
                "contact_boolean_sequence_sha256": _sequence_sha256(
                    contact_sequences[limb_id]
                ),
                **outcome,
                "within_step_contact_transition_count": (
                    within_step_transitions[limb_id]
                ),
            }
        )
    per_actuator = [
        {
            "actuator_id": actuator_id,
            "target_and_readback_sequence_fields": [
                "controller_target_velocity_rad_s",
                "motor_target_velocity_readback_rad_s",
                "declared_maximum_impulse_nms",
                "motor_maximum_impulse_readback_nms",
            ],
            "target_and_readback_sequence_sample_count": len(
                target_readback_sequences[actuator_id]
            ),
            "target_and_readback_sequence_sha256": _sequence_sha256(
                target_readback_sequences[actuator_id]
            ),
            "selected_cap_source": source_by_actuator[actuator_id],
            "selected_maximum_impulse_nms": selected_cap_by_actuator[
                actuator_id
            ],
        }
        for actuator_id in actuator_ids
    ]
    return {
        "schema_version": (
            "sporespore_qsdk_r23d58_cap_source_factorial_characterization_v1"
        ),
        "profile_id": item.profile_id,
        "hip_cap_source": item.hip_cap_source,
        "knee_cap_source": item.knee_cap_source,
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
        "per_limb_contact_characterization": per_limb,
        "per_actuator_target_readback_and_selected_cap_characterization": (
            per_actuator
        ),
        "torso_contact_characterization": {
            "sequence_sample_count": len(torso_contacts),
            "sequence_sha256": _sequence_sha256(torso_contacts),
            "contact_true_step_count": sum(torso_contacts),
            "first_contact_semantic_step_or_null": next(
                (
                    index
                    for index, contact in enumerate(torso_contacts)
                    if contact
                ),
                None,
            ),
        },
        "torso_pose_and_displacement_context": {
            "initial_position_world_m": initial_position,
            "final_position_world_m": final_position,
            "displacement_world_m": displacement,
            "displacement_norm_m": math.sqrt(
                math.fsum(component * component for component in displacement)
            ),
            "initial_yaw_rad": torso_yaws[0],
            "final_yaw_rad": torso_yaws[-1],
            "yaw_delta_rad": torso_yaws[-1] - torso_yaws[0],
            "minimum_torso_height_m": min(torso_heights),
            "maximum_torso_height_m": max(torso_heights),
            "maximum_absolute_torso_tilt_rad": max(
                abs(value) for value in torso_tilts
            ),
        },
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
        "full_sequences_retained_in_content_addressed_trace": True,
        "configured_motor_parameters_only": True,
        "measured_motor_torque_available": False,
        "measured_motor_impulse_available": False,
        "turning_gate_invoked": False,
        "mechanism_selected": False,
        "physical_acceptance_authority": False,
    }


def _numeric_metric_projection(
    characterization: Mapping[str, Any],
) -> dict[str, float]:
    metrics: dict[str, float] = {}
    for limb in characterization["per_limb_contact_characterization"]:
        limb_id = str(limb["limb_id"])
        for field in (
            "contact_loss_transition_count",
            "contact_gain_transition_count",
            "complete_contact_cycle_count",
            "contact_true_step_count",
        ):
            metrics[f"limb.{limb_id}.{field}"] = float(limb[field])
        first_loss = limb["first_contact_loss_semantic_step_or_null"]
        if first_loss is not None:
            metrics[f"limb.{limb_id}.first_contact_loss_semantic_step"] = float(
                first_loss
            )
    for actuator in characterization[
        "per_actuator_target_readback_and_selected_cap_characterization"
    ]:
        metrics[
            f"actuator.{actuator['actuator_id']}.selected_maximum_impulse_nms"
        ] = float(actuator["selected_maximum_impulse_nms"])
    torso_contact = characterization["torso_contact_characterization"]
    metrics["torso.contact_true_step_count"] = float(
        torso_contact["contact_true_step_count"]
    )
    pose = characterization["torso_pose_and_displacement_context"]
    for index, axis in enumerate(("x", "y", "z")):
        metrics[f"torso.displacement_world_{axis}_m"] = float(
            pose["displacement_world_m"][index]
        )
    for field in (
        "displacement_norm_m",
        "yaw_delta_rad",
        "minimum_torso_height_m",
        "maximum_torso_height_m",
        "maximum_absolute_torso_tilt_rad",
    ):
        metrics[f"torso.{field}"] = float(pose[field])
    for window in characterization["ordered_windows"]:
        if window["window_id"] != "full_horizon":
            continue
        for actuator in window["ordered_actuator_statistics"]:
            actuator_id = actuator["actuator_id"]
            metrics[
                f"actuator.{actuator_id}.controller_target_velocity_absolute_sum_rad_s"
            ] = float(
                actuator["controller_target_velocity_absolute_sum_rad_s"]
            )
    return metrics


def _metric_delta(
    high: Mapping[str, float],
    low: Mapping[str, float],
) -> tuple[dict[str, float], list[str]]:
    common = sorted(set(high) & set(low))
    missing = sorted(set(high) ^ set(low))
    return (
        {metric: float(high[metric] - low[metric]) for metric in common},
        missing,
    )


def _factorial_contrast_report(
    characterization_by_profile: Mapping[str, Mapping[str, Any]],
) -> dict[str, Any]:
    if set(characterization_by_profile) != set(design.ORDERED_PROFILE_IDS):
        raise R23D58EvaluationError(
            "R23D58_FACTORIAL_CHARACTERIZATION_PROFILE_SET_INVALID"
        )
    metrics = {
        profile_id: _numeric_metric_projection(
            characterization_by_profile[profile_id]
        )
        for profile_id in design.ORDERED_PROFILE_IDS
    }
    ordered: list[dict[str, Any]] = []
    simple_deltas: dict[str, dict[str, float]] = {}
    for contrast_id, (high_profile, low_profile) in (
        design.PREDECLARED_FACTORIAL_CONTRASTS.items()
    ):
        deltas, missing = _metric_delta(
            metrics[high_profile], metrics[low_profile]
        )
        simple_deltas[contrast_id] = deltas
        ordered.append(
            {
                "contrast_id": contrast_id,
                "formula": f"{high_profile} minus {low_profile}",
                "high_profile_id": high_profile,
                "low_profile_id": low_profile,
                "ordered_metric_deltas": [
                    {"metric_id": metric, "delta": deltas[metric]}
                    for metric in sorted(deltas)
                ],
                "metrics_omitted_due_null_or_shape_mismatch": missing,
                "superiority_or_equivalence_interpretation": False,
                "mechanism_selection_authority": False,
            }
        )
    knee_fixture = simple_deltas["knee_source_at_fixture_hip"]
    knee_portable = simple_deltas["knee_source_at_portable_hip"]
    interaction, interaction_missing = _metric_delta(
        knee_fixture, knee_portable
    )
    ordered.append(
        {
            "contrast_id": "interaction",
            "formula": (
                "knee_source_at_fixture_hip minus "
                "knee_source_at_portable_hip"
            ),
            "ordered_metric_deltas": [
                {"metric_id": metric, "delta": interaction[metric]}
                for metric in sorted(interaction)
            ],
            "metrics_omitted_due_null_or_shape_mismatch": (
                interaction_missing
            ),
            "superiority_or_equivalence_interpretation": False,
            "mechanism_selection_authority": False,
        }
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r23d58_predeclared_factorial_contrasts_v1"
        ),
        "ordered_contrast_count": len(ordered),
        "ordered_contrasts": ordered,
        "outcome_threshold_count": 0,
        "superiority_margin_declared": False,
        "equivalence_or_non_inferiority_margin_declared": False,
        "posthoc_profile_selection_performed": False,
        "mechanism_selected": False,
        "turning_gate_invoked": False,
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
        raise R23D58EvaluationError("R23D58_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    if not (authority_root / ".git").exists():
        raise R23D58EvaluationError("R23D58_AUTHORITY_REPO_ROOT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict)
        or entry.get("cell_id") != item.cell_id
        or entry.get("profile_id") != item.profile_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D58EvaluationError("R23D58_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, expected, strict=True):
        evaluation, rows = evaluate_entry(
            entry,
            item,
            expected_source_commit=expected_source_commit,
            authority_repo_root=authority_root,
        )
        evaluation["profile_id"] = item.profile_id
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows
    all_execution_valid = all(row["execution_valid"] for row in evaluations)
    all_contextual_physical_gates_passed = all(
        row["common_physical_gate_passed"] for row in evaluations
    )
    characterization_by_profile: dict[str, Any] = {}
    contrast_report: dict[str, Any] = {
        "status": "not_computed_because_one_or_more_cells_are_execution_invalid",
        "mechanism_selected": False,
        "turning_gate_invoked": False,
        "physical_acceptance_authority": False,
    }
    if all_execution_valid:
        characterization_by_profile = {
            item.profile_id: characterize_rows(
                rows_by_cell[item.cell_id], item
            )
            for item in expected
        }
        contrast_report = _factorial_contrast_report(
            characterization_by_profile
        )
    classification = (
        "valid_complete_outcome_exposed_godot_cap_source_factorial_rear_contact_mechanism_development"
        if all_execution_valid
        else "invalid_complete_outcome_exposed_godot_cap_source_factorial_rear_contact_mechanism_development"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["live_fixture_actuator_cap_binding_verified"] = all_execution_valid
    claims["actuator_phase_characterization_complete"] = all_execution_valid
    claims["cap_source_factorial_characterization_complete"] = (
        all_execution_valid
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": "development",
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
            "cap_source_factorial_characterization_complete": (
                all_execution_valid
            ),
            "characterization_by_profile": characterization_by_profile,
            "predeclared_factorial_contrasts": contrast_report,
            "turning_gate_invoked": False,
            "turning_mechanism_selected": False,
        },
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_held_out_condition_consumed": False,
        "outcome_exposed_before_campaign_identity_reservation": True,
        "terminal_restoration_or_taper_invoked": False,
        "cross_engine_equivalence_test_invoked": False,
        "population_inference_attempted": False,
        "posthoc_profile_selection_performed": False,
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
        portable_cap = 0.5 + index * 0.01
        fixture_cap = portable_cap * 1.015
        selected_source = (
            item.hip_cap_source
            if joint_index == 0
            else item.knee_cap_source
        )
        selected_cap = (
            portable_cap
            if selected_source == design.CAP_SOURCE_PORTABLE_COMPILED
            else fixture_cap
        )
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
                "declared_maximum_impulse_nms": selected_cap,
                "motor_maximum_impulse_readback_nms": selected_cap,
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
    item: design.Cell,
    rows: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    observation = rows[0]["actuator_phase_observation"]
    applications = observation["ordered_applications"]
    actuator_ids = list(observation["ordered_actuator_ids"])
    ordered_bindings: list[dict[str, Any]] = []
    maximum_delta = 0.0
    distinct_count = 0
    for application in applications:
        joint_index = int(application["limb_joint_index"])
        portable = 0.5 + actuator_ids.index(application["actuator_id"]) * 0.01
        fixture = portable * 1.015
        source = item.hip_cap_source if joint_index == 0 else item.knee_cap_source
        selected = (
            portable
            if source == design.CAP_SOURCE_PORTABLE_COMPILED
            else fixture
        )
        delta = abs(portable - fixture)
        maximum_delta = max(maximum_delta, delta)
        distinct_count += int(
            delta > design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
        )
        if selected != float(application["declared_maximum_impulse_nms"]):
            raise AssertionError("R23D58_SYNTHETIC_CAP_APPLICATION_MISMATCH")
        ordered_bindings.append(
            {
                "actuator_id": application["actuator_id"],
                "joint_id": application["joint_id"],
                "host_joint_id": application["host_joint_id"],
                "limb_id": application["limb_id"],
                "joint_role": "hip_pitch" if joint_index == 0 else "knee_pitch",
                "host_joint_name": f"joint_{application['actuator_id']}",
                "selected_cap_source": source,
                "portable_compiled_maximum_impulse_nms": portable,
                "fixture_prebinding_maximum_impulse_nms": fixture,
                "portable_fixture_absolute_delta_nms": delta,
                "selected_maximum_impulse_nms": selected,
                "motor_maximum_impulse_readback_nms": selected,
                "readback_error_nms": 0.0,
                "readback_matches": True,
            }
        )
    receipt = {
        "schema_version": design.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA,
        "ok": True,
        "failure_code": "",
        "policy_id": design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID,
        "profile_id": item.profile_id,
        "hip_cap_source": item.hip_cap_source,
        "knee_cap_source": item.knee_cap_source,
        "factorial_design": "two_by_two_hip_source_x_knee_source",
        "fixture_composition_schema_version": design.LIVE_FIXTURE_COMPOSITION_SCHEMA,
        "ordered_actuator_ids": actuator_ids,
        "ordered_bindings": ordered_bindings,
        "validated_actuator_count": design.ACTUATOR_COUNT,
        "validated_limb_count": len(design.LIMB_IDS),
        "unique_host_joint_object_count": design.ACTUATOR_COUNT,
        "portable_fixture_distinct_actuator_count": distinct_count,
        "maximum_portable_fixture_absolute_delta_nms": maximum_delta,
        "write_count": design.ACTUATOR_COUNT,
        "readback_count": design.ACTUATOR_COUNT,
        "readback_tolerance_nms": design.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS,
        "maximum_postbinding_readback_error_nms": 0.0,
        "all_fixture_composition_markers_valid": True,
        "all_host_joint_names_valid": True,
        "all_postbinding_readbacks_match": True,
        "complete_surface_validated_before_first_write": True,
        "scene_tree_insertion_count": design.ACTUATOR_COUNT,
        "configured_parameter_readback_only": True,
        "measured_motor_torque_available": False,
        "measured_motor_impulse_available": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }
    return {
        "godot_execution_predicates": {
            "raw_sdk_authority_summary": {
                "r23d58_live_fixture_actuator_cap_factorial_binding_policy_id": (
                    design.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
                ),
                "r23d58_live_fixture_actuator_cap_factorial_binding_profile_id": (
                    item.profile_id
                ),
                "r23d58_live_fixture_actuator_cap_factorial_binding_receipt": receipt,
                "r23d58_live_fixture_actuator_cap_factorial_binding_integrity_passed": True,
            }
        }
    }


def _cap_projection_mutation(value: dict[str, Any], mutation_id: str) -> None:
    predicates = value["godot_execution_predicates"]
    raw_summary = predicates["raw_sdk_authority_summary"]
    receipt = raw_summary[
        "r23d58_live_fixture_actuator_cap_factorial_binding_receipt"
    ]
    if mutation_id == "missing_projection":
        value.pop("godot_execution_predicates")
    elif mutation_id == "missing_summary":
        predicates.pop("raw_sdk_authority_summary")
    elif mutation_id == "wrong_projected_policy":
        raw_summary[
            "r23d58_live_fixture_actuator_cap_factorial_binding_policy_id"
        ] += "_mutated"
    elif mutation_id == "wrong_projected_profile":
        raw_summary[
            "r23d58_live_fixture_actuator_cap_factorial_binding_profile_id"
        ] = design.PROFILE_FIXTURE_HIP_FIXTURE_KNEE
    elif mutation_id == "integrity_false":
        raw_summary[
            "r23d58_live_fixture_actuator_cap_factorial_binding_integrity_passed"
        ] = False
    elif mutation_id == "missing_receipt":
        raw_summary.pop(
            "r23d58_live_fixture_actuator_cap_factorial_binding_receipt"
        )
    elif mutation_id == "receipt_schema":
        receipt["schema_version"] += "_mutated"
    elif mutation_id == "receipt_policy":
        receipt["policy_id"] += "_mutated"
    elif mutation_id == "receipt_profile":
        receipt["profile_id"] = design.PROFILE_FIXTURE_HIP_FIXTURE_KNEE
    elif mutation_id == "receipt_source":
        receipt["hip_cap_source"] = design.CAP_SOURCE_FIXTURE_PREBINDING
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
    elif mutation_id == "binding_source":
        receipt["ordered_bindings"][0]["selected_cap_source"] = (
            design.CAP_SOURCE_FIXTURE_PREBINDING
        )
    elif mutation_id == "binding_cap":
        receipt["ordered_bindings"][0]["selected_maximum_impulse_nms"] += 0.01
    elif mutation_id == "binding_source_delta":
        receipt["ordered_bindings"][0][
            "portable_fixture_absolute_delta_nms"
        ] += 0.01
    else:
        raise AssertionError(mutation_id)


def _manifest_paths_value(value: Any) -> list[str]:
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise R23D58EvaluationError("R23D58_TERMINAL_MANIFEST_INVALID")
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
    characterization_by_profile = {
        item.profile_id: characterize_rows(traces[item.cell_id], item)
        for item in design.cells()
    }
    characterizations = list(characterization_by_profile.values())
    factorial_contrasts = _factorial_contrast_report(
        characterization_by_profile
    )
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
        "wrong_projected_profile",
        "integrity_false",
        "missing_receipt",
        "receipt_schema",
        "receipt_policy",
        "receipt_profile",
        "receipt_source",
        "validated_count",
        "write_count",
        "readback_count",
        "excessive_readback_error",
        "readback_flag",
        "actuator_order",
        "binding_source",
        "binding_cap",
        "binding_source_delta",
    )
    cap_trace_mutation_ids = (
        "application_declared_cap_type",
        "application_readback_type",
    )
    cap_projections = {
        item.profile_id: _synthetic_cap_binding_projection(
            item, traces[item.cell_id]
        )
        for item in design.cells()
    }
    cap_projection_positive_count = sum(
        not _cap_binding_projection_failures(
            cap_projections[item.profile_id], traces[item.cell_id], item
        )
        for item in design.cells()
    )
    if cap_projection_positive_count != len(design.cells()):
        raise R23D58EvaluationError("R23D58_CAP_BINDING_POSITIVE_CANARY_INVALID")
    cap_projection = cap_projections[first.profile_id]
    cap_projection_rejections = 0
    for mutation_id in cap_projection_mutation_ids:
        mutated = copy.deepcopy(cap_projection)
        _cap_projection_mutation(mutated, mutation_id)
        cap_projection_rejections += int(
            bool(
                _cap_binding_projection_failures(
                    mutated, traces[first.cell_id], first
                )
            )
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
            bool(
                _cap_binding_projection_failures(
                    cap_projection, mutated_rows, first
                )
            )
        )
    trace_transport_metadata = {
        "trace_transport_id": design.TRACE_TRANSPORT_ID,
        "godot_runtime_version": "4.7-stable (official)",
        "selected_godot_invocation": 'JSON.stringify(value, "", true, true)',
        "godot_json_sorted_keys": True,
        "godot_json_full_precision": True,
        "reported_error_recomputation_consistency_tolerance": (
            design.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
        ),
    }
    if _trace_transport_metadata_failures(trace_transport_metadata):
        raise R23D58EvaluationError(
            "R23D58_TRACE_TRANSPORT_METADATA_POSITIVE_CANARY_INVALID"
        )
    transport_metadata_mutations = {
        "trace_transport_id": "mutated",
        "godot_runtime_version": "4.8-stable (official)",
        "selected_godot_invocation": "JSON.stringify(rows)",
        "godot_json_sorted_keys": False,
        "godot_json_full_precision": False,
        "reported_error_recomputation_consistency_tolerance": 1.0e-12,
    }
    transport_metadata_rejections = 0
    for field, replacement in transport_metadata_mutations.items():
        mutated = copy.deepcopy(trace_transport_metadata)
        mutated[field] = replacement
        transport_metadata_rejections += int(
            bool(_trace_transport_metadata_failures(mutated))
        )
    invalid_manifest_count = 0
    for value in ("one", {"path": "one"}, [""], [1]):
        try:
            _manifest_paths_value(value)
        except R23D58EvaluationError:
            invalid_manifest_count += 1
    alternate = _alternate_windows_spelling(DECLARATION_PATH)
    same_file_alias_accepted = _same_existing_file(DECLARATION_PATH, alternate)
    wrong_existing_file_rejected = not _same_existing_file(
        DECLARATION_PATH,
        ROOT / "r23d58_godot_cap_source_factorial.py",
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
        or transport_metadata_rejections != len(transport_metadata_mutations)
        or not characterization_exact
        or factorial_contrasts["ordered_contrast_count"] != 5
        or factorial_contrasts["posthoc_profile_selection_performed"] is not False
        or [
            len(_manifest_paths_value(value))
            for value in ([], ["one"], ["one", "two", "three", "four"])
        ]
        != [0, 1, 4]
        or invalid_manifest_count != 4
        or not same_file_alias_accepted
        or not wrong_existing_file_rejected
        or complete_arguments.repo_root != REPO_ROOT
    ):
        raise R23D58EvaluationError("R23D58_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d58_evaluator_preflight_v1",
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
        "live_fixture_cap_binding_projection_positive_control_count": (
            cap_projection_positive_count
        ),
        "live_fixture_cap_binding_projection_mutation_rejection_count": (
            cap_projection_rejections
        ),
        "trace_transport_metadata_positive_control_count": 1,
        "trace_transport_metadata_mutation_rejection_count": (
            transport_metadata_rejections
        ),
        "trace_transport_id": design.TRACE_TRANSPORT_ID,
        "godot_runtime_version": "4.7-stable (official)",
        "godot_json_full_precision": True,
        "reported_error_recomputation_consistency_tolerance": (
            design.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
        ),
        "descriptive_characterization_canary_count": len(characterizations),
        "predeclared_factorial_contrast_canary_count": (
            factorial_contrasts["ordered_contrast_count"]
        ),
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
            marker = "QSDK_R23D58_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D58_TRACE_RETAINED "
        else:
            manifest_value = json.loads(args.manifest.read_text(encoding="utf-8"))
            paths = _manifest_paths_value(manifest_value)
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.expected_source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D58_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D58EvaluationError,
        inherited.R23D34EvaluationError,
        inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D58_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
