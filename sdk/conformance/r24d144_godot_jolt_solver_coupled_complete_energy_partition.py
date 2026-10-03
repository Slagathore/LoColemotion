#!/usr/bin/env python3
"""Thin R144 binding for shared compact Godot zero-world qualification."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.compact_godot_zero_world_qualification import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d144_godot_jolt_solver_coupled_complete_energy_partition_zero_world_qualification_contract_v1.json",
        )
    )
