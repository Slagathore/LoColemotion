#!/usr/bin/env python3
"""Bind R127 identities to the reusable controller-qualification closure audit."""

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
    "sdk/conformance/r24d127_godot_jolt_solver_coupled_controller_"
    "qualification_closure.py"
)
MARKER = "QSDK_R24D127_GODOT_JOLT_SOLVER_COUPLED_CONTROLLER_QUALIFICATION_CLOSURE_PASS"
SUPPORT_COMMAND_SHA256 = (
    "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
)
RAISE_COMMAND_SHA256 = (
    "sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
    "sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
    "sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
)

SPEC = VersionedRecoveryControllerQualificationSpec(
    gate_id="QSDK-R24D127",
    authority_prefix="r24d127",
    source_commit="aa61fc2cb1afc2b4efb11730702a1bf53178e1f1",
    source_subject=(
        "[recovery/godot] Freeze R127: bind solver-coupled controller realization"
    ),
    closure_relative_path=(
        "sdk/recovery/r24d127_godot_jolt_solver_coupled_controller_"
        "zero_world_qualification_closure_v1.json"
    ),
    closure_schema=(
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_"
        "zero_world_qualification_closure_v1"
    ),
    qualified_status=(
        "closed_complete_zero_world_versioned_solver_coupled_realization_"
        "qualified_distinct_physical_declaration_required"
    ),
    closure_authority_mode=(
        "closed_complete_zero_world_versioned_solver_coupled_realization_qualification"
    ),
    predecessor_status=(
        "closed_complete_zero_world_incomplete_energy_authority_development_"
        "progression_qualified_successor_declaration_required"
    ),
    attempt_schema=(
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_"
        "zero_world_attempt_v1"
    ),
    receipt_schema=(
        "sporespore_qsdk_r24d127_godot_jolt_solver_coupled_controller_"
        "zero_world_receipt_v1"
    ),
    qualification_directory_prefix=(
        "qsdk-r24d127-godot-jolt-solver-coupled-controller-qualification-"
    ),
    source_audit_marker=(
        "QSDK_R24D127_GODOT_JOLT_SOLVER_COUPLED_CONTROLLER_SOURCE_PASS"
    ),
    native_zero_world_marker=(
        "SPORESPORE_GODOT_R24D127_SOLVER_COUPLED_CONTROLLER_ZERO_WORLD"
    ),
    source_inventory_count=37,
    authored_source_path_count=17,
    prospective_status=(
        "prospective_zero_world_versioned_solver_coupled_realization_"
        "implementation_qualification_pending"
    ),
    change_kind="actuation_realization",
    historical_controller_id="sporespore_exact_s169_prone_to_standing_controller_v5",
    successor_controller_id="sporespore_exact_s169_prone_to_standing_controller_v6",
    historical_profile_sha256=(
        "sha256:fe6beb259550c06e137fc89a5e752d2cfc088edd5f8136cd944c5776a4c34909"
    ),
    successor_profile_sha256=(
        "sha256:a764ea9f96bc9dbb00d594d87603aa87a95bf7a43c03085520952138f3989d33"
    ),
    historical_command_sha256=SUPPORT_COMMAND_SHA256,
    successor_command_sha256=SUPPORT_COMMAND_SHA256,
    changed_indices=(),
    historical_regression_receipt_field="historical_v1_v5_regression_passed",
    historical_regression_qualification_field="historical_v1_v5_regression_count",
    preserved_receipt_field="portable_commands_preserved",
    preflight_schema="sporespore_versioned_recovery_controller_realization_preflight_v1",
    core_runtime_sha256=(
        "sha256:06f6c25ddcb3ca5855e28da6e72d1a976978e96304dfa8818bd23d08b8356022"
    ),
    qualified_claim_field=(
        "versioned_solver_coupled_controller_realization_mechanics_qualified"
    ),
    adequacy_field=(
        "qualification_adequate_for_exact_solver_coupled_controller_"
        "realization_and_production_route"
    ),
    decision_result="qualified_exact_versioned_solver_coupled_controller_realization_route",
    next_gate_id="r24d128",
    next_declaration_required_field="r24d128_distinct_physical_declaration_required",
    raise_body_phase_steps=(0, 180, 360),
    historical_raise_command_sha256=RAISE_COMMAND_SHA256,
    successor_raise_command_sha256=RAISE_COMMAND_SHA256,
    command_mutation_refusal_count=2,
    historical_preservation_contract_field="historical_v1_v5_preserved",
    historical_actuator_mode=(
        "force_based_order_neutral_joint_space_effective_inertia_native_"
        "angular_velocity_guarded_v3"
    ),
    successor_actuator_mode="solver_coupled_native_constraint_motor_v1",
    historical_actuation_realization_id=(
        "godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_"
        "population_guarded_joint_impulse_v1"
    ),
    successor_actuation_realization_id=(
        "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1"
    ),
    realization_mismatch_refusal_count=2,
    production_worker_pairing_control_count=4,
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
