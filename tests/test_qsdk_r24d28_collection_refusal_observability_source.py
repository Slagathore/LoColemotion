"""Compact zero-world source/contract audit for QSDK-R24D28."""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = REPO_ROOT / "sdk"
ADAPTER_ROOT = SDK_ROOT / "adapters/mujoco"
SDK_PYTHON = SDK_ROOT / "python"
for path in (ADAPTER_ROOT, SDK_PYTHON):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_mujoco_adapter import native_recovery_development as runtime  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d28_collection_refusal_observability_worker as worker,
)


CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d28_collection_refusal_observability_contract_v1.json"
)
PREDECESSOR_CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d27_natural_recovery_progression_contract_v1.json"
)
PREDECESSOR_CLOSURE_PATH = (
    SDK_ROOT / "recovery/r24d27_natural_recovery_progression_invalid_closure_v1.json"
)
SUPPORT_MATRIX_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
RUNTIME_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
WORKER_PATH = (
    SDK_ROOT
    / "adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d28_collection_refusal_observability_worker.py"
)
ZERO_WORLD_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d28_collection_refusal_observability_zero_world.ps1"
)
PHYSICAL_WRAPPER = (
    SDK_ROOT / "run_qsdk_r24d28_collection_refusal_observability_development.ps1"
)
EXPECTED_CHANGED_PREDECESSOR_PATHS = {
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py",
    "sdk/adapters/mujoco/test_native_recovery_development.py",
}
EXPECTED_NEW_PATHS = {
    "sdk/recovery/r24d27_natural_recovery_progression_invalid_closure_v1.json",
    "tests/test_qsdk_r24d27_natural_recovery_progression_invalid_closure.py",
    "sdk/recovery/r24d28_collection_refusal_observability_contract_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d28_collection_refusal_observability_worker.py",
    "tests/test_qsdk_r24d28_collection_refusal_observability_source.py",
    "sdk/run_qsdk_r24d28_collection_refusal_observability_zero_world.ps1",
    "sdk/run_qsdk_r24d28_collection_refusal_observability_development.ps1",
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


def load(path: Path) -> dict[str, Any]:
    value = json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicates,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git_blob(path: Path) -> str:
    relative = path.relative_to(REPO_ROOT).as_posix()
    return subprocess.run(
        ["git", "hash-object", "--", relative],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    ).stdout.strip()


def _qualification_manifest(closure: dict[str, Any]) -> dict[str, dict[str, Any]]:
    qualification = closure["qualification"]
    receipt_path = Path(qualification["evidence_root"]) / qualification["receipt_path"]
    exact(raw_sha256(receipt_path), qualification["receipt_raw_sha256"], "QUALIFICATION_DIGEST")
    receipt = load(receipt_path)
    exact(receipt["source_commit"], closure["source_commit"], "QUALIFICATION_SOURCE")
    exact(receipt["ok"], True, "QUALIFICATION_OK")
    manifest = receipt["source_manifest"]
    exact(len(manifest), 61, "PREDECESSOR_MANIFEST_COUNT")
    return {entry["path"]: entry for entry in manifest}


def _expect_builder_refusal(
    error: runtime.NativeRecoveryCollectionRefusal,
    missing_key: str,
) -> None:
    diagnostic = deepcopy(error.diagnostic)
    diagnostic["refusal_context"].pop(missing_key)
    mutated = runtime.NativeRecoveryCollectionRefusal(diagnostic)
    try:
        worker.build_collection_refusal_partial_v1(
            mutated,
            source_commit="0" * 40,
            contract_path="synthetic_contract.json",
            qualification_receipt_path="synthetic_qualification.json",
            operation_lock={"role": "conformance", "test_only": True},
        )
    except worker.R24D28WorkerError:
        return
    raise AuditFailure(f"MISSING_DIAGNOSTIC_ACCEPTED:{missing_key}")


def main() -> int:
    contract = load(CONTRACT_PATH)
    predecessor = load(PREDECESSOR_CONTRACT_PATH)
    closure = load(PREDECESSOR_CLOSURE_PATH)
    exact(contract["schema_version"], worker.CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    exact(contract["gate_id"], worker.GATE_ID, "CONTRACT_GATE")
    exact(contract["campaign_id"], worker.CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["physical_question_declared"], True, "PHYSICAL_QUESTION")
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    exact(contract["population_inference_declared"], False, "POPULATION")
    worker.load_contract_v1(CONTRACT_PATH)

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D27", "LINEAGE_GATE")
    exact(
        lineage["predecessor_closure_raw_sha256"],
        raw_sha256(PREDECESSOR_CLOSURE_PATH),
        "LINEAGE_CLOSURE",
    )
    exact(lineage["predecessor_may_rerun"], False, "LINEAGE_RERUN")
    exact(lineage["predecessor_exact_refusal_reason_retained"], False, "LINEAGE_REASON")
    exact(closure["decision"]["r24d27_may_be_rerun"], False, "CLOSURE_RERUN")
    exact(
        closure["observed_failure"]["exact_refusal_reason_known"],
        False,
        "CLOSURE_REASON",
    )

    change = contract["controlled_change"]
    exact(change["production_runtime_changed"], True, "RUNTIME_CHANGE")
    exact(change["diagnostic_retention_changed"], True, "DIAGNOSTIC_CHANGE")
    for key in (
        "controller_changed",
        "native_physics_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "physical_rig_changed",
        "morphology_changed",
        "initializer_changed",
        "contact_observer_changed",
        "development_execution_bound_changed",
        "natural_route_stop_rule_changed",
        "seed_selector_changed",
        "held_out_selector_changed",
        "paired_evaluator_meaning_changed",
        "campaign_projection_changed",
        "result_interpretation_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")

    threshold = contract["threshold_and_margin_authority"]
    predecessor_threshold = predecessor["threshold_and_margin_authority"]
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

    cell = contract["selected_development_cell"]
    predecessor_cell = predecessor["selected_development_cell"]
    for key in (
        "cohort_id",
        "question_class",
        "cell_id",
        "initial_state_id",
        "torso_roll_rad",
        "seed_label",
        "seed_sha256",
        "seed",
        "random_draw_count",
    ):
        exact(cell[key], predecessor_cell[key], f"CELL_{key.upper()}")
    horizon = contract["ghost_horizon"]
    predecessor_horizon = predecessor["ghost_horizon"]
    for key in (
        "outer_steps_per_arm",
        "maximum_steps_per_arm",
        "entry_prone_confirm_steps",
        "native_substeps_per_outer_step",
        "paired_arm_count",
        "maximum_total_outer_steps",
        "maximum_total_native_solver_steps",
        "existing_route_stop_phases",
        "fixed_full_1200_step_execution_required",
        "additional_seed_required",
        "additional_physical_canary_required",
    ):
        exact(horizon[key], predecessor_horizon[key], f"HORIZON_{key.upper()}")

    source_inventory = contract["source_inventory"]
    exact(len(source_inventory), 68, "SOURCE_COUNT")
    exact(len(set(source_inventory)), 68, "SOURCE_UNIQUE")
    for relative in source_inventory:
        require((REPO_ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    predecessor_manifest = _qualification_manifest(closure)
    exact(set(predecessor_manifest), set(predecessor["source_inventory"]), "PREDECESSOR_SET")
    exact(
        set(source_inventory),
        set(predecessor_manifest) | EXPECTED_NEW_PATHS,
        "SOURCE_UNION",
    )
    unchanged_count = 0
    changed_count = 0
    for relative, frozen in predecessor_manifest.items():
        path = REPO_ROOT / relative
        if relative in EXPECTED_CHANGED_PREDECESSOR_PATHS:
            require(raw_sha256(path) != frozen["raw_sha256"], f"EXPECTED_CHANGE_MISSING:{relative}")
            changed_count += 1
        else:
            exact(raw_sha256(path), frozen["raw_sha256"], f"REUSED_DIGEST:{relative}")
            exact(path.stat().st_size, frozen["byte_length"], f"REUSED_LENGTH:{relative}")
            exact(git_blob(path), frozen["git_blob_oid"], f"REUSED_BLOB:{relative}")
            unchanged_count += 1
    exact(unchanged_count, 59, "UNCHANGED_COUNT")
    exact(changed_count, 2, "CHANGED_COUNT")
    exact(
        set(contract["prospective_freeze"]["changed_predecessor_source_paths"]),
        EXPECTED_CHANGED_PREDECESSOR_PATHS,
        "DECLARED_CHANGED_SET",
    )

    runtime_source = RUNTIME_PATH.read_text(encoding="utf-8")
    for token in (
        "class NativeRecoveryCollectionRefusal",
        "def require_supported_native_collection_v1(",
        '"collector_receipt": deepcopy(dict(collected))',
        '"current_observation": observation',
        '"current_native_receipt": native',
        '"accepted_prefix": {',
        '"execution_counts": {',
    ):
        require(token in runtime_source, f"RUNTIME_TOKEN:{token}")
    collection_index = runtime_source.index(
        "collected = collect_native_v2(core, collection)"
    )
    production_call_index = runtime_source.index(
        "        require_supported_native_collection_v1(",
        collection_index,
    )
    require(collection_index < production_call_index, "RUNTIME_CALL_ORDER")
    worker_source = WORKER_PATH.read_text(encoding="utf-8")
    for token in (
        "def publish_collection_refusal_v1(",
        'partial_path = output_directory / "partial_result.json"',
        'output_directory / "invalid_result.json"',
        "except runtime.NativeRecoveryCollectionRefusal as error:",
    ):
        require(token in worker_source, f"WORKER_TOKEN:{token}")
    for path, tokens in (
        (
            ZERO_WORLD_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
                '"QSDK-R24D28"',
                "qsdk_r24d28_collection_refusal_observability_worker",
            ),
        ),
        (
            PHYSICAL_WRAPPER,
            (
                "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
                '"QSDK-R24D28"',
                "qsdk_r24d28_collection_refusal_observability_worker",
                '-ExpectedCellId "development_recovery_morphology_nominal"',
                "-ExpectedHorizonSteps 1200",
            ),
        ),
    ):
        source = path.read_text(encoding="utf-8")
        for token in tokens:
            require(token in source, f"WRAPPER_TOKEN:{path.name}:{token}")

    controls, details = worker._forced_refusal_observability_controls()
    exact(len(controls), 6, "DIRECT_CONTROL_COUNT")
    require(all(controls.values()), "DIRECT_CONTROL_FAILURE")
    exact(details["forced_collector_support_status"], "invalid_observation", "DETAIL_STATUS")
    exact(details["forced_collector_refusal_reason"], "energy_balance_invalid", "DETAIL_REASON")
    refusal = worker._synthetic_refusal_receipt()
    context = worker._synthetic_refusal_context()
    try:
        runtime.require_supported_native_collection_v1(refusal, refusal_context=context)
    except runtime.NativeRecoveryCollectionRefusal as error:
        for missing in (
            "semantic_step",
            "phase",
            "arm_kind",
            "current_observation",
            "current_native_receipt",
            "accepted_prefix",
            "execution_counts",
        ):
            _expect_builder_refusal(error, missing)
    else:
        raise AuditFailure("DIRECT_TYPED_REFUSAL_MISSING")

    gate = contract["complete_zero_world_gate"]
    exact(gate["inherited_r24d27_control_count"], 31, "INHERITED_CONTROLS")
    exact(gate["forced_refusal_observability_control_count"], 6, "DIRECT_CONTROLS")
    exact(gate["total_negative_control_count"], 37, "TOTAL_CONTROLS")
    exact(gate["construct_mujoco_model"], False, "MODEL_CONSTRUCTION")
    exact(gate["world_attempt_count"], 0, "WORLDS")
    exact(gate["solver_step_count"], 0, "SOLVER_STEPS")
    exact(gate["full_seeded_ghost_required"], False, "FULL_GHOST")
    exact(gate["additional_physical_canary_required"], False, "CANARY")
    held_out = contract["held_out_seal"]
    exact(held_out["held_out_cell_access_count"], 0, "HELDOUT")
    exact(held_out["held_out_selector_invocation_count"], 0, "SELECTOR")
    claim = contract["claim_boundary"]
    for key in (
        "official_zero_world_qualification_passed",
        "physical_question_opened",
        "exact_collection_refusal_observed",
        "controller_progression_to_stance_handoff_proven",
        "prone_to_standing_claimed",
        "repeatability_rate_claimed",
        "population_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    support = json.loads(SUPPORT_MATRIX_PATH.read_text(encoding="utf-8"))
    require(isinstance(support, dict), "SUPPORT_MATRIX_ROOT")
    boundary = support["morphology"]["recovery_morphology_boundary"]
    exact(boundary["next_gate_id"], "QSDK-R24D29", "SUPPORT_NEXT")
    latest = boundary["latest_development_attempt"]
    exact(latest["gate_id"], "QSDK-R24D28", "SUPPORT_GATE")
    exact(
        latest["status"],
        "closed_consumed_diagnosable_invalid_observation_"
        "observability_positive_progression_unresolved",
        "SUPPORT_STATUS",
    )
    exact(
        latest["forced_failure_zero_world_control_required"],
        True,
        "SUPPORT_FORCED_FAILURE",
    )
    exact(latest["exact_failure_observability_repair_positive"], True, "SUPPORT_OBSERVABILITY")
    exact(latest["valid_physical_behavior_result_observed"], False, "SUPPORT_BEHAVIOR")
    next_boundary = boundary["next_development_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D29", "SUPPORT_NEXT_GATE")
    exact(
        next_boundary["retained_step_82_zero_world_conformance_fixture_required"],
        True,
        "SUPPORT_NEXT_FIXTURE",
    )
    exact(next_boundary["physical_execution_authorized"], False, "SUPPORT_NEXT_PHYSICAL")

    print(
        "QSDK_R24D28_COLLECTION_REFUSAL_OBSERVABILITY_SOURCE_PASS "
        "inventory=68 reused_sources=59 changed_sources=2 new_sources=7 "
        "inherited_controls=31 observability_controls=6 controls=37 "
        "models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D28_COLLECTION_REFUSAL_OBSERVABILITY_SOURCE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
