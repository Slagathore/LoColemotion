#!/usr/bin/env python3
"""Compact prospective declaration audit for QSDK-R23D66.

R23D66 is a finite held-out decision over one exact deterministic fixture,
three native engines, and three command arms. This module validates the frozen
question and a compact one-mutation-per-surface control set. It constructs no
model or world and grants no physical authorization.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Callable, Sequence


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
DECLARATION = ROOT / "r23d66_production_route_three_engine_turning_validation_preregistration_v1.json"
CAMPAIGN_ID = (
    "QSDK-R23D66-PRODUCTION-ROUTE-QUALIFIED-SELECTED-PROFILE-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D66"
RELEASE_GATE_ID = "QSDK-R23"
PARENT_COMMIT = "e2fc35e8c247f7706ca8f41d58acb21843d5ae3f"
PARENT_TREE = "ca2f63c3073c1ad2e7872b1b6fd138f497fdb37d"
CAMPAIGN_SEED = 23_179
ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = (
    ("reference_zero", 0.0),
    ("positive_heading", 0.2),
    ("negative_heading", -0.2),
)
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
RECOVERY_DURATION_STEPS = 600
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
PROFILE_SHA256 = "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
POLICY_ID = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_"
    "predictive_stability_guarded_steering_v1"
)
INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.0007091651204973459,
    "fixture_yaw_rad": -0.005476593039929867,
    "initial_linear_velocity_world_m_s": [
        0.00007717916741967201,
        0.0,
        -0.0024514873512089252,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.0003892438253387809,
        -0.0025603838730603456,
        0.0014470412861555815,
    ],
    "gait_phase_offset_ticks": -2,
}
COMMON_GATES = {
    "minimum_final_forward_displacement_m": 0.030123046875,
    "maximum_tilt_rad": 0.6,
    "minimum_torso_height_m": 0.2499708652072946,
    "minimum_contact_cycles_per_limb": 2,
    "maximum_torso_ground_contact_step_count": 0,
    "maximum_controller_error_count": 0,
    "maximum_safe_no_actuation_count": 0,
    "maximum_nonfinite_observation_count": 0,
    "maximum_actuator_application_mismatch_count": 0,
    "exact_controller_semantic_step_count": 2_992,
    "exact_validated_portable_command_count": 23_936,
    "exact_native_actuation_application_count": 23_936,
    "maximum_portable_impulse_violation_count": 0,
}
LINEAGE_BINDINGS = {
    "sdk/turning/r23d31_cycle_integrated_directional_response_closure_v1.json": (
        "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c"
    ),
    "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json": (
        "sha256:910fd0ba2369a889430c1228f2eaea1146cf26005c4ac51f353803869d709fd8"
    ),
    "sdk/turning/r23d61_selected_actuator_profile_publication_v1.json": (
        "sha256:a9bf3f1a780cced8f3cdbf00642c7a2e17c6a3df9e3651791b380f0b8c8b2b9e"
    ),
    "sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json": (
        "sha256:2cc44221fa1e594d630f249af26b6343921684bca5f8791c83c8ad36660fbd2f"
    ),
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_closure_v1.json": (
        "sha256:02d8f03957c2e799abc69c12adfc18d7d38753d238ac4f475db56cd1f7821e96"
    ),
    "tests/test_qsdk_r23d65_physical_closure.ps1": (
        "sha256:47715a6909c50aeb48ddf26cbe11a8e679c9de39d0578bfbabe64f462a8bcc74"
    ),
    "sdk/turning/three_engine_turning_production_route_development_closure_v1.json": (
        "sha256:defa74f02d0018764389309847e04387f36c7ccfd7b3aefc78aede92a33e75b0"
    ),
    "tests/test_three_engine_turning_production_route_development_closure.ps1": (
        "sha256:4de3e8e3af52ebff434867260eaee836b574baebc87c5b8c8f16209b1a517bc2"
    ),
}


class DeclarationError(ValueError):
    """Raised when a frozen declaration surface changes."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DeclarationError(f"QSDK_R23D66_DECLARATION_{code}")


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), "JSON_ROOT_INVALID")
    return value


