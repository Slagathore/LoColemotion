"""Zero-world canaries and mutation controls for QSDK-R23D11 stage zero."""

from __future__ import annotations

from dataclasses import replace
import math
from typing import Callable

import r23d11_stability_assisted_taper as policy


IDS = tuple(f"actuator_{index}" for index in range(policy.ACTUATOR_COUNT))
NEUTRAL = (0.1,) * policy.ACTUATOR_COUNT
RAW = (1.0,) * policy.ACTUATOR_COUNT


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_error(call: Callable[[], object], code: str) -> None:
    try:
        call()
    except policy.ContractError as error:
        require(str(error) == code, f"expected {code}, got {error}")
    else:
        raise AssertionError(f"expected {code}")


def call(**changes: object) -> object:
    values: dict[str, object] = {
        "semantic_step": 0,
        "actuator_ids": IDS,
        "neutral_velocities_rad_s": NEUTRAL,
        "raw_stability_velocity_deltas_rad_s": RAW,
        "availability": policy.AVAILABLE,
        "taper_numerator": 120,
        "taper_denominator": 120,
    }
    values.update(changes)
    return policy.compose_active_step(**values)  # type: ignore[arg-type]


def mutation_controls() -> int:
    controls: list[tuple[Callable[[], object], str]] = [
        (lambda: call(actuator_ids=IDS[:-1]), "R23D11_ACTUATOR_ORDER_INVALID"),
        (
            lambda: call(actuator_ids=IDS[:-1] + (IDS[0],)),
            "R23D11_ACTUATOR_ORDER_INVALID",
        ),
        (
            lambda: call(neutral_velocities_rad_s=NEUTRAL[:-1]),
            "R23D11_NEUTRAL_VELOCITY_INVALID",
        ),
        (
            lambda: call(neutral_velocities_rad_s=(math.nan,) + NEUTRAL[1:]),
            "R23D11_NEUTRAL_VELOCITY_INVALID",
        ),
        (
            lambda: call(neutral_velocities_rad_s=(0.351,) + NEUTRAL[1:]),
            "R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND",
        ),
        (
            lambda: call(raw_stability_velocity_deltas_rad_s=RAW[:-1]),
            "R23D11_STABILITY_CORRECTION_COUNT_INVALID",
        ),
        (
            lambda: call(raw_stability_velocity_deltas_rad_s=(math.inf,) + RAW[1:]),
            "R23D11_AVAILABLE_CORRECTION_INVALID",
        ),
        (
            lambda: call(
                availability=policy.OBSERVATION_UNAVAILABLE,
                raw_stability_velocity_deltas_rad_s=RAW,
            ),
            "R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE",
        ),
        (lambda: call(availability="arm_specific"), "R23D11_AVAILABILITY_INVALID"),
        (lambda: call(semantic_step=-1), "R23D11_SEMANTIC_STEP_INVALID"),
        (lambda: call(taper_numerator=0), "R23D11_TAPER_FRACTION_INVALID"),
        (lambda: call(taper_numerator=121), "R23D11_TAPER_FRACTION_INVALID"),
        (lambda: call(taper_denominator=119), "R23D11_TAPER_FRACTION_INVALID"),
        (
            lambda: call(
                memory=policy.CompositionMemory(previous_semantic_step=0),
            ),
            "R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE",
        ),
        (
            lambda: call(
                memory=policy.CompositionMemory(0, IDS, (0.0,) * 8),
            ),
            "R23D11_PREVIOUS_STEP_NOT_PREVIOUS",
        ),
        (
            lambda: call(
                semantic_step=1,
                memory=policy.CompositionMemory(0, tuple(reversed(IDS)), (0.0,) * 8),
            ),
            "R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID",
        ),
        (
            lambda: call(
                semantic_step=1,
                memory=policy.CompositionMemory(0, IDS, (0.0,) * 7),
            ),
            "R23D11_PREVIOUS_CORRECTION_INVALID",
        ),
        (
            lambda: call(
                semantic_step=1,
                memory=policy.CompositionMemory(0, IDS, (math.nan,) + (0.0,) * 7),
            ),
            "R23D11_PREVIOUS_CORRECTION_INVALID",
        ),
    ]
    for invoke, code in controls:
        expect_error(invoke, code)
    return len(controls)


def main() -> int:
    result = policy.run_zero_world_preflight()
    require(result["canary_count"] == 7, "canary count changed")
    require(result["world_build_count"] == 0, "zero-world preflight built a world")
    require(not result["physical_execution_authorized"], "preflight gained authority")

    memory, first = call()  # type: ignore[misc]
    first_rows = first["ordered_actuator_composition"]
    require(
        all(row["applied_stability_velocity_delta_rad_s"] == 0.01 for row in first_rows),
        "initial slew bound changed",
    )
    _, second = call(semantic_step=1, memory=memory)  # type: ignore[misc]
    require(
        all(
            row["applied_stability_velocity_delta_rad_s"] == 0.02
            for row in second["ordered_actuator_composition"]
        ),
        "continuation slew bound changed",
    )
    _, unavailable = call(  # type: ignore[misc]
        availability=policy.PLANNING_INFEASIBLE,
        raw_stability_velocity_deltas_rad_s=(None,) * 8,
    )
    require(unavailable["fallback_applied"], "unavailable fallback changed")
    require(
        all(row["applied_stability_velocity_delta_rad_s"] == 0.0 for row in unavailable["ordered_actuator_composition"]),
        "unavailable correction was fabricated",
    )
    passive = policy.compose_passive_step(IDS)
    require(
        passive["native_actuation_application_count"] == 0
        and not passive["neutral_composition_invoked"]
        and not passive["stability_composition_invoked"],
        "passive boundary changed",
    )
    require(
        (
            policy.GLOBAL_REQUESTED_CORRECTION_SCALE,
            policy.MAXIMUM_ABSOLUTE_STABILITY_VELOCITY_DELTA_RAD_S,
            policy.MAXIMUM_STABILITY_VELOCITY_SLEW_PER_STEP_RAD_S,
            policy.MAXIMUM_ABSOLUTE_NEUTRAL_VELOCITY_RAD_S,
            policy.MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S,
        )
        == (0.5, 0.075, 0.010, 0.35, 0.425),
        "frozen composition constants changed",
    )

    mutation_count = mutation_controls()
    require(mutation_count == 18, "mutation count changed")
    print(
        "QSDK_R23D11_ORACLE_PASS "
        "canaries=7 mutations=18 actuators=8 temporal_steps=900 "
        "active_maximum=540 taper=120 passive=360 "
        "processes=0 models=0 worlds=0 physical_authority=False"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
