"""QSDK-R24D37 engine-neutral recovery-energy zero-world controls."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from typing import Any, Callable, Sequence

from sporespore_locomotion import LocomotionCore, LocomotionCoreError


GATE_ID = "QSDK-R24D37"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_preflight_v1"
)
LEDGER_V2 = "sporespore_recovery_energy_balance_ledger_v2"
EQUATION_V2 = (
    "current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2"
)
PARTITION_V2 = (
    "sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2"
)
R24D36_SOURCE = "7d1e357c8458d503985cafd31cfa6c0797bf350d"
R24D36_CLOSURE_SHA256 = (
    "sha256:b47b32f8dd2520492a97d26157d76a7a17d51bd0a1f87bf367088b94f3ce3eba"
)
REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d37_engine_neutral_signed_exchange_ledger_contract_v1.json"
)
R24D36_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d36_signed_work_preprojection_qualification_closure_v1.json"
)


class R24D37PreflightError(RuntimeError):
    """Stable zero-world control failure."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D37PreflightError(code)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def _sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = _load(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is False, "PHYSICAL_QUESTION")
    _require(contract.get("behavior_question_declared") is False, "BEHAVIOR_QUESTION")
    inventory = contract["source_inventory"]
    _require(
        len(inventory)
        == len(set(inventory))
        == contract["source_inventory_strategy"]["source_inventory_count"],
        "SOURCE_INVENTORY",
    )
    return contract


def _aggregation_request() -> dict[str, Any]:
    return {
        "schema_version": (
            "sporespore_recovery_energy_balance_aggregation_request_v2"
        ),
        "source_profile_id": "r24d37_zero_world_signed_exchange_fixture_v1",
        "initial_mechanical_energy_j": 10.0,
        "current_mechanical_energy_j": 11.5,
        "ordered_increments": [
            {
                "sequence_index": 0,
                "semantic_step": 12,
                "applied_actuator_work_j": 4.0,
                "signed_external_work_j": 1.0,
                "signed_constraint_exchange_j": 2.0,
                "passive_dissipation_j": 0.5,
                "source_measurement": True,
            },
            {
                "sequence_index": 1,
                "semantic_step": 12,
                "applied_actuator_work_j": -0.5,
                "signed_external_work_j": -0.25,
                "signed_constraint_exchange_j": -3.0,
                "passive_dissipation_j": 1.25,
                "source_measurement": True,
            },
            {
                "sequence_index": 2,
                "semantic_step": 13,
                "applied_actuator_work_j": 0.0,
                "signed_external_work_j": 0.0,
                "signed_constraint_exchange_j": 0.0,
                "passive_dissipation_j": 0.0,
                "source_measurement": True,
            },
        ],
    }


