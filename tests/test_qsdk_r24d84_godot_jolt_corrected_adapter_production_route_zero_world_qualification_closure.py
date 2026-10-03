#!/usr/bin/env python3
"""Audit the compact R84 corrected production-route qualification closure."""

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
    "sdk/recovery/r24d84_godot_jolt_corrected_adapter_production_route_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "6bf1003ac2f0325df8eabe8ff33351ddeb9a1d1e"
STATUS = (
    "closed_complete_zero_world_corrected_adapter_production_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_adapter_semantics_qualified_physics_blocked_"
    "pending_distinct_route_successor"
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
    "sha256:251e7c2211988cbd57716b0cbd74f2852f395480321a398408be82d4fe230ac1"
)


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_"
                "production_route_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D84",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R84 route ghost: bind one world and "
                "two steps"
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
                "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_"
                "production_route_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_"
                "production_route_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d84-godot-jolt-corrected-adapter-production-route-"
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
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D84_GODOT_JOLT_CORRECTED_ADAPTER_PRODUCTION_"
                    "ROUTE_SOURCE_PASS"
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
                "prospective_corrected_adapter_production_route_complete_"
                "zero_world_qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": True,
            "controlled_change.r83_qualified_adapter_semantics_bound": True,
            "controlled_change.actual_production_world_builder_selected": True,
            "controlled_change.actual_production_route_selected": True,
            "controlled_change.existing_generic_two_step_worker_reused": True,
            "controlled_change.existing_serial_physical_supervisor_reused": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "route_ghost_question.seed": 622754850,
            "route_ghost_question.seed_sha256": SEED_SHA256,
            "route_ghost_question.held_out": False,
            "route_ghost_question.world_count": 1,
            "route_ghost_question.maximum_world_build_count": 1,
            "route_ghost_question.maximum_outer_solver_steps": 2,
            "route_ghost_question.minimum_completed_solver_steps_for_valid_route": 2,
            "route_ghost_question.behavior_evaluator_invocation_count": 0,
            "route_ghost_question.full_seeded_world_demo": False,
            "route_ghost_question.recovery_success_required": False,
            "critical_path_audit_policy.source_inventory_count": 62,
            "critical_path_audit_policy.qualified_physical_path_count": 47,
            "critical_path_audit_policy.current_zero_world_worker_count": 0,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "critical_path_audit_policy.bespoke_physical_canary_added_count": 0,
            "critical_path_audit_policy.full_seeded_ghost_count": 0,
            "physical_runner.published_closure_authorization_control_required": False,
            "physical_runner.direct_committed_closure_recheck_under_operation_lock_required": True,
            "physical_runner.qualified_physical_source_drift_check_required": True,
        },
        "CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "source_inventory_count": 62,
            "authored_source_path_count": 10,
            "qualified_physical_path_count": 47,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 0,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "r83_closure_audit_reexecution_count": 0,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "production_wrapper_runtime_identity_receipt.selected_console_path": CONSOLE_PATH,
            "production_wrapper_runtime_identity_receipt.selected_console_sha256": CONSOLE_SHA256,
            "production_wrapper_runtime_identity_receipt.selected_console_byte_length": 293376,
            "production_wrapper_runtime_identity_receipt.worker_parse_count": 1,
            "supervisor_projection_receipt.ok": False,
            "supervisor_projection_receipt.status": "forced_failure_projection_control",
            "missing_physical_switch_refusal_receipt.ok": True,
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
            "qualification.source_manifest_entry_count": 62,
            "qualification.source_inventory_count": 62,
            "qualification.authored_source_path_count": 10,
            "qualification.qualified_physical_path_count": 47,
            "qualification.bound_predecessor_count": 1,
            "qualification.current_zero_world_worker_count": 0,
            "qualification.production_worker_parse_count": 1,
            "qualification.forced_supervisor_failure_control_count": 1,
            "qualification.missing_physical_switch_refusal_count": 1,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "runtime_identity_projection.selected_console_byte_length": 293376,
            "decision.physical_ghost_authorized": True,
            "decision.published_closure_authorization_control_required": False,
            "decision.direct_committed_closure_recheck_required": True,
            "decision.maximum_world_build_count": 1,
            "decision.maximum_outer_solver_steps": 2,
            "decision.behavior_evaluator_invocation_count": 0,
            "decision.physical_attempted": False,
            "next_boundary.complete_zero_world_gate_passed": True,
            "next_boundary.physical_execution_authorized": True,
            "next_boundary.maximum_physical_steps_authorized": 2,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
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
        "next_gate_id": "QSDK-R24D84",
        "r24d84_contract_path": (
            "sdk/recovery/r24d84_godot_jolt_corrected_adapter_"
            "production_route_contract_v1.json"
        ),
        "r24d84_source_status": STATUS,
        "r24d84_source_commit": SOURCE,
        "r24d84_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d84_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d84_zero_world_closure_byte_length": len(closure_raw),
        "r24d84_official_qualification_attempt_count": 1,
        "r24d84_source_inventory_count": 62,
        "r24d84_authored_source_path_count": 10,
        "r24d84_qualified_physical_path_count": 47,
        "r24d84_production_worker_parse_count": 1,
        "r24d84_forced_supervisor_failure_control_count": 1,
        "r24d84_missing_physical_switch_refusal_count": 1,
        "r24d84_historical_closure_audits_executed_count": 0,
        "r24d84_model_construction_count": 0,
        "r24d84_world_attempt_count": 0,
        "r24d84_world_build_count": 0,
        "r24d84_solver_step_count": 0,
        "r24d84_zero_world_gate_passed": True,
        "r24d84_zero_world_qualification_pending": False,
        "r24d84_zero_world_qualified": True,
        "r24d84_physical_execution_authorized": True,
        "r24d84_physical_attempt_consumed": False,
        "physical_execution_blocked_until_r24d84_zero_world_qualification": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d84_contract_path",
        expected=live_expected,
        prefix="LIVE_R84",
    )
    print(
        "QSDK_R24D84_GODOT_JOLT_CORRECTED_ADAPTER_PRODUCTION_ROUTE_ZERO_WORLD_"
        "CLOSURE_PASS sources=62 physical_paths=47 checks=9/9 worker_parses=1 "
        "forced_failures=1 switch_refusals=1 historical_audits=0 canaries=0 "
        "full_seed_ghosts=0 models=0 worlds=0 steps=0 next=one_world_two_steps "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    main()
