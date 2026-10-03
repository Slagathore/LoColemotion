#!/usr/bin/env python3
"""Compact R96 nested-target source audit and zero-world route preflight."""

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
    "sdk/recovery/r24d96_godot_jolt_nested_guarded_"
    "recovery_route_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_"
    "zero_world_qualification_closure_v1.json"
)
R95_PHYSICAL_CLOSURE = ROOT / (
    "sdk/recovery/r24d95_godot_jolt_publication_stable_guarded_"
    "recovery_route_ghost_invalid_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d96_godot_jolt_nested_guarded_recovery_route.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d96_godot_jolt_nested_guarded_recovery_route_"
    "zero_world_qualification.ps1"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
PRODUCTION_WORKER = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
ZERO_WORKER = ROOT / (
    "tests/test_sdk_godot_jolt_nested_native_angular_velocity_guard_zero_world.gd"
)
ZERO_MARKER = (
    "SPORESPORE_GODOT_JOLT_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_ZERO_WORLD "
)
SOURCE_MARKER = "QSDK_R24D96_GODOT_JOLT_NESTED_GUARDED_ROUTE_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D96_NESTED_GUARDED_RECOVERY_ROUTE_SUPERVISOR "
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_"
    "recovery_route_contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_route_"
    "zero_world_qualification_closure_v1"
)
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d96_nested_guarded_recovery_route_runtime_identity_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_nested_guarded_recovery_route_complete_zero_world_"
    "qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_nested_guarded_recovery_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
R95_STATUS = (
    "closed_consumed_invalid_incomplete_guarded_route_ghost_immediate_native_"
    "readback_exceeded_inner_guard_r96_required"
)
ACTUATOR_MODE = "force_based_nested_native_angular_velocity_guarded_v1"
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d96_source_measured_nested_native_angular_velocity_"
    "guarded_joint_impulse_v1"
)
WORK_MAPPING_ID = (
    "godot_jolt_r24d96_nested_guarded_centered_source_measured_joint_work_v1"
)


