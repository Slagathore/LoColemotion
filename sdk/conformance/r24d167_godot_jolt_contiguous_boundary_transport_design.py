#!/usr/bin/env python3
"""Thin R167 binding for the zero-world contiguous-boundary design."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_boundary_transport_design import (  # noqa: E402
    run_contiguous_boundary_transport_design_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_contiguous_boundary_transport_design_cli(
            ROOT,
            "sdk/recovery/r24d167_godot_jolt_contiguous_boundary_transport_design_v1.json",
            "sporespore_qsdk_r24d167_godot_jolt_contiguous_boundary_transport_design_v1",
            "sha256:c44789a252976208aace4b541e2030564a38399df2e5facbbb00586ccb70e775",
            21813,
            "QSDK_R24D167_GODOT_JOLT_CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_PASS",
            "QSDK_R24D167_GODOT_JOLT_CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_FAIL",
            gate_id="QSDK-R24D167",
            expected_status=(
                "closed_zero_world_contiguous_boundary_transport_design_qualified_"
                "r168_implementation_required_physics_blocked"
            ),
            authority_mode=(
                "closed_zero_world_executable_contiguous_boundary_transport_design"
            ),
            next_gate_id="QSDK-R24D168",
            next_required_decision_key=(
                "r24d168_zero_world_boundary_transport_implementation_required"
            ),
            live_record_key="r24d165_contract_path",
            live_identity_prefix="r24d167_design",
            required_record_paths={
                "interpretation.r166_boundary_alignment_defect_preserved": True,
                "interpretation.r148_observer_equations_preserved": True,
                "interpretation.r162_rotation_term_preserved": True,
                "interpretation.v6_controller_preserved": True,
                "interpretation.frozen_energy_threshold_preserved": True,
                "decision.boundary_transport_implementation_selected": True,
                "decision.native_engine_rebuild_selected": False,
                "decision.full_seeded_ghost_selected": False,
                "decision.bespoke_physical_canary_selected": False,
                "claim_boundary.r167_live_boundary_transport_qualified": False,
            },
        )
    )
