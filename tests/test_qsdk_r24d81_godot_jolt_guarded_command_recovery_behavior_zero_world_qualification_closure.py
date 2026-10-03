#!/usr/bin/env python3
"""Audit the compact R81 path-role-safe recovery qualification closure."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    records_with_key,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "6abcff4fd2542389c7d741512d265f6e5eb561bb"
STATUS = (
    "closed_complete_zero_world_guarded_command_recovery_behavior_qualified_"
    "one_paired_development_attempt_authorized_after_publication_control"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_finite_recovery_command_transport_population_"
    "qualified_physics_blocked_pending_distinct_successor"
)
R80_INVALID_STATUS = (
    "closed_consumed_invalid_incomplete_published_closure_control_"
    "qualified_physical_path_role_conflict"
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
POPULATION_SHA256 = (
    "sha256:0285fcd60dd739084fa6131d58ce7d389d556a9da1d4dae1239d98293228dc46"
)


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d81_godot_jolt_guarded_command_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D81",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R81 path-role-safe recovery pair"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "qualification_runner",
                "physical_runner",
                "shared_supervisor",
                "command_population_worker",
                "behavior_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d81_godot_jolt_guarded_command_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d81_godot_jolt_guarded_command_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d81-godot-jolt-guarded-command-recovery-behavior-"
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
                    "QSDK_R24D81_GODOT_JOLT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
            },
            physical_question_declared=True,
        )
    )
    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": True,
            "controlled_change.distinct_physical_campaign_identity_added": True,
            "controlled_change.r79_guarded_command_transport_reused": True,
            "controlled_change.r80_positive_zero_world_qualification_bound": True,
            "controlled_change.r80_invalid_authorization_control_closure_bound": True,
            "controlled_change.publication_only_path_role_partition_added": True,
            "controlled_change.publication_only_paths_removed_from_qualified_physical_paths": 2,
            "controlled_change.guarded_target_projection_significant_decimal_digits": 13,
            "controlled_change.canonical_digest_significant_decimal_digits": 14,
            "controlled_change.portable_recovery_controller_changed_from_r80": False,
            "controlled_change.portable_recovery_evaluator_changed_from_r80": False,
            "controlled_change.behavior_threshold_changed_from_r80": False,
            "controlled_change.physical_envelope_changed_from_r80": False,
            "critical_path_audit_policy.focused_source_inventory_count": 76,
            "critical_path_audit_policy.qualified_physical_path_count": 59,
            "critical_path_audit_policy.current_zero_world_worker_count": 1,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "source_path_roles.publication_only_path_count": 2,
            "source_path_roles.qualified_physical_path_count": 59,
            "source_path_roles.overlap_count": 0,
            "ghost_and_canary_adequacy.full_seeded_physical_ghost_required": False,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
        },
        "CONTRACT",
    )
    exact(closure["bound_predecessors"], contract["bound_predecessors"], "PREDECESSORS")
    exact(
        closure["bound_predecessors"][0]["closure_status"],
        R80_INVALID_STATUS,
        "R80_INVALID_PREDECESSOR_STATUS",
    )
    exact(
        closure["bound_predecessors"][1]["closure_status"],
        PREDECESSOR_STATUS,
        "R79_PREDECESSOR_STATUS",
    )
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "focused_source_inventory_count": 76,
            "authored_source_path_count": 11,
            "qualified_physical_path_count": 59,
            "bound_predecessor_count": 2,
            "current_zero_world_worker_count": 1,
            "active_command_cell_count": 603,
            "application_pass_count": 603,
            "validated_command_count": 4824,
            "host_write_count": 4824,
            "host_readback_count": 4824,
            "digest_mismatch_count": 0,
            "forced_digest_failure_rejection_count": 1,
            "behavior_worker_parse_count": 1,
            "supervisor_forced_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_physical_ghost_count": 0,
            "published_closure_observed": 0,
            "command_population_receipt.unique_expected_digest_count": 362,
            "command_population_receipt.unique_recomputed_digest_count": 362,
            "command_population_receipt.population_sha256": POPULATION_SHA256,
            "command_population_receipt.forced_digest_failure_rejected": True,
            "command_population_receipt.forced_digest_failure_detail.host_write_count": 0,
            "production_wrapper_runtime_identity_receipt.selected_console_path": CONSOLE_PATH,
            "production_wrapper_runtime_identity_receipt.selected_console_sha256": CONSOLE_SHA256,
            "production_wrapper_runtime_identity_receipt.worker_parse_count": 1,
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
            "qualification.source_manifest_entry_count": 76,
            "qualification.focused_source_inventory_count": 76,
            "qualification.authored_source_path_count": 11,
            "qualification.qualified_physical_path_count": 59,
            "qualification.publication_only_path_count": 2,
            "qualification.path_role_overlap_count": 0,
            "qualification.bound_predecessor_count": 2,
            "qualification.current_zero_world_worker_count": 1,
            "qualification.active_command_cell_count": 603,
            "qualification.application_pass_count": 603,
            "qualification.validated_command_count": 4824,
            "qualification.host_write_count": 4824,
            "qualification.host_readback_count": 4824,
            "qualification.digest_mismatch_count": 0,
            "qualification.forced_digest_failure_rejection_count": 1,
            "qualification.behavior_worker_parse_count": 1,
            "qualification.supervisor_forced_failure_control_count": 1,
            "qualification.missing_physical_switch_refusal_count": 1,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "runtime_identity_projection.selected_console_byte_length": 293376,
            "command_transport_observation.population_sha256": POPULATION_SHA256,
            "command_transport_observation.unique_expected_digest_count": 362,
            "command_transport_observation.unique_recomputed_digest_count": 362,
            "source_path_role_observation.source_inventory_count": 76,
            "source_path_role_observation.qualified_physical_path_count": 59,
            "source_path_role_observation.publication_only_path_count": 2,
            "source_path_role_observation.path_role_overlap_count": 0,
            "source_path_role_observation.publication_only_paths_excluded_from_qualified_physical_paths": True,
            "decision.physical_behavior_attempt_authorized_after_publication_control": True,
            "decision.full_seeded_physical_ghost_required": False,
            "decision.additional_physical_canary_required": False,
            "decision.physical_attempted": False,
            "claim_boundary.physical_execution_authorized_now": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.published_closure_authorization_control_passed": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_physical_steps_authorized_after_control": 2400,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected_projection = dict(contract["physical_authorization_projection"])
    expected_projection["zero_world_qualification_passed"] = True
    expected_projection["source_freeze_commit"] = SOURCE
    expected_projection["physical_execution_authorized"] = True
    exact(
        closure["physical_authorization"],
        expected_projection,
        "PHYSICAL_AUTHORIZATION_PROJECTION",
    )

    expected = {
        "r24d81_source_status": STATUS,
        "r24d81_source_commit": SOURCE,
        "r24d81_official_qualification_attempt_count": 1,
        "r24d81_zero_world_qualification_pending": False,
        "r24d81_zero_world_qualified": True,
        "r24d81_source_inventory_count": 76,
        "r24d81_qualified_physical_path_count": 59,
        "r24d81_publication_only_path_count": 2,
        "r24d81_path_role_overlap_count": 0,
        "r24d81_active_command_cell_count": 603,
        "r24d81_application_pass_count": 603,
        "r24d81_validated_command_count": 4824,
        "r24d81_host_write_count": 4824,
        "r24d81_host_readback_count": 4824,
        "r24d81_digest_mismatch_count": 0,
        "r24d81_forced_digest_failure_rejection_count": 1,
        "r24d81_behavior_worker_parse_count": 1,
        "r24d81_supervisor_forced_failure_control_count": 1,
        "r24d81_missing_physical_switch_refusal_count": 1,
        "r24d81_historical_closure_audits_executed_count": 0,
        "r24d81_model_construction_count": 0,
        "r24d81_world_attempt_count": 0,
        "r24d81_world_build_count": 0,
        "r24d81_solver_step_count": 0,
        "r24d81_physical_execution_authorized": False,
        "r24d81_physical_attempt_consumed": False,
        "r24d81_physical_execution_blocked": True,
        "physical_execution_blocked_until_r24d81_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d81_published_closure_control": True,
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", closure_relative
    )
    assert isinstance(publication, str)
    if publication:
        closure_blob = git(ROOT, "show", f"{publication}:{closure_relative}", text=False)
    else:
        try:
            closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
        except subprocess.CalledProcessError:
            closure_blob = CLOSURE.read_bytes()
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        if publication:
            authority_raw = git(ROOT, "show", f"{publication}:{relative}", text=False)
            assert isinstance(authority_raw, bytes)
            authority = json.loads(authority_raw)
        else:
            authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d81_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{relative}",
        )
        exact(
            record["r24d81_zero_world_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{relative}",
        )
        exact(
            record["r24d81_zero_world_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{relative}",
        )
    print(
        "QSDK_R24D81_GODOT_JOLT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=76 physical_paths=59 publication_paths=2 "
        "overlap=0 checks=9/9 workers=1 cells=603/603 "
        "commands=4824 writes=4824 readbacks=4824 mismatches=0 failures=2 "
        "historical_audits=0 models=0 worlds=0 steps=0 next=publication_control "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    main()
