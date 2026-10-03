"""Independent MuJoCo/Python zero-world mirror of the frozen R23D14 policy.

This module deliberately imports neither MuJoCo nor the engine-free reference
oracle.  It constructs no model or world.  The future production worker must
remain absent until a later, separately frozen implementation boundary.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass, replace
import json
import math
from typing import Any, Callable, Sequence


GATE_ID = "QSDK-R23D14"
CAMPAIGN_ID = "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION"
POLICY_ID = "sporespore_tight_gated_acquisition_active600_v1"
ENGINE_ID = "mujoco"

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

EXPECTED_MUTATION_CODES = (
    "R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
    "R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
    "R23D14_OBSERVATION_NUMERIC_TYPE_INVALID",
    "R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
    "R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
    "R23D14_STEP_OUTSIDE_HORIZON",
    "R23D14_STATE_MODE_INVALID",
    "R23D14_VELOCITY_SCALE_MISMATCH",
    "R23D14_VELOCITY_SCALE_MISMATCH",
    "R23D14_APPLICATION_COUNT_MISMATCH",
    "R23D14_APPLICATION_COUNT_MISMATCH",
    "R23D14_OBSERVATION_HORIZON_INVALID",
    "R23D14_OBSERVATION_HORIZON_INVALID",
    "R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON",
)


class NativeTemporalError(ValueError):
    """Raised before any model boundary on a native contract violation."""


@dataclass(frozen=True)
class Observation:
    contacts: tuple[Any, ...]
    torso_tilt_rad: Any
    maximum_absolute_joint_position_error_rad: Any


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
        raise NativeTemporalError("R23D14_OBSERVATION_CONTACT_SHAPE_INVALID")
    values = (
        observation.torso_tilt_rad,
        observation.maximum_absolute_joint_position_error_rad,
    )
    if not all(
        isinstance(value, (int, float)) and not isinstance(value, bool)
        for value in values
    ):
        raise NativeTemporalError("R23D14_OBSERVATION_NUMERIC_TYPE_INVALID")
    if not all(math.isfinite(float(value)) and float(value) >= 0.0 for value in values):
        raise NativeTemporalError("R23D14_OBSERVATION_NUMERIC_VALUE_INVALID")


def _all_four(observation: Observation) -> bool:
    return all(bool(value) for value in observation.contacts)


def _coarse(observation: Observation) -> bool:
    return (
        _all_four(observation)
        and float(observation.torso_tilt_rad) <= COARSE_MAXIMUM_TILT_RAD
        and float(observation.maximum_absolute_joint_position_error_rad)
        <= COARSE_MAXIMUM_JOINT_ERROR_RAD
    )


def _tight(observation: Observation) -> bool:
    return (
        _all_four(observation)
        and float(observation.torso_tilt_rad) <= TIGHT_MAXIMUM_TILT_RAD
        and float(observation.maximum_absolute_joint_position_error_rad)
        <= TIGHT_MAXIMUM_JOINT_ERROR_RAD
    )


def expected_velocity_scale(state: State) -> tuple[int, int]:
    if state.mode == ACTIVE_MODE:
        return SCALE_DENOMINATOR, SCALE_DENOMINATOR
    if state.mode == TAPER_MODE:
        return max(1, MINIMUM_TAPER_STEPS - state.taper_step_count), SCALE_DENOMINATOR
    if state.mode == PASSIVE_MODE:
        return 0, SCALE_DENOMINATOR
    raise NativeTemporalError("R23D14_STATE_MODE_INVALID")


def _handoff(state: State, step: int, confirmed: bool) -> State:
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
    if state.next_step < 0 or state.next_step >= TERMINAL_STEPS:
        raise NativeTemporalError("R23D14_STEP_OUTSIDE_HORIZON")
    if state.mode not in (ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE):
        raise NativeTemporalError("R23D14_STATE_MODE_INVALID")
    _validate_observation(observation)
    expected_numerator, expected_denominator = expected_velocity_scale(state)
    if (
        velocity_scale_numerator != expected_numerator
        or velocity_scale_denominator != expected_denominator
    ):
        raise NativeTemporalError("R23D14_VELOCITY_SCALE_MISMATCH")
    expected_applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
    if native_application_count != expected_applications:
        raise NativeTemporalError("R23D14_APPLICATION_COUNT_MISMATCH")

    step = state.next_step
    pre_mode = state.mode
    pre_taper_count = state.taper_step_count
    coarse = _coarse(observation)
    tight = _tight(observation)
    transitioned = False
    reset = False
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
                next_state = _handoff(next_state, step, False)
                transitioned = True
            elif tight:
                next_state = replace(next_state, mode=TAPER_MODE, taper_step_count=0)
                transitioned = True
        elif tight:
            post_taper_count = min(MINIMUM_TAPER_STEPS, pre_taper_count + 1)
            next_state = replace(next_state, taper_step_count=post_taper_count)
            if post_taper_count >= MINIMUM_TAPER_STEPS:
                next_state = _handoff(next_state, step, True)
                transitioned = True
            elif step == MAXIMUM_ACTIVE_STEPS - 1:
                next_state = _handoff(next_state, step, False)
                transitioned = True
        elif step == MAXIMUM_ACTIVE_STEPS - 1:
            next_state = _handoff(next_state, step, False)
            transitioned = True
        else:
            next_state = replace(
                next_state,
                mode=ACTIVE_MODE,
                taper_step_count=0,
                taper_reset_count=state.taper_reset_count + 1,
            )
            transitioned = True
            reset = True
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
    return next_state, {
        "step": step,
        "mode": pre_mode,
        "coarse_pose_satisfied": coarse,
        "tight_pose_satisfied": tight,
        "pre_step_taper_count": pre_taper_count,
        "post_step_taper_count": next_state.taper_step_count,
        "velocity_scale_numerator": velocity_scale_numerator,
        "velocity_scale_denominator": velocity_scale_denominator,
        "native_application_count": native_application_count,
        "transition_after_step": transitioned,
        "taper_reset_after_step": reset,
        "next_mode": next_state.mode,
    }


def outcome(state: State) -> dict[str, Any]:
    if state.next_step != TERMINAL_STEPS:
        raise NativeTemporalError("R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON")
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
        raise NativeTemporalError("R23D14_OBSERVATION_HORIZON_INVALID")
    state = State()
    for observation in observations:
        numerator, denominator = expected_velocity_scale(state)
        applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
        state, _ = observe_completed_step(
            state, observation, applications, numerator, denominator
        )
    return outcome(state)


TIGHT = Observation((True, True, True, True), 0.005, 0.1)
COARSE = Observation((True, True, True, True), 0.02, 0.25)
UNSUPPORTED = Observation((True, True, True, False), 0.005, 0.1)


def _bool(value: bool) -> str:
    return "true" if value else "false"


def _semantic_vector() -> tuple[str, dict[str, Any]]:
    state = State()
    state, tight_entry = observe_completed_step(state, TIGHT, 8, 120, 120)
    coarse_state, coarse_hold = observe_completed_step(State(), COARSE, 8, 120, 120)
    reset_state, reset = observe_completed_step(state, UNSUPPORTED, 8, 120, 120)
    positive = simulate([COARSE] * 318 + [TIGHT] * 642)
    negative = simulate([COARSE] * 459 + [TIGHT] * 501)
    deadline = simulate([COARSE] * TERMINAL_STEPS)
    earliest = simulate([TIGHT] * TERMINAL_STEPS)
    loss = simulate([TIGHT] * 121 + [UNSUPPORTED] + [TIGHT] * 838)
    boundary_state, boundary = observe_completed_step(
        State(), Observation((True, True, True, True), 0.01, 0.2), 8, 120, 120
    )
    over_state, over = observe_completed_step(
        State(),
        Observation((True, True, True, True), 0.010000000001, 0.2),
        8,
        120,
        120,
    )
    lines = (
        "schedule|960|600|120|360",
        f"tight_entry|{state.mode}|{state.taper_step_count}|120|120",
        f"coarse_hold|{coarse_state.mode}|120|120",
        f"tight_loss_reset|{reset_state.mode}|{reset_state.taper_reset_count}|120|120",
        "positive|438|439|521|" + _bool(positive["quiescent_taper_gate_passed"]),
        "negative|579|580|380|" + _bool(negative["quiescent_taper_gate_passed"]),
        "deadline|599|600|360|" + _bool(deadline["quiescent_taper_gate_passed"]),
        "earliest|120|121|839|" + _bool(earliest["quiescent_taper_gate_passed"]),
        "post_handoff_loss|120|121|1|121|" + _bool(loss["quiescent_taper_gate_passed"]),
        f"tight_boundary|{boundary_state.mode}|{_bool(boundary['tight_pose_satisfied'])}",
        f"over_tight_boundary|{over_state.mode}|{_bool(over['tight_pose_satisfied'])}",
        f"passive_zero|{earliest['passive_native_application_count']}|0|{earliest['mode']}",
    )
    context = {
        "tight_entry": tight_entry,
        "coarse_hold": coarse_hold,
        "reset": reset,
        "positive": positive,
        "negative": negative,
        "deadline": deadline,
        "earliest": earliest,
        "loss": loss,
    }
    return "\n".join(lines), context


def _mutation_actions() -> tuple[Callable[[], Any], ...]:
    return (
        lambda: observe_completed_step(
            State(), replace(TIGHT, contacts=(True, True, True)), 8, 120, 120
        ),
        lambda: observe_completed_step(
            State(), replace(TIGHT, contacts=(True, True, True, 1)), 8, 120, 120
        ),
        lambda: observe_completed_step(
            State(), replace(TIGHT, torso_tilt_rad="0.005"), 8, 120, 120
        ),
        lambda: observe_completed_step(
            State(), replace(TIGHT, torso_tilt_rad=math.nan), 8, 120, 120
        ),
        lambda: observe_completed_step(
            State(),
            replace(TIGHT, maximum_absolute_joint_position_error_rad=-0.1),
            8,
            120,
            120,
        ),
        lambda: observe_completed_step(State(next_step=960), TIGHT, 8, 120, 120),
        lambda: observe_completed_step(
            State(mode="negative_heading_recovery"), TIGHT, 8, 120, 120
        ),
        lambda: observe_completed_step(State(), TIGHT, 8, 119, 120),
        lambda: observe_completed_step(State(), TIGHT, 8, 120, 119),
        lambda: observe_completed_step(State(), TIGHT, 0, 120, 120),
        lambda: observe_completed_step(
            State(mode=PASSIVE_MODE), TIGHT, 8, 0, 120
        ),
        lambda: simulate([TIGHT] * 959),
        lambda: simulate([TIGHT] * 961),
        lambda: outcome(State(next_step=959)),
    )


def preflight() -> dict[str, Any]:
    vector, context = _semantic_vector()
    codes: list[str] = []
    for action in _mutation_actions():
        try:
            action()
        except NativeTemporalError as error:
            codes.append(str(error))
        else:
            raise NativeTemporalError("R23D14_MUTATION_UNEXPECTEDLY_ACCEPTED")
    if tuple(codes) != EXPECTED_MUTATION_CODES:
        raise NativeTemporalError("R23D14_MUTATION_FAILURE_CODES_CHANGED")
    retained_positive = (
        context["positive"]["handoff_after_active_step"] == 438
        and context["positive"]["passive_step_count"] == 521
        and context["positive"]["quiescent_taper_gate_passed"]
    )
    retained_negative = (
        context["negative"]["handoff_after_active_step"] == 579
        and context["negative"]["passive_step_count"] == 380
        and context["negative"]["quiescent_taper_gate_passed"]
    )
    passive_zero = (
        context["earliest"]["passive_native_application_count"] == 0
        and context["earliest"]["mode"] == PASSIVE_MODE
    )
    if not (retained_positive and retained_negative and passive_zero):
        raise NativeTemporalError("R23D14_NATIVE_CANARY_FAILED")
    return {
        "schema_version": "sporespore_qsdk_r23d14_native_temporal_preflight_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "policy_id": POLICY_ID,
        "engine_id": ENGINE_ID,
        "language": "python",
        "valid_canary_count": 12,
        "mutation_control_count": len(codes),
        "valid_canary_vector": vector,
        "mutation_failure_codes": codes,
        "retained_positive_timing_shape_passed": retained_positive,
        "retained_negative_timing_shape_passed": retained_negative,
        "passive_exact_zero_actuation_canary_passed": passive_zero,
        "reference_oracle_imported": False,
        "physical_worker_implemented": False,
        "physical_execution_authorized": False,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _failure(code: str) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r23d14_native_temporal_failure_v1",
        "engine_id": ENGINE_ID,
        "failure_stage": "before_model",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight", "physical"))
    args = parser.parse_args(argv)
    if args.command == "physical":
        print(
            "QSDK_R23D14_MUJOCO_TEMPORAL_FAILURE ",
            json.dumps(
                _failure("QSDK_R23D14_MJC_PHYSICAL_ROUTE_NOT_IMPLEMENTED"),
                sort_keys=True,
                separators=(",", ":"),
            ),
            sep="",
        )
        return 1
    try:
        receipt = preflight()
    except NativeTemporalError as error:
        print(
            "QSDK_R23D14_MUJOCO_TEMPORAL_FAILURE ",
            json.dumps(_failure(str(error)), sort_keys=True, separators=(",", ":")),
            sep="",
        )
        return 1
    print(
        "QSDK_R23D14_MUJOCO_TEMPORAL_PREFLIGHT ",
        json.dumps(receipt, sort_keys=True, separators=(",", ":")),
        sep="",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
