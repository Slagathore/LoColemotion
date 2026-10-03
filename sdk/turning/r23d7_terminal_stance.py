"""Zero-world schedule and trace canaries for QSDK-R23D7.

R23D7 is the prospective morphology-neutral stance successor to the immutable
R23D6 finite negative. It preserves the turning horizon and outcome gates,
replaces dynamic pose capture with an atomic all-eight-joint neutral target,
constructs no physics model, and grants no physical authority.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
CONTRACT_PATH = ROOT / "r23d7_neutral_stance_preregistration_v1.json"
R23D3_CLOSURE_PATH = ROOT / "r23d3_physical_closure_v1.json"
MUJOCO_RESTORATION_CLOSURE_PATH = (
    SDK_ROOT / "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
)
RAPIER_RESTORATION_CLOSURE_PATH = (
    SDK_ROOT / "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)

SCHEMA_VERSION = "sporespore_qsdk_r23d7_neutral_stance_preregistration_v1"
CAMPAIGN_ID = "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT"
GATE_ID = "QSDK-R23D7"
TRACE_SCHEMA = "sporespore_qsdk_r23d7_turn_neutral_stance_settle_trace_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d7_turn_neutral_stance_settle_trace_row_v1"
REPORT_SCHEMA = "sporespore_qsdk_r23d7_synthetic_cell_projection_v1"
RESTORATION_POLICY_ID = "sporespore_morphology_neutral_stance_bounded_pd_v1"

CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_DURATION_STEPS = 1_200
REFERENCE_RECOVERY_STEPS = 600
REFERENCE_CONTINUATION_STEPS = 592
RESTORATION_STEPS = 540
CONTACT_ACQUISITION_STEPS = 180
CONTACT_HOLD_STEPS = 360
PASSIVE_SETTLE_STEPS = 240
TOTAL_TRACE_STEPS = 3_772
ACTUATOR_COUNT = 8
ACTIVE_STEPS = CONTROLLER_STEPS + RESTORATION_STEPS
EXPECTED_NATIVE_APPLICATION_COUNT = ACTIVE_STEPS * ACTUATOR_COUNT

LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
STAGE_A_ARMS = ("positive_heading", "negative_heading")
STAGE_B_ARMS = ("reference_zero", "positive_heading", "negative_heading")
STAGE_B_ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}

TRACE_ROW_FIELDS = (
    "schema_version",
    "cell_id",
    "trace_step",
    "phase_id",
    "controller_semantic_step",
    "desired_heading_offset_rad",
    "measured_yaw_rad",
    "torso_height_m",
    "torso_tilt_rad",
    "torso_ground_contact",
    "ordered_foot_contacts",
    "actuator_command_count",
    "native_actuation_application_count",
    "zero_actuation",
    "command_composition_mode",
    "restoration_receipt_present",
    "neutral_target_activation_count",
    "maximum_absolute_joint_position_error_rad",
    "maximum_absolute_commanded_joint_velocity_rad_s",
)


class R23D7Error(RuntimeError):
    """The prospective R23D7 declaration or a zero-world projection is invalid."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    arm_id: str
    turn_heading_offset_rad: float


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


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _exact_keys(value: Any, expected: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(expected)


def stage_a_cells() -> list[Cell]:
    return [
        Cell(
            stage_id="mujoco_neutral_stance_screen",
            cell_id=f"mujoco__neutral_stance__{arm_id}",
            engine_id="mujoco",
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for arm_id in STAGE_A_ARMS
    ]


def stage_b_cells() -> list[Cell]:
    return [
        Cell(
            stage_id="three_engine_confirmation",
            cell_id=f"{engine_id}__neutral_stance__{arm_id}",
            engine_id=engine_id,
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for engine_id in STAGE_B_ENGINES
        for arm_id in STAGE_B_ARMS
    ]


def all_cells() -> list[Cell]:
    return stage_a_cells() + stage_b_cells()


def _load_obsolete_r23d4_shaped_contract() -> dict[str, Any]:
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise R23D7Error(f"R23D7_CONTRACT_UNREADABLE:{type(error).__name__}") from error

    lineage = contract.get("lineage", {})
    disclosed = contract.get("disclosed_predecessor_results", {})
    borrowed = contract.get("borrowed_terminal_restoration_authorities", {})
    fixture = contract.get("fixture", {})
    stage_a = contract.get("stage_a_mujoco_terminal_stance_screen", {})
    selector = contract.get("stage_a_selector", {})
    stage_b = contract.get("stage_b_three_engine_confirmation", {})
    schedule = contract.get("command_and_terminal_schedule", {})
    outcomes = contract.get("unchanged_outcome_gates", {})
    restoration = contract.get("terminal_restoration_gates", {})
    trace = contract.get("diagnostic_trace_contract", {})
    transport = contract.get("supervisor_transport_contract", {})
    future = contract.get("future_implementation_requirements", {})
    authorization = contract.get("authorization", {})
    claims = contract.get("claim_boundary", {})

    expected_stage_a_ids = [cell.cell_id for cell in stage_a_cells()]
    expected_stage_b_ids = [cell.cell_id for cell in stage_b_cells()]
    expected_stage_a_arms = [
        {
            "arm_id": arm_id,
            "turn_heading_offset_rad": ARM_OFFSETS[arm_id],
            "expected_yaw_delta_sign": 1 if ARM_OFFSETS[arm_id] > 0.0 else -1,
        }
        for arm_id in STAGE_A_ARMS
    ]
    expected_schedule = {
        "schema_version": "sporespore_qsdk_r23d7_turn_neutral_stance_settle_schedule_v1",
        "turning_controller_semantic_step_count": CONTROLLER_STEPS,
        "turn_start_semantic_step": TURN_START_STEP,
        "turn_duration_steps": TURN_DURATION_STEPS,
        "reference_recovery_duration_steps": REFERENCE_RECOVERY_STEPS,
        "reference_continuation_steps": REFERENCE_CONTINUATION_STEPS,
        "terminal_stance_step_count": RESTORATION_STEPS,
        "maximum_four_contact_acquisition_steps": CONTACT_ACQUISITION_STEPS,
        "required_consecutive_all_four_contact_hold_steps": CONTACT_HOLD_STEPS,
        "passive_settle_step_count": PASSIVE_SETTLE_STEPS,
        "total_traced_step_count": TOTAL_TRACE_STEPS,
        "terminal_restoration_policy_id": RESTORATION_POLICY_ID,
        "missing_limb_desired_foot_velocity_world_m_s": [0.0, -0.02, 0.0],
        "damped_least_squares_lambda_m": 0.04,
        "maximum_absolute_restoration_joint_velocity_rad_s": 0.35,
        "pose_hold_position_gain_per_s": 8.0,
        "pose_hold_rate_damping": 0.65,
        "contacting_limb_target_joint_velocity_mode": (
            "captured_pose_proportional_derivative_velocity_v1"
        ),
        "heading_correction_mode": (
            "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        ),
        "turning_controller_native_applications_per_step": ACTUATOR_COUNT,
        "terminal_restoration_native_applications_per_step": ACTUATOR_COUNT,
        "passive_settle_native_applications_per_step": 0,
        "all_engine_workers_execute_exact_fixed_schedule": True,
        "outcome_accumulators_cover_all_3772_steps": True,
        "passive_settle_is_zero_actuation_but_not_untraced": True,
    }
    expected_outcomes = {
        "maximum_absolute_requested_or_held_steering_fraction": 0.4,
        "minimum_absolute_signed_turn_phase_yaw_delta_rad": 0.01,
        "minimum_final_forward_displacement_m": 0.030123046875,
        "maximum_tilt_rad": 0.6,
        "minimum_torso_height_m": 0.2499708652072946,
        "minimum_contact_cycles_per_limb": 2,
        "zero_torso_ground_contact_required": True,
        "zero_controller_errors_required": True,
        "zero_safe_no_actuation_during_active_phases_required": True,
        "zero_nonfinite_observations_required": True,
        "zero_actuator_application_mismatches_required": True,
        "exact_native_application_count_required": True,
        "maximum_tilt_and_minimum_height_cover_controller_restoration_and_passive_settle": True,
        "numeric_thresholds_unchanged_from_r23d3": True,
    }

    invalid = (
        contract.get("schema_version") != SCHEMA_VERSION
        or contract.get("status")
        != "stage_zero_preregistered_no_workers_no_physical_authorization"
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("release_gate_id") != "QSDK-R23"
        or lineage.get("predecessor_id") != "QSDK-R23D3"
        or lineage.get("predecessor_identity_reused") is not False
        or lineage.get("predecessor_world_rerun_permitted") is not False
        or lineage.get("terminal_restoration_policy_added") is not True
        or lineage.get("outcome_numeric_thresholds_changed") is not False
        or lineage.get("passive_terminal_challenge_removed_or_reclassified")
        is not False
        or lineage.get("outcome_measurement_horizon_expanded_to_include_restoration")
        is not True
        or lineage.get("predecessor_closure_raw_sha256")
        != "sha256:d4e0e1370191aa9cac923d2ec74f0d1679653f307119eaaa56785d55bbf379ab"
        or _raw_sha256(R23D3_CLOSURE_PATH)
        != lineage.get("predecessor_closure_raw_sha256")
        or disclosed.get("stage_a_classification") != "valid_none_stage_a"
        or disclosed.get("stage_a_terminal_entry_count") != 8
        or disclosed.get("positive_heading_outcome_pass_count") != 4
        or disclosed.get("negative_heading_signed_yaw_pass_count") != 4
        or disclosed.get("negative_heading_outcome_pass_count") != 0
        or disclosed.get("threshold_crossing_localized_to_untraced_passive_settle")
        is not True
        or disclosed.get("unique_controller_cause_established") is not False
        or disclosed.get("fixed_onset_choice") != "onset_600"
        or disclosed.get(
            "fixed_onset_choice_has_population_or_unbiased_selection_authority"
        )
        is not False
        or borrowed.get("mujoco_closure_raw_sha256")
        != "sha256:5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09"
        or _raw_sha256(MUJOCO_RESTORATION_CLOSURE_PATH)
        != borrowed.get("mujoco_closure_raw_sha256")
        or borrowed.get("rapier_closure_raw_sha256")
        != "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
        or _raw_sha256(RAPIER_RESTORATION_CLOSURE_PATH)
        != borrowed.get("rapier_closure_raw_sha256")
        or borrowed.get("borrowed_semantics_are_not_r23d7_turning_evidence") is not True
        or borrowed.get("godot_jolt_terminal_restoration_implementation_still_required")
        is not True
        or fixture.get("morphology_id") != "qsdk_r05_generated_s169"
        or fixture.get("campaign_seed") != 21_501
        or fixture.get("descriptor_schema_version")
        != "sporespore_bounded_quadruped_descriptor_v1"
        or fixture.get("fresh_morphology_consumed") is not False
        or fixture.get("physics_hz") != 120
        or fixture.get("authored_sliding_friction") != 0.95
        or fixture.get("selected_candidate_id") != "BW5R-B"
        or fixture.get("selected_policy_id") != "sporespore_balanced_wave_bw5r_b_v1"
        or fixture.get("selected_policy_digest")
        != "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        or fixture.get("gait_cycle_steps") != 360
        or fixture.get("ordered_limb_ids") != list(LIMB_IDS)
        or fixture.get("nominal_phase_offsets_steps") != [0, 90, 180, 270]
        or fixture.get("initial_perturbation_inherited_unchanged_from_r23d3")
        is not True
        or stage_a.get("ordered_cell_ids") != expected_stage_a_ids
        or stage_a.get("ordered_arms") != expected_stage_a_arms
        or stage_a.get("declared_cell_count") != 2
        or stage_a.get("declared_world_count") != 2
        or stage_a.get("fixed_onset_id") != "onset_600"
        or stage_a.get("turn_start_semantic_step") != TURN_START_STEP
        or stage_a.get("parallel_execution_permitted") is not False
        or stage_a.get("replacement_or_selective_rerun_permitted") is not False
        or selector.get("selected_policy_id_if_both_signed_arms_pass")
        != "contact_acquisition_pose_hold_v1"
        or selector.get("none_is_valid_development_result") is not True
        or selector.get("invalid_is_not_encoded_as_none") is not True
        or selector.get("stage_b_launch_requires_both_signed_stage_a_outcomes")
        is not True
        or stage_b.get("ordered_engine_ids") != list(STAGE_B_ENGINES)
        or stage_b.get("ordered_arm_ids") != list(STAGE_B_ARMS)
        or stage_b.get("arm_heading_offsets_rad") != ARM_OFFSETS
        or stage_b.get("fixed_onset_id") != "onset_600"
        or stage_b.get("turn_start_semantic_step") != TURN_START_STEP
        or stage_b.get("declared_cell_count_if_launched") != 9
        or stage_b.get("declared_world_count_if_launched") != 9
        or [cell.cell_id for cell in stage_b_cells()] != expected_stage_b_ids
        or stage_b.get("parallel_execution_permitted") is not False
        or stage_b.get("replacement_or_selective_rerun_permitted") is not False
        or stage_b.get("launch_forbidden_if_stage_a_invalid_incomplete_or_valid_none")
        is not True
        or stage_b.get("all_nine_cells_execute_without_outcome_based_early_stop")
        is not True
        or stage_b.get("complete_nine_report_aggregate_required") is not True
        or stage_b.get(
            "stage_a_mujoco_reports_are_not_substituted_for_stage_b_mujoco_reports"
        )
        is not True
        or schedule != expected_schedule
        or outcomes != expected_outcomes
        or restoration.get("restoration_receipt_required_each_active_restoration_step")
        is not True
        or restoration.get("all_four_contacts_acquired_within_180_steps") is not True
        or restoration.get("consecutive_all_four_contact_hold_steps_required")
        != CONTACT_HOLD_STEPS
        or restoration.get(
            "exact_zero_native_application_during_passive_settle_required"
        )
        is not True
        or restoration.get("passive_settle_trace_rows_required") != PASSIVE_SETTLE_STEPS
        or trace.get("trace_schema_version") != TRACE_SCHEMA
        or trace.get("row_schema_version") != TRACE_ROW_SCHEMA
        or trace.get("rows_per_complete_cell") != TOTAL_TRACE_STEPS
        or trace.get("hash_projection") != "sha256_canonical_sorted_key_ndjson_rows_v1"
        or trace.get("passive_zero_actuation_required_per_settle_row") is not True
        or transport.get("empty_terminal_path_collection_serialization")
        != "utf8_json_array_plus_lf"
        or transport.get("exact_empty_collection_bytes_utf8_hex") != "5b5d0a"
        or transport.get("zero_world_empty_stage_b_path_executed_before_physics")
        is not True
        or future.get("stage_a_physical_worker_count") != 0
        or future.get("stage_b_physical_worker_count") != 0
        or future.get("production_evaluator_implemented") is not False
        or future.get("aggregate_supervisor_implemented") is not False
        or future.get("terminal_restoration_engine_implementation_count") != 0
        or authorization.get("physical_execution_authorized") is not False
        or authorization.get("physical_process_launch_count") != 0
        or authorization.get("world_attempt_count") != 0
        or authorization.get("world_build_count") != 0
        or claims.get("stage_zero_design_complete") is not True
        or claims.get("stage_a_result_exists") is not False
        or claims.get("stage_b_result_exists") is not False
        or claims.get("command_conditioned_turning") is not False
        or claims.get("bilateral_signed_turning") is not False
        or claims.get("portable_basic_turning") is not False
        or claims.get("cross_engine_equivalence") is not False
        or claims.get("q_sdk_r23_satisfied") is not False
        or claims.get("prone_to_standing") is not False
        or claims.get("release_authorized") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D7Error("R23D7_CONTRACT_IDENTITY_INVALID")
    return contract


def load_contract() -> dict[str, Any]:
    """Validate the frozen R23D7 declaration used by every worker/evaluator."""

    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D7Error(f"R23D7_CONTRACT_UNREADABLE:{type(error).__name__}") from error
    lineage = contract.get("lineage", {})
    inherited = contract.get("inherited_unchanged_scientific_contract", {})
    schedule = contract.get("frozen_schedule_and_gate_snapshot", {})
    policy = contract.get("neutral_stance_policy_contract", {})
    stage_a = contract.get("stage_a_mujoco_terminal_stance_screen", {})
    stage_b = contract.get("stage_b_three_engine_confirmation", {})
    trace = contract.get("diagnostic_trace_contract", {})
    authorization = contract.get("authorization", {})
    claims = contract.get("claim_boundary", {})
    invalid = (
        contract.get("schema_version") != SCHEMA_VERSION
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or lineage.get("predecessor_id") != "QSDK-R23D6"
        or lineage.get("predecessor_status")
        != "closed_consumed_valid_none_stage_a_terminal_restoration_negative"
        or lineage.get("predecessor_same_identity_rerun_allowed") is not False
        or inherited.get("outcome_numeric_thresholds_changed") is not False
        or inherited.get("stage_a_selector_changed") is not False
        or schedule.get("turning_controller_semantic_step_count") != CONTROLLER_STEPS
        or schedule.get("terminal_stance_step_count") != RESTORATION_STEPS
        or schedule.get("maximum_four_contact_acquisition_steps")
        != CONTACT_ACQUISITION_STEPS
        or schedule.get("required_consecutive_all_four_contact_hold_steps")
        != CONTACT_HOLD_STEPS
        or schedule.get("passive_settle_step_count") != PASSIVE_SETTLE_STEPS
        or schedule.get("total_traced_step_count") != TOTAL_TRACE_STEPS
        or schedule.get("exact_active_native_application_count")
        != EXPECTED_NATIVE_APPLICATION_COUNT
        or policy.get("policy_id") != RESTORATION_POLICY_ID
        or policy.get("activation_is_atomic_for_all_eight_actuators") is not True
        or policy.get("dynamic_pose_capture") is not False
        or stage_a.get("ordered_cell_ids") != [cell.cell_id for cell in stage_a_cells()]
        or stage_a.get("declared_world_count") != len(stage_a_cells())
        or stage_b.get("declared_cell_count_if_launched") != len(stage_b_cells())
        or trace.get("every_one_of_3772_steps_retained") is not True
        or trace.get("neutral_target_activation_count_every_terminal_step_required")
        is not True
        or authorization.get("physical_execution_authorized") is not False
        or claims.get("command_conditioned_turning") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D7Error("R23D7_CONTRACT_IDENTITY_INVALID")
    return contract


def phase_for_trace_step(cell: Cell, trace_step: int) -> tuple[str, int | None, float]:
    if trace_step < 0 or trace_step >= TOTAL_TRACE_STEPS:
        raise R23D7Error("R23D7_TRACE_STEP_OUT_OF_RANGE")
    if trace_step < TURN_START_STEP:
        return "reference_warmup", trace_step, 0.0
    if trace_step < TURN_START_STEP + TURN_DURATION_STEPS:
        return "commanded_turn", trace_step, cell.turn_heading_offset_rad
    if trace_step < TURN_START_STEP + TURN_DURATION_STEPS + REFERENCE_RECOVERY_STEPS:
        return "reference_recovery", trace_step, 0.0
    if trace_step < CONTROLLER_STEPS:
        return "reference_continuation", trace_step, 0.0
    if trace_step < CONTROLLER_STEPS + CONTACT_ACQUISITION_STEPS:
        return "terminal_neutral_stance_acquisition", None, 0.0
    if trace_step < ACTIVE_STEPS:
        return "terminal_neutral_stance_hold", None, 0.0
    return "passive_zero_actuation_settle", None, 0.0


def expected_phase_counts() -> dict[str, int]:
    return {
        "reference_warmup": TURN_START_STEP,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": REFERENCE_RECOVERY_STEPS,
        "reference_continuation": REFERENCE_CONTINUATION_STEPS,
        "terminal_neutral_stance_acquisition": CONTACT_ACQUISITION_STEPS,
        "terminal_neutral_stance_hold": CONTACT_HOLD_STEPS,
        "passive_zero_actuation_settle": PASSIVE_SETTLE_STEPS,
    }


def synthetic_trace_row(cell: Cell, trace_step: int) -> dict[str, Any]:
    phase_id, controller_step, heading_offset = phase_for_trace_step(cell, trace_step)
    passive = phase_id == "passive_zero_actuation_settle"
    restoration = phase_id.startswith("terminal_")
    if phase_id == "commanded_turn" and cell.turn_heading_offset_rad != 0.0:
        progress = (trace_step - TURN_START_STEP + 1) / TURN_DURATION_STEPS
        measured_yaw = cell.turn_heading_offset_rad * 0.5 * progress
    else:
        measured_yaw = cell.turn_heading_offset_rad * 0.5
    return {
        "schema_version": TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_step,
        "desired_heading_offset_rad": heading_offset,
        "measured_yaw_rad": measured_yaw,
        "torso_height_m": 0.4,
        "torso_tilt_rad": 0.1,
        "torso_ground_contact": False,
        # The trace hash recursively sorts JSON object keys.  Emit and require
        # that same canonical order so a valid trace remains valid after its
        # content-addressed NDJSON round trip.
        "ordered_foot_contacts": {
            limb_id: True for limb_id in sorted(LIMB_IDS)
        },
        "actuator_command_count": 0 if passive else ACTUATOR_COUNT,
        "native_actuation_application_count": 0 if passive else ACTUATOR_COUNT,
        "zero_actuation": passive,
        "command_composition_mode": (
            "passive_zero_actuation_v1"
            if passive
            else RESTORATION_POLICY_ID
            if restoration
            else "balanced_wave_turning_v1"
        ),
        "restoration_receipt_present": restoration,
        "neutral_target_activation_count": ACTUATOR_COUNT if restoration else 0,
        "maximum_absolute_joint_position_error_rad": 0.05 if restoration else None,
        "maximum_absolute_commanded_joint_velocity_rad_s": 0.35 if restoration else None,
    }


def synthetic_trace(cell: Cell) -> list[dict[str, Any]]:
    return [synthetic_trace_row(cell, step) for step in range(TOTAL_TRACE_STEPS)]


def validate_trace(cell: Cell, rows: Sequence[Any]) -> dict[str, Any]:
    failures: list[str] = []
    phase_counts = {phase: 0 for phase in expected_phase_counts()}
    hasher = hashlib.sha256()
    byte_length = 0
    if len(rows) != TOTAL_TRACE_STEPS:
        failures.append("R23D7_TRACE_ROW_COUNT")
    for index, row in enumerate(rows):
        if not _exact_keys(row, TRACE_ROW_FIELDS):
            failures.append(f"R23D7_TRACE_ROW_FIELDS:{index}")
            continue
        expected_phase, expected_controller_step, expected_heading = (
            phase_for_trace_step(cell, index)
        )
        passive = expected_phase == "passive_zero_actuation_settle"
        restoration = expected_phase.startswith("terminal_")
        if (
            row.get("schema_version") != TRACE_ROW_SCHEMA
            or row.get("cell_id") != cell.cell_id
            or type(row.get("trace_step")) is not int
            or row.get("trace_step") != index
        ):
            failures.append(f"R23D7_TRACE_ROW_IDENTITY:{index}")
        if (
            row.get("phase_id") != expected_phase
            or row.get("controller_semantic_step") != expected_controller_step
            or not _finite(row.get("desired_heading_offset_rad"))
            or not math.isclose(
                float(row.get("desired_heading_offset_rad", math.inf)),
                expected_heading,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
        ):
            failures.append(f"R23D7_TRACE_PHASE:{index}")
        else:
            phase_counts[expected_phase] += 1
        contacts = row.get("ordered_foot_contacts")
        if (
            not _finite(row.get("measured_yaw_rad"))
            or not _finite(row.get("torso_height_m"))
            or not _finite(row.get("torso_tilt_rad"))
            or type(row.get("torso_ground_contact")) is not bool
            or not isinstance(contacts, dict)
            or list(contacts) != sorted(LIMB_IDS)
            or not all(type(value) is bool for value in contacts.values())
        ):
            failures.append(f"R23D7_TRACE_OBSERVATION:{index}")
        expected_count = 0 if passive else ACTUATOR_COUNT
        expected_mode = (
            "passive_zero_actuation_v1"
            if passive
            else RESTORATION_POLICY_ID
            if restoration
            else "balanced_wave_turning_v1"
        )
        if (
            type(row.get("actuator_command_count")) is not int
            or row.get("actuator_command_count") != expected_count
            or type(row.get("native_actuation_application_count")) is not int
            or row.get("native_actuation_application_count") != expected_count
            or row.get("zero_actuation") is not passive
            or row.get("command_composition_mode") != expected_mode
            or row.get("restoration_receipt_present") is not restoration
        ):
            failures.append(f"R23D7_TRACE_ACTUATION:{index}")
        if restoration:
            if (
                row.get("neutral_target_activation_count") != ACTUATOR_COUNT
                or not _finite(row.get("maximum_absolute_joint_position_error_rad"))
                or float(row["maximum_absolute_joint_position_error_rad"]) < 0.0
                or not _finite(
                    row.get("maximum_absolute_commanded_joint_velocity_rad_s")
                )
                or float(row["maximum_absolute_commanded_joint_velocity_rad_s"])
                > 0.35 + 1.0e-12
            ):
                failures.append(f"R23D7_TRACE_NEUTRAL_STANCE:{index}")
        elif (
            row.get("neutral_target_activation_count") != 0
            or row.get("maximum_absolute_joint_position_error_rad") is not None
            or row.get("maximum_absolute_commanded_joint_velocity_rad_s") is not None
        ):
            failures.append(f"R23D7_TRACE_NEUTRAL_STANCE_ABSENT:{index}")
        raw = _canonical_bytes(row) + b"\n"
        hasher.update(raw)
        byte_length += len(raw)
    if phase_counts != expected_phase_counts():
        failures.append("R23D7_TRACE_PHASE_COUNTS")
    return {
        "ok": not failures,
        "failure_codes": failures,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hasher.hexdigest(),
        "byte_length": byte_length,
        "hash_projection": "sha256_canonical_sorted_key_ndjson_rows_v1",
        "phase_counts": phase_counts,
    }


def _outcome_failures(cell: Cell, measurements: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    yaw = measurements.get("turn_phase_yaw_delta_rad")
    expected_sign = (
        0
        if cell.arm_id == "reference_zero"
        else (1 if cell.turn_heading_offset_rad > 0 else -1)
    )
    signed_yaw = _finite(yaw) and (
        expected_sign == 0
        or (abs(float(yaw)) >= 0.01 and (1 if float(yaw) > 0 else -1) == expected_sign)
    )
    checks = (
        ("R23D7_SIGNED_YAW", signed_yaw),
        (
            "R23D7_STEERING_BOUND",
            _finite(measurements.get("maximum_absolute_steering_fraction"))
            and float(measurements["maximum_absolute_steering_fraction"]) <= 0.4,
        ),
        (
            "R23D7_FORWARD_DISPLACEMENT",
            _finite(measurements.get("final_forward_displacement_m"))
            and float(measurements["final_forward_displacement_m"]) >= 0.030123046875,
        ),
        (
            "R23D7_MAXIMUM_TILT",
            _finite(measurements.get("maximum_tilt_rad"))
            and float(measurements["maximum_tilt_rad"]) <= 0.6,
        ),
        (
            "R23D7_MINIMUM_HEIGHT",
            _finite(measurements.get("minimum_torso_height_m"))
            and float(measurements["minimum_torso_height_m"]) >= 0.2499708652072946,
        ),
        (
            "R23D7_CONTACT_CYCLES",
            measurements.get("contact_cycle_count_by_limb")
            == {limb_id: 2 for limb_id in LIMB_IDS},
        ),
        (
            "R23D7_TORSO_CONTACT",
            measurements.get("torso_ground_contact_step_count") == 0,
        ),
        ("R23D7_CONTROLLER_ERRORS", measurements.get("controller_error_count") == 0),
        (
            "R23D7_ACTIVE_SAFE_NO_ACTUATION",
            measurements.get("active_safe_no_actuation_count") == 0,
        ),
        ("R23D7_NONFINITE", measurements.get("nonfinite_observation_count") == 0),
        (
            "R23D7_APPLICATION_MISMATCH",
            measurements.get("actuator_application_mismatch_count") == 0,
        ),
        (
            "R23D7_NATIVE_APPLICATION_COUNT",
            measurements.get("native_actuation_application_count")
            == EXPECTED_NATIVE_APPLICATION_COUNT,
        ),
        (
            "R23D7_CONTACT_ACQUISITION",
            type(measurements.get("first_all_four_contact_restoration_step")) is int
            and 0
            <= measurements["first_all_four_contact_restoration_step"]
            < CONTACT_ACQUISITION_STEPS,
        ),
        (
            "R23D7_CONTACT_HOLD",
            measurements.get("consecutive_all_four_contact_hold_step_count")
            >= CONTACT_HOLD_STEPS,
        ),
        ("R23D7_POSE_MEMORY", measurements.get("captured_pose_memory_valid") is True),
        (
            "R23D7_JOINT_VELOCITY_BOUND",
            measurements.get("bounded_joint_velocity_valid") is True,
        ),
        (
            "R23D7_HEADING_RECEIPT",
            measurements.get("heading_correction_receipt_valid") is True,
        ),
        (
            "R23D7_PASSIVE_ZERO_APPLICATION",
            measurements.get("passive_native_actuation_application_count") == 0,
        ),
        (
            "R23D7_PASSIVE_TRACE_ROWS",
            measurements.get("passive_settle_trace_row_count") == PASSIVE_SETTLE_STEPS,
        ),
    )
    for code, passed in checks:
        if not passed:
            failures.append(code)
    return failures


def synthetic_report(cell: Cell, *, passing: bool = True) -> dict[str, Any]:
    trace = validate_trace(cell, synthetic_trace(cell))
    measurements = {
        "final_forward_displacement_m": 1.0,
        "turn_phase_yaw_delta_rad": (
            0.0
            if cell.arm_id == "reference_zero"
            else cell.turn_heading_offset_rad * 0.5
        ),
        "maximum_absolute_steering_fraction": 0.2,
        "maximum_tilt_rad": 0.2,
        "minimum_torso_height_m": 0.4,
        "contact_cycle_count_by_limb": {limb_id: 2 for limb_id in LIMB_IDS},
        "torso_ground_contact_step_count": 0,
        "controller_error_count": 0,
        "active_safe_no_actuation_count": 0,
        "nonfinite_observation_count": 0,
        "actuator_application_mismatch_count": 0,
        "native_actuation_application_count": EXPECTED_NATIVE_APPLICATION_COUNT,
        "first_all_four_contact_restoration_step": 0,
        "consecutive_all_four_contact_hold_step_count": CONTACT_HOLD_STEPS,
        "captured_pose_memory_valid": True,
        "bounded_joint_velocity_valid": True,
        "heading_correction_receipt_valid": True,
        "passive_native_actuation_application_count": 0,
        "passive_settle_trace_row_count": PASSIVE_SETTLE_STEPS,
    }
    if not passing:
        measurements["maximum_tilt_rad"] = 0.7
    failures = _outcome_failures(cell, measurements)
    return {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": cell.engine_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "trace_summary": trace,
        "execution": {
            "integrity_passed": True,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "total_trace_step_count": TOTAL_TRACE_STEPS,
            "native_actuation_application_count": EXPECTED_NATIVE_APPLICATION_COUNT,
        },
        "measurements": measurements,
        "outcome": {
            "outcome_gate_passed": not failures,
            "failed_gate_ids": failures,
        },
        "claims": {
            "command_conditioned_turning": False,
            "bilateral_signed_turning": False,
            "portable_basic_turning": False,
            "cross_engine_equivalence": False,
            "physical_acceptance_authority": False,
        },
        "synthetic_zero_world_projection": True,
    }


def _report_failures(cell: Cell, report: Any) -> list[str]:
    if not isinstance(report, dict):
        return ["R23D7_REPORT_TYPE"]
    expected_identity = {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": cell.engine_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
    }
    failures = [
        f"R23D7_REPORT_IDENTITY:{key}"
        for key, expected in expected_identity.items()
        if type(report.get(key)) is not type(expected) or report.get(key) != expected
    ]
    trace = report.get("trace_summary", {})
    execution = report.get("execution", {})
    if (
        trace.get("ok") is not True
        or trace.get("failure_codes") != []
        or trace.get("row_count") != TOTAL_TRACE_STEPS
        or trace.get("phase_counts") != expected_phase_counts()
    ):
        failures.append("R23D7_REPORT_TRACE")
    if (
        execution.get("integrity_passed") is not True
        or execution.get("world_attempt_count") != 1
        or execution.get("world_build_count") != 1
        or execution.get("total_trace_step_count") != TOTAL_TRACE_STEPS
        or execution.get("native_actuation_application_count")
        != EXPECTED_NATIVE_APPLICATION_COUNT
    ):
        failures.append("R23D7_REPORT_EXECUTION")
    recomputed = _outcome_failures(cell, report.get("measurements", {}))
    outcome = report.get("outcome", {})
    if (
        outcome.get("outcome_gate_passed") is not (not recomputed)
        or outcome.get("failed_gate_ids") != recomputed
    ):
        failures.append("R23D7_REPORT_OUTCOME_RECOMPUTE")
    if report.get("synthetic_zero_world_projection") is not True:
        failures.append("R23D7_REPORT_NOT_ZERO_WORLD")
    claims = report.get("claims", {})
    if not isinstance(claims, dict) or any(
        value is not False for value in claims.values()
    ):
        failures.append("R23D7_REPORT_CLAIMS")
    return failures


def evaluate_stage_a(reports: Sequence[Any]) -> dict[str, Any]:
    expected_cells = stage_a_cells()
    if len(reports) != len(expected_cells):
        return {
            "valid": False,
            "classification": "invalid_or_incomplete_stage_a",
            "selected_terminal_restoration_policy_id": "INVALID",
            "stage_b_launch_authorized": False,
            "failure_codes": ["R23D7_STAGE_A_CARDINALITY"],
        }
    failures: list[str] = []
    outcome_passes: list[bool] = []
    for cell, report in zip(expected_cells, reports, strict=True):
        cell_failures = _report_failures(cell, report)
        failures.extend(f"{cell.cell_id}:{failure}" for failure in cell_failures)
        outcome_passes.append(
            isinstance(report, dict)
            and report.get("outcome", {}).get("outcome_gate_passed") is True
        )
    if failures:
        return {
            "valid": False,
            "classification": "invalid_or_incomplete_stage_a",
            "selected_terminal_restoration_policy_id": "INVALID",
            "stage_b_launch_authorized": False,
            "failure_codes": failures,
        }
    selected = all(outcome_passes)
    return {
        "valid": True,
        "classification": "valid_selected_stage_a"
        if selected
        else "valid_none_stage_a",
        "selected_terminal_restoration_policy_id": (
            "contact_acquisition_pose_hold_v1" if selected else "NONE"
        ),
        "stage_b_launch_authorized": selected,
        "failure_codes": [],
    }


def serialize_terminal_paths(paths: Sequence[str]) -> bytes:
    if not isinstance(paths, (list, tuple)) or any(
        not isinstance(path, str) or not path for path in paths
    ):
        raise R23D7Error("R23D7_TERMINAL_PATH_COLLECTION_INVALID")
    return _canonical_bytes(list(paths)) + b"\n"


def evaluator_transport_decision(
    *, stdout: str, stderr: str, exit_code: int, output_manifest_retained: bool
) -> dict[str, Any]:
    if type(stdout) is not str or type(stderr) is not str or type(exit_code) is not int:
        raise R23D7Error("R23D7_EVALUATOR_TRANSPORT_TYPES")
    transport_retained = (
        output_manifest_retained and stdout is not None and stderr is not None
    )
    marker_parse_authorized = (
        transport_retained and exit_code == 0 and bool(stdout.strip())
    )
    return {
        "stdout_retained": True,
        "stderr_retained": True,
        "exit_code_retained": True,
        "output_manifest_retained": output_manifest_retained,
        "marker_parse_authorized": marker_parse_authorized,
    }


def _negative_control_count() -> int:
    cell = stage_a_cells()[0]
    base = synthetic_trace(cell)
    controls: list[list[dict[str, Any]]] = []
    missing = copy.deepcopy(base[:-1])
    controls.append(missing)
    wrong_step = copy.deepcopy(base)
    wrong_step[10]["trace_step"] = 11
    controls.append(wrong_step)
    wrong_phase = copy.deepcopy(base)
    wrong_phase[CONTROLLER_STEPS]["phase_id"] = "reference_continuation"
    controls.append(wrong_phase)
    passive_actuation = copy.deepcopy(base)
    passive_actuation[ACTIVE_STEPS]["native_actuation_application_count"] = 8
    controls.append(passive_actuation)
    missing_restoration = copy.deepcopy(base)
    missing_restoration[CONTROLLER_STEPS]["restoration_receipt_present"] = False
    controls.append(missing_restoration)
    wrong_controller_step = copy.deepcopy(base)
    wrong_controller_step[CONTROLLER_STEPS]["controller_semantic_step"] = (
        CONTROLLER_STEPS
    )
    controls.append(wrong_controller_step)
    wrong_contact_order = copy.deepcopy(base)
    wrong_contact_order[0]["ordered_foot_contacts"] = {
        "front_left": True,
        "rear_left": True,
        "rear_right": True,
        "front_right": True,
    }
    controls.append(wrong_contact_order)
    wrong_mode = copy.deepcopy(base)
    wrong_mode[ACTIVE_STEPS]["command_composition_mode"] = RESTORATION_POLICY_ID
    controls.append(wrong_mode)
    rejected = sum(not validate_trace(cell, rows)["ok"] for rows in controls)
    if rejected != len(controls):
        raise R23D7Error("R23D7_TRACE_NEGATIVE_CONTROL_ESCAPED")
    return rejected


def run_preflight() -> dict[str, Any]:
    load_contract()
    traces = [validate_trace(cell, synthetic_trace(cell)) for cell in all_cells()]
    if not all(trace["ok"] for trace in traces):
        raise R23D7Error("R23D7_SYNTHETIC_TRACE_INVALID")
    selected = evaluate_stage_a([synthetic_report(cell) for cell in stage_a_cells()])
    none_reports = [synthetic_report(cell) for cell in stage_a_cells()]
    none_reports[1] = synthetic_report(stage_a_cells()[1], passing=False)
    none_result = evaluate_stage_a(none_reports)
    invalid_result = evaluate_stage_a([synthetic_report(stage_a_cells()[0])])
    forged = [synthetic_report(cell) for cell in stage_a_cells()]
    forged[0]["outcome"]["outcome_gate_passed"] = False
    forged_result = evaluate_stage_a(forged)
    selector_canaries = (
        selected.get("classification") == "valid_selected_stage_a"
        and selected.get("stage_b_launch_authorized") is True
        and none_result.get("classification") == "valid_none_stage_a"
        and none_result.get("stage_b_launch_authorized") is False
        and invalid_result.get("classification") == "invalid_or_incomplete_stage_a"
        and invalid_result.get("selected_terminal_restoration_policy_id") == "INVALID"
        and forged_result.get("classification") == "invalid_or_incomplete_stage_a"
    )
    if not selector_canaries:
        raise R23D7Error("R23D7_SELECTOR_CANARY_INVALID")
    empty_manifest = serialize_terminal_paths([])
    nonempty_manifest = serialize_terminal_paths(["one.json"])
    if (
        empty_manifest != b"[]\n"
        or json.loads(empty_manifest) != []
        or json.loads(nonempty_manifest) != ["one.json"]
    ):
        raise R23D7Error("R23D7_EMPTY_MANIFEST_CANARY_INVALID")
    good_transport = evaluator_transport_decision(
        stdout="QSDK_R23D7_EVALUATION {}\n",
        stderr="",
        exit_code=0,
        output_manifest_retained=True,
    )
    empty_stdout = evaluator_transport_decision(
        stdout="", stderr="parse failure", exit_code=1, output_manifest_retained=True
    )
    missing_output = evaluator_transport_decision(
        stdout="marker", stderr="", exit_code=0, output_manifest_retained=False
    )
    if (
        good_transport["marker_parse_authorized"] is not True
        or empty_stdout["marker_parse_authorized"] is not False
        or missing_output["marker_parse_authorized"] is not False
    ):
        raise R23D7Error("R23D7_EVALUATOR_TRANSPORT_CANARY_INVALID")
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    return {
        "schema_version": "sporespore_qsdk_r23d7_stage_zero_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "contract_raw_sha256": _raw_sha256(CONTRACT_PATH),
        "predecessor_closure_raw_sha256": _raw_sha256(R23D3_CLOSURE_PATH),
        "stage_a_cell_count": len(stage_a_cells()),
        "stage_b_projected_cell_count": len(stage_b_cells()),
        "trace_validation_count": len(traces),
        "trace_row_validation_count": sum(trace["row_count"] for trace in traces),
        "trace_negative_control_rejection_count": _negative_control_count(),
        "selector_canary_pass_count": 4,
        "empty_manifest_canary_pass_count": 2,
        "evaluator_transport_canary_pass_count": 3,
        "controller_step_count": CONTROLLER_STEPS,
        "terminal_stance_step_count": RESTORATION_STEPS,
        "passive_settle_trace_step_count": PASSIVE_SETTLE_STEPS,
        "total_trace_step_count_per_cell": TOTAL_TRACE_STEPS,
        "numeric_outcome_thresholds_unchanged": contract["unchanged_outcome_gates"][
            "numeric_thresholds_unchanged_from_r23d3"
        ],
        "stage_a_physical_worker_count": 0,
        "stage_b_physical_worker_count": 0,
        "physical_process_launch_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "command_conditioned_turning": False,
        "bilateral_signed_turning": False,
        "portable_basic_turning": False,
        "cross_engine_equivalence": False,
        "q_sdk_r23_satisfied": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def main(arguments: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if arguments is None else arguments)
    if args != ["preflight"]:
        print("usage: r23d7_terminal_stabilization.py preflight", file=sys.stderr)
        return 2
    try:
        receipt = run_preflight()
    except (OSError, ValueError, R23D7Error) as error:
        print(f"QSDK_R23D7_STAGE_ZERO_FAILURE {type(error).__name__}:{error}")
        return 1
    print("QSDK_R23D7_STAGE_ZERO_PREFLIGHT " + json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
