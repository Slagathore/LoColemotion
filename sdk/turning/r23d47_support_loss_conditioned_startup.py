"""R23D47 CAS-receipt repair successor to consumed invalid R23D46."""

from __future__ import annotations

from dataclasses import dataclass

import r23d46_support_loss_conditioned_startup as parent


CAMPAIGN_ID = (
    "QSDK-R23D47-SUPPORT-LOSS-CONDITIONED-STARTUP-"
    "RETENTION-REPAIR-DEVELOPMENT"
)
GATE_ID = "QSDK-R23D47"
STAGE_ID = "mujoco_support_loss_conditioned_startup_retention_repair_development"
ENGINE_ID = parent.ENGINE_ID
ARM_ID = parent.ARM_ID
POLICY_ID = parent.POLICY_ID
CANDIDATE_ID = parent.CANDIDATE_ID
CONTROLLER_STEPS = parent.CONTROLLER_STEPS
TURN_START_STEP = parent.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = parent.TURN_END_STEP_EXCLUSIVE
TURN_DURATION_STEPS = parent.TURN_DURATION_STEPS
ACTUATOR_COUNT = parent.ACTUATOR_COUNT
GAIT_CYCLE_STEPS = parent.GAIT_CYCLE_STEPS
PHASE_OFFSETS = parent.PHASE_OFFSETS
RAMP_LAST_LOCAL_STEP = parent.RAMP_LAST_LOCAL_STEP
PROBE_LAST_SEMANTIC_STEP = parent.PROBE_LAST_SEMANTIC_STEP
STARTUP_TRANSFORM_ID = parent.STARTUP_TRANSFORM_ID
CAMPAIGN_SEED = parent.CAMPAIGN_SEED
MORPHOLOGY_ID = parent.MORPHOLOGY_ID
LIMB_IDS = parent.LIMB_IDS
TRACE_ROW_SCHEMA = parent.TRACE_ROW_SCHEMA
INITIAL_PERTURBATION = parent.INITIAL_PERTURBATION
StartupTransformError = parent.StartupTransformError
SupportLossConditionedStartup = parent.SupportLossConditionedStartup
smoothstep_scale = parent.smoothstep_scale


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    onset_id: str
    turn_start_semantic_step: int
    arm_id: str
    turn_heading_offset_rad: float


def cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"{ENGINE_ID}__{CANDIDATE_ID}__{ARM_ID}",
            engine_id=ENGINE_ID,
            onset_id="onset_600",
            turn_start_semantic_step=TURN_START_STEP,
            arm_id=ARM_ID,
            turn_heading_offset_rad=0.0,
        )
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
        raise StartupTransformError(
            f"R23D47_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}"
        )
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item != cells()[0] or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise StartupTransformError(f"R23D47_STEP_INVALID:{semantic_step}")
    return "reference_walk", 0.0


def stage_a_cells() -> list[Cell]:
    return cells()


def stage_b_cells(onset_id: str) -> list[Cell]:
    return cells() if onset_id == "onset_600" else []


def expected_segment_counts(item: Cell) -> dict[str, int]:
    if item != cells()[0]:
        raise StartupTransformError("R23D47_SEGMENT_CELL_INVALID")
    return {"reference_walk": CONTROLLER_STEPS}
