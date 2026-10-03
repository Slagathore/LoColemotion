#!/usr/bin/env python3
"""Compact R99 component-norm behavior source audit and zero-world preflight."""

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
    retained_file_tree_projection,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_exact_retained_inventory,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_"
    "contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PHYSICAL_CLOSURE = ROOT / (
    "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_"
    "invalid_closure_v1.json"
)
PREDECESSOR = ROOT / (
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "invalid_closure_v1.json"
)
FIRST_QUALIFICATION_FAILURE = ROOT / (
    "sdk/recovery/r24d99_godot_jolt_component_norm_recovery_behavior_first_"
    "zero_world_qualification_failure_v1.json"
)
RUNNER = ROOT / "sdk/run_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior.ps1"
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior_"
    "zero_world_qualification.ps1"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
SHARED_QUALIFIER = "sdk/run_qsdk_core_zero_world_qualification.ps1"
PRODUCTION_WORKER = "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
ZERO_WORKER = ROOT / "tests/test_sdk_godot_r24d99_guard_boundary_consistency_zero_world.gd"
ZERO_MARKER = "SPORESPORE_GODOT_R24D99_GUARD_BOUNDARY_CONSISTENCY_ZERO_WORLD "
SOURCE_MARKER = "QSDK_R24D99_GODOT_JOLT_COMPONENT_NORM_RECOVERY_BEHAVIOR_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D99_COMPONENT_NORM_RECOVERY_BEHAVIOR_SUPERVISOR "
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior_"
    "contract_v1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior_"
    "zero_world_qualification_closure_v1"
)
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d99_component_norm_behavior_runtime_identity_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_component_norm_nested_guarded_recovery_behavior_complete_"
    "zero_world_qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_component_norm_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)
PHYSICAL_CLOSED_STATUS = (
    "closed_consumed_invalid_incomplete_component_norm_recovery_behavior_"
    "guard_refinement_failed_r100_required"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_nested_guarded_recovery_behavior_no_"
    "feasible_parent_scale_r99_required"
)
SEED_LABEL = (
    "QSDK-R24D99/development/godot/"
    "r99-component-norm-exact-nominal-prone-to-standing-paired-v1"
)
SEED_SHA256 = (
    "sha256:f1446a1853e3d6886e96232e80384be334bd2607fed79ad942fe0dc19e118a6d"
)
ACTUATOR_MODE = (
    "force_based_component_norm_nested_native_angular_velocity_guarded_v1"
)
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d99_component_norm_nested_guarded_joint_impulse_v1"
)
WORK_MAPPING_ID = (
    "godot_jolt_r24d99_component_norm_nested_guarded_centered_joint_work_v1"
)
NUMERIC_PREDICATE_ID = (
    "godot_vector3_components_widened_to_float64_euclidean_squared_norm_v1"
)


def _validate_runtime(contract: dict[str, Any]) -> Path:
    runtime = contract["exact_runtime"]
    executable = Path(runtime["console_path"])
    require(executable.is_file(), "EXACT_RUNTIME_MISSING")
    raw = executable.read_bytes()
    verify_exact_paths(
        runtime,
        {
            "console_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            "console_byte_length": len(raw),
            "runtime_profile_id": (
                "godot_4_7_jolt_sporespore_motor_and_solved_contact_telemetry_v3"
            ),
            "runtime_version": "4.7.stable.custom_build.5b4e0cb0f",
        },
        "EXACT_RUNTIME",
    )
    return executable


