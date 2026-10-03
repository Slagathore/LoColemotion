"""Compact source audit for the prospective QSDK-R24D38 mapping seam."""

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
from sdk.conformance import r24d38_recovery_energy_mapping as preflight  # noqa: E402


CONTRACT_PATH = SDK_ROOT / "recovery/r24d38_native_energy_v2_mapping_contract_v1.json"
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
SCHEMA_REGISTRY_PATH = SDK_ROOT / "versioning/schema_registry_v1.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
MAPPING_PATH = (
    SDK_ROOT / "adapters/mujoco/sporespore_mujoco_adapter/recovery_energy_v2_mapping.py"
)
R36_RUNTIME_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
WRAPPER_PATH = SDK_ROOT / "run_qsdk_r24d38_native_energy_v2_mapping_zero_world.ps1"
NEW_PATHS = {
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_energy_v2_mapping.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_energy_v2_mapping_fixture.py",
    "sdk/adapters/mujoco/test_recovery_energy_v2_mapping.py",
    "sdk/conformance/r24d38_recovery_energy_mapping.py",
    "sdk/recovery/r24d38_native_energy_v2_mapping_contract_v1.json",
    "sdk/run_qsdk_r24d38_native_energy_v2_mapping_zero_world.ps1",
    "tests/test_qsdk_r24d38_native_energy_v2_mapping_source.py",
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
        == 17
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
        receipt["controls_passed"] == receipt["control_count"] == 9
        and receipt["native_component_receipt_count"] == 10
        and receipt["forced_failure_count"] == 5
        and receipt["typed_refusal_count"] == 2
        and receipt["model_construction_count"] == 0
        and receipt["world_attempt_count"] == 0
        and receipt["world_build_count"] == 0
        and receipt["solver_step_count"] == 0
        and receipt["physics_state_modified"] is False
        and receipt["physical_question_opened"] is False,
        "COMPLETE_ZERO_WORLD_PREFLIGHT",
    )

    mapping_source = MAPPING_PATH.read_text(encoding="utf-8")
    require(
        "import mujoco" not in mapping_source
        and "import numpy" not in mapping_source
        and "native_recovery_development" not in mapping_source
        and "mj_step" not in mapping_source
        and "MjModel" not in mapping_source
        and "recovery_energy_balance_aggregate_v2" in mapping_source
        and "mechanical_energy_change_used_as_work_source" in mapping_source
        and "energy_balance_residual_used_as_work_source" in mapping_source,
        "PURE_MAPPING_SURFACE",
    )
    runtime_source = R36_RUNTIME_PATH.read_text(encoding="utf-8")
    require(
        "class MujocoSignedWorkPreprojectionRecoveryWorld" in runtime_source
        and "energy_work_preprojection_required = True" in runtime_source
        and runtime_source.index("raise NativeEnergyProjectionRefusal(diagnostic)")
        < runtime_source.index("state = self._state_frame")
        and str(R36_RUNTIME_PATH.relative_to(REPO_ROOT)).replace("\\", "/")
        not in changed,
        "HISTORICAL_R36_ROUTE_UNCHANGED",
    )

    registry = load(SCHEMA_REGISTRY_PATH)
    schema_ids = [item["schema_id"] for item in registry["schemas"]]
    require(
        schema_ids.count("sporespore_recovery_observation_v1") == 1
        and schema_ids.count("sporespore_recovery_observation_v2") == 1,
        "OBSERVATION_SCHEMA_REGISTRATION",
    )

    expected_status = (
        "prospective_native_energy_v2_mapping_source_zero_world_development_"
        "passed_physics_blocked_pending_qualification"
    )
    release38 = find_gate(load(RELEASE_PATH), preflight.GATE_ID)
    support38 = find_gate(load(SUPPORT_PATH), preflight.GATE_ID)
    require(release38 is not None and support38 is not None, "LIVE_R38_MISSING")
    for live in (release38, support38):
        require(
            live["status"] == expected_status
            and live["contract_path"]
            == "sdk/recovery/r24d38_native_energy_v2_mapping_contract_v1.json"
            and live["mapping_profile_id"]
            == "mujoco_r24d36_native_components_to_recovery_energy_v2_v1"
            and live["portable_observation_schema"]
            == "sporespore_recovery_observation_v2"
            and live["r24d38_source_declared"] is True
            and live["r24d38_development_zero_world_gate_passed"] is True
            and live["r24d38_official_qualification_passed"] is False
            and live["maximum_physical_steps_authorized"] == 0
            and live["physical_execution_authorized"] is False,
            "LIVE_AUTHORITY",
        )

    wrapper = WRAPPER_PATH.read_text(encoding="utf-8")
    require(
        "run_qsdk_core_zero_world_qualification.ps1" in wrapper
        and "test_recovery_energy_v2_mapping" in wrapper
        and "qsdk-r24d38-qualification-" in wrapper
        and "physical" not in WRAPPER_PATH.name
        and "smoke" not in WRAPPER_PATH.name,
        "SHARED_ZERO_WORLD_RUNNER_ONLY",
    )
    print(
        "QSDK_R24D38_NATIVE_ENERGY_V2_MAPPING_SOURCE_PASS "
        f"inventory={len(inventory)} controls=9/9 receipts=10 "
        "forced_failures=5 refusals=2 models=0 worlds=0 solver_steps=0 "
        "physical=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
