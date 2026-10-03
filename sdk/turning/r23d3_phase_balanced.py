"""Zero-world design/evaluation surface for QSDK-R23D3.

R23D3 is a prospective two-stage development screen.  Stage A uses classic
MuJoCo to screen four signed turn-onset timings.  The frozen selector may then
authorize one complete, serialized three-engine Stage-B matrix.  This module
freezes and exercises that logic without constructing a physics world.

The physical workers and one-shot supervisor intentionally do not exist at
this stage.  Synthetic rows below are schema and evaluator canaries only; they
are never physical or locomotion evidence.
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
CONTRACT_PATH = ROOT / "r23d3_phase_balanced_preregistration_v1.json"
R23D2_CLOSURE_PATH = ROOT / "r23d2_physical_closure_v1.json"

SCHEMA_VERSION = "sporespore_qsdk_r23d3_phase_balanced_preregistration_v1"
CAMPAIGN_ID = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
GATE_ID = "QSDK-R23D3"
TRACE_SCHEMA = "sporespore_qsdk_r23d3_turn_diagnostic_trace_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1"
PROJECTED_REPORT_SCHEMA = "sporespore_qsdk_r23d3_synthetic_cell_projection_v1"
GODOT_PREDICATE_SCHEMA = (
    "sporespore_qsdk_r23d3_godot_execution_predicate_summary_v1"
)

CONTROLLER_STEPS = 2_992
TURN_DURATION_STEPS = 1_200
RECOVERY_DURATION_STEPS = 600
ACTUATOR_COUNT = 8
GAIT_CYCLE_STEPS = 360
LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
PHASE_OFFSETS = (0, 90, 180, 270)
ONSET_IDS = ("onset_600", "onset_690", "onset_780", "onset_870")
ONSET_STEPS = (600, 690, 780, 870)
ARM_IDS = ("positive_heading", "negative_heading")
ARM_OFFSETS = (0.2, -0.2)
STAGE_B_ENGINE_IDS = ("godot_jolt", "rapier_parry", "mujoco")
STAGE_B_ARM_IDS = ("reference_zero", "positive_heading", "negative_heading")

TRACE_ROW_FIELDS = (
    "schema_version",
    "cell_id",
    "semantic_step",
    "segment_id",
    "desired_heading_offset_rad",
    "measured_yaw_rad",
    "desired_heading_error_rad",
    "yaw_tracking_error_rad",
    "requested_steering_fraction",
    "held_steering_fraction",
    "steering_saturated",
    "torso_position_world_m",
    "torso_height_m",
    "torso_tilt_rad",
    "torso_ground_contact",
    "ordered_limb_phase_before",
    "ordered_foot_contacts_before",
    "ordered_foot_contacts_after",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "oracle_passed",
)
TRACE_SUMMARY_FIELDS = (
    "ok",
    "failure_codes",
    "row_count",
    "raw_sha256",
    "byte_length",
    "hash_projection",
    "segment_counts",
    "onset_snapshot",
    "steering_saturation_step_count",
)
ONSET_SNAPSHOT_FIELDS = (
    "semantic_step",
    "ordered_limb_phase_before",
    "ordered_foot_contacts_before",
    "torso_position_world_m",
    "measured_yaw_rad",
    "requested_steering_fraction",
    "held_steering_fraction",
)
LIMB_PHASE_FIELDS = (
    "limb_id",
    "gait_step",
    "local_phase_step",
    "release_hold_step_count",
)
PROJECTED_REPORT_FIELDS = (
    "schema_version",
    "campaign_id",
    "gate_id",
    "stage_id",
    "cell_id",
    "engine_id",
    "onset_id",
    "turn_start_semantic_step",
    "arm_id",
    "turn_heading_offset_rad",
    "trace_summary",
    "execution",
    "outcome",
    "claims",
    "synthetic_zero_world_projection",
)
EXECUTION_FIELDS = (
    "integrity_passed",
    "controller_semantic_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
    "world_attempt_count",
    "world_build_count",
)
OUTCOME_FIELDS = (
    "walking_gate_passed",
    "turn_phase_yaw_delta_rad",
    "signed_yaw_response_passed",
    "outcome_gate_passed",
    "failed_gate_ids",
)
PHYSICAL_OUTCOME_MEASUREMENT_FIELDS = (
    "final_forward_displacement_m",
    "turn_phase_yaw_delta_rad",
    "maximum_absolute_requested_steering_fraction",
    "maximum_absolute_held_steering_fraction",
    "maximum_tilt_rad",
    "minimum_torso_height_m",
    "contact_cycle_count_by_limb",
    "torso_ground_contact_step_count",
    "controller_error_count",
    "safe_no_actuation_count",
    "nonfinite_observation_count",
    "actuator_application_mismatch_count",
    "controller_semantic_step_count",
    "validated_portable_command_count",
    "native_actuation_application_count",
)


class R23D3Error(RuntimeError):
    """A frozen declaration, trace, report, or aggregate is invalid."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    onset_id: str
    turn_start_semantic_step: int
    arm_id: str
    turn_heading_offset_rad: float


