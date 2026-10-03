#!/usr/bin/env python3
"""Thin R132 binding for the reusable infrastructure-invalid closure audit."""

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
        "progress_marker_count": 4,
        "progress_binding_valid": False,
        "complete_raw_result_observed": True,
        "actual_model_construction_count_observable": True,
        "actual_model_construction_count": 1,
        "actual_world_attempt_count_observable": True,
        "actual_world_attempt_count": 1,
        "actual_world_build_count_observable": True,
        "actual_world_build_count": 1,
        "actual_solver_step_count_observable": True,
        "actual_solver_step_count": 59,
        "actual_behavior_evaluator_invocation_count_observable": True,
        "actual_behavior_evaluator_invocation_count": 0,
        "physics_state_modified_observable": True,
        "physics_state_modified": True,
    },
    "raw_exact_paths": {
        "ok": False,
        "status": "invalid_or_incomplete_behavior_development",
        "failure_code": "QSDK_R24D132_BEHAVIOR_PORTABLE_ADVANCE_FAILED",
        "source_commit": "eb1b1f7ef4e0687d7563ea83974ab9bd2f789a42",
        "actuator_mode": "solver_coupled_native_constraint_motor_v1",
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "model_construction_attempt_count": 1,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 59,
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
        "arm_execution_summary.status": "population_inconsistent",
        "arm_execution_summary.summarized_solver_step_count": 59,
        "arm_execution_summary.total_solver_step_count": 59,
        "detail.failure_code": "QSDK_R24D65_BEHAVIOR_CONTROL_REFUSED",
        "detail.detail.ok": False,
        "detail.detail.failure_code": "DIGEST_INVALID",
        "detail.detail.detail": "STANCE_STEP_OBSERVATION_BINDING",
        "detail.detail.model_construction_count": 0,
        "detail.detail.world_attempt_count": 0,
        "detail.detail.world_build_count": 0,
        "detail.detail.solver_step_count": 0,
        "detail.detail.physics_state_modified": False,
    },
    "raw_first_arm_exact_paths": {
        "arm_kind": "candidate_command",
        "outer_step_count": 58,
        "native_solver_step_count": 59,
        "final_phase": "raise_body",
        "in_run_invariant_receipt_count": 58,
        "all_in_run_physical_invariants_passed": True,
        "in_run_invariant_population_sha256": (
            "sha256:821189ee12fe9e0d85da2e218102a9cc794eac55bcf21344a48f372ba23da0f1"
        ),
        "trace_v3_sha256": (
            "sha256:8fdc7365ecb82e2eeb910034bb54998a87f1a416855f02d1c2442d453db0ae07"
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
        "worker.progress_marker_count": 4,
        "worker.progress_binding_valid": False,
        "worker.progress_cadence_steps": 30,
        "worker.progress_stall_timeout_seconds": 600,
        "worker.total_timeout_seconds": 24000,
        "worker.last_progress_receipt.arm_kind": "candidate_command",
        "worker.last_progress_receipt.arm_step_count": 58,
        "worker.last_progress_receipt.completed_solver_step_count": 59,
        "worker.last_progress_receipt.milestone": "failure_serialization_started",
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "v5_step_observation_v3_to_stance_collection_observation_v2_"
            "digest_mismatch_at_first_development_handoff"
        ),
        "observed_failure.core_failure_code": "DIGEST_INVALID",
        "observed_failure.core_failure_detail": "STANCE_STEP_OBSERVATION_BINDING",
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.v5_step_to_stance_observation_representation_mismatch_established": True,
        "interpretation.native_physics_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r133_distinct_successor_required": True,
        "claim_boundary.partial_physical_trajectory_observed": True,
        "claim_boundary.in_run_physical_invariants_observable": True,
        "claim_boundary.all_observed_in_run_physical_invariants_passed": True,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d132_godot_jolt_corrected_progression_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d132_godot_jolt_corrected_progression_recovery_behavior_physical_closure_v1",
            "QSDK-R24D132",
            "sha256:a3861d602430611e684730cd5b1ac2d0412df17e5279ec0d620fb129d492f8d3",
            15435,
            "QSDK_R24D132_CORRECTED_PROGRESSION_RECOVERY_BEHAVIOR_INVALID_CLOSURE_PASS",
            "QSDK_R24D132_CORRECTED_PROGRESSION_RECOVERY_BEHAVIOR_INVALID_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d132_godot_jolt_corrected_progression_"
                "recovery_behavior_contract_v1.json"
            ),
            live_record_key="r24d132_contract_path",
            live_identity_prefix="r24d132_physical_closure",
            next_gate_id="QSDK-R24D133",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
