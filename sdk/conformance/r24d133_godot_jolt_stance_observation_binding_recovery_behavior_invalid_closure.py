#!/usr/bin/env python3
"""Thin R133 binding for the reusable infrastructure-invalid closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_infrastructure_invalid_physical_closure import (  # noqa: E402
    run_cli,
)


STRUCTURED_INVALID_PROFILE = {
    "physical_exact_paths": {
        "worker_timeout_seconds": 24000,
        "worker_semantic_exit_code": 1,
        "worker_host_exit_code": -1,
        "worker_timed_out": False,
        "termination_protocol_valid": True,
        "raw_marker_count": 1,
        "raw_binding_valid": True,
        "progress_marker_count": 26,
        "progress_binding_valid": True,
        "complete_raw_result_observed": True,
        "actual_model_construction_count_observable": True,
        "actual_model_construction_count": 2,
        "actual_world_attempt_count_observable": True,
        "actual_world_attempt_count": 2,
        "actual_world_build_count_observable": True,
        "actual_world_build_count": 2,
        "actual_solver_step_count_observable": True,
        "actual_solver_step_count": 568,
        "actual_behavior_evaluator_invocation_count_observable": True,
        "actual_behavior_evaluator_invocation_count": 0,
        "behavior_evaluator_refusal_receipt_observed": True,
        "physics_state_modified_observable": True,
        "physics_state_modified": True,
    },
    "raw_exact_paths": {
        "ok": False,
        "status": "invalid_or_incomplete_behavior_development",
        "failure_code": "QSDK_R24D133_BEHAVIOR_EVALUATOR_FAILED",
        "source_commit": "055b469a90410435d93fb4ba23d042d6c3880dc7",
        "actuator_mode": "solver_coupled_native_constraint_motor_v1",
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "model_construction_attempt_count": 2,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": 568,
        "behavior_evaluator_invocation_count": 0,
        "physical_question_opened": True,
        "physics_state_modified": True,
        "physics_failure_is_valid_evidence": True,
        "held_out": False,
        "held_out_cell_access_count": 0,
        "population_inference_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "arm_execution_summary.completed_arm_count": 2,
        "arm_execution_summary.status": "population_consistent",
        "arm_execution_summary.summarized_solver_step_count": 568,
        "arm_execution_summary.total_solver_step_count": 568,
        "arm_execution_summary.ordered_arm_summaries_sha256": (
            "sha256:7486ea7637ed4f399d17fede8e9f0ad6643a538379fef46ea1514a9dc2ae3967"
        ),
        "detail.failure_code": "QSDK_R24D65_BEHAVIOR_EVALUATION_REFUSED",
        "detail.detail.support_status": "invalid_observation",
        "detail.detail.refusal_reason": "trace_or_initial_state_invalid",
        "detail.detail.verdict": "refused",
        "detail.detail.candidate_trace.observation_count": 300,
        "detail.detail.candidate_trace.accepted_observation_count": 59,
        "detail.detail.candidate_trace.final_phase": "refused",
        "detail.detail.candidate_trace.terminal_failure_code": (
            "active_recovery_phase_owner_invalid"
        ),
        "detail.detail.matched_zero_command_trace.observation_count": 268,
        "detail.detail.matched_zero_command_trace.accepted_observation_count": 268,
        "detail.detail.matched_zero_command_trace.final_phase": "failed",
        "detail.detail.matched_zero_command_trace.terminal_failure_code": (
            "phase_timeout:establish_distal_support"
        ),
        "detail.detail.model_construction_count": 0,
        "detail.detail.world_attempt_count": 0,
        "detail.detail.world_build_count": 0,
        "detail.detail.solver_step_count": 0,
        "detail.detail.physics_state_modified": False,
    },
    "raw_ordered_arm_exact_paths": [
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 300,
            "native_solver_step_count": 300,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:stance_dwell",
            "in_run_invariant_receipt_count": 300,
            "all_in_run_physical_invariants_passed": True,
            "arm_identity_valid": True,
            "arm_result_validation_passed": True,
            "digest_shapes_valid": True,
            "in_run_invariant_population_sha256": (
                "sha256:d8a6319ecade308b2e93b7676e03b2ce8d15afda44896edb04988809b0f52d8f"
            ),
            "trace_v3_sha256": (
                "sha256:183a731bd7a26514c2edbe8617dc25bbd3cf45c4e13c8ea5a1ffef0b55cd5fc1"
            ),
        },
        {
            "arm_kind": "matched_zero_command",
            "outer_step_count": 268,
            "native_solver_step_count": 268,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:establish_distal_support",
            "in_run_invariant_receipt_count": 268,
            "all_in_run_physical_invariants_passed": True,
            "arm_identity_valid": True,
            "arm_result_validation_passed": True,
            "digest_shapes_valid": True,
            "in_run_invariant_population_sha256": (
                "sha256:83f7a9764dbe480bf71a1bcf19739230157c9f1b9281dc1135ac45f10b139e58"
            ),
            "trace_v3_sha256": (
                "sha256:1853ddabb263553be324b0fd7cd06e19b13f04bffbe65b73d648895e66d8ac04"
            ),
        },
    ],
    "terminal_exact_paths": {
        "worker.semantic_exit_code": 1,
        "worker.host_exit_code": -1,
        "worker.timed_out": False,
        "worker.timeout_kind": "",
        "worker.termination_protocol_valid": True,
        "worker.termination_protocol_failure_code": "",
        "worker.raw_marker_count": 1,
        "worker.raw_binding_valid": True,
        "worker.progress_marker_count": 26,
        "worker.progress_binding_valid": True,
        "worker.progress_cadence_steps": 30,
        "worker.progress_stall_timeout_seconds": 600,
        "worker.total_timeout_seconds": 24000,
        "worker.last_progress_receipt.arm_kind": "matched_zero_command",
        "worker.last_progress_receipt.arm_step_count": 268,
        "worker.last_progress_receipt.completed_solver_step_count": 568,
        "worker.last_progress_receipt.milestone": "failure_serialization_started",
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "v4_evaluator_replay_omits_r126_development_progression_and_"
            "rejects_first_stance_owned_candidate_observation"
        ),
        "observed_failure.evaluation_refusal_reason": "trace_or_initial_state_invalid",
        "observed_failure.candidate_replay_failure_code": (
            "active_recovery_phase_owner_invalid"
        ),
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.v4_evaluator_development_progression_omission_established": True,
        "interpretation.stance_observation_binding_failure_established": False,
        "interpretation.native_physics_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r134_distinct_successor_required": True,
        "claim_boundary.partial_physical_trajectory_observed": True,
        "claim_boundary.physical_arm_terminal_summaries_observed": True,
        "claim_boundary.in_run_physical_invariants_observable": True,
        "claim_boundary.all_observed_in_run_physical_invariants_passed": True,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d133_godot_jolt_stance_observation_binding_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d133_godot_jolt_stance_observation_binding_recovery_behavior_physical_closure_v1",
            "QSDK-R24D133",
            "sha256:b64b51f7749573654018c1baeda80a018fdf85acedc0997abe19d19bc78041fa",
            17071,
            "QSDK_R24D133_STANCE_OBSERVATION_BINDING_RECOVERY_BEHAVIOR_INVALID_CLOSURE_PASS",
            "QSDK_R24D133_STANCE_OBSERVATION_BINDING_RECOVERY_BEHAVIOR_INVALID_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d133_godot_jolt_stance_observation_binding_"
                "recovery_behavior_contract_v1.json"
            ),
            live_record_key="r24d133_contract_path",
            live_identity_prefix="r24d133_physical_closure",
            next_gate_id="QSDK-R24D134",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
