"""Prospective R23D60 held-out Godot/Jolt turning declaration.

R23D60 consumes only the candidate-selection permission created by the valid,
complete R23D59 finite decision.  The seed, perturbation, three heading arms,
schedule, common physical gates, and cycle-integrated turning floors were all
reserved before R23D59 outcomes.  This module is pure declaration authority:
it constructs no model or physics world.
"""

from __future__ import annotations

import argparse
import copy
from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Sequence

import r23d59_godot_knee_source_finite_decision as reservation


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent

CAMPAIGN_ID = reservation.R23D60_CAMPAIGN_ID
GATE_ID = "QSDK-R23D60"
QUESTION_CLASS = "finite_decision"
STAGE_ID = "godot_fixture_knee_held_out_turning_validation"
ENGINE_ID = reservation.ENGINE_ID
PROFILE_ID = reservation.PROFILE_FIXTURE_KNEE
PROFILE_DEFINITION = copy.deepcopy(reservation.PROFILE_DEFINITIONS[PROFILE_ID])
POLICY_ID = reservation.POLICY_ID
MORPHOLOGY_ID = reservation.MORPHOLOGY_ID
CAMPAIGN_SEED = reservation.RESERVED_R23D60_SEED
INITIAL_PERTURBATION = copy.deepcopy(
    reservation.RESERVED_R23D60_INITIAL_PERTURBATION
)
ARM_OFFSETS = copy.deepcopy(reservation.R23D60_ARM_OFFSETS)
CONTROLLER_STEPS = reservation.CONTROLLER_STEPS
TURN_START_STEP = reservation.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = reservation.TURN_END_STEP_EXCLUSIVE
TURN_DURATION_STEPS = reservation.TURN_DURATION_STEPS
RECOVERY_DURATION_STEPS = reservation.RECOVERY_DURATION_STEPS
ACTUATOR_COUNT = reservation.ACTUATOR_COUNT
GAIT_CYCLE_STEPS = reservation.GAIT_CYCLE_STEPS
RAMP_LAST_LOCAL_STEP = reservation.RAMP_LAST_LOCAL_STEP
PROBE_LAST_SEMANTIC_STEP = reservation.PROBE_LAST_SEMANTIC_STEP
TASK_FRAME_ORIGIN_POLICY_ID = reservation.TASK_FRAME_ORIGIN_POLICY_ID
STARTUP_TRANSFORM_ID = reservation.STARTUP_TRANSFORM_ID
STARTUP_RAMP_ID = reservation.STARTUP_RAMP_ID
STARTUP_RAMP_STEPS = reservation.STARTUP_RAMP_STEPS
INITIAL_SCHEDULE_BIND_STEP = reservation.INITIAL_SCHEDULE_BIND_STEP
FIXED_ORIGIN_LAST_SEMANTIC_STEP = reservation.FIXED_ORIGIN_LAST_SEMANTIC_STEP
EXPECTED_REANCHOR_STEPS = reservation.EXPECTED_REANCHOR_STEPS
LIMB_IDS = reservation.LIMB_IDS
PHASE_OFFSETS = reservation.PHASE_OFFSETS
TRACE_ROW_SCHEMA = reservation.TRACE_ROW_SCHEMA
ACTUATOR_PHASE_OBSERVATION_SCHEMA = reservation.ACTUATOR_PHASE_OBSERVATION_SCHEMA
APPLICATION_RECEIPT_SCHEMA = reservation.APPLICATION_RECEIPT_SCHEMA
LIVE_FIXTURE_CAP_BINDING_POLICY_ID = reservation.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
LIVE_FIXTURE_COMPOSITION_SCHEMA = reservation.LIVE_FIXTURE_COMPOSITION_SCHEMA
LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA = (
    reservation.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA
)
LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA = (
    reservation.LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA
)
LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS = (
    reservation.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
)
TRACE_TRANSPORT_ID = reservation.TRACE_TRANSPORT_ID
REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE = (
    reservation.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
)
COMMON_PHYSICAL_GATES = copy.deepcopy(reservation.COMMON_PHYSICAL_GATES)
MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD = (
    reservation.R23D60_MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
)
MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD = (
    reservation.R23D60_MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD
)

StartupTransformError = reservation.StartupTransformError
SupportLossConditionedStartup = reservation.SupportLossConditionedStartup


