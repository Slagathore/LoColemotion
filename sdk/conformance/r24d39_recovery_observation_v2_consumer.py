"""Compact QSDK-R24D39 observation-V2 consumer controls."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from typing import Any, Callable, Sequence

from sporespore_locomotion import LocomotionCore

from adapters.mujoco.sporespore_mujoco_adapter.recovery_observation_v2_route import (
    publish_recovery_observation_v2,
)
from adapters.mujoco.sporespore_mujoco_adapter.recovery_observation_v2_route_fixture import (
    synthetic_r24d39_evaluation_request_v3,
    synthetic_r24d39_initialize_request_v2,
    synthetic_r24d39_publication_arguments_v1,
    synthetic_r24d39_step_request_v3,
)
from adapters.mujoco.sporespore_mujoco_adapter.recovery_runtime import (
    plan_control_v3,
)


GATE_ID = "QSDK-R24D39"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_contract_v1"
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_preflight_v1"
)
R24D38_SOURCE = "5ff284ae77486be4007698add327445ffa1a5cc0"
R24D38_CLOSURE_SHA256 = (
    "sha256:59cbf3618ec30d4bf11fc42438c5504feb8ed784028833fef3a19e6844f67379"
)
R24D38_CLOSURE_AUDIT_SHA256 = (
    "sha256:0f9c9f0c6fede64f0817e4dd70a0ebc50de9327abdd82948ad90d332872eaa08"
)
REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d39_recovery_observation_v2_consumer_contract_v1.json"
)
R24D38_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d38_native_energy_v2_mapping_qualification_closure_v1.json"
)
R24D38_CLOSURE_AUDIT_PATH = (
    REPO_ROOT
    / "tests/test_qsdk_r24d38_native_energy_v2_mapping_qualification_closure.py"
)
ABI_MANIFEST_PATH = REPO_ROOT / "sdk/versioning/c_abi_manifest_v1.json"
SCHEMA_REGISTRY_PATH = REPO_ROOT / "sdk/versioning/schema_registry_v1.json"
HEADER_PATH = REPO_ROOT / "sdk/include/sporespore_locomotion.h"
NATIVE_ROUTE_PATH = (
    REPO_ROOT
    / "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)


class R24D39PreflightError(RuntimeError):
    """Stable zero-world control failure."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D39PreflightError(code)


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


