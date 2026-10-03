"""Development successor adding disclosed horizon to tight-gated acquisition.

The retained v1 screen first reached the negative tight pose at active index
459 and completed only 80 of 120 required taper steps before the 540-step
deadline.  This outcome-visible v2 keeps every pose threshold and the complete
controller law, raises maximum active steps to 600, and raises the total
terminal horizon to 960 so at least 360 passive steps remain.
"""

from __future__ import annotations

from dataclasses import asdict
from typing import Any, Sequence

try:
    from . import terminal_tight_first_development as v1
except ImportError:  # pragma: no cover - direct invocation route
    import terminal_tight_first_development as v1


CANDIDATE_ID = "tight_gated_acquisition_active600_v2"
SCHEMA_VERSION = "sporespore_terminal_tight_first_horizon_development_v1"
ACTIVE_MODE = v1.ACTIVE_MODE
TAPER_MODE = v1.TAPER_MODE
PASSIVE_MODE = v1.PASSIVE_MODE
CONFIRMED_REASON = v1.CONFIRMED_REASON
DEADLINE_REASON = v1.DEADLINE_REASON
TERMINAL_STEPS = 960
MAXIMUM_ACTIVE_STEPS = 600
MINIMUM_TAPER_STEPS = v1.MINIMUM_TAPER_STEPS
MINIMUM_PASSIVE_STEPS = v1.MINIMUM_PASSIVE_STEPS
ACTUATOR_COUNT = v1.ACTUATOR_COUNT
SCALE_DENOMINATOR = v1.SCALE_DENOMINATOR
Observation = v1.Observation
State = v1.State
ContractError = v1.ContractError
expected_velocity_scale_fraction = v1.expected_velocity_scale_fraction
tight_pose_satisfied = v1.tight_pose_satisfied
coarse_pose_satisfied = v1.coarse_pose_satisfied


def observe_completed_step(
    state: State,
    observation: Observation,
    native_application_count: int,
    velocity_scale_numerator: int,
    velocity_scale_denominator: int,
) -> tuple[State, dict[str, Any]]:
    return v1._observe_completed_step_for_horizons(
        state,
        observation,
        native_application_count,
        velocity_scale_numerator,
        velocity_scale_denominator,
        terminal_steps=TERMINAL_STEPS,
        maximum_active_steps=MAXIMUM_ACTIVE_STEPS,
    )


def outcome(state: State) -> dict[str, Any]:
    if state.next_step != TERMINAL_STEPS:
        raise ContractError("TIGHT_FIRST_HORIZON_OUTCOME_BEFORE_HORIZON")
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
        raise ContractError("TIGHT_FIRST_HORIZON_OBSERVATION_COUNT_INVALID")
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
    observed_timing = [coarse_only] * 459 + [tight] * (TERMINAL_STEPS - 459)
    observed = simulate(observed_timing)
    deadline = simulate([coarse_only] * TERMINAL_STEPS)
    checks = {
        "first_tight_at_459_enters_taper": (
            observed["receipts"][459]["next_mode"] == TAPER_MODE
        ),
        "confirmation_finishes_at_579": (
            observed["outcome"]["handoff_after_active_step"] == 579
        ),
        "first_passive_is_580": observed["outcome"]["first_passive_step"] == 580,
        "retains_380_passive_steps": observed["outcome"]["passive_step_count"] == 380,
        "observed_timing_passes_complete_gate": bool(
            observed["outcome"]["quiescent_taper_gate_passed"]
        ),
        "coarse_only_deadline_is_599": (
            deadline["outcome"]["handoff_after_active_step"] == 599
        ),
        "coarse_only_still_fails": not bool(
            deadline["outcome"]["quiescent_taper_gate_passed"]
        ),
        "deadline_retains_360_passive_steps": (
            deadline["outcome"]["passive_step_count"] == 360
        ),
    }
    if not all(checks.values()):
        raise ContractError("TIGHT_FIRST_HORIZON_ZERO_WORLD_PREFLIGHT_FAILED")
    return {
        "schema_version": SCHEMA_VERSION,
        "candidate_id": CANDIDATE_ID,
        "predecessor_candidate_id": v1.CANDIDATE_ID,
        "development_only": True,
        "outcomes_are_exposed": True,
        "candidate_change": "maximum_active_540_to_600_and_terminal_900_to_960",
        "unchanged_thresholds": {"tilt_rad": 0.01, "joint_error_rad": 0.2},
        "unchanged_minimum_taper_steps": MINIMUM_TAPER_STEPS,
        "unchanged_minimum_passive_steps": MINIMUM_PASSIVE_STEPS,
        "observed_first_tight_active_index": 459,
        "predicted_confirmation_active_index": 579,
        "active_margin_steps": 20,
        "predicted_passive_steps": 380,
        "check_count": len(checks),
        "checks": checks,
        "arm_identity_or_heading_sign_used": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "validation_authority": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }
