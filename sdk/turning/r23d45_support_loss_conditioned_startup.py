"""Portable support-loss-conditioned startup transform for QSDK-R23D45.

R23D45 is an outcome-exposed development successor.  It does not branch on
engine identity.  The first four controller observations form a fixed startup
probe.  If every declared foot is simultaneously out of contact during that
probe, the transform latches a one-cycle smoothstep velocity ramp beginning on
that same semantic step.  Otherwise it permanently remains the identity
transform.  Once the decision is locked it cannot be changed later in the run.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping


CAMPAIGN_ID = "QSDK-R23D45-SUPPORT-LOSS-CONDITIONED-STARTUP-DEVELOPMENT"
GATE_ID = "QSDK-R23D45"
STAGE_ID = "mujoco_support_loss_conditioned_startup_development"
ENGINE_ID = "mujoco"
ARM_ID = "reference_zero"
POLICY_ID = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
    "stability_guarded_steering_v1"
)
CANDIDATE_ID = "r23d29_support_loss_conditioned_startup_v1"
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
TURN_DURATION_STEPS = TURN_END_STEP_EXCLUSIVE - TURN_START_STEP
ACTUATOR_COUNT = 8
GAIT_CYCLE_STEPS = 360
RAMP_LAST_LOCAL_STEP = GAIT_CYCLE_STEPS - 1
PROBE_LAST_SEMANTIC_STEP = 3
STARTUP_TRANSFORM_ID = "support_loss_latched_smoothstep_one_cycle_v1"
CAMPAIGN_SEED = 21_507
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
LIMB_IDS = ("rear_left", "front_left", "rear_right", "front_right")
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


class StartupTransformError(ValueError):
    """Raised when the state-conditioned transform contract is violated."""


def smoothstep_scale(local_step: int) -> float:
    """Return exact zero at local step 0 and exact unity from step 359."""

    if not isinstance(local_step, int) or isinstance(local_step, bool) or local_step < 0:
        raise StartupTransformError(f"R23D45_LOCAL_STEP_INVALID:{local_step}")
    if local_step >= RAMP_LAST_LOCAL_STEP:
        return 1.0
    progress = local_step / float(RAMP_LAST_LOCAL_STEP)
    return progress * progress * (3.0 - 2.0 * progress)


def _support_count(contacts: Mapping[str, bool]) -> int:
    if not isinstance(contacts, Mapping) or set(contacts) != set(LIMB_IDS):
        raise StartupTransformError("R23D45_CONTACT_IDENTITY_INVALID")
    if any(type(contacts[limb_id]) is not bool for limb_id in LIMB_IDS):
        raise StartupTransformError("R23D45_CONTACT_VALUE_INVALID")
    return sum(int(contacts[limb_id]) for limb_id in LIMB_IDS)


@dataclass
class SupportLossConditionedStartup:
    """Deterministic one-run startup state; inputs are portable observations."""

    next_semantic_step: int = 0
    trigger_step: int | None = None
    decision_locked: bool = False
    minimum_probe_support_count: int = len(LIMB_IDS)

    def step(
        self,
        semantic_step: int,
        ordered_foot_contacts_before: Mapping[str, bool],
    ) -> dict[str, object]:
        if (
            not isinstance(semantic_step, int)
            or isinstance(semantic_step, bool)
            or semantic_step != self.next_semantic_step
            or not 0 <= semantic_step < CONTROLLER_STEPS
        ):
            raise StartupTransformError(
                f"R23D45_SEMANTIC_STEP_INVALID:{semantic_step}:"
                f"expected_{self.next_semantic_step}"
            )

        support_count = _support_count(ordered_foot_contacts_before)
        in_probe = semantic_step <= PROBE_LAST_SEMANTIC_STEP
        self.minimum_probe_support_count = min(
            self.minimum_probe_support_count,
            support_count,
        )
        if (
            in_probe
            and not self.decision_locked
            and self.trigger_step is None
            and support_count == 0
        ):
            self.trigger_step = semantic_step

        if semantic_step >= PROBE_LAST_SEMANTIC_STEP:
            self.decision_locked = True

        if self.trigger_step is None:
            local_ramp_step: int | None = None
            scale = 1.0
        else:
            local_ramp_step = semantic_step - self.trigger_step
            scale = smoothstep_scale(local_ramp_step)

        self.next_semantic_step += 1
        return {
            "startup_transform_id": STARTUP_TRANSFORM_ID,
            "startup_probe_active": in_probe,
            "startup_probe_support_count": support_count,
            "startup_probe_complete_support_loss": support_count == 0,
            "startup_transform_decision_locked": self.decision_locked,
            "startup_ramp_triggered": self.trigger_step is not None,
            "startup_ramp_trigger_step": self.trigger_step,
            "startup_ramp_local_step": local_ramp_step,
            "startup_velocity_scale": scale,
            "startup_ramp_active": self.trigger_step is not None and scale < 1.0,
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
        raise StartupTransformError(
            f"R23D45_CELL_INVALID:{stage_id}:{engine_id}:{arm_id}"
        )
    return matches[0]


def segment_for_step(item: Cell, semantic_step: int) -> tuple[str, float]:
    if item != cells()[0] or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise StartupTransformError(f"R23D45_STEP_INVALID:{semantic_step}")
    return "reference_walk", 0.0
