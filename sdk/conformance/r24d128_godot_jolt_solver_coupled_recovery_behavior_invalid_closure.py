#!/usr/bin/env python3
"""Thin R128 binding for the reusable infrastructure-invalid closure audit."""

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
        "progress_marker_count": 3,
        "progress_binding_valid": False,
        "complete_raw_result_observed": True,
        "actual_model_construction_count_observable": True,
        "actual_model_construction_count": 1,
        "actual_world_attempt_count_observable": True,
        "actual_world_attempt_count": 1,
        "actual_world_build_count_observable": True,
        "actual_world_build_count": 1,
        "actual_solver_step_count_observable": True,
        "actual_solver_step_count": 28,
        "actual_behavior_evaluator_invocation_count_observable": True,
        "actual_behavior_evaluator_invocation_count": 0,
        "physics_state_modified_observable": True,
        "physics_state_modified": True,
    },
    "raw_exact_paths": {
        "ok": False,
        "status": "invalid_or_incomplete_behavior_development",
        "failure_code": "QSDK_R24D128_BEHAVIOR_COMMAND_APPLICATION_FAILED",
        "source_commit": "c2094719e4856a11ad954c578d3b7ca0ff39b700",
        "actuator_mode": "solver_coupled_native_constraint_motor_v1",
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "model_construction_attempt_count": 1,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 28,
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
        "arm_execution_summary.completed_arm_count": 1,
        "detail.ok": True,
        "detail.semantic_step": 29,
        "detail.source_control_semantic_step": 28,
        "detail.phase": "establish_distal_support",
        "detail.solver_coupled_motor_target_write_count": 8,
        "detail.motor_enabled_count": 8,
        "detail.host_write_count": 8,
        "detail.host_readback_count": 8,
        "detail.pre_solver_direct_body_impulse_write_count": 0,
        "detail.physics_state_modified": False,
    },
    "raw_first_arm_exact_paths": {
        "arm_kind": "candidate_command",
        "outer_step_count": 28,
        "native_solver_step_count": 28,
        "in_run_invariant_receipt_count": 28,
        "all_in_run_physical_invariants_passed": True,
        "in_run_invariant_population_sha256": (
            "sha256:e88635a2f2cf920fdb721112f8f28a5e7efb03b3ec71d1715a1a1470316f03b6"
        ),
    },
    "terminal_exact_paths": {
        "worker.semantic_exit_code": 1,
        "worker.host_exit_code": -1,
        "worker.timed_out": False,
        "worker.timeout_kind": "",
        "worker.termination_protocol_valid": True,
        "worker.termination_protocol_failure_code": "",
        "worker.raw_marker_count": 1,
        "worker.raw_binding_valid": True,
        "worker.progress_marker_count": 3,
        "worker.progress_binding_valid": False,
        "worker.progress_cadence_steps": 30,
        "worker.progress_stall_timeout_seconds": 600,
        "worker.total_timeout_seconds": 24000,
        "worker.last_progress_receipt.arm_kind": "candidate_command",
        "worker.last_progress_receipt.arm_step_count": 28,
        "worker.last_progress_receipt.completed_solver_step_count": 28,
        "worker.last_progress_receipt.milestone": "failure_serialization_started",
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "active_solver_coupled_application_mutation_flag_mismatch_before_step_29"
        ),
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.producer_consumer_mutation_semantics_mismatch_established": True,
        "interpretation.native_physics_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r129_distinct_successor_required": True,
        "claim_boundary.partial_physical_trajectory_observed": True,
        "claim_boundary.in_run_physical_invariants_observable": True,
        "claim_boundary.all_observed_in_run_physical_invariants_passed": True,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d128_godot_jolt_solver_coupled_recovery_behavior_invalid_closure_v1.json",
            "sporespore_qsdk_r24d128_godot_jolt_solver_coupled_recovery_behavior_invalid_closure_v1",
            "QSDK-R24D128",
            "sha256:837c2b0f2b3d73f91bb3bdaa6dec094945dab633db232fed85aabad1c1b44690",
            15463,
            "QSDK_R24D128_SOLVER_COUPLED_RECOVERY_BEHAVIOR_INVALID_CLOSURE_PASS",
            "QSDK_R24D128_SOLVER_COUPLED_RECOVERY_BEHAVIOR_INVALID_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d128_godot_jolt_solver_coupled_recovery_"
                "behavior_contract_v1.json"
            ),
            live_record_key="r24d128_contract_path",
            live_identity_prefix="r24d128_physical_closure",
            next_gate_id="QSDK-R24D129",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
