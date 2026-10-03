#!/usr/bin/env python3
"""Thin R150 binding for the reusable two-step route-closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_route_physical_closure import (  # noqa: E402
    DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            root=ROOT,
            closure_relative_path="sdk/recovery/r24d150_godot_jolt_discrete_staging_live_route_ghost_closure_v1.json",
            closure_schema="sporespore_qsdk_r24d150_godot_jolt_discrete_staging_live_route_ghost_closure_v1",
            gate_id="QSDK-R24D150",
            closure_status="closed_consumed_valid_complete_discrete_staging_core_bound_route_ghost_passed_distinct_recovery_behavior_successor_required",
            invocation_source_commit="00a2e416d9b8b8a0fe46acabd9a82c422e439153",
            schemas={
                "attempt": "sporespore_qsdk_r24d150_discrete_staging_live_route_attempt_v1",
                "raw": "sporespore_qsdk_r24d150_godot_jolt_discrete_staging_live_route_raw_v1",
                "terminal": "sporespore_qsdk_r24d150_discrete_staging_live_route_terminal_v1",
            },
            actuator_mode="solver_coupled_native_constraint_motor_v1",
            actuator_mapping_id="godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1",
            work_mapping_id="godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1",
            projection_key="",
            projection_schema="",
            qualified_source_commit="cf378e3a2fbcafc94ad8b0ac54f7020523f4371f",
            qualification_closure_relative_path="sdk/recovery/r24d150_godot_jolt_discrete_staging_core_binding_zero_world_qualification_closure_v1.json",
            qualified_physical_path_count=58,
            live_prefix="r24d150",
            next_gate_id="QSDK-R24D151",
            next_live_prefix="r24d151",
            route_realization_profile=DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
            profile_bindings={
                "recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
                "energy_route_id": "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1",
                "energy_mapping_profile_id": "godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1",
                "predecessor_energy_route_id": "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1",
                "predecessor_energy_mapping_profile_id": "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1",
                "application_schema": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1",
                "actuation_realization_id": "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1",
                "application_mutation_semantics_id": "godot_jolt_r24d129_solver_coupled_constraint_configuration_mutation_v1",
                "partition_rule_id": "godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1",
                "source_receipt_schema": "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_receipt_v1",
                "source_component_receipts_schema": "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_component_receipts_v1",
                "boundary_capture_schema": "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_body_boundary_capture_v1",
                "observer_schema": "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_exchange_v1",
                "accumulator_schema": "sporespore_qsdk_r24d148_godot_discrete_staging_accumulator_v1",
                "mapping_receipt_schema": "sporespore_qsdk_r24d148_godot_discrete_staging_energy_mapping_receipt_v1",
                "discrete_staging_rule_id": "godot_jolt_gravity_force_and_position_staging_exchange_v1",
                "live_boundary_transport_id": "godot_jolt_r24d149_pre_callback_to_post_solver_body_boundary_transport_v1",
                "native_world_route_id": "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_native_world_v1",
            },
            pass_marker="QSDK_R24D150_DISCRETE_STAGING_LIVE_ROUTE_PHYSICAL_CLOSURE_PASS",
            failure_marker="QSDK_R24D150_DISCRETE_STAGING_LIVE_ROUTE_PHYSICAL_CLOSURE_FAIL",
        )
    )
