#!/usr/bin/env python3
"""Compact R98 nested-guarded behavior source audit and zero-world preflight."""

from __future__ import annotations

import argparse
import hashlib
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
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PHYSICAL_CLOSURE = ROOT / (
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "invalid_closure_v1.json"
)
R92_PHYSICAL_CLOSURE = ROOT / (
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "invalid_closure_v1.json"
)
R97_PHYSICAL_CLOSURE = ROOT / (
    "sdk/recovery/r24d97_godot_jolt_applied_scale_route_"
    "ghost_positive_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d98_godot_jolt_nested_guarded_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "zero_world_qualification.ps1"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
PRODUCTION_WORKER = "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
ZERO_WORKER = (
    ROOT / "tests/test_sdk_godot_nested_guarded_behavior_dispatch_zero_world.gd"
)
ZERO_MARKER = "SPORESPORE_GODOT_NESTED_GUARDED_BEHAVIOR_DISPATCH_ZERO_WORLD "
SOURCE_MARKER = (
    "QSDK_R24D98_GODOT_JOLT_NESTED_GUARDED_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D98_NESTED_GUARDED_RECOVERY_BEHAVIOR_SUPERVISOR "
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_"
    "behavior_contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "zero_world_qualification_closure_v1"
)
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d98_nested_guarded_behavior_runtime_identity_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_nested_guarded_recovery_behavior_complete_zero_world_"
    "qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_nested_guarded_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)
PHYSICAL_CLOSED_STATUS = (
    "closed_consumed_invalid_incomplete_nested_guarded_recovery_behavior_no_"
    "feasible_parent_scale_r99_required"
)
R92_STATUS = (
    "closed_consumed_complete_producer_negative_invalid_for_physical_inference_"
    "native_angular_velocity_limit_assertions"
)
R97_STATUS = (
    "closed_valid_complete_applied_scale_recovery_production_route_ghost_"
    "passed_distinct_r24d98_behavior_successor_required"
)
SEED_LABEL = (
    "QSDK-R24D98/development/godot/"
    "r97-nested-guarded-exact-nominal-prone-to-standing-paired-v1"
)
SEED_SHA256 = (
    "sha256:92f3bd8868339e780a4517edf65ebb45d5a07e13e6ecb6803bb4e30a616d986d"
)
ACTUATOR_MODE = "force_based_nested_native_angular_velocity_guarded_v1"
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d96_source_measured_nested_native_angular_velocity_"
    "guarded_joint_impulse_v1"
)
WORK_MAPPING_ID = (
    "godot_jolt_r24d96_nested_guarded_centered_source_measured_joint_work_v1"
)


def _validate_predecessor(
    contract: dict[str, Any],
    index: int,
    path: Path,
    declaration_expected: dict[str, Any],
    closure_expected: dict[str, Any],
) -> None:
    declarations = contract.get("bound_predecessors")
    require(isinstance(declarations, list) and len(declarations) == 2,
            "PREDECESSOR_COUNT")
    declaration = declarations[index]
    require(isinstance(declaration, dict), f"PREDECESSOR_TYPE:{index}")
    raw = path.read_bytes()
    verify_exact_paths(
        declaration,
        {
            "path": path.relative_to(ROOT).as_posix(),
            "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            "byte_length": len(raw),
            "same_identity_rerun_permitted": False,
            "same_identity_requalification_permitted": False,
            "historical_result_rewritten": False,
            "historical_interpretation_rewritten": False,
            **declaration_expected,
        },
        f"PREDECESSOR_DECLARATION_{index}",
    )
    value = load(path)
    verify_exact_paths(value, closure_expected, f"PREDECESSOR_CLOSURE_{index}")


