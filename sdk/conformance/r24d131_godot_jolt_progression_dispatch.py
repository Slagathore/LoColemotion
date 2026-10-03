#!/usr/bin/env python3
"""Thin R131 binding for the production recovery-route gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.production_recovery_route_binding_gate import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d131_godot_jolt_progression_dispatch_contract_v1.json",
            "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_contract_v1",
            "QSDK-R24D131",
            "QSDK_R24D131_GODOT_JOLT_PROGRESSION_DISPATCH_SOURCE_PASS",
            "QSDK_R24D131_GODOT_JOLT_PROGRESSION_DISPATCH_SOURCE_FAIL",
        )
    )
