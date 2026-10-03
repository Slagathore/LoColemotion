#!/usr/bin/env python3
"""Thin R166 binding for the retained boundary-alignment diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_energy_gate_diagnosis import (  # noqa: E402
    run_rotation_boundary_alignment_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_rotation_boundary_alignment_diagnosis_cli(
            ROOT,
            (
                "sdk/recovery/r24d166_godot_jolt_discrete_staging_"
                "boundary_alignment_diagnosis_v1.json"
            ),
            (
                "sporespore_qsdk_r24d166_godot_jolt_discrete_staging_"
                "boundary_alignment_diagnosis_v1"
            ),
            "sha256:67b6bdb14c2a9a1874457fcaee29b129aabc33a3697a362708e9f0f0f29c3572",
            28451,
            (
                "QSDK_R24D166_GODOT_JOLT_DISCRETE_STAGING_BOUNDARY_"
                "ALIGNMENT_DIAGNOSIS_PASS"
            ),
            (
                "QSDK_R24D166_GODOT_JOLT_DISCRETE_STAGING_BOUNDARY_"
                "ALIGNMENT_DIAGNOSIS_FAIL"
            ),
            gate_id="QSDK-R24D166",
            expected_status=(
                "closed_zero_world_retained_trace_and_source_timing_boundary_"
                "alignment_defect_localized_r167_design_required_physics_blocked"
            ),
            authority_mode=(
                "closed_zero_world_retained_trace_and_immutable_source_boundary_"
                "alignment_diagnosis"
            ),
            next_gate_id="QSDK-R24D167",
            next_required_decision_key=(
                "r24d167_zero_world_contiguous_boundary_transport_design_required"
            ),
            live_record_key="r24d165_contract_path",
            live_identity_prefix="r24d166_diagnosis",
            ignored_forward_live_keys=(
                "r24d167_zero_world_contiguous_boundary_transport_design_required",
                "r24d167_question_class_declared",
                "r24d167_physical_execution_authorized",
                "physical_execution_blocked_pending_r24d167_declaration",
                "physical_execution_blocked_until_r24d167_zero_world_qualification",
            ),
            required_record_paths={
                "interpretation.r154_valid_complete_behavior_negative_preserved": True,
                "interpretation.r165_valid_complete_behavior_negative_preserved": True,
                "interpretation.prior_exact_balance_partition_safe_for_prospective_reliance": False,
                "decision.contiguous_boundary_transport_design_selected": True,
                "decision.boundary_transport_implementation_selected": False,
                "decision.r148_observer_equation_change_selected": False,
                "decision.native_engine_rebuild_selected": False,
                "decision.full_seeded_ghost_selected": False,
                "decision.bespoke_physical_canary_selected": False,
                "claim_boundary.current_exact_balance_safety_authority_available_for_prospective_reliance": False,
                "claim_boundary.r24d167_boundary_transport_designed": False,
                "claim_boundary.r24d167_boundary_transport_implemented": False,
            },
        )
    )
