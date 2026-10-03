#!/usr/bin/env python3
"""Thin R119 binding for the reusable recovery load-path diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_load_path_diagnosis import (  # noqa: E402
    run_raise_body_load_path_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_raise_body_load_path_cli(
            ROOT,
            "sdk/recovery/r24d119_godot_jolt_raise_body_load_path_diagnosis_v1.json",
            "sporespore_qsdk_r24d119_godot_jolt_raise_body_load_path_diagnosis_v1",
            "sha256:77c28e5163c303c56904c5613b43353d19b154d11ec064866f73500eac8cdae8",
            33090,
            "QSDK_R24D119_RAISE_BODY_LOAD_PATH_DIAGNOSIS_PASS",
            "QSDK_R24D119_RAISE_BODY_LOAD_PATH_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D119",
            next_gate_id="QSDK-R24D120",
            live_record_key="r24d118_contract_path",
            live_identity_prefix="r24d119_diagnosis",
            ignored_forward_live_keys=("r24d120_zero_world_implementation_required",),
        )
    )