def _validate_first_qualification_failure(contract: dict[str, Any]) -> dict[str, Any]:
    failure_raw = FIRST_QUALIFICATION_FAILURE.read_bytes()
    history = contract["qualification_history"]
    evidence_root = Path(history["first_attempt_evidence_root"])
    verify_exact_paths(
        history,
        {
            "official_attempt_count": 1,
            "valid_complete_attempt_count": 0,
            "invalid_or_incomplete_attempt_count": 1,
            "consumed_source_commits": [
                "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8"
            ],
            "first_attempt_failure_record_path": (
                FIRST_QUALIFICATION_FAILURE.relative_to(ROOT).as_posix()
            ),
            "first_attempt_failure_record_raw_sha256": (
                "sha256:" + hashlib.sha256(failure_raw).hexdigest()
            ),
            "first_attempt_failure_record_byte_length": len(failure_raw),
            "first_attempt_evidence_root": evidence_root.as_posix(),
            "same_source_retry_permitted": False,
            "distinct_clean_pushed_source_required": True,
            "current_source_must_differ_from_consumed_source": True,
            "complete_zero_world_qualification_still_required": True,
            "physical_execution_remains_blocked": True,
        },
        "QUALIFICATION_HISTORY",
    )
    record = json.loads(failure_raw)
    verify_exact_paths(
        record,
        {
            "schema_version": (
                "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_"
                "behavior_first_zero_world_qualification_failure_v1"
            ),
            "gate_id": "QSDK-R24D99",
            "source.commit": "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8",
            "source.clean_pushed_and_live_remote_equal_at_launch": True,
            "source.same_source_official_qualification_retry_permitted": False,
            "attempt.completed_check_count": 9,
            "attempt.qualification_receipt_written": False,
            "attempt.model_construction_count": 0,
            "attempt.world_attempt_count": 0,
            "attempt.world_build_count": 0,
            "attempt.solver_step_count": 0,
            "attempt.behavior_evaluator_invocation_count": 0,
            "attempt.physics_state_modified": False,
            "attempt.physical_question_opened": False,
            "failure.contract_source_inventory_missing": True,
            "failure.native_engine_or_physics_failure_observed": False,
            "failure.behavior_result_exists": False,
            "next_boundary.same_source_retry_permitted": False,
            "next_boundary.distinct_clean_pushed_source_required": True,
            "next_boundary.physical_execution_blocked": True,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.physical_execution_authorized": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.release_authority": False,
        },
        "FIRST_QUALIFICATION_FAILURE",
    )
    require(
        Path(record["attempt"]["evidence_root"]) == evidence_root,
        "FIRST_QUALIFICATION_EVIDENCE_ROOT",
    )
    verify_exact_retained_inventory(evidence_root, record["retained_evidence"]["files"])
    verify_exact_paths(
        record["retained_evidence"]["tree"],
        retained_file_tree_projection(evidence_root),
        "FIRST_QUALIFICATION_FAILURE_TREE",
    )
    require(
        not (evidence_root / "qualification_receipt.json").exists()
        and not (evidence_root / "qualification_failure.json").exists(),
        "FIRST_QUALIFICATION_TERMINAL_RECEIPT_UNEXPECTED",
    )
    attempt = load(evidence_root / "qualification_attempt.json")
    verify_exact_paths(
        attempt,
        {
            "source_commit": "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8",
            "upstream_commit": "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8",
            "live_remote_commit": "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8",
            "worktree_clean_at_start": True,
            "operation_lock.acquired": True,
            "operation_lock.test_only": False,
            "world_attempt_count": 0,
            "solver_step_count": 0,
            "physical_question_opened": False,
        },
        "FIRST_QUALIFICATION_ATTEMPT",
    )
    preflight_lines = (evidence_root / "production_preflight.log").read_text(
        encoding="utf-8"
    ).splitlines()
    require(bool(preflight_lines), "FIRST_QUALIFICATION_PREFLIGHT_EMPTY")
    preflight = json.loads(preflight_lines[-1])
    controls.require_zero_authority(preflight)
    verify_exact_paths(
        preflight,
        {
            "gate_id": "QSDK-R24D99",
            "ok": True,
            "qualified_physical_path_count": 47,
            "current_zero_world_positive_case_count": 8,
            "current_zero_world_forced_failure_case_count": 5,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "FIRST_QUALIFICATION_PREFLIGHT",
    )
    require(
        SOURCE_MARKER in (evidence_root / "source_audit.log").read_text("utf-8"),
        "FIRST_QUALIFICATION_SOURCE_MARKER",
    )
    return record


def validate_sources() -> tuple[dict[str, Any], bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "gate_id": "QSDK-R24D99",
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "authored_parent_commit": (
                "b32d2ba5ec21712e440bab22d87fc86d1f4e68dc"
            ),
            "controlled_change.r24d98_invalid_closure_bound": True,
            "controlled_change.r24d98_frozen_closure_changed": False,
            "controlled_change.r24d98_historical_audit_live_successor_state_decoupled": True,
            "controlled_change.r24d99_first_zero_world_qualification_failure_bound": True,
            "controlled_change.r24d99_consumed_source_retry_permitted": False,
            "controlled_change.explicit_source_inventory_added": True,
            "controlled_change.shared_qualifier_validates_source_inventory_before_expensive_checks": True,
            "controlled_change.source_manifest_construction_moved_inside_failure_retention_boundary": True,
            "controlled_change.outer_guard_exceedance_established_by_r24d98": False,
            "controlled_change.component_norm_numeric_predicate_id": (
                NUMERIC_PREDICATE_ID
            ),
            "controlled_change.native_angular_velocity_outer_guard_changed": False,
            "controlled_change.native_angular_velocity_inner_projection_target_changed": False,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "complete_zero_world_gate.current_worker_count": 1,
            "complete_zero_world_gate.current_positive_case_count": 8,
            "complete_zero_world_gate.current_forced_failure_case_count": 5,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "behavior_execution_contract.actuator_mode": ACTUATOR_MODE,
            "behavior_execution_contract.actuator_mapping_id": ACTUATOR_MAPPING_ID,
            "behavior_execution_contract.work_mapping_id": WORK_MAPPING_ID,
            "behavior_execution_contract.numeric_predicate_id": NUMERIC_PREDICATE_ID,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CONTRACT",
    )
    controls.validate_development_question(contract, "QSDK-R24D99")
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
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_outer_solver_steps": 2400,
            "maximum_outer_solver_steps_per_arm": 1200,
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
            "new_representation_rule_count": 1,
            "equivalence_margin_count": 0,
            "non_inferiority_margin_count": 0,
            "held_out_cell_access_count": 0,
            "population_claim_count": 0,
        },
        "THRESHOLD_ADEQUACY",
    )
    predecessor = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    verify_exact_paths(
        predecessor,
        {
            "schema_version": (
                "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D98",
            "closure_status": PREDECESSOR_STATUS,
            "source.commit": "57e2a31c08b58307944d38e6615f204da2cd7144",
            "decision.behavior_attempt_consumed_for_exact_source": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.valid_complete_behavior_result": False,
            "decision.prone_to_standing_claimed": False,
        },
        "PREDECESSOR_CLOSURE",
    )
    _validate_first_qualification_failure(contract)
    executable = _validate_runtime(contract)
    qualified = contract["qualified_physical_paths"]
    require(
        isinstance(qualified, list)
        and len(qualified) == len(set(qualified)) == 47,
        "QUALIFIED_PHYSICAL_PATH_POPULATION",
    )
    for relative in qualified:
        require((ROOT / relative).is_file(), f"QUALIFIED_PATH_MISSING:{relative}")
    source_inventory = contract["source_inventory"]
    require(
        isinstance(source_inventory, list)
        and len(source_inventory) == len(set(source_inventory)) == 65,
        "SOURCE_INVENTORY_POPULATION",
    )
    require(
        set(qualified).issubset(source_inventory)
        and set(contract["authored_source_paths"]).issubset(source_inventory),
        "SOURCE_INVENTORY_COVERAGE",
    )
    for relative in source_inventory:
        require((ROOT / relative).is_file(), f"SOURCE_INVENTORY_PATH_MISSING:{relative}")

    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=CLOSURE_SCHEMA,
        gate_id="QSDK-R24D99",
    )
    require(
        source_commit != "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8",
        "CONSUMED_QUALIFICATION_SOURCE_REUSED",
    )
    physical_closed = PHYSICAL_CLOSURE.is_file()
    marker_paths = (
        WORLD,
        ROUTE,
        SUPERVISOR,
        PRODUCTION_WORKER,
        ZERO_WORKER.relative_to(ROOT).as_posix(),
        RUNNER.relative_to(ROOT).as_posix(),
        QUALIFICATION_RUNNER,
        SHARED_QUALIFIER,
    )
    bound = {path: source_bytes(ROOT, source_commit, path) for path in marker_paths}
    verify_bound_source_markers(
        bound,
        {
            WORLD: (
                "COMPONENT_NORM_NUMERIC_PREDICATE_ID",
                "angular_velocity_component_norm_limit_relation_v1",
                "nested_native_angular_velocity_guard_pair_projection_v2",
                "component_norm_nested_native_angular_velocity_guard_readback_receipt_v1",
                "component_norm_nested_guarded_force_based_joint_work_projection_v1",
            ),
            ROUTE: (
                "apply_behavior_control_force_based_component_norm_nested_guarded_v5",
                "component_norm_numeric_predicate_required",
                "component_norm_guarded_force_based_applied_scale_projection_v1",
            ),
            SUPERVISOR: (
                '"force_based_component_norm_nested_native_angular_velocity_guarded_v1"',
                "Test-SporeSporeDirectQuestionAuthorization",
                "qualified_physical_source_drift",
            ),
            PRODUCTION_WORKER: (
                "ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED",
                "apply_behavior_control_force_based_component_norm_nested_guarded_v5",
                "behavior_application_receipt_valid_v2",
            ),
            ZERO_WORKER.relative_to(ROOT).as_posix(): (
                "legacy_nested_projection_failure_code",
                "mapped_projection_validation_passed",
                "production_dispatch_accepted",
                "forced_failure_case_count",
            ),
            RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D99"',
                f'"{ACTUATOR_MODE}"',
                'PhysicalQuestionKind = "behavior_development"',
                "MaximumOuterSolverSteps = 2400",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D99"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
            SHARED_QUALIFIER: (
                "QSDK_CORE_ZERO_WORLD_SOURCE_INVENTORY_MISSING",
                '$sourceInventoryProperty = $contract.PSObject.Properties["source_inventory"]',
                '$checks["source_manifest_frozen"] = $true',
            ),
        },
        "SOURCE_MARKERS",
    )
    live_expected: dict[str, Any] = {
        "r24d99_question_class_declared": True,
        "r24d99_question_class": "development",
        "r24d99_physical_question_declared": True,
        "r24d99_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d99_r24d98_invalid_closure_bound": True,
        "r24d99_component_norm_source_implemented": True,
        "r24d99_numeric_predicate_id": NUMERIC_PREDICATE_ID,
        "r24d99_actuator_mapping_id": ACTUATOR_MAPPING_ID,
        "r24d99_work_mapping_id": WORK_MAPPING_ID,
        "r24d99_zero_world_worker_count": 1,
        "r24d99_zero_world_positive_case_count": 8,
        "r24d99_zero_world_forced_failure_case_count": 5,
        "r24d99_historical_closure_audits_executed_count": 0,
        "r24d99_additional_physical_ghost_required": False,
        "r24d99_additional_physical_canary_required": False,
        "r24d99_official_qualification_attempt_count": 1,
        "r24d99_incomplete_qualification_attempt_count": 1,
        "r24d99_first_qualification_source_commit": (
            "11e5228c3a96133ecbb1e4a47e8d34c04ddb4bd8"
        ),
        "r24d99_first_qualification_failure_record_path": (
            FIRST_QUALIFICATION_FAILURE.relative_to(ROOT).as_posix()
        ),
        "r24d99_first_qualification_evidence_root": (
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
            "qsdk-r24d99-godot-jolt-component-norm-recovery-behavior-"
            "qualification-20260831T182343412Z-11e5228c"
        ),
        "r24d99_first_qualification_failure_code": (
            "QSDK_CORE_ZERO_WORLD_SOURCE_INVENTORY_MISSING"
        ),
        "r24d99_first_qualification_model_construction_count": 0,
        "r24d99_first_qualification_world_attempt_count": 0,
        "r24d99_first_qualification_world_build_count": 0,
        "r24d99_first_qualification_solver_step_count": 0,
        "r24d99_source_inventory_contract_fixed": True,
        "r24d99_same_source_qualification_retry_permitted": False,
        "physical_execution_blocked_pending_r24d99_declaration": False,
    }
    if published:
        live_expected.update(
            {
                "r24d99_source_status": (
                    PHYSICAL_CLOSED_STATUS if physical_closed else QUALIFIED_STATUS
                ),
                "r24d99_source_commit": source_commit,
                "r24d99_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d99_official_qualification_attempt_count": 2,
                "r24d99_valid_complete_qualification_attempt_count": 1,
                "r24d99_zero_world_qualification_pending": False,
                "r24d99_zero_world_qualified": True,
                "r24d99_physical_execution_authorized": not physical_closed,
                "r24d99_physical_attempt_consumed": physical_closed,
                "physical_execution_blocked_until_r24d99_zero_world_qualification": False,
            }
        )
    else:
        live_expected.update(
            {
                "r24d99_source_status": PROSPECTIVE_STATUS,
                "r24d99_zero_world_qualification_pending": True,
                "r24d99_zero_world_qualified": False,
                "r24d99_physical_execution_authorized": False,
                "physical_execution_blocked_until_r24d99_zero_world_qualification": True,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d99_contract_path",
        expected=live_expected,
        prefix="LIVE_R99",
    )
    require(executable.is_file(), "EXACT_RUNTIME_DISAPPEARED")
    return contract, published


def run_preflight(contract: dict[str, Any]) -> dict[str, Any]:
    executable = Path(contract["exact_runtime"]["console_path"])
    worker = controls.run_zero_world_worker_specs(
        ROOT,
        executable,
        (
            {
                "id": "r99_component_norm_boundary_and_production_path",
                "path": ZERO_WORKER,
                "marker": ZERO_MARKER,
                "expected": {
                    "gate_id": "QSDK-R24D99",
                    "ok": True,
                    "positive_case_count": 8,
                    "forced_failure_case_count": 5,
                    "legacy_predicates_disagree": True,
                    "legacy_nested_projection_ok": False,
                    "legacy_nested_projection_failure_code": (
                        "QSDK_R24D96_NESTED_PAIR_TARGET_PROJECTION_FAILED"
                    ),
                    "corrected_nested_projection_validation_passed": True,
                    "mapped_projection_validation_passed": True,
                    "applied_scale_projection_passed": True,
                    "native_readback_validation_passed": True,
                    "centered_work_projection_passed": True,
                    "production_dispatch_accepted": True,
                    "production_mapping_selected": True,
                    "production_mutation_rejected": True,
                    "source_above_outer_guard_rejected": True,
                    "mismatched_impulse_pair_rejected": True,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                },
            },
        ),
    )["r99_component_norm_boundary_and_production_path"]
    runtime_identity = controls.run_route_runtime_identity(
        ROOT,
        RUNNER,
        SUPERVISOR_MARKER,
        gate_id="QSDK-R24D99",
        schema=RUNTIME_IDENTITY_SCHEMA,
        contract=contract,
        worker_relative_path=PRODUCTION_WORKER,
        actuator_mode=ACTUATOR_MODE,
    )
    projection = controls.run_projection_control(
        ROOT, RUNNER, SUPERVISOR_MARKER, "QSDK-R24D99"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D99",
        "sporespore_qsdk_r24d99_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d99_behavior_preflight_v1",
        "gate_id": "QSDK-R24D99",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        "numeric_predicate_id": NUMERIC_PREDICATE_ID,
        "qualified_physical_path_count": len(contract["qualified_physical_paths"]),
        "current_zero_world_worker_count": 1,
        "current_zero_world_positive_case_count": 8,
        "current_zero_world_forced_failure_case_count": 5,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
        "current_worker_receipt": worker,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
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
    contract, published = validate_sources()
    if args.core_library is None:
        print(
            SOURCE_MARKER,
            json.dumps(
                {
                    "gate_id": "QSDK-R24D99",
                    "ok": True,
                    "published": published,
                    "qualified_physical_path_count": len(
                        contract["qualified_physical_paths"]
                    ),
                    "current_zero_world_worker_count": 1,
                    "historical_closure_audits_executed_count": 0,
                },
                sort_keys=True,
            ),
        )
        return 0
    require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
    print(json.dumps(run_preflight(contract), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ClosureAuditError, controls.ControlError, OSError, KeyError, TypeError, ValueError) as error:
        print(f"{SOURCE_MARKER}_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