def _raw_sha256(path: Path) -> str:
    try:
        return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        raise R23D3Error(
            f"R23D3_SOURCE_UNREADABLE:{path.name}:{type(error).__name__}"
        ) from error


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _exact_keys(value: Any, keys: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(keys)


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _value_type(value: Any) -> str:
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    if value is None:
        return "null"
    return type(value).__name__


def _strict_equal(observed: Any, expected: Any) -> bool:
    return type(observed) is type(expected) and observed == expected


def _sha256_string(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def _signed_yaw_response(cell: Cell, yaw_delta: Any) -> bool:
    if cell.arm_id == "reference_zero":
        return _finite_number(yaw_delta)
    if not _finite_number(yaw_delta) or abs(float(yaw_delta)) < 0.01:
        return False
    expected_sign = 1.0 if cell.turn_heading_offset_rad > 0.0 else -1.0
    return math.copysign(1.0, float(yaw_delta)) == expected_sign


def load_contract() -> dict[str, Any]:
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise R23D3Error(
            f"R23D3_CONTRACT_UNREADABLE:{type(error).__name__}"
        ) from error

    lineage = contract.get("lineage", {})
    fixture = contract.get("fixture", {})
    predecessor = contract.get("disclosed_predecessor_results", {})
    stage_a = contract.get("stage_a_mujoco_onset_screen", {})
    selector = contract.get("stage_a_selector", {})
    stage_b = contract.get("stage_b_three_engine_confirmation", {})
    schedule = contract.get("command_schedule", {})
    outcomes = contract.get("unchanged_outcome_gates", {})
    diagnostic = contract.get("diagnostic_trace_contract", {})
    stage_report = contract.get("stage_report_contract", {})
    godot = contract.get("godot_post_world_failure_contract", {})
    classifications = contract.get("result_classification", {})
    future = contract.get("future_implementation_requirements", {})
    authorization = contract.get("authorization", {})
    claims = contract.get("claim_boundary", {})

    actual_stage_a_cells = [cell.cell_id for cell in stage_a_cells_from(contract)]
    expected_stage_a_cells = [
        f"mujoco__{onset_id}__{arm_id}"
        for onset_id in ONSET_IDS
        for arm_id in ARM_IDS
    ]
    expected_onsets = [
        {
            "onset_id": onset_id,
            "turn_start_semantic_step": onset_step,
            "nominal_quarter_cycle_index": index,
        }
        for index, (onset_id, onset_step) in enumerate(
            zip(ONSET_IDS, ONSET_STEPS, strict=True)
        )
    ]
    expected_signed_arms = [
        {
            "arm_id": arm_id,
            "turn_heading_offset_rad": offset,
            "expected_yaw_delta_sign": 1 if offset > 0.0 else -1,
        }
        for arm_id, offset in zip(ARM_IDS, ARM_OFFSETS, strict=True)
    ]
    expected_godot_predicates = [
        {
            "predicate_id": "sdk_summary_ok",
            "source_path": "sdk_authority_summary.ok",
            "expected_value": True,
        },
        {
            "predicate_id": "sdk_failure_code_empty",
            "source_path": "sdk_authority_summary.failure_code",
            "expected_value": "",
        },
        {
            "predicate_id": "sdk_step_count",
            "source_path": "sdk_authority_summary.step_count",
            "expected_value": CONTROLLER_STEPS,
        },
        {
            "predicate_id": "sdk_safe_no_actuation_count",
            "source_path": "sdk_authority_summary.safe_no_actuation_count",
            "expected_value": 0,
        },
        {
            "predicate_id": "sdk_mismatch_count",
            "source_path": "sdk_authority_summary.mismatch_count",
            "expected_value": 0,
        },
        {
            "predicate_id": "sdk_validated_command_count",
            "source_path": "sdk_authority_summary.validated_balanced_wave_command_count",
            "expected_value": CONTROLLER_STEPS * ACTUATOR_COUNT,
        },
        {
            "predicate_id": "sdk_native_application_count",
            "source_path": "sdk_authority_summary.native_actuation_application_count",
            "expected_value": CONTROLLER_STEPS * ACTUATOR_COUNT,
        },
    ]
    expected_outcomes = {
        "maximum_absolute_requested_or_held_steering_fraction": 0.4,
        "minimum_absolute_signed_turn_phase_yaw_delta_rad": 0.01,
        "minimum_final_forward_displacement_m": 0.030123046875,
        "maximum_tilt_rad": 0.6,
        "minimum_torso_height_m": 0.2499708652072946,
        "minimum_contact_cycles_per_limb": 2,
        "zero_torso_ground_contact_required": True,
        "zero_controller_errors_required": True,
        "zero_safe_no_actuation_required": True,
        "zero_nonfinite_observations_required": True,
        "zero_actuator_application_mismatches_required": True,
        "exact_native_application_count_required": True,
        "recovery_heading_measured_not_thresholded": True,
    }

    if (
        contract.get("schema_version") != SCHEMA_VERSION
        or contract.get("status")
        != "stage_zero_preregistered_no_workers_no_physical_authorization"
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("release_gate_id") != "QSDK-R23"
        or lineage.get("predecessor_id") != "QSDK-R23D2"
        or lineage.get("predecessor_identity_reused") is not False
        or lineage.get("predecessor_world_rerun_permitted") is not False
        or lineage.get("r23d2_results_exposed_before_preregistration") is not True
        or lineage.get("predecessor_closure_raw_sha256")
        != "sha256:83fb890445f1355027ff5062c6d9c3f83792f124a9ee3c2561eab85efe249680"
        or _raw_sha256(R23D2_CLOSURE_PATH)
        != lineage.get("predecessor_closure_raw_sha256")
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
        or fixture.get("gait_cycle_steps") != GAIT_CYCLE_STEPS
        or fixture.get("ordered_limb_ids") != list(LIMB_IDS)
        or fixture.get("nominal_phase_offsets_steps") != list(PHASE_OFFSETS)
        or fixture.get("initial_perturbation_inherited_unchanged_from_r23d2")
        is not True
        or predecessor.get("godot_jolt_exact_failed_execution_subpredicate_known")
        is not False
        or predecessor.get("godot_jolt_retained_terminal_wave_ticks")
        != {"reference_zero": 2859, "positive_heading": 2891, "negative_heading": 2930}
        or predecessor.get("godot_jolt_inferred_post_settle_controller_step_counts")
        != {"reference_zero": 2620, "positive_heading": 2652, "negative_heading": 2691}
        or predecessor.get("godot_jolt_inference_basis")
        != "retained_terminal_wave_tick_plus_one_minus_frozen_240_tick_settle"
        or predecessor.get("godot_jolt_frozen_expected_controller_step_count")
        != CONTROLLER_STEPS
        or predecessor.get(
            "godot_jolt_fixed_horizon_mismatch_forensic_hypothesis_supported"
        )
        is not True
        or predecessor.get(
            "godot_jolt_horizon_hypothesis_is_not_a_reconstructed_r23d2_cell_report"
        )
        is not True
        or stage_a.get("engine_id") != "mujoco"
        or stage_a.get("host_profile_id")
        != "mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1"
        or stage_a.get("onset_candidates") != expected_onsets
        or stage_a.get("signed_arms") != expected_signed_arms
        or stage_a.get("declared_cell_count") != 8
        or stage_a.get("declared_world_count") != 8
        or stage_a.get("all_cells_execute_without_outcome_based_early_stop")
        is not True
        or stage_a.get("parallel_execution_permitted") is not False
        or stage_a.get("replacement_or_selective_rerun_permitted") is not False
        or actual_stage_a_cells != expected_stage_a_cells
        or stage_a.get("ordered_cell_ids") != expected_stage_a_cells
        or selector.get("selection_domain") != "onset_id"
        or selector.get("parsimony_order") != list(ONSET_IDS)
        or selector.get("none_is_valid_development_result") is not True
        or selector.get("invalid_is_not_encoded_as_none") is not True
        or selector.get("selection_authority")
        != "authorize_the_predeclared_stage_b_matrix_only"
        or selector.get("controller_promotion_authority") is not False
        or selector.get("release_authority") is not False
        or stage_b.get("ordered_engine_ids") != list(STAGE_B_ENGINE_IDS)
        or stage_b.get("ordered_arm_ids") != list(STAGE_B_ARM_IDS)
        or stage_b.get("arm_heading_offsets_rad")
        != {"reference_zero": 0.0, "positive_heading": 0.2, "negative_heading": -0.2}
        or stage_b.get("declared_cell_count_if_launched") != 9
        or stage_b.get("declared_world_count_if_launched") != 9
        or stage_b.get("launch_forbidden_if_stage_a_invalid_incomplete_or_valid_none")
        is not True
        or stage_b.get("all_nine_cells_execute_without_outcome_based_early_stop")
        is not True
        or stage_b.get("parallel_execution_permitted") is not False
        or stage_b.get("replacement_or_selective_rerun_permitted") is not False
        or stage_b.get("complete_nine_report_aggregate_required") is not True
        or stage_b.get("stage_a_mujoco_reports_are_not_substituted_for_stage_b_mujoco_reports")
        is not True
        or schedule.get("controller_semantic_step_count") != CONTROLLER_STEPS
        or schedule.get("schema_version")
        != "sporespore_qsdk_r23d3_selected_onset_turn_return_v1"
        or schedule.get("domain") != "controller_semantic_step"
        or schedule.get("turn_duration_steps") != TURN_DURATION_STEPS
        or schedule.get("reference_recovery_duration_steps")
        != RECOVERY_DURATION_STEPS
        or schedule.get("after_reference_recovery") != "hold_reference_heading"
        or schedule.get("turn_heading_offset_source")
        != "arm.turn_heading_offset_rad"
        or schedule.get("reference_heading_source")
        != "state.task_frame.reference_yaw_rad"
        or schedule.get(
            "all_engine_physical_workers_must_execute_exact_fixed_controller_horizon"
        )
        is not True
        or schedule.get(
            "godot_contact_gated_evidence_termination_must_not_bound_controller_horizon"
        )
        is not True
        or schedule.get(
            "onset_candidates_are_semantic_timing_interventions_not_claimed_exact_physical_phase_bins"
        )
        is not True
        or schedule.get("observed_controller_memory_and_support_state_at_onset_required")
        is not True
        or outcomes != expected_outcomes
        or diagnostic.get("trace_schema_version") != TRACE_SCHEMA
        or diagnostic.get("row_schema_version") != TRACE_ROW_SCHEMA
        or diagnostic.get("rows_per_complete_cell") != CONTROLLER_STEPS
        or diagnostic.get("hash_projection")
        != "sha256_canonical_sorted_key_ndjson_rows_v1"
        or diagnostic.get("required_row_fields") != list(TRACE_ROW_FIELDS)
        or diagnostic.get("required_limb_phase_fields") != list(LIMB_PHASE_FIELDS)
        or diagnostic.get("onset_snapshot_required_fields")
        != list(ONSET_SNAPSHOT_FIELDS)
        or diagnostic.get("one_row_per_controller_semantic_step_required") is not True
        or diagnostic.get("ordered_contiguous_semantic_steps_required") is not True
        or diagnostic.get("content_addressed_before_terminal_entry_required")
        is not True
        or diagnostic.get("terminal_entry_records_trace_raw_sha256_and_byte_length")
        is not True
        or diagnostic.get(
            "full_trace_is_diagnostic_and_integrity_evidence_not_population_authority"
        )
        is not True
        or stage_report.get("zero_world_projection_schema_version")
        != PROJECTED_REPORT_SCHEMA
        or stage_report.get("future_physical_report_schema_version")
        != "sporespore_qsdk_r23d3_engine_cell_report_v1"
        or stage_report.get("selector_requires_observed_turn_phase_yaw_delta_rad")
        is not True
        or stage_report.get("signed_yaw_response_recomputed_by_evaluator") is not True
        or stage_report.get("required_outcome_fields") != list(OUTCOME_FIELDS)
        or stage_report.get("future_physical_report_required_measurement_fields")
        != list(PHYSICAL_OUTCOME_MEASUREMENT_FIELDS)
        or stage_report.get(
            "production_evaluator_recomputes_every_unchanged_outcome_gate"
        )
        is not True
        or stage_report.get("worker_authored_outcome_pass_bits_are_not_selection_authority")
        is not True
        or godot.get("required_predicates") != expected_godot_predicates
        or godot.get("summary_schema_version") != GODOT_PREDICATE_SCHEMA
        or godot.get("retained_on_every_post_world_success_or_failure") is not True
        or godot.get(
            "each_predicate_retains_expected_observed_passed_and_value_type"
        )
        is not True
        or godot.get("raw_sdk_authority_summary_retained") is not True
        or godot.get("grouped_failure_without_predicate_summary_forbidden") is not True
        or godot.get("real_shaped_one_field_mutation_canary_per_predicate_required_before_physics")
        is not True
        or godot.get("fixed_controller_horizon_step_count") != CONTROLLER_STEPS
        or godot.get("adaptive_contact_gated_terminal_end_for_controller_trace_forbidden")
        is not True
        or godot.get(
            "zero_world_worker_preflight_must_prove_fixed_horizon_configuration_before_fixture_insertion"
        )
        is not True
        or godot.get("post_world_fixed_horizon_receipt_required") is not True
        or classifications.get("none_is_never_an_invalid_sentinel") is not True
        or future.get("stage_a_physical_worker_count") != 0
        or future.get("stage_b_physical_worker_count") != 0
        or future.get("production_evaluator_implemented") is not False
        or future.get("aggregate_supervisor_implemented") is not False
        or future.get("zero_world_godot_execution_predicate_projector_implemented")
        is not True
        or future.get("physical_godot_execution_predicate_projector_implemented")
        is not False
        or future.get("godot_fixed_controller_horizon_physical_worker_implemented")
        is not False
        or future.get("godot_fixed_horizon_zero_world_worker_preflight_implemented")
        is not False
        or future.get("godot_fixed_horizon_required_before_physical_authorization")
        is not True
        or future.get("full_trace_writer_implemented_engine_count") != 0
        or future.get("complete_zero_world_gate_required") is not True
        or future.get(
            "all_source_raw_hashes_must_be_git_blob_or_declared_checkout_projection_reproducible"
        )
        is not True
        or future.get("clean_pushed_source_equals_origin_and_live_github_required")
        is not True
        or future.get("source_exact_full_godot_v2_attestation_required") is not True
        or future.get("global_locomotion_operation_lock_required") is not True
        or future.get("content_addressed_retention_before_consumption_required")
        is not True
        or future.get("serial_execution_required") is not True
        or future.get("single_supervisor_attempt_required") is not True
        or authorization.get("physical_execution_authorized") is not False
        or authorization.get("physical_process_launch_count") != 0
        or authorization.get("world_attempt_count") != 0
        or authorization.get("world_build_count") != 0
        or claims.get("stage_zero_design_complete") is not True
        or any(
            claims.get(field) is not False
            for field in (
                "stage_a_result_exists",
                "stage_b_result_exists",
                "command_conditioned_turning",
                "bilateral_signed_turning",
                "portable_basic_turning",
                "cross_engine_equivalence",
                "q_sdk_r23_satisfied",
                "release_authorized",
                "physical_acceptance_authority",
            )
        )
    ):
        raise R23D3Error("R23D3_CONTRACT_IDENTITY_INVALID")
    return contract


def stage_a_cells_from(contract: dict[str, Any]) -> list[Cell]:
    stage = contract.get("stage_a_mujoco_onset_screen", {})
    cells: list[Cell] = []
    for onset in stage.get("onset_candidates", []):
        for arm in stage.get("signed_arms", []):
            onset_id = str(onset.get("onset_id", ""))
            arm_id = str(arm.get("arm_id", ""))
            cells.append(
                Cell(
                    stage_id="mujoco_onset_screen",
                    cell_id=f"mujoco__{onset_id}__{arm_id}",
                    engine_id="mujoco",
                    onset_id=onset_id,
                    turn_start_semantic_step=int(
                        onset.get("turn_start_semantic_step", -1)
                    ),
                    arm_id=arm_id,
                    turn_heading_offset_rad=float(
                        arm.get("turn_heading_offset_rad", math.nan)
                    ),
                )
            )
    return cells


def stage_a_cells(contract: dict[str, Any] | None = None) -> list[Cell]:
    return stage_a_cells_from(contract if contract is not None else load_contract())


def stage_b_cells(selected_onset_id: str) -> list[Cell]:
    if selected_onset_id not in ONSET_IDS:
        raise R23D3Error("R23D3_STAGE_B_SELECTED_ONSET_INVALID")
    onset_step = ONSET_STEPS[ONSET_IDS.index(selected_onset_id)]
    offsets = {"reference_zero": 0.0, **dict(zip(ARM_IDS, ARM_OFFSETS, strict=True))}
    return [
        Cell(
            stage_id="three_engine_confirmation",
            cell_id=f"{engine_id}__{selected_onset_id}__{arm_id}",
            engine_id=engine_id,
            onset_id=selected_onset_id,
            turn_start_semantic_step=onset_step,
            arm_id=arm_id,
            turn_heading_offset_rad=offsets[arm_id],
        )
        for engine_id in STAGE_B_ENGINE_IDS
        for arm_id in STAGE_B_ARM_IDS
    ]


def segment_for_step(cell: Cell, semantic_step: int) -> tuple[str, float]:
    if semantic_step < 0 or semantic_step >= CONTROLLER_STEPS:
        raise R23D3Error("R23D3_SEMANTIC_STEP_OUT_OF_RANGE")
    turn_end = cell.turn_start_semantic_step + TURN_DURATION_STEPS
    recovery_end = turn_end + RECOVERY_DURATION_STEPS
    if semantic_step < cell.turn_start_semantic_step:
        return "reference_warmup", 0.0
    if semantic_step < turn_end:
        return "commanded_turn", cell.turn_heading_offset_rad
    if semantic_step < recovery_end:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts(cell: Cell) -> dict[str, int]:
    return {
        "reference_warmup": cell.turn_start_semantic_step,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": RECOVERY_DURATION_STEPS,
        "after_declared_schedule": (
            CONTROLLER_STEPS
            - cell.turn_start_semantic_step
            - TURN_DURATION_STEPS
            - RECOVERY_DURATION_STEPS
        ),
    }


def _synthetic_limb_phases(semantic_step: int) -> list[dict[str, Any]]:
    gait_step = semantic_step + 3
    return [
        {
            "limb_id": limb_id,
            "gait_step": gait_step,
            "local_phase_step": (
                gait_step + GAIT_CYCLE_STEPS - phase_offset
            )
            % GAIT_CYCLE_STEPS,
            "release_hold_step_count": 0,
        }
        for limb_id, phase_offset in zip(LIMB_IDS, PHASE_OFFSETS, strict=True)
    ]


def synthetic_trace_row(cell: Cell, semantic_step: int) -> dict[str, Any]:
    segment_id, heading_offset = segment_for_step(cell, semantic_step)
    turn_progress = 0.0
    if segment_id == "commanded_turn" and cell.turn_heading_offset_rad != 0.0:
        turn_progress = (
            semantic_step - cell.turn_start_semantic_step + 1
        ) / TURN_DURATION_STEPS
    measured_yaw = cell.turn_heading_offset_rad * 0.25 * turn_progress
    requested = -heading_offset
    held = requested * 0.75
    contacts = {limb_id: True for limb_id in LIMB_IDS}
    return {
        "schema_version": TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "semantic_step": semantic_step,
        "segment_id": segment_id,
        "desired_heading_offset_rad": heading_offset,
        "measured_yaw_rad": measured_yaw,
        "desired_heading_error_rad": heading_offset,
        "yaw_tracking_error_rad": measured_yaw - heading_offset,
        "requested_steering_fraction": requested,
        "held_steering_fraction": held,
        "steering_saturated": (
            abs(requested) >= 0.4 - 1.0e-12 or abs(held) >= 0.4 - 1.0e-12
        ),
        "torso_position_world_m": [semantic_step / CONTROLLER_STEPS, 0.4, 0.0],
        "torso_height_m": 0.4,
        "torso_tilt_rad": 0.1,
        "torso_ground_contact": False,
        "ordered_limb_phase_before": _synthetic_limb_phases(semantic_step),
        "ordered_foot_contacts_before": dict(contacts),
        "ordered_foot_contacts_after": dict(contacts),
        "validated_portable_command_count": ACTUATOR_COUNT,
        "native_actuation_application_count": ACTUATOR_COUNT,
        "oracle_passed": True,
    }


def synthetic_trace(cell: Cell) -> list[dict[str, Any]]:
    return [synthetic_trace_row(cell, step) for step in range(CONTROLLER_STEPS)]


def validate_trace(cell: Cell, rows: Any) -> dict[str, Any]:
    failures: list[str] = []
    if not isinstance(rows, list):
        return {
            "ok": False,
            "failure_codes": ["R23D3_TRACE_NOT_ARRAY"],
            "row_count": 0,
            "raw_sha256": None,
            "byte_length": 0,
            "segment_counts": {},
            "onset_snapshot": None,
            "steering_saturation_step_count": 0,
        }
    if len(rows) != CONTROLLER_STEPS:
        failures.append("R23D3_TRACE_ROW_COUNT")

    segment_counts = {
        "reference_warmup": 0,
        "commanded_turn": 0,
        "reference_recovery": 0,
        "after_declared_schedule": 0,
    }
    onset_snapshot: dict[str, Any] | None = None
    saturation_count = 0
    hasher = hashlib.sha256()
    byte_length = 0

    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"R23D3_TRACE_ROW_TYPE:{index}")
            continue
        try:
            encoded = _canonical_bytes(row)
        except (TypeError, ValueError, OverflowError):
            failures.append(f"R23D3_TRACE_CANONICALIZATION:{index}")
            encoded = b"R23D3_INVALID_CANONICAL_ROW"
        hasher.update(encoded)
        hasher.update(b"\n")
        byte_length += len(encoded) + 1
        if not _exact_keys(row, TRACE_ROW_FIELDS):
            failures.append(f"R23D3_TRACE_ROW_FIELDS:{index}")
            continue
        if (
            row["schema_version"] != TRACE_ROW_SCHEMA
            or row["cell_id"] != cell.cell_id
            or type(row["semantic_step"]) is not int
            or row["semantic_step"] != index
        ):
            failures.append(f"R23D3_TRACE_ROW_IDENTITY:{index}")
        expected_segment, expected_offset = segment_for_step(cell, index)
        if row["segment_id"] != expected_segment:
            failures.append(f"R23D3_TRACE_SEGMENT:{index}")
        else:
            segment_counts[expected_segment] += 1
        if not _finite_number(row["desired_heading_offset_rad"]) or not math.isclose(
            float(row["desired_heading_offset_rad"]),
            expected_offset,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ):
            failures.append(f"R23D3_TRACE_HEADING_OFFSET:{index}")
        for field in (
            "measured_yaw_rad",
            "desired_heading_error_rad",
            "yaw_tracking_error_rad",
            "requested_steering_fraction",
            "held_steering_fraction",
            "torso_height_m",
            "torso_tilt_rad",
        ):
            if not _finite_number(row[field]):
                failures.append(f"R23D3_TRACE_NONFINITE:{index}:{field}")
        position = row["torso_position_world_m"]
        if (
            not isinstance(position, list)
            or len(position) != 3
            or any(not _finite_number(value) for value in position)
        ):
            failures.append(f"R23D3_TRACE_TORSO_POSITION:{index}")
        for field in ("steering_saturated", "torso_ground_contact", "oracle_passed"):
            if not isinstance(row[field], bool):
                failures.append(f"R23D3_TRACE_BOOLEAN:{index}:{field}")
        expected_saturation = (
            _finite_number(row["requested_steering_fraction"])
            and _finite_number(row["held_steering_fraction"])
            and (
                abs(float(row["requested_steering_fraction"])) >= 0.4 - 1.0e-12
                or abs(float(row["held_steering_fraction"])) >= 0.4 - 1.0e-12
            )
        )
        if row["steering_saturated"] is not expected_saturation:
            failures.append(f"R23D3_TRACE_SATURATION:{index}")
        if row["steering_saturated"] is True:
            saturation_count += 1
        if row["oracle_passed"] is not True:
            failures.append(f"R23D3_TRACE_ORACLE:{index}")
        if any(
            type(row[field]) is not int or row[field] != ACTUATOR_COUNT
            for field in (
                "validated_portable_command_count",
                "native_actuation_application_count",
            )
        ):
            failures.append(f"R23D3_TRACE_APPLICATION_COUNT:{index}")

        limb_phases = row["ordered_limb_phase_before"]
        if not isinstance(limb_phases, list) or len(limb_phases) != 4:
            failures.append(f"R23D3_TRACE_LIMB_PHASE_COUNT:{index}")
        else:
            for phase_index, phase in enumerate(limb_phases):
                if not _exact_keys(phase, LIMB_PHASE_FIELDS):
                    failures.append(
                        f"R23D3_TRACE_LIMB_PHASE_FIELDS:{index}:{phase_index}"
                    )
                    continue
                if phase["limb_id"] != LIMB_IDS[phase_index]:
                    failures.append(
                        f"R23D3_TRACE_LIMB_ORDER:{index}:{phase_index}"
                    )
                gait_step = phase["gait_step"]
                release_hold = phase["release_hold_step_count"]
                if (
                    type(gait_step) is not int
                    or gait_step < 0
                    or type(release_hold) is not int
                    or release_hold < 0
                    or type(phase["local_phase_step"]) is not int
                ):
                    failures.append(
                        f"R23D3_TRACE_LIMB_COUNTER:{index}:{phase_index}"
                    )
                    continue
                expected_local = (
                    gait_step + GAIT_CYCLE_STEPS - PHASE_OFFSETS[phase_index]
                ) % GAIT_CYCLE_STEPS
                if phase["local_phase_step"] != expected_local:
                    failures.append(
                        f"R23D3_TRACE_LOCAL_PHASE:{index}:{phase_index}"
                    )

        for contact_field in (
            "ordered_foot_contacts_before",
            "ordered_foot_contacts_after",
        ):
            contacts = row[contact_field]
            if (
                not isinstance(contacts, dict)
                or set(contacts) != set(LIMB_IDS)
                or any(not isinstance(contacts[limb], bool) for limb in LIMB_IDS)
            ):
                failures.append(f"R23D3_TRACE_CONTACTS:{index}:{contact_field}")

        if index == cell.turn_start_semantic_step:
            onset_snapshot = {
                "semantic_step": index,
                "ordered_limb_phase_before": copy.deepcopy(limb_phases),
                "ordered_foot_contacts_before": copy.deepcopy(
                    row["ordered_foot_contacts_before"]
                ),
                "torso_position_world_m": copy.deepcopy(position),
                "measured_yaw_rad": row["measured_yaw_rad"],
                "requested_steering_fraction": row["requested_steering_fraction"],
                "held_steering_fraction": row["held_steering_fraction"],
            }

    if segment_counts != expected_segment_counts(cell):
        failures.append("R23D3_TRACE_SEGMENT_COUNTS")
    if onset_snapshot is None:
        failures.append("R23D3_TRACE_ONSET_SNAPSHOT")

    return {
        "ok": not failures,
        "failure_codes": failures,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hasher.hexdigest(),
        "byte_length": byte_length,
        "hash_projection": "sha256_canonical_sorted_key_ndjson_rows_v1",
        "segment_counts": segment_counts,
        "onset_snapshot": onset_snapshot,
        "steering_saturation_step_count": saturation_count,
    }


def _onset_snapshot_valid(cell: Cell, snapshot: Any) -> bool:
    if not _exact_keys(snapshot, ONSET_SNAPSHOT_FIELDS):
        return False
    if (
        type(snapshot["semantic_step"]) is not int
        or snapshot["semantic_step"] != cell.turn_start_semantic_step
    ):
        return False
    position = snapshot["torso_position_world_m"]
    if (
        not isinstance(position, list)
        or len(position) != 3
        or any(not _finite_number(value) for value in position)
    ):
        return False
    if any(
        not _finite_number(snapshot[field])
        for field in (
            "measured_yaw_rad",
            "requested_steering_fraction",
            "held_steering_fraction",
        )
    ):
        return False
    contacts = snapshot["ordered_foot_contacts_before"]
    if (
        not isinstance(contacts, dict)
        or set(contacts) != set(LIMB_IDS)
        or any(not isinstance(contacts[limb], bool) for limb in LIMB_IDS)
    ):
        return False
    phases = snapshot["ordered_limb_phase_before"]
    if not isinstance(phases, list) or len(phases) != len(LIMB_IDS):
        return False
    for index, phase in enumerate(phases):
        if not _exact_keys(phase, LIMB_PHASE_FIELDS):
            return False
        if phase["limb_id"] != LIMB_IDS[index]:
            return False
        if any(
            type(phase[field]) is not int or phase[field] < 0
            for field in (
                "gait_step",
                "local_phase_step",
                "release_hold_step_count",
            )
        ):
            return False
        expected_local = (
            phase["gait_step"] + GAIT_CYCLE_STEPS - PHASE_OFFSETS[index]
        ) % GAIT_CYCLE_STEPS
        if phase["local_phase_step"] != expected_local:
            return False
    return True


def projected_report(
    cell: Cell,
    trace_summary: dict[str, Any],
    *,
    walking_gate_passed: bool = True,
    turn_phase_yaw_delta_rad: float | None = None,
) -> dict[str, Any]:
    if turn_phase_yaw_delta_rad is None:
        turn_phase_yaw_delta_rad = (
            0.0
            if cell.arm_id == "reference_zero"
            else (0.1 if cell.turn_heading_offset_rad > 0.0 else -0.1)
        )
    signed_yaw_response_passed = _signed_yaw_response(
        cell, turn_phase_yaw_delta_rad
    )
    outcome_ok = walking_gate_passed and (
        cell.arm_id == "reference_zero" or signed_yaw_response_passed
    )
    return {
        "schema_version": PROJECTED_REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": cell.engine_id,
        "onset_id": cell.onset_id,
        "turn_start_semantic_step": cell.turn_start_semantic_step,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "trace_summary": copy.deepcopy(trace_summary),
        "execution": {
            "integrity_passed": bool(trace_summary.get("ok", False)),
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "validated_portable_command_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
            "native_actuation_application_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
            "world_attempt_count": 1,
            "world_build_count": 1,
        },
        "outcome": {
            "walking_gate_passed": walking_gate_passed,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "signed_yaw_response_passed": signed_yaw_response_passed,
            "outcome_gate_passed": outcome_ok,
            "failed_gate_ids": [] if outcome_ok else ["R23D3_SYNTHETIC_OUTCOME"],
        },
        "claims": {
            "physical_acceptance_authority": False,
            "q_sdk_r23_satisfied": False,
            "release_authorized": False,
        },
        "synthetic_zero_world_projection": True,
    }


def validate_projected_report(report: Any, cell: Cell) -> list[str]:
    failures: list[str] = []
    if not _exact_keys(report, PROJECTED_REPORT_FIELDS):
        return ["R23D3_REPORT_FIELDS"]
    if (
        report["schema_version"] != PROJECTED_REPORT_SCHEMA
        or report["campaign_id"] != CAMPAIGN_ID
        or report["gate_id"] != GATE_ID
        or report["stage_id"] != cell.stage_id
        or report["cell_id"] != cell.cell_id
        or report["engine_id"] != cell.engine_id
        or report["onset_id"] != cell.onset_id
        or report["turn_start_semantic_step"] != cell.turn_start_semantic_step
        or report["arm_id"] != cell.arm_id
        or not _finite_number(report["turn_heading_offset_rad"])
        or not math.isclose(
            float(report["turn_heading_offset_rad"]),
            cell.turn_heading_offset_rad,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        )
        or report["synthetic_zero_world_projection"] is not True
    ):
        failures.append("R23D3_REPORT_IDENTITY")

    trace = report["trace_summary"]
    if (
        not _exact_keys(trace, TRACE_SUMMARY_FIELDS)
        or trace.get("ok") is not True
        or trace.get("failure_codes") != []
        or trace.get("row_count") != CONTROLLER_STEPS
        or type(trace.get("row_count")) is not int
        or not _sha256_string(trace.get("raw_sha256"))
        or type(trace.get("byte_length")) is not int
        or trace.get("byte_length", 0) <= 0
        or trace.get("hash_projection")
        != "sha256_canonical_sorted_key_ndjson_rows_v1"
        or trace.get("segment_counts") != expected_segment_counts(cell)
        or not _onset_snapshot_valid(cell, trace.get("onset_snapshot"))
        or type(trace.get("steering_saturation_step_count")) is not int
        or not 0 <= trace.get("steering_saturation_step_count", -1) <= CONTROLLER_STEPS
    ):
        failures.append("R23D3_REPORT_TRACE_SUMMARY")
    execution = report["execution"]
    if (
        not _exact_keys(execution, EXECUTION_FIELDS)
        or execution.get("integrity_passed") is not True
        or any(
            type(execution.get(field)) is not int
            for field in EXECUTION_FIELDS
            if field != "integrity_passed"
        )
        or execution.get("controller_semantic_step_count") != CONTROLLER_STEPS
        or execution.get("validated_portable_command_count")
        != CONTROLLER_STEPS * ACTUATOR_COUNT
        or execution.get("native_actuation_application_count")
        != CONTROLLER_STEPS * ACTUATOR_COUNT
        or execution.get("world_attempt_count") != 1
        or execution.get("world_build_count") != 1
    ):
        failures.append("R23D3_REPORT_EXECUTION")
    outcome = report["outcome"]
    observed_yaw = outcome.get("turn_phase_yaw_delta_rad") if isinstance(outcome, dict) else None
    recomputed_signed_response = _signed_yaw_response(cell, observed_yaw)
    if (
        not _exact_keys(outcome, OUTCOME_FIELDS)
        or not isinstance(outcome.get("walking_gate_passed"), bool)
        or not _finite_number(observed_yaw)
        or not isinstance(outcome.get("signed_yaw_response_passed"), bool)
        or outcome.get("signed_yaw_response_passed") is not recomputed_signed_response
        or not isinstance(outcome.get("outcome_gate_passed"), bool)
        or not isinstance(outcome.get("failed_gate_ids"), list)
        or any(
            not isinstance(failure_id, str) or not failure_id
            for failure_id in outcome.get("failed_gate_ids", [])
        )
        or len(set(outcome.get("failed_gate_ids", [])))
        != len(outcome.get("failed_gate_ids", []))
        or outcome.get("outcome_gate_passed")
        is not (
            outcome.get("walking_gate_passed")
            and (
                cell.arm_id == "reference_zero"
                or outcome.get("signed_yaw_response_passed")
            )
        )
        or (outcome.get("outcome_gate_passed") and outcome.get("failed_gate_ids"))
        or (
            not outcome.get("outcome_gate_passed")
            and not outcome.get("failed_gate_ids")
        )
    ):
        failures.append("R23D3_REPORT_OUTCOME")
    claims = report["claims"]
    if (
        claims
        != {
            "physical_acceptance_authority": False,
            "q_sdk_r23_satisfied": False,
            "release_authorized": False,
        }
    ):
        failures.append("R23D3_REPORT_CLAIMS")
    return failures


def evaluate_stage_a(reports: Sequence[dict[str, Any]]) -> dict[str, Any]:
    cells = stage_a_cells()
    failures: list[str] = []
    if len(reports) != len(cells):
        failures.append("R23D3_STAGE_A_REPORT_COUNT")
    seen: set[str] = set()
    for index, cell in enumerate(cells):
        if index >= len(reports):
            failures.append(f"R23D3_STAGE_A_MISSING:{cell.cell_id}")
            continue
        report = reports[index]
        report_failures = validate_projected_report(report, cell)
        failures.extend(f"{failure}:{cell.cell_id}" for failure in report_failures)
        if isinstance(report, dict):
            cell_id = str(report.get("cell_id", ""))
            if cell_id in seen:
                failures.append(f"R23D3_STAGE_A_DUPLICATE:{cell_id}")
            seen.add(cell_id)
    if len(reports) > len(cells):
        failures.append("R23D3_STAGE_A_EXTRA_REPORT")
    if failures:
        return {
            "valid": False,
            "classification": "invalid_or_incomplete_stage_a",
            "selected_onset_id": "NONE",
            "eligible_onset_ids": [],
            "failure_codes": failures,
            "stage_b_launch_authorized": False,
            "projected_world_count": len(reports),
            "claims": _false_claims(),
        }

    eligible: list[str] = []
    for onset_id in ONSET_IDS:
        onset_reports = [report for report in reports if report["onset_id"] == onset_id]
        if (
            len(onset_reports) == 2
            and [report["arm_id"] for report in onset_reports] == list(ARM_IDS)
            and all(report["outcome"]["outcome_gate_passed"] for report in onset_reports)
        ):
            eligible.append(onset_id)
    selected = eligible[0] if eligible else "NONE"
    return {
        "valid": True,
        "classification": (
            "valid_selected_stage_a" if selected != "NONE" else "valid_none_stage_a"
        ),
        "selected_onset_id": selected,
        "eligible_onset_ids": eligible,
        "failure_codes": [],
        "stage_b_launch_authorized": selected != "NONE",
        "projected_world_count": 8,
        "claims": _false_claims(),
    }


def evaluate_stage_b(
    selected_onset_id: str,
    reports: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    cells = stage_b_cells(selected_onset_id)
    failures: list[str] = []
    outcome_failure_count = 0
    if len(reports) != len(cells):
        failures.append("R23D3_STAGE_B_REPORT_COUNT")
    seen: set[str] = set()
    for index, cell in enumerate(cells):
        if index >= len(reports):
            failures.append(f"R23D3_STAGE_B_MISSING:{cell.cell_id}")
            continue
        report = reports[index]
        report_failures = validate_projected_report(report, cell)
        failures.extend(f"{failure}:{cell.cell_id}" for failure in report_failures)
        if isinstance(report, dict):
            cell_id = str(report.get("cell_id", ""))
            if cell_id in seen:
                failures.append(f"R23D3_STAGE_B_DUPLICATE:{cell_id}")
            seen.add(cell_id)
            if not report_failures and not report["outcome"]["outcome_gate_passed"]:
                outcome_failure_count += 1
    if len(reports) > len(cells):
        failures.append("R23D3_STAGE_B_EXTRA_REPORT")
    if failures:
        return {
            "valid": False,
            "classification": "invalid_or_incomplete_complete",
            "outcome_failure_count": outcome_failure_count,
            "failure_codes": failures,
            "projected_world_count": len(reports),
            "claims": _false_claims(),
        }
    return {
        "valid": True,
        "classification": (
            "valid_positive_complete"
            if outcome_failure_count == 0
            else "valid_negative_complete"
        ),
        "outcome_failure_count": outcome_failure_count,
        "failure_codes": [],
        "projected_world_count": 9,
        "claims": _false_claims(),
    }


def evaluate_complete(
    stage_a_reports: Sequence[dict[str, Any]],
    stage_b_reports: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    stage_a = evaluate_stage_a(stage_a_reports)
    if not stage_a["valid"]:
        classification = "invalid_or_incomplete_stage_a"
        if stage_b_reports:
            stage_a["failure_codes"].append("R23D3_STAGE_B_OPENED_AFTER_INVALID_STAGE_A")
        return {
            "classification": classification,
            "stage_a": stage_a,
            "stage_b": None,
            "claims": _false_claims(),
        }
    if stage_a["selected_onset_id"] == "NONE":
        if stage_b_reports:
            return {
                "classification": "invalid_or_incomplete_complete",
                "stage_a": stage_a,
                "stage_b": {
                    "valid": False,
                    "failure_codes": ["R23D3_STAGE_B_OPENED_AFTER_VALID_NONE"],
                },
                "claims": _false_claims(),
            }
        return {
            "classification": "valid_none_stage_a",
            "stage_a": stage_a,
            "stage_b": None,
            "claims": _false_claims(),
        }
    stage_b = evaluate_stage_b(stage_a["selected_onset_id"], stage_b_reports)
    return {
        "classification": stage_b["classification"],
        "stage_a": stage_a,
        "stage_b": stage_b,
        "claims": _false_claims(),
    }


def _false_claims() -> dict[str, bool]:
    return {
        "command_conditioned_turning": False,
        "bilateral_signed_turning": False,
        "portable_basic_turning": False,
        "cross_engine_equivalence": False,
        "q_sdk_r23_satisfied": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def project_godot_execution_predicates(summary: Any) -> dict[str, Any]:
    expected = (
        ("sdk_summary_ok", "ok", True),
        ("sdk_failure_code_empty", "failure_code", ""),
        ("sdk_step_count", "step_count", CONTROLLER_STEPS),
        ("sdk_safe_no_actuation_count", "safe_no_actuation_count", 0),
        ("sdk_mismatch_count", "mismatch_count", 0),
        (
            "sdk_validated_command_count",
            "validated_balanced_wave_command_count",
            CONTROLLER_STEPS * ACTUATOR_COUNT,
        ),
        (
            "sdk_native_application_count",
            "native_actuation_application_count",
            CONTROLLER_STEPS * ACTUATOR_COUNT,
        ),
    )
    rows: list[dict[str, Any]] = []
    for predicate_id, field, expected_value in expected:
        present = isinstance(summary, dict) and field in summary
        observed = summary.get(field) if present else None
        rows.append(
            {
                "predicate_id": predicate_id,
                "source_path": f"sdk_authority_summary.{field}",
                "expected_value": copy.deepcopy(expected_value),
                "observed_value": copy.deepcopy(observed),
                "observed_value_type": _value_type(observed),
                "field_present": present,
                "passed": present and _strict_equal(observed, expected_value),
            }
        )
    return {
        "schema_version": GODOT_PREDICATE_SCHEMA,
        "ok": all(row["passed"] for row in rows),
        "failed_predicate_ids": [
            row["predicate_id"] for row in rows if not row["passed"]
        ],
        "ordered_predicates": rows,
        "raw_sdk_authority_summary": copy.deepcopy(summary),
        "physical_acceptance_authority": False,
    }


def _good_godot_summary() -> dict[str, Any]:
    return {
        "ok": True,
        "failure_code": "",
        "step_count": CONTROLLER_STEPS,
        "safe_no_actuation_count": 0,
        "mismatch_count": 0,
        "validated_balanced_wave_command_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
        "native_actuation_application_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    contract = load_contract()
    trace_summaries: dict[str, dict[str, Any]] = {}
    trace_row_count = 0
    trace_validation_count = 0

    all_cells = stage_a_cells(contract) + stage_b_cells("onset_600")
    for cell in all_cells:
        summary = validate_trace(cell, synthetic_trace(cell))
        if not summary["ok"]:
            raise R23D3Error(f"R23D3_SYNTHETIC_TRACE_INVALID:{cell.cell_id}")
        trace_summaries[cell.cell_id] = summary
        trace_row_count += summary["row_count"]
        trace_validation_count += 1

    trace_cell = stage_a_cells(contract)[0]
    trace_negative_controls: list[tuple[str, Any]] = []
    base_trace = synthetic_trace(trace_cell)

    missing_row = base_trace[:-1]
    trace_negative_controls.append(("missing_row", missing_row))
    wrong_step = copy.deepcopy(base_trace)
    wrong_step[10]["semantic_step"] = 11
    trace_negative_controls.append(("wrong_step", wrong_step))
    wrong_segment = copy.deepcopy(base_trace)
    wrong_segment[trace_cell.turn_start_semantic_step]["segment_id"] = "reference_warmup"
    trace_negative_controls.append(("wrong_segment", wrong_segment))
    wrong_offset = copy.deepcopy(base_trace)
    wrong_offset[trace_cell.turn_start_semantic_step]["desired_heading_offset_rad"] = -0.2
    trace_negative_controls.append(("wrong_offset", wrong_offset))
    wrong_phase = copy.deepcopy(base_trace)
    wrong_phase[0]["ordered_limb_phase_before"][1]["local_phase_step"] += 1
    trace_negative_controls.append(("wrong_local_phase", wrong_phase))
    wrong_contacts = copy.deepcopy(base_trace)
    del wrong_contacts[0]["ordered_foot_contacts_after"]["rear_right"]
    trace_negative_controls.append(("missing_contact", wrong_contacts))
    wrong_application = copy.deepcopy(base_trace)
    wrong_application[0]["native_actuation_application_count"] = 7
    trace_negative_controls.append(("wrong_application_count", wrong_application))
    wrong_oracle = copy.deepcopy(base_trace)
    wrong_oracle[0]["oracle_passed"] = False
    trace_negative_controls.append(("oracle_rejection", wrong_oracle))
    wrong_saturation = copy.deepcopy(base_trace)
    wrong_saturation[0]["steering_saturated"] = True
    trace_negative_controls.append(("wrong_saturation", wrong_saturation))
    nonfinite = copy.deepcopy(base_trace)
    nonfinite[0]["measured_yaw_rad"] = math.nan
    trace_negative_controls.append(("nonfinite", nonfinite))

    trace_negative_rejections = 0
    for control_id, rows in trace_negative_controls:
        result = validate_trace(trace_cell, rows)
        if result["ok"]:
            raise R23D3Error(f"R23D3_TRACE_NEGATIVE_ACCEPTED:{control_id}")
        trace_negative_rejections += 1

    stage_a_reports = [
        projected_report(cell, trace_summaries[cell.cell_id])
        for cell in stage_a_cells(contract)
    ]
    selected_first = evaluate_stage_a(stage_a_reports)
    if selected_first["selected_onset_id"] != "onset_600":
        raise R23D3Error("R23D3_SELECTOR_FIRST_CANARY_INVALID")

    fallback_reports = copy.deepcopy(stage_a_reports)
    for report in fallback_reports:
        if report["onset_id"] in ("onset_600", "onset_690"):
            report["outcome"]["walking_gate_passed"] = False
            report["outcome"]["outcome_gate_passed"] = False
            report["outcome"]["failed_gate_ids"] = ["R23D3_SYNTHETIC_OUTCOME"]
    fallback = evaluate_stage_a(fallback_reports)
    if fallback["selected_onset_id"] != "onset_780":
        raise R23D3Error("R23D3_SELECTOR_FALLBACK_CANARY_INVALID")

    none_reports = copy.deepcopy(stage_a_reports)
    for report in none_reports:
        if report["arm_id"] == "negative_heading":
            report["outcome"]["turn_phase_yaw_delta_rad"] = 0.0
            report["outcome"]["signed_yaw_response_passed"] = False
            report["outcome"]["outcome_gate_passed"] = False
            report["outcome"]["failed_gate_ids"] = ["R23D3_SYNTHETIC_OUTCOME"]
    none_result = evaluate_stage_a(none_reports)
    if (
        none_result["classification"] != "valid_none_stage_a"
        or none_result["stage_b_launch_authorized"]
    ):
        raise R23D3Error("R23D3_SELECTOR_NONE_CANARY_INVALID")

    invalid_reports = stage_a_reports[:-1]
    invalid_result = evaluate_stage_a(invalid_reports)
    if invalid_result["classification"] != "invalid_or_incomplete_stage_a":
        raise R23D3Error("R23D3_SELECTOR_INVALID_CANARY_INVALID")

    stage_b_reports = [
        projected_report(cell, trace_summaries[cell.cell_id])
        for cell in stage_b_cells("onset_600")
    ]
    complete_positive = evaluate_complete(stage_a_reports, stage_b_reports)
    if complete_positive["classification"] != "valid_positive_complete":
        raise R23D3Error("R23D3_COMPLETE_POSITIVE_CANARY_INVALID")

    complete_negative_reports = copy.deepcopy(stage_b_reports)
    complete_negative_reports[-1]["outcome"]["walking_gate_passed"] = False
    complete_negative_reports[-1]["outcome"]["outcome_gate_passed"] = False
    complete_negative_reports[-1]["outcome"]["failed_gate_ids"] = [
        "R23D3_SYNTHETIC_OUTCOME"
    ]
    complete_negative = evaluate_complete(
        stage_a_reports, complete_negative_reports
    )
    if complete_negative["classification"] != "valid_negative_complete":
        raise R23D3Error("R23D3_COMPLETE_NEGATIVE_CANARY_INVALID")

    none_complete = evaluate_complete(none_reports, [])
    if none_complete["classification"] != "valid_none_stage_a":
        raise R23D3Error("R23D3_COMPLETE_NONE_CANARY_INVALID")
    forbidden_stage_b = evaluate_complete(none_reports, stage_b_reports)
    if forbidden_stage_b["classification"] != "invalid_or_incomplete_complete":
        raise R23D3Error("R23D3_FORBIDDEN_STAGE_B_CANARY_INVALID")
    missing_stage_b = evaluate_complete(stage_a_reports, stage_b_reports[:-1])
    if missing_stage_b["classification"] != "invalid_or_incomplete_complete":
        raise R23D3Error("R23D3_MISSING_STAGE_B_CANARY_INVALID")

    good_godot = _good_godot_summary()
    good_projection = project_godot_execution_predicates(good_godot)
    if not good_projection["ok"]:
        raise R23D3Error("R23D3_GODOT_POSITIVE_CANARY_INVALID")
    godot_mutations = (
        ("sdk_summary_ok", "ok", False),
        ("sdk_failure_code_empty", "failure_code", "SDK_FAILURE"),
        ("sdk_step_count", "step_count", CONTROLLER_STEPS - 1),
        ("sdk_safe_no_actuation_count", "safe_no_actuation_count", 1),
        ("sdk_mismatch_count", "mismatch_count", 1),
        (
            "sdk_validated_command_count",
            "validated_balanced_wave_command_count",
            CONTROLLER_STEPS * ACTUATOR_COUNT - 1,
        ),
        (
            "sdk_native_application_count",
            "native_actuation_application_count",
            CONTROLLER_STEPS * ACTUATOR_COUNT - 1,
        ),
    )
    godot_mutation_rejections = 0
    for predicate_id, field, value in godot_mutations:
        mutated = copy.deepcopy(good_godot)
        mutated[field] = value
        projection = project_godot_execution_predicates(mutated)
        if projection["ok"] or projection["failed_predicate_ids"] != [predicate_id]:
            raise R23D3Error(
                f"R23D3_GODOT_PREDICATE_MUTATION_INVALID:{predicate_id}"
            )
        godot_mutation_rejections += 1

    receipt = {
        "schema_version": "sporespore_qsdk_r23d3_stage_zero_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "contract_raw_sha256": _raw_sha256(CONTRACT_PATH),
        "predecessor_closure_raw_sha256": _raw_sha256(R23D2_CLOSURE_PATH),
        "stage_a_cell_count": 8,
        "stage_b_projected_cell_count": 9,
        "trace_validation_count": trace_validation_count,
        "trace_row_validation_count": trace_row_count,
        "trace_negative_control_rejection_count": trace_negative_rejections,
        "selector_canary_pass_count": 4,
        "complete_evaluation_canary_pass_count": 5,
        "godot_execution_predicate_count": 7,
        "godot_execution_predicate_mutation_rejection_count": (
            godot_mutation_rejections
        ),
        "godot_fixed_horizon_requirement_preregistered": True,
        "godot_fixed_horizon_controller_step_count": CONTROLLER_STEPS,
        "godot_fixed_horizon_zero_world_worker_preflight_implemented": False,
        "godot_fixed_horizon_physical_worker_implemented": False,
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
    return receipt


def main(argv: Sequence[str]) -> int:
    if list(argv) != ["preflight"]:
        print("usage: r23d3_phase_balanced.py preflight", file=sys.stderr)
        return 2
    try:
        receipt = run_zero_world_preflight()
    except (R23D3Error, ValueError, TypeError, OverflowError) as error:
        print(f"QSDK_R23D3_STAGE_ZERO_FAILURE {type(error).__name__}:{error}")
        return 1
    print(
        "QSDK_R23D3_STAGE_ZERO_PREFLIGHT "
        + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
