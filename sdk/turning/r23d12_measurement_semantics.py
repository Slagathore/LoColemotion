"""Pure zero-world diagnostic-semantics contract for QSDK-R23D12.

R23D11 coupled two independent facts in its trace validator: whether the
stability planner could produce a correction, and whether the adapter could
measure a dynamic support margin.  This module makes those facts orthogonal.
It contains no physics, controller, selector, or outcome logic.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Sequence


GATE_ID = "QSDK-R23D12"
CAMPAIGN_ID = (
    "QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-"
    "BILATERAL-TURN-DEVELOPMENT"
)

ACTIVE_CONTROL = "active_control"
PASSIVE_OBSERVATION = "passive_observation"
PHASE_CLASSES = (ACTIVE_CONTROL, PASSIVE_OBSERVATION)

PLANNER_AVAILABLE = "available"
PLANNER_OBSERVATION_UNAVAILABLE = "observation_unavailable"
PLANNER_INFEASIBLE = "planning_infeasible"
PLANNER_AVAILABILITY_VALUES = (
    PLANNER_AVAILABLE,
    PLANNER_OBSERVATION_UNAVAILABLE,
    PLANNER_INFEASIBLE,
)

SUPPORT_MARGIN_MEASURED = "measured"
SUPPORT_MARGIN_UNAVAILABLE = "measurement_unavailable"
SUPPORT_MARGIN_AVAILABILITY_VALUES = (
    SUPPORT_MARGIN_MEASURED,
    SUPPORT_MARGIN_UNAVAILABLE,
)

ACTUATOR_COUNT = 8


class ContractError(ValueError):
    """Raised when a diagnostic row violates the prospective R23D12 schema."""


@dataclass(frozen=True)
class DiagnosticSemanticsInput:
    phase_class: str
    stability_planning_availability: str | None
    minimum_dynamic_support_margin_availability: str
    minimum_dynamic_support_margin_m: float | None
    ordered_applied_stability_velocity_deltas_rad_s: Sequence[float]


def _finite_number(value: object) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
    )


def validate_diagnostic_semantics(
    value: DiagnosticSemanticsInput,
) -> dict[str, Any]:
    """Validate one row and return a deterministic evidence-only receipt.

    Planner availability controls only whether stability deltas must fall back
    to exact zero.  Support-margin availability controls only whether the
    margin must be finite or null.  No rule derives either field from the
    other.
    """

    if value.phase_class not in PHASE_CLASSES:
        raise ContractError("R23D12_PHASE_CLASS_INVALID")

    planner_availability = value.stability_planning_availability
    if value.phase_class == ACTIVE_CONTROL:
        if planner_availability not in PLANNER_AVAILABILITY_VALUES:
            raise ContractError("R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID")
    elif planner_availability is not None:
        raise ContractError("R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL")

    margin_availability = value.minimum_dynamic_support_margin_availability
    if margin_availability not in SUPPORT_MARGIN_AVAILABILITY_VALUES:
        raise ContractError("R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID")

    support_margin = value.minimum_dynamic_support_margin_m
    if margin_availability == SUPPORT_MARGIN_MEASURED:
        if not _finite_number(support_margin):
            raise ContractError("R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE")
        normalized_support_margin = float(support_margin)
    else:
        if support_margin is not None:
            raise ContractError("R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE")
        normalized_support_margin = None

    deltas = tuple(value.ordered_applied_stability_velocity_deltas_rad_s)
    if len(deltas) != ACTUATOR_COUNT or not all(_finite_number(item) for item in deltas):
        raise ContractError("R23D12_STABILITY_DELTA_VECTOR_INVALID")
    normalized_deltas = tuple(float(item) for item in deltas)

    exact_zero_required = (
        value.phase_class == PASSIVE_OBSERVATION
        or planner_availability != PLANNER_AVAILABLE
    )
    if exact_zero_required and any(item != 0.0 for item in normalized_deltas):
        raise ContractError("R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO")

    return {
        "schema_version": "sporespore_qsdk_r23d12_diagnostic_semantics_receipt_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "phase_class": value.phase_class,
        "stability_planning_availability": planner_availability,
        "minimum_dynamic_support_margin_availability": margin_availability,
        "minimum_dynamic_support_margin_m": normalized_support_margin,
        "ordered_applied_stability_velocity_deltas_rad_s": list(normalized_deltas),
        "stability_fallback_exact_zero_required": exact_zero_required,
        "planner_and_support_margin_availability_are_independent": True,
        "planner_availability_controls_only_stability_fallback": True,
        "support_margin_availability_controls_only_margin_nullability": True,
        "decision_threshold_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def declared_valid_canaries() -> tuple[DiagnosticSemanticsInput, ...]:
    zeros = (0.0,) * ACTUATOR_COUNT
    small_deltas = (0.01,) * ACTUATOR_COUNT
    return (
        DiagnosticSemanticsInput(
            ACTIVE_CONTROL,
            PLANNER_AVAILABLE,
            SUPPORT_MARGIN_MEASURED,
            0.05,
            small_deltas,
        ),
        DiagnosticSemanticsInput(
            ACTIVE_CONTROL,
            PLANNER_AVAILABLE,
            SUPPORT_MARGIN_UNAVAILABLE,
            None,
            small_deltas,
        ),
        DiagnosticSemanticsInput(
            ACTIVE_CONTROL,
            PLANNER_OBSERVATION_UNAVAILABLE,
            SUPPORT_MARGIN_MEASURED,
            -0.01,
            zeros,
        ),
        DiagnosticSemanticsInput(
            ACTIVE_CONTROL,
            PLANNER_OBSERVATION_UNAVAILABLE,
            SUPPORT_MARGIN_UNAVAILABLE,
            None,
            zeros,
        ),
        DiagnosticSemanticsInput(
            ACTIVE_CONTROL,
            PLANNER_INFEASIBLE,
            SUPPORT_MARGIN_MEASURED,
            0.0,
            zeros,
        ),
        DiagnosticSemanticsInput(
            PASSIVE_OBSERVATION,
            None,
            SUPPORT_MARGIN_MEASURED,
            0.02,
            zeros,
        ),
        DiagnosticSemanticsInput(
            PASSIVE_OBSERVATION,
            None,
            SUPPORT_MARGIN_UNAVAILABLE,
            None,
            zeros,
        ),
    )

