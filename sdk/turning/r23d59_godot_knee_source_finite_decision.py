"""Prospective R23D59 Godot/Jolt knee-cap-source finite decision.

R23D59 is scientifically distinct from the consumed R23D58 development
factorial. It runs two frozen knee-cap-source profiles, with portable hip caps
fixed, over three fresh matched deterministic perturbations. The exact six-cell
conjunction may select one profile for a separately reserved held-out R23D60
turning validation. It is not a turning campaign, a superiority study, an
equivalence/non-inferiority study, or a population claim.

This module is pure design and declaration-audit authority. It constructs no
model or physics world.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import r23d58_godot_cap_source_factorial as predecessor


CAMPAIGN_ID = "QSDK-R23D59-GODOT-KNEE-CAP-SOURCE-THREE-SEED-FINITE-DECISION"
GATE_ID = "QSDK-R23D59"
QUESTION_CLASS = "finite_decision"
STAGE_ID = "godot_knee_cap_source_three_seed_finite_decision"
ENGINE_ID = "godot_jolt"
POLICY_ID = predecessor.POLICY_ID
MORPHOLOGY_ID = predecessor.MORPHOLOGY_ID
CONTROLLER_STEPS = predecessor.CONTROLLER_STEPS
TURN_START_STEP = predecessor.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = predecessor.TURN_END_STEP_EXCLUSIVE
TURN_DURATION_STEPS = predecessor.TURN_DURATION_STEPS
RECOVERY_DURATION_STEPS = predecessor.RECOVERY_DURATION_STEPS
ACTUATOR_COUNT = predecessor.ACTUATOR_COUNT
GAIT_CYCLE_STEPS = predecessor.GAIT_CYCLE_STEPS
RAMP_LAST_LOCAL_STEP = predecessor.RAMP_LAST_LOCAL_STEP
PROBE_LAST_SEMANTIC_STEP = predecessor.PROBE_LAST_SEMANTIC_STEP
TASK_FRAME_ORIGIN_POLICY_ID = predecessor.TASK_FRAME_ORIGIN_POLICY_ID
STARTUP_TRANSFORM_ID = predecessor.STARTUP_TRANSFORM_ID
STARTUP_RAMP_ID = predecessor.STARTUP_RAMP_ID
STARTUP_RAMP_STEPS = predecessor.STARTUP_RAMP_STEPS
INITIAL_SCHEDULE_BIND_STEP = predecessor.INITIAL_SCHEDULE_BIND_STEP
FIXED_ORIGIN_LAST_SEMANTIC_STEP = predecessor.FIXED_ORIGIN_LAST_SEMANTIC_STEP
EXPECTED_REANCHOR_STEPS = predecessor.EXPECTED_REANCHOR_STEPS
LIMB_IDS = predecessor.LIMB_IDS
PHASE_OFFSETS = predecessor.PHASE_OFFSETS
TRACE_ROW_SCHEMA = predecessor.TRACE_ROW_SCHEMA
ACTUATOR_PHASE_OBSERVATION_SCHEMA = predecessor.ACTUATOR_PHASE_OBSERVATION_SCHEMA
APPLICATION_RECEIPT_SCHEMA = predecessor.APPLICATION_RECEIPT_SCHEMA
LIVE_FIXTURE_CAP_BINDING_POLICY_ID = predecessor.LIVE_FIXTURE_CAP_BINDING_POLICY_ID
LIVE_FIXTURE_COMPOSITION_SCHEMA = predecessor.LIVE_FIXTURE_COMPOSITION_SCHEMA
LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA = (
    predecessor.LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA
)
LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA = (
    predecessor.LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA
)
LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS = (
    predecessor.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
)
TRACE_TRANSPORT_ID = predecessor.TRACE_TRANSPORT_ID
REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE = (
    predecessor.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
)
CAP_SOURCE_PORTABLE_COMPILED = predecessor.CAP_SOURCE_PORTABLE_COMPILED
CAP_SOURCE_FIXTURE_PREBINDING = predecessor.CAP_SOURCE_FIXTURE_PREBINDING

StartupTransformError = predecessor.StartupTransformError
SupportLossConditionedStartup = predecessor.SupportLossConditionedStartup
smoothstep_scale = predecessor.smoothstep_scale

PROFILE_PORTABLE = predecessor.PROFILE_PORTABLE_HIP_PORTABLE_KNEE
PROFILE_FIXTURE_KNEE = predecessor.PROFILE_PORTABLE_HIP_FIXTURE_KNEE
# Retained only as invalid-mutation sentinels used by the accepted R23D58 cap
# projection controls. They are not R23D59 factor levels or campaign cells.
PROFILE_FIXTURE_HIP_PORTABLE_KNEE = (
    predecessor.PROFILE_FIXTURE_HIP_PORTABLE_KNEE
)
PROFILE_FIXTURE_HIP_FIXTURE_KNEE = (
    predecessor.PROFILE_FIXTURE_HIP_FIXTURE_KNEE
)
ORDERED_PROFILE_IDS = (PROFILE_PORTABLE, PROFILE_FIXTURE_KNEE)
PROFILE_DEFINITIONS = {
    PROFILE_PORTABLE: copy.deepcopy(predecessor.PROFILE_DEFINITIONS[PROFILE_PORTABLE]),
    PROFILE_FIXTURE_KNEE: copy.deepcopy(
        predecessor.PROFILE_DEFINITIONS[PROFILE_FIXTURE_KNEE]
    ),
}

DECISION_SEEDS = (21_513, 21_514, 21_515)
RESERVED_R23D60_SEED = 21_516
INITIAL_PERTURBATIONS = {
    21_513: {
        "campaign_seed": 21_513,
        "fixture_vertical_clearance_m": 0.00006347735325107351,
        "fixture_yaw_rad": -0.007286008447408676,
        "initial_linear_velocity_world_m_s": [
            -0.000333231408149004,
            0.0,
            -0.0027139047160744667,
        ],
        "initial_torso_angular_velocity_world_rad_s": [
            0.001592416549101472,
            0.0019763787277042866,
            -0.00020259374286979437,
        ],
        "gait_phase_offset_ticks": -1,
    },
    21_514: {
        "campaign_seed": 21_514,
        "fixture_vertical_clearance_m": 0.0004711337387561798,
        "fixture_yaw_rad": -0.005686357617378235,
        "initial_linear_velocity_world_m_s": [
            -0.0021158172748982906,
            0.0,
            -0.0029127239249646664,
        ],
        "initial_torso_angular_velocity_world_rad_s": [
            -0.001648021163418889,
            -0.003364833537489176,
            -0.0007431361591443419,
        ],
        "gait_phase_offset_ticks": -2,
    },
    21_515: {
        "campaign_seed": 21_515,
        "fixture_vertical_clearance_m": 0.0004844205977860838,
        "fixture_yaw_rad": -0.001246036496013403,
        "initial_linear_velocity_world_m_s": [
            0.0029606353491544724,
            0.0,
            0.0005961563438177109,
        ],
        "initial_torso_angular_velocity_world_rad_s": [
            0.0010913035366684198,
            -0.0018947913777083158,
            -0.00025555735919624567,
        ],
        "gait_phase_offset_ticks": 3,
    },
}
RESERVED_R23D60_INITIAL_PERTURBATION = {
    "campaign_seed": 21_516,
    "fixture_vertical_clearance_m": 0.0008292800048366189,
    "fixture_yaw_rad": -0.0031932652927935123,
    "initial_linear_velocity_world_m_s": [
        0.0030934750102460384,
        0.0,
        -0.0007665741723030806,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.0007512527517974377,
        0.0010391897521913052,
        0.0010421534534543753,
    ],
    "gait_phase_offset_ticks": 0,
}

COMMON_PHYSICAL_GATES = {
    "minimum_final_forward_displacement_m": 0.030123046875,
    "maximum_tilt_rad": 0.6,
    "minimum_torso_height_m": 0.2499708652072946,
    "minimum_contact_cycles_per_limb": 2,
    "maximum_torso_ground_contact_step_count": 0,
    "maximum_controller_error_count": 0,
    "maximum_safe_no_actuation_count": 0,
    "maximum_nonfinite_observation_count": 0,
    "maximum_actuator_application_mismatch_count": 0,
    "exact_controller_semantic_step_count": 2992,
    "exact_validated_portable_command_count": 23936,
    "exact_native_actuation_application_count": 23936,
    "maximum_portable_impulse_violation_count": 0,
}

R23D60_CAMPAIGN_ID = (
    "QSDK-R23D60-GODOT-KNEE-SOURCE-FROZEN-PROFILE-HELD-OUT-TURNING-VALIDATION"
)
R23D60_ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}
R23D60_MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD = 0.01
R23D60_MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD = 0.01


class DeclarationError(ValueError):
    """Raised when the prospective declaration differs from the frozen design."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    campaign_seed: int
    arm_id: str
    turn_heading_offset_rad: float
    profile_id: str
    hip_cap_source: str
    knee_cap_source: str

    @property
    def onset_id(self) -> str:
        """Compatibility field for the accepted fixed-horizon evaluator core."""

        return "onset_600"

    @property
    def turn_start_semantic_step(self) -> int:
        """Compatibility field; the R23D59 schedule remains unchanged."""

        return TURN_START_STEP


def cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"godot_jolt__s{seed}__{profile_id}",
            engine_id=ENGINE_ID,
            campaign_seed=seed,
            arm_id="reference_zero",
            turn_heading_offset_rad=0.0,
            profile_id=profile_id,
            hip_cap_source=str(PROFILE_DEFINITIONS[profile_id]["hip_cap_source"]),
            knee_cap_source=str(PROFILE_DEFINITIONS[profile_id]["knee_cap_source"]),
        )
        for seed in DECISION_SEEDS
        for profile_id in ORDERED_PROFILE_IDS
    ]


def cell(stage_id: str, engine_id: str, profile_id: str, campaign_seed: int) -> Cell:
    """Resolve one exact matched-seed/profile cell."""

    matches = [
        item
        for item in cells()
        if item.stage_id == stage_id
        and item.engine_id == engine_id
        and item.profile_id == profile_id
        and item.campaign_seed == campaign_seed
    ]
    if len(matches) != 1:
        raise StartupTransformError(
            f"R23D59_CELL_INVALID:{stage_id}:{engine_id}:{campaign_seed}:{profile_id}"
        )
    return matches[0]


def cell_by_id(cell_id: str) -> Cell:
    matches = [item for item in cells() if item.cell_id == cell_id]
    if len(matches) != 1:
        raise StartupTransformError(f"R23D59_CELL_ID_INVALID:{cell_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item not in cells() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise StartupTransformError(f"R23D59_STEP_INVALID:{semantic_step}")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    if item not in cells():
        raise StartupTransformError(f"R23D59_CELL_INVALID:{item!r}")
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


def decide_profile(
    *, matrix_execution_valid: bool, portable_adequate: bool, fixture_knee_adequate: bool
) -> dict[str, Any]:
    """Apply the frozen finite-decision table without an outcome-fitted margin."""

    if not all(
        isinstance(value, bool)
        for value in (
            matrix_execution_valid,
            portable_adequate,
            fixture_knee_adequate,
        )
    ):
        raise DeclarationError("R23D59_DECISION_INPUT_NOT_BOOLEAN")
    if not matrix_execution_valid:
        return {
            "decision_id": "no_selection_matrix_invalid_or_incomplete",
            "selected_profile_id": None,
        }
    if portable_adequate:
        return {
            "decision_id": (
                "portable_selected_both_finite_adequate_by_engine_neutral_preference"
                if fixture_knee_adequate
                else "portable_selected_only_portable_finite_adequate"
            ),
            "selected_profile_id": PROFILE_PORTABLE,
        }
    if fixture_knee_adequate:
        return {
            "decision_id": "fixture_knee_selected_only_fixture_knee_finite_adequate",
            "selected_profile_id": PROFILE_FIXTURE_KNEE,
        }
    return {
        "decision_id": "no_selection_neither_profile_finite_adequate",
        "selected_profile_id": None,
    }


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DeclarationError(code)


def validate_declaration(value: dict[str, Any]) -> None:
    matrix = value.get("frozen_matrix", {})
    rules = value.get("finite_decision_rule", {})
    reserved = value.get("reserved_r23d60_held_out_turning_validation", {})
    claims = value.get("claims", {})
    dependencies = value.get("prospective_dependency_completeness", {})

    _require(value.get("campaign_id") == CAMPAIGN_ID, "CAMPAIGN_ID_CHANGED")
    _require(value.get("gate_id") == GATE_ID, "GATE_ID_CHANGED")
    _require(value.get("question_class") == QUESTION_CLASS, "QUESTION_CLASS_CHANGED")
    _require(value.get("physical_campaign_opened") is False, "PHYSICAL_OPENED")
    _require(matrix.get("stage_id") == STAGE_ID, "STAGE_ID_CHANGED")
    _require(matrix.get("ordered_campaign_seeds") == list(DECISION_SEEDS), "SEEDS_CHANGED")
    _require(matrix.get("ordered_profile_ids") == list(ORDERED_PROFILE_IDS), "PROFILES_CHANGED")
    _require(matrix.get("profile_definitions") == PROFILE_DEFINITIONS, "PROFILE_DEFINITIONS_CHANGED")
    _require(matrix.get("initial_perturbations") == [INITIAL_PERTURBATIONS[s] for s in DECISION_SEEDS], "PERTURBATIONS_CHANGED")
    _require(matrix.get("cells") == [asdict(item) for item in cells()], "CELLS_CHANGED")
    _require(matrix.get("declared_cell_count") == 6, "CELL_COUNT_CHANGED")
    _require(matrix.get("declared_world_count") == 6, "WORLD_COUNT_CHANGED")
    _require(matrix.get("serial_execution_required") is True, "SERIAL_EXECUTION_CHANGED")
    _require(matrix.get("all_cells_run_regardless_of_intermediate_outcome") is True, "COMPLETE_MATRIX_CHANGED")
    _require(value.get("frozen_common_physical_gates") == COMMON_PHYSICAL_GATES, "COMMON_GATES_CHANGED")
    _require(rules.get("complete_execution_valid_matrix_required_before_selection") is True, "MATRIX_PREREQUISITE_CHANGED")
    _require(rules.get("profile_adequacy_rule") == "all_three_profile_cells_execution_valid_and_pass_every_frozen_common_physical_gate", "ADEQUACY_RULE_CHANGED")
    _require(rules.get("both_adequate_preference") == PROFILE_PORTABLE, "BOTH_ADEQUATE_PREFERENCE_CHANGED")
    _require(rules.get("superiority_claim_authorized") is False, "SUPERIORITY_CLAIM_CHANGED")
    _require(rules.get("equivalence_or_non_inferiority_claim_authorized") is False, "EQUIVALENCE_CLAIM_CHANGED")
    _require(reserved.get("campaign_id") == R23D60_CAMPAIGN_ID, "R23D60_CAMPAIGN_CHANGED")
    _require(reserved.get("campaign_seed") == RESERVED_R23D60_SEED, "R23D60_SEED_CHANGED")
    _require(reserved.get("initial_perturbation") == RESERVED_R23D60_INITIAL_PERTURBATION, "R23D60_PERTURBATION_CHANGED")
    _require(reserved.get("ordered_arm_offsets_rad") == R23D60_ARM_OFFSETS, "R23D60_ARMS_CHANGED")
    _require(reserved.get("minimum_raw_signed_cycle_shift_rad") == R23D60_MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD, "R23D60_RAW_FLOOR_CHANGED")
    _require(reserved.get("minimum_reference_conditioned_cycle_shift_rad") == R23D60_MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD, "R23D60_CONDITIONED_FLOOR_CHANGED")
    _require(reserved.get("physical_campaign_opened") is False, "R23D60_PHYSICAL_OPENED")
    _require(reserved.get("candidate_profile_resolved") is False, "R23D60_CANDIDATE_PRESELECTED")
    _require(dependencies.get("complete_transitive_runtime_and_declaration_inventory_required_before_physical_freeze") is True, "DEPENDENCY_COMPLETENESS_CHANGED")
    _require(dependencies.get("r23d58_result_reuse_forbidden") is True, "R23D58_REUSE_CHANGED")
    _require(
        claims.get("r23d59_local_declaration_gate_passed") is True,
        "LOCAL_DECLARATION_GATE_CHANGED",
    )
    _require(
        all(
            result is False
            for claim_id, result in claims.items()
            if claim_id != "r23d59_local_declaration_gate_passed"
        ),
        "FALSE_CLAIM_CHANGED",
    )


def audit_declaration(path: Path) -> dict[str, Any]:
    original = json.loads(path.read_text(encoding="utf-8"))
    validate_declaration(original)
    mutations: list[tuple[str, Any]] = [
        ("campaign_id", lambda v: v.__setitem__("campaign_id", "mutated")),
        ("question_class", lambda v: v.__setitem__("question_class", "development")),
        ("seed_order", lambda v: v["frozen_matrix"]["ordered_campaign_seeds"].reverse()),
        ("perturbation", lambda v: v["frozen_matrix"]["initial_perturbations"][0].__setitem__("fixture_yaw_rad", 0.0)),
        ("profile_order", lambda v: v["frozen_matrix"]["ordered_profile_ids"].reverse()),
        ("profile_source", lambda v: v["frozen_matrix"]["profile_definitions"][PROFILE_FIXTURE_KNEE].__setitem__("knee_cap_source", "mutated")),
        ("cell_omission", lambda v: v["frozen_matrix"]["cells"].pop()),
        ("contact_threshold", lambda v: v["frozen_common_physical_gates"].__setitem__("minimum_contact_cycles_per_limb", 1)),
        ("matrix_completion", lambda v: v["frozen_matrix"].__setitem__("all_cells_run_regardless_of_intermediate_outcome", False)),
        ("selection_preference", lambda v: v["finite_decision_rule"].__setitem__("both_adequate_preference", PROFILE_FIXTURE_KNEE)),
        ("r23d60_seed", lambda v: v["reserved_r23d60_held_out_turning_validation"].__setitem__("campaign_seed", 21_517)),
        ("r23d60_turning_floor", lambda v: v["reserved_r23d60_held_out_turning_validation"].__setitem__("minimum_raw_signed_cycle_shift_rad", 0.0)),
        ("turning_claim", lambda v: v["claims"].__setitem__("godot_jolt_turning", True)),
        ("physical_open", lambda v: v.__setitem__("physical_campaign_opened", True)),
    ]
    rejected = 0
    for name, mutate in mutations:
        candidate = copy.deepcopy(original)
        mutate(candidate)
        try:
            validate_declaration(candidate)
        except DeclarationError:
            rejected += 1
        else:
            raise DeclarationError(f"MUTATION_ACCEPTED:{name}")

    decision_cases = [
        decide_profile(matrix_execution_valid=False, portable_adequate=True, fixture_knee_adequate=True),
        decide_profile(matrix_execution_valid=True, portable_adequate=True, fixture_knee_adequate=False),
        decide_profile(matrix_execution_valid=True, portable_adequate=False, fixture_knee_adequate=True),
        decide_profile(matrix_execution_valid=True, portable_adequate=False, fixture_knee_adequate=False),
        decide_profile(matrix_execution_valid=True, portable_adequate=True, fixture_knee_adequate=True),
    ]
    _require(decision_cases[0]["selected_profile_id"] is None, "INVALID_MATRIX_SELECTED")
    _require(decision_cases[1]["selected_profile_id"] == PROFILE_PORTABLE, "PORTABLE_NOT_SELECTED")
    _require(decision_cases[2]["selected_profile_id"] == PROFILE_FIXTURE_KNEE, "FIXTURE_NOT_SELECTED")
    _require(decision_cases[3]["selected_profile_id"] is None, "NEITHER_SELECTED")
    _require(decision_cases[4]["selected_profile_id"] == PROFILE_PORTABLE, "PREFERENCE_NOT_APPLIED")
    _require(not any(math.isnan(float(item.turn_heading_offset_rad)) for item in cells()), "NONFINITE_CELL")
    return {
        "schema_version": "sporespore_qsdk_r23d59_preregistration_audit_v1",
        "campaign_id": CAMPAIGN_ID,
        "question_class": QUESTION_CLASS,
        "declared_cell_count": len(cells()),
        "decision_seed_count": len(DECISION_SEEDS),
        "reserved_held_out_seed_count": 1,
        "selection_case_count": len(decision_cases),
        "mutation_rejection_count": rejected,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_campaign_opened": False,
        "r23d60_physical_campaign_opened": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--declaration", type=Path, required=True)
    args = parser.parse_args()
    receipt = audit_declaration(args.declaration.resolve())
    print("QSDK_R23D59_PREREGISTRATION_AUDIT " + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
