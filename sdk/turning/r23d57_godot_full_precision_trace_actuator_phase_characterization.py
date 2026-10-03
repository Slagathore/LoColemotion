"""Post-R23D56 full-precision Godot/Jolt actuator/phase characterization.

R23D57 preserves R23D56's exact finite matrix, controller, morphology,
schedule, thresholds, task-frame policy, live cap route, observation, and
seed. Its sole declared change is the Godot 4.7 full-precision JSON transport
used to retain trace rows before the unchanged Python evaluator reads them.

This three-world campaign is development characterization on an already
observed condition.  It can produce a complete descriptive record for a later
mechanism hypothesis; it cannot select a turning mechanism or validate turning.
"""

from __future__ import annotations

from dataclasses import dataclass

import r23d56_godot_valid_route_actuator_phase_characterization as predecessor


CAMPAIGN_ID = "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
GATE_ID = "QSDK-R23D57"
STAGE_ID = "godot_full_precision_trace_actuator_phase_characterization_development"
POLICY_ID = predecessor.POLICY_ID
CANDIDATE_ID = "r23d29_r23d53_condition_post_r23d55_valid_route_full_precision_trace_actuator_phase_characterization_development"
ENGINE_IDS = predecessor.ENGINE_IDS
ARM_OFFSETS = predecessor.ARM_OFFSETS
CONTROLLER_STEPS = predecessor.CONTROLLER_STEPS
TURN_START_STEP = predecessor.TURN_START_STEP
TURN_END_STEP_EXCLUSIVE = predecessor.TURN_END_STEP_EXCLUSIVE
TURN_DURATION_STEPS = predecessor.TURN_DURATION_STEPS
RECOVERY_DURATION_STEPS = predecessor.RECOVERY_DURATION_STEPS
ACTUATOR_COUNT = predecessor.ACTUATOR_COUNT
GAIT_CYCLE_STEPS = predecessor.GAIT_CYCLE_STEPS
RAMP_LAST_LOCAL_STEP = predecessor.RAMP_LAST_LOCAL_STEP
PROBE_LAST_SEMANTIC_STEP = predecessor.PROBE_LAST_SEMANTIC_STEP
STARTUP_TRANSFORM_ID = predecessor.STARTUP_TRANSFORM_ID
STARTUP_RAMP_ID = predecessor.STARTUP_RAMP_ID
STARTUP_RAMP_STEPS = predecessor.STARTUP_RAMP_STEPS
CAMPAIGN_SEED = predecessor.CAMPAIGN_SEED
MORPHOLOGY_ID = predecessor.MORPHOLOGY_ID
LIMB_IDS = predecessor.LIMB_IDS
PHASE_OFFSETS = predecessor.PHASE_OFFSETS
TRACE_ROW_SCHEMA = predecessor.TRACE_ROW_SCHEMA
INITIAL_PERTURBATION = predecessor.INITIAL_PERTURBATION
TASK_FRAME_ORIGIN_POLICY_ID = predecessor.TASK_FRAME_ORIGIN_POLICY_ID
INITIAL_SCHEDULE_BIND_STEP = predecessor.INITIAL_SCHEDULE_BIND_STEP
FIXED_ORIGIN_LAST_SEMANTIC_STEP = predecessor.FIXED_ORIGIN_LAST_SEMANTIC_STEP
EXPECTED_REANCHOR_STEPS = predecessor.EXPECTED_REANCHOR_STEPS
ACTUATOR_PHASE_OBSERVATION_SCHEMA = (
    "sporespore_godot_jolt_actuator_phase_observation_v1"
)
APPLICATION_RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_full_authority_application_receipt_v1"
)
LIVE_FIXTURE_CAP_BINDING_POLICY_ID = (
    "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"
)
LIVE_FIXTURE_COMPOSITION_SCHEMA = (
    "sporespore_godot_jolt_fixture_joint_composition_v1"
)
LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_live_fixture_actuator_cap_binding_receipt_v1"
)
LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_live_fixture_actuator_cap_validation_receipt_v1"
)
LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS = 2.5e-7
TRACE_TRANSPORT_ID = "godot_4_7_json_stringify_full_precision_binary64_v1"
REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE = 1.0e-15

StartupTransformError = predecessor.StartupTransformError
SupportLossConditionedStartup = predecessor.SupportLossConditionedStartup
smoothstep_scale = predecessor.smoothstep_scale


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
            cell_id=f"godot_jolt__{CANDIDATE_ID}__{arm_id}",
            engine_id="godot_jolt",
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
        raise StartupTransformError(
            f"R23D57_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}"
        )
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item not in cells() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise StartupTransformError(f"R23D57_STEP_INVALID:{semantic_step}")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", item.turn_heading_offset_rad
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    return {
        "reference_warmup": TURN_START_STEP,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": RECOVERY_DURATION_STEPS,
        "after_declared_schedule": (
            CONTROLLER_STEPS
            - TURN_END_STEP_EXCLUSIVE
            - RECOVERY_DURATION_STEPS
        ),
    }
