"""Independent MuJoCo/Python diagnostic-semantics mirror for QSDK-R23D12.

This module deliberately does not import the stage-zero reference oracle.  It
implements the frozen schema independently and contains no MuJoCo model,
physics step, controller, selector, or outcome logic.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
import argparse
import json
import math
from typing import Any, Sequence


GATE_ID = "QSDK-R23D12"
CAMPAIGN_ID = (
    "QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-"
    "BILATERAL-TURN-DEVELOPMENT"
)
ENGINE_ID = "mujoco"

ACTIVE_CONTROL = "active_control"
PASSIVE_OBSERVATION = "passive_observation"
PLANNER_AVAILABLE = "available"
PLANNER_OBSERVATION_UNAVAILABLE = "observation_unavailable"
PLANNER_INFEASIBLE = "planning_infeasible"
PLANNER_VALUES = (
    PLANNER_AVAILABLE,
    PLANNER_OBSERVATION_UNAVAILABLE,
    PLANNER_INFEASIBLE,
)
MARGIN_MEASURED = "measured"
MARGIN_UNAVAILABLE = "measurement_unavailable"
MARGIN_VALUES = (MARGIN_MEASURED, MARGIN_UNAVAILABLE)
ACTUATOR_COUNT = 8

EXPECTED_MUTATION_CODES = (
    "R23D12_PHASE_CLASS_INVALID",
    "R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID",
    "R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID",
    "R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL",
    "R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID",
    "R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
    "R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
    "R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
    "R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE",
    "R23D12_STABILITY_DELTA_VECTOR_INVALID",
    "R23D12_STABILITY_DELTA_VECTOR_INVALID",
    "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
    "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
    "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
)


class NativeSemanticsError(ValueError):
    """Raised when the independent native schema rejects a row."""


@dataclass(frozen=True)
class NativeDiagnosticInput:
    phase_class: str
    stability_planning_availability: str | None
    minimum_dynamic_support_margin_availability: str
    minimum_dynamic_support_margin_m: object
    ordered_applied_stability_velocity_deltas_rad_s: Sequence[object]


def _finite_number(value: object) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
    )


def validate_diagnostic_semantics(value: NativeDiagnosticInput) -> dict[str, Any]:
    """Validate one native trace row without consulting the reference oracle."""

    if value.phase_class not in (ACTIVE_CONTROL, PASSIVE_OBSERVATION):
        raise NativeSemanticsError("R23D12_PHASE_CLASS_INVALID")

    planner = value.stability_planning_availability
    if value.phase_class == ACTIVE_CONTROL:
        if planner not in PLANNER_VALUES:
            raise NativeSemanticsError(
                "R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID"
            )
    elif planner is not None:
        raise NativeSemanticsError(
            "R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL"
        )

    margin_availability = value.minimum_dynamic_support_margin_availability
    if margin_availability not in MARGIN_VALUES:
        raise NativeSemanticsError("R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID")

    margin = value.minimum_dynamic_support_margin_m
    if margin_availability == MARGIN_MEASURED:
        if not _finite_number(margin):
            raise NativeSemanticsError("R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE")
        normalized_margin: float | None = float(margin)
    else:
        if margin is not None:
            raise NativeSemanticsError("R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE")
        normalized_margin = None

    raw_deltas = tuple(value.ordered_applied_stability_velocity_deltas_rad_s)
    if len(raw_deltas) != ACTUATOR_COUNT or not all(
        _finite_number(item) for item in raw_deltas
    ):
        raise NativeSemanticsError("R23D12_STABILITY_DELTA_VECTOR_INVALID")
    deltas = tuple(float(item) for item in raw_deltas)

    exact_zero_required = (
        value.phase_class == PASSIVE_OBSERVATION
        or planner != PLANNER_AVAILABLE
    )
    if exact_zero_required and any(item != 0.0 for item in deltas):
        raise NativeSemanticsError(
            "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO"
        )

    return {
        "phase_class": value.phase_class,
        "stability_planning_availability": planner,
        "minimum_dynamic_support_margin_availability": margin_availability,
        "minimum_dynamic_support_margin_m": normalized_margin,
        "ordered_applied_stability_velocity_deltas_rad_s": list(deltas),
        "stability_fallback_exact_zero_required": exact_zero_required,
    }


def _valid_canaries() -> tuple[NativeDiagnosticInput, ...]:
    zeros = (0.0,) * ACTUATOR_COUNT
    small = (0.01,) * ACTUATOR_COUNT
    return (
        NativeDiagnosticInput(ACTIVE_CONTROL, PLANNER_AVAILABLE, MARGIN_MEASURED, 0.05, small),
        NativeDiagnosticInput(ACTIVE_CONTROL, PLANNER_AVAILABLE, MARGIN_UNAVAILABLE, None, small),
        NativeDiagnosticInput(
            ACTIVE_CONTROL,
            PLANNER_OBSERVATION_UNAVAILABLE,
            MARGIN_MEASURED,
            -0.01,
            zeros,
        ),
        NativeDiagnosticInput(
            ACTIVE_CONTROL,
            PLANNER_OBSERVATION_UNAVAILABLE,
            MARGIN_UNAVAILABLE,
            None,
            zeros,
        ),
        NativeDiagnosticInput(ACTIVE_CONTROL, PLANNER_INFEASIBLE, MARGIN_MEASURED, 0.0, zeros),
        NativeDiagnosticInput(PASSIVE_OBSERVATION, None, MARGIN_MEASURED, 0.02, zeros),
        NativeDiagnosticInput(PASSIVE_OBSERVATION, None, MARGIN_UNAVAILABLE, None, zeros),
    )


def _cross_product_inputs() -> tuple[NativeDiagnosticInput, ...]:
    rows: list[NativeDiagnosticInput] = []
    zeros = (0.0,) * ACTUATOR_COUNT
    nonzero = (0.01,) * ACTUATOR_COUNT
    for planner in PLANNER_VALUES:
        for margin_availability, margin in (
            (MARGIN_MEASURED, 0.03),
            (MARGIN_UNAVAILABLE, None),
        ):
            rows.append(
                NativeDiagnosticInput(
                    ACTIVE_CONTROL,
                    planner,
                    margin_availability,
                    margin,
                    nonzero if planner == PLANNER_AVAILABLE else zeros,
                )
            )
    return tuple(rows)


def _mutations() -> tuple[NativeDiagnosticInput, ...]:
    baseline = _valid_canaries()[0]
    zeros = (0.0,) * ACTUATOR_COUNT
    return (
        replace(baseline, phase_class="terminal"),
        replace(baseline, stability_planning_availability=None),
        replace(baseline, stability_planning_availability="arm_specific"),
        replace(
            baseline,
            phase_class=PASSIVE_OBSERVATION,
            stability_planning_availability=PLANNER_AVAILABLE,
        ),
        replace(baseline, minimum_dynamic_support_margin_availability="estimated"),
        replace(baseline, minimum_dynamic_support_margin_m=None),
        replace(baseline, minimum_dynamic_support_margin_m=True),
        replace(baseline, minimum_dynamic_support_margin_m=math.nan),
        replace(
            baseline,
            minimum_dynamic_support_margin_availability=MARGIN_UNAVAILABLE,
            minimum_dynamic_support_margin_m=0.01,
        ),
        replace(
            baseline,
            ordered_applied_stability_velocity_deltas_rad_s=zeros[:-1],
        ),
        replace(
            baseline,
            ordered_applied_stability_velocity_deltas_rad_s=(0.0,) * 7
            + (math.inf,),
        ),
        replace(
            baseline,
            stability_planning_availability=PLANNER_OBSERVATION_UNAVAILABLE,
        ),
        replace(baseline, stability_planning_availability=PLANNER_INFEASIBLE),
        replace(
            baseline,
            phase_class=PASSIVE_OBSERVATION,
            stability_planning_availability=None,
        ),
    )


def _receipt_vector(receipt: dict[str, Any]) -> str:
    planner = receipt["stability_planning_availability"]
    planner_text = "null" if planner is None else str(planner)
    margin = receipt["minimum_dynamic_support_margin_m"]
    margin_text = "null" if margin is None else f"{float(margin):.6f}"
    delta_text = ",".join(
        f"{float(item):.6f}"
        for item in receipt["ordered_applied_stability_velocity_deltas_rad_s"]
    )
    zero_text = (
        "true" if receipt["stability_fallback_exact_zero_required"] else "false"
    )
    return "|".join(
        (
            str(receipt["phase_class"]),
            planner_text,
            str(receipt["minimum_dynamic_support_margin_availability"]),
            margin_text,
            delta_text,
            zero_text,
        )
    )


def preflight() -> dict[str, Any]:
    valid_receipts = [validate_diagnostic_semantics(row) for row in _valid_canaries()]
    cross_receipts = [
        validate_diagnostic_semantics(row) for row in _cross_product_inputs()
    ]
    mutation_codes: list[str] = []
    for row in _mutations():
        try:
            validate_diagnostic_semantics(row)
        except NativeSemanticsError as error:
            mutation_codes.append(str(error))
        else:
            raise NativeSemanticsError("R23D12_MUTATION_UNEXPECTEDLY_ACCEPTED")
    if tuple(mutation_codes) != EXPECTED_MUTATION_CODES:
        raise NativeSemanticsError("R23D12_MUTATION_FAILURE_CODES_CHANGED")

    critical = valid_receipts[2]
    critical_passed = (
        critical["stability_planning_availability"]
        == PLANNER_OBSERVATION_UNAVAILABLE
        and critical["minimum_dynamic_support_margin_availability"]
        == MARGIN_MEASURED
        and critical["minimum_dynamic_support_margin_m"] == -0.01
        and critical["stability_fallback_exact_zero_required"]
    )
    if not critical_passed:
        raise NativeSemanticsError("R23D12_CRITICAL_FAILURE_SHAPE_NOT_ACCEPTED")

    return {
        "schema_version": "sporespore_qsdk_r23d12_native_semantics_preflight_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "engine_id": ENGINE_ID,
        "language": "python",
        "valid_canary_count": len(valid_receipts),
        "active_cross_product_count": len(cross_receipts),
        "mutation_control_count": len(mutation_codes),
        "critical_r23d11_failure_shape_passed": critical_passed,
        "valid_canary_vector": "\n".join(_receipt_vector(row) for row in valid_receipts),
        "active_cross_product_vector": "\n".join(
            _receipt_vector(row) for row in cross_receipts
        ),
        "mutation_failure_codes": mutation_codes,
        "planner_and_support_margin_availability_are_independent": True,
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
        "schema_version": "sporespore_qsdk_r23d12_native_semantics_failure_v1",
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
            "QSDK_R23D12_MUJOCO_SEMANTICS_FAILURE ",
            json.dumps(
                _failure("QSDK_R23D12_MJC_PHYSICAL_ROUTE_NOT_IMPLEMENTED"),
                sort_keys=True,
                separators=(",", ":"),
            ),
            sep="",
        )
        return 1
    try:
        receipt = preflight()
    except NativeSemanticsError as error:
        print(
            "QSDK_R23D12_MUJOCO_SEMANTICS_FAILURE ",
            json.dumps(_failure(str(error)), sort_keys=True, separators=(",", ":")),
            sep="",
        )
        return 1
    print(
        "QSDK_R23D12_MUJOCO_SEMANTICS_PREFLIGHT ",
        json.dumps(receipt, sort_keys=True, separators=(",", ":")),
        sep="",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
