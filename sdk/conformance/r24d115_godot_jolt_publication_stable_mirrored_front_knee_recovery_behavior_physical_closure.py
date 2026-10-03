#!/usr/bin/env python3
"""Thin R115 binding for the reusable finite behavior physical closure."""

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
            "sdk/recovery/r24d115_godot_jolt_publication_stable_mirrored_front_knee_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d115_godot_jolt_publication_stable_mirrored_front_knee_recovery_behavior_physical_closure_v1",
            "QSDK-R24D115",
            "sha256:895347345933153884d439a1a9d0b2324232c85a0a4e0e9dedfe48bcd1e0eae9",
            29703,
            "QSDK_R24D115_PUBLICATION_STABLE_MIRRORED_FRONT_KNEE_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D115_PUBLICATION_STABLE_MIRRORED_FRONT_KNEE_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d115_godot_jolt_publication_stable_mirrored_front_knee_recovery_behavior_contract_v1.json",
            actuation_projection_mode="joint_space_effective_inertia_population_v1",
            live_record_key="r24d115_contract_path",
            live_identity_prefix="r24d115_physical_closure",
            ignored_forward_live_keys=(
                "r24d116_zero_world_load_path_and_successor_pose_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D116",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
