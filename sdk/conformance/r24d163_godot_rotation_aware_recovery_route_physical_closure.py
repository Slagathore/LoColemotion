#!/usr/bin/env python3
"""Audit the one consumed R163 rotation-aware two-step route ghost."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    core_canonical_bytes,
    exact,
    verify_exact_paths,
)
from sdk.conformance.finite_godot_recovery_route_physical_closure import (  # noqa: E402
    ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
    validate_closure,
)


CLOSURE_STATUS = (
    "closed_consumed_valid_complete_rotation_aware_recovery_ledger_route_ghost_"
    "passed_distinct_behavior_successor_required"
)
CLOSURE_PATH = (
    "sdk/recovery/r24d163_godot_rotation_aware_recovery_route_ghost_closure_v1.json"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d163_godot_rotation_aware_recovery_route_ghost_closure_v1"
)
PROFILE_BINDINGS = {
    "recovery_controller_id": (
        "sporespore_exact_s169_prone_to_standing_controller_v6"
    ),
    "application_schema": (
        "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_"
        "energy_command_application_receipt_v1"
    ),
    "intermediate_application_schema": (
        "sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_"
        "command_application_receipt_v1"
    ),
    "predecessor_application_schema": (
        "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_"
        "command_application_receipt_v1"
    ),
    "native_application_schema": (
        "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_"
        "application_receipt_v1"
    ),
    "predecessor_native_application_schema": (
        "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_"
        "application_receipt_v1"
    ),
    "native_source_trace_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_native_"
        "source_trace_v1"
    ),
    "application_provenance_profile_id": (
        "godot_jolt_r24d152_route_aware_discrete_staging_application_"
        "provenance_v1"
    ),
    "complete_energy_authority_profile_id": (
        "godot_jolt_r24d151_commissioned_discrete_staging_complete_energy_"
        "partition_authority_v1"
    ),
    "actuation_realization_id": (
        "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1"
    ),
    "application_mutation_semantics_id": (
        "godot_jolt_r24d129_solver_coupled_constraint_configuration_mutation_v1"
    ),
    "energy_route_id": (
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_"
        "recovery_observation_v3_route_v1"
    ),
    "energy_mapping_profile_id": (
        "godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_"
        "mapping_v1"
    ),
    "predecessor_energy_route_id": (
        "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_"
        "recovery_observation_v3_route_v1"
    ),
    "predecessor_energy_mapping_profile_id": (
        "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_"
        "mapping_v1"
    ),
    "source_receipt_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_"
        "source_receipt_v1"
    ),
    "source_component_receipts_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_"
        "source_component_receipts_v1"
    ),
    "rotation_aware_predecessor_source_receipt_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_"
        "energy_source_receipt_v1"
    ),
    "rotation_aware_predecessor_source_component_receipts_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_source_"
        "component_receipts_v1"
    ),
    "native_bound_measurement_schema": (
        "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_"
        "bound_measurement_v1"
    ),
    "native_measurement_schema": (
        "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_"
        "measurement_v1"
    ),
    "step_mapping_schema": (
        "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_step_"
        "mapping_v1"
    ),
    "partition_contract_schema": (
        "sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_"
        "energy_partition_contract_v1"
    ),
    "partition_numerical_term_count": 14,
    "recovery_energy_ledger_profile_id": (
        "godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
    ),
    "solver_energy_consumer_contract_schema": (
        "sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2"
    ),
    "solver_energy_telemetry_schema": (
        "sporespore.godot_jolt_solver_energy_exchange_telemetry.v2"
    ),
    "solver_energy_telemetry_profile_id": (
        "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6"
    ),
    "boundary_capture_schema": (
        "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_body_boundary_"
        "capture_v1"
    ),
    "observer_schema": (
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_exchange_v1"
    ),
    "accumulator_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_accumulator_v1"
    ),
    "mapping_receipt_schema": (
        "sporespore_qsdk_r24d148_godot_discrete_staging_energy_mapping_"
        "receipt_v1"
    ),
    "discrete_staging_rule_id": (
        "godot_jolt_gravity_force_and_position_staging_exchange_v1"
    ),
    "live_boundary_transport_id": (
        "godot_jolt_r24d149_pre_callback_to_post_solver_body_boundary_"
        "transport_v1"
    ),
    "native_world_route_id": (
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_"
        "native_world_v1"
    ),
    "partition_rule_id": (
        "godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_"
        "partition_v1"
    ),
}


def main() -> int:
    try:
        exact(
            core_canonical_bytes(
                {
                    "negative_exponent": -3.725290298461914e-8,
                    "small_positive": 1.4901161193847656e-8,
                }
            ),
            (
                b'{"negative_exponent":-3.7252902984619e-8,'
                b'"small_positive":1.4901161193848e-8}'
            ),
            "R163_CORE_CANONICAL_RENDERING",
        )
        closure = validate_closure(
            root=ROOT,
            closure_relative_path=CLOSURE_PATH,
            closure_schema=CLOSURE_SCHEMA,
            gate_id="QSDK-R24D163",
            closure_status=CLOSURE_STATUS,
            invocation_source_commit=(
                "283efa814e9272f24ae4c6875d24e715a5d5a650"
            ),
            schemas={
                "attempt": (
                    "sporespore_qsdk_r24d163_rotation_aware_recovery_route_"
                    "attempt_v1"
                ),
                "raw": (
                    "sporespore_qsdk_r24d163_godot_rotation_aware_recovery_"
                    "route_raw_v1"
                ),
                "terminal": (
                    "sporespore_qsdk_r24d163_rotation_aware_recovery_route_"
                    "terminal_v1"
                ),
            },
            actuator_mode="solver_coupled_native_constraint_motor_v1",
            actuator_mapping_id=(
                "godot_jolt_r24d144_solver_coupled_native_constraint_motor_"
                "mapping_v1"
            ),
            work_mapping_id=(
                "godot_jolt_r24d144_current_step_native_hinge_motor_work_"
                "mapping_v1"
            ),
            projection_key="",
            projection_schema="",
            qualified_source_commit=(
                "26a0fab98337f2cf3afe117e67047b84a2a7d28a"
            ),
            qualification_closure_relative_path=(
                "sdk/recovery/r24d163_godot_rotation_aware_recovery_route_"
                "zero_world_qualification_closure_v1.json"
            ),
            qualified_physical_path_count=69,
            live_prefix="r24d163",
            next_gate_id="QSDK-R24D164",
            next_live_prefix="r24d164",
            route_realization_profile=(
                ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE
            ),
            profile_bindings=PROFILE_BINDINGS,
        )
        verify_exact_paths(
            closure,
            {
                "audit_resolution.classification": (
                    "independent_closure_audit_numeric_rendering_and_assertion_"
                    "composition_defects_repaired"
                ),
                "audit_resolution.initial_refusal_code": (
                    "ROUTE_STAGING_ROTATION_ORIGINAL_COMPONENTS_SHA"
                ),
                "audit_resolution.authoritative_core_receipt_hashes_passed": True,
                "audit_resolution.retained_evidence_changed": False,
                "audit_resolution.physical_result_rewritten": False,
                "audit_resolution.behavior_evaluator_changed": False,
                "audit_resolution.threshold_or_margin_changed": False,
                "audit_resolution.physical_rerun_performed": False,
                "audit_resolution.model_construction_count": 0,
                "audit_resolution.world_attempt_count": 0,
                "audit_resolution.world_build_count": 0,
                "audit_resolution.solver_step_count": 0,
            },
            "R163_AUDIT_RESOLUTION",
        )
        print(
            "QSDK_R24D163_ROTATION_AWARE_RECOVERY_ROUTE_PHYSICAL_CLOSURE_PASS",
            json.dumps(
                {
                    "gate_id": closure["gate_id"],
                    "ok": True,
                    "status": closure["closure_status"],
                    "attempt_id": closure["physical_attempt"]["attempt_id"],
                    "model_construction_count": 1,
                    "world_build_count": 1,
                    "solver_step_count": 2,
                    "same_identity_rerun_permitted": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        AssertionError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(
            "QSDK_R24D163_ROTATION_AWARE_RECOVERY_ROUTE_PHYSICAL_CLOSURE_FAIL:"
            f"{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
