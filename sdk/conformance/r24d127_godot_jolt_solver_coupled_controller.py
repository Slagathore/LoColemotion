#!/usr/bin/env python3
"""Thin R127 binding for the reusable versioned-controller gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.versioned_recovery_controller_target_gate import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d127_godot_jolt_solver_coupled_controller_contract_v1.json",
            "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_contract_v1",
            "QSDK-R24D127",
            "QSDK_R24D127_GODOT_JOLT_SOLVER_COUPLED_CONTROLLER_SOURCE_PASS",
            "QSDK_R24D127_GODOT_JOLT_SOLVER_COUPLED_CONTROLLER_SOURCE_FAIL",
            authority_field_prefix="r24d127",
            expected_historical_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v5"
            ),
            expected_successor_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v6"
            ),
            expected_historical_profile_sha256=(
                "sha256:fe6beb259550c06e137fc89a5e752d2cfc088edd5f8136cd944c5776a4c34909"
            ),
            expected_successor_profile_sha256=(
                "sha256:a764ea9f96bc9dbb00d594d87603aa87a95bf7a43c03085520952138f3989d33"
            ),
            expected_historical_command_sha256=(
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
            ),
            expected_successor_command_sha256=(
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
            ),
            expected_historical_targets=(
                0.60,
                -1.05,
                0.60,
                -1.05,
                -0.60,
                1.05,
                -0.60,
                1.05,
            ),
            expected_successor_targets=(
                0.60,
                -1.05,
                0.60,
                -1.05,
                -0.60,
                1.05,
                -0.60,
                1.05,
            ),
            expected_changed_target_indices=(),
            expected_changed_joint_ids=(),
            expected_cross_version_refusal_count=2,
            expected_unregistered_controller_refusal_count=3,
            expected_change_kind="actuation_realization",
            expected_status=(
                "prospective_zero_world_versioned_solver_coupled_realization_"
                "implementation_qualification_pending"
            ),
            expected_authority_mode=(
                "prospective_zero_world_versioned_solver_coupled_realization_"
                "implementation"
            ),
            expected_historical_maximum_target_speed_rad_s=22.0,
            expected_successor_maximum_target_speed_rad_s=22.0,
            expected_preflight_schema=(
                "sporespore_versioned_recovery_controller_realization_preflight_v1"
            ),
            expected_historical_regression_field="historical_v1_v5_regression_count",
            expected_historical_preservation_field="historical_v1_v5_preserved",
            expected_raise_body_phase_steps=(0, 180, 360),
            expected_historical_raise_command_sha256=(
                "sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
                "sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
                "sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
            ),
            expected_successor_raise_command_sha256=(
                "sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
                "sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
                "sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
            ),
            expected_command_mutation_refusal_count=2,
            expected_historical_actuator_mode=(
                "force_based_order_neutral_joint_space_effective_inertia_"
                "native_angular_velocity_guarded_v3"
            ),
            expected_successor_actuator_mode=(
                "solver_coupled_native_constraint_motor_v1"
            ),
            expected_historical_actuation_realization_id=(
                "godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_"
                "population_guarded_joint_impulse_v1"
            ),
            expected_successor_actuation_realization_id=(
                "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1"
            ),
            expected_energy_source_profile_id=(
                "godot_jolt_r24d57_native_recovery_energy_mapping_v1"
            ),
            expected_realization_mismatch_refusal_count=2,
        )
    )