def _validate_predecessors(contract: dict[str, Any]) -> None:
    _validate_predecessor(
        contract,
        0,
        R92_PHYSICAL_CLOSURE,
        {
            "gate_id": "QSDK-R24D92",
            "role": (
                "consumed_complete_producer_negative_invalid_for_behavioral_"
                "inference"
            ),
            "closure_status": R92_STATUS,
        },
        {
            "schema_version": (
                "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D92",
            "closure_status": R92_STATUS,
            "source.commit": "d242d92dfe968e2a5f4fe8a24acb096ef704cd8e",
            "physical_attempt.attempt_count_for_exact_source_and_gate": 1,
            "physical_attempt.seed": 278151771,
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.model_construction_count": 2,
            "physical_attempt.world_build_count": 2,
            "physical_attempt.solver_step_count": 536,
            "physical_attempt.behavior_evaluator_invocation_count": 1,
            "decision.native_angular_velocity_limit_assertions_observed": True,
            "decision.closure_invalid_for_behavioral_inference": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.scientific_behavior_negative_accepted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
    )
    _validate_predecessor(
        contract,
        1,
        R97_PHYSICAL_CLOSURE,
        {
            "gate_id": "QSDK-R24D97",
            "role": "valid_complete_nested_guarded_production_route_ghost",
            "closure_status": R97_STATUS,
        },
        {
            "schema_version": (
                "sporespore_qsdk_r24d97_godot_jolt_applied_scale_route_"
                "ghost_positive_closure_v1"
            ),
            "gate_id": "QSDK-R24D97",
            "closure_status": R97_STATUS,
            "source.commit": "16ab79ceb25d4dfc29cba8462f395944b10c74be",
            "physical_attempt.attempt_count_for_exact_source_and_gate": 1,
            "physical_attempt.status": "valid_complete_integration_ghost",
            "physical_attempt.native_engine_health_passed": True,
            "physical_attempt.model_construction_count": 1,
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 2,
            "physical_attempt.nested_guarded_command_application_executed": True,
            "decision.integration_ghost_passed": True,
            "decision.in_run_physical_invariants_passed": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.recovery_success_established": False,
            "next_boundary.gate_id": "QSDK-R24D98",
            "next_boundary.physical_execution_blocked": True,
            "claim_boundary.prone_to_standing_claimed": False,
        },
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "gate_id": "QSDK-R24D98",
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "controlled_change.r24d92_consumed_invalid_behavior_closure_bound": True,
            "controlled_change.r24d97_valid_complete_route_closure_bound": True,
            "controlled_change.r24d92_same_identity_rerun_permitted": False,
            "controlled_change.r24d97_same_identity_rerun_permitted": False,
            "controlled_change.r24d92_seed_value_reused": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.actuator_mode_changed_to_r24d97_nested_guarded_route": True,
            "controlled_change.production_behavior_worker_nested_dispatch_added": True,
            "controlled_change.native_route_or_world_changed": False,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "complete_zero_world_gate.current_behavior_dispatch_worker_count": 1,
            "complete_zero_world_gate.current_behavior_dispatch_positive_case_count": 4,
            "complete_zero_world_gate.current_behavior_dispatch_forced_failure_case_count": 7,
            "physical_runner.actuator_mode": ACTUATOR_MODE,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CONTRACT",
    )
    controls.validate_development_question(contract, "QSDK-R24D98")
    question = contract["finite_behavior_question"]
    verify_exact_paths(
        question,
        {
            "seed": 278151771,
            "seed_label": SEED_LABEL,
            "seed_sha256": SEED_SHA256,
            "held_out": False,
            "cell_count": 1,
            "physical_cohort_count": 1,
            "arm_count": 2,
            "world_count": 2,
            "ordered_arms": ["candidate_command", "matched_zero_command"],
            "candidate_and_matched_zero_run_sequentially": True,
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_outer_solver_steps": 2400,
            "maximum_outer_solver_steps_per_arm": 1200,
            "physics_ticks_per_second": 120,
            "behavior_evaluator_invocation_count": 1,
            "same_source_attempt_limit": 1,
            "same_identity_rerun_permitted": False,
            "repeatability_claimed": False,
            "population_inference_claimed": False,
            "cross_engine_equivalence_claimed": False,
        },
        "FINITE_BEHAVIOR_QUESTION",
    )
    require(
        "sha256:" + hashlib.sha256(SEED_LABEL.encode("utf-8")).hexdigest()
        == SEED_SHA256,
        "SEED_LABEL_DIGEST",
    )
    verify_exact_paths(
        contract["behavior_execution_contract"],
        {
            "genuine_engine": "godot_4_7_jolt",
            "policy_semantics_id": "sporespore_recovery_v4",
            "task_id": "prone_to_standing_v1",
            "recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v1"
            ),
            "actuator_profile_id": "s169_mass_scaled_actuator_profile_v1",
            "actuator_mode": ACTUATOR_MODE,
            "actuator_mapping_id": ACTUATOR_MAPPING_ID,
            "work_mapping_id": WORK_MAPPING_ID,
            "worker_path": PRODUCTION_WORKER,
            "native_engine_health_required": True,
            "physical_success_required_for_worker_validity": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "BEHAVIOR_EXECUTION",
    )
    verify_exact_paths(
        contract["threshold_margin_cohort_and_population_adequacy"],
        {
            "threshold_profile_id": "supported_exact_recovery_v4",
            "threshold_profile_sha256": (
                "sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34"
            ),
            "maximum_energy_balance_residual_j": 0.25,
            "required_stance_dwell_steps": 60,
            "stance_dwell_timeout_steps": 240,
            "maximum_outer_solver_steps_per_arm": 1200,
            "native_angular_velocity_outer_guard_rad_s": 47.11813735961914,
            "native_angular_velocity_inner_projection_target_rad_s": 47.11238479614258,
            "new_empirical_threshold_count": 0,
            "new_behavior_threshold_count": 0,
            "equivalence_margin_count": 0,
            "non_inferiority_margin_count": 0,
            "held_out_cell_access_count": 0,
            "population_claim_count": 0,
        },
        "THRESHOLD_COHORT_ADEQUACY",
    )
    verify_exact_paths(
        contract["physical_authorization_projection"],
        {
            "gate_id": "QSDK-R24D98",
            "question_class": "development",
            "seed": 278151771,
            "seed_label": SEED_LABEL,
            "seed_sha256": SEED_SHA256,
            "held_out": False,
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_outer_solver_steps": 2400,
            "maximum_outer_solver_steps_per_arm": 1200,
            "behavior_evaluator_invocation_count": 1,
            "same_identity_rerun_permitted": False,
            "physical_execution_authorized": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "AUTHORIZATION_PROJECTION",
    )
    _validate_predecessors(contract)
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=CLOSURE_SCHEMA,
        gate_id="QSDK-R24D98",
    )
    physical_closed = PHYSICAL_CLOSURE.is_file()
    if physical_closed:
        physical_raw = PHYSICAL_CLOSURE.read_bytes().replace(b"\r\n", b"\n")
        verify_exact_paths(
            {
                "byte_length": len(physical_raw),
                "raw_sha256": "sha256:" + hashlib.sha256(physical_raw).hexdigest(),
            },
            {
                "byte_length": 16793,
                "raw_sha256": (
                    "sha256:2407fcbce4d82a1ca4575ee5701b73b667e58629a6348448f"
                    "cb9787e2ed2c6e8"
                ),
            },
            "PHYSICAL_CLOSURE_BLOB",
        )
        verify_exact_paths(
            load(PHYSICAL_CLOSURE),
            {
                "schema_version": (
                    "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_"
                    "recovery_behavior_invalid_closure_v1"
                ),
                "gate_id": "QSDK-R24D98",
                "closure_status": PHYSICAL_CLOSED_STATUS,
                "source.commit": "57e2a31c08b58307944d38e6615f204da2cd7144",
                "decision.behavior_attempt_consumed_for_exact_source": True,
                "decision.same_identity_rerun_permitted": False,
                "decision.valid_complete_behavior_result": False,
                "decision.prone_to_standing_claimed": False,
            },
            "PHYSICAL_CLOSURE",
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
                "NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID",
                "NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID",
                "NATIVE_ANGULAR_VELOCITY_INNER_PROJECTION_TARGET_SCHEMA",
            ),
            ROUTE: (
                "apply_behavior_control_force_based_nested_guarded_v4",
                "native_angular_velocity_nested_projection_required",
                "guarded_force_based_applied_scale_projection_v1",
            ),
            SUPERVISOR: (
                '"behavior_development"',
                "Test-SporeSporeDirectQuestionAuthorization",
                "qualified_physical_source_drift",
            ),
            PRODUCTION_WORKER: (
                "ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED",
                "apply_behavior_control_force_based_nested_guarded_v4",
                "behavior_application_receipt_valid_v2",
                "all_immediate_native_readbacks_inside_guard",
            ),
            ZERO_WORKER.relative_to(ROOT).as_posix(): (
                "production_validation_seam_invoked",
                "positive_case_count",
                "forced_failure_case_count",
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D98"',
                f'ActuatorMode = "{ACTUATOR_MODE}"',
                'PhysicalQuestionKind = "behavior_development"',
                "MaximumOuterSolverSteps = 2400",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D98"',
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
            "authored_source_path_count": 11,
            "qualified_physical_path_count": 48,
            "bound_predecessor_count": 2,
            "current_zero_world_worker_count": 1,
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "COUNTS",
    )
    live_expected: dict[str, Any] = {
        "r24d98_question_class_declared": True,
        "r24d98_question_class": "development",
        "r24d98_physical_question_declared": True,
        "r24d98_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d98_r92_consumed_invalid_behavior_closure_bound": True,
        "r24d98_r97_valid_route_closure_bound": True,
        "r24d98_exact_r92_behavior_question_reused": True,
        "r24d98_nested_guarded_actuator_route_selected": True,
        "r24d98_behavior_worker_nested_dispatch_added": True,
        "r24d98_zero_world_worker_count": 1,
        "r24d98_additional_physical_ghost_required": False,
        "r24d98_additional_physical_canary_required": False,
        "physical_execution_blocked_pending_r24d98_declaration": False,
    }
    if published:
        live_expected.update(
            {
                "r24d98_source_status": (
                    PHYSICAL_CLOSED_STATUS if physical_closed else QUALIFIED_STATUS
                ),
                "r24d98_source_commit": source_commit,
                "r24d98_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d98_official_qualification_attempt_count": 1,
                "r24d98_zero_world_qualification_pending": False,
                "r24d98_zero_world_qualified": True,
                "r24d98_physical_execution_authorized": not physical_closed,
                "r24d98_physical_attempt_consumed": physical_closed,
                "physical_execution_blocked_until_r24d98_zero_world_qualification": False,
            }
        )
    else:
        live_expected.update(
            {
                "r24d98_source_status": PROSPECTIVE_STATUS,
                "r24d98_zero_world_qualification_pending": True,
                "r24d98_zero_world_qualified": False,
                "r24d98_physical_execution_authorized": False,
                "physical_execution_blocked_until_r24d98_zero_world_qualification": True,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d98_contract_path",
        expected=live_expected,
        prefix="LIVE_R98",
    )
    return contract, counts, published


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    executable = Path(contract["exact_runtime"]["console_path"])
    worker = controls.run_zero_world_worker_specs(
        ROOT,
        executable,
        (
            {
                "id": "r98_nested_guarded_behavior_dispatch",
                "path": ZERO_WORKER,
                "marker": ZERO_MARKER,
                "expected": {
                    "gate_id": "QSDK-R24D98",
                    "ok": True,
                    "positive_case_count": 4,
                    "forced_failure_case_count": 7,
                    "nested_active_positive_count": 1,
                    "nested_no_actuation_positive_count": 1,
                    "legacy_compatibility_positive_count": 2,
                    "production_validation_seam_invoked": True,
                    "nested_mapping_selection_verified": True,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                },
            },
        ),
    )["r98_nested_guarded_behavior_dispatch"]
    runtime_identity = controls.run_route_runtime_identity(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        gate_id="QSDK-R24D98",
        schema=RUNTIME_IDENTITY_SCHEMA,
        contract=contract,
        worker_relative_path=PRODUCTION_WORKER,
        actuator_mode=ACTUATOR_MODE,
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D98"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D98",
        "sporespore_qsdk_r24d98_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d98_behavior_preflight_v1",
        "gate_id": "QSDK-R24D98",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "current_behavior_dispatch_worker_receipt": worker,
        "current_behavior_dispatch_positive_case_count": 4,
        "current_behavior_dispatch_forced_failure_case_count": 7,
        "r92_closure_audit_reexecution_count": 0,
        "r97_closure_audit_reexecution_count": 0,
        "historical_closure_audits_executed_count": 0,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "forced_supervisor_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "behavior_evaluator_invocation_count": 0,
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
                {"gate_id": "QSDK-R24D98", "ok": True, "published": published,
                 **counts},
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
        print(f"QSDK_R24D98_NESTED_GUARDED_BEHAVIOR_FAIL:{error}", file=sys.stderr)
        raise SystemExit(1) from error
