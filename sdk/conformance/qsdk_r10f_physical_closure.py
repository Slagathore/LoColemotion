#!/usr/bin/env python3
"""Audit and close the single QSDK-R10F-L14 process-isolated physical identity."""

from __future__ import annotations

import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
from typing import Any, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[2]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
import qsdk_r10f_l14_authority_contract as l14_authority
import qsdk_r10f_l14_qualification_components as l14_components
import qsdk_r10f_l14_runtime_binding as l14_runtime
import qsdk_r10f_l14_terminal_consumers as l14_terminal
import qsdk_r10f_l14_walking_failure_retention as l14_walking_failure
import qsdk_r10f_l14_no_resume_terminal as l14_no_resume
import qsdk_r10f_l15_launch_relationship as l15_launch
import qsdk_r10f_l15_collection_retention as l15_collection
import qsdk_r10f_l15_collection_context as l15_context

EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
REPAIR_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10f_l14_terminal_boundary_successor_design_v1.json"
)
BRANCH_COMPLETENESS_ADDENDUM_PATH = l14_authority.addendum_audit.PATH
EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256 = l14_authority.addendum_audit.SHA256
PREDECESSOR_REPAIR_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json"
)
MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v19.json"
STAGE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_"
    "zero_world_qualification_closure_v15.json"
)
AUTHORITY_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_execution_authority_v15.json"
)
CLOSURE_PATH = ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v15.json"
SUPERVISOR_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json"
)
PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v14.json"
)
EXPECTED_DESIGN_SHA256 = (
    "sha256:696cc5ee80002e39968d27c6f21fa97f9309b7f08d3caad2961699ceb7184dfa"
)
EXPECTED_REPAIR_DESIGN_BYTES = 13_371
EXPECTED_REPAIR_DESIGN_SHA256 = (
    "sha256:ef04ca607078dbd67e2944f5970ba100fd8cbf970539fccc4dabdfd5c2d5691f"
)
EXPECTED_PREDECESSOR_REPAIR_DESIGN_BYTES = 27_267
EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256 = (
    "sha256:ce85d54e7a8cc12304015f5551d4f7874ad783613cd7feb566fc63cb10b20ce9"
)
RAW_SCHEMA = "sporespore_qsdk_r10f_process_isolated_child_raw_v1"
SUPERVISOR_SCHEMA = "sporespore_qsdk_r10f_l9_physical_supervisor_result_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r10f_l9_physical_attempt_identity_v1"
CHILD_ATTEMPT_SCHEMA = "sporespore_qsdk_r10f_l9_child_attempt_identity_v1"
ARM_RESULT_SCHEMA = "sporespore_qsdk_r10f_l9_process_isolated_arm_result_v1"
TRACE_SCHEMA = "sporespore_qsdk_r10f_l9_process_isolated_compact_native_trace_v1"
PRECONDITION_SCHEMA = (
    "sporespore_qsdk_r10f_l9_process_isolated_precondition_terminal_receipt_v1"
)
RELEASE_SCHEMA = (
    "sporespore_qsdk_r10f_l11_process_isolated_precondition_release_receipt_v1"
)
RELEASE_OWNER_SOURCE_SCHEMA = (
    "sporespore_qsdk_r10f_l11_precondition_release_owner_source_projection_v1"
)
WALKING_HANDOFF_SCHEMA = (
    "sporespore_qsdk_r10f_l12_walking_actuation_handoff_receipt_v1"
)
HOST_CAP_BINDING_SCHEMA = (
    "sporespore_qsdk_r10f_l12_walking_host_cap_projection_binding_v1"
)
WALKING_LEDGER_SCHEMA = (
    "sporespore_qsdk_r10f_l13_bw5r_b_route_aware_discrete_staging_"
    "application_intent_v2"
)
NATIVE_TRANSPORT_VERIFICATION_SCHEMA = (
    "sporespore_balanced_wave_native_step_transport_verification_v1"
)
HOST_TARGET_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r10f_godot_binary32_motor_target_projection_v1"
)
WALKING_LEDGER_PREDICATE_SCHEMA = (
    "sporespore_qsdk_r10f_l13_walking_ledger_predicate_receipt_v1"
)
MOTOR_CONFIGURATION_SCHEMA = (
    "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
)
MOTOR_READBACK_SCHEMA = (
    "sporespore_qsdk_r10f_recovery_native_motor_population_readback_v1"
)
HOST_CAP_PROJECTION_ID = (
    "godot_jolt_binary32_native_effective_impulse_limit_inverse_projection_v1"
)
HOST_CAP_PROJECTION_SCOPE = "exact_s169_published_actuator_profile_at_120_hz_only"
WALKING_FACADE_ID = "sporespore_qsdk_r10f_recovery_native_s169_locomotion_facade_v1"
INTERACTION_SCHEMA = "sporespore_qsdk_r10f_l9_process_isolated_interaction_source_v1"
POPULATION_SCHEMA = "sporespore_qsdk_r10f_l9_process_population_evaluation_v1"
PAIR_EVALUATION_SCHEMA = (
    "sporespore_qsdk_r10f_l9_process_isolated_pair_evaluation_v1"
)
AUTHORITY_SCHEMA = "sporespore_qsdk_r10f_development_route_ghost_execution_authority_v15"
STAGE_SCHEMA = (
    "sporespore_qsdk_r10f_development_route_ghost_"
    "zero_world_qualification_closure_v15"
)
REPAIR_ID = "QSDK-R10F-L14"
HANDOFF_REPAIR_ID = "QSDK-R10F-L12"
RELEASE_REPAIR_ID = "QSDK-R10F-L11"
CHILD_CONTRACT_REPAIR_ID = "QSDK-R10F-L9"
EXPECTED_SUPERVISOR_REFUSAL_BYTES = 6_486
EXPECTED_SUPERVISOR_REFUSAL_SHA256 = (
    "sha256:93e60e8fe747a8ba7a5b6a1621175ce4bf877f537a2a5d03d01ff9e186e1140f"
)
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES = 9_998
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = (
    "sha256:1df9bd1896deb23989d6a3c080948a21805a1465b2682748d7e31c7fa1bdd4cb"
)
ACTIVE_ARM = "kick_passive_recovery_resume"
BASELINE_ARM = "matched_no_kick_continuation"
ARM_IDS = [ACTIVE_ARM, BASELINE_ARM]
ARM_ORDER = [BASELINE_ARM, ACTIVE_ARM]
JOINT_IDS = [
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
]
ACTUATOR_IDS = [f"{joint_id}_motor" for joint_id in JOINT_IDS]
PUBLISHED_CAPS_NMS = [
    0.05362625170687301,
    0.4567500054836273,
    0.05362625170687301,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
]
HOST_CAPS_NMS = [
    0.05362624675035477,
    0.45674997568130493,
    0.05362624675035477,
    0.45674997568130493,
    0.05637374147772789,
    0.45674997568130493,
    0.05637374147772789,
    0.45674997568130493,
]
NATIVE_EFFECTIVE_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_projection_v1"
)
HOST_CAP_SELECTION_RULE = (
    "greatest_binary32_host_input_whose_complete_native_effective_impulse_"
    "projection_is_not_above_the_unchanged_published_cap"
)
MOTOR_CONFIGURATION_KEYS = {
    "schema_version",
    "gate_id",
    "ok",
    "global_semantic_step",
    "reason",
    "motor_enabled",
    "ordered_joint_receipts",
    "motor_configuration_write_count",
    "body_transform_write_count",
    "body_velocity_write_count",
    "body_impulse_write_count",
    "solver_reset_count",
    "physics_state_modified",
    "physical_acceptance_authority",
    "release_authority",
}
MOTOR_READBACK_KEYS = {
    "schema_version",
    "gate_id",
    "ok",
    "global_semantic_step",
    "reason",
    "expected_motor_enabled",
    "ordered_joint_readbacks",
    "motor_enabled_count",
    "zero_target_velocity_count",
    "native_readback_count",
    "body_transform_write_count",
    "body_velocity_write_count",
    "body_impulse_write_count",
    "solver_reset_count",
    "solver_step_count",
    "physics_state_modified",
    "physical_acceptance_authority",
    "release_authority",
}
HOST_CAP_PROJECTION_KEYS = {
    "schema_version",
    "ok",
    "projection_id",
    "scope",
    "actuator_id",
    "actuator_index",
    "published_maximum_outer_step_impulse_nms",
    "nearest_binary32_host_maximum_impulse_nms",
    "nearest_binary32_host_cap_binary32_hex",
    "configured_host_maximum_impulse_nms",
    "configured_host_cap_binary32_hex",
    "nearest_to_configured_downward_binary32_step_count",
    "projected_native_maximum_torque_limit_nm",
    "projected_native_torque_limit_binary32_hex",
    "native_solver_step_s",
    "native_solver_step_binary32_hex",
    "projected_native_effective_impulse_limit_nms",
    "projected_native_effective_limit_binary32_hex",
    "native_effective_limit_not_above_published",
    "next_binary32_host_maximum_impulse_nms",
    "next_binary32_host_cap_binary32_hex",
    "next_projected_native_maximum_torque_limit_nm",
    "next_projected_native_effective_impulse_limit_nms",
    "next_native_effective_limit_above_published",
    "configured_to_next_binary32_ulp_distance",
    "selection_rule",
    "nominal_host_conversion_step_s",
    "published_cap_changed",
    "empirical_margin_added",
    "measurement_clamped",
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "solver_step_count",
    "physics_state_modified",
    "physical_acceptance_authority",
    "release_authority",
}
HOST_CAP_BINDING_KEYS = {
    "schema_version",
    "gate_id",
    "ok",
    "projection_id",
    "scope",
    "selection_rule",
    "ordered_actuator_ids",
    "ordered_published_caps_nms",
    "ordered_selected_host_caps_nms",
    "published_cap_by_actuator_id",
    "selected_host_cap_by_actuator_id",
    "ordered_projection_receipts",
    "projection_count",
    "selected_effective_limit_not_above_published_count",
    "immediately_higher_effective_limit_above_published_count",
    "binary32_maximality_proof_count",
    "published_cap_changed",
    "empirical_margin_added",
    "raw_measurement_clamped",
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "solver_step_count",
    "physics_state_modified",
    "physical_acceptance_authority",
    "release_authority",
    "payload_sha256",
}
WALKING_HANDOFF_KEYS = {
    "schema_version",
    "gate_id",
    "ok",
    "facade_id",
    "model_instance_id",
    "facade_segment_id",
    "evaluation_segment_id",
    "walking_session_id",
    "global_semantic_step",
    "selected_policy_id",
    "selected_policy_digest",
    "motor_configuration_receipt",
    "motor_configuration_receipt_sha256",
    "precommand_motor_population_readback",
    "precommand_motor_population_readback_sha256",
    "host_cap_projection_binding",
    "host_cap_projection_binding_sha256",
    "ordered_actuator_ids",
    "published_cap_by_actuator_id",
    "authorized_host_cap_by_actuator_id",
    "motor_enabled_count",
    "zero_target_velocity_count",
    "motor_configuration_write_count",
    "native_readback_count",
    "solver_step_count",
    "body_transform_write_count",
    "body_velocity_write_count",
    "body_impulse_write_count",
    "solver_reset_count",
    "physics_state_modified",
    "outcome_derived_correction",
    "physical_acceptance_authority",
    "release_authority",
    "payload_sha256",
}
PAIR_BARRIER_ID = "sporespore_qsdk_r10f_precondition_pair_barrier_v1"
PAIR_REPAIR_ID = "QSDK-R10F-L6"
DISPOSITION_REPAIR_ID = "QSDK-R10F-L7"
PAIR_STATE_SCHEMA = "sporespore_qsdk_r10f_precondition_pair_barrier_state_v1"
PAIR_TERMINAL_SCHEMA = "sporespore_qsdk_r10f_precondition_terminal_source_v1"
PAIR_PLAN_SCHEMA = "sporespore_qsdk_r10f_precondition_pair_barrier_plan_v1"
PAIR_APPLICATION_SCHEMA = (
    "sporespore_qsdk_r10f_precondition_pair_barrier_application_v1"
)
DISPOSITION_SCHEMA = "sporespore_qsdk_r10f_precondition_terminal_disposition_v1"
ABORT_POPULATION_SCHEMA = (
    "sporespore_qsdk_r10f_precondition_terminal_disposition_abort_population_v1"
)
DISPOSITION_FAILURE_CODE = "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED"
DISPOSITION_BUILD_OUTER_FAILURE_CODE = (
    "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID"
)
DISPOSITION_BUILD_INNER_FAILURE_CODE = "QSDK_R10F_L7_DISPOSITION_BUILD_INVALID"
DISPOSITION_BUILD_FAILURE_SCHEMA = (
    "sporespore_qsdk_r10f_precondition_terminal_disposition_failure_v1"
)
DISPOSITION_COMPLETE = "complete_source_retained"
DISPOSITION_FAILED = "failed_source_retained"
DISPOSITION_REFUSED = "refused_source_retained"
DISPOSITION_NONTERMINAL = "nonterminal_last_completed_state_retained"
DISPOSITIONS = {
    DISPOSITION_COMPLETE,
    DISPOSITION_FAILED,
    DISPOSITION_REFUSED,
    DISPOSITION_NONTERMINAL,
}
FAILURE_DISPOSITIONS = {DISPOSITION_FAILED, DISPOSITION_REFUSED}
DISPOSITION_KEYS = {
    "schema_version",
    "gate_id",
    "repair_id",
    "attempt_id",
    "arm_id",
    "model_instance_id",
    "global_semantic_step",
    "disposition",
    "orchestrator_phase",
    "route_terminal",
    "route_terminal_reason",
    "recovery_controller_id",
    "recovery_terminal",
    "recovery_terminal_phase",
    "recovery_terminal_failure_code",
    "recovery_step_global_semantic_step",
    "recovery_memory",
    "recovery_memory_sha256",
    "recovery_step_receipt",
    "recovery_step_receipt_sha256",
    "recovery_classification",
    "recovery_classification_sha256",
    "pair_ready",
    "pair_terminal_source_sha256",
    "pair_state_sha256",
    "source_measurement",
    "outcome_derived_correction",
    "body_transform_write_count",
    "body_velocity_write_count",
    "solver_reset_count",
    "physical_acceptance_authority",
    "release_authority",
    "payload_sha256",
}
ABORT_POPULATION_KEYS = {
    "schema_version",
    "gate_id",
    "repair_id",
    "attempt_id",
    "failure_code",
    "global_semantic_step",
    "ordered_arm_ids",
    "disposition_by_arm",
    "disposition_sha256_by_arm",
    "failing_arm_ids",
    "failing_disposition_by_arm",
    "pair_state_sha256",
    "retained_global_lockstep_solver_frame_count",
    "retained_worker_solver_step_count",
    "expected_worker_solver_step_count_at_stop",
    "post_failure_additional_solver_step_count",
    "next_solver_step_permitted",
    "generic_terminal_frame_lockstep_failure_label_used",
    "nonfailing_peer_last_completed_state_retained",
    "independent_closure_validation_required",
    "summary_boolean_without_independent_validation",
    "source_measurement",
    "outcome_derived_correction",
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_readback_count",
    "solver_step_count",
    "physics_state_modified",
    "physical_acceptance_authority",
    "release_authority",
    "payload_sha256",
}
DISPOSITION_BUILD_FAILURE_KEYS = {
    "schema_version",
    "gate_id",
    "repair_id",
    "ok",
    "failure_code",
    "detail",
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_readback_count",
    "solver_step_count",
    "physics_state_modified",
    "physical_acceptance_authority",
    "release_authority",
}
PAIR_STATE_KEYS = {
    "schema_version",
    "gate_id",
    "repair_id",
    "barrier_id",
    "attempt_id",
    "model_instance_id_by_arm",
    "ready_by_arm",
    "terminal_source_by_arm",
    "terminal_source_sha256_by_arm",
    "terminal_global_step_by_arm",
    "planned_global_semantic_step",
    "planned_action_by_arm",
    "planned_action_completed_by_arm",
    "planned_application_sha256_by_arm",
    "current_plan",
    "current_plan_sha256",
    "last_completed_global_semantic_step",
    "completed_wait_step_count_by_arm",
    "release_planned_global_step",
    "release_completed_global_step",
    "released",
    "state_revision",
    "source_measurement",
    "outcome_derived_readiness",
    "physical_acceptance_authority",
    "release_authority",
    "payload_sha256",
}
PRECONDITION_PHASE = "canonical_prone_precondition_recovery"
FAILED_PHASE = "failed"
NO_ACTUATION_LEDGER_SCHEMA = "sporespore_qsdk_r10f_no_actuation_route_aware_discrete_staging_application_intent_v1"
ACTION_RECOVERY = "continue_recovery"
ACTION_WAIT = "no_actuation_wait"
ACTION_RELEASE = "no_actuation_release"
SEED = 40200
SEED_SHA256 = "sha256:efa3c38b428cc5f2daa6b156a8e3e35769623c7c23af6f9079b1d27c66e190fa"
CAMPAIGN_ID = "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
WORK_ID = "QSDK-R10F-L14-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"


def work_id_for_family(repair_id: str | None = None) -> str:
    selected = REPAIR_ID if repair_id is None else repair_id
    if selected == "QSDK-R10F-L15":
        return "QSDK-R10F-L15-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"
    # Historical diagnostic callers explicitly bind both original constants.
    # Preserve that exact work ID, rather than broadening accepted report labels.
    require(selected == REPAIR_ID, "PROCESS_WORK_FAMILY")
    return WORK_ID
RAW_MARKER = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_RAW "
READY_MARKER = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY "
POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
POLICY_SHA256 = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
ACTUATOR_PROFILE_ID = (
    "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
)
MATERIAL_PROFILE_ID = "godot_jolt_legacy_mu180_d3d5cd1_v1"
RECOVERY_MORPHOLOGY_SHA256 = (
    "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
)
RECOVERY_CONTROLLER_ID = "sporespore_exact_s169_prone_to_standing_controller_v6"
NATIVE_EFFECT_FLOOR_M_S = 0.0001
KICK_IMPULSE_MAGNITUDE_N_S = 0.25
VECTOR_ALLOWANCE = 2.0e-6
IMPULSE_ALLOWANCE = 4.76837158203125e-7
SELF_TEST_MARKER = "QSDK_R10F_PHYSICAL_CLOSURE_SELF_TEST_PASS "
AUDIT_MARKER = "QSDK_R10F_PHYSICAL_REPORT_AUDIT_PASS "
COMPILED_MARKER = "QSDK_R10F_PHYSICAL_CLOSURE_COMPILED "
MAX_EXACT_JSON_INTEGER = 9_007_199_254_740_991


class ClosureFailure(RuntimeError):
    """The consumed R10F development result is not complete enough to close."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def is_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def is_identifier(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{32}", value) is not None


def exact_int(value: Any, expected: int) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value == expected


def bounded_int(value: Any, minimum: int, maximum: int) -> bool:
    return (
        isinstance(value, int)
        and not isinstance(value, bool)
        and minimum <= value <= maximum
    )


def integer_valued_native_step_matches(
    value: Any, source_value: Any, expected_step: Any
) -> bool:
    """Accept a bound step only when its retained source number kind is unchanged."""

    if (
        type(value) is not type(source_value)
        or value != source_value
        or not bounded_int(expected_step, 1, 3842)
    ):
        return False
    if isinstance(value, int) and not isinstance(value, bool):
        return value == expected_step
    return (
        isinstance(value, float)
        and math.isfinite(value)
        and value.is_integer()
        and 1.0 <= value <= 3842.0
        and int(value) == expected_step
    )


def canonical_number_text(value: float) -> str:
    """Match the core's fourteen-significant-digit canonical binary64 text."""

    require(math.isfinite(value), "CANONICAL_NONFINITE_NUMBER")
    if value == 0.0:
        return "0"
    if value.is_integer() and abs(value) <= MAX_EXACT_JSON_INTEGER:
        return str(int(value))
    quantized = float(f"{value:.13e}")
    if quantized == 0.0:
        return "0"
    if quantized.is_integer() and abs(quantized) <= MAX_EXACT_JSON_INTEGER:
        return str(int(quantized))

    shortest = repr(quantized).lower()
    sign = ""
    if shortest.startswith("-"):
        sign = "-"
        shortest = shortest[1:]
    if "e" in shortest:
        coefficient, exponent_text = shortest.split("e", 1)
        exponent = int(exponent_text)
    else:
        coefficient = shortest
        exponent = 0
    fractional_digits = (
        len(coefficient) - coefficient.index(".") - 1 if "." in coefficient else 0
    )
    digits = coefficient.replace(".", "").lstrip("0")
    require(bool(digits), "CANONICAL_ZERO_COMPONENTS")
    power = exponent - fractional_digits
    length = len(digits)
    decimal_position = length + power
    if 0 <= power and decimal_position <= 16:
        rendered = digits + ("0" * power) + ".0"
    elif 0 < decimal_position <= 16:
        rendered = digits[:decimal_position] + "." + digits[decimal_position:]
    elif -5 < decimal_position <= 0:
        rendered = "0." + ("0" * (-decimal_position)) + digits
    else:
        scientific_exponent = decimal_position - 1
        exponent_text = (
            f"+{scientific_exponent}"
            if scientific_exponent >= 0
            else str(scientific_exponent)
        )
        rendered = (
            digits + "e" + exponent_text
            if length == 1
            else digits[0] + "." + digits[1:] + "e" + exponent_text
        )
    return sign + rendered


def canonical_json_v1(value: Any) -> str:
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, int):
        require(
            not isinstance(value, bool) and abs(value) <= MAX_EXACT_JSON_INTEGER,
            "CANONICAL_INTEGER_RANGE",
        )
        return str(value)
    if isinstance(value, float):
        return canonical_number_text(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if isinstance(value, list):
        return "[" + ",".join(canonical_json_v1(item) for item in value) + "]"
    if isinstance(value, Mapping):
        require(
            all(isinstance(key, str) for key in value),
            "CANONICAL_OBJECT_KEY_TYPE",
        )
        entries = (
            json.dumps(key, ensure_ascii=False, separators=(",", ":"))
            + ":"
            + canonical_json_v1(value[key])
            for key in sorted(value)
        )
        return "{" + ",".join(entries) + "}"
    raise ClosureFailure(f"CANONICAL_UNSUPPORTED_TYPE:{type(value).__name__}")


def canonical_sha256_v1(value: Any) -> str:
    encoded = canonical_json_v1(value).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def payload_sha256_v1(value: Mapping[str, Any]) -> str:
    payload = dict(value)
    payload.pop("payload_sha256", None)
    return canonical_sha256_v1(payload)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def file_identity(path: Path, *, relative_to: Path | None = None) -> dict[str, Any]:
    resolved = path.resolve()
    display = (
        resolved.relative_to(relative_to.resolve()).as_posix()
        if relative_to is not None
        else resolved.as_posix()
    )
    return {
        "path": display,
        "byte_length": resolved.stat().st_size,
        "raw_sha256": sha256_file(resolved),
    }


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def write_new_json(path: Path, value: Mapping[str, Any]) -> None:
    require(not path.exists(), f"OUTPUT_ALREADY_EXISTS:{path}")
    encoded = (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    try:
        with path.open("xb") as stream:
            stream.write(encoded)
            stream.flush()
    except FileExistsError as exc:
        raise ClosureFailure(f"OUTPUT_ALREADY_EXISTS:{path}") from exc


def run(arguments: Iterable[str | Path]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        tuple(str(value) for value in arguments),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def git(*arguments: str) -> str:
    result = run(("git", *arguments))
    require(
        result.returncode == 0,
        f"GIT_FAILED:{' '.join(arguments)}:{(result.stdout + result.stderr)[-2000:]}",
    )
    return result.stdout.strip()


def ledger_scope(authority_mode: str) -> dict[str, str]:
    return {
        "subsystem": "recovery",
        "engine_scope": "godot_jolt",
        "authority_mode": authority_mode,
        "question_class": "development",
    }


def source_policy() -> dict[str, Any]:
    manifest = read_json(MANIFEST_PATH, "MANIFEST")
    policy = manifest.get("policy")
    require(isinstance(policy, dict), "MANIFEST_POLICY")
    count = policy.get("expected_qualified_source_count")
    digest = policy.get("expected_qualified_source_path_sha256")
    require(
        manifest.get("schema_version") == "sporespore_qsdk_r10f_dependency_manifest_v9"
        and manifest.get("repair_id") == REPAIR_ID
        and manifest.get("status")
        == "prospective_complete_transitive_source_closure_zero_world"
        and isinstance(count, int)
        and not isinstance(count, bool)
        and count > 0
        and is_sha256(digest),
        "MANIFEST_UNFINALIZED",
    )
    return {"count": count, "digest": digest}


def validate_predecessor_physical_closure(source_commit: str) -> dict[str, Any]:
    closure = read_json(PREDECESSOR_PHYSICAL_CLOSURE_PATH, "PREDECESSOR_CLOSURE")
    bindings = closure.get("evidence_bindings")
    dispositions = closure.get("precondition_terminal_dispositions")
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v8"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L7"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "a07514ce2ce14c870811c86f55b6c775be4789db"
        and closure.get("stage_commit") == "db5d56cbaa4869920c5b38f2f0352da4b1630cda"
        and closure.get("authority_commit")
        == "898c6ff2146bf8e19367b196a0a1d309c3d39bfa"
        and closure.get("closure_audit_commit")
        == "63911dacda99c31dc67e7fbd7a4b2826b21e2483"
        and closure.get("attempt_id") == "0485211cfa1049e6bdee374b406d0c32"
        and closure.get("failure_code")
        == "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("maximum_campaign_attempt_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 2)
        and exact_int(closure.get("world_build_count"), 2)
        and exact_int(closure.get("solver_step_count"), 2)
        and isinstance(dispositions, dict)
        and dispositions.get("validation_class")
        == "disposition_builder_number_kind_rejection"
        and dispositions.get("inner_failure_code")
        == "QSDK_R10F_L7_DISPOSITION_BUILD_INVALID"
        and dispositions.get("memory_last_semantic_step_json_kind") == "binary64"
        and dispositions.get("receipt_global_semantic_step_json_kind") == "integer"
        and dispositions.get("numeric_values_equal") is True
        and dispositions.get("independent_receipt_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    for key in (
        "supervisor_result",
        "attempt_identity",
        "worker_stdout",
        "worker_stderr",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l7_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    ):
        declared = bindings.get(key)
        require(isinstance(declared, dict), f"PREDECESSOR_BINDING_{key.upper()}")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        expected = file_identity(
            actual_path,
            relative_to=None if declared_path.is_absolute() else ROOT,
        )
        require(declared == expected, f"PREDECESSOR_BINDING_{key.upper()}_IDENTITY")
    relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
        "PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
    )
    binding = file_identity(PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": closure["status"],
            "repair_id": "QSDK-R10F-L7",
            "classification": closure["classification"],
            "attempt_id": closure["attempt_id"],
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "world_attempt_count": 2,
            "world_build_count": 2,
            "solver_step_count": 2,
            "scientific_outcome": "none",
            "number_kind_diagnosis_independently_validated": True,
        }
    )
    return binding


def validate_repair_design(source_commit: str) -> dict[str, Any]:
    design = read_json(REPAIR_DESIGN_PATH, "REPAIR_DESIGN")
    predecessor = design.get("predecessor_design")
    consumed = design.get("consumed_l7_physical_closure")
    diagnosis = design.get("retained_diagnosis")
    change = design.get("controlled_change")
    envelope = design.get("bounded_execution_envelope")
    claim = design.get("claim_boundary")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES
        and sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256
        and design.get("schema_version")
        == "sporespore_qsdk_r10f_l8_integer_valued_native_step_domain_successor_design_v1"
        and design.get("status") == "prospective_zero_world_implementation_authorized"
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and isinstance(predecessor, dict)
        and predecessor.get("path")
        == PREDECESSOR_REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        and predecessor.get("byte_length")
        == PREDECESSOR_REPAIR_DESIGN_PATH.stat().st_size
        and predecessor.get("raw_sha256")
        == "sha256:1f1288acb506c39347e33ca6c6f0c86749caaf955f83dce71836cd8100f98c3b"
        and predecessor.get("repair_id") == "QSDK-R10F-L7"
        and predecessor.get("superseded") is False
        and isinstance(consumed, dict)
        and consumed.get("path")
        == PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        and consumed.get("raw_sha256") == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and consumed.get("attempt_id") == "0485211cfa1049e6bdee374b406d0c32"
        and exact_int(consumed.get("solver_step_count"), 2)
        and exact_int(consumed.get("global_lockstep_solver_frame_count"), 1)
        and consumed.get("same_identity_rerun_permitted") is False
        and isinstance(diagnosis, dict)
        and diagnosis.get("recovery_memory_last_semantic_step_runtime_kind")
        == "binary64"
        and diagnosis.get("disposition_recovery_step_global_semantic_step_runtime_kind")
        == "integer"
        and diagnosis.get("numeric_values_equal") is True
        and diagnosis.get("independent_retained_receipt_validation_passed") is True
        and diagnosis.get("l7_validator_rejected_integer_valued_binary64") is True
        and isinstance(change, dict)
        and change.get("mechanism") == "integer_valued_native_step_domain_validation_v1"
        and change.get("source_field") == "recovery_memory.last_semantic_step"
        and exact_int(change.get("minimum_accepted_step"), 1)
        and exact_int(change.get("maximum_accepted_step"), 3842)
        and change.get("preserve_original_source_number_kind_in_receipt") is True
        and change.get("physical_closure_must_independently_validate_number_kind")
        is True
        and all(
            change.get(key) is False
            for key in (
                "cast_or_rewrite_source_measurement_permitted",
                "canonical_digest_policy_changed",
                "other_discrete_fields_relaxed",
                "fractional_step_permitted",
                "nonfinite_step_permitted",
                "boolean_step_permitted",
                "string_step_permitted",
                "null_step_permitted",
                "out_of_domain_step_permitted",
                "mismatched_integer_valued_step_permitted",
                "outcome_derived_step_correction_permitted",
            )
        )
        and isinstance(envelope, dict)
        and exact_int(envelope.get("maximum_solver_steps_per_arm"), 3842)
        and exact_int(envelope.get("maximum_total_solver_steps"), 7684)
        and exact_int(envelope.get("solver_budget_delta_from_l7"), 0)
        and envelope.get("same_identity_rerun_permitted") is False
        and isinstance(claim, dict)
        and claim.get("physical_execution_authorized") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False,
        "REPAIR_DESIGN_FIELDS",
    )
    relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(REPAIR_DESIGN_PATH)),
        "REPAIR_DESIGN_SOURCE_BLOB",
    )
    return file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT)


def validate_authority_files(source: Mapping[str, Any]) -> dict[str, Any]:
    require(
        AUTHORITY_PATH.is_file()
        and STAGE_PATH.is_file()
        and SUPERVISOR_REFUSAL_PATH.is_file()
        and PREDECESSOR_PHYSICAL_CLOSURE_PATH.is_file()
        and REPAIR_DESIGN_PATH.is_file(),
        "AUTHORITY_FILES_MISSING",
    )
    authority = read_json(AUTHORITY_PATH, "AUTHORITY")
    stage = read_json(STAGE_PATH, "STAGE")
    policy = source_policy()
    predecessor_physical_closure = validate_predecessor_physical_closure(
        str(source.get("source_commit", ""))
    )
    repair_design = validate_repair_design(str(source.get("source_commit", "")))
    require(
        SUPERVISOR_REFUSAL_PATH.stat().st_size == EXPECTED_SUPERVISOR_REFUSAL_BYTES
        and sha256_file(SUPERVISOR_REFUSAL_PATH) == EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "SUPERSEDED_SUPERVISOR_REFUSAL_IDENTITY",
    )
    require(
        authority.get("schema_version") == AUTHORITY_SCHEMA
        and authority.get("status") == "authorized_single_use_unconsumed"
        and authority.get("gate_id") == "QSDK-R10F"
        and authority.get("repair_id") == REPAIR_ID
        and authority.get("campaign_role") == "development_route_ghost"
        and authority.get("source_commit") == source.get("source_commit")
        and authority.get("qualified_source_path_count") == policy["count"]
        and authority.get("qualified_source_path_sha256") == policy["digest"]
        and authority.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and authority.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and authority.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and authority.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and exact_int(authority.get("seed"), SEED)
        and authority.get("seed_sha256") == SEED_SHA256
        and exact_int(authority.get("maximum_world_count"), 2)
        and exact_int(authority.get("maximum_solver_step_count"), 7684)
        and exact_int(authority.get("maximum_campaign_attempt_count"), 1)
        and authority.get("zero_world_qualification_passed") is True
        and authority.get("physical_execution_authorized") is True
        and authority.get("physical_identity_consumed") is False
        and authority.get("same_identity_rerun_permitted") is False
        and authority.get("physical_acceptance_authority") is False
        and authority.get("release_authority") is False,
        "AUTHORITY_FIELDS",
    )
    require(
        stage.get("schema_version") == STAGE_SCHEMA
        and stage.get("status") == "closed_passing_official_zero_world_qualification"
        and stage.get("repair_id") == REPAIR_ID
        and stage.get("source_commit") == source.get("source_commit")
        and stage.get("qualification_parent_commit") == source.get("source_commit")
        and stage.get("qualified_source_path_count") == policy["count"]
        and stage.get("qualified_source_path_sha256") == policy["digest"]
        and stage.get("official_zero_world_qualification_passed") is True
        and stage.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and isinstance(stage.get("repair_design"), dict)
        and stage["repair_design"].get("raw_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and stage["repair_design"].get("repair_id") == REPAIR_ID
        and exact_int(stage["repair_design"].get("minimum_accepted_step"), 1)
        and exact_int(stage["repair_design"].get("maximum_accepted_step"), 3842)
        and exact_int(stage["repair_design"].get("maximum_solver_steps_per_arm"), 3842)
        and exact_int(stage["repair_design"].get("maximum_total_solver_steps"), 7684)
        and stage["repair_design"].get("source_number_kind_preserved") is True
        and stage["repair_design"].get("physical_execution_authorized_by_design")
        is False
        and isinstance(stage.get("superseded_physical_supervisor_refusal"), dict)
        and stage["superseded_physical_supervisor_refusal"].get("raw_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and stage["superseded_physical_supervisor_refusal"].get("repair_id")
        == "QSDK-R10F-L2"
        and stage["superseded_physical_supervisor_refusal"].get(
            "physical_attempt_identity_consumed"
        )
        is False
        and isinstance(stage.get("consumed_predecessor_physical_closure"), dict)
        and stage["consumed_predecessor_physical_closure"].get("raw_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and stage["consumed_predecessor_physical_closure"].get("repair_id")
        == "QSDK-R10F-L7"
        and stage["consumed_predecessor_physical_closure"].get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and stage["consumed_predecessor_physical_closure"].get(
            "physical_identity_consumed"
        )
        is True
        and stage["consumed_predecessor_physical_closure"].get(
            "same_identity_rerun_permitted"
        )
        is False
        and exact_int(
            stage["consumed_predecessor_physical_closure"].get("world_attempt_count"),
            2,
        )
        and exact_int(
            stage["consumed_predecessor_physical_closure"].get("world_build_count"),
            2,
        )
        and exact_int(
            stage["consumed_predecessor_physical_closure"].get("solver_step_count"),
            2,
        )
        and stage["consumed_predecessor_physical_closure"].get(
            "number_kind_diagnosis_independently_validated"
        )
        is True
        and stage.get("physical_execution_authorized_by_freeze") is False
        and stage.get("physical_acceptance_authority") is False
        and stage.get("release_authority") is False,
        "STAGE_FIELDS",
    )
    require(
        authority.get("zero_world_qualification_closure_sha256")
        == sha256_file(STAGE_PATH),
        "STAGE_SHA256_BINDING",
    )
    require(
        source.get("authority_sha256") == sha256_file(AUTHORITY_PATH),
        "AUTHORITY_SHA256_BINDING",
    )
    return {
        "authority": authority,
        "stage": stage,
        "policy": policy,
        "repair_design": repair_design,
        "predecessor_physical_closure": predecessor_physical_closure,
    }


def validate_live_authority_graph(authority: Mapping[str, Any]) -> dict[str, str]:
    root = Path(git("rev-parse", "--show-toplevel")).resolve()
    remote = git("remote", "get-url", "origin")
    branch = git("branch", "--show-current")
    status = git("status", "--porcelain=v1", "--untracked-files=all")
    head = git("rev-parse", "HEAD")
    origin = git("rev-parse", "origin/main")
    live = git("ls-remote", "origin", "refs/heads/main").split()
    authority_relative = AUTHORITY_PATH.relative_to(ROOT).as_posix()
    closer_relative = Path(__file__).resolve().relative_to(ROOT).as_posix()
    authority_commit = git("log", "-1", "--format=%H", "--", authority_relative)
    source = str(authority.get("source_commit", ""))
    stage = str(authority.get("authorization_parent_commit", ""))
    closure_audit_commit = source
    if head != authority_commit:
        require(
            git("rev-parse", "HEAD^") == authority_commit,
            "CLOSURE_AUDIT_CHILD_NOT_DIRECT_AUTHORITY_CHILD",
        )
        require(
            git(
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "--no-renames",
                "-r",
                head,
            ).splitlines()
            == [closer_relative],
            "CLOSURE_AUDIT_CHILD_NOT_CLOSER_ONLY",
        )
        closure_audit_commit = head
    require(
        root == ROOT.resolve() == EXPECTED_ROOT.resolve()
        and remote == EXPECTED_REMOTE
        and branch == "main"
        and status == ""
        and head == origin
        and live == [head, "refs/heads/main"]
        and git("rev-parse", f"{authority_commit}^") == stage
        and git("rev-parse", f"{authority_commit}^^") == source
        and head in {authority_commit, closure_audit_commit},
        "CLEAN_LIVE_COMMITTED_AUTHORITY_GRAPH_REQUIRED",
    )
    require(
        git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            stage,
        ).splitlines()
        == [STAGE_PATH.relative_to(ROOT).as_posix()]
        and git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            authority_commit,
        ).splitlines()
        == [authority_relative],
        "AUTHORITY_GRAPH_SINGLE_PATH_COMMITS",
    )
    require(
        git("rev-parse", f"{closure_audit_commit}:{closer_relative}")
        == git("hash-object", str(Path(__file__).resolve())),
        "CLOSURE_AUDIT_SOURCE_BLOB_DRIFT",
    )
    return {
        "source_commit": source,
        "stage_commit": stage,
        "authority_commit": authority_commit,
        "closure_audit_commit": closure_audit_commit,
    }


def validate_solver_counter_invariant(
    arm_id: str,
    expected_global_step: int,
    row: Any,
    invariant: Any,
    body_identity: Any,
) -> None:
    require(isinstance(row, dict), f"ARM_{arm_id}_ROW_NOT_OBJECT")
    require(isinstance(invariant, dict), f"ARM_{arm_id}_INVARIANT_NOT_OBJECT")
    projection = invariant.get("solver_counter_projection")
    predicates = invariant.get("predicates")
    require(
        row.get("schema_version") == "sporespore_qsdk_r10f_compact_native_trace_row_v1"
        and row.get("arm_id") == arm_id
        and exact_int(row.get("global_semantic_step"), expected_global_step)
        and row.get("body_population_instance_sha256") == body_identity
        and invariant.get("schema_version")
        == "sporespore_qsdk_r10f_in_run_native_invariant_v1"
        and invariant.get("arm_id") == arm_id
        and exact_int(invariant.get("global_semantic_step"), expected_global_step)
        and invariant.get("body_population_instance_sha256") == body_identity
        and invariant.get("all_in_run_physical_invariants_passed") is True
        and invariant.get("physical_acceptance_authority") is False
        and invariant.get("release_authority") is False
        and isinstance(predicates, dict)
        and bool(predicates)
        and all(value is True for value in predicates.values()),
        f"ARM_{arm_id}_ROW_INVARIANT_BINDING",
    )
    require(
        isinstance(projection, dict)
        and projection.get("schema_version")
        == "sporespore_qsdk_r10f_collection_solver_counter_projection_v1"
        and projection.get("gate_id") == "QSDK-R10F"
        and projection.get("ok") is True
        and exact_int(projection.get("global_semantic_step"), expected_global_step)
        and exact_int(
            projection.get("cumulative_solver_step_count"), expected_global_step
        )
        and exact_int(
            projection.get("retained_global_cumulative_solver_step_count"),
            expected_global_step,
        )
        and exact_int(projection.get("completed_step_delta"), 1)
        and projection.get("source_counter_semantics")
        == "cumulative_completed_global_solver_step_sequence"
        and projection.get("aggregate_counter_semantics")
        == "one_delta_per_accepted_arm_collection"
        and projection.get("retained_global_collector_unchanged") is True
        and projection.get("source_measurement") is True
        and projection.get("outcome_derived_correction") is False
        and projection.get("physical_acceptance_authority") is False
        and projection.get("release_authority") is False
        and predicates.get("collector_cumulative_solver_step_exact") is True
        and predicates.get("collector_global_counter_binding_exact") is True
        and predicates.get("accepted_collection_step_delta_exact") is True
        and predicates.get("collector_counter_outcome_correction_zero") is True,
        f"ARM_{arm_id}_SOLVER_COUNTER_PROJECTION",
    )


def validate_pair_terminal_source(
    arm_id: str,
    source: Any,
    *,
    attempt_id: str,
    model_instance_id: str,
) -> int:
    require(isinstance(source, dict), f"PAIR_{arm_id}_TERMINAL_SOURCE_OBJECT")
    step = source.get("terminal_step_receipt")
    classification = source.get("terminal_classification")
    require(
        source.get("schema_version") == PAIR_TERMINAL_SCHEMA
        and source.get("gate_id") == "QSDK-R10F"
        and source.get("repair_id") == PAIR_REPAIR_ID
        and source.get("barrier_id") == PAIR_BARRIER_ID
        and source.get("attempt_id") == attempt_id
        and source.get("arm_id") == arm_id
        and source.get("model_instance_id") == model_instance_id
        and bounded_int(source.get("global_semantic_step"), 1, 1200)
        and source.get("recovery_controller_id")
        == "sporespore_exact_s169_prone_to_standing_controller_v6"
        and source.get("terminal_phase") == "complete"
        and source.get("stable_four_foot_stance") is True
        and isinstance(step, dict)
        and isinstance(step.get("memory"), dict)
        and step["memory"].get("phase") == "complete"
        and isinstance(classification, dict)
        and classification.get("stable_stance_gate") is True
        and is_sha256(source.get("terminal_step_receipt_sha256"))
        and is_sha256(source.get("terminal_classification_sha256"))
        and source.get("source_measurement") is True
        and source.get("outcome_derived_readiness") is False
        and exact_int(source.get("model_construction_count"), 0)
        and exact_int(source.get("world_attempt_count"), 0)
        and exact_int(source.get("world_build_count"), 0)
        and exact_int(source.get("scene_tree_insertion_count"), 0)
        and exact_int(source.get("native_readback_count"), 0)
        and exact_int(source.get("solver_step_count"), 0)
        and source.get("physics_state_modified") is False
        and source.get("physical_acceptance_authority") is False
        and source.get("release_authority") is False
        and is_sha256(source.get("payload_sha256")),
        f"PAIR_{arm_id}_TERMINAL_SOURCE_FIELDS",
    )
    return int(source["global_semantic_step"])


def validate_pair_plan(application: Mapping[str, Any]) -> dict[str, Any]:
    plan = application.get("pair_plan_receipt")
    require(isinstance(plan, dict), "PAIR_APPLICATION_PLAN_OBJECT")
    actions = plan.get("action_by_arm")
    ready = plan.get("ready_by_arm")
    sources = plan.get("terminal_source_sha256_by_arm")
    require(
        plan.get("schema_version") == PAIR_PLAN_SCHEMA
        and plan.get("gate_id") == "QSDK-R10F"
        and plan.get("repair_id") == PAIR_REPAIR_ID
        and plan.get("barrier_id") == PAIR_BARRIER_ID
        and plan.get("attempt_id") == application.get("attempt_id")
        and bounded_int(plan.get("completed_global_semantic_step"), 1, 1200)
        and exact_int(
            plan.get("planned_global_semantic_step"),
            int(plan.get("completed_global_semantic_step", -2)) + 1,
        )
        and plan.get("planned_global_semantic_step")
        == application.get("global_semantic_step")
        and plan.get("ordered_arm_ids") == ARM_ORDER
        and isinstance(actions, dict)
        and sorted(actions) == sorted(ARM_IDS)
        and isinstance(ready, dict)
        and sorted(ready) == sorted(ARM_IDS)
        and isinstance(sources, dict)
        and sorted(sources) == sorted(ARM_IDS)
        and all(isinstance(ready[arm], bool) for arm in ARM_IDS)
        and is_sha256(plan.get("state_before_sha256"))
        and plan.get("common_solver_frame_required") is True
        and plan.get("world_pause_or_step_skip_permitted") is False
        and plan.get("motors_enabled_for_wait_or_release_permitted") is False
        and plan.get("outcome_derived_readiness") is False
        and plan.get("physical_acceptance_authority") is False
        and plan.get("release_authority") is False
        and is_sha256(plan.get("payload_sha256"))
        and application.get("pair_plan_receipt_sha256") == plan.get("payload_sha256"),
        "PAIR_APPLICATION_PLAN_FIELDS",
    )
    ready_count = sum(1 for arm in ARM_IDS if ready[arm])
    require(ready_count in {1, 2}, "PAIR_APPLICATION_PLAN_READY_COUNT")
    for candidate_arm in ARM_IDS:
        expected_action = (
            ACTION_RELEASE
            if ready_count == 2
            else (ACTION_WAIT if ready[candidate_arm] else ACTION_RECOVERY)
        )
        require(
            actions.get(candidate_arm) == expected_action,
            f"PAIR_APPLICATION_PLAN_ACTION_{candidate_arm}",
        )
        require(
            (
                is_sha256(sources.get(candidate_arm))
                if ready[candidate_arm]
                else sources.get(candidate_arm) == ""
            ),
            f"PAIR_APPLICATION_PLAN_SOURCE_{candidate_arm}",
        )
    return plan


def validate_pair_application(
    arm_id: str,
    application: Any,
    *,
    attempt_id: str,
    model_instance_id: str,
    terminal_source_sha256: str,
) -> tuple[int, str, dict[str, Any]]:
    require(isinstance(application, dict), f"PAIR_{arm_id}_APPLICATION_OBJECT")
    plan = validate_pair_plan(application)
    configuration = application.get("motor_configuration_receipt")
    readback = application.get("motor_population_readback")
    ledger = application.get("ledger_application_intent")
    ordered = application.get("ordered_motor_readbacks")
    action = application.get("action_kind")
    step = application.get("global_semantic_step")
    require(
        application.get("schema_version") == PAIR_APPLICATION_SCHEMA
        and application.get("gate_id") == "QSDK-R10F"
        and application.get("repair_id") == PAIR_REPAIR_ID
        and application.get("ok") is True
        and application.get("attempt_id") == attempt_id
        and application.get("arm_id") == arm_id
        and application.get("model_instance_id") == model_instance_id
        and bounded_int(step, 2, 1201)
        and action in {ACTION_WAIT, ACTION_RELEASE}
        and application.get("terminal_source_sha256") == terminal_source_sha256
        and isinstance(configuration, dict)
        and is_sha256(application.get("motor_configuration_receipt_sha256"))
        and isinstance(readback, dict)
        and is_sha256(application.get("motor_population_readback_sha256"))
        and isinstance(ledger, dict)
        and is_sha256(application.get("ledger_application_intent_sha256"))
        and isinstance(ordered, list)
        and application.get("control_owner") == "none"
        and application.get("actuation_owner") == "none"
        and application.get("no_actuation_requested") is True
        and application.get("source_measurement") is True
        and application.get("outcome_derived_readiness") is False
        and exact_int(application.get("body_transform_write_count"), 0)
        and exact_int(application.get("body_velocity_write_count"), 0)
        and exact_int(application.get("solver_reset_count"), 0)
        and application.get("physical_acceptance_authority") is False
        and application.get("release_authority") is False
        and is_sha256(application.get("payload_sha256")),
        f"PAIR_{arm_id}_APPLICATION_FIELDS",
    )
    ready = plan["ready_by_arm"]
    sources = plan["terminal_source_sha256_by_arm"]
    require(
        ready[arm_id] is True
        and plan["action_by_arm"][arm_id] == action
        and sources[arm_id] == terminal_source_sha256,
        f"PAIR_{arm_id}_APPLICATION_PLAN_BINDING",
    )
    require(
        configuration.get("schema_version")
        == "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
        and configuration.get("gate_id") == "QSDK-R10F"
        and configuration.get("ok") is True
        and configuration.get("global_semantic_step") == step
        and configuration.get("motor_enabled") is False
        and exact_int(configuration.get("motor_configuration_write_count"), 16)
        and exact_int(configuration.get("body_transform_write_count"), 0)
        and exact_int(configuration.get("body_velocity_write_count"), 0)
        and exact_int(configuration.get("body_impulse_write_count"), 0)
        and exact_int(configuration.get("solver_reset_count"), 0)
        and configuration.get("physics_state_modified") is True
        and configuration.get("physical_acceptance_authority") is False
        and configuration.get("release_authority") is False
        and isinstance(configuration.get("ordered_joint_receipts"), list)
        and len(configuration["ordered_joint_receipts"]) == len(JOINT_IDS),
        f"PAIR_{arm_id}_MOTOR_CONFIGURATION",
    )
    require(
        readback.get("schema_version")
        == "sporespore_qsdk_r10f_recovery_native_motor_population_readback_v1"
        and readback.get("gate_id") == "QSDK-R10F"
        and readback.get("ok") is True
        and readback.get("global_semantic_step") == step
        and readback.get("expected_motor_enabled") is False
        and exact_int(readback.get("motor_enabled_count"), 0)
        and exact_int(readback.get("zero_target_velocity_count"), 8)
        and exact_int(readback.get("native_readback_count"), 24)
        and exact_int(readback.get("body_transform_write_count"), 0)
        and exact_int(readback.get("body_velocity_write_count"), 0)
        and exact_int(readback.get("body_impulse_write_count"), 0)
        and exact_int(readback.get("solver_reset_count"), 0)
        and exact_int(readback.get("solver_step_count"), 0)
        and readback.get("physics_state_modified") is False
        and readback.get("physical_acceptance_authority") is False
        and readback.get("release_authority") is False
        and isinstance(readback.get("ordered_joint_readbacks"), list)
        and len(readback["ordered_joint_readbacks"]) == len(JOINT_IDS)
        and len(ordered) == len(JOINT_IDS),
        f"PAIR_{arm_id}_MOTOR_READBACK",
    )
    for index, (joint_id, actuator_id) in enumerate(zip(JOINT_IDS, ACTUATOR_IDS)):
        configured = configuration["ordered_joint_receipts"][index]
        native = readback["ordered_joint_readbacks"][index]
        projected = ordered[index]
        require(
            isinstance(configured, dict)
            and configured.get("joint_id") == joint_id
            and configured.get("motor_enabled") is False
            and configured.get("motor_target_velocity_rad_s") == 0
            and isinstance(native, dict)
            and native.get("actuator_id") == actuator_id
            and native.get("joint_id") == joint_id
            and native.get("motor_enabled") is False
            and native.get("motor_target_velocity_rad_s") == 0
            and isinstance(native.get("motor_maximum_impulse_nms"), (int, float))
            and not isinstance(native.get("motor_maximum_impulse_nms"), bool)
            and native["motor_maximum_impulse_nms"] > 0
            and projected
            == {
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0,
            },
            f"PAIR_{arm_id}_MOTOR_ROW_{index}",
        )
    require(
        ledger.get("schema_version") == NO_ACTUATION_LEDGER_SCHEMA
        and ledger.get("gate_id") == "QSDK-R10F"
        and ledger.get("ok") is True
        and ledger.get("semantic_step") == step
        and ledger.get("phase") == "canonical_prone_precondition_recovery"
        and ledger.get("controller_owner") == "none"
        and ledger.get("recovery_controller_id") is None
        and ledger.get("no_actuation_requested") is True
        and exact_int(ledger.get("motor_enabled_count"), 0)
        and ledger.get("native_joint_motors_disabled") is True
        and ledger.get("owner_source_receipt") == plan
        and ledger.get("owner_source_receipt_sha256") == plan.get("payload_sha256")
        and ledger.get("motor_population_readback") == readback
        and ledger.get("motor_population_readback_sha256")
        == application.get("motor_population_readback_sha256")
        and ledger.get("force_aware_recovery_used") is False
        and ledger.get("physical_acceptance_authority") is False
        and ledger.get("release_authority") is False,
        f"PAIR_{arm_id}_NO_ACTUATION_LEDGER",
    )
    return int(step), str(action), plan


def validate_precondition_pair_barrier(
    raw: Mapping[str, Any], arms: Mapping[str, Any], attempt_id: str
) -> dict[str, Any]:
    state = raw.get("precondition_pair_barrier_state")
    evidence = raw.get("precondition_pair_barrier_evidence_by_arm")
    evaluation = raw.get("route_evaluation")
    require(isinstance(state, dict), "PAIR_STATE_OBJECT")
    require(
        isinstance(evidence, dict) and sorted(evidence) == sorted(ARM_IDS),
        "PAIR_EVIDENCE",
    )
    require(isinstance(evaluation, dict), "PAIR_EVALUATION")
    model_ids = state.get("model_instance_id_by_arm")
    ready = state.get("ready_by_arm")
    sources = state.get("terminal_source_by_arm")
    source_shas = state.get("terminal_source_sha256_by_arm")
    source_steps = state.get("terminal_global_step_by_arm")
    actions = state.get("planned_action_by_arm")
    completed = state.get("planned_action_completed_by_arm")
    applications = state.get("planned_application_sha256_by_arm")
    waits = state.get("completed_wait_step_count_by_arm")
    release_step = state.get("release_completed_global_step")
    require(
        state.get("schema_version") == PAIR_STATE_SCHEMA
        and state.get("gate_id") == "QSDK-R10F"
        and state.get("repair_id") == PAIR_REPAIR_ID
        and state.get("barrier_id") == PAIR_BARRIER_ID
        and state.get("attempt_id") == attempt_id
        and all(
            isinstance(value, dict) and sorted(value) == sorted(ARM_IDS)
            for value in (
                model_ids,
                ready,
                sources,
                source_shas,
                source_steps,
                actions,
                completed,
                applications,
                waits,
            )
        )
        and all(ready[arm] is True for arm in ARM_IDS)
        and all(actions[arm] == ACTION_RELEASE for arm in ARM_IDS)
        and all(completed[arm] is True for arm in ARM_IDS)
        and bounded_int(release_step, 2, 1201)
        and state.get("release_planned_global_step") == release_step
        and state.get("planned_global_semantic_step") == release_step
        and state.get("last_completed_global_semantic_step") == release_step
        and state.get("released") is True
        and state.get("source_measurement") is True
        and state.get("outcome_derived_readiness") is False
        and state.get("physical_acceptance_authority") is False
        and state.get("release_authority") is False
        and is_sha256(state.get("payload_sha256"))
        and raw.get("precondition_pair_barrier_state_sha256")
        == state.get("payload_sha256")
        and raw.get("precondition_pair_barrier_state_valid") is True
        and raw.get("precondition_pair_barrier_released") is True
        and evaluation.get("precondition_pair_barrier_state_sha256")
        == state.get("payload_sha256")
        and evaluation.get("precondition_pair_barrier_released") is True
        and evaluation.get("precondition_pair_barrier_release_global_step")
        == release_step
        and isinstance(evaluation.get("route_receipts"), dict)
        and evaluation["route_receipts"].get(
            "precondition_pair_barrier_released_from_two_source_terminals"
        )
        is True,
        "PAIR_STATE_FIELDS",
    )
    final_plan = state.get("current_plan")
    require(
        isinstance(final_plan, dict)
        and state.get("current_plan_sha256") == final_plan.get("payload_sha256"),
        "PAIR_FINAL_PLAN_BINDING",
    )
    projected: dict[str, Any] = {}
    release_plans: list[dict[str, Any]] = []
    for arm_id in ARM_IDS:
        arm = arms[arm_id]
        model_id = arm.get("model_instance_id")
        require(model_ids[arm_id] == model_id, f"PAIR_{arm_id}_MODEL_BINDING")
        terminal_step = validate_pair_terminal_source(
            arm_id,
            sources[arm_id],
            attempt_id=attempt_id,
            model_instance_id=str(model_id),
        )
        source_sha = sources[arm_id]["payload_sha256"]
        require(
            source_shas[arm_id] == source_sha
            and source_steps[arm_id] == terminal_step
            and arm.get("precondition_terminal_source") == sources[arm_id]
            and arm.get("precondition_terminal_source_sha256") == source_sha
            and arm.get("precondition_pair_barrier_retention_valid") is True,
            f"PAIR_{arm_id}_TERMINAL_BINDING",
        )
        arm_apps = arm.get("precondition_pair_barrier_application_projections")
        retained = evidence[arm_id]
        require(
            isinstance(arm_apps, list)
            and bool(arm_apps)
            and retained.get("precondition_terminal_source") == sources[arm_id]
            and retained.get("precondition_terminal_source_sha256") == source_sha
            and retained.get("precondition_pair_barrier_application_projections")
            == arm_apps
            and retained.get("precondition_pair_barrier_application_projection_count")
            == len(arm_apps)
            and arm.get("precondition_pair_barrier_application_projection_count")
            == len(arm_apps),
            f"PAIR_{arm_id}_EVIDENCE_BINDING",
        )
        previous_step = terminal_step
        wait_count = 0
        release_count = 0
        for app in arm_apps:
            app_step, action, plan = validate_pair_application(
                arm_id,
                app,
                attempt_id=attempt_id,
                model_instance_id=str(model_id),
                terminal_source_sha256=source_sha,
            )
            require(app_step > previous_step, f"PAIR_{arm_id}_APPLICATION_ORDER")
            previous_step = app_step
            if action == ACTION_WAIT:
                require(app_step < release_step, f"PAIR_{arm_id}_WAIT_AFTER_RELEASE")
                wait_count += 1
            else:
                require(app_step == release_step, f"PAIR_{arm_id}_RELEASE_STEP")
                release_count += 1
                release_plans.append(plan)
        require(
            release_count == 1
            and arm_apps[-1].get("action_kind") == ACTION_RELEASE
            and arm_apps[-1].get("global_semantic_step") == release_step
            and arm.get("precondition_pair_barrier_wait_application_count")
            == wait_count
            and arm.get("precondition_pair_barrier_release_application_count") == 1
            and waits[arm_id] == wait_count
            and applications[arm_id] == arm_apps[-1].get("payload_sha256"),
            f"PAIR_{arm_id}_APPLICATION_COUNTS",
        )
        projected[arm_id] = {
            "terminal_global_step": terminal_step,
            "terminal_source_sha256": source_sha,
            "wait_application_count": wait_count,
            "release_application_count": 1,
        }
    require(
        len(release_plans) == 2 and release_plans[0] == release_plans[1] == final_plan,
        "PAIR_COMMON_RELEASE_PLAN",
    )
    return {
        "state_sha256": state["payload_sha256"],
        "release_global_step": release_step,
        "arm_evidence": projected,
    }


def validate_unreleased_disposition_pair_state(
    state: Any, *, attempt_id: str, allow_all_ready: bool
) -> dict[str, Any]:
    require(isinstance(state, dict), "L7_PAIR_STATE_OBJECT")
    require(set(state) == PAIR_STATE_KEYS, "L7_PAIR_STATE_KEYS")
    maps = {
        key: state.get(key)
        for key in (
            "model_instance_id_by_arm",
            "ready_by_arm",
            "terminal_source_by_arm",
            "terminal_source_sha256_by_arm",
            "terminal_global_step_by_arm",
            "planned_action_by_arm",
            "planned_action_completed_by_arm",
            "planned_application_sha256_by_arm",
            "completed_wait_step_count_by_arm",
        )
    }
    require(
        all(
            isinstance(value, dict) and sorted(value) == sorted(ARM_IDS)
            for value in maps.values()
        ),
        "L7_PAIR_STATE_MAPS",
    )
    model_ids = maps["model_instance_id_by_arm"]
    ready = maps["ready_by_arm"]
    sources = maps["terminal_source_by_arm"]
    source_shas = maps["terminal_source_sha256_by_arm"]
    source_steps = maps["terminal_global_step_by_arm"]
    actions = maps["planned_action_by_arm"]
    completed = maps["planned_action_completed_by_arm"]
    applications = maps["planned_application_sha256_by_arm"]
    waits = maps["completed_wait_step_count_by_arm"]
    global_step = state.get("last_completed_global_semantic_step")
    require(
        state.get("schema_version") == PAIR_STATE_SCHEMA
        and state.get("gate_id") == "QSDK-R10F"
        and state.get("repair_id") == PAIR_REPAIR_ID
        and state.get("barrier_id") == PAIR_BARRIER_ID
        and state.get("attempt_id") == attempt_id
        and all(isinstance(model_ids[arm], str) and model_ids[arm] for arm in ARM_IDS)
        and all(isinstance(ready[arm], bool) for arm in ARM_IDS)
        and (allow_all_ready or not all(ready[arm] for arm in ARM_IDS))
        and bounded_int(global_step, 1, 1200)
        and state.get("planned_global_semantic_step") == global_step
        and all(
            actions[arm] in {ACTION_RECOVERY, ACTION_WAIT, ACTION_RELEASE}
            for arm in ARM_IDS
        )
        and all(completed[arm] is True for arm in ARM_IDS)
        and all(is_sha256(applications[arm]) for arm in ARM_IDS)
        and all(bounded_int(waits[arm], 0, 1199) for arm in ARM_IDS)
        and state.get("release_planned_global_step") is None
        and state.get("release_completed_global_step") is None
        and state.get("released") is False
        and bounded_int(state.get("state_revision"), 0, 100_000)
        and state.get("source_measurement") is True
        and state.get("outcome_derived_readiness") is False
        and state.get("physical_acceptance_authority") is False
        and state.get("release_authority") is False,
        "L7_PAIR_STATE_FIELDS",
    )
    for arm_id in ARM_IDS:
        if ready[arm_id]:
            require(
                isinstance(sources[arm_id], dict)
                and bounded_int(source_steps[arm_id], 1, int(global_step)),
                f"L7_PAIR_STATE_READY_SOURCE_{arm_id}",
            )
            validate_pair_terminal_source(
                arm_id,
                sources[arm_id],
                attempt_id=attempt_id,
                model_instance_id=model_ids[arm_id],
            )
            step = sources[arm_id]["terminal_step_receipt"]
            classification = sources[arm_id]["terminal_classification"]
            require(
                sources[arm_id]["global_semantic_step"] == source_steps[arm_id]
                and source_shas[arm_id] == sources[arm_id]["payload_sha256"]
                and sources[arm_id]["terminal_step_receipt_sha256"]
                == payload_sha256_v1(step)
                and sources[arm_id]["terminal_classification_sha256"]
                == payload_sha256_v1(classification)
                and sources[arm_id]["payload_sha256"]
                == payload_sha256_v1(sources[arm_id]),
                f"L7_PAIR_STATE_READY_DIGESTS_{arm_id}",
            )
        else:
            require(
                sources[arm_id] is None
                and source_shas[arm_id] == ""
                and source_steps[arm_id] is None,
                f"L7_PAIR_STATE_NOT_READY_SOURCE_{arm_id}",
            )
        expected_wait_count = (
            int(global_step) - int(source_steps[arm_id]) if ready[arm_id] else 0
        )
        require(
            exact_int(waits[arm_id], expected_wait_count),
            f"L7_PAIR_STATE_WAIT_COUNT_{arm_id}",
        )

    current_plan = state.get("current_plan")
    if current_plan is None:
        require(
            state.get("current_plan_sha256") == "" and global_step == 1,
            "L7_PAIR_STATE_NULL_PLAN",
        )
    else:
        require(isinstance(current_plan, dict), "L7_PAIR_STATE_PLAN_OBJECT")
        plan_ready = current_plan.get("ready_by_arm")
        plan_sources = current_plan.get("terminal_source_sha256_by_arm")
        plan_actions = current_plan.get("action_by_arm")
        require(
            current_plan.get("schema_version") == PAIR_PLAN_SCHEMA
            and current_plan.get("gate_id") == "QSDK-R10F"
            and current_plan.get("repair_id") == PAIR_REPAIR_ID
            and current_plan.get("barrier_id") == PAIR_BARRIER_ID
            and current_plan.get("attempt_id") == attempt_id
            and current_plan.get("completed_global_semantic_step") == global_step - 1
            and current_plan.get("planned_global_semantic_step") == global_step
            and current_plan.get("ordered_arm_ids") == ARM_ORDER
            and isinstance(plan_ready, dict)
            and sorted(plan_ready) == sorted(ARM_IDS)
            and isinstance(plan_sources, dict)
            and sorted(plan_sources) == sorted(ARM_IDS)
            and isinstance(plan_actions, dict)
            and sorted(plan_actions) == sorted(ARM_IDS)
            and current_plan.get("common_solver_frame_required") is True
            and current_plan.get("world_pause_or_step_skip_permitted") is False
            and current_plan.get("motors_enabled_for_wait_or_release_permitted")
            is False
            and current_plan.get("outcome_derived_readiness") is False
            and current_plan.get("physical_acceptance_authority") is False
            and current_plan.get("release_authority") is False
            and is_sha256(current_plan.get("state_before_sha256"))
            and current_plan.get("payload_sha256") == payload_sha256_v1(current_plan)
            and state.get("current_plan_sha256") == current_plan["payload_sha256"]
            and actions == plan_actions,
            "L7_PAIR_STATE_PLAN_FIELDS",
        )
        plan_ready_count = sum(1 for arm in ARM_IDS if plan_ready[arm] is True)
        for arm_id in ARM_IDS:
            require(
                isinstance(plan_ready[arm_id], bool)
                and (
                    (is_sha256(plan_sources[arm_id]) and ready[arm_id] is True)
                    if plan_ready[arm_id]
                    else plan_sources[arm_id] == ""
                )
                and (
                    not plan_ready[arm_id]
                    or plan_sources[arm_id] == source_shas[arm_id]
                )
                and plan_actions[arm_id]
                == (
                    ACTION_RELEASE
                    if plan_ready_count == len(ARM_IDS)
                    else (ACTION_WAIT if plan_ready[arm_id] else ACTION_RECOVERY)
                ),
                f"L7_PAIR_STATE_PLAN_ARM_{arm_id}",
            )
    require(
        state.get("payload_sha256") == payload_sha256_v1(state),
        "L7_PAIR_STATE_PAYLOAD_SHA256",
    )
    return {
        "global_semantic_step": int(global_step),
        "model_instance_id_by_arm": dict(model_ids),
        "ready_by_arm": dict(ready),
        "terminal_source_by_arm": dict(sources),
        "terminal_source_sha256_by_arm": dict(source_shas),
        "terminal_global_step_by_arm": dict(source_steps),
        "completed_wait_step_count_by_arm": dict(waits),
        "state_sha256": state["payload_sha256"],
    }


def expected_unreleased_barrier_native_readback_count(
    state_projection: Mapping[str, Any],
) -> int:
    """Derive worker-only native reads from independently validated wait steps."""

    waits = state_projection.get("completed_wait_step_count_by_arm")
    require(
        isinstance(waits, dict)
        and sorted(waits) == sorted(ARM_IDS)
        and all(bounded_int(waits[arm_id], 0, 1199) for arm_id in ARM_IDS),
        "L7_WAIT_READBACK_COUNT_SOURCE",
    )
    return sum(int(waits[arm_id]) for arm_id in ARM_IDS) * len(JOINT_IDS) * 3


def validate_terminal_disposition(
    receipt: Any,
    *,
    arm_id: str,
    state: Mapping[str, Any],
    state_projection: Mapping[str, Any],
) -> str:
    require(isinstance(receipt, dict), f"L7_DISPOSITION_{arm_id}_OBJECT")
    require(set(receipt) == DISPOSITION_KEYS, f"L7_DISPOSITION_{arm_id}_KEYS")
    global_step = state_projection["global_semantic_step"]
    model_ids = state_projection["model_instance_id_by_arm"]
    ready_by_arm = state_projection["ready_by_arm"]
    source_shas = state_projection["terminal_source_sha256_by_arm"]
    memory = receipt.get("recovery_memory")
    step = receipt.get("recovery_step_receipt")
    classification = receipt.get("recovery_classification")
    require(
        receipt.get("schema_version") == DISPOSITION_SCHEMA
        and receipt.get("gate_id") == "QSDK-R10F"
        and receipt.get("repair_id") == DISPOSITION_REPAIR_ID
        and receipt.get("attempt_id") == state.get("attempt_id")
        and receipt.get("arm_id") == arm_id
        and receipt.get("model_instance_id") == model_ids[arm_id]
        and exact_int(receipt.get("global_semantic_step"), int(global_step))
        and receipt.get("disposition") in DISPOSITIONS
        and isinstance(receipt.get("orchestrator_phase"), str)
        and isinstance(receipt.get("route_terminal"), bool)
        and isinstance(receipt.get("route_terminal_reason"), str)
        and receipt.get("recovery_controller_id")
        == "sporespore_exact_s169_prone_to_standing_controller_v6"
        and isinstance(receipt.get("recovery_terminal"), bool)
        and isinstance(receipt.get("recovery_terminal_phase"), str)
        and isinstance(receipt.get("recovery_terminal_failure_code"), str)
        and bounded_int(
            receipt.get("recovery_step_global_semantic_step"), 1, int(global_step)
        )
        and isinstance(memory, dict)
        and isinstance(step, dict)
        and isinstance(classification, dict)
        and isinstance(receipt.get("pair_ready"), bool)
        and receipt.get("pair_ready") is ready_by_arm[arm_id]
        and receipt.get("pair_terminal_source_sha256") == source_shas[arm_id]
        and receipt.get("pair_state_sha256") == state_projection["state_sha256"]
        and receipt.get("source_measurement") is True
        and receipt.get("outcome_derived_correction") is False
        and exact_int(receipt.get("body_transform_write_count"), 0)
        and exact_int(receipt.get("body_velocity_write_count"), 0)
        and exact_int(receipt.get("solver_reset_count"), 0)
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        f"L7_DISPOSITION_{arm_id}_FIELDS",
    )
    require(
        step.get("memory") == memory
        and step.get("classification") == classification
        and integer_valued_native_step_matches(
            memory.get("last_semantic_step"),
            step["memory"].get("last_semantic_step"),
            receipt.get("recovery_step_global_semantic_step"),
        )
        and step.get("next_phase") == memory.get("phase")
        and receipt.get("recovery_memory_sha256") == canonical_sha256_v1(memory)
        and receipt.get("recovery_step_receipt_sha256") == canonical_sha256_v1(step)
        and receipt.get("recovery_classification_sha256")
        == canonical_sha256_v1(classification)
        and receipt.get("payload_sha256") == payload_sha256_v1(receipt),
        f"L7_DISPOSITION_{arm_id}_NESTED_BINDINGS",
    )
    route_terminal = receipt["route_terminal"]
    route_reason = receipt["route_terminal_reason"]
    orchestrator_phase = receipt["orchestrator_phase"]
    recovery_terminal = receipt["recovery_terminal"]
    recovery_phase = receipt["recovery_terminal_phase"]
    recovery_failure = receipt["recovery_terminal_failure_code"]
    require(
        route_terminal is (orchestrator_phase == FAILED_PHASE)
        and route_terminal is bool(route_reason),
        f"L7_DISPOSITION_{arm_id}_ROUTE_TERMINAL",
    )
    if recovery_terminal:
        require(
            recovery_phase in {"complete", "failed", "refused"}
            and memory.get("phase") == recovery_phase
            and ((recovery_phase == "complete") is (recovery_failure == "")),
            f"L7_DISPOSITION_{arm_id}_RECOVERY_TERMINAL",
        )
    else:
        require(
            recovery_phase == ""
            and recovery_failure == ""
            and memory.get("phase") not in {"complete", "failed", "refused"},
            f"L7_DISPOSITION_{arm_id}_RECOVERY_NONTERMINAL",
        )
    disposition = receipt["disposition"]
    if disposition == DISPOSITION_COMPLETE:
        source = state_projection["terminal_source_by_arm"][arm_id]
        source_step = state_projection["terminal_global_step_by_arm"][arm_id]
        require(
            ready_by_arm[arm_id] is True
            and route_terminal is False
            and orchestrator_phase == PRECONDITION_PHASE
            and recovery_terminal is True
            and recovery_phase == "complete"
            and recovery_failure == ""
            and classification.get("stable_stance_gate") is True
            and receipt.get("recovery_step_global_semantic_step") == source_step
            and isinstance(source, dict)
            and receipt.get("pair_terminal_source_sha256")
            == source.get("payload_sha256")
            and source.get("terminal_step_receipt") == step
            and source.get("terminal_classification") == classification,
            f"L7_DISPOSITION_{arm_id}_COMPLETE",
        )
    elif disposition == DISPOSITION_FAILED:
        require(
            ready_by_arm[arm_id] is False
            and route_terminal is True
            and orchestrator_phase == FAILED_PHASE
            and (
                (
                    recovery_terminal is True
                    and recovery_phase == "failed"
                    and bool(recovery_failure)
                    and route_reason == recovery_failure
                )
                or (recovery_terminal is False and bool(route_reason))
            ),
            f"L7_DISPOSITION_{arm_id}_FAILED",
        )
    elif disposition == DISPOSITION_REFUSED:
        require(
            ready_by_arm[arm_id] is False
            and route_terminal is True
            and orchestrator_phase == FAILED_PHASE
            and recovery_terminal is True
            and recovery_phase == "refused"
            and bool(recovery_failure)
            and route_reason == recovery_failure,
            f"L7_DISPOSITION_{arm_id}_REFUSED",
        )
    else:
        require(
            disposition == DISPOSITION_NONTERMINAL
            and ready_by_arm[arm_id] is False
            and route_terminal is False
            and orchestrator_phase == PRECONDITION_PHASE
            and recovery_terminal is False,
            f"L7_DISPOSITION_{arm_id}_NONTERMINAL",
        )
    return str(disposition)


def validate_terminal_disposition_population(
    raw: Mapping[str, Any], *, attempt_id: str, require_abort: bool
) -> dict[str, Any]:
    state = raw.get("precondition_terminal_disposition_pair_state")
    state_projection = validate_unreleased_disposition_pair_state(
        state, attempt_id=attempt_id, allow_all_ready=not require_abort
    )
    require(isinstance(state, dict), "L7_DISPOSITION_PAIR_STATE_OBJECT")
    dispositions = raw.get("precondition_terminal_disposition_by_arm")
    shas = raw.get("precondition_terminal_disposition_sha256_by_arm")
    require(
        raw.get("precondition_terminal_disposition_pair_state_sha256")
        == state_projection["state_sha256"]
        and raw.get("precondition_terminal_disposition_population_valid") is True
        and isinstance(dispositions, dict)
        and sorted(dispositions) == sorted(ARM_IDS)
        and isinstance(shas, dict)
        and sorted(shas) == sorted(ARM_IDS),
        "L7_DISPOSITION_POPULATION_FIELDS",
    )
    disposition_by_arm: dict[str, str] = {}
    for arm_id in ARM_ORDER:
        disposition_by_arm[arm_id] = validate_terminal_disposition(
            dispositions[arm_id],
            arm_id=arm_id,
            state=state,
            state_projection=state_projection,
        )
        require(
            shas[arm_id] == dispositions[arm_id]["payload_sha256"],
            f"L7_DISPOSITION_{arm_id}_POPULATION_SHA",
        )
    failing = [
        arm_id
        for arm_id in ARM_ORDER
        if disposition_by_arm[arm_id] in FAILURE_DISPOSITIONS
    ]
    if not require_abort:
        require(
            not failing
            and all(
                disposition_by_arm[arm_id] == DISPOSITION_COMPLETE for arm_id in ARM_IDS
            ),
            "L7_VALID_ROUTE_COMPLETE_DISPOSITIONS",
        )
        return {
            "pair_state_sha256": state_projection["state_sha256"],
            "global_semantic_step": state_projection["global_semantic_step"],
            "completed_wait_step_count_by_arm": state_projection[
                "completed_wait_step_count_by_arm"
            ],
            "expected_worker_extra_native_readback_count": (
                expected_unreleased_barrier_native_readback_count(state_projection)
            ),
            "disposition_by_arm": disposition_by_arm,
            "disposition_sha256_by_arm": dict(shas),
            "failing_arm_ids": [],
            "abort_population_sha256": "",
            "independent_population_validation_performed": True,
            "summary_boolean_only": False,
        }

    population = raw.get("precondition_terminal_abort_population")
    require(isinstance(population, dict), "L7_ABORT_POPULATION_OBJECT")
    require(set(population) == ABORT_POPULATION_KEYS, "L7_ABORT_POPULATION_KEYS")
    failing_by_arm = {arm_id: disposition_by_arm[arm_id] for arm_id in failing}
    global_step = state_projection["global_semantic_step"]
    expected_solver_steps = int(global_step) * len(ARM_IDS)
    require(
        bool(failing)
        and population.get("schema_version") == ABORT_POPULATION_SCHEMA
        and population.get("gate_id") == "QSDK-R10F"
        and population.get("repair_id") == DISPOSITION_REPAIR_ID
        and population.get("attempt_id") == attempt_id
        and population.get("failure_code") == DISPOSITION_FAILURE_CODE
        and exact_int(population.get("global_semantic_step"), int(global_step))
        and population.get("ordered_arm_ids") == ARM_ORDER
        and population.get("disposition_by_arm") == dispositions
        and population.get("disposition_sha256_by_arm") == shas
        and population.get("failing_arm_ids") == failing
        and population.get("failing_disposition_by_arm") == failing_by_arm
        and population.get("pair_state_sha256") == state_projection["state_sha256"]
        and exact_int(
            population.get("retained_global_lockstep_solver_frame_count"),
            int(global_step),
        )
        and exact_int(
            population.get("retained_worker_solver_step_count"),
            expected_solver_steps,
        )
        and exact_int(
            population.get("expected_worker_solver_step_count_at_stop"),
            expected_solver_steps,
        )
        and exact_int(population.get("post_failure_additional_solver_step_count"), 0)
        and population.get("next_solver_step_permitted") is False
        and population.get("generic_terminal_frame_lockstep_failure_label_used")
        is False
        and population.get("nonfailing_peer_last_completed_state_retained")
        is (len(failing) < len(ARM_IDS))
        and population.get("independent_closure_validation_required") is True
        and population.get("summary_boolean_without_independent_validation") is False
        and population.get("source_measurement") is True
        and population.get("outcome_derived_correction") is False
        and exact_int(population.get("model_construction_count"), 0)
        and exact_int(population.get("world_attempt_count"), 0)
        and exact_int(population.get("world_build_count"), 0)
        and exact_int(population.get("scene_tree_insertion_count"), 0)
        and exact_int(population.get("native_readback_count"), 0)
        and exact_int(population.get("solver_step_count"), 0)
        and population.get("physics_state_modified") is False
        and population.get("physical_acceptance_authority") is False
        and population.get("release_authority") is False
        and population.get("payload_sha256") == payload_sha256_v1(population)
        and raw.get("precondition_terminal_abort_population_sha256")
        == population.get("payload_sha256")
        and raw.get("precondition_terminal_abort_population_valid") is True,
        "L7_ABORT_POPULATION_FIELDS",
    )
    return {
        "pair_state_sha256": state_projection["state_sha256"],
        "global_semantic_step": int(global_step),
        "completed_wait_step_count_by_arm": state_projection[
            "completed_wait_step_count_by_arm"
        ],
        "expected_worker_extra_native_readback_count": (
            expected_unreleased_barrier_native_readback_count(state_projection)
        ),
        "disposition_by_arm": disposition_by_arm,
        "disposition_sha256_by_arm": dict(shas),
        "failing_arm_ids": failing,
        "abort_population_sha256": population["payload_sha256"],
        "independent_population_validation_performed": True,
        "summary_boolean_only": False,
    }


def validate_invalid_disposition_raw(
    raw: Any, source_commit: str, authority_sha: str, attempt_id: str
) -> dict[str, Any]:
    require(isinstance(raw, dict), "L7_INVALID_RAW_OBJECT")
    disposition = validate_terminal_disposition_population(
        raw, attempt_id=attempt_id, require_abort=True
    )
    detail = raw.get("detail")
    global_step = disposition["global_semantic_step"]
    expected_solver_steps = int(global_step) * len(ARM_IDS)
    require(
        raw.get("schema_version") == RAW_SCHEMA
        and raw.get("gate_id") == "QSDK-R10F"
        and raw.get("question_class") == "development"
        and raw.get("ledger_scope") == ledger_scope("consumed_physical_development_raw")
        and raw.get("status") == "invalid_or_incomplete_behavior_development"
        and raw.get("ok") is False
        and raw.get("failure_code") == DISPOSITION_FAILURE_CODE
        and raw.get("source_commit") == source_commit
        and raw.get("authorization_sha256") == authority_sha
        and raw.get("attempt_id") == attempt_id
        and exact_int(raw.get("seed"), SEED)
        and raw.get("seed_sha256") == SEED_SHA256
        and raw.get("held_out") is False
        and exact_int(raw.get("held_out_cell_access_count"), 0)
        and raw.get("population_inference_claimed") is False
        and raw.get("recovery_success_required_for_valid_result") is False
        and raw.get("physics_failure_is_valid_evidence") is True
        and raw.get("precondition_pair_barrier_state")
        == raw.get("precondition_terminal_disposition_pair_state")
        and raw.get("precondition_pair_barrier_state_sha256")
        == disposition["pair_state_sha256"]
        and raw.get("precondition_pair_barrier_state_valid") is True
        and raw.get("precondition_pair_barrier_released") is False
        and exact_int(raw.get("behavior_evaluator_invocation_count"), 0)
        and exact_int(raw.get("model_construction_attempt_count"), 2)
        and exact_int(raw.get("model_construction_count"), 2)
        and exact_int(raw.get("world_attempt_count"), 2)
        and exact_int(raw.get("world_build_count"), 2)
        and exact_int(raw.get("solver_step_count"), expected_solver_steps)
        and exact_int(raw.get("maximum_solver_step_count"), 7684)
        and exact_int(raw.get("global_lockstep_solver_frame_count"), int(global_step))
        and exact_int(raw.get("external_kick_application_count"), 0)
        and exact_int(
            raw.get("explicit_worker_extra_native_readback_count"),
            disposition["expected_worker_extra_native_readback_count"],
        )
        and raw.get("physical_question_opened") is True
        and raw.get("physics_state_modified") is True
        and raw.get("event_triggered_passive_recovery_observed") is False
        and raw.get("recovery_success_observed") is False
        and raw.get("prone_to_standing_claimed") is False
        and raw.get("kick_impulse_alone_causes_fall_claimed") is False
        and raw.get("force_aware_recovery") is False
        and raw.get("force_aware_bracing") is False
        and raw.get("arbitrary_fall_recovery_claimed") is False
        and raw.get("cross_engine_push_recovery_claimed") is False
        and raw.get("physical_acceptance_authority") is False
        and raw.get("release_authority") is False,
        "L7_INVALID_RAW_FIELDS",
    )
    population = raw["precondition_terminal_abort_population"]
    require(
        isinstance(detail, dict)
        and set(detail)
        == {
            "ok",
            "failure_code",
            "failing_arm_ids",
            "precondition_terminal_abort_population",
            "precondition_terminal_abort_population_sha256",
        }
        and detail.get("ok") is False
        and detail.get("failure_code") == DISPOSITION_FAILURE_CODE
        and detail.get("failing_arm_ids") == disposition["failing_arm_ids"]
        and detail.get("precondition_terminal_abort_population") == population
        and detail.get("precondition_terminal_abort_population_sha256")
        == population.get("payload_sha256"),
        "L7_INVALID_RAW_DETAIL_BINDING",
    )
    return disposition


def validate_disposition_build_invalid_raw(
    raw: Any, source_commit: str, authority_sha: str, attempt_id: str
) -> dict[str, Any]:
    """Validate the observed L7 receipt-builder failure without reinterpreting it.

    L7 produced a complete first-step, nonterminal disposition receipt, then its
    GDScript validator rejected the native recovery memory's integer-valued
    binary64 ``last_semantic_step`` because that validator required a Variant
    integer.  This closer validates the retained receipt and its hashes
    independently, and records the exact JSON number-kind mismatch as a
    diagnostic only.  It does not turn the consumed route into valid evidence.
    """

    require(isinstance(raw, dict), "L7_BUILD_INVALID_RAW_OBJECT")
    pair_state = raw.get("precondition_pair_barrier_state")
    state_projection = validate_unreleased_disposition_pair_state(
        pair_state, attempt_id=attempt_id, allow_all_ready=True
    )
    require(isinstance(pair_state, dict), "L7_BUILD_INVALID_PAIR_STATE_OBJECT")
    detail = raw.get("detail")
    require(
        isinstance(detail, dict)
        and set(detail) == {"ok", "failure_code", "arm_id", "build"}
        and detail.get("ok") is False
        and detail.get("failure_code") == DISPOSITION_BUILD_OUTER_FAILURE_CODE
        and detail.get("arm_id") == BASELINE_ARM,
        "L7_BUILD_INVALID_RAW_DETAIL",
    )
    build = detail.get("build")
    require(
        isinstance(build, dict)
        and set(build) == DISPOSITION_BUILD_FAILURE_KEYS
        and build.get("schema_version") == DISPOSITION_BUILD_FAILURE_SCHEMA
        and build.get("gate_id") == "QSDK-R10F"
        and build.get("repair_id") == DISPOSITION_REPAIR_ID
        and build.get("ok") is False
        and build.get("failure_code") == DISPOSITION_BUILD_INNER_FAILURE_CODE
        and exact_int(build.get("model_construction_count"), 0)
        and exact_int(build.get("world_attempt_count"), 0)
        and exact_int(build.get("world_build_count"), 0)
        and exact_int(build.get("scene_tree_insertion_count"), 0)
        and exact_int(build.get("native_readback_count"), 0)
        and exact_int(build.get("solver_step_count"), 0)
        and build.get("physics_state_modified") is False
        and build.get("physical_acceptance_authority") is False
        and build.get("release_authority") is False,
        "L7_BUILD_INVALID_INNER_FAILURE",
    )
    build_detail = build.get("detail")
    require(
        isinstance(build_detail, dict) and set(build_detail) == {"receipt"},
        "L7_BUILD_INVALID_INNER_DETAIL",
    )
    receipt = build_detail.get("receipt")
    disposition = validate_terminal_disposition(
        receipt,
        arm_id=BASELINE_ARM,
        state=pair_state,
        state_projection=state_projection,
    )
    require(
        disposition == DISPOSITION_NONTERMINAL,
        "L7_BUILD_INVALID_DISPOSITION_KIND",
    )
    require(isinstance(receipt, dict), "L7_BUILD_INVALID_RECEIPT_OBJECT")
    memory = receipt.get("recovery_memory")
    memory_last_step = (
        memory.get("last_semantic_step") if isinstance(memory, dict) else None
    )
    receipt_step = receipt.get("recovery_step_global_semantic_step")
    require(
        isinstance(memory_last_step, float)
        and math.isfinite(memory_last_step)
        and memory_last_step.is_integer()
        and exact_int(receipt_step, int(memory_last_step))
        and int(memory_last_step) == state_projection["global_semantic_step"],
        "L7_BUILD_INVALID_NUMBER_KIND_DIAGNOSIS",
    )
    expected_solver_steps = state_projection["global_semantic_step"] * len(ARM_IDS)
    require(
        raw.get("schema_version") == RAW_SCHEMA
        and raw.get("gate_id") == "QSDK-R10F"
        and raw.get("question_class") == "development"
        and raw.get("ledger_scope") == ledger_scope("consumed_physical_development_raw")
        and raw.get("status") == "invalid_or_incomplete_behavior_development"
        and raw.get("ok") is False
        and raw.get("failure_code") == DISPOSITION_BUILD_OUTER_FAILURE_CODE
        and raw.get("source_commit") == source_commit
        and raw.get("authorization_sha256") == authority_sha
        and raw.get("attempt_id") == attempt_id
        and exact_int(raw.get("seed"), SEED)
        and raw.get("seed_sha256") == SEED_SHA256
        and raw.get("held_out") is False
        and exact_int(raw.get("held_out_cell_access_count"), 0)
        and raw.get("population_inference_claimed") is False
        and raw.get("recovery_success_required_for_valid_result") is False
        and raw.get("physics_failure_is_valid_evidence") is True
        and raw.get("precondition_pair_barrier_state_sha256")
        == state_projection["state_sha256"]
        and raw.get("precondition_pair_barrier_state_valid") is True
        and raw.get("precondition_pair_barrier_released") is False
        and raw.get("precondition_terminal_disposition_by_arm") == {}
        and raw.get("precondition_terminal_disposition_sha256_by_arm")
        == {arm_id: "" for arm_id in ARM_IDS}
        and raw.get("precondition_terminal_disposition_pair_state") == {}
        and raw.get("precondition_terminal_disposition_pair_state_sha256") == ""
        and raw.get("precondition_terminal_disposition_population_valid") is False
        and raw.get("precondition_terminal_abort_population") == {}
        and raw.get("precondition_terminal_abort_population_sha256") == ""
        and raw.get("precondition_terminal_abort_population_valid") is False
        and exact_int(raw.get("behavior_evaluator_invocation_count"), 0)
        and exact_int(raw.get("model_construction_attempt_count"), 2)
        and exact_int(raw.get("model_construction_count"), 2)
        and exact_int(raw.get("world_attempt_count"), 2)
        and exact_int(raw.get("world_build_count"), 2)
        and exact_int(raw.get("solver_step_count"), expected_solver_steps)
        and exact_int(raw.get("maximum_solver_step_count"), 7684)
        and exact_int(
            raw.get("global_lockstep_solver_frame_count"),
            state_projection["global_semantic_step"],
        )
        and exact_int(raw.get("external_kick_application_count"), 0)
        and exact_int(raw.get("explicit_worker_extra_native_readback_count"), 0)
        and raw.get("physical_question_opened") is True
        and raw.get("physics_state_modified") is True
        and raw.get("event_triggered_passive_recovery_observed") is False
        and raw.get("recovery_success_observed") is False
        and raw.get("prone_to_standing_claimed") is False
        and raw.get("kick_impulse_alone_causes_fall_claimed") is False
        and raw.get("force_aware_recovery") is False
        and raw.get("force_aware_bracing") is False
        and raw.get("arbitrary_fall_recovery_claimed") is False
        and raw.get("cross_engine_push_recovery_claimed") is False
        and raw.get("physical_acceptance_authority") is False
        and raw.get("release_authority") is False,
        "L7_BUILD_INVALID_RAW_FIELDS",
    )
    return {
        "validation_class": "disposition_builder_number_kind_rejection",
        "outer_failure_code": DISPOSITION_BUILD_OUTER_FAILURE_CODE,
        "inner_failure_code": DISPOSITION_BUILD_INNER_FAILURE_CODE,
        "failing_arm_id": BASELINE_ARM,
        "retained_disposition": disposition,
        "pair_state_sha256": state_projection["state_sha256"],
        "global_semantic_step": state_projection["global_semantic_step"],
        "memory_last_semantic_step_json_kind": "binary64",
        "memory_last_semantic_step_numeric_value": memory_last_step,
        "receipt_global_semantic_step_json_kind": "integer",
        "receipt_global_semantic_step_numeric_value": receipt_step,
        "numeric_values_equal": memory_last_step == receipt_step,
        "independent_receipt_validation_performed": True,
        "summary_boolean_only": False,
    }


def validate_arm(arm_id: str, value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), f"ARM_{arm_id}_NOT_OBJECT")
    trace = value.get("trace")
    rows = trace.get("rows") if isinstance(trace, dict) else None
    invariants = value.get("in_run_invariant_receipts")
    initial_identity = value.get("initial_same_body_identity_receipt")
    initial_application_validation = value.get("initial_application_validation_receipt")
    terminal_identity = value.get("terminal_same_body_identity_receipt")
    body_identity = value.get("body_population_instance_sha256")
    require(
        value.get("schema_version")
        == "sporespore_qsdk_r10f_continuous_passive_recovery_arm_result_v1"
        and value.get("gate_id") == "QSDK-R10F"
        and value.get("ok") is True
        and value.get("arm_id") == arm_id
        and isinstance(value.get("model_instance_id"), str)
        and bool(value.get("model_instance_id"))
        and is_sha256(body_identity)
        and value.get("same_body_identity_preserved") is True
        and isinstance(initial_identity, dict)
        and initial_identity.get("body_population_instance_sha256") == body_identity
        and isinstance(initial_application_validation, dict)
        and initial_application_validation.get("schema_version")
        == "sporespore_qsdk_r10f_initial_bootstrap_application_validation_v1"
        and initial_application_validation.get("gate_id") == "QSDK-R10F"
        and initial_application_validation.get("ok") is True
        and exact_int(initial_application_validation.get("check_count"), 11)
        and initial_application_validation.get("failed_checks") == []
        and initial_application_validation.get("observed_application_schema")
        == "sporespore_qsdk_r24d57_godot_application_intent_v1"
        and initial_application_validation.get("expected_application_schema")
        == "sporespore_qsdk_r24d57_godot_application_intent_v1"
        and initial_application_validation.get(
            "active_application_validator_applicable"
        )
        is False
        and exact_int(initial_application_validation.get("model_construction_count"), 0)
        and exact_int(initial_application_validation.get("world_attempt_count"), 0)
        and exact_int(initial_application_validation.get("world_build_count"), 0)
        and exact_int(
            initial_application_validation.get("scene_tree_insertion_count"), 0
        )
        and exact_int(initial_application_validation.get("native_readback_count"), 0)
        and exact_int(initial_application_validation.get("solver_step_count"), 0)
        and initial_application_validation.get("physics_state_modified") is False
        and initial_application_validation.get("physical_acceptance_authority") is False
        and initial_application_validation.get("release_authority") is False
        and isinstance(terminal_identity, dict)
        and terminal_identity.get("body_population_instance_sha256") == body_identity
        and isinstance(trace, dict)
        and trace.get("schema_version")
        == "sporespore_qsdk_r10f_compact_native_trace_v1"
        and trace.get("gate_id") == "QSDK-R10F"
        and trace.get("arm_id") == arm_id
        and trace.get("model_instance_id") == value.get("model_instance_id")
        and trace.get("body_population_instance_sha256") == body_identity
        and isinstance(rows, list)
        and bool(rows)
        and is_sha256(value.get("trace_sha256"))
        and exact_int(value.get("outer_step_count"), len(rows))
        and exact_int(value.get("native_solver_step_count"), len(rows))
        and isinstance(invariants, list)
        and len(invariants) == len(rows)
        and exact_int(value.get("in_run_invariant_receipt_count"), len(rows))
        and value.get("all_in_run_physical_invariants_passed") is True
        and all(
            isinstance(item, dict)
            and item.get("all_in_run_physical_invariants_passed") is True
            for item in invariants
        )
        and exact_int(value.get("body_population_rebuild_count"), 0)
        and exact_int(value.get("body_transform_write_count"), 0)
        and exact_int(value.get("body_velocity_write_count"), 0)
        and exact_int(value.get("solver_reset_count"), 0)
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        f"ARM_{arm_id}_FIELDS",
    )
    for index, (row, invariant) in enumerate(zip(rows, invariants), start=1):
        validate_solver_counter_invariant(
            arm_id,
            index,
            row,
            invariant,
            body_identity,
        )
    expected_kicks = 1 if arm_id == ACTIVE_ARM else 0
    require(
        exact_int(value.get("external_kick_application_count"), expected_kicks),
        f"ARM_{arm_id}_KICK_COUNT",
    )
    return {
        "model_instance_id": value["model_instance_id"],
        "body_population_instance_sha256": body_identity,
        "outer_step_count": len(rows),
        "solver_counter_projection_verified_count": len(rows),
        "trace_sha256": value["trace_sha256"],
        "final_phase": value.get("final_phase"),
        "terminal_reason": value.get("terminal_reason"),
    }


def validate_valid_raw(
    raw: Mapping[str, Any], source_commit: str, authority_sha: str, attempt_id: str
) -> dict[str, Any]:
    evaluation = raw.get("route_evaluation")
    arms = raw.get("arm_results")
    require(isinstance(evaluation, dict), "RAW_EVALUATION")
    require(isinstance(arms, dict) and sorted(arms) == sorted(ARM_IDS), "RAW_ARMS")
    behavior = evaluation.get("behavior_passed")
    false_receipts = evaluation.get("false_route_receipts")
    require(isinstance(behavior, bool), "RAW_BEHAVIOR_TYPE")
    require(
        isinstance(false_receipts, list)
        and all(isinstance(value, str) and value for value in false_receipts)
        and behavior is (len(false_receipts) == 0),
        "RAW_FALSE_RECEIPTS",
    )
    expected_outcome = "positive" if behavior else "negative"
    require(
        raw.get("schema_version") == RAW_SCHEMA
        and raw.get("gate_id") == "QSDK-R10F"
        and raw.get("question_class") == "development"
        and raw.get("ledger_scope") == ledger_scope("consumed_physical_development_raw")
        and raw.get("status") == "valid_complete_behavior_development"
        and raw.get("ok") is True
        and raw.get("scientific_outcome") == expected_outcome
        and raw.get("source_commit") == source_commit
        and raw.get("authorization_sha256") == authority_sha
        and raw.get("attempt_id") == attempt_id
        and exact_int(raw.get("seed"), SEED)
        and raw.get("seed_sha256") == SEED_SHA256
        and raw.get("held_out") is False
        and exact_int(raw.get("held_out_cell_access_count"), 0)
        and raw.get("population_inference_claimed") is False
        and raw.get("physics_failure_is_valid_evidence") is True
        and exact_int(raw.get("model_construction_attempt_count"), 2)
        and exact_int(raw.get("model_construction_count"), 2)
        and exact_int(raw.get("world_attempt_count"), 2)
        and exact_int(raw.get("world_build_count"), 2)
        and exact_int(raw.get("complete_trace_count"), 2)
        and exact_int(raw.get("behavior_evaluator_invocation_count"), 1)
        and exact_int(raw.get("external_kick_application_count"), 1)
        and bounded_int(raw.get("solver_step_count"), 2, 7684)
        and exact_int(raw.get("maximum_solver_step_count"), 7684)
        and raw.get("all_in_run_physical_invariants_passed") is True
        and raw.get("same_body_identity_preserved") is True
        and raw.get("physical_question_opened") is True
        and raw.get("physics_state_modified") is True
        and raw.get("event_triggered_passive_recovery_observed") is behavior
        and raw.get("recovery_success_observed") is behavior
        and raw.get("prone_to_standing_claimed") is behavior
        and raw.get("kick_impulse_alone_causes_fall_claimed") is False
        and raw.get("force_aware_recovery") is False
        and raw.get("force_aware_bracing") is False
        and raw.get("arbitrary_fall_recovery_claimed") is False
        and raw.get("cross_engine_push_recovery_claimed") is False
        and raw.get("physical_acceptance_authority") is False
        and raw.get("release_authority") is False,
        "RAW_FIELDS",
    )
    require(
        evaluation.get("schema_version")
        == "sporespore_qsdk_r10f_continuous_passive_recovery_evaluation_v1"
        and evaluation.get("gate_id") == "QSDK-R10F"
        and evaluation.get("ok") is True
        and evaluation.get("evidence_valid") is True
        and evaluation.get("outcome_complete") is True
        and exact_int(evaluation.get("threshold_override_input_count"), 0)
        and evaluation.get("event_triggered_passive_recovery") is True
        and evaluation.get("force_aware_recovery") is False
        and evaluation.get("physical_acceptance_authority") is False
        and evaluation.get("release_authority") is False
        and is_sha256(evaluation.get("payload_sha256"))
        and is_sha256(evaluation.get("interaction_pair_receipt_sha256"))
        and is_sha256(evaluation.get("precondition_pair_barrier_state_sha256"))
        and evaluation.get("precondition_pair_barrier_released") is True,
        "RAW_EVALUATION_FIELDS",
    )
    projections = {arm_id: validate_arm(arm_id, arms[arm_id]) for arm_id in ARM_IDS}
    pair_barrier = validate_precondition_pair_barrier(raw, arms, attempt_id)
    terminal_dispositions = validate_terminal_disposition_population(
        raw, attempt_id=attempt_id, require_abort=False
    )
    disposition_state = raw["precondition_terminal_disposition_pair_state"]
    final_pair_state = raw["precondition_pair_barrier_state"]
    require(
        all(
            disposition_state["model_instance_id_by_arm"][arm_id]
            == arms[arm_id]["model_instance_id"]
            and disposition_state["terminal_source_sha256_by_arm"][arm_id]
            == final_pair_state["terminal_source_sha256_by_arm"][arm_id]
            for arm_id in ARM_IDS
        ),
        "L7_VALID_DISPOSITION_FINAL_PAIR_BINDING",
    )
    require(
        terminal_dispositions["global_semantic_step"] + 1
        == pair_barrier["release_global_step"],
        "L7_VALID_DISPOSITION_RELEASE_ORDER",
    )
    for arm_id in ARM_IDS:
        projections[arm_id]["precondition_pair_barrier"] = pair_barrier["arm_evidence"][
            arm_id
        ]
    require(
        projections[ACTIVE_ARM]["outer_step_count"]
        == projections[BASELINE_ARM]["outer_step_count"]
        and projections[ACTIVE_ARM]["model_instance_id"]
        != projections[BASELINE_ARM]["model_instance_id"]
        and raw.get("solver_step_count")
        == projections[ACTIVE_ARM]["outer_step_count"]
        + projections[BASELINE_ARM]["outer_step_count"]
        and raw.get("in_run_invariant_receipt_count") == raw.get("solver_step_count")
        and raw.get("global_lockstep_solver_frame_count")
        == projections[ACTIVE_ARM]["outer_step_count"],
        "RAW_LOCKSTEP_POPULATION",
    )
    return {
        "classification": (
            "valid_complete_behavior_positive"
            if behavior
            else "valid_complete_behavior_development_negative"
        ),
        "route_execution_valid": True,
        "evidence_valid": True,
        "outcome_complete": True,
        "behavior_passed": behavior,
        "scientific_outcome": expected_outcome,
        "false_route_receipts": list(false_receipts),
        "arm_projections": projections,
        "precondition_pair_barrier": pair_barrier,
        "precondition_terminal_dispositions": terminal_dispositions,
    }


def validate_report(
    report: Mapping[str, Any], *, report_path: Path | None, verify_files: bool
) -> dict[str, Any]:
    source_commit = report.get("source_commit")
    authority_sha = report.get("authority_sha256")
    attempt_id = report.get("attempt_id")
    route_valid = report.get("route_execution_valid")
    require(
        report.get("schema_version") == SUPERVISOR_SCHEMA
        and report.get("gate_id") == "QSDK-R10F"
        and report.get("repair_id") == REPAIR_ID
        and report.get("campaign_id")
        == "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
        and report.get("campaign_role") == "development_route_ghost"
        and report.get("question_class") == "development"
        and report.get("ledger_scope")
        == ledger_scope("consumed_physical_campaign_report")
        and isinstance(report.get("ok"), bool)
        and report.get("status")
        in {
            "valid_complete_behavior_development",
            "invalid_or_incomplete_behavior_development",
        }
        and is_commit(source_commit)
        and is_sha256(authority_sha)
        and report.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and report.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and is_identifier(attempt_id)
        and report.get("attempt_identity_consumed") is True
        and report.get("same_identity_rerun_permitted") is False
        and exact_int(report.get("maximum_campaign_attempt_count"), 1)
        and isinstance(report.get("raw_marker_valid"), bool)
        and isinstance(route_valid, bool)
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False,
        "SUPERVISOR_FIELDS",
    )
    raw = report.get("worker_receipt")
    termination = report.get("termination")
    engine_health = report.get("engine_health")
    require(isinstance(termination, dict), "TERMINATION_NOT_OBJECT")
    require(isinstance(engine_health, dict), "ENGINE_HEALTH_NOT_OBJECT")
    if route_valid:
        require(
            report.get("ok") is True
            and report.get("status") == "valid_complete_behavior_development"
            and report.get("failure_code") == ""
            and report.get("raw_marker_valid") is True
            and report.get("count_fields_known") is True
            and termination.get("termination_protocol_valid") is True
            and exact_int(termination.get("exit_code"), 0)
            and termination.get("timed_out") is False
            and engine_health.get("passed") is True
            and isinstance(raw, dict),
            "VALID_SUPERVISOR_ROUTE",
        )
        outcome = validate_valid_raw(raw, source_commit, authority_sha, attempt_id)
        require(
            report.get("scientific_outcome") == outcome["scientific_outcome"]
            and report.get("behavior_passed") is outcome["behavior_passed"]
            and report.get("model_construction_count")
            == raw.get("model_construction_count")
            and report.get("world_attempt_count") == raw.get("world_attempt_count")
            and report.get("world_build_count") == raw.get("world_build_count")
            and report.get("solver_step_count") == raw.get("solver_step_count"),
            "VALID_SUPERVISOR_RAW_PROJECTION",
        )
    else:
        require(
            report.get("ok") is False
            and report.get("status") == "invalid_or_incomplete_behavior_development"
            and report.get("scientific_outcome") == "none"
            and report.get("behavior_passed") is False
            and isinstance(report.get("failure_code"), str)
            and bool(report.get("failure_code")),
            "INVALID_SUPERVISOR_ROUTE",
        )
        for key, maximum in (
            ("model_construction_count", 2),
            ("world_attempt_count", 2),
            ("world_build_count", 2),
            ("solver_step_count", 7684),
        ):
            require(bounded_int(report.get(key), -1, maximum), f"INVALID_{key.upper()}")
        l7_disposition_evidence_present = isinstance(raw, dict) and (
            raw.get("failure_code") == DISPOSITION_FAILURE_CODE
            or raw.get("precondition_terminal_abort_population_valid") is True
        )
        l7_disposition_build_failure_present = isinstance(raw, dict) and (
            raw.get("failure_code") == DISPOSITION_BUILD_OUTER_FAILURE_CODE
            or report.get("failure_code") == DISPOSITION_BUILD_OUTER_FAILURE_CODE
        )
        terminal_dispositions: dict[str, Any] = {}
        if l7_disposition_evidence_present:
            require(
                report.get("failure_code") == DISPOSITION_FAILURE_CODE
                and report.get("raw_marker_valid") is True
                and report.get("count_fields_known") is True
                and termination.get("termination_protocol_valid") is True
                and exact_int(termination.get("exit_code"), 1)
                and termination.get("timed_out") is False
                and engine_health.get("passed") is True,
                "L7_INVALID_SUPERVISOR_RECEIPT",
            )
            terminal_dispositions = validate_invalid_disposition_raw(
                raw, source_commit, authority_sha, attempt_id
            )
            require(
                report.get("model_construction_count")
                == raw.get("model_construction_count")
                and report.get("world_attempt_count") == raw.get("world_attempt_count")
                and report.get("world_build_count") == raw.get("world_build_count")
                and report.get("solver_step_count") == raw.get("solver_step_count"),
                "L7_INVALID_SUPERVISOR_RAW_PROJECTION",
            )
        elif l7_disposition_build_failure_present:
            require(
                report.get("failure_code") == DISPOSITION_BUILD_OUTER_FAILURE_CODE
                and report.get("raw_marker_valid") is True
                and report.get("count_fields_known") is True
                and termination.get("termination_protocol_valid") is True
                and exact_int(termination.get("exit_code"), 1)
                and termination.get("timed_out") is False
                and engine_health.get("passed") is True,
                "L7_BUILD_INVALID_SUPERVISOR_RECEIPT",
            )
            terminal_dispositions = validate_disposition_build_invalid_raw(
                raw, source_commit, authority_sha, attempt_id
            )
            require(
                report.get("model_construction_count")
                == raw.get("model_construction_count")
                and report.get("world_attempt_count") == raw.get("world_attempt_count")
                and report.get("world_build_count") == raw.get("world_build_count")
                and report.get("solver_step_count") == raw.get("solver_step_count"),
                "L7_BUILD_INVALID_SUPERVISOR_RAW_PROJECTION",
            )
        outcome = {
            "classification": "invalid_or_incomplete_no_behavioral_conclusion",
            "route_execution_valid": False,
            "evidence_valid": False,
            "outcome_complete": False,
            "behavior_passed": False,
            "scientific_outcome": "none",
            "false_route_receipts": [],
            "arm_projections": {},
            "precondition_pair_barrier": {},
            "precondition_terminal_dispositions": terminal_dispositions,
        }
    if verify_files:
        require(report_path is not None, "REPORT_PATH_REQUIRED")
        resolved = report_path.resolve()
        require(
            resolved.name == "supervisor_result.json"
            and resolved.parent.parent.resolve() == EVIDENCE_ROOT.resolve()
            and Path(str(report.get("evidence_root", ""))).resolve()
            == resolved.parent.resolve(),
            "REPORT_LOCATION",
        )
        expected_root = EVIDENCE_ROOT / (
            "qsdk-r10f-development-route-ghost-" + str(authority_sha)[7:23]
        )
        require(resolved.parent == expected_root.resolve(), "REPORT_IDENTITY_ROOT")
        attempt_path = resolved.parent / "attempt_identity.json"
        stdout_path = resolved.parent / "worker.stdout.txt"
        stderr_path = resolved.parent / "worker.stderr.txt"
        require(
            attempt_path.is_file() and stdout_path.is_file() and stderr_path.is_file(),
            "REPORT_COMPANION_FILES",
        )
        attempt = read_json(attempt_path, "ATTEMPT")
        require(
            attempt.get("schema_version") == ATTEMPT_SCHEMA
            and attempt.get("repair_id") == REPAIR_ID
            and attempt.get("campaign_id")
            == "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
            and attempt.get("campaign_role") == "development_route_ghost"
            and attempt.get("question_class") == "development"
            and attempt.get("ledger_scope")
            == ledger_scope("consumed_physical_attempt_identity")
            and attempt.get("status")
            == "physical_identity_consumed_before_worker_start"
            and attempt.get("source_commit") == source_commit
            and attempt.get("authority_sha256") == authority_sha
            and attempt.get("consumed_predecessor_physical_closure_sha256")
            == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
            and attempt.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
            and attempt.get("attempt_id") == attempt_id
            and is_identifier(attempt.get("termination_nonce"))
            and exact_int(attempt.get("seed"), SEED)
            and attempt.get("same_identity_rerun_permitted") is False
            and exact_int(attempt.get("maximum_campaign_attempt_count"), 1)
            and exact_int(attempt.get("maximum_world_count"), 2)
            and attempt.get("physical_execution_authorized") is True
            and attempt.get("physical_acceptance_authority") is False
            and attempt.get("release_authority") is False,
            "ATTEMPT_FIELDS",
        )
        require(
            termination.get("stdout") == stdout_path.read_bytes().decode("utf-8")
            and termination.get("stderr") == stderr_path.read_bytes().decode("utf-8"),
            "PROCESS_LOG_BINDING",
        )
        if report.get("raw_marker_valid") is True:
            marker = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_RAW "
            matches = [
                line[len(marker) :]
                for line in stdout_path.read_bytes().decode("utf-8").splitlines()
                if line.startswith(marker)
            ]
            require(len(matches) == 1, "RAW_LOG_MARKER_COUNT")
            try:
                logged_raw = json.loads(matches[0])
            except json.JSONDecodeError as exc:
                raise ClosureFailure(f"RAW_LOG_MARKER_JSON:{exc}") from exc
            require(logged_raw == raw, "RAW_LOG_SUPERVISOR_BINDING")
        authority_files = validate_authority_files(report)
        outcome["evidence_bindings"] = {
            "supervisor_result": file_identity(resolved),
            "attempt_identity": file_identity(attempt_path),
            "worker_stdout": file_identity(stdout_path),
            "worker_stderr": file_identity(stderr_path),
            "execution_authority": file_identity(AUTHORITY_PATH, relative_to=ROOT),
            "stage_freeze": file_identity(STAGE_PATH, relative_to=ROOT),
            "r10f_design": file_identity(DESIGN_PATH, relative_to=ROOT),
            "l8_repair_design": file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT),
            "superseded_physical_supervisor_refusal": file_identity(
                SUPERVISOR_REFUSAL_PATH, relative_to=ROOT
            ),
            "consumed_predecessor_physical_closure": file_identity(
                PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT
            ),
        }
        outcome["authority"] = authority_files["authority"]
    return outcome


def build_closure(
    report_path: Path, report: Mapping[str, Any], outcome: Mapping[str, Any]
) -> dict[str, Any]:
    authority = outcome.get("authority")
    require(isinstance(authority, dict), "CLOSURE_AUTHORITY_MISSING")
    graph = validate_live_authority_graph(authority)
    bindings = outcome.get("evidence_bindings")
    require(isinstance(bindings, dict), "CLOSURE_BINDINGS_MISSING")
    behavior = bool(outcome["behavior_passed"])
    return {
        "schema_version": "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v9",
        "status": {
            "valid_complete_behavior_positive": "closed_consumed_valid_complete_behavior_positive",
            "valid_complete_behavior_development_negative": (
                "closed_consumed_valid_complete_behavior_development_negative"
            ),
            "invalid_or_incomplete_no_behavioral_conclusion": (
                "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
            ),
        }[str(outcome["classification"])],
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "campaign_id": "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME",
        "campaign_role": "development_route_ghost",
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_physical_campaign_closure"),
        "source_commit": report["source_commit"],
        "stage_commit": graph["stage_commit"],
        "authority_commit": graph["authority_commit"],
        "closure_audit_commit": graph["closure_audit_commit"],
        "authority_sha256": report["authority_sha256"],
        "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "superseded_physical_supervisor_refusal_sha256": (
            EXPECTED_SUPERVISOR_REFUSAL_SHA256
        ),
        "consumed_predecessor_physical_closure_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "attempt_id": report["attempt_id"],
        "classification": outcome["classification"],
        "route_execution_valid": outcome["route_execution_valid"],
        "evidence_valid": outcome["evidence_valid"],
        "outcome_complete": outcome["outcome_complete"],
        "behavior_passed": behavior,
        "scientific_outcome": outcome["scientific_outcome"],
        "false_route_receipts": list(outcome["false_route_receipts"]),
        "arm_projections": dict(outcome["arm_projections"]),
        "precondition_pair_barrier": dict(outcome["precondition_pair_barrier"]),
        "precondition_terminal_dispositions": dict(
            outcome["precondition_terminal_dispositions"]
        ),
        "failure_code": report["failure_code"],
        "evidence_bindings": dict(bindings),
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "campaign_attempt_count": 1,
        "maximum_campaign_attempt_count": 1,
        "world_attempt_count": report["world_attempt_count"],
        "world_build_count": report["world_build_count"],
        "solver_step_count": report["solver_step_count"],
        "event_triggered_passive_recovery_observed": behavior,
        "continuous_same_body_recovery_resume_observed": behavior,
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "held_out_finite_decision_declared": False,
        "held_out_finite_decision_authorized": False,
        "distinct_held_out_successor_may_be_declared": behavior,
        "sdk1_m07_satisfied": False,
        "q_sdk_r10_satisfied": False,
        "r10e_l3_finite_negative_preserved": True,
        "r172_exact_nominal_positive_preserved": True,
        "r173_three_engine_prone_to_standing_preserved": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def synthetic_arm(arm_id: str, *, behavior: bool) -> dict[str, Any]:
    body = "sha256:" + ("a" if arm_id == ACTIVE_ARM else "b") * 64
    model = "active-model" if arm_id == ACTIVE_ARM else "baseline-model"
    row = {
        "schema_version": "sporespore_qsdk_r10f_compact_native_trace_row_v1",
        "arm_id": arm_id,
        "global_semantic_step": 1,
        "body_population_instance_sha256": body,
    }
    counter_projection = {
        "schema_version": (
            "sporespore_qsdk_r10f_collection_solver_counter_projection_v1"
        ),
        "gate_id": "QSDK-R10F",
        "ok": True,
        "global_semantic_step": 1,
        "cumulative_solver_step_count": 1,
        "retained_global_cumulative_solver_step_count": 1,
        "completed_step_delta": 1,
        "source_counter_semantics": (
            "cumulative_completed_global_solver_step_sequence"
        ),
        "aggregate_counter_semantics": "one_delta_per_accepted_arm_collection",
        "retained_global_collector_unchanged": True,
        "source_measurement": True,
        "outcome_derived_correction": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    counter_predicates = {
        "collector_cumulative_solver_step_exact": True,
        "collector_global_counter_binding_exact": True,
        "accepted_collection_step_delta_exact": True,
        "collector_counter_outcome_correction_zero": True,
    }
    invariant = {
        "schema_version": "sporespore_qsdk_r10f_in_run_native_invariant_v1",
        "arm_id": arm_id,
        "global_semantic_step": 1,
        "body_population_instance_sha256": body,
        "solver_counter_projection": counter_projection,
        "predicates": counter_predicates,
        "all_in_run_physical_invariants_passed": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    row_two = dict(row)
    row_two["global_semantic_step"] = 2
    counter_projection_two = dict(counter_projection)
    counter_projection_two["global_semantic_step"] = 2
    counter_projection_two["cumulative_solver_step_count"] = 2
    counter_projection_two["retained_global_cumulative_solver_step_count"] = 2
    invariant_two = json.loads(json.dumps(invariant))
    invariant_two["global_semantic_step"] = 2
    invariant_two["solver_counter_projection"] = counter_projection_two
    return {
        "schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_arm_result_v1",
        "gate_id": "QSDK-R10F",
        "ok": True,
        "arm_id": arm_id,
        "model_instance_id": model,
        "body_population_instance_sha256": body,
        "initial_same_body_identity_receipt": {"body_population_instance_sha256": body},
        "initial_application_validation_receipt": {
            "schema_version": (
                "sporespore_qsdk_r10f_initial_bootstrap_application_validation_v1"
            ),
            "gate_id": "QSDK-R10F",
            "ok": True,
            "check_count": 11,
            "failed_checks": [],
            "observed_application_schema": (
                "sporespore_qsdk_r24d57_godot_application_intent_v1"
            ),
            "expected_application_schema": (
                "sporespore_qsdk_r24d57_godot_application_intent_v1"
            ),
            "active_application_validator_applicable": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "scene_tree_insertion_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "terminal_same_body_identity_receipt": {
            "body_population_instance_sha256": body
        },
        "same_body_identity_preserved": True,
        "trace": {
            "schema_version": "sporespore_qsdk_r10f_compact_native_trace_v1",
            "gate_id": "QSDK-R10F",
            "arm_id": arm_id,
            "model_instance_id": model,
            "body_population_instance_sha256": body,
            "rows": [row, row_two],
        },
        "trace_sha256": "sha256:" + "c" * 64,
        "outer_step_count": 2,
        "native_solver_step_count": 2,
        "in_run_invariant_receipts": [invariant, invariant_two],
        "in_run_invariant_receipt_count": 2,
        "all_in_run_physical_invariants_passed": True,
        "final_phase": "complete" if behavior else "failed",
        "terminal_reason": "complete" if behavior else "synthetic_negative",
        "external_kick_application_count": 1 if arm_id == ACTIVE_ARM else 0,
        "body_population_rebuild_count": 0,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "solver_reset_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def synthetic_pair_barrier(
    arm_results: Mapping[str, dict[str, Any]], attempt_id: str
) -> tuple[dict[str, Any], dict[str, Any]]:
    source_by_arm: dict[str, dict[str, Any]] = {}
    source_sha_by_arm: dict[str, str] = {}
    model_by_arm = {
        arm_id: str(arm_results[arm_id]["model_instance_id"]) for arm_id in ARM_IDS
    }
    for arm_id in ARM_IDS:
        classification = {
            "schema_version": "synthetic_stance_classification_v1",
            "arm_id": arm_id,
            "stable_stance_gate": True,
            "source_measurement": True,
        }
        step_receipt = {
            "schema_version": "synthetic_recovery_terminal_step_v1",
            "arm_id": arm_id,
            "global_semantic_step": 1,
            "next_phase": "complete",
            "memory": {"phase": "complete", "last_semantic_step": 1},
            "classification": classification,
        }
        source = {
            "schema_version": PAIR_TERMINAL_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": PAIR_REPAIR_ID,
            "barrier_id": PAIR_BARRIER_ID,
            "attempt_id": attempt_id,
            "arm_id": arm_id,
            "model_instance_id": model_by_arm[arm_id],
            "global_semantic_step": 1,
            "recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v6"
            ),
            "terminal_phase": "complete",
            "stable_four_foot_stance": True,
            "terminal_step_receipt": step_receipt,
            "terminal_step_receipt_sha256": payload_sha256_v1(step_receipt),
            "terminal_classification": classification,
            "terminal_classification_sha256": payload_sha256_v1(classification),
            "source_measurement": True,
            "outcome_derived_readiness": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "scene_tree_insertion_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "payload_sha256": "",
        }
        source["payload_sha256"] = payload_sha256_v1(source)
        source_by_arm[arm_id] = source
        source_sha_by_arm[arm_id] = source["payload_sha256"]
    plan_sha = "sha256:" + "a" * 64
    plan = {
        "schema_version": PAIR_PLAN_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": PAIR_REPAIR_ID,
        "barrier_id": PAIR_BARRIER_ID,
        "attempt_id": attempt_id,
        "completed_global_semantic_step": 1,
        "planned_global_semantic_step": 2,
        "ordered_arm_ids": ARM_ORDER,
        "action_by_arm": {arm_id: ACTION_RELEASE for arm_id in ARM_IDS},
        "ready_by_arm": {arm_id: True for arm_id in ARM_IDS},
        "terminal_source_sha256_by_arm": dict(source_sha_by_arm),
        "state_before_sha256": "sha256:" + "b" * 64,
        "common_solver_frame_required": True,
        "world_pause_or_step_skip_permitted": False,
        "motors_enabled_for_wait_or_release_permitted": False,
        "outcome_derived_readiness": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": plan_sha,
    }
    application_sha_by_arm: dict[str, str] = {}
    evidence: dict[str, Any] = {}
    for index, arm_id in enumerate(ARM_IDS):
        configured_rows = [
            {
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0,
            }
            for joint_id in JOINT_IDS
        ]
        native_rows = [
            {
                "actuator_id": actuator_id,
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0,
                "motor_maximum_impulse_nms": 0.5,
            }
            for joint_id, actuator_id in zip(JOINT_IDS, ACTUATOR_IDS)
        ]
        projected_rows = [
            {
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0,
            }
            for joint_id in JOINT_IDS
        ]
        configuration = {
            "schema_version": (
                "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
            ),
            "gate_id": "QSDK-R10F",
            "ok": True,
            "global_semantic_step": 2,
            "reason": "synthetic_l6_release_motors_disabled",
            "motor_enabled": False,
            "ordered_joint_receipts": configured_rows,
            "motor_configuration_write_count": 16,
            "body_transform_write_count": 0,
            "body_velocity_write_count": 0,
            "body_impulse_write_count": 0,
            "solver_reset_count": 0,
            "physics_state_modified": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        readback = {
            "schema_version": (
                "sporespore_qsdk_r10f_recovery_native_motor_population_readback_v1"
            ),
            "gate_id": "QSDK-R10F",
            "ok": True,
            "global_semantic_step": 2,
            "reason": "synthetic_l6_release_pre_solver_readback",
            "expected_motor_enabled": False,
            "ordered_joint_readbacks": native_rows,
            "motor_enabled_count": 0,
            "zero_target_velocity_count": 8,
            "native_readback_count": 24,
            "body_transform_write_count": 0,
            "body_velocity_write_count": 0,
            "body_impulse_write_count": 0,
            "solver_reset_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        readback_sha = "sha256:" + "c" * 64
        ledger = {
            "schema_version": NO_ACTUATION_LEDGER_SCHEMA,
            "gate_id": "QSDK-R10F",
            "ok": True,
            "semantic_step": 2,
            "phase": "canonical_prone_precondition_recovery",
            "controller_owner": "none",
            "recovery_controller_id": None,
            "no_actuation_requested": True,
            "motor_enabled_count": 0,
            "native_joint_motors_disabled": True,
            "owner_source_receipt": plan,
            "owner_source_receipt_sha256": plan_sha,
            "motor_population_readback": readback,
            "motor_population_readback_sha256": readback_sha,
            "force_aware_recovery_used": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        application_sha = "sha256:" + ("d" if index == 0 else "e") * 64
        application = {
            "schema_version": PAIR_APPLICATION_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": PAIR_REPAIR_ID,
            "ok": True,
            "attempt_id": attempt_id,
            "arm_id": arm_id,
            "model_instance_id": model_by_arm[arm_id],
            "global_semantic_step": 2,
            "action_kind": ACTION_RELEASE,
            "terminal_source_sha256": source_sha_by_arm[arm_id],
            "pair_plan_receipt": plan,
            "pair_plan_receipt_sha256": plan_sha,
            "motor_configuration_receipt": configuration,
            "motor_configuration_receipt_sha256": "sha256:" + "f" * 64,
            "motor_population_readback": readback,
            "motor_population_readback_sha256": readback_sha,
            "ledger_application_intent": ledger,
            "ledger_application_intent_sha256": "sha256:" + "1" * 64,
            "ordered_motor_readbacks": projected_rows,
            "control_owner": "none",
            "actuation_owner": "none",
            "no_actuation_requested": True,
            "source_measurement": True,
            "outcome_derived_readiness": False,
            "body_transform_write_count": 0,
            "body_velocity_write_count": 0,
            "solver_reset_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "payload_sha256": application_sha,
        }
        application_sha_by_arm[arm_id] = application_sha
        arm_results[arm_id].update(
            {
                "precondition_terminal_source": source_by_arm[arm_id],
                "precondition_terminal_source_sha256": source_sha_by_arm[arm_id],
                "precondition_pair_barrier_application_projections": [application],
                "precondition_pair_barrier_application_projection_count": 1,
                "precondition_pair_barrier_wait_application_count": 0,
                "precondition_pair_barrier_release_application_count": 1,
                "precondition_pair_barrier_retention_valid": True,
            }
        )
        evidence[arm_id] = {
            "precondition_terminal_source": source_by_arm[arm_id],
            "precondition_terminal_source_sha256": source_sha_by_arm[arm_id],
            "precondition_pair_barrier_application_projections": [application],
            "precondition_pair_barrier_application_projection_count": 1,
        }
    state_sha = "sha256:" + "2" * 64
    state = {
        "schema_version": PAIR_STATE_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": PAIR_REPAIR_ID,
        "barrier_id": PAIR_BARRIER_ID,
        "attempt_id": attempt_id,
        "model_instance_id_by_arm": model_by_arm,
        "ready_by_arm": {arm_id: True for arm_id in ARM_IDS},
        "terminal_source_by_arm": source_by_arm,
        "terminal_source_sha256_by_arm": source_sha_by_arm,
        "terminal_global_step_by_arm": {arm_id: 1 for arm_id in ARM_IDS},
        "planned_global_semantic_step": 2,
        "planned_action_by_arm": {arm_id: ACTION_RELEASE for arm_id in ARM_IDS},
        "planned_action_completed_by_arm": {arm_id: True for arm_id in ARM_IDS},
        "planned_application_sha256_by_arm": application_sha_by_arm,
        "current_plan": plan,
        "current_plan_sha256": plan_sha,
        "last_completed_global_semantic_step": 2,
        "completed_wait_step_count_by_arm": {arm_id: 0 for arm_id in ARM_IDS},
        "release_planned_global_step": 2,
        "release_completed_global_step": 2,
        "released": True,
        "state_revision": 8,
        "source_measurement": True,
        "outcome_derived_readiness": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": state_sha,
    }
    return state, evidence


def synthetic_disposition_pair_state(
    *,
    attempt_id: str,
    model_by_arm: Mapping[str, str],
    source_by_arm: Mapping[str, dict[str, Any] | None],
    global_semantic_step: int = 1,
) -> dict[str, Any]:
    require(
        bounded_int(global_semantic_step, 1, 1200),
        "SYNTHETIC_DISPOSITION_GLOBAL_STEP",
    )
    ready = {arm_id: source_by_arm[arm_id] is not None for arm_id in ARM_IDS}
    source_steps = {
        arm_id: (
            int(source_by_arm[arm_id]["global_semantic_step"])
            if source_by_arm[arm_id] is not None
            else None
        )
        for arm_id in ARM_IDS
    }
    actions = {
        arm_id: (
            ACTION_RECOVERY
            if global_semantic_step == 1 or not ready[arm_id]
            else ACTION_WAIT
        )
        for arm_id in ARM_IDS
    }
    current_plan: dict[str, Any] | None = None
    if global_semantic_step > 1:
        current_plan = {
            "schema_version": PAIR_PLAN_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": PAIR_REPAIR_ID,
            "barrier_id": PAIR_BARRIER_ID,
            "attempt_id": attempt_id,
            "completed_global_semantic_step": global_semantic_step - 1,
            "planned_global_semantic_step": global_semantic_step,
            "ordered_arm_ids": ARM_ORDER,
            "ready_by_arm": ready,
            "terminal_source_sha256_by_arm": {
                arm_id: (
                    str(source_by_arm[arm_id]["payload_sha256"])
                    if source_by_arm[arm_id] is not None
                    else ""
                )
                for arm_id in ARM_IDS
            },
            "action_by_arm": actions,
            "common_solver_frame_required": True,
            "world_pause_or_step_skip_permitted": False,
            "motors_enabled_for_wait_or_release_permitted": False,
            "state_before_sha256": "sha256:" + "5" * 64,
            "outcome_derived_readiness": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "payload_sha256": "",
        }
        current_plan["payload_sha256"] = payload_sha256_v1(current_plan)
    state = {
        "schema_version": PAIR_STATE_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": PAIR_REPAIR_ID,
        "barrier_id": PAIR_BARRIER_ID,
        "attempt_id": attempt_id,
        "model_instance_id_by_arm": dict(model_by_arm),
        "ready_by_arm": ready,
        "terminal_source_by_arm": dict(source_by_arm),
        "terminal_source_sha256_by_arm": {
            arm_id: (
                str(source_by_arm[arm_id]["payload_sha256"])
                if source_by_arm[arm_id] is not None
                else ""
            )
            for arm_id in ARM_IDS
        },
        "terminal_global_step_by_arm": source_steps,
        "planned_global_semantic_step": global_semantic_step,
        "planned_action_by_arm": actions,
        "planned_action_completed_by_arm": {arm_id: True for arm_id in ARM_IDS},
        "planned_application_sha256_by_arm": {
            arm_id: "sha256:" + ("6" if arm_id == ACTIVE_ARM else "7") * 64
            for arm_id in ARM_IDS
        },
        "current_plan": current_plan,
        "current_plan_sha256": (
            str(current_plan["payload_sha256"]) if current_plan is not None else ""
        ),
        "last_completed_global_semantic_step": global_semantic_step,
        "completed_wait_step_count_by_arm": {
            arm_id: (
                global_semantic_step - int(source_steps[arm_id]) if ready[arm_id] else 0
            )
            for arm_id in ARM_IDS
        },
        "release_planned_global_step": None,
        "release_completed_global_step": None,
        "released": False,
        "state_revision": global_semantic_step * len(ARM_IDS),
        "source_measurement": True,
        "outcome_derived_readiness": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    state["payload_sha256"] = payload_sha256_v1(state)
    return state


def synthetic_disposition(
    *,
    state: Mapping[str, Any],
    arm_id: str,
    disposition: str,
    recovery_phase: str,
    recovery_failure: str,
) -> dict[str, Any]:
    complete = disposition == DISPOSITION_COMPLETE
    route_terminal = disposition in FAILURE_DISPOSITIONS
    recovery_terminal = recovery_phase in {"complete", "failed", "refused"}
    global_step = int(state["last_completed_global_semantic_step"])
    source = state["terminal_source_by_arm"][arm_id]
    recovery_step = (
        int(source["global_semantic_step"])
        if complete and isinstance(source, dict)
        else global_step
    )
    classification = {
        "schema_version": "synthetic_stance_classification_v1",
        "arm_id": arm_id,
        "stable_stance_gate": complete,
        "source_measurement": True,
    }
    memory = {"phase": recovery_phase, "last_semantic_step": recovery_step}
    step = {
        "schema_version": "synthetic_recovery_terminal_step_v1",
        "arm_id": arm_id,
        "global_semantic_step": recovery_step,
        "next_phase": recovery_phase,
        "memory": memory,
        "classification": classification,
    }
    terminal_sources = state["terminal_source_sha256_by_arm"]
    receipt = {
        "schema_version": DISPOSITION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": DISPOSITION_REPAIR_ID,
        "attempt_id": state["attempt_id"],
        "arm_id": arm_id,
        "model_instance_id": state["model_instance_id_by_arm"][arm_id],
        "global_semantic_step": global_step,
        "disposition": disposition,
        "orchestrator_phase": FAILED_PHASE if route_terminal else PRECONDITION_PHASE,
        "route_terminal": route_terminal,
        "route_terminal_reason": recovery_failure if route_terminal else "",
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "recovery_terminal": recovery_terminal,
        "recovery_terminal_phase": recovery_phase if recovery_terminal else "",
        "recovery_terminal_failure_code": recovery_failure,
        "recovery_step_global_semantic_step": recovery_step,
        "recovery_memory": memory,
        "recovery_memory_sha256": canonical_sha256_v1(memory),
        "recovery_step_receipt": step,
        "recovery_step_receipt_sha256": canonical_sha256_v1(step),
        "recovery_classification": classification,
        "recovery_classification_sha256": canonical_sha256_v1(classification),
        "pair_ready": state["ready_by_arm"][arm_id],
        "pair_terminal_source_sha256": terminal_sources[arm_id],
        "pair_state_sha256": state["payload_sha256"],
        "source_measurement": True,
        "outcome_derived_correction": False,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "solver_reset_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    if complete:
        require(isinstance(source, dict), f"SYNTHETIC_COMPLETE_SOURCE_{arm_id}")
        receipt["recovery_memory"] = source["terminal_step_receipt"]["memory"]
        receipt["recovery_step_receipt"] = source["terminal_step_receipt"]
        receipt["recovery_classification"] = source["terminal_classification"]
        receipt["recovery_memory_sha256"] = canonical_sha256_v1(
            receipt["recovery_memory"]
        )
        receipt["recovery_step_receipt_sha256"] = canonical_sha256_v1(
            receipt["recovery_step_receipt"]
        )
        receipt["recovery_classification_sha256"] = canonical_sha256_v1(
            receipt["recovery_classification"]
        )
    receipt["payload_sha256"] = payload_sha256_v1(receipt)
    return receipt


def synthetic_disposition_population(
    state: Mapping[str, Any], dispositions: Mapping[str, dict[str, Any]]
) -> dict[str, Any]:
    global_step = int(state["last_completed_global_semantic_step"])
    expected_solver_steps = global_step * len(ARM_IDS)
    shas = {arm_id: dispositions[arm_id]["payload_sha256"] for arm_id in ARM_ORDER}
    failing = [
        arm_id
        for arm_id in ARM_ORDER
        if dispositions[arm_id]["disposition"] in FAILURE_DISPOSITIONS
    ]
    failing_by_arm = {arm_id: dispositions[arm_id]["disposition"] for arm_id in failing}
    population = {
        "schema_version": ABORT_POPULATION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": DISPOSITION_REPAIR_ID,
        "attempt_id": state["attempt_id"],
        "failure_code": DISPOSITION_FAILURE_CODE,
        "global_semantic_step": global_step,
        "ordered_arm_ids": ARM_ORDER,
        "disposition_by_arm": dict(dispositions),
        "disposition_sha256_by_arm": shas,
        "failing_arm_ids": failing,
        "failing_disposition_by_arm": failing_by_arm,
        "pair_state_sha256": state["payload_sha256"],
        "retained_global_lockstep_solver_frame_count": global_step,
        "retained_worker_solver_step_count": expected_solver_steps,
        "expected_worker_solver_step_count_at_stop": expected_solver_steps,
        "post_failure_additional_solver_step_count": 0,
        "next_solver_step_permitted": False,
        "generic_terminal_frame_lockstep_failure_label_used": False,
        "nonfailing_peer_last_completed_state_retained": len(failing) < len(ARM_IDS),
        "independent_closure_validation_required": True,
        "summary_boolean_without_independent_validation": False,
        "source_measurement": True,
        "outcome_derived_correction": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    population["payload_sha256"] = payload_sha256_v1(population)
    return population


def synthetic_report(*, behavior: bool, valid: bool = True) -> dict[str, Any]:
    source = "1" * 40
    authority = "sha256:" + "2" * 64
    attempt = "3" * 32
    false_receipts = [] if behavior else ["synthetic_behavior_receipt"]
    arm_results = {
        arm_id: synthetic_arm(arm_id, behavior=behavior) for arm_id in ARM_IDS
    }
    pair_state, pair_evidence = synthetic_pair_barrier(arm_results, attempt)
    disposition_state = synthetic_disposition_pair_state(
        attempt_id=attempt,
        model_by_arm=pair_state["model_instance_id_by_arm"],
        source_by_arm=pair_state["terminal_source_by_arm"],
    )
    dispositions = {
        arm_id: synthetic_disposition(
            state=disposition_state,
            arm_id=arm_id,
            disposition=DISPOSITION_COMPLETE,
            recovery_phase="complete",
            recovery_failure="",
        )
        for arm_id in ARM_IDS
    }
    disposition_shas = {
        arm_id: dispositions[arm_id]["payload_sha256"] for arm_id in ARM_IDS
    }
    evaluation = {
        "schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_evaluation_v1",
        "gate_id": "QSDK-R10F",
        "ok": True,
        "evidence_valid": True,
        "outcome_complete": True,
        "behavior_passed": behavior,
        "route_receipts": {
            "precondition_pair_barrier_released_from_two_source_terminals": True
        },
        "false_route_receipts": false_receipts,
        "threshold_override_input_count": 0,
        "event_triggered_passive_recovery": True,
        "force_aware_recovery": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "sha256:" + "4" * 64,
        "interaction_pair_receipt_sha256": "sha256:" + "5" * 64,
        "precondition_pair_barrier_state_sha256": pair_state["payload_sha256"],
        "precondition_pair_barrier_released": True,
        "precondition_pair_barrier_release_global_step": 2,
    }
    raw = {
        "schema_version": RAW_SCHEMA,
        "gate_id": "QSDK-R10F",
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_physical_development_raw"),
        "status": "valid_complete_behavior_development",
        "ok": True,
        "scientific_outcome": "positive" if behavior else "negative",
        "source_commit": source,
        "authorization_sha256": authority,
        "attempt_id": attempt,
        "seed": SEED,
        "seed_sha256": SEED_SHA256,
        "held_out": False,
        "held_out_cell_access_count": 0,
        "population_inference_claimed": False,
        "physics_failure_is_valid_evidence": True,
        "precondition_pair_barrier_state": pair_state,
        "precondition_pair_barrier_state_sha256": pair_state["payload_sha256"],
        "precondition_pair_barrier_state_valid": True,
        "precondition_pair_barrier_released": True,
        "precondition_pair_barrier_evidence_by_arm": pair_evidence,
        "precondition_terminal_disposition_by_arm": dispositions,
        "precondition_terminal_disposition_sha256_by_arm": disposition_shas,
        "precondition_terminal_disposition_pair_state": disposition_state,
        "precondition_terminal_disposition_pair_state_sha256": disposition_state[
            "payload_sha256"
        ],
        "precondition_terminal_disposition_population_valid": True,
        "route_evaluation": evaluation,
        "arm_results": arm_results,
        "model_construction_attempt_count": 2,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "complete_trace_count": 2,
        "behavior_evaluator_invocation_count": 1,
        "in_run_invariant_receipt_count": 4,
        "all_in_run_physical_invariants_passed": True,
        "same_body_identity_preserved": True,
        "solver_step_count": 4,
        "maximum_solver_step_count": 7684,
        "global_lockstep_solver_frame_count": 2,
        "external_kick_application_count": 1,
        "physical_question_opened": True,
        "physics_state_modified": True,
        "event_triggered_passive_recovery_observed": behavior,
        "recovery_success_observed": behavior,
        "prone_to_standing_claimed": behavior,
        "kick_impulse_alone_causes_fall_claimed": False,
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "arbitrary_fall_recovery_claimed": False,
        "cross_engine_push_recovery_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if valid:
        return {
            "schema_version": SUPERVISOR_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": REPAIR_ID,
            "campaign_id": (
                "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
            ),
            "campaign_role": "development_route_ghost",
            "question_class": "development",
            "ledger_scope": ledger_scope("consumed_physical_campaign_report"),
            "ok": True,
            "status": "valid_complete_behavior_development",
            "scientific_outcome": "positive" if behavior else "negative",
            "failure_code": "",
            "source_commit": source,
            "authority_sha256": authority,
            "consumed_predecessor_physical_closure_sha256": (
                EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
            ),
            "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
            "attempt_id": attempt,
            "attempt_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "maximum_campaign_attempt_count": 1,
            "raw_marker_valid": True,
            "route_execution_valid": True,
            "behavior_passed": behavior,
            "count_fields_known": True,
            "model_construction_count": 2,
            "world_attempt_count": 2,
            "world_build_count": 2,
            "solver_step_count": 4,
            "worker_receipt": raw,
            "termination": {
                "termination_protocol_valid": True,
                "exit_code": 0,
                "timed_out": False,
            },
            "engine_health": {"passed": True},
            "evidence_root": "C:/synthetic",
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    failure_state = synthetic_disposition_pair_state(
        attempt_id=attempt,
        model_by_arm=pair_state["model_instance_id_by_arm"],
        source_by_arm={arm_id: None for arm_id in ARM_IDS},
    )
    failure_dispositions = {
        ACTIVE_ARM: synthetic_disposition(
            state=failure_state,
            arm_id=ACTIVE_ARM,
            disposition=DISPOSITION_FAILED,
            recovery_phase="failed",
            recovery_failure="SYNTHETIC_PRECONDITION_FAILED",
        ),
        BASELINE_ARM: synthetic_disposition(
            state=failure_state,
            arm_id=BASELINE_ARM,
            disposition=DISPOSITION_NONTERMINAL,
            recovery_phase="establish_distal_support",
            recovery_failure="",
        ),
    }
    failure_shas = {
        arm_id: failure_dispositions[arm_id]["payload_sha256"] for arm_id in ARM_IDS
    }
    abort_population = synthetic_disposition_population(
        failure_state, failure_dispositions
    )
    invalid_raw = {
        "schema_version": RAW_SCHEMA,
        "gate_id": "QSDK-R10F",
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_physical_development_raw"),
        "status": "invalid_or_incomplete_behavior_development",
        "ok": False,
        "failure_code": DISPOSITION_FAILURE_CODE,
        "detail": {
            "ok": False,
            "failure_code": DISPOSITION_FAILURE_CODE,
            "failing_arm_ids": [ACTIVE_ARM],
            "precondition_terminal_abort_population": abort_population,
            "precondition_terminal_abort_population_sha256": abort_population[
                "payload_sha256"
            ],
        },
        "source_commit": source,
        "authorization_sha256": authority,
        "attempt_id": attempt,
        "seed": SEED,
        "seed_sha256": SEED_SHA256,
        "held_out": False,
        "held_out_cell_access_count": 0,
        "population_inference_claimed": False,
        "recovery_success_required_for_valid_result": False,
        "physics_failure_is_valid_evidence": True,
        "precondition_pair_barrier_state": failure_state,
        "precondition_pair_barrier_state_sha256": failure_state["payload_sha256"],
        "precondition_pair_barrier_state_valid": True,
        "precondition_pair_barrier_released": False,
        "precondition_pair_barrier_evidence_by_arm": {arm_id: {} for arm_id in ARM_IDS},
        "precondition_terminal_disposition_by_arm": failure_dispositions,
        "precondition_terminal_disposition_sha256_by_arm": failure_shas,
        "precondition_terminal_disposition_pair_state": failure_state,
        "precondition_terminal_disposition_pair_state_sha256": failure_state[
            "payload_sha256"
        ],
        "precondition_terminal_disposition_population_valid": True,
        "precondition_terminal_abort_population": abort_population,
        "precondition_terminal_abort_population_sha256": abort_population[
            "payload_sha256"
        ],
        "precondition_terminal_abort_population_valid": True,
        "behavior_evaluator_invocation_count": 0,
        "model_construction_attempt_count": 2,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": 2,
        "maximum_solver_step_count": 7684,
        "global_lockstep_solver_frame_count": 1,
        "external_kick_application_count": 0,
        "explicit_worker_extra_native_readback_count": 0,
        "physical_question_opened": True,
        "physics_state_modified": True,
        "event_triggered_passive_recovery_observed": False,
        "recovery_success_observed": False,
        "prone_to_standing_claimed": False,
        "kick_impulse_alone_causes_fall_claimed": False,
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "arbitrary_fall_recovery_claimed": False,
        "cross_engine_push_recovery_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    return {
        "schema_version": SUPERVISOR_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "campaign_id": "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME",
        "campaign_role": "development_route_ghost",
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_physical_campaign_report"),
        "ok": False,
        "status": "invalid_or_incomplete_behavior_development",
        "scientific_outcome": "none",
        "failure_code": DISPOSITION_FAILURE_CODE,
        "source_commit": source,
        "authority_sha256": authority,
        "consumed_predecessor_physical_closure_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "attempt_id": attempt,
        "attempt_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "maximum_campaign_attempt_count": 1,
        "raw_marker_valid": True,
        "route_execution_valid": False,
        "behavior_passed": False,
        "count_fields_known": True,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": 2,
        "worker_receipt": invalid_raw,
        "termination": {
            "termination_protocol_valid": True,
            "exit_code": 1,
            "timed_out": False,
        },
        "engine_health": {"passed": True},
        "evidence_root": "C:/synthetic",
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def synthetic_waiting_peer_invalid_report() -> dict[str, Any]:
    """Exercise a retained peer wait and its exact native-readback projection."""

    report = synthetic_report(behavior=False, valid=False)
    raw = report["worker_receipt"]
    attempt_id = str(report["attempt_id"])
    arm_results = {arm_id: synthetic_arm(arm_id, behavior=False) for arm_id in ARM_IDS}
    released_state, _ = synthetic_pair_barrier(arm_results, attempt_id)
    source_by_arm = {
        ACTIVE_ARM: None,
        BASELINE_ARM: released_state["terminal_source_by_arm"][BASELINE_ARM],
    }
    failure_state = synthetic_disposition_pair_state(
        attempt_id=attempt_id,
        model_by_arm=released_state["model_instance_id_by_arm"],
        source_by_arm=source_by_arm,
        global_semantic_step=2,
    )
    dispositions = {
        ACTIVE_ARM: synthetic_disposition(
            state=failure_state,
            arm_id=ACTIVE_ARM,
            disposition=DISPOSITION_FAILED,
            recovery_phase="failed",
            recovery_failure="SYNTHETIC_PRECONDITION_FAILED_AFTER_PEER_WAIT",
        ),
        BASELINE_ARM: synthetic_disposition(
            state=failure_state,
            arm_id=BASELINE_ARM,
            disposition=DISPOSITION_COMPLETE,
            recovery_phase="complete",
            recovery_failure="",
        ),
    }
    disposition_shas = {
        arm_id: dispositions[arm_id]["payload_sha256"] for arm_id in ARM_IDS
    }
    abort_population = synthetic_disposition_population(failure_state, dispositions)
    expected_readbacks = len(JOINT_IDS) * 3
    raw.update(
        {
            "detail": {
                "ok": False,
                "failure_code": DISPOSITION_FAILURE_CODE,
                "failing_arm_ids": [ACTIVE_ARM],
                "precondition_terminal_abort_population": abort_population,
                "precondition_terminal_abort_population_sha256": abort_population[
                    "payload_sha256"
                ],
            },
            "precondition_pair_barrier_state": failure_state,
            "precondition_pair_barrier_state_sha256": failure_state["payload_sha256"],
            "precondition_terminal_disposition_by_arm": dispositions,
            "precondition_terminal_disposition_sha256_by_arm": disposition_shas,
            "precondition_terminal_disposition_pair_state": failure_state,
            "precondition_terminal_disposition_pair_state_sha256": failure_state[
                "payload_sha256"
            ],
            "precondition_terminal_abort_population": abort_population,
            "precondition_terminal_abort_population_sha256": abort_population[
                "payload_sha256"
            ],
            "solver_step_count": 4,
            "global_lockstep_solver_frame_count": 2,
            "explicit_worker_extra_native_readback_count": expected_readbacks,
        }
    )
    report["solver_step_count"] = 4
    return report


def synthetic_generic_invalid_report() -> dict[str, Any]:
    report = synthetic_report(behavior=False, valid=False)
    report.update(
        {
            "failure_code": "SYNTHETIC_INFRASTRUCTURE_FAILURE",
            "raw_marker_valid": False,
            "count_fields_known": False,
            "model_construction_count": -1,
            "world_attempt_count": -1,
            "world_build_count": -1,
            "solver_step_count": -1,
            "worker_receipt": None,
            "termination": {
                "termination_protocol_valid": False,
                "exit_code": 124,
                "timed_out": True,
            },
            "engine_health": {"passed": False},
        }
    )
    return report


def synthetic_disposition_build_invalid_report() -> dict[str, Any]:
    report = synthetic_report(behavior=False, valid=False)
    raw = report["worker_receipt"]
    receipt = raw["precondition_terminal_disposition_by_arm"][BASELINE_ARM]
    receipt["recovery_memory"]["last_semantic_step"] = 1.0
    receipt["recovery_memory_sha256"] = canonical_sha256_v1(receipt["recovery_memory"])
    receipt["recovery_step_receipt_sha256"] = canonical_sha256_v1(
        receipt["recovery_step_receipt"]
    )
    receipt["payload_sha256"] = payload_sha256_v1(receipt)
    build = {
        "schema_version": DISPOSITION_BUILD_FAILURE_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": DISPOSITION_REPAIR_ID,
        "ok": False,
        "failure_code": DISPOSITION_BUILD_INNER_FAILURE_CODE,
        "detail": {"receipt": receipt},
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    raw.update(
        {
            "failure_code": DISPOSITION_BUILD_OUTER_FAILURE_CODE,
            "detail": {
                "ok": False,
                "failure_code": DISPOSITION_BUILD_OUTER_FAILURE_CODE,
                "arm_id": BASELINE_ARM,
                "build": build,
            },
            "precondition_terminal_disposition_by_arm": {},
            "precondition_terminal_disposition_sha256_by_arm": {
                arm_id: "" for arm_id in ARM_IDS
            },
            "precondition_terminal_disposition_pair_state": {},
            "precondition_terminal_disposition_pair_state_sha256": "",
            "precondition_terminal_disposition_population_valid": False,
            "precondition_terminal_abort_population": {},
            "precondition_terminal_abort_population_sha256": "",
            "precondition_terminal_abort_population_valid": False,
        }
    )
    report["failure_code"] = DISPOSITION_BUILD_OUTER_FAILURE_CODE
    return report


def self_test() -> dict[str, Any]:
    fixtures = [
        synthetic_report(behavior=True),
        synthetic_report(behavior=False),
        synthetic_report(behavior=False, valid=False),
        synthetic_generic_invalid_report(),
        synthetic_disposition_build_invalid_report(),
        synthetic_waiting_peer_invalid_report(),
    ]
    outcomes = [
        validate_report(value, report_path=None, verify_files=False)
        for value in fixtures
    ]
    require(
        [value["classification"] for value in outcomes]
        == [
            "valid_complete_behavior_positive",
            "valid_complete_behavior_development_negative",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
        ],
        "SELF_TEST_CLASSIFICATIONS",
    )
    waiting_peer_projection = outcomes[-1]["precondition_terminal_dispositions"]
    require(
        waiting_peer_projection["global_semantic_step"] == 2
        and waiting_peer_projection["completed_wait_step_count_by_arm"]
        == {ACTIVE_ARM: 0, BASELINE_ARM: 1}
        and waiting_peer_projection["expected_worker_extra_native_readback_count"]
        == len(JOINT_IDS) * 3,
        "SELF_TEST_WAITING_PEER_NATIVE_READBACK_PROJECTION",
    )
    numeric_domain_positive_count = sum(
        1
        for value, source_value, expected in (
            (1, 1, 1),
            (1.0, 1.0, 1),
            (3842, 3842, 3842),
            (3842.0, 3842.0, 3842),
        )
        if integer_valued_native_step_matches(value, source_value, expected)
    )
    require(numeric_domain_positive_count == 4, "SELF_TEST_NATIVE_STEP_POSITIVES")
    numeric_domain_rejected = sum(
        1
        for value, source_value, expected in (
            (1.5, 1.5, 1),
            (float("nan"), float("nan"), 1),
            (float("inf"), float("inf"), 1),
            (float("-inf"), float("-inf"), 1),
            (0, 0, 1),
            (-1, -1, 1),
            (3843, 3843, 3843),
            (2.0, 2.0, 1),
            (True, True, 1),
            ("1", "1", 1),
            (None, None, 1),
            (1.0, 1.0, 0),
            (3842.0, 3842.0, 3843),
            (1, 1.0, 1),
            (1.0, 1, 1),
        )
        if not integer_valued_native_step_matches(value, source_value, expected)
    )
    require(numeric_domain_rejected == 15, "SELF_TEST_NATIVE_STEP_REJECTIONS")
    rejected = numeric_domain_rejected
    report_rejected = 0
    for fixture_index, path, changed in (
        (0, ("repair_id",), "QSDK-R10F"),
        (0, ("attempt_identity_consumed",), False),
        (0, ("same_identity_rerun_permitted",), True),
        (
            0,
            ("consumed_predecessor_physical_closure_sha256",),
            "sha256:" + "9" * 64,
        ),
        (0, ("repair_design_sha256",), "sha256:" + "9" * 64),
        (0, ("maximum_campaign_attempt_count",), 2),
        (0, ("route_execution_valid",), False),
        (0, ("scientific_outcome",), "negative"),
        (0, ("worker_receipt", "world_attempt_count"), 3),
        (0, ("worker_receipt", "solver_step_count"), 3),
        (0, ("worker_receipt", "force_aware_recovery"), True),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "initial_application_validation_receipt",
                "active_application_validator_applicable",
            ),
            True,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "body_transform_write_count",
            ),
            1,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "in_run_invariant_receipts",
                0,
                "solver_counter_projection",
                "cumulative_solver_step_count",
            ),
            2,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "in_run_invariant_receipts",
                0,
                "solver_counter_projection",
                "completed_step_delta",
            ),
            2,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "in_run_invariant_receipts",
                0,
                "predicates",
                "collector_global_counter_binding_exact",
            ),
            False,
        ),
        (
            0,
            (
                "worker_receipt",
                "route_evaluation",
                "threshold_override_input_count",
            ),
            1,
        ),
        (1, ("worker_receipt", "route_evaluation", "false_route_receipts"), []),
        (0, ("worker_receipt", "precondition_pair_barrier_state", "released"), False),
        (
            0,
            (
                "worker_receipt",
                "precondition_pair_barrier_state",
                "terminal_source_by_arm",
                ACTIVE_ARM,
                "stable_four_foot_stance",
            ),
            False,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "precondition_pair_barrier_application_projections",
                0,
                "motor_configuration_receipt",
                "ordered_joint_receipts",
                0,
                "motor_enabled",
            ),
            True,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "precondition_pair_barrier_application_projections",
                0,
                "motor_population_readback",
                "ordered_joint_readbacks",
                0,
                "motor_maximum_impulse_nms",
            ),
            0,
        ),
        (
            0,
            (
                "worker_receipt",
                "arm_results",
                ACTIVE_ARM,
                "precondition_pair_barrier_application_projections",
                0,
                "ledger_application_intent",
                "force_aware_recovery_used",
            ),
            True,
        ),
        (
            0,
            (
                "worker_receipt",
                "precondition_pair_barrier_evidence_by_arm",
                ACTIVE_ARM,
                "precondition_pair_barrier_application_projection_count",
            ),
            2,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
            ),
            None,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                BASELINE_ARM,
            ),
            None,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "arm_id",
            ),
            BASELINE_ARM,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "global_semantic_step",
            ),
            2,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "disposition",
            ),
            "unknown",
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "recovery_terminal_failure_code",
            ),
            "",
        ),
        (
            0,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "recovery_terminal_failure_code",
            ),
            "SYNTHETIC_UNEXPECTED_FAILURE",
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "recovery_step_receipt_sha256",
            ),
            "sha256:" + "9" * 64,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "recovery_memory",
                "last_semantic_step",
            ),
            0,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "recovery_classification_sha256",
            ),
            "sha256:" + "9" * 64,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "pair_state_sha256",
            ),
            "sha256:" + "9" * 64,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "pair_ready",
            ),
            True,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_by_arm",
                ACTIVE_ARM,
                "outcome_derived_correction",
            ),
            True,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_abort_population",
                "generic_terminal_frame_lockstep_failure_label_used",
            ),
            True,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_abort_population",
                "post_failure_additional_solver_step_count",
            ),
            1,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_abort_population",
                "summary_boolean_without_independent_validation",
            ),
            True,
        ),
        (
            2,
            (
                "worker_receipt",
                "precondition_terminal_disposition_pair_state",
                "planned_action_completed_by_arm",
                ACTIVE_ARM,
            ),
            False,
        ),
        (
            2,
            ("worker_receipt", "explicit_worker_extra_native_readback_count"),
            1,
        ),
        (2, ("worker_receipt", "detail", "failing_arm_ids"), []),
        (2, ("termination", "exit_code"), 0),
        (2, ("failure_code",), ""),
        (4, ("failure_code",), ""),
        (
            4,
            ("worker_receipt", "failure_code"),
            "SYNTHETIC_UNRELATED_FAILURE",
        ),
        (4, ("worker_receipt", "detail", "arm_id"), ACTIVE_ARM),
        (
            4,
            ("worker_receipt", "detail", "build", "failure_code"),
            "SYNTHETIC_INNER_FAILURE",
        ),
        (
            4,
            (
                "worker_receipt",
                "detail",
                "build",
                "detail",
                "receipt",
                "recovery_memory",
                "last_semantic_step",
            ),
            1,
        ),
        (
            4,
            (
                "worker_receipt",
                "detail",
                "build",
                "detail",
                "receipt",
                "recovery_step_global_semantic_step",
            ),
            2,
        ),
        (
            4,
            ("worker_receipt", "precondition_terminal_disposition_population_valid"),
            True,
        ),
        (4, ("worker_receipt", "solver_step_count"), 4),
        (4, ("termination", "exit_code"), 0),
        (
            4,
            (
                "worker_receipt",
                "detail",
                "build",
                "detail",
                "receipt",
                "payload_sha256",
            ),
            "sha256:" + "9" * 64,
        ),
    ):
        mutation = json.loads(json.dumps(fixtures[fixture_index]))
        target: Any = mutation
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = changed
        try:
            validate_report(mutation, report_path=None, verify_files=False)
        except ClosureFailure:
            rejected += 1
            report_rejected += 1
    require(report_rejected == 55, "SELF_TEST_REPORT_MUTATION_REJECTIONS")
    require(rejected == 70, "SELF_TEST_MUTATION_REJECTIONS")
    return {
        "schema_version": "sporespore_qsdk_r10f_physical_closure_self_test_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": ledger_scope("zero_world_physical_closure_self_test"),
        "ok": True,
        "synthetic_report_control_count": len(fixtures),
        "integer_valued_native_step_positive_control_count": (
            numeric_domain_positive_count
        ),
        "integer_valued_native_step_mutation_rejection_count": (
            numeric_domain_rejected
        ),
        "report_mutation_rejection_count": report_rejected,
        "mutation_rejection_count": rejected,
        "classifications": [value["classification"] for value in outcomes],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def vector3(value: Any, code: str) -> tuple[float, float, float]:
    require(
        isinstance(value, list)
        and len(value) == 3
        and all(finite_number(component) for component in value),
        code,
    )
    return tuple(float(component) for component in value)  # type: ignore[return-value]


def vector_norm(value: tuple[float, float, float]) -> float:
    return math.sqrt(sum(component * component for component in value))


def vector_subtract(
    left: tuple[float, float, float], right: tuple[float, float, float]
) -> tuple[float, float, float]:
    return tuple(left[index] - right[index] for index in range(3))  # type: ignore[return-value]


def vector_close(
    left: tuple[float, float, float],
    right: tuple[float, float, float],
    allowance: float,
) -> bool:
    return all(abs(left[index] - right[index]) <= allowance for index in range(3))


def parse_utc_timestamp(value: Any, code: str) -> datetime:
    require(isinstance(value, str) and bool(value), code)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ClosureFailure(code) from exc
    require(parsed.tzinfo is not None, code)
    return parsed.astimezone(timezone.utc)


def l9_source_policy() -> dict[str, Any]:
    manifest = read_json(MANIFEST_PATH, "L14_MANIFEST")
    policy = manifest.get("policy")
    require(
        manifest.get("schema_version")
        == "sporespore_qsdk_r10f_dependency_manifest_v19"
        and manifest.get("status")
        == "prospective_complete_transitive_source_closure_zero_world"
        and manifest.get("gate_id") == "QSDK-R10F"
        and manifest.get("repair_id") == REPAIR_ID
        and isinstance(policy, dict)
        and bounded_int(policy.get("expected_qualified_source_count"), 1, 1000)
        and is_sha256(policy.get("expected_qualified_source_path_sha256")),
        "L14_MANIFEST_POLICY",
    )
    return {
        "count": policy["expected_qualified_source_count"],
        "digest": policy["expected_qualified_source_path_sha256"],
    }


def verify_l9_binding(
    binding: Any,
    path: Path,
    code: str,
    *,
    relative_to: Path | None = None,
) -> dict[str, Any]:
    require(isinstance(binding, dict), f"{code}_NOT_OBJECT")
    expected = file_identity(path, relative_to=relative_to)
    require(
        binding.get("path") == expected["path"]
        and exact_int(binding.get("byte_length"), expected["byte_length"])
        and binding.get("raw_sha256") == expected["raw_sha256"],
        f"{code}_IDENTITY",
    )
    return expected


def validate_l9_repair_design(source_commit: str) -> dict[str, Any]:
    design = read_json(REPAIR_DESIGN_PATH, "L11_REPAIR_DESIGN")
    change = design.get("controlled_change")
    frozen = design.get("frozen_behavioral_terms")
    population = design.get("prospective_development_population")
    positives = design.get("required_positive_zero_world_controls")
    negatives = design.get("required_negative_zero_world_controls")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    authorities_value = design.get("bound_authorities")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES
        and sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256
        and design.get("schema_version")
        == "sporespore_qsdk_r10f_l11_precondition_release_owner_source_successor_design_v1"
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == "QSDK-R10F-L10"
        and design.get("design_id")
        == "QSDK-R10F-L11-PRECONDITION-RELEASE-OWNER-SOURCE-PROJECTION"
        and isinstance(authorities_value, list)
        and len(authorities_value) == 5
        and isinstance(change, dict)
        and change.get("change_class")
        == "precondition_release_no_actuation_owner_source_representation_only"
        and change.get("mechanism")
        == "precondition_release_owner_source_projection_v1"
        and change.get("source_contract")
        == "a fully validated complete precondition terminal receipt"
        and change.get("full_terminal_receipt_retained_without_mutation") is True
        and change.get("full_recovery_step_receipt_retained_without_mutation") is True
        and change.get("terminal_and_step_digests_revalidated") is True
        and change.get("broad_no_actuation_outcome_guard_changed") is False
        and change.get("release_receipt_schema_advanced_to_l11") is True
        and change.get("release_receipt_key_set_changed") is False
        and change.get("terminal_receipt_schema_changed") is False
        and change.get("interaction_source_schema_changed") is False
        and change.get("canonical_digest_policy_changed") is False
        and change.get("body_transform_or_velocity_write_permitted") is False
        and change.get("solver_reset_permitted") is False
        and change.get("process_isolation_changed") is False
        and change.get("child_order_changed") is False
        and change.get("threshold_changed") is False
        and change.get("controller_changed") is False
        and change.get("selected_policy_changed") is False
        and change.get("behavior_evaluator_terms_changed") is False
        and change.get("outcome_derived_correction") is False
        and isinstance(frozen, dict)
        and frozen.get("ordered_child_roles") == ARM_ORDER
        and frozen.get("one_world_per_child_process") is True
        and frozen.get("one_arm_per_child_process") is True
        and frozen.get("child_processes_overlap_in_wall_clock_time") is False
        and exact_int(frozen.get("maximum_child_process_count"), 2)
        and exact_int(frozen.get("maximum_world_count_per_child"), 1)
        and exact_int(frozen.get("maximum_total_world_count"), 2)
        and exact_int(frozen.get("maximum_solver_steps_per_child"), 3842)
        and exact_int(frozen.get("maximum_total_solver_steps"), 7684)
        and frozen.get("force_aware_recovery") is False
        and frozen.get("force_aware_bracing") is False
        and isinstance(population, dict)
        and exact_int(population.get("maximum_campaign_attempt_count"), 1)
        and exact_int(population.get("maximum_child_process_count"), 2)
        and exact_int(population.get("maximum_total_world_build_count"), 2)
        and exact_int(population.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(population.get("maximum_total_solver_step_count"), 7684)
        and population.get("both_child_reports_required_for_any_pair_outcome") is True
        and population.get(
            "any_invalid_or_incomplete_child_forces_no_behavioral_conclusion"
        )
        is True
        and isinstance(positives, list)
        and len(positives) == len(set(positives)) == 7
        and isinstance(negatives, list)
        and len(negatives) == len(set(negatives)) == 15
        and isinstance(claim, dict)
        and claim.get("zero_world_implementation_authorized") is True
        and claim.get("physical_execution_authorized") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(decision, dict)
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == "precondition_release_no_actuation_owner_source_projection",
        "L11_REPAIR_DESIGN_FIELDS",
    )
    authorities = {
        value.get("role"): value
        for value in authorities_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        set(authorities)
        == {
            "consumed_l10_physical_closure",
            "l10_nullable_terminal_failure_design",
            "observed_l10_worker_source",
            "observed_l10_child_contract_source",
            "observed_l10_no_actuation_ledger_source",
        },
        "L11_REPAIR_DESIGN_AUTHORITY_SET",
    )
    consumed = authorities["consumed_l10_physical_closure"]
    require(
        consumed.get("path")
        == PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        and exact_int(
            consumed.get("byte_length"), EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        )
        and consumed.get("raw_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "L11_REPAIR_DESIGN_PREDECESSOR_BINDING",
    )
    predecessor_design = authorities["l10_nullable_terminal_failure_design"]
    require(
        predecessor_design.get("path")
        == PREDECESSOR_REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        and exact_int(
            predecessor_design.get("byte_length"),
            EXPECTED_PREDECESSOR_REPAIR_DESIGN_BYTES,
        )
        and predecessor_design.get("raw_sha256")
        == EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256,
        "L11_REPAIR_DESIGN_PARENT_BINDING",
    )
    for role, relative, expected_blob in (
        (
            "observed_l10_worker_source",
            "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
            "ea48b5cf80caf5d1c3cca8b161f19a64641732ca",
        ),
        (
            "observed_l10_child_contract_source",
            "sdk/adapters/godot/gdscript/"
            "qsdk_r10f_process_isolated_child_contract_v1.gd",
            "9638c5739980860789dadc27f370649d87013c44",
        ),
        (
            "observed_l10_no_actuation_ledger_source",
            "sdk/adapters/godot/gdscript/"
            "qsdk_r10f_recovery_native_locomotion_facade_v1.gd",
            "2615ba0921675fecaeff0f9d59c7cf392a8b3e13",
        ),
    ):
        observed = authorities[role]
        historical_commit = observed.get("source_commit")
        require(
            observed.get("path") == relative
            and historical_commit
            == "3a3203d2cd1f85d5f401bf12dc094398dbe02354"
            and observed.get("git_blob_oid") == expected_blob
            and git("rev-parse", f"{historical_commit}:{relative}") == expected_blob,
            f"L11_REPAIR_DESIGN_{role.upper()}_HISTORICAL_IDENTITY",
        )
    retained = design.get("retained_l10_result")
    diagnosis = design.get("retained_diagnosis")
    require(
        isinstance(retained, dict)
        and retained.get("attempt_id") == "f141e4523d6b44ee9cb80ec054788780"
        and retained.get("source_commit")
        == "3a3203d2cd1f85d5f401bf12dc094398dbe02354"
        and retained.get("observed_child_process_count") == 1
        and retained.get("world_attempt_count") == 1
        and retained.get("world_build_count") == 1
        and retained.get("solver_step_count") == 240
        and retained.get("external_kick_application_count") == 0
        and retained.get("behavior_evaluator_invocation_count") == 0
        and retained.get("route_execution_valid") is False
        and retained.get("scientific_outcome") == "none"
        and retained.get("same_identity_rerun_permitted") is False
        and isinstance(diagnosis, dict)
        and diagnosis.get("first_child_outer_failure_code")
        == "QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID"
        and diagnosis.get("first_child_inner_failure_code")
        == "QSDK_R10F_NO_ACTUATION_LEDGER_INPUT_INVALID"
        and diagnosis.get("retained_owner_source_has_forbidden_top_level_key")
        == "physical_result"
        and diagnosis.get("broad_outcome_guard_correctly_refused_runtime_source")
        is True
        and diagnosis.get("runtime_source_was_not_malformed") is True
        and diagnosis.get("runtime_source_was_too_broad_for_the_no_actuation_ledger_role")
        is True
        and diagnosis.get("l10_nullable_terminal_failure_projection_passed_runtime_boundary")
        is True
        and diagnosis.get("precondition_release_receipt_built") is False
        and diagnosis.get("behavior_question_reached") is False
        and diagnosis.get("scientific_outcome") == "none",
        "L11_REPAIR_DESIGN_RETAINED_DIAGNOSIS",
    )
    relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(REPAIR_DESIGN_PATH)),
        "L11_REPAIR_DESIGN_SOURCE_BLOB",
    )
    binding = file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": design["status"],
            "repair_id": REPAIR_ID,
            "change_class": (
                "precondition_release_no_actuation_owner_source_representation_only"
            ),
            "bound_authority_count": 5,
            "positive_control_count": 7,
            "mutation_rejection_count": 15,
            "maximum_child_process_count": 2,
            "maximum_world_count_per_child": 1,
            "maximum_total_world_count": 2,
            "maximum_solver_steps_per_child": 3842,
            "maximum_total_solver_steps": 7684,
            "full_terminal_receipt_retained_without_mutation": True,
            "full_recovery_step_receipt_retained_without_mutation": True,
            "broad_no_actuation_outcome_guard_changed": False,
            "release_receipt_schema_advanced_to_l11": True,
            "physical_execution_authorized_by_design": False,
        }
    )
    return binding


def _validate_l12_repair_design_retired(source_commit: str) -> dict[str, Any]:
    """Bind the immutable L12 walking-actuation handoff successor design."""
    design = read_json(REPAIR_DESIGN_PATH, "L12_REPAIR_DESIGN")
    authorities_value = design.get("bound_authorities")
    change = design.get("controlled_change")
    frozen = design.get("frozen_behavioral_terms")
    population = design.get("prospective_development_population")
    positives = design.get("required_positive_zero_world_controls")
    negatives = design.get("required_negative_zero_world_controls")
    retained = design.get("retained_l11_result")
    release = design.get("retained_l11_release_boundary")
    diagnosis = design.get("retained_diagnosis")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES
        and sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256
        and design.get("schema_version")
        == "sporespore_qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1"
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == RELEASE_REPAIR_ID
        and design.get("design_id")
        == "QSDK-R10F-L12-WALKING-ACTUATION-OWNERSHIP-HANDOFF"
        and isinstance(authorities_value, list)
        and len(authorities_value) == 8
        and isinstance(change, dict)
        and change.get("change_class")
        == "r10f_walking_actuation_ownership_handoff_and_existing_host_cap_binding_only"
        and change.get("mechanism") == "walking_actuation_ownership_handoff_v1"
        and change.get("covered_evaluation_segments")
        == ["walking_prefix", "matched_continuation", "walking_resume"]
        and exact_int(change.get("motor_enable_write_count_per_fresh_session"), 8)
        and exact_int(change.get("zero_target_write_count_per_fresh_session"), 8)
        and exact_int(change.get("handoff_solver_step_count"), 0)
        and change.get("existing_complete_override_interface_used") is True
        and change.get("extra_solver_step_inserted") is False
        and change.get("release_step_changed") is False
        and change.get("release_motors_disabled_invariant_changed") is False
        and change.get("shared_adapter_enable_behavior_changed") is False
        and change.get("shared_adapter_cap_resolution_behavior_changed") is False
        and change.get("published_actuator_profile_changed") is False
        and change.get("selected_host_cap_changed_from_r69") is False
        and change.get("new_tolerance_or_margin_added") is False
        and change.get("raw_measurement_clamped") is False
        and change.get("threshold_changed") is False
        and change.get("controller_changed") is False
        and change.get("selected_policy_changed") is False
        and change.get("outcome_derived_correction") is False
        and isinstance(frozen, dict)
        and frozen.get("ordered_child_roles") == ARM_ORDER
        and frozen.get("one_arm_per_child_process") is True
        and frozen.get("one_world_per_child_process") is True
        and frozen.get("child_processes_overlap_in_wall_clock_time") is False
        and exact_int(frozen.get("maximum_child_process_count"), 2)
        and exact_int(frozen.get("maximum_world_count_per_child"), 1)
        and exact_int(frozen.get("maximum_total_world_count"), 2)
        and exact_int(frozen.get("maximum_solver_steps_per_child"), 3842)
        and exact_int(frozen.get("maximum_total_solver_steps"), 7684)
        and frozen.get("force_aware_recovery") is False
        and frozen.get("force_aware_bracing") is False
        and isinstance(population, dict)
        and exact_int(population.get("maximum_campaign_attempt_count"), 1)
        and exact_int(population.get("maximum_child_process_count"), 2)
        and exact_int(population.get("maximum_total_world_build_count"), 2)
        and exact_int(population.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(population.get("maximum_total_solver_step_count"), 7684)
        and population.get("both_child_reports_required_for_any_pair_outcome") is True
        and population.get(
            "any_invalid_or_incomplete_child_forces_no_behavioral_conclusion"
        )
        is True
        and isinstance(positives, list)
        and len(positives) == len(set(positives)) == 13
        and isinstance(negatives, list)
        and len(negatives) == len(set(negatives)) == 19
        and isinstance(retained, dict)
        and retained.get("attempt_id") == "977175976c09461c9fac94dd23e6ab21"
        and retained.get("first_child_attempt_id")
        == "7bae4d8af5484fcabe27bd7e3e60c427"
        and retained.get("source_commit")
        == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and retained.get("stage_commit")
        == "487584fc851bf6825e7c7de919e6c777fa71215b"
        and retained.get("authority_commit")
        == "f0fb74e29d1064ade3d817933d7835ca4927998c"
        and retained.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and retained.get("first_child_inner_failure_code")
        == "QSDK_R10F_LOCOMOTION_MOTOR_READBACK_INVALID:front_left_hip"
        and exact_int(retained.get("solver_step_count"), 241)
        and exact_int(retained.get("external_kick_application_count"), 0)
        and retained.get("route_execution_valid") is False
        and retained.get("scientific_outcome") == "none"
        and retained.get("physical_identity_consumed") is True
        and retained.get("same_identity_rerun_permitted") is False
        and isinstance(release, dict)
        and exact_int(release.get("completed_precondition_terminal_step"), 240)
        and exact_int(release.get("release_step"), 241)
        and exact_int(release.get("release_configuration_write_count"), 16)
        and exact_int(release.get("release_native_readback_count"), 24)
        and exact_int(release.get("released_motor_count"), 8)
        and exact_int(release.get("released_motor_enabled_count"), 0)
        and exact_int(release.get("released_zero_target_velocity_count"), 8)
        and release.get("l11_release_owner_projection_passed_runtime_boundary") is True
        and release.get("release_step_completed_in_the_same_world") is True
        and isinstance(diagnosis, dict)
        and diagnosis.get("walking_facade_session_start_reached") is True
        and diagnosis.get("first_selected_policy_command_planning_reached") is True
        and diagnosis.get("first_walking_solver_step_completed") is False
        and diagnosis.get("release_left_all_motor_flags_disabled") is True
        and diagnosis.get("walking_session_start_enables_motor_flags") is False
        and diagnosis.get("live_host_caps_exactly_match_qualified_r69_selected_host_caps")
        is True
        and diagnosis.get("host_cap_composition_gap_kind")
        == (
            "deterministic_static_and_qualified_projection_mismatch_"
            "not_a_second_observed_physical_failure"
        )
        and isinstance(claim, dict)
        and claim.get("zero_world_implementation_authorized") is True
        and claim.get("physical_execution_authorized") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(decision, dict)
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == (
            "r10f_walking_actuation_ownership_handoff_"
            "with_qualified_host_cap_binding"
        ),
        "L12_REPAIR_DESIGN_FIELDS",
    )
    authorities = {
        value.get("role"): value
        for value in authorities_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        set(authorities)
        == {
            "consumed_l11_physical_closure",
            "l11_release_owner_projection_design",
            "qualified_r69_host_cap_projection_contract",
            "qualified_r69_zero_world_projection_population",
            "observed_l11_worker_source",
            "observed_l11_locomotion_facade_source",
            "observed_l11_shared_walking_adapter_source",
            "observed_l11_recovery_world_host_cap_source",
        },
        "L12_REPAIR_DESIGN_BOUND_AUTHORITY_SET",
    )
    for role, bound_path in (
        ("consumed_l11_physical_closure", PREDECESSOR_PHYSICAL_CLOSURE_PATH),
        ("l11_release_owner_projection_design", PREDECESSOR_REPAIR_DESIGN_PATH),
        (
            "qualified_r69_host_cap_projection_contract",
            ROOT
            / "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json",
        ),
        (
            "qualified_r69_zero_world_projection_population",
            ROOT
            / (
                "sdk/recovery/r24d69_godot_native_effective_impulse_limit_"
                "zero_world_qualification_closure_v1.json"
            ),
        ),
    ):
        declared = authorities[role]
        require(
            declared.get("path") == bound_path.relative_to(ROOT).as_posix()
            and declared.get("byte_length") == bound_path.stat().st_size
            and declared.get("raw_sha256") == sha256_file(bound_path)
            and declared.get("git_blob_oid") == git("hash-object", str(bound_path)),
            f"L12_REPAIR_DESIGN_{role.upper()}_IDENTITY",
        )
    historical_commit = "02f7b554a29ed80ad55d9d21930f23a267c07273"
    historical = {
        "observed_l11_worker_source": (
            "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
            "5c13fb1c50b1aa24d0e63456c6dd6bdacce86015",
        ),
        "observed_l11_locomotion_facade_source": (
            "sdk/adapters/godot/gdscript/"
            "qsdk_r10f_recovery_native_locomotion_facade_v1.gd",
            "2615ba0921675fecaeff0f9d59c7cf392a8b3e13",
        ),
        "observed_l11_shared_walking_adapter_source": (
            "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
            "ef793ede82d63ee266ee815f2b0dd19866ef9596",
        ),
        "observed_l11_recovery_world_host_cap_source": (
            "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
            "c418010d7dd22baf00af8ad6f4cd9f0b870957f0",
        ),
    }
    for role, (relative, expected_blob) in historical.items():
        declared = authorities[role]
        require(
            declared.get("path") == relative
            and declared.get("source_commit") == historical_commit
            and declared.get("git_blob_oid") == expected_blob
            and git("rev-parse", f"{historical_commit}:{relative}") == expected_blob,
            f"L12_REPAIR_DESIGN_{role.upper()}_HISTORICAL_IDENTITY",
        )
    relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(REPAIR_DESIGN_PATH)),
        "L12_REPAIR_DESIGN_SOURCE_BLOB",
    )
    binding = file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": design["status"],
            "repair_id": REPAIR_ID,
            "change_class": (
                "r10f_walking_actuation_ownership_handoff_"
                "and_existing_host_cap_binding_only"
            ),
            "bound_authority_count": 8,
            "positive_control_count": 13,
            "mutation_rejection_count": 19,
            "walking_actuation_handoff_positive_control_count": 5,
            "walking_actuation_handoff_mutation_rejection_count": 22,
            "qualified_r69_projection_count": 8,
            "maximum_child_process_count": 2,
            "maximum_world_count_per_child": 1,
            "maximum_total_world_count": 2,
            "maximum_solver_steps_per_child": 3842,
            "maximum_total_solver_steps": 7684,
            "existing_complete_override_interface_used": True,
            "shared_adapter_enable_behavior_changed": False,
            "published_actuator_profile_changed": False,
            "extra_solver_step_inserted": False,
            "l11_release_receipt_preserved": True,
            "physical_execution_authorized_by_design": False,
        }
    )
    return binding


def _validate_l13_repair_design_retired(source_commit: str) -> dict[str, Any]:
    """Bind the immutable L13 transport/projection design to physical closure."""
    design = read_json(REPAIR_DESIGN_PATH, "L13_REPAIR_DESIGN")
    authorities_value = design.get("bound_authorities")
    change = design.get("controlled_change")
    transport = change.get("native_step_transport_verification", {}) if isinstance(change, dict) else {}
    projection = change.get("host_target_projection", {}) if isinstance(change, dict) else {}
    ledger = change.get("walking_ledger_successor", {}) if isinstance(change, dict) else {}
    retention = change.get("partial_child_failure_retention", {}) if isinstance(change, dict) else {}
    frozen = design.get("frozen_behavioral_terms")
    population = design.get("prospective_development_population")
    positives = design.get("required_positive_zero_world_controls")
    negatives = design.get("required_negative_zero_world_controls")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES
        and sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256
        and design.get("schema_version")
        == (
            "sporespore_qsdk_r10f_l13_walking_ledger_transport_projection_"
            "successor_design_v1"
        )
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == HANDOFF_REPAIR_ID
        and design.get("design_id")
        == "QSDK-R10F-L13-WALKING-LEDGER-TRANSPORT-AND-HOST-TARGET-PROJECTION"
        and design.get("authored_parent_commit")
        == "d5c48a02835af1c8aa7185d90d685f2714fbe512"
        and isinstance(authorities_value, list)
        and len(authorities_value) == 12
        and isinstance(change, dict)
        and change.get("change_class")
        == (
            "walking_ledger_transport_verification_host_target_projection_"
            "and_failure_retention_only"
        )
        and isinstance(transport, dict)
        and transport.get("new_receipt_schema")
        == NATIVE_TRANSPORT_VERIFICATION_SCHEMA
        and transport.get("raw_native_response_rewritten") is False
        and transport.get("controller_receipt_digest_removed") is False
        and transport.get("native_controller_receipt_digest_remains_bound") is True
        and isinstance(projection, dict)
        and projection.get("new_projection_schema") == HOST_TARGET_PROJECTION_SCHEMA
        and projection.get("projection_rule")
        == "float(PackedFloat32Array([controller_target_velocity_rad_s])[0])"
        and projection.get("projection_kind")
        == "deterministic_host_representation_not_empirical_correction"
        and exact_int(projection.get("ordered_actuator_count"), 8)
        and projection.get("controller_binary64_target_retained_separately") is True
        and projection.get("expected_binary32_host_target_retained_separately")
        is True
        and projection.get("application_readback_must_equal_expected_binary32_exactly")
        is True
        and projection.get("population_readback_must_equal_expected_binary32_exactly")
        is True
        and projection.get("new_tolerance_or_margin_added") is False
        and projection.get("controller_command_rounded_before_write") is False
        and projection.get("host_write_changed") is False
        and projection.get("solver_input_changed") is False
        and isinstance(ledger, dict)
        and ledger.get("new_application_schema") == WALKING_LEDGER_SCHEMA
        and ledger.get("named_predicate_receipt_required") is True
        and ledger.get("failed_predicate_ids_retained") is True
        and ledger.get("source_receipts_retained_on_failure") is True
        and isinstance(retention, dict)
        and all(value is True for value in retention.values())
        and change.get("shared_adapter_motor_enable_behavior_changed") is False
        and change.get("published_actuator_profile_changed") is False
        and change.get("selected_host_cap_changed_from_r69") is False
        and change.get("threshold_changed") is False
        and change.get("controller_changed") is False
        and change.get("physical_schedule_changed") is False
        and change.get("solver_budget_changed") is False
        and change.get("outcome_derived_correction") is False
        and isinstance(frozen, dict)
        and frozen.get("ordered_child_roles") == ARM_ORDER
        and frozen.get("one_arm_per_child_process") is True
        and frozen.get("one_world_per_child_process") is True
        and exact_int(frozen.get("maximum_child_process_count"), 2)
        and exact_int(frozen.get("maximum_world_count_per_child"), 1)
        and exact_int(frozen.get("maximum_total_world_count"), 2)
        and exact_int(frozen.get("maximum_solver_steps_per_child"), 3842)
        and exact_int(frozen.get("maximum_total_solver_steps"), 7684)
        and frozen.get("force_aware_recovery") is False
        and frozen.get("force_aware_bracing") is False
        and isinstance(population, dict)
        and exact_int(population.get("maximum_campaign_attempt_count"), 1)
        and exact_int(population.get("maximum_child_process_count"), 2)
        and exact_int(population.get("maximum_total_world_build_count"), 2)
        and exact_int(population.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(population.get("maximum_total_solver_step_count"), 7684)
        and population.get("both_child_reports_required_for_any_pair_outcome") is True
        and population.get(
            "any_invalid_or_incomplete_child_forces_no_behavioral_conclusion"
        )
        is True
        and isinstance(positives, list)
        and len(positives) == len(set(positives)) == 15
        and isinstance(negatives, list)
        and len(negatives) == len(set(negatives)) == 16
        and isinstance(claim, dict)
        and claim.get("l12_physical_identity_closed") is True
        and claim.get("l12_same_identity_rerun_permitted") is False
        and claim.get("l12_walking_handoff_crossed_runtime_boundary") is True
        and claim.get("l12_first_walking_solver_step_completed") is False
        and claim.get("zero_world_implementation_authorized") is True
        and claim.get("physical_execution_authorized") is False
        and claim.get("force_aware_recovery") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(decision, dict)
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == (
            "walking_ledger_native_transport_verification_binary32_host_target_"
            "projection_and_failure_retention"
        ),
        "L13_REPAIR_DESIGN_FIELDS",
    )
    authorities = {
        value.get("role"): value
        for value in authorities_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        set(authorities)
        == {
            "consumed_l12_physical_closure",
            "retrospective_l12_zero_world_diagnosis",
            "l12_walking_handoff_design",
            "observed_l12_locomotion_facade_source",
            "observed_l12_shared_walking_adapter_source",
            "observed_l12_process_isolated_worker_source",
            "observed_l12_zero_world_fixture_source",
            "current_godot_json_transport_source",
            "current_recovery_canonicalization_source",
            "current_godot_native_adapter_source",
            "current_native_ffi_source",
            "current_balanced_wave_runtime_source",
        },
        "L13_REPAIR_DESIGN_BOUND_AUTHORITY_SET",
    )
    authored_parent = str(design["authored_parent_commit"])
    for role, declared in authorities.items():
        declared_path = Path(str(declared.get("path", "")))
        if declared_path.is_absolute():
            require(
                role == "retrospective_l12_zero_world_diagnosis"
                and declared_path.is_file()
                and exact_int(declared.get("byte_length"), declared_path.stat().st_size)
                and declared.get("raw_sha256") == sha256_file(declared_path),
                f"L13_REPAIR_DESIGN_{role.upper()}_EXTERNAL_IDENTITY",
            )
            continue
        relative = declared_path.as_posix()
        historical_commit = str(declared.get("source_commit", authored_parent))
        blob = declared.get("git_blob_oid")
        require(
            relative
            and is_commit(historical_commit)
            and isinstance(blob, str)
            and re.fullmatch(r"[0-9a-f]{40}", blob) is not None
            and git("rev-parse", f"{historical_commit}:{relative}") == blob
            and exact_int(
                declared.get("byte_length", declared.get("checkout_byte_length")),
                int(git("cat-file", "-s", blob)),
            ),
            f"L13_REPAIR_DESIGN_{role.upper()}_HISTORICAL_IDENTITY",
        )
    relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(REPAIR_DESIGN_PATH)),
        "L13_REPAIR_DESIGN_SOURCE_BLOB",
    )
    binding = file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": design["status"],
            "repair_id": REPAIR_ID,
            "change_class": change["change_class"],
            "bound_authority_count": 12,
            "positive_control_count": 15,
            "mutation_rejection_group_count": 16,
            "walking_ledger_l13_positive_control_count": 15,
            "walking_ledger_l13_mutation_rejection_count": 16,
            "walking_ledger_failure_retention_positive_control_count": 1,
            "walking_ledger_failure_retention_mutation_rejection_count": 15,
            "production_shaped_walking_fixture_count": 3,
            "detached_hinge_parameter_container_count": 24,
            "binary32_host_target_projection_count": 8,
            "maximum_child_process_count": 2,
            "maximum_world_count_per_child": 1,
            "maximum_total_world_count": 2,
            "maximum_solver_steps_per_child": 3842,
            "maximum_total_solver_steps": 7684,
            "native_preparse_transport_verification_required": True,
            "named_predicate_receipt_required": True,
            "complete_failed_step_source_retention_required": True,
            "shared_adapter_enable_behavior_changed": False,
            "published_actuator_profile_changed": False,
            "extra_solver_step_inserted": False,
            "l12_walking_handoff_preserved": True,
            "force_aware_recovery": False,
            "physical_execution_authorized_by_design": False,
        }
    )
    return binding


def validate_l14_repair_design(source_commit: str) -> dict[str, Any]:
    try:
        return l14_authority.repair_design_binding(source_commit)
    except ValueError as exc:
        raise ClosureFailure(str(exc)) from exc


def validate_l14_predecessor_physical_closure(source_commit: str) -> dict[str, Any]:
    try:
        return l14_authority.predecessor_physical_closure_binding(source_commit)
    except ValueError as exc:
        raise ClosureFailure(str(exc)) from exc


def validate_l14_branch_completeness_addendum(source_commit: str) -> dict[str, Any]:
    try:
        return l14_authority.branch_completeness_addendum_binding(source_commit)
    except ValueError as exc:
        raise ClosureFailure(str(exc)) from exc


def validate_l9_predecessor_physical_closure(source_commit: str) -> dict[str, Any]:
    closure = read_json(PREDECESSOR_PHYSICAL_CLOSURE_PATH, "L10_PHYSICAL_CLOSURE")
    process = closure.get("process_isolation")
    bindings = closure.get("evidence_bindings")
    dispositions = closure.get("precondition_terminal_dispositions")
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v11"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L10"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit")
        == "3a3203d2cd1f85d5f401bf12dc094398dbe02354"
        and closure.get("stage_commit")
        == "f919697053cf01915e891daf75a076acb51b67e5"
        and closure.get("authority_commit")
        == "b811d813050546e78971c38279d4386e409ae351"
        and closure.get("closure_audit_commit")
        == "3a3203d2cd1f85d5f401bf12dc094398dbe02354"
        and closure.get("attempt_id") == "f141e4523d6b44ee9cb80ec054788780"
        and closure.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("measurement_complete") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("observed_child_process_count"), 1)
        and exact_int(closure.get("model_construction_attempt_count"), 1)
        and exact_int(closure.get("model_construction_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 1)
        and exact_int(closure.get("world_build_count"), 1)
        and exact_int(closure.get("solver_step_count"), 240)
        and isinstance(process, dict)
        and process.get("ordered_declared_child_roles") == ARM_ORDER
        and exact_int(process.get("declared_child_count"), 2)
        and exact_int(process.get("observed_child_count"), 1)
        and process.get("distinct_child_process_ids") is False
        and process.get("child_process_lifetimes_overlap") is None
        and process.get("child_retry_or_replacement_used") is False
        and closure.get("topology_validation_errors") == ["declared_child_missing"]
        and closure.get("child_validation_errors")
        == {BASELINE_ARM: f"L9_{BASELINE_ARM}_REPORT_FIELDS"}
        and isinstance(dispositions, dict)
        and dispositions.get("disposition_by_arm") == {}
        and dispositions.get("precondition_negative_roles") == []
        and dispositions.get("independent_population_validation_performed") is True
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("force_aware_recovery") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "L10_PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    expected_binding_keys = {
        "supervisor_result",
        "attempt_identity",
        "child_process_artifacts",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l10_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    }
    require(set(bindings) == expected_binding_keys, "L10_PREDECESSOR_BINDING_SET")

    def verify_predecessor_binding(declared: Any, code: str) -> None:
        require(isinstance(declared, dict), f"{code}_NOT_OBJECT")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = declared_path if declared_path.is_absolute() else ROOT / declared_path
        expected = file_identity(
            actual_path,
            relative_to=None if declared_path.is_absolute() else ROOT,
        )
        require(
            declared.get("path") == expected["path"]
            and declared.get("byte_length") == expected["byte_length"]
            and declared.get("raw_sha256") == expected["raw_sha256"],
            f"{code}_IDENTITY",
        )

    for key in sorted(expected_binding_keys - {"child_process_artifacts"}):
        declared = bindings[key]
        verify_predecessor_binding(declared, f"L10_PREDECESSOR_{key.upper()}")
    child_artifacts = bindings["child_process_artifacts"]
    require(
        isinstance(child_artifacts, dict)
        and set(child_artifacts) == {BASELINE_ARM},
        "L10_PREDECESSOR_CHILD_ARTIFACT_SET",
    )
    baseline_artifacts = child_artifacts[BASELINE_ARM]
    require(
        isinstance(baseline_artifacts, dict)
        and set(baseline_artifacts)
        == {
            "child_attempt_identity",
            "worker_stdout",
            "worker_stderr",
            "termination_receipt",
            "engine_health",
            "child_envelope",
            "worker_report",
        },
        "L10_PREDECESSOR_BASELINE_ARTIFACT_SET",
    )
    for key, declared in baseline_artifacts.items():
        verify_predecessor_binding(declared, f"L10_PREDECESSOR_CHILD_{key.upper()}")
    relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
        "L10_PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
    )
    binding = file_identity(PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": closure["status"],
            "repair_id": "QSDK-R10F-L10",
            "classification": closure["classification"],
            "attempt_id": closure["attempt_id"],
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "observed_child_process_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 240,
            "scientific_outcome": "none",
            "release_owner_source_failure_retained": True,
        }
    )
    return binding


def _validate_l12_predecessor_physical_closure_retired(
    source_commit: str,
) -> dict[str, Any]:
    """Reopen the immutable consumed L11 walking-handoff failure."""
    closure = read_json(PREDECESSOR_PHYSICAL_CLOSURE_PATH, "L11_PHYSICAL_CLOSURE")
    process = closure.get("process_isolation")
    dispositions = closure.get("precondition_terminal_dispositions")
    bindings = closure.get("evidence_bindings")
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v12"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == RELEASE_REPAIR_ID
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit")
        == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and closure.get("stage_commit")
        == "487584fc851bf6825e7c7de919e6c777fa71215b"
        and closure.get("authority_commit")
        == "f0fb74e29d1064ade3d817933d7835ca4927998c"
        and closure.get("closure_audit_commit")
        == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and closure.get("attempt_id") == "977175976c09461c9fac94dd23e6ab21"
        and closure.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("measurement_complete") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("observed_child_process_count"), 1)
        and exact_int(closure.get("model_construction_attempt_count"), 1)
        and exact_int(closure.get("model_construction_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 1)
        and exact_int(closure.get("world_build_count"), 1)
        and exact_int(closure.get("solver_step_count"), 241)
        and isinstance(process, dict)
        and process.get("ordered_declared_child_roles") == ARM_ORDER
        and exact_int(process.get("declared_child_count"), 2)
        and exact_int(process.get("observed_child_count"), 1)
        and process.get("distinct_child_process_ids") is False
        and process.get("child_process_lifetimes_overlap") is None
        and process.get("child_retry_or_replacement_used") is False
        and closure.get("topology_validation_errors") == ["declared_child_missing"]
        and closure.get("child_validation_errors")
        == {BASELINE_ARM: f"L9_{BASELINE_ARM}_REPORT_FIELDS"}
        and isinstance(dispositions, dict)
        and dispositions.get("disposition_by_arm") == {}
        and dispositions.get("precondition_negative_roles") == []
        and dispositions.get("independent_population_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("force_aware_recovery") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "L11_PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    expected_binding_keys = {
        "supervisor_result",
        "attempt_identity",
        "child_process_artifacts",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l11_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    }
    require(set(bindings) == expected_binding_keys, "L11_PREDECESSOR_BINDING_SET")

    def verify_predecessor_binding(declared: Any, code: str) -> None:
        require(isinstance(declared, dict), f"{code}_NOT_OBJECT")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = declared_path if declared_path.is_absolute() else ROOT / declared_path
        expected = file_identity(
            actual_path,
            relative_to=None if declared_path.is_absolute() else ROOT,
        )
        require(
            declared.get("path") == expected["path"]
            and declared.get("byte_length") == expected["byte_length"]
            and declared.get("raw_sha256") == expected["raw_sha256"],
            f"{code}_IDENTITY",
        )

    for key in sorted(expected_binding_keys - {"child_process_artifacts"}):
        verify_predecessor_binding(bindings[key], f"L11_PREDECESSOR_{key.upper()}")
    child_artifacts = bindings["child_process_artifacts"]
    require(
        isinstance(child_artifacts, dict) and set(child_artifacts) == {BASELINE_ARM},
        "L11_PREDECESSOR_CHILD_ARTIFACT_SET",
    )
    baseline_artifacts = child_artifacts[BASELINE_ARM]
    require(
        isinstance(baseline_artifacts, dict)
        and set(baseline_artifacts)
        == {
            "child_attempt_identity",
            "worker_stdout",
            "worker_stderr",
            "termination_receipt",
            "engine_health",
            "child_envelope",
            "worker_report",
        },
        "L11_PREDECESSOR_BASELINE_ARTIFACT_SET",
    )
    for key, declared in baseline_artifacts.items():
        verify_predecessor_binding(declared, f"L11_PREDECESSOR_CHILD_{key.upper()}")
    relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
        "L11_PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
    )
    binding = file_identity(PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": closure["status"],
            "repair_id": RELEASE_REPAIR_ID,
            "classification": closure["classification"],
            "attempt_id": closure["attempt_id"],
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "observed_child_process_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 241,
            "scientific_outcome": "none",
            "l11_release_step_completed": True,
            "walking_handoff_failure_retained": True,
        }
    )
    return binding


def validate_l13_predecessor_physical_closure(
    source_commit: str,
) -> dict[str, Any]:
    """Bind and reopen the consumed L12 walking-ledger closure."""
    closure = read_json(PREDECESSOR_PHYSICAL_CLOSURE_PATH, "L12_PHYSICAL_CLOSURE")
    process = closure.get("process_isolation")
    dispositions = closure.get("precondition_terminal_dispositions")
    bindings = closure.get("evidence_bindings")
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v13"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == HANDOFF_REPAIR_ID
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit")
        == "0d41c01a80985338aa411ee3049fcdab44a1e63c"
        and closure.get("stage_commit")
        == "6baeb8738e1b3103aca3900df3090dd2c60a1d67"
        and closure.get("authority_commit")
        == "c46bab9a10e1428799336fbcff8a056b05391682"
        and closure.get("closure_audit_commit")
        == "0d41c01a80985338aa411ee3049fcdab44a1e63c"
        and closure.get("attempt_id") == "72d2701413434ea5a611fe17a9fd7a89"
        and closure.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("measurement_complete") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("observed_child_process_count"), 1)
        and exact_int(closure.get("model_construction_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 1)
        and exact_int(closure.get("world_build_count"), 1)
        and exact_int(closure.get("solver_step_count"), 241)
        and exact_int(closure.get("explicit_worker_extra_native_readback_count"), 48)
        and isinstance(process, dict)
        and process.get("ordered_declared_child_roles") == ARM_ORDER
        and exact_int(process.get("declared_child_count"), 2)
        and exact_int(process.get("observed_child_count"), 1)
        and process.get("distinct_child_process_ids") is False
        and process.get("child_process_lifetimes_overlap") is None
        and process.get("one_arm_per_child_process") is False
        and process.get("one_world_per_child_process") is False
        and process.get("child_retry_or_replacement_used") is False
        and process.get("world_or_body_state_transferred_between_children") is False
        and closure.get("topology_validation_errors") == ["declared_child_missing"]
        and closure.get("child_validation_errors")
        == {
            BASELINE_ARM: "L9_matched_no_kick_continuation_REPORT_FIELDS",
        }
        and isinstance(dispositions, dict)
        and dispositions.get("disposition_by_arm") == {}
        and dispositions.get("precondition_negative_roles") == []
        and dispositions.get("independent_population_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("walking_actuation_handoff_observed") is False
        and exact_int(closure.get("walking_actuation_handoff_receipt_count"), 0)
        and exact_int(
            closure.get("walking_actuation_handoff_extra_solver_step_count"), 0
        )
        and closure.get("walking_actuation_handoff_outcome_derived_correction_used")
        is False
        and closure.get("shared_adapter_enable_behavior_changed") is False
        and closure.get("published_actuator_profile_changed") is False
        and closure.get("threshold_or_controller_changed") is False
        and closure.get("force_aware_recovery") is False
        and closure.get("force_aware_bracing") is False
        and closure.get("held_out_finite_decision_authorized") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "L13_PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    expected_binding_keys = {
        "supervisor_result",
        "attempt_identity",
        "child_process_artifacts",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l12_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    }
    require(set(bindings) == expected_binding_keys, "L13_PREDECESSOR_BINDING_SET")
    for key in sorted(expected_binding_keys - {"child_process_artifacts"}):
        declared = bindings[key]
        declared_path = Path(str(declared.get("path", "")))
        actual = declared_path if declared_path.is_absolute() else ROOT / declared_path
        verify_l9_binding(
            declared,
            actual,
            f"L13_PREDECESSOR_{key.upper()}",
            relative_to=None if declared_path.is_absolute() else ROOT,
        )
    child_artifacts = bindings["child_process_artifacts"]
    require(
        isinstance(child_artifacts, dict) and set(child_artifacts) == {BASELINE_ARM},
        "L13_PREDECESSOR_CHILD_ARTIFACT_SET",
    )
    baseline_artifacts = child_artifacts[BASELINE_ARM]
    require(
        isinstance(baseline_artifacts, dict)
        and set(baseline_artifacts)
        == {
            "child_attempt_identity",
            "worker_stdout",
            "worker_stderr",
            "termination_receipt",
            "engine_health",
            "child_envelope",
            "worker_report",
        },
        "L13_PREDECESSOR_BASELINE_ARTIFACT_SET",
    )
    for key, declared in baseline_artifacts.items():
        declared_path = Path(str(declared.get("path", "")))
        verify_l9_binding(
            declared,
            declared_path,
            f"L13_PREDECESSOR_CHILD_{key.upper()}",
        )
    relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
        "L13_PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
    )
    binding = file_identity(PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": closure["status"],
            "repair_id": HANDOFF_REPAIR_ID,
            "classification": closure["classification"],
            "attempt_id": closure["attempt_id"],
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "observed_child_process_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 241,
            "scientific_outcome": "none",
            "l12_walking_handoff_crossed_runtime_boundary": True,
            "l12_first_walking_solver_step_completed": False,
            "walking_ledger_identity_failure_retained": True,
        }
    )
    return binding


def select_l15_production_family() -> None:
    """Explicit CLI selection; imported historical readers remain L14 by default."""
    import qsdk_r10f_authority_materializer as materializer
    import qsdk_r10f_l15_launch_ownership_publication_successor_design as design

    globals().update({
        "REPAIR_ID": "QSDK-R10F-L15",
        "WORK_ID": "QSDK-R10F-L15-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT",
        "MANIFEST_PATH": ROOT / "sdk/qsdk_r10f_dependency_manifest_v20.json",
        "STAGE_PATH": ROOT / materializer.L15_STAGE_RELATIVE,
        "AUTHORITY_PATH": ROOT / materializer.L15_AUTHORITY_RELATIVE,
        "STAGE_SCHEMA": materializer.L15_STAGE_SCHEMA,
        "AUTHORITY_SCHEMA": materializer.L15_AUTHORITY_SCHEMA,
        "CLOSURE_PATH": ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v16.json",
        "REPAIR_DESIGN_PATH": design.DESIGN,
        "EXPECTED_REPAIR_DESIGN_BYTES": design.DESIGN_BYTES,
        "EXPECTED_REPAIR_DESIGN_SHA256": design.DESIGN_SHA,
        "PREDECESSOR_PHYSICAL_CLOSURE_PATH": materializer.L15_PREDECESSOR_PATH,
        "EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES": materializer.L15_PREDECESSOR_BYTES,
        "EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256": materializer.L15_PREDECESSOR_SHA256,
    })


def read_l15_closure_graph() -> dict[str, Any]:
    import qsdk_r10f_authority_materializer as materializer

    try:
        return materializer.l15_committed_graph_binding()
    except (RuntimeError, ValueError, OSError) as exc:
        raise ClosureFailure(f"L15_CLOSURE_GRAPH:{exc}") from exc


def validate_l9_authority_files(source: Mapping[str, Any]) -> dict[str, Any]:
    if REPAIR_ID == "QSDK-R10F-L15":
        binding = read_l15_closure_graph()
        require(source.get("authority_sha256") == binding["authority_sha256"]
                and source.get("source_commit") == binding["authority"]["source_commit"],
                "L15_REPORT_AUTHORITY_SOURCE_BINDING")
        stage = binding["freeze"]
        return {
            "authority": binding["authority"], "stage": stage,
            "policy": {"count": stage["qualified_source_path_count"],
                       "digest": stage["qualified_source_path_sha256"]},
            "repair_design": binding["repair_design"],
            "branch_completeness_addendum": binding["branch_completeness_addendum"],
            "predecessor_physical_closure": binding["consumed_predecessor_physical_closure"],
        }
    require(
        AUTHORITY_PATH.is_file()
        and STAGE_PATH.is_file()
        and SUPERVISOR_REFUSAL_PATH.is_file()
        and PREDECESSOR_PHYSICAL_CLOSURE_PATH.is_file()
        and REPAIR_DESIGN_PATH.is_file()
        and BRANCH_COMPLETENESS_ADDENDUM_PATH.is_file(),
        "L9_AUTHORITY_FILES_MISSING",
    )
    authority = read_json(AUTHORITY_PATH, "L9_AUTHORITY")
    stage = read_json(STAGE_PATH, "L9_STAGE")
    for label, value in (("AUTHORITY", authority), ("STAGE", stage)):
        try:
            l14_components.validate_receipt(value.get("l14_component_qualification"))
            l14_runtime.validate_binding(value.get("l14_exact_runtime_images"))
        except ValueError as exc:
            raise ClosureFailure(f"L14_{label}_COMPONENT_QUALIFICATION:{exc}") from exc
    policy = l9_source_policy()
    source_commit = str(source.get("source_commit", ""))
    try:
        l14_runtime.read_retained_runtime(stage.get("qualified_runtime_identity"), source_commit)
    except (ValueError, OSError) as exc:
        raise ClosureFailure(f"L14_QUALIFIED_RUNTIME_RECORD:{exc}") from exc
    repair_design = validate_l14_repair_design(source_commit)
    branch_addendum = validate_l14_branch_completeness_addendum(source_commit)
    predecessor = validate_l14_predecessor_physical_closure(source_commit)
    require(
        SUPERVISOR_REFUSAL_PATH.stat().st_size == EXPECTED_SUPERVISOR_REFUSAL_BYTES
        and sha256_file(SUPERVISOR_REFUSAL_PATH)
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "L9_SUPERVISOR_REFUSAL_IDENTITY",
    )
    require(
        authority.get("schema_version") == AUTHORITY_SCHEMA
        and authority.get("status") == "authorized_single_use_unconsumed"
        and authority.get("gate_id") == "QSDK-R10F"
        and authority.get("repair_id") == REPAIR_ID
        and authority.get("campaign_id") == CAMPAIGN_ID
        and authority.get("campaign_role") == "development_route_ghost"
        and authority.get("question_class") == "development"
        and authority.get("ledger_scope")
        == ledger_scope("single_use_physical_execution_authority")
        and authority.get("source_commit") == source_commit
        and authority.get("qualification_parent_commit") == source_commit
        and authority.get("qualified_source_path_count") == policy["count"]
        and authority.get("qualified_source_path_sha256") == policy["digest"]
        and authority.get("dependency_manifest_raw_sha256") == sha256_file(MANIFEST_PATH)
        and authority.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and authority.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and authority.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and authority.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and authority.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and exact_int(authority.get("seed"), SEED)
        and authority.get("seed_sha256") == SEED_SHA256
        and authority.get("ordered_child_roles") == ARM_ORDER
        and exact_int(authority.get("maximum_child_process_count"), 2)
        and exact_int(authority.get("maximum_world_count_per_child"), 1)
        and exact_int(authority.get("maximum_world_count"), 2)
        and exact_int(authority.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(authority.get("maximum_solver_step_count"), 7684)
        and exact_int(authority.get("maximum_campaign_attempt_count"), 1)
        and authority.get("child_processes_overlap_in_wall_clock_time") is False
        and authority.get("child_retry_permitted") is False
        and authority.get("child_replacement_permitted") is False
        and authority.get("zero_world_qualification_passed") is True
        and authority.get("physical_execution_authorized") is True
        and authority.get("physical_identity_consumed") is False
        and authority.get("same_identity_rerun_permitted") is False
        and authority.get("physical_acceptance_authority") is False
        and authority.get("release_authority") is False,
        "L9_AUTHORITY_FIELDS",
    )
    stage_claim = stage.get("claim_boundary")
    require(
        stage.get("schema_version") == STAGE_SCHEMA
        and stage.get("status") == "closed_passing_official_zero_world_qualification"
        and stage.get("gate_id") == "QSDK-R10F"
        and stage.get("repair_id") == REPAIR_ID
        and stage.get("campaign_id") == CAMPAIGN_ID
        and stage.get("campaign_role") == "development_route_ghost"
        and stage.get("question_class") == "development"
        and stage.get("ledger_scope") == ledger_scope("official_zero_world_qualification")
        and stage.get("source_commit") == source_commit
        and stage.get("qualification_parent_commit") == source_commit
        and stage.get("qualified_source_path_count") == policy["count"]
        and stage.get("qualified_source_path_sha256") == policy["digest"]
        and stage.get("dependency_manifest_raw_sha256") == sha256_file(MANIFEST_PATH)
        and stage.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and stage.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and l14_authority.design_audit.exact(stage.get("repair_design"), repair_design)
        and stage.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and l14_authority.addendum_binding_valid(stage.get("branch_completeness_addendum"))
        and l14_authority.design_audit.exact(
            stage.get("consumed_predecessor_physical_closure"), predecessor
        )
        and stage.get("ordered_child_roles") == ARM_ORDER
        and exact_int(stage.get("maximum_child_process_count"), 2)
        and exact_int(stage.get("maximum_world_count_per_child"), 1)
        and exact_int(stage.get("maximum_world_count"), 2)
        and exact_int(stage.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(stage.get("maximum_solver_step_count"), 7684)
        and exact_int(stage.get("maximum_campaign_attempt_count"), 1)
        and stage.get("child_processes_overlap_in_wall_clock_time") is False
        and stage.get("child_retry_permitted") is False
        and stage.get("child_replacement_permitted") is False
        and stage.get("official_zero_world_qualification_passed") is True
        and stage.get("physical_execution_authorized_by_freeze") is False
        and isinstance(stage.get("preserved_bound_authorities"), list)
        and bool(stage.get("preserved_bound_authorities"))
        and isinstance(stage_claim, dict)
        and stage_claim.get("process_isolation_qualified_zero_world") is True
        and stage_claim.get(
            "nullable_terminal_failure_code_projection_qualified_zero_world"
        )
        is True
        and stage_claim.get(
            "precondition_release_owner_source_projection_qualified_zero_world"
        )
        is True
        and stage_claim.get("walking_actuation_handoff_qualified_zero_world") is True
        and stage_claim.get(
            "walking_native_preparse_transport_verification_qualified_zero_world"
        )
        is True
        and stage_claim.get(
            "walking_binary32_host_target_projection_qualified_zero_world"
        )
        is True
        and stage_claim.get("walking_ledger_v2_named_predicates_qualified_zero_world")
        is True
        and stage_claim.get("walking_failed_step_source_retention_qualified_zero_world")
        is True
        and exact_int(
            stage_claim.get("walking_ledger_l13_positive_control_count"), 15
        )
        and exact_int(
            stage_claim.get("walking_ledger_l13_mutation_rejection_count"), 16
        )
        and exact_int(
            stage_claim.get(
                "walking_ledger_failure_retention_positive_control_count"
            ),
            1,
        )
        and exact_int(
            stage_claim.get(
                "walking_ledger_failure_retention_mutation_rejection_count"
            ),
            15,
        )
        and exact_int(stage_claim.get("production_shaped_walking_fixture_count"), 3)
        and exact_int(
            stage_claim.get("detached_hinge_parameter_container_count"), 24
        )
        and exact_int(stage_claim.get("qualified_r69_host_cap_projection_count"), 8)
        and stage_claim.get("shared_adapter_enable_behavior_changed") is False
        and stage_claim.get("published_actuator_profile_changed") is False
        and exact_int(stage_claim.get("walking_handoff_extra_solver_step_count"), 0)
        and stage_claim.get("threshold_or_controller_changed") is False
        and stage_claim.get("r10f_behavior_observed") is False
        and stage_claim.get("sdk1_m07_satisfied") is False
        and stage.get("physical_acceptance_authority") is False
        and stage.get("release_authority") is False,
        "L9_STAGE_FIELDS",
    )
    require(
        authority.get("zero_world_qualification_closure_sha256")
        == sha256_file(STAGE_PATH)
        and source.get("authority_sha256") == sha256_file(AUTHORITY_PATH),
        "L9_AUTHORITY_CONTENT_BINDING",
    )
    for path in (DESIGN_PATH, MANIFEST_PATH):
        relative = path.relative_to(ROOT).as_posix()
        require(
            git("rev-parse", f"{source_commit}:{relative}")
            == git("hash-object", str(path)),
            f"L9_SOURCE_BLOB:{relative}",
        )
    return {
        "authority": authority,
        "stage": stage,
        "policy": policy,
        "repair_design": repair_design,
        "branch_completeness_addendum": branch_addendum,
        "predecessor_physical_closure": predecessor,
    }


def validate_l9_live_authority_graph(authority: Mapping[str, Any]) -> dict[str, str]:
    root = Path(git("rev-parse", "--show-toplevel")).resolve()
    remote = git("remote", "get-url", "origin")
    branch = git("branch", "--show-current")
    status = git("status", "--porcelain=v1", "--untracked-files=all")
    head = git("rev-parse", "HEAD")
    origin = git("rev-parse", "origin/main")
    live = git("ls-remote", "origin", "refs/heads/main").split()
    authority_relative = AUTHORITY_PATH.relative_to(ROOT).as_posix()
    closer_relative = Path(__file__).resolve().relative_to(ROOT).as_posix()
    authority_commit = git("log", "-1", "--format=%H", "--", authority_relative)
    source = str(authority.get("source_commit", ""))
    stage = str(authority.get("authorization_parent_commit", ""))
    closure_audit_commit = source
    if head != authority_commit:
        require(
            git("rev-parse", "HEAD^") == authority_commit,
            "L9_CLOSURE_AUDIT_CHILD_NOT_DIRECT_AUTHORITY_CHILD",
        )
        require(
            git(
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "--no-renames",
                "-r",
                head,
            ).splitlines()
            == [closer_relative],
            "L9_CLOSURE_AUDIT_CHILD_NOT_CLOSER_ONLY",
        )
        closure_audit_commit = head
    require(
        root == ROOT.resolve() == EXPECTED_ROOT.resolve()
        and remote == EXPECTED_REMOTE
        and branch == "main"
        and status == ""
        and head == origin
        and live == [head, "refs/heads/main"]
        and git("rev-parse", f"{authority_commit}^") == stage
        and git("rev-parse", f"{authority_commit}^^") == source
        and head in {authority_commit, closure_audit_commit},
        "L9_CLEAN_LIVE_COMMITTED_AUTHORITY_GRAPH_REQUIRED",
    )
    require(
        git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            stage,
        ).splitlines()
        == [STAGE_PATH.relative_to(ROOT).as_posix()]
        and git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            authority_commit,
        ).splitlines()
        == [authority_relative],
        "L9_AUTHORITY_GRAPH_SINGLE_PATH_COMMITS",
    )
    require(
        git("rev-parse", f"{closure_audit_commit}:{closer_relative}")
        == git("hash-object", str(Path(__file__).resolve())),
        "L9_CLOSURE_SOURCE_BLOB_DRIFT",
    )
    return {
        "source_commit": source,
        "stage_commit": stage,
        "authority_commit": authority_commit,
        "closure_audit_commit": closure_audit_commit,
    }


def nullable_terminal_failure_code_matches(
    memory: Any, terminal_phase: Any, projected_failure_code: Any
) -> bool:
    if (
        not isinstance(memory, dict)
        or "phase" not in memory
        or "terminal_failure_code" not in memory
        or type(terminal_phase) is not str
        or type(projected_failure_code) is not str
        or type(memory["phase"]) is not str
        or memory["phase"] != terminal_phase
    ):
        return False
    source_value = memory["terminal_failure_code"]
    if terminal_phase == "complete":
        if source_value is not None or projected_failure_code != "":
            return False
        return True
    if terminal_phase in {"failed", "refused"}:
        if (
            type(source_value) is not str
            or not source_value
            or projected_failure_code != source_value
        ):
            return False
        return True
    return False


def validate_l9_terminal_receipt(
    terminal: Any,
    *,
    parent_attempt_id: str,
    child_attempt_id: str,
    role: str,
    model_instance_id: str,
    maximum_step: int,
) -> dict[str, Any]:
    expected_keys = {
        "schema_version",
        "gate_id",
        "repair_id",
        "parent_attempt_id",
        "child_attempt_id",
        "arm_id",
        "model_instance_id",
        "completed_global_semantic_step",
        "disposition",
        "recovery_controller_id",
        "recovery_terminal_phase",
        "recovery_terminal_failure_code",
        "recovery_memory",
        "recovery_memory_sha256",
        "recovery_step_receipt",
        "recovery_step_receipt_sha256",
        "recovery_classification",
        "recovery_classification_sha256",
        "stable_four_foot_stance",
        "body_transform_write_count",
        "body_velocity_write_count",
        "solver_reset_count",
        "source_measurement",
        "outcome_derived_correction",
        "physical_acceptance_authority",
        "release_authority",
        "payload_sha256",
    }
    require(isinstance(terminal, dict), f"L9_{role}_TERMINAL_NOT_OBJECT")
    require(set(terminal) == expected_keys, f"L9_{role}_TERMINAL_KEY_SET")
    step_number = terminal.get("completed_global_semantic_step")
    memory = terminal.get("recovery_memory")
    step = terminal.get("recovery_step_receipt")
    classification = terminal.get("recovery_classification")
    disposition = terminal.get("disposition")
    require(
        terminal.get("schema_version") == PRECONDITION_SCHEMA
        and terminal.get("gate_id") == "QSDK-R10F"
        and terminal.get("repair_id") == CHILD_CONTRACT_REPAIR_ID
        and terminal.get("parent_attempt_id") == parent_attempt_id
        and terminal.get("child_attempt_id") == child_attempt_id
        and terminal.get("arm_id") == role
        and terminal.get("model_instance_id") == model_instance_id
        and bounded_int(step_number, 1, maximum_step)
        and disposition
        in {
            "complete_source_retained",
            "failed_source_retained",
            "refused_source_retained",
        }
        and terminal.get("recovery_controller_id") == RECOVERY_CONTROLLER_ID
        and isinstance(memory, dict)
        and isinstance(step, dict)
        and isinstance(classification, dict)
        and isinstance(terminal.get("stable_four_foot_stance"), bool)
        and exact_int(terminal.get("body_transform_write_count"), 0)
        and exact_int(terminal.get("body_velocity_write_count"), 0)
        and exact_int(terminal.get("solver_reset_count"), 0)
        and terminal.get("source_measurement") is True
        and terminal.get("outcome_derived_correction") is False
        and terminal.get("physical_acceptance_authority") is False
        and terminal.get("release_authority") is False,
        f"L9_{role}_TERMINAL_FIELDS",
    )
    content_predicates = l14_terminal.terminal_content_predicates(
        terminal,
        native_step_matches=integer_valued_native_step_matches,
        canonical_sha256=canonical_sha256_v1,
        payload_sha256=payload_sha256_v1,
    )
    failed_content = [key for key, passed in content_predicates.items() if not passed]
    require(
        not failed_content,
        f"L14_{role}_TERMINAL_CONTENT_ADDRESS:" + ",".join(failed_content),
    )
    phase = terminal.get("recovery_terminal_phase")
    failure = terminal.get("recovery_terminal_failure_code")
    require(
        nullable_terminal_failure_code_matches(memory, phase, failure),
        f"L10_{role}_TERMINAL_FAILURE_SOURCE_PROJECTION",
    )
    if disposition == "complete_source_retained":
        require(
            phase == "complete"
            and failure == ""
            and terminal.get("stable_four_foot_stance") is True,
            f"L9_{role}_TERMINAL_COMPLETE_CLASS",
        )
    else:
        expected_phase = (
            "failed" if disposition == "failed_source_retained" else "refused"
        )
        require(
            phase == expected_phase
            and isinstance(failure, str)
            and bool(failure),
            f"L9_{role}_TERMINAL_NEGATIVE_CLASS",
        )
    return {
        "disposition": disposition,
        "completed_global_semantic_step": step_number,
        "payload_sha256": terminal["payload_sha256"],
    }


def l11_release_owner_source_projection(
    terminal: Mapping[str, Any],
) -> dict[str, Any]:
    """Reconstruct the exact non-outcome owner source for one release frame."""
    completed_step = terminal.get("completed_global_semantic_step")
    require(
        terminal.get("disposition") == "complete_source_retained"
        and bounded_int(completed_step, 1, 3842)
        and is_sha256(terminal.get("payload_sha256"))
        and is_sha256(terminal.get("recovery_memory_sha256"))
        and is_sha256(terminal.get("recovery_step_receipt_sha256")),
        "L11_RELEASE_OWNER_TERMINAL_INVALID",
    )
    source: dict[str, Any] = {
        "schema_version": RELEASE_OWNER_SOURCE_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": RELEASE_REPAIR_ID,
        "parent_attempt_id": terminal.get("parent_attempt_id"),
        "child_attempt_id": terminal.get("child_attempt_id"),
        "arm_id": terminal.get("arm_id"),
        "model_instance_id": terminal.get("model_instance_id"),
        "completed_terminal_global_semantic_step": completed_step,
        "release_global_semantic_step": int(completed_step) + 1,
        "source_kind": "validated_complete_precondition_release_no_actuation",
        "precondition_terminal_receipt_sha256": terminal.get("payload_sha256"),
        "recovery_memory_sha256": terminal.get("recovery_memory_sha256"),
        "recovery_step_receipt_sha256": terminal.get(
            "recovery_step_receipt_sha256"
        ),
        "source_measurement": True,
        "outcome_derived_correction": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    source["payload_sha256"] = payload_sha256_v1(source)
    return source


def validate_l9_release_receipt(
    release: Any,
    terminal: Mapping[str, Any],
    *,
    parent_attempt_id: str,
    child_attempt_id: str,
    role: str,
    model_instance_id: str,
) -> dict[str, Any]:
    expected_keys = {
        "schema_version",
        "gate_id",
        "repair_id",
        "parent_attempt_id",
        "child_attempt_id",
        "arm_id",
        "model_instance_id",
        "global_semantic_step",
        "action_kind",
        "precondition_terminal_receipt",
        "precondition_terminal_receipt_sha256",
        "motor_configuration_receipt",
        "motor_configuration_receipt_sha256",
        "motor_population_readback",
        "motor_population_readback_sha256",
        "ledger_application_intent",
        "ledger_application_intent_sha256",
        "ordered_motor_readbacks",
        "control_owner",
        "actuation_owner",
        "no_actuation_requested",
        "source_measurement",
        "outcome_derived_correction",
        "body_transform_write_count",
        "body_velocity_write_count",
        "solver_reset_count",
        "physical_acceptance_authority",
        "release_authority",
        "payload_sha256",
    }
    require(isinstance(release, dict), f"L9_{role}_RELEASE_NOT_OBJECT")
    require(set(release) == expected_keys, f"L9_{role}_RELEASE_KEY_SET")
    configuration = release.get("motor_configuration_receipt")
    readback = release.get("motor_population_readback")
    ledger = release.get("ledger_application_intent")
    projected_rows = release.get("ordered_motor_readbacks")
    expected_owner_source = l11_release_owner_source_projection(terminal)
    require(
        release.get("schema_version") == RELEASE_SCHEMA
        and release.get("gate_id") == "QSDK-R10F"
        and release.get("repair_id") == RELEASE_REPAIR_ID
        and release.get("parent_attempt_id") == parent_attempt_id
        and release.get("child_attempt_id") == child_attempt_id
        and release.get("arm_id") == role
        and release.get("model_instance_id") == model_instance_id
        and exact_int(
            release.get("global_semantic_step"),
            int(terminal["completed_global_semantic_step"]) + 1,
        )
        and release.get("action_kind") == "process_isolated_no_actuation_release"
        and release.get("precondition_terminal_receipt") == terminal
        and release.get("precondition_terminal_receipt_sha256")
        == terminal.get("payload_sha256")
        and isinstance(configuration, dict)
        and isinstance(readback, dict)
        and isinstance(ledger, dict)
        and isinstance(projected_rows, list)
        and release.get("control_owner") == "none"
        and release.get("actuation_owner") == "none"
        and release.get("no_actuation_requested") is True
        and release.get("source_measurement") is True
        and release.get("outcome_derived_correction") is False
        and exact_int(release.get("body_transform_write_count"), 0)
        and exact_int(release.get("body_velocity_write_count"), 0)
        and exact_int(release.get("solver_reset_count"), 0)
        and release.get("physical_acceptance_authority") is False
        and release.get("release_authority") is False,
        f"L9_{role}_RELEASE_FIELDS",
    )
    require(
        release.get("motor_configuration_receipt_sha256")
        == canonical_sha256_v1(configuration)
        and release.get("motor_population_readback_sha256")
        == canonical_sha256_v1(readback)
        and release.get("ledger_application_intent_sha256")
        == canonical_sha256_v1(ledger)
        and release.get("payload_sha256") == payload_sha256_v1(release),
        f"L9_{role}_RELEASE_CONTENT_ADDRESS",
    )
    configured_rows = configuration.get("ordered_joint_receipts")
    native_rows = readback.get("ordered_joint_readbacks")
    global_step = release["global_semantic_step"]
    require(
        configuration.get("ok") is True
        and exact_int(configuration.get("global_semantic_step"), global_step)
        and configuration.get("motor_enabled") is False
        and isinstance(configured_rows, list)
        and len(configured_rows) == len(JOINT_IDS)
        and readback.get("ok") is True
        and exact_int(readback.get("global_semantic_step"), global_step)
        and readback.get("expected_motor_enabled") is False
        and exact_int(readback.get("motor_enabled_count"), 0)
        and exact_int(readback.get("zero_target_velocity_count"), len(JOINT_IDS))
        and exact_int(readback.get("native_readback_count"), len(JOINT_IDS) * 3)
        and isinstance(native_rows, list)
        and len(native_rows) == len(JOINT_IDS)
        and len(projected_rows) == len(JOINT_IDS)
        and ledger.get("ok") is True
        and exact_int(ledger.get("semantic_step"), global_step)
        and ledger.get("no_actuation_requested") is True
        and ledger.get("controller_owner") == "none"
        and ledger.get("owner_source_receipt") == expected_owner_source
        and ledger.get("owner_source_receipt_sha256")
        == canonical_sha256_v1(expected_owner_source)
        and ledger.get("motor_population_readback") == readback,
        f"L11_{role}_RELEASE_NO_ACTUATION_SOURCES",
    )
    for index, joint_id in enumerate(JOINT_IDS):
        configured = configured_rows[index]
        native = native_rows[index]
        projected = projected_rows[index]
        require(
            isinstance(configured, dict)
            and configured.get("joint_id") == joint_id
            and configured.get("motor_enabled") is False
            and finite_number(configured.get("motor_target_velocity_rad_s"))
            and float(configured["motor_target_velocity_rad_s"]) == 0.0
            and isinstance(native, dict)
            and native.get("joint_id") == joint_id
            and native.get("motor_enabled") is False
            and finite_number(native.get("motor_target_velocity_rad_s"))
            and float(native["motor_target_velocity_rad_s"]) == 0.0
            and finite_number(native.get("motor_maximum_impulse_nms"))
            and float(native["motor_maximum_impulse_nms"]) > 0.0
            and isinstance(projected, dict)
            and set(projected)
            == {"joint_id", "motor_enabled", "motor_target_velocity_rad_s"}
            and projected.get("joint_id") == joint_id
            and projected.get("motor_enabled") is False
            and finite_number(projected.get("motor_target_velocity_rad_s"))
            and float(projected["motor_target_velocity_rad_s"]) == 0.0,
            f"L9_{role}_RELEASE_MOTOR_ROW_{index}",
        )
    return {
        "global_semantic_step": global_step,
        "payload_sha256": release["payload_sha256"],
        "owner_source_payload_sha256": expected_owner_source["payload_sha256"],
        "owner_source_receipt_sha256": canonical_sha256_v1(expected_owner_source),
        "native_readback_count": len(JOINT_IDS) * 3,
    }


def binary32_v1(value: float) -> float:
    return struct.unpack(">f", struct.pack(">f", float(value)))[0]


def binary32_bits_v1(value: float) -> int:
    return struct.unpack(">I", struct.pack(">f", binary32_v1(value)))[0]


def binary32_from_bits_v1(bits: int) -> float:
    return struct.unpack(">f", struct.pack(">I", bits))[0]


def l12_payload_sha256_v1(value: Mapping[str, Any]) -> str:
    """Match the L12 facade receipts, whose digest field is blank while hashed."""
    payload = dict(value)
    payload["payload_sha256"] = ""
    return canonical_sha256_v1(payload)


def l12_expected_host_cap_projection(index: int) -> dict[str, Any]:
    require(0 <= index < len(ACTUATOR_IDS), "L12_PROJECTION_INDEX")
    actuator_id = ACTUATOR_IDS[index]
    published_cap = PUBLISHED_CAPS_NMS[index]
    outer_step = 1.0 / 120.0
    native_solver_step = binary32_v1(outer_step)
    nearest_host_cap = binary32_v1(published_cap)
    nearest_host_bits = binary32_bits_v1(nearest_host_cap)
    configured_host_cap = math.nan
    configured_host_bits = -1
    projected_torque = math.nan
    projected_effective = math.nan
    downward_steps = -1
    for decrement in range(4):
        candidate_bits = nearest_host_bits - decrement
        require(candidate_bits > 0, f"L12_PROJECTION_POSITIVE_BITS_{index}")
        candidate_host_cap = binary32_from_bits_v1(candidate_bits)
        candidate_torque = binary32_v1(candidate_host_cap / outer_step)
        candidate_effective = binary32_v1(candidate_torque * native_solver_step)
        if candidate_effective <= published_cap:
            configured_host_cap = candidate_host_cap
            configured_host_bits = candidate_bits
            projected_torque = candidate_torque
            projected_effective = candidate_effective
            downward_steps = decrement
            break
    require(
        downward_steps >= 0 and configured_host_cap == HOST_CAPS_NMS[index],
        f"L12_PROJECTION_CONFIGURED_HOST_CAP_{index}",
    )
    next_host_bits = configured_host_bits + 1
    next_host_cap = binary32_from_bits_v1(next_host_bits)
    next_torque = binary32_v1(next_host_cap / outer_step)
    next_effective = binary32_v1(next_torque * native_solver_step)
    require(
        projected_effective <= published_cap and next_effective > published_cap,
        f"L12_PROJECTION_MAXIMALITY_{index}",
    )
    return {
        "schema_version": NATIVE_EFFECTIVE_PROJECTION_SCHEMA,
        "ok": True,
        "projection_id": HOST_CAP_PROJECTION_ID,
        "scope": HOST_CAP_PROJECTION_SCOPE,
        "actuator_id": actuator_id,
        "actuator_index": index,
        "published_maximum_outer_step_impulse_nms": published_cap,
        "nearest_binary32_host_maximum_impulse_nms": nearest_host_cap,
        "nearest_binary32_host_cap_binary32_hex": f"0x{nearest_host_bits:08x}",
        "configured_host_maximum_impulse_nms": configured_host_cap,
        "configured_host_cap_binary32_hex": f"0x{configured_host_bits:08x}",
        "nearest_to_configured_downward_binary32_step_count": downward_steps,
        "projected_native_maximum_torque_limit_nm": projected_torque,
        "projected_native_torque_limit_binary32_hex": (
            f"0x{binary32_bits_v1(projected_torque):08x}"
        ),
        "native_solver_step_s": native_solver_step,
        "native_solver_step_binary32_hex": (
            f"0x{binary32_bits_v1(native_solver_step):08x}"
        ),
        "projected_native_effective_impulse_limit_nms": projected_effective,
        "projected_native_effective_limit_binary32_hex": (
            f"0x{binary32_bits_v1(projected_effective):08x}"
        ),
        "native_effective_limit_not_above_published": True,
        "next_binary32_host_maximum_impulse_nms": next_host_cap,
        "next_binary32_host_cap_binary32_hex": f"0x{next_host_bits:08x}",
        "next_projected_native_maximum_torque_limit_nm": next_torque,
        "next_projected_native_effective_impulse_limit_nms": next_effective,
        "next_native_effective_limit_above_published": True,
        "configured_to_next_binary32_ulp_distance": 1,
        "selection_rule": HOST_CAP_SELECTION_RULE,
        "nominal_host_conversion_step_s": outer_step,
        "published_cap_changed": False,
        "empirical_margin_added": False,
        "measurement_clamped": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_l12_walking_handoff(
    receipt: Any,
    *,
    expected_model_instance_id: str,
    expected_evaluation_segment: str,
    expected_session_id: str,
    expected_global_semantic_step: int,
) -> dict[str, Any]:
    code = f"L12_HANDOFF_{expected_evaluation_segment.upper()}"
    require(isinstance(receipt, dict), f"{code}_NOT_OBJECT")
    require(set(receipt) == WALKING_HANDOFF_KEYS, f"{code}_KEY_SET")
    expected_facade_segment = (
        "walking_prefix"
        if expected_evaluation_segment == "walking_prefix"
        else "walking_resume"
    )
    configuration = receipt.get("motor_configuration_receipt")
    readback = receipt.get("precommand_motor_population_readback")
    binding = receipt.get("host_cap_projection_binding")
    published_map = dict(zip(ACTUATOR_IDS, PUBLISHED_CAPS_NMS))
    host_map = dict(zip(ACTUATOR_IDS, HOST_CAPS_NMS))
    require(
        receipt.get("schema_version") == WALKING_HANDOFF_SCHEMA
        and receipt.get("gate_id") == "QSDK-R10F"
        and receipt.get("ok") is True
        and receipt.get("facade_id") == WALKING_FACADE_ID
        and receipt.get("model_instance_id") == expected_model_instance_id
        and receipt.get("facade_segment_id") == expected_facade_segment
        and receipt.get("evaluation_segment_id") == expected_evaluation_segment
        and receipt.get("walking_session_id") == expected_session_id
        and exact_int(
            receipt.get("global_semantic_step"), expected_global_semantic_step
        )
        and receipt.get("selected_policy_id") == POLICY_ID
        and receipt.get("selected_policy_digest") == POLICY_SHA256
        and isinstance(configuration, dict)
        and isinstance(readback, dict)
        and isinstance(binding, dict)
        and receipt.get("ordered_actuator_ids") == ACTUATOR_IDS
        and receipt.get("published_cap_by_actuator_id") == published_map
        and receipt.get("authorized_host_cap_by_actuator_id") == host_map
        and exact_int(receipt.get("motor_enabled_count"), len(JOINT_IDS))
        and exact_int(receipt.get("zero_target_velocity_count"), len(JOINT_IDS))
        and exact_int(
            receipt.get("motor_configuration_write_count"), len(JOINT_IDS) * 2
        )
        and exact_int(receipt.get("native_readback_count"), len(JOINT_IDS) * 3)
        and exact_int(receipt.get("solver_step_count"), 0)
        and exact_int(receipt.get("body_transform_write_count"), 0)
        and exact_int(receipt.get("body_velocity_write_count"), 0)
        and exact_int(receipt.get("body_impulse_write_count"), 0)
        and exact_int(receipt.get("solver_reset_count"), 0)
        and receipt.get("physics_state_modified") is True
        and receipt.get("outcome_derived_correction") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        f"{code}_FIELDS",
    )

    reason = (
        "l12_walking_actuation_handoff_precommand:"
        + expected_evaluation_segment
    )
    require(
        set(configuration) == MOTOR_CONFIGURATION_KEYS
        and configuration.get("schema_version") == MOTOR_CONFIGURATION_SCHEMA
        and configuration.get("gate_id") == "QSDK-R10F"
        and configuration.get("ok") is True
        and exact_int(
            configuration.get("global_semantic_step"),
            expected_global_semantic_step,
        )
        and configuration.get("reason") == reason
        and configuration.get("motor_enabled") is True
        and exact_int(
            configuration.get("motor_configuration_write_count"),
            len(JOINT_IDS) * 2,
        )
        and exact_int(configuration.get("body_transform_write_count"), 0)
        and exact_int(configuration.get("body_velocity_write_count"), 0)
        and exact_int(configuration.get("body_impulse_write_count"), 0)
        and exact_int(configuration.get("solver_reset_count"), 0)
        and configuration.get("physics_state_modified") is True
        and configuration.get("physical_acceptance_authority") is False
        and configuration.get("release_authority") is False,
        f"{code}_CONFIGURATION_FIELDS",
    )
    configuration_rows = configuration.get("ordered_joint_receipts")
    require(
        isinstance(configuration_rows, list)
        and len(configuration_rows) == len(JOINT_IDS),
        f"{code}_CONFIGURATION_POPULATION",
    )
    for index, row in enumerate(configuration_rows):
        require(
            isinstance(row, dict)
            and set(row)
            == {"joint_id", "motor_enabled", "motor_target_velocity_rad_s"}
            and row.get("joint_id") == JOINT_IDS[index]
            and row.get("motor_enabled") is True
            and finite_number(row.get("motor_target_velocity_rad_s"))
            and float(row["motor_target_velocity_rad_s"]) == 0.0,
            f"{code}_CONFIGURATION_ROW_{index}",
        )

    require(
        set(readback) == MOTOR_READBACK_KEYS
        and readback.get("schema_version") == MOTOR_READBACK_SCHEMA
        and readback.get("gate_id") == "QSDK-R10F"
        and readback.get("ok") is True
        and exact_int(
            readback.get("global_semantic_step"), expected_global_semantic_step
        )
        and readback.get("reason") == reason
        and readback.get("expected_motor_enabled") is True
        and exact_int(readback.get("motor_enabled_count"), len(JOINT_IDS))
        and exact_int(readback.get("zero_target_velocity_count"), len(JOINT_IDS))
        and exact_int(readback.get("native_readback_count"), len(JOINT_IDS) * 3)
        and exact_int(readback.get("body_transform_write_count"), 0)
        and exact_int(readback.get("body_velocity_write_count"), 0)
        and exact_int(readback.get("body_impulse_write_count"), 0)
        and exact_int(readback.get("solver_reset_count"), 0)
        and exact_int(readback.get("solver_step_count"), 0)
        and readback.get("physics_state_modified") is False
        and readback.get("physical_acceptance_authority") is False
        and readback.get("release_authority") is False,
        f"{code}_READBACK_FIELDS",
    )
    readback_rows = readback.get("ordered_joint_readbacks")
    require(
        isinstance(readback_rows, list) and len(readback_rows) == len(JOINT_IDS),
        f"{code}_READBACK_POPULATION",
    )
    for index, row in enumerate(readback_rows):
        require(
            isinstance(row, dict)
            and set(row)
            == {
                "actuator_id",
                "joint_id",
                "motor_enabled",
                "motor_target_velocity_rad_s",
                "motor_maximum_impulse_nms",
            }
            and row.get("actuator_id") == ACTUATOR_IDS[index]
            and row.get("joint_id") == JOINT_IDS[index]
            and row.get("motor_enabled") is True
            and finite_number(row.get("motor_target_velocity_rad_s"))
            and float(row["motor_target_velocity_rad_s"]) == 0.0
            and finite_number(row.get("motor_maximum_impulse_nms"))
            and float(row["motor_maximum_impulse_nms"]) == HOST_CAPS_NMS[index],
            f"{code}_READBACK_ROW_{index}",
        )

    expected_projections = [
        l12_expected_host_cap_projection(index) for index in range(len(JOINT_IDS))
    ]
    require(
        set(binding) == HOST_CAP_BINDING_KEYS
        and binding.get("schema_version") == HOST_CAP_BINDING_SCHEMA
        and binding.get("gate_id") == "QSDK-R10F"
        and binding.get("ok") is True
        and binding.get("projection_id") == HOST_CAP_PROJECTION_ID
        and binding.get("scope") == HOST_CAP_PROJECTION_SCOPE
        and binding.get("selection_rule") == HOST_CAP_SELECTION_RULE
        and binding.get("ordered_actuator_ids") == ACTUATOR_IDS
        and binding.get("ordered_published_caps_nms") == PUBLISHED_CAPS_NMS
        and binding.get("ordered_selected_host_caps_nms") == HOST_CAPS_NMS
        and binding.get("published_cap_by_actuator_id") == published_map
        and binding.get("selected_host_cap_by_actuator_id") == host_map
        and binding.get("ordered_projection_receipts") == expected_projections
        and exact_int(binding.get("projection_count"), len(JOINT_IDS))
        and exact_int(
            binding.get("selected_effective_limit_not_above_published_count"),
            len(JOINT_IDS),
        )
        and exact_int(
            binding.get("immediately_higher_effective_limit_above_published_count"),
            len(JOINT_IDS),
        )
        and exact_int(
            binding.get("binary32_maximality_proof_count"), len(JOINT_IDS)
        )
        and binding.get("published_cap_changed") is False
        and binding.get("empirical_margin_added") is False
        and binding.get("raw_measurement_clamped") is False
        and exact_int(binding.get("model_construction_count"), 0)
        and exact_int(binding.get("world_attempt_count"), 0)
        and exact_int(binding.get("world_build_count"), 0)
        and exact_int(binding.get("solver_step_count"), 0)
        and binding.get("physics_state_modified") is False
        and binding.get("physical_acceptance_authority") is False
        and binding.get("release_authority") is False
        and binding.get("payload_sha256") == l12_payload_sha256_v1(binding),
        f"{code}_HOST_CAP_BINDING",
    )
    for index, projection in enumerate(binding["ordered_projection_receipts"]):
        require(
            isinstance(projection, dict)
            and set(projection) == HOST_CAP_PROJECTION_KEYS
            and exact_int(projection.get("actuator_index"), index)
            and exact_int(
                projection.get("nearest_to_configured_downward_binary32_step_count"),
                expected_projections[index][
                    "nearest_to_configured_downward_binary32_step_count"
                ],
            )
            and exact_int(
                projection.get("configured_to_next_binary32_ulp_distance"), 1
            )
            and exact_int(projection.get("model_construction_count"), 0)
            and exact_int(projection.get("world_attempt_count"), 0)
            and exact_int(projection.get("world_build_count"), 0)
            and exact_int(projection.get("solver_step_count"), 0),
            f"{code}_HOST_CAP_PROJECTION_{index}",
        )

    require(
        receipt.get("motor_configuration_receipt_sha256")
        == canonical_sha256_v1(configuration)
        and receipt.get("precommand_motor_population_readback_sha256")
        == canonical_sha256_v1(readback)
        and receipt.get("host_cap_projection_binding_sha256")
        == binding["payload_sha256"]
        and receipt.get("payload_sha256") == l12_payload_sha256_v1(receipt),
        f"{code}_DIGEST_BINDINGS",
    )
    return {
        "evaluation_segment_id": expected_evaluation_segment,
        "walking_session_id": expected_session_id,
        "global_semantic_step": expected_global_semantic_step,
        "payload_sha256": receipt["payload_sha256"],
        "host_cap_projection_binding_sha256": binding["payload_sha256"],
        "qualified_projection_count": len(expected_projections),
        "native_readback_count": len(JOINT_IDS) * 3,
        "motor_configuration_write_count": len(JOINT_IDS) * 2,
        "solver_step_count": 0,
    }


def validate_l9_walking_sessions(
    sessions: Any, role: str
) -> dict[str, Any]:
    require(isinstance(sessions, list), f"L9_{role}_WALKING_SESSIONS_NOT_ARRAY")
    by_segment: dict[str, bool] = {}
    by_segment_receipt: dict[str, Mapping[str, Any]] = {}
    session_ids: set[str] = set()
    ordered_receipts: list[Mapping[str, Any]] = []
    for index, session in enumerate(sessions):
        require(isinstance(session, dict), f"L9_{role}_WALKING_SESSION_{index}")
        segment = session.get("evaluation_segment_id")
        session_id = session.get("session_id")
        evaluation = session.get("evaluation")
        require(
            segment in {"walking_prefix", "walking_resume", "matched_continuation"}
            and segment not in by_segment
            and isinstance(session_id, str)
            and bool(session_id)
            and session_id not in session_ids
            and isinstance(evaluation, dict)
            and evaluation.get("ok") is True
            and evaluation.get("evidence_valid") is True
            and evaluation.get("outcome_complete") is True
            and isinstance(evaluation.get("behavior_passed"), bool)
            and evaluation.get("arm_id") == role
            and evaluation.get("segment_id") == segment
            and evaluation.get("physical_acceptance_authority") is False
            and evaluation.get("release_authority") is False,
            f"L9_{role}_WALKING_SESSION_FIELDS_{index}",
        )
        session_ids.add(session_id)
        by_segment[str(segment)] = bool(evaluation["behavior_passed"])
        by_segment_receipt[str(segment)] = session
        ordered_receipts.append(session)
    return {
        "session_count": len(sessions),
        "ordered_receipts": ordered_receipts,
        "ordered_session_ids": [str(value["session_id"]) for value in ordered_receipts],
        "behavior_by_segment": by_segment,
        "receipt_by_segment": by_segment_receipt,
        "all_retained_session_behaviors_passed": all(by_segment.values()),
    }


def validate_l12_walking_handoff_population(
    arm: Mapping[str, Any],
    walking: Mapping[str, Any],
    *,
    role: str,
    model_instance_id: str,
    complete_precondition: bool,
    release_projection: Mapping[str, Any],
    maximum_step: int,
    source_proven_no_resume_negative: bool = False,
) -> dict[str, Any]:
    handoffs = arm.get("walking_actuation_handoff_receipts")
    require(isinstance(handoffs, list), f"L12_{role}_HANDOFFS_NOT_ARRAY")
    require(
        isinstance(source_proven_no_resume_negative, bool)
        and (not source_proven_no_resume_negative or (role == ACTIVE_ARM and complete_precondition)),
        f"L14_{role}_NO_RESUME_POPULATION_SELECTION",
    )
    expected_segments = (
        []
        if not complete_precondition
        else (
            ["walking_prefix", "matched_continuation"]
            if role == BASELINE_ARM
            else (
                ["walking_prefix"]
                if source_proven_no_resume_negative
                else ["walking_prefix", "walking_resume"]
            )
        )
    )
    sessions = walking.get("ordered_receipts")
    require(
        isinstance(sessions, list)
        and len(sessions) == len(expected_segments)
        and len(handoffs) == len(expected_segments),
        f"L12_{role}_HANDOFF_POPULATION_COUNT",
    )
    if not complete_precondition:
        return {
            "handoff_count": 0,
            "ordered_evaluation_segments": [],
            "ordered_global_semantic_steps": [],
            "ordered_session_ids": [],
            "ordered_payload_sha256s": [],
            "qualified_projection_count_per_handoff": 0,
            "extra_solver_step_count": 0,
        }

    release_step = release_projection.get("global_semantic_step")
    require(
        bounded_int(release_step, 1, maximum_step),
        f"L12_{role}_RELEASE_STEP_FOR_HANDOFF",
    )
    prior_step = int(release_step)
    projected: list[dict[str, Any]] = []
    observed_session_ids: set[str] = set()
    for index, expected_segment in enumerate(expected_segments):
        session = sessions[index]
        handoff = handoffs[index]
        require(
            isinstance(session, dict) and isinstance(handoff, dict),
            f"L12_{role}_HANDOFF_SHAPE_{index}",
        )
        session_id = session.get("session_id")
        handoff_step = handoff.get("global_semantic_step")
        expected_facade_segment = (
            "walking_prefix" if expected_segment == "walking_prefix" else "walking_resume"
        )
        start = session.get("start_receipt")
        require(
            session.get("evaluation_segment_id") == expected_segment
            and isinstance(session_id, str)
            and bool(session_id)
            and session_id not in observed_session_ids
            and bounded_int(handoff_step, prior_step + 1, maximum_step)
            and (index != 0 or int(handoff_step) == int(release_step) + 1)
            and isinstance(start, dict)
            and start.get("schema_version")
            == "sporespore_qsdk_r10f_recovery_native_locomotion_session_v1"
            and start.get("gate_id") == "QSDK-R10F"
            and start.get("ok") is True
            and start.get("facade_id") == WALKING_FACADE_ID
            and start.get("model_instance_id") == model_instance_id
            and start.get("segment_id") == expected_facade_segment
            and start.get("session_id") == session_id
            and exact_int(start.get("global_start_step"), int(handoff_step) - 1)
            and start.get("selected_policy_id") == POLICY_ID
            and start.get("task_frame_reanchored_in_controller_memory") is True
            and start.get("task_frame_frozen_for_walking_segment") is True
            and exact_int(start.get("body_transform_write_count"), 0)
            and exact_int(start.get("body_velocity_write_count"), 0)
            and exact_int(start.get("solver_reset_count"), 0)
            and exact_int(start.get("model_construction_count"), 0)
            and exact_int(start.get("world_attempt_count"), 0)
            and exact_int(start.get("world_build_count"), 0)
            and exact_int(start.get("solver_step_count"), 0)
            and start.get("physics_state_modified") is False
            and start.get("physical_acceptance_authority") is False
            and start.get("release_authority") is False,
            f"L12_{role}_SESSION_HANDOFF_BINDING_{index}",
        )
        projection = validate_l12_walking_handoff(
            handoff,
            expected_model_instance_id=model_instance_id,
            expected_evaluation_segment=expected_segment,
            expected_session_id=session_id,
            expected_global_semantic_step=int(handoff_step),
        )
        projected.append(projection)
        observed_session_ids.add(session_id)
        prior_step = int(handoff_step)
    return {
        "handoff_count": len(projected),
        "ordered_evaluation_segments": expected_segments,
        "ordered_global_semantic_steps": [
            value["global_semantic_step"] for value in projected
        ],
        "ordered_session_ids": [value["walking_session_id"] for value in projected],
        "ordered_payload_sha256s": [value["payload_sha256"] for value in projected],
        "qualified_projection_count_per_handoff": len(JOINT_IDS),
        "native_readback_count": sum(value["native_readback_count"] for value in projected),
        "motor_configuration_write_count": sum(
            value["motor_configuration_write_count"] for value in projected
        ),
        "extra_solver_step_count": sum(value["solver_step_count"] for value in projected),
    }


def validate_l9_interaction_source(
    interaction: Any,
    *,
    parent_attempt_id: str,
    child_attempt_id: str,
    role: str,
    model_instance_id: str,
    maximum_step: int,
    prefix_session: Mapping[str, Any],
) -> dict[str, Any]:
    expected_keys = {
        "schema_version",
        "gate_id",
        "repair_id",
        "parent_attempt_id",
        "child_attempt_id",
        "arm_id",
        "model_instance_id",
        "completed_effect_global_step",
        "interaction_local_step",
        "prefix_session_id",
        "prefix_session_receipt_sha256",
        "task_frame_forward_axis_world_host_real",
        "task_frame_lateral_axis_world_host_real",
        "scheduled_impulse_world_n_s",
        "pre_event_velocity_world_m_s",
        "completed_effect_velocity_world_m_s",
        "raw_velocity_delta_world_m_s",
        "raw_velocity_delta_magnitude_m_s",
        "application_count",
        "source_measurement",
        "outcome_derived_correction",
        "global_step_rewritten_for_pair_alignment",
        "force_aware_recovery_used",
        "physical_acceptance_authority",
        "release_authority",
        "payload_sha256",
    }
    require(isinstance(interaction, dict), f"L9_{role}_INTERACTION_NOT_OBJECT")
    require(set(interaction) == expected_keys, f"L9_{role}_INTERACTION_KEY_SET")
    forward = vector3(
        interaction.get("task_frame_forward_axis_world_host_real"),
        f"L9_{role}_INTERACTION_FORWARD",
    )
    lateral = vector3(
        interaction.get("task_frame_lateral_axis_world_host_real"),
        f"L9_{role}_INTERACTION_LATERAL",
    )
    impulse = vector3(
        interaction.get("scheduled_impulse_world_n_s"),
        f"L9_{role}_INTERACTION_IMPULSE",
    )
    before = vector3(
        interaction.get("pre_event_velocity_world_m_s"),
        f"L9_{role}_INTERACTION_BEFORE",
    )
    after = vector3(
        interaction.get("completed_effect_velocity_world_m_s"),
        f"L9_{role}_INTERACTION_AFTER",
    )
    retained_delta = vector3(
        interaction.get("raw_velocity_delta_world_m_s"),
        f"L9_{role}_INTERACTION_DELTA",
    )
    computed_delta = vector_subtract(after, before)
    require(
        interaction.get("schema_version") == INTERACTION_SCHEMA
        and interaction.get("gate_id") == "QSDK-R10F"
        and interaction.get("repair_id") == CHILD_CONTRACT_REPAIR_ID
        and interaction.get("parent_attempt_id") == parent_attempt_id
        and interaction.get("child_attempt_id") == child_attempt_id
        and interaction.get("arm_id") == role
        and interaction.get("model_instance_id") == model_instance_id
        and bounded_int(interaction.get("completed_effect_global_step"), 2, maximum_step)
        and exact_int(interaction.get("interaction_local_step"), 1)
        and interaction.get("prefix_session_id") == prefix_session.get("session_id")
        and interaction.get("prefix_session_receipt_sha256")
        == canonical_sha256_v1(prefix_session)
        and abs(vector_norm(forward) - 1.0) <= VECTOR_ALLOWANCE
        and abs(vector_norm(lateral) - 1.0) <= VECTOR_ALLOWANCE
        and abs(sum(forward[index] * lateral[index] for index in range(3)))
        <= VECTOR_ALLOWANCE
        and vector_close(retained_delta, computed_delta, 1.0e-12)
        and finite_number(interaction.get("raw_velocity_delta_magnitude_m_s"))
        and abs(
            float(interaction["raw_velocity_delta_magnitude_m_s"])
            - vector_norm(retained_delta)
        )
        <= 1.0e-12
        and interaction.get("source_measurement") is True
        and interaction.get("outcome_derived_correction") is False
        and interaction.get("global_step_rewritten_for_pair_alignment") is False
        and interaction.get("force_aware_recovery_used") is False
        and interaction.get("physical_acceptance_authority") is False
        and interaction.get("release_authority") is False
        and interaction.get("payload_sha256") == payload_sha256_v1(interaction),
        f"L9_{role}_INTERACTION_FIELDS",
    )
    if role == ACTIVE_ARM:
        expected_impulse = tuple(
            component * KICK_IMPULSE_MAGNITUDE_N_S for component in lateral
        )
        require(
            exact_int(interaction.get("application_count"), 1)
            and vector_close(impulse, expected_impulse, VECTOR_ALLOWANCE)
            and abs(vector_norm(impulse) - KICK_IMPULSE_MAGNITUDE_N_S)
            <= IMPULSE_ALLOWANCE
            and vector_norm(retained_delta) >= NATIVE_EFFECT_FLOOR_M_S,
            "L9_ACTIVE_INTERACTION_ROLE_SOURCE",
        )
    else:
        require(
            exact_int(interaction.get("application_count"), 0)
            and vector_norm(impulse) == 0.0,
            "L9_BASELINE_INTERACTION_ROLE_SOURCE",
        )
    return {
        "completed_effect_global_step": interaction["completed_effect_global_step"],
        "forward_axis": list(forward),
        "lateral_axis": list(lateral),
        "scheduled_impulse_world_n_s": list(impulse),
        "raw_velocity_delta_world_m_s": list(retained_delta),
        "raw_velocity_delta_magnitude_m_s": vector_norm(retained_delta),
        "application_count": interaction["application_count"],
        "payload_sha256": interaction["payload_sha256"],
    }


def validate_l9_child_report(
    report: Any,
    *,
    expected_role: str,
    expected_parent_attempt_id: str,
    expected_child_attempt_id: str,
    expected_source_commit: str,
    expected_authority_sha256: str,
    expected_worker_process_id: int,
    require_l15_family: bool = False,
) -> dict[str, Any]:
    # The enclosing source-selected reader chooses this opt-in; never infer an
    # expected family from the offered report. No qualification is granted here.
    require(type(require_l15_family) is bool, "L15_CHILD_FAMILY_MODE_KIND")
    expected_repair = "QSDK-R10F-L15" if require_l15_family else REPAIR_ID
    require(isinstance(report, dict), f"L9_{expected_role}_REPORT_NOT_OBJECT")
    configuration = report.get("configuration")
    arm = report.get("arm_result")
    require(
        report.get("schema_version") == RAW_SCHEMA
        and report.get("gate_id") == "QSDK-R10F"
        and report.get("repair_id") == expected_repair
        and report.get("work_id") == work_id_for_family(expected_repair)
        and report.get("question_class") == "development"
        and report.get("ledger_scope")
        == ledger_scope("consumed_process_isolated_child_physical_development_raw")
        and report.get("status")
        == "valid_complete_process_isolated_child_development"
        and report.get("ok") is True
        and report.get("measurement_complete") is True
        and report.get("scientific_outcome") == "none"
        and report.get("source_commit") == expected_source_commit
        and report.get("authorization_sha256") == expected_authority_sha256
        and report.get("parent_attempt_id") == expected_parent_attempt_id
        and report.get("child_attempt_id") == expected_child_attempt_id
        and report.get("attempt_id") == expected_child_attempt_id
        and report.get("arm_id") == expected_role
        and exact_int(report.get("process_id"), expected_worker_process_id)
        and exact_int(report.get("seed"), SEED)
        and report.get("seed_sha256") == SEED_SHA256
        and report.get("actuator_mode")
        == "solver_coupled_native_constraint_motor_v1"
        and report.get("recovery_controller_id") == RECOVERY_CONTROLLER_ID
        and isinstance(report.get("energy_route_id"), str)
        and bool(report.get("energy_route_id"))
        and exact_int(report.get("physics_ticks_per_second"), 120)
        and report.get("held_out") is False
        and exact_int(report.get("held_out_cell_access_count"), 0)
        and report.get("population_inference_claimed") is False
        and report.get("one_arm_per_process") is True
        and report.get("one_world_per_process") is True
        and report.get("world_or_body_state_imported_from_peer") is False
        and isinstance(configuration, dict)
        and isinstance(arm, dict)
        and report.get("physical_question_opened") is True
        and report.get("physics_state_modified") is True
        and report.get("force_aware_recovery") is False
        and report.get("force_aware_bracing") is False
        and report.get("arbitrary_fall_recovery_claimed") is False
        and report.get("cross_engine_push_recovery_claimed") is False
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False,
        f"L9_{expected_role}_REPORT_FIELDS",
    )
    require(
        configuration.get("ok") is True
        and configuration.get("gate_id") == "QSDK-R10F"
        and configuration.get("selected_policy_id") == POLICY_ID
        and configuration.get("selected_policy_digest") == POLICY_SHA256
        and configuration.get("recovery_morphology_spec_sha256")
        == RECOVERY_MORPHOLOGY_SHA256
        and configuration.get("actuator_profile_id") == ACTUATOR_PROFILE_ID
        and configuration.get("material_profile_id") == MATERIAL_PROFILE_ID
        and is_sha256(configuration.get("actuator_profile_sha256"))
        and is_sha256(configuration.get("material_profile_sha256"))
        and is_sha256(configuration.get("recovery_context_sha256"))
        and configuration.get("post_construction_transform_write_permitted") is False
        and configuration.get("post_construction_velocity_write_permitted") is False
        and configuration.get("solver_reset_permitted") is False
        and configuration.get("event_triggered_passive_recovery") is True
        and configuration.get("force_aware_recovery") is False
        and report.get("configuration_sha256") == canonical_sha256_v1(configuration),
        f"L9_{expected_role}_CONFIGURATION",
    )
    solver_steps = report.get("solver_step_count")
    require(
        exact_int(report.get("model_construction_attempt_count"), 1)
        and exact_int(report.get("model_construction_count"), 1)
        and exact_int(report.get("world_attempt_count"), 1)
        and exact_int(report.get("world_build_count"), 1)
        and bounded_int(solver_steps, 1, 3842)
        and exact_int(report.get("maximum_solver_step_count"), 3842)
        and exact_int(report.get("global_solver_frame_count"), int(solver_steps))
        and exact_int(report.get("complete_trace_count"), 1)
        and exact_int(report.get("behavior_evaluator_invocation_count"), 0)
        and bounded_int(report.get("explicit_worker_extra_native_readback_count"), 0, 10**9)
        and report.get("all_in_run_physical_invariants_passed") is True
        and report.get("same_body_identity_preserved") is True,
        f"L9_{expected_role}_COUNTERS",
    )
    require(
        arm.get("schema_version") == ARM_RESULT_SCHEMA
        and arm.get("gate_id") == "QSDK-R10F"
        and arm.get("repair_id") == expected_repair
        and arm.get("ok") is True
        and arm.get("parent_attempt_id") == expected_parent_attempt_id
        and arm.get("child_attempt_id") == expected_child_attempt_id
        and arm.get("arm_id") == expected_role
        and isinstance(arm.get("model_instance_id"), str)
        and bool(arm.get("model_instance_id"))
        and is_sha256(arm.get("body_population_instance_sha256"))
        and arm.get("same_body_identity_preserved") is True
        and exact_int(arm.get("outer_step_count"), int(solver_steps))
        and exact_int(arm.get("native_solver_step_count"), int(solver_steps))
        and exact_int(arm.get("body_population_rebuild_count"), 0)
        and exact_int(arm.get("body_transform_write_count"), 0)
        and exact_int(arm.get("body_velocity_write_count"), 0)
        and exact_int(arm.get("solver_reset_count"), 0)
        and arm.get("global_step_values_rewritten_for_pair_alignment") is False
        and arm.get("full_trace_retained") is True
        and arm.get("all_in_run_physical_invariants_passed") is True
        and arm.get("physical_acceptance_authority") is False
        and arm.get("release_authority") is False,
        f"L9_{expected_role}_ARM_FIELDS",
    )
    model_instance_id = str(arm["model_instance_id"])
    body_identity = arm["body_population_instance_sha256"]
    initial_identity = arm.get("initial_same_body_identity_receipt")
    terminal_identity = arm.get("terminal_same_body_identity_receipt")
    initial_application = arm.get("initial_application_validation_receipt")
    require(
        isinstance(initial_identity, dict)
        and initial_identity.get("body_population_instance_sha256") == body_identity
        and isinstance(terminal_identity, dict)
        and terminal_identity.get("body_population_instance_sha256") == body_identity
        and isinstance(initial_application, dict)
        and initial_application.get("schema_version")
        == "sporespore_qsdk_r10f_initial_bootstrap_application_validation_v1"
        and initial_application.get("gate_id") == "QSDK-R10F"
        and initial_application.get("ok") is True
        and exact_int(initial_application.get("check_count"), 11)
        and initial_application.get("failed_checks") == []
        and exact_int(initial_application.get("model_construction_count"), 0)
        and exact_int(initial_application.get("world_attempt_count"), 0)
        and exact_int(initial_application.get("world_build_count"), 0)
        and exact_int(initial_application.get("scene_tree_insertion_count"), 0)
        and exact_int(initial_application.get("native_readback_count"), 0)
        and exact_int(initial_application.get("solver_step_count"), 0)
        and initial_application.get("physics_state_modified") is False
        and initial_application.get("physical_acceptance_authority") is False
        and initial_application.get("release_authority") is False,
        f"L9_{expected_role}_BODY_IDENTITY_OR_INITIAL_APPLICATION",
    )
    trace = arm.get("trace")
    rows = trace.get("rows") if isinstance(trace, dict) else None
    invariants = arm.get("in_run_invariant_receipts")
    require(
        isinstance(trace, dict)
        and trace.get("schema_version") == TRACE_SCHEMA
        and trace.get("gate_id") == "QSDK-R10F"
        and trace.get("repair_id") == expected_repair
        and trace.get("parent_attempt_id") == expected_parent_attempt_id
        and trace.get("child_attempt_id") == expected_child_attempt_id
        and trace.get("arm_id") == expected_role
        and trace.get("model_instance_id") == model_instance_id
        and trace.get("body_population_instance_sha256") == body_identity
        and isinstance(rows, list)
        and len(rows) == solver_steps
        and arm.get("trace_sha256") == canonical_sha256_v1(trace)
        and isinstance(invariants, list)
        and len(invariants) == solver_steps
        and exact_int(arm.get("in_run_invariant_receipt_count"), int(solver_steps))
        and exact_int(
            report.get("in_run_invariant_receipt_count"), int(solver_steps)
        ),
        f"L9_{expected_role}_TRACE_OR_INVARIANT_POPULATION",
    )
    for index, (row, invariant) in enumerate(zip(rows, invariants), start=1):
        require(
            isinstance(row, dict) and row.get("source_measurement") is True,
            f"L9_{expected_role}_TRACE_SOURCE_{index}",
        )
        validate_solver_counter_invariant(
            expected_role,
            index,
            row,
            invariant,
            body_identity,
        )
    terminal = report.get("precondition_terminal_receipt")
    terminal_projection = validate_l9_terminal_receipt(
        terminal,
        parent_attempt_id=expected_parent_attempt_id,
        child_attempt_id=expected_child_attempt_id,
        role=expected_role,
        model_instance_id=model_instance_id,
        maximum_step=int(solver_steps),
    )
    require(
        report.get("precondition_terminal_receipt_sha256")
        == terminal_projection["payload_sha256"]
        and arm.get("precondition_terminal_receipt") == terminal
        and arm.get("precondition_terminal_receipt_sha256")
        == terminal_projection["payload_sha256"],
        f"L9_{expected_role}_TERMINAL_BINDINGS",
    )
    complete_precondition = (
        terminal_projection["disposition"] == "complete_source_retained"
    )
    release = report.get("precondition_release_receipt")
    release_projection: dict[str, Any] = {}
    if complete_precondition:
        release_projection = validate_l9_release_receipt(
            release,
            terminal,
            parent_attempt_id=expected_parent_attempt_id,
            child_attempt_id=expected_child_attempt_id,
            role=expected_role,
            model_instance_id=model_instance_id,
        )
        require(
            report.get("precondition_release_receipt_sha256")
            == release_projection["payload_sha256"]
            and arm.get("precondition_release_receipt") == release
            and arm.get("precondition_release_receipt_sha256")
            == release_projection["payload_sha256"]
            and arm.get("precondition_release_receipt_valid") is True,
            f"L9_{expected_role}_RELEASE_BINDINGS",
        )
    else:
        require(
            release == {}
            and report.get("precondition_release_receipt_sha256") == ""
            and arm.get("precondition_release_receipt") == {}
            and arm.get("precondition_release_receipt_sha256") == ""
            and arm.get("precondition_release_receipt_valid") is False,
            f"L9_{expected_role}_NEGATIVE_RELEASE_ABSENCE",
        )
    walking = validate_l9_walking_sessions(arm.get("walking_sessions"), expected_role)
    no_resume_terminal: dict[str, Any] = {}
    terminal_transition = arm.get("terminal_orchestrator_transition")
    terminal_before = (
        terminal_transition.get("state_before")
        if isinstance(terminal_transition, dict) else None
    )
    terminal_before_resume = (
        isinstance(terminal_before, dict)
        and terminal_before.get("phase") in {l14_no_resume.CONFIRM, l14_no_resume.RECOVERY}
    )
    if complete_precondition and expected_role == ACTIVE_ARM and (
        walking["session_count"] != 2
        or report.get("reached_walking_resume") is not True
        or terminal_before_resume
    ):
        # A missing resume is never a proof. Validate the recorded failed
        # transition and its full enclosing source links before selecting the
        # one-session population. Baseline and resumed branches are unchanged.
        try:
            no_resume_terminal = l14_no_resume.validate_no_resume_terminal(
                report,
                canonical_sha256=canonical_sha256_v1,
                payload_sha256=payload_sha256_v1,
                native_step_matches=integer_valued_native_step_matches,
            )
        except (ValueError, KeyError, TypeError, AttributeError) as exc:
            raise ClosureFailure(f"L14_{expected_role}_NO_RESUME_SOURCE:{exc}") from exc
    walking_handoffs = validate_l12_walking_handoff_population(
        arm,
        walking,
        role=expected_role,
        model_instance_id=model_instance_id,
        complete_precondition=complete_precondition,
        release_projection=release_projection,
        maximum_step=int(solver_steps),
        source_proven_no_resume_negative=bool(no_resume_terminal),
    )
    reached_interaction = report.get("reached_interaction")
    require(isinstance(reached_interaction, bool), f"L9_{expected_role}_REACHED_TYPE")
    interaction = report.get("interaction_source")
    interaction_projection: dict[str, Any] = {}
    if reached_interaction:
        prefix = walking["receipt_by_segment"].get("walking_prefix")
        require(isinstance(prefix, dict), f"L9_{expected_role}_PREFIX_SESSION_MISSING")
        prefix_source = l14_terminal.interaction_start_projection(
            prefix,
            interaction,
            model_instance_id=model_instance_id,
            canonical_sha256=canonical_sha256_v1,
        )
        require(
            prefix_source["ok"],
            f"L14_{expected_role}_INTERACTION_START_SOURCE:"
            + ",".join(prefix_source["failed_predicates"]),
        )
        interaction_projection = validate_l9_interaction_source(
            interaction,
            parent_attempt_id=expected_parent_attempt_id,
            child_attempt_id=expected_child_attempt_id,
            role=expected_role,
            model_instance_id=model_instance_id,
            maximum_step=int(solver_steps),
            prefix_session=prefix_source["start_receipt"],
        )
        require(
            report.get("interaction_source_sha256")
            == interaction_projection["payload_sha256"]
            and arm.get("interaction_source") == interaction,
            f"L9_{expected_role}_INTERACTION_BINDINGS",
        )
    else:
        require(
            interaction == {}
            and report.get("interaction_source_sha256") == ""
            and arm.get("interaction_source") == {},
            f"L9_{expected_role}_INTERACTION_ABSENCE",
        )
    expected_kicks = 1 if reached_interaction and expected_role == ACTIVE_ARM else 0
    require(
        exact_int(report.get("external_kick_application_count"), expected_kicks)
        and exact_int(arm.get("external_kick_application_count"), expected_kicks),
        f"L9_{expected_role}_KICK_COUNT",
    )
    role_outcome = report.get("role_outcome")
    if not complete_precondition:
        require(
            role_outcome == "precondition_negative"
            and report.get("reached_walking_prefix") is False
            and reached_interaction is False
            and report.get("reached_post_kick_recovery") is False
            and report.get("reached_walking_resume") is False
            and walking["session_count"] == 0,
            f"L9_{expected_role}_PRECONDITION_NEGATIVE_OUTCOME",
        )
    elif expected_role == BASELINE_ARM:
        require(
            role_outcome == "matched_reference_complete"
            and report.get("reached_walking_prefix") is True
            and reached_interaction is True
            and {"walking_prefix", "matched_continuation"}
            <= set(walking["behavior_by_segment"]),
            "L9_BASELINE_ROLE_OUTCOME",
        )
    else:
        require(
            role_outcome in {"behavior_positive", "behavior_negative"}
            and report.get("reached_walking_prefix") is True
            and reached_interaction is True
            and "walking_prefix" in walking["behavior_by_segment"],
            "L9_ACTIVE_ROLE_OUTCOME",
        )
        if role_outcome == "behavior_positive":
            require(
                report.get("reached_post_kick_recovery") is True
                and report.get("reached_walking_resume") is True
                and "walking_resume" in walking["behavior_by_segment"]
                and walking["all_retained_session_behaviors_passed"] is True,
                "L9_ACTIVE_POSITIVE_ROUTE",
            )
    expected_observed = role_outcome == "behavior_positive"
    for key in ("event_triggered_passive_recovery_observed", "recovery_success_observed"):
        if key in report:
            require(
                report.get(key) is expected_observed,
                f"L9_{expected_role}_{key.upper()}",
            )
    for key in ("prone_to_standing_claimed", "kick_impulse_alone_causes_fall_claimed"):
        if key in report:
            require(report.get(key) is False, f"L9_{expected_role}_{key.upper()}")
    return {
        "role": expected_role,
        "child_attempt_id": expected_child_attempt_id,
        "process_id": expected_worker_process_id,
        "disposition": terminal_projection["disposition"],
        "complete_precondition": complete_precondition,
        "role_outcome": role_outcome,
        "solver_step_count": solver_steps,
        "configuration_sha256": report["configuration_sha256"],
        "model_instance_id": model_instance_id,
        "body_population_instance_sha256": body_identity,
        "trace_sha256": arm["trace_sha256"],
        "walking": {
            "session_count": walking["session_count"],
            "behavior_by_segment": walking["behavior_by_segment"],
            "all_retained_session_behaviors_passed": walking[
                "all_retained_session_behaviors_passed"
            ],
        },
        "walking_actuation_handoffs": walking_handoffs,
        "no_resume_terminal": no_resume_terminal,
        "terminal": terminal_projection,
        "release": release_projection,
        "interaction": interaction_projection,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_l9_pair_from_children(
    baseline: Mapping[str, Any], active: Mapping[str, Any]
) -> dict[str, Any]:
    if not baseline["complete_precondition"] or not active["complete_precondition"]:
        negative_roles = [
            child["role"]
            for child in (baseline, active)
            if not child["complete_precondition"]
        ]
        return {
            "classification": "invalid_or_incomplete_no_behavioral_conclusion",
            "status": "valid_complete_precondition_diagnostic_no_r10f_behavioral_outcome",
            "ok": True,
            "evidence_valid": True,
            "measurement_complete": True,
            "route_execution_valid": False,
            "outcome_complete": False,
            "behavior_passed": False,
            "scientific_outcome": "none",
            "failure_code": "QSDK_R10F_L9_PRECONDITION_NEGATIVE_RETAINED",
            "precondition_negative_roles": negative_roles,
            "computed_measurements": {},
            "false_route_receipts": [],
        }
    baseline_source = baseline["interaction"]
    active_source = active["interaction"]
    baseline_forward = tuple(baseline_source["forward_axis"])
    active_forward = tuple(active_source["forward_axis"])
    baseline_lateral = tuple(baseline_source["lateral_axis"])
    active_lateral = tuple(active_source["lateral_axis"])
    require(
        vector_close(active_forward, baseline_forward, VECTOR_ALLOWANCE)
        and vector_close(active_lateral, baseline_lateral, VECTOR_ALLOWANCE),
        "L9_PAIR_TASK_FRAME_MISMATCH",
    )
    active_delta = tuple(active_source["raw_velocity_delta_world_m_s"])
    baseline_delta = tuple(baseline_source["raw_velocity_delta_world_m_s"])
    paired_delta = vector_subtract(active_delta, baseline_delta)
    paired_magnitude = vector_norm(paired_delta)
    require(
        paired_magnitude >= NATIVE_EFFECT_FLOOR_M_S,
        "L9_PAIR_NATIVE_EFFECT_BELOW_FROZEN_FLOOR",
    )
    baseline_segments = baseline["walking"]["behavior_by_segment"]
    active_segments = active["walking"]["behavior_by_segment"]
    require(
        {"walking_prefix", "matched_continuation"} <= set(baseline_segments)
        and "walking_prefix" in active_segments,
        "L9_PAIR_ROUTE_EVIDENCE_MISSING",
    )
    active_positive = active["role_outcome"] == "behavior_positive"
    if active_positive:
        require("walking_resume" in active_segments, "L9_PAIR_ACTIVE_RESUME_MISSING")
    behavior = (
        baseline["role_outcome"] == "matched_reference_complete"
        and active_positive
        and baseline["walking"]["all_retained_session_behaviors_passed"]
        and active["walking"]["all_retained_session_behaviors_passed"]
    )
    measurements = {
        "active_completed_effect_global_step": active_source[
            "completed_effect_global_step"
        ],
        "baseline_completed_effect_global_step": baseline_source[
            "completed_effect_global_step"
        ],
        "interaction_local_step": 1,
        "task_frame_impulse_n_s": [0.0, 0.0, KICK_IMPULSE_MAGNITUDE_N_S],
        "active_velocity_delta_world_m_s": list(active_delta),
        "active_velocity_delta_magnitude_m_s": vector_norm(active_delta),
        "baseline_velocity_delta_world_m_s": list(baseline_delta),
        "baseline_velocity_delta_magnitude_m_s": vector_norm(baseline_delta),
        "paired_kick_effect_delta_world_m_s": list(paired_delta),
        "paired_kick_effect_magnitude_m_s": paired_magnitude,
        "native_effect_floor_m_s": NATIVE_EFFECT_FLOOR_M_S,
        "matched_no_kick_delta_subtracted": True,
    }
    return {
        "classification": (
            "valid_complete_behavior_positive"
            if behavior
            else "valid_complete_behavior_development_negative"
        ),
        "status": (
            "valid_complete_behavior_positive_development"
            if behavior
            else "valid_complete_behavior_negative_development"
        ),
        "ok": True,
        "evidence_valid": True,
        "measurement_complete": True,
        "route_execution_valid": True,
        "outcome_complete": True,
        "behavior_passed": behavior,
        "scientific_outcome": "positive" if behavior else "negative",
        "failure_code": "",
        "precondition_negative_roles": [],
        "computed_measurements": measurements,
        "false_route_receipts": (
            []
            if behavior
            else [
                segment
                for segment, passed in active_segments.items()
                if not passed
            ]
        ),
    }


def project_l9_engine_health(stderr: str) -> dict[str, Any]:
    stderr_bytes = stderr.encode("utf-8")
    nonempty_lines = [line for line in stderr.splitlines() if line]
    fatal_lines: list[str] = []
    unique_fatal_lines: list[str] = []
    engine_error_count = 0
    assertion_failure_count = 0
    assertion_site_count = 0
    for line in nonempty_lines:
        trimmed = line.lstrip()
        engine_error = trimmed.startswith(("ERROR:", "SCRIPT ERROR:", "FATAL:", "CRASH:"))
        assertion_failure = "Jolt Physics assertion" in trimmed
        assertion_site = trimmed.startswith("at: jolt_assert")
        engine_error_count += int(engine_error)
        assertion_failure_count += int(assertion_failure)
        assertion_site_count += int(assertion_site)
        if engine_error or assertion_failure or assertion_site:
            fatal_lines.append(line)
            if line not in unique_fatal_lines:
                unique_fatal_lines.append(line)
    return {
        "schema_version": "sporespore_godot_engine_health_projection_v1",
        "selector_id": "godot_typed_fatal_diagnostic_selector_v1",
        "stderr_raw_byte_length": len(stderr_bytes),
        "stderr_raw_sha256": "sha256:" + hashlib.sha256(stderr_bytes).hexdigest(),
        "stderr_nonempty_line_count": len(nonempty_lines),
        "engine_error_line_count": engine_error_count,
        "native_assertion_failure_line_count": assertion_failure_count,
        "native_assertion_site_line_count": assertion_site_count,
        "fatal_diagnostic_line_count": len(fatal_lines),
        "fatal_diagnostic_unique_line_count": len(unique_fatal_lines),
        "ordered_unique_fatal_diagnostic_lines": unique_fatal_lines,
        "passed": not fatal_lines,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l9_normalized_path(value: Any, code: str) -> Path:
    require(isinstance(value, str) and bool(value), code)
    try:
        return Path(value).resolve()
    except OSError as exc:
        raise ClosureFailure(code) from exc


def l9_observed_counter_projection(envelopes: list[Mapping[str, Any]]) -> dict[str, Any]:
    names = (
        "model_construction_attempt_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "explicit_worker_extra_native_readback_count",
    )
    values: dict[str, int] = {}
    known: dict[str, bool] = {}
    for name in names:
        field_known = bool(envelopes)
        total = 0
        for envelope in envelopes:
            child_report = envelope.get("report")
            value = child_report.get(name) if isinstance(child_report, dict) else None
            if not bounded_int(value, 0, 10**12):
                field_known = False
                break
            total += int(value)
        known[name] = field_known
        values[name] = total if field_known else -1
    core_known = all(
        known[name]
        for name in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
        )
    )
    return {
        "known": known,
        "core_known": core_known,
        **values,
        "physics_state_modified": (
            values["solver_step_count"] > 0 if known["solver_step_count"] else None
        ),
    }


def l9_json_numbers_close(left: Any, right: Any, allowance: float = 1.0e-12) -> bool:
    if isinstance(left, bool) or isinstance(right, bool):
        return left is right
    if finite_number(left) and finite_number(right):
        return abs(float(left) - float(right)) <= allowance
    if isinstance(left, dict) and isinstance(right, dict):
        return set(left) == set(right) and all(
            l9_json_numbers_close(left[key], right[key], allowance) for key in left
        )
    if isinstance(left, list) and isinstance(right, list):
        return len(left) == len(right) and all(
            l9_json_numbers_close(a, b, allowance) for a, b in zip(left, right)
        )
    return left == right


def validate_l9_child_artifact_files(
    envelope: Mapping[str, Any],
    descriptor: Mapping[str, Any],
    *,
    child_root: Path,
    require_l15_launch: bool = False,
    require_l15_collection: bool = False,
) -> dict[str, Any]:
    require(type(require_l15_collection) is bool, "L15_COLLECTION_MODE_TYPE")
    require_l15_collection = require_l15_collection or REPAIR_ID == "QSDK-R10F-L15"
    artifact_bindings = envelope.get("retained_artifact_bindings")
    require(isinstance(artifact_bindings, dict), "L9_CHILD_ARTIFACT_BINDINGS")
    child_identity_path = child_root / "child_attempt_identity.json"
    stdout_path = child_root / "worker.stdout.txt"
    stderr_path = child_root / "worker.stderr.txt"
    termination_path = child_root / "termination_receipt.json"
    health_path = child_root / "engine_health.json"
    envelope_path = child_root / "child_envelope.json"
    required = (
        child_identity_path,
        stdout_path,
        stderr_path,
        termination_path,
        health_path,
        envelope_path,
    )
    require(all(path.is_file() for path in required), "L9_CHILD_COMPANION_FILES")
    bindings = {
        "child_attempt_identity": verify_l9_binding(
            artifact_bindings.get("child_attempt_identity"),
            child_identity_path,
            "L9_CHILD_ATTEMPT_BINDING",
        ),
        "worker_stdout": verify_l9_binding(
            artifact_bindings.get("worker_stdout"), stdout_path, "L9_CHILD_STDOUT_BINDING"
        ),
        "worker_stderr": verify_l9_binding(
            artifact_bindings.get("worker_stderr"), stderr_path, "L9_CHILD_STDERR_BINDING"
        ),
        "termination_receipt": verify_l9_binding(
            artifact_bindings.get("termination_receipt"),
            termination_path,
            "L9_CHILD_TERMINATION_BINDING",
        ),
        "engine_health": verify_l9_binding(
            artifact_bindings.get("engine_health"), health_path, "L9_CHILD_HEALTH_BINDING"
        ),
        "child_envelope": file_identity(envelope_path),
    }
    retained_envelope = (
        l15_collection.parse_json(envelope_path.read_bytes().decode("utf-8"))
        if require_l15_collection
        else read_json(envelope_path, "L9_CHILD_ENVELOPE")
    )
    require(
        l15_collection.same(retained_envelope, envelope)
        if require_l15_collection
        else retained_envelope == envelope,
        "L9_CHILD_ENVELOPE_FILE_BINDING",
    )
    child_identity = read_json(child_identity_path, "L9_CHILD_ATTEMPT_IDENTITY")
    require(
        child_identity.get("schema_version") == CHILD_ATTEMPT_SCHEMA
        and child_identity.get("gate_id") == "QSDK-R10F"
        and child_identity.get("repair_id") == REPAIR_ID
        and child_identity.get("status") == "reserved_and_retained_before_first_child_start"
        and is_identifier(child_identity.get("parent_attempt_id"))
        and child_identity.get("child_attempt_id") == descriptor.get("child_attempt_id")
        and child_identity.get("launch_index") == descriptor.get("launch_index")
        and child_identity.get("role") == descriptor.get("role")
        and child_identity.get("termination_nonce") == descriptor.get("termination_nonce")
        and l9_normalized_path(
            child_identity.get("evidence_path"), "L9_CHILD_IDENTITY_EVIDENCE_PATH"
        )
        == child_root
        and exact_int(child_identity.get("child_retry_count"), 0)
        and exact_int(child_identity.get("child_replacement_count"), 0)
        and child_identity.get("physical_acceptance_authority") is False
        and child_identity.get("release_authority") is False,
        "L9_CHILD_ATTEMPT_IDENTITY_FIELDS",
    )
    require(
        child_identity.get("child_attempt_id") == envelope.get("child_attempt_id"),
        "L9_CHILD_ATTEMPT_ENVELOPE_ID",
    )
    stdout = stdout_path.read_bytes().decode("utf-8")
    stderr = stderr_path.read_bytes().decode("utf-8")
    termination = read_json(termination_path, "L9_CHILD_TERMINATION")
    health = read_json(health_path, "L9_CHILD_ENGINE_HEALTH")
    require(
        termination.get("stdout") == stdout
        and termination.get("stderr") == stderr
        and termination.get("started_utc") == envelope.get("started_utc")
        and termination.get("completed_utc") == envelope.get("completed_utc")
        and termination.get("process_id") == envelope.get("process_id")
        and termination.get("worker_process_id") == envelope.get("worker_process_id")
        and termination.get("exit_code") == envelope.get("exit_code")
        and termination.get("termination_protocol_valid")
        is envelope.get("termination_protocol_valid"),
        "L9_CHILD_TERMINATION_ENVELOPE_BINDING",
    )
    if require_l15_launch or REPAIR_ID == "QSDK-R10F-L15":
        for field, termination_field in (
            ("r10f_l15_launch_relationship", "r10f_l15_launch_relationship"),
            ("termination_ready_receipt", "termination_ready_receipt"),
        ):
            require(
                field in envelope and termination_field in termination
                and l15_launch.same(envelope[field], termination[termination_field]),
                "L15_TERMINATION_FILE_SOURCE_BINDING:" + field,
            )
    require(
        health == project_l9_engine_health(stderr)
        and health.get("passed") is envelope.get("engine_health_passed"),
        "L9_CHILD_ENGINE_HEALTH_RECOMPUTATION",
    )
    raw_lines = [
        line[len(RAW_MARKER) :]
        for line in stdout.splitlines()
        if line.startswith(RAW_MARKER)
    ]
    if envelope.get("raw_marker_valid") is True:
        require(len(raw_lines) == 1, "L9_CHILD_RAW_MARKER_COUNT")
        try:
            logged_raw = (
                l15_collection.parse_json(raw_lines[0])
                if require_l15_collection
                else json.loads(raw_lines[0])
            )
        except ValueError as exc:
            raise ClosureFailure("L9_CHILD_RAW_MARKER_JSON") from exc
        require(
            l15_collection.same(logged_raw, envelope.get("report"))
            if require_l15_collection
            else logged_raw == envelope.get("report"),
            "L9_CHILD_RAW_MARKER_BINDING",
        )
        worker_report_path = child_root / "worker_report.json"
        require(worker_report_path.is_file(), "L9_CHILD_WORKER_REPORT_MISSING")
        verify_l9_binding(
            artifact_bindings.get("worker_report"),
            worker_report_path,
            "L9_CHILD_WORKER_REPORT_BINDING",
        )
        if require_l15_collection:
            worker_report = l15_collection.parse_json(
                worker_report_path.read_bytes().decode("utf-8")
            )
            require(
                l15_collection.same(worker_report, logged_raw),
                "L15_CHILD_WORKER_REPORT_CONTENT",
            )
        else:
            require(
                read_json(worker_report_path, "L9_CHILD_WORKER_REPORT") == logged_raw,
                "L9_CHILD_WORKER_REPORT_CONTENT",
            )
        bindings["worker_report"] = file_identity(worker_report_path)
    else:
        require(
            artifact_bindings.get("worker_report") is None
            and envelope.get("report") is None,
            "L9_CHILD_ABSENT_RAW_BINDING",
        )
        bindings["worker_report"] = None
    ready = termination.get("termination_ready_receipt")
    retained_ready_line = None
    if termination.get("termination_protocol_valid") is True:
        ready_lines = [
            line[len(READY_MARKER) :]
            for line in stdout.splitlines()
            if line.startswith(READY_MARKER)
        ]
        require(len(ready_lines) == 1, "L9_CHILD_READY_MARKER_COUNT")
        retained_ready_line = READY_MARKER + ready_lines[0]
        try:
            logged_ready = json.loads(ready_lines[0])
        except json.JSONDecodeError as exc:
            raise ClosureFailure("L9_CHILD_READY_MARKER_JSON") from exc
        require(
            isinstance(ready, dict)
            and logged_ready == ready
            and ready.get("schema_version")
            == "sporespore_godot_supervised_termination_ready_v1"
            and ready.get("termination_protocol_id")
            == "godot_4_7_gdscript_shutdown_containment_v1"
            and ready.get("termination_nonce") == descriptor.get("termination_nonce")
            and ready.get("process_id") == envelope.get("worker_process_id")
            and ready.get("worker_receipt_emitted") is True
            and ready.get("requested_exit_code") == envelope.get("exit_code")
            and termination.get("timed_out") is False
            and termination.get("supervisor_terminated") is True
            and termination.get("termination_protocol_failure_code") == "",
            "L9_CHILD_TERMINATION_READY_RECEIPT",
        )
    retained_result = {"bindings": bindings, "child_identity": child_identity}
    if require_l15_launch or REPAIR_ID == "QSDK-R10F-L15":
        retained_result["ready_line"] = retained_ready_line
    return retained_result


def validate_l13_native_transport_verification(
    receipt: Any,
    *,
    expected_semantic_step: int,
    expected_controller_receipt_sha256: str,
) -> dict[str, Any]:
    keys = {
        "schema_version",
        "verification_version",
        "ok",
        "policy_id",
        "semantic_step",
        "controller_receipt_schema_version",
        "controller_receipt_sha256",
        "native_actuation_receipt_sha256",
        "raw_native_response_sha256",
        "raw_native_response_byte_length",
        "successful_public_envelope",
        "policy_identity_exact",
        "semantic_step_identity_exact",
        "controller_receipt_schema_exact",
        "native_canonical_receipt_digest_exact",
        "preparse_native_response_verified",
        "raw_native_response_rewritten",
        "post_parse_dictionary_rehash_used",
        "floating_point_measurement_field_count",
        "world_build_count",
        "solver_step_count",
        "physical_acceptance_authority",
        "payload_sha256",
    }
    require(isinstance(receipt, dict), "L13_NATIVE_TRANSPORT_NOT_OBJECT")
    require(
        set(receipt) == keys
        and receipt.get("schema_version") == NATIVE_TRANSPORT_VERIFICATION_SCHEMA
        and receipt.get("verification_version")
        == "sporespore_godot_balanced_wave_native_step_transport_verification_v1"
        and receipt.get("ok") is True
        and receipt.get("policy_id") == POLICY_ID
        and exact_int(receipt.get("semantic_step"), expected_semantic_step)
        and receipt.get("controller_receipt_schema_version")
        == "sporespore_controller_step_receipt_v2"
        and receipt.get("controller_receipt_sha256")
        == expected_controller_receipt_sha256
        and receipt.get("native_actuation_receipt_sha256")
        == expected_controller_receipt_sha256
        and is_sha256(receipt.get("raw_native_response_sha256"))
        and bounded_int(receipt.get("raw_native_response_byte_length"), 1, 10**9)
        and receipt.get("successful_public_envelope") is True
        and receipt.get("policy_identity_exact") is True
        and receipt.get("semantic_step_identity_exact") is True
        and receipt.get("controller_receipt_schema_exact") is True
        and receipt.get("native_canonical_receipt_digest_exact") is True
        and receipt.get("preparse_native_response_verified") is True
        and receipt.get("raw_native_response_rewritten") is False
        and receipt.get("post_parse_dictionary_rehash_used") is False
        and exact_int(receipt.get("floating_point_measurement_field_count"), 0)
        and exact_int(receipt.get("world_build_count"), 0)
        and exact_int(receipt.get("solver_step_count"), 0)
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("payload_sha256") == l12_payload_sha256_v1(receipt),
        "L13_NATIVE_TRANSPORT_FIELDS",
    )
    return {
        "payload_sha256": receipt["payload_sha256"],
        "raw_native_response_sha256": receipt["raw_native_response_sha256"],
        "controller_receipt_sha256": expected_controller_receipt_sha256,
        "semantic_step": expected_semantic_step,
        "floating_point_measurement_field_count": 0,
        "preparse_native_response_verified": True,
        "post_parse_dictionary_rehash_used": False,
    }


def validate_l13_host_target_projection(receipt: Any) -> dict[str, Any]:
    keys = {
        "schema_version",
        "gate_id",
        "ok",
        "projection_rule",
        "projection_kind",
        "ordered_actuator_ids",
        "ordered_target_projections",
        "projection_count",
        "nonzero_controller_target_count",
        "controller_binary64_target_retained_separately",
        "expected_binary32_host_target_retained_separately",
        "application_readback_equals_projection_count",
        "population_readback_equals_projection_count",
        "application_population_readbacks_equal_count",
        "r69_host_cap_exact_count",
        "controller_command_rounded_before_write",
        "host_write_changed",
        "solver_input_changed",
        "empirical_margin_added",
        "tolerance_added",
        "raw_measurement_clamped",
        "outcome_derived_correction",
        "failed_predicate_ids",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
        "payload_sha256",
    }
    row_keys = {
        "actuator_id",
        "joint_id",
        "controller_binary64_target_velocity_rad_s",
        "expected_binary32_host_target_velocity_rad_s",
        "application_host_applied_binary64_target_velocity_rad_s",
        "application_motor_target_velocity_readback_rad_s",
        "population_motor_target_velocity_readback_rad_s",
        "published_cap_nms",
        "authorized_host_cap_nms",
        "application_declared_maximum_impulse_nms",
        "application_motor_maximum_impulse_readback_nms",
        "population_motor_maximum_impulse_readback_nms",
        "controller_request_finite",
        "binary32_projection_finite",
        "application_request_preserved_exactly",
        "application_readback_equals_projection_exactly",
        "population_readback_equals_projection_exactly",
        "application_population_readbacks_equal_exactly",
        "r69_host_cap_exact",
    }
    require(isinstance(receipt, dict), "L13_HOST_TARGET_PROJECTION_NOT_OBJECT")
    rows = receipt.get("ordered_target_projections")
    failures = receipt.get("failed_predicate_ids")
    require(
        set(receipt) == keys
        and receipt.get("schema_version") == HOST_TARGET_PROJECTION_SCHEMA
        and receipt.get("gate_id") == "QSDK-R10F"
        and isinstance(receipt.get("ok"), bool)
        and receipt.get("projection_rule")
        == "float(PackedFloat32Array([controller_target_velocity_rad_s])[0])"
        and receipt.get("projection_kind")
        == "deterministic_host_representation_not_empirical_correction"
        and receipt.get("ordered_actuator_ids") == ACTUATOR_IDS
        and exact_int(receipt.get("projection_count"), len(ACTUATOR_IDS))
        and isinstance(rows, list)
        and len(rows) == len(ACTUATOR_IDS)
        and isinstance(failures, list)
        and len(failures) == len(set(failures))
        and all(isinstance(value, str) and bool(value) for value in failures)
        and receipt.get("controller_binary64_target_retained_separately") is True
        and receipt.get("expected_binary32_host_target_retained_separately") is True
        and receipt.get("controller_command_rounded_before_write") is False
        and receipt.get("host_write_changed") is False
        and receipt.get("solver_input_changed") is False
        and receipt.get("empirical_margin_added") is False
        and receipt.get("tolerance_added") is False
        and receipt.get("raw_measurement_clamped") is False
        and receipt.get("outcome_derived_correction") is False
        and exact_int(receipt.get("model_construction_count"), 0)
        and exact_int(receipt.get("world_attempt_count"), 0)
        and exact_int(receipt.get("world_build_count"), 0)
        and exact_int(receipt.get("solver_step_count"), 0)
        and isinstance(receipt.get("physics_state_modified"), bool)
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False
        and receipt.get("payload_sha256") == l12_payload_sha256_v1(receipt),
        "L13_HOST_TARGET_PROJECTION_FIELDS",
    )
    exact_application = 0
    exact_population = 0
    exact_pair = 0
    exact_caps = 0
    nonzero = 0
    fully_valid_rows = True
    for index, row in enumerate(rows):
        require(
            isinstance(row, dict)
            and set(row) == row_keys
            and row.get("actuator_id") == ACTUATOR_IDS[index]
            and row.get("joint_id") == JOINT_IDS[index]
            and isinstance(row.get("controller_request_finite"), bool)
            and isinstance(row.get("binary32_projection_finite"), bool)
            and isinstance(row.get("application_request_preserved_exactly"), bool)
            and isinstance(
                row.get("application_readback_equals_projection_exactly"), bool
            )
            and isinstance(
                row.get("population_readback_equals_projection_exactly"), bool
            )
            and isinstance(
                row.get("application_population_readbacks_equal_exactly"), bool
            )
            and isinstance(row.get("r69_host_cap_exact"), bool),
            f"L13_HOST_TARGET_PROJECTION_ROW_{index}",
        )
        controller = row.get("controller_binary64_target_velocity_rad_s")
        expected = row.get("expected_binary32_host_target_velocity_rad_s")
        application_request = row.get(
            "application_host_applied_binary64_target_velocity_rad_s"
        )
        application_readback = row.get(
            "application_motor_target_velocity_readback_rad_s"
        )
        population_readback = row.get(
            "population_motor_target_velocity_readback_rad_s"
        )
        published_cap = row.get("published_cap_nms")
        authorized_cap = row.get("authorized_host_cap_nms")
        application_cap = row.get("application_declared_maximum_impulse_nms")
        application_cap_readback = row.get(
            "application_motor_maximum_impulse_readback_nms"
        )
        population_cap_readback = row.get(
            "population_motor_maximum_impulse_readback_nms"
        )
        controller_finite = finite_number(controller)
        expected_binary32 = (
            binary32_v1(float(controller)) if controller_finite else None
        )
        projection_finite = (
            controller_finite
            and finite_number(expected)
            and float(expected) == expected_binary32
        )
        application_request_exact = (
            controller_finite
            and finite_number(application_request)
            and float(application_request) == float(controller)
        )
        application_projection_exact = (
            projection_finite
            and finite_number(application_readback)
            and float(application_readback) == float(expected)
        )
        population_projection_exact = (
            projection_finite
            and finite_number(population_readback)
            and float(population_readback) == float(expected)
        )
        application_population_exact = (
            finite_number(application_readback)
            and finite_number(population_readback)
            and float(application_readback) == float(population_readback)
        )
        r69_host_cap_exact = (
            finite_number(published_cap)
            and finite_number(authorized_cap)
            and finite_number(application_cap)
            and finite_number(application_cap_readback)
            and finite_number(population_cap_readback)
            and float(published_cap) > 0.0
            and float(authorized_cap) > 0.0
            and float(authorized_cap) <= float(published_cap)
            and float(application_cap) == float(authorized_cap)
            and float(application_cap_readback) == float(authorized_cap)
            and float(population_cap_readback) == float(authorized_cap)
        )
        if controller_finite:
            nonzero += int(float(controller) != 0.0)
        require(
            row.get("controller_request_finite") is controller_finite
            and row.get("binary32_projection_finite") is projection_finite
            and row.get("application_request_preserved_exactly")
            is application_request_exact
            and row.get("application_readback_equals_projection_exactly")
            is application_projection_exact
            and row.get("population_readback_equals_projection_exactly")
            is population_projection_exact
            and row.get("application_population_readbacks_equal_exactly")
            is application_population_exact
            and row.get("r69_host_cap_exact") is r69_host_cap_exact,
            f"L13_HOST_TARGET_PROJECTION_ROW_DERIVATION_{index}",
        )
        fully_valid_rows = (
            fully_valid_rows
            and controller_finite
            and projection_finite
            and application_request_exact
            and application_projection_exact
            and population_projection_exact
            and application_population_exact
            and r69_host_cap_exact
        )
        exact_application += int(
            row.get("application_readback_equals_projection_exactly") is True
        )
        exact_population += int(
            row.get("population_readback_equals_projection_exactly") is True
        )
        exact_pair += int(
            row.get("application_population_readbacks_equal_exactly") is True
        )
        exact_caps += int(row.get("r69_host_cap_exact") is True)
    require(
        exact_int(receipt.get("nonzero_controller_target_count"), nonzero)
        and exact_int(
            receipt.get("application_readback_equals_projection_count"),
            exact_application,
        )
        and exact_int(
            receipt.get("population_readback_equals_projection_count"),
            exact_population,
        )
        and exact_int(
            receipt.get("application_population_readbacks_equal_count"), exact_pair
        )
        and exact_int(receipt.get("r69_host_cap_exact_count"), exact_caps)
        and receipt.get("ok") is (len(failures) == 0),
        "L13_HOST_TARGET_PROJECTION_COUNTS",
    )
    if receipt.get("ok") is True:
        require(
            not failures
            and fully_valid_rows
            and exact_application == len(ACTUATOR_IDS)
            and exact_population == len(ACTUATOR_IDS)
            and exact_pair == len(ACTUATOR_IDS)
            and exact_caps == len(ACTUATOR_IDS),
            "L13_HOST_TARGET_PROJECTION_OK_CONTRADICTION",
        )
    return {
        "payload_sha256": receipt["payload_sha256"],
        "ok": receipt["ok"],
        "failed_predicate_ids": list(failures),
        "projection_count": len(rows),
        "nonzero_controller_target_count": nonzero,
        "application_readback_equals_projection_count": exact_application,
        "population_readback_equals_projection_count": exact_population,
        "application_population_readbacks_equal_count": exact_pair,
        "r69_host_cap_exact_count": exact_caps,
        "controller_command_rounded_before_write": False,
        "host_write_changed": False,
        "solver_input_changed": False,
    }


def l13_expected_walking_ledger_predicate_coordinates() -> list[tuple[str, str, str, int]]:
    identity_ids = [
        "input.sdk_present",
        "input.global_semantic_step_positive",
        "input.phase_present",
        "input.session_id_present",
        "input.session_local_step_positive",
        "identity.portable_step_has_no_outcome_derived_top_level",
        "identity.authority_application_has_no_outcome_derived_top_level",
        "identity.motor_population_has_no_outcome_derived_top_level",
        "identity.walking_handoff_has_no_outcome_derived_top_level",
        "identity.walking_handoff_valid",
        "identity.native_output_shape",
        "identity.actuation_shape",
        "identity.commands_shape",
        "identity.controller_receipt_shape",
        "identity.applications_shape",
        "identity.readbacks_shape",
        "identity.portable_step_ok",
        "identity.selected_policy",
        "identity.portable_step_clock",
        "identity.actuation_step_clock",
        "identity.actuation_not_safe_no_actuation",
        "identity.native_transport_verification_present",
        "identity.native_transport_verification_valid",
        "identity.adapter_exposed_digest_equals_actuation_digest",
        "identity.native_verified_digest_equals_actuation_digest",
        "identity.authority_application_schema",
        "identity.authority_application_ok",
        "identity.authority_application_step_clock",
        "identity.authority_application_command_count",
        "identity.authority_application_actuator_order",
        "identity.authority_application_motor_parameters_only",
        "identity.authority_application_r69_override_applied",
        "identity.authority_application_r69_cap_map",
        "identity.motor_population_ok",
        "identity.motor_population_global_step_clock",
        "identity.motor_population_motors_enabled",
        "identity.motor_population_enabled_count",
        "identity.commands_cardinality",
        "identity.applications_cardinality",
        "identity.readbacks_cardinality",
        "identity.published_caps_cardinality",
        "identity.authorized_caps_cardinality",
        "identity.handoff_session",
        "identity.handoff_global_step",
    ]
    coordinates = [(value, "identity", "", -1) for value in identity_ids]
    coordinates.append(("row.host_target_projection_receipt_valid", "row", "", -1))
    row_suffixes = [
        "shape",
        "actuator_identity",
        "joint_identity",
        "controller_request_finite",
        "binary32_projection_finite",
        "application_request_preserved_exactly",
        "application_readback_equals_projection_exactly",
        "population_readback_equals_projection_exactly",
        "application_population_readbacks_equal_exactly",
        "r69_host_cap_exact",
    ]
    for index, actuator_id in enumerate(ACTUATOR_IDS):
        coordinates.extend(
            (f"row.{index}.{suffix}", "row", actuator_id, index)
            for suffix in row_suffixes
        )
    return coordinates


def validate_l13_walking_ledger_predicates(receipt: Any) -> dict[str, Any]:
    keys = {
        "schema_version",
        "gate_id",
        "ok",
        "all_predicates_evaluated",
        "generic_failure_without_predicate_detail",
        "identity_predicate_count",
        "row_predicate_count",
        "predicate_count",
        "passed_predicate_count",
        "failed_predicate_count",
        "failed_predicate_ids",
        "ordered_predicates",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "physical_acceptance_authority",
        "release_authority",
        "payload_sha256",
    }
    require(isinstance(receipt, dict), "L13_LEDGER_PREDICATES_NOT_OBJECT")
    predicates = receipt.get("ordered_predicates")
    failed = receipt.get("failed_predicate_ids")
    require(
        set(receipt) == keys
        and receipt.get("schema_version") == WALKING_LEDGER_PREDICATE_SCHEMA
        and receipt.get("gate_id") == "QSDK-R10F"
        and isinstance(receipt.get("ok"), bool)
        and receipt.get("all_predicates_evaluated") is True
        and receipt.get("generic_failure_without_predicate_detail") is False
        and isinstance(predicates, list)
        and bool(predicates)
        and isinstance(failed, list)
        and len(failed) == len(set(failed))
        and all(isinstance(value, str) and bool(value) for value in failed)
        and exact_int(receipt.get("model_construction_count"), 0)
        and exact_int(receipt.get("world_attempt_count"), 0)
        and exact_int(receipt.get("world_build_count"), 0)
        and exact_int(receipt.get("solver_step_count"), 0)
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False
        and receipt.get("payload_sha256") == l12_payload_sha256_v1(receipt),
        "L13_LEDGER_PREDICATE_FIELDS",
    )
    derived_failed: list[str] = []
    identity_count = 0
    row_count = 0
    expected_coordinates = l13_expected_walking_ledger_predicate_coordinates()
    require(
        len(predicates) == len(expected_coordinates),
        "L13_LEDGER_PREDICATE_POPULATION",
    )
    for index, predicate in enumerate(predicates):
        expected_id, expected_scope, expected_actuator, expected_row = (
            expected_coordinates[index]
        )
        require(
            isinstance(predicate, dict)
            and set(predicate)
            == {"predicate_id", "scope", "passed", "actuator_id", "row_index"}
            and isinstance(predicate.get("predicate_id"), str)
            and bool(predicate.get("predicate_id"))
            and predicate.get("scope") in {"identity", "row"}
            and isinstance(predicate.get("passed"), bool)
            and isinstance(predicate.get("actuator_id"), str)
            and isinstance(predicate.get("row_index"), int)
            and not isinstance(predicate.get("row_index"), bool)
            and predicate.get("predicate_id") == expected_id
            and predicate.get("scope") == expected_scope
            and predicate.get("actuator_id") == expected_actuator
            and exact_int(predicate.get("row_index"), expected_row),
            f"L13_LEDGER_PREDICATE_ROW_{index}",
        )
        if predicate["scope"] == "identity":
            identity_count += 1
            require(
                predicate.get("actuator_id") == ""
                and exact_int(predicate.get("row_index"), -1),
                f"L13_LEDGER_IDENTITY_PREDICATE_{index}",
            )
        else:
            row_count += 1
            require(
                bounded_int(predicate.get("row_index"), -1, len(ACTUATOR_IDS) - 1),
                f"L13_LEDGER_ROW_PREDICATE_{index}",
            )
        if predicate["passed"] is False:
            derived_failed.append(str(predicate["predicate_id"]))
    require(
        len(derived_failed) == len(set(derived_failed))
        and failed == derived_failed
        and exact_int(receipt.get("identity_predicate_count"), identity_count)
        and exact_int(receipt.get("row_predicate_count"), row_count)
        and exact_int(receipt.get("predicate_count"), len(predicates))
        and exact_int(
            receipt.get("passed_predicate_count"), len(predicates) - len(failed)
        )
        and exact_int(receipt.get("failed_predicate_count"), len(failed))
        and receipt.get("ok") is (len(failed) == 0),
        "L13_LEDGER_PREDICATE_COUNTS",
    )
    return {
        "payload_sha256": receipt["payload_sha256"],
        "ok": receipt["ok"],
        "predicate_count": len(predicates),
        "failed_predicate_ids": list(failed),
        "generic_failure_without_predicate_detail": False,
    }


def validate_l14_partial_walking_evaluation_failure_report(
    report: Any,
    **identity: Any,
) -> dict[str, Any]:
    # Reuse the actual predecessor's strict outer identity/invalidity checks.
    # This new receipt is additional failure evidence, never a child success.
    prior = validate_l13_partial_walking_failure_report(report, **identity)
    partial = report["partial_arm"]
    if not partial.get("last_walking_evaluation_failure"):
        return prior
    result = l14_walking_failure.validate_failure_retention(
        partial,
        role=identity["expected_role"],
        canonical_sha256=canonical_sha256_v1,
        payload_sha256=payload_sha256_v1,
    )
    require(
        result["walking_evaluation_failure_retention_valid"],
        "L14_PARTIAL_WALKING_EVALUATION_RETENTION:"
        + ",".join(result["failed_predicate_ids"]),
    )
    require(
        exact_int(report.get("solver_step_count"), len(partial["trace_rows"]))
        and bounded_int(report.get("solver_step_count"), 1, 3842)
        and exact_int(report.get("global_solver_frame_count"), report["solver_step_count"])
        and exact_int(report.get("world_build_count"), 1),
        "L14_PARTIAL_WALKING_ALL_OBSERVED_ROW_COUNT",
    )
    return {**prior, **result, "walking_evaluation_failure_present": True}


def validate_l13_partial_walking_failure_report(
    report: Any,
    *,
    expected_role: str,
    expected_parent_attempt_id: str,
    expected_child_attempt_id: str,
    expected_source_commit: str,
    expected_authority_sha256: str,
    expected_worker_process_id: int,
) -> dict[str, Any]:
    require(isinstance(report, dict), "L13_PARTIAL_REPORT_NOT_OBJECT")
    partial = report.get("partial_arm")
    require(
        report.get("schema_version") == RAW_SCHEMA
        and report.get("gate_id") == "QSDK-R10F"
        and report.get("repair_id") == REPAIR_ID
        and report.get("work_id") == work_id_for_family()
        and report.get("ledger_scope")
        == ledger_scope("consumed_process_isolated_child_incomplete_raw")
        and report.get("status")
        == "invalid_or_incomplete_process_isolated_child_development"
        and report.get("ok") is False
        and report.get("measurement_complete") is False
        and report.get("scientific_outcome") == "none"
        and report.get("role_outcome") == "none"
        and isinstance(report.get("failure_code"), str)
        and bool(report.get("failure_code"))
        and report.get("source_commit") == expected_source_commit
        and report.get("authorization_sha256") == expected_authority_sha256
        and report.get("parent_attempt_id") == expected_parent_attempt_id
        and report.get("child_attempt_id") == expected_child_attempt_id
        and report.get("attempt_id") == expected_child_attempt_id
        and report.get("arm_id") == expected_role
        and exact_int(report.get("process_id"), expected_worker_process_id)
        and exact_int(report.get("seed"), SEED)
        and report.get("seed_sha256") == SEED_SHA256
        and report.get("one_arm_per_process") is True
        and report.get("one_world_per_process") is True
        and report.get("world_or_body_state_imported_from_peer") is False
        and report.get("force_aware_recovery") is False
        and report.get("force_aware_bracing") is False
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False
        and isinstance(partial, dict),
        "L13_PARTIAL_REPORT_FIELDS",
    )
    session = partial.get("active_walking_session")
    failure = partial.get("last_walking_step_failure")
    if not isinstance(session, dict) or not session or not isinstance(failure, dict) or not failure:
        return {
            "partial_arm_retained": True,
            "walking_ledger_failure_present": False,
            "walking_ledger_failure_retention_valid": False,
        }
    required_sources = (
        "portable_step_receipt",
        "native_step_transport_verification",
        "controller_step_receipt",
        "authority_application_receipt",
        "motor_population_readback",
        "walking_actuation_handoff_receipt",
        "host_target_projection_receipt",
        "walking_ledger_predicate_receipt",
    )
    failure_keys = {
        "schema_version",
        "gate_id",
        "ok",
        "failure_code",
        "failed_predicate_ids",
        *required_sources,
        "generic_failure_without_predicate_detail",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    }
    require(
        set(failure) == failure_keys
        and all(isinstance(failure.get(key), dict) for key in required_sources)
        and failure.get("schema_version") == WALKING_LEDGER_SCHEMA
        and failure.get("gate_id") == "QSDK-R10F"
        and failure.get("ok") is False
        and failure.get("failure_code")
        in {
            "QSDK_R10F_L13_WALKING_LEDGER_PREDICATES_FAILED",
            "QSDK_R10F_L13_WALKING_LEDGER_DIGEST_INVALID",
        }
        and isinstance(failure.get("failed_predicate_ids"), list)
        and bool(failure.get("failed_predicate_ids"))
        and len(failure["failed_predicate_ids"])
        == len(set(failure["failed_predicate_ids"]))
        and all(
            isinstance(value, str) and bool(value)
            for value in failure["failed_predicate_ids"]
        )
        and failure.get("generic_failure_without_predicate_detail") is False
        and exact_int(failure.get("model_construction_count"), 0)
        and exact_int(failure.get("world_attempt_count"), 0)
        and exact_int(failure.get("world_build_count"), 0)
        and exact_int(failure.get("solver_step_count"), 0)
        and isinstance(failure.get("physics_state_modified"), bool)
        and failure.get("physical_acceptance_authority") is False
        and failure.get("release_authority") is False
        and isinstance(session.get("session_id"), str)
        and bool(session.get("session_id"))
        and isinstance(session.get("start_receipt"), dict)
        and isinstance(session.get("walking_actuation_handoff_receipt"), dict),
        "L13_PARTIAL_WALKING_FAILURE_SOURCES",
    )
    portable = failure["portable_step_receipt"]
    native = failure["native_step_transport_verification"]
    controller = failure["controller_step_receipt"]
    authority_application = failure["authority_application_receipt"]
    population_readback = failure["motor_population_readback"]
    handoff = failure["walking_actuation_handoff_receipt"]
    projection_receipt = failure["host_target_projection_receipt"]
    controller_digest = portable.get("controller_step_receipt_sha256")
    local_step = portable.get("semantic_step")
    native_output = portable.get("native_output")
    actuation = native_output.get("actuation") if isinstance(native_output, dict) else None
    commands = actuation.get("ordered_commands") if isinstance(actuation, dict) else None
    applications = authority_application.get("ordered_applications")
    readbacks = population_readback.get("ordered_joint_readbacks")
    projection_rows = projection_receipt.get("ordered_target_projections")
    handoff_global_step = handoff.get("global_semantic_step")
    published_cap_by_actuator_id = handoff.get("published_cap_by_actuator_id")
    authorized_host_cap_by_actuator_id = handoff.get(
        "authorized_host_cap_by_actuator_id"
    )
    require(
        is_sha256(controller_digest)
        and bounded_int(local_step, 1, 3842)
        and portable.get("native_step_transport_verification") == native
        and portable.get("controller_policy_id") == POLICY_ID
        and isinstance(actuation, dict)
        and actuation.get("receipt") == controller
        and actuation.get("receipt_sha256") == controller_digest
        and exact_int(actuation.get("semantic_step"), int(local_step))
        and controller.get("schema_version")
        == "sporespore_controller_step_receipt_v2"
        and controller.get("policy_id") == POLICY_ID
        and exact_int(controller.get("semantic_step"), int(local_step))
        and authority_application.get("schema_version")
        == "sporespore_godot_jolt_full_authority_application_receipt_v1"
        and authority_application.get("ok") is True
        and exact_int(authority_application.get("semantic_step"), int(local_step))
        and authority_application.get("ordered_actuator_ids") == ACTUATOR_IDS
        and exact_int(
            authority_application.get("applied_command_count"), len(ACTUATOR_IDS)
        )
        and authority_application.get("configured_motor_parameters_only") is True
        and authority_application.get("maximum_impulse_override_applied") is True
        and authority_application.get("physical_acceptance_authority") is False
        and authority_application.get("release_authority") is False
        and population_readback.get("schema_version") == MOTOR_READBACK_SCHEMA
        and population_readback.get("gate_id") == "QSDK-R10F"
        and population_readback.get("ok") is True
        and population_readback.get("expected_motor_enabled") is True
        and exact_int(
            population_readback.get("motor_enabled_count"), len(ACTUATOR_IDS)
        )
        and population_readback.get("physical_acceptance_authority") is False
        and population_readback.get("release_authority") is False
        and isinstance(commands, list)
        and isinstance(applications, list)
        and isinstance(readbacks, list)
        and isinstance(projection_rows, list)
        and len(commands) == len(ACTUATOR_IDS)
        and len(applications) == len(ACTUATOR_IDS)
        and len(readbacks) == len(ACTUATOR_IDS)
        and len(projection_rows) == len(ACTUATOR_IDS)
        and isinstance(published_cap_by_actuator_id, dict)
        and isinstance(authorized_host_cap_by_actuator_id, dict)
        and bounded_int(handoff_global_step, 1, 3842)
        and handoff == session.get("walking_actuation_handoff_receipt"),
        "L13_PARTIAL_WALKING_FAILURE_SOURCE_BINDINGS",
    )
    transport = validate_l13_native_transport_verification(
        native,
        expected_semantic_step=int(local_step),
        expected_controller_receipt_sha256=str(controller_digest),
    )
    projection = validate_l13_host_target_projection(projection_receipt)
    predicates = validate_l13_walking_ledger_predicates(
        failure["walking_ledger_predicate_receipt"]
    )
    if failure["failure_code"] == "QSDK_R10F_L13_WALKING_LEDGER_PREDICATES_FAILED":
        require(
            predicates["ok"] is False
            and predicates["failed_predicate_ids"]
            == failure["failed_predicate_ids"],
            "L13_PARTIAL_WALKING_FAILURE_PREDICATE_BINDING",
        )
    else:
        require(
            failure["failed_predicate_ids"]
            == ["identity.success_payload_digests_valid"],
            "L13_PARTIAL_WALKING_FAILURE_DIGEST_ID",
        )
    for index, (command, application, readback, row) in enumerate(
        zip(commands, applications, readbacks, projection_rows)
    ):
        require(
            isinstance(command, dict)
            and isinstance(application, dict)
            and isinstance(readback, dict)
            and isinstance(row, dict)
            and command.get("actuator_id") == ACTUATOR_IDS[index]
            and application.get("actuator_id") == ACTUATOR_IDS[index]
            and application.get("joint_id") == JOINT_IDS[index]
            and readback.get("actuator_id") == ACTUATOR_IDS[index]
            and readback.get("joint_id") == JOINT_IDS[index]
            and row.get("actuator_id") == ACTUATOR_IDS[index]
            and row.get("joint_id") == JOINT_IDS[index]
            and row.get("controller_binary64_target_velocity_rad_s")
            == command.get("target_velocity_rad_s")
            and row.get("application_host_applied_binary64_target_velocity_rad_s")
            == application.get("host_applied_target_velocity_rad_s")
            and row.get("application_motor_target_velocity_readback_rad_s")
            == application.get("motor_target_velocity_readback_rad_s")
            and row.get("population_motor_target_velocity_readback_rad_s")
            == readback.get("motor_target_velocity_rad_s")
            and row.get("published_cap_nms")
            == published_cap_by_actuator_id.get(ACTUATOR_IDS[index])
            and row.get("authorized_host_cap_nms")
            == authorized_host_cap_by_actuator_id.get(ACTUATOR_IDS[index])
            and row.get("application_declared_maximum_impulse_nms")
            == application.get("declared_maximum_impulse_nms")
            and row.get("application_motor_maximum_impulse_readback_nms")
            == application.get("motor_maximum_impulse_readback_nms")
            and row.get("population_motor_maximum_impulse_readback_nms")
            == readback.get("motor_maximum_impulse_nms"),
            f"L13_PARTIAL_WALKING_FAILURE_ROW_BINDING_{index}",
        )
    require(
        failure.get("physics_state_modified")
        is bool(authority_application.get("ok", False)),
        "L13_PARTIAL_WALKING_FAILURE_PHYSICS_STATE",
    )
    handoff_projection = validate_l12_walking_handoff(
        handoff,
        expected_model_instance_id=str(partial.get("model_instance_id", "")),
        expected_evaluation_segment=str(session.get("evaluation_segment_id", "")),
        expected_session_id=str(session["session_id"]),
        expected_global_semantic_step=int(handoff_global_step),
    )
    return {
        "partial_arm_retained": True,
        "walking_ledger_failure_present": True,
        "walking_ledger_failure_retention_valid": True,
        "failure_code": failure["failure_code"],
        "failed_predicate_ids": list(failure["failed_predicate_ids"]),
        "retained_source_count": len(required_sources),
        "walking_session_id": session["session_id"],
        "walking_session_local_step": int(local_step),
        "native_transport_verification": transport,
        "host_target_projection": projection,
        "walking_ledger_predicates": predicates,
        "walking_actuation_handoff": handoff_projection,
        "no_additional_solver_step": True,
        "force_aware_recovery": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def require_l15_context_expectations(expected_identity, expected_binding) -> bool:
    context_mode = expected_binding is not None or REPAIR_ID == "QSDK-R10F-L15"
    if context_mode:
        require(
            type(expected_identity) is dict
            and expected_identity.keys() == l15_collection.IDENTITY_KEYS,
            "L15_QUALIFIED_COLLECTION_IDENTITY_REQUIRED",
        )
        try:
            l15_context.validate_expected_binding(expected_binding)
        except (ValueError, TypeError, KeyError) as exc:
            raise ClosureFailure(f"L15_QUALIFIED_CONTEXT_BINDING_REQUIRED:{exc}") from exc
    return context_mode


def validate_l9_child_envelope(
    envelope: Any,
    descriptor: Mapping[str, Any],
    *,
    parent_attempt_id: str,
    source_commit: str,
    authority_sha256: str,
    verify_files: bool,
    require_l15_launch: bool = False,
    expected_l15_collection_identity: Mapping[str, Any] | None = None,
    expected_l15_context_binding: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    require(type(require_l15_launch) is bool, "L15_REQUIRED_MODE_TYPE")
    require_l15_launch = require_l15_launch or REPAIR_ID == "QSDK-R10F-L15"
    context_mode = require_l15_context_expectations(
        expected_l15_collection_identity, expected_l15_context_binding
    )
    collection_mode = (
        expected_l15_collection_identity is not None or REPAIR_ID == "QSDK-R10F-L15"
    )
    if collection_mode:
        # The future source/qualification handoff must supply this independently.
        # Never recover expected identity from the failed packet itself.
        require(
            type(expected_l15_collection_identity) is dict
            and expected_l15_collection_identity.keys() == l15_collection.IDENTITY_KEYS,
            "L15_QUALIFIED_COLLECTION_IDENTITY_REQUIRED",
        )
    role = descriptor.get("role")
    require(isinstance(envelope, dict), f"L9_{role}_ENVELOPE_NOT_OBJECT")
    child_root = l9_normalized_path(
        descriptor.get("evidence_path"), f"L9_{role}_DESCRIPTOR_EVIDENCE_PATH"
    )
    require(
        envelope.get("role") == role
        and envelope.get("child_attempt_id") == descriptor.get("child_attempt_id")
        and envelope.get("termination_nonce") == descriptor.get("termination_nonce")
        and l9_normalized_path(
            envelope.get("evidence_path"), f"L9_{role}_ENVELOPE_EVIDENCE_PATH"
        )
        == child_root
        and exact_int(envelope.get("child_retry_count"), 0)
        and exact_int(envelope.get("child_replacement_count"), 0)
        and bounded_int(envelope.get("process_id"), 1, 2**31 - 1)
        and bounded_int(envelope.get("worker_process_id"), 0, 2**31 - 1)
        and bounded_int(envelope.get("exit_code"), -2**31, 2**31 - 1)
        and isinstance(envelope.get("termination_protocol_valid"), bool)
        and isinstance(envelope.get("engine_health_passed"), bool)
        and isinstance(envelope.get("raw_marker_valid"), bool)
        and envelope.get("physical_acceptance_authority") is False
        and envelope.get("release_authority") is False,
        f"L9_{role}_ENVELOPE_FIELDS",
    )
    started = parse_utc_timestamp(envelope.get("started_utc"), f"L9_{role}_START_TIME")
    completed = parse_utc_timestamp(
        envelope.get("completed_utc"), f"L9_{role}_COMPLETE_TIME"
    )
    require(completed >= started, f"L9_{role}_PROCESS_TIME_ORDER")
    child_projection: dict[str, Any] | None = None
    child_error = ""
    walking_failure_retention: dict[str, Any] = {}
    collection_failure_retention: dict[str, Any] = {}
    l15_launch_payload: dict[str, Any] | None = None
    prepared_context: dict[str, Any] = {}
    if context_mode:
        raw_report = envelope.get("report")
        try:
            prepared_context = l15_context.validate_worker_comparison(
                raw_report.get("l15_prepared_context_comparison")
                if isinstance(raw_report, dict) else None,
                expected_raw_binding=expected_l15_context_binding,
                expected_identity=expected_l15_collection_identity,
                canonical_sha256=canonical_sha256_v1,
            )
        except (ValueError, KeyError, TypeError, OverflowError) as exc:
            prepared_context = {
                "prepared_context_valid": False,
                "validation_error": str(exc),
                "context_integrity_establishes_valid_child": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            }
    try:
        child_projection = validate_l9_child_report(
            envelope.get("report"),
            expected_role=str(role),
            expected_parent_attempt_id=parent_attempt_id,
            expected_child_attempt_id=str(descriptor.get("child_attempt_id")),
            expected_source_commit=source_commit,
            expected_authority_sha256=authority_sha256,
            expected_worker_process_id=int(envelope.get("worker_process_id")),
        )
        if context_mode:
            require(
                prepared_context["prepared_context_valid"] is True,
                f"L15_{role}_PREPARED_CONTEXT_INVALID:"
                + prepared_context.get("validation_error", ""),
            )
        if require_l15_launch:
            try:
                context = l15_launch.production_context(
                    parent_attempt_id=parent_attempt_id,
                    descriptor=dict(descriptor),
                    source_commit=source_commit,
                    authority_sha256=authority_sha256,
                    runtime_binding=l14_runtime.expected_binding(),
                )
                l15_launch_payload = l15_launch.validate_child_launch(envelope, context)
            except (ValueError, KeyError, TypeError, OverflowError) as exc:
                raise ClosureFailure(f"L15_{role}_LAUNCH_RELATIONSHIP:{exc}") from exc
        require(
            envelope.get("exit_code") == 0
            and envelope.get("termination_protocol_valid") is True
            and envelope.get("engine_health_passed") is True
            and envelope.get("raw_marker_valid") is True
            and (
                require_l15_launch
                or envelope.get("process_id") == envelope.get("worker_process_id")
            ),
            f"L9_{role}_VALID_CHILD_LAUNCH",
        )
    except ClosureFailure as exc:
        child_error = str(exc)
        child_projection = None
        raw_report = envelope.get("report")
        if (
            isinstance(raw_report, dict)
            and raw_report.get("schema_version") == RAW_SCHEMA
            and raw_report.get("repair_id") == REPAIR_ID
            and raw_report.get("work_id") == work_id_for_family()
            and raw_report.get("status")
            == "invalid_or_incomplete_process_isolated_child_development"
        ):
            try:
                walking_failure_retention = validate_l14_partial_walking_evaluation_failure_report(
                    raw_report,
                    expected_role=str(role),
                    expected_parent_attempt_id=parent_attempt_id,
                    expected_child_attempt_id=str(descriptor.get("child_attempt_id")),
                    expected_source_commit=source_commit,
                    expected_authority_sha256=authority_sha256,
                    expected_worker_process_id=int(envelope.get("worker_process_id")),
                )
            except ClosureFailure as retention_exc:
                partial = raw_report.get("partial_arm")
                retained_failure = (
                    partial.get("last_walking_step_failure")
                    if isinstance(partial, dict)
                    else None
                )
                walking_failure_retention = {
                    "partial_arm_retained": isinstance(partial, dict),
                    "walking_ledger_failure_present": (
                        isinstance(retained_failure, dict) and bool(retained_failure)
                    ),
                    "walking_ledger_failure_retention_valid": False,
                    "retention_validation_error": str(retention_exc),
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                }
            if collection_mode:
                expected_report_identity = {
                    "schema_version": RAW_SCHEMA,
                    "gate_id": "QSDK-R10F",
                    "repair_id": REPAIR_ID,
                    "work_id": work_id_for_family(),
                    "ledger_scope": ledger_scope(
                        "consumed_process_isolated_child_incomplete_raw"
                    ),
                    "source_commit": source_commit,
                    "authorization_sha256": authority_sha256,
                    "parent_attempt_id": parent_attempt_id,
                    "child_attempt_id": descriptor["child_attempt_id"],
                    "attempt_id": descriptor["child_attempt_id"],
                    "arm_id": role,
                    "process_id": envelope["worker_process_id"],
                    "seed": SEED,
                    "seed_sha256": SEED_SHA256,
                    "actuator_mode": "solver_coupled_native_constraint_motor_v1",
                    "recovery_controller_id": RECOVERY_CONTROLLER_ID,
                    "energy_route_id": (
                        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_"
                        "complete_energy_recovery_observation_v3_route_v1"
                    ),
                }
                try:
                    collection_failure_retention = l15_collection.validate_partial_report(
                        raw_report,
                        expected_report_identity=expected_report_identity,
                        expected_identity=expected_l15_collection_identity,
                        canonical_sha256=canonical_sha256_v1,
                        maximum_solver_steps=3842,
                    )
                except (ClosureFailure, ValueError, KeyError, TypeError, OverflowError) as retention_exc:
                    collection_failure_retention = {
                        "collection_failure_retention_valid": False,
                        "retention_validation_error": str(retention_exc),
                        "retention_establishes_valid_child": False,
                        "valid_physical_route_established": False,
                        "physical_acceptance_authority": False,
                        "release_authority": False,
                    }
    artifacts: dict[str, Any] = {}
    child_identity: dict[str, Any] = {}
    if verify_files:
        retained = validate_l9_child_artifact_files(
            envelope, descriptor, child_root=child_root,
            require_l15_launch=require_l15_launch,
            require_l15_collection=collection_mode,
        )
        artifacts = retained["bindings"]
        child_identity = retained["child_identity"]
        if require_l15_launch and child_projection is not None:
            require(
                l15_launch_payload is not None
                and retained["ready_line"] == l15_launch_payload["ready_line"],
                "L15_READY_LINE_BYTE_SOURCE_BINDING",
            )
        require(
            child_identity.get("parent_attempt_id") == parent_attempt_id
            and child_identity.get("source_commit") == source_commit
            and child_identity.get("authority_sha256") == authority_sha256,
            f"L9_{role}_CHILD_IDENTITY_PARENT_AUTHORITY",
        )
    result = {
        "role": role,
        "child_attempt_id": descriptor.get("child_attempt_id"),
        "termination_nonce": descriptor.get("termination_nonce"),
        "evidence_path": child_root.as_posix(),
        "process_id": envelope.get("process_id"),
        "worker_process_id": envelope.get("worker_process_id"),
        "started": started,
        "completed": completed,
        "child_valid": child_projection is not None,
        "child_validation_error": child_error,
        "child": child_projection,
        "walking_failure_retention": walking_failure_retention,
        "artifact_bindings": artifacts,
    }
    if collection_mode:
        result["collection_failure_retention"] = collection_failure_retention
    if context_mode:
        result["prepared_context_integrity"] = prepared_context
    return result


def validate_l9_population_projection(
    population: Any,
    children: list[Mapping[str, Any]],
    expected_pair: Mapping[str, Any] | None,
    *,
    source_commit: str,
    authority_sha256: str,
    parent_attempt_id: str,
) -> None:
    require(isinstance(population, dict), "L9_POPULATION_NOT_OBJECT")
    require(
        population.get("schema_version") == POPULATION_SCHEMA
        and population.get("gate_id") == "QSDK-R10F"
        and population.get("repair_id") == REPAIR_ID
        and population.get("physical_acceptance_authority") is False
        and population.get("release_authority") is False,
        "L9_POPULATION_COMMON_FIELDS",
    )
    if expected_pair is None:
        require(
            population.get("ok") is False
            and population.get("status") == "invalid_or_incomplete_process_population"
            and population.get("evidence_valid") is False
            and population.get("measurement_complete") is False
            and population.get("route_execution_valid") is False
            and population.get("outcome_complete") is False
            and population.get("behavior_passed") is False
            and population.get("scientific_outcome") == "none"
            and population.get("failure_code")
            == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
            and exact_int(population.get("ordered_child_count"), len(children))
            and exact_int(population.get("evaluator_invocation_count"), 0)
            and exact_int(population.get("model_construction_count"), 0)
            and exact_int(population.get("world_attempt_count"), 0)
            and exact_int(population.get("world_build_count"), 0)
            and exact_int(population.get("native_readback_count"), 0)
            and exact_int(population.get("solver_step_count"), 0)
            and population.get("physics_state_modified") is False
            and isinstance(population.get("population_validation_errors"), list)
            and bool(population.get("population_validation_errors")),
            "L9_INVALID_POPULATION_FIELDS",
        )
        return
    require(len(children) == 2, "L9_VALID_POPULATION_CHILD_COUNT")
    baseline = children[0]["child"]
    active = children[1]["child"]
    require(isinstance(baseline, dict) and isinstance(active, dict), "L9_VALID_CHILDREN")
    child_ids = [child["child_attempt_id"] for child in children]
    process_ids = [child["process_id"] for child in children]
    evidence_paths = [child["evidence_path"] for child in children]
    total_steps = int(baseline["solver_step_count"]) + int(active["solver_step_count"])
    require(
        population.get("ok") is expected_pair["ok"]
        and population.get("status") == expected_pair["status"]
        and population.get("evidence_valid") is expected_pair["evidence_valid"]
        and population.get("measurement_complete")
        is expected_pair["measurement_complete"]
        and population.get("route_execution_valid")
        is expected_pair["route_execution_valid"]
        and population.get("outcome_complete") is expected_pair["outcome_complete"]
        and population.get("behavior_passed") is expected_pair["behavior_passed"]
        and population.get("scientific_outcome") == expected_pair["scientific_outcome"]
        and population.get("failure_code") == expected_pair["failure_code"]
        and population.get("population_validation_errors") == []
        and exact_int(population.get("ordered_child_count"), 2)
        and population.get("ordered_child_roles") == ARM_ORDER
        and population.get("child_attempt_ids") == child_ids
        and population.get("child_process_ids") == process_ids
        and isinstance(population.get("child_evidence_paths"), list)
        and len(population["child_evidence_paths"]) == 2
        and all(
            l9_normalized_path(value, "L9_POPULATION_CHILD_PATH")
            == Path(evidence_paths[index]).resolve()
            for index, value in enumerate(population["child_evidence_paths"])
        )
        and population.get("process_lifetimes_overlap") is False
        and population.get("serialized_fresh_processes_valid") is True
        and population.get("all_declared_children_present") is True
        and population.get("child_retry_or_replacement_used") is False
        and exact_int(population.get("evaluator_invocation_count"), 1)
        and exact_int(population.get("model_construction_count"), 2)
        and exact_int(population.get("world_attempt_count"), 2)
        and exact_int(population.get("world_build_count"), 2)
        and exact_int(population.get("solver_step_count"), total_steps)
        and exact_int(population.get("maximum_solver_step_count"), 7684)
        and population.get("physics_state_modified") is True,
        "L9_VALID_POPULATION_FIELDS",
    )
    validations = population.get("child_validations")
    require(
        isinstance(validations, list)
        and len(validations) == 2
        and all(isinstance(value, dict) and value.get("ok") is True for value in validations)
        and [value.get("role") for value in validations] == ARM_ORDER
        and [value.get("disposition") for value in validations]
        == [baseline["disposition"], active["disposition"]]
        and [value.get("solver_step_count") for value in validations]
        == [baseline["solver_step_count"], active["solver_step_count"]]
        and all(
            exact_int(
                value.get("walking_actuation_handoff_count"),
                child["walking_actuation_handoffs"]["handoff_count"],
            )
            and l14_terminal.same_source_value(
                value.get("no_resume_terminal"), child["no_resume_terminal"]
            )
            for value, child in zip(validations, (baseline, active))
        )
        and all(value.get("validation_errors") == [] for value in validations),
        "L9_POPULATION_CHILD_VALIDATIONS",
    )
    pair = population.get("pair_evaluation")
    require(
        isinstance(pair, dict)
        and pair.get("schema_version") == PAIR_EVALUATION_SCHEMA
        and pair.get("gate_id") == "QSDK-R10F"
        and pair.get("repair_id") == REPAIR_ID
        and pair.get("ok") is expected_pair["ok"]
        and pair.get("status") == expected_pair["status"]
        and pair.get("evidence_valid") is expected_pair["evidence_valid"]
        and pair.get("measurement_complete") is expected_pair["measurement_complete"]
        and pair.get("route_execution_valid") is expected_pair["route_execution_valid"]
        and pair.get("outcome_complete") is expected_pair["outcome_complete"]
        and pair.get("behavior_passed") is expected_pair["behavior_passed"]
        and pair.get("scientific_outcome") == expected_pair["scientific_outcome"]
        and pair.get("failure_code") == expected_pair["failure_code"]
        and exact_int(pair.get("evaluator_invocation_count"), 1)
        and pair.get("pair_alignment_basis")
        == "phase_local_receipts_and_walking_session_local_steps"
        and pair.get("global_solver_step_values_rewritten_for_pair_alignment") is False
        and pair.get("trace_truncation_used_for_pair_alignment") is False
        and pair.get("force_aware_recovery") is False
        and pair.get("physical_acceptance_authority") is False
        and pair.get("release_authority") is False,
        "L9_PAIR_EVALUATION_FIELDS",
    )
    if expected_pair["route_execution_valid"]:
        require(
            l9_json_numbers_close(
                pair.get("computed_measurements"), expected_pair["computed_measurements"]
            )
            and pair.get("outcome_derived_correction") is False
            and pair.get("failed_pair_source_predicates") == []
            and isinstance(pair.get("route_receipts"), dict)
            and all(value is True for value in pair["route_receipts"].values()),
            "L9_PAIR_MEASUREMENT_OR_ROUTE_RECEIPTS",
        )
    else:
        require(
            pair.get("precondition_negative_roles")
            == expected_pair["precondition_negative_roles"],
            "L9_PAIR_PRECONDITION_NEGATIVE_ROLES",
        )


def validate_l9_attempt_identity_document(
    attempt: Any,
    descriptors: list[Any],
    *,
    source_commit: str,
    authority_sha256: str,
    parent_attempt_id: str,
) -> None:
    require(
        isinstance(attempt, dict)
        and attempt.get("schema_version") == ATTEMPT_SCHEMA
        and attempt.get("gate_id") == "QSDK-R10F"
        and attempt.get("repair_id") == REPAIR_ID
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("campaign_role") == "development_route_ghost"
        and attempt.get("question_class") == "development"
        and attempt.get("ledger_scope")
        == ledger_scope("consumed_physical_attempt_identity")
        and attempt.get("status")
        == "physical_identity_and_ordered_children_consumed_before_first_child_start"
        and attempt.get("source_commit") == source_commit
        and attempt.get("authority_sha256") == authority_sha256
        and attempt.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and attempt.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and attempt.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and attempt.get("attempt_id") == parent_attempt_id
        and attempt.get("ordered_child_manifest") == descriptors
        and exact_int(attempt.get("seed"), SEED)
        and attempt.get("same_identity_rerun_permitted") is False
        and attempt.get("child_retry_permitted") is False
        and attempt.get("child_replacement_permitted") is False
        and exact_int(attempt.get("maximum_campaign_attempt_count"), 1)
        and exact_int(attempt.get("maximum_child_process_count"), 2)
        and exact_int(attempt.get("maximum_world_count_per_child"), 1)
        and exact_int(attempt.get("maximum_total_world_count"), 2)
        and exact_int(attempt.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(attempt.get("maximum_total_solver_step_count"), 7684)
        and attempt.get("physical_execution_authorized") is True
        and attempt.get("physical_acceptance_authority") is False
        and attempt.get("release_authority") is False,
        "L9_ATTEMPT_IDENTITY_FIELDS",
    )


def validate_l9_report(
    report: Mapping[str, Any], *, report_path: Path | None, verify_files: bool,
    require_l15_launch: bool = False,
    require_l15_publication: bool = False,
    expected_l15_collection_identity: Mapping[str, Any] | None = None,
    expected_l15_context_binding: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    require(type(require_l15_launch) is bool, "L15_REQUIRED_MODE_TYPE")
    require(type(require_l15_publication) is bool, "L15_PUBLICATION_MODE_TYPE")
    if verify_files and (require_l15_publication or REPAIR_ID == "QSDK-R10F-L15"):
        require(report_path is not None, "L9_REPORT_PATH_REQUIRED")
        # A later exception is a distinct retained source. Never accept the
        # primary alone, even if that file says the pair was valid. A malformed
        # terminal file also blocks acceptance; it does not erase the failure.
        require(
            not (report_path.resolve().parent / "terminal_supervisor_failure.json").exists(),
            "L15_LATER_TERMINAL_FAILURE_REQUIRES_TERMINAL_CLOSURE",
        )
    context_mode = require_l15_context_expectations(
        expected_l15_collection_identity, expected_l15_context_binding
    )
    source_commit = report.get("source_commit")
    authority_sha = report.get("authority_sha256")
    parent_attempt_id = report.get("attempt_id")
    descriptors = report.get("ordered_child_manifest")
    envelopes = report.get("child_envelopes")
    population = report.get("process_population_evaluation")
    require(
        report.get("schema_version") == SUPERVISOR_SCHEMA
        and report.get("gate_id") == "QSDK-R10F"
        and report.get("repair_id") == REPAIR_ID
        and report.get("campaign_id") == CAMPAIGN_ID
        and report.get("campaign_role") == "development_route_ghost"
        and report.get("question_class") == "development"
        and report.get("ledger_scope")
        == ledger_scope("consumed_physical_campaign_report")
        and isinstance(report.get("ok"), bool)
        and isinstance(report.get("evidence_valid"), bool)
        and isinstance(report.get("measurement_complete"), bool)
        and isinstance(report.get("route_execution_valid"), bool)
        and isinstance(report.get("outcome_complete"), bool)
        and isinstance(report.get("behavior_passed"), bool)
        and report.get("scientific_outcome") in {"none", "positive", "negative"}
        and isinstance(report.get("failure_code"), str)
        and is_commit(source_commit)
        and is_sha256(authority_sha)
        and report.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and report.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and report.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and is_identifier(parent_attempt_id)
        and report.get("attempt_identity_consumed") is True
        and report.get("same_identity_rerun_permitted") is False
        and exact_int(report.get("maximum_campaign_attempt_count"), 1)
        and exact_int(report.get("maximum_child_process_count"), 2)
        and exact_int(report.get("maximum_world_count_per_child"), 1)
        and exact_int(report.get("maximum_total_world_count"), 2)
        and exact_int(report.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(report.get("maximum_total_solver_step_count"), 7684)
        and isinstance(descriptors, list)
        and len(descriptors) == 2
        and isinstance(envelopes, list)
        and 1 <= len(envelopes) <= 2
        and report.get("physical_question_opened") is True
        and report.get("force_aware_recovery") is False
        and report.get("force_aware_bracing") is False
        and report.get("arbitrary_fall_recovery_claimed") is False
        and report.get("cross_engine_push_recovery_claimed") is False
        and report.get("sdk1_m07_satisfied") is False
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False,
        "L9_SUPERVISOR_FIELDS",
    )
    descriptor_paths: list[Path] = []
    child_ids: list[str] = []
    nonces: list[str] = []
    for index, descriptor in enumerate(descriptors):
        require(isinstance(descriptor, dict), f"L9_DESCRIPTOR_{index}_NOT_OBJECT")
        expected_role = ARM_ORDER[index]
        require(
            exact_int(descriptor.get("launch_index"), index + 1)
            and descriptor.get("role") == expected_role
            and is_identifier(descriptor.get("child_attempt_id"))
            and descriptor.get("child_attempt_id") != parent_attempt_id
            and is_identifier(descriptor.get("termination_nonce"))
            and exact_int(descriptor.get("child_retry_count"), 0)
            and exact_int(descriptor.get("child_replacement_count"), 0),
            f"L9_DESCRIPTOR_{index}_FIELDS",
        )
        child_ids.append(str(descriptor["child_attempt_id"]))
        nonces.append(str(descriptor["termination_nonce"]))
        descriptor_paths.append(
            l9_normalized_path(
                descriptor.get("evidence_path"), f"L9_DESCRIPTOR_{index}_PATH"
            )
        )
    require(
        len(set(child_ids)) == 2
        and len(set(nonces)) == 2
        and descriptor_paths[0] != descriptor_paths[1],
        "L9_DESCRIPTOR_IDENTITIES_NOT_DISTINCT",
    )
    children: list[dict[str, Any]] = []
    for index, envelope in enumerate(envelopes):
        require(
            isinstance(envelope, dict) and envelope.get("role") == ARM_ORDER[index],
            f"L9_ENVELOPE_ORDER_{index}",
        )
        children.append(
            validate_l9_child_envelope(
                envelope,
                descriptors[index],
                parent_attempt_id=str(parent_attempt_id),
                source_commit=str(source_commit),
                authority_sha256=str(authority_sha),
                verify_files=verify_files,
                require_l15_launch=require_l15_launch,
                expected_l15_collection_identity=expected_l15_collection_identity,
                expected_l15_context_binding=expected_l15_context_binding,
            )
        )
    topology_errors: list[str] = []
    if len(children) != 2:
        topology_errors.append("declared_child_missing")
    if len(children) == 2:
        if children[0]["process_id"] == children[1]["process_id"]:
            topology_errors.append("child_process_id_reused")
        if children[0]["completed"] > children[1]["started"]:
            topology_errors.append("child_process_lifetimes_overlap")
    # Configuration equality is population-level: each child can be valid in
    # isolation while still failing the frozen matched-arm comparison.
    if (
        len(children) == 2
        and children[0]["child_valid"]
        and children[1]["child_valid"]
        and children[0]["child"]["configuration_sha256"]
        != children[1]["child"]["configuration_sha256"]
    ):
        topology_errors.append("frozen_configuration_mismatch")
    expected_pair: dict[str, Any] | None = None
    if (
        len(children) == 2
        and not topology_errors
        and all(child["child_valid"] for child in children)
    ):
        expected_pair = validate_l9_pair_from_children(
            children[0]["child"], children[1]["child"]
        )
    validate_l9_population_projection(
        population,
        children,
        expected_pair,
        source_commit=str(source_commit),
        authority_sha256=str(authority_sha),
        parent_attempt_id=str(parent_attempt_id),
    )
    observed_counts = l9_observed_counter_projection(envelopes)
    require(
        exact_int(report.get("ordered_child_count"), len(envelopes))
        and report.get("all_declared_children_present") is (len(envelopes) == 2)
        and report.get("observed_completed_child_count_fields_known")
        is observed_counts["core_known"]
        and report.get("observed_count_field_known") == observed_counts["known"]
        and report.get("model_construction_attempt_count")
        == observed_counts["model_construction_attempt_count"]
        and report.get("model_construction_count")
        == observed_counts["model_construction_count"]
        and report.get("world_attempt_count") == observed_counts["world_attempt_count"]
        and report.get("world_build_count") == observed_counts["world_build_count"]
        and report.get("solver_step_count") == observed_counts["solver_step_count"]
        and report.get("explicit_worker_extra_native_readback_count")
        == observed_counts["explicit_worker_extra_native_readback_count"]
        and report.get("physics_state_modified")
        is observed_counts["physics_state_modified"],
        "L9_SUPERVISOR_OBSERVED_COUNTER_PROJECTION",
    )
    require(
        report.get("ok") is population.get("ok")
        and report.get("status") == population.get("status")
        and report.get("evidence_valid") is population.get("evidence_valid")
        and report.get("measurement_complete") is population.get("measurement_complete")
        and report.get("route_execution_valid") is population.get("route_execution_valid")
        and report.get("outcome_complete") is population.get("outcome_complete")
        and report.get("behavior_passed") is population.get("behavior_passed")
        and report.get("scientific_outcome") == population.get("scientific_outcome")
        and report.get("failure_code") == population.get("failure_code")
        and report.get("child_processes_overlap_in_wall_clock_time")
        is population.get("process_lifetimes_overlap")
        and report.get("serialized_fresh_processes_valid")
        is bool(population.get("serialized_fresh_processes_valid", False))
        and report.get("child_retry_or_replacement_used")
        is bool(population.get("child_retry_or_replacement_used", False))
        and report.get("evaluator_invocation_count")
        == population.get("evaluator_invocation_count")
        and report.get("event_triggered_passive_recovery_observed")
        is (bool(population.get("ok")) and bool(population.get("behavior_passed")))
        and report.get("continuous_same_body_recovery_resume_observed")
        is (bool(population.get("ok")) and bool(population.get("behavior_passed"))),
        "L9_SUPERVISOR_POPULATION_PROJECTION",
    )
    if expected_pair is None:
        independent = {
            "classification": "invalid_or_incomplete_no_behavioral_conclusion",
            "route_execution_valid": False,
            "evidence_valid": False,
            "measurement_complete": False,
            "outcome_complete": False,
            "behavior_passed": False,
            "scientific_outcome": "none",
            "failure_code": report["failure_code"],
            "false_route_receipts": [],
            "computed_measurements": {},
            "precondition_negative_roles": [],
        }
    else:
        independent = dict(expected_pair)
    dispositions = {
        child["role"]: child["child"]["disposition"]
        for child in children
        if child["child_valid"]
    }
    walking_failure_retention_by_arm = {
        child["role"]: dict(child["walking_failure_retention"])
        for child in children
        if child["walking_failure_retention"]
    }
    independent.update(
        {
            "child_projections": {
                child["role"]: child["child"]
                for child in children
                if child["child_valid"]
            },
            "child_validation_errors": {
                child["role"]: child["child_validation_error"]
                for child in children
                if not child["child_valid"]
            },
            "walking_failure_retention_by_arm": walking_failure_retention_by_arm,
            "topology_validation_errors": topology_errors,
            "precondition_terminal_dispositions": {
                "disposition_by_arm": dispositions,
                "precondition_negative_roles": [
                    role
                    for role, disposition in dispositions.items()
                    if disposition != "complete_source_retained"
                ],
                "independent_population_validation_performed": True,
                "summary_boolean_only": False,
            },
            "process_isolation": {
                "ordered_declared_child_roles": ARM_ORDER,
                "declared_child_count": 2,
                "observed_child_count": len(children),
                "distinct_child_process_ids": (
                    len(children) == 2
                    and children[0]["process_id"] != children[1]["process_id"]
                ),
                "child_process_lifetimes_overlap": (
                    None
                    if len(children) != 2
                    else children[0]["completed"] > children[1]["started"]
                ),
                "one_arm_per_child_process": all(
                    child["child_valid"] for child in children
                ),
                "one_world_per_child_process": all(
                    child["child_valid"] for child in children
                ),
                "child_retry_or_replacement_used": False,
                "world_or_body_state_transferred_between_children": False,
            },
        }
    )
    if expected_l15_collection_identity is not None or REPAIR_ID == "QSDK-R10F-L15":
        independent["collection_failure_retention_by_arm"] = {
            child["role"]: child["collection_failure_retention"]
            for child in children
            if child.get("collection_failure_retention")
        }
    if context_mode:
        independent["prepared_context_integrity_by_arm"] = {
            child["role"]: child["prepared_context_integrity"] for child in children
        }
    if verify_files:
        require(report_path is not None, "L9_REPORT_PATH_REQUIRED")
        resolved = report_path.resolve()
        expected_root = EVIDENCE_ROOT / (
            "qsdk-r10f-development-route-ghost-" + str(authority_sha)[7:23]
        )
        require(
            resolved.name == "supervisor_result.json"
            and resolved.parent.parent.resolve() == EVIDENCE_ROOT.resolve()
            and resolved.parent == expected_root.resolve()
            and l9_normalized_path(report.get("evidence_root"), "L9_EVIDENCE_ROOT")
            == expected_root.resolve(),
            "L9_REPORT_LOCATION",
        )
        expected_child_paths = [
            expected_root / "children" / f"01-{BASELINE_ARM}",
            expected_root / "children" / f"02-{ACTIVE_ARM}",
        ]
        require(
            descriptor_paths == [path.resolve() for path in expected_child_paths],
            "L9_DESCRIPTOR_PATH_LAYOUT",
        )
        attempt_path = expected_root / "attempt_identity.json"
        require(attempt_path.is_file(), "L9_ATTEMPT_IDENTITY_MISSING")
        attempt = read_json(attempt_path, "L9_ATTEMPT_IDENTITY")
        validate_l9_attempt_identity_document(
            attempt,
            descriptors,
            source_commit=str(source_commit),
            authority_sha256=str(authority_sha),
            parent_attempt_id=str(parent_attempt_id),
        )
        authority_files = validate_l9_authority_files(report)
        independent["evidence_bindings"] = {
            "supervisor_result": file_identity(resolved),
            "attempt_identity": file_identity(attempt_path),
            "child_process_artifacts": {
                child["role"]: child["artifact_bindings"] for child in children
            },
            "execution_authority": file_identity(AUTHORITY_PATH, relative_to=ROOT),
            "stage_freeze": file_identity(STAGE_PATH, relative_to=ROOT),
            "r10f_design": file_identity(DESIGN_PATH, relative_to=ROOT),
            "l14_repair_design": file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT),
            "l14_branch_completeness_addendum": file_identity(
                BRANCH_COMPLETENESS_ADDENDUM_PATH, relative_to=ROOT
            ),
            "superseded_physical_supervisor_refusal": file_identity(
                SUPERVISOR_REFUSAL_PATH, relative_to=ROOT
            ),
            "consumed_predecessor_physical_closure": file_identity(
                PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT
            ),
        }
        independent["authority"] = authority_files["authority"]
    return independent


def validate_l15_primary_report_failure_retention(
    failure: Mapping[str, Any], *, report_path: Path
) -> dict[str, Any]:
    """Reopen the error-time bytes without promoting or repairing the primary.

    The write-time binding and error-time binding are different observations.
    Even an incomplete JSON file is retainable here. If hashing failed during
    error handling, a successful read now cannot invent that missing old hash.
    """
    retained = failure.get("l15_primary_report_failure_retention")
    require(
        isinstance(retained, dict)
        and set(retained) == {
            "schema_version", "ledger_scope", "primary_file_exists",
            "primary_file_binding", "primary_file_binding_failure",
            "primary_written_binding", "primary_write_completed",
            "primary_marker_published", "primary_report_replaced",
            "physical_acceptance_authority", "release_authority",
        }
        and retained.get("schema_version")
        == "sporespore_qsdk_r10f_l15_primary_report_failure_retention_v1"
        and retained.get("ledger_scope")
        == ledger_scope("development_primary_report_failure_retention")
        and all(type(retained.get(key)) is bool for key in (
            "primary_file_exists", "primary_write_completed", "primary_marker_published"
        ))
        and isinstance(retained.get("primary_file_binding_failure"), str)
        and retained.get("primary_report_replaced") is False
        and retained.get("physical_acceptance_authority") is False
        and retained.get("release_authority") is False,
        "L15_PRIMARY_FAILURE_RETENTION_FIELDS",
    )
    primary_path = report_path.resolve().parent / "supervisor_result.json"
    exists = retained["primary_file_exists"]
    written = retained["primary_written_binding"]
    observed = retained["primary_file_binding"]
    binding_failure = retained["primary_file_binding_failure"]
    require(exists is primary_path.is_file(), "L15_PRIMARY_FAILURE_FILE_PRESENCE")
    for label, binding in (("WRITTEN", written), ("OBSERVED", observed)):
        if binding is not None:
            require(
                isinstance(binding, dict)
                and set(binding) == {"path", "byte_length", "raw_sha256"}
                and binding.get("path") == primary_path.as_posix()
                and type(binding.get("byte_length")) is int
                and binding["byte_length"] >= 0
                and is_sha256(binding.get("raw_sha256")),
                f"L15_PRIMARY_FAILURE_{label}_BINDING_FIELDS",
            )
    require(
        (written is None or retained["primary_write_completed"])
        and (not retained["primary_marker_published"] or (
            retained["primary_write_completed"] and written is not None
        )),
        "L15_PRIMARY_FAILURE_PUBLICATION_STATE",
    )
    require(
        (exists and (
            (observed is not None and binding_failure == "")
            or (observed is None and bool(binding_failure))
        ))
        or (not exists and observed is None and binding_failure == ""),
        "L15_PRIMARY_FAILURE_BINDING_STATE",
    )
    current = None
    if exists:
        try:
            current = file_identity(primary_path)
        except OSError as exc:
            raise ClosureFailure(f"L15_PRIMARY_FAILURE_FILE_UNREADABLE:{exc}") from exc
        if observed is not None:
            require(
                l15_launch.same(observed, current),
                "L15_PRIMARY_FAILURE_OBSERVED_BYTES_CHANGED",
            )
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_primary_failure_retention_audit_v1",
        "ledger_scope": ledger_scope("development_primary_report_failure_retention_audit"),
        "primary_written_binding": written,
        "primary_error_time_binding": observed,
        "primary_current_file_binding": current,
        "primary_error_time_binding_failure": binding_failure,
        "primary_write_completed": retained["primary_write_completed"],
        "primary_marker_published": retained["primary_marker_published"],
        "original_written_bytes_still_present": (
            None if written is None else l15_launch.same(written, current)
        ),
        "error_time_bytes_independently_verified": observed is not None,
        "primary_json_parsed_or_repaired": False,
        "primary_report_replaced": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_l9_terminal_supervisor_failure(
    failure: Mapping[str, Any], *, report_path: Path,
    require_l15_launch: bool = False,
    require_l15_publication: bool = False,
    expected_l15_collection_identity: Mapping[str, Any] | None = None,
    expected_l15_context_binding: Mapping[str, Any] | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    require(type(require_l15_launch) is bool, "L15_REQUIRED_MODE_TYPE")
    require(type(require_l15_publication) is bool, "L15_PUBLICATION_MODE_TYPE")
    require_l15_publication = require_l15_publication or REPAIR_ID == "QSDK-R10F-L15"
    context_mode = require_l15_context_expectations(
        expected_l15_collection_identity, expected_l15_context_binding
    )
    observed = failure.get("observed_child_envelopes")
    root = l9_normalized_path(
        failure.get("physical_attempt_root"), "L9_TERMINAL_FAILURE_ROOT"
    )
    parent_attempt_id = failure.get("attempt_id")
    require(
        failure.get("schema_version") == "sporespore_qsdk_r10f_supervisor_refusal_v1"
        and failure.get("gate_id") == "QSDK-R10F"
        and failure.get("repair_id") == REPAIR_ID
        and failure.get("campaign_id") == CAMPAIGN_ID
        and failure.get("campaign_role") == "development_route_ghost"
        and failure.get("question_class") == "development"
        and failure.get("ledger_scope")
        == ledger_scope("consumed_physical_supervisor_failure")
        and failure.get("ok") is False
        and failure.get("mode") == "Physical"
        and isinstance(failure.get("failure_code"), str)
        and bool(failure.get("failure_code"))
        and failure.get("physical_execution_requested") is True
        and failure.get("physical_attempt_identity_consumed") is True
        and is_identifier(parent_attempt_id)
        and failure.get("physical_question_opened") is True
        and isinstance(observed, list)
        and 0 <= len(observed) <= 2
        and exact_int(failure.get("observed_completed_child_count"), len(observed))
        and failure.get("physical_acceptance_authority") is False
        and failure.get("release_authority") is False,
        "L9_TERMINAL_SUPERVISOR_FAILURE_FIELDS",
    )
    resolved_report = report_path.resolve()
    require(
        resolved_report.name == "terminal_supervisor_failure.json"
        and resolved_report.parent == root
        and root.parent == EVIDENCE_ROOT.resolve(),
        "L9_TERMINAL_SUPERVISOR_FAILURE_LOCATION",
    )
    primary_retention = (
        validate_l15_primary_report_failure_retention(failure, report_path=resolved_report)
        if require_l15_publication else None
    )
    attempt_path = root / "attempt_identity.json"
    require(attempt_path.is_file(), "L9_TERMINAL_FAILURE_ATTEMPT_MISSING")
    attempt = read_json(attempt_path, "L9_TERMINAL_FAILURE_ATTEMPT")
    descriptors = attempt.get("ordered_child_manifest")
    source_commit = attempt.get("source_commit")
    authority_sha = attempt.get("authority_sha256")
    require(
        isinstance(descriptors, list)
        and len(descriptors) == 2
        and is_commit(source_commit)
        and is_sha256(authority_sha),
        "L9_TERMINAL_FAILURE_ATTEMPT_SOURCE",
    )
    validate_l9_attempt_identity_document(
        attempt,
        descriptors,
        source_commit=str(source_commit),
        authority_sha256=str(authority_sha),
        parent_attempt_id=str(parent_attempt_id),
    )
    expected_root = EVIDENCE_ROOT / (
        "qsdk-r10f-development-route-ghost-" + str(authority_sha)[7:23]
    )
    require(root == expected_root.resolve(), "L9_TERMINAL_FAILURE_IDENTITY_ROOT")
    expected_paths = [
        root / "children" / f"01-{BASELINE_ARM}",
        root / "children" / f"02-{ACTIVE_ARM}",
    ]
    for index, descriptor in enumerate(descriptors):
        require(
            isinstance(descriptor, dict)
            and exact_int(descriptor.get("launch_index"), index + 1)
            and descriptor.get("role") == ARM_ORDER[index]
            and is_identifier(descriptor.get("child_attempt_id"))
            and is_identifier(descriptor.get("termination_nonce"))
            and l9_normalized_path(
                descriptor.get("evidence_path"),
                f"L9_TERMINAL_FAILURE_DESCRIPTOR_PATH_{index}",
            )
            == expected_paths[index].resolve()
            and exact_int(descriptor.get("child_retry_count"), 0)
            and exact_int(descriptor.get("child_replacement_count"), 0),
            f"L9_TERMINAL_FAILURE_DESCRIPTOR_{index}",
        )
    require(
        descriptors[0]["child_attempt_id"] != descriptors[1]["child_attempt_id"]
        and descriptors[0]["termination_nonce"] != descriptors[1]["termination_nonce"],
        "L9_TERMINAL_FAILURE_CHILD_IDENTITIES_DISTINCT",
    )
    children: list[dict[str, Any]] = []
    for index, envelope in enumerate(observed):
        require(
            isinstance(envelope, dict) and envelope.get("role") == ARM_ORDER[index],
            f"L9_TERMINAL_FAILURE_ENVELOPE_ORDER_{index}",
        )
        children.append(
            validate_l9_child_envelope(
                envelope,
                descriptors[index],
                parent_attempt_id=str(parent_attempt_id),
                source_commit=str(source_commit),
                authority_sha256=str(authority_sha),
                verify_files=True,
                require_l15_launch=require_l15_launch,
                expected_l15_collection_identity=expected_l15_collection_identity,
                expected_l15_context_binding=expected_l15_context_binding,
            )
        )
    counts = l9_observed_counter_projection(observed)
    require(
        failure.get("count_fields_known") is counts["core_known"]
        and failure.get("model_construction_count")
        == counts["model_construction_count"]
        and failure.get("world_attempt_count") == counts["world_attempt_count"]
        and failure.get("world_build_count") == counts["world_build_count"]
        and failure.get("solver_step_count") == counts["solver_step_count"]
        and failure.get("native_readback_count")
        == counts["explicit_worker_extra_native_readback_count"]
        and exact_int(failure.get("scene_tree_insertion_count"), -1)
        and failure.get("physics_state_modified") is counts["physics_state_modified"],
        "L9_TERMINAL_FAILURE_COUNTER_PROJECTION",
    )
    topology_errors = ["terminal_supervisor_failure_before_pair_evaluation"]
    if primary_retention is not None:
        # In L15 the catch may run after a valid pair or even publication.
        # Do not infer the failure's timing from this terminal file's name.
        topology_errors = [
            "terminal_supervisor_failure_after_primary_publication"
            if primary_retention["primary_marker_published"]
            else "terminal_supervisor_failure_without_primary_publication"
        ]
    if len(children) != 2:
        topology_errors.append("declared_child_missing")
    if len(children) == 2:
        if children[0]["process_id"] == children[1]["process_id"]:
            topology_errors.append("child_process_id_reused")
        if children[0]["completed"] > children[1]["started"]:
            topology_errors.append("child_process_lifetimes_overlap")
    child_projections = {
        child["role"]: child["child"]
        for child in children
        if child["child_valid"]
    }
    dispositions = {
        role: projection["disposition"]
        for role, projection in child_projections.items()
    }
    walking_failure_retention_by_arm = {
        child["role"]: dict(child["walking_failure_retention"])
        for child in children
        if child["walking_failure_retention"]
    }
    authority_files = validate_l9_authority_files(
        {"source_commit": source_commit, "authority_sha256": authority_sha}
    )
    outcome = {
        "classification": "invalid_or_incomplete_no_behavioral_conclusion",
        "route_execution_valid": False,
        "evidence_valid": False,
        "measurement_complete": False,
        "outcome_complete": False,
        "behavior_passed": False,
        "scientific_outcome": "none",
        "failure_code": failure["failure_code"],
        "false_route_receipts": [],
        "computed_measurements": {},
        "child_projections": child_projections,
        "child_validation_errors": {
            child["role"]: child["child_validation_error"]
            for child in children
            if not child["child_valid"]
        },
        "walking_failure_retention_by_arm": walking_failure_retention_by_arm,
        "topology_validation_errors": topology_errors,
        "precondition_terminal_dispositions": {
            "disposition_by_arm": dispositions,
            "precondition_negative_roles": [
                role
                for role, disposition in dispositions.items()
                if disposition != "complete_source_retained"
            ],
            "independent_population_validation_performed": False,
            "summary_boolean_only": False,
        },
        "process_isolation": {
            "ordered_declared_child_roles": ARM_ORDER,
            "declared_child_count": 2,
            "observed_child_count": len(children),
            "distinct_child_process_ids": (
                len(children) == 2
                and children[0]["process_id"] != children[1]["process_id"]
            ),
            "child_process_lifetimes_overlap": (
                None
                if len(children) != 2
                else children[0]["completed"] > children[1]["started"]
            ),
            "one_arm_per_child_process": all(
                child["child_valid"] for child in children
            ),
            "one_world_per_child_process": all(
                child["child_valid"] for child in children
            ),
            "child_retry_or_replacement_used": False,
            "world_or_body_state_transferred_between_children": False,
        },
        "evidence_bindings": {
            "terminal_supervisor_failure": file_identity(resolved_report),
            "attempt_identity": file_identity(attempt_path),
            "child_process_artifacts": {
                child["role"]: child["artifact_bindings"] for child in children
            },
            "execution_authority": file_identity(AUTHORITY_PATH, relative_to=ROOT),
            "stage_freeze": file_identity(STAGE_PATH, relative_to=ROOT),
            "r10f_design": file_identity(DESIGN_PATH, relative_to=ROOT),
            "l14_repair_design": file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT),
            "l14_branch_completeness_addendum": file_identity(
                BRANCH_COMPLETENESS_ADDENDUM_PATH, relative_to=ROOT
            ),
            "superseded_physical_supervisor_refusal": file_identity(
                SUPERVISOR_REFUSAL_PATH, relative_to=ROOT
            ),
            "consumed_predecessor_physical_closure": file_identity(
                PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT
            ),
        },
        "authority": authority_files["authority"],
    }
    if expected_l15_collection_identity is not None or REPAIR_ID == "QSDK-R10F-L15":
        outcome["collection_failure_retention_by_arm"] = {
            child["role"]: child["collection_failure_retention"]
            for child in children
            if child.get("collection_failure_retention")
        }
    if context_mode:
        outcome["prepared_context_integrity_by_arm"] = {
            child["role"]: child["prepared_context_integrity"] for child in children
        }
    if primary_retention is not None:
        outcome["l15_primary_report_failure_retention"] = primary_retention
        if primary_retention["primary_current_file_binding"] is not None:
            outcome["evidence_bindings"]["retained_primary_supervisor_result"] = (
                primary_retention["primary_current_file_binding"]
            )
    normalized = {
        "source_commit": source_commit,
        "authority_sha256": authority_sha,
        "attempt_id": parent_attempt_id,
        "ordered_child_count": len(children),
        "model_construction_attempt_count": counts[
            "model_construction_attempt_count"
        ],
        "model_construction_count": counts["model_construction_count"],
        "world_attempt_count": counts["world_attempt_count"],
        "world_build_count": counts["world_build_count"],
        "solver_step_count": counts["solver_step_count"],
        "explicit_worker_extra_native_readback_count": counts[
            "explicit_worker_extra_native_readback_count"
        ],
    }
    return normalized, outcome


def l14_handoff_closure_projection(outcome: Mapping[str, Any]) -> dict[str, Any]:
    """Summarize independently validated children, never raw report flags.

    A complete pre-resume negative has two baseline handoffs and one active
    prefix handoff. It has no resumed-walking handoff and proves no recovery
    success. All other complete routes retain the original two-plus-two rule.
    """
    children = outcome.get("child_projections")
    require(isinstance(children, dict), "L14_CLOSURE_CHILD_PROJECTIONS")
    projections = {
        role: child.get("walking_actuation_handoffs", {})
        for role, child in children.items()
        if isinstance(child, dict)
    }
    require(set(projections) == set(children), "L14_CLOSURE_CHILD_PROJECTION_SHAPE")
    count = 0
    extra_steps = 0
    for role, value in projections.items():
        require(
            isinstance(value, dict)
            and bounded_int(value.get("handoff_count"), 0, 2)
            and exact_int(value.get("extra_solver_step_count"), 0),
            "L14_CLOSURE_HANDOFF_PROJECTION:" + role,
        )
        count += value["handoff_count"]
        extra_steps += value["extra_solver_step_count"]
    route_valid = outcome.get("route_execution_valid")
    require(type(route_valid) is bool, "L14_CLOSURE_ROUTE_VALID_KIND")
    no_resume = False
    expected_count = None
    if route_valid:
        require(set(children) == set(ARM_ORDER), "L14_CLOSURE_COMPLETE_CHILD_SET")
        active_proof = children[ACTIVE_ARM].get("no_resume_terminal")
        require(isinstance(active_proof, dict), "L14_CLOSURE_NO_RESUME_PROOF_SHAPE")
        no_resume = active_proof.get("source_proven_no_resume_negative") is True
        expected = {
            BASELINE_ARM: ["walking_prefix", "matched_continuation"],
            ACTIVE_ARM: ["walking_prefix"] if no_resume else ["walking_prefix", "walking_resume"],
        }
        expected_count = sum(len(segments) for segments in expected.values())
        require(
            all(
                projections[role].get("ordered_evaluation_segments") == segments
                and exact_int(projections[role].get("handoff_count"), len(segments))
                for role, segments in expected.items()
            )
            and count == expected_count
            and (not no_resume or outcome.get("behavior_passed") is False),
            "L14_CLOSURE_BRANCH_HANDOFF_POPULATION",
        )
    return {
        "walking_actuation_handoff_observed": route_valid,
        "walking_actuation_handoff_receipt_count": count,
        "walking_actuation_handoff_expected_count_for_complete_route": expected_count,
        "walking_actuation_handoff_extra_solver_step_count": extra_steps,
        "source_proven_no_resume_negative_observed": route_valid and no_resume,
    }


def build_l9_closure(
    report_path: Path, report: Mapping[str, Any], outcome: Mapping[str, Any]
) -> dict[str, Any]:
    authority = outcome.get("authority")
    bindings = outcome.get("evidence_bindings")
    require(isinstance(authority, dict), "L9_CLOSURE_AUTHORITY_MISSING")
    try:
        l14_components.validate_receipt(authority.get("l14_component_qualification"))
        l14_runtime.validate_binding(authority.get("l14_exact_runtime_images"))
    except ValueError as exc:
        raise ClosureFailure(f"L14_CLOSURE_COMPONENT_QUALIFICATION:{exc}") from exc
    require(isinstance(bindings, dict), "L9_CLOSURE_BINDINGS_MISSING")
    graph = validate_l9_live_authority_graph(authority)
    classification = str(outcome["classification"])
    behavior = bool(outcome["behavior_passed"])
    child_projections = outcome.get("child_projections")
    require(isinstance(child_projections, dict), "L13_CLOSURE_CHILD_PROJECTIONS")
    walking_failure_retention = outcome.get("walking_failure_retention_by_arm")
    require(
        isinstance(walking_failure_retention, dict),
        "L13_CLOSURE_WALKING_FAILURE_RETENTION",
    )
    handoff_summary = l14_handoff_closure_projection(outcome)
    handoff_receipt_count = handoff_summary["walking_actuation_handoff_receipt_count"]
    return {
        "schema_version": (
            "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v16"
            if REPAIR_ID == "QSDK-R10F-L15" else
            "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v15"
        ),
        "l14_component_qualification": copy.deepcopy(authority["l14_component_qualification"]),
        "l14_exact_runtime_images": copy.deepcopy(authority["l14_exact_runtime_images"]),
        "status": {
            "valid_complete_behavior_positive": (
                "closed_consumed_valid_complete_behavior_positive"
            ),
            "valid_complete_behavior_development_negative": (
                "closed_consumed_valid_complete_behavior_development_negative"
            ),
            "invalid_or_incomplete_no_behavioral_conclusion": (
                "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
            ),
        }[classification],
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "campaign_id": CAMPAIGN_ID,
        "campaign_role": "development_route_ghost",
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_physical_campaign_closure"),
        "source_commit": report["source_commit"],
        "stage_commit": graph["stage_commit"],
        "authority_commit": graph["authority_commit"],
        "closure_audit_commit": graph["closure_audit_commit"],
        "authority_sha256": report["authority_sha256"],
        "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "branch_completeness_addendum_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "superseded_physical_supervisor_refusal_sha256": (
            EXPECTED_SUPERVISOR_REFUSAL_SHA256
        ),
        "consumed_predecessor_physical_closure_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "attempt_id": report["attempt_id"],
        "classification": classification,
        "route_execution_valid": outcome["route_execution_valid"],
        "evidence_valid": outcome["evidence_valid"],
        "measurement_complete": outcome["measurement_complete"],
        "outcome_complete": outcome["outcome_complete"],
        "behavior_passed": behavior,
        "scientific_outcome": outcome["scientific_outcome"],
        "failure_code": outcome["failure_code"],
        "false_route_receipts": list(outcome["false_route_receipts"]),
        "computed_pair_measurements": dict(outcome["computed_measurements"]),
        **({
            "l15_primary_report_failure_retention": copy.deepcopy(
                outcome["l15_primary_report_failure_retention"]
            ),
        } if "l15_primary_report_failure_retention" in outcome else {}),
        "child_projections": dict(child_projections),
        "child_validation_errors": dict(outcome["child_validation_errors"]),
        "process_isolation": dict(outcome["process_isolation"]),
        "topology_validation_errors": list(outcome["topology_validation_errors"]),
        "precondition_terminal_dispositions": dict(
            outcome["precondition_terminal_dispositions"]
        ),
        "evidence_bindings": dict(bindings),
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "campaign_attempt_count": 1,
        "maximum_campaign_attempt_count": 1,
        "observed_child_process_count": report["ordered_child_count"],
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_total_world_count": 2,
        "maximum_solver_step_count_per_child": 3842,
        "maximum_total_solver_step_count": 7684,
        "model_construction_attempt_count": report[
            "model_construction_attempt_count"
        ],
        "model_construction_count": report["model_construction_count"],
        "world_attempt_count": report["world_attempt_count"],
        "world_build_count": report["world_build_count"],
        "solver_step_count": report["solver_step_count"],
        "explicit_worker_extra_native_readback_count": report[
            "explicit_worker_extra_native_readback_count"
        ],
        "event_triggered_passive_recovery_observed": behavior,
        "continuous_same_body_recovery_resume_observed": behavior,
        **handoff_summary,
        "walking_actuation_handoff_qualified_projection_count_per_receipt": (
            len(JOINT_IDS) if handoff_receipt_count > 0 else 0
        ),
        "walking_actuation_handoff_outcome_derived_correction_used": False,
        "walking_native_preparse_transport_verification_qualified_zero_world": True,
        "walking_binary32_host_target_projection_qualified_zero_world": True,
        "walking_ledger_v2_named_predicates_qualified_zero_world": True,
        "walking_failed_step_source_retention_qualified_zero_world": True,
        "walking_ledger_l13_positive_control_count": 15,
        "walking_ledger_l13_mutation_rejection_count": 16,
        "walking_ledger_failure_retention_positive_control_count": 1,
        "walking_ledger_failure_retention_mutation_rejection_count": 15,
        "production_shaped_l13_walking_fixture_count": 3,
        "detached_l13_hinge_parameter_container_count": 24,
        "walking_failed_step_source_retention_by_arm": dict(
            walking_failure_retention
        ),
        "walking_failed_step_source_retention_observed": any(
            isinstance(value, dict)
            and value.get("walking_ledger_failure_present") is True
            for value in walking_failure_retention.values()
        ),
        "walking_failed_step_source_retention_all_observed_valid": all(
            isinstance(value, dict)
            and value.get("walking_ledger_failure_retention_valid") is True
            for value in walking_failure_retention.values()
            if isinstance(value, dict)
            and value.get("walking_ledger_failure_present") is True
        ),
        "walking_ledger_v2_success_receipts_retained_in_compact_closure": False,
        "shared_adapter_enable_behavior_changed": False,
        "published_actuator_profile_changed": False,
        "threshold_or_controller_changed": False,
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "held_out_finite_decision_declared": False,
        "held_out_finite_decision_authorized": False,
        "distinct_held_out_successor_may_be_declared": behavior,
        "sdk1_m07_satisfied": False,
        "q_sdk_r10_satisfied": False,
        "r10e_l3_finite_negative_preserved": True,
        "r172_exact_nominal_positive_preserved": True,
        "r173_three_engine_prone_to_standing_preserved": True,
        "l8_shared_process_topology_confound_preserved": True,
        "l9_process_isolated_topology_independently_validated": (
            not outcome["topology_validation_errors"]
            and report["ordered_child_count"] == 2
        ),
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l9_synthetic_initial_application() -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r10f_initial_bootstrap_application_validation_v1",
        "gate_id": "QSDK-R10F",
        "ok": True,
        "check_count": 11,
        "failed_checks": [],
        "observed_application_schema": (
            "sporespore_qsdk_r24d57_godot_application_intent_v1"
        ),
        "expected_application_schema": (
            "sporespore_qsdk_r24d57_godot_application_intent_v1"
        ),
        "active_application_validator_applicable": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l9_synthetic_walking_session(
    role: str,
    segment: str,
    behavior: bool,
    model_instance_id: str,
    global_start_step: int,
) -> dict[str, Any]:
    session_id = f"synthetic-{role}-{segment}"
    facade_segment = "walking_prefix" if segment == "walking_prefix" else "walking_resume"
    return {
        "session_id": session_id,
        "evaluation_segment_id": segment,
        "completion_receipt": {},
        "step_receipt_sha256s": [],
        "start_receipt": {
            "schema_version": (
                "sporespore_qsdk_r10f_recovery_native_locomotion_session_v1"
            ),
            "gate_id": "QSDK-R10F",
            "ok": True,
            "facade_id": WALKING_FACADE_ID,
            "model_instance_id": model_instance_id,
            "segment_id": facade_segment,
            "session_id": session_id,
            "global_start_step": global_start_step,
            "initial_gait_steps": {},
            "selected_policy_id": POLICY_ID,
            "task_frame_reanchored_in_controller_memory": True,
            "task_frame_origin_world_m": [0.0, 0.0, 0.0],
            "task_frame_forward_axis_world_host_real": [1.0, 0.0, 0.0],
            "task_frame_lateral_axis_world_host_real": [0.0, 0.0, 1.0],
            "task_frame_initial_yaw_rad": 0.0,
            "task_frame_frozen_for_walking_segment": True,
            "body_transform_write_count": 0,
            "body_velocity_write_count": 0,
            "solver_reset_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "evaluation": {
            "ok": True,
            "evidence_valid": True,
            "outcome_complete": True,
            "behavior_passed": behavior,
            "arm_id": role,
            "segment_id": segment,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def l12_synthetic_walking_handoff(
    model_instance_id: str,
    evaluation_segment: str,
    session_id: str,
    global_semantic_step: int,
) -> dict[str, Any]:
    reason = f"l12_walking_actuation_handoff_precommand:{evaluation_segment}"
    configuration = {
        "schema_version": MOTOR_CONFIGURATION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": True,
        "global_semantic_step": global_semantic_step,
        "reason": reason,
        "motor_enabled": True,
        "ordered_joint_receipts": [
            {
                "joint_id": joint_id,
                "motor_enabled": True,
                "motor_target_velocity_rad_s": 0.0,
            }
            for joint_id in JOINT_IDS
        ],
        "motor_configuration_write_count": len(JOINT_IDS) * 2,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "body_impulse_write_count": 0,
        "solver_reset_count": 0,
        "physics_state_modified": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    readback = {
        "schema_version": MOTOR_READBACK_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": True,
        "global_semantic_step": global_semantic_step,
        "reason": reason,
        "expected_motor_enabled": True,
        "ordered_joint_readbacks": [
            {
                "actuator_id": ACTUATOR_IDS[index],
                "joint_id": JOINT_IDS[index],
                "motor_enabled": True,
                "motor_target_velocity_rad_s": 0.0,
                "motor_maximum_impulse_nms": HOST_CAPS_NMS[index],
            }
            for index in range(len(JOINT_IDS))
        ],
        "motor_enabled_count": len(JOINT_IDS),
        "zero_target_velocity_count": len(JOINT_IDS),
        "native_readback_count": len(JOINT_IDS) * 3,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "body_impulse_write_count": 0,
        "solver_reset_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    published_map = dict(zip(ACTUATOR_IDS, PUBLISHED_CAPS_NMS))
    host_map = dict(zip(ACTUATOR_IDS, HOST_CAPS_NMS))
    binding = {
        "schema_version": HOST_CAP_BINDING_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": True,
        "projection_id": HOST_CAP_PROJECTION_ID,
        "scope": HOST_CAP_PROJECTION_SCOPE,
        "selection_rule": HOST_CAP_SELECTION_RULE,
        "ordered_actuator_ids": ACTUATOR_IDS,
        "ordered_published_caps_nms": PUBLISHED_CAPS_NMS,
        "ordered_selected_host_caps_nms": HOST_CAPS_NMS,
        "published_cap_by_actuator_id": published_map,
        "selected_host_cap_by_actuator_id": host_map,
        "ordered_projection_receipts": [
            l12_expected_host_cap_projection(index)
            for index in range(len(JOINT_IDS))
        ],
        "projection_count": len(JOINT_IDS),
        "selected_effective_limit_not_above_published_count": len(JOINT_IDS),
        "immediately_higher_effective_limit_above_published_count": len(JOINT_IDS),
        "binary32_maximality_proof_count": len(JOINT_IDS),
        "published_cap_changed": False,
        "empirical_margin_added": False,
        "raw_measurement_clamped": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    binding["payload_sha256"] = l12_payload_sha256_v1(binding)
    receipt = {
        "schema_version": WALKING_HANDOFF_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": True,
        "facade_id": WALKING_FACADE_ID,
        "model_instance_id": model_instance_id,
        "facade_segment_id": (
            "walking_prefix"
            if evaluation_segment == "walking_prefix"
            else "walking_resume"
        ),
        "evaluation_segment_id": evaluation_segment,
        "walking_session_id": session_id,
        "global_semantic_step": global_semantic_step,
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_SHA256,
        "motor_configuration_receipt": configuration,
        "motor_configuration_receipt_sha256": canonical_sha256_v1(configuration),
        "precommand_motor_population_readback": readback,
        "precommand_motor_population_readback_sha256": canonical_sha256_v1(readback),
        "host_cap_projection_binding": binding,
        "host_cap_projection_binding_sha256": binding["payload_sha256"],
        "ordered_actuator_ids": ACTUATOR_IDS,
        "published_cap_by_actuator_id": published_map,
        "authorized_host_cap_by_actuator_id": host_map,
        "motor_enabled_count": len(JOINT_IDS),
        "zero_target_velocity_count": len(JOINT_IDS),
        "motor_configuration_write_count": len(JOINT_IDS) * 2,
        "native_readback_count": len(JOINT_IDS) * 3,
        "solver_step_count": 0,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "body_impulse_write_count": 0,
        "solver_reset_count": 0,
        "physics_state_modified": True,
        "outcome_derived_correction": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    receipt["payload_sha256"] = l12_payload_sha256_v1(receipt)
    return receipt


def l13_synthetic_partial_walking_failure_report(
    *,
    role: str,
    parent_attempt_id: str,
    child_attempt_id: str,
    source_commit: str,
    authority_sha256: str,
    process_id: int,
) -> dict[str, Any]:
    model_instance_id = f"synthetic-model-{role}"
    evaluation_segment = "walking_prefix"
    global_step = 242
    local_step = 1
    session = l9_synthetic_walking_session(
        role,
        evaluation_segment,
        False,
        model_instance_id,
        global_step - 1,
    )
    session_id = str(session["session_id"])
    handoff = l12_synthetic_walking_handoff(
        model_instance_id,
        evaluation_segment,
        session_id,
        global_step,
    )
    session["walking_actuation_handoff_receipt"] = copy.deepcopy(handoff)

    controller_targets = [
        0.101,
        0.202,
        0.303,
        0.404,
        0.505,
        0.606,
        0.707,
        0.808,
    ]
    controller = {
        "schema_version": "sporespore_controller_step_receipt_v2",
        "policy_id": POLICY_ID,
        "semantic_step": local_step,
        "synthetic_source": True,
    }
    controller_digest = canonical_sha256_v1(controller)
    commands = [
        {
            "actuator_id": ACTUATOR_IDS[index],
            "target_velocity_rad_s": controller_targets[index],
            "maximum_impulse_nms": PUBLISHED_CAPS_NMS[index],
        }
        for index in range(len(ACTUATOR_IDS))
    ]
    native_transport = {
        "schema_version": NATIVE_TRANSPORT_VERIFICATION_SCHEMA,
        "verification_version": (
            "sporespore_godot_balanced_wave_native_step_transport_verification_v1"
        ),
        "ok": True,
        "policy_id": POLICY_ID,
        "semantic_step": local_step,
        "controller_receipt_schema_version": "sporespore_controller_step_receipt_v2",
        "controller_receipt_sha256": controller_digest,
        "native_actuation_receipt_sha256": controller_digest,
        "raw_native_response_sha256": "sha256:" + "4" * 64,
        "raw_native_response_byte_length": 4096,
        "successful_public_envelope": True,
        "policy_identity_exact": True,
        "semantic_step_identity_exact": True,
        "controller_receipt_schema_exact": True,
        "native_canonical_receipt_digest_exact": True,
        "preparse_native_response_verified": True,
        "raw_native_response_rewritten": False,
        "post_parse_dictionary_rehash_used": False,
        "floating_point_measurement_field_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "payload_sha256": "",
    }
    native_transport["payload_sha256"] = l12_payload_sha256_v1(native_transport)
    portable = {
        "ok": True,
        "controller_policy_id": POLICY_ID,
        "semantic_step": local_step,
        "controller_step_receipt_sha256": controller_digest,
        "native_step_transport_verification": copy.deepcopy(native_transport),
        "native_output": {
            "actuation": {
                "semantic_step": local_step,
                "safe_no_actuation": False,
                "ordered_commands": copy.deepcopy(commands),
                "receipt": copy.deepcopy(controller),
                "receipt_sha256": controller_digest,
            }
        },
    }

    applications: list[dict[str, Any]] = []
    readbacks: list[dict[str, Any]] = []
    projection_rows: list[dict[str, Any]] = []
    projection_failed = [
        "projection.row.0.application_readback_equals_projection",
        "projection.row.0.population_readback_equals_projection",
    ]
    for index, target in enumerate(controller_targets):
        expected = binary32_v1(target)
        realized = (
            binary32_from_bits_v1(binary32_bits_v1(expected) + 1)
            if index == 0
            else expected
        )
        application_projection_exact = realized == expected
        population_projection_exact = realized == expected
        applications.append(
            {
                "actuator_id": ACTUATOR_IDS[index],
                "joint_id": JOINT_IDS[index],
                "host_applied_target_velocity_rad_s": target,
                "motor_target_velocity_readback_rad_s": realized,
                "declared_maximum_impulse_nms": HOST_CAPS_NMS[index],
                "motor_maximum_impulse_readback_nms": HOST_CAPS_NMS[index],
            }
        )
        readbacks.append(
            {
                "actuator_id": ACTUATOR_IDS[index],
                "joint_id": JOINT_IDS[index],
                "motor_enabled": True,
                "motor_target_velocity_rad_s": realized,
                "motor_maximum_impulse_nms": HOST_CAPS_NMS[index],
            }
        )
        projection_rows.append(
            {
                "actuator_id": ACTUATOR_IDS[index],
                "joint_id": JOINT_IDS[index],
                "controller_binary64_target_velocity_rad_s": target,
                "expected_binary32_host_target_velocity_rad_s": expected,
                "application_host_applied_binary64_target_velocity_rad_s": target,
                "application_motor_target_velocity_readback_rad_s": realized,
                "population_motor_target_velocity_readback_rad_s": realized,
                "published_cap_nms": PUBLISHED_CAPS_NMS[index],
                "authorized_host_cap_nms": HOST_CAPS_NMS[index],
                "application_declared_maximum_impulse_nms": HOST_CAPS_NMS[index],
                "application_motor_maximum_impulse_readback_nms": HOST_CAPS_NMS[
                    index
                ],
                "population_motor_maximum_impulse_readback_nms": HOST_CAPS_NMS[
                    index
                ],
                "controller_request_finite": True,
                "binary32_projection_finite": True,
                "application_request_preserved_exactly": True,
                "application_readback_equals_projection_exactly": (
                    application_projection_exact
                ),
                "population_readback_equals_projection_exactly": (
                    population_projection_exact
                ),
                "application_population_readbacks_equal_exactly": True,
                "r69_host_cap_exact": True,
            }
        )
    authority_application = {
        "schema_version": "sporespore_godot_jolt_full_authority_application_receipt_v1",
        "ok": True,
        "semantic_step": local_step,
        "ordered_actuator_ids": ACTUATOR_IDS,
        "ordered_applications": applications,
        "applied_command_count": len(ACTUATOR_IDS),
        "configured_motor_parameters_only": True,
        "maximum_impulse_override_applied": True,
        "authorized_maximum_impulse_by_actuator_id": dict(
            zip(ACTUATOR_IDS, HOST_CAPS_NMS)
        ),
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    population_readback = {
        "schema_version": MOTOR_READBACK_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": True,
        "global_semantic_step": global_step,
        "expected_motor_enabled": True,
        "ordered_joint_readbacks": readbacks,
        "motor_enabled_count": len(ACTUATOR_IDS),
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    host_projection = {
        "schema_version": HOST_TARGET_PROJECTION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": False,
        "projection_rule": (
            "float(PackedFloat32Array([controller_target_velocity_rad_s])[0])"
        ),
        "projection_kind": (
            "deterministic_host_representation_not_empirical_correction"
        ),
        "ordered_actuator_ids": ACTUATOR_IDS,
        "ordered_target_projections": projection_rows,
        "projection_count": len(ACTUATOR_IDS),
        "nonzero_controller_target_count": len(ACTUATOR_IDS),
        "controller_binary64_target_retained_separately": True,
        "expected_binary32_host_target_retained_separately": True,
        "application_readback_equals_projection_count": len(ACTUATOR_IDS) - 1,
        "population_readback_equals_projection_count": len(ACTUATOR_IDS) - 1,
        "application_population_readbacks_equal_count": len(ACTUATOR_IDS),
        "r69_host_cap_exact_count": len(ACTUATOR_IDS),
        "controller_command_rounded_before_write": False,
        "host_write_changed": False,
        "solver_input_changed": False,
        "empirical_margin_added": False,
        "tolerance_added": False,
        "raw_measurement_clamped": False,
        "outcome_derived_correction": False,
        "failed_predicate_ids": projection_failed,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    host_projection["payload_sha256"] = l12_payload_sha256_v1(host_projection)

    ledger_failed_ids = [
        "row.host_target_projection_receipt_valid",
        "row.0.application_readback_equals_projection_exactly",
        "row.0.population_readback_equals_projection_exactly",
    ]
    ordered_predicates = [
        {
            "predicate_id": predicate_id,
            "scope": scope,
            "passed": predicate_id not in ledger_failed_ids,
            "actuator_id": actuator_id,
            "row_index": row_index,
        }
        for predicate_id, scope, actuator_id, row_index in (
            l13_expected_walking_ledger_predicate_coordinates()
        )
    ]
    identity_count = sum(
        value[1] == "identity"
        for value in l13_expected_walking_ledger_predicate_coordinates()
    )
    predicate_receipt = {
        "schema_version": WALKING_LEDGER_PREDICATE_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": False,
        "all_predicates_evaluated": True,
        "generic_failure_without_predicate_detail": False,
        "identity_predicate_count": identity_count,
        "row_predicate_count": len(ordered_predicates) - identity_count,
        "predicate_count": len(ordered_predicates),
        "passed_predicate_count": len(ordered_predicates) - len(ledger_failed_ids),
        "failed_predicate_count": len(ledger_failed_ids),
        "failed_predicate_ids": ledger_failed_ids,
        "ordered_predicates": ordered_predicates,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    predicate_receipt["payload_sha256"] = l12_payload_sha256_v1(predicate_receipt)
    failure = {
        "schema_version": WALKING_LEDGER_SCHEMA,
        "gate_id": "QSDK-R10F",
        "ok": False,
        "failure_code": "QSDK_R10F_L13_WALKING_LEDGER_PREDICATES_FAILED",
        "failed_predicate_ids": ledger_failed_ids,
        "portable_step_receipt": portable,
        "native_step_transport_verification": native_transport,
        "controller_step_receipt": controller,
        "authority_application_receipt": authority_application,
        "motor_population_readback": population_readback,
        "walking_actuation_handoff_receipt": handoff,
        "host_target_projection_receipt": host_projection,
        "walking_ledger_predicate_receipt": predicate_receipt,
        "generic_failure_without_predicate_detail": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    return {
        "schema_version": RAW_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "work_id": work_id_for_family(),
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_process_isolated_child_incomplete_raw"),
        "status": "invalid_or_incomplete_process_isolated_child_development",
        "ok": False,
        "measurement_complete": False,
        "scientific_outcome": "none",
        "role_outcome": "none",
        "failure_code": "QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID",
        "source_commit": source_commit,
        "authorization_sha256": authority_sha256,
        "parent_attempt_id": parent_attempt_id,
        "child_attempt_id": child_attempt_id,
        "attempt_id": child_attempt_id,
        "arm_id": role,
        "process_id": process_id,
        "seed": SEED,
        "seed_sha256": SEED_SHA256,
        "one_arm_per_process": True,
        "one_world_per_process": True,
        "world_or_body_state_imported_from_peer": False,
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "partial_arm": {
            "arm_id": role,
            "model_instance_id": model_instance_id,
            "active_walking_session": session,
            "last_walking_step_failure": failure,
        },
    }


def l9_synthetic_solver_receipts(
    role: str, body_identity: str, solver_steps: int
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    invariants: list[dict[str, Any]] = []
    for step in range(1, solver_steps + 1):
        row = {
            "schema_version": "sporespore_qsdk_r10f_compact_native_trace_row_v1",
            "arm_id": role,
            "global_semantic_step": step,
            "body_population_instance_sha256": body_identity,
            "source_measurement": True,
        }
        projection = {
            "schema_version": (
                "sporespore_qsdk_r10f_collection_solver_counter_projection_v1"
            ),
            "gate_id": "QSDK-R10F",
            "ok": True,
            "global_semantic_step": step,
            "cumulative_solver_step_count": step,
            "retained_global_cumulative_solver_step_count": step,
            "completed_step_delta": 1,
            "source_counter_semantics": (
                "cumulative_completed_global_solver_step_sequence"
            ),
            "aggregate_counter_semantics": "one_delta_per_accepted_arm_collection",
            "retained_global_collector_unchanged": True,
            "source_measurement": True,
            "outcome_derived_correction": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        predicates = {
            "collector_cumulative_solver_step_exact": True,
            "collector_global_counter_binding_exact": True,
            "accepted_collection_step_delta_exact": True,
            "collector_counter_outcome_correction_zero": True,
        }
        invariant = {
            "schema_version": "sporespore_qsdk_r10f_in_run_native_invariant_v1",
            "arm_id": role,
            "global_semantic_step": step,
            "body_population_instance_sha256": body_identity,
            "solver_counter_projection": projection,
            "predicates": predicates,
            "all_in_run_physical_invariants_passed": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        rows.append(row)
        invariants.append(invariant)
    return rows, invariants


def l9_synthetic_child_report(
    role: str,
    parent_attempt_id: str,
    child_attempt_id: str,
    source_commit: str,
    authority_sha256: str,
    process_id: int,
    *,
    outcome: str = "positive",
) -> dict[str, Any]:
    require(
        outcome in {"positive", "behavior_negative", "precondition_negative"},
        "L9_SYNTHETIC_OUTCOME",
    )
    solver_steps = 6
    precondition_negative = outcome == "precondition_negative"
    active = role == ACTIVE_ARM
    model_id = f"synthetic-model-{role}"
    body_identity = "sha256:" + ("b" if active else "a") * 64
    phase = "failed" if precondition_negative else "complete"
    failure_source = "phase_timeout:stance_dwell" if precondition_negative else None
    failure_projection = failure_source if precondition_negative else ""
    classification = {"stable_stance_gate": not precondition_negative}
    memory = {
        "phase": phase,
        "terminal_failure_code": failure_source,
        "last_semantic_step": 1,
    }
    step_receipt = {
        "memory": copy.deepcopy(memory),
        "classification": copy.deepcopy(classification),
        "next_phase": phase,
    }
    terminal = {
        "schema_version": PRECONDITION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": CHILD_CONTRACT_REPAIR_ID,
        "parent_attempt_id": parent_attempt_id,
        "child_attempt_id": child_attempt_id,
        "arm_id": role,
        "model_instance_id": model_id,
        "completed_global_semantic_step": 1,
        "disposition": (
            "failed_source_retained"
            if precondition_negative
            else "complete_source_retained"
        ),
        "recovery_controller_id": RECOVERY_CONTROLLER_ID,
        "recovery_terminal_phase": phase,
        "recovery_terminal_failure_code": failure_projection,
        "recovery_memory": memory,
        "recovery_memory_sha256": canonical_sha256_v1(memory),
        "recovery_step_receipt": step_receipt,
        "recovery_step_receipt_sha256": canonical_sha256_v1(step_receipt),
        "recovery_classification": classification,
        "recovery_classification_sha256": canonical_sha256_v1(classification),
        "stable_four_foot_stance": not precondition_negative,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "solver_reset_count": 0,
        "source_measurement": True,
        "outcome_derived_correction": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "payload_sha256": "",
    }
    terminal["payload_sha256"] = payload_sha256_v1(terminal)
    release: dict[str, Any] = {}
    if not precondition_negative:
        configured_rows = [
            {
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0.0,
            }
            for joint_id in JOINT_IDS
        ]
        native_rows = [
            {
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0.0,
                "motor_maximum_impulse_nms": 0.1,
            }
            for joint_id in JOINT_IDS
        ]
        configuration_receipt = {
            "ok": True,
            "global_semantic_step": 2,
            "motor_enabled": False,
            "ordered_joint_receipts": configured_rows,
        }
        population_readback = {
            "ok": True,
            "global_semantic_step": 2,
            "expected_motor_enabled": False,
            "motor_enabled_count": 0,
            "zero_target_velocity_count": len(JOINT_IDS),
            "native_readback_count": len(JOINT_IDS) * 3,
            "ordered_joint_readbacks": native_rows,
        }
        release_owner_source = l11_release_owner_source_projection(terminal)
        ledger = {
            "ok": True,
            "semantic_step": 2,
            "no_actuation_requested": True,
            "controller_owner": "none",
            "owner_source_receipt": copy.deepcopy(release_owner_source),
            "owner_source_receipt_sha256": canonical_sha256_v1(
                release_owner_source
            ),
            "motor_population_readback": copy.deepcopy(population_readback),
        }
        release = {
            "schema_version": RELEASE_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": RELEASE_REPAIR_ID,
            "parent_attempt_id": parent_attempt_id,
            "child_attempt_id": child_attempt_id,
            "arm_id": role,
            "model_instance_id": model_id,
            "global_semantic_step": 2,
            "action_kind": "process_isolated_no_actuation_release",
            "precondition_terminal_receipt": copy.deepcopy(terminal),
            "precondition_terminal_receipt_sha256": terminal["payload_sha256"],
            "motor_configuration_receipt": configuration_receipt,
            "motor_configuration_receipt_sha256": canonical_sha256_v1(
                configuration_receipt
            ),
            "motor_population_readback": population_readback,
            "motor_population_readback_sha256": canonical_sha256_v1(
                population_readback
            ),
            "ledger_application_intent": ledger,
            "ledger_application_intent_sha256": canonical_sha256_v1(ledger),
            "ordered_motor_readbacks": configured_rows,
            "control_owner": "none",
            "actuation_owner": "none",
            "no_actuation_requested": True,
            "source_measurement": True,
            "outcome_derived_correction": False,
            "body_transform_write_count": 0,
            "body_velocity_write_count": 0,
            "solver_reset_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "payload_sha256": "",
        }
        release["payload_sha256"] = payload_sha256_v1(release)
    sessions: list[dict[str, Any]] = []
    if not precondition_negative:
        sessions.append(
            l9_synthetic_walking_session(
                role,
                "walking_prefix",
                True,
                model_id,
                2,
            )
        )
        if active:
            sessions.append(
                l9_synthetic_walking_session(
                    role,
                    "walking_resume",
                    outcome != "behavior_negative",
                    model_id,
                    4,
                )
            )
        else:
            sessions.append(
                l9_synthetic_walking_session(
                    role,
                    "matched_continuation",
                    True,
                    model_id,
                    4,
                )
            )
    walking_handoffs = [
        l12_synthetic_walking_handoff(
            model_id,
            str(session["evaluation_segment_id"]),
            str(session["session_id"]),
            3 if index == 0 else 5,
        )
        for index, session in enumerate(sessions)
    ]
    interaction: dict[str, Any] = {}
    if not precondition_negative:
        before = [0.1, 0.0, -0.01]
        delta = [0.0, 0.0, 0.02] if active else [0.0, 0.0, 0.001]
        after = [before[index] + delta[index] for index in range(3)]
        prefix = sessions[0]["start_receipt"]
        interaction = {
            "schema_version": INTERACTION_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": CHILD_CONTRACT_REPAIR_ID,
            "parent_attempt_id": parent_attempt_id,
            "child_attempt_id": child_attempt_id,
            "arm_id": role,
            "model_instance_id": model_id,
            "completed_effect_global_step": 4,
            "interaction_local_step": 1,
            "prefix_session_id": prefix["session_id"],
            "prefix_session_receipt_sha256": canonical_sha256_v1(prefix),
            "task_frame_forward_axis_world_host_real": [1.0, 0.0, 0.0],
            "task_frame_lateral_axis_world_host_real": [0.0, 0.0, 1.0],
            "scheduled_impulse_world_n_s": (
                [0.0, 0.0, KICK_IMPULSE_MAGNITUDE_N_S]
                if active
                else [0.0, 0.0, 0.0]
            ),
            "pre_event_velocity_world_m_s": before,
            "completed_effect_velocity_world_m_s": after,
            "raw_velocity_delta_world_m_s": delta,
            "raw_velocity_delta_magnitude_m_s": vector_norm(tuple(delta)),
            "application_count": 1 if active else 0,
            "source_measurement": True,
            "outcome_derived_correction": False,
            "global_step_rewritten_for_pair_alignment": False,
            "force_aware_recovery_used": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "payload_sha256": "",
        }
        interaction["payload_sha256"] = payload_sha256_v1(interaction)
    rows, invariants = l9_synthetic_solver_receipts(role, body_identity, solver_steps)
    trace = {
        "schema_version": TRACE_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "parent_attempt_id": parent_attempt_id,
        "child_attempt_id": child_attempt_id,
        "arm_id": role,
        "model_instance_id": model_id,
        "body_population_instance_sha256": body_identity,
        "rows": rows,
    }
    role_outcome = (
        "precondition_negative"
        if precondition_negative
        else (
            "matched_reference_complete"
            if not active
            else (
                "behavior_negative"
                if outcome == "behavior_negative"
                else "behavior_positive"
            )
        )
    )
    arm = {
        "schema_version": ARM_RESULT_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ok": True,
        "parent_attempt_id": parent_attempt_id,
        "child_attempt_id": child_attempt_id,
        "arm_id": role,
        "model_instance_id": model_id,
        "body_population_instance_sha256": body_identity,
        "initial_same_body_identity_receipt": {
            "body_population_instance_sha256": body_identity
        },
        "terminal_same_body_identity_receipt": {
            "body_population_instance_sha256": body_identity
        },
        "same_body_identity_preserved": True,
        "initial_application_validation_receipt": l9_synthetic_initial_application(),
        "precondition_terminal_receipt": copy.deepcopy(terminal),
        "precondition_terminal_receipt_sha256": terminal["payload_sha256"],
        "precondition_release_receipt": copy.deepcopy(release),
        "precondition_release_receipt_sha256": (
            release.get("payload_sha256", "")
        ),
        "precondition_release_receipt_valid": not precondition_negative,
        "walking_sessions": sessions,
        "walking_actuation_handoff_receipts": walking_handoffs,
        "interaction_source": copy.deepcopy(interaction),
        "trace": trace,
        "trace_sha256": canonical_sha256_v1(trace),
        "outer_step_count": solver_steps,
        "native_solver_step_count": solver_steps,
        "in_run_invariant_receipts": invariants,
        "in_run_invariant_receipt_count": solver_steps,
        "all_in_run_physical_invariants_passed": True,
        "final_phase": phase,
        "terminal_reason": failure_projection,
        "external_kick_application_count": (
            1 if active and not precondition_negative else 0
        ),
        "body_population_rebuild_count": 0,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "solver_reset_count": 0,
        "global_step_values_rewritten_for_pair_alignment": False,
        "full_trace_retained": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    configuration = {
        "ok": True,
        "gate_id": "QSDK-R10F",
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_SHA256,
        "recovery_morphology_spec_sha256": RECOVERY_MORPHOLOGY_SHA256,
        "actuator_profile_id": ACTUATOR_PROFILE_ID,
        "actuator_profile_sha256": "sha256:" + "1" * 64,
        "material_profile_id": MATERIAL_PROFILE_ID,
        "material_profile_sha256": "sha256:" + "2" * 64,
        "recovery_context_sha256": "sha256:" + "3" * 64,
        "post_construction_transform_write_permitted": False,
        "post_construction_velocity_write_permitted": False,
        "solver_reset_permitted": False,
        "event_triggered_passive_recovery": True,
        "force_aware_recovery": False,
    }
    observed = role_outcome == "behavior_positive"
    return {
        "schema_version": RAW_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "work_id": work_id_for_family(),
        "question_class": "development",
        "ledger_scope": ledger_scope(
            "consumed_process_isolated_child_physical_development_raw"
        ),
        "status": "valid_complete_process_isolated_child_development",
        "ok": True,
        "measurement_complete": True,
        "scientific_outcome": "none",
        "role_outcome": role_outcome,
        "source_commit": source_commit,
        "authorization_sha256": authority_sha256,
        "parent_attempt_id": parent_attempt_id,
        "child_attempt_id": child_attempt_id,
        "attempt_id": child_attempt_id,
        "arm_id": role,
        "process_id": process_id,
        "seed": SEED,
        "seed_label": "QSDK-R10F/development/godot/event-triggered-passive-recovery-v1",
        "seed_sha256": SEED_SHA256,
        "actuator_mode": "solver_coupled_native_constraint_motor_v1",
        "recovery_controller_id": RECOVERY_CONTROLLER_ID,
        "energy_route_id": "synthetic-qualified-energy-route",
        "physics_ticks_per_second": 120,
        "held_out": False,
        "held_out_cell_access_count": 0,
        "population_inference_claimed": False,
        "one_arm_per_process": True,
        "one_world_per_process": True,
        "world_or_body_state_imported_from_peer": False,
        "configuration": configuration,
        "configuration_sha256": canonical_sha256_v1(configuration),
        "precondition_terminal_receipt": terminal,
        "precondition_terminal_receipt_sha256": terminal["payload_sha256"],
        "precondition_release_receipt": release,
        "precondition_release_receipt_sha256": release.get("payload_sha256", ""),
        "interaction_source": interaction,
        "interaction_source_sha256": interaction.get("payload_sha256", ""),
        "arm_result": arm,
        "reached_walking_prefix": not precondition_negative,
        "reached_interaction": not precondition_negative,
        "reached_post_kick_recovery": active and not precondition_negative,
        "reached_walking_resume": active and not precondition_negative,
        "behavior_evaluator_invocation_count": 0,
        "complete_trace_count": 1,
        "in_run_invariant_receipt_count": solver_steps,
        "all_in_run_physical_invariants_passed": True,
        "same_body_identity_preserved": True,
        "model_construction_attempt_count": 1,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": solver_steps,
        "maximum_solver_step_count": 3842,
        "global_solver_frame_count": solver_steps,
        "external_kick_application_count": (
            1 if active and not precondition_negative else 0
        ),
        "explicit_worker_extra_native_readback_count": 0,
        "physical_question_opened": True,
        "physics_state_modified": True,
        "event_triggered_passive_recovery_observed": observed,
        "recovery_success_observed": observed,
        "prone_to_standing_claimed": False,
        "kick_impulse_alone_causes_fall_claimed": False,
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "arbitrary_fall_recovery_claimed": False,
        "cross_engine_push_recovery_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l9_synthetic_population(
    envelopes: list[dict[str, Any]],
    parent_attempt_id: str,
    source_commit: str,
    authority_sha256: str,
) -> dict[str, Any]:
    projections: list[dict[str, Any]] = []
    errors: list[str] = []
    for index, envelope in enumerate(envelopes):
        try:
            projection = validate_l9_child_report(
                envelope["report"],
                expected_role=ARM_ORDER[index],
                expected_parent_attempt_id=parent_attempt_id,
                expected_child_attempt_id=envelope["child_attempt_id"],
                expected_source_commit=source_commit,
                expected_authority_sha256=authority_sha256,
                expected_worker_process_id=envelope["worker_process_id"],
            )
            projections.append(projection)
        except ClosureFailure as exc:
            errors.append(f"CHILD_{index}:{exc}")
    if len(envelopes) != 2:
        errors.append(f"ORDERED_CHILD_COUNT_INVALID:{len(envelopes)}")
    if errors or len(projections) != 2:
        return {
            "schema_version": POPULATION_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": REPAIR_ID,
            "ok": False,
            "status": "invalid_or_incomplete_process_population",
            "evidence_valid": False,
            "measurement_complete": False,
            "route_execution_valid": False,
            "outcome_complete": False,
            "behavior_passed": False,
            "scientific_outcome": "none",
            "failure_code": "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED",
            "population_validation_errors": errors,
            "child_validations": [],
            "ordered_child_count": len(envelopes),
            "process_lifetimes_overlap": None,
            "evaluator_invocation_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    pair_projection = validate_l9_pair_from_children(projections[0], projections[1])
    pair: dict[str, Any] = {
        "schema_version": PAIR_EVALUATION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ok": pair_projection["ok"],
        "status": pair_projection["status"],
        "evidence_valid": pair_projection["evidence_valid"],
        "measurement_complete": pair_projection["measurement_complete"],
        "route_execution_valid": pair_projection["route_execution_valid"],
        "outcome_complete": pair_projection["outcome_complete"],
        "behavior_passed": pair_projection["behavior_passed"],
        "scientific_outcome": pair_projection["scientific_outcome"],
        "failure_code": pair_projection["failure_code"],
        "evaluator_invocation_count": 1,
        "pair_alignment_basis": "phase_local_receipts_and_walking_session_local_steps",
        "global_solver_step_values_rewritten_for_pair_alignment": False,
        "trace_truncation_used_for_pair_alignment": False,
        "force_aware_recovery": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if pair_projection["route_execution_valid"]:
        pair.update(
            {
                "pair_source_predicates": {"synthetic_all_independently_checked": True},
                "failed_pair_source_predicates": [],
                "computed_measurements": pair_projection["computed_measurements"],
                "route_receipts": {
                    "both_children_independently_validated": True,
                    "both_preconditions_complete": True,
                    "active_one_native_kick_retained": True,
                    "baseline_zero_kick_retained": True,
                    "paired_native_effect_meets_frozen_floor": True,
                    "full_child_traces_retained": True,
                    "phase_local_alignment_only": True,
                    "global_step_rewriting_absent": True,
                    "trace_truncation_absent": True,
                },
                "outcome_derived_correction": False,
            }
        )
    else:
        pair["precondition_negative_roles"] = pair_projection[
            "precondition_negative_roles"
        ]
    total_steps = sum(int(value["solver_step_count"]) for value in projections)
    return {
        "schema_version": POPULATION_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ok": pair_projection["ok"],
        "status": pair_projection["status"],
        "evidence_valid": pair_projection["evidence_valid"],
        "measurement_complete": pair_projection["measurement_complete"],
        "route_execution_valid": pair_projection["route_execution_valid"],
        "outcome_complete": pair_projection["outcome_complete"],
        "behavior_passed": pair_projection["behavior_passed"],
        "scientific_outcome": pair_projection["scientific_outcome"],
        "failure_code": pair_projection["failure_code"],
        "population_validation_errors": [],
        "child_validations": [
            {
                "ok": True,
                "role": value["role"],
                "disposition": value["disposition"],
                "solver_step_count": value["solver_step_count"],
                "walking_actuation_handoff_count": value[
                    "walking_actuation_handoffs"
                ]["handoff_count"],
                "no_resume_terminal": copy.deepcopy(value["no_resume_terminal"]),
                "validation_errors": [],
            }
            for value in projections
        ],
        "ordered_child_count": 2,
        "ordered_child_roles": ARM_ORDER,
        "child_attempt_ids": [value["child_attempt_id"] for value in envelopes],
        "child_process_ids": [value["process_id"] for value in envelopes],
        "child_evidence_paths": [value["evidence_path"] for value in envelopes],
        "process_lifetimes_overlap": False,
        "serialized_fresh_processes_valid": True,
        "all_declared_children_present": True,
        "child_retry_or_replacement_used": False,
        "evaluator_invocation_count": 1,
        "pair_evaluation": pair,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": total_steps,
        "maximum_solver_step_count": 7684,
        "physics_state_modified": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l9_synthetic_supervisor(case: str) -> dict[str, Any]:
    require(
        case
        in {
            "behavior_positive",
            "behavior_negative",
            "precondition_negative",
            "missing_active_child",
            "invalid_active_child",
        },
        "L9_SYNTHETIC_CASE",
    )
    parent = "0123456789abcdef0123456789abcdef"
    source = "0123456789abcdef0123456789abcdef01234567"
    authority = "sha256:" + "9" * 64
    child_ids = ["1" * 32, "2" * 32]
    nonces = ["3" * 32, "4" * 32]
    paths = [
        f"C:/synthetic/children/01-{BASELINE_ARM}",
        f"C:/synthetic/children/02-{ACTIVE_ARM}",
    ]
    descriptors = [
        {
            "launch_index": index + 1,
            "role": role,
            "child_attempt_id": child_ids[index],
            "termination_nonce": nonces[index],
            "evidence_path": paths[index],
            "child_retry_count": 0,
            "child_replacement_count": 0,
        }
        for index, role in enumerate(ARM_ORDER)
    ]
    active_outcome = (
        "behavior_negative" if case == "behavior_negative" else "positive"
    )
    baseline_outcome = "precondition_negative" if case == "precondition_negative" else "positive"
    reports = [
        l9_synthetic_child_report(
            BASELINE_ARM,
            parent,
            child_ids[0],
            source,
            authority,
            1101,
            outcome=baseline_outcome,
        ),
        l9_synthetic_child_report(
            ACTIVE_ARM,
            parent,
            child_ids[1],
            source,
            authority,
            1102,
            outcome=active_outcome,
        ),
    ]
    if case == "invalid_active_child":
        reports[1]["configuration_sha256"] = "sha256:" + "f" * 64
    envelopes = [
        {
            "role": role,
            "child_attempt_id": child_ids[index],
            "termination_nonce": nonces[index],
            "evidence_path": paths[index],
            "child_retry_count": 0,
            "child_replacement_count": 0,
            "started_utc": f"2026-01-01T00:00:0{index * 2}+00:00",
            "completed_utc": f"2026-01-01T00:00:0{index * 2 + 1}+00:00",
            "process_id": 1101 + index,
            "worker_process_id": 1101 + index,
            "exit_code": 0,
            "termination_protocol_valid": True,
            "engine_health_passed": True,
            "raw_marker_valid": True,
            "report": reports[index],
            "retained_artifact_bindings": {},
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        for index, role in enumerate(ARM_ORDER)
    ]
    if case == "missing_active_child":
        envelopes = envelopes[:1]
    population = l9_synthetic_population(envelopes, parent, source, authority)
    counts = l9_observed_counter_projection(envelopes)
    population_ok = bool(population["ok"])
    return {
        "schema_version": SUPERVISOR_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "campaign_id": CAMPAIGN_ID,
        "campaign_role": "development_route_ghost",
        "question_class": "development",
        "ledger_scope": ledger_scope("consumed_physical_campaign_report"),
        "ok": population_ok,
        "status": population["status"],
        "evidence_valid": population["evidence_valid"],
        "measurement_complete": population["measurement_complete"],
        "route_execution_valid": population["route_execution_valid"],
        "outcome_complete": population["outcome_complete"],
        "behavior_passed": population["behavior_passed"],
        "scientific_outcome": population["scientific_outcome"],
        "failure_code": population["failure_code"],
        "source_commit": source,
        "authority_sha256": authority,
        "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "branch_completeness_addendum_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "consumed_predecessor_physical_closure_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "attempt_id": parent,
        "attempt_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "maximum_campaign_attempt_count": 1,
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_total_world_count": 2,
        "maximum_solver_step_count_per_child": 3842,
        "maximum_total_solver_step_count": 7684,
        "ordered_child_manifest": descriptors,
        "ordered_child_count": len(envelopes),
        "all_declared_children_present": len(envelopes) == 2,
        "child_processes_overlap_in_wall_clock_time": population.get(
            "process_lifetimes_overlap"
        ),
        "serialized_fresh_processes_valid": bool(
            population.get("serialized_fresh_processes_valid", False)
        ),
        "child_retry_or_replacement_used": bool(
            population.get("child_retry_or_replacement_used", False)
        ),
        "evaluator_invocation_count": population["evaluator_invocation_count"],
        "process_population_evaluation": population,
        "child_envelopes": envelopes,
        "observed_completed_child_count_fields_known": counts["core_known"],
        "observed_count_field_known": counts["known"],
        "model_construction_attempt_count": counts[
            "model_construction_attempt_count"
        ],
        "model_construction_count": counts["model_construction_count"],
        "world_attempt_count": counts["world_attempt_count"],
        "world_build_count": counts["world_build_count"],
        "solver_step_count": counts["solver_step_count"],
        "explicit_worker_extra_native_readback_count": counts[
            "explicit_worker_extra_native_readback_count"
        ],
        "physical_question_opened": True,
        "physics_state_modified": counts["physics_state_modified"],
        "event_triggered_passive_recovery_observed": (
            population_ok and bool(population["behavior_passed"])
        ),
        "continuous_same_body_recovery_resume_observed": (
            population_ok and bool(population["behavior_passed"])
        ),
        "force_aware_recovery": False,
        "force_aware_bracing": False,
        "arbitrary_fall_recovery_claimed": False,
        "cross_engine_push_recovery_claimed": False,
        "sdk1_m07_satisfied": False,
        "operation_lock": {},
        "evidence_root": "C:/synthetic",
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l9_set_path(value: Any, path: tuple[Any, ...], replacement: Any) -> None:
    target = value
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = replacement


def l9_synthetic_artifact_reopening_self_test() -> tuple[int, int]:
    fixture = l9_synthetic_supervisor("behavior_positive")
    descriptor = copy.deepcopy(fixture["ordered_child_manifest"][0])
    envelope = copy.deepcopy(fixture["child_envelopes"][0])
    with tempfile.TemporaryDirectory(prefix="sporespore-r10f-l9-closure-") as temp:
        child_root = Path(temp).resolve()
        descriptor["evidence_path"] = child_root.as_posix()
        envelope["evidence_path"] = child_root.as_posix()
        child_identity = {
            "schema_version": CHILD_ATTEMPT_SCHEMA,
            "gate_id": "QSDK-R10F",
            "repair_id": REPAIR_ID,
            "status": "reserved_and_retained_before_first_child_start",
            "parent_attempt_id": envelope["report"]["parent_attempt_id"],
            "child_attempt_id": descriptor["child_attempt_id"],
            "launch_index": descriptor["launch_index"],
            "role": descriptor["role"],
            "termination_nonce": descriptor["termination_nonce"],
            "evidence_path": child_root.as_posix(),
            "source_commit": envelope["report"]["source_commit"],
            "authority_sha256": envelope["report"]["authorization_sha256"],
            "child_retry_count": 0,
            "child_replacement_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        ready = {
            "schema_version": "sporespore_godot_supervised_termination_ready_v1",
            "termination_protocol_id": "godot_4_7_gdscript_shutdown_containment_v1",
            "termination_nonce": descriptor["termination_nonce"],
            "process_id": envelope["worker_process_id"],
            "worker_receipt_emitted": True,
            "requested_exit_code": 0,
        }
        raw_line = RAW_MARKER + json.dumps(
            envelope["report"], sort_keys=True, separators=(",", ":")
        )
        ready_line = READY_MARKER + json.dumps(
            ready, sort_keys=True, separators=(",", ":")
        )
        stdout = raw_line + "\n" + ready_line + "\n"
        stderr = ""
        termination = {
            "exit_code": 0,
            "timed_out": False,
            "stdout": stdout,
            "stderr": stderr,
            "started_utc": envelope["started_utc"],
            "completed_utc": envelope["completed_utc"],
            "process_id": envelope["process_id"],
            "worker_process_id": envelope["worker_process_id"],
            "supervisor_terminated": True,
            "termination_protocol_valid": True,
            "termination_protocol_failure_code": "",
            "termination_ready_receipt": ready,
        }
        health = project_l9_engine_health(stderr)

        def write_json_file(path: Path, value: Any) -> None:
            path.write_bytes(
                (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode(
                    "utf-8"
                )
            )

        child_identity_path = child_root / "child_attempt_identity.json"
        stdout_path = child_root / "worker.stdout.txt"
        stderr_path = child_root / "worker.stderr.txt"
        termination_path = child_root / "termination_receipt.json"
        health_path = child_root / "engine_health.json"
        worker_report_path = child_root / "worker_report.json"
        envelope_path = child_root / "child_envelope.json"
        write_json_file(child_identity_path, child_identity)
        stdout_path.write_bytes(stdout.encode("utf-8"))
        stderr_path.write_bytes(stderr.encode("utf-8"))
        write_json_file(termination_path, termination)
        write_json_file(health_path, health)
        write_json_file(worker_report_path, envelope["report"])
        envelope["retained_artifact_bindings"] = {
            "child_attempt_identity": file_identity(child_identity_path),
            "worker_stdout": file_identity(stdout_path),
            "worker_stderr": file_identity(stderr_path),
            "termination_receipt": file_identity(termination_path),
            "engine_health": file_identity(health_path),
            "worker_report": file_identity(worker_report_path),
        }
        write_json_file(envelope_path, envelope)
        retained = validate_l9_child_artifact_files(
            envelope, descriptor, child_root=child_root
        )
        require(
            isinstance(retained.get("bindings"), dict)
            and retained["bindings"].get("worker_report")
            == file_identity(worker_report_path),
            "L9_ARTIFACT_REOPENING_POSITIVE",
        )
        rejected = 0
        original_worker_report = worker_report_path.read_bytes()
        worker_report_path.write_bytes(original_worker_report + b" ")
        try:
            validate_l9_child_artifact_files(
                envelope, descriptor, child_root=child_root
            )
        except ClosureFailure:
            rejected += 1
        worker_report_path.write_bytes(original_worker_report)
        original_envelope = envelope_path.read_bytes()
        changed_envelope = copy.deepcopy(envelope)
        changed_envelope["physical_acceptance_authority"] = True
        write_json_file(envelope_path, changed_envelope)
        try:
            validate_l9_child_artifact_files(
                envelope, descriptor, child_root=child_root
            )
        except ClosureFailure:
            rejected += 1
        envelope_path.write_bytes(original_envelope)
        require(rejected == 2, "L9_ARTIFACT_REOPENING_MUTATIONS")
    return 1, 2


def l9_self_test() -> dict[str, Any]:
    cases = [
        "behavior_positive",
        "behavior_negative",
        "precondition_negative",
        "missing_active_child",
        "invalid_active_child",
    ]
    fixtures = [l9_synthetic_supervisor(case) for case in cases]
    outcomes = [
        validate_l9_report(value, report_path=None, verify_files=False)
        for value in fixtures
    ]
    expected_classifications = [
        "valid_complete_behavior_positive",
        "valid_complete_behavior_development_negative",
        "invalid_or_incomplete_no_behavioral_conclusion",
        "invalid_or_incomplete_no_behavioral_conclusion",
        "invalid_or_incomplete_no_behavioral_conclusion",
    ]
    require(
        [value["classification"] for value in outcomes] == expected_classifications,
        "L9_SELF_TEST_CLASSIFICATIONS",
    )
    numeric_positive = (
        (1, 1, 1),
        (3842, 3842, 3842),
        (1.0, 1.0, 1),
        (3842.0, 3842.0, 3842),
    )
    require(
        all(integer_valued_native_step_matches(*values) for values in numeric_positive),
        "L9_SELF_TEST_INTEGER_POSITIVES",
    )
    numeric_negative = (
        (True, True, 1),
        ("1", "1", 1),
        (None, None, 1),
        (0, 0, 1),
        (3843, 3843, 3842),
        (1.5, 1.5, 1),
        (float("nan"), float("nan"), 1),
        (float("inf"), float("inf"), 1),
        (1, 1.0, 1),
        (1.0, 1, 1),
        (2, 2, 1),
        (2.0, 2.0, 1),
        (1, 1, True),
        (1, 1, 0),
        (1, 1, 3843),
    )
    numeric_rejections = sum(
        not integer_valued_native_step_matches(*values) for values in numeric_negative
    )
    require(numeric_rejections == 15, "L9_SELF_TEST_INTEGER_REJECTIONS")
    nullable_positive = (
        ({"phase": "complete", "terminal_failure_code": None}, "complete", ""),
        (
            {"phase": "failed", "terminal_failure_code": "phase_timeout:stance_dwell"},
            "failed",
            "phase_timeout:stance_dwell",
        ),
        (
            {"phase": "refused", "terminal_failure_code": "invalid_observation"},
            "refused",
            "invalid_observation",
        ),
    )
    require(
        all(nullable_terminal_failure_code_matches(*values) for values in nullable_positive),
        "L10_SELF_TEST_NULLABLE_POSITIVES",
    )
    nullable_negative = (
        ({"phase": "complete", "terminal_failure_code": ""}, "complete", ""),
        ({"phase": "complete", "terminal_failure_code": "invented"}, "complete", ""),
        ({"phase": "failed", "terminal_failure_code": None}, "failed", ""),
        ({"phase": "failed", "terminal_failure_code": ""}, "failed", ""),
        ({"phase": "refused", "terminal_failure_code": None}, "refused", ""),
        ({"phase": "refused", "terminal_failure_code": ""}, "refused", ""),
        ({"phase": "failed", "terminal_failure_code": True}, "failed", "True"),
        ({"phase": "failed", "terminal_failure_code": 7}, "failed", "7"),
        ({"phase": "failed", "terminal_failure_code": 7.0}, "failed", "7.0"),
        ({"phase": "failed", "terminal_failure_code": ["failure"]}, "failed", "failure"),
        ({"phase": "failed", "terminal_failure_code": {"failure": True}}, "failed", "failure"),
        ({"phase": "complete"}, "complete", ""),
        ({"phase": "complete", "terminal_failure_code": None}, "failed", ""),
        ({"phase": "complete", "terminal_failure_code": None}, "complete", "invented"),
    )
    nullable_unit_rejections = sum(
        not nullable_terminal_failure_code_matches(*values) for values in nullable_negative
    )
    require(nullable_unit_rejections == 14, "L10_SELF_TEST_NULLABLE_UNIT_REJECTIONS")
    baseline_terminal = copy.deepcopy(
        fixtures[0]["child_envelopes"][0]["report"]["precondition_terminal_receipt"]
    )
    nullable_receipt_rejections = 0
    source_rewrite = copy.deepcopy(baseline_terminal)
    source_rewrite["recovery_memory"]["terminal_failure_code"] = ""
    source_rewrite["recovery_step_receipt"]["memory"] = copy.deepcopy(
        source_rewrite["recovery_memory"]
    )
    source_rewrite["recovery_memory_sha256"] = canonical_sha256_v1(
        source_rewrite["recovery_memory"]
    )
    source_rewrite["recovery_step_receipt_sha256"] = canonical_sha256_v1(
        source_rewrite["recovery_step_receipt"]
    )
    source_rewrite["payload_sha256"] = payload_sha256_v1(source_rewrite)
    for terminal_mutation in (
        source_rewrite,
        {**copy.deepcopy(baseline_terminal), "recovery_memory_sha256": "sha256:" + "0" * 64},
    ):
        terminal_mutation["payload_sha256"] = payload_sha256_v1(terminal_mutation)
        try:
            validate_l9_terminal_receipt(
                terminal_mutation,
                parent_attempt_id="0123456789abcdef0123456789abcdef",
                child_attempt_id="1" * 32,
                role=BASELINE_ARM,
                model_instance_id=f"synthetic-model-{BASELINE_ARM}",
                maximum_step=4,
            )
        except ClosureFailure:
            nullable_receipt_rejections += 1
    require(
        nullable_receipt_rejections == 2,
        "L10_SELF_TEST_NULLABLE_RECEIPT_REJECTIONS",
    )
    nullable_rejections = nullable_unit_rejections + nullable_receipt_rejections
    require(nullable_rejections == 16, "L10_SELF_TEST_NULLABLE_REJECTIONS")
    mutation_specs: tuple[tuple[tuple[Any, ...], Any], ...] = (
        (("repair_id",), "QSDK-R10F-L8"),
        (("authority_sha256",), "sha256:" + "8" * 64),
        (("consumed_predecessor_physical_closure_sha256",), "sha256:" + "8" * 64),
        (("attempt_identity_consumed",), False),
        (("maximum_child_process_count",), 3),
        (("sdk1_m07_satisfied",), True),
        (("force_aware_recovery",), True),
        (("ordered_child_manifest", 0, "role"), ACTIVE_ARM),
        (("ordered_child_manifest", 1, "child_attempt_id"), "1" * 32),
        (("ordered_child_manifest", 0, "child_retry_count"), 1),
        (
            ("ordered_child_manifest", 1, "evidence_path"),
            f"C:/synthetic/children/01-{BASELINE_ARM}",
        ),
        (("child_envelopes", 0, "role"), ACTIVE_ARM),
        (("child_envelopes", 1, "process_id"), 1101),
        (("child_envelopes", 1, "started_utc"), "2026-01-01T00:00:00+00:00"),
        (("child_envelopes", 0, "child_retry_count"), 1),
        (("child_envelopes", 0, "exit_code"), 1),
        (
            ("child_envelopes", 0, "report", "configuration_sha256"),
            "sha256:" + "f" * 64,
        ),
        (
            (
                "child_envelopes",
                0,
                "report",
                "precondition_terminal_receipt",
                "payload_sha256",
            ),
            "sha256:" + "f" * 64,
        ),
        (
            (
                "child_envelopes",
                0,
                "report",
                "precondition_release_receipt",
                "payload_sha256",
            ),
            "sha256:" + "f" * 64,
        ),
        (
            (
                "child_envelopes",
                1,
                "report",
                "arm_result",
                "walking_actuation_handoff_receipts",
            ),
            copy.deepcopy(
                fixtures[0]["child_envelopes"][1]["report"]["arm_result"][
                    "walking_actuation_handoff_receipts"
                ][:1]
            ),
        ),
        (
            (
                "child_envelopes",
                1,
                "report",
                "arm_result",
                "walking_actuation_handoff_receipts",
                0,
                "precommand_motor_population_readback",
                "ordered_joint_readbacks",
                0,
                "motor_enabled",
            ),
            False,
        ),
        (
            (
                "child_envelopes",
                1,
                "report",
                "arm_result",
                "walking_actuation_handoff_receipts",
                0,
                "host_cap_projection_binding",
                "selected_host_cap_by_actuator_id",
                "front_left_hip_motor",
            ),
            HOST_CAPS_NMS[1],
        ),
        (
            (
                "child_envelopes",
                1,
                "report",
                "arm_result",
                "walking_actuation_handoff_receipts",
                1,
                "walking_session_id",
            ),
            str(
                fixtures[0]["child_envelopes"][1]["report"]["arm_result"][
                    "walking_actuation_handoff_receipts"
                ][0]["walking_session_id"]
            ),
        ),
        (
            ("child_envelopes", 0, "report", "arm_result", "trace_sha256"),
            "sha256:" + "f" * 64,
        ),
        (
            (
                "child_envelopes",
                0,
                "report",
                "arm_result",
                "trace",
                "rows",
                0,
                "global_semantic_step",
            ),
            1.0,
        ),
        (
            (
                "child_envelopes",
                0,
                "report",
                "arm_result",
                "in_run_invariant_receipts",
                0,
                "all_in_run_physical_invariants_passed",
            ),
            False,
        ),
        (
            (
                "child_envelopes",
                0,
                "report",
                "arm_result",
                "terminal_same_body_identity_receipt",
                "body_population_instance_sha256",
            ),
            "sha256:" + "f" * 64,
        ),
        (("child_envelopes", 0, "report", "external_kick_application_count"), 1),
        (
            (
                "child_envelopes",
                1,
                "report",
                "interaction_source",
                "payload_sha256",
            ),
            "sha256:" + "f" * 64,
        ),
        (
            (
                "child_envelopes",
                1,
                "report",
                "interaction_source",
                "application_count",
            ),
            2,
        ),
        (("child_envelopes", 1, "report", "force_aware_recovery"), True),
        (("child_envelopes", 1, "report", "role_outcome"), "behavior_negative"),
        (
            (
                "child_envelopes",
                1,
                "report",
                "arm_result",
                "walking_sessions",
                1,
                "evaluation",
                "behavior_passed",
            ),
            False,
        ),
        (("process_population_evaluation", "status"), "forged_positive"),
        (
            (
                "process_population_evaluation",
                "pair_evaluation",
                "computed_measurements",
                "paired_kick_effect_magnitude_m_s",
            ),
            10.0,
        ),
        (("process_population_evaluation", "evaluator_invocation_count"), 2),
        (("solver_step_count",), 7),
        (("scientific_outcome",), "negative"),
        (("all_declared_children_present",), False),
    )
    rejected = 0
    for path, replacement in mutation_specs:
        mutation = copy.deepcopy(fixtures[0])
        l9_set_path(mutation, path, replacement)
        try:
            validate_l9_report(mutation, report_path=None, verify_files=False)
        except ClosureFailure:
            rejected += 1

    def refresh_release_binding(mutation: dict[str, Any], child_index: int = 0) -> None:
        report = mutation["child_envelopes"][child_index]["report"]
        release = report["precondition_release_receipt"]
        ledger = release["ledger_application_intent"]
        owner = ledger["owner_source_receipt"]
        owner["payload_sha256"] = payload_sha256_v1(owner)
        ledger["owner_source_receipt_sha256"] = canonical_sha256_v1(owner)
        release["ledger_application_intent_sha256"] = canonical_sha256_v1(ledger)
        release["payload_sha256"] = payload_sha256_v1(release)
        report["precondition_release_receipt_sha256"] = release["payload_sha256"]
        report["arm_result"]["precondition_release_receipt"] = copy.deepcopy(release)
        report["arm_result"]["precondition_release_receipt_sha256"] = release[
            "payload_sha256"
        ]

    semantic_release_mutations: list[dict[str, Any]] = []
    foreign_owner = copy.deepcopy(fixtures[0])
    foreign_source = foreign_owner["child_envelopes"][0]["report"][
        "precondition_release_receipt"
    ]["ledger_application_intent"]["owner_source_receipt"]
    foreign_source["child_attempt_id"] = "e" * 32
    refresh_release_binding(foreign_owner)
    semantic_release_mutations.append(foreign_owner)

    owner_digest_mismatch = copy.deepcopy(fixtures[0])
    refresh_release_binding(owner_digest_mismatch)
    mismatched_report = owner_digest_mismatch["child_envelopes"][0]["report"]
    mismatched_release = mismatched_report["precondition_release_receipt"]
    mismatched_ledger = mismatched_release["ledger_application_intent"]
    mismatched_ledger["owner_source_receipt_sha256"] = "sha256:" + "9" * 64
    mismatched_release["ledger_application_intent_sha256"] = canonical_sha256_v1(
        mismatched_ledger
    )
    mismatched_release["payload_sha256"] = payload_sha256_v1(mismatched_release)
    mismatched_report["precondition_release_receipt_sha256"] = mismatched_release[
        "payload_sha256"
    ]
    mismatched_report["arm_result"]["precondition_release_receipt"] = copy.deepcopy(
        mismatched_release
    )
    mismatched_report["arm_result"][
        "precondition_release_receipt_sha256"
    ] = mismatched_release["payload_sha256"]
    semantic_release_mutations.append(owner_digest_mismatch)

    injected_outcome = copy.deepcopy(fixtures[0])
    injected_source = injected_outcome["child_envelopes"][0]["report"][
        "precondition_release_receipt"
    ]["ledger_application_intent"]["owner_source_receipt"]
    injected_source["physical_result"] = True
    refresh_release_binding(injected_outcome)
    semantic_release_mutations.append(injected_outcome)

    step_digest_mismatch = copy.deepcopy(fixtures[0])
    step_source = step_digest_mismatch["child_envelopes"][0]["report"][
        "precondition_release_receipt"
    ]["ledger_application_intent"]["owner_source_receipt"]
    step_source["recovery_step_receipt_sha256"] = "sha256:" + "9" * 64
    refresh_release_binding(step_digest_mismatch)
    semantic_release_mutations.append(step_digest_mismatch)

    semantic_release_rejections = 0
    for mutation in semantic_release_mutations:
        try:
            validate_l9_report(mutation, report_path=None, verify_files=False)
        except ClosureFailure:
            semantic_release_rejections += 1
    require(
        rejected == len(mutation_specs) == 39
        and semantic_release_rejections == len(semantic_release_mutations) == 4,
        "L12_SELF_TEST_HANDOFF_AND_RELEASE_MUTATION_REJECTIONS",
    )
    rejected += semantic_release_rejections
    artifact_controls, artifact_rejections = l9_synthetic_artifact_reopening_self_test()
    l13_parent_attempt_id = "7" * 32
    l13_child_attempt_id = "8" * 32
    l13_source_commit = "9" * 40
    l13_authority_sha256 = "sha256:" + "a" * 64
    l13_process_id = 3101
    l13_failure_report = l13_synthetic_partial_walking_failure_report(
        role=BASELINE_ARM,
        parent_attempt_id=l13_parent_attempt_id,
        child_attempt_id=l13_child_attempt_id,
        source_commit=l13_source_commit,
        authority_sha256=l13_authority_sha256,
        process_id=l13_process_id,
    )
    l13_failure_projection = validate_l13_partial_walking_failure_report(
        l13_failure_report,
        expected_role=BASELINE_ARM,
        expected_parent_attempt_id=l13_parent_attempt_id,
        expected_child_attempt_id=l13_child_attempt_id,
        expected_source_commit=l13_source_commit,
        expected_authority_sha256=l13_authority_sha256,
        expected_worker_process_id=l13_process_id,
    )
    require(
        l13_failure_projection.get("walking_ledger_failure_retention_valid") is True
        and exact_int(l13_failure_projection.get("retained_source_count"), 8)
        and exact_int(
            l13_failure_projection.get("walking_session_local_step"), 1
        )
        and l13_failure_projection.get("no_additional_solver_step") is True,
        "L13_SELF_TEST_FAILURE_RETENTION_POSITIVE",
    )
    descriptor = {
        "role": BASELINE_ARM,
        "child_attempt_id": l13_child_attempt_id,
        "termination_nonce": "b" * 32,
        "evidence_path": f"C:/synthetic/children/01-{BASELINE_ARM}",
    }
    envelope = {
        "role": BASELINE_ARM,
        "child_attempt_id": l13_child_attempt_id,
        "termination_nonce": descriptor["termination_nonce"],
        "evidence_path": descriptor["evidence_path"],
        "child_retry_count": 0,
        "child_replacement_count": 0,
        "process_id": 4101,
        "worker_process_id": l13_process_id,
        "exit_code": 1,
        "termination_protocol_valid": True,
        "engine_health_passed": True,
        "raw_marker_valid": True,
        "started_utc": "2026-01-01T00:00:00+00:00",
        "completed_utc": "2026-01-01T00:00:01+00:00",
        "report": l13_failure_report,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    envelope_projection = validate_l9_child_envelope(
        envelope,
        descriptor,
        parent_attempt_id=l13_parent_attempt_id,
        source_commit=l13_source_commit,
        authority_sha256=l13_authority_sha256,
        verify_files=False,
    )
    require(
        envelope_projection.get("child_valid") is False
        and envelope_projection.get("walking_failure_retention")
        == l13_failure_projection,
        "L13_SELF_TEST_CHILD_ENVELOPE_FAILURE_RETENTION",
    )

    retention_mutations: list[dict[str, Any]] = []
    for top_level_key in (
        "active_walking_session",
        "last_walking_step_failure",
    ):
        mutation = copy.deepcopy(l13_failure_report)
        mutation["partial_arm"].pop(top_level_key)
        retention_mutations.append(mutation)
    for session_key in (
        "session_id",
        "start_receipt",
        "walking_actuation_handoff_receipt",
    ):
        mutation = copy.deepcopy(l13_failure_report)
        mutation["partial_arm"]["active_walking_session"].pop(session_key)
        retention_mutations.append(mutation)
    for source_key in (
        "portable_step_receipt",
        "native_step_transport_verification",
        "controller_step_receipt",
        "authority_application_receipt",
        "motor_population_readback",
        "walking_actuation_handoff_receipt",
        "host_target_projection_receipt",
        "walking_ledger_predicate_receipt",
    ):
        mutation = copy.deepcopy(l13_failure_report)
        mutation["partial_arm"]["last_walking_step_failure"].pop(source_key)
        retention_mutations.append(mutation)
    unnamed_failure = copy.deepcopy(l13_failure_report)
    unnamed_failure["partial_arm"]["last_walking_step_failure"][
        "failed_predicate_ids"
    ] = []
    retention_mutations.append(unnamed_failure)
    generic_failure = copy.deepcopy(l13_failure_report)
    generic_failure["partial_arm"]["last_walking_step_failure"][
        "generic_failure_without_predicate_detail"
    ] = True
    retention_mutations.append(generic_failure)
    retention_rejections = 0
    for mutation in retention_mutations:
        try:
            projection = validate_l13_partial_walking_failure_report(
                mutation,
                expected_role=BASELINE_ARM,
                expected_parent_attempt_id=l13_parent_attempt_id,
                expected_child_attempt_id=l13_child_attempt_id,
                expected_source_commit=l13_source_commit,
                expected_authority_sha256=l13_authority_sha256,
                expected_worker_process_id=l13_process_id,
            )
            if projection.get("walking_ledger_failure_retention_valid") is not True:
                retention_rejections += 1
        except ClosureFailure:
            retention_rejections += 1
    require(
        retention_rejections == len(retention_mutations) == 15,
        "L13_SELF_TEST_FAILURE_RETENTION_MUTATIONS",
    )
    return {
        "schema_version": "sporespore_qsdk_r10f_l13_physical_closure_self_test_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": ledger_scope("zero_world_physical_closure_self_test"),
        "ok": True,
        "synthetic_report_control_count": len(fixtures),
        "integer_valued_native_step_positive_control_count": len(numeric_positive),
        "integer_valued_native_step_mutation_rejection_count": numeric_rejections,
        "nullable_terminal_failure_code_positive_control_count": len(nullable_positive),
        "nullable_terminal_failure_code_mutation_rejection_count": nullable_rejections,
        "release_owner_source_mutation_rejection_count": (
            semantic_release_rejections
        ),
        "walking_actuation_handoff_mutation_rejection_count": 4,
        "walking_failure_retention_positive_control_count": 1,
        "walking_failure_retention_mutation_rejection_count": retention_rejections,
        "walking_failure_retention_retained_source_count": 8,
        "walking_ledger_named_predicate_count": int(
            l13_failure_projection["walking_ledger_predicates"]["predicate_count"]
        ),
        "partial_child_envelope_failure_retention_projected": True,
        "process_isolated_report_mutation_rejection_count": rejected,
        "retained_artifact_positive_control_count": artifact_controls,
        "retained_artifact_mutation_rejection_count": artifact_rejections,
        "mutation_rejection_count": (
            numeric_rejections
            + nullable_rejections
            + rejected
            + artifact_rejections
            + retention_rejections
        ),
        "classifications": [value["classification"] for value in outcomes],
        "content_digest_recomputation_enabled": True,
        "retained_child_artifact_reopening_enabled": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--l15", action="store_true")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("self-test")
    audit_parser = subparsers.add_parser("audit-report")
    audit_parser.add_argument("--report", required=True, type=Path)
    compile_parser = subparsers.add_parser("compile")
    compile_parser.add_argument("--report", required=True, type=Path)
    compile_parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    try:
        context_arguments: dict[str, Any] = {}
        if arguments.l15:
            require(arguments.command != "self-test", "L15_USE_COMPLETE_COMPONENT_QUALIFICATION")
            select_l15_production_family()
            binding = read_l15_closure_graph()
            expected = binding["l15_prepared_context_expectation"]
            context_arguments = {
                "expected_l15_collection_identity": expected["collection_identity"],
                "expected_l15_context_binding": expected["raw_capture_binding"],
                "require_l15_launch": True, "require_l15_publication": True,
            }
        if arguments.command == "self-test":
            receipt = l9_self_test()
            marker = SELF_TEST_MARKER
        else:
            report_path = arguments.report.resolve()
            observed_document = read_json(report_path, "SUPERVISOR_REPORT")
            if observed_document.get("schema_version") == SUPERVISOR_SCHEMA:
                normalized_report = observed_document
                outcome = validate_l9_report(
                    normalized_report, report_path=report_path, verify_files=True,
                    **context_arguments,
                )
            elif (
                observed_document.get("schema_version")
                == "sporespore_qsdk_r10f_supervisor_refusal_v1"
                and observed_document.get("physical_attempt_identity_consumed") is True
            ):
                normalized_report, outcome = validate_l9_terminal_supervisor_failure(
                    observed_document, report_path=report_path, **context_arguments,
                )
            else:
                raise ClosureFailure("SUPERVISOR_REPORT_SCHEMA")
            if arguments.command == "audit-report":
                receipt = {
                    "schema_version": "sporespore_qsdk_r10f_physical_report_audit_v1",
                    "gate_id": "QSDK-R10F",
                    "repair_id": REPAIR_ID,
                    "ledger_scope": ledger_scope("zero_world_physical_report_audit"),
                    "ok": True,
                    "report": file_identity(report_path),
                    "outcome": outcome,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "scene_tree_insertion_count": 0,
                    "native_readback_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                }
                marker = AUDIT_MARKER
            else:
                require(
                    arguments.output.resolve() == CLOSURE_PATH.resolve(), "OUTPUT_PATH"
                )
                closure = build_l9_closure(report_path, normalized_report, outcome)
                write_new_json(CLOSURE_PATH, closure)
                receipt = {
                    "schema_version": "sporespore_qsdk_r10f_physical_closure_compilation_v1",
                    "gate_id": "QSDK-R10F",
                    "repair_id": REPAIR_ID,
                    "ledger_scope": ledger_scope("zero_world_closure_compilation"),
                    "ok": True,
                    "classification": outcome["classification"],
                    "output": file_identity(CLOSURE_PATH, relative_to=ROOT),
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "scene_tree_insertion_count": 0,
                    "native_readback_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                }
                marker = COMPILED_MARKER
    except (ClosureFailure, OSError) as exc:
        print(f"QSDK_R10F_PHYSICAL_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1
    print(marker + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
