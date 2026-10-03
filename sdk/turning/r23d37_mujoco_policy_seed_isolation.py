"""Pure identity and schedule for the QSDK-R23D37 development screen."""

from __future__ import annotations

from dataclasses import dataclass


CAMPAIGN_ID = "QSDK-R23D37-MUJOCO-R23D21-POLICY-SEED-ISOLATION"
GATE_ID = "QSDK-R23D37"
STAGE_ID = "mujoco_r23d21_same_seed_policy_isolation"
ENGINE_ID = "mujoco"
ARM_ID = "reference_zero"
POLICY_ID = "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1"
CANDIDATE_ID = "r23d21_same_seed_policy_isolation"
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
TURN_DURATION_STEPS = TURN_END_STEP_EXCLUSIVE - TURN_START_STEP
ACTUATOR_COUNT = 8
GAIT_CYCLE_STEPS = 360
CAMPAIGN_SEED = 21_507
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
PHASE_OFFSETS = (0, 90, 180, 270)
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1"
INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.000752027379348874,
    "fixture_yaw_rad": 0.00378431053832173,
    "initial_linear_velocity_world_m_s": [
        0.00160547578707337,
        0.0,
        0.00106023065745831,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.000368934357538819,
        -0.00194891076534987,
        -0.00188004493247718,
    ],
    "gait_phase_offset_ticks": -3,
}


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
        raise ValueError(f"R23D37_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item != cells()[0] or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise ValueError(f"R23D37_STEP_INVALID:{semantic_step}")
    return "reference_walk", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    if item != cells()[0]:
        raise ValueError(f"R23D37_CELL_INVALID:{item.cell_id}")
    return {"reference_walk": CONTROLLER_STEPS}
