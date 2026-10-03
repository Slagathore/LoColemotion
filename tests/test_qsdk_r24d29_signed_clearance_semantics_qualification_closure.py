"""Audit the retained zero-world QSDK-R24D29 qualification closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    canonical_bytes,
    exact,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_retained_commit,
    verify_retained_file_manifest,
    verify_source_receipt_manifest,
)


CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/"
    "r24d29_signed_clearance_semantics_qualification_closure_v1.json"
)
SOURCE = "1c39e99d70d5b958d426d7f7301e779ee247daa7"


def verify_binding(binding: dict[str, object]) -> bytes:
    relative = str(binding["path"])
    raw = source_bytes(ROOT, SOURCE, relative)
    exact(len(raw), binding["byte_length"], f"SOURCE_LENGTH:{relative}")
    exact(sha256(raw), binding["raw_sha256"], f"SOURCE_HASH:{relative}")
    exact(
        git(ROOT, "rev-parse", f"{SOURCE}:{relative}"),
        binding["git_blob_oid"],
        f"SOURCE_OID:{relative}",
    )
    return raw


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d29_signed_clearance_semantics_"
        "qualification_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D29", "GATE")
    exact(
        closure["closure_status"],
        "closed_complete_zero_world_signed_clearance_semantics_"
        "positive_no_physical_question",
        "STATUS",
    )
    exact(closure["question_class"], "development", "QUESTION")
    exact(closure["physical_question_declared"], False, "PHYSICAL_QUESTION")
    exact(closure["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        closure["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    exact(closure["population_inference_declared"], False, "POPULATION")
    exact(closure["source_commit"], SOURCE, "SOURCE")
    verify_retained_commit(ROOT, SOURCE, closure["source_parent_commit"])
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), closure["source_tree"], "TREE")

    bindings = closure["frozen_source_bindings"]
    exact(len(bindings), 5, "BINDING_COUNT")
    exact(len({item["path"] for item in bindings}), 5, "BINDING_UNIQUE")
    bound = {str(item["path"]): verify_binding(item) for item in bindings}
    contract_path = "sdk/recovery/r24d29_signed_clearance_semantics_contract_v1.json"
    fixture_path = "sdk/recovery/r24d29_retained_step82_clearance_fixture_v1.json"
    contract = loads(bound[contract_path])
    fixture = loads(bound[fixture_path])
    exact(contract["gate_id"], "QSDK-R24D29", "CONTRACT_GATE")
    exact(contract["question_class"], "development", "CONTRACT_CLASS")
    exact(contract["physical_question_declared"], False, "CONTRACT_PHYSICAL")
    exact(contract["qualification_and_closure"]["qualification_result_pending"], True, "CONTRACT_PROSPECTIVE")
    exact(contract["claim_boundary"]["development_zero_world_gate_passed"], True, "CONTRACT_DEVELOPMENT")
    exact(contract["claim_boundary"]["official_zero_world_qualification_passed"], False, "CONTRACT_PRE_RESULT")
    exact(fixture["gate_id"], "QSDK-R24D29", "FIXTURE_GATE")
    exact(fixture["mutation_control_count"], 8, "FIXTURE_CONTROL_COUNT")
    exact(fixture["historical_result"]["historical_result_rewritten"], False, "FIXTURE_HISTORY")
    exact(fixture["historical_result"]["same_identity_rerun_permitted"], False, "FIXTURE_RERUN")

    support = closure["audit_support_binding"]
    verify_binding(support)
    exact(
        git(ROOT, "rev-parse", f"HEAD:{support['path']}"),
        support["git_blob_oid"],
        "CURRENT_AUDIT_SUPPORT_OID",
    )

    qualification = closure["qualification"]
    evidence_root = Path(qualification["evidence_root"])
    artifacts = qualification["retained_artifacts"]
    exact(len(artifacts), qualification["retained_artifact_count"], "ARTIFACT_COUNT")
    exact(len({item["path"] for item in artifacts}), 8, "ARTIFACT_UNIQUE")
    verify_retained_file_manifest(evidence_root, artifacts)
    require(not (evidence_root / "qualification_failure.json").exists(), "FAILURE_FILE")

    attempt_path = evidence_root / qualification["attempt_path"]
    receipt_path = evidence_root / qualification["receipt_path"]
    exact(attempt_path.stat().st_size, qualification["attempt_byte_length"], "ATTEMPT_LENGTH")
    exact(sha256(attempt_path.read_bytes()), qualification["attempt_raw_sha256"], "ATTEMPT_HASH")
    exact(receipt_path.stat().st_size, qualification["receipt_byte_length"], "RECEIPT_LENGTH")
    exact(sha256(receipt_path.read_bytes()), qualification["receipt_raw_sha256"], "RECEIPT_HASH")
    attempt = load(attempt_path)
    receipt = load(receipt_path)

    matching_attempts: list[Path] = []
    for directory in evidence_root.parent.glob("qsdk-r24d29-qualification-*"):
        candidate = directory / "qualification_attempt.json"
        if not candidate.is_file():
            continue
        value = load(candidate)
        if value.get("gate_id") == "QSDK-R24D29" and value.get("source_commit") == SOURCE:
            matching_attempts.append(directory)
    exact(
        len(matching_attempts),
        qualification["official_qualification_attempt_count_for_source"],
        "SOURCE_ATTEMPT_COUNT",
    )
    exact(matching_attempts, [evidence_root], "SOURCE_ATTEMPT_IDENTITY")

    exact(attempt["schema_version"], "sporespore_qsdk_r24d29_signed_clearance_semantics_zero_world_attempt_v1", "ATTEMPT_SCHEMA")
    exact(attempt["gate_id"], "QSDK-R24D29", "ATTEMPT_GATE")
    exact(attempt["mode"], "qualification", "ATTEMPT_MODE")
    exact(attempt["source_commit"], SOURCE, "ATTEMPT_SOURCE")
    exact(attempt["upstream_commit"], SOURCE, "ATTEMPT_UPSTREAM")
    exact(attempt["live_remote_commit"], SOURCE, "ATTEMPT_LIVE")
    exact(attempt["worktree_clean_at_start"], True, "ATTEMPT_CLEAN")
    exact(attempt["operation_lock"]["acquired"], True, "ATTEMPT_LOCK")
    exact(attempt["operation_lock"]["test_only"], False, "ATTEMPT_LOCK_TEST")

    exact(receipt["schema_version"], "sporespore_qsdk_r24d29_signed_clearance_semantics_zero_world_receipt_v1", "RECEIPT_SCHEMA")
    exact(receipt["gate_id"], "QSDK-R24D29", "RECEIPT_GATE")
    exact(receipt["mode"], "qualification", "RECEIPT_MODE")
    exact(receipt["ok"], True, "RECEIPT_OK")
    exact(receipt["source_commit"], SOURCE, "RECEIPT_SOURCE")
    exact(receipt["upstream_commit"], SOURCE, "RECEIPT_UPSTREAM")
    exact(receipt["live_remote_commit"], SOURCE, "RECEIPT_LIVE")
    exact(receipt["contract_path"], contract_path, "RECEIPT_CONTRACT_PATH")
    exact(receipt["contract_raw_sha256"], sha256(bound[contract_path]), "RECEIPT_CONTRACT_HASH")
    exact(receipt["checks"], {key: True for key in (
        "core_dynamic_library_rebuilt",
        "core_recovery_tests_passed",
        "mujoco_adapter_zero_world_tests_passed",
        "source_contract_audit_passed",
        "production_preflight_passed",
        "worktree_unchanged",
    )}, "RECEIPT_CHECKS")
    exact(receipt["toolchain"], qualification["toolchain"], "TOOLCHAIN")
    exact(receipt["operation_lock_released"], True, "RECEIPT_LOCK_RELEASED")

    source_manifest = receipt["source_manifest"]
    exact(len(source_manifest), qualification["source_manifest_entry_count"], "SOURCE_COUNT")
    exact([item["path"] for item in source_manifest], contract["source_inventory"], "SOURCE_INVENTORY")
    source_manifest_canonical = canonical_bytes(source_manifest)
    exact(len(source_manifest_canonical), qualification["source_manifest_canonical_byte_length"], "SOURCE_MANIFEST_LENGTH")
    exact(sha256(source_manifest_canonical), qualification["source_manifest_canonical_sha256"], "SOURCE_MANIFEST_HASH")
    verify_source_receipt_manifest(ROOT, SOURCE, source_manifest)

    preflight = receipt["production_preflight"]
    preflight_canonical = canonical_bytes(preflight)
    exact(len(preflight_canonical), qualification["production_preflight_canonical_byte_length"], "PREFLIGHT_LENGTH")
    exact(sha256(preflight_canonical), qualification["production_preflight_canonical_sha256"], "PREFLIGHT_HASH")
    exact(preflight["gate_id"], "QSDK-R24D29", "PREFLIGHT_GATE")
    exact(preflight["ok"], True, "PREFLIGHT_OK")
    exact(preflight["engine"], "mujoco_native", "PREFLIGHT_ENGINE")
    exact(preflight["inherited_r24d28_control_count"], 37, "PREFLIGHT_INHERITED")
    exact(preflight["signed_clearance_control_count"], 8, "PREFLIGHT_DIRECT")
    exact(preflight["negative_control_count"], 45, "PREFLIGHT_TOTAL")
    exact(preflight["negative_controls_passed"], 45, "PREFLIGHT_PASSED")
    exact(len(preflight["signed_clearance_controls"]), 8, "PREFLIGHT_CONTROL_CARDINALITY")
    exact(
        set(preflight["signed_clearance_controls"]),
        set(fixture["mutation_population"]),
        "PREFLIGHT_CONTROL_SET",
    )
    require(all(preflight["signed_clearance_controls"].values()), "PREFLIGHT_CONTROL_FAILURE")
    details = preflight["signed_clearance_control_details"]
    expected = fixture["expected_successor_projection"]
    exact(details["retained_semantic_step"], 82, "DETAIL_STEP")
    exact(details["retained_phase"], "establish_distal_support", "DETAIL_PHASE")
    exact(details["successor_pose_class"], expected["pose_class"], "DETAIL_POSE")
    exact(details["successor_minimum_nonfoot_clearance_m"], expected["minimum_nonfoot_clearance_m"], "DETAIL_CLEARANCE")
    exact(details["successor_next_phase"], expected["next_phase"], "DETAIL_NEXT_PHASE")
    exact(expected["raised_body_gate"], False, "FIXTURE_RAISED_GATE")
    exact(expected["stable_stance_gate"], False, "FIXTURE_STABLE_GATE")

    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(attempt[key], 0, f"ATTEMPT_{key.upper()}")
        exact(receipt[key], 0, f"RECEIPT_{key.upper()}")
        exact(preflight[key], 0, f"PREFLIGHT_{key.upper()}")
        exact(qualification[key], 0, f"QUALIFICATION_{key.upper()}")
    for value, code in (
        (receipt["physics_state_modified"], "RECEIPT_PHYSICS"),
        (receipt["physical_question_opened"], "RECEIPT_PHYSICAL"),
        (receipt["controller_physical_viability_proven"], "RECEIPT_CONTROLLER"),
        (receipt["prone_to_standing_claimed"], "RECEIPT_STANDING"),
        (receipt["physical_acceptance_authority"], "RECEIPT_ACCEPTANCE"),
        (receipt["release_authority"], "RECEIPT_RELEASE"),
    ):
        exact(value, False, code)

    decision = closure["decision"]
    exact(decision["result"], "positive_exact_retained_step82_signed_clearance_semantics_conformance", "DECISION")
    exact(decision["exact_retained_observation_accepted_as_complete_data"], True, "DECISION_ACCEPTED")
    exact(decision["successor_pose_class"], expected["pose_class"], "DECISION_POSE")
    exact(decision["successor_minimum_nonfoot_clearance_m"], expected["minimum_nonfoot_clearance_m"], "DECISION_CLEARANCE")
    exact(decision["raised_body_gate_passed"], False, "DECISION_RAISED")
    exact(decision["stable_stance_gate_passed"], False, "DECISION_STABLE")
    exact(decision["new_behavior_threshold_count"], 0, "DECISION_THRESHOLDS")
    exact(decision["new_empirical_threshold_count"], 0, "DECISION_EMPIRICAL")
    exact(decision["new_margin_count"], 0, "DECISION_MARGINS")
    exact(decision["r24d29_closed_without_physics"], True, "DECISION_CLOSED")
    exact(decision["r24d29_physical_execution_permitted"], False, "DECISION_PHYSICAL")

    exact(closure["sdk_status"]["sdk1_completed_steps"], 11, "SDK1_SCORE")
    exact(closure["sdk_status"]["full_program_completed_steps"], 11, "PROGRAM_SCORE")
    integration = closure["integration_observations"]
    exact(len(integration), 1, "INTEGRATION_COUNT")
    exact(integration[0]["official_qualification_result_rewritten"], False, "INTEGRATION_REWRITE")
    exact(integration[0]["official_qualification_reexecuted"], False, "INTEGRATION_RERUN")
    exact(integration[0]["world_attempt_count"], 0, "INTEGRATION_WORLDS")
    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D30", "NEXT_GATE")
    exact(next_boundary["status"], "not_yet_frozen_physical_execution_blocked", "NEXT_STATUS")
    exact(next_boundary["distinct_clean_pushed_source_freeze_required"], True, "NEXT_FREEZE")
    exact(next_boundary["r24d29_physical_execution_authorized"], False, "NEXT_PHYSICAL")
    exact(next_boundary["r24d29_may_be_requalified"], False, "NEXT_REQUALIFY")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    claims = closure["claim_boundary"]
    for key in (
        "official_zero_world_qualification_passed",
        "signed_clearance_semantics_conformance_positive",
        "exact_retained_observation_accepted_as_complete_data",
        "negative_clearance_preserved_and_blocks_progress",
    ):
        exact(claims[key], True, f"CLAIM_{key.upper()}")
    for key in (
        "r24d28_historical_result_rewritten",
        "physical_question_opened",
        "physical_behavior_result_observed",
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
        exact(claims[key], False, f"CLAIM_{key.upper()}")

    audit_log = (evidence_root / "source_audit.log").read_text(encoding="utf-8")
    require("QSDK_R24D29_SIGNED_CLEARANCE_SEMANTICS_SOURCE_PASS" in audit_log, "SOURCE_AUDIT_MARKER")
    print(
        "QSDK_R24D29_SIGNED_CLEARANCE_QUALIFICATION_CLOSURE_PASS "
        "sources=75 controls=45/45 models=0 worlds=0 solver_steps=0 "
        "clearance_m=-0.002553879273647315 pose=transitional "
        "raised=False stable=False physical=False next=QSDK-R24D30"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        OSError,
        KeyError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            f"QSDK_R24D29_SIGNED_CLEARANCE_QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
