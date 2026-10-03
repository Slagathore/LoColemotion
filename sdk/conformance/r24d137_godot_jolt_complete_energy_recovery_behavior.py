#!/usr/bin/env python3
"""Thin R137 binding for the reusable finite recovery behavior gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d137_godot_jolt_complete_energy_"
    "recovery_behavior_contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d137_godot_jolt_complete_energy_"
    "recovery_behavior_contract_v1"
)


if __name__ == "__main__":
    raise SystemExit(run_cli(ROOT, CONTRACT, CONTRACT_SCHEMA))
