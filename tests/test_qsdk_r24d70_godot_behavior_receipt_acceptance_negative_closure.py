"""Audit the consumed valid finite R24D70 Godot/Jolt negative."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    canonical_bytes,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d70_godot_behavior_receipt_acceptance_"
    "negative_closure_v1.json"
)
SOURCE = "766149fd9c31c00241e11040ab7cd2fa8ae5939b"
STATUS = "closed_consumed_valid_finite_negative_distal_support_timeout"
DECISION_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "valid_complete_behavior_result_observed",
    "scientific_negative_observed",
    "both_models_constructed",
    "both_worlds_built",
    "five_hundred_twenty_six_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_accepted",
    "all_acceptance_checks_passed",
    "all_in_run_physical_invariants_passed",
    "candidate_distal_support_timeout_observed",
    "matched_zero_distal_support_timeout_observed",
    "r69_invalid_result_preserved",
    "distinct_successor_required",
)
DECISION_FALSE = (
    "same_identity_rerun_permitted",
    "r24d70_requalification_permitted",
    "recovery_success_observed",
    "portable_controller_general_failure_claimed",
    "historical_threshold_changed",
    "historical_margin_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "repeatability_rate_claimed",
    "population_claimed",
    "held_out_validation_claimed",
    "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "valid_complete_behavior_result_observed",
    "scientific_negative_observed",
    "both_models_constructed",
    "both_worlds_built",
    "five_hundred_twenty_six_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_accepted",
    "all_acceptance_checks_passed",
    "all_526_in_run_physical_invariants_passed",
    "retained_candidate_distal_support_timeout_observation",
    "retained_matched_zero_distal_support_timeout_observation",
    "r69_invalid_result_preserved",
    "distinct_successor_required",
)
CLAIM_FALSE = (
    "recovery_success_observed",
    "portable_controller_general_failure_claimed",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "repeatability_rate_claimed",
    "population_claimed",
    "held_out_validation_claimed",
    "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def verify_invariant_population(
    arm: dict, summary: dict, arm_kind: str
) -> None:
    receipts = arm["in_run_invariant_receipts"]
    exact(len(receipts), 263, f"{arm_kind}:INVARIANT_COUNT")
    exact(
        [receipt["semantic_step"] for receipt in receipts],
        list(range(1, 264)),
        f"{arm_kind}:SEMANTIC_STEPS",
    )
    exact(
        [receipt["native_space_step_sequence"] for receipt in receipts],
        list(range(1, 264)),
        f"{arm_kind}:NATIVE_STEPS",
    )
    require(
        all(
            receipt["schema_version"]
            == "sporespore_qsdk_r24d65_godot_in_run_invariant_receipt_v1"
            and receipt["arm_kind"] == arm_kind
            and receipt["all_in_run_physical_invariants_passed"] is True
            and receipt["missing_measurement_synthesis_count"] == 0
            and receipt["adapter_side_discrete_staging_event_count"] == 0
            and sum(receipt["external_interventions"].values()) == 0
            and receipt["controller_ownership"]["fallback_controller_active"]
            is False
            and receipt["controller_ownership"]["source_measurement"] is True
            for receipt in receipts
        ),
        f"{arm_kind}:IN_RUN_INVARIANTS",
    )
    exact(
        sha256(canonical_bytes(receipts)),
        summary["in_run_invariant_population_sha256"],
        f"{arm_kind}:POPULATION_HASH",
    )
    exact(summary["trace_v3_sha256"], arm["trace_v3_sha256"], f"{arm_kind}:TRACE")


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_"
                "negative_closure_v1"
            ),
            "gate_id": "QSDK-R24D70",
            "stage_id": "R24D70-BEHAVIOR",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": "physical_development_closure",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "78d039fed96a39f72302be3c2f78f19e7e4b2abe"
            ),
            "source.tree": "414370d59de2c37fe2dca5c52f89201fc7ce35d4",
            "source.subject": (
                "[recovery/godot] Close R70 control: physical pair authorized"
            ),
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%T", SOURCE),
        closure["source"]["tree"],
        "SOURCE_TREE",
    )
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D70",
        source_commit=SOURCE,
        status="valid_complete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d70_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d70_godot_behavior_receipt_"
                "acceptance_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d70_behavior_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "complete_trace_count",
            "in_run_invariant_receipt_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "scientific_outcome": "negative",
            "physical_question_opened": True,
            "physics_failure_is_valid_evidence": True,
            "recovery_success_required_for_valid_result": False,
            "recovery_success_observed": False,
            "all_in_run_physical_invariants_passed": True,
            "evaluation_receipt.support_status": "supported_exact",
            "evaluation_receipt.verdict": "physical_development_failed",
            "evaluation_receipt.physical_development_trace_valid": True,
            "evaluation_receipt.candidate_physical_path_completed": False,
            "evaluation_receipt.matched_zero_command_physical_control_failed_to_complete": True,
            "evaluation_receipt.all_negative_control_requirements_enforced": False,
            "evaluation_acceptance_receipt.ok": True,
            "evaluation_acceptance_receipt.status": "accepted",
            "evaluation_acceptance_receipt.scientific_outcome": "negative",
            "evaluation_acceptance_receipt.verdict": "physical_development_failed",
            "evaluation_acceptance_receipt.common_check_count": 22,
            "evaluation_acceptance_receipt.common_pass_count": 22,
            "evaluation_acceptance_receipt.verdict_check_count": 9,
            "evaluation_acceptance_receipt.verdict_pass_count": 9,
            "candidate_arm.outer_step_count": 263,
            "candidate_arm.native_solver_step_count": 263,
            "candidate_arm.final_phase": "failed",
            "candidate_arm.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "matched_zero_arm.outer_step_count": 263,
            "matched_zero_arm.native_solver_step_count": 263,
            "matched_zero_arm.final_phase": "failed",
            "matched_zero_arm.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 2,
            "arm_execution_summary.summarized_solver_step_count": 526,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:30c42a7fbe6a6147c02c9c49d47ec87d37567394f7db8947dd4bcb44a9bcc048"
            ),
        },
        "RAW_RESULT",
    )
    require(
        all(raw["evaluation_acceptance_receipt"]["common_checks"].values()),
        "COMMON_CHECKS",
    )
    require(
        all(raw["evaluation_acceptance_receipt"]["verdict_checks"].values()),
        "VERDICT_CHECKS",
    )
    exact(
        raw["candidate_arm"]["declared_initial_state_sha256"],
        raw["matched_zero_arm"]["declared_initial_state_sha256"],
        "INITIAL_STATE_IDENTITY",
    )
    summaries = raw["arm_execution_summary"]["ordered_arm_summaries"]
    exact(
        sha256(canonical_bytes(summaries)),
        raw["arm_execution_summary"]["ordered_arm_summaries_sha256"],
        "SUMMARY_HASH",
    )
    verify_invariant_population(
        raw["candidate_arm"], summaries[0], "candidate_command"
    )
    verify_invariant_population(
        raw["matched_zero_arm"], summaries[1], "matched_zero_command"
    )
    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": True,
            "completed_utc": physical["completed_utc"],
            "worker.termination_protocol_failure_code": "",
            "recovery_success_observed": False,
        },
        "TERMINAL",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_RAW ",
            '"scientific_outcome":"negative"',
            "QSDK_R24D70_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    worker = bound[
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    ].decode()
    require_ordered_markers(
        worker,
        (
            "validate_physical_evaluation_receipt_v1(evaluation)",
            "compact_behavior_arm_invariant_summary_v1(",
            '"scientific_outcome": (',
            '"evaluation_acceptance_receipt": acceptance,',
            '"arm_execution_summary": arm_execution_summary,',
        ),
        "WORKER_SEMANTICS",
    )
    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "classification": (
                "valid_finite_negative_candidate_and_zero_timed_out_"
                "establish_distal_support"
            ),
            "integration_or_evidence_failure_established": False,
            "verdict_aware_consumer_acceptance_passed": True,
            "portable_evaluator_verdict": "physical_development_failed",
            "acceptance_common_pass_count": 22,
            "acceptance_verdict_pass_count": 9,
            "candidate_observation_count": 263,
            "matched_zero_observation_count": 263,
            "all_526_in_run_physical_invariants_passed": True,
            "finite_candidate_recovery_failure_observed": True,
            "portable_controller_general_failure_established": False,
            "native_physics_fault_established": False,
            "actuator_cap_inadequacy_established": False,
            "behavior_threshold_inadequacy_established": False,
            "distinct_successor_required_before_any_new_physical_attempt": True,
        },
        "CAUSE",
    )
    verify_boolean_partition(
        closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION"
    )
    verify_boolean_partition(
        closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM"
    )
    exact(
        closure["sdk_status"],
        {
            "sdk1_milestone_advanced": False,
            "sdk1_completed_steps": 11,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": 11,
            "full_program_total_steps": 25,
        },
        "SDK_STATUS",
    )
    verify_exact_paths(
        closure["next_boundary"],
        {
            "gate_id": "QSDK-R24D71",
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "diagnostic_reuse_of_consumed_r70_evidence_permitted": True,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "r24d70_may_be_rerun_or_requalified": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    revision = publication or None
    raw_closure = (
        CLOSURE.read_bytes()
        if revision is None
        else source_bytes(ROOT, revision, relative)
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d70_behavior_negative_closure_raw_sha256": sha256(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_NEGATIVE_"
        "CLOSURE_PASS attempts=1 models=2 worlds=2 steps=526 evaluator=1 "
        "invariants=526/526 outcome=negative next=R24D71 sdk1=11/20"
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
            "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_NEGATIVE_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
