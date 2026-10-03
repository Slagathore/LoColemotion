#!/usr/bin/env python3
"""Thin R106 binding for the reusable paired target-tracking diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_trace_diagnosis import (  # noqa: E402
    run_paired_target_tracking_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_paired_target_tracking_cli(
            ROOT,
            "sdk/recovery/r24d106_godot_jolt_paired_target_tracking_diagnosis_v1.json",
            "sporespore_qsdk_r24d106_godot_jolt_paired_target_tracking_diagnosis_v1",
            "sha256:f6a4f07f931bf14275110731750fcdcd2bf6a9981cc52a3e982306312f7b6ac7",
            15882,
            "QSDK_R24D106_PAIRED_TARGET_TRACKING_DIAGNOSIS_PASS",
            "QSDK_R24D106_PAIRED_TARGET_TRACKING_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D106",
            next_gate_id="QSDK-R24D107",
            live_record_key="r24d105_contract_path",
            live_identity_prefix="r24d106_diagnosis",
        )
    )
