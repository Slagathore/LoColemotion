#!/usr/bin/env python3
"""Thin R149 binding for the reusable consumed-invalid route audit."""

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
            closure_relative_path="sdk/recovery/r24d149_godot_jolt_discrete_staging_live_route_ghost_invalid_closure_v1.json",
            closure_schema="sporespore_qsdk_r24d149_godot_jolt_discrete_staging_live_route_ghost_invalid_closure_v1",
            gate_id="QSDK-R24D149",
            closure_status="closed_consumed_invalid_incomplete_post_step_portable_core_collector_identity_refused_r150_required",
            invocation_source_commit="5507d7ee18774e2e03bf3a534abe1b9281830593",
            schemas={
                "attempt": "sporespore_qsdk_r24d149_discrete_staging_live_route_attempt_v1",
                "raw": "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_live_route_raw_v1",
                "terminal": "sporespore_qsdk_r24d149_discrete_staging_live_route_terminal_v1",
            },
            actuator_mode="solver_coupled_native_constraint_motor_v1",
            recovery_controller_id="sporespore_exact_s169_prone_to_standing_controller_v6",
            recovery_energy_route_id="sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1",
            failure_code="QSDK_R24D149_GHOST_FIRST_PORTABLE_ROUTE_FAILED",
            detail_failure_code="QSDK_R24D57_NATIVE_COLLECTION_REFUSED",
            root_cause_refusal_reason="collector_or_runtime_profile_identity_invalid",
            qualified_source_commit="4d6f1e0f3581227012f756cb491b2309c2c11efa",
            qualification_closure_relative_path="sdk/recovery/r24d149_godot_jolt_discrete_staging_live_route_zero_world_qualification_closure_v1.json",
            contract_relative_path="sdk/recovery/r24d149_godot_jolt_discrete_staging_live_route_contract_v1.json",
            qualified_physical_path_count=56,
            live_prefix="r24d149",
            next_gate_id="QSDK-R24D150",
            next_live_prefix="r24d150",
            disposition="invalid_or_incomplete_after_first_solver_step_portable_core_collector_identity_refused",
            observed_model_construction_attempt_count=1,
            observed_model_construction_count=1,
            observed_world_attempt_count=1,
            observed_world_build_count=1,
            observed_solver_step_count=1,
            observed_physical_question_opened=True,
            observed_physics_state_modified=True,
            pass_marker="QSDK_R24D149_DISCRETE_STAGING_LIVE_ROUTE_INVALID_CLOSURE_PASS",
            failure_marker="QSDK_R24D149_DISCRETE_STAGING_LIVE_ROUTE_INVALID_CLOSURE_FAIL",
        )
    )
