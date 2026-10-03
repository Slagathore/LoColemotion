#!/usr/bin/env python3
"""Audit the one consumed R169 contiguous-boundary production-route ghost."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_route_physical_closure import (  # noqa: E402
    CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
    run_cli,
)


CLOSURE_STATUS = (
    "closed_consumed_valid_complete_contiguous_boundary_production_route_ghost_"
    "passed_distinct_behavior_successor_required"
)
CLOSURE_PATH = (
    "sdk/recovery/"
    "r24d169_godot_contiguous_boundary_route_ghost_physical_closure_v1.json"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d169_godot_contiguous_boundary_route_ghost_"
    "physical_closure_v1"
)
PROFILE_BINDINGS = {
    "accumulator_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_accumulator_v1"
    ),
    "actuation_realization_id": (
        "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1"
    ),
    "application_mutation_semantics_id": (
        "godot_jolt_r24d129_solver_coupled_constraint_configuration_"
        "mutation_v1"
    ),
    "application_provenance_profile_id": (
        "godot_jolt_r24d152_route_aware_discrete_staging_application_"
        "provenance_v1"
    ),
    "application_schema": (
        "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_"
        "energy_command_application_receipt_v1"
    ),
    "boundary_capture_schema": (
        "sporespore_qsdk_r24d168_godot_jolt_contiguous_body_boundary_capture_v1"
    ),
    "boundary_transport_design_id": (
        "godot_jolt_r24d167_contiguous_completed_step_boundary_transport_v1"
    ),
    "boundary_transport_initializer_schema": (
        "sporespore_qsdk_r24d168_native_initializer_boundary_transport_v1"
    ),
    "boundary_transport_pair_schema": (
        "sporespore_qsdk_r24d167_contiguous_body_boundary_pair_v1"
    ),
    "boundary_transport_state_schema": (
        "sporespore_qsdk_r24d167_boundary_transport_state_v1"
    ),
    "complete_energy_authority_profile_id": (
        "godot_jolt_r24d151_commissioned_discrete_staging_complete_energy_"
        "partition_authority_v1"
    ),
    "discrete_staging_rule_id": (
        "godot_jolt_gravity_force_and_position_staging_exchange_v1"
    ),
    "energy_mapping_profile_id": (
        "godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_"
        "mapping_v1"
    ),
    "energy_route_id": (
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_"
        "recovery_observation_v3_route_v1"
    ),
    "intermediate_application_schema": (
        "sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_"
        "command_application_receipt_v1"
    ),
    "live_boundary_transport_id": (
        "godot_jolt_r24d168_live_contiguous_completed_step_boundary_transport_v1"
    ),
    "mapping_receipt_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_energy_mapping_"
        "receipt_v1"
    ),
    "native_application_schema": (
        "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_"
        "application_receipt_v1"
    ),
    "native_bound_measurement_schema": (
        "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_"
        "bound_measurement_v1"
    ),
    "native_measurement_schema": (
        "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_"
        "measurement_v1"
    ),
    "native_source_trace_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_native_"
        "source_trace_v1"
    ),
    "native_world_route_id": (
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_"
        "native_world_v1"
    ),
    "observer_schema": (
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_exchange_v1"
    ),
    "partition_contract_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_"
        "energy_partition_contract_v1"
    ),
    "partition_numerical_term_count": 14,
    "partition_rule_id": (
        "godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_"
        "partition_v1"
    ),
    "predecessor_application_schema": (
        "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_"
        "command_application_receipt_v1"
    ),
    "predecessor_energy_mapping_profile_id": (
        "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_"
        "mapping_v1"
    ),
    "predecessor_energy_route_id": (
        "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_"
        "recovery_observation_v3_route_v1"
    ),
    "predecessor_native_application_schema": (
        "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_"
        "application_receipt_v1"
    ),
    "recovery_controller_id": (
        "sporespore_exact_s169_prone_to_standing_controller_v6"
    ),
    "recovery_energy_ledger_profile_id": (
        "godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
    ),
    "rotation_aware_predecessor_source_component_receipts_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_source_"
        "component_receipts_v1"
    ),
    "rotation_aware_predecessor_source_receipt_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_"
        "energy_source_receipt_v1"
    ),
    "solver_energy_consumer_contract_schema": (
        "sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2"
    ),
    "solver_energy_telemetry_profile_id": (
        "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6"
    ),
    "solver_energy_telemetry_schema": (
        "sporespore.godot_jolt_solver_energy_exchange_telemetry.v2"
    ),
    "source_component_receipts_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_"
        "component_receipts_v1"
    ),
    "source_receipt_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_"
        "receipt_v1"
    ),
    "step_mapping_schema": (
        "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_step_"
        "mapping_v1"
    ),
}


def main() -> int:
    return run_cli(
        pass_marker=(
            "QSDK_R24D169_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_PHYSICAL_CLOSURE_PASS"
        ),
        failure_marker=(
            "QSDK_R24D169_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_PHYSICAL_CLOSURE_FAIL"
        ),
        root=ROOT,
        closure_relative_path=CLOSURE_PATH,
        closure_schema=CLOSURE_SCHEMA,
        gate_id="QSDK-R24D169",
        closure_status=CLOSURE_STATUS,
        invocation_source_commit="1cc09f9ff42d003276d82d2a3ed24f79c23ee4c3",
        schemas={
            "attempt": (
                "sporespore_qsdk_r24d169_contiguous_boundary_route_ghost_"
                "attempt_v1"
            ),
            "raw": (
                "sporespore_qsdk_r24d169_godot_contiguous_boundary_route_"
                "ghost_raw_v1"
            ),
            "terminal": (
                "sporespore_qsdk_r24d169_contiguous_boundary_route_ghost_"
                "terminal_v1"
            ),
        },
        actuator_mode="solver_coupled_native_constraint_motor_v1",
        actuator_mapping_id=(
            "godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1"
        ),
        work_mapping_id=(
            "godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1"
        ),
        projection_key="",
        projection_schema="",
        qualified_source_commit="d55c1163e86ff8e3d0cdefa8faff7f46b4bb2f0f",
        qualification_closure_relative_path=(
            "sdk/recovery/r24d169_godot_contiguous_boundary_route_ghost_"
            "zero_world_qualification_closure_v1.json"
        ),
        qualified_physical_path_count=74,
        live_prefix="r24d169",
        next_gate_id="QSDK-R24D170",
        next_live_prefix="r24d170",
        route_realization_profile=(
            CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE
        ),
        profile_bindings=PROFILE_BINDINGS,
    )


if __name__ == "__main__":
    raise SystemExit(main())
