"""Compact zero-world source/contract audit for QSDK-R24D25."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
ADAPTER_ROOT = SDK_ROOT / "adapters" / "mujoco"
for entry in (SDK_ROOT / "python", ADAPTER_ROOT):
    if str(entry) not in sys.path:
        sys.path.insert(0, str(entry))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import recovery_morphology_route as route  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d25_first_active_command_worker as worker,
)


CONTRACT_PATH = SDK_ROOT / "recovery" / "r24d25_first_active_command_contract_v1.json"
CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"
ZERO_WORLD_WRAPPER = SDK_ROOT / "run_qsdk_r24d25_first_active_command_zero_world.ps1"
PHYSICAL_WRAPPER = SDK_ROOT / "run_qsdk_r24d25_first_active_command_development.ps1"


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
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    exact(contract["population_inference_declared"], False, "POPULATION")
    worker.load_contract_v1(CONTRACT_PATH)

    horizon = contract["ghost_horizon"]
    exact(horizon["entry_prone_confirm_steps"], 12, "CONFIRM_STEPS")
    exact(horizon["outer_steps_per_arm"], 13, "HORIZON")
    exact(
        horizon["first_active_native_application_outer_index_zero_based"],
        12,
        "FIRST_ACTIVE_INDEX",
    )
    exact(horizon["maximum_total_outer_steps"], 26, "OUTER_STEPS")
    exact(horizon["maximum_total_native_solver_steps"], 130, "SOLVER_STEPS")
    require("exact shortest physical horizon" in horizon["adequacy"], "ADEQUACY")
    authority = contract["threshold_and_margin_authority"]
    exact(authority["new_behavior_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(authority["new_empirical_threshold_count"], 0, "EMPIRICAL")
    exact(authority["new_margin_count"], 0, "MARGINS")

    inventory = contract["source_inventory"]
    exact(len(inventory), 47, "INVENTORY_COUNT")
    exact(len(inventory), len(set(inventory)), "INVENTORY_UNIQUE")
    exact(
        [relative for relative in inventory if not (REPO_ROOT / relative).is_file()],
        [],
        "INVENTORY_MISSING",
    )
    for wrapper, tokens in (
        (
            ZERO_WORLD_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
                '"QSDK-R24D25"',
                "qsdk_r24d25_first_active_command_worker",
            ),
        ),
        (
            PHYSICAL_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
                '"QSDK-R24D25"',
                "qsdk_r24d25_first_active_command_worker",
                '-ExpectedCellId "development_recovery_morphology_nominal"',
                "-ExpectedHorizonSteps 13",
            ),
        ),
    ):
        text = wrapper.read_text(encoding="utf-8")
        for token in tokens:
            require(token in text, f"WRAPPER_TOKEN_MISSING:{token}")

    positive = worker._positive_control_facts()
    require(all(worker.evaluate_command_coverage_facts_v1(positive).values()), "POSITIVE")
    with patch.object(route.mujoco, "MjModel", ForbiddenMjModel):
        receipt = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    exact(receipt["ok"], True, "PREFLIGHT_OK")
    exact(receipt["inherited_r24d24_control_count"], 18, "INHERITED_COUNT")
    exact(receipt["command_coverage_control_count"], 5, "COMMAND_COUNT")
    exact(receipt["command_coverage_controls_passed"], 5, "COMMAND_PASS")
    exact(receipt["negative_control_count"], 23, "NEGATIVE_COUNT")
    exact(receipt["negative_controls_passed"], 23, "NEGATIVE_PASS")
    exact(
        set(receipt["command_coverage_decision_controls"]),
        {
            "twelve_step_horizon_rejected",
            "missing_candidate_application_rejected",
            "early_candidate_application_rejected",
            "matched_zero_actuation_rejected",
            "zero_native_impulse_rejected",
        },
        "FORCED_FAILURE_CONTROLS",
    )
    require(all(receipt["command_coverage_decision_controls"].values()), "FORCED_FAILURE")
    for field in (
        "model_construction_count",
        "data_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(receipt[field], 0, f"ZERO_WORLD:{field}")
    exact(receipt["physics_state_modified"], False, "PHYSICS_STATE")
    exact(receipt["physical_question_opened"], False, "PHYSICAL_QUESTION")
    exact(receipt["prone_to_standing_claimed"], False, "PRONE_CLAIM")
    exact(receipt["physical_acceptance_authority"], False, "ACCEPTANCE")
    exact(receipt["release_authority"], False, "RELEASE")

    print(
        "QSDK_R24D25_FIRST_ACTIVE_COMMAND_SOURCE_PASS "
        "inventory=47 inherited_controls=18 command_controls=5 controls=23 "
        "models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, KeyError, TypeError, ValueError) as error:
        print(f"QSDK_R24D25_FIRST_ACTIVE_COMMAND_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
