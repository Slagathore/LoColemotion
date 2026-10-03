#!/usr/bin/env python3
"""Thin R120 binding for the reusable versioned-controller parameter gate."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.versioned_recovery_controller_target_gate import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d120_godot_jolt_raise_body_speed_controller_contract_v1.json",
            "sporespore_qsdk_r24d120_godot_jolt_raise_body_speed_controller_contract_v1",
            "QSDK-R24D120",
            "QSDK_R24D120_GODOT_JOLT_RAISE_BODY_SPEED_CONTROLLER_SOURCE_PASS",
            "QSDK_R24D120_GODOT_JOLT_RAISE_BODY_SPEED_CONTROLLER_SOURCE_FAIL",
            authority_field_prefix="r24d120",
            expected_historical_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v3"
            ),
            expected_successor_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v4"
            ),
            expected_historical_profile_sha256=(
                "sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
            ),
            expected_successor_profile_sha256=(
                "sha256:2e9f4f5720aec96b28552a04c8f1b6bbfeb3b01eaceac76834b450cb0d9b4900"
            ),
            expected_historical_command_sha256=(
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
            ),
            expected_successor_command_sha256=(
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
            ),
            expected_historical_targets=(
                0.60,
                -1.05,
                0.60,
                -1.05,
                -0.60,
                1.05,
                -0.60,
                1.05,
            ),
            expected_successor_targets=(
                0.60,
                -1.05,
                0.60,
                -1.05,
                -0.60,
                1.05,
                -0.60,
                1.05,
            ),
            expected_changed_target_indices=(),
            expected_changed_joint_ids=(),
            expected_cross_version_refusal_count=2,
            expected_unregistered_controller_refusal_count=3,
            expected_change_kind="raise_body_maximum_target_speed",
            expected_status=(
                "prospective_zero_world_versioned_raise_body_speed_"
                "implementation_qualification_pending"
            ),
            expected_authority_mode=(
                "prospective_zero_world_versioned_raise_body_speed_implementation"
            ),
            expected_historical_maximum_target_speed_rad_s=0.75,
            expected_successor_maximum_target_speed_rad_s=8.0,
            expected_preflight_schema=(
                "sporespore_versioned_recovery_controller_parameter_preflight_v2"
            ),
            expected_historical_regression_field=("historical_v1_v3_regression_count"),
            expected_historical_stance_pose_id=("exact_s169_zero_joint_stance_pose_v1"),
            expected_successor_stance_pose_id=("exact_s169_zero_joint_stance_pose_v2"),
            expected_raise_body_phase_steps=(0, 180, 360),
            expected_historical_raise_command_sha256=(
                "sha256:c9b643dc31923b9c59389d21a3750e2cd6c800002b9b30faf7631d47823a4b2d",
                "sha256:32727a1340c791d9c2224c633908018ce113ddef686f0dc755a894b9d168f38f",
                "sha256:c37b949e24558a92b1656b7b773d63e294152264b35c9f7623674a1eb202e545",
            ),
            expected_successor_raise_command_sha256=(
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
                "sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
                "sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
            ),
            expected_command_mutation_refusal_count=2,
        )
    )
