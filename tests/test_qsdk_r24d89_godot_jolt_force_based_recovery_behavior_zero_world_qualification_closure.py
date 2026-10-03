#!/usr/bin/env python3
"""Audit the compact R89 force-based behavior qualification closure."""

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
    "sdk/recovery/r24d89_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "af3d8431558a58c28f71319a0a23a616d4702d03"
STATUS = (
    "closed_complete_zero_world_force_based_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)
PREDECESSOR_STATUS = (
    "closed_valid_complete_force_based_recovery_production_route_ghost_"
    "passed_distinct_r24d89_behavior_successor_required"
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
    "sha256:d17757ccf7bacc8bd0aade6d9d93886c5ccb33e8883606c5f9242cd080c044b5"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d89_godot_jolt_force_based_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D89",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R89 behavior: bind force-based "
                "prone-to-stand pair"
            ),
            source_binding_names=(
                "contract",
                "source_audit",
                "shared_helper",
                "shared_controls",
                "physical_runner",
                "shared_supervisor",
                "production_worker",
                "qualification_runner",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d89_godot_jolt_force_based_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d89_godot_jolt_force_based_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d89-godot-jolt-force-based-recovery-behavior-"
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
                    "QSDK_R24D89_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "complete_active_recovery_population_has_transport_stable_"
                    "command_identity ... ok"
                ),
                "production_preflight.log": '"production_worker_parse_count": 1',
            },
            physical_question_declared=True,
        )
    )

    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_force_based_recovery_behavior_complete_zero_world_"
                "qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "controlled_change.r85_valid_finite_behavior_negative_bound": True,
            "controlled_change.r88_valid_complete_force_based_production_route_bound": True,
            "controlled_change.r85_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r85_portable_recovery_controller_changed": False,
            "controlled_change.r85_portable_recovery_evaluator_changed": False,
            "controlled_change.r85_behavior_threshold_changed": False,
            "controlled_change.r87_force_based_actuator_mapping_selected": True,
            "controlled_change.r87_source_measured_work_mapping_selected": True,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "finite_behavior_question.seed": 278151771,
            "finite_behavior_question.seed_sha256": SEED_SHA256,
            "finite_behavior_question.held_out": False,
            "finite_behavior_question.arm_count": 2,
            "finite_behavior_question.maximum_world_build_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
            "behavior_execution_contract.actuator_mode": ACTUATOR_MODE,
            "critical_path_audit_policy.source_inventory_count": 63,
            "critical_path_audit_policy.qualified_physical_path_count": 48,
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
            "qualified_physical_path_count": 48,
            "bound_predecessor_count": 2,
            "unchanged_behavior_semantics_binding_count": 5,
            "current_zero_world_worker_count": 0,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "behavior_evaluator_invocation_count": 0,
            "production_wrapper_runtime_identity_receipt.selected_console_path": CONSOLE_PATH,
            "production_wrapper_runtime_identity_receipt.selected_console_sha256": CONSOLE_SHA256,
            "production_wrapper_runtime_identity_receipt.worker_parse_count": 1,
            "production_wrapper_runtime_identity_receipt.actuator_mode": ACTUATOR_MODE,
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
            "qualification.qualified_physical_path_count": 48,
            "qualification.bound_predecessor_count": 2,
            "qualification.unchanged_behavior_semantics_binding_count": 5,
            "qualification.production_worker_parse_count": 1,
            "qualification.forced_supervisor_failure_control_count": 1,
            "qualification.missing_physical_switch_refusal_count": 1,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.behavior_evaluator_invocation_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "runtime_identity_projection.actuator_mode": ACTUATOR_MODE,
            "decision.physical_ghost_authorized": False,
            "decision.physical_behavior_attempt_authorized": True,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.maximum_outer_solver_steps_per_arm": 1200,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.physical_attempted": False,
            "next_boundary.complete_zero_world_gate_passed": True,
            "next_boundary.physical_execution_authorized": True,
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

    closure_raw = CLOSURE.read_bytes()
    live_expected = {
        "r24d89_source_status": STATUS,
        "r24d89_source_commit": SOURCE,
        "r24d89_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d89_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d89_zero_world_closure_byte_length": len(closure_raw),
        "r24d89_official_qualification_attempt_count": 1,
        "r24d89_source_inventory_count": 63,
        "r24d89_authored_source_path_count": 10,
        "r24d89_qualified_physical_path_count": 48,
        "r24d89_bound_predecessor_count": 2,
        "r24d89_unchanged_behavior_semantics_binding_count": 5,
        "r24d89_production_worker_parse_count": 1,
        "r24d89_forced_supervisor_failure_control_count": 1,
        "r24d89_missing_physical_switch_refusal_count": 1,
        "r24d89_historical_closure_audits_executed_count": 0,
        "r24d89_bespoke_physical_canary_count": 0,
        "r24d89_full_seeded_ghost_count": 0,
        "r24d89_behavior_evaluator_invocation_count_during_qualification": 0,
        "r24d89_model_construction_count": 0,
        "r24d89_world_attempt_count": 0,
        "r24d89_world_build_count": 0,
        "r24d89_solver_step_count": 0,
        "r24d89_zero_world_gate_passed": True,
        "r24d89_zero_world_qualification_pending": False,
        "r24d89_zero_world_qualified": True,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d89_contract_path",
        expected=live_expected,
        prefix="LIVE_R89",
    )
    print(
        "QSDK_R24D89_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=63 physical_paths=48 checks=9/9 worker_parses=1 "
        "forced_failures=1 switch_refusals=1 historical_audits=0 canaries=0 "
        "full_seed_ghosts=0 models=0 worlds=0 steps=0 next=one_finite_pair "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    main()
