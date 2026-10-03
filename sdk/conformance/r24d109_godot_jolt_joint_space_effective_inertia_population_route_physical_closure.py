#!/usr/bin/env python3
"""Thin R109 binding for the reusable two-step route-closure audit."""

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
            closure_relative_path="sdk/recovery/r24d109_godot_jolt_joint_space_effective_inertia_population_route_ghost_closure_v1.json",
            closure_schema="sporespore_qsdk_r24d109_godot_jolt_joint_space_effective_inertia_population_route_ghost_closure_v1",
            gate_id="QSDK-R24D109",
            closure_status="closed_consumed_valid_complete_joint_space_effective_inertia_population_route_ghost_passed_distinct_finite_recovery_behavior_successor_required",
            invocation_source_commit="79f4e1d54c3ccf103d020cce6b4f267a24e90674",
            schemas={
                "attempt": "sporespore_qsdk_r24d109_joint_space_effective_inertia_population_route_attempt_v1",
                "raw": "sporespore_qsdk_r24d109_godot_jolt_joint_space_effective_inertia_population_route_raw_v1",
                "terminal": "sporespore_qsdk_r24d109_joint_space_effective_inertia_population_route_terminal_v1",
            },
            actuator_mode="force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3",
            actuator_mapping_id="godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_joint_impulse_v1",
            work_mapping_id="godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_centered_joint_work_v1",
            projection_key="joint_space_effective_inertia_population_guard_projection",
            projection_schema="sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guard_projection_v1",
            qualified_source_commit="5b4dba47889ecd1bb458be1e1811405f11e7a8c6",
            qualification_closure_relative_path="sdk/recovery/r24d109_godot_jolt_joint_space_effective_inertia_population_route_zero_world_qualification_closure_v1.json",
            qualified_physical_path_count=53,
            live_prefix="r24d109",
            next_gate_id="QSDK-R24D110",
            next_live_prefix="r24d110",
            pass_marker="QSDK_R24D109_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_ROUTE_PHYSICAL_CLOSURE_PASS",
            failure_marker="QSDK_R24D109_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_ROUTE_PHYSICAL_CLOSURE_FAIL",
        )
    )
