"""Pure signed-work classification before portable recovery-energy projection."""

from __future__ import annotations

from collections import OrderedDict
from copy import deepcopy
from dataclasses import dataclass
import inspect
import json
import math
from typing import Any, Mapping, Sequence


PROFILE_ID = "mujoco_signed_work_portable_v1_preprojection_v1"
RECEIPT_SCHEMA = "sporespore_mujoco_energy_work_preprojection_receipt_v1"
SUMMARY_SCHEMA = "sporespore_mujoco_energy_work_preprojection_summary_v1"
PORTABLE_LEDGER_SCHEMA = "sporespore_recovery_energy_balance_ledger_v1"
SIGNED_CONSTRAINT_REFUSAL = "portable_v1_signed_constraint_work_unrepresentable"
PASSIVE_WORK_REFUSAL = "nonzero_unqualified_passive_work"


class EnergyWorkProjectionError(ValueError):
    """Stable fail-closed error for malformed or mutated projection evidence."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise EnergyWorkProjectionError(code)


def _finite(value: float, code: str) -> float:
    _require(not isinstance(value, bool), code)
    try:
        result = float(value)
    except (TypeError, ValueError) as error:
        raise EnergyWorkProjectionError(code) from error
    _require(math.isfinite(result), code)
    return result


@dataclass(frozen=True)
class EnergyWorkPreprojectionV1:
    """One exact classification that never rewrites a signed native term."""

    constraint_work_j: float
    damper_work_j: float
    fluid_work_j: float
    adhesion_work_j: float
    qualified_passive_dissipation_j: float | None
    support_status: str
    refusal_reason: str | None

    def receipt_v1(self) -> dict[str, Any]:
        supported = self.support_status == "supported_exact"
        return {
            "schema_version": RECEIPT_SCHEMA,
            "projection_profile_id": PROFILE_ID,
            "source_terms": {
                "signed_constraint_work_j": self.constraint_work_j,
                "signed_damper_work_j": self.damper_work_j,
                "signed_fluid_work_j": self.fluid_work_j,
                "signed_adhesion_work_j": self.adhesion_work_j,
            },
            "component_semantics": {
                "constraint": "signed_constraint_exchange_never_dissipation",
                "damper": "exact_zero_only_in_current_qualified_subset",
                "fluid": "exact_zero_only_in_current_qualified_subset",
                "adhesion": "exact_zero_only_in_current_qualified_subset",
            },
            "qualified_passive_dissipation_j": (
                self.qualified_passive_dissipation_j
            ),
            "portable_v1_projection": {
                "energy_balance_schema": PORTABLE_LEDGER_SCHEMA,
                "support_status": self.support_status,
                "refusal_reason": self.refusal_reason,
                "external_work_increment_j": 0.0 if supported else None,
                "dissipated_energy_increment_j": 0.0 if supported else None,
            },
            "source_values_retained_exactly": True,
            "mechanical_energy_change_used_as_input": False,
            "energy_balance_residual_used_as_input": False,
            "absolute_value_applied": False,
            "negative_value_clamped": False,
            "historical_result_relabelled": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }


def classify_energy_work_for_portable_v1(
    *,
    constraint_work_j: float,
    damper_work_j: float,
    fluid_work_j: float,
    adhesion_work_j: float,
) -> EnergyWorkPreprojectionV1:
    """Classify representability under the unchanged portable v1 ledger.

    R24D33 qualifies nonzero constraint work but requires the other three
    native force channels to be exactly zero. Constraint work remains signed;
    portable v1 has no signed constraint channel. Consequently only the exact
    all-zero non-actuator tuple can be projected without changing semantics.
    Every other finite tuple returns a typed refusal while retaining its signs.
    """

    constraint = _finite(constraint_work_j, "QSDK_R24D36_CONSTRAINT_WORK_INVALID")
    damper = _finite(damper_work_j, "QSDK_R24D36_DAMPER_WORK_INVALID")
    fluid = _finite(fluid_work_j, "QSDK_R24D36_FLUID_WORK_INVALID")
    adhesion = _finite(adhesion_work_j, "QSDK_R24D36_ADHESION_WORK_INVALID")
    passive_is_qualified = damper == fluid == adhesion == 0.0
    if not passive_is_qualified:
        status = "unsupported_capability"
        reason = PASSIVE_WORK_REFUSAL
        passive_dissipation = None
    elif constraint != 0.0:
        status = "unsupported_capability"
        reason = SIGNED_CONSTRAINT_REFUSAL
        passive_dissipation = 0.0
    else:
        status = "supported_exact"
        reason = None
        passive_dissipation = 0.0
    return EnergyWorkPreprojectionV1(
        constraint_work_j=constraint,
        damper_work_j=damper,
        fluid_work_j=fluid,
        adhesion_work_j=adhesion,
        qualified_passive_dissipation_j=passive_dissipation,
        support_status=status,
        refusal_reason=reason,
    )


def validate_energy_work_preprojection_receipt_v1(
    receipt: Mapping[str, Any],
) -> EnergyWorkPreprojectionV1:
    """Replay one receipt and reject every semantic or value mutation."""

    _require(isinstance(receipt, Mapping), "QSDK_R24D36_RECEIPT_INVALID")
    terms = receipt.get("source_terms")
    _require(isinstance(terms, Mapping), "QSDK_R24D36_SOURCE_TERMS_INVALID")
    replayed = classify_energy_work_for_portable_v1(
        constraint_work_j=terms.get("signed_constraint_work_j"),
        damper_work_j=terms.get("signed_damper_work_j"),
        fluid_work_j=terms.get("signed_fluid_work_j"),
        adhesion_work_j=terms.get("signed_adhesion_work_j"),
    )
    _require(
        dict(receipt) == replayed.receipt_v1(),
        "QSDK_R24D36_PREPROJECTION_RECEIPT_MUTATED",
    )
    return replayed


def summarize_energy_work_preprojections_v1(
    receipts: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    """Retain ordered substep decisions and exact signed aggregate terms."""

    _require(bool(receipts), "QSDK_R24D36_RECEIPT_SERIES_EMPTY")
    replayed = [
        validate_energy_work_preprojection_receipt_v1(item) for item in receipts
    ]
    refused = [
        {
            "index": index,
            "reason": item.refusal_reason,
        }
        for index, item in enumerate(replayed)
        if item.support_status != "supported_exact"
    ]
    return {
        "schema_version": SUMMARY_SCHEMA,
        "projection_profile_id": PROFILE_ID,
        "receipt_count": len(replayed),
        "source_term_sums": {
            "signed_constraint_work_j": math.fsum(
                item.constraint_work_j for item in replayed
            ),
            "signed_damper_work_j": math.fsum(item.damper_work_j for item in replayed),
            "signed_fluid_work_j": math.fsum(item.fluid_work_j for item in replayed),
            "signed_adhesion_work_j": math.fsum(
                item.adhesion_work_j for item in replayed
            ),
        },
        "support_status": "supported_exact" if not refused else "unsupported_capability",
        "refused_substeps": refused,
        "portable_v1_dissipated_energy_increment_j": 0.0 if not refused else None,
        "source_values_retained_exactly": True,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def energy_work_projection_zero_world_controls_v1(
) -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    """Exercise exact support, refusal, replay, and forbidden-input controls."""

    zero = classify_energy_work_for_portable_v1(
        constraint_work_j=0.0,
        damper_work_j=0.0,
        fluid_work_j=0.0,
        adhesion_work_j=0.0,
    )
    positive = classify_energy_work_for_portable_v1(
        constraint_work_j=0.25,
        damper_work_j=0.0,
        fluid_work_j=0.0,
        adhesion_work_j=0.0,
    )
    negative = classify_energy_work_for_portable_v1(
        constraint_work_j=-0.5,
        damper_work_j=0.0,
        fluid_work_j=0.0,
        adhesion_work_j=0.0,
    )
    passive = [
        classify_energy_work_for_portable_v1(
            constraint_work_j=0.0,
            damper_work_j=value if channel == "damper" else 0.0,
            fluid_work_j=value if channel == "fluid" else 0.0,
            adhesion_work_j=value if channel == "adhesion" else 0.0,
        )
        for channel in ("damper", "fluid", "adhesion")
        for value in (-0.25, 0.25)
    ]
    summary = summarize_energy_work_preprojections_v1(
        [zero.receipt_v1(), positive.receipt_v1(), negative.receipt_v1()]
    )
    mutated = deepcopy(zero.receipt_v1())
    mutated["portable_v1_projection"]["dissipated_energy_increment_j"] = 1.0
    mutation_refused = False
    try:
        validate_energy_work_preprojection_receipt_v1(mutated)
    except EnergyWorkProjectionError as error:
        mutation_refused = str(error) == "QSDK_R24D36_PREPROJECTION_RECEIPT_MUTATED"
    nonfinite_refused = True
    for value in (math.nan, math.inf, -math.inf):
        try:
            classify_energy_work_for_portable_v1(
                constraint_work_j=value,
                damper_work_j=0.0,
                fluid_work_j=0.0,
                adhesion_work_j=0.0,
            )
            nonfinite_refused = False
        except EnergyWorkProjectionError:
            pass
    signature = set(inspect.signature(classify_energy_work_for_portable_v1).parameters)
    serialized = json.dumps(
        [zero.receipt_v1(), positive.receipt_v1(), negative.receipt_v1(), summary],
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    controls: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "exact_zero_nonactuator_tuple_projects_to_zero_nonnegative_dissipation",
                zero.support_status == "supported_exact"
                and zero.qualified_passive_dissipation_j == 0.0,
            ),
            (
                "positive_and_negative_constraint_work_retain_sign_and_refuse_portable_v1",
                positive.constraint_work_j == 0.25
                and negative.constraint_work_j == -0.5
                and positive.refusal_reason == negative.refusal_reason
                == SIGNED_CONSTRAINT_REFUSAL,
            ),
            (
                "nonzero_unqualified_passive_terms_refuse_without_sign_transformation",
                all(
                    item.refusal_reason == PASSIVE_WORK_REFUSAL
                    and item.qualified_passive_dissipation_j is None
                    for item in passive
                ),
            ),
            (
                "ordered_receipt_summary_preserves_signed_terms_and_refusal_indices",
                summary["receipt_count"] == 3
                and summary["source_term_sums"]["signed_constraint_work_j"] == -0.25
                and [item["index"] for item in summary["refused_substeps"]] == [1, 2],
            ),
            (
                "receipt_mutation_and_nonfinite_input_fail_closed",
                mutation_refused and nonfinite_refused,
            ),
            (
                "mechanical_energy_residual_clamp_and_absolute_value_are_absent",
                "mechanical_energy_change_j" not in signature
                and "energy_balance_residual_j" not in signature
                and all(
                    item.receipt_v1()["absolute_value_applied"] is False
                    and item.receipt_v1()["negative_value_clamped"] is False
                    for item in (zero, positive, negative, *passive)
                ),
            ),
        ]
    )
    return controls, {
        "projection_profile_id": PROFILE_ID,
        "portable_ledger_schema": PORTABLE_LEDGER_SCHEMA,
        "serialized_fixture_byte_length": len(serialized.encode("utf-8")),
        "signed_constraint_fixture_sum_j": summary["source_term_sums"][
            "signed_constraint_work_j"
        ],
        "primitive_control_count": len(controls),
    }
