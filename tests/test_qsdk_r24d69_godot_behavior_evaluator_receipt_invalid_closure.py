"""Audit the consumed R69 worker-predicate integration invalidity."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
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
    "sdk/recovery/r24d69_godot_behavior_evaluator_receipt_"
    "invalid_closure_v1.json"
)
SOURCE = "1fd9b510c20d58bb35ffe508113b5de2b22d714c"
STATUS = (
    "closed_consumed_invalid_positive_only_worker_evaluator_receipt_"
    "acceptance_predicate"
)
DECISION_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "both_models_constructed",
    "both_worlds_built",
    "five_hundred_twenty_six_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_returned",
    "portable_evaluator_trace_valid",
    "worker_acceptance_predicate_contradiction_established",
    "distinct_successor_source_required",
    "consumer_predicate_repair_required",
)
DECISION_FALSE = (
    "same_identity_rerun_permitted",
    "r24d69_requalification_permitted",
    "valid_physical_behavior_result_observed",
    "behavior_physics_failure_established",
    "controller_failure_established",
    "recovery_result_established",
    "historical_threshold_changed",
    "historical_margin_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "invalid_integration_result",
    "both_models_constructed",
    "both_worlds_built",
    "five_hundred_twenty_six_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_returned",
    "portable_evaluator_trace_valid",
    "retained_candidate_phase_timeout_observation",
    "retained_matched_zero_phase_timeout_observation",
    "worker_acceptance_predicate_contradiction_established",
    "distinct_successor_required",
)
CLAIM_FALSE = (
    "valid_physical_behavior_result_observed",
    "behavior_physics_failure_established",
    "controller_failure_established",
    "recovery_result_established",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d69_godot_behavior_evaluator_receipt_"
                "invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D69",
            "stage_id": "R24D69-BEHAVIOR",
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
                "515e91cc9f846f52548dcfe5313eb52928e2225e"
            ),
            "source.tree": "b65a7ef67b85e71bf47e1ee36cfd96c771f9ea01",
            "source.subject": (
                "[recovery/godot] Close R69 control: finite pair authorized"
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
        gate_id="QSDK-R24D69",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d69_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d69_godot_native_effective_"
                "impulse_limit_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d69_behavior_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "failure_code": physical["failure_code"],
            "physical_question_opened": True,
            "physics_failure_is_valid_evidence": True,
            "recovery_success_required_for_valid_result": False,
            "detail.support_status": "supported_exact",
            "detail.verdict": "physical_development_failed",
            "detail.initial_state_identity_matched": True,
            "detail.physical_development_trace_valid": True,
            "detail.candidate_physical_path_completed": False,
            "detail.candidate_trace.observation_count": 263.0,
            "detail.candidate_trace.accepted_observation_count": 263.0,
            "detail.candidate_trace.final_phase": "failed",
            "detail.candidate_trace.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "detail.matched_zero_command_physical_control_failed_to_complete": True,
            "detail.matched_zero_command_trace.observation_count": 263.0,
            "detail.matched_zero_command_trace.accepted_observation_count": 263.0,
            "detail.matched_zero_command_trace.final_phase": "failed",
            "detail.matched_zero_command_trace.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "detail.all_negative_control_requirements_enforced": False,
            "detail.controller_implemented": True,
            "detail.physical_threshold_authority": True,
            "detail.physical_question_opened": True,
            "detail.physical_result": False,
            "model_construction_attempt_count": 2,
            "model_construction_count": 2,
            "world_attempt_count": 2,
            "world_build_count": 2,
            "solver_step_count": 526,
            "maximum_solver_step_count": 2400,
            "behavior_evaluator_invocation_count": 0,
            "held_out_cell_access_count": 0,
            "physics_state_modified": True,
        },
        "RAW_RESULT",
    )
    verify_exact_paths(
        terminal,
        {
            "physical_question_kind": "behavior_development",
            "integration_ghost_passed": False,
            "behavior_development_completed": False,
            "completed_utc": physical["completed_utc"],
            "worker.termination_protocol_failure_code": "",
            "worker.termination_protocol_valid": True,
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
            "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_RAW ",
            physical["failure_code"],
            "QSDK_R24D69_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    worker = bound[
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    ].decode()
    core = bound["sdk/core/src/recovery.rs"].decode()
    require_ordered_markers(
        worker,
        (
            '"physical_development_passed",',
            '"physical_development_failed",',
            '"physical_development_incomplete",',
            'or not bool(evaluation.get("all_negative_control_requirements_enforced", false))',
            '_abort(_failure_code("BEHAVIOR_EVALUATOR_RECEIPT_INVALID"), evaluation)',
        ),
        "WORKER_ACCEPTANCE",
    )
    require_ordered_markers(
        core,
        (
            "let physical_development_passed = candidate_physical_path_completed",
            "let physical_development_incomplete = physical_development_trace_valid",
            "RecoveryEvaluationVerdictV1::PhysicalDevelopmentFailed",
            "all_negative_control_requirements_enforced: synthetic_canary_passed",
            "|| physical_development_passed",
        ),
        "CORE_FLAG_SEMANTICS",
    )
    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "classification": (
                "positive_only_worker_acceptance_predicate_rejected_supported_"
                "failed_evaluator_receipt"
            ),
            "portable_evaluator_receipt_returned": True,
            "portable_evaluator_support_status": "supported_exact",
            "portable_evaluator_verdict": "physical_development_failed",
            "portable_evaluator_trace_valid": True,
            "candidate_observation_count": 263,
            "candidate_accepted_observation_count": 263,
            "matched_zero_observation_count": 263,
            "matched_zero_accepted_observation_count": 263,
            "all_negative_control_requirements_enforced": False,
            "worker_declares_failed_and_incomplete_verdicts_admissible": True,
            "worker_unconditionally_requires_all_negative_control_requirements_enforced": True,
            "core_sets_physical_all_negative_control_flag_only_for_physical_development_passed": True,
            "failed_or_incomplete_receipt_can_satisfy_worker_predicate": False,
            "worker_acceptance_predicate_contradiction_established": True,
            "behavior_physics_failure_established": False,
            "controller_failure_established": False,
            "recovery_result_established": False,
            "distinct_successor_required": True,
            "additional_physical_ghost_required": False,
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
            "gate_id": "QSDK-R24D70",
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "positive_negative_incomplete_and_refusal_controls_required": True,
            "compact_invalid_path_arm_invariant_summary_required": True,
            "portable_core_or_evaluator_change_permitted": False,
            "behavior_threshold_change_permitted": False,
            "actuator_cap_change_permitted": False,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "r24d69_may_be_rerun_or_requalified": False,
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
            "r24d69_behavior_invalid_closure_raw_sha256": sha256(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D69_GODOT_BEHAVIOR_EVALUATOR_RECEIPT_INVALID_CLOSURE_PASS "
        "attempts=1 models=2 worlds=2 steps=526 evaluator_receipt=1 "
        "accepted_evaluator=0 predicate_contradiction=1 next=R24D70 sdk1=11/20"
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
            "QSDK_R24D69_GODOT_BEHAVIOR_EVALUATOR_RECEIPT_INVALID_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
