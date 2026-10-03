"""QSDK-R24D38 native-receipt to portable-observation V2 controls."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from typing import Any, Callable, Sequence

from sporespore_locomotion import LocomotionCore

from adapters.mujoco.sporespore_mujoco_adapter import energy_work_projection
from adapters.mujoco.sporespore_mujoco_adapter.recovery_energy_v2_mapping import (
    MAPPING_PROFILE_ID,
    PORTABLE_OBSERVATION_V2_SCHEMA,
    RecoveryEnergyV2MappingError,
    map_r24d36_components_to_recovery_observation_v2,
)
from adapters.mujoco.sporespore_mujoco_adapter.recovery_energy_v2_mapping_fixture import (
    synthetic_r24d38_mapping_request_v1,
)


GATE_ID = "QSDK-R24D38"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d38_native_energy_v2_mapping_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d38_native_energy_v2_mapping_preflight_v1"
R24D37_SOURCE = "f6063a33097b6c0a6f83b3d43313daf7f06a93aa"
R24D37_CLOSURE_SHA256 = (
    "sha256:c762c9a29bf5f6b67f4f1add386d217745ad8cfc9e87c2e0d4b1401c97f7bacb"
)
R24D37_CLOSURE_AUDIT_SHA256 = (
    "sha256:b9a4fd2f888ad03cf0b59701b007e4bbab701fce5b1d6690bede89c346f3fb8e"
)
REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d38_native_energy_v2_mapping_contract_v1.json"
)
R24D37_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d37_engine_neutral_signed_exchange_ledger_qualification_closure_v1.json"
)
R24D37_CLOSURE_AUDIT_PATH = (
    REPO_ROOT
    / "tests/test_qsdk_r24d37_engine_neutral_signed_exchange_ledger_qualification_closure.py"
)


class R24D38PreflightError(RuntimeError):
    """Stable zero-world control failure."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D38PreflightError(code)


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


