#!/usr/bin/env python3
"""Thin R154 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d154_godot_jolt_accumulator_aware_discrete_staging_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d154_godot_jolt_accumulator_aware_discrete_staging_recovery_behavior_physical_closure_v1",
            "QSDK-R24D154",
            "sha256:6921e7cae291d50ddb5f0ad949c8cfe02cdfb26e49755a922e0bc4395d6f596e",
            30087,
            "QSDK_R24D154_ACCUMULATOR_AWARE_DISCRETE_STAGING_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D154_ACCUMULATOR_AWARE_DISCRETE_STAGING_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d154_godot_jolt_accumulator_aware_discrete_staging_recovery_behavior_contract_v1.json",
            actuation_projection_mode="solver_coupled_constraint_motor_v1",
            live_record_key="r24d154_contract_path",
            live_identity_prefix="r24d154_physical_closure",
            ignored_forward_live_keys=(),
            next_gate_id="QSDK-R24D155",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
