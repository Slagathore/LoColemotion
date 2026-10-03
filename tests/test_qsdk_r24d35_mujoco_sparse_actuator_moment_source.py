"""Compact source audit for the prospective QSDK-R24D35 sparse seam."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
ADAPTER_ROOT = SDK_ROOT / "adapters/mujoco"
for path in (SDK_ROOT / "python", ADAPTER_ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import native_recovery_development as runtime  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d35_sparse_actuator_moment_worker as worker,
)


CONTRACT_PATH = SDK_ROOT / "recovery/r24d35_mujoco_sparse_actuator_moment_contract_v1.json"
R34_CONTRACT_PATH = SDK_ROOT / "recovery/r24d34_mujoco_implicit_step_route_wiring_contract_v1.json"
R34_CLOSURE_PATH = SDK_ROOT / "recovery/r24d34_mujoco_implicit_step_route_wiring_invalid_closure_v1.json"
R34_AUDIT_PATH = REPO_ROOT / "tests/test_qsdk_r24d34_mujoco_implicit_step_route_wiring_invalid_closure.py"
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
NEW_PATHS = {
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/sparse_actuator_moment.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/bounded_recovery_route_smoke.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d35_sparse_actuator_moment_worker.py",
    "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_contract_v1.json",
    "tests/test_qsdk_r24d35_mujoco_sparse_actuator_moment_source.py",
    "sdk/run_qsdk_r24d35_sparse_actuator_moment_zero_world.ps1",
    "sdk/run_qsdk_r24d35_sparse_actuator_moment_smoke.ps1",
}


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


def main() -> int:
    contract = worker.load_contract_v1(CONTRACT_PATH)
    predecessor = load(R34_CONTRACT_PATH)
    closure = load(R34_CLOSURE_PATH)
    release35 = find_gate(load(RELEASE_PATH), worker.GATE_ID)
    support35 = find_gate(load(SUPPORT_PATH), worker.GATE_ID)
    require(release35 is not None and support35 is not None, "LIVE_R35_MISSING")
    require(
        sha256(R34_CLOSURE_PATH) == worker.R24D34_CLOSURE_SHA256
        and sha256(R34_AUDIT_PATH)
        == contract["lineage"]["predecessor_closure_audit_raw_sha256"]
        and closure["source"]["commit"] == worker.R24D34_SOURCE
        and closure["physical_attempt"]["invalid_or_incomplete_retained"] is True
        and closure["next_boundary"]["r24d34_may_rerun"] is False,
        "R34_LINEAGE",
    )
    overlay = set(contract["source_inventory"])
    changed = set(
        subprocess.run(
            ["git", "diff", "--name-only", worker.R24D34_SOURCE],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    )
    changed_predecessor = changed.intersection(predecessor["source_inventory"])
    require(
        all((REPO_ROOT / relative).is_file() for relative in overlay)
        and changed_predecessor.issubset(overlay)
        and NEW_PATHS.issubset(overlay)
        and all(
            subprocess.run(
                ["git", "cat-file", "-e", f"{contract['declaration_parent_commit']}:{relative}"],
                cwd=REPO_ROOT,
                capture_output=True,
                check=False,
            ).returncode
            != 0
            for relative in NEW_PATHS
        ),
        "CONTENT_ADDRESSED_OVERLAY",
    )
    controls, details = worker._zero_world_controls()
    require(
        len(controls)
        == sum(controls.values())
        == contract["complete_zero_world_gate"]["required_control_count"]
        == 9
        and list(controls) == contract["complete_zero_world_gate"]["required_controls"]
        and details["synthetic_expansion_receipt_count"] == 10,
        "CONTROLS",
    )
    with patch.object(runtime.mujoco.MjModel, "from_xml_string") as constructor:
        preflight = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    constructor.assert_not_called()
    require(
        preflight["negative_controls_passed"] == 9
        and preflight["model_construction_count"] == 0
        and preflight["world_attempt_count"] == 0
        and preflight["solver_step_count"] == 0
        and preflight["physics_state_modified"] is False,
        "ZERO_WORLD_PREFLIGHT",
    )
    expected_status = "prospective_sparse_actuator_moment_source_zero_world_development_passed_physics_blocked_pending_qualification"
    for live in (release35, support35):
        require(
            live["status"] == expected_status
            and live["contract_path"]
            == "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_contract_v1.json"
            and live["route_id"] == runtime.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID
            and live["r24d35_source_declared"] is True
            and live["r24d35_development_zero_world_gate_passed"] is True
            and live["r24d35_official_qualification_passed"] is False
            and live["physical_execution_authorized"] is False,
            "LIVE_AUTHORITY",
        )
    zero_wrapper = (SDK_ROOT / "run_qsdk_r24d35_sparse_actuator_moment_zero_world.ps1").read_text(encoding="utf-8")
    smoke_wrapper = (SDK_ROOT / "run_qsdk_r24d35_sparse_actuator_moment_smoke.ps1").read_text(encoding="utf-8")
    require(
        "-Mode $Mode" in zero_wrapper
        and "qsdk-r24d35-qualification-" in zero_wrapper
        and "-ExpectedHorizonSteps 2" in smoke_wrapper
        and "-ExpectedPairedArmCount 2" in smoke_wrapper,
        "WRAPPERS",
    )
    print(
        "QSDK_R24D35_MUJOCO_SPARSE_ACTUATOR_MOMENT_SOURCE_PASS "
        f"overlay={len(overlay)} inherited={len(predecessor['source_inventory'])} "
        f"controls={sum(controls.values())}/9 models=0 worlds=0 solver_steps=0 physical=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
