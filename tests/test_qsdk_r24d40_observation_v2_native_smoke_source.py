"""Compact source audit for the prospective QSDK-R24D40 native route smoke."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
for path in (REPO_ROOT, SDK_ROOT, SDK_ROOT / "python", SDK_ROOT / "adapters/mujoco"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d40_observation_v2_native_smoke_worker as worker,
)


CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d40_mujoco_observation_v2_native_smoke_contract_v1.json"
)
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
MILESTONE_PATH = SDK_ROOT / "release/quadruped_sdk1_milestone_mapping_v1.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
ROUTE_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_route.py"
)
NATIVE_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
ZERO_WRAPPER_PATH = (
    SDK_ROOT / "run_qsdk_r24d40_observation_v2_native_smoke_zero_world.ps1"
)
PHYSICAL_WRAPPER_PATH = SDK_ROOT / "run_qsdk_r24d40_observation_v2_native_smoke.ps1"
NEW_PATHS = {
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d40_observation_v2_native_smoke_worker.py",
    "sdk/recovery/r24d40_mujoco_observation_v2_native_smoke_contract_v1.json",
    "sdk/run_qsdk_r24d40_observation_v2_native_smoke.ps1",
    "sdk/run_qsdk_r24d40_observation_v2_native_smoke_zero_world.ps1",
    "tests/test_qsdk_r24d40_observation_v2_native_smoke_source.py",
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
    contract = worker.load_contract_v1(CONTRACT_PATH)
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
        == 19
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

    receipt = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    require(
        receipt["controls_passed"] == receipt["control_count"] == 8
        and receipt["forced_failure_count"] == 7
        and receipt["model_construction_count"] == 0
        and receipt["world_attempt_count"] == 0
        and receipt["world_build_count"] == 0
        and receipt["solver_step_count"] == 0
        and receipt["physics_state_modified"] is False
        and receipt["physical_question_opened"] is False,
        "COMPLETE_ZERO_WORLD_PREFLIGHT",
    )

    route_source = ROUTE_PATH.read_text(encoding="utf-8")
    native_source = NATIVE_PATH.read_text(encoding="utf-8")
    require(
        "def validate_recovery_observation_v2_in_run_invariants_v1" in route_source
        and "publish_recovery_observation_v2(" in route_source
        and "import mujoco" not in route_source
        and "import numpy" not in route_source
        and "native_time_tolerance_s" in route_source
        and "publication_replayed_exact" in route_source,
        "PURE_REPLAYABLE_INVARIANT_VALIDATOR",
    )
    call = "validate_recovery_observation_v2_in_run_invariants_v1("
    require(
        "class MujocoObservationV2RecoveryWorld" in native_source
        and call in native_source
        and native_source.index(call)
        < native_source.index('native["observation_v2_publication"] = publication')
        < native_source.index(
            'return deepcopy(publication["portable_observation"]), native'
        ),
        "PRODUCTION_IN_RUN_CHECK_BEFORE_RETURN",
    )

    expected_status = (
        "prospective_native_mujoco_observation_v2_smoke_development_zero_world_"
        "passed_physics_blocked_pending_qualification"
    )
    release40 = find_gate(load(RELEASE_PATH), worker.GATE_ID)
    support40 = find_gate(load(SUPPORT_PATH), worker.GATE_ID)
    require(release40 is not None and support40 is not None, "LIVE_R40_MISSING")
    for live in (release40, support40):
        require(
            live["status"] == expected_status
            and live["contract_path"]
            == "sdk/recovery/r24d40_mujoco_observation_v2_native_smoke_contract_v1.json"
            and live["r24d40_source_declared"] is True
            and live["r24d40_development_zero_world_gate_passed"] is True
            and live["r24d40_official_qualification_passed"] is False
            and live["in_run_invariant_validator_implemented"] is True
            and live["maximum_total_outer_steps_authorized"] == 2
            and live["maximum_physical_steps_authorized"] == 10
            and live["physical_execution_authorized"] is False
            and live["prone_to_standing_claimed"] is False,
            "LIVE_AUTHORITY",
        )

    milestones = load(MILESTONE_PATH)
    require(
        milestones["sdk1_contract"]["milestone_count"] == 20
        and milestones["claim_boundary"]["mapping_completion_alone_authorizes_release"]
        is False,
        "SDK1_COUNT_UNCHANGED",
    )
    zero_wrapper = ZERO_WRAPPER_PATH.read_text(encoding="utf-8")
    physical_wrapper = PHYSICAL_WRAPPER_PATH.read_text(encoding="utf-8")
    require(
        "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1" in zero_wrapper
        and "run_qsdk_r24d18_mujoco_native_recovery_development.ps1" in physical_wrapper
        and "-ExpectedHorizonSteps 1" in physical_wrapper
        and "-ExpectedPairedArmCount 2" in physical_wrapper
        and "full_seed" not in physical_wrapper.lower(),
        "SHARED_RUNNERS_AND_MINIMUM_HORIZON_ONLY",
    )
    print(
        "QSDK_R24D40_OBSERVATION_V2_NATIVE_SMOKE_SOURCE_PASS "
        "inventory=19 controls=8/8 forced_failures=7 "
        "models=0 worlds=0 solver_steps=0 physical=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
