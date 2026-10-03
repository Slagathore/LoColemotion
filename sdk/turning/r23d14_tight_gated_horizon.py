"""Pure temporal oracle for the prospective QSDK-R23D14 policy.

This module constructs no adapter, model, or physics world.  It freezes the
tight-gated 600/960 terminal state machine selected by the outcome-visible
MuJoCo development lane.  Native engine implementations must mirror this
transition exactly before the finite three-engine confirmation can open.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, replace
import math
from typing import Any, Sequence


POLICY_ID = "sporespore_tight_gated_acquisition_active600_v1"
SCHEMA_VERSION = "sporespore_qsdk_r23d14_tight_gated_horizon_oracle_v1"

ACTIVE_MODE = "active_neutral_acquisition"
TAPER_MODE = "active_quiescent_taper"
PASSIVE_MODE = "irreversible_zero_actuation_stability"
CONFIRMED_REASON = "support_pose_quiescence_confirmed"
DEADLINE_REASON = "deadline_forced_without_quiescence_confirmation"

TERMINAL_STEPS = 960
MAXIMUM_ACTIVE_STEPS = 600
MINIMUM_TAPER_STEPS = 120
MINIMUM_PASSIVE_STEPS = 360
ACTUATOR_COUNT = 8
SCALE_DENOMINATOR = 120

COARSE_MAXIMUM_TILT_RAD = 0.035
COARSE_MAXIMUM_JOINT_ERROR_RAD = 0.32
TIGHT_MAXIMUM_TILT_RAD = 0.01
TIGHT_MAXIMUM_JOINT_ERROR_RAD = 0.2


class ContractError(ValueError):
    """The prospective R23D14 temporal contract failed closed."""


@dataclass(frozen=True)
class Observation:
    contacts: tuple[bool, bool, bool, bool]
    torso_tilt_rad: float
    maximum_absolute_joint_position_error_rad: float


@dataclass(frozen=True)
class State:
    next_step: int = 0
    mode: str = ACTIVE_MODE
    taper_step_count: int = 0
    confirmation_satisfied: bool = False
    handoff_after_active_step: int | None = None
    first_passive_step: int | None = None
    handoff_reason: str | None = None
    active_step_count: int = 0
    passive_step_count: int = 0
    active_native_application_count: int = 0
    passive_native_application_count: int = 0
    taper_reset_count: int = 0
    first_post_handoff_contact_loss_step: int | None = None
    post_handoff_contact_loss_step_count: int = 0


def _validate_observation(observation: Observation) -> None:
    if len(observation.contacts) != 4 or not all(
        isinstance(value, bool) for value in observation.contacts
    ):
        raise ContractError("R23D14_OBSERVATION_CONTACT_SHAPE_INVALID")
    values = (
        observation.torso_tilt_rad,
        observation.maximum_absolute_joint_position_error_rad,
    )
    if not all(isinstance(value, (int, float)) for value in values):
        raise ContractError("R23D14_OBSERVATION_NUMERIC_TYPE_INVALID")
    if not all(math.isfinite(float(value)) and float(value) >= 0.0 for value in values):
        raise ContractError("R23D14_OBSERVATION_NUMERIC_VALUE_INVALID")


def coarse_pose_satisfied(observation: Observation) -> bool:
    _validate_observation(observation)
    return (
        all(observation.contacts)
        and observation.torso_tilt_rad <= COARSE_MAXIMUM_TILT_RAD
        and observation.maximum_absolute_joint_position_error_rad
        <= COARSE_MAXIMUM_JOINT_ERROR_RAD
    )


def tight_pose_satisfied(observation: Observation) -> bool:
    _validate_observation(observation)
    return (
        all(observation.contacts)
        and observation.torso_tilt_rad <= TIGHT_MAXIMUM_TILT_RAD
        and observation.maximum_absolute_joint_position_error_rad
        <= TIGHT_MAXIMUM_JOINT_ERROR_RAD
    )


def expected_velocity_scale_fraction(state: State) -> tuple[int, int]:
    if state.mode == ACTIVE_MODE:
        return SCALE_DENOMINATOR, SCALE_DENOMINATOR
    if state.mode == TAPER_MODE:
        return max(1, MINIMUM_TAPER_STEPS - state.taper_step_count), SCALE_DENOMINATOR
    if state.mode == PASSIVE_MODE:
        return 0, SCALE_DENOMINATOR
    raise ContractError("R23D14_STATE_MODE_INVALID")


def _transition_to_passive(state: State, *, step: int, confirmed: bool) -> State:
    return replace(
        state,
        mode=PASSIVE_MODE,
        confirmation_satisfied=confirmed,
        handoff_after_active_step=step,
        first_passive_step=step + 1,
        handoff_reason=CONFIRMED_REASON if confirmed else DEADLINE_REASON,
    )


def observe_completed_step(
    state: State,
    observation: Observation,
    native_application_count: int,
    velocity_scale_numerator: int,
    velocity_scale_denominator: int,
) -> tuple[State, dict[str, Any]]:
    """Advance one completed step without engine, arm, or outcome identity."""

    if state.next_step < 0 or state.next_step >= TERMINAL_STEPS:
        raise ContractError("R23D14_STEP_OUTSIDE_HORIZON")
    if state.mode not in (ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE):
        raise ContractError("R23D14_STATE_MODE_INVALID")
    _validate_observation(observation)
    expected_numerator, expected_denominator = expected_velocity_scale_fraction(state)
    if (
        velocity_scale_numerator != expected_numerator
        or velocity_scale_denominator != expected_denominator
    ):
        raise ContractError("R23D14_VELOCITY_SCALE_MISMATCH")
    expected_applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
    if native_application_count != expected_applications:
        raise ContractError("R23D14_APPLICATION_COUNT_MISMATCH")

    step = state.next_step
    pre_mode = state.mode
    pre_taper_count = state.taper_step_count
    coarse = coarse_pose_satisfied(observation)
    tight = tight_pose_satisfied(observation)
    transitioned = False
    taper_reset = False
    next_state = replace(state, next_step=step + 1)

    if pre_mode in (ACTIVE_MODE, TAPER_MODE):
        next_state = replace(
            next_state,
            active_step_count=state.active_step_count + 1,
            active_native_application_count=(
                state.active_native_application_count + native_application_count
            ),
        )
        if pre_mode == ACTIVE_MODE:
            if step == MAXIMUM_ACTIVE_STEPS - 1:
                next_state = _transition_to_passive(
                    next_state, step=step, confirmed=False
                )
                transitioned = True
            elif tight:
                next_state = replace(next_state, mode=TAPER_MODE, taper_step_count=0)
                transitioned = True
        else:
            if tight:
                post_taper_count = min(MINIMUM_TAPER_STEPS, pre_taper_count + 1)
                next_state = replace(next_state, taper_step_count=post_taper_count)
                if post_taper_count >= MINIMUM_TAPER_STEPS:
                    next_state = _transition_to_passive(
                        next_state, step=step, confirmed=True
                    )
                    transitioned = True
                elif step == MAXIMUM_ACTIVE_STEPS - 1:
                    next_state = _transition_to_passive(
                        next_state, step=step, confirmed=False
                    )
                    transitioned = True
            elif step == MAXIMUM_ACTIVE_STEPS - 1:
                next_state = _transition_to_passive(
                    next_state, step=step, confirmed=False
                )
                transitioned = True
            else:
                next_state = replace(
                    next_state,
                    mode=ACTIVE_MODE,
                    taper_step_count=0,
                    taper_reset_count=state.taper_reset_count + 1,
                )
                transitioned = True
                taper_reset = True
    else:
        next_state = replace(
            next_state,
            passive_step_count=state.passive_step_count + 1,
            passive_native_application_count=(
                state.passive_native_application_count + native_application_count
            ),
        )
        if not all(observation.contacts):
            next_state = replace(
                next_state,
                post_handoff_contact_loss_step_count=(
                    state.post_handoff_contact_loss_step_count + 1
                ),
                first_post_handoff_contact_loss_step=(
                    state.first_post_handoff_contact_loss_step
                    if state.first_post_handoff_contact_loss_step is not None
                    else step
                ),
            )

    return next_state, {
        "step": step,
        "mode": pre_mode,
        "all_four_contacts": all(observation.contacts),
        "torso_tilt_rad": float(observation.torso_tilt_rad),
        "maximum_absolute_joint_position_error_rad": float(
            observation.maximum_absolute_joint_position_error_rad
        ),
        "coarse_pose_satisfied": coarse,
        "tight_pose_satisfied": tight,
        "pre_step_taper_count": pre_taper_count,
        "post_step_taper_count": next_state.taper_step_count,
        "velocity_scale_numerator": velocity_scale_numerator,
        "velocity_scale_denominator": velocity_scale_denominator,
        "native_application_count": native_application_count,
        "transition_after_step": transitioned,
        "taper_reset_after_step": taper_reset,
        "next_mode": next_state.mode,
        "handoff_reason": (
            next_state.handoff_reason
            if transitioned and next_state.mode == PASSIVE_MODE
            else None
        ),
    }


def outcome(state: State) -> dict[str, Any]:
    if state.next_step != TERMINAL_STEPS:
        raise ContractError("R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON")
    passed = (
        state.confirmation_satisfied
        and state.handoff_reason == CONFIRMED_REASON
        and state.first_passive_step is not None
        and state.first_passive_step <= MAXIMUM_ACTIVE_STEPS
        and state.passive_step_count >= MINIMUM_PASSIVE_STEPS
        and state.passive_native_application_count == 0
        and state.post_handoff_contact_loss_step_count == 0
        and state.mode == PASSIVE_MODE
    )
    return {**asdict(state), "quiescent_taper_gate_passed": passed}


def simulate(observations: Sequence[Observation]) -> dict[str, Any]:
    if len(observations) != TERMINAL_STEPS:
        raise ContractError("R23D14_OBSERVATION_HORIZON_INVALID")
    state = State()
    receipts: list[dict[str, Any]] = []
    for observation in observations:
        numerator, denominator = expected_velocity_scale_fraction(state)
        applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
        state, receipt = observe_completed_step(
            state, observation, applications, numerator, denominator
        )
        receipts.append(receipt)
    return {"state": state, "receipts": receipts, "outcome": outcome(state)}


def run_zero_world_preflight() -> dict[str, Any]:
    tight = Observation((True, True, True, True), 0.005, 0.1)
    coarse = Observation((True, True, True, True), 0.02, 0.25)
    unsupported = Observation((True, True, True, False), 0.005, 0.1)
    positive_timing = simulate([coarse] * 318 + [tight] * 642)
    negative_timing = simulate([coarse] * 459 + [tight] * 501)
    deadline = simulate([coarse] * TERMINAL_STEPS)

    state = State()
    numerator, denominator = expected_velocity_scale_fraction(state)
    state, entered = observe_completed_step(
        state, tight, ACTUATOR_COUNT, numerator, denominator
    )
    numerator, denominator = expected_velocity_scale_fraction(state)
    state, reset = observe_completed_step(
        state, unsupported, ACTUATOR_COUNT, numerator, denominator
    )
    checks = {
        "exact_horizons": (
            TERMINAL_STEPS == 960
            and MAXIMUM_ACTIVE_STEPS == 600
            and MINIMUM_TAPER_STEPS == 120
            and MINIMUM_PASSIVE_STEPS == 360
        ),
        "tight_enters_taper": entered["next_mode"] == TAPER_MODE,
        "coarse_only_does_not_enter_taper": (
            deadline["receipts"][0]["next_mode"] == ACTIVE_MODE
        ),
        "tight_loss_resets_full_acquisition": (
            reset["next_mode"] == ACTIVE_MODE
            and reset["taper_reset_after_step"] is True
            and expected_velocity_scale_fraction(state)
            == (SCALE_DENOMINATOR, SCALE_DENOMINATOR)
        ),
        "positive_retained_timing_handoff_after_438": (
            positive_timing["outcome"]["handoff_after_active_step"] == 438
        ),
        "positive_retained_timing_has_521_passive_steps": (
            positive_timing["outcome"]["passive_step_count"] == 521
        ),
        "negative_retained_timing_handoff_after_579": (
            negative_timing["outcome"]["handoff_after_active_step"] == 579
        ),
        "negative_retained_timing_has_380_passive_steps": (
            negative_timing["outcome"]["passive_step_count"] == 380
        ),
        "both_retained_timings_pass": (
            positive_timing["outcome"]["quiescent_taper_gate_passed"]
            and negative_timing["outcome"]["quiescent_taper_gate_passed"]
        ),
        "coarse_only_deadline_after_599": (
            deadline["outcome"]["handoff_after_active_step"] == 599
        ),
        "deadline_retains_360_passive_steps": (
            deadline["outcome"]["passive_step_count"] == 360
        ),
        "coarse_only_deadline_fails": (
            not deadline["outcome"]["quiescent_taper_gate_passed"]
        ),
    }
    if not all(checks.values()):
        raise ContractError("R23D14_ZERO_WORLD_PREFLIGHT_FAILED")
    return {
        "schema_version": SCHEMA_VERSION,
        "policy_id": POLICY_ID,
        "check_count": len(checks),
        "checks": checks,
        "arm_identity_or_heading_sign_used": False,
        "native_engine_route_count": 0,
        "physical_worker_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "validation_authority": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }
