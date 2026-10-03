"""Compact zero-world source/contract audit for QSDK-R24D23."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
ADAPTER_ROOT = SDK_ROOT / "adapters" / "mujoco"
SDK_PYTHON = SDK_ROOT / "python"
for entry in (SDK_PYTHON, ADAPTER_ROOT):
    if str(entry) not in sys.path:
        sys.path.insert(0, str(entry))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import recovery_morphology_route as route  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d23_recovery_morphology_worker as worker,
)


CONTRACT_PATH = (
    SDK_ROOT
    / "recovery"
    / "r24d23_mujoco_recovery_morphology_route_contract_v1.json"
)
CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"
ZERO_WORLD_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d23_mujoco_recovery_morphology_zero_world.ps1"
)
PHYSICAL_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d23_mujoco_recovery_morphology_development.ps1"
)


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


class ForbiddenMjModel:
    @staticmethod
    def from_xml_string(*_args: object, **_kwargs: object) -> object:
        raise AuditFailure("ZERO_WORLD_CONSTRUCTED_MJMODEL")


def main() -> int:
    require(CORE_LIBRARY.is_file(), "CORE_LIBRARY_MISSING")
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    exact(contract["schema_version"], worker.CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    exact(contract["gate_id"], worker.GATE_ID, "CONTRACT_GATE")
    exact(contract["campaign_id"], worker.CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(
        contract["ledger_scope"],
        {
            "subsystem": "recovery",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "development_ghost",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    worker.load_contract_v1(CONTRACT_PATH)

    inventory = contract["source_inventory"]
    require(isinstance(inventory, list) and inventory, "INVENTORY_EMPTY")
    exact(len(inventory), len(set(inventory)), "INVENTORY_UNIQUE")
    missing = [relative for relative in inventory if not (REPO_ROOT / relative).is_file()]
    exact(missing, [], "INVENTORY_MISSING")

    zero_text = ZERO_WORLD_WRAPPER.read_text(encoding="utf-8")
    physical_text = PHYSICAL_WRAPPER.read_text(encoding="utf-8")
    for text, required in (
        (
            zero_text,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
                '"QSDK-R24D23"',
                "qsdk_r24d23_recovery_morphology_worker",
            ),
        ),
        (
            physical_text,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
                '"QSDK-R24D23"',
                "qsdk_r24d23_recovery_morphology_worker",
                '-ExpectedCellId "development_recovery_morphology_nominal"',
                "-ExpectedHorizonSteps 2",
            ),
        ),
    ):
        for token in required:
            require(token in text, f"WRAPPER_TOKEN_MISSING:{token}")

    core = LocomotionCore(CORE_LIBRARY)
    with patch.object(route.mujoco, "MjModel", ForbiddenMjModel):
        receipt = route.run_zero_world_preflight(core)
    exact(receipt["ok"], True, "PREFLIGHT_OK")
    exact(receipt["route_id"], route.ROUTE_ID, "ROUTE_ID")
    exact(
        receipt["recovery_morphology_spec_sha256"],
        route.EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "RECOVERY_HASH",
    )
    exact(receipt["negative_control_count"], 4, "NEGATIVE_COUNT")
    exact(receipt["negative_controls_passed"], 4, "NEGATIVE_PASS")
    exact(
        receipt["typed_refusal_control"]["support_status"],
        "unsupported_prone_geometry_infeasible",
        "TYPED_REFUSAL",
    )
    for field in (
        "model_construction_count",
        "data_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(receipt[field], 0, f"ZERO_WORLD:{field}")
    exact(receipt["physics_state_modified"], False, "PHYSICS_STATE")
    exact(receipt["physical_question_opened"], False, "PHYSICAL_QUESTION")
    exact(receipt["prone_to_standing_claimed"], False, "PRONE_CLAIM")
    exact(receipt["physical_acceptance_authority"], False, "ACCEPTANCE")
    exact(receipt["release_authority"], False, "RELEASE")

    print(
        "QSDK_R24D23_MUJOCO_RECOVERY_MORPHOLOGY_SOURCE_PASS "
        f"inventory={len(inventory)} joints=8 negative_controls=4 "
        "models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D23_MUJOCO_RECOVERY_MORPHOLOGY_SOURCE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
