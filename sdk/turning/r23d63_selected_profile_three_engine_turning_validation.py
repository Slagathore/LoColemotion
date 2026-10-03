#!/usr/bin/env python3
"""Prospective design and mutation audit for QSDK-R23D63.

R23D63 is a finite decision on one fresh deterministic perturbation.  It joins
the R23D60 policy/schedule/measurement semantics to the exact public actuator
profile closed by R23D61 and requires the same nine-cell matrix in genuine
Godot/Jolt, Rapier/Parry, and MuJoCo physics.  This module constructs no model
or world and grants no physical authorization.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable, Sequence


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
CAMPAIGN_ID = "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
GATE_ID = "QSDK-R23D63"
QUESTION_CLASS = "finite_decision"
STAGE_ID = "receipt_schema_repaired_selected_profile_matched_three_engine_turning_validation"
CAMPAIGN_SEED = 23_169
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
DESCRIPTOR_SHA256 = "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
MORPHOLOGY_SPEC_SHA256 = "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
PROFILE_SHA256 = "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
PROFILE_SEMANTICS_ID = "sporespore_outer_control_step_angular_impulse_budget_120hz_v1"
POLICY_ID = "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1"
TASK_ORIGIN_POLICY_ID = "warmup_preserving_command_onset_origin_reanchor_v1"
STARTUP_TRANSFORM_ID = "support_loss_latched_smoothstep_one_cycle_v1"
CONTROLLER_STEPS = 2_992
ACTUATOR_COUNT = 8
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
RECOVERY_DURATION_STEPS = 600
ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = (
    ("reference_zero", 0.0),
    ("positive_heading", 0.2),
    ("negative_heading", -0.2),
)
INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.00007932152220746502,
    "fixture_yaw_rad": 0.002175381872802973,
    "initial_linear_velocity_world_m_s": [
        0.002873786259442568,
        0.0,
        -0.0036080731078982353,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.00014649319928139448,
        0.002177086193114519,
        0.0017654569819569588,
    ],
    "gait_phase_offset_ticks": 1,
}
ORDERED_CAPS_NMS = (
    0.05362625170687301,
    0.4567500054836273,
    0.05362625170687301,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
)
ORDERED_CAPS_BINARY64_HEX = (
    "0x3fab74e66a937fb7",
    "0x3fdd3b6460000000",
    "0x3fab74e66a937fb7",
    "0x3fdd3b6460000000",
    "0x3facdd051a8b389b",
    "0x3fdd3b6460000000",
    "0x3facdd051a8b389b",
    "0x3fdd3b6460000000",
)
HOST_MAPPING_IDS = {
    "godot_jolt": "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1",
    "rapier_parry": "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1",
    "mujoco": "sporespore_mujoco_velocity_force_range_cap_mapping_v1",
}
R23D31_CLOSURE = ROOT / "r23d31_cycle_integrated_directional_response_closure_v1.json"
R23D48_CLOSURE = ROOT / "r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
R23D50_CLOSURE = ROOT / "r23d50_rapier_cas_path_identity_replay_closure_v1.json"
R23D60_CLOSURE = ROOT / "r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json"
R23D61_CONTRACT = ROOT / "r23d61_selected_actuator_profile_publication_v1.json"
R23D61_CLOSURE = ROOT / "r23d61_selected_actuator_profile_publication_closure_v1.json"
R23D62_CLOSURE = ROOT / "r23d62_selected_profile_three_engine_turning_validation_closure_v1.json"
R23D62_CLOSURE_AUDIT = REPO_ROOT / "tests/test_qsdk_r23d62_physical_closure.ps1"
DECLARATION_PARENT_COMMIT = "11eb2d3918d8f254d07b3ee7fe99dd51957b82f1"
DECLARATION_PARENT_TREE = "91a597da16ffdc871641939c302bc5a4082208d1"
R23D62_CLOSURE_SHA256 = "sha256:b23bae4fc87ec934d6ab4cb4f753ce8eb74a96d932ca7e7735cbb1e5d352730e"
R23D62_CLOSURE_AUDIT_SHA256 = "sha256:df1fc1a09e1f8b632efb6590148645014e83824c0dc4e625991788bbed6d29ab"
EXPECTED_SOURCE_HASHES = {
    "sdk/turning/r23d31_cycle_integrated_directional_response_closure_v1.json": "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c",
    "sdk/turning/r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json": "sha256:5b2ce3553a78836035c6a7b6ff11ee585cb615f0ebcc70341902e7bca58b7063",
    "sdk/turning/r23d50_rapier_cas_path_identity_replay_closure_v1.json": "sha256:47bee3d69965e2ffc79fae820223be3bfdfb001fa9fa2d2bc7ee7620ca0e9f48",
    "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json": "sha256:910fd0ba2369a889430c1228f2eaea1146cf26005c4ac51f353803869d709fd8",
    "sdk/turning/r23d61_selected_actuator_profile_publication_v1.json": "sha256:a9bf3f1a780cced8f3cdbf00642c7a2e17c6a3df9e3651791b380f0b8c8b2b9e",
    "sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json": "sha256:2cc44221fa1e594d630f249af26b6343921684bca5f8791c83c8ad36660fbd2f",
    "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_closure_v1.json": R23D62_CLOSURE_SHA256,
}


class DeclarationError(ValueError):
    """Raised when any prospective declaration identity changes."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    campaign_seed: int
    profile_id: str
    arm_id: str
    turn_heading_offset_rad: float
    host_mapping_id: str


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DeclarationError(f"QSDK_R23D63_DECLARATION_{code}")


