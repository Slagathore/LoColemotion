#!/usr/bin/env python3
"""Thin R143 binding for the reusable digest-bound engineering diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_load_path_diagnosis import (  # noqa: E402
    run_bound_zero_world_engineering_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_bound_zero_world_engineering_diagnosis_cli(
            ROOT,
            "sdk/recovery/r24d143_godot_jolt_actuator_realization_energy_partition_diagnosis_v1.json",
            "sporespore_qsdk_r24d143_godot_jolt_actuator_realization_energy_partition_diagnosis_v1",
            "sha256:9dfbbfd5d83c16ad6775fd45b7302f67121750f83d5be8d9e0d0826bd3cc595b",
            31532,
            "QSDK_R24D143_ACTUATOR_REALIZATION_ENERGY_PARTITION_DIAGNOSIS_PASS",
            "QSDK_R24D143_ACTUATOR_REALIZATION_ENERGY_PARTITION_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D143",
            expected_status=(
                "closed_zero_world_solver_coupled_native_motor_"
                "complete_energy_partition_selected"
            ),
            authority_mode=(
                "closed_zero_world_retained_evidence_actuator_realization_"
                "energy_partition_diagnosis"
            ),
            next_gate_id="QSDK-R24D144",
            next_required_decision_key=(
                "r24d144_zero_world_solver_coupled_complete_energy_"
                "partition_implementation_required"
            ),
            live_record_key="r24d142_contract_path",
            live_identity_prefix="r24d143_diagnosis",
            required_record_paths={
                "interpretation.existing_runtime_measurements_adequate_for_adapter_first_zero_world_successor": True,
                "interpretation.formal_superiority_established": False,
                "decision.solver_coupled_native_motor_complete_energy_partition_selected": True,
                "decision.native_engine_rebuild_selected": False,
                "decision.recovery_controller_change_selected": False,
                "decision.short_real_runtime_partition_route_ghost_required_after_r24d144": True,
                "claim_boundary.formal_causal_attribution_claimed": False,
                "claim_boundary.complete_solver_coupled_energy_partition_claimed": False,
            },
            ignored_forward_live_keys=(
                "r24d144_zero_world_solver_coupled_complete_energy_partition_implementation_required",
                "physical_execution_blocked_pending_r24d144_declaration",
                "physical_execution_blocked_until_r24d144_zero_world_qualification",
            ),
        )
    )
