#!/usr/bin/env python3
"""Thin R105 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d105_godot_jolt_order_neutral_population_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d105_godot_jolt_order_neutral_population_recovery_behavior_physical_closure_v1",
            "QSDK-R24D105",
            "sha256:0f64a4cf5bec896a77b757ba3a0995c04f6d7ab3c861d5413e514d879df5712c",
            26086,
            "QSDK_R24D105_ORDER_NEUTRAL_POPULATION_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D105_ORDER_NEUTRAL_POPULATION_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d105_godot_jolt_order_neutral_population_recovery_behavior_contract_v1.json",
            actuation_projection_mode="order_neutral_population_v1",
            live_record_key="r24d105_contract_path",
            live_identity_prefix="r24d105_physical_closure",
            ignored_forward_live_keys=(),
            next_gate_id="QSDK-R24D106",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