def cells() -> tuple[Cell, ...]:
    return tuple(
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"{engine_id}__s{CAMPAIGN_SEED}__selected_profile__{arm_id}",
            engine_id=engine_id,
            campaign_seed=CAMPAIGN_SEED,
            profile_id=PROFILE_ID,
            arm_id=arm_id,
            turn_heading_offset_rad=offset,
            host_mapping_id=HOST_MAPPING_IDS[engine_id],
        )
        for engine_id in ENGINES
        for arm_id, offset in ARMS
    )


def cell(engine_id: str, arm_id: str) -> Cell:
    matches = [item for item in cells() if item.engine_id == engine_id and item.arm_id == arm_id]
    _require(len(matches) == 1, "CELL_INVALID")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    _require(0 <= semantic_step < CONTROLLER_STEPS, "SEMANTIC_STEP_INVALID")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", item.turn_heading_offset_rad
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts() -> dict[str, int]:
    return {
        "reference_warmup": 600,
        "commanded_turn": 1_200,
        "reference_recovery": 600,
        "after_declared_schedule": 592,
    }


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), "JSON_ROOT_INVALID")
    return value


def validate_declaration(value: dict[str, Any]) -> None:
    _require(value.get("schema_version") == "sporespore_qsdk_r23d63_selected_profile_three_engine_turning_validation_preregistration_v1", "SCHEMA_INVALID")
    _require(value.get("status") == "prospective_zero_world_only_physical_not_opened", "STATUS_INVALID")
    _require(value.get("campaign_id") == CAMPAIGN_ID, "CAMPAIGN_INVALID")
    _require(value.get("gate_id") == GATE_ID, "GATE_INVALID")
    _require(value.get("question_class") == QUESTION_CLASS, "QUESTION_CLASS_INVALID")
    _require(value.get("physical_question_declared") is True, "QUESTION_NOT_DECLARED")
    _require(value.get("physical_campaign_opened") is False, "CAMPAIGN_ALREADY_OPENED")

    lineage = value.get("immutable_lineage", {})
    _require(lineage.get("declaration_parent_commit") == DECLARATION_PARENT_COMMIT, "PARENT_COMMIT_INVALID")
    _require(lineage.get("declaration_parent_tree_git_oid") == DECLARATION_PARENT_TREE, "PARENT_TREE_INVALID")
    _require(lineage.get("historical_result_reinterpreted") is False, "HISTORICAL_REINTERPRETATION")
    _require(lineage.get("historical_world_reused_as_r23d63_cell") is False, "HISTORICAL_WORLD_REUSED")
    _require(lineage.get("r23d63_seed_had_prior_repository_occurrence") is False, "SEED_NOT_FRESH")
    _require(lineage.get("r23d63_seed_identity_occurrence_count_at_parent_commit") == 0, "SEED_PARENT_OCCURRENCE_INVALID")
    for relative, digest in EXPECTED_SOURCE_HASHES.items():
        _require(lineage.get("source_hashes", {}).get(relative) == digest, "LINEAGE_HASH_INVALID")
        _require(raw_sha256(REPO_ROOT / relative) == digest, "LIVE_LINEAGE_HASH_INVALID")

    predecessor = value.get("predecessor_closure", {})
    _require(predecessor.get("gate_id") == "QSDK-R23D62", "PREDECESSOR_GATE_INVALID")
    _require(predecessor.get("closure_raw_sha256") == R23D62_CLOSURE_SHA256, "PREDECESSOR_CLOSURE_HASH_INVALID")
    _require(predecessor.get("closure_audit_raw_sha256") == R23D62_CLOSURE_AUDIT_SHA256, "PREDECESSOR_AUDIT_HASH_INVALID")
    _require(raw_sha256(R23D62_CLOSURE) == R23D62_CLOSURE_SHA256, "LIVE_PREDECESSOR_CLOSURE_INVALID")
    _require(raw_sha256(R23D62_CLOSURE_AUDIT) == R23D62_CLOSURE_AUDIT_SHA256, "LIVE_PREDECESSOR_AUDIT_INVALID")
    _require(predecessor.get("campaign_identity_consumed") is True, "PREDECESSOR_NOT_CONSUMED")
    _require(predecessor.get("physical_outcome_exposed") is False, "PREDECESSOR_OUTCOME_EXPOSED")
    _require(predecessor.get("world_build_count") == 0, "PREDECESSOR_WORLD_COUNT_INVALID")
    _require(predecessor.get("turning_result_observed") is False, "PREDECESSOR_TURNING_RESULT_REWRITTEN")
    _require(predecessor.get("same_identity_repair_or_rerun_permitted") is False, "PREDECESSOR_RERUN_PERMITTED")

    change = value.get("successor_change_budget", {})
    _require(change.get("scientifically_distinct_successor_required") is True, "DISTINCT_SUCCESSOR_NOT_REQUIRED")
    _require(change.get("fresh_pre_outcome_seed_and_perturbation_required") is True, "FRESH_SEED_NOT_REQUIRED")
    _require(change.get("allowed_mechanism_changes") == [
        "production_authorization_receipt_complete_matrix_proof_projection",
        "pre_attempt_three_engine_receipt_schema_parity_and_mutation_gate",
        "named_supervisor_receipt_schema_failure_diagnostic",
    ], "CHANGE_BUDGET_INVALID")
    for key in (
        "selected_public_profile_preserved",
        "controller_and_policy_semantics_preserved",
        "physics_and_native_engine_bindings_preserved",
        "schedule_task_origin_startup_and_measurement_preserved",
        "common_physical_thresholds_preserved",
        "turning_thresholds_preserved",
        "selector_evaluator_and_interpretation_preserved",
    ):
        _require(change.get(key) is True, f"CHANGE_BUDGET_{key.upper()}_INVALID")
    _require(change.get("historical_result_or_interpretation_rewritten") is False, "HISTORICAL_RESULT_REWRITTEN")

    receipt_schema = value.get("authorization_receipt_schema_conformance", {})
    _require(receipt_schema.get("question_class") == "equivalence_non_inferiority", "RECEIPT_QUESTION_CLASS_INVALID")
    _require(receipt_schema.get("producer_ids") == list(ENGINES), "RECEIPT_PRODUCER_POPULATION_INVALID")
    _require(receipt_schema.get("declared_producer_count") == 3, "RECEIPT_PRODUCER_COUNT_INVALID")
    _require(receipt_schema.get("required_conforming_producer_count") == 3, "RECEIPT_ACCEPTANCE_COUNT_INVALID")
    _require(receipt_schema.get("required_field") == "complete_ordered_nine_cell_matrix_validated", "RECEIPT_FIELD_INVALID")
    _require(receipt_schema.get("required_json_type") == "boolean", "RECEIPT_TYPE_INVALID")
    _require(receipt_schema.get("required_value") is True, "RECEIPT_VALUE_INVALID")
    _require(receipt_schema.get("equivalence_margin") == 0, "RECEIPT_EQUIVALENCE_MARGIN_INVALID")
    _require(receipt_schema.get("non_inferiority_margin") == 0, "RECEIPT_NON_INFERIORITY_MARGIN_INVALID")
    _require(receipt_schema.get("sampling_used") is False, "RECEIPT_SAMPLING_INVALID")
    _require(receipt_schema.get("negative_control_count_per_engine") == 4, "RECEIPT_CONTROL_COUNT_INVALID")
    _require(receipt_schema.get("total_negative_control_count") == 12, "RECEIPT_TOTAL_CONTROL_COUNT_INVALID")
    _require(receipt_schema.get("actual_production_composer_required_per_engine") is True, "RECEIPT_PRODUCTION_COMPOSER_NOT_REQUIRED")
    _require(receipt_schema.get("must_pass_before_physical_freeze") is True, "RECEIPT_GATE_AFTER_FREEZE")
    _require(receipt_schema.get("must_pass_before_attempt_authorization") is True, "RECEIPT_GATE_AFTER_ATTEMPT")
    _require(receipt_schema.get("physical_equivalence_claimed") is False, "PHYSICAL_EQUIVALENCE_SMUGGLED")

    profile = value.get("published_profile_binding", {})
    _require(profile.get("profile_id") == PROFILE_ID, "PROFILE_ID_INVALID")
    _require(profile.get("profile_sha256") == PROFILE_SHA256, "PROFILE_SHA_INVALID")
    _require(profile.get("morphology_id") == MORPHOLOGY_ID, "MORPHOLOGY_INVALID")
    _require(profile.get("descriptor_sha256") == DESCRIPTOR_SHA256, "DESCRIPTOR_INVALID")
    _require(profile.get("morphology_spec_sha256") == MORPHOLOGY_SPEC_SHA256, "MORPHOLOGY_SPEC_INVALID")
    _require(profile.get("semantics_id") == PROFILE_SEMANTICS_ID, "PROFILE_SEMANTICS_INVALID")
    _require(tuple(profile.get("ordered_caps_nms", [])) == ORDERED_CAPS_NMS, "CAP_VECTOR_INVALID")
    _require(tuple(profile.get("ordered_caps_binary64_hex", [])) == ORDERED_CAPS_BINARY64_HEX, "CAP_BITS_INVALID")
    _require(profile.get("public_resolution_required_in_each_worker") is True, "PUBLIC_PROFILE_NOT_REQUIRED")
    _require(profile.get("legacy_fixture_override_permitted") is False, "LEGACY_OVERRIDE_PERMITTED")

    matrix = value.get("frozen_matrix", {})
    _require(matrix.get("stage_id") == STAGE_ID, "STAGE_INVALID")
    _require(tuple(matrix.get("ordered_engine_ids", [])) == ENGINES, "ENGINE_ORDER_INVALID")
    _require(tuple(matrix.get("ordered_arm_ids", [])) == tuple(item[0] for item in ARMS), "ARM_ORDER_INVALID")
    _require(tuple(matrix.get("ordered_heading_offsets_rad", [])) == tuple(item[1] for item in ARMS), "ARM_OFFSET_INVALID")
    _require(matrix.get("declared_cell_count") == 9 and matrix.get("declared_world_count") == 9, "MATRIX_COUNT_INVALID")
    _require(matrix.get("seed") == CAMPAIGN_SEED, "SEED_INVALID")
    _require(matrix.get("initial_perturbation") == INITIAL_PERTURBATION, "PERTURBATION_INVALID")
    _require(matrix.get("morphology_id") == MORPHOLOGY_ID, "MATRIX_MORPHOLOGY_INVALID")
    _require(matrix.get("controller_policy_id") == POLICY_ID, "POLICY_INVALID")
    _require(matrix.get("task_frame_origin_policy_id") == TASK_ORIGIN_POLICY_ID, "TASK_ORIGIN_INVALID")
    _require(matrix.get("startup_transform_id") == STARTUP_TRANSFORM_ID, "STARTUP_TRANSFORM_INVALID")
    _require(matrix.get("controller_step_count") == CONTROLLER_STEPS, "HORIZON_INVALID")
    _require(matrix.get("turn_start_step") == TURN_START_STEP, "TURN_START_INVALID")
    _require(matrix.get("turn_end_step_exclusive") == TURN_END_STEP_EXCLUSIVE, "TURN_END_INVALID")
    _require(matrix.get("recovery_duration_steps") == RECOVERY_DURATION_STEPS, "RECOVERY_INVALID")
    _require(matrix.get("expected_reanchor_semantic_steps") == [600, 1800, 2400], "REANCHOR_INVALID")
    _require(matrix.get("serial_execution_required") is True, "SERIAL_EXECUTION_NOT_REQUIRED")
    _require(matrix.get("fresh_world_required_per_cell") is True, "FRESH_WORLD_NOT_REQUIRED")
    _require(matrix.get("all_cells_run_regardless_of_intermediate_outcome") is True, "EARLY_STOP_PERMITTED")
    _require(matrix.get("engine_identity_is_policy_input") is False, "ENGINE_POLICY_BRANCH")
    _require(matrix.get("arm_identity_is_policy_input") is False, "ARM_POLICY_BRANCH")
    _require(matrix.get("host_mapping_ids") == HOST_MAPPING_IDS, "HOST_MAPPING_INVALID")
    _require(matrix.get("cells") == [asdict(item) for item in cells()], "CELLS_INVALID")

    r60 = load_json(R23D60_CLOSURE)["threshold_margin_and_cohort_provenance"]
    gates = value.get("frozen_common_physical_gates", {})
    for key in (
        "minimum_final_forward_displacement_m",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
        "minimum_contact_cycles_per_limb",
        "maximum_torso_ground_contact_step_count",
        "maximum_controller_error_count",
        "maximum_safe_no_actuation_count",
        "maximum_nonfinite_observation_count",
        "maximum_actuator_application_mismatch_count",
        "exact_controller_semantic_step_count",
        "exact_validated_portable_command_count",
        "exact_native_actuation_application_count",
        "maximum_portable_impulse_violation_count",
    ):
        _require(gates.get(key) == r60.get(key), f"COMMON_GATE_{key.upper()}_INVALID")
    measure = value.get("cycle_integrated_measurement", {})
    _require(measure.get("minimum_raw_signed_cycle_shift_rad") == 0.01, "RAW_FLOOR_INVALID")
    _require(measure.get("minimum_reference_conditioned_cycle_shift_rad") == 0.01, "CONDITIONED_FLOOR_INVALID")
    _require(measure.get("both_signed_arms_required") is True and measure.get("reference_arm_required") is True, "TURNING_CONJUNCTION_INVALID")

    rule = value.get("finite_decision_rule", {})
    _require(rule.get("complete_execution_valid_nine_cell_matrix_required") is True, "COMPLETE_MATRIX_NOT_REQUIRED")
    _require(rule.get("all_nine_cells_must_pass_every_common_physical_gate") is True, "COMMON_CONJUNCTION_INVALID")
    _require(rule.get("each_engine_must_independently_pass_both_turning_gates") is True, "ENGINE_TURNING_CONJUNCTION_INVALID")
    _require(rule.get("positive_classification") == "valid_complete_positive_exact_matched_three_engine_portable_turning_validation", "POSITIVE_CLASS_INVALID")
    _require(rule.get("negative_classification") == "valid_complete_negative_exact_matched_three_engine_portable_turning_validation", "NEGATIVE_CLASS_INVALID")
    _require(rule.get("invalid_or_incomplete_classification") == "invalid_or_incomplete_exact_matched_three_engine_portable_turning_validation", "INVALID_CLASS_INVALID")
    _require(rule.get("early_stop_or_selective_rerun_permitted") is False, "SELECTIVE_RERUN_PERMITTED")
    _require(rule.get("positive_qsdk_r23_transition_permitted") is True, "R23_TRANSITION_NOT_DECLARED")
    _require(rule.get("positive_cross_engine_equivalence") is False, "EQUIVALENCE_SMUGGLED")

    adequacy = value.get("threshold_margin_and_cohort_provenance", {})
    _require(adequacy.get("seed_selected_before_any_r23d63_outcome") is True, "SEED_PROVENANCE_INVALID")
    _require(adequacy.get("adequate_for_exact_finite_three_engine_fixture_claim_only") is True, "COHORT_ADEQUACY_INVALID")
    _require(adequacy.get("stochastic_repeatability_rate_estimated") is False, "REPEATABILITY_SMUGGLED")
    _require(adequacy.get("cross_engine_equivalence_attempted") is False, "EQUIVALENCE_ATTEMPTED")
    _require(adequacy.get("population_inference_attempted") is False, "POPULATION_SMUGGLED")
    _require(adequacy.get("new_outcome_threshold_count") == 0, "NEW_THRESHOLD_INTRODUCED")

    implementation = value.get("implementation_and_execution_requirements", {})
    _require(implementation.get("complete_zero_world_gate_and_negative_controls_required") is True, "ZERO_WORLD_GATE_NOT_REQUIRED")
    _require(implementation.get("authorization_receipt_schema_conformance_gate_required") is True, "RECEIPT_SCHEMA_GATE_NOT_REQUIRED")
    _require(implementation.get("authorization_receipt_schema_conformance_gate_must_precede_freeze") is True, "RECEIPT_SCHEMA_GATE_AFTER_FREEZE")
    _require(implementation.get("authorization_receipt_schema_conformance_gate_must_precede_attempt_authorization") is True, "RECEIPT_SCHEMA_GATE_AFTER_ATTEMPT")
    _require(implementation.get("three_separate_native_workers_required") is True, "NATIVE_WORKERS_NOT_REQUIRED")
    _require(implementation.get("clean_pushed_qualification_and_separate_adoption_required") is True, "QUALIFICATION_NOT_REQUIRED")
    _require(implementation.get("physical_world_may_open_from_this_declaration_alone") is False, "DECLARATION_AUTHORIZES_PHYSICS")

    claims = value.get("claims", {})
    true_claims = {key for key, item in claims.items() if item is True}
    _require(true_claims == {"r23d63_preregistered"}, "CLAIM_BOUNDARY_INVALID")


