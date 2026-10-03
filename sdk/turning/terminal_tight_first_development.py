"""Development-only tight-gated terminal transition for portable turning.

This module is a repeatable, outcome-visible hypothesis screen.  It changes no
frozen R23D10-R23D13 identity and grants no validation, physical-acceptance, or
release authority.  The only candidate change is temporal: full acquisition
authority continues until the frozen *tight* four-contact pose is reached;
taper then requires that tight predicate to remain true for 120 completed
steps.  A tight-pose loss resets acquisition to full authority.
"""

from __future__ import annotations

from dataclasses import replace
from typing import Any, Sequence

try:
    from . import r23d10_quiescent_taper as inherited
except ImportError:  # pragma: no cover - direct invocation route
    import r23d10_quiescent_taper as inherited


CANDIDATE_ID = "tight_gated_acquisition_v1"
SCHEMA_VERSION = "sporespore_terminal_tight_first_development_v1"

ACTIVE_MODE = inherited.ACTIVE_MODE
TAPER_MODE = inherited.TAPER_MODE
PASSIVE_MODE = inherited.PASSIVE_MODE
CONFIRMED_REASON = inherited.CONFIRMED_REASON
DEADLINE_REASON = inherited.DEADLINE_REASON
TERMINAL_STEPS = inherited.TERMINAL_STEPS
MAXIMUM_ACTIVE_STEPS = inherited.MAXIMUM_ACTIVE_STEPS
MINIMUM_TAPER_STEPS = inherited.MINIMUM_TAPER_STEPS
MINIMUM_PASSIVE_STEPS = inherited.MINIMUM_PASSIVE_STEPS
ACTUATOR_COUNT = inherited.ACTUATOR_COUNT
SCALE_DENOMINATOR = inherited.SCALE_DENOMINATOR
Observation = inherited.Observation
State = inherited.State
ContractError = inherited.ContractError
expected_velocity_scale_fraction = inherited.expected_velocity_scale_fraction
tight_pose_satisfied = inherited.tight_pose_satisfied
coarse_pose_satisfied = inherited.coarse_pose_satisfied
outcome = inherited.outcome


def _transition_to_passive(state: State, *, step: int, confirmed: bool) -> State:
    return replace(
        state,
        mode=PASSIVE_MODE,
        confirmation_satisfied=confirmed,
        handoff_after_active_step=step,
        first_passive_step=step + 1,
        handoff_reason=CONFIRMED_REASON if confirmed else DEADLINE_REASON,
    )


def _observe_completed_step_for_horizons(
    state: State,
    observation: Observation,
    native_application_count: int,
    velocity_scale_numerator: int,
    velocity_scale_denominator: int,
    *,
    terminal_steps: int,
    maximum_active_steps: int,
) -> tuple[State, dict[str, Any]]:
    """Advance the candidate after one completed step without arm identity."""

    if state.next_step < 0 or state.next_step >= terminal_steps:
        raise ContractError("TIGHT_FIRST_STEP_OUTSIDE_HORIZON")
    if state.mode not in (ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE):
        raise ContractError("TIGHT_FIRST_STATE_MODE_INVALID")
    inherited._validate_observation(observation)
    expected_numerator, expected_denominator = expected_velocity_scale_fraction(state)
    if (
        velocity_scale_numerator != expected_numerator
        or velocity_scale_denominator != expected_denominator
    ):
        raise ContractError("TIGHT_FIRST_VELOCITY_SCALE_MISMATCH")
    expected_applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
    if native_application_count != expected_applications:
        raise ContractError("TIGHT_FIRST_APPLICATION_COUNT_MISMATCH")

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
            if step == maximum_active_steps - 1:
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
                elif step == maximum_active_steps - 1:
                    next_state = _transition_to_passive(
                        next_state, step=step, confirmed=False
                    )
                    transitioned = True
            elif step == maximum_active_steps - 1:
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


def observe_completed_step(
    state: State,
    observation: Observation,
    native_application_count: int,
    velocity_scale_numerator: int,
    velocity_scale_denominator: int,
) -> tuple[State, dict[str, Any]]:
    return _observe_completed_step_for_horizons(
        state,
        observation,
        native_application_count,
        velocity_scale_numerator,
        velocity_scale_denominator,
        terminal_steps=TERMINAL_STEPS,
        maximum_active_steps=MAXIMUM_ACTIVE_STEPS,
    )


def simulate(observations: Sequence[Observation]) -> dict[str, Any]:
    if len(observations) != TERMINAL_STEPS:
        raise ContractError("TIGHT_FIRST_OBSERVATION_HORIZON_INVALID")
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
    coarse_only = Observation((True, True, True, True), 0.02, 0.25)
    unsupported = Observation((True, True, True, False), 0.005, 0.1)

    passing = simulate([tight] * TERMINAL_STEPS)
    deadline = simulate([coarse_only] * TERMINAL_STEPS)

    state = State()
    numerator, denominator = expected_velocity_scale_fraction(state)
    state, first = observe_completed_step(
        state, tight, ACTUATOR_COUNT, numerator, denominator
    )
    numerator, denominator = expected_velocity_scale_fraction(state)
    state, reset = observe_completed_step(
        state, unsupported, ACTUATOR_COUNT, numerator, denominator
    )

    checks = {
        "tight_enters_taper": first["next_mode"] == TAPER_MODE,
        "coarse_only_does_not_enter_taper": (
            deadline["receipts"][0]["next_mode"] == ACTIVE_MODE
        ),
        "tight_loss_resets_full_acquisition": (
            reset["next_mode"] == ACTIVE_MODE
            and reset["taper_reset_after_step"] is True
            and expected_velocity_scale_fraction(state)
            == (SCALE_DENOMINATOR, SCALE_DENOMINATOR)
        ),
        "continuous_tight_completes_passive_handoff": bool(
            passing["outcome"]["quiescent_taper_gate_passed"]
        ),
        "coarse_only_deadline_fails": not bool(
            deadline["outcome"]["quiescent_taper_gate_passed"]
        ),
        "deadline_still_preserves_passive_horizon": (
            deadline["outcome"]["passive_step_count"] == MINIMUM_PASSIVE_STEPS
        ),
    }
    if not all(checks.values()):
        raise ContractError("TIGHT_FIRST_ZERO_WORLD_PREFLIGHT_FAILED")
    return {
        "schema_version": SCHEMA_VERSION,
        "candidate_id": CANDIDATE_ID,
        "development_only": True,
        "candidate_change": "tight_pose_gates_taper_entry_and_continuation",
        "unchanged_thresholds": {"tilt_rad": 0.01, "joint_error_rad": 0.2},
        "unchanged_horizons": {
            "terminal_steps": TERMINAL_STEPS,
            "maximum_active_steps": MAXIMUM_ACTIVE_STEPS,
            "minimum_taper_steps": MINIMUM_TAPER_STEPS,
            "minimum_passive_steps": MINIMUM_PASSIVE_STEPS,
        },
        "check_count": len(checks),
        "checks": checks,
        "arm_identity_or_heading_sign_used": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "validation_authority": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }
