#!/usr/bin/env python3
"""Canonical retained-evidence evaluator for the prospective QSDK-R23D65 decision.

R23D65 is an exact finite conjunction, not an equivalence or population study.
The accepted R23D48/R23D60 trace, common-gate, task-origin, startup, CAS, and
cycle-integrated measurement algorithms are reused mechanically.  This module
adds the R23D61 public-profile resolution, per-engine host mapping, physical
binding, exact ordered-cap, and nine-cell conjunction checks.  Its preflight
constructs no native model or physics world and grants no physical authority.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d31_cycle_integrated_measurement as measurement
import r23d58_godot_cap_source_factorial_evaluator as accepted
import r23d60_godot_fixture_knee_held_out_turning_validation as r60_design
import r23d65_selected_profile_three_engine_turning_validation as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT
    / "r23d65_selected_profile_three_engine_turning_validation_"
    "preregistration_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d48_trace.ps1"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
REPORT_SCHEMA = "sporespore_qsdk_r23d65_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d65_worker_failure_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d65_turning_trace_row_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d65_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d65_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = (
    "sporespore_qsdk_r23d65_complete_three_engine_turning_evaluation_v1"
)
PHYSICAL_BINDING_SCHEMA = (
    "sporespore_qsdk_r23d62_physical_actuator_cap_binding_v1"
)
TRACE_TRANSPORT_ID = "sporespore_r23d65_full_precision_native_trace_transport_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"

PROFILE_ACTUATOR_IDS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
PROFILE_JOINT_IDS = (
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
)
PLACEHOLDER_TRACE_ACTUATOR_IDS = tuple(
    f"{limb_id}_joint_{joint_index}"
    for limb_id in r60_design.LIMB_IDS
    for joint_index in range(2)
)
TRACE_ACTUATOR_IDS = PROFILE_ACTUATOR_IDS
COLD_GODOT_TRACE_SHA256 = (
    "sha256:5a90a4b11d9cab5f49513752a0cd2beb3da7346672db3f0747a1b071cab3ccbc"
)
COLD_GODOT_TRACE_ROW_COUNT = 2_992
COLD_BASELINE_SCHEMA = (
    "sporespore_qsdk_r23d65_canonical_evaluator_genuine_godot_"
    "trace_shape_cold_baseline_v1"
)
HOST_MAPPING_SCHEMAS = {
    "godot_jolt": "sporespore_godot_actuator_cap_profile_binding_receipt_v1",
    "rapier_parry": "sporespore_rapier_actuator_cap_profile_zero_world_mapping_v1",
    "mujoco": "sporespore_mujoco_actuator_cap_profile_zero_world_mapping_v1",
}
CONFIGURATION_READBACK_TOLERANCE_NMS = {
    "godot_jolt": 2.5e-7,
    "rapier_parry": 4.355907492481492e-7,
    "mujoco": 4.440892098500626e-16,
}
DECLARED_SEGMENT_COUNTS = design.expected_segment_counts()
FALSE_CLAIMS = {
    "r23d65_finite_three_engine_turning": False,
    "godot_jolt_turning_extended_to_seed_23175": False,
    "fresh_rapier_turning_replication": False,
    "fresh_mujoco_turning_replication": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "arbitrary_quadruped_coverage": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D65EvaluationError(RuntimeError):
    """The declaration, trace, mapping, binding, or finite matrix is invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D65EvaluationError(code)


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


