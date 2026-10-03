#!/usr/bin/env python3
"""R104 binding for the shared two-step Godot/Jolt route qualification."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import (  # noqa: E402
    godot_recovery_route_zero_world_controls as controls,
)
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    complete_in_run_physical_invariant_projection,
    load,
    require,
    resolve_prospective_source_freeze,
    sha256,
    source_bytes,
    verify_bound_source_markers,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_supervised_bounded_ghost_attempt,
    verify_two_step_native_portable_route,
)

GATE_ID = "QSDK-R24D104"
CONTRACT = ROOT / (
    "sdk/recovery/r24d104_godot_jolt_order_neutral_population_route_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d104_godot_jolt_order_neutral_population_route_"
    "zero_world_qualification_closure_v1.json"
)
PHYSICAL_CLOSURE = ROOT / (
    "sdk/recovery/r24d104_godot_jolt_order_neutral_population_route_"
    "ghost_positive_closure_v1.json"
)
R103_CLOSURE = ROOT / (
    "sdk/recovery/r24d103_godot_jolt_order_neutral_population_projection_"
    "zero_world_qualification_closure_v1.json"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
PRODUCTION_WORKER = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
ZERO_WORKER = ROOT / (
    "tests/test_sdk_godot_r24d103_order_neutral_population_projection_zero_world.gd"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d104_godot_jolt_order_neutral_population_route.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d104_godot_jolt_order_neutral_population_route_"
    "zero_world_qualification.ps1"
)
SOURCE_MARKER = "QSDK_R24D104_GODOT_JOLT_ORDER_NEUTRAL_ROUTE_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D104_ORDER_NEUTRAL_ROUTE_SUPERVISOR "
ZERO_MARKER = "SPORESPORE_GODOT_R24D103_ORDER_NEUTRAL_POPULATION_ZERO_WORLD "
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d104_godot_jolt_order_neutral_population_route_" "contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d104_godot_jolt_order_neutral_population_route_"
    "zero_world_qualification_closure_v1"
)
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d104_order_neutral_population_route_runtime_identity_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_order_neutral_population_route_complete_zero_world_"
    "qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_order_neutral_population_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
PHYSICAL_CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d104_godot_jolt_order_neutral_population_route_"
    "ghost_positive_closure_v1"
)
PHYSICAL_CLOSED_STATUS = (
    "closed_valid_complete_order_neutral_population_recovery_production_route_"
    "ghost_passed_distinct_r24d105_behavior_successor_required"
)
PHYSICAL_SOURCE_COMMIT = "18b47ee5c70f3f4508f4eebe68926aa00fb73cbb"
ACTUATOR_MODE = (
    "force_based_order_neutral_population_native_angular_velocity_guarded_v1"
)
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d103_order_neutral_population_guarded_joint_impulse_v1"
)
WORK_MAPPING_ID = (
    "godot_jolt_r24d103_order_neutral_population_guarded_centered_joint_work_v1"
)


def validate_physical_closure() -> dict[str, Any] | None:
    """Verify the consumed two-step result through shared physical mechanics."""

    if not PHYSICAL_CLOSURE.is_file():
        return None
    closure = load(PHYSICAL_CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": PHYSICAL_CLOSURE_SCHEMA,
            "gate_id": GATE_ID,
            "closure_status": PHYSICAL_CLOSED_STATUS,
            "question_class": "development",
            "source.commit": PHYSICAL_SOURCE_COMMIT,
            "authorization_dependency.qualification_closure_raw_sha256": (
                "sha256:572bf3eb3b265964d2ce3c802b5d0d1189ce484310f12b96e0924db4c3c7a2ba"
            ),
            "decision.integration_ghost_passed": True,
            "decision.in_run_physical_invariants_passed": True,
            "decision.native_engine_health_passed": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.recovery_success_established": False,
            "decision.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "PHYSICAL_CLOSURE",
    )
    values = verify_supervised_bounded_ghost_attempt(
        physical=closure["physical_attempt"],
        gate_id=GATE_ID,
        source_commit=PHYSICAL_SOURCE_COMMIT,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d104_route_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d104_godot_jolt_order_neutral_population_"
                "route_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d104_route_terminal_v1",
        },
    )
    raw = values["raw"]
    verify_two_step_native_portable_route(
        raw,
        phase="establish_distal_support",
        joint_count=8,
    )
    verify_exact_paths(
        raw,
        {
            "actuator_mode": ACTUATOR_MODE,
            "actuator_mapping_id": ACTUATOR_MAPPING_ID,
            "work_mapping_id": WORK_MAPPING_ID,
            "host_write_count": 9,
            "body_impulse_write_count": 9,
            "host_readback_count": 8,
            "native_angular_velocity_initial_readback_count": 9,
            "native_angular_velocity_post_application_readback_count": 9,
            "native_angular_velocity_total_readback_count": 18,
            "population_actuator_count": 8,
            "population_body_count": 9,
            "in_run_physical_invariant_step_count": 2,
            "all_in_run_physical_invariants_passed": True,
            "behavior_evaluator_invocation_count": 0,
            "prone_to_standing_claimed": False,
        },
        "PHYSICAL_RAW",
    )
    application = raw["first_step"]["application_intent"]
    verify_exact_paths(
        application,
        {
            "ok": True,
            "validated_command_count": 8,
            "host_write_count": 9,
            "body_impulse_write_count": 9,
            "host_readback_count": 8,
            "order_neutral_population_projection_required": True,
            "aggregate_body_application_required": True,
            "per_actuator_attribution_required": True,
            "input_iteration_order_has_action_authority": False,
            "all_immediate_native_readbacks_inside_guard": True,
            "physics_state_modified": True,
        },
        "PHYSICAL_APPLICATION",
    )
    bodies = application["ordered_body_application_receipts"]
    actuators = application["ordered_receipts"]
    require(len(bodies) == 9 and len(actuators) == 8, "PHYSICAL_RECEIPT_COUNTS")
    require(
        all(row["call_performed"] and row["call_returned"] for row in bodies)
        and sum(int(row["body_impulse_write_count"]) for row in bodies) == 9,
        "PHYSICAL_BODY_APPLICATIONS",
    )
    require(
        all(
            row["ok"]
            and row["source_measurement"]
            and all(
                float(value) == 0.0
                for value in row["pairing_residual_world_nms"].values()
            )
            for row in actuators
        ),
        "PHYSICAL_ACTUATOR_ATTRIBUTION",
    )
    projected = complete_in_run_physical_invariant_projection(raw)
    for key, value in projected.items():
        require(
            closure["in_run_physical_invariants"].get(key) == value,
            f"PHYSICAL_INVARIANT:{key}",
        )
    return closure


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "gate_id": GATE_ID,
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "controlled_change.r24d103_qualified_closure_bound": True,
            "controlled_change.order_neutral_population_projection_changed": False,
            "controlled_change.production_ghost_mode_binding_added": True,
            "controlled_change.production_ghost_receipt_validation_added": True,
            "controlled_change.portable_controller_changed": False,
            "controlled_change.behavior_evaluator_changed": False,
            "complete_zero_world_gate.current_zero_world_worker_count": 1,
            "complete_zero_world_gate.current_positive_case_count": 17,
            "complete_zero_world_gate.current_forced_failure_case_count": 8,
            "physical_runner.actuator_mode": ACTUATOR_MODE,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CONTRACT",
    )
    controls.validate_two_step_route_declaration(
        contract,
        GATE_ID,
        question_expected={
            "validated_command_count": 8,
            "minimum_expected_host_write_count": 1,
            "maximum_expected_host_write_count": 9,
            "expected_host_readback_count": 8,
            "minimum_expected_body_impulse_write_count": 1,
            "maximum_expected_body_impulse_write_count": 9,
            "expected_hard_constraint_motor_disabled_count": 8,
            "expected_hard_constraint_motor_target_write_count": 0,
            "expected_native_angular_velocity_initial_readback_count": 9,
            "expected_native_angular_velocity_post_application_readback_count": 9,
            "expected_native_angular_velocity_total_readback_count": 18,
            "order_neutral_population_projection_required": True,
            "aggregate_body_application_required": True,
            "per_actuator_attribution_required": True,
            "input_iteration_order_has_action_authority": False,
            "in_run_physical_invariant_step_count": 2,
            "all_in_run_physical_invariants_required": True,
            "actuator_mode": ACTUATOR_MODE,
            "actuator_mapping_id": ACTUATOR_MAPPING_ID,
            "work_mapping_id": WORK_MAPPING_ID,
        },
    )
    predecessor = controls.validate_bound_predecessor(ROOT, contract, R103_CLOSURE)
    verify_exact_paths(
        predecessor,
        {
            "schema_version": (
                "sporespore_qsdk_r24d103_godot_jolt_order_neutral_population_"
                "projection_zero_world_qualification_closure_v1"
            ),
            "gate_id": "QSDK-R24D103",
            "status": "closed_passing_zero_world_implementation_qualification",
            "source.qualification_source_freeze_commit": (
                "658ba5c43df9ec716c709f36c3f2c1a526763cc2"
            ),
            "decision.r24d103_zero_world_population_projection_qualified": True,
            "decision.r24d103_same_source_requalification_permitted": False,
            "decision.physical_execution_authorized": False,
            "decision.prone_to_standing_claimed": False,
        },
        "R103_CLOSURE",
    )
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=CLOSURE_SCHEMA,
        gate_id=GATE_ID,
    )
    marker_paths = (
        WORLD,
        ROUTE,
        SUPERVISOR,
        PRODUCTION_WORKER,
        ZERO_WORKER.relative_to(ROOT).as_posix(),
        PHYSICAL_RUNNER.relative_to(ROOT).as_posix(),
        QUALIFICATION_RUNNER,
    )
    bound = {path: source_bytes(ROOT, source_commit, path) for path in marker_paths}
    verify_bound_source_markers(
        bound,
        {
            WORLD: (
                "ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID",
                "order_neutral_population_guard_projection_v1",
            ),
            ROUTE: (
                "apply_behavior_control_force_based_order_neutral_population_guarded_v7",
                "QSDK_R24D103_POPULATION_BODY_WRITE_COUNT_INVALID",
            ),
            SUPERVISOR: (f'"{ACTUATOR_MODE}"', "qualified_physical_source_drift"),
            PRODUCTION_WORKER: (
                "ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED",
                "validate_order_neutral_population_route_application_v1",
                "apply_behavior_control_force_based_order_neutral_population_guarded_v7",
            ),
            ZERO_WORKER.relative_to(ROOT).as_posix(): (
                "route_ghost_receipt_validation_passed",
                "route_ghost_mutation_rejected",
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D104"',
                f'ActuatorMode = "{ACTUATOR_MODE}"',
                "MaximumOuterSolverSteps = 2",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D104"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
        },
        "SOURCE_MARKERS",
    )
    counts = controls.validate_route_source_populations(ROOT, contract)
    policy = contract["critical_path_audit_policy"]
    controls.require_fields(
        counts,
        {
            "source_inventory_count": policy["source_inventory_count"],
            "authored_source_path_count": policy["authored_source_path_count"],
            "qualified_physical_path_count": policy["qualified_physical_path_count"],
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 1,
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "COUNTS",
    )
    physical_closure = validate_physical_closure()
    live_expected: dict[str, Any] = {
        "r24d104_question_class": "development",
        "r24d104_physical_question_declared": True,
        "r24d104_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d104_r103_qualified_closure_bound": True,
        "r24d104_actuator_mode": ACTUATOR_MODE,
        "r24d104_zero_world_worker_count": 1,
        "r24d104_smallest_coverage_adequate_route_ghost_required": True,
        "r24d104_full_seeded_ghost_required": False,
        "r24d104_additional_seed_required": False,
        "physical_execution_blocked_pending_r24d104_declaration": False,
    }
    if physical_closure is not None:
        physical_raw = PHYSICAL_CLOSURE.read_bytes()
        live_expected.update(
            {
                "next_gate_id": "QSDK-R24D105",
                "r24d104_source_status": PHYSICAL_CLOSED_STATUS,
                "r24d104_source_commit": source_commit,
                "r24d104_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d104_official_qualification_attempt_count": 1,
                "r24d104_zero_world_qualification_pending": False,
                "r24d104_zero_world_qualified": True,
                "r24d104_minimal_native_route_ghost_required": False,
                "r24d104_physical_attempt_consumed": True,
                "r24d104_physical_attempt_disposition": (
                    "valid_complete_integration_ghost_positive"
                ),
                "r24d104_ghost_positive_closure_path": (
                    PHYSICAL_CLOSURE.relative_to(ROOT).as_posix()
                ),
                "r24d104_ghost_positive_closure_raw_sha256": sha256(physical_raw),
                "r24d104_ghost_positive_closure_byte_length": len(physical_raw),
                "r24d104_invocation_source_commit": PHYSICAL_SOURCE_COMMIT,
                "r24d104_observed_model_construction_count": 1,
                "r24d104_observed_world_attempt_count": 1,
                "r24d104_observed_world_build_count": 1,
                "r24d104_observed_solver_step_count": 2,
                "r24d104_order_neutral_population_command_application_executed": True,
                "r24d104_shared_post_application_native_readback_executed": True,
                "r24d104_integration_ghost_passed": True,
                "r24d104_in_run_physical_invariants_passed": True,
                "r24d104_native_engine_health_passed": True,
                "r24d104_body_impulse_write_count": 9,
                "r24d104_native_angular_velocity_total_readback_count": 18,
                "r24d104_physical_execution_authorized": False,
                "r24d104_same_identity_rerun_permitted": False,
                "r24d105_distinct_successor_required": True,
                "r24d105_question_class_declared": False,
                "r24d105_physical_execution_authorized": False,
                "physical_execution_blocked_until_r24d104_zero_world_qualification": False,
                "physical_execution_blocked_pending_r24d105_declaration": True,
                "physical_execution_blocked_until_r24d105_zero_world_qualification": True,
            }
        )
    elif published:
        live_expected.update(
            {
                "r24d104_source_status": QUALIFIED_STATUS,
                "r24d104_source_commit": source_commit,
                "r24d104_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d104_official_qualification_attempt_count": 1,
                "r24d104_zero_world_qualification_pending": False,
                "r24d104_zero_world_qualified": True,
                "r24d104_physical_execution_authorized": True,
                "physical_execution_blocked_until_r24d104_zero_world_qualification": False,
            }
        )
    else:
        live_expected.update(
            {
                "r24d104_source_status": PROSPECTIVE_STATUS,
                "r24d104_zero_world_qualification_pending": True,
                "r24d104_zero_world_qualified": False,
                "r24d104_physical_execution_authorized": False,
                "physical_execution_blocked_until_r24d104_zero_world_qualification": True,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d104_contract_path",
        expected=live_expected,
        prefix="LIVE_R104",
    )
    return contract, counts, published


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    worker = controls.run_zero_world_worker_specs(
        ROOT,
        Path(contract["exact_runtime"]["console_path"]),
        (
            {
                "id": "r104_order_neutral_population_route",
                "path": ZERO_WORKER,
                "marker": ZERO_MARKER,
                "expected": {
                    "gate_id": "QSDK-R24D103",
                    "ok": True,
                    "route_ghost_receipt_validation_passed": True,
                    "route_ghost_mutation_rejected": True,
                    "positive_case_count": 17,
                    "forced_failure_case_count": 8,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "body_impulse_write_count": 0,
                    "native_readback_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                    "prone_to_standing_claimed": False,
                },
            },
        ),
    )["r104_order_neutral_population_route"]
    runtime_identity = controls.run_route_runtime_identity(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        gate_id=GATE_ID,
        schema=RUNTIME_IDENTITY_SCHEMA,
        contract=contract,
        worker_relative_path=PRODUCTION_WORKER,
        actuator_mode=ACTUATOR_MODE,
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, GATE_ID
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        GATE_ID,
        "sporespore_qsdk_r24d104_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d104_route_preflight_v1",
        "gate_id": GATE_ID,
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "current_zero_world_worker_receipt": worker,
        "current_positive_case_count": 17,
        "current_forced_failure_case_count": 8,
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
    arguments = parser.parse_args()
    contract, counts, published = validate_sources()
    if arguments.core_library is None:
        print(
            SOURCE_MARKER,
            json.dumps(
                {"gate_id": GATE_ID, "ok": True, "published": published, **counts},
                sort_keys=True,
            ),
        )
        return 0
    require(arguments.core_library.is_file(), "CORE_LIBRARY_MISSING")
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
        print(f"QSDK_R24D104_ORDER_NEUTRAL_ROUTE_FAIL:{error}", file=sys.stderr)
        raise SystemExit(1) from error
