#!/usr/bin/env python3
"""Thin R124 binding for the reusable qualification-closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_qualification_closure import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d124_godot_jolt_raise_body_speed_recovery_behavior_zero_world_qualification_closure_v1.json",
            "sporespore_qsdk_r24d124_godot_jolt_raise_body_speed_recovery_behavior_zero_world_qualification_closure_v1",
            "QSDK-R24D124",
            "QSDK_R24D124_RAISE_BODY_SPEED_RECOVERY_BEHAVIOR_QUALIFICATION_CLOSURE_PASS",
            "QSDK_R24D124_RAISE_BODY_SPEED_RECOVERY_BEHAVIOR_QUALIFICATION_CLOSURE_FAIL",
        )
    )
