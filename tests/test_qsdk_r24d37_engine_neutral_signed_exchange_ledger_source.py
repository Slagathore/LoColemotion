"""Compact source audit for QSDK-R24D37's engine-neutral ledger V2."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
for path in (SDK_ROOT / "python", SDK_ROOT / "conformance"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
import r24d37_energy_ledger as worker  # noqa: E402


CONTRACT_PATH = (
    SDK_ROOT
    / "recovery/r24d37_engine_neutral_signed_exchange_ledger_contract_v1.json"
)
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
ABI_PATH = SDK_ROOT / "versioning/c_abi_manifest_v1.json"
SCHEMA_PATH = SDK_ROOT / "versioning/schema_registry_v1.json"
CORE_SOURCE_PATH = SDK_ROOT / "core/src/recovery_energy.rs"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
NEW_PATHS = {
    "sdk/conformance/r24d37_energy_ledger.py",
    "sdk/core/src/recovery_energy.rs",
    "sdk/recovery/r24d37_engine_neutral_signed_exchange_ledger_contract_v1.json",
    "sdk/run_qsdk_core_zero_world_qualification.ps1",
    "sdk/run_qsdk_r24d37_engine_neutral_energy_ledger_zero_world.ps1",
    "tests/test_qsdk_r24d37_engine_neutral_signed_exchange_ledger_source.py",
}
SYMBOLS = {
    "ss_recovery_energy_balance_aggregate_v2_json",
    "ss_recovery_energy_balance_evaluate_v2_json",
    "ss_recovery_energy_balance_migrate_v1_json",
}
SCHEMAS = {
    "sporespore_recovery_energy_balance_ledger_v1",
    "sporespore_recovery_energy_work_increment_v2",
    "sporespore_recovery_energy_balance_ledger_v2",
    "sporespore_recovery_energy_balance_aggregation_request_v2",
    "sporespore_recovery_energy_balance_aggregation_receipt_v2",
    "sporespore_recovery_energy_balance_evaluation_request_v2",
    "sporespore_recovery_energy_balance_evaluation_receipt_v2",
    "sporespore_recovery_energy_balance_migration_request_v1",
    "sporespore_recovery_energy_balance_migration_receipt_v1",
}


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AssertionError(code)


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def find_gate(value: Any, gate_id: str) -> dict[str, Any] | None:
    if isinstance(value, dict):
        if value.get("gate_id") == gate_id:
            return value
        for nested in value.values():
            found = find_gate(nested, gate_id)
            if found is not None:
                return found
    elif isinstance(value, list):
        for nested in value:
            found = find_gate(nested, gate_id)
            if found is not None:
                return found
    return None


def main() -> int:
    contract = worker.load_contract_v1(CONTRACT_PATH)
    inventory = set(contract["source_inventory"])
    changed = set(
        subprocess.run(
            ["git", "diff", "--name-only", contract["declaration_parent_commit"]],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    )
    changed.update(
        subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    )
    require(
        all((REPO_ROOT / relative).is_file() for relative in inventory)
        and changed == inventory
        and NEW_PATHS.issubset(inventory)
        and all(
            subprocess.run(
                [
                    "git",
                    "cat-file",
                    "-e",
                    f"{contract['declaration_parent_commit']}:{relative}",
                ],
                cwd=REPO_ROOT,
                capture_output=True,
                check=False,
            ).returncode
            != 0
            for relative in NEW_PATHS
        ),
        "CONTENT_ADDRESSED_SOURCE_POPULATION",
    )

    source = CORE_SOURCE_PATH.read_text(encoding="utf-8")
    require(
        "pub struct RecoveryEnergyBalanceLedgerV2" in source
        and "pub sequence_index: u64" in source
        and "pub semantic_step: u64" in source
        and "pub cumulative_signed_external_work_j: f64" in source
        and "pub cumulative_signed_constraint_exchange_j: f64" in source
        and "pub cumulative_passive_dissipation_j: f64" in source
        and "digest_serializable(&request.ordered_increments)" in source
        and "MAX_EXACT_JSON_INTEGER" in source
        and "add_finite(" in source
        and "portable_v1_signed_constraint_work_unrepresentable" in source
        and "portable_v1_nonzero_external_work_unrepresentable" in source
        and source.count("signed_residual_j.abs()") == 1
        and ".clamp(" not in source
        and ".max(0" not in source
        and "mechanical_energy_change" not in source
        and "balance_residual_used" not in source,
        "CORE_SEMANTIC_BOUNDARY",
    )
    parent_recovery = subprocess.run(
        ["git", "show", f"{contract['declaration_parent_commit']}:sdk/core/src/recovery.rs"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    require(
        (SDK_ROOT / "core/src/recovery.rs").read_text(encoding="utf-8")
        == parent_recovery,
        "V1_RECOVERY_SOURCE_CHANGED",
    )

    abi = load(ABI_PATH)
    symbols = [entry["name"] for entry in abi["symbols"]]
    registry = load(SCHEMA_PATH)
    schemas = [entry["schema_id"] for entry in registry["schemas"]]
    require(
        len(symbols) == len(set(symbols)) == 44
        and SYMBOLS.issubset(symbols)
        and len(schemas) == len(set(schemas)) == 67
        and SCHEMAS.issubset(schemas),
        "ABI_SCHEMA_REGISTRATION",
    )
    header = (SDK_ROOT / "include/sporespore_locomotion.h").read_text(encoding="utf-8")
    python = (SDK_ROOT / "python/sporespore_locomotion.py").read_text(encoding="utf-8")
    godot = (SDK_ROOT / "adapters/godot/src/lib.rs").read_text(encoding="utf-8")
    ffi = (SDK_ROOT / "core/src/ffi.rs").read_text(encoding="utf-8")
    require(
        all(
            symbol in header and symbol in python and symbol in godot and symbol in ffi
            for symbol in SYMBOLS
        )
        and "def recovery_energy_balance_aggregate_v2(" in python
        and "def recovery_energy_balance_evaluate_v2(" in python
        and "def recovery_energy_balance_migrate_v1(" in python,
        "HOST_BINDINGS",
    )

    preflight = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    require(
        preflight["ok"] is True
        and preflight["control_count"]
        == preflight["controls_passed"]
        == contract["complete_zero_world_gate"]["required_control_count"]
        == 9
        and list(preflight["controls"])
        == contract["complete_zero_world_gate"]["required_controls"]
        and preflight["model_construction_count"] == 0
        and preflight["world_attempt_count"] == 0
        and preflight["world_build_count"] == 0
        and preflight["solver_step_count"] == 0
        and preflight["physics_state_modified"] is False
        and preflight["physical_question_opened"] is False,
        "COMPLETE_ZERO_WORLD_PREFLIGHT",
    )

    expected_status = contract["status"]
    release37 = find_gate(load(RELEASE_PATH), worker.GATE_ID)
    support37 = find_gate(load(SUPPORT_PATH), worker.GATE_ID)
    require(release37 is not None and support37 is not None, "LIVE_R37_MISSING")
    for live in (release37, support37):
        require(
            live["status"] == expected_status
            and live["contract_path"]
            == "sdk/recovery/r24d37_engine_neutral_signed_exchange_ledger_contract_v1.json"
            and live["ledger_schema"]
            == "sporespore_recovery_energy_balance_ledger_v2"
            and live["development_zero_world_gate_passed"] is True
            and live["official_qualification_passed"] is False
            and live["maximum_physical_steps_authorized"] == 0
            and live["physical_execution_authorized"] is False,
            "LIVE_AUTHORITY",
        )

    shared = (SDK_ROOT / "run_qsdk_core_zero_world_qualification.ps1").read_text(
        encoding="utf-8"
    )
    wrapper = (
        SDK_ROOT / "run_qsdk_r24d37_engine_neutral_energy_ledger_zero_world.ps1"
    ).read_text(encoding="utf-8")
    require(
        "cargo build --offline -p sporespore-locomotion-core" in shared
        and "cargo check --offline -p sporespore-godot-adapter" in shared
        and "SPORESPORE_LOCOMOTION_LIBRARY" in shared
        and "Enter-SporeSporeLocomotionOperationLock -Role physical" not in shared
        and "world_attempt_count = 0" in shared
        and "-Mode $Mode" in wrapper
        and "qsdk-r24d37-qualification-" in wrapper
        and "run_qsdk_core_zero_world_qualification.ps1" in wrapper,
        "ZERO_WORLD_ONLY_RUNNER",
    )
    print(
        "QSDK_R24D37_ENGINE_NEUTRAL_SIGNED_EXCHANGE_LEDGER_SOURCE_PASS "
        f"inventory={len(inventory)} controls=9/9 symbols=44 schemas=67 "
        "models=0 worlds=0 solver_steps=0 physical=false sdk1=11/20 full=11/25"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
