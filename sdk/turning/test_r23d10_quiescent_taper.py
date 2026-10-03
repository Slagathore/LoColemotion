from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import sys


MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d10_quiescent_taper as policy


SUPPORTED = (True, True, True, True)
PARTIAL = (True, True, True, False)
TIGHT = policy.Observation(SUPPORTED, 0.005, 0.18)
COARSE_ONLY = policy.Observation(SUPPORTED, 0.03, 0.30)
PARTIAL_TIGHT = policy.Observation(PARTIAL, 0.005, 0.18)
TILT_OUTSIDE_COARSE = policy.Observation(SUPPORTED, 0.04, 0.18)
ERROR_OUTSIDE_COARSE = policy.Observation(SUPPORTED, 0.005, 0.33)
TILT_OUTSIDE_TIGHT = policy.Observation(SUPPORTED, 0.02, 0.18)
ERROR_OUTSIDE_TIGHT = policy.Observation(SUPPORTED, 0.005, 0.25)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_contract_error(action, code: str) -> None:
    try:
        action()
    except policy.ContractError as error:
        require(str(error) == code, f"expected {code}, observed {error}")
        return
    raise AssertionError(f"expected ContractError {code}")


def repeat(observation: policy.Observation, count: int) -> list[policy.Observation]:
    return [observation for _ in range(count)]


def canary_support_from_first_step() -> dict:
    result = policy.simulate(repeat(TIGHT, policy.TERMINAL_STEPS))
    observed = result["outcome"]
    require(observed["quiescent_taper_gate_passed"], "first-step support did not pass")
    require(observed["handoff_after_active_step"] == 120, "first handoff step changed")
    require(observed["first_passive_step"] == 121, "first passive step changed")
    require(observed["active_step_count"] == 121, "first active count changed")
    require(observed["passive_step_count"] == 779, "first passive count changed")
    require(observed["post_handoff_contact_loss_step_count"] == 0, "first support lost")
    require(
        policy.validate_replay(
            repeat(TIGHT, policy.TERMINAL_STEPS),
            result["receipts"],
            result["outcome"],
        ),
        "first-step replay failed",
    )
    return observed


def canary_r23d9_positive_shape() -> dict:
    observations = repeat(PARTIAL_TIGHT, 313) + repeat(
        TIGHT, policy.TERMINAL_STEPS - 313
    )
    result = policy.simulate(observations)
    observed = result["outcome"]
    require(observed["quiescent_taper_gate_passed"], "positive-shaped path failed")
    require(observed["handoff_after_active_step"] == 433, "positive handoff changed")
    require(observed["first_passive_step"] == 434, "positive passive start changed")
    require(observed["passive_step_count"] == 466, "positive passive count changed")
    return observed


def canary_reset_then_confirm() -> dict:
    observations = (
        repeat(PARTIAL_TIGHT, 10)
        + repeat(TIGHT, 1)
        + repeat(TIGHT, 50)
        + repeat(PARTIAL_TIGHT, 1)
        + repeat(TIGHT, policy.TERMINAL_STEPS - 62)
    )
    result = policy.simulate(observations)
    observed = result["outcome"]
    require(observed["quiescent_taper_gate_passed"], "reset path failed")
    require(observed["taper_reset_count"] == 1, "reset count changed")
    require(observed["handoff_after_active_step"] == 182, "reset handoff changed")
    require(observed["first_passive_step"] == 183, "reset passive start changed")
    return observed


def canary_never_tight() -> dict:
    result = policy.simulate(repeat(COARSE_ONLY, policy.TERMINAL_STEPS))
    observed = result["outcome"]
    require(not observed["quiescent_taper_gate_passed"], "deadline path passed")
    require(not observed["confirmation_satisfied"], "deadline path confirmed")
    require(observed["handoff_reason"] == policy.DEADLINE_REASON, "deadline reason changed")
    require(observed["handoff_after_active_step"] == 539, "deadline handoff changed")
    require(observed["first_passive_step"] == 540, "deadline passive start changed")
    require(observed["passive_step_count"] == 360, "deadline passive count changed")
    return observed


def canary_post_handoff_contact_loss() -> dict:
    observations = repeat(TIGHT, policy.TERMINAL_STEPS)
    observations[500] = PARTIAL_TIGHT
    result = policy.simulate(observations)
    observed = result["outcome"]
    require(not observed["quiescent_taper_gate_passed"], "post-handoff loss passed")
    require(observed["mode"] == policy.PASSIVE_MODE, "post-handoff path reactivated")
    require(observed["first_post_handoff_contact_loss_step"] == 500, "loss step changed")
    require(observed["post_handoff_contact_loss_step_count"] == 1, "loss count changed")
    return observed


