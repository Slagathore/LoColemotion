#!/usr/bin/env python3
"""Compact source audit and zero-world preflight for QSDK-R24D56."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d56_godot_current_recovery_public_surface_contract_v1.json"
)
GODOT_WORKER = (
    REPO_ROOT
    / "tests/test_sdk_qsdk_r24d56_godot_current_recovery_surface_zero_world.gd"
)
GODOT_EXE = Path(
    r"C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)
SOURCE_MARKER = "QSDK_R24D56_GODOT_RECOVERY_PUBLIC_SURFACE_SOURCE_PASS"
GODOT_MARKER = "QSDK_R24D56_GODOT_RECOVERY_SURFACE_ZERO_WORLD "

NEW_ABI_SYMBOLS = {
    "ss_recovery_step_v4_json",
    "ss_recovery_evaluate_trace_v4_json",
    "ss_recovery_energy_balance_aggregate_v3_json",
    "ss_recovery_energy_balance_evaluate_v3_json",
}
NEW_SCHEMAS = {
    "sporespore_recovery_observation_v3",
    "sporespore_recovery_step_request_v4",
    "sporespore_recovery_trace_v3",
    "sporespore_recovery_evaluation_request_v4",
    "sporespore_recovery_energy_work_increment_v3",
    "sporespore_recovery_energy_balance_ledger_v3",
    "sporespore_recovery_energy_balance_aggregation_request_v3",
    "sporespore_recovery_energy_balance_aggregation_receipt_v3",
    "sporespore_recovery_energy_balance_evaluation_request_v3",
    "sporespore_recovery_energy_balance_evaluation_receipt_v3",
}
GODOT_INPUT_METHODS = (
    "recovery_initialize_v1_json",
    "recovery_initialize_v2_json",
    "recovery_step_v1_json",
    "recovery_step_v2_json",
    "recovery_step_v3_json",
    "recovery_step_v4_json",
    "recovery_evaluate_trace_v1_json",
    "recovery_evaluate_trace_v2_json",
    "recovery_evaluate_trace_v3_json",
    "recovery_evaluate_trace_v4_json",
    "recovery_energy_balance_aggregate_v2_json",
    "recovery_energy_balance_aggregate_v3_json",
    "recovery_energy_balance_evaluate_v2_json",
    "recovery_energy_balance_evaluate_v3_json",
    "recovery_energy_balance_migrate_v1_json",
    "recovery_collect_native_v1_json",
    "recovery_collect_native_v2_json",
    "recovery_collect_native_v3_json",
    "recovery_plan_control_v1_json",
    "recovery_plan_control_v2_json",
    "recovery_plan_control_v3_json",
    "recovery_plan_stance_control_v1_json",
    "recovery_plan_stance_control_v2_json",
    "recovery_plan_stance_control_v3_json",
)
GDSCRIPT_WRAPPERS = (
    "initialize_v1",
    "initialize_v2",
    "step_v1",
    "step_v2",
    "step_v3",
    "step_v4",
    "evaluate_trace_v1",
    "evaluate_trace_v2",
    "evaluate_trace_v3",
    "evaluate_trace_v4",
    "aggregate_energy_v2",
    "aggregate_energy_v3",
    "evaluate_energy_v2",
    "evaluate_energy_v3",
    "migrate_energy_v1",
    "collect_native_v1",
    "collect_native_v2",
    "collect_native_v3",
    "plan_control_v1",
    "plan_control_v2",
    "plan_control_v3",
    "plan_stance_control_v1",
    "plan_stance_control_v2",
    "plan_stance_control_v3",
)


class SurfaceError(RuntimeError):
    """Stable fail-closed R24D56 error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise SurfaceError(code)


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _validate_contract() -> dict[str, Any]:
    contract = _load_json(CONTRACT_PATH)
    _require(contract["gate_id"] == "QSDK-R24D56", "CONTRACT_GATE")
    _require(contract["question_class"] == "development", "QUESTION_CLASS")
    _require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    surface = contract["public_surface"]
    _require(surface["godot_input_method_count"] == len(GODOT_INPUT_METHODS), "METHOD_COUNT")
    _require(surface["godot_input_methods"] == list(GODOT_INPUT_METHODS), "METHOD_ORDER")
    _require(surface["new_core_public_entrypoint_count"] == len(NEW_ABI_SYMBOLS), "ABI_COUNT")
    _require(set(surface["new_core_public_entrypoints"]) == NEW_ABI_SYMBOLS, "ABI_SET")
    _require(set(surface["new_registered_schemas"]) == NEW_SCHEMAS, "SCHEMA_SET")
    gate = contract["complete_zero_world_gate"]
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        _require(gate[key] == 0, f"ZERO_COUNT:{key}")
    _require(gate["must_pass_before_physics"] is True, "ZERO_GATE_REQUIRED")
    _require(contract["held_out_seal"]["held_out_cell_access_count"] == 0, "HELD_OUT")
    inventory = contract["source_inventory"]
    _require(len(inventory) == len(set(inventory)), "SOURCE_INVENTORY_DUPLICATE")
    for relative in inventory:
        _require((REPO_ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    for predecessor in contract["bound_predecessors"]:
        path = REPO_ROOT / predecessor["path"]
        _require(_raw_sha256(path) == predecessor["raw_sha256"], "PREDECESSOR_SHA")
    return contract


def _validate_sources() -> dict[str, int]:
    contract = _validate_contract()
    ffi = (REPO_ROOT / "sdk/core/src/ffi.rs").read_text(encoding="utf-8")
    header = (REPO_ROOT / "sdk/include/sporespore_locomotion.h").read_text(encoding="utf-8")
    python_surface = (REPO_ROOT / "sdk/python/sporespore_locomotion.py").read_text(
        encoding="utf-8"
    )
    godot_rust = (REPO_ROOT / "sdk/adapters/godot/src/lib.rs").read_text(encoding="utf-8")
    godot_script = (
        REPO_ROOT / "sdk/adapters/godot/gdscript/recovery_runtime.gd"
    ).read_text(encoding="utf-8")
    manifest = _load_json(REPO_ROOT / "sdk/versioning/c_abi_manifest_v1.json")
    registry = _load_json(REPO_ROOT / "sdk/versioning/schema_registry_v1.json")
    symbols = {item["name"] for item in manifest["symbols"]}
    schemas = {item["schema_id"] for item in registry["schemas"]}
    _require(len(symbols) == 55 and NEW_ABI_SYMBOLS <= symbols, "ABI_MANIFEST")
    _require(len(schemas) == 89 and NEW_SCHEMAS <= schemas, "SCHEMA_REGISTRY")
    for symbol in NEW_ABI_SYMBOLS:
        _require(f"fn {symbol}(" in ffi, f"FFI_SYMBOL:{symbol}")
        _require(f"{symbol}(" in header, f"HEADER_SYMBOL:{symbol}")
        _require(symbol in python_surface, f"PYTHON_SYMBOL:{symbol}")
        _require(symbol in godot_rust, f"GODOT_SYMBOL:{symbol}")
    for method in GODOT_INPUT_METHODS:
        _require(f"fn {method}(" in godot_rust, f"GODOT_METHOD:{method}")
    for wrapper in GDSCRIPT_WRAPPERS:
        _require(f"static func {wrapper}(" in godot_script, f"GDSCRIPT_WRAPPER:{wrapper}")
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "abi_symbol_count": len(symbols),
        "schema_count": len(schemas),
        "godot_input_method_count": len(GODOT_INPUT_METHODS),
    }


def _energy_v3_fixture() -> dict[str, Any]:
    return {
        "schema_version": "sporespore_recovery_energy_balance_aggregation_request_v3",
        "source_profile_id": "r24d56_zero_world_staging_energy_fixture_v1",
        "initial_mechanical_energy_j": 10.0,
        "current_mechanical_energy_j": 11.875,
        "ordered_increments": [
            {
                "sequence_index": 1,
                "semantic_step": 1,
                "applied_actuator_work_j": 4.0,
                "signed_external_work_j": 1.0,
                "signed_constraint_exchange_j": 2.0,
                "signed_discrete_staging_exchange_j": 0.5,
                "passive_dissipation_j": 0.5,
                "source_measurement": True,
            },
            {
                "sequence_index": 2,
                "semantic_step": 2,
                "applied_actuator_work_j": -0.5,
                "signed_external_work_j": -0.25,
                "signed_constraint_exchange_j": -3.0,
                "signed_discrete_staging_exchange_j": -0.125,
                "passive_dissipation_j": 1.25,
                "source_measurement": True,
            },
        ],
    }


def _run_preflight(core_library: Path) -> dict[str, Any]:
    counts = _validate_sources()
    sys.path.insert(0, str(REPO_ROOT / "sdk/python"))
    from sporespore_locomotion import LocomotionCore, LocomotionCoreError

    core = LocomotionCore(core_library.resolve())
    malformed_operations: tuple[tuple[Callable[[dict[str, Any]], Any], str], ...] = (
        (core.recovery_step_v4, "sporespore_recovery_step_request_v4"),
        (core.recovery_evaluate_trace_v4, "sporespore_recovery_evaluation_request_v4"),
        (
            core.recovery_energy_balance_aggregate_v3,
            "sporespore_recovery_energy_balance_aggregation_request_v3",
        ),
        (
            core.recovery_energy_balance_evaluate_v3,
            "sporespore_recovery_energy_balance_evaluation_request_v3",
        ),
    )
    refused = 0
    for operation, schema in malformed_operations:
        try:
            operation({"schema_version": schema})
        except LocomotionCoreError as error:
            refused += int(error.failure_code == "SCHEMA_INVALID")
    _require(refused == len(malformed_operations), "NEW_ABI_REFUSAL")
    energy = core.recovery_energy_balance_aggregate_v3(_energy_v3_fixture())
    _require(energy["evaluation"]["signed_residual_j"] == 0.0, "ENERGY_RESIDUAL")

    # The shared zero-world runner builds this debug GDExtension before any
    # Python process loads the core DLL. Rebuilding here would reintroduce the
    # Windows loader-handle race that the shared ordering deliberately avoids.
    _require(
        (REPO_ROOT / "sdk/target/debug/sporespore_godot_adapter.dll").is_file(),
        "GODOT_ADAPTER_DEBUG_BINARY_MISSING",
    )
    _require(GODOT_EXE.is_file(), "GODOT_EXECUTABLE_MISSING")
    godot = subprocess.run(
        [
            str(GODOT_EXE),
            "--headless",
            "--path",
            str(REPO_ROOT),
            "--script",
            "res://" + GODOT_WORKER.relative_to(REPO_ROOT).as_posix(),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    _require(godot.returncode == 0, f"GODOT_WORKER:{godot.stdout}:{godot.stderr}")
    marker_lines = [line for line in godot.stdout.splitlines() if line.startswith(GODOT_MARKER)]
    _require(len(marker_lines) == 1, "GODOT_MARKER")
    godot_receipt = json.loads(marker_lines[0][len(GODOT_MARKER) :])
    _require(
        godot_receipt["ok"] is True
        and godot_receipt["input_method_count"] == len(GODOT_INPUT_METHODS)
        and godot_receipt["input_method_present_count"] == len(GODOT_INPUT_METHODS)
        and godot_receipt["direct_core_refusal_count"] == len(GODOT_INPUT_METHODS)
        and godot_receipt["local_schema_mutation_rejection_count"]
        == len(GODOT_INPUT_METHODS),
        "GODOT_RECEIPT",
    )
    return {
        "schema_version": "sporespore_qsdk_r24d56_godot_recovery_public_surface_preflight_v1",
        "gate_id": "QSDK-R24D56",
        "ok": True,
        "runtime_id": "sporespore_godot_current_recovery_public_surface_v1",
        "runtime_version": "recovery_observation_v3_step_and_evaluator_v4",
        **counts,
        "new_abi_forced_failure_count": refused,
        "energy_v3_signed_residual_j": energy["evaluation"]["signed_residual_j"],
        "godot_receipt": godot_receipt,
        "godot_executable_raw_sha256": _raw_sha256(GODOT_EXE),
        "stock_godot_profile_promoted": False,
        "instrumented_godot_profile_substituted": False,
        "native_runtime_observation_collection_executed": False,
        "held_out_cell_access_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    arguments = parser.parse_args()
    if arguments.core_library is None:
        counts = _validate_sources()
        print(
            SOURCE_MARKER,
            " ".join(f"{key}={value}" for key, value in counts.items()),
        )
        return 0
    print(
        json.dumps(
            _run_preflight(arguments.core_library),
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, SurfaceError, ValueError, json.JSONDecodeError) as error:
        print(f"QSDK_R24D56_GODOT_RECOVERY_PUBLIC_SURFACE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
