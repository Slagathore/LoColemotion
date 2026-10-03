"""Compact zero-world source/contract audit for QSDK-R24D27."""

from __future__ import annotations

import hashlib
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
    qsdk_r24d27_natural_recovery_progression_worker as worker,
)


CONTRACT_PATH = (
    SDK_ROOT / "recovery" / "r24d27_natural_recovery_progression_contract_v1.json"
)
PREDECESSOR_CLOSURE_PATH = (
    SDK_ROOT
    / "recovery"
    / "r24d26_active_receipt_serialization_positive_closure_v1.json"
)
CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"
RUNTIME_PATH = (
    ADAPTER_ROOT
    / "sporespore_mujoco_adapter"
    / "native_recovery_development.py"
)
ZERO_WORLD_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d27_natural_recovery_progression_zero_world.ps1"
)
PHYSICAL_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d27_natural_recovery_progression_development.ps1"
)


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


class ForbiddenMjModel:
    @staticmethod
    def from_xml_string(*_args: object, **_kwargs: object) -> object:
        raise AuditFailure("ZERO_WORLD_CONSTRUCTED_MJMODEL")


def predecessor_evidence() -> tuple[dict[str, object], dict[str, object]]:
    exact(
        raw_sha256(PREDECESSOR_CLOSURE_PATH),
        worker.R24D26_CLOSURE_SHA256,
        "PREDECESSOR_CLOSURE_HASH",
    )
    closure = json.loads(PREDECESSOR_CLOSURE_PATH.read_text(encoding="utf-8"))
    qualification = closure["qualification"]
    qualification_path = (
        Path(str(qualification["evidence_root"])) / str(qualification["receipt_path"])
    )
    exact(
        raw_sha256(qualification_path),
        qualification["receipt_raw_sha256"],
        "PREDECESSOR_QUALIFICATION_HASH",
    )
    receipt = json.loads(qualification_path.read_text(encoding="utf-8"))
    return closure, receipt


def verify_predecessor_source_reuse(receipt: dict[str, object]) -> None:
    manifest = receipt["source_manifest"]
    require(isinstance(manifest, list), "PREDECESSOR_SOURCE_MANIFEST")
    exact(len(manifest), 54, "PREDECESSOR_SOURCE_COUNT")
    for item in manifest:
        require(isinstance(item, dict), "PREDECESSOR_SOURCE_ITEM")
        path = REPO_ROOT / str(item["path"])
        require(path.is_file(), f"PREDECESSOR_SOURCE_MISSING:{item['path']}")
        exact(
            raw_sha256(path),
            item["raw_sha256"],
            f"PREDECESSOR_SOURCE_DRIFT:{item['path']}",
        )


