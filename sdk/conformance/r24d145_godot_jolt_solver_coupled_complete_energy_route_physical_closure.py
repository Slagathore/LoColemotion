#!/usr/bin/env python3
"""Thin R145 binding for the reusable two-step route-closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_route_physical_closure import (  # noqa: E402
    SOLVER_COUPLED_COMPLETE_ENERGY_PROFILE,
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            root=ROOT,
            closure_relative_path="sdk/recovery/r24d145_godot_jolt_solver_coupled_complete_energy_route_ghost_closure_v1.json",
            closure_schema="sporespore_qsdk_r24d145_godot_jolt_solver_coupled_complete_energy_route_ghost_closure_v1",
            gate_id="QSDK-R24D145",
            closure_status="closed_consumed_valid_complete_solver_coupled_complete_energy_route_ghost_passed_distinct_recovery_behavior_successor_required",
            invocation_source_commit="1a36c44e9ae34454cbdc9e360aaf48d1fc648308",
            schemas={
                "attempt": "sporespore_qsdk_r24d145_solver_coupled_complete_energy_route_attempt_v1",
                "raw": "sporespore_qsdk_r24d145_godot_jolt_solver_coupled_complete_energy_route_raw_v1",
                "terminal": "sporespore_qsdk_r24d145_solver_coupled_complete_energy_route_terminal_v1",
            },
            actuator_mode="solver_coupled_native_constraint_motor_v1",
            actuator_mapping_id="godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1",
            work_mapping_id="godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1",
            projection_key="",
            projection_schema="",
            qualified_source_commit="ba7a4360bd51f38a6de2209d4ef002a3cae3c5d7",
            qualification_closure_relative_path="sdk/recovery/r24d145_godot_jolt_solver_coupled_complete_energy_route_zero_world_qualification_closure_v1.json",
            qualified_physical_path_count=51,
            live_prefix="r24d145",
            next_gate_id="QSDK-R24D146",
            next_live_prefix="r24d146",
            route_realization_profile=SOLVER_COUPLED_COMPLETE_ENERGY_PROFILE,
            profile_bindings={
                "recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
                "energy_route_id": "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1",
                "application_schema": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1",
                "actuation_realization_id": "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1",
                "application_mutation_semantics_id": "godot_jolt_r24d129_solver_coupled_constraint_configuration_mutation_v1",
                "energy_mapping_profile_id": "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1",
                "partition_rule_id": "godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1",
            },
            pass_marker="QSDK_R24D145_SOLVER_COUPLED_COMPLETE_ENERGY_ROUTE_PHYSICAL_CLOSURE_PASS",
            failure_marker="QSDK_R24D145_SOLVER_COUPLED_COMPLETE_ENERGY_ROUTE_PHYSICAL_CLOSURE_FAIL",
        )
    )
