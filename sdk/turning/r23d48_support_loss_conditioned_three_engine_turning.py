"""Finite three-engine turning design using the portable R23D45 startup rule.

R23D48 is a fresh held-out successor.  The R23D29 controller, three-arm
turning schedule, R23D31 measurement, and physical gates remain unchanged.
Only the unconditional startup ramp is replaced by the already-observed
support-loss-conditioned transform: the first four portable foot-contact
observations may latch one smoothstep cycle, otherwise the transform remains
the identity for the entire world.
"""

from __future__ import annotations

from dataclasses import dataclass

import r23d45_support_loss_conditioned_startup as startup


CAMPAIGN_ID = "QSDK-R23D48-SUPPORT-LOSS-CONDITIONED-THREE-ENGINE-TURNING"
GATE_ID = "QSDK-R23D48"
RELEASE_GATE_ID = "QSDK-R23"
STAGE_ID = "three_engine_support_loss_conditioned_turning_validation"
POLICY_ID = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
    "stability_guarded_steering_v1"
)
CANDIDATE_ID = "r23d29_support_loss_conditioned_turning_validation"
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
GAIT_CYCLE_STEPS = startup.GAIT_CYCLE_STEPS
RAMP_LAST_LOCAL_STEP = startup.RAMP_LAST_LOCAL_STEP
PROBE_LAST_SEMANTIC_STEP = startup.PROBE_LAST_SEMANTIC_STEP
STARTUP_TRANSFORM_ID = startup.STARTUP_TRANSFORM_ID
# Compatibility aliases used by the inherited turning/evidence surfaces.
STARTUP_RAMP_ID = STARTUP_TRANSFORM_ID
STARTUP_RAMP_STEPS = GAIT_CYCLE_STEPS
CAMPAIGN_SEED = 21_512
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
LIMB_IDS = startup.LIMB_IDS
PHASE_OFFSETS = (0, 90, 180, 270)
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d48_turning_trace_row_v1"
INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.000977878458797932,
    "fixture_yaw_rad": -0.0030376547947526,
    "initial_linear_velocity_world_m_s": [
        0.00269566150382161,
        0.0,
        0.000103241764008999,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.000322412699460983,
        -0.00202120910398662,
        0.000436143483966589,
    ],
    "gait_phase_offset_ticks": 1,
}

StartupTransformError = startup.StartupTransformError
SupportLossConditionedStartup = startup.SupportLossConditionedStartup
smoothstep_scale = startup.smoothstep_scale


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
        raise StartupTransformError(
            f"R23D48_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}"
        )
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item not in cells() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise StartupTransformError(f"R23D48_STEP_INVALID:{semantic_step}")
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