def expected_cells() -> list[dict[str, Any]]:
    return [
        {
            "cell_id": f"r23d66__{engine_id}__s{CAMPAIGN_SEED}__{arm_id}",
            "engine_id": engine_id,
            "arm_id": arm_id,
            "turn_heading_offset_rad": offset,
        }
        for engine_id in ENGINES
        for arm_id, offset in ARMS
    ]


def segment_for_step(semantic_step: int) -> tuple[str, float | None]:
    _require(0 <= semantic_step < CONTROLLER_STEPS, "SEMANTIC_STEP_INVALID")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", None
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "reference_continuation", 0.0


def expected_segment_counts() -> dict[str, int]:
    counts: dict[str, int] = {}
    for semantic_step in range(CONTROLLER_STEPS):
        segment, _ = segment_for_step(semantic_step)
        counts[segment] = counts.get(segment, 0) + 1
    return counts


def validate_declaration(value: dict[str, Any]) -> None:
    _require(
        value.get("schema_version")
        == "sporespore_qsdk_r23d66_production_route_three_engine_turning_validation_preregistration_v1",
        "SCHEMA_INVALID",
    )
    _require(
        value.get("status") == "prospective_declaration_complete_physical_not_authorized",
        "STATUS_INVALID",
    )
    _require(value.get("campaign_id") == CAMPAIGN_ID, "CAMPAIGN_ID_INVALID")
    _require(value.get("gate_id") == GATE_ID, "GATE_ID_INVALID")
    _require(value.get("release_gate_id") == RELEASE_GATE_ID, "RELEASE_GATE_ID_INVALID")
    _require(value.get("physical_question_class") == "finite_decision", "QUESTION_CLASS_INVALID")
    ledger = value.get("ledger_scope", {})
    _require(
        ledger
        == {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "held_out_prospective",
            "question_class": "finite_decision",
        },
        "LEDGER_SCOPE_INVALID",
    )
    _require(value.get("physical_question_declared") is True, "QUESTION_NOT_DECLARED")
    _require(value.get("physical_campaign_opened") is False, "CAMPAIGN_ALREADY_OPENED")

    parent = value.get("declaration_parent", {})
    _require(parent.get("commit") == PARENT_COMMIT, "PARENT_COMMIT_INVALID")
    _require(parent.get("tree_git_oid") == PARENT_TREE, "PARENT_TREE_INVALID")
    _require(parent.get("clean_pushed_and_live_equal_when_selected") is True, "PARENT_NOT_PUSHED")

    predecessor = value.get("immutable_predecessor", {})
    _require(predecessor.get("gate_id") == "QSDK-R23D65", "PREDECESSOR_GATE_INVALID")
    _require(predecessor.get("campaign_identity_consumed") is True, "PREDECESSOR_NOT_CONSUMED")
    _require(predecessor.get("held_out_seed_outcome_exposed") is True, "PREDECESSOR_SEED_NOT_EXPOSED")
    _require(
        predecessor.get("same_identity_repair_completion_or_rerun_permitted") is False,
        "PREDECESSOR_RERUN_PERMITTED",
    )
    _require(
        predecessor.get("scientific_or_physical_turning_result_exists") is False,
        "PREDECESSOR_RESULT_REWRITTEN",
    )
    _require(predecessor.get("historical_result_or_interpretation_rewritten") is False, "HISTORY_REWRITTEN")

    route = value.get("qualified_development_route_prior", {})
    _require(route.get("question_class") == "development", "ROUTE_CLASS_INVALID")
    _require(route.get("route_execution_valid") is True, "ROUTE_NOT_VALID")
    _require(route.get("execution_valid_engine_count") == 3, "ROUTE_ENGINE_COUNT_INVALID")
    _require(route.get("behavioral_outcome") == "not_evaluated_development_route_ghost", "ROUTE_OUTCOME_INVALID")
    _require(route.get("direct_reuse_as_held_out_behavioral_evidence_permitted") is False, "ROUTE_PROMOTED")
    _require(route.get("direct_reuse_as_r23d66_source_qualification_permitted") is False, "ROUTE_REUSED")

    bindings = value.get("lineage_bindings", {})
    _require(bindings == LINEAGE_BINDINGS, "LINEAGE_BINDINGS_INVALID")
    for relative, digest in LINEAGE_BINDINGS.items():
        _require(raw_sha256(REPO_ROOT / relative) == digest, "LIVE_LINEAGE_DIGEST_INVALID")

    change = value.get("scientific_distinction_and_change_budget", {})
    _require(change.get("fresh_seed") == CAMPAIGN_SEED, "FRESH_SEED_INVALID")
    _require(change.get("fresh_seed_identity_occurrence_count_at_declaration_parent") == 0, "SEED_OCCURRENCE_INVALID")
    for key in (
        "new_campaign_gate_stage_and_cell_identity_required",
        "fresh_pre_outcome_seed_and_perturbation_required",
        "selected_public_profile_preserved",
        "controller_policy_and_memory_semantics_preserved",
        "native_physics_and_host_mapping_semantics_preserved",
        "task_origin_startup_schedule_and_measurement_preserved",
        "common_physical_thresholds_preserved",
        "turning_thresholds_preserved",
        "selector_decision_rule_and_interpretation_preserved",
    ):
        _require(change.get(key) is True, f"CHANGE_BUDGET_{key.upper()}_INVALID")
    _require(change.get("formal_cross_engine_effect_equivalence_added") is False, "EQUIVALENCE_ADDED")
    _require(change.get("historical_result_reinterpreted") is False, "HISTORY_REINTERPRETED")

    profile = value.get("published_profile_binding", {})
    _require(profile.get("profile_id") == PROFILE_ID, "PROFILE_ID_INVALID")
    _require(profile.get("profile_sha256") == PROFILE_SHA256, "PROFILE_DIGEST_INVALID")
    _require(profile.get("morphology_id") == MORPHOLOGY_ID, "MORPHOLOGY_INVALID")
    _require(profile.get("public_resolution_required_in_each_worker") is True, "PROFILE_RESOLUTION_NOT_REQUIRED")
    _require(profile.get("host_mapping_receipt_required_before_each_world") is True, "HOST_MAPPING_NOT_REQUIRED")
    _require(profile.get("legacy_fixture_override_permitted") is False, "LEGACY_OVERRIDE_PERMITTED")
    _require(profile.get("profile_tuning_permitted") is False, "PROFILE_TUNING_PERMITTED")

    seed_compilation = value.get("seed_fixture_compilation", {})
    seed_compiler = REPO_ROOT / str(seed_compilation.get("compiler_path", ""))
    _require(seed_compilation.get("pure_zero_world_compiler") is True, "SEED_COMPILER_NOT_PURE")
    _require(seed_compilation.get("compiled_before_any_r23d66_model_or_world") is True, "SEED_COMPILED_LATE")
    _require(seed_compilation.get("model_construction_count") == 0, "SEED_MODEL_COUNT_INVALID")
    _require(seed_compilation.get("world_attempt_count") == 0, "SEED_ATTEMPT_COUNT_INVALID")
    _require(seed_compilation.get("world_build_count") == 0, "SEED_WORLD_COUNT_INVALID")
    _require(raw_sha256(seed_compiler) == seed_compilation.get("compiler_raw_sha256"), "SEED_COMPILER_DIGEST_INVALID")

    matrix = value.get("frozen_matrix", {})
    _require(matrix.get("ordered_engine_ids") == list(ENGINES), "ENGINE_ORDER_INVALID")
    _require(matrix.get("ordered_arm_ids") == [item[0] for item in ARMS], "ARM_ORDER_INVALID")
    _require(matrix.get("ordered_heading_offsets_rad") == [item[1] for item in ARMS], "ARM_OFFSETS_INVALID")
    _require(matrix.get("declared_cell_count") == 9, "CELL_COUNT_INVALID")
    _require(matrix.get("declared_world_count") == 9, "WORLD_COUNT_INVALID")
    _require(matrix.get("seed") == CAMPAIGN_SEED, "MATRIX_SEED_INVALID")
    _require(matrix.get("initial_perturbation") == INITIAL_PERTURBATION, "PERTURBATION_INVALID")
    _require(matrix.get("morphology_id") == MORPHOLOGY_ID, "MATRIX_MORPHOLOGY_INVALID")
    _require(matrix.get("controller_policy_id") == POLICY_ID, "POLICY_ID_INVALID")
    _require(matrix.get("controller_step_count") == CONTROLLER_STEPS, "CONTROLLER_STEPS_INVALID")
    _require(matrix.get("turn_start_step") == TURN_START_STEP, "TURN_START_INVALID")
    _require(matrix.get("turn_end_step_exclusive") == TURN_END_STEP_EXCLUSIVE, "TURN_END_INVALID")
    _require(matrix.get("recovery_duration_steps") == RECOVERY_DURATION_STEPS, "RECOVERY_STEPS_INVALID")
    _require(matrix.get("after_declared_schedule_step_count") == 592, "CONTINUATION_STEPS_INVALID")
    _require(matrix.get("cells") == expected_cells(), "CELLS_INVALID")
    _require(matrix.get("engine_identity_is_policy_input") is False, "ENGINE_IS_POLICY_INPUT")
    _require(matrix.get("arm_identity_is_policy_input") is False, "ARM_IS_POLICY_INPUT")
    _require(matrix.get("fresh_world_required_per_cell") is True, "FRESH_WORLD_NOT_REQUIRED")
    _require(matrix.get("serial_execution_required") is True, "SERIAL_EXECUTION_NOT_REQUIRED")
    _require(
        expected_segment_counts()
        == {
            "reference_warmup": 600,
            "commanded_turn": 1_200,
            "reference_recovery": 600,
            "reference_continuation": 592,
        },
        "SCHEDULE_SEGMENTATION_INVALID",
    )

    _require(value.get("frozen_common_physical_gates") == COMMON_GATES, "COMMON_GATES_INVALID")
    measurement = value.get("frozen_turning_measurement", {})
    _require(measurement.get("minimum_raw_signed_cycle_shift_rad") == 0.01, "RAW_TURNING_FLOOR_INVALID")
    _require(
        measurement.get("minimum_reference_conditioned_cycle_shift_rad") == 0.01,
        "CONDITIONED_TURNING_FLOOR_INVALID",
    )
    _require(measurement.get("reference_arm_required_per_engine") is True, "REFERENCE_ARM_NOT_REQUIRED")
    _require(measurement.get("both_signed_arms_required_per_engine") is True, "SIGNED_ARMS_NOT_REQUIRED")
    _require(measurement.get("absolute_zero_command_yaw_population_claimed") is False, "ZERO_YAW_POPULATION_CLAIMED")

    decision = value.get("finite_decision_rule", {})
    for key in (
        "complete_execution_valid_nine_cell_matrix_required",
        "all_nine_cells_must_pass_every_common_physical_gate",
        "each_engine_must_independently_pass_both_raw_signed_turning_floors",
        "each_engine_must_independently_pass_both_reference_conditioned_turning_floors",
        "positive_qsdk_r23_transition_permitted",
    ):
        _require(decision.get(key) is True, f"DECISION_{key.upper()}_INVALID")
    _require(decision.get("positive_cross_engine_equivalence") is False, "EQUIVALENCE_PERMITTED")
    _require(decision.get("early_stop_or_selective_rerun_permitted") is False, "SELECTIVE_RERUN_PERMITTED")
    _require(
        decision.get("posthoc_threshold_selector_evaluator_or_interpretation_change_permitted") is False,
        "POSTHOC_CHANGE_PERMITTED",
    )

    provenance = value.get("threshold_margin_cohort_and_population_provenance", {})
    for key in ("superiority_margin", "equivalence_margin", "non_inferiority_margin", "population_margin"):
        _require(provenance.get(key) is None, f"{key.upper()}_INVALID")
    _require(provenance.get("sampling_used") is False, "SAMPLING_CLAIMED")
    _require(provenance.get("seed_selected_before_any_r23d66_outcome") is True, "SEED_SELECTED_LATE")
    _require(provenance.get("all_nine_fresh_native_worlds_required") is True, "FRESH_WORLDS_NOT_REQUIRED")
    _require(bool(str(provenance.get("finite_cohort_adequacy_argument", "")).strip()), "COHORT_ADEQUACY_MISSING")
    _require(provenance.get("formal_cross_engine_equivalence_attempted") is False, "EQUIVALENCE_ATTEMPTED")
    _require(provenance.get("population_inference_attempted") is False, "POPULATION_INFERENCE_ATTEMPTED")

    interlocks = value.get("implementation_and_execution_interlocks", {})
    _require(interlocks.get("declaration_alone_authorizes_physical_execution") is False, "DECLARATION_AUTHORIZES_PHYSICS")
    _require(interlocks.get("shared_production_route_required") is True, "SHARED_ROUTE_NOT_REQUIRED")
    _require(interlocks.get("separate_behavior_only_worker_fork_permitted") is False, "BEHAVIOR_FORK_PERMITTED")
    _require(interlocks.get("complete_zero_world_gate_required_before_freeze") is True, "ZERO_WORLD_NOT_REQUIRED")
    _require(interlocks.get("additional_physical_development_ghost_required") is False, "EXTRA_GHOST_REQUIRED")
    _require(bool(str(interlocks.get("additional_ghost_waiver_adequacy_argument", "")).strip()), "GHOST_ADEQUACY_MISSING")
    _require(interlocks.get("clean_pushed_source_required") is True, "CLEAN_PUSH_NOT_REQUIRED")
    _require(interlocks.get("fresh_scoped_qualification_required") is True, "QUALIFICATION_NOT_REQUIRED")
    _require(interlocks.get("separate_exact_adoption_required") is True, "ADOPTION_NOT_REQUIRED")
    _require(interlocks.get("physical_workers_serialized") is True, "WORKERS_NOT_SERIALIZED")
    _require(interlocks.get("complete_evaluator_invocation_count") == 1, "EVALUATOR_COUNT_INVALID")

    controls = value.get("compact_declaration_mutation_controls", {})
    _require(controls.get("declared_control_count") == 13, "MUTATION_COUNT_INVALID")
    _require(len(controls.get("controlled_surfaces", [])) == 13, "MUTATION_SURFACES_INVALID")
    _require(controls.get("one_representative_mutation_per_surface_required") is True, "MUTATION_COVERAGE_INVALID")
    _require(controls.get("exhaustive_alias_canary_expansion_required") is False, "CANARY_EXPANSION_REQUIRED")

    claims = value.get("claims", {})
    _require(claims.get("r23d66_preregistered") is True, "PREREGISTRATION_CLAIM_INVALID")
    for key in (
        "r23d66_implementation_complete",
        "r23d66_complete_zero_world_gate_passed",
        "r23d66_physical_campaign_opened",
        "finite_three_engine_turning",
        "portable_basic_turning",
        "q_sdk_r23_satisfied",
        "cross_engine_equivalence",
        "population_robustness",
        "arbitrary_quadruped_coverage",
        "prone_to_standing",
        "physical_acceptance_authority",
        "release_authorized",
        "release_score_changed",
    ):
        _require(claims.get(key) is False, f"CLAIM_{key.upper()}_INVALID")
    _require(claims.get("release_score_before") == "10/25", "SCORE_BEFORE_INVALID")
    _require(claims.get("release_score_after") == "10/25", "SCORE_AFTER_INVALID")


