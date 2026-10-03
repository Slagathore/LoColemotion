#!/usr/bin/env python3
"""Audit R91's wrapper-reachable recovery-behavior qualification closure."""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    sha256,
    source_bytes,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d91_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "90fcbd37b56466a6a2961cc61b9283eadf6c0101"
STATUS = (
    "closed_complete_zero_world_wrapper_reachable_recovery_behavior_"
    "qualification_passed_future_state_audit_not_reusable_no_control_or_"
    "physics_authorized_r92_required"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_generic_authorization_dispatch_qualification_"
    "passed_precontrol_wrapper_mode_unreachable_no_control_or_physics_"
    "authorized_r91_required"
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
    "sha256:83863edfdf6b22173c06da922784548f23f3a1350cea7340df7b8f2212ef6d2d"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"
WRAPPER = "sdk/run_qsdk_r24d91_godot_jolt_force_based_recovery_behavior.ps1"
SOURCE_AUDIT = "sdk/conformance/r24d91_godot_jolt_force_based_recovery_behavior.py"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"


def _mode_validate_set() -> tuple[str, ...]:
    text = source_bytes(ROOT, SOURCE, WRAPPER).decode("utf-8")
    match = re.search(
        r"\[ValidateSet\((.*?)\)\]\s*\[string\]\$Mode",
        text,
        flags=re.DOTALL,
    )
    if match is None:
        raise AssertionError("MODE_VALIDATE_SET")
    return tuple(re.findall(r'"([^"]+)"', match.group(1)))


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d91_godot_jolt_force_based_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D91",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Declare R91 behavior: expose publication control"
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
                "sporespore_qsdk_r24d91_godot_jolt_force_based_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d91_godot_jolt_force_based_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d91-godot-jolt-force-based-recovery-behavior-"
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
                    "QSDK_R24D91_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "complete_active_recovery_population_has_transport_stable_"
                    "command_identity ... ok"
                ),
                "production_preflight.log": (
                    '"authorization_control_wrapper_reachability_refusal_count": 1'
                ),
            },
            physical_question_declared=True,
        )
    )

    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_wrapper_authorization_control_reachability_"
                "recovery_behavior_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "question_class": "development",
            "controlled_change.r90_complete_zero_world_qualification_bound": True,
            "controlled_change.r90_precontrol_wrapper_mode_reachability_limit_bound": True,
            "controlled_change.r90_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r90_portable_recovery_controller_changed": False,
            "controlled_change.r90_portable_recovery_evaluator_changed": False,
            "controlled_change.r90_behavior_threshold_changed": False,
            "controlled_change.physical_wrapper_authorization_control_mode_added": True,
            "controlled_change.authorization_control_wrapper_reachability_refusal_added": True,
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
            "critical_path_audit_policy.qualified_physical_path_count": 47,
            "critical_path_audit_policy.authored_source_path_count": 10,
            "critical_path_audit_policy.bound_predecessor_count": 1,
            "critical_path_audit_policy.authorization_control_wrapper_reachability_refusal_count": 1,
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
            "authorization_control_wrapper_reachability_refusal_receipt.expected_terminal": "authorization_path_required",
            "authorization_control_wrapper_reachability_refusal_receipt.expected_terminal_observed": True,
            "authorization_control_wrapper_reachability_refusal_receipt.powershell_parameter_binding_failure_observed": False,
            "authorization_control_wrapper_reachability_refusal_receipt.operation_lock_acquired": False,
            "authorization_control_wrapper_reachability_refusal_receipt.authorization_control_receipt_count": 0,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "published_closure_authorization_control_count": 0,
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
            "qualification.qualified_physical_path_count": 47,
            "qualification.bound_predecessor_count": 1,
            "qualification.unchanged_behavior_semantics_binding_count": 8,
            "qualification.direct_authorization_dispatch_truth_table_case_count": 5,
            "qualification.authorization_control_wrapper_reachability_refusal_count": 1,
            "qualification.production_worker_parse_count": 1,
            "qualification.published_closure_authorization_control_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "runtime_identity_projection.actuator_mode": ACTUATOR_MODE,
            "decision.physical_ghost_authorized": False,
            "post_qualification_future_state_diagnosis.source_audit_requires_control_root_absent": True,
            "post_qualification_future_state_diagnosis.physical_supervisor_runs_source_preflight_before_authorization_control_receipt_lookup": True,
            "post_qualification_future_state_diagnosis.future_physical_preflight_would_reject_the_required_retained_control_root": True,
            "post_qualification_future_state_diagnosis.authorization_control_receipt_count": 0,
            "post_qualification_future_state_diagnosis.source_reusable_for_published_authorization_control_and_following_physical_preflight": False,
            "decision.physical_behavior_attempt_authorized": False,
            "decision.published_closure_authorization_control_authorized": False,
            "decision.published_closure_authorization_control_attempted": False,
            "decision.distinct_r92_source_required": True,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.maximum_outer_solver_steps_per_arm": 1200,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.physical_attempted": False,
            "next_boundary.gate_id": "QSDK-R24D92",
            "next_boundary.complete_zero_world_gate_passed": False,
            "next_boundary.physical_execution_authorized": False,
            "claim_boundary.authorization_control_wrapper_reachability_refusal_passed": True,
            "claim_boundary.future_state_stable_source_preflight_proven": False,
            "claim_boundary.published_closure_authorization_control_passed": False,
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
            "physical_execution_authorized": False,
        }
    )
    exact(closure["physical_authorization"], expected_authorization, "AUTHORIZATION")
    exact(
        _mode_validate_set(),
        (
            "Preflight",
            "Physical",
            "ProjectionControl",
            "AuthorizationControl",
            "RuntimeIdentity",
        ),
        "WRAPPER_MODES",
    )
    source_audit = source_bytes(ROOT, SOURCE, SOURCE_AUDIT).decode("utf-8")
    exact(
        'require(not control_root.exists(), "PREEXISTING_R91_AUTHORIZATION_CONTROL_ROOT")'
        in source_audit,
        True,
        "GLOBAL_CONTROL_ROOT_ABSENCE_ASSERTION",
    )
    supervisor = source_bytes(ROOT, SOURCE, SUPERVISOR).decode("utf-8")
    physical = supervisor.split("function Invoke-R57Physical", 1)[1]
    exact(
        physical.find("$preflight = Invoke-R57Preflight")
        < physical.find("Find-R57AuthorizationControlReceipts"),
        True,
        "PHYSICAL_PREFLIGHT_PRECEDES_CONTROL_LOOKUP",
    )

    closure_raw = CLOSURE.read_bytes()
    live_expected = {
        "r24d91_source_status": STATUS,
        "r24d91_source_commit": SOURCE,
        "r24d91_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d91_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d91_zero_world_closure_byte_length": len(closure_raw),
        "r24d91_official_qualification_attempt_count": 1,
        "r24d91_source_inventory_count": 63,
        "r24d91_authored_source_path_count": 10,
        "r24d91_qualified_physical_path_count": 47,
        "r24d91_direct_authorization_dispatch_truth_table_case_count": 5,
        "r24d91_wrapper_reachability_refusal_count": 1,
        "r24d91_zero_world_qualification_pending": False,
        "r24d91_zero_world_qualified": True,
        "r24d91_published_authorization_control_reachable": True,
        "r24d91_future_state_stable_source_preflight": False,
        "r24d91_published_authorization_control_pending": False,
        "r24d91_published_authorization_control_passed": False,
        "r24d91_physical_execution_authorized": False,
        "r24d91_physical_attempt_consumed": False,
        "r24d91_distinct_successor_required": True,
        "physical_execution_blocked_until_r24d91_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d91_published_authorization_control": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d91_contract_path",
        expected=live_expected,
        prefix="LIVE_R91",
    )
    print(
        "QSDK_R24D91_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=63 physical_paths=47 checks=9/9 dispatch=5 "
        "wrapper_refusals=1 controls=0 models=0 worlds=0 steps=0 "
        "next=r92 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
