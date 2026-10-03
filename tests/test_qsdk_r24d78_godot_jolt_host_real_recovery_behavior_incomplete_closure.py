#!/usr/bin/env python3
"""Audit the consumed command-digest-invalid R78 physical invocation."""

from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    records_with_key,
    require,
    require_ordered_markers,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d78_godot_jolt_host_real_recovery_behavior_"
    "incomplete_closure_v1.json"
)
SOURCE = "653eb1e40edeba61bfbe51fa20f61c9ad9bfa88e"
STATUS = "closed_consumed_invalid_incomplete_command_digest_before_pair_completion"
CLOSURE_SHA256 = (
    "sha256:9f1ecffab8278108f032d2fadffabef482b148d75ec1d1d7ffa62954b5a893c6"
)
CLOSURE_BYTES = 16541


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d78_godot_jolt_host_real_recovery_"
                "behavior_incomplete_closure_v1"
            ),
            "gate_id": "QSDK-R24D78",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": "consumed_physical_development_closure",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "a000c8a52902d5fb5fd2017a685f3b91fdb08fa8",
            "source.tree": "713fa27a6337badb6ecfc5b07603de61ba1c2aa4",
            "source.subject": (
                "[recovery/godot] Close R78 control: physical pair authorized"
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
    exact(len(closure["source"]["bindings"]), 10, "SOURCE_BINDING_COUNT")
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    physical = closure["physical_attempt"]
    exact(physical["attempt_count_for_exact_source_and_gate"], 1, "ATTEMPT_COUNT")
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D78",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d78_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d78_godot_host_real_recovery_behavior_"
                "raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d78_behavior_terminal_v1",
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
        raw,
        {
            "ok": False,
            "status": "invalid_or_incomplete_behavior_development",
            "failure_code": "QSDK_R24D78_BEHAVIOR_COMMAND_APPLICATION_FAILED",
            "detail.failure_code": "QSDK_R24D57_COMMAND_DIGEST_INVALID",
            "detail.detail": {},
            "physical_question_opened": True,
            "physics_state_modified": True,
            "physics_failure_is_valid_evidence": True,
            "model_construction_attempt_count": 1,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 393,
            "behavior_evaluator_invocation_count": 0,
            "held_out_cell_access_count": 0,
            "arm_execution_summary.schema_version": (
                "sporespore_qsdk_godot_behavior_arm_invariant_summary_v1"
            ),
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 1,
            "arm_execution_summary.summarized_solver_step_count": 393,
            "arm_execution_summary.total_solver_step_count": 393,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:659c0c8bb4c509a7ba539e70472790ba36faceeaccb3e49b539887edc1ce516e"
            ),
        },
        "RAW",
    )
    arms = raw["arm_execution_summary"]["ordered_arm_summaries"]
    exact(len(arms), 1, "RAW_ARM_COUNT")
    verify_exact_paths(
        arms[0],
        {
            "arm_kind": "candidate_command",
            "arm_identity_valid": True,
            "arm_result_validation_passed": True,
            "digest_shapes_valid": True,
            "all_in_run_physical_invariants_passed": True,
            "outer_step_count": 393,
            "native_solver_step_count": 393,
            "in_run_invariant_receipt_count": 393,
            "final_phase": "raise_body",
            "terminal_failure_code": None,
            "declared_initial_state_sha256": (
                "sha256:206ca392e57533334494fdab9f20d83a1f9a87b8e7aedeaeb225f7550837823f"
            ),
            "trace_v3_sha256": (
                "sha256:b344fa633dbc58941634f4c42f15632cb4ebda98db6836c9b6b281a8173f58f5"
            ),
            "in_run_invariant_population_sha256": (
                "sha256:999473f2a24a3aa5ef956e023423d461393954753407e56d871c56a96ffa4853"
            ),
        },
        "RAW_ARM",
    )
    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": False,
            "preflight.ok": True,
            "preflight.selected_console_sha256": (
                "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
            ),
            "preflight.selected_console_byte_length": 293376,
            "preflight.worker_parse_count": 1,
            "worker.semantic_exit_code": 1,
            "worker.termination_protocol_valid": True,
            "worker.raw_binding_valid": True,
            "recovery_success_observed": False,
            "prone_to_standing_claimed": False,
        },
        "TERMINAL",
    )
    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build.5b4e0cb0f",
            "QSDK_R24D78_GODOT_HOST_REAL_RECOVERY_BEHAVIOR_RAW ",
            '"failure_code":"QSDK_R24D57_COMMAND_DIGEST_INVALID"',
            '"failure_code":"QSDK_R24D78_BEHAVIOR_COMMAND_APPLICATION_FAILED"',
            "QSDK_R24D78_GODOT_HOST_REAL_RECOVERY_BEHAVIOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    exact((evidence / "godot.stderr.log").read_bytes(), b"", "STDERR_EMPTY")

    route = source_bytes(
        ROOT, SOURCE, "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
    ).decode("utf-8")
    worker = source_bytes(
        ROOT, SOURCE, "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    ).decode("utf-8")
    digest_check = (
        'if _sha256(sdk, commands) != String(control.get("command_sha256", "")):'
    )
    digest_failure = 'return _failure("QSDK_R24D57_COMMAND_DIGEST_INVALID")'
    command_preflight = "var unique_instances: Dictionary = {}"
    first_host_write = "joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)"
    require(
        all(marker in route for marker in (digest_check, digest_failure, command_preflight)),
        "ROUTE_DIGEST_BOUNDARY_MISSING",
    )
    require(first_host_write in route, "ROUTE_HOST_WRITE_MISSING")
    require(
        route.index(digest_check)
        < route.index(digest_failure)
        < route.index(command_preflight)
        < route.index(first_host_write),
        "ROUTE_DIGEST_NOT_PREWRITE",
    )
    require(
        worker.index("_total_solver_step_count += 1")
        < worker.index("_memory = (advanced[\"next_memory\"] as Dictionary).duplicate(true)")
        < worker.index("var application := RouteScript.apply_behavior_control_v1(")
        < worker.index(
            '_abort(_failure_code("BEHAVIOR_COMMAND_APPLICATION_FAILED"), application)'
        ),
        "WORKER_FAILURE_SEQUENCE",
    )

    diagnosis = closure["command_digest_diagnosis"]
    verify_exact_paths(
        diagnosis,
        {
            "qualified_runtime_selected": True,
            "production_worker_parse_passed": True,
            "raw_failure_code": "QSDK_R24D78_BEHAVIOR_COMMAND_APPLICATION_FAILED",
            "nested_failure_code": "QSDK_R24D57_COMMAND_DIGEST_INVALID",
            "failure_after_completed_solver_step_count": 393,
            "source_projected_failed_application_semantic_step": 394,
            "failure_during_candidate_raise_body_command_application": True,
            "failure_preceded_host_command_preflight_and_writes": True,
            "portable_receipt_command_digest_recomputed_by_godot_adapter": True,
            "expected_and_recomputed_digest_values_retained": False,
            "offending_command_or_numeric_field_retained": False,
            "exact_numeric_root_cause_claimed": False,
            "r78_host_real_projection_reached_393_completed_steps_without_readback_failure": True,
            "threshold_controller_evaluator_or_physical_envelope_changed": False,
            "termination_protocol_valid": True,
            "integration_valid": False,
            "valid_behavior_pair_completed": False,
            "scientific_positive_observed": False,
            "scientific_negative_observed": False,
        },
        "DIAGNOSIS",
    )

    verify_boolean_partition(
        closure["decision"],
        (
            "physical_invocation_retained",
            "physical_invocation_consumed_for_exact_source",
            "authorization_and_control_valid",
            "qualified_runtime_selected",
            "termination_protocol_valid",
            "raw_result_bound",
            "integration_or_evidence_failure_observed",
            "physics_state_modified",
            "physical_question_opened",
            "model_constructed",
            "world_constructed",
            "solver_steps_executed",
            "partial_candidate_trace_retained",
            "host_real_projection_progressed_beyond_r77",
        ),
        (
            "matched_zero_world_executed",
            "controller_behavior_evaluated",
            "valid_behavior_result_observed",
            "scientific_positive_observed",
            "scientific_negative_observed",
            "same_identity_rerun_permitted",
            "r24d78_requalification_permitted",
            "historical_result_rewritten",
            "prone_to_standing_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        "DECISION",
    )
    verify_exact_paths(
        closure,
        {
            "partial_physical_observation.complete_candidate_arm_observed": False,
            "partial_physical_observation.matched_zero_arm_started": False,
            "partial_physical_observation.behavior_evaluator_invocation_count": 0,
            "partial_physical_observation.standing_observed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
            "next_boundary.gate_id": "QSDK-R24D79",
            "next_boundary.question_class": "development",
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_blocked": True,
            "next_boundary.maximum_world_attempt_count": 0,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "next_boundary.full_seeded_ghost_required": False,
            "next_boundary.additional_physical_canary_required": False,
            "claim_boundary.integration_valid": False,
            "claim_boundary.candidate_prefix_invariants_valid": True,
            "claim_boundary.complete_candidate_arm_observed": False,
            "claim_boundary.matched_zero_arm_observed": False,
            "claim_boundary.behavior_evaluator_invoked": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
        },
        "CLAIMS",
    )

    live_expectations = {
        "next_gate_id": "QSDK-R24D79",
        "r24d78_source_status": STATUS,
        "r24d78_physical_attempt_consumed": True,
        "r24d78_physical_attempt_count": 1,
        "r24d78_physical_invocation_source_commit": SOURCE,
        "r24d78_physical_attempt_id": "6e157a552c5c472aad2c86ec458b1fc6",
        "r24d78_physical_failure_code": (
            "QSDK_R24D78_BEHAVIOR_COMMAND_APPLICATION_FAILED"
        ),
        "r24d78_nested_failure_code": "QSDK_R24D57_COMMAND_DIGEST_INVALID",
        "r24d78_physical_execution_authorized": False,
        "r24d78_physical_execution_blocked": True,
        "r24d78_observed_model_construction_count": 1,
        "r24d78_observed_world_build_count": 1,
        "r24d78_observed_solver_step_count": 393,
        "r24d78_observed_behavior_evaluator_invocation_count": 0,
        "r24d78_physical_question_opened": True,
        "r24d78_integration_valid": False,
        "r24d78_valid_behavior_result_observed": False,
        "r24d78_scientific_positive_observed": False,
        "r24d78_scientific_negative_observed": False,
        "r24d78_incomplete_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d78_incomplete_closure_raw_sha256": CLOSURE_SHA256,
        "r24d78_incomplete_closure_byte_length": CLOSURE_BYTES,
        "r24d79_distinct_successor_required": True,
        "r24d79_question_class": "development",
        "r24d79_physical_question_declared": False,
        "r24d79_complete_zero_world_gate_required": True,
        "r24d79_full_seeded_ghost_required": False,
        "r24d79_additional_physical_canary_required": False,
        "r24d79_physical_execution_authorized": False,
        "r24d79_physical_execution_blocked": True,
    }
    for relative in closure["live_authority_paths"]:
        live = json.loads((ROOT / relative).read_bytes())
        nodes = records_with_key(live, "r24d78_question_class")
        exact(len(nodes), 1, f"LIVE_R78_COUNT:{relative}")
        verify_exact_paths(nodes[0], live_expectations, f"LIVE_R78:{relative}")

    print(
        "QSDK_R24D78_GODOT_HOST_REAL_RECOVERY_BEHAVIOR_INCOMPLETE_"
        "CLOSURE_PASS attempts=1 models=1 worlds=1 steps=393 invariants=393 "
        "pair=0 evaluator=0 digest_invalid=1 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
