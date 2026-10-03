#!/usr/bin/env python3
"""Thin R141 binding for the reusable infrastructure-invalid closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_infrastructure_invalid_physical_closure import (  # noqa: E402
    run_cli,
)


ROUTE_ID = (
    "sporespore_qsdk_r24d136_godot_jolt_complete_energy_"
    "recovery_observation_v3_route_v1"
)

STRUCTURED_INVALID_PROFILE = {
    "physical_exact_paths": {
        "worker_timeout_seconds": 24000,
        "worker_semantic_exit_code": 0,
        "worker_host_exit_code": -1,
        "worker_timed_out": False,
        "termination_protocol_valid": True,
        "raw_marker_count": 1,
        "raw_binding_valid": False,
        "progress_marker_count": 38,
        "progress_binding_valid": True,
        "native_engine_health_screen_passed": True,
        "complete_raw_result_observed": True,
        "actual_model_construction_count_observable": True,
        "actual_model_construction_count": 2,
        "actual_world_attempt_count_observable": True,
        "actual_world_attempt_count": 2,
        "actual_world_build_count_observable": True,
        "actual_world_build_count": 2,
        "actual_solver_step_count_observable": True,
        "actual_solver_step_count": 907,
        "actual_behavior_evaluator_invocation_count_observable": True,
        "actual_behavior_evaluator_invocation_count": 1,
        "physics_state_modified_observable": True,
        "physics_state_modified": True,
        "raw_valid_complete_status_observed": True,
        "raw_scientific_outcome": "negative",
    },
    "raw_exact_paths": {
        "ok": True,
        "status": "valid_complete_behavior_development",
        "scientific_outcome": "negative",
        "schema_version": (
            "sporespore_qsdk_r24d141_godot_v5_complete_energy_"
            "recovery_behavior_raw_v1"
        ),
        "gate_id": "QSDK-R24D141",
        "question_class": "development",
        "source_commit": "8f11b826e49454033c35ec9848c684a7f812104b",
        "attempt_id": "97daf9da77574f568fb091a1bc94a7cb",
        "authorization_sha256": (
            "sha256:c0de05a6c3ee29b38b994a961c1e0486377d3e8ec9b3431ff632f522f61114f8"
        ),
        "seed": 278151771,
        "seed_sha256": (
            "sha256:56acbb13436024d64c4373a9dac5299155c853d599aab1a7269b2bba6b8fbfda"
        ),
        "actuator_mode": (
            "force_based_order_neutral_joint_space_effective_inertia_"
            "native_angular_velocity_guarded_v3"
        ),
        "actuation_realization_id": (
            "godot_jolt_r24d137_complete_energy_r109_force_based_realization_v1"
        ),
        "actuator_mapping_id": (
            "godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_"
            "population_guarded_joint_impulse_v1"
        ),
        "work_mapping_id": (
            "godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_"
            "population_guarded_centered_joint_work_v1"
        ),
        "recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v6"
        ),
        "energy_route_id": ROUTE_ID,
        "physics_ticks_per_second": 120,
        "outer_step_duration_s": 1.0 / 120.0,
        "production_advance_dispatch_id": (
            "godot_jolt_r24d137_complete_energy_recovery_progression_dispatch_v1"
        ),
        "production_evaluation_dispatch_id": (
            "godot_jolt_r24d137_complete_energy_recovery_evaluation_dispatch_v1"
        ),
        "selected_portable_advance_route": "r136_complete_energy_progression_v5",
        "selected_portable_evaluation_route": (
            "r136_complete_energy_authority_evaluation_v5"
        ),
        "model_construction_attempt_count": 2,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": 907,
        "behavior_evaluator_invocation_count": 1,
        "complete_trace_count": 2,
        "in_run_invariant_receipt_count": 907,
        "physical_question_opened": True,
        "physics_state_modified": True,
        "physics_failure_is_valid_evidence": True,
        "held_out": False,
        "population_inference_claimed": False,
        "all_in_run_physical_invariants_passed": True,
        "stance_observation_binding_receipt_count": 0,
        "recovery_success_observed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "arm_execution_summary.completed_arm_count": 2,
        "arm_execution_summary.status": "population_consistent",
        "arm_execution_summary.summarized_solver_step_count": 907,
        "arm_execution_summary.total_solver_step_count": 907,
        "arm_execution_summary.ordered_arm_summaries_sha256": (
            "sha256:d391316129fe55be9bec267553645add80be039d8e577f9da5164dddef454d88"
        ),
    },
    "raw_absent_keys": ("recovery_energy_route_id",),
    "raw_ordered_arm_exact_paths": [
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 639,
            "native_solver_step_count": 639,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:raise_body",
            "in_run_invariant_receipt_count": 639,
            "all_in_run_physical_invariants_passed": True,
            "arm_identity_valid": True,
            "arm_result_validation_passed": True,
            "digest_shapes_valid": True,
            "in_run_invariant_population_sha256": (
                "sha256:baa855bea093c3464f3d4841d31e389fc563c508bbbe560bcca157a4549eab7d"
            ),
            "trace_v3_sha256": (
                "sha256:b1985457c01778d2b00102992cdf98833cddcd9466e424e47e4af0acbc7a15b1"
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
                "sha256:9cc5537efd81deeea7d084da04ec6e03f6db5d1f16a5cb5b3851e9ee6dd8149a"
            ),
            "trace_v3_sha256": (
                "sha256:9cecd64c3bcd04b6405a9fff41da0de6ca3438012fafe5d0928a1df4525c2ce9"
            ),
        },
    ],
    "terminal_exact_paths": {
        "worker.semantic_exit_code": 0,
        "worker.host_exit_code": -1,
        "worker.timed_out": False,
        "worker.timeout_kind": "",
        "worker.termination_protocol_valid": True,
        "worker.termination_protocol_failure_code": "",
        "worker.raw_marker_count": 1,
        "worker.raw_binding_valid": False,
        "worker.progress_marker_count": 38,
        "worker.progress_binding_valid": True,
        "worker.progress_cadence_steps": 30,
        "worker.progress_stall_timeout_seconds": 600,
        "worker.total_timeout_seconds": 24000,
        "worker.last_progress_receipt.arm_kind": "",
        "worker.last_progress_receipt.arm_step_count": 0,
        "worker.last_progress_receipt.completed_solver_step_count": 907,
        "worker.last_progress_receipt.milestone": "raw_serialization_started",
        "worker.engine_health.selector_id": (
            "godot_typed_fatal_diagnostic_selector_v1"
        ),
        "worker.engine_health.passed": True,
        "worker.engine_health.stderr_raw_byte_length": 0,
        "worker.engine_health.stderr_raw_sha256": (
            "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        ),
        "worker.engine_health.stderr_nonempty_line_count": 0,
        "worker.engine_health.engine_error_line_count": 0,
        "worker.engine_health.native_assertion_failure_line_count": 0,
        "worker.engine_health.native_assertion_site_line_count": 0,
        "worker.engine_health.fatal_diagnostic_line_count": 0,
        "worker.engine_health.fatal_diagnostic_unique_line_count": 0,
    },
    "closure_exact_paths": {
        "observed_failure.classification": (
            "complete_raw_behavior_negative_rejected_by_supervisor_energy_"
            "route_field_binding_mismatch"
        ),
        "observed_failure.supervisor_raw_binding_valid": False,
        "observed_failure.expected_raw_binding_field": "recovery_energy_route_id",
        "observed_failure.expected_raw_binding_value": ROUTE_ID,
        "observed_failure.expected_raw_binding_field_present": False,
        "observed_failure.emitted_raw_binding_field": "energy_route_id",
        "observed_failure.emitted_raw_binding_value": ROUTE_ID,
        "observed_failure.emitted_raw_binding_field_present": True,
        "observed_failure.all_other_supervisor_raw_binding_predicates_passed": True,
        "observed_failure.all_result_specific_validity_predicates_passed": True,
        "observed_failure.native_engine_health_passed": True,
        "observed_failure.complete_raw_result_observed": True,
        "observed_failure.raw_status": "valid_complete_behavior_development",
        "observed_failure.raw_scientific_outcome": "negative",
        "observed_failure.raw_all_in_run_physical_invariants_passed": True,
        "observed_failure.raw_in_run_invariant_receipt_count": 907,
        "interpretation.harness_or_integration_failure_established": True,
        "interpretation.supervisor_contract_binding_failure_established": True,
        "interpretation.native_runtime_access_integration_failure_established": False,
        "interpretation.exact_offending_field_pair_established": True,
        "interpretation.complete_raw_physical_arms_observed": True,
        "interpretation.all_907_raw_in_run_physical_invariants_passed": True,
        "interpretation.subordinate_raw_behavior_negative_observed": True,
        "interpretation.subordinate_raw_behavior_negative_accepted_for_inference": False,
        "interpretation.native_physics_failure_established": False,
        "interpretation.complete_behavior_result_established": False,
        "decision.infrastructure_invalid_result_retained": True,
        "decision.r142_distinct_successor_required": True,
        "decision.supervisor_energy_route_field_binding_correction_required": True,
        "claim_boundary.partial_physical_trajectory_observed": True,
        "claim_boundary.physical_arm_terminal_summaries_observed": True,
        "claim_boundary.in_run_physical_invariants_observable": True,
        "claim_boundary.all_observed_in_run_physical_invariants_passed": True,
        "claim_boundary.complete_raw_behavior_result_observed": True,
        "claim_boundary.subordinate_raw_behavior_negative_observed": True,
        "claim_boundary.behavior_negative_accepted_for_finite_development_inference": False,
    },
}


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d141_godot_jolt_v5_complete_energy_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d141_godot_jolt_v5_complete_energy_recovery_behavior_physical_closure_v1",
            "QSDK-R24D141",
            "sha256:6d191892f1c040c106137e2ce613452c28ff3ee739213df4d15f49ed743e1f18",
            18055,
            "QSDK_R24D141_V5_COMPLETE_ENERGY_RECOVERY_BEHAVIOR_INVALID_CLOSURE_PASS",
            "QSDK_R24D141_V5_COMPLETE_ENERGY_RECOVERY_BEHAVIOR_INVALID_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d141_godot_jolt_v5_complete_energy_"
                "recovery_behavior_contract_v1.json"
            ),
            live_record_key="r24d141_contract_path",
            live_identity_prefix="r24d141_physical_closure",
            next_gate_id="QSDK-R24D142",
            timeout_seconds=24000,
            structured_invalid_profile=STRUCTURED_INVALID_PROFILE,
        )
    )
