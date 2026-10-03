#!/usr/bin/env python3
"""Thin R130 binding for the reusable declared-route diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_progression_route_diagnosis import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d130_godot_jolt_declared_progression_route_diagnosis_v1.json",
            "sporespore_qsdk_r24d130_godot_jolt_declared_progression_route_diagnosis_v1",
            "sha256:fa2bb5ad31bde06cf4dbc9220684a1537274efc2f60943c0c788139741c83c63",
            15124,
            "QSDK_R24D130_DECLARED_PROGRESSION_ROUTE_DIAGNOSIS_PASS",
            "QSDK_R24D130_DECLARED_PROGRESSION_ROUTE_DIAGNOSIS_FAIL",
        )
    )
