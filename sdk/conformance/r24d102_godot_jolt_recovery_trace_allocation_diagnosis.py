#!/usr/bin/env python3
"""Thin R102 binding for the reusable retained-trace diagnosis audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_trace_diagnosis import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d102_godot_jolt_recovery_trace_allocation_diagnosis_v1.json",
            "sporespore_qsdk_r24d102_godot_jolt_recovery_trace_allocation_diagnosis_v1",
            "sha256:68fe3a8307b56f001af45899e4bb2627420e4b329b7a6471ee2fd4113e27ac47",
            14767,
            "QSDK_R24D102_RECOVERY_TRACE_ALLOCATION_DIAGNOSIS_PASS",
            "QSDK_R24D102_RECOVERY_TRACE_ALLOCATION_DIAGNOSIS_FAIL",
        )
    )
