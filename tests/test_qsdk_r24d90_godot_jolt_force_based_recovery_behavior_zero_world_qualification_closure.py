#!/usr/bin/env python3
"""Audit R90's qualification and its retained pre-control reachability limit."""

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
    "sdk/recovery/r24d90_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "096cc62c41f3f413312b0fecb0d9715d16996ec7"
STATUS = (
    "closed_complete_zero_world_generic_authorization_dispatch_qualification_"
    "passed_precontrol_wrapper_mode_unreachable_no_control_or_physics_"
    "authorized_r91_required"
)
PREDECESSOR_STATUS = (
    "closed_invalid_prephysical_authorization_content_behavior_misclassified_"
    "as_ghost_no_world_opened_r90_required"
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
    "sha256:d0b6ae0f8eac299645e22176b53e20731b9d8a0ba677bacd6132feb9109e15c8"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"
WRAPPER = "sdk/run_qsdk_r24d90_godot_jolt_force_based_recovery_behavior.ps1"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"


def _mode_validate_set(relative: str) -> tuple[str, ...]:
    text = source_bytes(ROOT, SOURCE, relative).decode("utf-8")
    match = re.search(
        r"\[ValidateSet\((.*?)\)\]\s*\[string\]\$Mode",
        text,
        flags=re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"MODE_VALIDATE_SET:{relative}")
    return tuple(re.findall(r'"([^"]+)"', match.group(1)))


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d90_godot_jolt_force_based_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D90",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Declare R90 behavior: dispatch authority by "
                "question kind"
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
                "sporespore_qsdk_r24d90_godot_jolt_force_based_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d90_godot_jolt_force_based_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d90-godot-jolt-force-based-recovery-behavior-"
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
                    "QSDK_R24D90_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "complete_active_recovery_population_has_transport_stable_"
                    "command_identity ... ok"
                ),
                "production_preflight.log": (
                    '"direct_authorization_dispatch_truth_table_case_count": 5'
                ),
            },
            physical_question_declared=True,
        )
    )

    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_generic_authorization_dispatch_recovery_behavior_"
                "complete_zero_world_qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "controlled_change.r89_complete_zero_world_qualification_bound": True,
            "controlled_change.r89_prephysical_authorization_failure_bound": True,
            "controlled_change.r89_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.shared_direct_authorization_dispatch_changed": True,
            "controlled_change.published_closure_authorization_control_required": True,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "finite_behavior_question.seed": 278151771,
            "finite_behavior_question.seed_sha256": SEED_SHA256,
            "finite_behavior_question.maximum_world_build_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
            "behavior_execution_contract.actuator_mode": ACTUATOR_MODE,
            "critical_path_audit_policy.source_inventory_count": 65,
            "critical_path_audit_policy.qualified_physical_path_count": 50,
            "critical_path_audit_policy.authored_source_path_count": 11,
            "critical_path_audit_policy.direct_authorization_dispatch_truth_table_case_count": 5,
        },
        "CONTRACT",
    )
    exact(closure["bound_predecessors"], contract["bound_predecessors"], "PREDECESSORS")
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "actuator_mode": ACTUATOR_MODE,
            "source_inventory_count": 65,
            "authored_source_path_count": 11,
            "qualified_physical_path_count": 50,
            "bound_predecessor_count": 2,
            "unchanged_behavior_semantics_binding_count": 8,
            "direct_authorization_dispatch_truth_table_case_count": 5,
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
            "qualification.source_manifest_entry_count": 65,
            "qualification.source_inventory_count": 65,
            "qualification.authored_source_path_count": 11,
            "qualification.qualified_physical_path_count": 50,
            "qualification.direct_authorization_dispatch_truth_table_case_count": 5,
            "qualification.production_worker_parse_count": 1,
            "qualification.published_closure_authorization_control_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "runtime_identity_projection.actuator_mode": ACTUATOR_MODE,
            "post_qualification_reachability_diagnosis.required_authorization_control_mode_present": False,
            "post_qualification_reachability_diagnosis.shared_supervisor_authorization_control_mode_present": True,
            "post_qualification_reachability_diagnosis.authorization_control_receipt_count": 0,
            "post_qualification_reachability_diagnosis.source_reusable_for_authorization_control": False,
            "decision.physical_ghost_authorized": False,
            "decision.physical_behavior_attempt_authorized": False,
            "decision.published_closure_authorization_control_authorized": False,
            "decision.distinct_r91_source_required": True,
            "decision.physical_attempted": False,
            "next_boundary.gate_id": "QSDK-R24D91",
            "next_boundary.physical_execution_authorized": False,
            "claim_boundary.official_zero_world_qualification_passed": True,
            "claim_boundary.published_closure_authorization_control_reachable": False,
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
    wrapper_modes = _mode_validate_set(WRAPPER)
    supervisor_modes = _mode_validate_set(SUPERVISOR)
    exact(
        wrapper_modes,
        ("Preflight", "Physical", "ProjectionControl", "RuntimeIdentity"),
        "WRAPPER_MODES",
    )
    exact("AuthorizationControl" in supervisor_modes, True, "SUPERVISOR_MODE")
    exact(
        closure["post_qualification_reachability_diagnosis"]
        ["physical_runner_validate_set_values"],
        list(wrapper_modes),
        "WRAPPER_MODE_BINDING",
    )

    closure_raw = CLOSURE.read_bytes()
    live_expected = {
        "r24d90_source_status": STATUS,
        "r24d90_source_commit": SOURCE,
        "r24d90_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d90_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d90_zero_world_closure_byte_length": len(closure_raw),
        "r24d90_official_qualification_attempt_count": 1,
        "r24d90_source_inventory_count": 65,
        "r24d90_authored_source_path_count": 11,
        "r24d90_qualified_physical_path_count": 50,
        "r24d90_direct_authorization_dispatch_truth_table_case_count": 5,
        "r24d90_zero_world_qualification_pending": False,
        "r24d90_zero_world_qualified": True,
        "r24d90_published_authorization_control_reachable": False,
        "r24d90_published_authorization_control_pending": False,
        "r24d90_published_authorization_control_passed": False,
        "r24d90_physical_execution_authorized": False,
        "r24d90_physical_attempt_consumed": False,
        "r24d90_distinct_successor_required": True,
        "physical_execution_blocked_until_r24d90_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d90_published_authorization_control": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d90_contract_path",
        expected=live_expected,
        prefix="LIVE_R90",
    )
    print(
        "QSDK_R24D90_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=65 physical_paths=50 checks=9/9 dispatch=5 "
        "wrapper_control_reachable=false controls=0 models=0 worlds=0 steps=0 "
        "next=r91 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