def _json_sha256(value: Any) -> str:
    payload = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D65EvaluationError(
            f"R23D65_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    try:
        design.validate_declaration(value)
    except design.DeclarationError as error:
        raise R23D65EvaluationError(
            f"R23D65_DECLARATION_INVALID:{error}"
        ) from error
    requirements = value.get("implementation_and_execution_requirements", {})
    decision = value.get("finite_decision_rule", {})
    _require(
        requirements.get("public_profile_resolution_and_host_readback_controls_required")
        is True
        and requirements.get("task_origin_and_schedule_semantic_canaries_required_per_engine")
        is True
        and requirements.get("exact_worker_to_retainer_to_evaluator_transport_canary_required_per_engine")
        is True
        and decision.get("complete_execution_valid_nine_cell_matrix_required") is True
        and decision.get("each_engine_must_independently_pass_both_turning_gates")
        is True
        and decision.get("positive_qsdk_r23_transition_permitted") is True
        and decision.get("positive_cross_engine_equivalence") is False,
        "R23D65_EVALUATOR_DECLARATION_REQUIREMENTS_INVALID",
    )
    return value


def _cell_by_id(cell_id: str) -> design.Cell:
    matches = [item for item in design.cells() if item.cell_id == cell_id]
    _require(len(matches) == 1, f"R23D65_CELL_ID_INVALID:{cell_id}")
    return matches[0]


def _expected_segment_counts(_item: design.Cell) -> dict[str, int]:
    return dict(DECLARED_SEGMENT_COUNTS)


def _bind_accepted_core() -> None:
    """Bind accepted generic algorithms to the frozen R23D65 identities."""

    portable_source = r60_design.reservation.CAP_SOURCE_PORTABLE_COMPILED
    fixture_source = r60_design.reservation.CAP_SOURCE_FIXTURE_PREBINDING
    if not hasattr(design.Cell, "hip_cap_source"):
        setattr(design.Cell, "hip_cap_source", property(lambda _item: portable_source))
        setattr(design.Cell, "knee_cap_source", property(lambda _item: fixture_source))
        setattr(design.Cell, "onset_id", property(lambda _item: "onset_600"))
        setattr(
            design.Cell,
            "turn_start_semantic_step",
            property(lambda _item: design.TURN_START_STEP),
        )

    design.ENGINE_IDS = design.ENGINES
    design.ARM_OFFSETS = dict(design.ARMS)
    design.TURN_DURATION_STEPS = design.TURN_END_STEP_EXCLUSIVE - design.TURN_START_STEP
    design.GAIT_CYCLE_STEPS = r60_design.GAIT_CYCLE_STEPS
    design.RAMP_LAST_LOCAL_STEP = r60_design.RAMP_LAST_LOCAL_STEP
    design.PROBE_LAST_SEMANTIC_STEP = r60_design.PROBE_LAST_SEMANTIC_STEP
    design.STARTUP_RAMP_ID = design.STARTUP_TRANSFORM_ID
    design.STARTUP_RAMP_STEPS = r60_design.STARTUP_RAMP_STEPS
    design.INITIAL_SCHEDULE_BIND_STEP = r60_design.INITIAL_SCHEDULE_BIND_STEP
    design.FIXED_ORIGIN_LAST_SEMANTIC_STEP = r60_design.FIXED_ORIGIN_LAST_SEMANTIC_STEP
    design.EXPECTED_REANCHOR_STEPS = r60_design.EXPECTED_REANCHOR_STEPS
    design.TASK_FRAME_ORIGIN_POLICY_ID = design.TASK_ORIGIN_POLICY_ID
    design.LIMB_IDS = r60_design.LIMB_IDS
    design.PHASE_OFFSETS = r60_design.PHASE_OFFSETS
    design.TRACE_ROW_SCHEMA = TRACE_ROW_SCHEMA
    design.ACTUATOR_PHASE_OBSERVATION_SCHEMA = (
        r60_design.ACTUATOR_PHASE_OBSERVATION_SCHEMA
    )
    design.APPLICATION_RECEIPT_SCHEMA = r60_design.APPLICATION_RECEIPT_SCHEMA
    design.TRACE_TRANSPORT_ID = TRACE_TRANSPORT_ID
    design.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE = (
        r60_design.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
    )
    design.CAP_SOURCE_PORTABLE_COMPILED = portable_source
    design.CAP_SOURCE_FIXTURE_PREBINDING = fixture_source
    design.ORDERED_PROFILE_IDS = (design.PROFILE_ID,)
    design.PROFILE_DEFINITIONS = {
        design.PROFILE_ID: {
            "hip_cap_source": portable_source,
            "knee_cap_source": fixture_source,
        }
    }
    design.PROFILE_FIXTURE_HIP_FIXTURE_KNEE = design.PROFILE_ID
    design.StartupTransformError = design.DeclarationError
    design.SupportLossConditionedStartup = r60_design.SupportLossConditionedStartup
    design.cell_by_id = _cell_by_id
    design.expected_segment_counts = _expected_segment_counts
    design.MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD = 0.01
    design.MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD = 0.01

    accepted.design = design
    accepted.DECLARATION_PATH = DECLARATION_PATH
    accepted.PUBLISHER_PATH = PUBLISHER_PATH
    accepted.PUBLISHER_MARKER = PUBLISHER_MARKER
    accepted.REPORT_SCHEMA = REPORT_SCHEMA
    accepted.FAILURE_SCHEMA = FAILURE_SCHEMA
    accepted.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
    accepted.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
    accepted.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
    accepted.FALSE_CLAIMS = FALSE_CLAIMS
    accepted.load_declaration = load_declaration
    accepted._cap_binding_projection_failures = _public_profile_projection_failures
    accepted._cas_binding_failures = _cas_binding_failures

    inherited = accepted.inherited
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
    inherited.validate_trace = accepted.validate_trace


def _trace_profile_cap_failures(
    rows: Any,
    item: design.Cell,
    *,
    expected_actuator_ids: Sequence[str] = TRACE_ACTUATOR_IDS,
) -> list[str]:
    if not isinstance(rows, list) or len(rows) != design.CONTROLLER_STEPS:
        return ["R23D65_TRACE_CAP_ROWS_INVALID"]
    tolerance = CONFIGURATION_READBACK_TOLERANCE_NMS[item.engine_id]
    for semantic_step, row in enumerate(rows):
        if not isinstance(row, Mapping):
            return [f"R23D65_TRACE_CAP_ROW_INVALID:{semantic_step}"]
        observation = row.get("actuator_phase_observation")
        if not isinstance(observation, Mapping):
            return [f"R23D65_TRACE_CAP_OBSERVATION_MISSING:{semantic_step}"]
        actuator_ids = observation.get("ordered_actuator_ids")
        applications = observation.get("ordered_applications")
        if actuator_ids != list(expected_actuator_ids) or not isinstance(applications, list):
            return [f"R23D65_TRACE_CAP_ORDER_INVALID:{semantic_step}"]
        if len(applications) != design.ACTUATOR_COUNT:
            return [f"R23D65_TRACE_CAP_CARDINALITY_INVALID:{semantic_step}"]
        for index, (application, trace_actuator_id, cap) in enumerate(
            zip(
                applications,
                expected_actuator_ids,
                design.ORDERED_CAPS_NMS,
                strict=True,
            )
        ):
            if not isinstance(application, Mapping):
                return [f"R23D65_TRACE_CAP_APPLICATION_INVALID:{semantic_step}:{index}"]
            declared = application.get("declared_maximum_impulse_nms")
            readback = application.get("motor_maximum_impulse_readback_nms")
            reported_error = application.get("motor_maximum_impulse_readback_error_nms")
            if not all(_finite(value) for value in (declared, readback, reported_error)):
                return [f"R23D65_TRACE_CAP_NONFINITE:{semantic_step}:{index}"]
            recomputed_error = abs(float(readback) - float(declared))
            if (
                application.get("actuator_id") != trace_actuator_id
                or float(declared) != float(cap)
                or recomputed_error > tolerance
                or abs(float(reported_error) - recomputed_error) > 1.0e-15
                or application.get("maximum_impulse_readback_matches") is not True
            ):
                return [f"R23D65_TRACE_CAP_IDENTITY_INVALID:{semantic_step}:{index}"]
    return []


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    _bind_accepted_core()
    item = _cell_by_id(cell_id)
    summary = accepted.validate_trace(cell_id, rows)
    failures = list(summary.get("failure_codes", []))
    cap_failures = _trace_profile_cap_failures(rows, item)
    failures.extend(cap_failures)
    summary.update(
        schema_version=TRACE_SUMMARY_SCHEMA,
        ok=not failures,
        failure_codes=failures[:32],
        campaign_seed=item.campaign_seed,
        profile_id=item.profile_id,
        host_mapping_id=item.host_mapping_id,
        exact_public_profile_caps_observed=not cap_failures,
    )
    return summary


def _resolution_failures(value: Any) -> list[str]:
    if not isinstance(value, Mapping):
        return ["R23D65_PROFILE_RESOLUTION_MISSING"]
    profile = value.get("profile")
    if not isinstance(profile, Mapping):
        return ["R23D65_PROFILE_RESOLUTION_PROFILE_MISSING"]
    semantics = profile.get("semantics")
    ordered_caps = profile.get("ordered_caps")
    invalid = (
        value.get("schema_version") != "sporespore_actuator_cap_profile_receipt_v1"
        or value.get("requested_profile_id") != design.PROFILE_ID
        or value.get("supported_profile_ids") != [design.PROFILE_ID]
        or value.get("support_status") != "supported_exact"
        or value.get("refusal_reason") is not None
        or value.get("descriptor_sha256") != design.DESCRIPTOR_SHA256
        or value.get("morphology_spec_sha256") != design.MORPHOLOGY_SPEC_SHA256
        or value.get("profile_sha256") != design.PROFILE_SHA256
        or value.get("world_build_count") != 0
        or value.get("physics_state_modified") is not False
        or value.get("physical_acceptance_authority") is not False
        or value.get("release_authority") is not False
        or profile.get("schema_version") != "sporespore_actuator_cap_profile_v1"
        or profile.get("profile_id") != design.PROFILE_ID
        or profile.get("supported_morphology_id") != design.MORPHOLOGY_ID
        or profile.get("supported_descriptor_sha256") != design.DESCRIPTOR_SHA256
        or profile.get("supported_morphology_spec_sha256")
        != design.MORPHOLOGY_SPEC_SHA256
        or not isinstance(semantics, Mapping)
        or semantics.get("semantics_id") != design.PROFILE_SEMANTICS_ID
        or not isinstance(ordered_caps, list)
        or len(ordered_caps) != design.ACTUATOR_COUNT
    )
    if invalid:
        return ["R23D65_PROFILE_RESOLUTION_INVALID"]
    for index, (entry, actuator_id, joint_id, cap, cap_hex) in enumerate(
        zip(
            ordered_caps,
            PROFILE_ACTUATOR_IDS,
            PROFILE_JOINT_IDS,
            design.ORDERED_CAPS_NMS,
            design.ORDERED_CAPS_BINARY64_HEX,
            strict=True,
        )
    ):
        if not isinstance(entry, Mapping) or (
            entry.get("actuator_id") != actuator_id
            or entry.get("joint_id") != joint_id
            or not _finite(entry.get("maximum_outer_step_impulse_nms"))
            or float(entry["maximum_outer_step_impulse_nms"]) != float(cap)
            or entry.get("maximum_outer_step_impulse_binary64_hex") != cap_hex
        ):
            return [f"R23D65_PROFILE_RESOLUTION_CAP_INVALID:{index}"]
    return []


def _host_mapping_failures(value: Any, item: design.Cell) -> list[str]:
    if not isinstance(value, Mapping):
        return ["R23D65_HOST_MAPPING_MISSING"]
    ordered_field = "ordered_bindings" if item.engine_id == "godot_jolt" else "ordered_mappings"
    ordered = value.get(ordered_field)
    invalid = (
        value.get("schema_version") != HOST_MAPPING_SCHEMAS[item.engine_id]
        or value.get("ok") is not True
        or value.get("host_mapping_id") != item.host_mapping_id
        or value.get("profile_id") != design.PROFILE_ID
        or value.get("profile_sha256") != design.PROFILE_SHA256
        or value.get("portable_semantics_id") != design.PROFILE_SEMANTICS_ID
        or value.get("validated_actuator_count") != design.ACTUATOR_COUNT
        or value.get("world_build_count") != 0
        or value.get("solver_step_count") != 0
        or value.get("physics_state_modified") is not False
        or value.get("physical_acceptance_authority") is not False
        or value.get("release_authority") is not False
        or not isinstance(ordered, list)
        or len(ordered) != design.ACTUATOR_COUNT
    )
    if invalid:
        return ["R23D65_HOST_MAPPING_INVALID"]
    for index, (entry, actuator_id, joint_id, cap) in enumerate(
        zip(
            ordered,
            PROFILE_ACTUATOR_IDS,
            PROFILE_JOINT_IDS,
            design.ORDERED_CAPS_NMS,
            strict=True,
        )
    ):
        if not isinstance(entry, Mapping) or (
            entry.get("actuator_id") != actuator_id
            or entry.get("joint_id") != joint_id
        ):
            return [f"R23D65_HOST_MAPPING_ORDER_INVALID:{index}"]
        if item.engine_id == "godot_jolt":
            declared = entry.get("declared_maximum_outer_step_impulse_nms")
            readback = entry.get("godot_maximum_impulse_readback_nms")
            error = entry.get("readback_error_nms")
            if not all(_finite(number) for number in (declared, readback, error)) or (
                float(declared) != float(cap)
                or abs(float(readback) - float(cap))
                > CONFIGURATION_READBACK_TOLERANCE_NMS[item.engine_id]
                or abs(float(error) - abs(float(readback) - float(cap))) > 1.0e-15
            ):
                return [f"R23D65_GODOT_MAPPING_NUMERIC_INVALID:{index}"]
        elif item.engine_id == "rapier_parry":
            portable = entry.get("portable_maximum_outer_step_impulse_nms")
            force = entry.get("rapier_maximum_force_nm_f32")
            reconstructed = entry.get("reconstructed_outer_step_impulse_nms")
            error = entry.get("outer_step_reconstruction_error_nms")
            budget = entry.get("outer_step_reconstruction_budget_nms")
            if not all(
                _finite(number)
                for number in (portable, force, reconstructed, error, budget)
            ) or (
                float(portable) != float(cap)
                or float(force) <= 0.0
                or entry.get("builder_motor_model") != "ForceBased"
                or entry.get("builder_maximum_force_readback_nm_f32") != force
                or entry.get("mutable_maximum_force_readback_nm_f32") != force
                or abs(float(error) - abs(float(reconstructed) - float(cap))) > 1.0e-15
                or float(error) > float(budget)
            ):
                return [f"R23D65_RAPIER_MAPPING_NUMERIC_INVALID:{index}"]
        else:
            portable = entry.get("portable_maximum_outer_step_impulse_nms")
            force_range = entry.get("mujoco_symmetric_force_range_nm")
            reconstructed = entry.get("reconstructed_outer_step_impulse_nms")
            error = entry.get("outer_step_reconstruction_error_nms")
            budget = entry.get("outer_step_reconstruction_budget_nms")
            if not all(
                _finite(number) for number in (portable, reconstructed, error, budget)
            ) or (
                float(portable) != float(cap)
                or not isinstance(force_range, list)
                or len(force_range) != 2
                or not all(_finite(number) for number in force_range)
                or float(force_range[0]) != -float(force_range[1])
                or float(force_range[1]) <= 0.0
                or abs(float(error) - abs(float(reconstructed) - float(cap))) > 1.0e-15
                or float(error) > float(budget)
                or f'name="{actuator_id}"' not in str(entry.get("velocity_actuator_xml", ""))
                or f'joint="{joint_id}"' not in str(entry.get("velocity_actuator_xml", ""))
            ):
                return [f"R23D65_MUJOCO_MAPPING_NUMERIC_INVALID:{index}"]
    return []


def _physical_binding_failures(
    value: Any,
    item: design.Cell,
    host_mapping: Any,
) -> list[str]:
    if not isinstance(value, Mapping):
        return ["R23D65_PHYSICAL_BINDING_MISSING"]
    ordered = value.get("ordered_bindings")
    invalid = (
        value.get("schema_version") != PHYSICAL_BINDING_SCHEMA
        or value.get("ok") is not True
        or value.get("failure_code") != ""
        or value.get("engine_id") != item.engine_id
        or value.get("profile_id") != design.PROFILE_ID
        or value.get("profile_sha256") != design.PROFILE_SHA256
        or value.get("host_mapping_id") != item.host_mapping_id
        or value.get("host_mapping_receipt_sha256") != _json_sha256(host_mapping)
        or value.get("completed_before_first_solver_step") is not True
        or value.get("solver_step_count_at_binding") != 0
        or value.get("validated_actuator_count") != design.ACTUATOR_COUNT
        or value.get("write_count") != design.ACTUATOR_COUNT
        or value.get("readback_count") != design.ACTUATOR_COUNT
        or value.get("all_readbacks_match") is not True
        or not isinstance(ordered, list)
        or len(ordered) != design.ACTUATOR_COUNT
    )
    if invalid:
        return ["R23D65_PHYSICAL_BINDING_INVALID"]
    tolerance = CONFIGURATION_READBACK_TOLERANCE_NMS[item.engine_id]
    for index, (entry, profile_id, trace_id, joint_id, cap) in enumerate(
        zip(
            ordered,
            PROFILE_ACTUATOR_IDS,
            TRACE_ACTUATOR_IDS,
            PROFILE_JOINT_IDS,
            design.ORDERED_CAPS_NMS,
            strict=True,
        )
    ):
        if not isinstance(entry, Mapping):
            return [f"R23D65_PHYSICAL_BINDING_ENTRY_INVALID:{index}"]
        declared = entry.get("declared_maximum_outer_step_impulse_nms")
        readback = entry.get("host_readback_outer_step_impulse_nms")
        error = entry.get("readback_error_nms")
        if not all(_finite(number) for number in (declared, readback, error)) or (
            entry.get("profile_actuator_id") != profile_id
            or entry.get("trace_actuator_id") != trace_id
            or entry.get("joint_id") != joint_id
            or float(declared) != float(cap)
            or abs(float(readback) - float(cap)) > tolerance
            or abs(float(error) - abs(float(readback) - float(cap))) > 1.0e-15
            or entry.get("readback_matches") is not True
        ):
            return [f"R23D65_PHYSICAL_BINDING_IDENTITY_INVALID:{index}"]
    return []


def _public_profile_projection_failures(
    entry: Mapping[str, Any],
    rows: Sequence[Mapping[str, Any]],
    item: design.Cell,
) -> list[str]:
    resolution = entry.get("actuator_cap_profile_resolution_receipt")
    host_mapping = entry.get("actuator_cap_profile_host_mapping_receipt")
    physical_binding = entry.get("actuator_cap_profile_physical_binding_receipt")
    failures = _resolution_failures(resolution)
    failures.extend(_host_mapping_failures(host_mapping, item))
    failures.extend(_physical_binding_failures(physical_binding, item, host_mapping))
    failures.extend(_trace_profile_cap_failures(rows, item))
    return failures


def _cas_binding_failures(
    entry: Mapping[str, Any],
    *,
    authority_repo_root: Path | None = None,
) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, Mapping) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D65_TRACE_ARTIFACT_RECEIPT"]
    item = _cell_by_id(str(entry.get("cell_id", "")))
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
        or artifact.get("trace_transport_id") != TRACE_TRANSPORT_ID
        or artifact.get("trace_transport_engine_id") != item.engine_id
        or artifact.get("canonical_ndjson") is not True
        or artifact.get("full_precision") is not True
    ):
        return ["R23D65_TRACE_ARTIFACT_IDENTITY"]
    authority_root = REPO_ROOT if authority_repo_root is None else authority_repo_root.resolve()
    directory = (
        authority_root.parent
        / "SporeSpore_Evidence"
        / "artifacts"
        / "sha256"
        / digest_hex
    ).resolve()
    payload = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    try:
        recorded_payload = Path(str(artifact.get("payload_path", ""))).resolve(strict=True)
        recorded_manifest = Path(str(artifact.get("manifest_path", ""))).resolve(strict=True)
    except OSError:
        return ["R23D65_TRACE_ARTIFACT_CAS_PATH"]
    if recorded_payload != payload or recorded_manifest != manifest_path:
        return ["R23D65_TRACE_ARTIFACT_CAS_PATH"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D65_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
    if (
        "sha256:" + hashlib.sha256(raw).hexdigest() != digest
        or len(raw) != artifact.get("byte_length")
        or manifest.get("schema_version")
        != "sporespore_content_addressed_artifact_manifest_v1"
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != digest
        or manifest.get("byte_length") != len(raw)
        or manifest.get("payload_name") != "payload.bin"
        or manifest.get("media_type") != "application/x-ndjson"
    ):
        return ["R23D65_TRACE_ARTIFACT_BYTES"]
    return []


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    _bind_accepted_core()
    value = accepted.retain_trace(**kwargs)
    item = _cell_by_id(str(value["cell_id"]))
    value.update(
        schema_version=TRACE_RETENTION_SCHEMA,
        campaign_seed=item.campaign_seed,
        profile_id=item.profile_id,
        engine_id=item.engine_id,
        host_mapping_id=item.host_mapping_id,
    )
    return value


def _entry_identity_failures(entry: Any, item: design.Cell) -> list[str]:
    if not isinstance(entry, Mapping):
        return ["R23D65_ENTRY_TYPE"]
    expected = {
        "campaign_seed": item.campaign_seed,
        "profile_id": item.profile_id,
        "host_mapping_id": item.host_mapping_id,
        "arm_id": item.arm_id,
        "turn_heading_offset_rad": item.turn_heading_offset_rad,
    }
    return [
        f"R23D65_ENTRY_{field.upper()}_IDENTITY"
        for field, value in expected.items()
        if entry.get(field) != value
    ]


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    _bind_accepted_core()
    evaluation, rows = accepted.evaluate_entry(
        entry,
        item,
        expected_source_commit=expected_source_commit,
        authority_repo_root=authority_repo_root,
    )
    failures = _entry_identity_failures(entry, item)
    trace_summary = validate_trace(item.cell_id, rows) if rows else None
    if rows and trace_summary is not None and trace_summary.get("ok") is not True:
        failures.extend(trace_summary.get("failure_codes", []))
    if failures:
        evaluation["execution_valid"] = False
        evaluation["common_physical_gate_passed"] = False
        evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + failures
    evaluation.update(
        campaign_seed=item.campaign_seed,
        profile_id=item.profile_id,
        host_mapping_id=item.host_mapping_id,
        arm_id=item.arm_id,
        turn_heading_offset_rad=item.turn_heading_offset_rad,
    )
    return evaluation, rows


def _validate_complete_order(entries: Sequence[Any]) -> None:
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, Mapping)
        or entry.get("cell_id") != item.cell_id
        or entry.get("engine_id") != item.engine_id
        or entry.get("campaign_seed") != item.campaign_seed
        or entry.get("profile_id") != item.profile_id
        or entry.get("host_mapping_id") != item.host_mapping_id
        or entry.get("arm_id") != item.arm_id
        or entry.get("turn_heading_offset_rad") != item.turn_heading_offset_rad
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D65EvaluationError("R23D65_COMPLETE_ENTRY_ORDER_INVALID")


