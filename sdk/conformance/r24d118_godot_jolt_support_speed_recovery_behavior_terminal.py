#!/usr/bin/env python3
"""Terminal-state R118 binding for the reusable finite behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d118_godot_jolt_support_speed_recovery_behavior_contract_v1.json",
            "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_behavior_contract_v1",
            terminal_closure_relative_path=(
                "sdk/recovery/r24d118_godot_jolt_support_speed_recovery_"
                "behavior_physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d118_godot_jolt_support_speed_recovery_"
                "behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:b7e9aa21b3f87f34860b9c6381be2f861893a831c7044d5ec2ca0de17f23c23a"
            ),
            terminal_closure_byte_length=29535,
            terminal_live_keys=(
                "r24d118_source_status",
                "r24d118_physical_execution_authorized",
            ),
        )
    )
