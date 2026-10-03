#!/usr/bin/env python3
"""Thin R109 binding for the reusable finite Godot/Jolt production gate."""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_gate import run_cli  # noqa: E402

CONTRACT = (
    "sdk/recovery/r24d109_godot_jolt_joint_space_effective_inertia_population_"
    "route_contract_v1.json"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d109_godot_jolt_joint_space_effective_inertia_"
    "population_route_contract_v1"
)


if __name__ == "__main__":
    physical_closure_relative = (
        "sdk/recovery/r24d109_godot_jolt_joint_space_effective_inertia_"
        "population_route_ghost_closure_v1.json"
    )
    physical_closure = ROOT / physical_closure_relative
    terminal_arguments = {}
    if physical_closure.is_file():
        raw = physical_closure.read_bytes()
        terminal_arguments = {
            "terminal_closure_relative_path": physical_closure_relative,
            "terminal_closure_schema": (
                "sporespore_qsdk_r24d109_godot_jolt_joint_space_effective_"
                "inertia_population_route_ghost_closure_v1"
            ),
            "terminal_closure_raw_sha256": (
                "sha256:" + hashlib.sha256(raw).hexdigest()
            ),
            "terminal_closure_byte_length": len(raw),
            "terminal_live_keys": (
                "r24d109_source_status",
                "r24d109_physical_execution_authorized",
            ),
        }
    raise SystemExit(
        run_cli(ROOT, CONTRACT, CONTRACT_SCHEMA, **terminal_arguments)
    )
