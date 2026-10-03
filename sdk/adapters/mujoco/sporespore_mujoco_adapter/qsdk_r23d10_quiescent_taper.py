"""Independent MuJoCo/Python temporal mirror for prospective QSDK-R23D10.

This module deliberately imports neither MuJoCo nor the engine-free oracle.
It constructs no model or world.  The separate test module compares this
implementation against the frozen oracle, while this file remains a genuinely
independent native-language transcription of the terminal scheduler.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass, replace
import json
import math
from typing import Any, Sequence


CAMPAIGN_ID = (
    "QSDK-R23D10-SUPPORT-POSE-CONFIRMED-QUIESCENT-TAPER-"
    "BILATERAL-TURN-DEVELOPMENT"
)
GATE_ID = "QSDK-R23D10"
ENGINE_ID = "mujoco"
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


class NativeContractError(ValueError):
    """The MuJoCo-native mirror rejected a temporal-contract violation."""


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
        isinstance(contact, bool) for contact in observation.contacts
    ):
        raise NativeContractError("R23D10_OBSERVATION_CONTACT_SHAPE_INVALID")
    values = (
        observation.torso_tilt_rad,
        observation.maximum_absolute_joint_position_error_rad,
    )
    if not all(isinstance(value, (int, float)) for value in values):
        raise NativeContractError("R23D10_OBSERVATION_NUMERIC_TYPE_INVALID")
    if not all(math.isfinite(float(value)) and float(value) >= 0.0 for value in values):
        raise NativeContractError("R23D10_OBSERVATION_NUMERIC_VALUE_INVALID")


def _all_four(observation: Observation) -> bool:
    return all(observation.contacts)


def _coarse(observation: Observation) -> bool:
    return (
        _all_four(observation)
        and observation.torso_tilt_rad <= COARSE_MAXIMUM_TILT_RAD
        and observation.maximum_absolute_joint_position_error_rad
        <= COARSE_MAXIMUM_JOINT_ERROR_RAD
    )


def _tight(observation: Observation) -> bool:
    return (
        _all_four(observation)
        and observation.torso_tilt_rad <= TIGHT_MAXIMUM_TILT_RAD
        and observation.maximum_absolute_joint_position_error_rad
        <= TIGHT_MAXIMUM_JOINT_ERROR_RAD
    )


def expected_velocity_scale(state: State) -> tuple[int, int]:
    if state.mode == ACTIVE_MODE:
        return SCALE_DENOMINATOR, SCALE_DENOMINATOR
    if state.mode == TAPER_MODE:
        return max(1, MINIMUM_TAPER_STEPS - state.taper_step_count), SCALE_DENOMINATOR
    if state.mode == PASSIVE_MODE:
        return 0, SCALE_DENOMINATOR
    raise NativeContractError("R23D10_STATE_MODE_INVALID")


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
        raise NativeContractError("R23D10_STEP_OUTSIDE_HORIZON")
    if state.mode not in (ACTIVE_MODE, TAPER_MODE, PASSIVE_MODE):
        raise NativeContractError("R23D10_STATE_MODE_INVALID")
    _validate_observation(observation)
    expected_numerator, expected_denominator = expected_velocity_scale(state)
    if (
        velocity_scale_numerator != expected_numerator
        or velocity_scale_denominator != expected_denominator
    ):
        raise NativeContractError("R23D10_VELOCITY_SCALE_MISMATCH")
    expected_applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
    if native_application_count != expected_applications:
        raise NativeContractError("R23D10_APPLICATION_COUNT_MISMATCH")

    step = state.next_step
    mode = state.mode
    pre_taper_count = state.taper_step_count
    coarse = _coarse(observation)
    tight = _tight(observation)
    transitioned = False
    reset = False
    next_state = replace(state, next_step=step + 1)

    if mode in (ACTIVE_MODE, TAPER_MODE):
        next_state = replace(
            next_state,
            active_step_count=state.active_step_count + 1,
            active_native_application_count=(
                state.active_native_application_count + native_application_count
            ),
        )
        if mode == ACTIVE_MODE:
            if step == MAXIMUM_ACTIVE_STEPS - 1:
                next_state = _handoff(next_state, step, False)
                transitioned = True
            elif coarse:
                next_state = replace(next_state, mode=TAPER_MODE, taper_step_count=0)
                transitioned = True
        elif coarse:
            post_taper_count = min(MINIMUM_TAPER_STEPS, pre_taper_count + 1)
            next_state = replace(next_state, taper_step_count=post_taper_count)
            if post_taper_count >= MINIMUM_TAPER_STEPS and tight:
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

    receipt = {
        "step": step,
        "mode": mode,
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
        "taper_reset_after_step": reset,
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
        raise NativeContractError("R23D10_OUTCOME_BEFORE_HORIZON")
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
        raise NativeContractError("R23D10_OBSERVATION_HORIZON_INVALID")
    state = State()
    receipts: list[dict[str, Any]] = []
    for observation in observations:
        numerator, denominator = expected_velocity_scale(state)
        applications = 0 if state.mode == PASSIVE_MODE else ACTUATOR_COUNT
        state, receipt = observe_completed_step(
            state, observation, applications, numerator, denominator
        )
        receipts.append(receipt)
    return {"receipts": receipts, "outcome": outcome(state)}


SUPPORTED = (True, True, True, True)
PARTIAL = (True, True, True, False)
TIGHT = Observation(SUPPORTED, 0.005, 0.18)
COARSE_ONLY = Observation(SUPPORTED, 0.03, 0.30)
PARTIAL_TIGHT = Observation(PARTIAL, 0.005, 0.18)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise NativeContractError(message)


def _raises(code: str, action: Any) -> bool:
    try:
        action()
    except NativeContractError as error:
        return str(error) == code
    return False


def run_zero_world_preflight() -> tuple[int, int]:
    first = simulate([TIGHT] * TERMINAL_STEPS)["outcome"]
    delayed = simulate([PARTIAL_TIGHT] * 313 + [TIGHT] * 587)["outcome"]
    reset = simulate(
        [PARTIAL_TIGHT] * 10
        + [TIGHT] * 51
        + [PARTIAL_TIGHT]
        + [TIGHT] * 838
    )["outcome"]
    deadline = simulate([COARSE_ONLY] * TERMINAL_STEPS)["outcome"]
    loss_rows = [TIGHT] * TERMINAL_STEPS
    loss_rows[500] = PARTIAL_TIGHT
    loss = simulate(loss_rows)["outcome"]
    _require(first["handoff_after_active_step"] == 120 and first["quiescent_taper_gate_passed"], "R23D10_MJC_CANARY_FIRST")
    _require(delayed["handoff_after_active_step"] == 433 and delayed["quiescent_taper_gate_passed"], "R23D10_MJC_CANARY_DELAYED")
    _require(reset["handoff_after_active_step"] == 182 and reset["taper_reset_count"] == 1, "R23D10_MJC_CANARY_RESET")
    _require(deadline["handoff_after_active_step"] == 539 and not deadline["quiescent_taper_gate_passed"], "R23D10_MJC_CANARY_DEADLINE")
    _require(loss["first_post_handoff_contact_loss_step"] == 500 and not loss["quiescent_taper_gate_passed"], "R23D10_MJC_CANARY_LOSS")

    mutations = 0
    state, receipt = observe_completed_step(State(), PARTIAL_TIGHT, 8, 120, 120)
    _require(state.mode == ACTIVE_MODE and not receipt["transition_after_step"], "R23D10_MJC_MUTATION_COARSE_CONTACT")
    mutations += 1
    taper = State(next_step=10, mode=TAPER_MODE, taper_step_count=5)
    state, receipt = observe_completed_step(taper, PARTIAL_TIGHT, 8, 115, 120)
    _require(state.mode == ACTIVE_MODE and receipt["taper_reset_after_step"], "R23D10_MJC_MUTATION_RESET_CONTACT")
    mutations += 1
    for observation, label in (
        (Observation(SUPPORTED, 0.04, 0.18), "TILT"),
        (Observation(SUPPORTED, 0.005, 0.33), "ERROR"),
    ):
        state, _ = observe_completed_step(taper, observation, 8, 115, 120)
        _require(state.mode == ACTIVE_MODE, f"R23D10_MJC_MUTATION_RESET_{label}")
        mutations += 1
    _require(_raises("R23D10_VELOCITY_SCALE_MISMATCH", lambda: observe_completed_step(taper, TIGHT, 8, 114, 120)), "R23D10_MJC_MUTATION_NUMERATOR")
    mutations += 1
    _require(_raises("R23D10_VELOCITY_SCALE_MISMATCH", lambda: observe_completed_step(taper, TIGHT, 8, 115, 119)), "R23D10_MJC_MUTATION_DENOMINATOR")
    mutations += 1
    early = State(next_step=100, mode=TAPER_MODE, taper_step_count=118)
    state, _ = observe_completed_step(early, TIGHT, 8, 2, 120)
    _require(state.mode == TAPER_MODE, "R23D10_MJC_MUTATION_EARLY_HANDOFF")
    mutations += 1
    near = State(next_step=200, mode=TAPER_MODE, taper_step_count=119)
    for observation, label in (
        (Observation(SUPPORTED, 0.02, 0.18), "TIGHT_TILT"),
        (Observation(SUPPORTED, 0.005, 0.25), "TIGHT_ERROR"),
    ):
        state, _ = observe_completed_step(near, observation, 8, 1, 120)
        _require(state.mode == TAPER_MODE and not state.confirmation_satisfied, f"R23D10_MJC_MUTATION_{label}")
        mutations += 1
    deadline_state = State(next_step=539)
    state, _ = observe_completed_step(deadline_state, PARTIAL_TIGHT, 8, 120, 120)
    _require(state.mode == PASSIVE_MODE and state.handoff_reason == DEADLINE_REASON, "R23D10_MJC_MUTATION_DEADLINE")
    mutations += 1
    _require(not deadline["quiescent_taper_gate_passed"], "R23D10_MJC_MUTATION_FORCED_PASS")
    mutations += 1
    passive = State(next_step=600, mode=PASSIVE_MODE, confirmation_satisfied=True, handoff_after_active_step=120, first_passive_step=121, handoff_reason=CONFIRMED_REASON)
    state, _ = observe_completed_step(passive, PARTIAL_TIGHT, 0, 0, 120)
    _require(state.mode == PASSIVE_MODE, "R23D10_MJC_MUTATION_REACTIVATION")
    mutations += 1
    _require(_raises("R23D10_APPLICATION_COUNT_MISMATCH", lambda: observe_completed_step(passive, TIGHT, 8, 0, 120)), "R23D10_MJC_MUTATION_PASSIVE_APPLICATION")
    mutations += 1
    _require(_raises("R23D10_OUTCOME_BEFORE_HORIZON", lambda: outcome(State(next_step=899))), "R23D10_MJC_MUTATION_SHORT_HORIZON")
    mutations += 1
    _require((COARSE_MAXIMUM_TILT_RAD, COARSE_MAXIMUM_JOINT_ERROR_RAD, TIGHT_MAXIMUM_TILT_RAD, TIGHT_MAXIMUM_JOINT_ERROR_RAD) == (0.035, 0.32, 0.01, 0.2), "R23D10_MJC_MUTATION_THRESHOLDS")
    mutations += 1
    _require((MINIMUM_TAPER_STEPS, MAXIMUM_ACTIVE_STEPS, MINIMUM_PASSIVE_STEPS, TERMINAL_STEPS) == (120, 540, 360, 900), "R23D10_MJC_MUTATION_SCHEDULE")
    mutations += 1
    _require(mutations == 16, "R23D10_MJC_MUTATION_COUNT")
    return 5, mutations


def _cell(stage_id: str, arm_id: str) -> None:
    allowed = {
        "mujoco_quiescent_taper_screen": ("positive_heading", "negative_heading"),
        "three_engine_confirmation": (
            "reference_zero",
            "positive_heading",
            "negative_heading",
        ),
    }
    if stage_id not in allowed or arm_id not in allowed[stage_id]:
        raise NativeContractError("R23D10_MJC_CELL_IDENTITY_INVALID")


def preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    _cell(stage_id, arm_id)
    canaries, mutations = run_zero_world_preflight()
    return {
        "schema_version": "sporespore_qsdk_r23d10_mujoco_temporal_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": stage_id,
        "arm_id": arm_id,
        "terminal_step_count": TERMINAL_STEPS,
        "maximum_active_step_count": MAXIMUM_ACTIVE_STEPS,
        "minimum_quiescent_taper_step_count": MINIMUM_TAPER_STEPS,
        "minimum_passive_step_count": MINIMUM_PASSIVE_STEPS,
        "oracle_canary_count": canaries,
        "mutation_control_count": mutations,
        "native_temporal_mirror": True,
        "fixed_total_trace_step_count": 3892,
        "physical_worker_implemented": True,
        "physical_worker_dormant_behind_supervisor_authorization": True,
        "physical_execution_authorized": False,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    preflight_parser = commands.add_parser("preflight")
    for command_parser in (
        preflight_parser,
        commands.add_parser("authorization-preflight"),
        commands.add_parser("physical"),
    ):
        command_parser.add_argument("--stage-id", required=True)
        command_parser.add_argument("--arm-id", required=True)
        command_parser.add_argument("--source-commit", default="")
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            receipt = preflight(args.stage_id, args.arm_id)
            print(
                "QSDK_R23D10_MUJOCO_PREFLIGHT "
                + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        from . import qsdk_r23d10_quiescent_taper_physical as physical

        if args.command == "authorization-preflight":
            receipt = physical.authorization_preflight(
                args.stage_id, args.arm_id, args.source_commit
            )
            print(
                "QSDK_R23D10_MUJOCO_AUTHORIZATION_PREFLIGHT "
                + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        report = physical.run_physical(args.stage_id, args.arm_id, args.source_commit)
        print(
            "QSDK_R23D10_TERMINAL "
            + json.dumps(report, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except NativeContractError as error:
        print("QSDK_R23D10_MUJOCO_FAILURE " + json.dumps({"failure_code": str(error)}, sort_keys=True))
        return 1
    except Exception as error:
        try:
            from . import qsdk_r23d10_quiescent_taper_physical as physical

            if isinstance(error, physical.R23D10MujocoPhysicalError):
                if error.terminal_receipt is not None:
                    print(
                        "QSDK_R23D10_TERMINAL "
                        + json.dumps(
                            error.terminal_receipt,
                            allow_nan=False,
                            separators=(",", ":"),
                            sort_keys=True,
                        )
                    )
                else:
                    print(
                        "QSDK_R23D10_MUJOCO_FAILURE "
                        + json.dumps({"failure_code": str(error)}, sort_keys=True)
                    )
                return 1
        except Exception:
            pass
        raise


if __name__ == "__main__":
    raise SystemExit(main())
