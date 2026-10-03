#!/usr/bin/env python3
"""Thin R107 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d107_godot_jolt_joint_target_monotone_population_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d107_godot_jolt_joint_target_monotone_population_recovery_behavior_physical_closure_v1",
            "QSDK-R24D107",
            "sha256:1b94ab31c614dfc03696baa390ba8470dabb386d04330aa92b2988cdf9a5710d",
            27477,
            "QSDK_R24D107_JOINT_TARGET_MONOTONE_POPULATION_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D107_JOINT_TARGET_MONOTONE_POPULATION_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d107_godot_jolt_joint_target_monotone_population_recovery_behavior_contract_v1.json",
            actuation_projection_mode="joint_target_monotone_population_v1",
            live_record_key="r24d107_contract_path",
            live_identity_prefix="r24d107_physical_closure",
            ignored_forward_live_keys=(
                "r24d108_zero_world_trajectory_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D108",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
