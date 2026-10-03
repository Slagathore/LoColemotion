"""Prospective R23D58 Godot/Jolt cap-source factorial design.

R23D58 asks a finite development question on the already observed Candidate35
condition: with every other declared input held fixed, how do the four
portable-versus-fixture hip/knee actuator-cap source combinations change the
retained contact, actuator, and torso traces?

The four cells are descriptive mechanism characterization only.  They do not
invoke a turning evaluator, select a mechanism, validate turning, or authorize
physical execution.  This module is pure design authority and constructs no
physics world.
"""

from __future__ import annotations

from dataclasses import dataclass

import r23d57_godot_full_precision_trace_actuator_phase_characterization as predecessor


CAMPAIGN_ID = (
    "QSDK-R23D58-GODOT-CAP-SOURCE-FACTORIAL-REAR-CONTACT-MECHANISM-DEVELOPMENT"
)
GATE_ID = "QSDK-R23D58"
STAGE_ID = "godot_cap_source_factorial_rear_contact_mechanism_development"
POLICY_ID = predecessor.POLICY_ID
CANDIDATE_ID = (
    "r23d29_r23d53_condition_post_r23d57_cap_source_factorial_"
    "rear_contact_mechanism_development"
)
ENGINE_IDS = ("godot_jolt",)
ARM_OFFSETS = {"reference_zero": 0.0}
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
ACTUATOR_PHASE_OBSERVATION_SCHEMA = predecessor.ACTUATOR_PHASE_OBSERVATION_SCHEMA
APPLICATION_RECEIPT_SCHEMA = predecessor.APPLICATION_RECEIPT_SCHEMA
LIVE_FIXTURE_CAP_BINDING_POLICY_ID = (
    "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_v1"
)
LIVE_FIXTURE_COMPOSITION_SCHEMA = predecessor.LIVE_FIXTURE_COMPOSITION_SCHEMA
LIVE_FIXTURE_CAP_BINDING_RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_receipt_v1"
)
LIVE_FIXTURE_CAP_VALIDATION_RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_live_fixture_cap_source_factorial_validation_receipt_v1"
)
LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS = (
    predecessor.LIVE_FIXTURE_CAP_READBACK_TOLERANCE_NMS
)
TRACE_TRANSPORT_ID = "godot_4_7_sorted_full_precision_authoritative_json_v1"
REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE = (
    predecessor.REPORTED_ERROR_RECOMPUTATION_CONSISTENCY_TOLERANCE
)

CAP_SOURCE_PORTABLE_COMPILED = "portable_compiled_morphology"
CAP_SOURCE_FIXTURE_PREBINDING = "fixture_realized_prebinding"

PROFILE_PORTABLE_HIP_PORTABLE_KNEE = "portable_hip__portable_knee"
PROFILE_PORTABLE_HIP_FIXTURE_KNEE = "portable_hip__fixture_knee"
PROFILE_FIXTURE_HIP_PORTABLE_KNEE = "fixture_hip__portable_knee"
PROFILE_FIXTURE_HIP_FIXTURE_KNEE = "fixture_hip__fixture_knee"

ORDERED_PROFILE_IDS = (
    PROFILE_PORTABLE_HIP_PORTABLE_KNEE,
    PROFILE_PORTABLE_HIP_FIXTURE_KNEE,
    PROFILE_FIXTURE_HIP_PORTABLE_KNEE,
    PROFILE_FIXTURE_HIP_FIXTURE_KNEE,
)

PROFILE_DEFINITIONS = {
    PROFILE_PORTABLE_HIP_PORTABLE_KNEE: {
        "hip_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
        "knee_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
    },
    PROFILE_PORTABLE_HIP_FIXTURE_KNEE: {
        "hip_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
        "knee_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
    },
    PROFILE_FIXTURE_HIP_PORTABLE_KNEE: {
        "hip_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
        "knee_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
    },
    PROFILE_FIXTURE_HIP_FIXTURE_KNEE: {
        "hip_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
        "knee_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
    },
}

PREDECLARED_FACTORIAL_CONTRASTS = {
    "knee_source_at_portable_hip": (
        PROFILE_PORTABLE_HIP_FIXTURE_KNEE,
        PROFILE_PORTABLE_HIP_PORTABLE_KNEE,
    ),
    "knee_source_at_fixture_hip": (
        PROFILE_FIXTURE_HIP_FIXTURE_KNEE,
        PROFILE_FIXTURE_HIP_PORTABLE_KNEE,
    ),
    "hip_source_at_portable_knee": (
        PROFILE_FIXTURE_HIP_PORTABLE_KNEE,
        PROFILE_PORTABLE_HIP_PORTABLE_KNEE,
    ),
    "hip_source_at_fixture_knee": (
        PROFILE_FIXTURE_HIP_FIXTURE_KNEE,
        PROFILE_PORTABLE_HIP_FIXTURE_KNEE,
    ),
}

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
    profile_id: str
    hip_cap_source: str
    knee_cap_source: str


def cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_ID,
            cell_id=f"godot_jolt__{CANDIDATE_ID}__profile_{profile_id}",
            engine_id="godot_jolt",
            onset_id="onset_600",
            turn_start_semantic_step=TURN_START_STEP,
            arm_id="reference_zero",
            turn_heading_offset_rad=0.0,
            profile_id=profile_id,
            hip_cap_source=str(PROFILE_DEFINITIONS[profile_id]["hip_cap_source"]),
            knee_cap_source=str(PROFILE_DEFINITIONS[profile_id]["knee_cap_source"]),
        )
        for profile_id in ORDERED_PROFILE_IDS
    ]


def cell(stage_id: str, engine_id: str, profile_id: str) -> Cell:
    matches = [
        item
        for item in cells()
        if item.stage_id == stage_id
        and item.engine_id == engine_id
        and item.profile_id == profile_id
    ]
    if len(matches) != 1:
        raise StartupTransformError(
            f"R23D58_CELL_INVALID:{stage_id}:{engine_id}:{profile_id}"
        )
    return matches[0]


def cell_by_id(cell_id: str) -> Cell:
    matches = [item for item in cells() if item.cell_id == cell_id]
    if len(matches) != 1:
        raise StartupTransformError(f"R23D58_CELL_ID_INVALID:{cell_id}")
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item not in cells() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise StartupTransformError(f"R23D58_STEP_INVALID:{semantic_step}")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def expected_segment_counts(item: Cell) -> dict[str, int]:
    if item not in cells():
        raise StartupTransformError(f"R23D58_CELL_INVALID:{item!r}")
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