def _fails_closed(operation: Callable[[], object], failure_code: str) -> bool:
    try:
        operation()
    except LocomotionCoreError as error:
        return error.failure_code == failure_code
    return False


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    contract = load_contract_v1()
    closure36 = _load(R24D36_CLOSURE_PATH)
    aggregate = core.recovery_energy_balance_aggregate_v2(_aggregation_request())
    ledger = aggregate["ledger"]
    evaluation = core.recovery_energy_balance_evaluate_v2(
        {
            "schema_version": (
                "sporespore_recovery_energy_balance_evaluation_request_v2"
            ),
            "ledger": ledger,
        }
    )

    mutated_request = _aggregation_request()
    mutated_request["ordered_increments"][1]["signed_constraint_exchange_j"] = -2.5
    mutated = core.recovery_energy_balance_aggregate_v2(mutated_request)

    v1 = {
        "initial_mechanical_energy_j": 10.0,
        "current_mechanical_energy_j": 11.0,
        "cumulative_applied_actuator_work_j": 2.0,
        "cumulative_external_work_j": 0.0,
        "cumulative_dissipated_energy_j": 1.0,
        "source_measurement": True,
    }
    upgrade = core.recovery_energy_balance_migrate_v1(
        {
            "schema_version": (
                "sporespore_recovery_energy_balance_migration_request_v1"
            ),
            "direction": "v1_to_v2",
            "source_v1": v1,
            "source_v2": None,
        }
    )
    downgrade = core.recovery_energy_balance_migrate_v1(
        {
            "schema_version": (
                "sporespore_recovery_energy_balance_migration_request_v1"
            ),
            "direction": "v2_to_v1",
            "source_v1": None,
            "source_v2": upgrade["target_v2"],
        }
    )

    constraint_refusals: list[dict[str, Any]] = []
    for value in (-0.5, 0.5):
        source = deepcopy(upgrade["target_v2"])
        source["cumulative_signed_constraint_exchange_j"] = value
        constraint_refusals.append(
            core.recovery_energy_balance_migrate_v1(
                {
                    "schema_version": (
                        "sporespore_recovery_energy_balance_migration_request_v1"
                    ),
                    "direction": "v2_to_v1",
                    "source_v1": None,
                    "source_v2": source,
                }
            )
        )
    external = deepcopy(upgrade["target_v2"])
    external["cumulative_signed_external_work_j"] = -0.25
    external_refusal = core.recovery_energy_balance_migrate_v1(
        {
            "schema_version": (
                "sporespore_recovery_energy_balance_migration_request_v1"
            ),
            "direction": "v2_to_v1",
            "source_v1": None,
            "source_v2": external,
        }
    )

    invalid_cases: list[bool] = []
    unknown = _aggregation_request()
    unknown["unknown"] = True
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_aggregate_v2(unknown),
            "SCHEMA_INVALID",
        )
    )
    negative = _aggregation_request()
    negative["ordered_increments"][0]["passive_dissipation_j"] = -0.25
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_aggregate_v2(negative),
            "SCHEMA_INVALID",
        )
    )
    reordered = _aggregation_request()
    reordered["ordered_increments"][1]["sequence_index"] = 3
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_aggregate_v2(reordered),
            "ORDER_INVALID",
        )
    )
    unmeasured = _aggregation_request()
    unmeasured["ordered_increments"][0]["source_measurement"] = False
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_aggregate_v2(unmeasured),
            "SCHEMA_INVALID",
        )
    )
    wrong_partition = deepcopy(ledger)
    wrong_partition["component_partition_id"] = "mutated_partition"
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_evaluate_v2(
                {
                    "schema_version": (
                        "sporespore_recovery_energy_balance_evaluation_request_v2"
                    ),
                    "ledger": wrong_partition,
                }
            ),
            "IDENTITY_INVALID",
        )
    )
    overflowing = _aggregation_request()
    overflowing["ordered_increments"][0]["applied_actuator_work_j"] = 1.0e308
    overflowing["ordered_increments"][1]["applied_actuator_work_j"] = 1.0e308
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_aggregate_v2(overflowing),
            "NONFINITE_VALUE",
        )
    )
    inexact_identity = _aggregation_request()
    inexact_identity["ordered_increments"][0]["sequence_index"] = 9_007_199_254_740_992
    invalid_cases.append(
        _fails_closed(
            lambda: core.recovery_energy_balance_aggregate_v2(inexact_identity),
            "SCHEMA_INVALID",
        )
    )

    controls = {
        "r24d36_closure_is_exact_consumed_and_selects_r24d37": (
            _sha256(R24D36_CLOSURE_PATH) == R24D36_CLOSURE_SHA256
            and closure36["source"]["commit"] == R24D36_SOURCE
            and closure36["next_boundary"]["gate_id"] == GATE_ID
            and closure36["next_boundary"]["r24d36_may_be_requalified"] is False
        ),
        "ordered_aggregation_preserves_disjoint_signed_and_passive_channels": (
            aggregate["increment_count"] == 3
            and aggregate["first_sequence_index"] == 0
            and aggregate["last_sequence_index"] == 2
            and aggregate["first_semantic_step"] == 12
            and aggregate["last_semantic_step"] == 13
            and ledger["schema_version"] == LEDGER_V2
            and ledger["equation_id"] == EQUATION_V2
            and ledger["component_partition_id"] == PARTITION_V2
            and ledger["cumulative_applied_actuator_work_j"] == 3.5
            and ledger["cumulative_signed_external_work_j"] == 0.75
            and ledger["cumulative_signed_constraint_exchange_j"] == -1.0
            and ledger["cumulative_passive_dissipation_j"] == 1.75
        ),
        "repeated_semantic_steps_and_ordered_source_digest_are_exact": (
            aggregate["ordered_source_values_sha256"]
            == ledger["source_values_sha256"]
            and aggregate["ledger_sha256"] == evaluation["ledger_sha256"]
            and mutated["ordered_source_values_sha256"]
            != aggregate["ordered_source_values_sha256"]
            and mutated["ledger_sha256"] != aggregate["ledger_sha256"]
        ),
        "v2_evaluator_uses_declared_signed_algebra_without_threshold": (
            evaluation["equation_id"] == EQUATION_V2
            and evaluation["signed_residual_j"] == 0.0
            and evaluation["absolute_residual_j"] == 0.0
            and evaluation["threshold_applied"] is False
            and evaluation["physical_result"] is False
        ),
        "invalid_schema_order_measurement_dissipation_and_partition_fail_closed": all(
            invalid_cases
        ),
        "v1_upgrade_and_zero_exchange_downgrade_are_explicit_and_lossless": (
            upgrade["support_status"] == "supported_exact"
            and upgrade["target_v2"]["cumulative_signed_external_work_j"] == 0.0
            and upgrade["target_v2"]["cumulative_signed_constraint_exchange_j"]
            == 0.0
            and upgrade["target_v2"]["cumulative_passive_dissipation_j"] == 1.0
            and downgrade["support_status"] == "supported_exact"
            and downgrade["target_v1"] == v1
            and upgrade["implicit_migration_used"] is False
            and downgrade["implicit_migration_used"] is False
        ),
        "lossy_v1_downgrades_are_typed_refusals_for_both_constraint_signs_and_external_work": (
            all(
                item["support_status"] == "unsupported_capability"
                and item["refusal_reason"]
                == "portable_v1_signed_constraint_work_unrepresentable"
                and item["target_v1"] is None
                for item in constraint_refusals
            )
            and external_refusal["support_status"] == "unsupported_capability"
            and external_refusal["refusal_reason"]
            == "portable_v1_nonzero_external_work_unrepresentable"
            and external_refusal["target_v1"] is None
        ),
        "public_receipts_are_zero_world_nonphysical_and_nonrelease": all(
            item["model_construction_count"] == 0
            and item["world_attempt_count"] == 0
            and item["world_build_count"] == 0
            and item["solver_step_count"] == 0
            and item["physics_state_modified"] is False
            and item["physical_acceptance_authority"] is False
            and item["release_authority"] is False
            for item in (aggregate, evaluation, upgrade, downgrade, *constraint_refusals)
        ),
        "contract_keeps_physics_thresholds_held_out_and_scores_unchanged": (
            contract["complete_zero_world_gate"]["required_control_count"] == 9
            and contract["qualification_authority"]["maximum_physical_steps_authorized"]
            == 0
            and contract["threshold_margin_and_population_authority"][
                "new_behavior_threshold_count"
            ]
            == 0
            and contract["held_out_seal"]["held_out_cell_access_count"] == 0
            and contract["claim_boundary"]["sdk1_release_readiness"] == "11/20"
            and contract["claim_boundary"]["full_program_readiness"] == "11/25"
        ),
    }
    _require(len(controls) == 9 and all(controls.values()), "R24D37_CONTROL_FAILED")
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "gate_id": GATE_ID,
        "ok": True,
        "runtime_id": "sporespore_engine_neutral_locomotion_core",
        "runtime_version": core.version,
        "control_count": len(controls),
        "controls_passed": sum(controls.values()),
        "controls": controls,
        "ledger_sha256": aggregate["ledger_sha256"],
        "ordered_source_values_sha256": aggregate["ordered_source_values_sha256"],
        "positive_and_negative_constraint_refusal_count": len(constraint_refusals),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "behavior_question_opened": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    receipt = run_zero_world_preflight(LocomotionCore(arguments.core_library.resolve()))
    print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
