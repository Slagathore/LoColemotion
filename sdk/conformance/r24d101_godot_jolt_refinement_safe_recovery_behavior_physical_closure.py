#!/usr/bin/env python3
"""Thin R101 binding for the reusable finite behavior physical closure."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_physical_closure import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d101_godot_jolt_refinement_safe_recovery_behavior_negative_closure_v1.json",
            "sporespore_qsdk_r24d101_godot_jolt_refinement_safe_recovery_behavior_negative_closure_v1",
            "QSDK-R24D101",
            "sha256:58f605bc3940f501187c3ab7ef1491e7769a20fbc7bc9a5544ae8ad739c1c2a5",
            20963,
            "QSDK_R24D101_REFINEMENT_SAFE_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D101_REFINEMENT_SAFE_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
        )
    )
