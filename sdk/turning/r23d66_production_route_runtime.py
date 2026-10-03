"""Runtime projection of the frozen R23D66 finite turning declaration.

The accepted full-horizon evaluator and native workers consume a small Python
design surface.  This module projects that surface from the immutable R23D66
declaration while retaining the already accepted R23D65 data types and
profile constants.  It contains no physics entry point and constructs no
model or world.
"""

from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Any

import r23d65_selected_profile_three_engine_turning_validation as predecessor
import r23d66_production_route_three_engine_turning_validation as declaration


ROOT = Path(__file__).resolve().parent
DECLARATION_PATH = declaration.DECLARATION

CAMPAIGN_ID = declaration.CAMPAIGN_ID
GATE_ID = declaration.GATE_ID
QUESTION_CLASS = "finite_decision"
STAGE_ID = "production_route_qualified_selected_profile_three_engine_turning_validation"
CAMPAIGN_SEED = declaration.CAMPAIGN_SEED
CONTROLLER_STEPS = declaration.CONTROLLER_STEPS
TURN_START_STEP = declaration.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = declaration.TURN_END_STEP_EXCLUSIVE
RECOVERY_DURATION_STEPS = declaration.RECOVERY_DURATION_STEPS
ACTUATOR_COUNT = 8
ENGINES = declaration.ENGINES
ARMS = declaration.ARMS
INITIAL_PERTURBATION = declaration.INITIAL_PERTURBATION

MORPHOLOGY_ID = predecessor.MORPHOLOGY_ID
DESCRIPTOR_SHA256 = predecessor.DESCRIPTOR_SHA256
MORPHOLOGY_SPEC_SHA256 = predecessor.MORPHOLOGY_SPEC_SHA256
PROFILE_ID = predecessor.PROFILE_ID
PROFILE_SHA256 = predecessor.PROFILE_SHA256
PROFILE_SEMANTICS_ID = predecessor.PROFILE_SEMANTICS_ID
POLICY_ID = predecessor.POLICY_ID
TASK_ORIGIN_POLICY_ID = predecessor.TASK_ORIGIN_POLICY_ID
STARTUP_TRANSFORM_ID = predecessor.STARTUP_TRANSFORM_ID
ORDERED_CAPS_NMS = predecessor.ORDERED_CAPS_NMS
ORDERED_CAPS_BINARY64_HEX = predecessor.ORDERED_CAPS_BINARY64_HEX
HOST_MAPPING_IDS = predecessor.HOST_MAPPING_IDS

Cell = predecessor.Cell
DeclarationError = declaration.DeclarationError
raw_sha256 = declaration.raw_sha256


def cells() -> tuple[Cell, ...]:
    """Return the complete frozen engine-major, arm-minor R23D66 matrix."""

    return tuple(
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"r23d66__{engine_id}__s{CAMPAIGN_SEED}__{arm_id}",
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
    if len(matches) != 1:
        raise DeclarationError(
            f"QSDK_R23D66_RUNTIME_CELL_INVALID:{engine_id}:{arm_id}"
        )
    return matches[0]


def cell_by_id(cell_id: str) -> Cell:
    matches = [item for item in cells() if item.cell_id == cell_id]
    if len(matches) != 1:
        raise DeclarationError(f"QSDK_R23D66_RUNTIME_CELL_ID_INVALID:{cell_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if not 0 <= semantic_step < CONTROLLER_STEPS:
        raise DeclarationError(
            f"QSDK_R23D66_RUNTIME_SEMANTIC_STEP_INVALID:{semantic_step}"
        )
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


def load_declaration() -> dict[str, Any]:
    value = declaration.load_json(DECLARATION_PATH)
    declaration.validate_declaration(value)
    return value


def validate_runtime_projection() -> dict[str, Any]:
    """Prove this runtime projection is only a view of the frozen question."""

    frozen = load_declaration()
    matrix = frozen["frozen_matrix"]
    projected_cells = [asdict(item) for item in cells()]
    frozen_cells = matrix["cells"]
    exact = (
        matrix["seed"] == CAMPAIGN_SEED
        and matrix["controller_step_count"] == CONTROLLER_STEPS
        and matrix["turn_start_step"] == TURN_START_STEP
        and matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        and matrix["recovery_duration_steps"] == RECOVERY_DURATION_STEPS
        and matrix["ordered_engine_ids"] == list(ENGINES)
        and matrix["ordered_arm_ids"] == [item[0] for item in ARMS]
        and matrix["initial_perturbation"] == INITIAL_PERTURBATION
        and [
            {
                "cell_id": item["cell_id"],
                "engine_id": item["engine_id"],
                "arm_id": item["arm_id"],
                "turn_heading_offset_rad": item["turn_heading_offset_rad"],
            }
            for item in projected_cells
        ]
        == frozen_cells
        and sum(_declared_segment_counts().values()) == CONTROLLER_STEPS
    )
    if not exact:
        raise DeclarationError("QSDK_R23D66_RUNTIME_PROJECTION_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d66_runtime_projection_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "cell_count": len(projected_cells),
        "segment_counts": _declared_segment_counts(),
        "controller_step_count": CONTROLLER_STEPS,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
