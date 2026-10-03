#!/usr/bin/env python3
"""Thin R142 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d142_godot_jolt_v5_raw_binding_corrected_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d142_godot_jolt_v5_raw_binding_corrected_recovery_behavior_physical_closure_v1",
            "QSDK-R24D142",
            "sha256:7f4efcfaebcf798c6c1b3d594c0843c00d2b1facbc2063be12f2c2991340f447",
            31881,
            "QSDK_R24D142_V5_RAW_BINDING_CORRECTED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D142_V5_RAW_BINDING_CORRECTED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d142_godot_jolt_v5_raw_binding_corrected_recovery_behavior_contract_v1.json",
            actuation_projection_mode="joint_space_effective_inertia_population_v1",
            live_record_key="r24d142_contract_path",
            live_identity_prefix="r24d142_physical_closure",
            ignored_forward_live_keys=(
                "r24d143_zero_world_raise_body_trajectory_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D143",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
