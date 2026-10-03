#!/usr/bin/env python3
"""Thin R153 binding for the reusable infrastructure-invalid closure audit."""

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
        "raw_binding_valid": False,
        "progress_marker_count": 3,
        "progress_binding_valid": False,
        "native_engine_health_screen_passed": True,
        "complete_raw_result_observed": True,
        "actual_model_construction_count_observable": True,
        "actual_model_construction_count": 1,
        "actual_world_attempt_count_observable": True,
        "actual_world_attempt_count": 1,
        "actual_world_build_count_observable": True,
        "actual_world_build_count": 1,
        "actual_solver_step_count_observable": True,
        "actual_solver_step_count": 2,
        "actual_behavior_evaluator_invocation_count_observable": True,
        "actual_behavior_evaluator_invocation_count": 0,
        "accepted_in_run_invariant_receipt_count": 1,
        "physics_state_modified_observable": True,
        "physics_state_modified": True,
        "recovery_energy_route_id": (
            "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_"
            "energy_recovery_observation_v3_route_v1"
        ),
    },
    "raw_exact_paths": {
        "ok": False,
        "status": "invalid_or_incomplete_behavior_development",
        "failure_code": "QSDK_R24D153_BEHAVIOR_IN_RUN_INVARIANT_INVALID",
        "source_commit": "e88070c40b98e347cba747723b8dd89180652c30",
        "actuator_mode": "solver_coupled_native_constraint_motor_v1",
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "model_construction_attempt_count": 1,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 2,
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
        "arm_execution_summary.status": "population_inconsistent",
        "arm_execution_summary.completed_arm_count": 1,
        "arm_execution_summary.summarized_solver_step_count": 2,
        "arm_execution_summary.total_solver_step_count": 2,
        "detail.schema_version": (
            "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_"
            "complete_energy_in_run_invariant_receipt_v1"
        ),
        "detail.semantic_step": 2,
        "detail.native_space_step_sequence": 2,
        "detail.adapter_side_discrete_staging_event_count": 2,
        "detail.all_in_run_physical_invariants_passed": True,
        "detail.complete_energy_invariants_passed": True,
        "detail.discrete_staging_invariants_passed": True,
        "detail.route_aware_application_provenance_invariants_passed": True,
        "detail.native_engine_health_passed": True,
        "detail.application_provenance_profile_id": (
            "godot_jolt_r24d152_route_aware_discrete_staging_"
            "application_provenance_v1"
        ),
    },
    "raw_ordered_arm_exact_paths": [
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 1,
            "native_solver_step_count": 2,
            "in_run_invariant_receipt_count": 1,
            "all_in_run_physical_invariants_passed": True,
            "arm_result_validation_passed": False,
            "final_phase": "confirm_prone",
            "terminal_failure_code": None,
        }
    ],
    "terminal_exact_paths": {
        "worker.semantic_exit_code": 1,
        "worker.host_exit_code": -1,
        "worker.timed_out": False,
        "worker.timeout_kind": "",
        "worker.termination_protocol_valid": True,
        "worker.termination_protocol_failure_code": "",
        "worker.raw_marker_count": 1,
        "worker.raw_binding_valid": False,
        "worker.progress_marker_count": 3,
        "worker.progress_binding_valid": False,
        "worker.progress_cadence_steps": 30,
        "worker.progress_stall_timeout_seconds": 600,
        "worker.total_timeout_seconds": 24000,
        "worker.last_progress_receipt.arm_kind": "candidate_command",
        "worker.last_progress_receipt.arm_step_count": 1,
        "worker.last_progress_receipt.completed_solver_step_count": 2,
        "worker.last_progress_receipt.milestone": "failure_serialization_started",
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "cumulative_discrete_staging_event_count_rejected_by_"
            "per_observation_validator_after_second_solver_step"
        ),
        "observed_failure.observed_cumulative_event_count": 2,
        "observed_failure.validator_expected_event_count": 1,
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.cumulative_vs_per_observation_count_mismatch_established": True,
        "interpretation.native_physics_failure_established": False,
        "interpretation.physical_invariant_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r154_distinct_successor_required": True,
        "claim_boundary.two_native_solver_steps_executed": True,
        "claim_boundary.partial_physical_trajectory_observed": True,
        "claim_boundary.in_run_physical_invariants_observable": True,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d153_godot_jolt_route_aware_discrete_staging_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d153_godot_jolt_route_aware_discrete_staging_recovery_behavior_physical_closure_v1",
            "QSDK-R24D153",
            "sha256:4342d429574a525840996d6b24fab44df8aab7f772bbd6b697ea7450c89a27a4",
            16065,
            "QSDK_R24D153_ROUTE_AWARE_DISCRETE_STAGING_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D153_ROUTE_AWARE_DISCRETE_STAGING_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d153_godot_jolt_route_aware_discrete_staging_"
                "recovery_behavior_contract_v1.json"
            ),
            live_record_key="r24d153_contract_path",
            live_identity_prefix="r24d153_physical_closure",
            next_gate_id="QSDK-R24D154",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
