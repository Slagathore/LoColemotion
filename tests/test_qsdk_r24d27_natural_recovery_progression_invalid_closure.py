"""Verify the retained QSDK-R24D27 invalid development closure."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE = (
    REPO_ROOT
    / "sdk/recovery/r24d27_natural_recovery_progression_invalid_closure_v1.json"
)
SOURCE_COMMIT = "3068186be9513f4d31b80e249581ef3107419882"


class ClosureError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


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


def source_at_commit(relative: str) -> str:
    return subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    ).stdout


def blob_at_commit(relative: str) -> str:
    return subprocess.run(
        ["git", "rev-parse", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    ).stdout.strip()


def verify_artifacts(root: Path, artifacts: list[dict[str, Any]]) -> None:
    for artifact in artifacts:
        path = root / artifact["path"]
        require(path.is_file(), f"ARTIFACT_MISSING:{path}")
        exact(path.stat().st_size, artifact["byte_length"], f"LENGTH:{path.name}")
        exact(raw_sha256(path), artifact["raw_sha256"], f"DIGEST:{path.name}")


def audit() -> None:
    closure = load(CLOSURE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d27_natural_recovery_progression_invalid_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D27", "GATE")
    exact(closure["question_class"], "development", "QUESTION")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE")
    exact(closure["physical_question_declared"], True, "PHYSICAL_QUESTION")
    exact(closure["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        closure["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )
    contract = REPO_ROOT / closure["contract_path"]
    exact(contract.stat().st_size, closure["contract_byte_length"], "CONTRACT_LENGTH")
    exact(raw_sha256(contract), closure["contract_raw_sha256"], "CONTRACT_DIGEST")

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    verify_artifacts(qualification_root, qualification["retained_artifacts"])
    receipt = load(qualification_root / qualification["receipt_path"])
    exact(receipt["ok"], True, "QUALIFICATION_OK")
    exact(receipt["mode"], "qualification", "QUALIFICATION_MODE")
    exact(receipt["source_commit"], SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    exact(len(receipt["source_manifest"]), 61, "QUALIFICATION_MANIFEST")
    exact(receipt["production_preflight"]["negative_control_count"], 31, "CONTROLS")
    exact(receipt["production_preflight"]["negative_controls_passed"], 31, "PASS")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(receipt[key], 0, f"QUALIFICATION_{key.upper()}")
    exact(receipt["physics_state_modified"], False, "QUALIFICATION_PHYSICS")
    exact(receipt["held_out_cell_access_count"], 0, "QUALIFICATION_HELDOUT")
    exact(receipt["held_out_selector_invocation_count"], 0, "QUALIFICATION_SELECTOR")
    exact(receipt["operation_lock_released"], True, "QUALIFICATION_LOCK")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    verify_artifacts(attempt_root, attempt["retained_artifacts"])
    invalid = load(attempt_root / "invalid_result.json")
    completion = load(attempt_root / "supervisor_completion.json")
    reservation = load(attempt_root / "attempt_reservation.json")
    exact(invalid["source_commit"], SOURCE_COMMIT, "INVALID_SOURCE")
    exact(invalid["invalid_but_retained"], True, "INVALID_RETAINED")
    exact(invalid["error_type"], "NativeRecoveryRouteError", "ERROR_TYPE")
    exact(invalid["error"], "QSDK_R24D18_NATIVE_COLLECTION_REFUSED", "ERROR")
    require("run_paired_development" in invalid["traceback"], "STACK_PAIRED")
    require("candidate = _run_arm" in invalid["traceback"], "STACK_CANDIDATE")
    require("collect_native_v2" not in invalid["traceback"], "STACK_NO_COLLECTOR_DETAIL")
    exact(completion["worker_started"], True, "WORKER_STARTED")
    exact(completion["worker_exit_code"], 2, "WORKER_EXIT")
    exact(completion["invalid_or_incomplete_retained"], True, "COMPLETION")
    exact(completion["operation_lock_released"], True, "LOCK_RELEASED")
    exact(completion["caught_error"], None, "SUPERVISOR_ERROR")
    exact(reservation["horizon_steps_per_arm"], 1200, "HORIZON")
    exact(reservation["paired_arm_count"], 2, "ARMS")
    exact(reservation["held_out_cell_access_count"], 0, "HELDOUT")
    for path in ("paired_full_result.json", "paired_summary.json", "manifest.json"):
        require(not (attempt_root / path).exists(), f"UNEXPECTED_COMPLETE_RESULT:{path}")

    source_path = closure["observed_failure"]["source_path"]
    source = source_at_commit(source_path)
    exact(
        blob_at_commit(source_path),
        closure["observed_failure"]["source_git_blob_oid"],
        "SOURCE_BLOB",
    )
    collection = "collected = collect_native_v2(core, collection)"
    generic_error = '"QSDK_R24D18_NATIVE_COLLECTION_REFUSED"'
    candidate_call = "candidate = _run_arm("
    matched_call = "matched_zero = _run_arm("
    require(collection in source, "SOURCE_COLLECTION")
    require(generic_error in source, "SOURCE_GENERIC_ERROR")
    require(source.index(collection) < source.index(generic_error), "SOURCE_COLLECTION_ORDER")
    require(source.index(candidate_call) < source.index(matched_call), "SOURCE_ARM_ORDER")
    worker_path = closure["observed_failure"]["worker_path"]
    exact(
        blob_at_commit(worker_path),
        closure["observed_failure"]["worker_git_blob_oid"],
        "WORKER_BLOB",
    )

    for key in (
        "candidate_arm_entered_by_source_order",
        "native_world_was_opened_by_source_order",
        "at_least_one_candidate_native_step_completed_by_source_order",
    ):
        exact(attempt[key], True, f"ATTEMPT_{key.upper()}")
    exact(attempt["matched_zero_arm_entered_by_source_order"], False, "MATCHED_ZERO")
    exact(attempt["exact_execution_counts_published"], False, "COUNTS_PUBLISHED")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "outer_step_count",
        "solver_step_count",
        "physics_state_modified",
    ):
        exact(attempt[key], None, f"UNPUBLISHED_{key.upper()}")

    failure = closure["observed_failure"]
    exact(
        failure["class"],
        "native_collection_refusal_genericized_before_durable_retention",
        "FAILURE_CLASS",
    )
    exact(failure["collector_invocation_proven"], True, "COLLECTOR_INVOKED")
    exact(failure["collector_return_proven"], True, "COLLECTOR_RETURNED")
    exact(failure["collector_acceptance_predicate_failed"], True, "PREDICATE")
    for key in (
        "exact_failed_predicate_branch_known",
        "exact_refusal_reason_known",
        "exact_physical_invariant_failure_known",
        "integration_failure_established",
        "physics_behavior_failure_established",
        "threshold_failure_established",
        "selector_failure_established",
        "evaluator_failure_established",
        "natural_progression_result_observed",
        "controller_progression_interpretation_permitted",
        "result_interpretation_rewritten",
    ):
        exact(failure[key], False, f"FAILURE_{key.upper()}")

    postmortem = closure["zero_world_gate_postmortem"]
    exact(postmortem["gate_result_rewritten"], False, "GATE_REWRITE")
    exact(postmortem["gate_passed_for_declared_controls"], True, "GATE_PASS")
    exact(postmortem["physical_opening_was_appropriate"], True, "OPENING")
    exact(postmortem["invalid_path_diagnostic_retention_was_adequate"], False, "RETENTION")
    exact(postmortem["full_seeded_ghost_required"], False, "FULL_GHOST")
    exact(postmortem["additional_physical_canary_required"], False, "CANARY")

    decision = closure["decision"]
    exact(decision["r24d27_result"], "consumed_invalid_incomplete_and_retained", "DECISION")
    exact(decision["r24d27_may_be_rerun"], False, "RERUN")
    exact(decision["natural_recovery_progression_observed"], False, "PROGRESSION")
    exact(decision["sdk1_completed_steps"], 11, "SDK1")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")
    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D28", "NEXT")
    exact(next_boundary["forced_failure_observability_control_required"], True, "FORCED_FAILURE")
    exact(next_boundary["controller_changed"], False, "NEXT_CONTROLLER")
    exact(next_boundary["native_physics_changed"], False, "NEXT_PHYSICS")
    exact(next_boundary["behavior_thresholds_changed"], False, "NEXT_THRESHOLDS")
    exact(next_boundary["diagnostic_retention_changed"], True, "NEXT_DIAGNOSTICS")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    claim = closure["claim_boundary"]
    exact(claim["complete_zero_world_gate_passed"], True, "CLAIM_ZERO_WORLD")
    exact(claim["physical_question_opened"], True, "CLAIM_PHYSICAL")
    for key in (
        "valid_physical_development_trace_observed",
        "complete_native_receipt_observed",
        "exact_native_collection_refusal_observed",
        "natural_recovery_progression_observed",
        "recovery_to_stance_handoff_observed",
        "controller_physical_viability_proven",
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

    print(
        "QSDK_R24D27_INVALID_CLOSURE_PASS result=invalid_incomplete "
        "cause=native_collection_refusal_observability_loss exact_counts=unpublished "
        "heldout_access=0 prone_to_standing_claimed=False next=QSDK-R24D28"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D27_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
