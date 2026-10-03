#!/usr/bin/env python3
"""Audit the consumed post-physics command-readback-invalid R77 invocation."""

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
    "sdk/recovery/r24d77_godot_jolt_runtime_bound_recovery_behavior_"
    "incomplete_closure_v1.json"
)
SOURCE = "a0f10ef5c6e1f0d0c668eb67432141d09f6eb435"
STATUS = (
    "closed_consumed_invalid_incomplete_host_command_readback_before_pair_"
    "completion"
)


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d77_godot_jolt_runtime_bound_recovery_"
                "behavior_incomplete_closure_v1"
            ),
            "gate_id": "QSDK-R24D77",
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
            "source.parent_commit": "33ef933ab270b5354bcc5c610eb6fee32812904f",
            "source.tree": "3e7c0f48b262945f92465e8cb0dde5125a1843a3",
            "source.subject": (
                "[recovery/godot] Close R77 control: physical pair authorized"
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
        gate_id="QSDK-R24D77",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d77_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d77_godot_runtime_bound_recovery_"
                "behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d77_behavior_terminal_v1",
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
            "failure_code": "QSDK_R24D77_BEHAVIOR_COMMAND_APPLICATION_FAILED",
            "detail.failure_code": "QSDK_R24D57_COMMAND_READBACK_INVALID",
            "detail.detail": {},
            "physical_question_opened": True,
            "physics_state_modified": True,
            "physics_failure_is_valid_evidence": True,
            "arm_execution_summary.schema_version": (
                "sporespore_qsdk_godot_behavior_arm_invariant_summary_v1"
            ),
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 1,
            "arm_execution_summary.summarized_solver_step_count": 137,
            "arm_execution_summary.total_solver_step_count": 137,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:5e8f83e9d65aa5fd723f23b7edbc9bc322b8b5b8c452bbb2de4375be770323ee"
            ),
        },
        "RAW",
    )
    arm = raw["arm_execution_summary"]["ordered_arm_summaries"]
    exact(len(arm), 1, "RAW_ARM_COUNT")
    verify_exact_paths(
        arm[0],
        {
            "arm_kind": "candidate_command",
            "arm_identity_valid": True,
            "arm_result_validation_passed": True,
            "digest_shapes_valid": True,
            "all_in_run_physical_invariants_passed": True,
            "outer_step_count": 137,
            "native_solver_step_count": 137,
            "in_run_invariant_receipt_count": 137,
            "final_phase": "raise_body",
            "terminal_failure_code": None,
            "declared_initial_state_sha256": (
                "sha256:206ca392e57533334494fdab9f20d83a1f9a87b8e7aedeaeb225f7550837823f"
            ),
            "trace_v3_sha256": (
                "sha256:7f0c3f94917056caf046f059a3083afcb8116afae0cb3614af3473ce1e02bbb6"
            ),
            "in_run_invariant_population_sha256": (
                "sha256:037a229cf558f0289ea7601bb426ecbc34cdffa6fbb92a0658a643396908015e"
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
            "QSDK_R24D77_GODOT_RUNTIME_BOUND_RECOVERY_BEHAVIOR_RAW ",
            '"failure_code":"QSDK_R24D57_COMMAND_READBACK_INVALID"',
            '"failure_code":"QSDK_R24D77_BEHAVIOR_COMMAND_APPLICATION_FAILED"',
            "QSDK_R24D77_GODOT_RUNTIME_BOUND_RECOVERY_BEHAVIOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    exact((evidence / "godot.stderr.log").read_bytes(), b"", "STDERR_EMPTY")

    diagnosis = closure["runtime_and_command_readback_diagnosis"]
    route = source_bytes(
        ROOT, SOURCE, "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
    ).decode("utf-8")
    worker = source_bytes(
        ROOT, SOURCE, "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    ).decode("utf-8")
    gait = source_bytes(
        ROOT, SOURCE, "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    ).decode("utf-8")
    require("const COMMAND_READBACK_TOLERANCE := 1.0e-9" in route, "ROUTE_TOLERANCE")
    require("var canonical_velocity := clampf(" in route, "ROUTE_BINARY64_COMMAND")
    require(
        'float(item["godot_target_velocity_rad_s"]),' in route
        and "absf(readback - float(item[\"godot_target_velocity_rad_s\"]))"
        in route,
        "ROUTE_WRITE_READBACK_COMPARISON",
    )
    require(
        'return _failure("QSDK_R24D57_COMMAND_READBACK_INVALID")' in route,
        "ROUTE_FAILURE_DETAIL_OMITTED",
    )
    require(
        "_capture_completed_step()" in worker
        and "var semantic_step := int(_model.get(\"host_step_count\", 0)) + 1"
        in worker
        and "_abort(_failure_code(\"BEHAVIOR_COMMAND_APPLICATION_FAILED\"), application)"
        in worker,
        "WORKER_FAILURE_SEQUENCE",
    )
    require(
        "const P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S := 2.0e-8" in gait
        and "const P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S := 1.2e-7"
        in gait
        and "var host_values := PackedFloat32Array([value])" in gait,
        "PREEXISTING_HOST_REAL_MODEL",
    )
    historical = json.loads(
        source_bytes(
            ROOT,
            SOURCE,
            "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_"
            "characterization_closure_v1.json",
        )
    )
    historical_maximum = max(
        cell["maximum_target_velocity_readback_error_rad_s"]
        for cell in historical["ordered_cells"]
    )
    exact(
        historical_maximum,
        diagnosis["historical_observed_maximum_target_velocity_readback_error_rad_s"],
        "HISTORICAL_HOST_READBACK_MAXIMUM",
    )
    verify_exact_paths(
        diagnosis,
        {
            "qualified_runtime_selected": True,
            "production_worker_parse_passed": True,
            "raw_failure_code": "QSDK_R24D77_BEHAVIOR_COMMAND_APPLICATION_FAILED",
            "nested_failure_code": "QSDK_R24D57_COMMAND_READBACK_INVALID",
            "failure_semantic_step": 138,
            "failure_after_completed_solver_step_count": 137,
            "failure_during_first_raise_body_command_application": True,
            "frozen_route_command_readback_tolerance_rad_s": 1e-9,
            "frozen_route_projects_binary64_command_to_host_real_before_comparison": False,
            "precise_failing_actuator_and_delta_retained": False,
            "preexisting_host_command_quantization_tolerance_rad_s": 1.2e-7,
            "preexisting_motor_readback_tolerance_rad_s": 2e-8,
            "historical_observation_used_as_diagnostic_only": True,
            "threshold_or_behavior_evaluator_changed": False,
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
        ),
        (
            "matched_zero_world_executed",
            "controller_behavior_evaluated",
            "valid_behavior_result_observed",
            "scientific_positive_observed",
            "scientific_negative_observed",
            "same_identity_rerun_permitted",
            "r24d77_requalification_permitted",
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
            "partial_physical_observation.behavior_evaluator_invocation_count": 0,
            "partial_physical_observation.standing_observed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
            "next_boundary.gate_id": "QSDK-R24D78",
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
            "next_gate_id": "QSDK-R24D78",
            "r24d77_source_status": STATUS,
            "r24d77_physical_attempt_consumed": True,
            "r24d77_physical_attempt_count": 1,
            "r24d77_physical_invocation_source_commit": SOURCE,
            "r24d77_physical_attempt_id": "847988e339c84426a3403aff3dc3060e",
            "r24d77_physical_failure_code": (
                "QSDK_R24D77_BEHAVIOR_COMMAND_APPLICATION_FAILED"
            ),
            "r24d77_nested_failure_code": "QSDK_R24D57_COMMAND_READBACK_INVALID",
            "r24d77_physical_execution_authorized": False,
            "r24d77_physical_execution_blocked": True,
            "r24d77_observed_model_construction_count": 1,
            "r24d77_observed_world_build_count": 1,
            "r24d77_observed_solver_step_count": 137,
            "r24d77_observed_behavior_evaluator_invocation_count": 0,
            "r24d77_physical_question_opened": True,
            "r24d77_integration_valid": False,
            "r24d77_valid_behavior_result_observed": False,
            "r24d77_scientific_positive_observed": False,
            "r24d77_scientific_negative_observed": False,
            "r24d77_incomplete_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d77_incomplete_closure_raw_sha256": (
                "sha256:240e9dba7d5fca1497c826904843079fa1966c5b3b9dc926cf3ae8a2a87797d8"
            ),
            "r24d77_incomplete_closure_byte_length": 16535,
            "r24d78_distinct_successor_required": True,
            "r24d78_question_class": "development",
            "r24d78_physical_question_declared": False,
            "r24d78_complete_zero_world_gate_required": True,
            "r24d78_full_seeded_ghost_required": False,
            "r24d78_additional_physical_canary_required": False,
            "r24d78_physical_execution_authorized": False,
            "r24d78_physical_execution_blocked": True,
    }
    for relative in closure["live_authority_paths"]:
        live = json.loads((ROOT / relative).read_bytes())
        nodes = records_with_key(live, "r24d77_question_class")
        exact(len(nodes), 1, f"LIVE_R77_COUNT:{relative}")
        verify_exact_paths(nodes[0], live_expectations, f"LIVE_R77:{relative}")
    print(
        "QSDK_R24D77_GODOT_RUNTIME_BOUND_RECOVERY_BEHAVIOR_INCOMPLETE_"
        "CLOSURE_OK attempts=1 models=1 worlds=1 steps=137 invariants=137 "
        "pair=0 evaluator=0 readback_invalid=1 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
