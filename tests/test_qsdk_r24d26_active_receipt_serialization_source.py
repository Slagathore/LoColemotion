"""Compact zero-world source/contract audit for QSDK-R24D26."""

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
    native_recovery_development as runtime,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d26_active_receipt_serialization_worker as worker,
)


CONTRACT_PATH = (
    SDK_ROOT / "recovery" / "r24d26_active_receipt_serialization_contract_v1.json"
)
CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"
RUNTIME_PATH = (
    ADAPTER_ROOT
    / "sporespore_mujoco_adapter"
    / "native_recovery_development.py"
)
ZERO_WORLD_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d26_active_receipt_serialization_zero_world.ps1"
)
PHYSICAL_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d26_active_receipt_serialization_development.ps1"
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
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    exact(contract["population_inference_declared"], False, "POPULATION")
    worker.load_contract_v1(CONTRACT_PATH)

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D25", "LINEAGE_GATE")
    exact(
        lineage["predecessor_result"],
        "closed_consumed_invalid_incomplete_active_application_receipt_serialization",
        "LINEAGE_RESULT",
    )
    exact(lineage["predecessor_may_rerun"], False, "LINEAGE_RERUN")
    change = contract["controlled_change"]
    exact(change["production_runtime_changed"], True, "RUNTIME_CHANGE")
    for unchanged in (
        "controller_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "physical_rig_changed",
        "initializer_changed",
        "contact_observer_changed",
        "schedule_changed",
        "seed_selector_changed",
        "held_out_selector_changed",
        "paired_evaluator_meaning_changed",
        "result_interpretation_changed",
    ):
        exact(change[unchanged], False, f"UNCHANGED:{unchanged}")
    authority = contract["threshold_and_margin_authority"]
    exact(authority["new_behavior_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(authority["new_empirical_threshold_count"], 0, "EMPIRICAL")
    exact(authority["new_margin_count"], 0, "MARGINS")

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
    exact(horizon["full_horizon_ghost_required"], False, "FULL_GHOST")
    exact(horizon["additional_seed_required"], False, "EXTRA_SEED")

    inventory = contract["source_inventory"]
    exact(len(inventory), 54, "INVENTORY_COUNT")
    exact(len(inventory), len(set(inventory)), "INVENTORY_UNIQUE")
    exact(
        [relative for relative in inventory if not (REPO_ROOT / relative).is_file()],
        [],
        "INVENTORY_MISSING",
    )
    runtime_text = RUNTIME_PATH.read_text(encoding="utf-8")
    for token in (
        "def prepare_active_recovery_host_command_v1(",
        "host_clamped[index] = bool(targets[index] != requested)",
        "def canonicalize_recovery_application_receipt_v1(",
        "type(value) is bool",
        "targets, host_clamped = prepare_active_recovery_host_command_v1(",
        "application, application_sha256 = canonicalize_recovery_application_receipt_v1(",
    ):
        require(token in runtime_text, f"PRODUCTION_TOKEN_MISSING:{token}")
    for wrapper, tokens in (
        (
            ZERO_WORLD_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
                '"QSDK-R24D26"',
                "qsdk_r24d26_active_receipt_serialization_worker",
            ),
        ),
        (
            PHYSICAL_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
                '"QSDK-R24D26"',
                "qsdk_r24d26_active_receipt_serialization_worker",
                '-ExpectedCellId "development_recovery_morphology_nominal"',
                "-ExpectedHorizonSteps 13",
            ),
        ),
    ):
        text = wrapper.read_text(encoding="utf-8")
        for token in tokens:
            require(token in text, f"WRAPPER_TOKEN_MISSING:{token}")

    with patch.object(route.mujoco, "MjModel", ForbiddenMjModel):
        receipt = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    exact(receipt["ok"], True, "PREFLIGHT_OK")
    exact(receipt["inherited_r24d25_control_count"], 23, "INHERITED_COUNT")
    exact(receipt["active_application_serialization_control_count"], 2, "SERIAL_COUNT")
    exact(receipt["active_application_serialization_controls_passed"], 2, "SERIAL_PASS")
    exact(receipt["negative_control_count"], 25, "NEGATIVE_COUNT")
    exact(receipt["negative_controls_passed"], 25, "NEGATIVE_PASS")
    exact(
        set(receipt["active_application_serialization_controls"]),
        {
            "production_active_receipt_canonicalizes_builtin_booleans",
            "historical_numpy_boolean_receipt_rejected_before_physics",
        },
        "SERIALIZATION_CONTROLS",
    )
    require(
        all(receipt["active_application_serialization_controls"].values()),
        "FORCED_FAILURE",
    )
    details = receipt["active_application_serialization_control_details"]
    exact(details["ordered_host_clamped_type_names"], ["bool"] * 8, "BOOL_TYPES")
    exact(
        details["historical_rejection"],
        "QSDK_R24D26_APPLICATION_HOST_CLAMP_TYPE:0",
        "HISTORICAL_REJECTION",
    )
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
        "QSDK_R24D26_ACTIVE_RECEIPT_SERIALIZATION_SOURCE_PASS "
        "inventory=54 inherited_controls=23 serialization_controls=2 controls=25 "
        "models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D26_ACTIVE_RECEIPT_SERIALIZATION_SOURCE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
