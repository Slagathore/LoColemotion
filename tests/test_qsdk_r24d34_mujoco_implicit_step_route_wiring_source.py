"""Compact source-conformance audit for the prospective R24D34 freeze."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
ADAPTER_ROOT = SDK_ROOT / "adapters/mujoco"
for path in (SDK_ROOT / "python", ADAPTER_ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import native_recovery_development as runtime  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d34_implicit_step_route_wiring_worker as worker,
)


CONTRACT_PATH = SDK_ROOT / "recovery/r24d34_mujoco_implicit_step_route_wiring_contract_v1.json"
R33_CLOSURE_PATH = SDK_ROOT / "recovery/r24d33_mujoco_implicit_step_energy_measurement_qualification_closure_v1.json"
R33_AUDIT_PATH = REPO_ROOT / "tests/test_qsdk_r24d33_mujoco_implicit_step_energy_measurement_qualification_closure.py"
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
NEW_PATHS = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/implicit_step_energy_trace.py",
    "sdk/recovery/r24d34_mujoco_implicit_step_route_wiring_contract_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d34_implicit_step_route_wiring_worker.py",
    "tests/test_qsdk_r24d34_mujoco_implicit_step_route_wiring_source.py",
    "sdk/run_qsdk_r24d34_implicit_step_route_wiring_zero_world.ps1",
    "sdk/run_qsdk_r24d34_implicit_step_route_wiring_smoke.ps1",
)
LIVE_AUTHORITY_PATHS = (
    "sdk/release/quadruped_release_contract.json", "sdk/release/quadruped_support_matrix.json"
)


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AssertionError(code)


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


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


def absent_at(commit: str, relative: str) -> bool:
    return subprocess.run(
        ["git", "cat-file", "-e", f"{commit}:{relative}"],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
    ).returncode != 0


def main() -> int:
    contract = worker.load_contract_v1(CONTRACT_PATH)
    closure = load(R33_CLOSURE_PATH)
    release = load(RELEASE_PATH)
    support = load(SUPPORT_PATH)
    release34 = find_gate(release, worker.GATE_ID)
    support34 = find_gate(support, worker.GATE_ID)
    require(release34 is not None and support34 is not None, "LIVE_R34_MISSING")
    require(
        sha256(R33_CLOSURE_PATH) == worker.R24D33_CLOSURE_SHA256
        and sha256(R33_AUDIT_PATH)
        == contract["lineage"]["predecessor_closure_audit_raw_sha256"]
        and closure["qualification"]["controls_passed"] == 12
        and closure["qualification"]["world_attempt_count"] == 0,
        "R33_LINEAGE",
    )
    require(
        all((REPO_ROOT / relative).is_file() for relative in contract["source_inventory"])
        and all(relative in contract["source_inventory"] for relative in NEW_PATHS)
        and all(relative in contract["source_inventory"] for relative in LIVE_AUTHORITY_PATHS)
        and all(
            absent_at(contract["declaration_parent_commit"], relative)
            for relative in NEW_PATHS
        ),
        "SOURCE_INVENTORY",
    )
    controls, details = worker._zero_world_controls()
    require(
        contract["complete_zero_world_gate"]["must_pass_before_physics"] is True
        and len(controls)
        == sum(controls.values())
        == contract["complete_zero_world_gate"]["required_control_count"]
        == 10
        and list(controls) == contract["complete_zero_world_gate"]["required_controls"]
        and details["stage_calls"][-1] == "mj_implicit",
        "CONTROLS",
    )
    with patch.object(runtime.mujoco.MjModel, "from_xml_string") as constructor:
        preflight = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    constructor.assert_not_called()
    require(
        preflight["negative_controls_passed"] == 10
        and preflight["model_construction_count"] == 0
        and preflight["world_attempt_count"] == 0
        and preflight["solver_step_count"] == 0
        and preflight["physics_state_modified"] is False,
        "ZERO_WORLD_PREFLIGHT",
    )
    require(
        release34["status"]
        == support34["status"]
        == "prospective_native_route_wiring_source_zero_world_development_passed_physics_blocked_pending_qualification"
        and release34["r24d34_source_declared"] is True
        and support34["r24d34_source_declared"] is True
        and release34["r24d34_development_zero_world_gate_passed"] is True
        and support34["r24d34_development_zero_world_gate_passed"] is True
        and release34["r24d34_official_qualification_passed"] is False
        and support34["r24d34_official_qualification_passed"] is False
        and release34["physical_execution_authorized"] is False
        and support34["physical_execution_authorized"] is False,
        "LIVE_AUTHORITY",
    )
    zero_wrapper = (SDK_ROOT / "run_qsdk_r24d34_implicit_step_route_wiring_zero_world.ps1").read_text(encoding="utf-8")
    smoke_wrapper = (SDK_ROOT / "run_qsdk_r24d34_implicit_step_route_wiring_smoke.ps1").read_text(encoding="utf-8")
    shared_smoke = (SDK_ROOT / "run_qsdk_r24d18_mujoco_native_recovery_development.ps1").read_text(encoding="utf-8")
    require(
        "-Mode $Mode" in zero_wrapper
        and "qsdk-r24d34-qualification-" in zero_wrapper
        and "-ExpectedHorizonSteps 2" in smoke_wrapper
        and "-ExpectedPairedArmCount 2" in smoke_wrapper
        and "qsdk-r24d34-mujoco-implicit-step-route-smoke-" in smoke_wrapper
        and "$contract.ghost_horizon.outer_steps_per_arm" in shared_smoke,
        "WRAPPERS",
    )
    print(
        "QSDK_R24D34_MUJOCO_IMPLICIT_STEP_ROUTE_WIRING_SOURCE_PASS "
        f"sources={len(contract['source_inventory'])} controls={sum(controls.values())}/10 "
        "models=0 worlds=0 solver_steps=0 physical=false smoke_max=2x2"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
