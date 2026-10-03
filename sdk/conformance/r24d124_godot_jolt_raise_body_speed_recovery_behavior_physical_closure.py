#!/usr/bin/env python3
"""Thin R124 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d124_godot_jolt_raise_body_speed_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d124_godot_jolt_raise_body_speed_recovery_behavior_physical_closure_v1",
            "QSDK-R24D124",
            "sha256:774fb60b23f39de6686a88a4ba3c6f7d2709488a490e57144683ce38a2d0321d",
            30283,
            "QSDK_R24D124_RAISE_BODY_SPEED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D124_RAISE_BODY_SPEED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d124_godot_jolt_raise_body_speed_recovery_behavior_contract_v1.json",
            actuation_projection_mode="joint_space_effective_inertia_population_v1",
            live_record_key="r24d124_contract_path",
            live_identity_prefix="r24d124_physical_closure",
            ignored_forward_live_keys=(
                "r24d125_zero_world_v4_v5_raise_body_response_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D125",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
