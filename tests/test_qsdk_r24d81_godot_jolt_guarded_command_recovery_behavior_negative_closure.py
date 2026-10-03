#!/usr/bin/env python3
"""Audit the consumed valid finite R81 Godot/Jolt recovery negative."""

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
    records_with_key,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "negative_closure_v1.json"
)
SOURCE = "c17178c2ef5447fb4368ab268ef1a6eb94c5b595"
STATUS = (
    "closed_consumed_valid_finite_negative_raise_body_timeout_after_"
    "distal_support"
)
EVIDENCE_ROOT = (
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d81-godot-jolt-guarded-command-recovery-behavior/"
    "20260831T055732234Z-c17178c2-f84335e6"
)
DECISION_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "valid_complete_behavior_result_observed",
    "scientific_negative_observed",
    "both_models_constructed",
    "both_worlds_built",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_accepted",
    "all_acceptance_checks_passed",
    "all_in_run_physical_invariants_passed",
    "candidate_distal_support_completed",
    "candidate_raise_body_timeout_observed",
    "matched_zero_distal_support_timeout_observed",
    "candidate_progress_beyond_matched_zero_observed",
    "distinct_successor_required",
)
DECISION_FALSE = (
    "same_identity_rerun_permitted",
    "r24d81_requalification_permitted",
    "recovery_success_observed",
    "portable_controller_general_failure_claimed",
    "native_physics_fault_claimed",
    "actuator_cap_inadequacy_claimed",
    "behavior_threshold_inadequacy_claimed",
    "energy_ledger_defect_claimed",
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
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_accepted",
    "all_acceptance_checks_passed",
    "all_999_in_run_physical_invariants_passed",
    "retained_candidate_distal_support_completion",
    "retained_candidate_raise_body_timeout_observation",
    "retained_matched_zero_distal_support_timeout_observation",
    "candidate_progress_beyond_matched_zero_observed",
    "distinct_successor_required",
)
CLAIM_FALSE = (
    "recovery_success_observed",
    "portable_controller_general_failure_claimed",
    "native_physics_fault_claimed",
    "actuator_cap_inadequacy_claimed",
    "behavior_threshold_inadequacy_claimed",
    "energy_ledger_defect_claimed",
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
    arm: dict, summary: dict, arm_kind: str, expected_count: int
) -> None:
    receipts = arm["in_run_invariant_receipts"]
    exact(len(receipts), expected_count, f"{arm_kind}:INVARIANT_COUNT")
    exact(
        [receipt["semantic_step"] for receipt in receipts],
        list(range(1, expected_count + 1)),
        f"{arm_kind}:SEMANTIC_STEPS",
    )
    exact(
        [receipt["native_space_step_sequence"] for receipt in receipts],
        list(range(1, expected_count + 1)),
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


def verify_live_projection(closure: dict) -> None:
    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    closure_blob = (
        source_bytes(ROOT, publication, relative)
        if publication
        else CLOSURE.read_bytes()
    )
    expected = {
        "r24d81_source_status": STATUS,
        "r24d81_physical_attempt_consumed": True,
        "r24d81_physical_attempt_disposition": (
            "valid_finite_negative_raise_body_timeout_after_distal_support"
        ),
        "r24d81_behavior_negative_closure_path": relative,
        "r24d81_behavior_negative_closure_raw_sha256": sha256(closure_blob),
        "r24d81_behavior_negative_closure_byte_length": len(closure_blob),
        "r24d81_behavior_evidence_root": EVIDENCE_ROOT,
        "r24d81_invocation_source_commit": SOURCE,
        "r24d81_attempt_id": "f84335e61d3744b698661b81eaa6d970",
        "r24d81_observed_model_construction_count": 2,
        "r24d81_observed_world_attempt_count": 2,
        "r24d81_observed_world_build_count": 2,
        "r24d81_observed_solver_step_count": 999,
        "r24d81_observed_behavior_evaluator_invocation_count": 1,
        "r24d81_observed_in_run_invariant_receipt_count": 999,
        "r24d81_observed_scientific_outcome": "negative",
        "r24d81_valid_complete_behavior_result_observed": True,
        "r24d81_recovery_success_observed": False,
        "r24d81_all_in_run_physical_invariants_passed": True,
        "r24d81_candidate_completed_distal_support": True,
        "r24d81_candidate_terminal_failure_code": "phase_timeout:raise_body",
        "r24d81_candidate_maximum_com_height_gain_m": 0.16204401850700378,
        "r24d81_matched_zero_terminal_failure_code": (
            "phase_timeout:establish_distal_support"
        ),
        "r24d81_physical_execution_authorized": False,
        "r24d81_physical_execution_blocked": True,
        "r24d82_distinct_successor_required": True,
        "r24d82_question_class": "development",
        "r24d82_physical_question_declared": False,
        "physical_execution_blocked_until_r24d82_zero_world_qualification": True,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    for authority_path in closure["live_authority_paths"]:
        raw = (
            source_bytes(ROOT, publication, authority_path)
            if publication
            else (ROOT / authority_path).read_bytes()
        )
        authority = load_bytes(raw)
        records = records_with_key(authority, "r24d81_behavior_negative_closure_path")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_path}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_path}",
        )


