"""Pure temporal oracle for the QSDK-R23D10 terminal policy.

This module constructs no adapter, model, or physics world.  It defines the
prospectively frozen state transition that each later native engine route must
mirror exactly.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, replace
import math
from typing import Any, Iterable, Mapping, Sequence


ACTIVE_MODE = "active_neutral_acquisition"
TAPER_MODE = "active_quiescent_taper"
PASSIVE_MODE = "irreversible_zero_actuation_stability"
CONFIRMED_REASON = "support_pose_quiescence_confirmed"
DEADLINE_REASON = "deadline_forced_without_quiescence_confirmation"

TERMINAL_STEPS = 900
MAXIMUM_ACTIVE_STEPS = 540
MINIMUM_TAPER_STEPS = 120
MINIMUM_PASSIVE_STEPS = 360
ACTUATOR_COUNT = 8
SCALE_DENOMINATOR = 120

COARSE_MAXIMUM_TILT_RAD = 0.035
COARSE_MAXIMUM_JOINT_ERROR_RAD = 0.32
TIGHT_MAXIMUM_TILT_RAD = 0.01
TIGHT_MAXIMUM_JOINT_ERROR_RAD = 0.2


class ContractError(ValueError):
    """Raised when a caller violates the frozen temporal contract."""


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
        raise ContractError("R23D10_OBSERVATION_CONTACT_SHAPE_INVALID")
    values = (
        observation.torso_tilt_rad,
        observation.maximum_absolute_joint_position_error_rad,
    )
    if not all(isinstance(value, (int, float)) for value in values):
        raise ContractError("R23D10_OBSERVATION_NUMERIC_TYPE_INVALID")
    if not all(math.isfinite(float(value)) and float(value) >= 0.0 for value in values):
        raise ContractError("R23D10_OBSERVATION_NUMERIC_VALUE_INVALID")


def _all_four(observation: Observation) -> bool:
    return all(observation.contacts)


def coarse_pose_satisfied(observation: Observation) -> bool:
    _validate_observation(observation)
    return (
        _all_four(observation)
        and observation.torso_tilt_rad <= COARSE_MAXIMUM_TILT_RAD
        and observation.maximum_absolute_joint_position_error_rad
        <= COARSE_MAXIMUM_JOINT_ERROR_RAD
    )


def tight_pose_satisfied(observation: Observation) -> bool:
    _validate_observation(observation)
    return (
        _all_four(observation)
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
    raise ContractError("R23D10_STATE_MODE_INVALID")


def _transition_to_passive(
    state: State,
    *,
    step: int,
    confirmed: bool,
) -> State:
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
    """Advance the frozen policy after one completed physics step."""

    if state.next_step < 0 or state.next_step >= TERMINAL_STEPS:
        raise ContractError("R23D10_STEP_OUTSIDE_HORIZON")
    if state.mode not in (ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE):
        raise ContractError("R23D10_STATE_MODE_INVALID")
    _validate_observation(observation)

    expected_numerator, expected_denominator = expected_velocity_scale_fraction(state)
    if (
        velocity_scale_numerator != expected_numerator
        or velocity_scale_denominator != expected_denominator
    ):
        raise ContractError("R23D10_VELOCITY_SCALE_MISMATCH")
    expected_applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
    if native_application_count != expected_applications:
        raise ContractError("R23D10_APPLICATION_COUNT_MISMATCH")

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
            elif coarse:
                next_state = replace(next_state, mode=TAPER_MODE, taper_step_count=0)
                transitioned = True
        else:
            if coarse:
                post_taper_count = min(MINIMUM_TAPER_STEPS, pre_taper_count + 1)
                next_state = replace(next_state, taper_step_count=post_taper_count)
                if post_taper_count >= MINIMUM_TAPER_STEPS and tight:
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
        if not _all_four(observation):
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

    receipt = {
        "step": step,
        "mode": pre_mode,
        "all_four_contacts": _all_four(observation),
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
    return next_state, receipt


def outcome(state: State) -> dict[str, Any]:
    if state.next_step != TERMINAL_STEPS:
        raise ContractError("R23D10_OUTCOME_BEFORE_HORIZON")
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
    return {
        **asdict(state),
        "quiescent_taper_gate_passed": passed,
    }


def simulate(observations: Sequence[Observation]) -> dict[str, Any]:
    if len(observations) != TERMINAL_STEPS:
        raise ContractError("R23D10_OBSERVATION_HORIZON_INVALID")
    state = State()
    receipts: list[dict[str, Any]] = []
    for observation in observations:
        numerator, denominator = expected_velocity_scale_fraction(state)
        applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
        state, receipt = observe_completed_step(
            state,
            observation,
            applications,
            numerator,
            denominator,
        )
        receipts.append(receipt)
    return {"receipts": receipts, "outcome": outcome(state)}


def validate_replay(
    observations: Sequence[Observation],
    receipts: Sequence[Mapping[str, Any]],
    reported_outcome: Mapping[str, Any],
) -> bool:
    try:
        expected = simulate(observations)
    except ContractError:
        return False
    return list(receipts) == expected["receipts"] and dict(reported_outcome) == expected[
        "outcome"
    ]


def rows(
    segments: Iterable[
        tuple[
            int,
            tuple[bool, bool, bool, bool],
            float,
            float,
        ]
    ]
) -> list[Observation]:
    result: list[Observation] = []
    for count, contacts, tilt, joint_error in segments:
        if count < 0:
            raise ContractError("R23D10_SEGMENT_COUNT_INVALID")
        result.extend(
            Observation(contacts, float(tilt), float(joint_error))
            for _ in range(count)
        )
    if len(result) != TERMINAL_STEPS:
        raise ContractError("R23D10_SEGMENT_HORIZON_INVALID")
    return result
