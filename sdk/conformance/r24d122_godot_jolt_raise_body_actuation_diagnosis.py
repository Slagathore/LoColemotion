#!/usr/bin/env python3
"""Thin R122 binding for the reusable raise-body actuation diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_load_path_diagnosis import (  # noqa: E402
    run_raise_body_actuation_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_raise_body_actuation_diagnosis_cli(
            ROOT,
            "sdk/recovery/r24d122_godot_jolt_raise_body_actuation_diagnosis_v1.json",
            "sporespore_qsdk_r24d122_godot_jolt_raise_body_actuation_diagnosis_v1",
            "sha256:145fa7d3dcfd3bf67bff9c0c329a13551d7bec24ce0948a1a85c54add1b34cdc",
            23917,
            "QSDK_R24D122_RAISE_BODY_ACTUATION_DIAGNOSIS_PASS",
            "QSDK_R24D122_RAISE_BODY_ACTUATION_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D122",
            next_gate_id="QSDK-R24D123",
            live_record_key="r24d121_contract_path",
            live_identity_prefix="r24d122_diagnosis",
            ignored_forward_live_keys=("r24d123_zero_world_implementation_required",),
        )
    )
