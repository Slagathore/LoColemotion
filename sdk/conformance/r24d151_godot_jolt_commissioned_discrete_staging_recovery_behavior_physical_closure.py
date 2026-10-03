#!/usr/bin/env python3
"""Thin R151 binding for the reusable infrastructure-invalid closure audit."""

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
        "failure_code": "QSDK_R24D151_BEHAVIOR_NATIVE_SAMPLE_FAILED",
        "source_commit": "189161d0c4edc47ed8665eb58128afdbea74f11b",
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
        "detail.ok": False,
        "detail.failure_code": "QSDK_R24D144_WORLD_APPLICATION_PROVENANCE_INVALID",
        "detail.native_runtime_observation_collection_executed": False,
        "detail.model_construction_count": 0,
        "detail.world_attempt_count": 0,
        "detail.world_build_count": 0,
        "detail.solver_step_count": 0,
        "detail.physics_state_modified": False,
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
        "worker.last_progress_receipt.completed_solver_step_count": 0,
        "worker.last_progress_receipt.milestone": "failure_serialization_started",
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "r148_application_rejected_by_r144_only_native_sampler_"
            "after_first_solver_step"
        ),
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.producer_consumer_route_provenance_mismatch_established": True,
        "interpretation.native_physics_failure_established": False,
        "interpretation.physical_invariant_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r152_distinct_successor_required": True,
        "claim_boundary.one_native_solver_step_executed": True,
        "claim_boundary.partial_physical_trajectory_observed": False,
        "claim_boundary.in_run_physical_invariants_observable": False,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d151_godot_jolt_commissioned_discrete_staging_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d151_godot_jolt_commissioned_discrete_staging_recovery_behavior_physical_closure_v1",
            "QSDK-R24D151",
            "sha256:9929eacfee966913cb8ffad663d8e5811a7555784d38e9a466f0d935ba129251",
            15879,
            "QSDK_R24D151_COMMISSIONED_DISCRETE_STAGING_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D151_COMMISSIONED_DISCRETE_STAGING_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d151_godot_jolt_commissioned_discrete_"
                "staging_recovery_behavior_contract_v1.json"
            ),
            live_record_key="r24d151_contract_path",
            live_identity_prefix="r24d151_physical_closure",
            next_gate_id="QSDK-R24D152",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
