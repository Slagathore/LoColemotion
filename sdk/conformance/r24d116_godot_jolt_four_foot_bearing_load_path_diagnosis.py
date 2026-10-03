#!/usr/bin/env python3
"""Thin R116 binding for the reusable recovery load-path diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_load_path_diagnosis import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d116_godot_jolt_four_foot_bearing_load_path_diagnosis_v1.json",
            "sporespore_qsdk_r24d116_godot_jolt_four_foot_bearing_load_path_diagnosis_v1",
            "sha256:96ee2a64e6138576c5ae2e5a9b0f500d0894cf9697f8e9e7cae9012c48976ac0",
            16607,
            "QSDK_R24D116_FOUR_FOOT_BEARING_LOAD_PATH_DIAGNOSIS_PASS",
            "QSDK_R24D116_FOUR_FOOT_BEARING_LOAD_PATH_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D116",
            next_gate_id="QSDK-R24D117",
            live_record_key="r24d115_contract_path",
            live_identity_prefix="r24d116_diagnosis",
            next_required_key="r24d117_zero_world_implementation_required",
        )
    )
