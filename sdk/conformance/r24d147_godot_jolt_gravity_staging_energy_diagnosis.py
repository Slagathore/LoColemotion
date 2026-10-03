#!/usr/bin/env python3
"""Thin R147 binding for the reusable retained energy-handoff diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_energy_gate_diagnosis import (  # noqa: E402
    run_complete_energy_handoff_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_complete_energy_handoff_diagnosis_cli(
            ROOT,
            "sdk/recovery/r24d147_godot_jolt_gravity_staging_energy_diagnosis_v1.json",
            "sporespore_qsdk_r24d147_godot_jolt_gravity_staging_energy_diagnosis_v1",
            "sha256:27d32fe7af92301e024f660dbcff6d8a7d46e9954b9bfc5003ea228a6609cf67",
            23363,
            "QSDK_R24D147_GODOT_JOLT_GRAVITY_STAGING_ENERGY_DIAGNOSIS_PASS",
            "QSDK_R24D147_GODOT_JOLT_GRAVITY_STAGING_ENERGY_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D147",
            expected_status=(
                "closed_zero_world_retained_trace_gravity_staging_boundary_"
                "localized_physics_blocked"
            ),
            authority_mode=(
                "closed_zero_world_retained_trace_gravity_staging_energy_diagnosis"
            ),
            next_gate_id="QSDK-R24D148",
            next_required_decision_key=(
                "r24d148_zero_world_discrete_staging_observer_design_required"
            ),
            live_record_key="r24d146_contract_path",
            live_identity_prefix="r24d147_diagnosis",
            ignored_forward_live_keys=(
                "r24d148_zero_world_discrete_staging_observer_design_required",
                "physical_execution_blocked_pending_r24d148_zero_world_design",
            ),
        )
    )
