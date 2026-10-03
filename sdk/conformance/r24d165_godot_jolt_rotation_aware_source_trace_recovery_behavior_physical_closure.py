#!/usr/bin/env python3
"""Thin R165 binding for the reusable finite behavior physical closure."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_physical_closure import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d165_godot_jolt_rotation_aware_source_trace_recovery_behavior_physical_closure_v1",
            "QSDK-R24D165",
            "sha256:ee9637e48f416ad178a30404e019892b9bb0e5291bc1b58741b1a35052fba6a4",
            26260,
            "QSDK_R24D165_ROTATION_AWARE_SOURCE_TRACE_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D165_ROTATION_AWARE_SOURCE_TRACE_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d165_godot_jolt_rotation_aware_source_trace_"
                "recovery_behavior_contract_v1.json"
            ),
            actuation_projection_mode="solver_coupled_constraint_motor_v1",
            live_record_key="r24d165_contract_path",
            live_identity_prefix="r24d165_physical_closure",
            ignored_forward_live_keys=(
                "r24d166_distinct_successor_required",
                "r24d166_question_class_declared",
                "r24d166_physical_execution_authorized",
                "physical_execution_blocked_pending_r24d166_declaration",
                "physical_execution_blocked_until_r24d166_zero_world_qualification",
                "next_gate_id",
            ),
            next_gate_id="QSDK-R24D166",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