def _turning_projection(
    evaluations: Sequence[Mapping[str, Any]],
    rows_by_cell: Mapping[str, Sequence[Mapping[str, Any]]],
) -> dict[str, Any]:
    expected = design.cells()
    _require(len(evaluations) == len(expected), "R23D65_DECISION_EVALUATION_COUNT")
    for evaluation, item in zip(evaluations, expected, strict=True):
        _require(
            evaluation.get("cell_id") == item.cell_id
            and evaluation.get("engine_id") == item.engine_id
            and evaluation.get("campaign_seed") == item.campaign_seed
            and evaluation.get("profile_id") == item.profile_id
            and evaluation.get("host_mapping_id") == item.host_mapping_id
            and evaluation.get("arm_id") == item.arm_id,
            "R23D65_DECISION_EVALUATION_IDENTITY",
        )
    engine_results: dict[str, Any] = {}
    for engine_id in design.ENGINES:
        items = [item for item in expected if item.engine_id == engine_id]
        engine_evaluations = [
            value for value in evaluations if value.get("engine_id") == engine_id
        ]
        execution_valid = len(engine_evaluations) == 3 and all(
            value.get("execution_valid") is True for value in engine_evaluations
        )
        common_gates = len(engine_evaluations) == 3 and all(
            value.get("common_physical_gate_passed") is True
            for value in engine_evaluations
        )
        cycle: dict[str, Any] | None = None
        if execution_valid:
            cycle = measurement.measure_cycle_integrated_response(
                {
                    item.arm_id: accepted.inherited._measurement_rows(
                        rows_by_cell[item.cell_id]
                    )
                    for item in items
                }
            )
        engine_results[engine_id] = {
            "all_three_cells_execution_valid": execution_valid,
            "all_common_physical_gates_passed": common_gates,
            "cycle_integrated_measurement": cycle,
            "measurement_failure_codes": (
                []
                if cycle is None
                else [key for key, passed in cycle["gates"].items() if passed is not True]
            ),
            "passed": bool(
                execution_valid
                and common_gates
                and cycle is not None
                and cycle.get("passed") is True
            ),
        }
    matrix_execution_valid = all(
        result["all_three_cells_execution_valid"] for result in engine_results.values()
    )
    positive = matrix_execution_valid and all(
        result["passed"] for result in engine_results.values()
    )
    return {
        "matrix_execution_valid": matrix_execution_valid,
        "all_nine_common_physical_gates_passed": all(
            result["all_common_physical_gates_passed"]
            for result in engine_results.values()
        ),
        "engine_results": engine_results,
        "finite_three_engine_turning_positive": positive,
        "strict_nine_cell_conjunction_used": True,
        "minimum_raw_signed_cycle_shift_rad": 0.01,
        "minimum_reference_conditioned_cycle_shift_rad": 0.01,
        "pass_rate_estimated": False,
        "superiority_test_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
    }


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    load_declaration()
    _bind_accepted_core()
    _require(_source_commit(expected_source_commit), "R23D65_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    _require((authority_root / ".git").exists(), "R23D65_AUTHORITY_REPO_ROOT_INVALID")
    _validate_complete_order(entries)
    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, design.cells(), strict=True):
        evaluation, rows = evaluate_entry(
            entry,
            item,
            expected_source_commit=expected_source_commit,
            authority_repo_root=authority_root,
        )
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows
    projection = _turning_projection(evaluations, rows_by_cell)
    if not projection["matrix_execution_valid"]:
        classification = (
            "invalid_or_incomplete_exact_matched_three_engine_portable_turning_validation"
        )
    elif projection["finite_three_engine_turning_positive"]:
        classification = (
            "valid_complete_positive_exact_matched_three_engine_portable_turning_validation"
        )
    else:
        classification = (
            "valid_complete_negative_exact_matched_three_engine_portable_turning_validation"
        )
    positive = bool(projection["finite_three_engine_turning_positive"])
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims.update(
        r23d65_finite_three_engine_turning=positive,
        godot_jolt_turning_extended_to_seed_23175=positive,
        fresh_rapier_turning_replication=positive,
        fresh_mujoco_turning_replication=positive,
        finite_three_engine_turning=positive,
        portable_basic_turning=positive,
        q_sdk_r23_satisfied=positive,
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": design.raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "finite_decision": projection,
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_held_out_seed_count": 1,
        "fresh_held_out_seed_consumed": True,
        "selected_public_profile_id": design.PROFILE_ID,
        "turning_gate_invoked": True,
        "posthoc_threshold_or_selector_change_performed": False,
        "cross_engine_equivalence_test_invoked": False,
        "population_inference_attempted": False,
        "physical_acceptance_authority": False,
        "claims": claims,
    }


