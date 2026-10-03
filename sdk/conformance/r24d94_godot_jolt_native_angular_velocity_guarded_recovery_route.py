#!/usr/bin/env python3
"""Compact R94 source audit and zero-world guarded-route preflight."""

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
    load,
    require,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_zero_world_qualification_closure_v1.json"
)
R93_CLOSURE = ROOT / (
    "sdk/recovery/r24d93_godot_jolt_native_engine_health_"
    "zero_world_qualification_closure_v1.json"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
WORKER = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
ZERO_WORKER = "tests/test_sdk_godot_jolt_native_angular_velocity_guard_zero_world.gd"
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_zero_world_qualification.ps1"
)
SOURCE_MARKER = "QSDK_R24D94_GODOT_JOLT_GUARDED_RECOVERY_ROUTE_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D94_GUARDED_RECOVERY_ROUTE_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d94_guarded_recovery_route_runtime_identity_v1"
)
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_zero_world_qualification_closure_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_guarded_recovery_production_route_complete_zero_world_"
    "qualification_required_physics_blocked"
)
ACTUATOR_MODE = "force_based_native_angular_velocity_guarded_v1"
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d94_source_measured_native_angular_velocity_guarded_"
    "joint_impulse_v1"
)
WORK_MAPPING_ID = (
    "godot_jolt_r24d94_guarded_centered_source_measured_joint_work_v1"
)


