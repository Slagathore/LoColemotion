#!/usr/bin/env python3
"""Thin R128 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d128_godot_jolt_solver_coupled_recovery_behavior_"
    "contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d128_godot_jolt_solver_coupled_recovery_behavior_"
    "contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            CONTRACT,
            CONTRACT_SCHEMA,
            terminal_closure_relative_path=(
                "sdk/recovery/r24d128_godot_jolt_solver_coupled_recovery_"
                "behavior_invalid_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d128_godot_jolt_solver_coupled_recovery_"
                "behavior_invalid_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:837c2b0f2b3d73f91bb3bdaa6dec094945dab633db232fed85aabad1c1b44690"
            ),
            terminal_closure_byte_length=15463,
            terminal_live_keys=(
                "r24d128_source_status",
                "r24d128_physical_execution_authorized",
            ),
        )
    )
