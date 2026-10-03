#!/usr/bin/env python3
"""Thin R129 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d129_godot_jolt_solver_coupled_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d129_godot_jolt_solver_coupled_recovery_behavior_physical_closure_v1",
            "QSDK-R24D129",
            "sha256:b2f137d7122cbe29be285be5950aeab315b37f778df9af976c409cbb4c6dcccc",
            26939,
            "QSDK_R24D129_SOLVER_COUPLED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D129_SOLVER_COUPLED_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d129_godot_jolt_solver_coupled_recovery_behavior_contract_v1.json",
            actuation_projection_mode="solver_coupled_constraint_motor_v1",
            live_record_key="r24d129_contract_path",
            live_identity_prefix="r24d129_physical_closure",
            ignored_forward_live_keys=(
                "r24d130_zero_world_solver_coupled_stable_stance_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D130",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
