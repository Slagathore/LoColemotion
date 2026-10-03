#!/usr/bin/env python3
"""Compact R88 source audit and zero-world production-route preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    require,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CONTRACT = ROOT / (
    "sdk/recovery/"
    "r24d88_godot_force_based_recovery_production_route_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d88_godot_force_based_recovery_production_route_"
    "zero_world_qualification_closure_v1.json"
)
R87_CLOSURE = ROOT / (
    "sdk/recovery/r24d87_godot_force_based_recovery_actuator_"
    "zero_world_qualification_closure_v1.json"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
WORKER = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d88_godot_force_based_recovery_production_route.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d88_godot_force_based_recovery_production_route_"
    "zero_world_qualification.ps1"
)
SOURCE_MARKER = (
    "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_PRODUCTION_ROUTE_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D88_FORCE_BASED_RECOVERY_ROUTE_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d88_force_based_recovery_route_runtime_identity_v1"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d88_godot_force_based_recovery_"
    "production_route_contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d88_godot_force_based_recovery_production_route_"
    "zero_world_qualification_closure_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_force_based_recovery_production_route_complete_zero_world_"
    "qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_force_based_recovery_production_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d87_source_measured_force_based_joint_impulse_v1"
)
WORK_MAPPING_ID = "godot_jolt_r24d87_centered_source_measured_joint_work_v1"


def _validate_predecessor(contract: dict[str, Any]) -> dict[str, Any]:
    predecessor = controls.validate_bound_predecessor(ROOT, contract, R87_CLOSURE)
    verify_exact_paths(
        predecessor,
        {
            "gate_id": "QSDK-R24D87",
            "closure_status": (
                "closed_complete_zero_world_force_based_recovery_actuator_"
                "mapping_qualified_physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "source.commit": "b77d1aa0261177ffff8a9ffbde8391f0dc0d6ab1",
            "qualification.ok": True,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.r87_mapping_implemented": True,
            "decision.r87_zero_world_qualified": True,
            "decision.production_route_constructed_or_stepped": False,
            "decision.physical_execution_authorized": False,
            "decision.prone_to_standing_claimed": False,
            "next_boundary.gate_id": "QSDK-R24D88",
        },
        "R87",
    )
    return predecessor


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "controlled_change.r87_force_based_mapping_closure_bound": True,
            "controlled_change.actual_production_world_builder_selected": True,
            "controlled_change.actual_production_route_selected": True,
            "controlled_change.generic_two_step_worker_extended_with_explicit_actuator_mode": True,
            "controlled_change.shared_serial_physical_supervisor_extended_with_explicit_actuator_mode": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.canonical_target_changed": False,
            "controlled_change.pose_ramp_or_timeout_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.published_actuator_cap_changed": False,
            "controlled_change.native_world_builder_changed_from_r87": False,
            "controlled_change.native_route_mapping_changed_from_r87": False,
            "controlled_change.force_based_work_mapping_changed_from_r87": False,
            "complete_zero_world_gate.r87_closure_binding_count": 1,
            "complete_zero_world_gate.r87_closure_audit_reexecution_count": 0,
            "physical_runner.actuator_mode": ACTUATOR_MODE,
            "claim_boundary.r87_force_based_mapping_zero_world_qualified": True,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CONTRACT",
    )
    controls.validate_two_step_route_declaration(
        contract,
        "QSDK-R24D88",
        question_expected={
            "validated_command_count": 8,
            "expected_host_write_count": 16,
            "expected_host_readback_count": 8,
            "expected_body_impulse_write_count": 16,
            "expected_hard_constraint_motor_disabled_count": 8,
            "expected_hard_constraint_motor_target_write_count": 0,
            "in_run_physical_invariant_step_count": 2,
            "all_in_run_physical_invariants_required": True,
            "actuator_mode": ACTUATOR_MODE,
            "actuator_mapping_id": ACTUATOR_MAPPING_ID,
            "work_mapping_id": WORK_MAPPING_ID,
        },
    )
    _validate_predecessor(contract)
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=CLOSURE_SCHEMA,
        gate_id="QSDK-R24D88",
    )

    unchanged_commit = str(contract["unchanged_force_based_mapping_source_commit"])
    for relative in contract["unchanged_force_based_mapping_paths"]:
        exact(
            source_bytes(ROOT, source_commit, relative),
            source_bytes(ROOT, unchanged_commit, relative),
            f"UNCHANGED_R87_MAPPING:{relative}",
        )

    marker_paths = (
        WORLD,
        ROUTE,
        SUPERVISOR,
        WORKER,
        PHYSICAL_RUNNER.relative_to(ROOT).as_posix(),
        QUALIFICATION_RUNNER,
    )
    bound = {path: source_bytes(ROOT, source_commit, path) for path in marker_paths}
    verify_bound_source_markers(
        bound,
        {
            WORLD: (
                "godot_jolt_r24d87_source_measured_force_based_joint_impulse_v1",
                "godot_jolt_r24d87_centered_source_measured_joint_work_v1",
                "force_based_joint_impulse_projection_v1",
                "force_based_joint_work_projection_v1",
            ),
            ROUTE: (
                "apply_behavior_control_force_based_v2",
                "RigidBody3D.apply_torque_impulse",
                '"hard_constraint_motor_target_write_count": 0',
                '"body_impulse_write_count": 16',
            ),
            SUPERVISOR: (
                'ActuatorMode = "legacy_velocity_motor_v1"',
                "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
                "raw.actuator_mode -ceq $actuatorModeValue",
                "qualified_physical_source_drift",
            ),
            WORKER: (
                "const ACTUATOR_MODE_FORCE_BASED := \"force_based_joint_impulse_v1\"",
                "apply_behavior_control_force_based_v2",
                '"body_impulse_write_count": int(',
                "int(report[\"body_impulse_write_count\"]) == 16",
                '"actuator_mode": _actuator_mode',
                '"all_in_run_physical_invariants_passed": true',
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D88"',
                'ActuatorMode = "force_based_joint_impulse_v1"',
                "MaximumOuterSolverSteps = 2",
                "QualifiedPhysicalPaths",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D88"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
        },
        "SOURCE_MARKERS",
    )

    counts = controls.validate_route_source_populations(ROOT, contract)

    live_expected: dict[str, Any] = {
        "r24d88_question_class": "development",
        "r24d88_physical_question_declared": True,
        "r24d88_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d88_r87_force_based_mapping_closure_bound": True,
        "r24d88_actual_production_route_selected": True,
        "r24d88_force_based_actuator_mode_selected": True,
        "r24d88_smallest_coverage_adequate_route_ghost_required": True,
        "r24d88_full_seeded_ghost_required": False,
        "r24d88_additional_seed_required": False,
    }
    if published:
        live_expected.update(
            {
                "r24d88_source_commit": source_commit,
                "r24d88_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d88_official_qualification_attempt_count": 1,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d88_contract_path",
        expected=live_expected,
        prefix="LIVE_R88",
    )
    return contract, counts, published


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    runtime_identity = controls.run_route_runtime_identity(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        gate_id="QSDK-R24D88",
        schema=RUNTIME_IDENTITY_SCHEMA,
        contract=contract,
        worker_relative_path=WORKER,
        actuator_mode=ACTUATOR_MODE,
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D88"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D88",
        "sporespore_qsdk_r24d88_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d88_route_preflight_v1",
        "gate_id": "QSDK-R24D88",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "r87_closure_raw_sha256": contract["bound_predecessors"][0]["raw_sha256"],
        "r87_closure_audit_reexecution_count": 0,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "forced_supervisor_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    contract, counts, published = validate_sources()
    if args.core_library is None:
        print(
            SOURCE_MARKER,
            json.dumps(
                {
                    "gate_id": "QSDK-R24D88",
                    "ok": True,
                    "published": published,
                    **counts,
                },
                sort_keys=True,
            ),
        )
        return 0
    require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
    print(json.dumps(run_preflight(contract, counts), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        ClosureAuditError,
        controls.ControlError,
        AssertionError,
        KeyError,
        OSError,
        TypeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_ROUTE_FAIL:{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
