#!/usr/bin/env python3
"""Thin R111 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d111_godot_jolt_joint_space_effective_inertia_population_"
    "recovery_behavior_contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d111_godot_jolt_joint_space_effective_inertia_"
    "population_recovery_behavior_contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            CONTRACT,
            CONTRACT_SCHEMA,
            terminal_closure_relative_path=(
                "sdk/recovery/r24d111_godot_jolt_joint_space_effective_inertia_"
                "population_recovery_behavior_physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d111_godot_jolt_joint_space_effective_"
                "inertia_population_recovery_behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:bcd77bff3f7d7744ef464a23f7c91441776e0da94712070729374eb2d6af4a21"
            ),
            terminal_closure_byte_length=29027,
            terminal_live_keys=(
                "r24d111_source_status",
                "r24d111_physical_execution_authorized",
            ),
        )
    )