def _validate_predecessor(contract: dict[str, Any]) -> dict[str, Any]:
    predecessor = controls.validate_bound_predecessor(ROOT, contract, R93_CLOSURE)
    verify_exact_paths(
        predecessor,
        {
            "gate_id": "QSDK-R24D93",
            "closure_status": (
                "closed_complete_zero_world_native_engine_health_"
                "qualification_passed_no_physical_question_r24d94_required"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "source.commit": "c2a075639ae02e10490f899247d122f70b4cfbef",
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.shared_engine_diagnostic_invariant_qualified": True,
            "decision.complete_body_angular_velocity_limit_invariants_qualified": True,
            "decision.physical_question_declared": False,
            "decision.physical_execution_authorized": False,
            "decision.prone_to_standing_claimed": False,
            "next_boundary.gate_id": "QSDK-R24D94",
        },
        "R93",
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
            "controlled_change.r93_native_engine_health_closure_bound": True,
            "controlled_change.r92_result_remains_consumed_and_unchanged": True,
            "controlled_change.source_measured_native_angular_velocity_guard_added": True,
            "controlled_change.equal_and_opposite_pair_scale_projection_added": True,
            "controlled_change.ordered_initial_and_immediate_native_readbacks_added": True,
            "controlled_change.actual_production_route_selected": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.effective_jolt_angular_velocity_limit_changed": False,
            "guard_provenance.relative_headroom": 0.0001220703125,
            "guard_provenance.guard_limit_rad_s": 47.11813735961914,
            "guard_provenance.empirical_threshold_count": 0,
            "complete_zero_world_gate.r93_closure_binding_count": 1,
            "complete_zero_world_gate.r93_closure_audit_reexecution_count": 0,
            "complete_zero_world_gate.native_guard_positive_case_count": 5,
            "complete_zero_world_gate.native_guard_forced_failure_case_count": 13,
            "physical_runner.actuator_mode": ACTUATOR_MODE,
            "claim_boundary.r93_native_engine_health_zero_world_qualified": True,
            "claim_boundary.r94_guard_implemented": True,
            "claim_boundary.r94_guard_zero_world_qualified": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CONTRACT",
    )
    controls.validate_two_step_route_declaration(
        contract,
        "QSDK-R24D94",
        question_expected={
            "validated_command_count": 8,
            "expected_host_write_count": 16,
            "expected_host_readback_count": 8,
            "expected_body_impulse_write_count": 16,
            "expected_hard_constraint_motor_disabled_count": 8,
            "expected_hard_constraint_motor_target_write_count": 0,
            "expected_native_angular_velocity_initial_readback_count": 9,
            "expected_native_angular_velocity_post_application_readback_count": 16,
            "expected_native_angular_velocity_total_readback_count": 25,
            "all_immediate_native_readbacks_inside_guard_required": True,
            "guard_engagement_required": False,
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
        gate_id="QSDK-R24D94",
    )

    marker_paths = (
        WORLD,
        ROUTE,
        SUPERVISOR,
        WORKER,
        ZERO_WORKER,
        PHYSICAL_RUNNER.relative_to(ROOT).as_posix(),
        QUALIFICATION_RUNNER,
    )
    bound = {path: source_bytes(ROOT, source_commit, path) for path in marker_paths}
    verify_bound_source_markers(
        bound,
        {
            WORLD: (
                ACTUATOR_MAPPING_ID,
                WORK_MAPPING_ID,
                "native_angular_velocity_guard_limit_projection_v1",
                "native_angular_velocity_guard_pair_projection_v1",
                "native_angular_velocity_guard_readback_receipt_v1",
                "guarded_force_based_joint_work_projection_v1",
            ),
            ROUTE: (
                "apply_behavior_control_force_based_guarded_v3",
                "PhysicsServer3D.body_get_state",
                '"native_angular_velocity_total_readback_count": completed_native_readback_count',
                '"all_immediate_native_readbacks_inside_guard": true',
            ),
            SUPERVISOR: (
                '"force_based_native_angular_velocity_guarded_v1"',
                "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
                "raw.actuator_mode -ceq $actuatorModeValue",
                "qualified_physical_source_drift",
            ),
            WORKER: (
                "ACTUATOR_MODE_FORCE_BASED_GUARDED",
                "apply_behavior_control_force_based_guarded_v3",
                'application.get("native_angular_velocity_total_readback_count", -1)',
                'application.get("all_immediate_native_readbacks_inside_guard", false)',
            ),
            ZERO_WORKER: (
                "SPORESPORE_GODOT_JOLT_NATIVE_ANGULAR_VELOCITY_GUARD_ZERO_WORLD ",
                '"positive_case_count": 5',
                '"forced_failure_case_count": rejected.size()',
                '"saturation_guard_engaged": true',
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D94"',
                'ActuatorMode = "force_based_native_angular_velocity_guarded_v1"',
                "MaximumOuterSolverSteps = 2",
                "QualifiedPhysicalPaths",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D94"',
                "NativeZeroWorldScriptRelativePath",
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
        },
        "SOURCE_MARKERS",
    )

    counts = controls.validate_route_source_populations(ROOT, contract)
    verify_exact_paths(
        counts,
        {
            "current_zero_world_worker_count": 1,
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "COUNTS",
    )

    live_expected: dict[str, Any] = {
        "r24d94_question_class_declared": True,
        "r24d94_question_class": "development",
        "r24d94_physical_question_declared": True,
        "r24d94_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d94_source_status": PROSPECTIVE_STATUS,
        "r24d94_r93_native_engine_health_closure_bound": True,
        "r24d94_guarded_actuator_mode_selected": True,
        "r24d94_smallest_coverage_adequate_route_ghost_required": True,
        "r24d94_full_seeded_ghost_required": False,
        "r24d94_additional_seed_required": False,
        "r24d94_zero_world_qualification_pending": True,
        "r24d94_zero_world_qualified": False,
        "physical_execution_blocked_pending_r24d94_declaration": False,
        "physical_execution_blocked_until_r24d94_zero_world_qualification": True,
    }
    if published:
        live_expected.update(
            {
                "r24d94_source_commit": source_commit,
                "r24d94_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d94_official_qualification_attempt_count": 1,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d94_contract_path",
        expected=live_expected,
        prefix="LIVE_R94",
    )
    return contract, counts, published


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    runtime_identity = controls.run_route_runtime_identity(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        gate_id="QSDK-R24D94",
        schema=RUNTIME_IDENTITY_SCHEMA,
        contract=contract,
        worker_relative_path=WORKER,
        actuator_mode=ACTUATOR_MODE,
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D94"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D94",
        "sporespore_qsdk_r24d94_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d94_route_preflight_v1",
        "gate_id": "QSDK-R24D94",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "native_guard_positive_case_count": 5,
        "native_guard_forced_failure_case_count": 13,
        "r93_closure_raw_sha256": contract["bound_predecessors"][0]["raw_sha256"],
        "r93_closure_audit_reexecution_count": 0,
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
                    "gate_id": "QSDK-R24D94",
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
        print(f"QSDK_R24D94_GUARDED_RECOVERY_ROUTE_FAIL:{error}", file=sys.stderr)
        raise SystemExit(1) from error
