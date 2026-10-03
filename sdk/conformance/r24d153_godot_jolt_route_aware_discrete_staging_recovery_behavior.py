#!/usr/bin/env python3
"""Thin R153 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d153_godot_jolt_route_aware_discrete_staging_"
    "recovery_behavior_contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d153_godot_jolt_route_aware_discrete_staging_"
    "recovery_behavior_contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            CONTRACT,
            CONTRACT_SCHEMA,
            terminal_closure_relative_path=(
                "sdk/recovery/r24d153_godot_jolt_route_aware_discrete_staging_"
                "recovery_behavior_physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d153_godot_jolt_route_aware_discrete_"
                "staging_recovery_behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:4342d429574a525840996d6b24fab44df8aab7f772bbd6b697ea7450c89a27a4"
            ),
            terminal_closure_byte_length=16065,
            terminal_live_keys=(
                "r24d153_source_status",
                "r24d153_physical_execution_authorized",
                "r24d153_prone_to_standing_claimed",
                "r24d153_sdk1_milestone_advanced",
            ),
        )
    )
