"""Runtime projection for the compact R23D69 finite turning declaration.

R23D69 intentionally stores only its fresh campaign identity, seed fixture,
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
    / "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json"
)

SCHEMA = (
    "sporespore_qsdk_r23d69_complete_production_row_conformance_repaired_"
    "three_engine_turning_preregistration_v1"
)
STATUS = (
    "prospective_declaration_complete_compact_production_row_ghosts_"
    "and_implementation_pending_physical_not_authorized"
)
CAMPAIGN_ID = (
    "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D69"
QUESTION_CLASS = "finite_decision"
STAGE_ID = "complete_production_row_conformance_repaired_three_engine_turning_validation"
CAMPAIGN_SEED = 23_187

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
    "fixture_vertical_clearance_m": 0.00010815839777933434,
    "fixture_yaw_rad": 0.0055464268662035465,
    "initial_linear_velocity_world_m_s": [
        0.002818681765347719,
        0.0,
        -0.000058669596910476685,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.000020042527467012405,
        -0.0031501215416938066,
        0.001983115216717124,
    ],
    "gait_phase_offset_ticks": 1,
}

Cell = base.Cell


class DeclarationError(ValueError):
    """Raised when the compact declaration no longer projects exactly."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DeclarationError(f"QSDK_R23D69_RUNTIME_{code}")


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise DeclarationError(
            f"QSDK_R23D69_RUNTIME_JSON_UNREADABLE:{type(error).__name__}"
        ) from error
    _require(isinstance(value, dict), "JSON_ROOT_INVALID")
    return value