def _raises(operation: Callable[[], object]) -> bool:
    try:
        operation()
    except Exception:
        return True
    return False


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    contract = load_contract_v1()
    closure38 = _load(R24D38_CLOSURE_PATH)
    publication = publish_recovery_observation_v2(
        core,
        **synthetic_r24d39_publication_arguments_v1(core),
    )
    collection_request = publication["collection_request"]
    collection = publication["collection_receipt"]
    observation = publication["portable_observation"]

    initialized = core.recovery_initialize_v2(
        synthetic_r24d39_initialize_request_v2(publication)
    )
    step_request = synthetic_r24d39_step_request_v3(
        publication,
        memory=initialized["memory"],
    )
    step = core.recovery_step_v3(step_request)
    residual_request = deepcopy(step_request)
    residual_request["observation"]["energy_balance"][
        "cumulative_signed_constraint_exchange_j"
    ] += 1.0
    residual_step = core.recovery_step_v3(residual_request)
    control = plan_control_v3(core, collection_request, phase_step=0)
    evaluation = core.recovery_evaluate_trace_v3(
        synthetic_r24d39_evaluation_request_v3(core, publication)
    )

    binding_fields = (
        "mapping_receipt_sha256",
        "source_component_receipts_sha256",
        "observation_base_sha256",
        "ledger_sha256",
        "portable_observation_sha256",
        "source_chain_sha256",
    )
    binding_refusals = []
    for field in binding_fields:
        request = deepcopy(collection_request)
        request["observation_source_binding"][field] = "sha256:" + ("f" * 64)
        refusal = core.recovery_collect_native_v3(request)
        binding_refusals.append(
            refusal["support_status"] == "invalid_observation"
            and refusal["refusal_reason"] == "observation_v2_source_binding_mismatch"
            and refusal["solver_step_count"] == 0
        )

    wrong_schema = deepcopy(collection_request)
    wrong_schema["schema_version"] = "sporespore_recovery_native_collection_request_v2"
    legacy = deepcopy(wrong_schema)
    del legacy["observation_source_binding"]
    unsupported = deepcopy(collection_request)
    unsupported["adapter_capability"]["engine"] = "rapier_parry_native"
    unsupported_receipt = core.recovery_collect_native_v3(unsupported)

    manifest = _load(ABI_MANIFEST_PATH)
    registry = _load(SCHEMA_REGISTRY_PATH)
    header = HEADER_PATH.read_text(encoding="utf-8")
    native_source = NATIVE_ROUTE_PATH.read_text(encoding="utf-8")
    symbols = [item["name"] for item in manifest["symbols"]]
    schema_by_id = {item["schema_id"]: item for item in registry["schemas"]}
    v3_symbols = contract["public_surface"]["new_c_abi_symbols"]

    zero_world_values = (
        publication,
        collection,
        initialized,
        step,
        residual_step,
        control,
        evaluation,
        unsupported_receipt,
    )
    controls = {
        "r24d38_closure_is_exact_consumed_and_selects_r24d39": (
            _sha256(R24D38_CLOSURE_PATH) == R24D38_CLOSURE_SHA256
            and _sha256(R24D38_CLOSURE_AUDIT_PATH) == R24D38_CLOSURE_AUDIT_SHA256
            and closure38["source"]["commit"] == R24D38_SOURCE
            and closure38["next_boundary"]["gate_id"] == GATE_ID
            and closure38["next_boundary"]["r24d38_may_be_requalified"] is False
        ),
        "flat_observation_v2_publishes_through_exact_source_binding_and_v3_collector": (
            publication["support_status"] == "supported_exact"
            and publication["portable_observation_published"] is True
            and observation["schema_version"] == "sporespore_recovery_observation_v2"
            and collection["schema_version"]
            == "sporespore_recovery_native_collection_receipt_v2"
            and collection["support_status"] == "supported_exact"
            and collection["observation_sha256"]
            == publication["portable_observation_sha256"]
            and publication["observation_source_binding_sha256"] is not None
        ),
        "signed_constraint_exchange_reaches_v3_supervisor_without_v1_relabelling": (
            observation["energy_balance"]["cumulative_signed_constraint_exchange_j"]
            != 0.0
            and step["support_status"] == "supported_exact"
            and step["classification"]["energy_balance_residual_j"] == 0.0
            and residual_step["support_status"] == "supported_exact"
            and residual_step["classification"]["energy_balance_residual_j"] == 1.0
            and residual_step["classification"]["safety_gate"] is False
        ),
        "v3_controller_and_paired_evaluator_cross_the_public_abi_with_zero_world_receipts": (
            control["support_status"] == "supported_exact"
            and control["engine_identity_input_count"] == 0
            and control["engine_specific_policy_branch_count"] == 0
            and evaluation["support_status"] == "supported_exact"
            and evaluation["verdict"] == "synthetic_canary_failed"
            and evaluation["initial_state_identity_matched"] is True
            and evaluation["candidate_trace"]["accepted_observation_count"] == 1
            and evaluation["matched_zero_command_trace"]["accepted_observation_count"]
            == 1
            and evaluation["physical_question_opened"] is False
        ),
        "binding_schema_engine_and_legacy_consumer_mutations_fail_closed": (
            all(binding_refusals)
            and _raises(lambda: core.recovery_collect_native_v3(wrong_schema))
            and _raises(lambda: core.recovery_collect_native_v2(legacy))
            and unsupported_receipt["support_status"] == "unsupported_capability"
            and unsupported_receipt["refusal_reason"]
            == "observation_v2_native_mapping_not_qualified_for_engine"
        ),
        "mujoco_route_wiring_is_additive_and_historical_r24d36_refusal_behavior_is_preserved": (
            "class MujocoObservationV2RecoveryWorld" in native_source
            and "publication_route_id = OBSERVATION_V2_CONSUMER_ROUTE_ID"
            in native_source
            and "energy_work_preprojection_refusal_enabled = False" in native_source
            and "class MujocoSignedWorkPreprojectionRecoveryWorld" in native_source
            and "energy_work_preprojection_refusal_enabled = True" in native_source
            and "raise NativeEnergyProjectionRefusal(diagnostic)" in native_source
        ),
        "public_header_abi_manifest_and_schema_registry_are_exact": (
            len(symbols) == 48
            and all(symbols.count(symbol) == 1 for symbol in v3_symbols)
            and all(f"{symbol}(" in header for symbol in v3_symbols)
            and schema_by_id["sporespore_recovery_observation_v2"]["direction"]
            == "nested_bidirectional"
            and all(
                schema_id in schema_by_id
                for schema_id in (
                    "sporespore_recovery_step_request_v3",
                    "sporespore_recovery_trace_v2",
                    "sporespore_recovery_evaluation_request_v3",
                    "sporespore_recovery_native_collection_request_v3",
                    "sporespore_recovery_native_collection_receipt_v2",
                    "sporespore_recovery_observation_v2_source_binding_v1",
                    "sporespore_recovery_control_request_v3",
                )
            )
        ),
        "contract_keeps_physics_threshold_population_results_and_scores_unchanged": (
            contract["complete_zero_world_gate"]["required_control_count"] == 8
            and contract["qualification_authority"]["maximum_physical_steps_authorized"]
            == 0
            and contract["threshold_margin_and_population_authority"][
                "new_behavior_threshold_count"
            ]
            == 0
            and contract["threshold_margin_and_population_authority"][
                "population_claim_count"
            ]
            == 0
            and contract["held_out_seal"]["held_out_cell_access_count"] == 0
            and contract["claim_boundary"]["sdk1_release_readiness"] == "11/20"
            and contract["claim_boundary"]["full_program_readiness"] == "11/25"
            and all(
                value.get("model_construction_count", 0) == 0
                and value.get("world_attempt_count", 0) == 0
                and value.get("world_build_count", 0) == 0
                and value.get("solver_step_count", 0) == 0
                and value.get("physics_state_modified", False) is False
                and value.get("prone_to_standing_claimed", False) is False
                and value.get("physical_acceptance_authority", False) is False
                and value.get("release_authority", False) is False
                for value in zero_world_values
            )
        ),
    }
    failed_controls = [name for name, passed in controls.items() if not passed]
    _require(
        len(controls) == 8 and not failed_controls,
        "R24D39_CONTROL_FAILED:" + ",".join(failed_controls),
    )
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "gate_id": GATE_ID,
        "ok": True,
        "runtime_id": "sporespore_engine_neutral_locomotion_core",
        "runtime_version": core.version,
        "control_count": len(controls),
        "controls_passed": sum(controls.values()),
        "controls": controls,
        "portable_observation_sha256": publication["portable_observation_sha256"],
        "observation_source_binding_sha256": publication[
            "observation_source_binding_sha256"
        ],
        "forced_failure_count": len(binding_refusals) + 2,
        "typed_refusal_count": 1,
        "public_c_abi_symbol_count": len(symbols),
        "schema_registry_entry_count": len(registry["schemas"]),
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
