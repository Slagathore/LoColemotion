"""Compact zero-world source/contract audit for QSDK-R24D29."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
for path in (SDK_ROOT / "adapters/mujoco", SDK_ROOT / "python"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d29_signed_clearance_semantics_worker as worker,
)


CONTRACT_PATH = SDK_ROOT / "recovery/r24d29_signed_clearance_semantics_contract_v1.json"
FIXTURE_PATH = SDK_ROOT / "recovery/r24d29_retained_step82_clearance_fixture_v1.json"
CLOSURE_PATH = (
    SDK_ROOT
    / "recovery/r24d29_signed_clearance_semantics_qualification_closure_v1.json"
)
PREDECESSOR_CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d28_collection_refusal_observability_contract_v1.json"
)
PREDECESSOR_CLOSURE_RELATIVE = (
    "sdk/recovery/r24d28_collection_refusal_observability_physical_closure_v1.json"
)
PREDECESSOR_CLOSURE_AUDIT_RELATIVE = (
    "tests/test_qsdk_r24d28_collection_refusal_observability_physical_closure.py"
)
SUPPORT_MATRIX_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"
CORE_VALIDATOR_PATHS = {
    "sdk/core/src/recovery.rs",
    "sdk/core/src/recovery_runtime.rs",
}
NEW_PATHS = {
    "sdk/recovery/r24d29_signed_clearance_semantics_contract_v1.json",
    "sdk/recovery/r24d29_retained_step82_clearance_fixture_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d29_signed_clearance_semantics_worker.py",
    "tests/test_qsdk_r24d29_signed_clearance_semantics_source.py",
    "sdk/run_qsdk_r24d29_signed_clearance_semantics_zero_world.ps1",
}


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def load(path: Path, *, strict: bool = True) -> dict[str, Any]:
    value = json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicates if strict else None,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*arguments: str, binary: bool = False, check: bool = True) -> bytes | str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=check,
        capture_output=True,
        text=not binary,
        encoding=None if binary else "utf-8",
    )
    return result.stdout if binary else result.stdout.strip()


def parent_bytes(commit: str, relative: str) -> bytes:
    value = git("show", f"{commit}:{relative}", binary=True)
    require(isinstance(value, bytes), f"PARENT_BYTES:{relative}")
    return value


def current_blob(relative: str) -> str:
    value = git("hash-object", "--", relative)
    require(isinstance(value, str), f"CURRENT_BLOB:{relative}")
    return value


def parent_blob(commit: str, relative: str) -> str:
    value = git("rev-parse", f"{commit}:{relative}")
    require(isinstance(value, str), f"PARENT_BLOB:{relative}")
    return value


def main() -> int:
    contract = load(CONTRACT_PATH)
    fixture = load(FIXTURE_PATH)
    predecessor = load(PREDECESSOR_CONTRACT_PATH)
    closure_path = REPO_ROOT / PREDECESSOR_CLOSURE_RELATIVE
    closure = load(closure_path)

    exact(contract["schema_version"], worker.CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    exact(contract["gate_id"], worker.GATE_ID, "CONTRACT_GATE")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["physical_question_declared"], False, "PHYSICAL_QUESTION")
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    exact(contract["population_inference_declared"], False, "POPULATION")

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D28", "LINEAGE_GATE")
    exact(lineage["predecessor_closure_commit"], "ce03cebc4d3f3a7226244684c2f99bf25cf99bcc", "LINEAGE_COMMIT")
    exact(lineage["predecessor_closure_path"], PREDECESSOR_CLOSURE_RELATIVE, "LINEAGE_PATH")
    exact(lineage["predecessor_closure_raw_sha256"], raw_sha256(closure_path), "LINEAGE_DIGEST")
    exact(lineage["predecessor_may_rerun"], False, "LINEAGE_RERUN")
    for key in (
        "predecessor_result_rewritten",
        "predecessor_threshold_rewritten",
        "predecessor_interpretation_rewritten",
    ):
        exact(lineage[key], False, f"LINEAGE_{key.upper()}")
    exact(closure["closure_status"], lineage["predecessor_result"], "LINEAGE_STATUS")

    change = contract["controlled_change"]
    exact(change["portable_validation_changed"], True, "VALIDATION_CHANGE")
    exact(change["shared_validator_factored"], True, "VALIDATOR_FACTOR")
    for key in (
        "native_observer_changed",
        "native_physics_changed",
        "controller_changed",
        "morphology_changed",
        "initializer_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "portable_phase_machine_changed",
        "portable_pose_classifier_changed",
        "portable_evaluator_changed",
        "held_out_selector_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")
    semantics = contract["semantic_authority"]
    exact(semantics["empirical_threshold_selected"], False, "EMPIRICAL_THRESHOLD")
    exact(semantics["new_behavior_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(semantics["new_empirical_threshold_count"], 0, "NEW_EMPIRICAL")
    exact(semantics["new_margin_count"], 0, "NEW_MARGINS")

    exact(fixture["schema_version"], worker.FIXTURE_SCHEMA, "FIXTURE_SCHEMA")
    exact(fixture["gate_id"], worker.GATE_ID, "FIXTURE_GATE")
    exact(fixture["question_class"], "development", "FIXTURE_CLASS")
    exact(fixture["physical_question_declared"], False, "FIXTURE_PHYSICAL")
    source = fixture["source"]
    exact(source["predecessor_closure_path"], PREDECESSOR_CLOSURE_RELATIVE, "FIXTURE_CLOSURE")
    exact(source["predecessor_closure_raw_sha256"], raw_sha256(closure_path), "FIXTURE_CLOSURE_DIGEST")
    exact(source["partial_result_raw_sha256"], contract["retained_fixture"]["source_partial_result_raw_sha256"], "FIXTURE_PARTIAL_DIGEST")
    identity = fixture["exact_fixture_identity"]
    for key in (
        "current_observation_canonical_sha256",
        "current_collection_request_canonical_sha256",
        "current_step_request_canonical_sha256",
    ):
        exact(identity[key], contract["retained_fixture"][key], f"FIXTURE_{key.upper()}")
    exact(identity["semantic_step"], 82, "FIXTURE_STEP")
    exact(identity["accepted_prefix_length"], 82, "FIXTURE_PREFIX")
    exact(fixture["historical_result"]["historical_result_rewritten"], False, "HISTORICAL_REWRITE")
    exact(fixture["historical_result"]["same_identity_rerun_permitted"], False, "HISTORICAL_RERUN")
    exact(fixture["successor_semantics"]["negative_clearance_without_native_contact_is_valid_observation_data"], True, "NEGATIVE_CLEARANCE_DATA")
    exact(fixture["successor_semantics"]["negative_clearance_remains_a_failing_physical_clearance_measurement"], True, "NEGATIVE_CLEARANCE_GATE")
    exact(fixture["successor_semantics"]["invented_contact_provenance_permitted"], False, "CONTACT_SYNTHESIS")
    exact(fixture["successor_semantics"]["clearance_clamping_permitted"], False, "CLEARANCE_CLAMP")
    exact(fixture["mutation_control_count"], 8, "FIXTURE_MUTATION_COUNT")
    exact(fixture["mutation_population"], contract["complete_zero_world_gate"]["required_controls"], "FIXTURE_MUTATION_ORDER")

    freeze = contract["prospective_freeze"]
    parent = freeze["declaration_parent_commit"]
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", parent, "HEAD"],
        cwd=REPO_ROOT,
        capture_output=True,
    )
    exact(ancestor.returncode, 0, "DECLARATION_PARENT_ANCESTOR")
    predecessor_base = set(predecessor["source_inventory"]) | {
        PREDECESSOR_CLOSURE_RELATIVE,
        PREDECESSOR_CLOSURE_AUDIT_RELATIVE,
    }
    source_inventory = contract["source_inventory"]
    exact(len(source_inventory), 75, "SOURCE_COUNT")
    exact(len(set(source_inventory)), 75, "SOURCE_UNIQUE")
    exact(set(source_inventory), predecessor_base | NEW_PATHS, "SOURCE_UNION")
    exact(len(predecessor_base), 70, "PREDECESSOR_BASE_COUNT")
    exact(set(freeze["changed_predecessor_source_paths"]), CORE_VALIDATOR_PATHS, "DECLARED_CHANGED")
    exact(set(freeze["new_source_paths"]), NEW_PATHS, "DECLARED_NEW")
    exact(freeze["predecessor_source_population_count"], 70, "DECLARED_PREDECESSOR_COUNT")
    exact(freeze["reused_predecessor_source_count"], 68, "DECLARED_REUSED_COUNT")
    exact(freeze["changed_predecessor_source_count"], 2, "DECLARED_CHANGED_COUNT")
    exact(freeze["new_source_count"], 5, "DECLARED_NEW_COUNT")
    exact(freeze["source_inventory_count"], 75, "DECLARED_SOURCE_COUNT")

    reused = 0
    changed = 0
    for relative in sorted(predecessor_base):
        path = REPO_ROOT / relative
        require(path.is_file(), f"SOURCE_MISSING:{relative}")
        historical = parent_bytes(parent, relative)
        if relative in CORE_VALIDATOR_PATHS:
            require(path.read_bytes() != historical, f"EXPECTED_CHANGE_MISSING:{relative}")
            changed += 1
        else:
            exact(path.read_bytes(), historical, f"REUSED_BYTES:{relative}")
            exact(path.stat().st_size, len(historical), f"REUSED_LENGTH:{relative}")
            exact(current_blob(relative), parent_blob(parent, relative), f"REUSED_BLOB:{relative}")
            reused += 1
    exact(reused, 68, "REUSED_COUNT")
    exact(changed, 2, "CHANGED_COUNT")
    for relative in NEW_PATHS:
        require((REPO_ROOT / relative).is_file(), f"NEW_SOURCE_MISSING:{relative}")
        absent = subprocess.run(
            ["git", "cat-file", "-e", f"{parent}:{relative}"],
            cwd=REPO_ROOT,
            capture_output=True,
        )
        require(absent.returncode != 0, f"NEW_SOURCE_ALREADY_AT_PARENT:{relative}")

    recovery_source = (SDK_ROOT / "core/src/recovery.rs").read_text(encoding="utf-8")
    runtime_source = (SDK_ROOT / "core/src/recovery_runtime.rs").read_text(encoding="utf-8")
    helper = "validate_body_clearance_observation_v1"
    exact(recovery_source.count(f"fn {helper}("), 1, "SHARED_HELPER_DEFINITION")
    exact(recovery_source.count(f"{helper}("), 2, "RECOVERY_HELPER_CALL")
    exact(runtime_source.count(f"{helper}("), 1, "RUNTIME_HELPER_CALL")
    for token in (
        "Native contact presence/provenance and signed geometric clearance are",
        "independent source measurements",
        'return Err("present_nonfoot_contact_provenance_invalid".to_owned())',
        'return Err("absent_nonfoot_contact_values_invalid".to_owned())',
    ):
        require(token in recovery_source, f"CORE_TOKEN:{token}")
    for forbidden in (
        "body.minimum_nonfoot_clearance_m > 0.0",
        "body.minimum_nonfoot_clearance_m < 0.0",
    ):
        require(forbidden not in recovery_source, f"OLD_COUPLING_RECOVERY:{forbidden}")
        require(forbidden not in runtime_source, f"OLD_COUPLING_RUNTIME:{forbidden}")

    wrapper = (SDK_ROOT / "run_qsdk_r24d29_signed_clearance_semantics_zero_world.ps1").read_text(encoding="utf-8")
    for token in (
        "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
        '"QSDK-R24D29"',
        "qsdk_r24d29_signed_clearance_semantics_worker",
        'ValidateSet("development", "qualification")',
    ):
        require(token in wrapper, f"WRAPPER_TOKEN:{token}")

    gate = contract["complete_zero_world_gate"]
    exact(gate["must_pass_before_physics"], True, "GATE_REQUIRED")
    exact(gate["inherited_r24d28_control_count"], 37, "INHERITED_CONTROLS")
    exact(gate["signed_clearance_control_count"], 8, "DIRECT_CONTROLS")
    exact(gate["total_negative_control_count"], 45, "TOTAL_CONTROLS")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(gate[key], 0, f"GATE_{key.upper()}")
    exact(gate["physics_state_modified"], False, "GATE_PHYSICS")
    exact(gate["full_seeded_ghost_required"], False, "GATE_FULL_GHOST")
    exact(gate["additional_physical_canary_required"], False, "GATE_CANARY")
    qualification = contract["qualification_and_closure"]
    exact(qualification["qualification_result_pending"], True, "QUALIFICATION_PENDING")
    exact(qualification["r24d29_physical_execution_permitted"], False, "R24D29_PHYSICAL")
    exact(qualification["successful_qualification_closes_r24d29"], True, "QUALIFICATION_CLOSES")
    exact(qualification["next_physical_successor_gate_id"], "QSDK-R24D30", "NEXT_PHYSICAL_GATE")
    exact(contract["held_out_seal"]["held_out_cell_access_count"], 0, "HELDOUT")
    exact(contract["held_out_seal"]["held_out_selector_invocation_count"], 0, "SELECTOR")
    claim = contract["claim_boundary"]
    exact(claim["development_zero_world_gate_passed"], True, "CLAIM_DEVELOPMENT_GATE")
    for key, value in claim.items():
        if key != "development_zero_world_gate_passed":
            exact(value, False, f"CLAIM_{key.upper()}")

    require(CORE_LIBRARY.is_file(), "CORE_LIBRARY_MISSING")
    receipt = worker.run_zero_world_preflight(LocomotionCore(CORE_LIBRARY.resolve()))
    exact(receipt["schema_version"], worker.PREFLIGHT_SCHEMA, "PREFLIGHT_SCHEMA")
    exact(receipt["gate_id"], worker.GATE_ID, "PREFLIGHT_GATE")
    exact(receipt["inherited_r24d28_control_count"], 37, "PREFLIGHT_INHERITED")
    exact(receipt["signed_clearance_control_count"], 8, "PREFLIGHT_DIRECT")
    exact(receipt["negative_control_count"], 45, "PREFLIGHT_TOTAL")
    exact(receipt["negative_controls_passed"], 45, "PREFLIGHT_PASSED")
    exact(list(receipt["signed_clearance_controls"]), fixture["mutation_population"], "PREFLIGHT_ORDER")
    require(all(receipt["signed_clearance_controls"].values()), "PREFLIGHT_CONTROL_FAILURE")
    details = receipt["signed_clearance_control_details"]
    exact(details["current_observation_canonical_sha256"], identity["current_observation_canonical_sha256"], "PREFLIGHT_FIXTURE")
    exact(details["retained_semantic_step"], 82, "PREFLIGHT_STEP")
    exact(details["retained_phase"], "establish_distal_support", "PREFLIGHT_PHASE")
    exact(details["successor_pose_class"], "transitional", "PREFLIGHT_POSE")
    exact(details["successor_minimum_nonfoot_clearance_m"], -0.002553879273647315, "PREFLIGHT_CLEARANCE")
    exact(details["successor_next_phase"], "establish_distal_support", "PREFLIGHT_NEXT_PHASE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(receipt[key], 0, f"PREFLIGHT_{key.upper()}")
    exact(receipt["physics_state_modified"], False, "PREFLIGHT_PHYSICS")
    exact(receipt["physical_question_opened"], False, "PREFLIGHT_PHYSICAL")
    exact(receipt["prone_to_standing_claimed"], False, "PREFLIGHT_STANDING")

    support = load(SUPPORT_MATRIX_PATH, strict=False)
    boundary = support["morphology"]["recovery_morphology_boundary"]
    exact(boundary["next_gate_id"], "QSDK-R24D30", "SUPPORT_NEXT_GATE")
    closed = boundary["latest_zero_world_development_closure"]
    exact(closed["gate_id"], "QSDK-R24D29", "SUPPORT_CLOSED_GATE")
    exact(
        closed["status"],
        "closed_complete_zero_world_signed_clearance_semantics_"
        "positive_no_physical_question",
        "SUPPORT_STATUS",
    )
    exact(closed["contract_raw_sha256"], raw_sha256(CONTRACT_PATH), "SUPPORT_CONTRACT")
    exact(closed["retained_fixture_raw_sha256"], raw_sha256(FIXTURE_PATH), "SUPPORT_FIXTURE")
    exact(closed["closure_raw_sha256"], raw_sha256(CLOSURE_PATH), "SUPPORT_CLOSURE")
    exact(closed["source_inventory_count"], 75, "SUPPORT_SOURCES")
    exact(closed["zero_world_negative_control_count"], 45, "SUPPORT_CONTROLS")
    exact(closed["zero_world_negative_controls_passed"], 45, "SUPPORT_PASSED")
    exact(closed["development_zero_world_gate_passed"], True, "SUPPORT_DEVELOPMENT")
    exact(closed["official_zero_world_qualification_passed"], True, "SUPPORT_QUALIFICATION")
    exact(closed["next_physical_successor_gate_id"], "QSDK-R24D30", "SUPPORT_NEXT_PHYSICAL")
    exact(closed["physical_execution_authorized"], False, "SUPPORT_PHYSICAL")
    exact(closed["r24d29_may_be_requalified"], False, "SUPPORT_REQUALIFY")
    next_boundary = boundary["next_development_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D30", "SUPPORT_NEXT_BOUNDARY")
    exact(next_boundary["status"], "not_yet_frozen_physical_execution_blocked", "SUPPORT_NEXT_STATUS")
    exact(next_boundary["physical_execution_authorized"], False, "SUPPORT_NEXT_AUTHORITY")

    print(
        "QSDK_R24D29_SIGNED_CLEARANCE_SEMANTICS_SOURCE_PASS "
        "inventory=75 reused_sources=68 changed_sources=2 new_sources=5 "
        "inherited_controls=37 signed_clearance_controls=8 controls=45 "
        "models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D29_SIGNED_CLEARANCE_SEMANTICS_SOURCE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
