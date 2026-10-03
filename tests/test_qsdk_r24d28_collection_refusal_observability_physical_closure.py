"""Audit the retained QSDK-R24D28 qualification and physical refusal."""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/"
    "r24d28_collection_refusal_observability_physical_closure_v1.json"
)
SOURCE_COMMIT = "412bb9f3664cc36e17cf998ddc02e040aa074114"


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


def verify_inventory(root: Path, artifacts: list[dict[str, Any]]) -> None:
    exact(
        {path.name for path in root.iterdir() if path.is_file()},
        {artifact["path"] for artifact in artifacts},
        f"INVENTORY_SET:{root}",
    )
    for artifact in artifacts:
        path = root / artifact["path"]
        require(path.is_file(), f"ARTIFACT_MISSING:{path}")
        exact(path.stat().st_size, artifact["byte_length"], f"LENGTH:{path.name}")
        exact(raw_sha256(path), artifact["raw_sha256"], f"DIGEST:{path.name}")


def validate_claim_boundary(closure: Mapping[str, Any]) -> None:
    exact(
        closure["closure_status"],
        "closed_consumed_diagnosable_invalid_observation_"
        "observability_positive_progression_unresolved",
        "STATUS",
    )
    decision = closure["observability_decision"]
    exact(decision["exact_failure_observability_repair_positive"], True, "OBSERVABILITY")
    exact(decision["content_addressed_partial_retention_positive"], True, "RETENTION")
    exact(
        decision["r24d28_physical_behavior_result"],
        "invalid_incomplete_before_current_observation_acceptance",
        "BEHAVIOR_RESULT",
    )
    exact(decision["natural_recovery_progression_result_observed"], False, "PROGRESSION")
    exact(decision["matched_zero_result_observed"], False, "MATCHED_ZERO")
    exact(decision["r24d28_may_be_rerun"], False, "RERUN")
    exact(decision["historical_result_rewritten"], False, "REWRITE")
    exact(decision["sdk1_completed_steps"], 11, "SDK1")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")
    claim = closure["claim_boundary"]
    for key in (
        "complete_zero_world_gate_passed",
        "official_zero_world_qualification_passed",
        "physical_question_opened",
        "exact_native_collection_refusal_observed",
        "exact_partial_trace_retained",
    ):
        exact(claim[key], True, f"CLAIM_{key.upper()}")
    for key in (
        "valid_physical_development_trace_observed",
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


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d28_collection_refusal_observability_"
        "physical_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D28", "GATE")
    exact(closure["question_class"], "development", "QUESTION")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE")
    exact(closure["physical_question_declared"], True, "PHYSICAL_QUESTION")
    exact(closure["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        closure["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    exact(closure["population_inference_declared"], False, "POPULATION")
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )

    contract_authority = closure["contract"]
    contract_path = REPO_ROOT / contract_authority["path"]
    exact(contract_path.stat().st_size, contract_authority["byte_length"], "CONTRACT_LENGTH")
    exact(raw_sha256(contract_path), contract_authority["raw_sha256"], "CONTRACT_DIGEST")
    exact(
        blob_at_commit(contract_authority["path"]),
        contract_authority["git_blob_oid"],
        "CONTRACT_BLOB",
    )

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    verify_inventory(qualification_root, qualification["retained_artifacts"])
    receipt = load(qualification_root / qualification["receipt_path"])
    exact(raw_sha256(qualification_root / qualification["receipt_path"]), qualification["receipt_raw_sha256"], "QUALIFICATION_DIGEST")
    exact(receipt["schema_version"], "sporespore_qsdk_r24d28_collection_refusal_observability_zero_world_receipt_v1", "QUALIFICATION_SCHEMA")
    exact(receipt["gate_id"], "QSDK-R24D28", "QUALIFICATION_GATE")
    exact(receipt["mode"], "qualification", "QUALIFICATION_MODE")
    exact(receipt["ok"], True, "QUALIFICATION_OK")
    exact(receipt["source_commit"], SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    exact(len(receipt["source_manifest"]), qualification["source_inventory_count"], "SOURCE_COUNT")
    exact(receipt["production_preflight"]["negative_control_count"], 37, "CONTROLS")
    exact(receipt["production_preflight"]["negative_controls_passed"], 37, "CONTROL_PASS")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(receipt[key], 0, f"QUALIFICATION_{key.upper()}")
    exact(receipt["physics_state_modified"], False, "QUALIFICATION_PHYSICS")
    exact(receipt["operation_lock_released"], True, "QUALIFICATION_LOCK")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    verify_inventory(attempt_root, attempt["retained_artifacts"])
    reservation = load(attempt_root / "attempt_reservation.json")
    invalid = load(attempt_root / "invalid_result.json")
    partial_path = attempt_root / attempt["partial_result_path"]
    partial = load(partial_path)
    completion = load(attempt_root / "supervisor_completion.json")
    exact(reservation["source_commit"], SOURCE_COMMIT, "RESERVATION_SOURCE")
    exact(reservation["question_class"], "development", "RESERVATION_QUESTION")
    exact(reservation["horizon_steps_per_arm"], 1200, "HORIZON")
    exact(reservation["paired_arm_count"], 2, "ARMS")
    exact(reservation["held_out_cell_access_count"], 0, "HELDOUT")
    exact(completion["worker_started"], True, "WORKER_STARTED")
    exact(completion["worker_exit_code"], 2, "WORKER_EXIT")
    exact(completion["invalid_or_incomplete_retained"], True, "COMPLETION_INVALID")
    exact(completion["operation_lock_released"], True, "PHYSICAL_LOCK")
    exact(completion["caught_error"], None, "SUPERVISOR_ERROR")
    for name in ("paired_full_result.json", "paired_summary.json", "manifest.json"):
        require(not (attempt_root / name).exists(), f"UNEXPECTED_COMPLETE:{name}")

    exact(invalid["error_type"], "NativeRecoveryCollectionRefusal", "ERROR_TYPE")
    exact(invalid["error"], "QSDK_R24D18_NATIVE_COLLECTION_REFUSED", "ERROR_CODE")
    exact(invalid["collector_support_status"], "invalid_observation", "STATUS_EXACT")
    exact(invalid["collector_refusal_reason"], "absent_nonfoot_contact_values_invalid", "REASON_EXACT")
    exact(invalid["arm_kind"], "candidate_command", "ARM")
    exact(invalid["semantic_step"], 82, "STEP")
    exact(invalid["phase"], "establish_distal_support", "PHASE")
    exact(invalid["partial_result_path"], partial_path.name, "PARTIAL_PATH")
    exact(invalid["partial_result_raw_sha256"], raw_sha256(partial_path), "PARTIAL_DIGEST")
    exact(invalid["partial_result_byte_length"], partial_path.stat().st_size, "PARTIAL_LENGTH")
    exact(invalid["valid_physical_behavior_result_observed"], False, "INVALID_BEHAVIOR")
    exact(invalid["prone_to_standing_claimed"], False, "INVALID_STANDING")
    exact(invalid["physical_acceptance_authority"], False, "INVALID_ACCEPTANCE")
    exact(invalid["release_authority"], False, "INVALID_RELEASE")

    observed = closure["observed_refusal"]
    diagnostic = partial["native_collection_refusal"]
    context = diagnostic["refusal_context"]
    exact(diagnostic["collector_receipt"]["support_status"], observed["collector_support_status"], "COLLECTOR_STATUS")
    exact(diagnostic["collector_receipt"]["refusal_reason"], observed["collector_refusal_reason"], "COLLECTOR_REASON")
    exact(diagnostic["collector_supplied_native_post_step_observation_validated"], False, "COLLECTOR_VALIDATED")
    exact(context["arm_kind"], attempt["refusal_arm_kind"], "CONTEXT_ARM")
    exact(context["semantic_step"], attempt["refusal_semantic_step"], "CONTEXT_STEP")
    exact(context["phase"], attempt["refusal_phase"], "CONTEXT_PHASE")
    exact(context["execution_counts"], invalid["execution_counts"], "COUNTS_LINK")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_outer_steps_completed",
        "portable_steps_accepted",
        "native_solver_step_count",
        "physics_state_modified",
    ):
        exact(context["execution_counts"][key], attempt[key], f"COUNT_{key.upper()}")

    prefix = context["accepted_prefix"]
    for key, expected in observed["accepted_prefix_lengths"].items():
        exact(len(prefix[key]), expected, f"PREFIX_{key.upper()}")
    steps = [item["semantic_step"] for item in prefix["observations"]]
    exact(steps, list(range(82)), "SEMANTIC_STEPS")
    require(
        all(
            item["support_status"] == "supported_exact"
            and item["supplied_native_post_step_observation_validated"] is True
            for item in prefix["collector_receipts"]
        ),
        "PREFIX_COLLECTOR_ACCEPTANCE",
    )
    memory = context["memory_before_current_step"]
    for key, expected in observed["memory_before_refusal"].items():
        exact(memory[key], expected, f"MEMORY_{key.upper()}")

    bodies = {
        item["body_id"]: item
        for item in context["current_observation"]["ordered_body_clearance_observations"]
    }
    for expected in observed["inconsistent_body_observations"]:
        actual = bodies[expected["body_id"]]
        for key, value in expected.items():
            exact(actual[key], value, f"BODY_{expected['body_id']}_{key.upper()}")
    for body_id in ("front_left_distal", "front_right_distal"):
        exact(bodies[body_id]["nonfoot_contact_present"], True, f"FRONT_CONTACT:{body_id}")
    previous_bodies = {
        item["body_id"]: item
        for item in prefix["observations"][-1]["ordered_body_clearance_observations"]
    }
    for body_id in ("rear_left_distal", "rear_right_distal"):
        exact(previous_bodies[body_id]["nonfoot_contact_present"], True, f"PREVIOUS_CONTACT:{body_id}")
    foot = {
        item["contact_site_id"]: item["bearing_normal_impulse_ns"]
        for item in context["current_observation"]["ordered_foot_bearing_observations"]
    }
    exact(foot, observed["same_step_foot_bearing_impulses_ns"], "FOOT_IMPULSES")
    exact(context["held_out_cell_access_count"], 0, "CONTEXT_HELDOUT")
    exact(context["held_out_selector_invocation_count"], 0, "CONTEXT_SELECTOR")

    runtime_source = source_at_commit(observed["production_observer_path"])
    exact(blob_at_commit(observed["production_observer_path"]), observed["production_observer_git_blob_oid"], "RUNTIME_BLOB")
    require("def require_supported_native_collection_v1(" in runtime_source, "TYPED_HELPER")
    require('"accepted_prefix": {' in runtime_source, "PARTIAL_PREFIX_SOURCE")
    worker_source = source_at_commit(observed["worker_path"])
    exact(blob_at_commit(observed["worker_path"]), observed["worker_git_blob_oid"], "WORKER_BLOB")
    require(worker_source.index('partial_path = output_directory / "partial_result.json"') < worker_source.index('output_directory / "invalid_result.json"'), "PUBLISH_ORDER")
    predicate_source = source_at_commit(observed["predicate_authority_path"])
    require('return Err("absent_nonfoot_contact_values_invalid".to_owned())' in predicate_source, "PREDICATE_REASON")
    exact(observed["failure_class"], "native_observer_and_portable_collector_nonfoot_contact_consistency_mismatch", "FAILURE_CLASS")
    exact(observed["physical_threshold_failure_established"], False, "THRESHOLD_RESULT")
    exact(observed["controller_progression_result_valid"], False, "CONTROLLER_RESULT")

    validate_claim_boundary(closure)
    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D29", "NEXT_GATE")
    exact(next_boundary["retained_step_82_must_be_a_zero_world_conformance_fixture"], True, "NEXT_FIXTURE")
    exact(next_boundary["same_identity_rerun_permitted"], False, "NEXT_RERUN")
    exact(next_boundary["next_physical_execution_authorized"], False, "NEXT_PHYSICAL")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    mutations = (
        ("closure_status", "closed_positive"),
        ("observability_decision.exact_failure_observability_repair_positive", False),
        ("observability_decision.r24d28_may_be_rerun", True),
        ("claim_boundary.valid_physical_development_trace_observed", True),
        ("claim_boundary.prone_to_standing_claimed", True),
        ("claim_boundary.release_authority", True),
    )
    for dotted, value in mutations:
        mutated = deepcopy(closure)
        cursor: dict[str, Any] = mutated
        parts = dotted.split(".")
        for part in parts[:-1]:
            cursor = cursor[part]
        cursor[parts[-1]] = value
        try:
            validate_claim_boundary(mutated)
        except ClosureError:
            continue
        raise ClosureError(f"CLAIM_MUTATION_ACCEPTED:{dotted}")

    print(
        "QSDK_R24D28_PHYSICAL_CLOSURE_PASS result=diagnosable_invalid "
        "observability_positive=True reason=absent_nonfoot_contact_values_invalid "
        "arm=candidate_command step=82 phase=establish_distal_support "
        "worlds=1 outer_steps=83 solver_steps=415 accepted_prefix=82 "
        "progression_result=False heldout_access=0 next=QSDK-R24D29"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D28_PHYSICAL_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
