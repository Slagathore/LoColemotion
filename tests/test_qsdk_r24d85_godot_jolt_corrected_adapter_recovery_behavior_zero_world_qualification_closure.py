#!/usr/bin/env python3
"""Audit the compact R85 corrected-adapter behavior qualification closure."""

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
    "sdk/recovery/r24d85_godot_jolt_corrected_adapter_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "eeca7cacd0cdda66b2448a96698a12a7541a6d75"
STATUS = (
    "closed_complete_zero_world_corrected_adapter_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)
PREDECESSOR_STATUS = (
    "closed_valid_complete_corrected_adapter_production_route_ghost_passed_"
    "distinct_r24d85_behavior_successor_required"
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
    "sha256:99f5f0d2fe16876b2a739504e7ba8253ece233f27fec8192c39fa1b6cb33c4d1"
)


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d85_godot_jolt_corrected_adapter_"
                "recovery_behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D85",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R85 behavior pair: isolate corrected "
                "adapter"
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
                "sporespore_qsdk_r24d85_godot_jolt_corrected_adapter_"
                "recovery_behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d85_godot_jolt_corrected_adapter_"
                "recovery_behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d85-godot-jolt-corrected-adapter-recovery-behavior-"
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
                    "QSDK_R24D85_GODOT_JOLT_CORRECTED_ADAPTER_RECOVERY_"
                    "BEHAVIOR_SOURCE_PASS"
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
                "prospective_corrected_adapter_recovery_behavior_complete_"
                "zero_world_qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "controlled_change.r81_valid_finite_behavior_negative_bound": True,
            "controlled_change.r84_valid_complete_corrected_production_route_bound": True,
            "controlled_change.r81_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r81_portable_recovery_controller_changed": False,
            "controlled_change.r81_portable_recovery_evaluator_changed": False,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "controlled_change.published_closure_authorization_control_required": False,
            "finite_behavior_question.seed": 278151771,
            "finite_behavior_question.seed_sha256": SEED_SHA256,
            "finite_behavior_question.held_out": False,
            "finite_behavior_question.arm_count": 2,
            "finite_behavior_question.maximum_world_build_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
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
            "source_inventory_count": 63,
            "authored_source_path_count": 10,
            "qualified_physical_path_count": 48,
            "bound_predecessor_count": 2,
            "unchanged_behavior_source_binding_count": 8,
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
            "qualification.unchanged_behavior_source_binding_count": 8,
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
            "decision.physical_ghost_authorized": True,
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
        "next_gate_id": "QSDK-R24D85",
        "r24d85_source_status": STATUS,
        "r24d85_source_commit": SOURCE,
        "r24d85_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d85_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d85_zero_world_closure_byte_length": len(closure_raw),
        "r24d85_official_qualification_attempt_count": 1,
        "r24d85_source_inventory_count": 63,
        "r24d85_authored_source_path_count": 10,
        "r24d85_qualified_physical_path_count": 48,
        "r24d85_bound_predecessor_count": 2,
        "r24d85_unchanged_behavior_source_binding_count": 8,
        "r24d85_production_worker_parse_count": 1,
        "r24d85_forced_supervisor_failure_control_count": 1,
        "r24d85_missing_physical_switch_refusal_count": 1,
        "r24d85_historical_closure_audits_executed_count": 0,
        "r24d85_bespoke_physical_canary_count": 0,
        "r24d85_full_seeded_ghost_count": 0,
        "r24d85_behavior_evaluator_invocation_count_during_qualification": 0,
        "r24d85_model_construction_count": 0,
        "r24d85_world_attempt_count": 0,
        "r24d85_world_build_count": 0,
        "r24d85_solver_step_count": 0,
        "r24d85_zero_world_gate_passed": True,
        "r24d85_zero_world_qualification_pending": False,
        "r24d85_zero_world_qualified": True,
        "r24d85_physical_execution_authorized": True,
        "r24d85_physical_attempt_consumed": False,
        "physical_execution_blocked_until_r24d85_zero_world_qualification": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d85_contract_path",
        expected=live_expected,
        prefix="LIVE_R85",
    )
    print(
        "QSDK_R24D85_GODOT_JOLT_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=63 physical_paths=48 checks=9/9 worker_parses=1 "
        "forced_failures=1 switch_refusals=1 historical_audits=0 canaries=0 "
        "full_seed_ghosts=0 models=0 worlds=0 steps=0 next=one_finite_pair "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    main()
