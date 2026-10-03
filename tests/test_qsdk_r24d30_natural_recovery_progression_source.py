"""Compact prospective source/contract audit for QSDK-R24D30."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
for path in (
    SDK_ROOT / "adapters/mujoco",
    SDK_ROOT / "python",
    SDK_ROOT / "conformance",
):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    require,
    sha256,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d30_natural_recovery_progression_worker as worker,
)


CONTRACT_PATH = SDK_ROOT / "recovery/r24d30_natural_recovery_progression_contract_v1.json"
R24D29_CONTRACT_PATH = SDK_ROOT / "recovery/r24d29_signed_clearance_semantics_contract_v1.json"
R24D29_CLOSURE_RELATIVE = (
    "sdk/recovery/r24d29_signed_clearance_semantics_qualification_closure_v1.json"
)
R24D28_CLOSURE_RELATIVE = (
    "sdk/recovery/r24d28_collection_refusal_observability_physical_closure_v1.json"
)
R24D27_CONTRACT_RELATIVE = (
    "sdk/recovery/r24d27_natural_recovery_progression_contract_v1.json"
)
SUPPORT_MATRIX_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
RELEASE_CONTRACT_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
R24D30_CLOSURE_PATH = (
    SDK_ROOT / "recovery/r24d30_natural_recovery_progression_physical_closure_v1.json"
)
DECLARATION_PARENT = "61068f3c8fba63ec77f648302cb6ec62bcb3f256"
PARENT_DEPENDENCIES = [
    R24D29_CLOSURE_RELATIVE,
    "tests/test_qsdk_r24d29_signed_clearance_semantics_qualification_closure.py",
    "sdk/conformance/content_addressed_zero_world_closure.py",
]
NEW_PATHS = [
    "sdk/recovery/r24d30_natural_recovery_progression_contract_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d30_natural_recovery_progression_worker.py",
    "tests/test_qsdk_r24d30_natural_recovery_progression_source.py",
    "sdk/run_qsdk_r24d30_natural_recovery_progression_zero_world.ps1",
    "sdk/run_qsdk_r24d30_natural_recovery_progression_development.ps1",
]


def _raw_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def _load_live_authority(path: Path) -> dict[str, Any]:
    """Load legacy live authorities whose retained history has duplicate keys."""

    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"LIVE_AUTHORITY_ROOT:{path}")
    return value


def _current_blob(relative: str) -> str:
    value = git(REPO_ROOT, "hash-object", "--", relative)
    assert isinstance(value, str)
    return value


def _parent_blob(relative: str) -> str:
    value = git(REPO_ROOT, "rev-parse", f"{DECLARATION_PARENT}:{relative}")
    assert isinstance(value, str)
    return value


def _new_at_parent(relative: str) -> bool:
    result = subprocess.run(
        ["git", "cat-file", "-e", f"{DECLARATION_PARENT}:{relative}"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
    )
    return result.returncode != 0


def _find_release_gate(value: dict[str, Any], gate_id: str) -> dict[str, Any]:
    gates = value.get("gates")
    require(isinstance(gates, list), "RELEASE_GATES")
    matches = [item for item in gates if isinstance(item, dict) and item.get("gate_id") == gate_id]
    require(len(matches) == 1, f"RELEASE_GATE_COUNT:{gate_id}")
    return matches[0]


def main() -> int:
    contract = load(CONTRACT_PATH)
    predecessor_contract = load(R24D29_CONTRACT_PATH)
    r24d29_closure_path = REPO_ROOT / R24D29_CLOSURE_RELATIVE
    r24d29_closure = load(r24d29_closure_path)
    r24d28_closure_path = REPO_ROOT / R24D28_CLOSURE_RELATIVE
    r24d28_closure = load(r24d28_closure_path)
    r24d27_contract_path = REPO_ROOT / R24D27_CONTRACT_RELATIVE
    r24d27_contract = load(r24d27_contract_path)

    exact(contract["schema_version"], worker.CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    exact(contract["gate_id"], worker.GATE_ID, "CONTRACT_GATE")
    exact(contract["campaign_id"], worker.CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    exact(contract["declaration_parent_commit"], DECLARATION_PARENT, "DECLARATION_PARENT")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["physical_question_declared"], True, "PHYSICAL_QUESTION")
    for key in (
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(contract[key], False, f"QUESTION_{key.upper()}")
    worker.load_contract_v1(CONTRACT_PATH)

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D29", "LINEAGE_GATE")
    exact(lineage["predecessor_source_commit"], r24d29_closure["source_commit"], "LINEAGE_SOURCE")
    exact(lineage["predecessor_closure_commit"], DECLARATION_PARENT, "LINEAGE_CLOSURE_COMMIT")
    exact(lineage["predecessor_closure_path"], R24D29_CLOSURE_RELATIVE, "LINEAGE_PATH")
    exact(lineage["predecessor_closure_raw_sha256"], _raw_sha256(r24d29_closure_path), "LINEAGE_HASH")
    exact(lineage["predecessor_result"], r24d29_closure["closure_status"], "LINEAGE_STATUS")
    exact(lineage["predecessor_official_zero_world_qualification_passed"], True, "LINEAGE_QUALIFIED")
    exact(lineage["predecessor_physical_question_opened"], False, "LINEAGE_PHYSICAL")
    exact(lineage["predecessor_may_requalify"], False, "LINEAGE_REQUALIFY")
    exact(r24d29_closure["qualification"]["controls_passed"], 45, "LINEAGE_CONTROLS")
    exact(r24d29_closure["qualification"]["world_attempt_count"], 0, "LINEAGE_WORLDS")
    for key in (
        "predecessor_result_rewritten",
        "predecessor_threshold_rewritten",
        "predecessor_evaluator_rewritten",
        "predecessor_interpretation_rewritten",
    ):
        exact(lineage[key], False, f"LINEAGE_{key.upper()}")

    physical = contract["physical_lineage"]
    exact(physical["latest_physical_gate_id"], "QSDK-R24D28", "PHYSICAL_GATE")
    exact(physical["latest_physical_closure_path"], R24D28_CLOSURE_RELATIVE, "PHYSICAL_PATH")
    exact(physical["latest_physical_closure_raw_sha256"], _raw_sha256(r24d28_closure_path), "PHYSICAL_HASH")
    exact(physical["latest_physical_result"], r24d28_closure["closure_status"], "PHYSICAL_STATUS")
    exact(physical["latest_physical_may_rerun"], False, "PHYSICAL_RERUN")
    exact(physical["latest_physical_accepted_prefix_length"], 82, "PHYSICAL_PREFIX")

    decision = contract["decision_authority"]
    exact(decision["gate_id"], "QSDK-R24D27", "DECISION_GATE")
    exact(decision["contract_path"], R24D27_CONTRACT_RELATIVE, "DECISION_PATH")
    exact(decision["contract_raw_sha256"], _raw_sha256(r24d27_contract_path), "DECISION_HASH")
    for key in (
        "decision_meaning_reused_exact",
        "positive_rule_reused_exact",
        "valid_negative_rule_reused_exact",
        "invalid_or_incomplete_rule_reused_exact",
    ):
        exact(decision[key], True, f"DECISION_{key.upper()}")

    change = contract["controlled_change"]
    exact(change["qualified_r24d29_semantics_consumed"], True, "CHANGE_SEMANTICS")
    exact(change["campaign_identity_changed"], True, "CHANGE_IDENTITY")
    exact(change["append_only_result_identity_changed"], True, "CHANGE_PUBLISHER")
    for key in (
        "production_runtime_changed",
        "portable_validation_changed_since_r24d29",
        "controller_changed",
        "native_physics_changed",
        "native_observer_changed",
        "morphology_changed",
        "initializer_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "production_schedule_changed",
        "natural_route_stop_rule_changed",
        "portable_phase_machine_changed",
        "portable_pose_classifier_changed",
        "progression_evaluator_meaning_changed",
        "held_out_selector_changed",
        "result_interpretation_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")

    threshold = contract["threshold_and_margin_authority"]
    predecessor_threshold = r24d27_contract["threshold_and_margin_authority"]
    for key in (
        "behavior_threshold_profile_id",
        "complete_threshold_authority_path",
        "entry_prone_confirm_steps",
        "distal_bearing_minimum_impulse_ns",
        "minimum_com_height_gain_m",
        "stance_height_ratio_min",
        "stance_torso_up_dot_min",
        "minimum_nonfoot_clearance_m",
        "maximum_forbidden_contact_impulse_ns",
        "establish_distal_support_timeout_steps",
        "raise_body_timeout_steps",
        "total_timeout_steps",
    ):
        exact(threshold[key], predecessor_threshold[key], f"THRESHOLD_{key.upper()}")
    exact(threshold["new_behavior_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(threshold["new_empirical_threshold_count"], 0, "NEW_EMPIRICAL")
    exact(threshold["new_margin_count"], 0, "NEW_MARGINS")
    exact(threshold["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")

    exact(
        contract["selected_development_cell"]["cell_id"],
        r24d27_contract["selected_development_cell"]["cell_id"],
        "CELL_ID",
    )
    exact(
        contract["selected_development_cell"]["seed"],
        r24d27_contract["selected_development_cell"]["seed"],
        "CELL_SEED",
    )
    horizon = contract["ghost_horizon"]
    for key in (
        "outer_steps_per_arm",
        "maximum_steps_per_arm",
        "native_substeps_per_outer_step",
        "paired_arm_count",
        "maximum_total_outer_steps",
        "maximum_total_native_solver_steps",
        "existing_route_stop_phases",
    ):
        exact(horizon[key], r24d27_contract["ghost_horizon"][key], f"HORIZON_{key.upper()}")
    exact(horizon["additional_seed_required"], False, "ADDITIONAL_SEED")
    exact(horizon["additional_physical_canary_required"], False, "ADDITIONAL_CANARY")

    gate = contract["complete_zero_world_gate"]
    exact(gate["inherited_r24d29_control_count"], 45, "GATE_INHERITED")
    exact(gate["successor_integration_control_count"], 3, "GATE_SUCCESSOR")
    exact(gate["total_negative_control_count"], 48, "GATE_TOTAL")
    for key in (
        "construct_mujoco_model",
        "instantiate_mujoco_data",
        "physics_state_modified",
        "full_seeded_ghost_required",
        "additional_physical_canary_required",
    ):
        exact(gate[key], False, f"GATE_{key.upper()}")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(gate[key], 0, f"GATE_{key.upper()}")

    freeze = contract["prospective_freeze"]
    exact(freeze["source_inventory_count"], 83, "FREEZE_INVENTORY")
    exact(freeze["r24d29_freeze_source_population_count"], 75, "FREEZE_R24D29")
    exact(freeze["declaration_parent_source_population_count"], 78, "FREEZE_PARENT")
    exact(freeze["declaration_parent_source_bindings_reused_exact"], 78, "FREEZE_REUSED")
    exact(freeze["new_campaign_source_count"], 5, "FREEZE_NEW")
    exact(freeze["new_campaign_source_paths"], NEW_PATHS, "FREEZE_NEW_PATHS")
    exact(freeze["development_zero_world_gate_passed"], True, "FREEZE_DEVELOPMENT")
    exact(freeze["development_zero_world_gate_pending"], False, "FREEZE_PENDING")
    exact(freeze["official_qualification_executed"], False, "FREEZE_QUALIFICATION")
    exact(freeze["physical_decision_executed"], False, "FREEZE_PHYSICAL")

    expected_parent = list(predecessor_contract["source_inventory"]) + PARENT_DEPENDENCIES
    exact(len(expected_parent), 78, "PARENT_POPULATION")
    exact(freeze["closure_dependency_source_paths_in_declaration_parent"], PARENT_DEPENDENCIES, "PARENT_DEPENDENCIES")
    inventory = contract["source_inventory"]
    exact(inventory, expected_parent + NEW_PATHS, "SOURCE_INVENTORY")
    exact(len(inventory), len(set(inventory)), "SOURCE_UNIQUE")
    for relative in expected_parent:
        require((REPO_ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
        exact(_current_blob(relative), _parent_blob(relative), f"SOURCE_REUSED:{relative}")
    for relative in NEW_PATHS:
        require((REPO_ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
        require(_new_at_parent(relative), f"SOURCE_NOT_NEW:{relative}")

    worker_source = (REPO_ROOT / NEW_PATHS[1]).read_text(encoding="utf-8")
    for token in (
        "semantics.run_zero_world_preflight(core)",
        "progression.compact_projection_v1(full)",
        "observability.build_collection_refusal_partial_v1(",
        "run_recovery_morphology_route_ghost(",
        '"qualified_signed_clearance_semantics_gate_id": "QSDK-R24D29"',
    ):
        require(token in worker_source, f"WORKER_TOKEN:{token}")
    require("mujoco.MjModel" not in worker_source, "WORKER_DIRECT_MODEL")
    require("mujoco.MjData" not in worker_source, "WORKER_DIRECT_DATA")

    zero_wrapper = (REPO_ROOT / NEW_PATHS[3]).read_text(encoding="utf-8")
    physical_wrapper = (REPO_ROOT / NEW_PATHS[4]).read_text(encoding="utf-8")
    require("run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1" in zero_wrapper, "ZERO_BASE")
    require("run_qsdk_r24d18_mujoco_native_recovery_development.ps1" in physical_wrapper, "PHYSICAL_BASE")
    for source in (zero_wrapper, physical_wrapper):
        require(worker.GATE_ID in source, "WRAPPER_GATE")
        require("qsdk_r24d30_natural_recovery_progression_worker" in source, "WRAPPER_WORKER")

    checks, _details = worker._successor_integration_controls()
    exact(len(checks), 3, "CONTROL_COUNT")
    exact(sum(checks.values()), 3, "CONTROL_PASSED")

    support = _load_live_authority(SUPPORT_MATRIX_PATH)
    boundary = support["morphology"]["recovery_morphology_boundary"]
    next_boundary = boundary["next_development_boundary"]
    release = _load_live_authority(RELEASE_CONTRACT_PATH)
    recovery_gate = _find_release_gate(release, "QSDK-R24")
    if next_boundary["gate_id"] == worker.GATE_ID:
        live_state = "prospective"
        exact(
            next_boundary["status"],
            "prospective_freeze_authored_pending_clean_pushed_qualification",
            "SUPPORT_STATUS",
        )
        exact(
            next_boundary["contract_path"],
            CONTRACT_PATH.relative_to(REPO_ROOT).as_posix(),
            "SUPPORT_CONTRACT",
        )
        exact(
            next_boundary["contract_raw_sha256"],
            _raw_sha256(CONTRACT_PATH),
            "SUPPORT_CONTRACT_HASH",
        )
        latest = recovery_gate["proof"]["latest_recovery_boundary"]
        exact(latest["next_gate_id"], worker.GATE_ID, "RELEASE_NEXT_GATE")
        exact(
            latest["current_next_work"],
            "qualify_the_clean_pushed_r24d30_natural_recovery_progression_successor_before_any_physics",
            "RELEASE_NEXT_WORK",
        )
    else:
        live_state = "closed"
        require(R24D30_CLOSURE_PATH.is_file(), "R24D30_CLOSURE_MISSING")
        closure = load(R24D30_CLOSURE_PATH)
        exact(next_boundary["gate_id"], "QSDK-R24D31", "SUPPORT_NEXT_GATE")
        exact(
            next_boundary["status"],
            "not_yet_frozen_physical_execution_blocked",
            "SUPPORT_NEXT_STATUS",
        )
        exact(next_boundary["predecessor_gate_id"], worker.GATE_ID, "SUPPORT_PREDECESSOR")
        exact(
            next_boundary["predecessor_closure_raw_sha256"],
            _raw_sha256(R24D30_CLOSURE_PATH),
            "SUPPORT_CLOSURE_HASH",
        )
        completed = boundary["latest_development_attempt"]
        exact(completed["gate_id"], worker.GATE_ID, "SUPPORT_COMPLETED_GATE")
        exact(completed["source_commit"], closure["source_commit"], "SUPPORT_COMPLETED_SOURCE")
        exact(completed["contract_raw_sha256"], _raw_sha256(CONTRACT_PATH), "SUPPORT_COMPLETED_CONTRACT")
        exact(completed["closure_raw_sha256"], _raw_sha256(R24D30_CLOSURE_PATH), "SUPPORT_COMPLETED_CLOSURE")
        exact(completed["execution_valid"], True, "SUPPORT_COMPLETED_VALID")
        exact(completed["decision_positive"], False, "SUPPORT_COMPLETED_DECISION")
        exact(completed["r24d30_may_be_rerun"], False, "SUPPORT_COMPLETED_RERUN")
        proof = recovery_gate["proof"]
        release_completed = proof["latest_recovery_attempt"]
        exact(release_completed["gate_id"], worker.GATE_ID, "RELEASE_COMPLETED_GATE")
        exact(release_completed["source_commit"], closure["source_commit"], "RELEASE_COMPLETED_SOURCE")
        exact(release_completed["closure_raw_sha256"], _raw_sha256(R24D30_CLOSURE_PATH), "RELEASE_COMPLETED_CLOSURE")
        exact(release_completed["decision_positive"], False, "RELEASE_COMPLETED_DECISION")
        exact(proof["next_recovery_boundary"]["gate_id"], "QSDK-R24D31", "RELEASE_NEXT_GATE")
        exact(proof["next_recovery_boundary"]["physical_execution_authorized"], False, "RELEASE_NEXT_PHYSICAL")
    exact(next_boundary["physical_execution_authorized"], False, "SUPPORT_PHYSICAL")

    claims = contract["claim_boundary"]
    exact(claims["development_zero_world_gate_passed"], True, "CLAIM_DEVELOPMENT")
    for key, value in claims.items():
        if key.endswith("_retained") or key == "development_zero_world_gate_passed":
            exact(value, True, f"CLAIM_{key.upper()}")
        else:
            exact(value, False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D30_NATURAL_RECOVERY_PROGRESSION_SOURCE_PASS "
        "inventory=83 reused_parent_sources=78 new_sources=5 "
        "inherited_controls=45 successor_controls=3 controls=48 "
        f"models=0 worlds=0 solver_steps=0 live_state={live_state}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D30_NATURAL_RECOVERY_PROGRESSION_SOURCE_FAIL:{error}", file=sys.stderr)
        raise