Mutation = tuple[str, Callable[[dict[str, Any]], None]]


def mutation_controls() -> tuple[Mutation, ...]:
    return (
        ("schema_and_status", lambda value: value.__setitem__("status", "physical_authorized")),
        ("question_class", lambda value: value.__setitem__("physical_question_class", "equivalence_non_inferiority")),
        (
            "lineage_digest",
            lambda value: value["lineage_bindings"].__setitem__(
                next(iter(LINEAGE_BINDINGS)), "sha256:" + "0" * 64
            ),
        ),
        ("fresh_seed", lambda value: value["frozen_matrix"].__setitem__("seed", CAMPAIGN_SEED + 2)),
        (
            "compiled_perturbation",
            lambda value: value["frozen_matrix"]["initial_perturbation"].__setitem__("fixture_yaw_rad", 0.0),
        ),
        (
            "engine_order",
            lambda value: value["frozen_matrix"].__setitem__("ordered_engine_ids", list(reversed(ENGINES))),
        ),
        (
            "arm_order_and_offsets",
            lambda value: value["frozen_matrix"]["ordered_heading_offsets_rad"].__setitem__(1, 0.25),
        ),
        ("schedule", lambda value: value["frozen_matrix"].__setitem__("turn_start_step", 601)),
        (
            "common_gate",
            lambda value: value["frozen_common_physical_gates"].__setitem__(
                "minimum_final_forward_displacement_m", 0.0
            ),
        ),
        (
            "turning_floor",
            lambda value: value["frozen_turning_measurement"].__setitem__(
                "minimum_raw_signed_cycle_shift_rad", 0.0
            ),
        ),
        (
            "decision_rule",
            lambda value: value["finite_decision_rule"].__setitem__("early_stop_or_selective_rerun_permitted", True),
        ),
        (
            "route_authority_separation",
            lambda value: value["qualified_development_route_prior"].__setitem__(
                "direct_reuse_as_held_out_behavioral_evidence_permitted", True
            ),
        ),
        ("public_claim_boundary", lambda value: value["claims"].__setitem__("release_authorized", True)),
    )


