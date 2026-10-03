#!/usr/bin/env python3
"""Thin R140 binding for the reusable two-step route-closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_route_physical_closure import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            root=ROOT,
            closure_relative_path="sdk/recovery/r24d140_godot_jolt_v5_profile_position_solver_route_ghost_closure_v1.json",
            closure_schema="sporespore_qsdk_r24d140_godot_jolt_v5_profile_position_solver_route_ghost_closure_v1",
            gate_id="QSDK-R24D140",
            closure_status="closed_consumed_valid_complete_v5_context_position_solver_route_ghost_passed_distinct_finite_recovery_behavior_successor_required",
            invocation_source_commit="0ae6d526b25b1b2a2e64cb6d751b1d7b9eea3a56",
            schemas={
                "attempt": "sporespore_qsdk_r24d140_v5_profile_position_solver_route_attempt_v1",
                "raw": "sporespore_qsdk_r24d140_godot_jolt_v5_profile_position_solver_route_raw_v1",
                "terminal": "sporespore_qsdk_r24d140_v5_profile_position_solver_route_terminal_v1",
            },
            actuator_mode="force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3",
            actuator_mapping_id="godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_joint_impulse_v1",
            work_mapping_id="godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_centered_joint_work_v1",
            projection_key="joint_space_effective_inertia_population_guard_projection",
            projection_schema="sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guard_projection_v1",
            qualified_source_commit="ccac468e8d6a8f81035de646ba12855e306be6d2",
            qualification_closure_relative_path="sdk/recovery/r24d140_godot_jolt_v5_profile_position_solver_route_zero_world_qualification_closure_v1.json",
            qualified_physical_path_count=48,
            live_prefix="r24d140",
            next_gate_id="QSDK-R24D141",
            next_live_prefix="r24d141",
            pass_marker="QSDK_R24D140_V5_PROFILE_POSITION_SOLVER_ROUTE_PHYSICAL_CLOSURE_PASS",
            failure_marker="QSDK_R24D140_V5_PROFILE_POSITION_SOLVER_ROUTE_PHYSICAL_CLOSURE_FAIL",
        )
    )