def _fails_closed(operation: Callable[[], object], expected: str) -> bool:
    try:
        operation()
    except RecoveryEnergyV2MappingError as error:
        return expected in str(error)
    return False


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    contract = load_contract_v1()
    closure37 = _load(R24D37_CLOSURE_PATH)
    request = synthetic_r24d38_mapping_request_v1()
    supported = map_r24d36_components_to_recovery_observation_v2(core, request)
    increments = supported["ordered_increments"]
    aggregate = supported["ledger_aggregation_receipt"]
    ledger = aggregate["ledger"]
    observation = supported["portable_observation"]

    cumulative_actuator = 0.0
    cumulative_constraint = 0.0
    for increment in increments:
        cumulative_actuator += increment["applied_actuator_work_j"]
        cumulative_constraint += increment["signed_constraint_exchange_j"]

    source_preprojections = [
        substep["portable_v3_energy_preprojection"]
        for batch in request["ordered_native_component_batches"]
        for substep in batch["ordered_substep_receipts"]
    ]
    passive = map_r24d36_components_to_recovery_observation_v2(
        core,
        synthetic_r24d38_mapping_request_v1(centered_damper_force=1.0),
    )
    external = map_r24d36_components_to_recovery_observation_v2(
        core,
        synthetic_r24d38_mapping_request_v1(external_intervention_count=1),
    )

    mutated_value = synthetic_r24d38_mapping_request_v1()
    mutated_value["ordered_native_component_batches"][0]["ordered_substep_receipts"][0][
        "implicit_v3"
    ]["centered_constraint_work_j"] += 0.125
    mutated_projection = synthetic_r24d38_mapping_request_v1()
    mutated_projection["ordered_native_component_batches"][0][
        "ordered_substep_receipts"
    ][0]["portable_v3_energy_preprojection"]["source_values_retained_exactly"] = False
    reordered = synthetic_r24d38_mapping_request_v1()
    reordered["ordered_native_component_batches"][1]["semantic_step"] = 15
    incomplete = synthetic_r24d38_mapping_request_v1()
    del incomplete["ordered_native_component_batches"][0]["ordered_substep_receipts"][
        0
    ]["implicit_v3"]
    unknown = synthetic_r24d38_mapping_request_v1()
    unknown["unknown"] = True
    forced_failures = (
        _fails_closed(
            lambda: map_r24d36_components_to_recovery_observation_v2(
                core, mutated_value
            ),
            "IMPLICIT_COMPONENT_REPLAY_MISMATCH",
        ),
        _fails_closed(
            lambda: map_r24d36_components_to_recovery_observation_v2(
                core, mutated_projection
            ),
            "R24D36_PREPROJECTION_REPLAY_FAILED",
        ),
        _fails_closed(
            lambda: map_r24d36_components_to_recovery_observation_v2(core, reordered),
            "COMPONENT_BATCH_ORDER_INVALID",
        ),
        _fails_closed(
            lambda: map_r24d36_components_to_recovery_observation_v2(core, incomplete),
            "SUBSTEP_FIELDS_INVALID",
        ),
        _fails_closed(
            lambda: map_r24d36_components_to_recovery_observation_v2(core, unknown),
            "MAPPING_REQUEST_FIELDS_INVALID",
        ),
    )

    changed_base_request = deepcopy(request)
    changed_base_request["observation_base"]["state"][
        "zero_world_fixture"
    ] = "content_changed"
    changed_base = map_r24d36_components_to_recovery_observation_v2(
        core,
        changed_base_request,
    )

    controls = {
        "r24d37_closure_is_exact_consumed_and_selects_r24d38": (
            _sha256(R24D37_CLOSURE_PATH) == R24D37_CLOSURE_SHA256
            and _sha256(R24D37_CLOSURE_AUDIT_PATH) == R24D37_CLOSURE_AUDIT_SHA256
            and closure37["source"]["commit"] == R24D37_SOURCE
            and closure37["next_boundary"]["gate_id"] == GATE_ID
            and closure37["next_boundary"]["r24d37_may_be_requalified"] is False
        ),
        "complete_r24d36_receipts_replay_into_contiguous_ledger_v2_increments": (
            supported["support_status"] == "supported_exact"
            and supported["native_component_batch_count"] == 2
            and supported["native_component_receipt_count"] == 10
            and [item["sequence_index"] for item in increments] == list(range(10))
            and [item["semantic_step"] for item in increments]
            == ([12] * 5) + ([13] * 5)
            and aggregate["ordered_source_values_sha256"]
            == ledger["source_values_sha256"]
        ),
        "both_constraint_signs_cross_the_v1_refusal_seam_without_relabelling": (
            all(
                item["portable_v1_projection"]["support_status"]
                == "unsupported_capability"
                and item["portable_v1_projection"]["refusal_reason"]
                == energy_work_projection.SIGNED_CONSTRAINT_REFUSAL
                for item in source_preprojections
            )
            and any(item["signed_constraint_exchange_j"] > 0.0 for item in increments)
            and any(item["signed_constraint_exchange_j"] < 0.0 for item in increments)
            and ledger["cumulative_signed_constraint_exchange_j"]
            == cumulative_constraint
        ),
        "actuator_constraint_external_and_passive_partition_is_exact": (
            ledger["source_profile_id"] == MAPPING_PROFILE_ID
            and ledger["cumulative_applied_actuator_work_j"] == cumulative_actuator
            and ledger["cumulative_signed_external_work_j"] == 0.0
            and ledger["cumulative_passive_dissipation_j"] == 0.0
            and supported["component_partition"][
                "mechanical_energy_change_used_as_work_source"
            ]
            is False
            and supported["component_partition"][
                "energy_balance_residual_used_as_work_source"
            ]
            is False
        ),
        "portable_observation_v2_is_flat_content_addressed_and_v1_is_unchanged": (
            observation["schema_version"] == PORTABLE_OBSERVATION_V2_SCHEMA
            and observation["energy_balance"] == ledger
            and "legacy_observation" not in observation
            and supported["portable_observation_sha256"]
            == core.canonicalize_json(observation)["sha256"]
            and changed_base["source_component_receipts_sha256"]
            == supported["source_component_receipts_sha256"]
            and changed_base["ledger_sha256"] == supported["ledger_sha256"]
            and changed_base["observation_base_sha256"]
            != supported["observation_base_sha256"]
            and changed_base["portable_observation_sha256"]
            != supported["portable_observation_sha256"]
        ),
        "unqualified_passive_and_unmeasured_external_work_are_typed_refusals": (
            passive["support_status"] == "unsupported_capability"
            and passive["refusal_reason"] == energy_work_projection.PASSIVE_WORK_REFUSAL
            and passive["portable_observation"] is None
            and external["support_status"] == "unsupported_capability"
            and external["refusal_reason"]
            == "nonzero_external_intervention_work_unmeasured"
            and external["ledger_aggregation_receipt"] is None
        ),
        "value_projection_order_shape_and_unknown_field_mutations_fail_closed": all(
            forced_failures
        ),
        "mapping_receipts_are_threshold_free_zero_world_and_nonrelease": all(
            item["threshold_applied"] is False
            and item["physical_result"] is False
            and item["native_engine_execution_executed"] is False
            and item["model_construction_count"] == 0
            and item["world_attempt_count"] == 0
            and item["world_build_count"] == 0
            and item["solver_step_count"] == 0
            and item["physics_state_modified"] is False
            and item["physical_acceptance_authority"] is False
            and item["release_authority"] is False
            for item in (supported, passive, external)
        ),
        "contract_keeps_evaluator_physics_held_out_and_scores_unchanged": (
            contract["complete_zero_world_gate"]["required_control_count"] == 9
            and contract["portable_observation_v2"][
                "accepted_by_current_recovery_evaluator"
            ]
            is False
            and contract["qualification_authority"]["maximum_physical_steps_authorized"]
            == 0
            and contract["held_out_seal"]["held_out_cell_access_count"] == 0
            and contract["claim_boundary"]["sdk1_release_readiness"] == "11/20"
            and contract["claim_boundary"]["full_program_readiness"] == "11/25"
        ),
    }
    _require(len(controls) == 9 and all(controls.values()), "R24D38_CONTROL_FAILED")
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "gate_id": GATE_ID,
        "ok": True,
        "runtime_id": "sporespore_engine_neutral_locomotion_core",
        "runtime_version": core.version,
        "control_count": len(controls),
        "controls_passed": sum(controls.values()),
        "controls": controls,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "source_component_receipts_sha256": supported[
            "source_component_receipts_sha256"
        ],
        "ordered_source_values_sha256": supported["ordered_source_values_sha256"],
        "ledger_sha256": supported["ledger_sha256"],
        "portable_observation_sha256": supported["portable_observation_sha256"],
        "native_component_batch_count": 2,
        "native_component_receipt_count": 10,
        "forced_failure_count": len(forced_failures),
        "typed_refusal_count": 2,
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
