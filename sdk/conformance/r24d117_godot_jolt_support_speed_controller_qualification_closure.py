#!/usr/bin/env python3
"""Bind R117 identities to the reusable versioned-controller closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.versioned_recovery_controller_qualification_closure import (  # noqa: E402
    VersionedRecoveryControllerQualificationSpec,
    run_versioned_recovery_controller_qualification_audit,
)

AUDIT_RELATIVE_PATH = (
    "sdk/conformance/r24d117_godot_jolt_support_speed_controller_"
    "qualification_closure.py"
)
MARKER = "QSDK_R24D117_GODOT_JOLT_SUPPORT_SPEED_QUALIFICATION_CLOSURE_PASS"
SPEC = VersionedRecoveryControllerQualificationSpec(
    gate_id="QSDK-R24D117",
    authority_prefix="r24d117",
    source_commit="406af064cfab8d7a8da4665909107ab62559d935",
    source_subject="[recovery/core] Freeze R117: version support-speed controller",
    closure_relative_path=(
        "sdk/recovery/r24d117_godot_jolt_support_speed_controller_"
        "zero_world_qualification_closure_v1.json"
    ),
    closure_schema=(
        "sporespore_qsdk_r24d117_godot_jolt_support_speed_controller_"
        "zero_world_qualification_closure_v1"
    ),
    qualified_status=(
        "closed_complete_zero_world_versioned_support_speed_controller_"
        "qualified_successor_physical_declaration_required"
    ),
    closure_authority_mode=(
        "closed_complete_zero_world_versioned_controller_speed_qualification"
    ),
    predecessor_status=(
        "closed_zero_world_four_foot_contact_below_bearing_load_path_diagnosis_"
        "eight_rad_s_successor_selected"
    ),
    attempt_schema=(
        "sporespore_qsdk_r24d117_godot_jolt_support_speed_controller_"
        "zero_world_attempt_v1"
    ),
    receipt_schema=(
        "sporespore_qsdk_r24d117_godot_jolt_support_speed_controller_"
        "zero_world_receipt_v1"
    ),
    qualification_directory_prefix=(
        "qsdk-r24d117-godot-jolt-support-speed-controller-qualification-"
    ),
    source_audit_marker=(
        "QSDK_R24D117_GODOT_JOLT_SUPPORT_SPEED_CONTROLLER_SOURCE_PASS"
    ),
    native_zero_world_marker="SPORESPORE_GODOT_R24D117_SUPPORT_SPEED_ZERO_WORLD",
    source_inventory_count=26,
    authored_source_path_count=13,
    prospective_status=(
        "prospective_zero_world_versioned_controller_speed_"
        "implementation_qualification_pending"
    ),
    change_kind="maximum_target_speed",
    historical_controller_id="sporespore_exact_s169_prone_to_standing_controller_v2",
    successor_controller_id="sporespore_exact_s169_prone_to_standing_controller_v3",
    historical_profile_sha256=(
        "sha256:79bbc8be5aa6102f78e457731c3ef43f144c9f52ffac39aeda3a0475dc89d2f4"
    ),
    successor_profile_sha256=(
        "sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
    ),
    historical_command_sha256=(
        "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
    ),
    successor_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
    ),
    changed_indices=tuple(range(8)),
    historical_regression_receipt_field="historical_v1_v2_regression_passed",
    historical_regression_qualification_field="historical_v1_v2_regression_count",
    preserved_receipt_field="non_speed_command_fields_identical",
    preflight_schema="sporespore_versioned_recovery_controller_parameter_preflight_v1",
    core_runtime_sha256=(
        "sha256:3c381a524be2aef51412dc50367b1c60a9d2b35a940b2e19693b2518ab0da148"
    ),
    qualified_claim_field="versioned_support_speed_controller_mechanics_qualified",
    adequacy_field=(
        "qualification_adequate_for_exact_controller_speed_version_and_production_route"
    ),
    decision_result="qualified_exact_versioned_eight_rad_s_support_speed_controller_route",
    next_gate_id="r24d118",
    next_declaration_required_field="r24d118_distinct_physical_declaration_required",
    historical_maximum_target_speed_rad_s=1.0,
    successor_maximum_target_speed_rad_s=8.0,
)


if __name__ == "__main__":
    raise SystemExit(
        run_versioned_recovery_controller_qualification_audit(
            root=ROOT,
            spec=SPEC,
            audit_relative_path=AUDIT_RELATIVE_PATH,
            marker=MARKER,
        )
    )
