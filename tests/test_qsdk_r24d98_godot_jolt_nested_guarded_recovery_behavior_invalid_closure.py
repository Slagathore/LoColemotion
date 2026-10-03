#!/usr/bin/env python3
"""Audit the consumed inference-invalid R98 Godot/Jolt behavior attempt."""

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
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "invalid_closure_v1.json"
)
SOURCE = "57e2a31c08b58307944d38e6615f204da2cd7144"
LENGTH = 16793
DIGEST = "sha256:2407fcbce4d82a1ca4575ee5701b73b667e58629a6348448fcb9787e2ed2c6e8"
STATUS = (
    "closed_consumed_invalid_incomplete_nested_guarded_recovery_behavior_no_"
    "feasible_parent_scale_r99_required"
)

DECISION_TRUE = tuple(
    """
behavior_attempt_consumed_for_exact_source model_construction_completed
world_build_completed thirty_nine_solver_steps_completed physics_state_modified
termination_protocol_valid native_engine_health_passed
all_declared_in_run_invariants_for_retained_steps_passed
outer_guard_source_envelope_exceeded nested_guard_failed_closed
invalid_incomplete_result_retained distinct_r99_successor_required
""".split()
)
DECISION_FALSE = tuple(
    """
same_identity_rerun_permitted r24d98_requalification_permitted
complete_candidate_and_matched_zero_pair_observed behavior_evaluator_invoked
valid_complete_behavior_result valid_physics_behavior_negative
controller_physical_viability_proven recovery_success_established
historical_threshold_changed historical_selector_changed
historical_evaluator_changed historical_result_rewritten
prone_to_standing_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split()
)
CLAIM_TRUE = tuple(
    """
behavior_attempt_retained behavior_attempt_consumed_for_exact_source
one_model_and_world_constructed thirty_nine_solver_steps_executed
physics_state_modified termination_protocol_valid native_engine_health_passed
declared_in_run_invariants_for_retained_steps_passed
guard_projection_refusal_observed invalid_incomplete_result_retained
""".split()
)
CLAIM_FALSE = tuple(
    """
complete_paired_behavior_result matched_zero_arm_observed
behavior_evaluator_invoked valid_complete_behavior_result
valid_physics_behavior_negative controller_physical_viability_proven
recovery_success_established prone_to_standing_claimed population_claimed
cross_engine_recovery_claimed cross_engine_equivalence_claimed
sdk1_milestone_advanced physical_acceptance_authority release_authority
""".split()
)


def audit() -> None:
    raw_closure = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw_closure), sha256(raw_closure)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D98",
            "stage_id": "R24D98-BEHAVIOR",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "retained_finite_physical_development_invalid_closure"
            ),
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "396e247a16e2e5090bf3f80e3bd39e98b28127d5",
            "source.tree": "4526582b7a4709a610923e9f9957473a8913ebe7",
            "source.subject": (
                "[recovery/godot] Close R98 qualification: authorize finite "
                "behavior pair"
            ),
        },
        "CLOSURE",
    )
    for field, fmt in (("parent_commit", "%P"), ("tree", "%T"), ("subject", "%s")):
        exact(
            git(ROOT, "show", "-s", f"--format={fmt}", SOURCE),
            closure["source"][field],
            f"SOURCE_{field.upper()}",
        )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:4f481afaa2b6d9c90271f7ad35ad29f152f7daf05df686ada864b85c65e8b365"
            ),
            "qualification_closure_byte_length": 19900,
            "qualification_source_freeze_commit": (
                "396e247a16e2e5090bf3f80e3bd39e98b28127d5"
            ),
            "authorization_publication_commit": SOURCE,
            "complete_zero_world_gate_satisfied": True,
            "phase_aware_postpublication_source_audit_passed": True,
            "direct_committed_closure_recheck_satisfied": True,
            "qualified_physical_source_drift_check_passed": True,
            "qualified_physical_path_count": 48,
            "clean_pushed_remote_equality_passed": True,
            "same_identity_requalification_permitted": False,
        },
        "AUTHORIZATION",
    )

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D98",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d98_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d98_godot_nested_guarded_recovery_"
                "behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d98_behavior_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count",
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
        physical,
        {
            "attempt_count_for_exact_source_and_gate": 1,
            "seed": 278151771,
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_solver_step_count": 2400,
            "behavior_development_completed": False,
            "model_construction_attempt_count": 1,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 39,
            "behavior_evaluator_invocation_count": 0,
            "held_out_cell_access_count": 0,
            "retained_arm_summary_count": 1,
            "retained_in_run_invariant_receipt_count": 39,
            "physics_state_modified": True,
        },
        "PHYSICAL",
    )
    verify_exact_paths(
        raw,
        {
            "ok": False,
            "failure_code": "QSDK_R24D98_BEHAVIOR_COMMAND_APPLICATION_FAILED",
            "actuator_mode": (
                "force_based_nested_native_angular_velocity_guarded_v1"
            ),
            "physical_question_opened": True,
            "physics_failure_is_valid_evidence": True,
            "recovery_success_required_for_valid_result": False,
            "physics_state_modified": True,
            "behavior_evaluator_invocation_count": 0,
            "detail.body_impulse_write_count": 14,
            "detail.failure_code": (
                "QSDK_R24D94_GUARDED_PAIR_PROJECTION_INVALID:7"
            ),
            "detail.native_angular_velocity_readback_count": 23,
            "detail.detail.failure_code": (
                "QSDK_R24D96_NESTED_PAIR_TARGET_PROJECTION_FAILED"
            ),
            "detail.detail.detail.predecessor_projection_failure.failure_code": (
                "QSDK_R24D94_GUARD_NO_FEASIBLE_BODY_SCALE:7"
            ),
            "detail.detail.detail.predecessor_projection_failure.detail.parent_interval.failure_code": (
                "QSDK_R24D94_GUARD_INTERVAL_OUTSIDE_UNIT"
            ),
            "detail.detail.detail.predecessor_projection_failure.detail.child_interval.ok": True,
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 1,
            "arm_execution_summary.summarized_solver_step_count": 39,
            "arm_execution_summary.total_solver_step_count": 39,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:96d03d7dd6d06ca32a16c7154ea0d87aaba911bc70e34bc21fbdc31d4848a6c1"
            ),
        },
        "PRODUCER_RAW",
    )
    summaries = raw["arm_execution_summary"]["ordered_arm_summaries"]
    exact(len(summaries), 1, "ARM_SUMMARY_COUNT")
    verify_exact_paths(
        summaries[0],
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 39,
            "native_solver_step_count": 39,
            "final_phase": "establish_distal_support",
            "terminal_failure_code": None,
            "in_run_invariant_receipt_count": 39,
            "all_in_run_physical_invariants_passed": True,
        },
        "CANDIDATE_SUMMARY",
    )
    exact(
        sha256(canonical_bytes(summaries)),
        raw["arm_execution_summary"]["ordered_arm_summaries_sha256"],
        "ARM_SUMMARY_HASH",
    )
    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": False,
            "completed_utc": physical["completed_utc"],
            "source.head": SOURCE,
            "source.live_origin_main": SOURCE,
            "worker.semantic_exit_code": 1,
            "worker.host_exit_code": -1,
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.termination_protocol_failure_code": "",
            "worker.engine_health.passed": True,
            "worker.engine_health.stderr_raw_byte_length": 0,
            "worker.engine_health.fatal_diagnostic_line_count": 0,
            "recovery_success_observed": False,
            "same_identity_rerun_permitted": False,
        },
        "PRODUCER_TERMINAL",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D98_GODOT_NESTED_GUARDED_RECOVERY_BEHAVIOR_RAW ",
            '"failure_code":"QSDK_R24D98_BEHAVIOR_COMMAND_APPLICATION_FAILED"',
            "QSDK_R24D98_GODOT_NESTED_GUARDED_RECOVERY_BEHAVIOR_READY ",
        ),
        "STDOUT",
    )
    exact((evidence / "godot.stderr.log").read_bytes(), b"", "STDERR_EMPTY")
    world_source = source_bytes(
        ROOT,
        SOURCE,
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
    ).decode("utf-8")
    for marker in (
        "QSDK_R24D94_GUARD_INTERVAL_OUTSIDE_UNIT",
        "parent_source_speed <= outer_guard_limit",
        "child_source_speed <= outer_guard_limit",
        "QSDK_R24D96_NESTED_PAIR_TARGET_PROJECTION_FAILED",
    ):
        require(marker in world_source, f"BOUND_BRANCH_MARKER:{marker}")
    verify_exact_paths(
        closure["observed_failure"],
        {
            "classification": (
                "invalid_incomplete_candidate_arm_guard_projection_refusal_"
                "after_39_steps"
            ),
            "failed_actuator_index": 7,
            "completed_body_impulse_write_count": 14,
            "completed_native_angular_velocity_readback_count": 23,
            "candidate_outer_step_count": 39,
            "candidate_declared_in_run_invariant_receipt_count": 39,
            "candidate_all_declared_in_run_physical_invariants_passed": True,
            "matched_zero_arm_started": False,
            "behavior_evaluator_invoked": False,
            "native_engine_health_passed": True,
            "fatal_diagnostic_line_count": 0,
            "termination_protocol_valid": True,
            "worker_timed_out": False,
            "raw_physics_failure_is_valid_evidence_field": True,
            "valid_physics_behavior_negative": False,
            "complete_paired_behavior_result_valid": False,
            "at_least_one_source_body_above_outer_guard_inferred": True,
            "source_body_identity_and_speed_retained": False,
            "recovery_success_established": False,
            "prone_to_standing_established": False,
        },
        "OBSERVED_FAILURE",
    )

    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
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
            "gate_id": "QSDK-R24D99",
            "question_class": "development_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "r24d98_may_be_rerun_or_requalified": False,
            "r24d98_guard_target_selector_or_evaluator_may_be_rewritten": False,
            "full_seeded_behavior_ghost_required": False,
            "additional_physical_canary_required": False,
            "held_out_cells_remain_sealed": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    revision = publication or None
    published_raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    # This historical audit owns immutable R98 facts and the retained R99
    # diagnostic erratum only. Live successor progression (declaration,
    # qualification, later claims, and next-gate selection) belongs to the
    # active successor audit; binding it here would make valid forward progress
    # turn the historical regression red without changing any R98 evidence.
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d98_contract_path",
        expected={
            "r24d98_source_status": STATUS,
            "r24d98_physical_attempt_consumed": True,
            "r24d98_physical_attempt_disposition": (
                "invalid_or_incomplete_behavior_development"
            ),
            "r24d98_behavior_invalid_closure_path": relative,
            "r24d98_behavior_invalid_closure_raw_sha256": sha256(published_raw),
            "r24d98_behavior_invalid_closure_byte_length": len(published_raw),
            "r24d98_behavior_evidence_root": physical["evidence_root"],
            "r24d98_invocation_source_commit": SOURCE,
            "r24d98_attempt_id": physical["attempt_id"],
            "r24d98_observed_model_construction_count": 1,
            "r24d98_observed_world_attempt_count": 1,
            "r24d98_observed_world_build_count": 1,
            "r24d98_observed_solver_step_count": 39,
            "r24d98_observed_behavior_evaluator_invocation_count": 0,
            "r24d98_observed_in_run_invariant_receipt_count": 39,
            "r24d98_native_engine_health_passed": True,
            "r24d98_behavior_command_application_failed": True,
            "r24d98_outer_guard_source_envelope_exceeded": False,
            "r24d98_invalid_closure_outer_guard_inference_preserved": True,
            "r24d99_forward_erratum_applied": True,
            "r24d99_outer_guard_exceedance_not_established": True,
            "r24d99_mixed_numeric_predicate_witness_observed": True,
            "r24d99_legacy_length_predicate_inside": True,
            "r24d99_legacy_squared_predicate_inside": False,
            "r24d99_legacy_length_squared_rad2_s2": 2219.576904296875,
            "r24d99_component_and_limit_squared_rad2_s2": 2219.5768011798064,
            "r24d99_boundary_development_probe_path": (
                "tests/test_sdk_godot_r24d99_guard_boundary_consistency_zero_world.gd"
            ),
            "r24d99_boundary_probe_model_construction_count": 0,
            "r24d99_boundary_probe_world_build_count": 0,
            "r24d99_boundary_probe_solver_step_count": 0,
            "r24d98_valid_complete_behavior_result": False,
            "r24d98_behavior_negative_accepted_for_inference": False,
            "r24d98_physical_execution_authorized": False,
            "r24d98_authorized_world_count": 0,
            "r24d98_maximum_outer_solver_steps": 0,
            "r24d98_sdk1_milestone_advanced": False,
            "r24d99_distinct_successor_required": True,
            "r24d99_question_class": "development",
        },
        prefix="LIVE_R98_INVALID",
    )
    print(
        "QSDK_R24D98_GODOT_JOLT_NESTED_GUARDED_RECOVERY_BEHAVIOR_INVALID_"
        "CLOSURE_PASS attempts=1 models=1 worlds=1 steps=39 evaluator=0 "
        "native_health=pass result=invalid next=R24D99 sdk1=11/20"
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
            "QSDK_R24D98_GODOT_JOLT_NESTED_GUARDED_RECOVERY_BEHAVIOR_"
            f"INVALID_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
