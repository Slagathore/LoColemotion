#!/usr/bin/env python3
"""Thin R161 binding for the reusable digest-bound engineering diagnosis."""

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
            (
                "sdk/recovery/r24d161_godot_jolt_rotation_integration_"
                "scale_and_recovery_adoption_diagnosis_v1.json"
            ),
            (
                "sporespore_qsdk_r24d161_godot_jolt_rotation_integration_"
                "scale_and_recovery_adoption_diagnosis_v1"
            ),
            "sha256:1f163c137f04b180ebbddbd4774641d54ac145e46bd302a607ea551d6a61984e",
            20162,
            (
                "QSDK_R24D161_GODOT_JOLT_ROTATION_INTEGRATION_SCALE_AND_"
                "RECOVERY_ADOPTION_DIAGNOSIS_PASS"
            ),
            (
                "QSDK_R24D161_GODOT_JOLT_ROTATION_INTEGRATION_SCALE_AND_"
                "RECOVERY_ADOPTION_DIAGNOSIS_FAIL"
            ),
            gate_id="QSDK-R24D161",
            expected_status=(
                "closed_zero_world_scale_nonextrapolation_recovery_ledger_"
                "integration_selected_physics_blocked"
            ),
            authority_mode=(
                "closed_zero_world_immutable_evidence_scale_and_"
                "applicability_diagnosis"
            ),
            next_gate_id="QSDK-R24D162",
            next_required_decision_key=(
                "r24d162_zero_world_recovery_ledger_integration_required"
            ),
            live_record_key="r24d160_contract_path",
            live_identity_prefix="r24d161_diagnosis",
            required_record_paths={
                "interpretation.r154_valid_complete_behavior_negative_preserved": True,
                "interpretation.r160_valid_complete_native_observation_preserved": True,
                "interpretation.native_field_population_established": True,
                "interpretation.r160_values_applicable_to_r154_scale": False,
                "interpretation.r160_small_fixture_values_justify_omission": False,
                "interpretation.production_recovery_measurement_gap_open": True,
                "interpretation.measurement_completeness_integration_warranted": True,
                "interpretation.r154_residual_explained": False,
                "decision.recovery_ledger_integration_selected": True,
                "decision.controller_change_selected": False,
                "decision.threshold_change_selected": False,
                "decision.full_seeded_ghost_selected": False,
                "decision.bespoke_physical_canary_selected": False,
                "claim_boundary.r160_scale_generalized": False,
                "claim_boundary.rotational_staging_cause_established": False,
                "claim_boundary.recovery_ledger_integration_implemented": False,
            },
        )
    )