class DeclarationError(ValueError):
    """The supplied R23D60 declaration differs from the frozen contract."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    campaign_seed: int
    profile_id: str
    hip_cap_source: str
    knee_cap_source: str
    onset_id: str
    turn_start_semantic_step: int
    arm_id: str
    turn_heading_offset_rad: float


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_ID,
            cell_id=(
                f"{ENGINE_ID}__s{CAMPAIGN_SEED}__{PROFILE_ID}__{arm_id}"
            ),
            engine_id=ENGINE_ID,
            campaign_seed=CAMPAIGN_SEED,
            profile_id=PROFILE_ID,
            hip_cap_source=str(PROFILE_DEFINITION["hip_cap_source"]),
            knee_cap_source=str(PROFILE_DEFINITION["knee_cap_source"]),
            onset_id="onset_600",
            turn_start_semantic_step=TURN_START_STEP,
            arm_id=arm_id,
            turn_heading_offset_rad=float(offset),
        )
        for arm_id, offset in ARM_OFFSETS.items()
    ]


def cell(stage_id: str, engine_id: str, arm_id: str) -> Cell:
    matches = [
        item
        for item in cells()
        if item.stage_id == stage_id
        and item.engine_id == engine_id
        and item.arm_id == arm_id
    ]
    if len(matches) != 1:
        raise DeclarationError(
            f"R23D60_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}"
        )
    return matches[0]


def cell_by_id(cell_id: str) -> Cell:
    matches = [item for item in cells() if item.cell_id == cell_id]
    if len(matches) != 1:
        raise DeclarationError(f"R23D60_CELL_ID_INVALID:{cell_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item not in cells() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise DeclarationError(f"R23D60_STEP_INVALID:{semantic_step}")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", item.turn_heading_offset_rad
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    if item not in cells():
        raise DeclarationError(f"R23D60_CELL_INVALID:{item!r}")
    return {
        "reference_warmup": TURN_START_STEP,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": RECOVERY_DURATION_STEPS,
        "after_declared_schedule": (
            CONTROLLER_STEPS
            - TURN_END_STEP_EXCLUSIVE
            - RECOVERY_DURATION_STEPS
        ),
    }


def canonical_declaration() -> dict[str, Any]:
    r59_closure = (
        ROOT / "r23d59_godot_knee_source_finite_decision_closure_v1.json"
    )
    r59_audit = REPO_ROOT / "tests" / "test_qsdk_r23d59_physical_closure.ps1"
    r59_preregistration = (
        ROOT
        / "r23d59_godot_knee_source_finite_decision_preregistration_v1.json"
    )
    r59_design = ROOT / "r23d59_godot_knee_source_finite_decision.py"
    seed_compiler = ROOT / "r23d59_seed_fixture_compiler.gd"
    r53_closure = (
        ROOT / "r23d53_godot_warmup_preserving_origin_reanchor_closure_v1.json"
    )
    r31_closure = (
        ROOT / "r23d31_cycle_integrated_directional_response_closure_v1.json"
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r23d60_godot_fixture_knee_held_out_"
            "turning_validation_preregistration_v1"
        ),
        "status": "prospective_zero_world_only_physical_not_opened",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "study_classification": (
            "exact_single_held_out_deterministic_fixture_three_arm_native_"
            "godot_jolt_turning_validation"
        ),
        "question": (
            "On the pre-outcome reserved seed-21516 perturbation, does the "
            "R23D59-selected portable-hip/fixture-knee profile pass every "
            "unchanged common physical gate in all three fresh native "
            "Godot/Jolt arms and the unchanged raw plus reference-conditioned "
            "cycle-integrated directional-response floors?"
        ),
        "physical_question_declared": True,
        "physical_campaign_opened": False,
        "immutable_lineage": {
            "r23d59_closure_path": (
                "sdk/turning/"
                "r23d59_godot_knee_source_finite_decision_closure_v1.json"
            ),
            "r23d59_closure_raw_sha256": raw_sha256(r59_closure),
            "r23d59_closure_audit_path": (
                "tests/test_qsdk_r23d59_physical_closure.ps1"
            ),
            "r23d59_closure_audit_raw_sha256": raw_sha256(r59_audit),
            "r23d59_preregistration_raw_sha256": raw_sha256(
                r59_preregistration
            ),
            "r23d59_design_raw_sha256": raw_sha256(r59_design),
            "reserved_seed_compiler_raw_sha256": raw_sha256(seed_compiler),
            "r23d53_closure_raw_sha256": raw_sha256(r53_closure),
            "r23d31_closure_raw_sha256": raw_sha256(r31_closure),
            "r23d59_identity_consumed": True,
            "r23d59_complete_six_world_matrix_execution_valid": True,
            "r23d59_complete_dependency_inventory_proved": True,
            "r23d59_fixture_knee_profile_finite_adequate": True,
            "r23d59_portable_knee_profile_finite_adequate": False,
            "r23d59_selected_profile_id": PROFILE_ID,
            "r23d60_preregistration_permitted": True,
            "r23d60_seed_consumed": False,
            "r23d53_remains_valid_complete_negative_development": True,
            "historical_result_reinterpreted": False,
            "historical_world_reused_as_r23d60_cell": False,
            "same_identity_rerun_permitted": False,
        },
        "candidate_resolution": {
            "resolution_source": (
                "exact selected_profile_id from the valid complete R23D59 "
                "closure only"
            ),
            "selected_profile_id": PROFILE_ID,
            "profile_definition": copy.deepcopy(PROFILE_DEFINITION),
            "candidate_profile_resolution_rule_unchanged_from_r23d59": True,
            "candidate_profile_tuned_after_r23d59": False,
            "controller_source_or_gain_changed_after_r23d59": False,
            "fixture_cap_binding_policy_id": LIVE_FIXTURE_CAP_BINDING_POLICY_ID,
            "fixture_readback_tolerance_nms": (
                LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
            ),
        },
        "frozen_matrix": {
            "stage_id": STAGE_ID,
            "ordered_engine_ids": [ENGINE_ID],
            "ordered_profile_ids": [PROFILE_ID],
            "ordered_arm_ids": list(ARM_OFFSETS),
            "ordered_heading_offsets_rad": list(ARM_OFFSETS.values()),
            "cells": [asdict(item) for item in cells()],
            "declared_cell_count": 3,
            "declared_world_count": 3,
            "seed": CAMPAIGN_SEED,
            "initial_perturbation": copy.deepcopy(INITIAL_PERTURBATION),
            "morphology_id": MORPHOLOGY_ID,
            "controller_policy_id": POLICY_ID,
            "task_frame_origin_policy_id": TASK_FRAME_ORIGIN_POLICY_ID,
            "initial_schedule_bind_semantic_step": INITIAL_SCHEDULE_BIND_STEP,
            "fixed_origin_last_semantic_step": (
                FIXED_ORIGIN_LAST_SEMANTIC_STEP
            ),
            "expected_reanchor_semantic_steps": list(EXPECTED_REANCHOR_STEPS),
            "controller_step_count": CONTROLLER_STEPS,
            "turn_start_step": TURN_START_STEP,
            "turn_end_step_exclusive": TURN_END_STEP_EXCLUSIVE,
            "recovery_duration_steps": RECOVERY_DURATION_STEPS,
            "command_schedule": (
                "reference_warmup_600_then_role_heading_1200_then_"
                "reference_recovery_600_then_reference_continuation_592"
            ),
            "startup_transform_id": STARTUP_TRANSFORM_ID,
            "terminal_restoration_or_taper_invoked": False,
            "serial_execution_required": True,
            "fresh_world_required_per_arm": True,
            "all_cells_run_regardless_of_intermediate_outcome": True,
        },
        "frozen_common_physical_gates": copy.deepcopy(COMMON_PHYSICAL_GATES),
        "cycle_integrated_measurement": {
            "inherited_unchanged_from_r23d31_through_r23d53": True,
            "minimum_raw_signed_cycle_shift_rad": (
                MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
            ),
            "minimum_reference_conditioned_cycle_shift_rad": (
                MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD
            ),
            "reference_arm_required": True,
            "both_signed_arms_required": True,
            "positive_and_negative_expected_direction_required": True,
        },
        "finite_decision_rule": {
            "complete_execution_valid_three_arm_matrix_required": True,
            "all_three_arms_must_pass_every_common_physical_gate": True,
            "cycle_integrated_measurement_must_pass_every_frozen_gate": True,
            "positive_classification": (
                "valid_complete_positive_exact_held_out_godot_jolt_turning_"
                "validation"
            ),
            "negative_classification": (
                "valid_complete_negative_exact_held_out_godot_jolt_turning_"
                "validation"
            ),
            "invalid_or_incomplete_classification": (
                "invalid_or_incomplete_exact_held_out_godot_jolt_turning_"
                "validation"
            ),
            "positive_claim_scope": (
                "bounded native Godot/Jolt turning for the exact frozen "
                "profile, morphology, seed, perturbation, schedule, and three "
                "heading arms only"
            ),
            "early_stop_or_selective_rerun_permitted": False,
            "posthoc_threshold_selector_or_interpretation_change_permitted": (
                False
            ),
        },
        "threshold_and_margin_provenance": {
            "all_common_physical_gates_inherited_unchanged_from_r23d59": True,
            "contact_cycle_threshold_origin": (
                "Inherited unchanged from R23D34 through R23D59; no R23D59 "
                "outcome set or weakened it."
            ),
            "cycle_integrated_floors_inherited_unchanged_from_r23d31": True,
            "cycle_integrated_floor_origin": (
                "The 0.01 rad raw and reference-conditioned floors were "
                "reserved inside R23D59 before any R23D59 outcome and are "
                "directional-response detection floors, not equivalence "
                "margins."
            ),
            "new_outcome_threshold_count": 0,
            "superiority_margin_declared": False,
            "equivalence_or_non_inferiority_margin_declared": False,
            "population_margin_declared": False,
        },
        "cohort_provenance_and_adequacy": {
            "seed_generated_and_reserved_before_r23d59_outcomes": True,
            "seed_unused_by_r23d59_physics": True,
            "candidate_resolution_uses_only_predeclared_r23d59_decision_rule": (
                True
            ),
            "deterministic_exact_finite_fixture": True,
            "all_three_fresh_native_worlds_required": True,
            "adequate_for_exact_finite_godot_jolt_claim_only": True,
            "stochastic_repeatability_rate_estimated": False,
            "population_inference_attempted": False,
            "robustness_inference_attempted": False,
            "continuous_morphology_inference_attempted": False,
            "cross_engine_equivalence_attempted": False,
        },
        "implementation_and_execution_requirements": {
            "separate_dependency_closed_worker_required": True,
            "separate_dependency_closed_evaluator_required": True,
            "separate_one_shot_supervisor_required": True,
            "complete_zero_world_gate_and_negative_controls_required": True,
            "clean_pushed_same_source_replay_required": True,
            "fresh_campaign_scoped_qualification_required": True,
            "separate_attestation_adoption_required": True,
            "full_precision_trace_retention_required": True,
            "content_addressed_evidence_required": True,
            "physical_world_may_open_from_this_declaration_alone": False,
        },
        "required_zero_world_negative_controls": {
            "declaration_mutations_rejected": True,
            "selected_profile_mutation_rejected": True,
            "reserved_seed_or_perturbation_mutation_rejected": True,
            "arm_order_offset_or_schedule_mutation_rejected": True,
            "threshold_or_common_gate_mutation_rejected": True,
            "incomplete_or_reordered_matrix_rejected": True,
            "trace_observation_and_direction_mutations_rejected": True,
            "fixture_cap_binding_and_readback_mutations_rejected": True,
            "dependency_path_or_receipt_omission_rejected": True,
            "missing_physical_authorization_rejected_before_world": True,
        },
        "claims": {
            "r23d60_preregistered": True,
            "r23d60_complete_zero_world_gate_passed": False,
            "r23d60_physical_campaign_opened": False,
            "r23d60_seed_consumed": False,
            "godot_jolt_turning": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "population_robustness": False,
            "arbitrary_quadruped_coverage": False,
            "prone_to_standing": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def validate_declaration(value: Any) -> None:
    if value != canonical_declaration():
        raise DeclarationError("R23D60_DECLARATION_IDENTITY_INVALID")


def _mutated(value: dict[str, Any], path: Sequence[str], replacement: Any) -> dict:
    result = copy.deepcopy(value)
    cursor: Any = result
    for key in path[:-1]:
        cursor = cursor[key]
    cursor[path[-1]] = replacement
    return result


def run_zero_world_declaration_audit() -> dict[str, Any]:
    declaration = canonical_declaration()
    validate_declaration(declaration)
    expected_cells = cells()
    if len(expected_cells) != 3:
        raise DeclarationError("R23D60_CELL_COUNT_INVALID")
    if [item.arm_id for item in expected_cells] != list(ARM_OFFSETS):
        raise DeclarationError("R23D60_ARM_ORDER_INVALID")
    if [item.turn_heading_offset_rad for item in expected_cells] != list(
        ARM_OFFSETS.values()
    ):
        raise DeclarationError("R23D60_ARM_OFFSETS_INVALID")
    for item in expected_cells:
        if expected_segment_counts(item) != {
            "reference_warmup": 600,
            "commanded_turn": 1200,
            "reference_recovery": 600,
            "after_declared_schedule": 592,
        }:
            raise DeclarationError("R23D60_SEGMENT_COUNTS_INVALID")
        if segment_for_step(item, 599) != ("reference_warmup", 0.0):
            raise DeclarationError("R23D60_WARMUP_BOUNDARY_INVALID")
        if segment_for_step(item, 600) != (
            "commanded_turn",
            item.turn_heading_offset_rad,
        ):
            raise DeclarationError("R23D60_TURN_BOUNDARY_INVALID")
        if segment_for_step(item, 1800) != ("reference_recovery", 0.0):
            raise DeclarationError("R23D60_RECOVERY_BOUNDARY_INVALID")

    mutation_specs = [
        (("campaign_id",), "QSDK-R23D60-MUTATED"),
        (("question_class",), "development"),
        (("physical_campaign_opened",), True),
        (("immutable_lineage", "r23d59_selected_profile_id"), "mutated"),
        (("immutable_lineage", "r23d60_seed_consumed"), True),
        (("candidate_resolution", "selected_profile_id"), "mutated"),
        (
            ("candidate_resolution", "candidate_profile_tuned_after_r23d59"),
            True,
        ),
        (("frozen_matrix", "seed"), 21517),
        (("frozen_matrix", "ordered_arm_ids"), list(reversed(ARM_OFFSETS))),
        (("frozen_matrix", "ordered_heading_offsets_rad"), [0.0, -0.2, 0.2]),
        (("frozen_matrix", "turn_start_step"), 601),
        (("frozen_matrix", "declared_world_count"), 2),
        (
            (
                "frozen_common_physical_gates",
                "minimum_contact_cycles_per_limb",
            ),
            1,
        ),
        (
            (
                "cycle_integrated_measurement",
                "minimum_raw_signed_cycle_shift_rad",
            ),
            0.009,
        ),
        (
            (
                "cycle_integrated_measurement",
                "minimum_reference_conditioned_cycle_shift_rad",
            ),
            0.009,
        ),
        (
            (
                "finite_decision_rule",
                "all_three_arms_must_pass_every_common_physical_gate",
            ),
            False,
        ),
        (
            (
                "finite_decision_rule",
                "early_stop_or_selective_rerun_permitted",
            ),
            True,
        ),
        (
            (
                "cohort_provenance_and_adequacy",
                "population_inference_attempted",
            ),
            True,
        ),
        (
            (
                "implementation_and_execution_requirements",
                "separate_attestation_adoption_required",
            ),
            False,
        ),
        (("claims", "godot_jolt_turning"), True),
    ]
    rejected = 0
    for path, replacement in mutation_specs:
        try:
            validate_declaration(_mutated(declaration, path, replacement))
        except DeclarationError:
            rejected += 1
        else:
            raise DeclarationError(
                "R23D60_MUTATION_ACCEPTED:" + ".".join(path)
            )
    return {
        "schema_version": "sporespore_qsdk_r23d60_declaration_audit_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "cell_count": len(expected_cells),
        "mutation_rejection_count": rejected,
        "reserved_seed": CAMPAIGN_SEED,
        "selected_profile_id": PROFILE_ID,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_campaign_opened": False,
        "godot_jolt_turning": False,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--emit-declaration", action="store_true")
    action.add_argument("--self-test", action="store_true")
    action.add_argument("--declaration", type=Path)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    if args.emit_declaration:
        print(json.dumps(canonical_declaration(), indent=2, sort_keys=False))
        return 0
    if args.declaration is not None:
        supplied = json.loads(args.declaration.read_text(encoding="utf-8"))
        validate_declaration(supplied)
    if args.self_test or args.declaration is not None:
        print(
            "QSDK_R23D60_DECLARATION_PASS "
            + json.dumps(run_zero_world_declaration_audit(), sort_keys=True)
        )
        return 0
    raise AssertionError("argparse required one R23D60 declaration action")


if __name__ == "__main__":
    raise SystemExit(main())
