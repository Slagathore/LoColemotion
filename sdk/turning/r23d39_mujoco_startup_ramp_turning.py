"""Pure identity, schedule, and inherited startup ramp for QSDK-R23D39.

R23D38 selected the exact one-cycle canonical-velocity startup ramp on the
outcome-exposed MuJoCo seed-21507 reference condition.  R23D39 keeps that
mechanism and every physical dependency fixed, adds the already-established
bilateral heading-command arms, and asks only whether the stabilized body can
walk and satisfy the frozen cycle-integrated turning selector in MuJoCo.
"""

from __future__ import annotations

from dataclasses import dataclass

import r23d38_mujoco_startup_ramp_stabilization as inherited_ramp


CAMPAIGN_ID = "QSDK-R23D39-MUJOCO-R23D29-STARTUP-RAMP-TURNING-DEVELOPMENT"
GATE_ID = "QSDK-R23D39"
STAGE_ID = "mujoco_r23d29_startup_ramp_turning_development"
ENGINE_ID = "mujoco"
POLICY_ID = inherited_ramp.POLICY_ID
CANDIDATE_ID = "r23d29_startup_ramp_turning_development"
CONTROLLER_STEPS = inherited_ramp.CONTROLLER_STEPS
TURN_START_STEP = inherited_ramp.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = inherited_ramp.TURN_END_STEP_EXCLUSIVE
TURN_DURATION_STEPS = TURN_END_STEP_EXCLUSIVE - TURN_START_STEP
RECOVERY_DURATION_STEPS = 600
ACTUATOR_COUNT = inherited_ramp.ACTUATOR_COUNT
GAIT_CYCLE_STEPS = inherited_ramp.GAIT_CYCLE_STEPS
STARTUP_RAMP_STEPS = inherited_ramp.STARTUP_RAMP_STEPS
STARTUP_RAMP_ID = inherited_ramp.STARTUP_RAMP_ID
CAMPAIGN_SEED = inherited_ramp.CAMPAIGN_SEED
MORPHOLOGY_ID = inherited_ramp.MORPHOLOGY_ID
LIMB_IDS = inherited_ramp.LIMB_IDS
PHASE_OFFSETS = inherited_ramp.PHASE_OFFSETS
TRACE_ROW_SCHEMA = inherited_ramp.TRACE_ROW_SCHEMA
INITIAL_PERTURBATION = inherited_ramp.INITIAL_PERTURBATION
ENGINE_IDS = (ENGINE_ID,)
ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}


def startup_velocity_scale(semantic_step: int) -> float:
    """Return the byte-inherited R23D38 one-cycle smoothstep scale."""

    return inherited_ramp.startup_velocity_scale(semantic_step)


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
    """Return the exact serialized three-cell MuJoCo matrix."""

    return [
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"{ENGINE_ID}__{CANDIDATE_ID}__{arm_id}",
            engine_id=ENGINE_ID,
            onset_id="onset_600",
            turn_start_semantic_step=TURN_START_STEP,
            arm_id=arm_id,
            turn_heading_offset_rad=offset,
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
        raise ValueError(f"R23D39_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if not 0 <= semantic_step < CONTROLLER_STEPS:
        raise ValueError(f"R23D39_STEP_INVALID:{semantic_step}")
    if semantic_step < item.turn_start_semantic_step:
        return "reference_warmup", 0.0
    if semantic_step < item.turn_start_semantic_step + TURN_DURATION_STEPS:
        return "commanded_turn", item.turn_heading_offset_rad
    if (
        semantic_step
        < item.turn_start_semantic_step
        + TURN_DURATION_STEPS
        + RECOVERY_DURATION_STEPS
    ):
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    return {
        "reference_warmup": item.turn_start_semantic_step,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": RECOVERY_DURATION_STEPS,
        "after_declared_schedule": (
            CONTROLLER_STEPS
            - item.turn_start_semantic_step
            - TURN_DURATION_STEPS
            - RECOVERY_DURATION_STEPS
        ),
    }