def run_mutation_controls(value: dict[str, Any]) -> list[str]:
    rejected: list[str] = []
    for name, mutate in mutation_controls():
        candidate = copy.deepcopy(value)
        mutate(candidate)
        try:
            validate_declaration(candidate)
        except DeclarationError:
            rejected.append(name)
        else:
            raise DeclarationError(f"QSDK_R23D66_DECLARATION_MUTATION_ACCEPTED:{name}")
    return rejected


def arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--declaration", type=Path, default=DECLARATION)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = arguments(sys.argv[1:] if argv is None else argv)
    try:
        declaration = load_json(args.declaration)
        validate_declaration(declaration)
        rejected = run_mutation_controls(declaration)
    except (OSError, UnicodeError, json.JSONDecodeError, DeclarationError) as error:
        print(f"QSDK_R23D66_DECLARATION_FAILURE {type(error).__name__}:{error}")
        return 1
    receipt = {
        "schema_version": "sporespore_qsdk_r23d66_declaration_audit_receipt_v1",
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "reserved_seed": CAMPAIGN_SEED,
        "cell_count": len(expected_cells()),
        "schedule_segment_counts": expected_segment_counts(),
        "mutation_rejection_count": len(rejected),
        "mutation_ids": rejected,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_campaign_opened": False,
        "q_sdk_r23_satisfied": False,
        "release_authorized": False,
    }
    print(
        "QSDK_R23D66_DECLARATION_PASS "
        + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
