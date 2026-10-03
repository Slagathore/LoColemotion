"""Runtime projection for the compact R23D76 finite turning declaration.

R23D76 intentionally stores only its fresh campaign identity, seed fixture,
authorization repair, and exact R23D66 behavior-contract binding.  This module
projects that compact overlay onto the immutable R23D66 behavior surface for
the accepted evaluator and native workers.  It contains no physics entry point
and constructs no model or world.
"""

from __future__ import annotations

import copy
import hashlib
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

import r23d66_production_route_runtime as base


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
DECLARATION_PATH = (
    ROOT
    / "r23d76_fresh_finite_three_engine_turning_decision_v1.json"
)

SCHEMA = "sporespore_qsdk_r23d76_fresh_finite_three_engine_turning_decision_v1"
STATUS = "prospective_declaration_complete_implementation_pending_physical_not_authorized"
CAMPAIGN_ID = "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
GATE_ID = "QSDK-R23D76"
QUESTION_CLASS = "finite_decision"
STAGE_ID = "fresh_finite_three_engine_turning_decision"
CAMPAIGN_SEED = 23_197
MEASUREMENT_ORIGIN_POLICY_ID = "evidence_window_start_semantic_step_v1"
MEASUREMENT_ORIGIN_SEMANTIC_STEP = 472
NATIVE_STARTUP_BINDING_CONTRACT_ID = (
    "QSDK-R23D75-NATIVE-STARTUP-TRACE-EVALUATOR-CONFORMANCE-DEVELOPMENT"
)
SUPPORT_LOSS_STARTUP_ID = "support_loss_latched_smoothstep_one_cycle_v1"
MUJOCO_STARTUP_RAMP_ID = "canonical_velocity_smoothstep_one_gait_cycle_v1"
MUJOCO_STARTUP_RAMP_STEP_COUNT = 360
STARTUP_TRANSFORM_BY_ENGINE = {
    "godot_jolt": SUPPORT_LOSS_STARTUP_ID,
    "rapier_parry": SUPPORT_LOSS_STARTUP_ID,
    "mujoco": MUJOCO_STARTUP_RAMP_ID,
}

CONTROLLER_STEPS = base.CONTROLLER_STEPS
TURN_START_STEP = base.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = base.TURN_END_STEP_EXCLUSIVE
RECOVERY_DURATION_STEPS = base.RECOVERY_DURATION_STEPS
ACTUATOR_COUNT = base.ACTUATOR_COUNT
ENGINES = base.ENGINES
ARMS = base.ARMS

MORPHOLOGY_ID = base.MORPHOLOGY_ID
DESCRIPTOR_SHA256 = base.DESCRIPTOR_SHA256
MORPHOLOGY_SPEC_SHA256 = base.MORPHOLOGY_SPEC_SHA256
PROFILE_ID = base.PROFILE_ID
PROFILE_SHA256 = base.PROFILE_SHA256
PROFILE_SEMANTICS_ID = base.PROFILE_SEMANTICS_ID
POLICY_ID = base.POLICY_ID
TASK_ORIGIN_POLICY_ID = base.TASK_ORIGIN_POLICY_ID
STARTUP_TRANSFORM_ID = base.STARTUP_TRANSFORM_ID
ORDERED_CAPS_NMS = base.ORDERED_CAPS_NMS
ORDERED_CAPS_BINARY64_HEX = base.ORDERED_CAPS_BINARY64_HEX
HOST_MAPPING_IDS = base.HOST_MAPPING_IDS

INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.0008048271993175149,
    "fixture_yaw_rad": 0.006968908477574587,
    "initial_linear_velocity_world_m_s": [
        0.0011139935813844204,
        0.0,
        0.0009957263246178627,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.001996839651837945,
        0.0015670480206608772,
        0.0010064903181046247,
    ],
    "gait_phase_offset_ticks": -3,
}

Cell = base.Cell


