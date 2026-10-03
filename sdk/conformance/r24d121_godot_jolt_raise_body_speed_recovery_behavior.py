#!/usr/bin/env python3
"""Thin R121 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d121_godot_jolt_raise_body_speed_recovery_behavior_"
    "contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d121_godot_jolt_raise_body_speed_recovery_behavior_"
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
                "r24d121_godot_jolt_raise_body_speed_recovery_behavior_"
                "physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d121_godot_jolt_raise_body_speed_"
                "recovery_behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:d340380558d9cd0a0954d7d1cfdfd052bea1800bfb0b4168078c44465d8531ca"
            ),
            terminal_closure_byte_length=29953,
            terminal_live_keys=(
                "r24d121_source_status",
                "r24d121_physical_execution_authorized",
            ),
        )
    )
