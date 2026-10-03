#!/usr/bin/env python3
"""Thin R113 binding for the reusable versioned-controller target gate."""

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
            "sdk/recovery/r24d113_godot_jolt_mirrored_front_knee_controller_contract_v1.json",
            "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_controller_contract_v1",
            "QSDK-R24D113",
            "QSDK_R24D113_GODOT_JOLT_MIRRORED_FRONT_KNEE_CONTROLLER_SOURCE_PASS",
            "QSDK_R24D113_GODOT_JOLT_MIRRORED_FRONT_KNEE_CONTROLLER_SOURCE_FAIL",
            authority_field_prefix="r24d113",
            expected_historical_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v1"
            ),
            expected_successor_controller_id=(
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            expected_historical_profile_sha256=(
                "sha256:e6afb9811d0936157ce42f9e72911ac005ecf950f32a5b1f1f1cef24cf3eb2ef"
            ),
            expected_successor_profile_sha256=(
                "sha256:79bbc8be5aa6102f78e457731c3ef43f144c9f52ffac39aeda3a0475dc89d2f4"
            ),
            expected_historical_command_sha256=(
                "sha256:a3db46122897f379a8e85913bfb8d1b52f795886fd122ec9a99966917e57fd74"
            ),
            expected_successor_command_sha256=(
                "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
            ),
            expected_historical_targets=(
                0.60,
                1.05,
                0.60,
                1.05,
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
            expected_changed_target_indices=(1, 3),
            expected_changed_joint_ids=("front_left_knee", "front_right_knee"),
            expected_cross_version_refusal_count=2,
            expected_unregistered_controller_refusal_count=3,
        )
    )