def load_bytes(raw: bytes) -> dict:
    import json

    value = json.loads(raw)
    require(isinstance(value, dict), "LIVE_AUTHORITY_NOT_OBJECT")
    return value


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d81_godot_jolt_guarded_command_recovery_"
                "behavior_negative_closure_v1"
            ),
            "gate_id": "QSDK-R24D81",
            "stage_id": "R24D81-BEHAVIOR",
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
                "12290ca40de2d4f8d76d96fa096c1be42c179308"
            ),
            "source.tree": "d19b147fe60c842e9f727703f55b39802de07ca9",
            "source.subject": "[recovery/godot] Close R81 authorization control",
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
        gate_id="QSDK-R24D81",
        source_commit=SOURCE,
        status="valid_complete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d81_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d81_godot_guarded_command_recovery_"
                "behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d81_behavior_terminal_v1",
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
            "evaluation_acceptance_receipt.ok": True,
            "evaluation_acceptance_receipt.status": "accepted",
            "evaluation_acceptance_receipt.scientific_outcome": "negative",
            "evaluation_acceptance_receipt.verdict": "physical_development_failed",
            "evaluation_acceptance_receipt.common_check_count": 22,
            "evaluation_acceptance_receipt.common_pass_count": 22,
            "evaluation_acceptance_receipt.verdict_check_count": 9,
            "evaluation_acceptance_receipt.verdict_pass_count": 9,
            "candidate_arm.outer_step_count": 736,
            "candidate_arm.native_solver_step_count": 736,
            "candidate_arm.final_phase": "failed",
            "candidate_arm.terminal_failure_code": "phase_timeout:raise_body",
            "matched_zero_arm.outer_step_count": 263,
            "matched_zero_arm.native_solver_step_count": 263,
            "matched_zero_arm.final_phase": "failed",
            "matched_zero_arm.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 2,
            "arm_execution_summary.summarized_solver_step_count": 999,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:210b10444280778eaf0b4e6d9cda6f543658b882a88591cd45358245832f50a6"
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
        raw["candidate_arm"], summaries[0], "candidate_command", 736
    )
    verify_invariant_population(
        raw["matched_zero_arm"], summaries[1], "matched_zero_command", 263
    )

    candidate = raw["candidate_arm"]
    matched_zero = raw["matched_zero_arm"]
    candidate_classifications = [
        receipt["classification"] for receipt in candidate["portable_step_receipts"]
    ]
    zero_classifications = [
        receipt["classification"]
        for receipt in matched_zero["portable_step_receipts"]
    ]
    exact(candidate["final_memory"]["ordered_completed_phases"], [
        "confirm_prone", "establish_distal_support"
    ], "CANDIDATE_COMPLETED_PHASES")
    exact(
        matched_zero["final_memory"]["ordered_completed_phases"],
        ["confirm_prone"],
        "ZERO_COMPLETED_PHASES",
    )
    exact(
        (
            sum(item["distal_support_gate"] for item in candidate_classifications),
            sum(item["raised_body_gate"] for item in candidate_classifications),
            sum(item["safety_gate"] for item in candidate_classifications),
            sum(item["stable_stance_gate"] for item in candidate_classifications),
            sum(item["no_cheat_gate"] for item in candidate_classifications),
        ),
        (572, 0, 0, 0, 736),
        "CANDIDATE_GATE_COUNTS",
    )
    exact(
        sum(item["distal_support_gate"] for item in zero_classifications),
        0,
        "ZERO_DISTAL_SUPPORT_COUNT",
    )
    exact(
        max(item["center_of_mass_height_gain_m"] for item in candidate_classifications),
        0.16204401850700378,
        "CANDIDATE_MAX_COM_GAIN",
    )
    final_classification = candidate_classifications[-1]
    verify_exact_paths(
        final_classification,
        {
            "all_four_distal_sites_bearing": True,
            "any_nonfoot_contact": False,
            "minimum_nonfoot_clearance_m": 0.00887451238077884,
            "joint_limits_respected": True,
            "actuator_budget_respected": True,
            "maximum_nonfoot_contact_impulse_ns": 0.0,
            "center_of_mass_height_gain_m": 0.16203534603118896,
            "energy_balance_residual_j": 95828.9067539014,
            "raised_body_gate": False,
            "safety_gate": False,
            "no_cheat_gate": True,
        },
        "CANDIDATE_FINAL_CLASSIFICATION",
    )
    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": True,
            "completed_utc": physical["completed_utc"],
            "source.head": SOURCE,
            "source.live_origin_main": SOURCE,
            "authorization.control.raw_sha256": (
                "sha256:d9faf90ca9cfbad7fe29480b9426518ec2594eee22da20d072532a50f5d8ce13"
            ),
            "worker.semantic_exit_code": 0,
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.termination_protocol_failure_code": "",
            "recovery_success_observed": False,
            "same_identity_rerun_permitted": False,
        },
        "TERMINAL",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D81_GODOT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_RAW ",
            '"scientific_outcome":"negative"',
            "QSDK_R24D81_GODOT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_TERMINATION_READY ",
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
                "valid_finite_negative_candidate_raise_body_timeout_after_"
                "distal_support_while_zero_timed_out_distal_support"
            ),
            "integration_or_evidence_failure_established": False,
            "verdict_aware_consumer_acceptance_passed": True,
            "portable_evaluator_verdict": "physical_development_failed",
            "candidate_observation_count": 736,
            "candidate_completed_phases": [
                "confirm_prone", "establish_distal_support"
            ],
            "candidate_terminal_failure_code": "phase_timeout:raise_body",
            "candidate_distal_support_gate_true_count": 572,
            "candidate_raised_body_gate_true_count": 0,
            "candidate_maximum_com_height_gain_m": 0.16204401850700378,
            "frozen_minimum_com_height_gain_m": 0.22,
            "candidate_final_energy_balance_residual_j": 95828.9067539014,
            "frozen_maximum_energy_balance_residual_j": 0.25,
            "matched_zero_observation_count": 263,
            "matched_zero_terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "all_999_in_run_physical_invariants_passed": True,
            "candidate_progress_beyond_matched_zero_observed": True,
            "portable_controller_general_failure_established": False,
            "native_physics_fault_established": False,
            "actuator_cap_inadequacy_established": False,
            "behavior_threshold_inadequacy_established": False,
            "energy_ledger_defect_established": False,
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
            "gate_id": "QSDK-R24D82",
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "diagnostic_reuse_of_consumed_r81_evidence_permitted": True,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "zero_world_route_coverage_must_match_declared_change": True,
            "r24d81_may_be_rerun_or_requalified": False,
        },
        "NEXT",
    )
    verify_live_projection(closure)
    print(
        "QSDK_R24D81_GODOT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_NEGATIVE_"
        "CLOSURE_PASS attempts=1 models=2 worlds=2 steps=999 evaluator=1 "
        "invariants=999/999 candidate=raise_body_timeout zero=distal_support_timeout "
        "outcome=negative next=R24D82 sdk1=11/20"
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
            "QSDK_R24D81_GODOT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_NEGATIVE_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