Mutation = tuple[str, Callable[[dict[str, Any]], None]]


def _set(path: Sequence[str], value: Any) -> Callable[[dict[str, Any]], None]:
    def mutate(target: dict[str, Any]) -> None:
        cursor: dict[str, Any] = target
        for key in path[:-1]:
            cursor = cursor[key]
        cursor[path[-1]] = value

    return mutate


def mutation_controls() -> tuple[Mutation, ...]:
    return (
        ("campaign", _set(("campaign_id",), "mutated")),
        ("class", _set(("question_class",), "development")),
        ("opened", _set(("physical_campaign_opened",), True)),
        ("parent", _set(("immutable_lineage", "declaration_parent_commit"), "0" * 40)),
        ("parent_tree", _set(("immutable_lineage", "declaration_parent_tree_git_oid"), "0" * 40)),
        ("history", _set(("immutable_lineage", "historical_result_reinterpreted"), True)),
        ("predecessor_rerun", _set(("predecessor_closure", "same_identity_repair_or_rerun_permitted"), True)),
        ("change_budget", _set(("successor_change_budget", "turning_thresholds_preserved"), False)),
        ("receipt_population", _set(("authorization_receipt_schema_conformance", "required_conforming_producer_count"), 2)),
        ("receipt_field", _set(("authorization_receipt_schema_conformance", "required_field"), "alias")),
        ("receipt_type", _set(("authorization_receipt_schema_conformance", "required_json_type"), "string")),
        ("receipt_margin", _set(("authorization_receipt_schema_conformance", "equivalence_margin"), 1)),
        ("receipt_before_attempt", _set(("authorization_receipt_schema_conformance", "must_pass_before_attempt_authorization"), False)),
        ("profile", _set(("published_profile_binding", "profile_id"), "mutated")),
        ("profile_sha", _set(("published_profile_binding", "profile_sha256"), "sha256:" + "0" * 64)),
        ("caps", lambda v: v["published_profile_binding"]["ordered_caps_nms"].__setitem__(1, 0.1)),
        ("cap_bits", lambda v: v["published_profile_binding"]["ordered_caps_binary64_hex"].__setitem__(0, "0x0")),
        ("fallback", _set(("published_profile_binding", "legacy_fixture_override_permitted"), True)),
        ("engines", lambda v: v["frozen_matrix"]["ordered_engine_ids"].reverse()),
        ("arms", lambda v: v["frozen_matrix"]["ordered_arm_ids"].reverse()),
        ("offset", lambda v: v["frozen_matrix"]["ordered_heading_offsets_rad"].__setitem__(1, 0.21)),
        ("seed", _set(("frozen_matrix", "seed"), 23_168)),
        ("perturbation", _set(("frozen_matrix", "initial_perturbation", "fixture_yaw_rad"), 0.0)),
        ("policy", _set(("frozen_matrix", "controller_policy_id"), "mutated")),
        ("origin", _set(("frozen_matrix", "task_frame_origin_policy_id"), "mutated")),
        ("startup", _set(("frozen_matrix", "startup_transform_id"), "mutated")),
        ("horizon", _set(("frozen_matrix", "controller_step_count"), 2_991)),
        ("reanchor", lambda v: v["frozen_matrix"]["expected_reanchor_semantic_steps"].pop()),
        ("host_mapping", _set(("frozen_matrix", "host_mapping_ids", "rapier_parry"), "mutated")),
        ("drop_cell", lambda v: v["frozen_matrix"]["cells"].pop()),
        ("reorder_cells", lambda v: v["frozen_matrix"]["cells"].reverse()),
        ("cell_engine", _set(("frozen_matrix", "cells", "0", "engine_id"), "mutated")),
        ("forward_gate", _set(("frozen_common_physical_gates", "minimum_final_forward_displacement_m"), 0.0)),
        ("tilt_gate", _set(("frozen_common_physical_gates", "maximum_tilt_rad"), 0.7)),
        ("raw_floor", _set(("cycle_integrated_measurement", "minimum_raw_signed_cycle_shift_rad"), 0.0)),
        ("conditioned_floor", _set(("cycle_integrated_measurement", "minimum_reference_conditioned_cycle_shift_rad"), 0.0)),
        ("early_stop", _set(("finite_decision_rule", "early_stop_or_selective_rerun_permitted"), True)),
        ("equivalence", _set(("finite_decision_rule", "positive_cross_engine_equivalence"), True)),
        ("population", _set(("threshold_margin_and_cohort_provenance", "population_inference_attempted"), True)),
        ("zero_world", _set(("implementation_and_execution_requirements", "complete_zero_world_gate_and_negative_controls_required"), False)),
        ("physical_from_declaration", _set(("implementation_and_execution_requirements", "physical_world_may_open_from_this_declaration_alone"), True)),
        ("turning_claim", _set(("claims", "finite_three_engine_turning"), True)),
        ("release_claim", _set(("claims", "release_authorized"), True)),
    )


