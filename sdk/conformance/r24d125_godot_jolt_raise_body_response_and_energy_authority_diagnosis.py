#!/usr/bin/env python3
"""Thin R125 binding for the reusable response and energy-authority diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_load_path_diagnosis import (  # noqa: E402
    run_raise_body_response_and_energy_authority_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_raise_body_response_and_energy_authority_diagnosis_cli(
            ROOT,
            "sdk/recovery/r24d125_godot_jolt_raise_body_response_and_energy_authority_diagnosis_v1.json",
            "sporespore_qsdk_r24d125_godot_jolt_raise_body_response_and_energy_authority_diagnosis_v1",
            "sha256:e0155522cd007a1e4eaccdc0a1ed544e9d045cbdf4abad4b80fefe7fbf5133c2",
            27888,
            "QSDK_R24D125_RAISE_BODY_RESPONSE_AND_ENERGY_AUTHORITY_DIAGNOSIS_PASS",
            "QSDK_R24D125_RAISE_BODY_RESPONSE_AND_ENERGY_AUTHORITY_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D125",
            next_gate_id="QSDK-R24D126",
            live_record_key="r24d124_contract_path",
            live_identity_prefix="r24d125_diagnosis",
            ignored_forward_live_keys=("r24d126_zero_world_implementation_required",),
        )
    )