def mutation_controls() -> int:
    passed = 0

    state, receipt = policy.observe_completed_step(
        policy.State(), PARTIAL_TIGHT, policy.ACTUATOR_COUNT, 120, 120
    )
    require(state.mode == policy.ACTIVE_MODE and not receipt["transition_after_step"], "entered taper without coarse pose")
    passed += 1

    taper = policy.State(next_step=10, mode=policy.TAPER_MODE, taper_step_count=5)
    state, receipt = policy.observe_completed_step(taper, PARTIAL_TIGHT, 8, 115, 120)
    require(state.mode == policy.ACTIVE_MODE and state.taper_reset_count == 1 and receipt["taper_reset_after_step"], "contact loss did not reset taper")
    passed += 1

    state, _ = policy.observe_completed_step(taper, TILT_OUTSIDE_COARSE, 8, 115, 120)
    require(state.mode == policy.ACTIVE_MODE and state.taper_step_count == 0, "tilt failure did not reset taper")
    passed += 1

    state, _ = policy.observe_completed_step(taper, ERROR_OUTSIDE_COARSE, 8, 115, 120)
    require(state.mode == policy.ACTIVE_MODE and state.taper_step_count == 0, "joint-error failure did not reset taper")
    passed += 1

    expect_contract_error(
        lambda: policy.observe_completed_step(taper, TIGHT, 8, 114, 120),
        "R23D10_VELOCITY_SCALE_MISMATCH",
    )
    passed += 1

    expect_contract_error(
        lambda: policy.observe_completed_step(taper, TIGHT, 8, 115, 119),
        "R23D10_VELOCITY_SCALE_MISMATCH",
    )
    passed += 1

    base_observations = repeat(TIGHT, policy.TERMINAL_STEPS)
    base = policy.simulate(base_observations)
    changed_receipts = deepcopy(base["receipts"])
    changed_receipts[119]["next_mode"] = policy.PASSIVE_MODE
    require(
        not policy.validate_replay(base_observations, changed_receipts, base["outcome"]),
        "early handoff mutation escaped",
    )
    passed += 1

    nearly_complete = policy.State(
        next_step=200, mode=policy.TAPER_MODE, taper_step_count=119
    )
    state, _ = policy.observe_completed_step(
        nearly_complete, TILT_OUTSIDE_TIGHT, 8, 1, 120
    )
    require(state.mode == policy.TAPER_MODE and not state.confirmation_satisfied, "tight tilt omission escaped")
    passed += 1

    state, _ = policy.observe_completed_step(
        nearly_complete, ERROR_OUTSIDE_TIGHT, 8, 1, 120
    )
    require(state.mode == policy.TAPER_MODE and not state.confirmation_satisfied, "tight error omission escaped")
    passed += 1

    deadline = policy.State(next_step=539, mode=policy.ACTIVE_MODE)
    state, _ = policy.observe_completed_step(deadline, PARTIAL_TIGHT, 8, 120, 120)
    require(state.mode == policy.PASSIVE_MODE and state.handoff_reason == policy.DEADLINE_REASON, "active step survived deadline")
    passed += 1

    require(not canary_never_tight()["quiescent_taper_gate_passed"], "forced deadline mutation passed")
    passed += 1

    passive = policy.State(
        next_step=600,
        mode=policy.PASSIVE_MODE,
        handoff_after_active_step=120,
        first_passive_step=121,
        handoff_reason=policy.CONFIRMED_REASON,
        confirmation_satisfied=True,
    )
    state, _ = policy.observe_completed_step(passive, PARTIAL_TIGHT, 0, 0, 120)
    require(state.mode == policy.PASSIVE_MODE, "passive contact loss reactivated policy")
    passed += 1

    expect_contract_error(
        lambda: policy.observe_completed_step(passive, TIGHT, 8, 0, 120),
        "R23D10_APPLICATION_COUNT_MISMATCH",
    )
    passed += 1

    expect_contract_error(
        lambda: policy.outcome(policy.State(next_step=899)),
        "R23D10_OUTCOME_BEFORE_HORIZON",
    )
    passed += 1

    require(
        (
            policy.COARSE_MAXIMUM_TILT_RAD,
            policy.COARSE_MAXIMUM_JOINT_ERROR_RAD,
            policy.TIGHT_MAXIMUM_TILT_RAD,
            policy.TIGHT_MAXIMUM_JOINT_ERROR_RAD,
        )
        == (0.035, 0.32, 0.01, 0.2),
        "frozen threshold mutation escaped",
    )
    passed += 1

    require(
        (
            policy.MINIMUM_TAPER_STEPS,
            policy.MAXIMUM_ACTIVE_STEPS,
            policy.MINIMUM_PASSIVE_STEPS,
            policy.TERMINAL_STEPS,
        )
        == (120, 540, 360, 900),
        "frozen taper or horizon mutation escaped",
    )
    passed += 1

    return passed


def main() -> int:
    outcomes = {
        "support_from_first_step": canary_support_from_first_step(),
        "r23d9_positive_shape": canary_r23d9_positive_shape(),
        "reset_then_confirm": canary_reset_then_confirm(),
        "never_tight": canary_never_tight(),
        "post_handoff_contact_loss": canary_post_handoff_contact_loss(),
    }
    mutation_count = mutation_controls()
    require(len(outcomes) == 5, "oracle canary count changed")
    require(mutation_count == 16, "mutation control count changed")
    print(
        "QSDK_R23D10_ORACLE_PASS "
        f"canaries={len(outcomes)} mutations={mutation_count} "
        f"terminal_steps={policy.TERMINAL_STEPS} "
        f"maximum_active={policy.MAXIMUM_ACTIVE_STEPS} "
        f"taper={policy.MINIMUM_TAPER_STEPS} passive={policy.MINIMUM_PASSIVE_STEPS} "
        "processes=0 models=0 worlds=0 physical_authority=False"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
