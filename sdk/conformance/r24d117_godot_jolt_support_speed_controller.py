#!/usr/bin/env python3
"""Thin R117 binding for the reusable versioned-controller parameter gate."""

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
            "sdk/recovery/r24d117_godot_jolt_support_speed_controller_contract_v1.json",
            "sporespore_qsdk_r24d117_godot_jolt_support_speed_controller_contract_v1",
            "QSDK-R24D117",
            "QSDK_R24D117_GODOT_JOLT_SUPPORT_SPEED_CONTROLLER_SOURCE_PASS",
            "QSDK_R24D117_GODOT_JOLT_SUPPORT_SPEED_CONTROLLER_SOURCE_FAIL",
            authority_field_prefix="r24d117",
            expected_historical_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            expected_successor_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v3"
            ),
            expected_historical_profile_sha256=(
                "sha256:79bbc8be5aa6102f78e457731c3ef43f144c9f52ffac39aeda3a0475dc89d2f4"
            ),
            expected_successor_profile_sha256=(
                "sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
            ),
            expected_historical_command_sha256=(
                "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
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
            expected_change_kind="maximum_target_speed",
            expected_status=(
                "prospective_zero_world_versioned_controller_speed_"
                "implementation_qualification_pending"
            ),
            expected_authority_mode=(
                "prospective_zero_world_versioned_controller_speed_implementation"
            ),
            expected_historical_maximum_target_speed_rad_s=1.0,
            expected_successor_maximum_target_speed_rad_s=8.0,
            expected_preflight_schema=(
                "sporespore_versioned_recovery_controller_parameter_preflight_v1"
            ),
            expected_historical_regression_field=(
                "historical_v1_v2_regression_count"
            ),
        )
    )
