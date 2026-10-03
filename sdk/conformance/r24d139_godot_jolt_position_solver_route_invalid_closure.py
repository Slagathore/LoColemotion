#!/usr/bin/env python3
"""Thin R139 binding for the reusable consumed-invalid route audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_route_physical_closure import (  # noqa: E402
    run_invalid_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_invalid_cli(
            root=ROOT,
            closure_relative_path="sdk/recovery/r24d139_godot_jolt_position_solver_route_ghost_closure_v1.json",
            closure_schema="sporespore_qsdk_r24d139_godot_jolt_position_solver_route_ghost_closure_v1",
            gate_id="QSDK-R24D139",
            closure_status="closed_consumed_invalid_incomplete_pre_world_complete_energy_runtime_profile_refused_no_native_world_r140_required",
            invocation_source_commit="b1adbf96728a3ed1920b33e420216e8c0e38e518",
            schemas={
                "attempt": "sporespore_qsdk_r24d139_position_solver_route_attempt_v1",
                "raw": "sporespore_qsdk_r24d139_godot_jolt_position_solver_route_raw_v1",
                "terminal": "sporespore_qsdk_r24d139_position_solver_route_terminal_v1",
            },
            actuator_mode="force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3",
            recovery_controller_id="sporespore_exact_s169_prone_to_standing_controller_v6",
            recovery_energy_route_id="sporespore_qsdk_r24d136_godot_jolt_complete_energy_recovery_observation_v3_route_v1",
            failure_code="QSDK_R24D139_GHOST_CONTEXT_FAILED",
            detail_failure_code="QSDK_R24D136_EXACT_INSTRUMENTED_PROFILE_REQUIRED",
            qualified_source_commit="fe33086c1d4e370e22e35f5a889f7160638c58cb",
            qualification_closure_relative_path="sdk/recovery/r24d139_godot_jolt_position_solver_route_zero_world_qualification_closure_v1.json",
            contract_relative_path="sdk/recovery/r24d139_godot_jolt_position_solver_route_contract_v1.json",
            qualified_physical_path_count=48,
            live_prefix="r24d139",
            next_gate_id="QSDK-R24D140",
            next_live_prefix="r24d140",
            disposition="invalid_or_incomplete_pre_world_complete_energy_runtime_profile_refusal",
            pass_marker="QSDK_R24D139_POSITION_SOLVER_ROUTE_INVALID_CLOSURE_PASS",
            failure_marker="QSDK_R24D139_POSITION_SOLVER_ROUTE_INVALID_CLOSURE_FAIL",
        )
    )