def _validate_predecessor(contract: dict[str, Any]) -> None:
    predecessor = controls.validate_bound_predecessor(
        ROOT, contract, R95_PHYSICAL_CLOSURE
    )
    verify_exact_paths(
        predecessor,
        {
            "schema_version": (
                "sporespore_qsdk_r24d95_godot_jolt_publication_stable_"
                "guarded_recovery_route_ghost_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D95",
            "closure_status": R95_STATUS,
            "question_class": "development",
            "source.commit": "de2bd0dd1a8eae0365141702bb8df14f6fe09acb",
            "physical_attempt.attempt_count_for_exact_source_and_gate": 1,
            "physical_attempt.status": "invalid_or_incomplete_integration_ghost",
            "physical_attempt.model_construction_count": 1,
            "physical_attempt.world_attempt_count": 1,
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 1,
            "observed_failure.direct_failure_code": (
                "QSDK_R24D94_GUARDED_IMMEDIATE_NATIVE_READBACK_INVALID:0"
            ),
            "observed_failure.guard_limit_rad_s": 47.11813735961914,
            "observed_failure.native_engine_health_passed": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.distinct_r96_successor_required": True,
            "claim_boundary.valid_complete_integration_result": False,
            "next_boundary.gate_id": "QSDK-R24D96",
            "next_boundary.physical_execution_blocked": True,
            "next_boundary.guard_observation_limit_may_be_rewritten": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R95_PHYSICAL",
    )


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
            "controlled_change.r24d95_consumed_invalid_physical_closure_bound": True,
            "controlled_change.r24d95_same_identity_rerun_permitted": False,
            "controlled_change.r94_outer_guard_limit_or_derivation_changed": False,
            "controlled_change.source_derived_inner_projection_target_added": True,
            "controlled_change.inner_target_uses_same_1024_binary32_epsilon_rule": True,
            "controlled_change.r24d95_observation_selected_inner_margin": False,
            "controlled_change.outer_native_readback_guard_remains_authoritative": True,
            "projection_target_provenance.frozen_outer_guard_limit_rad_s": 47.11813735961914,
            "projection_target_provenance.inner_projection_target_limit_rad_s": 47.11238479614258,
            "projection_target_provenance.outer_to_target_absolute_headroom_rad_s": 0.0057525634765625,
            "projection_target_provenance.empirically_fitted": False,
            "projection_target_provenance.behavior_threshold_changed": False,
            "complete_zero_world_gate.current_nested_guard_worker_count": 1,
            "complete_zero_world_gate.current_nested_guard_positive_case_count": 5,
            "complete_zero_world_gate.current_nested_guard_forced_failure_case_count": 7,
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
        "QSDK-R24D96",
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
            "inner_projection_target_required": True,
            "outer_guard_zero_impulse_hold_permitted": True,
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
        gate_id="QSDK-R24D96",
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
                ACTUATOR_MAPPING_ID,
                WORK_MAPPING_ID,
                "native_angular_velocity_inner_projection_target_v1",
                "outer_guard_zero_impulse_hold",
            ),
            ROUTE: (
                "apply_behavior_control_force_based_nested_guarded_v4",
                "nested_projection_required",
                "native_angular_velocity_inner_projection_target",
            ),
            SUPERVISOR: (
                '"force_based_nested_native_angular_velocity_guarded_v1"',
                "qualified_physical_source_drift",
            ),
            PRODUCTION_WORKER: (
                "ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED",
                "apply_behavior_control_force_based_nested_guarded_v4",
            ),
            ZERO_WORKER.relative_to(ROOT).as_posix(): (
                "EXPECTED_INNER_TARGET_LIMIT_RAD_S",
                "OUTER_GUARD_HOLD_POSITIVE_INVALID",
                "forced_failure_case_count",
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D96"',
                f'ActuatorMode = "{ACTUATOR_MODE}"',
                "MaximumOuterSolverSteps = 2",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D96"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
        },
        "SOURCE_MARKERS",
    )
    counts = controls.validate_route_source_populations(ROOT, contract)
    verify_exact_paths(
        counts,
        {
            "source_inventory_count": 64,
            "authored_source_path_count": 14,
            "qualified_physical_path_count": 47,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 1,
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "COUNTS",
    )
    live_expected: dict[str, Any] = {
        "r24d96_question_class_declared": True,
        "r24d96_question_class": "development",
        "r24d96_physical_question_declared": True,
        "r24d96_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d96_r95_consumed_physical_closure_bound": True,
        "r24d96_outer_guard_unchanged": True,
        "r24d96_inner_projection_target_rad_s": 47.11238479614258,
        "r24d96_nested_guarded_actuator_mode_selected": True,
        "r24d96_zero_world_worker_count": 1,
        "r24d96_smallest_coverage_adequate_route_ghost_required": True,
        "r24d96_full_seeded_ghost_required": False,
        "r24d96_additional_seed_required": False,
        "physical_execution_blocked_pending_r24d96_declaration": False,
    }
    if published:
        live_expected.update(
            {
                "r24d96_source_status": QUALIFIED_STATUS,
                "r24d96_source_commit": source_commit,
                "r24d96_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d96_official_qualification_attempt_count": 1,
                "r24d96_zero_world_qualification_pending": False,
                "r24d96_zero_world_qualified": True,
                "r24d96_physical_execution_authorized": True,
                "physical_execution_blocked_until_r24d96_zero_world_qualification": False,
            }
        )
    else:
        live_expected.update(
            {
                "r24d96_source_status": PROSPECTIVE_STATUS,
                "r24d96_zero_world_qualification_pending": True,
                "r24d96_zero_world_qualified": False,
                "r24d96_physical_execution_authorized": False,
                "physical_execution_blocked_until_r24d96_zero_world_qualification": True,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d96_contract_path",
        expected=live_expected,
        prefix="LIVE_R96",
    )
    return contract, counts, published


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    executable = Path(contract["exact_runtime"]["console_path"])
    worker = controls.run_zero_world_worker_specs(
        ROOT,
        executable,
        (
            {
                "id": "r96_nested_guard",
                "path": ZERO_WORKER,
                "marker": ZERO_MARKER,
                "expected": {
                    "gate_id": "QSDK-R24D96",
                    "ok": True,
                    "predecessor_regression_passed": True,
                    "outer_guard_limit_rad_s": 47.11813735961914,
                    "projection_target_limit_rad_s": 47.11238479614258,
                    "outer_guard_unchanged": True,
                    "r24d95_observation_selected_margin": False,
                    "positive_case_count": 5,
                    "forced_failure_case_count": 7,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                },
            },
        ),
    )["r96_nested_guard"]
    runtime_identity = controls.run_route_runtime_identity(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        gate_id="QSDK-R24D96",
        schema=RUNTIME_IDENTITY_SCHEMA,
        contract=contract,
        worker_relative_path=PRODUCTION_WORKER,
        actuator_mode=ACTUATOR_MODE,
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D96"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D96",
        "sporespore_qsdk_r24d96_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d96_route_preflight_v1",
        "gate_id": "QSDK-R24D96",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "current_nested_guard_worker_receipt": worker,
        "current_nested_guard_positive_case_count": 5,
        "current_nested_guard_forced_failure_case_count": 7,
        "r95_closure_audit_reexecution_count": 0,
        "historical_closure_audits_executed_count": 0,
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
                {"gate_id": "QSDK-R24D96", "ok": True, "published": published, **counts},
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
        print(f"QSDK_R24D96_NESTED_GUARDED_ROUTE_FAIL:{error}", file=sys.stderr)
        raise SystemExit(1) from error
