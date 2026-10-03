#!/usr/bin/env python3
"""Audit the compact R92 future-state-stable qualification closure."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "dd938b1cc63a8dfb5dd86cfc410203d5ca2a82a1"
STATUS = (
    "closed_complete_zero_world_future_state_stable_recovery_behavior_"
    "qualified_one_finite_paired_development_attempt_authorized_after_"
    "publication_control"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_wrapper_reachable_recovery_behavior_"
    "qualification_passed_future_state_audit_not_reusable_no_control_or_"
    "physics_authorized_r92_required"
)
CHECKS = (
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)
CONSOLE_PATH = (
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d71-godot-solved-contact-telemetry/development-runtime-v3/"
    "19dc32b39400-b20323fd08a7/"
    "godot.windows.editor.dev.x86_64.console.exe"
)
CONSOLE_SHA256 = (
    "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
)
SEED_SHA256 = (
    "sha256:34eb7610bcb6fbc07e1324f53ef374e37542df20a7bd0a5189900dd96e754389"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D92",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Declare R92 behavior: preserve control population"
            ),
            source_binding_names=(
                "contract",
                "source_audit",
                "shared_helper",
                "shared_controls",
                "authorization_helper",
                "physical_runner",
                "shared_supervisor",
                "production_worker",
                "qualification_runner",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d92-godot-jolt-force-based-recovery-behavior-"
                "qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(
                {
                    "path": "sdk/python/test_ctypes_smoke.py",
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_"
                        "materialization"
                    ),
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
                {
                    "path": (
                        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_"
                        "behavior.gd"
                    ),
                    "cause": "windows_checkout_crlf_materialization",
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/crlf attr/text eol=lf",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D92_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "complete_active_recovery_population_has_transport_stable_"
                    "command_identity ... ok"
                ),
                "production_preflight.log": (
                    '"authorization_control_receipt_population_unchanged": true'
                ),
            },
            physical_question_declared=True,
        )
    )

    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_future_state_stable_authorization_control_"
                "reachability_recovery_behavior_complete_zero_world_"
                "qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "controlled_change.r91_complete_zero_world_qualification_bound": True,
            "controlled_change.r91_future_state_audit_limit_bound": True,
            "controlled_change.r91_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r91_portable_recovery_controller_changed": False,
            "controlled_change.r91_portable_recovery_evaluator_changed": False,
            "controlled_change.r91_behavior_threshold_changed": False,
            "controlled_change.authorization_control_wrapper_global_absence_assertion_removed": True,
            "controlled_change.authorization_control_wrapper_before_after_receipt_population_assertion_added": True,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "finite_behavior_question.seed": 278151771,
            "finite_behavior_question.seed_sha256": SEED_SHA256,
            "finite_behavior_question.maximum_world_build_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
            "behavior_execution_contract.actuator_mode": ACTUATOR_MODE,
            "critical_path_audit_policy.source_inventory_count": 63,
            "critical_path_audit_policy.qualified_physical_path_count": 47,
            "critical_path_audit_policy.authored_source_path_count": 10,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
        },
        "CONTRACT",
    )
    exact(closure["bound_predecessors"], contract["bound_predecessors"], "PREDECESSORS")

    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "actuator_mode": ACTUATOR_MODE,
            "source_inventory_count": 63,
            "authored_source_path_count": 10,
            "qualified_physical_path_count": 47,
            "bound_predecessor_count": 1,
            "unchanged_behavior_semantics_binding_count": 8,
            "direct_authorization_dispatch_truth_table_case_count": 5,
            "authorization_control_wrapper_reachability_refusal_count": 1,
            "authorization_control_receipt_population_before_after_equality_count": 1,
            "authorization_control_wrapper_reachability_refusal_receipt.expected_terminal": "authorization_path_required",
            "authorization_control_wrapper_reachability_refusal_receipt.control_root_presence_before": False,
            "authorization_control_wrapper_reachability_refusal_receipt.control_root_presence_after": False,
            "authorization_control_wrapper_reachability_refusal_receipt.authorization_control_receipt_count_before": 0,
            "authorization_control_wrapper_reachability_refusal_receipt.authorization_control_receipt_count_after": 0,
            "authorization_control_wrapper_reachability_refusal_receipt.authorization_control_receipt_population_unchanged": True,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "production_wrapper_runtime_identity_receipt.selected_console_path": CONSOLE_PATH,
            "production_wrapper_runtime_identity_receipt.selected_console_sha256": CONSOLE_SHA256,
            "production_wrapper_runtime_identity_receipt.worker_parse_count": 1,
            "supervisor_projection_receipt.status": "forced_failure_projection_control",
            "missing_physical_switch_refusal_receipt.refusal_count": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        },
        "PREFLIGHT",
    )

    verify_exact_paths(
        closure,
        {
            "qualification.check_count": len(CHECKS),
            "qualification.checks_passed": len(CHECKS),
            "qualification.source_manifest_entry_count": 63,
            "qualification.source_inventory_count": 63,
            "qualification.authored_source_path_count": 10,
            "qualification.qualified_physical_path_count": 47,
            "qualification.bound_predecessor_count": 1,
            "qualification.unchanged_behavior_semantics_binding_count": 8,
            "qualification.direct_authorization_dispatch_truth_table_case_count": 5,
            "qualification.authorization_control_wrapper_reachability_refusal_count": 1,
            "qualification.authorization_control_receipt_population_before_after_equality_count": 1,
            "qualification.production_worker_parse_count": 1,
            "qualification.forced_supervisor_failure_control_count": 1,
            "qualification.missing_physical_switch_refusal_count": 1,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "decision.physical_ghost_authorized": False,
            "decision.physical_behavior_attempt_authorized": True,
            "decision.published_closure_authorization_control_required": True,
            "decision.published_closure_authorization_control_authorized": True,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.maximum_outer_solver_steps_per_arm": 1200,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.physical_attempted": False,
            "next_boundary.complete_zero_world_gate_passed": True,
            "next_boundary.published_closure_authorization_control_passed": False,
            "next_boundary.physical_execution_authorized": False,
            "claim_boundary.future_state_stable_source_preflight_implemented": True,
            "claim_boundary.physical_execution_authorized_now": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected_authorization = dict(contract["physical_authorization_projection"])
    expected_authorization.update(
        {
            "source_freeze_commit": SOURCE,
            "zero_world_qualification_passed": True,
            "physical_execution_authorized": True,
        }
    )
    exact(
        closure["physical_authorization"],
        expected_authorization,
        "PHYSICAL_AUTHORIZATION",
    )

    reachability = preflight[
        "authorization_control_wrapper_reachability_refusal_receipt"
    ]
    keys = tuple(closure["future_state_stable_reachability_observation"])
    exact(
        closure["future_state_stable_reachability_observation"],
        {key: reachability[key] for key in keys},
        "FUTURE_STATE_REACHABILITY",
    )

    closure_raw = CLOSURE.read_bytes()
    live_expected = {
        "r24d92_source_commit": SOURCE,
        "r24d92_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d92_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d92_zero_world_closure_byte_length": len(closure_raw),
        "r24d92_official_qualification_attempt_count": 1,
        "r24d92_source_inventory_count": 63,
        "r24d92_authored_source_path_count": 10,
        "r24d92_qualified_physical_path_count": 47,
        "r24d92_direct_authorization_dispatch_truth_table_case_count": 5,
        "r24d92_wrapper_reachability_refusal_count": 1,
        "r24d92_receipt_population_before_after_equality_count": 1,
        "r24d92_future_state_stable_source_preflight": True,
        "r24d92_published_authorization_control_reachable": True,
        "r24d92_zero_world_qualification_pending": False,
        "r24d92_zero_world_qualified": True,
        "physical_execution_blocked_until_r24d92_zero_world_qualification": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d92_contract_path",
        expected=live_expected,
        prefix="LIVE_R92",
    )
    print(
        "QSDK_R24D92_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=63 physical_paths=47 checks=9/9 dispatch=5 "
        "wrapper_refusals=1 population_equalities=1 controls=0 models=0 "
        "worlds=0 steps=0 next=publication_control sdk1=11/20"
    )


if __name__ == "__main__":
    main()
