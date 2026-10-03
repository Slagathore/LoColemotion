#!/usr/bin/env python3
"""Thin R124 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d124_godot_jolt_raise_body_speed_recovery_behavior_"
    "contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d124_godot_jolt_raise_body_speed_recovery_behavior_"
    "contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            CONTRACT,
            CONTRACT_SCHEMA,
            terminal_closure_relative_path=(
                "sdk/recovery/"
                "r24d124_godot_jolt_raise_body_speed_recovery_behavior_"
                "physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d124_godot_jolt_raise_body_speed_"
                "recovery_behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:774fb60b23f39de6686a88a4ba3c6f7d2709488a490e57144683ce38a2d0321d"
            ),
            terminal_closure_byte_length=30283,
            terminal_live_keys=(
                "r24d124_source_status",
                "r24d124_physical_execution_authorized",
            ),
        )
    )