def replay_retained_incomplete_projection(closure: dict[str, object]) -> None:
    physical = closure["physical_attempt"]
    artifacts = closure["retained_physical_artifacts"]
    require(isinstance(physical, dict), "PREDECESSOR_PHYSICAL")
    require(isinstance(artifacts, list), "PREDECESSOR_ARTIFACTS")
    matches = [
        item
        for item in artifacts
        if isinstance(item, dict) and item.get("path") == "paired_full_result.json"
    ]
    exact(len(matches), 1, "PREDECESSOR_FULL_RESULT_ENTRY")
    full_path = Path(str(physical["evidence_root"])) / "paired_full_result.json"
    exact(raw_sha256(full_path), matches[0]["raw_sha256"], "PREDECESSOR_FULL_HASH")
    exact(full_path.stat().st_size, matches[0]["byte_length"], "PREDECESSOR_FULL_SIZE")
    envelope = json.loads(full_path.read_text(encoding="utf-8"))
    projection = worker.compact_projection_v1(envelope["result"])
    exact(projection["execution_valid"], False, "PREDECESSOR_NATURAL_STOP")
    exact(projection["decision_positive"], False, "PREDECESSOR_PROGRESSION")
    exact(projection["candidate"]["outer_step_count"], 13, "PREDECESSOR_CANDIDATE")
    exact(
        projection["candidate"]["final_phase"],
        "establish_distal_support",
        "PREDECESSOR_CANDIDATE_PHASE",
    )
    exact(
        projection["matched_zero_command"]["outer_step_count"],
        13,
        "PREDECESSOR_MATCHED_ZERO",
    )


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

    change = contract["controlled_change"]
    exact(change["development_execution_bound_changed"], True, "BOUND_CHANGE")
    exact(change["campaign_projection_changed"], True, "PROJECTION_CHANGE")
    for unchanged in (
        "production_runtime_changed",
        "controller_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "physical_rig_changed",
        "initializer_changed",
        "contact_observer_changed",
        "production_schedule_changed",
        "natural_route_stop_rule_changed",
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
    exact(horizon["outer_steps_per_arm"], 1200, "HORIZON")
    exact(horizon["maximum_steps_per_arm"], 1200, "MAXIMUM")
    exact(horizon["maximum_total_outer_steps"], 2400, "OUTER_MAXIMUM")
    exact(horizon["maximum_total_native_solver_steps"], 12000, "SOLVER_MAXIMUM")
    exact(
        set(horizon["existing_route_stop_phases"]),
        worker.NATURAL_STOP_PHASES,
        "STOP_PHASES",
    )

    inventory = contract["source_inventory"]
    exact(len(inventory), 61, "INVENTORY_COUNT")
    exact(len(inventory), len(set(inventory)), "INVENTORY_UNIQUE")
    exact(
        [relative for relative in inventory if not (REPO_ROOT / relative).is_file()],
        [],
        "INVENTORY_MISSING",
    )
    runtime_text = RUNTIME_PATH.read_text(encoding="utf-8")
    for token in (
        "_require(1 <= horizon_steps <= 1200, \"QSDK_R24D18_HORIZON\")",
        "if phase in _TERMINAL_PHASES:",
        "if phase in _STANCE_PHASES:",
        "break",
    ):
        require(token in runtime_text, f"NATURAL_STOP_TOKEN_MISSING:{token}")
    for wrapper, tokens in (
        (
            ZERO_WORLD_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
                '"QSDK-R24D27"',
                "qsdk_r24d27_natural_recovery_progression_worker",
            ),
        ),
        (
            PHYSICAL_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
                '"QSDK-R24D27"',
                "qsdk_r24d27_natural_recovery_progression_worker",
                '-ExpectedCellId "development_recovery_morphology_nominal"',
                "-ExpectedHorizonSteps 1200",
            ),
        ),
    ):
        text = wrapper.read_text(encoding="utf-8")
        for token in tokens:
            require(token in text, f"WRAPPER_TOKEN_MISSING:{token}")

    closure, receipt = predecessor_evidence()
    verify_predecessor_source_reuse(receipt)
    replay_retained_incomplete_projection(closure)

    with patch.object(route.mujoco, "MjModel", ForbiddenMjModel):
        preflight = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY))
    exact(preflight["ok"], True, "PREFLIGHT_OK")
    exact(preflight["inherited_r24d26_control_count"], 25, "INHERITED_COUNT")
    exact(preflight["natural_progression_control_count"], 6, "PROGRESSION_COUNT")
    exact(preflight["natural_progression_controls_passed"], 6, "PROGRESSION_PASS")
    exact(preflight["negative_control_count"], 31, "NEGATIVE_COUNT")
    exact(preflight["negative_controls_passed"], 31, "NEGATIVE_PASS")
    require(
        all(preflight["natural_progression_decision_controls"].values()),
        "FORCED_FAILURE",
    )
    exact(preflight["production_route_stop_semantics_reused"], True, "STOP_REUSE")
    exact(preflight["new_behavior_threshold_count"], 0, "PREFLIGHT_THRESHOLDS")
    exact(preflight["new_margin_count"], 0, "PREFLIGHT_MARGINS")
    for field in (
        "model_construction_count",
        "data_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(preflight[field], 0, f"ZERO_WORLD:{field}")
    exact(preflight["physics_state_modified"], False, "PHYSICS_STATE")
    exact(preflight["physical_question_opened"], False, "PHYSICAL_QUESTION")
    exact(preflight["prone_to_standing_claimed"], False, "PRONE_CLAIM")
    exact(preflight["physical_acceptance_authority"], False, "ACCEPTANCE")
    exact(preflight["release_authority"], False, "RELEASE")

    print(
        "QSDK_R24D27_NATURAL_RECOVERY_PROGRESSION_SOURCE_PASS "
        "inventory=61 reused_sources=54 inherited_controls=25 "
        "progression_controls=6 controls=31 retained_negative=1 "
        "models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D27_NATURAL_RECOVERY_PROGRESSION_SOURCE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