class DeclarationError(ValueError):
    """Raised when the compact declaration no longer projects exactly."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DeclarationError(f"QSDK_R23D76_RUNTIME_{code}")


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise DeclarationError(
            f"QSDK_R23D76_RUNTIME_JSON_UNREADABLE:{type(error).__name__}"
        ) from error
    _require(isinstance(value, dict), "JSON_ROOT_INVALID")
    return value


def cells() -> tuple[Cell, ...]:
    """Return the complete frozen engine-major, arm-minor R23D76 matrix."""

    return tuple(
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"r23d76__{engine_id}__s{CAMPAIGN_SEED}__{arm_id}",
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
    matches = [
        item
        for item in cells()
        if item.engine_id == engine_id and item.arm_id == arm_id
    ]
    _require(len(matches) == 1, f"CELL_INVALID:{engine_id}:{arm_id}")
    return matches[0]


def cell_by_id(cell_id: str) -> Cell:
    matches = [item for item in cells() if item.cell_id == cell_id]
    _require(len(matches) == 1, f"CELL_ID_INVALID:{cell_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    _require(0 <= semantic_step < CONTROLLER_STEPS, "SEMANTIC_STEP_INVALID")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", item.turn_heading_offset_rad
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "reference_continuation", 0.0


def _declared_segment_counts() -> dict[str, int]:
    return {
        "reference_warmup": 600,
        "commanded_turn": 1_200,
        "reference_recovery": 600,
        "reference_continuation": 592,
    }


def expected_segment_counts(_item: Cell | None = None) -> dict[str, int]:
    return _declared_segment_counts()


def load_source_declaration() -> dict[str, Any]:
    value = _read_json(DECLARATION_PATH)
    validate_declaration(value)
    return value


def validate_declaration(value: dict[str, Any]) -> None:
    """Validate the exact fresh finite R23D76 source declaration."""

    _require(value.get("schema_version") == SCHEMA, "SCHEMA_INVALID")
    _require(value.get("status") == STATUS, "STATUS_INVALID")
    _require(value.get("campaign_id") == CAMPAIGN_ID, "CAMPAIGN_ID_INVALID")
    _require(value.get("gate_id") == GATE_ID, "GATE_ID_INVALID")
    _require(value.get("release_gate_id") == "QSDK-R23", "RELEASE_GATE_ID_INVALID")
    _require(value.get("question_class") == QUESTION_CLASS, "QUESTION_CLASS_INVALID")
    _require(
        value.get("ledger_scope")
        == {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "prospective_declaration",
            "question_class": QUESTION_CLASS,
        },
        "LEDGER_SCOPE_INVALID",
    )
    _require(value.get("not_development_work") is True, "DEVELOPMENT_CLASS_INVALID")
    _require(value.get("not_superiority_work") is True, "SUPERIORITY_CLASS_INVALID")
    _require(
        value.get("not_equivalence_or_non_inferiority_work") is True,
        "EQUIVALENCE_CLASS_INVALID",
    )

    selection = value.get("held_out_seed_selection", {})
    _require(selection.get("seed") == CAMPAIGN_SEED, "FRESH_SEED_INVALID")
    _require(selection.get("first_fresh_candidate") == CAMPAIGN_SEED, "CANDIDATE_INVALID")
    _require(
        selection.get("first_fresh_candidate_token_occurrence_count_at_declaration_parent")
        == 0,
        "FRESH_SEED_OCCURRENCE_INVALID",
    )
    _require(
        selection.get("selection_performed_after_development_design_frozen") is True
        and selection.get("physical_outcome_observed_at_selection") is False
        and selection.get("physical_world_opened_at_selection") is False
        and selection.get("held_out_for_prospective_native_validation") is True,
        "HELD_OUT_SELECTION_INVALID",
    )

    fixture = value.get("seed_fixture_compilation", {})
    compiled = copy.deepcopy(fixture.get("compiled_initial_perturbation", {}))
    compiled.pop("cohort", None)
    _require(fixture.get("seed") == CAMPAIGN_SEED, "FIXTURE_SEED_INVALID")
    _require(compiled == INITIAL_PERTURBATION, "FIXTURE_INVALID")
    _require(
        fixture.get("model_construction_count") == 0
        and fixture.get("world_attempt_count") == 0
        and fixture.get("world_build_count") == 0,
        "FIXTURE_WORLD_COUNT_INVALID",
    )

    population = value.get("finite_population", {})
    _require(population.get("engine_order") == list(ENGINES), "ENGINE_ORDER_INVALID")
    _require(
        population.get("arm_order") == [arm_id for arm_id, _ in ARMS],
        "ARM_ORDER_INVALID",
    )
    _require(
        population.get("arm_heading_offsets_rad")
        == {arm_id: offset for arm_id, offset in ARMS},
        "ARM_OFFSETS_INVALID",
    )
    _require(
        population.get("ordered_cell_ids") == [item.cell_id for item in cells()],
        "CELL_ORDER_INVALID",
    )
    _require(
        population.get("declared_engine_count") == 3
        and population.get("declared_arm_count") == 3
        and population.get("declared_cell_count") == 9
        and population.get("sampling_used") is False
        and population.get("complete_enumeration_required") is True
        and population.get("all_cells_run_regardless_of_intermediate_behavior") is True
        and population.get("selective_completion_or_rerun_allowed") is False
        and population.get("population_inference_beyond_declared_matrix_allowed")
        is False,
        "FINITE_POPULATION_INVALID",
    )

    schedule = value.get("fixed_schedule", {})
    _require(
        schedule
        == {
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "first_semantic_step": 0,
            "last_semantic_step": CONTROLLER_STEPS - 1,
            "reference_warmup_step_count": TURN_START_STEP,
            "commanded_turn_step_count": TURN_END_STEP_EXCLUSIVE - TURN_START_STEP,
            "reference_recovery_step_count": RECOVERY_DURATION_STEPS,
            "reference_continuation_step_count": (
                CONTROLLER_STEPS - TURN_END_STEP_EXCLUSIVE - RECOVERY_DURATION_STEPS
            ),
            "turn_start_semantic_step": TURN_START_STEP,
            "turn_end_semantic_step_exclusive": TURN_END_STEP_EXCLUSIVE,
            "forward_displacement_measurement_origin_policy_id": (
                MEASUREMENT_ORIGIN_POLICY_ID
            ),
            "forward_displacement_measurement_origin_semantic_step": (
                MEASUREMENT_ORIGIN_SEMANTIC_STEP
            ),
            "native_startup_binding_contract_id": NATIVE_STARTUP_BINDING_CONTRACT_ID,
            "startup_transform_by_engine": STARTUP_TRANSFORM_BY_ENGINE,
            "startup_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
        },
        "FIXED_SCHEDULE_INVALID",
    )

    change = value.get("scientific_change_budget", {})
    _require(
        change.get("fresh_campaign_identity") is True
        and change.get("fresh_seed_and_compiled_initial_perturbation") is True
        and change.get("engine_aware_native_startup_evaluator_binding") is True
        and change.get("new_campaign_transport_identities") is True,
        "ALLOWED_CHANGE_BUDGET_INVALID",
    )
    for key in (
        "physical_command_changed",
        "behavior_threshold_changed",
        "selector_changed",
        "cycle_measurement_changed",
        "behavior_evaluator_changed",
        "controller_changed",
        "public_profile_changed",
        "schedule_changed",
        "engine_or_arm_population_changed",
        "native_startup_policy_changed",
        "historical_campaign_changed",
        "historical_evidence_reused_as_r23d76_result",
    ):
        _require(change.get(key) is False, f"FORBIDDEN_CHANGE_INVALID:{key}")

    thresholds = value.get("thresholds_and_estimator", {})
    expected_common = copy.deepcopy(base.load_declaration()["frozen_common_physical_gates"])
    expected_common.pop("maximum_portable_impulse_violation_count", None)
    _require(
        thresholds.get("common_physical_gate_vector") == expected_common,
        "COMMON_GATE_VECTOR_INVALID",
    )
    _require(
        thresholds.get("minimum_positive_raw_cycle_shift_rad") == 0.01
        and thresholds.get("maximum_negative_raw_cycle_shift_rad") == -0.01
        and thresholds.get("minimum_positive_reference_conditioned_cycle_shift_rad")
        == 0.01
        and thresholds.get("minimum_negative_reference_conditioned_cycle_shift_rad")
        == 0.01,
        "TURNING_THRESHOLDS_INVALID",
    )
    _require(
        thresholds.get("equivalence_margin") is None
        and thresholds.get("non_inferiority_margin") is None
        and thresholds.get("equivalence_or_non_inferiority_interpretation_allowed")
        is False,
        "MARGIN_INVALID",
    )

    zero_world = value.get("required_zero_world_implementation_gate", {})
    _require(
        zero_world.get("full_seeded_world_ghost_required") is False
        and zero_world.get("behavioral_success_prediction_allowed") is False,
        "GHOST_SCOPE_INVALID",
    )
    for key in (
        "production_worker_parse_and_route_construction_required",
        "compact_success_terminal_projection_required",
        "exact_seed_fixture_recompilation_required",
        "complete_three_engine_source_binding_required",
        "complete_nine_cell_selector_proof_required",
        "authorization_failure_before_model_required",
        "threshold_and_schedule_mutation_controls_required",
        "r23d74_closure_replay_required",
        "r23d75_conformance_closure_replay_required",
    ):
        _require(zero_world.get(key) is True, f"ZERO_WORLD_CONTROL_INVALID:{key}")
    _require(
        all(
            zero_world.get(key) == 0
            for key in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        ),
        "ZERO_WORLD_COUNT_INVALID",
    )

    smoke = value.get("post_zero_world_native_smoke", {})
    _require(
        smoke.get("required_before_qualification") is True
        and smoke.get("engine_count") == 3
        and smoke.get("maximum_world_count") == 3
        and smoke.get("maximum_solver_step_count_per_world") == 2
        and smoke.get("uses_held_out_seed_23197") is False
        and smoke.get("behavior_thresholds_applied") is False
        and smoke.get("behavioral_success_prediction_allowed") is False
        and smoke.get("finite_evidence") is False
        and smoke.get("physical_acceptance_authority") is False,
        "BOUNDED_NATIVE_SMOKE_INVALID",
    )

    authorization = value.get("physical_authorization", {})
    claims = value.get("claims", {})
    _require(
        authorization.get("physical_execution_authorized") is False
        and authorization.get("physical_acceptance_authority") is False,
        "SOURCE_AUTHORIZATION_INVALID",
    )
    _require(
        claims.get("implementation_complete") is False
        and claims.get("zero_world_gate_passed") is False
        and claims.get("native_smoke_passed") is False
        and claims.get("physical_campaign_opened") is False
        and claims.get("finite_three_engine_turning") is False
        and claims.get("portable_basic_turning") is False
        and claims.get("release_score_before") == "10/25"
        and claims.get("release_score_after") == "10/25"
        and claims.get("release_authorized") is False,
        "SOURCE_CLAIMS_INVALID",
    )


def load_declaration() -> dict[str, Any]:
    """Project R23D76 identity onto the unchanged R23D66 behavior contract."""

    source = load_source_declaration()
    projected = copy.deepcopy(base.load_declaration())
    projected.update(
        schema_version=SCHEMA,
        status=STATUS,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        release_gate_id="QSDK-R23",
        ledger_scope=copy.deepcopy(source["ledger_scope"]),
        physical_question_class=QUESTION_CLASS,
        question_class=QUESTION_CLASS,
        physical_question_declared=True,
        physical_campaign_opened=False,
        seed_fixture_compilation=copy.deepcopy(source["seed_fixture_compilation"]),
        fixed_schedule=copy.deepcopy(source["fixed_schedule"]),
        thresholds_and_estimator=copy.deepcopy(source["thresholds_and_estimator"]),
    )
    matrix = projected["frozen_matrix"]
    matrix.update(
        stage_id=STAGE_ID,
        seed=CAMPAIGN_SEED,
        initial_perturbation=copy.deepcopy(INITIAL_PERTURBATION),
        cells=[
            {
                "cell_id": item.cell_id,
                "engine_id": item.engine_id,
                "arm_id": item.arm_id,
                "turn_heading_offset_rad": item.turn_heading_offset_rad,
            }
            for item in cells()
        ],
    )
    return projected


def validate_runtime_projection() -> dict[str, Any]:
    source = load_source_declaration()
    projected = load_declaration()
    matrix = projected["frozen_matrix"]
    projected_cells = [asdict(item) for item in cells()]
    schedule = source["fixed_schedule"]
    population = source["finite_population"]
    exact = (
        matrix["seed"] == CAMPAIGN_SEED
        and matrix["controller_step_count"] == CONTROLLER_STEPS
        and matrix["turn_start_step"] == TURN_START_STEP
        and matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        and matrix["recovery_duration_steps"] == RECOVERY_DURATION_STEPS
        and matrix["ordered_engine_ids"] == population["engine_order"]
        and matrix["ordered_arm_ids"] == population["arm_order"]
        and matrix["initial_perturbation"] == INITIAL_PERTURBATION
        and [item["cell_id"] for item in projected_cells]
        == population["ordered_cell_ids"]
        and schedule["controller_semantic_step_count"] == CONTROLLER_STEPS
        and schedule["forward_displacement_measurement_origin_semantic_step"]
        == MEASUREMENT_ORIGIN_SEMANTIC_STEP
        and schedule["native_startup_binding_contract_id"]
        == NATIVE_STARTUP_BINDING_CONTRACT_ID
        and schedule["startup_transform_by_engine"] == STARTUP_TRANSFORM_BY_ENGINE
        and schedule["startup_step_count"] == MUJOCO_STARTUP_RAMP_STEP_COUNT
        and sum(_declared_segment_counts().values()) == CONTROLLER_STEPS
    )
    _require(exact, "PROJECTION_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d76_runtime_projection_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "cell_count": len(projected_cells),
        "segment_counts": _declared_segment_counts(),
        "controller_step_count": CONTROLLER_STEPS,
        "measurement_origin_policy_id": MEASUREMENT_ORIGIN_POLICY_ID,
        "measurement_origin_semantic_step": MEASUREMENT_ORIGIN_SEMANTIC_STEP,
        "native_startup_binding_contract_id": NATIVE_STARTUP_BINDING_CONTRACT_ID,
        "startup_transform_by_engine": copy.deepcopy(STARTUP_TRANSFORM_BY_ENGINE),
        "startup_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
        "source_declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "root_behavior_contract_raw_sha256": raw_sha256(base.DECLARATION_PATH),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