def _synthetic_resolution_receipt() -> dict[str, Any]:
    publication = json.loads(
        (ROOT / "r23d61_selected_actuator_profile_publication_v1.json").read_text(
            encoding="utf-8"
        )
    )["publication"]
    ordered_caps = copy.deepcopy(publication["ordered_caps"])
    return {
        "schema_version": "sporespore_actuator_cap_profile_receipt_v1",
        "requested_profile_id": design.PROFILE_ID,
        "supported_profile_ids": [design.PROFILE_ID],
        "support_status": "supported_exact",
        "refusal_reason": None,
        "descriptor_sha256": design.DESCRIPTOR_SHA256,
        "morphology_spec_sha256": design.MORPHOLOGY_SPEC_SHA256,
        "profile": {
            "schema_version": "sporespore_actuator_cap_profile_v1",
            "profile_id": design.PROFILE_ID,
            "supported_morphology_id": design.MORPHOLOGY_ID,
            "supported_descriptor_sha256": design.DESCRIPTOR_SHA256,
            "supported_morphology_spec_sha256": design.MORPHOLOGY_SPEC_SHA256,
            "semantics": {"semantics_id": design.PROFILE_SEMANTICS_ID},
            "ordered_caps": ordered_caps,
        },
        "profile_sha256": design.PROFILE_SHA256,
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _synthetic_host_mapping(item: design.Cell) -> dict[str, Any]:
    ordered: list[dict[str, Any]] = []
    for actuator_id, joint_id, cap in zip(
        PROFILE_ACTUATOR_IDS,
        PROFILE_JOINT_IDS,
        design.ORDERED_CAPS_NMS,
        strict=True,
    ):
        if item.engine_id == "godot_jolt":
            ordered.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": joint_id,
                    "declared_maximum_outer_step_impulse_nms": cap,
                    "godot_maximum_impulse_readback_nms": cap,
                    "readback_error_nms": 0.0,
                }
            )
        elif item.engine_id == "rapier_parry":
            force = cap * 120.0
            ordered.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": joint_id,
                    "portable_maximum_outer_step_impulse_nms": cap,
                    "rapier_maximum_force_nm_f32": force,
                    "reconstructed_outer_step_impulse_nms": cap,
                    "outer_step_reconstruction_error_nms": 0.0,
                    "outer_step_reconstruction_budget_nms": 1.0e-12,
                    "builder_motor_model": "ForceBased",
                    "builder_maximum_force_readback_nm_f32": force,
                    "mutable_maximum_force_readback_nm_f32": force,
                }
            )
        else:
            force = cap * 120.0
            ordered.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": joint_id,
                    "portable_maximum_outer_step_impulse_nms": cap,
                    "mujoco_symmetric_force_range_nm": [-force, force],
                    "reconstructed_outer_step_impulse_nms": cap,
                    "outer_step_reconstruction_error_nms": 0.0,
                    "outer_step_reconstruction_budget_nms": 1.0e-15,
                    "velocity_actuator_xml": (
                        f'<velocity name="{actuator_id}" joint="{joint_id}" '
                        f'forcelimited="true" forcerange="-{force} {force}"/>'
                    ),
                }
            )
    return {
        "schema_version": HOST_MAPPING_SCHEMAS[item.engine_id],
        "ok": True,
        "host_mapping_id": item.host_mapping_id,
        "profile_id": design.PROFILE_ID,
        "profile_sha256": design.PROFILE_SHA256,
        "portable_semantics_id": design.PROFILE_SEMANTICS_ID,
        "validated_actuator_count": design.ACTUATOR_COUNT,
        "ordered_bindings" if item.engine_id == "godot_jolt" else "ordered_mappings": ordered,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _synthetic_physical_binding(
    item: design.Cell,
    host_mapping: Mapping[str, Any],
) -> dict[str, Any]:
    ordered = [
        {
            "profile_actuator_id": profile_id,
            "trace_actuator_id": trace_id,
            "joint_id": joint_id,
            "declared_maximum_outer_step_impulse_nms": cap,
            "host_readback_outer_step_impulse_nms": cap,
            "readback_error_nms": 0.0,
            "readback_matches": True,
        }
        for profile_id, trace_id, joint_id, cap in zip(
            PROFILE_ACTUATOR_IDS,
            TRACE_ACTUATOR_IDS,
            PROFILE_JOINT_IDS,
            design.ORDERED_CAPS_NMS,
            strict=True,
        )
    ]
    return {
        "schema_version": PHYSICAL_BINDING_SCHEMA,
        "ok": True,
        "failure_code": "",
        "engine_id": item.engine_id,
        "profile_id": design.PROFILE_ID,
        "profile_sha256": design.PROFILE_SHA256,
        "host_mapping_id": item.host_mapping_id,
        "host_mapping_receipt_sha256": _json_sha256(host_mapping),
        "completed_before_first_solver_step": True,
        "solver_step_count_at_binding": 0,
        "validated_actuator_count": design.ACTUATOR_COUNT,
        "write_count": design.ACTUATOR_COUNT,
        "readback_count": design.ACTUATOR_COUNT,
        "all_readbacks_match": True,
        "ordered_bindings": ordered,
    }


def _synthetic_rows(item: design.Cell) -> list[dict[str, Any]]:
    _bind_accepted_core()
    rows = accepted._synthetic_rows(item)
    for row in rows:
        observation = row["actuator_phase_observation"]
        applications = observation["ordered_applications"]
        application_by_identity: dict[tuple[str, int], dict[str, Any]] = {}
        for application in applications:
            identity = (
                str(application.get("limb_id", "")),
                int(application.get("limb_joint_index", -1)),
            )
            _require(
                identity not in application_by_identity,
                "R23D65_SYNTHETIC_APPLICATION_IDENTITY_DUPLICATE",
            )
            application_by_identity[identity] = application
        corrected: list[dict[str, Any]] = []
        for index, (actuator_id, joint_id, cap) in enumerate(
            zip(
                PROFILE_ACTUATOR_IDS,
                PROFILE_JOINT_IDS,
                design.ORDERED_CAPS_NMS,
                strict=True,
            )
        ):
            limb_id = r60_design.LIMB_IDS[index // 2]
            joint_index = index % 2
            identity = (limb_id, joint_index)
            _require(
                identity in application_by_identity,
                f"R23D65_SYNTHETIC_APPLICATION_IDENTITY_MISSING:{index}",
            )
            application = copy.deepcopy(application_by_identity[identity])
            application.update(
                actuator_id=actuator_id,
                joint_id=joint_id,
                host_joint_id=(
                    f"{limb_id}.{'hip_pitch' if joint_index == 0 else 'knee_pitch'}"
                ),
                declared_maximum_impulse_nms=cap,
                motor_maximum_impulse_readback_nms=cap,
                motor_maximum_impulse_readback_error_nms=0.0,
                maximum_impulse_readback_matches=True,
            )
            corrected.append(application)
        observation["ordered_actuator_ids"] = list(PROFILE_ACTUATOR_IDS)
        observation["ordered_applications"] = corrected
    return rows


def _synthetic_projection(item: design.Cell) -> dict[str, Any]:
    host_mapping = _synthetic_host_mapping(item)
    return {
        "actuator_cap_profile_resolution_receipt": _synthetic_resolution_receipt(),
        "actuator_cap_profile_host_mapping_receipt": host_mapping,
        "actuator_cap_profile_physical_binding_receipt": (
            _synthetic_physical_binding(item, host_mapping)
        ),
    }


def _projection_mutation(value: dict[str, Any], mutation_id: str, item: design.Cell) -> None:
    if mutation_id == "missing_resolution":
        value.pop("actuator_cap_profile_resolution_receipt")
    elif mutation_id == "support_status":
        value["actuator_cap_profile_resolution_receipt"]["support_status"] = "out_of_domain_morphology"
    elif mutation_id == "descriptor":
        value["actuator_cap_profile_resolution_receipt"]["descriptor_sha256"] = "sha256:" + "0" * 64
    elif mutation_id == "profile_hash":
        value["actuator_cap_profile_resolution_receipt"]["profile_sha256"] = "sha256:" + "0" * 64
    elif mutation_id == "profile_cap_order":
        caps = value["actuator_cap_profile_resolution_receipt"]["profile"]["ordered_caps"]
        caps[0], caps[1] = caps[1], caps[0]
    elif mutation_id == "missing_host_mapping":
        value.pop("actuator_cap_profile_host_mapping_receipt")
    elif mutation_id == "host_schema":
        value["actuator_cap_profile_host_mapping_receipt"]["schema_version"] += "_mutated"
    elif mutation_id == "host_mapping_id":
        value["actuator_cap_profile_host_mapping_receipt"]["host_mapping_id"] = "wrong"
    elif mutation_id == "host_cap":
        host = value["actuator_cap_profile_host_mapping_receipt"]
        field = "ordered_bindings" if item.engine_id == "godot_jolt" else "ordered_mappings"
        cap_field = (
            "declared_maximum_outer_step_impulse_nms"
            if item.engine_id == "godot_jolt"
            else "portable_maximum_outer_step_impulse_nms"
        )
        host[field][0][cap_field] = 0.5
    elif mutation_id == "missing_physical_binding":
        value.pop("actuator_cap_profile_physical_binding_receipt")
    elif mutation_id == "physical_engine":
        value["actuator_cap_profile_physical_binding_receipt"]["engine_id"] = "wrong"
    elif mutation_id == "physical_mapping_id":
        value["actuator_cap_profile_physical_binding_receipt"]["host_mapping_id"] = "wrong"
    elif mutation_id == "physical_mapping_digest":
        value["actuator_cap_profile_physical_binding_receipt"]["host_mapping_receipt_sha256"] = "sha256:" + "0" * 64
    elif mutation_id == "physical_before_solver":
        value["actuator_cap_profile_physical_binding_receipt"]["completed_before_first_solver_step"] = False
    elif mutation_id == "physical_trace_id":
        value["actuator_cap_profile_physical_binding_receipt"]["ordered_bindings"][0]["trace_actuator_id"] = "wrong"
    elif mutation_id == "physical_cap":
        value["actuator_cap_profile_physical_binding_receipt"]["ordered_bindings"][0]["declared_maximum_outer_step_impulse_nms"] = 0.5
    else:
        raise AssertionError(f"unknown projection mutation: {mutation_id}")


def _synthetic_evaluations(
    *,
    matrix_valid: bool = True,
    common_gates_passed: bool = True,
) -> list[dict[str, Any]]:
    values = [
        {
            "cell_id": item.cell_id,
            "engine_id": item.engine_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "host_mapping_id": item.host_mapping_id,
            "arm_id": item.arm_id,
            "execution_valid": matrix_valid,
            "common_physical_gate_passed": matrix_valid and common_gates_passed,
        }
        for item in design.cells()
    ]
    if not matrix_valid:
        values[0]["execution_valid"] = False
        values[0]["common_physical_gate_passed"] = False
    return values


def _measurement_rows_by_cell(
    traces: Mapping[str, Sequence[Mapping[str, Any]]],
) -> dict[str, list[dict[str, Any]]]:
    return {
        item.cell_id: [dict(row) for row in traces[item.cell_id]]
        for item in design.cells()
    }


def run_failure_terminal_transport_canary() -> dict[str, Any]:
    """Exercise the complete evaluator with every engine/cell failure shape."""

    load_declaration()
    items = design.cells()
    source_commit = "1" * 40
    entries = [
        {
            "schema_version": FAILURE_SCHEMA,
            "campaign_id": design.CAMPAIGN_ID,
            "gate_id": design.GATE_ID,
            "stage_id": item.stage_id,
            "cell_id": item.cell_id,
            "engine_id": item.engine_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "host_mapping_id": item.host_mapping_id,
            "arm_id": item.arm_id,
            "turn_heading_offset_rad": item.turn_heading_offset_rad,
            "source_commit": source_commit,
            "failure_stage": "synthetic_zero_world_transport_canary",
            "failure_code": f"R23D65_SYNTHETIC_{item.engine_id.upper()}_FAILURE",
            "model_construction_count": (0 if item.engine_id == "mujoco" else 1),
            "world_attempt_count": (0 if item.engine_id == "mujoco" else 1),
            "world_build_count": (0 if item.engine_id == "mujoco" else 1),
            "physical_acceptance_authority": False,
        }
        for item in items
    ]
    evaluation = evaluate_complete_entries(
        entries,
        expected_source_commit=source_commit,
        authority_repo_root=REPO_ROOT,
    )
    cell_evaluations = evaluation.get("cell_evaluations", [])
    _require(
        evaluation.get("classification")
        == "invalid_or_incomplete_exact_matched_three_engine_portable_turning_validation"
        and len(cell_evaluations) == 9
        and all(
            observed.get("entry_kind") == "worker_failure"
            and observed.get("execution_valid") is False
            and observed.get("world_attempt_count")
            == source["world_attempt_count"]
            and observed.get("world_build_count") == source["world_build_count"]
            for observed, source in zip(cell_evaluations, entries, strict=True)
        ),
        "R23D65_COMPLETE_FAILURE_TERMINAL_CANARY_INVALID",
    )
    identity_rejections = 0
    for engine_id in design.ENGINES:
        candidate = copy.deepcopy(entries)
        target = next(
            index
            for index, item in enumerate(items)
            if item.engine_id == engine_id and item.arm_id == "reference_zero"
        )
        candidate[target].pop("host_mapping_id")
        try:
            evaluate_complete_entries(
                candidate,
                expected_source_commit=source_commit,
                authority_repo_root=REPO_ROOT,
            )
        except R23D65EvaluationError:
            identity_rejections += 1
    _require(
        identity_rejections == len(design.ENGINES),
        "R23D65_FAILURE_TERMINAL_IDENTITY_MUTATION_ACCEPTED",
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r23d65_failure_terminal_transport_canary_v1"
        ),
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": "equivalence_non_inferiority",
        "population": "complete_three_engine_nine_cell_worker_failure_terminal_population",
        "declared_engine_count": len(design.ENGINES),
        "conforming_engine_count": len(design.ENGINES),
        "declared_cell_count": len(entries),
        "conforming_cell_count": len(cell_evaluations),
        "identity_mutation_rejection_count": identity_rejections,
        "world_count_preservation_canary_count": len(cell_evaluations),
        "equivalence_margin": 0,
        "non_inferiority_margin": 0,
        "sampling_used": False,
        "classification": evaluation["classification"],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_equivalence_claimed": False,
        "physical_acceptance_authority": False,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    _bind_accepted_core()
    items = design.cells()
    traces = {item.cell_id: _synthetic_rows(item) for item in items}
    validations = [validate_trace(item.cell_id, traces[item.cell_id]) for item in items]
    _require(all(value["ok"] for value in validations), "R23D65_TRACE_POSITIVE_CANARY")

    base_mutations = (
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
    observation_mutations = (
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
    base_rejections = 0
    observation_rejections = 0
    for engine_id in design.ENGINES:
        item = next(
            value
            for value in items
            if value.engine_id == engine_id and value.arm_id == "reference_zero"
        )
        for mutation_id in base_mutations:
            candidate = copy.deepcopy(traces[item.cell_id])
            accepted._base_mutation(candidate, mutation_id)
            try:
                rejected = not validate_trace(item.cell_id, candidate)["ok"]
            except (RuntimeError, ValueError):
                rejected = True
            base_rejections += int(rejected)
        for mutation_id in observation_mutations:
            candidate = copy.deepcopy(traces[item.cell_id])
            accepted._observation_mutation(candidate, mutation_id)
            try:
                rejected = not validate_trace(item.cell_id, candidate)["ok"]
            except (RuntimeError, ValueError):
                rejected = True
            observation_rejections += int(rejected)
    _require(base_rejections == 30, "R23D65_TASK_ORIGIN_MUTATION_ACCEPTED")
    _require(observation_rejections == 60, "R23D65_OBSERVATION_MUTATION_ACCEPTED")

    projection_mutations = (
        "missing_resolution",
        "support_status",
        "descriptor",
        "profile_hash",
        "profile_cap_order",
        "missing_host_mapping",
        "host_schema",
        "host_mapping_id",
        "host_cap",
        "missing_physical_binding",
        "physical_engine",
        "physical_mapping_id",
        "physical_mapping_digest",
        "physical_before_solver",
        "physical_trace_id",
        "physical_cap",
    )
    profile_positive = 0
    projection_rejections = 0
    trace_cap_rejections = 0
    for engine_id in design.ENGINES:
        item = next(
            value
            for value in items
            if value.engine_id == engine_id and value.arm_id == "reference_zero"
        )
        projection = _synthetic_projection(item)
        profile_positive += int(
            not _public_profile_projection_failures(
                projection,
                traces[item.cell_id],
                item,
            )
        )
        for mutation_id in projection_mutations:
            candidate = copy.deepcopy(projection)
            _projection_mutation(candidate, mutation_id, item)
            projection_rejections += int(
                bool(
                    _public_profile_projection_failures(
                        candidate,
                        traces[item.cell_id],
                        item,
                    )
                )
            )
        cap_rows = copy.deepcopy(traces[item.cell_id])
        cap_rows[0]["actuator_phase_observation"]["ordered_applications"][0][
            "declared_maximum_impulse_nms"
        ] = 0.5
        trace_cap_rejections += int(
            bool(_trace_profile_cap_failures(cap_rows, item))
        )
    _require(profile_positive == 3, "R23D65_PROFILE_PROJECTION_POSITIVE_CANARY")
    _require(projection_rejections == 48, "R23D65_PROFILE_PROJECTION_MUTATION_ACCEPTED")
    _require(trace_cap_rejections == 3, "R23D65_TRACE_CAP_MUTATION_ACCEPTED")

    rows_by_cell = _measurement_rows_by_cell(traces)
    passing = _turning_projection(_synthetic_evaluations(), rows_by_cell)
    _require(
        passing["finite_three_engine_turning_positive"] is True,
        "R23D65_TURNING_POSITIVE_CANARY",
    )
    decision_rejections = 0
    common_failure = _synthetic_evaluations()
    common_failure[0]["common_physical_gate_passed"] = False
    decision_rejections += int(
        not _turning_projection(common_failure, rows_by_cell)[
            "finite_three_engine_turning_positive"
        ]
    )
    decision_rejections += int(
        not _turning_projection(
            _synthetic_evaluations(matrix_valid=False), rows_by_cell
        )["finite_three_engine_turning_positive"]
    )
    for engine_id in design.ENGINES:
        reversed_rows = _measurement_rows_by_cell(traces)
        positive = next(
            item.cell_id
            for item in items
            if item.engine_id == engine_id and item.arm_id == "positive_heading"
        )
        negative = next(
            item.cell_id
            for item in items
            if item.engine_id == engine_id and item.arm_id == "negative_heading"
        )
        reversed_rows[positive], reversed_rows[negative] = (
            reversed_rows[negative],
            reversed_rows[positive],
        )
        decision_rejections += int(
            not _turning_projection(_synthetic_evaluations(), reversed_rows)[
                "finite_three_engine_turning_positive"
            ]
        )
        zero_rows = _measurement_rows_by_cell(traces)
        for item in items:
            if item.engine_id == engine_id:
                for row in zero_rows[item.cell_id]:
                    row["measured_yaw_rad"] = 0.0
        decision_rejections += int(
            not _turning_projection(_synthetic_evaluations(), zero_rows)[
                "finite_three_engine_turning_positive"
            ]
        )
    _require(decision_rejections == 8, "R23D65_TURNING_DECISION_MUTATION_ACCEPTED")

    entries = [
        {
            "cell_id": item.cell_id,
            "engine_id": item.engine_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "host_mapping_id": item.host_mapping_id,
            "arm_id": item.arm_id,
            "turn_heading_offset_rad": item.turn_heading_offset_rad,
        }
        for item in items
    ]
    _validate_complete_order(entries)
    order_mutations: list[list[dict[str, Any]]] = []
    omitted = copy.deepcopy(entries)
    omitted.pop()
    order_mutations.append(omitted)
    swapped = copy.deepcopy(entries)
    swapped[0], swapped[1] = swapped[1], swapped[0]
    order_mutations.append(swapped)
    duplicate = copy.deepcopy(entries)
    duplicate[-1] = copy.deepcopy(duplicate[0])
    order_mutations.append(duplicate)
    for field, value in (
        ("engine_id", "wrong"),
        ("campaign_seed", 21516),
        ("profile_id", "wrong"),
        ("host_mapping_id", "wrong"),
        ("arm_id", "positive_heading"),
        ("turn_heading_offset_rad", 0.2),
    ):
        candidate = copy.deepcopy(entries)
        candidate[0][field] = value
        order_mutations.append(candidate)
    order_rejections = 0
    for candidate in order_mutations:
        try:
            _validate_complete_order(candidate)
        except R23D65EvaluationError:
            order_rejections += 1
    _require(order_rejections == 9, "R23D65_COMPLETE_ORDER_MUTATION_ACCEPTED")

    failure_canary = run_failure_terminal_transport_canary()

    return {
        "schema_version": "sporespore_qsdk_r23d65_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "declared_cell_count": len(items),
        "engine_count": len(design.ENGINES),
        "valid_trace_canary_count": len(validations),
        "task_origin_and_schedule_mutation_rejection_count": base_rejections,
        "actuator_observation_mutation_rejection_count": observation_rejections,
        "public_profile_projection_positive_control_count": profile_positive,
        "public_profile_projection_mutation_rejection_count": projection_rejections,
        "per_engine_trace_cap_mutation_rejection_count": trace_cap_rejections,
        "cycle_integrated_positive_control_count": 1,
        "turning_decision_mutation_rejection_count": decision_rejections,
        "complete_matrix_order_mutation_rejection_count": order_rejections,
        "complete_failure_terminal_engine_canary_count": failure_canary[
            "conforming_engine_count"
        ],
        "complete_failure_terminal_cell_canary_count": failure_canary[
            "conforming_cell_count"
        ],
        "complete_failure_terminal_identity_mutation_rejection_count": (
            failure_canary["identity_mutation_rejection_count"]
        ),
        "failure_terminal_world_count_preservation_canary_count": (
            failure_canary["world_count_preservation_canary_count"]
        ),
        "public_trace_actuator_ids": list(PROFILE_ACTUATOR_IDS),
        "placeholder_trace_actuator_identity_permitted": False,
        "canonical_evaluator_implementation_id": (
            "sporespore_qsdk_r23d65_retained_evidence_evaluator_v1"
        ),
        "observation_row_count_per_trace": design.CONTROLLER_STEPS,
        "observation_application_count_per_trace": (
            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        ),
        "turning_gate_invoked": True,
        "minimum_raw_signed_cycle_shift_rad": 0.01,
        "minimum_reference_conditioned_cycle_shift_rad": 0.01,
        "superiority_test_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def audit_genuine_godot_trace_shape(
    trace_path: Path,
    expected_sha256: str,
) -> dict[str, Any]:
    """Cold-check the canonical native actuator surface without reusing a result."""

    load_declaration()
    raw = trace_path.read_bytes()
    actual_sha256 = "sha256:" + hashlib.sha256(raw).hexdigest()
    _require(
        expected_sha256 == COLD_GODOT_TRACE_SHA256
        and actual_sha256 == COLD_GODOT_TRACE_SHA256,
        "R23D65_COLD_GODOT_TRACE_DIGEST_INVALID",
    )
    rows = [json.loads(line) for line in raw.splitlines()]
    _require(
        len(rows) == COLD_GODOT_TRACE_ROW_COUNT,
        "R23D65_COLD_GODOT_TRACE_ROW_COUNT_INVALID",
    )
    item = design.cell("godot_jolt", "reference_zero")
    public_failures = _trace_profile_cap_failures(rows, item)
    placeholder_failures = _trace_profile_cap_failures(
        rows,
        item,
        expected_actuator_ids=PLACEHOLDER_TRACE_ACTUATOR_IDS,
    )
    first_observation: Mapping[str, Any] = rows[0]["actuator_phase_observation"]
    _require(
        public_failures == []
        and placeholder_failures == ["R23D65_TRACE_CAP_ORDER_INVALID:0"]
        and tuple(first_observation.get("ordered_actuator_ids", []))
        == PROFILE_ACTUATOR_IDS,
        "R23D65_COLD_GODOT_TRACE_IDENTITY_PROJECTION_INVALID",
    )
    return {
        "schema_version": COLD_BASELINE_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "trace_raw_sha256": actual_sha256,
        "trace_row_count": len(rows),
        "ordered_actuator_ids": list(PROFILE_ACTUATOR_IDS),
        "public_identity_projection_failure_codes": public_failures,
        "placeholder_identity_negative_control_failure_codes": (
            placeholder_failures
        ),
        "historical_result_reinterpreted": False,
        "historical_world_reused_as_r23d65_cell": False,
        "input_shape_compatibility_only": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _manifest_paths(value: Any) -> list[str]:
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise R23D65EvaluationError("R23D65_TERMINAL_MANIFEST_INVALID")
    return list(value)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    commands.add_parser("failure-terminal-canary")
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
    evaluate.add_argument("--authority-repo-root", type=Path, required=True)
    cold = commands.add_parser("cold-godot-trace")
    cold.add_argument("--trace", type=Path, required=True)
    cold.add_argument("--expected-sha256", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if arguments.command == "preflight":
            value = run_zero_world_preflight()
            print("QSDK_R23D65_EVALUATOR_PREFLIGHT " + json.dumps(value, sort_keys=True))
        elif arguments.command == "failure-terminal-canary":
            value = run_failure_terminal_transport_canary()
            print(
                "QSDK_R23D65_FAILURE_TERMINAL_CANARY "
                + json.dumps(value, sort_keys=True)
            )
        elif arguments.command == "retain-trace":
            value = retain_trace(
                stage_id=arguments.stage_id,
                cell_id=arguments.cell_id,
                rows_json_path=arguments.rows_json,
                repo_root=arguments.repo_root,
                attempt_root=arguments.attempt_root,
                powershell=arguments.powershell,
                test_only=arguments.test_only,
                evidence_root_override=arguments.evidence_root_override,
            )
            print("QSDK_R23D65_TRACE_RETAINED " + json.dumps(value, sort_keys=True))
        elif arguments.command == "evaluate-complete":
            manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8"))
                for path in _manifest_paths(manifest)
            ]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=arguments.expected_source_commit,
                authority_repo_root=arguments.authority_repo_root,
            )
            print("QSDK_R23D65_COMPLETE_EVALUATION " + json.dumps(value, sort_keys=True))
        else:
            value = audit_genuine_godot_trace_shape(
                arguments.trace,
                arguments.expected_sha256,
            )
            print(
                "QSDK_R23D65_EVALUATOR_COLD_GODOT_TRACE "
                + json.dumps(value, sort_keys=True)
            )
    except (
        R23D65EvaluationError,
        accepted.R23D58EvaluationError,
        accepted.inherited.R23D34EvaluationError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D65_EVALUATOR_FAILURE {type(error).__name__}:{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
