#!/usr/bin/env python3
"""Thin R112 binding for the reusable phase-target diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_phase_target_diagnosis import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d112_godot_jolt_front_support_target_sign_diagnosis_v1.json",
            "sporespore_qsdk_r24d112_godot_jolt_front_support_target_sign_diagnosis_v1",
            "sha256:ccdfcc12c45f9c16360c06abd41b33ebd09fdae33e3911de2e618d1e728b5874",
            15042,
            "QSDK_R24D112_FRONT_SUPPORT_TARGET_SIGN_DIAGNOSIS_PASS",
            "QSDK_R24D112_FRONT_SUPPORT_TARGET_SIGN_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D112",
            next_gate_id="QSDK-R24D113",
            live_record_key="r24d111_contract_path",
            live_identity_prefix="r24d112_diagnosis",
        )
    )
