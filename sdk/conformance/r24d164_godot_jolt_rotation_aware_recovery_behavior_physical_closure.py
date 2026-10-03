#!/usr/bin/env python3
"""Thin R164 binding for the reusable infrastructure-invalid closure audit."""

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
        "actual_solver_step_count": 1,
        "actual_behavior_evaluator_invocation_count_observable": True,
        "actual_behavior_evaluator_invocation_count": 0,
        "accepted_in_run_invariant_receipt_count": 0,
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
        "failure_code": "QSDK_R24D164_BEHAVIOR_IN_RUN_INVARIANT_INVALID",
        "source_commit": "2e51ec18594a588aaa0b04475f92d6f8f49861b8",
        "actuator_mode": "solver_coupled_native_constraint_motor_v1",
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "model_construction_attempt_count": 1,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 1,
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
        "arm_execution_summary.completed_arm_count": 0,
        "arm_execution_summary.summarized_solver_step_count": 0,
        "arm_execution_summary.total_solver_step_count": 1,
        "detail.schema_version": (
            "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_"
            "in_run_invariant_receipt_v1"
        ),
        "detail.semantic_step": 1,
        "detail.native_space_step_sequence": 1,
        "detail.adapter_side_discrete_staging_event_count": 1,
        "detail.all_in_run_physical_invariants_passed": True,
        "detail.complete_energy_invariants_passed": True,
        "detail.discrete_staging_invariants_passed": True,
        "detail.route_aware_application_provenance_invariants_passed": True,
        "detail.rotation_aware_energy_ledger_invariants_passed": True,
        "detail.rotation_integration_exchange_included_exactly_once": True,
        "detail.native_engine_health_passed": True,
        "detail.native_source_trace_schema": (
            "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_"
            "native_source_trace_v1"
        ),
        "detail.recovery_energy_ledger_profile_id": (
            "godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
        ),
        "detail.application_provenance_profile_id": (
            "godot_jolt_r24d152_route_aware_discrete_staging_"
            "application_provenance_v1"
        ),
    },
    "raw_ordered_arm_exact_paths": [],
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
        "worker.last_progress_receipt.arm_step_count": 0,
        "worker.last_progress_receipt.completed_solver_step_count": 1,
        "worker.last_progress_receipt.milestone": "failure_serialization_started",
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "rotation_aware_native_source_trace_rejected_by_legacy_r152_"
            "schema_validator_after_first_solver_step"
        ),
        "observed_failure.semantic_step": 1,
        "observed_failure.observed_native_source_trace_schema": (
            "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_"
            "native_source_trace_v1"
        ),
        "observed_failure.validator_expected_native_source_trace_schema": (
            "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_"
            "native_source_trace_v1"
        ),
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.stale_native_source_trace_schema_validator_mismatch_established": True,
        "interpretation.native_physics_failure_established": False,
        "interpretation.physical_invariant_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r165_distinct_successor_required": True,
        "claim_boundary.one_native_solver_step_executed": True,
        "claim_boundary.partial_physical_trajectory_observed": True,
        "claim_boundary.in_run_physical_invariants_observable": True,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d164_godot_jolt_rotation_aware_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d164_godot_jolt_rotation_aware_recovery_behavior_physical_closure_v1",
            "QSDK-R24D164",
            "sha256:809f7729dcb222e9fb73290e4fb61dd9c17f76040ba9045f2768e9f810f1c2c9",
            15195,
            "QSDK_R24D164_ROTATION_AWARE_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D164_ROTATION_AWARE_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d164_godot_jolt_rotation_aware_recovery_"
                "behavior_contract_v1.json"
            ),
            live_record_key="r24d164_contract_path",
            live_identity_prefix="r24d164_physical_closure",
            next_gate_id="QSDK-R24D165",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
