"""Pure paired startup-transform matrix for QSDK-R23D44."""

from __future__ import annotations

from dataclasses import dataclass


CAMPAIGN_ID = "QSDK-R23D44-RAPIER-PAIRED-STARTUP-TRANSFORM-DEVELOPMENT"
GATE_ID = "QSDK-R23D44"
RELEASE_GATE_ID = "QSDK-R23"
STAGE_ID = "rapier_paired_startup_transform_development"
POLICY_ID = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
    "stability_guarded_steering_v1"
)
NO_RAMP_CANDIDATE_ID = "r23d29_no_startup_ramp_control"
RAMP_CANDIDATE_ID = "r23d29_canonical_startup_ramp_treatment"
CANDIDATE_IDS = (NO_RAMP_CANDIDATE_ID, RAMP_CANDIDATE_ID)
ENGINE_IDS = ("rapier_parry",)
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
NO_RAMP_ID = "none"
CAMPAIGN_SEED = 21_504
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
PHASE_OFFSETS = (0, 90, 180, 270)
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d44_turning_trace_row_v1"
INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.000819909968413413,
    "fixture_yaw_rad": -0.00561603251844645,
    "initial_linear_velocity_world_m_s": [
        -0.0015466371551156,
        0.0,
        0.0027512633241713,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.0000471633393317461,
        -0.00301092397421598,
        -0.000810656696557999,
    ],
    "gait_phase_offset_ticks": -1,
}


def startup_velocity_scale(semantic_step: int) -> float:
    """Return the frozen canonical smoothstep startup scale."""

    if semantic_step < 0:
        raise ValueError(f"R23D44_STEP_INVALID:{semantic_step}")
    if semantic_step >= STARTUP_RAMP_STEPS - 1:
        return 1.0
    progress = semantic_step / float(STARTUP_RAMP_STEPS - 1)
    return progress * progress * (3.0 - 2.0 * progress)


def startup_ramp_applied(candidate_id: str) -> bool:
    if candidate_id == NO_RAMP_CANDIDATE_ID:
        return False
    if candidate_id == RAMP_CANDIDATE_ID:
        return True
    raise ValueError(f"R23D44_CANDIDATE_INVALID:{candidate_id}")


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    candidate_id: str
    startup_ramp_applied: bool
    onset_id: str
    turn_start_semantic_step: int
    arm_id: str
    turn_heading_offset_rad: float


def cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"{engine_id}__{candidate_id}__{arm_id}",
            engine_id=engine_id,
            candidate_id=candidate_id,
            startup_ramp_applied=startup_ramp_applied(candidate_id),
            onset_id="onset_600",
            turn_start_semantic_step=TURN_START_STEP,
            arm_id=arm_id,
            turn_heading_offset_rad=offset,
        )
        for engine_id in ENGINE_IDS
        for candidate_id in CANDIDATE_IDS
        for arm_id, offset in ARM_OFFSETS.items()
    ]


def cell(stage_id: str, engine_id: str, arm_id: str, candidate_id: str | None = None) -> Cell:
    matches = [
        item
        for item in cells()
        if item.stage_id == stage_id
        and item.engine_id == engine_id
        and item.arm_id == arm_id
        and (candidate_id is None or item.candidate_id == candidate_id)
    ]
    if len(matches) != 1:
        raise ValueError(
            f"R23D44_CELL_INVALID:{stage_id}:{engine_id}:{candidate_id}:{arm_id}"
        )
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if not 0 <= semantic_step < CONTROLLER_STEPS:
        raise ValueError(f"R23D44_STEP_INVALID:{semantic_step}")
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
