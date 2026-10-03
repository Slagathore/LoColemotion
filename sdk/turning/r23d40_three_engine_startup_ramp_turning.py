"""Pure finite matrix and startup transform for QSDK-R23D40.

R23D40 is the first fresh validation that applies the already selected R23D29
policy and one-cycle canonical-velocity startup ramp to all three advertised
physics engines in one prospectively frozen matrix.
"""

from __future__ import annotations

from dataclasses import dataclass


CAMPAIGN_ID = "QSDK-R23D40-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION"
GATE_ID = "QSDK-R23D40"
RELEASE_GATE_ID = "QSDK-R23"
STAGE_ID = "three_engine_startup_ramp_turning_validation"
POLICY_ID = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
    "stability_guarded_steering_v1"
)
CANDIDATE_ID = "r23d29_startup_ramp_turning_validation"
ENGINE_IDS = ("rapier_parry", "godot_jolt", "mujoco")
ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
TURN_DURATION_STEPS = TURN_END_STEP_EXCLUSIVE - TURN_START_STEP
RECOVERY_DURATION_STEPS = 600
ACTUATOR_COUNT = 8
GAIT_CYCLE_STEPS = 360
STARTUP_RAMP_STEPS = GAIT_CYCLE_STEPS
STARTUP_RAMP_ID = "canonical_velocity_smoothstep_one_gait_cycle_v1"
CAMPAIGN_SEED = 21_508
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
PHASE_OFFSETS = (0, 90, 180, 270)
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d40_turning_trace_row_v1"
INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.000299032486509532,
    "fixture_yaw_rad": -0.00125696277245879,
    "initial_linear_velocity_world_m_s": [
        -0.0021639212500304,
        0.0,
        -0.000117000658065081,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.00184677203651518,
        -0.00000263703987002373,
        0.00165484147146344,
    ],
    "gait_phase_offset_ticks": 3,
}


def startup_velocity_scale(semantic_step: int) -> float:
    """Scale canonical velocity from exact zero to exact unity in one cycle."""

    if semantic_step < 0:
        raise ValueError(f"R23D40_STEP_INVALID:{semantic_step}")
    if semantic_step >= STARTUP_RAMP_STEPS - 1:
        return 1.0
    progress = semantic_step / float(STARTUP_RAMP_STEPS - 1)
    return progress * progress * (3.0 - 2.0 * progress)


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
            cell_id=f"{engine_id}__{CANDIDATE_ID}__{arm_id}",
            engine_id=engine_id,
            onset_id="onset_600",
            turn_start_semantic_step=TURN_START_STEP,
            arm_id=arm_id,
            turn_heading_offset_rad=offset,
        )
        for engine_id in ENGINE_IDS
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
        raise ValueError(f"R23D40_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if not 0 <= semantic_step < CONTROLLER_STEPS:
        raise ValueError(f"R23D40_STEP_INVALID:{semantic_step}")
    if semantic_step < item.turn_start_semantic_step:
        return "reference_warmup", 0.0
    if semantic_step < item.turn_start_semantic_step + TURN_DURATION_STEPS:
        return "commanded_turn", item.turn_heading_offset_rad
    if semantic_step < (
        item.turn_start_semantic_step
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
