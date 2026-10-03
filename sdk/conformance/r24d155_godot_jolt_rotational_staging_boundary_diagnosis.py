#!/usr/bin/env python3
"""Thin R155 binding for the reusable staging-successor diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_energy_gate_diagnosis import (  # noqa: E402
    run_discrete_staging_successor_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_discrete_staging_successor_diagnosis_cli(
            ROOT,
            "sdk/recovery/r24d155_godot_jolt_rotational_staging_boundary_diagnosis_v1.json",
            "sporespore_qsdk_r24d155_godot_jolt_rotational_staging_boundary_diagnosis_v1",
            "sha256:6d56ced147908d7df1e265768830347b3a47791111e34c79bbe65f7ed95117ec",
            20947,
            "QSDK_R24D155_GODOT_JOLT_ROTATIONAL_STAGING_BOUNDARY_DIAGNOSIS_PASS",
            "QSDK_R24D155_GODOT_JOLT_ROTATIONAL_STAGING_BOUNDARY_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D155",
            expected_status=(
                "closed_zero_world_retained_trace_rotational_staging_boundary_"
                "localized_physics_blocked"
            ),
            authority_mode=(
                "closed_zero_world_retained_trace_rotational_staging_boundary_diagnosis"
            ),
            next_gate_id="QSDK-R24D156",
            next_required_decision_key=(
                "r24d156_zero_world_rotational_staging_observer_design_required"
            ),
            live_record_key="r24d154_contract_path",
            live_identity_prefix="r24d155_diagnosis",
            ignored_forward_live_keys=(
                "r24d156_zero_world_rotational_staging_observer_design_required",
            ),
        )
    )
