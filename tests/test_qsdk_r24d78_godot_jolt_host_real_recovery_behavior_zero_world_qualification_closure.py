#!/usr/bin/env python3
"""Audit the compact R78 host-real recovery qualification closure."""

from __future__ import annotations

import json
from pathlib import Path
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
    "sdk/recovery/r24d78_godot_jolt_host_real_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "87a8d5f1c032d6b79de9a51eb6b953a061c1f830"
STATUS = (
    "closed_complete_zero_world_host_real_recovery_behavior_qualified_"
    "one_paired_development_attempt_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_host_command_readback_before_"
    "pair_completion"
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


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d78_godot_jolt_host_real_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D78",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Implement R78: project host-real commands"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "route",
                "focused_worker",
                "qualification_runner",
                "physical_runner",
                "shared_supervisor",
                "behavior_worker",
                "contact_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d78_godot_jolt_host_real_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d78_godot_jolt_host_real_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d78-godot-jolt-host-real-recovery-behavior-"
                "qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(
                {
                    "path": (
                        "sdk/adapters/godot/"
                        "sporespore_locomotion.gdextension.uid"
                    ),
                    "cause": "windows_text_checkout_crlf_materialization",
                    "git_attribute": "text=auto",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D78_GODOT_JOLT_HOST_REAL_RECOVERY_BEHAVIOR_"
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
            "controlled_change.explicit_packed_float32_command_projection_added": True,
            "controlled_change.projection_applied_in_actual_behavior_command_path": True,
            "controlled_change.canonical_unprojected_projected_and_readback_values_retained": True,
            "controlled_change.exact_projected_readback_required": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.physical_envelope_changed_from_r77": False,
            "host_real_projection_contract.binary32_relative_error_bound": 2.0**-23,
            "host_real_projection_contract.empirical_readback_tolerance_added": False,
            "critical_path_audit_policy.current_zero_world_worker_count": 8,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "ghost_and_canary_adequacy.full_seeded_physical_ghost_required": False,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
        },
        "CONTRACT",
    )
    exact(closure["bound_predecessors"], contract["bound_predecessors"], "PREDECESSORS")
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "focused_source_inventory_count": 79,
            "authored_source_path_count": 13,
            "qualified_physical_path_count": 55,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 8,
            "focused_host_real_application_worker_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_physical_ghost_count": 0,
            "behavior_worker_parse_count": 1,
            "supervisor_forced_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "r78_host_real_command_projection_receipt.actual_production_application_count": 1,
            "r78_host_real_command_projection_receipt.non_binary32_exact_projection_count": 8,
            "r78_host_real_command_projection_receipt.exact_projected_readback_count": 8,
            "r78_host_real_command_projection_receipt.mutation_rejection_count": 3,
            "production_wrapper_runtime_identity_receipt.schema_version": (
                "sporespore_qsdk_r24d78_runtime_identity_control_v1"
            ),
            "production_wrapper_runtime_identity_receipt.selected_console_path": CONSOLE_PATH,
            "production_wrapper_runtime_identity_receipt.selected_console_sha256": CONSOLE_SHA256,
            "production_wrapper_runtime_identity_receipt.worker_parse_count": 1,
            "model_construction_count": 0,
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
            "qualification.current_zero_world_worker_count": 8,
            "qualification.focused_host_real_application_count": 1,
            "qualification.focused_non_binary32_exact_projection_count": 8,
            "qualification.focused_exact_projected_readback_count": 8,
            "qualification.focused_projection_mutation_rejection_count": 3,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.selected_console_path": CONSOLE_PATH,
            "runtime_identity_projection.selected_console_sha256": CONSOLE_SHA256,
            "runtime_identity_projection.selected_console_byte_length": 293376,
            "host_real_projection_observation.actual_production_application_count": 1,
            "host_real_projection_observation.non_binary32_exact_projection_count": 8,
            "host_real_projection_observation.exact_projected_readback_count": 8,
            "host_real_projection_observation.mutation_rejection_count": 3,
            "host_real_projection_observation.empirical_readback_tolerance_added": False,
            "physical_authorization.zero_world_qualification_passed": True,
            "physical_authorization.source_freeze_commit": SOURCE,
            "physical_authorization.maximum_model_construction_count": 2,
            "physical_authorization.maximum_world_build_count": 2,
            "physical_authorization.maximum_outer_solver_steps": 2400,
            "physical_authorization.physical_execution_authorized": True,
            "decision.physical_behavior_attempt_authorized": True,
            "decision.focused_host_real_application_passed": True,
            "decision.full_seeded_physical_ghost_required": False,
            "decision.additional_physical_canary_required": False,
            "decision.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.physical_execution_authorized": True,
            "next_boundary.maximum_physical_steps_authorized": 2400,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    runtime = preflight["production_wrapper_runtime_identity_receipt"]
    exact(
        closure["runtime_identity_projection"],
        {
            "schema_version": runtime["schema_version"],
            "selected_console_path": runtime["selected_console_path"],
            "selected_console_sha256": runtime["selected_console_sha256"],
            "selected_console_byte_length": runtime["selected_console_byte_length"],
            "behavior_worker_path": runtime["worker_relative_path"],
            "wrapper_to_supervisor_binding_observed": True,
            "worker_parse_count": 1,
            "source_audit_execution_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
        "RUNTIME_IDENTITY_PROJECTION",
    )
    host = preflight["r78_host_real_command_projection_receipt"]
    direct = host["direct_projection"]
    exact(
        closure["host_real_projection_observation"],
        {
            "schema_version": host["schema_version"],
            "actual_production_application_count": host["actual_production_application_count"],
            "validated_command_count": host["validated_command_count"],
            "non_binary32_exact_projection_count": host["non_binary32_exact_projection_count"],
            "exact_projected_readback_count": host["exact_projected_readback_count"],
            "mutation_rejection_count": host["mutation_rejection_count"],
            "direct_canonical_target_velocity_rad_s": direct["canonical_target_velocity_rad_s"],
            "direct_projected_target_velocity_rad_s": direct["godot_projected_target_velocity_rad_s"],
            "direct_absolute_quantization_error_rad_s": direct["absolute_quantization_error_rad_s"],
            "direct_maximum_quantization_error_bound_rad_s": direct["maximum_quantization_error_bound_rad_s"],
            "host_real_format": direct["host_real_format"],
            "projection_method": direct["projection_method"],
            "empirical_readback_tolerance_added": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
        "HOST_REAL_PROJECTION",
    )

    expected = {
        "r24d78_source_commit": SOURCE,
        "r24d78_source_status": STATUS,
        "r24d78_official_qualification_attempt_count": 1,
        "r24d78_zero_world_qualification_pending": False,
        "r24d78_zero_world_qualified": True,
        "r24d78_model_construction_count": 0,
        "r24d78_world_attempt_count": 0,
        "r24d78_world_build_count": 0,
        "r24d78_solver_step_count": 0,
        "r24d78_physical_execution_authorized": True,
        "r24d78_physical_attempt_consumed": False,
        "r24d78_physical_execution_blocked": False,
        "physical_execution_blocked_pending_r24d78_declaration_and_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d78_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d78_published_closure_control": True,
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", closure_relative
    )
    assert isinstance(publication, str)
    if publication:
        closure_blob = git(ROOT, "show", f"{publication}:{closure_relative}", text=False)
    else:
        closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        if publication:
            authority_raw = git(ROOT, "show", f"{publication}:{relative}", text=False)
            assert isinstance(authority_raw, bytes)
            authority = json.loads(authority_raw)
        else:
            authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d78_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{relative}",
        )
        exact(
            record["r24d78_zero_world_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{relative}",
        )
        exact(
            record["r24d78_zero_world_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{relative}",
        )
    print(
        "QSDK_R24D78_GODOT_JOLT_HOST_REAL_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=79 checks=9/9 workers=8 host_application=1 "
        "mutations=3 historical_audits=0 models=0 worlds=0 steps=0 "
        "authorized=2x2400 evaluator=1 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
