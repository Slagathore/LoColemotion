"""Pure zero-world identity for the R23D36 MuJoCo walking restoration."""

from __future__ import annotations

from dataclasses import dataclass


CAMPAIGN_ID = "QSDK-R23D36-MUJOCO-R23D29-BW19V-WALKING-RESTORATION"
GATE_ID = "QSDK-R23D36"
STAGE_ID = "mujoco_r23d29_bw19v_walking_restoration"
POLICY_ID = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
    "stability_guarded_steering_v1"
)
STABILITY_POLICY_ID = "sporespore_scheduled_load_transfer_bw13p_a_v3"
CANDIDATE_ID = "r23d29_with_bw19v_load_transfer_residual"
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_DURATION_STEPS = 1_200
ACTUATOR_COUNT = 8
GAIT_CYCLE_STEPS = 360
CAMPAIGN_SEED = 21_507
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
ENGINE_ID = "mujoco"
ARM_ID = "reference_zero"
LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
PHASE_OFFSETS = (0, 90, 180, 270)
ACTUATOR_IDS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d36_walking_restoration_trace_row_v1"
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
    """Return the exact one-world restoration screen."""

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
        raise ValueError(f"R23D36_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item != cells()[0] or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise ValueError(f"R23D36_STEP_INVALID:{semantic_step}")
    return "reference_walk", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    if item != cells()[0]:
        raise ValueError("R23D36_CELL_INVALID")
    return {"reference_walk": CONTROLLER_STEPS}
