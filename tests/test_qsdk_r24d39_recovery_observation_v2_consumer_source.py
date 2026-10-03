"""Compact source audit for the prospective QSDK-R24D39 consumer seam."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
for path in (REPO_ROOT, SDK_ROOT, SDK_ROOT / "python"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sdk.conformance import (  # noqa: E402
    r24d39_recovery_observation_v2_consumer as preflight,
)


CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d39_recovery_observation_v2_consumer_contract_v1.json"
)
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
PUBLISHER_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_route.py"
)
NATIVE_ROUTE_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
CORE_RECOVERY_PATH = SDK_ROOT / "core/src/recovery.rs"
CORE_RUNTIME_PATH = SDK_ROOT / "core/src/recovery_runtime.rs"
WRAPPER_PATH = (
    SDK_ROOT / "run_qsdk_r24d39_recovery_observation_v2_consumer_zero_world.ps1"
)
NEW_PATHS = {
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_route.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_route_fixture.py",
    "sdk/adapters/mujoco/test_recovery_observation_v2_route.py",
    "sdk/conformance/r24d39_recovery_observation_v2_consumer.py",
    "sdk/recovery/r24d39_recovery_observation_v2_consumer_contract_v1.json",
    "sdk/run_qsdk_r24d39_recovery_observation_v2_consumer_zero_world.ps1",
    "tests/test_qsdk_r24d39_recovery_observation_v2_consumer_source.py",
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


def git_lines(*arguments: str) -> set[str]:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return {line for line in completed.stdout.splitlines() if line}


def main() -> int:
    contract = preflight.load_contract_v1(CONTRACT_PATH)
    inventory = set(contract["source_inventory"])
    changed = git_lines(
        "diff",
        "--name-only",
        contract["declaration_parent_commit"],
    ) | git_lines("ls-files", "--others", "--exclude-standard")
    require(
        changed == inventory
        and len(inventory)
        == contract["source_inventory_strategy"]["source_inventory_count"]
        == 27
        and all((REPO_ROOT / relative).is_file() for relative in inventory)
        and NEW_PATHS.issubset(inventory),
        "CONTENT_ADDRESSED_SOURCE_POPULATION",
    )
    for relative in NEW_PATHS:
        absent = subprocess.run(
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
        require(absent != 0, f"NEW_PATH_PREEXISTED:{relative}")

    receipt = preflight.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    require(
        receipt["controls_passed"] == receipt["control_count"] == 8
        and receipt["forced_failure_count"] == 8
        and receipt["typed_refusal_count"] == 1
        and receipt["public_c_abi_symbol_count"] == 48
        and receipt["schema_registry_entry_count"] == 76
        and receipt["model_construction_count"] == 0
        and receipt["world_attempt_count"] == 0
        and receipt["world_build_count"] == 0
        and receipt["solver_step_count"] == 0
        and receipt["physics_state_modified"] is False
        and receipt["physical_question_opened"] is False,
        "COMPLETE_ZERO_WORLD_PREFLIGHT",
    )

    publisher_source = PUBLISHER_PATH.read_text(encoding="utf-8")
    require(
        "import mujoco" not in publisher_source
        and "import numpy" not in publisher_source
        and "MjModel" not in publisher_source
        and "mj_step" not in publisher_source
        and "map_r24d36_components_to_recovery_observation_v2" in publisher_source
        and '"source_chain_sha256"' in publisher_source
        and "collect_native_v3" in publisher_source,
        "PURE_CONTENT_ADDRESSED_PUBLISHER",
    )
    native_source = NATIVE_ROUTE_PATH.read_text(encoding="utf-8")
    require(
        "class MujocoObservationV2RecoveryWorld" in native_source
        and "publication_route_id = OBSERVATION_V2_CONSUMER_ROUTE_ID" in native_source
        and "energy_work_preprojection_refusal_enabled = False" in native_source
        and "class MujocoSignedWorkPreprojectionRecoveryWorld" in native_source
        and "energy_work_preprojection_refusal_enabled = True" in native_source
        and native_source.index("raise NativeEnergyProjectionRefusal(diagnostic)")
        < native_source.index("state = self._state_frame"),
        "ADDITIVE_ROUTE_AND_HISTORICAL_REFUSAL",
    )
    recovery_source = CORE_RECOVERY_PATH.read_text(encoding="utf-8")
    runtime_source = CORE_RUNTIME_PATH.read_text(encoding="utf-8")
    require(
        "pub struct RecoveryObservationV2" in recovery_source
        and "pub struct RecoveryStepRequestV3" in recovery_source
        and "pub struct RecoveryEvaluationRequestV3" in recovery_source
        and "pub fn step_recovery_v3" in recovery_source
        and "pub fn evaluate_recovery_trace_v3" in recovery_source
        and "pub struct RecoveryNativeCollectionRequestV3" in runtime_source
        and "pub struct RecoveryControlRequestV3" in runtime_source
        and "source.source_chain_sha256 != observed_source_chain_sha256"
        in runtime_source,
        "TRUE_V2_CONSUMER_TYPES",
    )

    expected_status = (
        "prospective_observation_v2_consumer_source_zero_world_development_"
        "passed_physics_blocked_pending_qualification"
    )
    release39 = find_gate(load(RELEASE_PATH), preflight.GATE_ID)
    support39 = find_gate(load(SUPPORT_PATH), preflight.GATE_ID)
    require(release39 is not None and support39 is not None, "LIVE_R39_MISSING")
    for live in (release39, support39):
        require(
            live["status"] == expected_status
            and live["contract_path"]
            == "sdk/recovery/r24d39_recovery_observation_v2_consumer_contract_v1.json"
            and live["r24d39_source_declared"] is True
            and live["r24d39_development_zero_world_gate_passed"] is True
            and live["r24d39_official_qualification_passed"] is False
            and live["public_c_abi_symbol_count_total"] == 48
            and live["schema_registry_entry_count_total"] == 76
            and live["maximum_physical_steps_authorized"] == 0
            and live["physical_execution_authorized"] is False,
            "LIVE_AUTHORITY",
        )

    wrapper = WRAPPER_PATH.read_text(encoding="utf-8")
    require(
        "run_qsdk_core_zero_world_qualification.ps1" in wrapper
        and 'CargoTestFilter "observation_v2"' in wrapper
        and "test_complete_route_publishes_source_bound_observation_v2" in wrapper
        and "qsdk-r24d39-qualification-" in wrapper
        and "physical" not in WRAPPER_PATH.name
        and "smoke" not in WRAPPER_PATH.name,
        "SHARED_ZERO_WORLD_RUNNER_ONLY",
    )
    print(
        "QSDK_R24D39_RECOVERY_OBSERVATION_V2_CONSUMER_SOURCE_PASS "
        f"inventory={len(inventory)} controls=8/8 forced_failures=8 refusals=1 "
        "abi=48 schemas=76 models=0 worlds=0 solver_steps=0 physical=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
