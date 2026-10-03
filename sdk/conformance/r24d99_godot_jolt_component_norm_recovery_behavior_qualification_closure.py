#!/usr/bin/env python3
"""Publication-only R99 qualification closure audit.

This audit is deliberately outside R99's qualified physical path population.
The physical supervisor continues to execute the byte-exact source audit that
passed qualification; publication and retained-evidence checks cannot create
source drift in that preflight dependency.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    load,
    require,
    source_bytes,
    verify_bound_source_markers,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_supervised_bounded_ghost_attempt,
)

SOURCE_COMMIT = "9e00a9ac9c3f22260ee98ab587cbc3ba7bee9ebb"
PHYSICAL_SOURCE_COMMIT = "7c5338347513d9ee42f11a671185b1c8629ddc36"
SOURCE_AUDIT = (
    "sdk/conformance/r24d99_godot_jolt_component_norm_recovery_behavior.py"
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
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior.ps1"
)
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_behavior_"
    "zero_world_qualification_closure_v1"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_component_norm_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_nested_guarded_recovery_behavior_no_"
    "feasible_parent_scale_r99_required"
)
SEED_SHA256 = (
    "sha256:f1446a1853e3d6886e96232e80384be334bd2607fed79ad942fe0dc19e118a6d"
)
CLOSURE_RAW_SHA256 = (
    "sha256:ac3a1db55ad5af2eb0b054835c407c6175d8284a7440d7b87ce707f13a834515"
)
CLOSURE_BYTE_LENGTH = 19770
PHYSICAL_CLOSED_STATUS = (
    "closed_consumed_invalid_incomplete_component_norm_recovery_behavior_"
    "guard_refinement_failed_r100_required"
)
PHYSICAL_CLOSURE_RAW_SHA256 = (
    "sha256:40c5d3eeb2836d23523d9460736846de4c4103b405ab320932a8cf203320b464"
)
PHYSICAL_CLOSURE_BYTE_LENGTH = 12632
MARKER = "QSDK_R24D99_GODOT_JOLT_COMPONENT_NORM_RECOVERY_BEHAVIOR_CLOSURE_PASS"


def _validate() -> tuple[dict[str, Any], dict[str, Any]]:
    closure_raw = CLOSURE.read_bytes()
    require(
        len(closure_raw) == CLOSURE_BYTE_LENGTH
        and "sha256:" + hashlib.sha256(closure_raw).hexdigest()
        == CLOSURE_RAW_SHA256,
        "PUBLISHED_CLOSURE_RAW",
    )
    checkout_metadata = tuple(
        {
            "path": path,
            "cause": "existing_windows_checkout_mixed_line_ending_materialization",
            "git_attribute": "text eol=lf",
            "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
        }
        for path in (
            "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
            "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
            "sdk/python/test_ctypes_smoke.py",
            "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd",
        )
    )
    closure, frozen_contract, _receipt, _preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=CLOSURE_SCHEMA,
            gate_id="QSDK-R24D99",
            closure_status=QUALIFIED_STATUS,
            source_commit=SOURCE_COMMIT,
            source_subject=(
                "[recovery/core] Repair R99 qualifier: retain source manifest failures"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "shared_qualifier",
                "physical_runner",
                "shared_supervisor",
                "production_worker",
                "current_zero_world_worker",
                "qualification_runner",
                "first_qualification_failure",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d99-godot-jolt-component-norm-recovery-behavior-"
                "qualification-"
            ),
            expected_checks=(
                "source_manifest_frozen",
                "core_dynamic_library_rebuilt",
                "core_targeted_tests_passed",
                "godot_adapter_binding_check_passed",
                "godot_adapter_debug_build_passed",
                "python_binding_smoke_passed",
                "versioning_conformance_passed",
                "source_contract_audit_passed",
                "production_preflight_passed",
                "worktree_unchanged",
            ),
            checkout_only_metadata=checkout_metadata,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D99_GODOT_JOLT_COMPONENT_NORM_RECOVERY_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
                "production_preflight.log": (
                    "godot_vector3_components_widened_to_float64_"
                    "euclidean_squared_norm_v1"
                ),
            },
            physical_question_declared=True,
        )
    )
    require(
        isinstance(frozen_contract["source_inventory"], list)
        and len(frozen_contract["source_inventory"])
        == len(set(frozen_contract["source_inventory"]))
        == 65,
        "FROZEN_CONTRACT_SOURCE_INVENTORY",
    )
    frozen_source_audit = source_bytes(ROOT, SOURCE_COMMIT, SOURCE_AUDIT)
    require(
        source_bytes(ROOT, PHYSICAL_SOURCE_COMMIT, SOURCE_AUDIT)
        == frozen_source_audit,
        "PHYSICAL_INVOCATION_SOURCE_AUDIT_NOT_BYTE_EXACT",
    )

    qualified_paths = tuple(str(path) for path in frozen_contract["qualified_physical_paths"])
    require(len(qualified_paths) == len(set(qualified_paths)) == 47, "QUALIFIED_PATHS")
    drift = subprocess.run(
        [
            "git",
            "diff",
            "--quiet",
            SOURCE_COMMIT,
            PHYSICAL_SOURCE_COMMIT,
            "--",
            *qualified_paths,
        ],
        cwd=ROOT,
        check=False,
    )
    require(drift.returncode == 0, "PHYSICAL_INVOCATION_QUALIFIED_SOURCE_DRIFT")

    bound = {
        path: source_bytes(ROOT, SOURCE_COMMIT, path)
        for path in (
            "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1",
            "sdk/physical_authorization_projection.ps1",
        )
    }
    verify_bound_source_markers(
        bound,
        {
            "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1": (
                "Test-SporeSporeDirectQuestionAuthorization",
                "closure.decision.maximum_world_build_count",
                "closure.decision.physics_ticks_per_second",
                "closure.decision.outer_step_duration_s",
                "closure.decision.seed_sha256",
                "qualified_physical_source_drift",
            ),
            "sdk/physical_authorization_projection.ps1": (
                '$PhysicalQuestionKind -ceq "behavior_development"',
                '$decision["physical_behavior_attempt_authorized"]',
            ),
        },
        "DIRECT_AUTHORIZATION_CONSUMER",
    )
    verify_exact_paths(
        closure,
        {
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "qualification_history.official_attempt_count_across_sources": 2,
            "qualification_history.valid_complete_attempt_count": 1,
            "qualification_history.invalid_or_incomplete_attempt_count": 1,
            "qualification_history.same_source_retry_occurred": False,
            "qualification.check_count": 10,
            "qualification.checks_passed": 10,
            "qualification.source_inventory_count": 65,
            "qualification.qualified_physical_path_count": 47,
            "qualification.current_zero_world_positive_case_count": 8,
            "qualification.current_zero_world_forced_failure_case_count": 5,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "publication_repair.prior_publication_commit": (
                "25e7e5ce694bb96df6a8a9b01066e7716d1f2456"
            ),
            "publication_repair.physical_attempt_count_before_repair": 0,
            "qualified_path_drift_repair.detected_from_live_commit": (
                "fdd2e770cb12652fb0e97bbdd0382f3f8a5b66da"
            ),
            "qualified_path_drift_repair.changed_qualified_path_count": 1,
            "qualified_path_drift_repair.changed_qualified_path": SOURCE_AUDIT,
            "qualified_path_drift_repair.physical_attempt_count_before_detection": 0,
            "qualified_path_drift_repair.world_attempt_count_before_detection": 0,
            "qualified_path_drift_repair.solver_step_count_before_detection": 0,
            "qualified_path_drift_repair.restored_source_audit_raw_sha256": (
                "sha256:97f947e8e3c858683de0a3e32099f9ff2482d2c50a85859a0ef8664c426c287a"
            ),
            "qualified_path_drift_repair.qualified_source_changed_by_resolution": False,
            "qualified_path_drift_repair.qualification_result_changed": False,
            "qualified_path_drift_repair.physical_question_changed": False,
            "decision.physical_execution_authorized": True,
            "decision.physical_behavior_attempt_authorized": True,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.physics_ticks_per_second": 120,
            "decision.outer_step_duration_s": 1.0 / 120.0,
            "decision.seed": 278151771,
            "decision.seed_sha256": SEED_SHA256,
            "decision.held_out": False,
            "decision.physical_result_observed": False,
            "decision.prone_to_standing_claimed": False,
            "next_boundary.maximum_world_attempt_count": 2,
            "next_boundary.maximum_outer_solver_steps": 2400,
            "next_boundary.same_identity_rerun_permitted": False,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "closure_audit_path": (
                "sdk/conformance/r24d99_godot_jolt_component_norm_recovery_"
                "behavior_qualification_closure.py"
            ),
        },
        "PUBLISHED_CLOSURE",
    )
    physical_closure_raw = PHYSICAL_CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    require(
        len(physical_closure_raw) == PHYSICAL_CLOSURE_BYTE_LENGTH
        and "sha256:" + hashlib.sha256(physical_closure_raw).hexdigest()
        == PHYSICAL_CLOSURE_RAW_SHA256,
        "PHYSICAL_CLOSURE_RAW",
    )
    physical_closure = load(PHYSICAL_CLOSURE)
    physical = physical_closure["physical_attempt"]
    retained = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D99",
        source_commit=PHYSICAL_SOURCE_COMMIT,
        status="invalid_or_incomplete_behavior_development",
        schemas=physical["schemas"],
        raw_count_keys=(
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "held_out_cell_access_count",
        ),
    )
    verify_exact_paths(
        physical_closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d99_godot_jolt_component_norm_recovery_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D99",
            "closure_status": PHYSICAL_CLOSED_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "source.commit": PHYSICAL_SOURCE_COMMIT,
            "source.qualification_source_commit": SOURCE_COMMIT,
            "source.qualified_physical_path_count": 47,
            "source.qualified_physical_source_drift_count_at_physical_start": 0,
            "qualification_authority.raw_sha256_at_physical_start": (
                CLOSURE_RAW_SHA256
            ),
            "qualification_authority.byte_length_at_physical_start": (
                CLOSURE_BYTE_LENGTH
            ),
            "physical_attempt.attempt_count_for_exact_source_and_gate": 1,
            "physical_attempt.attempt_identity_consumed": True,
            "physical_attempt.model_construction_attempt_count": 1,
            "physical_attempt.model_construction_count": 1,
            "physical_attempt.world_attempt_count": 1,
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 33,
            "physical_attempt.behavior_evaluator_invocation_count": 0,
            "physical_attempt.native_engine_health_passed": True,
            "physical_attempt.physics_failure_is_valid_evidence": True,
            "physical_attempt.same_identity_rerun_permitted": False,
            "observed_failure.top_level_failure_code": (
                "QSDK_R24D99_BEHAVIOR_COMMAND_APPLICATION_FAILED"
            ),
            "observed_failure.route_failure_code": (
                "QSDK_R24D94_GUARDED_PAIR_PROJECTION_INVALID:3"
            ),
            "observed_failure.nested_projection_failure_code": (
                "QSDK_R24D99_NESTED_PAIR_TARGET_PROJECTION_FAILED"
            ),
            "observed_failure.guard_failure_code": (
                "QSDK_R24D99_GUARD_REFINEMENT_FAILED:3"
            ),
            "observed_failure.guard_failure_actuator_index": 3,
            "observed_failure.guard_failure_detail_retained": False,
            "observed_failure.specific_failed_refinement_predicate_established": False,
            "observed_failure.body_impulse_write_count": 6,
            "observed_failure.native_angular_velocity_readback_count": 15,
            "observed_failure.candidate_arm_completed_prefix_step_count": 33,
            "observed_failure.candidate_arm_in_run_invariant_receipt_count": 33,
            "observed_failure.candidate_arm_all_in_run_physical_invariants_passed": True,
            "observed_failure.matched_zero_arm_started": False,
            "observed_failure.behavior_evaluator_invoked": False,
            "interpretation.harness_or_integration_failure_established": False,
            "interpretation.component_norm_guard_refinement_terminal_failure_established": True,
            "interpretation.exact_refinement_predicate_cause_established": False,
            "interpretation.complete_behavior_result_established": False,
            "interpretation.scientific_behavior_negative_established": False,
            "interpretation.prone_to_standing_success_established": False,
            "decision.behavior_attempt_consumed_for_exact_source": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "decision.valid_complete_behavior_result": False,
            "decision.behavior_negative_accepted_for_inference": False,
            "decision.guard_refinement_failure_requires_distinct_successor": True,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": "QSDK-R24D100",
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.r24d99_same_identity_rerun_permitted": False,
            "claim_boundary.physical_attempted": True,
            "claim_boundary.physical_attempt_consumed": True,
            "claim_boundary.valid_complete_behavior_result": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
        },
        "PHYSICAL_CLOSURE",
    )
    verify_exact_paths(
        retained["raw"],
        {
            "failure_code": "QSDK_R24D99_BEHAVIOR_COMMAND_APPLICATION_FAILED",
            "detail.failure_code": "QSDK_R24D94_GUARDED_PAIR_PROJECTION_INVALID:3",
            "detail.detail.failure_code": (
                "QSDK_R24D99_NESTED_PAIR_TARGET_PROJECTION_FAILED"
            ),
            "detail.detail.detail.predecessor_projection_failure.failure_code": (
                "QSDK_R24D99_GUARD_REFINEMENT_FAILED:3"
            ),
            "detail.body_impulse_write_count": 6,
            "detail.native_angular_velocity_readback_count": 15,
            "physics_failure_is_valid_evidence": True,
            "arm_execution_summary.completed_arm_count": 1,
            "arm_execution_summary.total_solver_step_count": 33,
        },
        "PHYSICAL_RAW",
    )
    arm_summaries = retained["raw"]["arm_execution_summary"]["ordered_arm_summaries"]
    require(
        isinstance(arm_summaries, list) and len(arm_summaries) == 1,
        "PHYSICAL_ARM_SUMMARY_COUNT",
    )
    verify_exact_paths(
        arm_summaries[0],
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 33,
            "native_solver_step_count": 33,
            "all_in_run_physical_invariants_passed": True,
            "in_run_invariant_receipt_count": 33,
            "final_phase": "establish_distal_support",
        },
        "PHYSICAL_CANDIDATE_ARM",
    )
    require(
        retained["raw"]["detail"]["detail"]["detail"]
        ["predecessor_projection_failure"]["detail"]
        == {},
        "PHYSICAL_FAILURE_DETAIL_NOT_EMPTY",
    )
    verify_exact_paths(
        retained["terminal"],
        {
            "behavior_development_completed": False,
            "worker.engine_health.passed": True,
            "worker.engine_health.stderr_raw_byte_length": 0,
            "worker.engine_health.engine_error_line_count": 0,
            "worker.engine_health.fatal_diagnostic_line_count": 0,
            "recovery_success_observed": False,
            "prone_to_standing_claimed": False,
        },
        "PHYSICAL_TERMINAL",
    )
    require(
        b"QSDK_R24D99_PHYSICAL_IDENTITY_CONSUMED"
        in PHYSICAL_RUNNER.read_bytes(),
        "PHYSICAL_IDENTITY_REVOCATION_MISSING",
    )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d99_contract_path",
        expected={
            "r24d99_source_status": PHYSICAL_CLOSED_STATUS,
            "r24d99_source_commit": SOURCE_COMMIT,
            "r24d99_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d99_zero_world_closure_raw_sha256": CLOSURE_RAW_SHA256,
            "r24d99_zero_world_closure_byte_length": CLOSURE_BYTE_LENGTH,
            "r24d99_direct_authorization_projection_repaired": True,
            "r24d99_qualified_path_drift_detected_before_physics": True,
            "r24d99_qualified_path_drift_count": 1,
            "r24d99_frozen_source_audit_restored": True,
            "r24d99_publication_audit_path": (
                "sdk/conformance/r24d99_godot_jolt_component_norm_recovery_"
                "behavior_qualification_closure.py"
            ),
            "r24d99_physical_attempt_count_before_source_audit_restoration": 0,
            "r24d99_zero_world_qualified": True,
            "r24d99_physical_execution_authorized": False,
            "r24d99_physical_execution_blocked": True,
            "r24d99_physical_attempt_consumed": True,
            "r24d99_physical_attempt_disposition": (
                "invalid_or_incomplete_behavior_development"
            ),
            "r24d99_behavior_invalid_closure_path": (
                PHYSICAL_CLOSURE.relative_to(ROOT).as_posix()
            ),
            "r24d99_behavior_invalid_closure_raw_sha256": (
                PHYSICAL_CLOSURE_RAW_SHA256
            ),
            "r24d99_behavior_invalid_closure_byte_length": (
                PHYSICAL_CLOSURE_BYTE_LENGTH
            ),
            "r24d99_behavior_evidence_root": (
                "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
                "qsdk-r24d99-godot-jolt-component-norm-recovery-behavior/"
                "20260831T190154008Z-7c533834-99ac2229"
            ),
            "r24d99_invocation_source_commit": PHYSICAL_SOURCE_COMMIT,
            "r24d99_attempt_id": "99ac222940744b1d9f9aaf0289b0774e",
            "r24d99_observed_model_construction_count": 1,
            "r24d99_observed_world_attempt_count": 1,
            "r24d99_observed_world_build_count": 1,
            "r24d99_observed_solver_step_count": 33,
            "r24d99_observed_behavior_evaluator_invocation_count": 0,
            "r24d99_observed_in_run_invariant_receipt_count": 33,
            "r24d99_body_impulse_write_count": 6,
            "r24d99_native_angular_velocity_readback_count": 15,
            "r24d99_top_level_failure_code": (
                "QSDK_R24D99_BEHAVIOR_COMMAND_APPLICATION_FAILED"
            ),
            "r24d99_route_failure_code": (
                "QSDK_R24D94_GUARDED_PAIR_PROJECTION_INVALID:3"
            ),
            "r24d99_nested_projection_failure_code": (
                "QSDK_R24D99_NESTED_PAIR_TARGET_PROJECTION_FAILED"
            ),
            "r24d99_guard_failure_code": (
                "QSDK_R24D99_GUARD_REFINEMENT_FAILED:3"
            ),
            "r24d99_guard_failure_actuator_index": 3,
            "r24d99_guard_failure_detail_retained": False,
            "r24d99_specific_failed_refinement_predicate_established": False,
            "r24d99_native_engine_health_passed": True,
            "r24d99_completed_prefix_in_run_invariants_passed": True,
            "r24d99_physics_failure_is_valid_evidence": True,
            "r24d99_valid_complete_behavior_result": False,
            "r24d99_behavior_negative_accepted_for_inference": False,
            "r24d99_authorized_world_count": 0,
            "r24d99_maximum_outer_solver_steps": 0,
            "r24d99_same_identity_rerun_permitted": False,
            "r24d99_sdk1_milestone_advanced": False,
            "r24d100_distinct_successor_required": True,
            "physical_execution_blocked_until_r24d99_zero_world_qualification": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        prefix="LIVE_R99_PUBLICATION",
    )
    return closure, physical_closure


def main() -> int:
    try:
        closure, physical_closure = _validate()
    except (ClosureAuditError, KeyError, OSError, ValueError) as exc:
        print(f"{MARKER}_FAIL {exc}")
        return 1
    print(
        MARKER
        + " "
        + json.dumps(
            {
                "gate_id": closure["gate_id"],
                "ok": True,
                "qualified_physical_path_count": 47,
                "qualified_physical_source_drift_count": 0,
                "physical_attempt_count": 1,
                "world_attempt_count": 1,
                "solver_step_count": 33,
                "physical_status": physical_closure["physical_attempt"]["status"],
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