def cells() -> tuple[Cell, ...]:
    """Return the complete frozen engine-major, arm-minor R23D69 matrix."""

    return tuple(
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"r23d69__{engine_id}__s{CAMPAIGN_SEED}__{arm_id}",
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
    """Validate the compact overlay and its exact inherited behavior binding."""

    _require(value.get("schema_version") == SCHEMA, "SCHEMA_INVALID")
    _require(value.get("status") == STATUS, "STATUS_INVALID")
    _require(value.get("campaign_id") == CAMPAIGN_ID, "CAMPAIGN_ID_INVALID")
    _require(value.get("gate_id") == GATE_ID, "GATE_ID_INVALID")
    _require(value.get("release_gate_id") == "QSDK-R23", "RELEASE_GATE_ID_INVALID")
    _require(value.get("physical_question_class") == QUESTION_CLASS, "QUESTION_CLASS_INVALID")
    _require(
        value.get("ledger_scope")
        == {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "prospective_declaration",
            "question_class": "finite_decision",
        },
        "LEDGER_SCOPE_INVALID",
    )

    inherited = value.get("inherited_behavior_contract", {})
    immediate_base_path = (
        REPO_ROOT
        / "sdk"
        / "turning"
        / "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json"
    )
    _require(
        inherited.get("immediate_base_path")
        == "sdk/turning/r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "IMMEDIATE_BASE_PATH_INVALID",
    )
    _require(
        inherited.get("immediate_base_raw_sha256")
        == "sha256:6d538c8678951c92bce81e32ba29d076148ad640653d7a3164ad2388614a10b7",
        "IMMEDIATE_BASE_DIGEST_INVALID",
    )
    _require(
        raw_sha256(immediate_base_path) == inherited.get("immediate_base_raw_sha256"),
        "LIVE_IMMEDIATE_BASE_DIGEST_INVALID",
    )
    _require(
        inherited.get("root_base_path")
        == "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json",
        "ROOT_BASE_PATH_INVALID",
    )
    _require(
        inherited.get("root_base_raw_sha256")
        == "sha256:d625d911c6f582a1bccd5bf6b8fd019e93befd7893dc0e6ededbd5870c32571a",
        "ROOT_BASE_DIGEST_INVALID",
    )
    _require(
        raw_sha256(base.DECLARATION_PATH) == inherited.get("root_base_raw_sha256"),
        "LIVE_ROOT_BASE_DIGEST_INVALID",
    )
    _require(
        inherited.get("threshold_selector_evaluator_or_interpretation_change_count")
        == 0,
        "BEHAVIOR_CHANGE_INVALID",
    )
    _require(
        inherited.get("controller_profile_schedule_or_measurement_change_count")
        == 0,
        "CONTROLLER_CHANGE_INVALID",
    )
    _require(
        inherited.get("engine_or_arm_population_change_count") == 0,
        "POPULATION_CHANGE_INVALID",
    )

    distinction = value.get("scientific_distinction_and_change_budget", {})
    _require(distinction.get("fresh_seed") == CAMPAIGN_SEED, "FRESH_SEED_INVALID")
    _require(
        distinction.get("first_candidate_token_occurrence_count_at_declaration_parent")
        == 0,
        "FRESH_SEED_OCCURRENCE_INVALID",
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

    matrix = value.get("frozen_matrix", {})
    _require(matrix.get("campaign_seed") == CAMPAIGN_SEED, "MATRIX_SEED_INVALID")
    _require(matrix.get("engine_order") == list(ENGINES), "ENGINE_ORDER_INVALID")
    _require(
        matrix.get("arm_order") == [arm_id for arm_id, _ in ARMS],
        "ARM_ORDER_INVALID",
    )
    _require(
        matrix.get("ordered_cell_ids") == [item.cell_id for item in cells()],
        "CELL_ORDER_INVALID",
    )
    _require(
        matrix.get("declared_cell_count") == 9
        and matrix.get("complete_population_required") is True
        and matrix.get("sampling_used") is False,
        "MATRIX_COMPLETENESS_INVALID",
    )

    observed = value.get("observed_predecessor_integration_population", {})
    items = observed.get("items", [])
    _require(
        observed.get("complete_population_required") is True
        and observed.get("sampling_used") is False
        and observed.get("population_size") == 4
        and isinstance(items, list)
        and [item.get("failure_id") for item in items]
        == [
            "godot_actuator_phase_observation_missing",
            "rapier_post_schedule_segment_relabel",
            "mujoco_non_native_boolean_strict_json_failure",
            "mujoco_outer_failure_projection_lost_inner_counts",
        ]
        and observed.get("conformance_margin") == 0
        and observed.get("physical_world_count") == 0,
        "OBSERVED_INTEGRATION_POPULATION_INVALID",
    )
    ghost = value.get("compact_development_ghosts", {})
    _require(
        ghost.get("representative_semantic_steps")
        == [599, 600, 1799, 1800, 2399, 2400, 2991]
        and ghost.get("engine_count") == 3
        and ghost.get("representative_complete_row_count") == 21
        and ghost.get("failure_projection_case_count") == 2
        and ghost.get("inner_failure_receipt_preservation_required") is True
        and ghost.get("model_construction_count") == 0
        and ghost.get("world_attempt_count") == 0
        and ghost.get("world_build_count") == 0
        and ghost.get("physical_acceptance_authority") is False,
        "COMPACT_COMPLETE_ROW_GHOST_CONTRACT_INVALID",
    )



def load_declaration() -> dict[str, Any]:
    """Project the compact overlay onto the exact inherited behavior contract."""

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
        physical_question_declared=True,
        physical_campaign_opened=False,
        seed_fixture_compilation=copy.deepcopy(source["seed_fixture_compilation"]),
        inherited_behavior_contract=copy.deepcopy(source["inherited_behavior_contract"]),
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
    exact = (
        matrix["seed"] == CAMPAIGN_SEED
        and matrix["controller_step_count"] == CONTROLLER_STEPS
        and matrix["turn_start_step"] == TURN_START_STEP
        and matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        and matrix["recovery_duration_steps"] == RECOVERY_DURATION_STEPS
        and matrix["ordered_engine_ids"] == list(ENGINES)
        and matrix["ordered_arm_ids"] == [item[0] for item in ARMS]
        and matrix["initial_perturbation"] == INITIAL_PERTURBATION
        and [item["cell_id"] for item in projected_cells]
        == source["frozen_matrix"]["ordered_cell_ids"]
        and sum(_declared_segment_counts().values()) == CONTROLLER_STEPS
    )
    _require(exact, "PROJECTION_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d69_runtime_projection_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "cell_count": len(projected_cells),
        "segment_counts": _declared_segment_counts(),
        "controller_step_count": CONTROLLER_STEPS,
        "root_behavior_contract_raw_sha256": raw_sha256(base.DECLARATION_PATH),
        "immediate_base_contract_raw_sha256": raw_sha256(
            REPO_ROOT
            / "sdk"
            / "turning"
            / "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json"
        ),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
