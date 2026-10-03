#!/usr/bin/env python3
"""Thin R121 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d121_godot_jolt_raise_body_speed_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d121_godot_jolt_raise_body_speed_recovery_behavior_physical_closure_v1",
            "QSDK-R24D121",
            "sha256:d340380558d9cd0a0954d7d1cfdfd052bea1800bfb0b4168078c44465d8531ca",
            29953,
            "QSDK_R24D121_RAISE_BODY_SPEED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D121_RAISE_BODY_SPEED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d121_godot_jolt_raise_body_speed_recovery_behavior_contract_v1.json",
            actuation_projection_mode="joint_space_effective_inertia_population_v1",
            live_record_key="r24d121_contract_path",
            live_identity_prefix="r24d121_physical_closure",
            ignored_forward_live_keys=(
                "r24d122_zero_world_raise_body_actuation_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D122",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
