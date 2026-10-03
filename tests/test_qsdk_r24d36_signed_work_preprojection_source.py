"""Compact source audit for the prospective QSDK-R24D36 semantic seam."""

from __future__ import annotations

import inspect
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
from sporespore_mujoco_adapter import energy_work_projection as projection  # noqa: E402
from sporespore_mujoco_adapter import native_recovery_development as runtime  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d36_signed_work_preprojection_worker as worker,
)


CONTRACT_PATH = SDK_ROOT / "recovery/r24d36_signed_work_preprojection_contract_v1.json"
RELEASE_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
SUPPORT_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
NEW_PATHS = {
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/energy_work_projection.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d36_signed_work_preprojection_worker.py",
    "sdk/recovery/r24d36_signed_work_preprojection_contract_v1.json",
    "tests/test_qsdk_r24d36_signed_work_preprojection_source.py",
    "sdk/run_qsdk_r24d36_signed_work_preprojection_zero_world.ps1",
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
    require(
        all((REPO_ROOT / relative).is_file() for relative in inventory)
        and changed.issubset(inventory)
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

    controls, details = worker._zero_world_controls()
    require(
        len(controls)
        == sum(controls.values())
        == contract["complete_zero_world_gate"]["required_control_count"]
        == 9
        and list(controls) == contract["complete_zero_world_gate"]["required_controls"]
        and details["primitive_control_count"] == 6,
        "COMPLETE_ZERO_WORLD_CONTROLS",
    )
    with patch.object(runtime.mujoco.MjModel, "from_xml_string") as constructor:
        preflight = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    constructor.assert_not_called()
    require(
        preflight["negative_controls_passed"] == 9
        and preflight["route_id"] == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
        and preflight["energy_work_preprojection_profile_id"] == projection.PROFILE_ID
        and preflight["model_construction_count"] == 0
        and preflight["world_attempt_count"] == 0
        and preflight["world_build_count"] == 0
        and preflight["solver_step_count"] == 0
        and preflight["physics_state_modified"] is False
        and preflight["physical_question_opened"] is False,
        "ZERO_WORLD_PREFLIGHT",
    )

    step_source = inspect.getsource(runtime.MujocoNativeRecoveryWorld.step_native)
    require(
        step_source.index("raise NativeEnergyProjectionRefusal(diagnostic)")
        < step_source.index("state = self._state_frame")
        and runtime.MujocoSparseMomentImplicitStepRecoveryWorld.energy_work_preprojection_required
        is False
        and runtime.MujocoSignedWorkPreprojectionRecoveryWorld.energy_work_preprojection_required
        is True,
        "PREOBSERVATION_REFUSAL_ORDER",
    )

    expected_status = (
        "prospective_signed_work_preprojection_source_zero_world_development_"
        "passed_physics_blocked_pending_qualification"
    )
    release36 = find_gate(load(RELEASE_PATH), worker.GATE_ID)
    support36 = find_gate(load(SUPPORT_PATH), worker.GATE_ID)
    require(release36 is not None and support36 is not None, "LIVE_R36_MISSING")
    for live in (release36, support36):
        require(
            live["status"] == expected_status
            and live["contract_path"]
            == "sdk/recovery/r24d36_signed_work_preprojection_contract_v1.json"
            and live["route_id"] == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
            and live["projection_profile_id"] == projection.PROFILE_ID
            and live["r24d36_source_declared"] is True
            and live["r24d36_development_zero_world_gate_passed"] is True
            and live["r24d36_official_qualification_passed"] is False
            and live["maximum_physical_steps_authorized"] == 0
            and live["physical_execution_authorized"] is False,
            "LIVE_AUTHORITY",
        )

    wrapper = (
        SDK_ROOT / "run_qsdk_r24d36_signed_work_preprojection_zero_world.ps1"
    ).read_text(encoding="utf-8")
    require(
        "-Mode $Mode" in wrapper
        and "qsdk-r24d36-qualification-" in wrapper
        and "signed_work_preprojection_worker" in wrapper
        and "run_qsdk_r24d36_signed_work_preprojection" not in "\n".join(
            path for path in inventory if "physical" in path or "smoke" in path
        ),
        "ZERO_WORLD_ONLY_WRAPPER",
    )
    print(
        "QSDK_R24D36_SIGNED_WORK_PREPROJECTION_SOURCE_PASS "
        f"inventory={len(inventory)} changed={len(changed)} "
        f"controls={sum(controls.values())}/9 primitives=6/6 "
        "models=0 worlds=0 solver_steps=0 physical=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
