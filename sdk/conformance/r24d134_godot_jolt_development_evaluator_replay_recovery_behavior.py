#!/usr/bin/env python3
"""Thin R134 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d134_godot_jolt_development_evaluator_replay_"
    "recovery_behavior_contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d134_godot_jolt_development_evaluator_replay_"
    "recovery_behavior_contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            CONTRACT,
            CONTRACT_SCHEMA,
            terminal_closure_relative_path=(
                "sdk/recovery/"
                "r24d134_godot_jolt_development_evaluator_replay_"
                "recovery_behavior_physical_closure_v1.json"
            ),
            terminal_closure_schema=(
                "sporespore_qsdk_r24d134_godot_jolt_development_"
                "evaluator_replay_recovery_behavior_physical_closure_v1"
            ),
            terminal_closure_raw_sha256=(
                "sha256:6b6c2dac9a1ae87241c5783c2db153456d13f28d4b5006cf27d7c9d9e97c95a2"
            ),
            terminal_closure_byte_length=29056,
            terminal_live_keys=(
                "r24d134_source_status",
                "r24d134_physical_execution_authorized",
            ),
        )
    )
