#!/usr/bin/env python3
"""Bind R123 identities to the reusable versioned-controller closure audit."""

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
    "sdk/conformance/r24d123_godot_jolt_raise_body_speed_controller_"
    "qualification_closure.py"
)
MARKER = "QSDK_R24D123_GODOT_JOLT_RAISE_BODY_SPEED_QUALIFICATION_CLOSURE_PASS"
SPEC = VersionedRecoveryControllerQualificationSpec(
    gate_id="QSDK-R24D123",
    authority_prefix="r24d123",
    source_commit="71d4ed13021e5d1274fd0918aa6902089676a831",
    source_subject=("[recovery/core] Freeze R123: version bounded raise-body speed"),
    closure_relative_path=(
        "sdk/recovery/r24d123_godot_jolt_raise_body_speed_controller_"
        "zero_world_qualification_closure_v1.json"
    ),
    closure_schema=(
        "sporespore_qsdk_r24d123_godot_jolt_raise_body_speed_controller_"
        "zero_world_qualification_closure_v1"
    ),
    qualified_status=(
        "closed_complete_zero_world_versioned_twenty_two_rad_s_raise_body_speed_"
        "controller_qualified_successor_physical_declaration_required"
    ),
    closure_authority_mode=(
        "closed_complete_zero_world_versioned_raise_body_speed_qualification"
    ),
    predecessor_status=(
        "closed_zero_world_raise_body_post_solver_load_transfer_diagnosis_"
        "twenty_two_rad_s_bounded_successor_selected"
    ),
    attempt_schema=(
        "sporespore_qsdk_r24d123_godot_jolt_raise_body_speed_controller_"
        "zero_world_attempt_v1"
    ),
    receipt_schema=(
        "sporespore_qsdk_r24d123_godot_jolt_raise_body_speed_controller_"
        "zero_world_receipt_v1"
    ),
    qualification_directory_prefix=(
        "qsdk-r24d123-godot-jolt-raise-body-speed-controller-qualification-"
    ),
    source_audit_marker=(
        "QSDK_R24D123_GODOT_JOLT_RAISE_BODY_SPEED_CONTROLLER_SOURCE_PASS"
    ),
    native_zero_world_marker=("SPORESPORE_GODOT_R24D123_RAISE_BODY_SPEED_ZERO_WORLD"),
    source_inventory_count=32,
    authored_source_path_count=16,
    prospective_status=(
        "prospective_zero_world_versioned_raise_body_speed_"
        "implementation_qualification_pending"
    ),
    change_kind="raise_body_maximum_target_speed",
    historical_controller_id="sporespore_exact_s169_prone_to_standing_controller_v4",
    successor_controller_id="sporespore_exact_s169_prone_to_standing_controller_v5",
    historical_profile_sha256=(
        "sha256:2e9f4f5720aec96b28552a04c8f1b6bbfeb3b01eaceac76834b450cb0d9b4900"
    ),
    successor_profile_sha256=(
        "sha256:fe6beb259550c06e137fc89a5e752d2cfc088edd5f8136cd944c5776a4c34909"
    ),
    historical_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
    ),
    successor_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
    ),
    changed_indices=tuple(range(24)),
    historical_regression_receipt_field="historical_v1_v4_regression_passed",
    historical_regression_qualification_field="historical_v1_v4_regression_count",
    preserved_receipt_field="non_speed_command_fields_identical",
    preflight_schema="sporespore_versioned_recovery_controller_parameter_preflight_v2",
    core_runtime_sha256=(
        "sha256:1b08e0e8c06295a4d3ca1b026f5bde15e2fa8cbb5b32f7ebca433bf2a0a879b5"
    ),
    qualified_claim_field=(
        "versioned_twenty_two_rad_s_raise_body_speed_controller_mechanics_qualified"
    ),
    adequacy_field=(
        "qualification_adequate_for_exact_twenty_two_rad_s_raise_body_speed_"
        "version_and_production_route"
    ),
    decision_result=(
        "qualified_exact_versioned_twenty_two_rad_s_raise_body_speed_controller_route"
    ),
    next_gate_id="r24d124",
    next_declaration_required_field="r24d124_distinct_physical_declaration_required",
    historical_maximum_target_speed_rad_s=8.0,
    successor_maximum_target_speed_rad_s=22.0,
    raise_body_phase_steps=(0, 180, 360),
    historical_raise_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
        "sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
        "sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
    ),
    successor_raise_command_sha256=(
        "sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
        "sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
        "sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
    ),
    command_mutation_refusal_count=2,
    historical_preservation_contract_field="historical_v1_v4_preserved",
    additional_checkout_only_paths=(
        "tests/helpers/versioned_recovery_raise_body_speed_zero_world.gd",
        "tests/test_sdk_qsdk_r24d123_godot_raise_body_speed_controller_zero_world.gd",
    ),
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