def run_mutation_controls(value: dict[str, Any]) -> int:
    rejected = 0
    for name, mutate in mutation_controls():
        candidate = copy.deepcopy(value)
        if name == "cell_engine":
            candidate["frozen_matrix"]["cells"][0]["engine_id"] = "mutated"
        else:
            mutate(candidate)
        try:
            validate_declaration(candidate)
        except (DeclarationError, KeyError, TypeError, IndexError):
            rejected += 1
        else:
            raise DeclarationError(f"QSDK_R23D63_MUTATION_ACCEPTED:{name}")
    return rejected


def audit(path: Path) -> dict[str, Any]:
    value = load_json(path)
    validate_declaration(value)
    rejected = run_mutation_controls(value)
    _require(rejected == len(mutation_controls()), "MUTATION_COUNT_INVALID")
    schedule = [segment_for_step(cells()[0], step)[0] for step in range(CONTROLLER_STEPS)]
    counts = {name: schedule.count(name) for name in expected_segment_counts()}
    _require(counts == expected_segment_counts(), "SCHEDULE_COUNTS_INVALID")
    _require(all(math.isfinite(value) and value > 0.0 for value in ORDERED_CAPS_NMS), "CAP_NONFINITE")
    return {
        "schema_version": "sporespore_qsdk_r23d63_declaration_audit_receipt_v1",
        "question_class": QUESTION_CLASS,
        "engine_count": len(ENGINES),
        "arm_count_per_engine": len(ARMS),
        "cell_count": len(cells()),
        "reserved_seed": CAMPAIGN_SEED,
        "profile_id": PROFILE_ID,
        "mutation_rejection_count": rejected,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_campaign_opened": False,
        "finite_three_engine_turning": False,
        "q_sdk_r23_satisfied": False,
        "cross_engine_equivalence": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--declaration",
        type=Path,
        default=ROOT / "r23d63_selected_profile_three_engine_turning_validation_preregistration_v1.json",
    )
    args = parser.parse_args(argv)
    try:
        receipt = audit(args.declaration)
    except (OSError, json.JSONDecodeError, DeclarationError) as error:
        print(f"QSDK_R23D63_DECLARATION_FAILURE {error}")
        return 1
    print("QSDK_R23D63_DECLARATION_PASS " + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
