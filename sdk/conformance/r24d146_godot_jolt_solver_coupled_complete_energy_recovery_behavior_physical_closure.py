#!/usr/bin/env python3
"""Thin R146 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d146_godot_jolt_solver_coupled_complete_energy_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d146_godot_jolt_solver_coupled_complete_energy_recovery_behavior_physical_closure_v1",
            "QSDK-R24D146",
            "sha256:ad80b1942e4ecf152b2162fde366863dbb331f11601afbef47c60251731b64c1",
            28776,
            "QSDK_R24D146_SOLVER_COUPLED_COMPLETE_ENERGY_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D146_SOLVER_COUPLED_COMPLETE_ENERGY_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d146_godot_jolt_solver_coupled_complete_energy_recovery_behavior_contract_v1.json",
            actuation_projection_mode="solver_coupled_constraint_motor_v1",
            live_record_key="r24d146_contract_path",
            live_identity_prefix="r24d146_physical_closure",
            ignored_forward_live_keys=(),
            next_gate_id="QSDK-R24D147",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
