#!/usr/bin/env python3
"""Bind R120 identities to the reusable versioned-controller closure audit."""

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
    "sdk/conformance/r24d120_godot_jolt_raise_body_speed_controller_"
    "qualification_closure.py"
)
MARKER = "QSDK_R24D120_GODOT_JOLT_RAISE_BODY_SPEED_QUALIFICATION_CLOSURE_PASS"
SPEC = VersionedRecoveryControllerQualificationSpec(
    gate_id="QSDK-R24D120",
    authority_prefix="r24d120",
    source_commit="90f3e383f8c06325206928bb93882b488280cf1f",
    source_subject=("[recovery/core] Freeze R120: version raise-body speed continuity"),
    closure_relative_path=(
        "sdk/recovery/r24d120_godot_jolt_raise_body_speed_controller_"
        "zero_world_qualification_closure_v1.json"
    ),
    closure_schema=(
        "sporespore_qsdk_r24d120_godot_jolt_raise_body_speed_controller_"
        "zero_world_qualification_closure_v1"
    ),
    qualified_status=(
        "closed_complete_zero_world_versioned_raise_body_speed_controller_"
        "qualified_successor_physical_declaration_required"
    ),
    closure_authority_mode=(
        "closed_complete_zero_world_versioned_raise_body_speed_qualification"
    ),
    predecessor_status=(
        "closed_zero_world_raise_body_speed_discontinuity_and_nonfoot_load_path_"
        "diagnosis_eight_rad_s_continuation_successor_selected"
    ),
    attempt_schema=(
        "sporespore_qsdk_r24d120_godot_jolt_raise_body_speed_controller_"
        "zero_world_attempt_v1"
    ),
    receipt_schema=(
        "sporespore_qsdk_r24d120_godot_jolt_raise_body_speed_controller_"
        "zero_world_receipt_v1"
    ),
    qualification_directory_prefix=(
        "qsdk-r24d120-godot-jolt-raise-body-speed-controller-qualification-"
    ),
    source_audit_marker=(
        "QSDK_R24D120_GODOT_JOLT_RAISE_BODY_SPEED_CONTROLLER_SOURCE_PASS"
    ),
    native_zero_world_marker=("SPORESPORE_GODOT_R24D120_RAISE_BODY_SPEED_ZERO_WORLD"),
    source_inventory_count=29,
    authored_source_path_count=15,
    prospective_status=(
        "prospective_zero_world_versioned_raise_body_speed_"
        "implementation_qualification_pending"
    ),
    change_kind="raise_body_maximum_target_speed",
    historical_controller_id="sporespore_exact_s169_prone_to_standing_controller_v3",
    successor_controller_id="sporespore_exact_s169_prone_to_standing_controller_v4",
    historical_profile_sha256=(
        "sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
    ),
    successor_profile_sha256=(
        "sha256:2e9f4f5720aec96b28552a04c8f1b6bbfeb3b01eaceac76834b450cb0d9b4900"
    ),
    historical_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
    ),
    successor_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
    ),
    changed_indices=tuple(range(24)),
    historical_regression_receipt_field="historical_v1_v3_regression_passed",
    historical_regression_qualification_field="historical_v1_v3_regression_count",
    preserved_receipt_field="non_speed_command_fields_identical",
    preflight_schema="sporespore_versioned_recovery_controller_parameter_preflight_v2",
    core_runtime_sha256=(
        "sha256:57f67b38f7329fdda23f69a7d33239d87374f18c008a9537571c90f25f5f52e1"
    ),
    qualified_claim_field="versioned_raise_body_speed_controller_mechanics_qualified",
    adequacy_field=(
        "qualification_adequate_for_exact_raise_body_speed_version_and_production_route"
    ),
    decision_result=(
        "qualified_exact_versioned_eight_rad_s_raise_body_speed_controller_route"
    ),
    next_gate_id="r24d121",
    next_declaration_required_field="r24d121_distinct_physical_declaration_required",
    historical_maximum_target_speed_rad_s=0.75,
    successor_maximum_target_speed_rad_s=8.0,
    raise_body_phase_steps=(0, 180, 360),
    historical_raise_command_sha256=(
        "sha256:c9b643dc31923b9c59389d21a3750e2cd6c800002b9b30faf7631d47823a4b2d",
        "sha256:32727a1340c791d9c2224c633908018ce113ddef686f0dc755a894b9d168f38f",
        "sha256:c37b949e24558a92b1656b7b773d63e294152264b35c9f7623674a1eb202e545",
    ),
    successor_raise_command_sha256=(
        "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
        "sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
        "sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
    ),
    command_mutation_refusal_count=2,
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
