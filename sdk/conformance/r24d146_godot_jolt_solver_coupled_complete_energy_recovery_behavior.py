#!/usr/bin/env python3
"""Thin R146 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d146_godot_jolt_solver_coupled_complete_energy_"
    "recovery_behavior_contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d146_godot_jolt_solver_coupled_complete_energy_"
    "recovery_behavior_contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            CONTRACT,
            CONTRACT_SCHEMA,
            terminal_closure_relative_path=(
                "sdk/recovery/r24d146_godot_jolt_solver_coupled_complete_energy_"
                "recovery_behavior_physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d146_godot_jolt_solver_coupled_complete_"
                "energy_recovery_behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:ad80b1942e4ecf152b2162fde366863dbb331f11601afbef47c60251731b64c1"
            ),
            terminal_closure_byte_length=28776,
            terminal_live_keys=(
                "r24d146_source_status",
                "r24d146_physical_execution_authorized",
                "r24d146_prone_to_standing_claimed",
                "r24d146_sdk1_milestone_advanced",
            ),
        )
    )
