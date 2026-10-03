#!/usr/bin/env python3
"""Audit the compact R76 solved-contact recovery qualification closure."""

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
    "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "deaf755117bc458afc30ef920363f3be957ca294"
STATUS = (
    "closed_complete_zero_world_solved_contact_recovery_behavior_qualified_"
    "one_paired_development_attempt_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_positive_nonzero_exact_contact_population_after_valid_"
    "two_step_route"
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


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d76_godot_jolt_solved_contact_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D76",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R76: run solved-contact recovery "
                "behavior"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "qualification_runner",
                "physical_runner",
                "shared_supervisor",
                "behavior_worker",
                "contact_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d76_godot_jolt_solved_contact_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d76_godot_jolt_solved_contact_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d76-godot-jolt-solved-contact-recovery-behavior-"
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
                    "QSDK_R24D76_GODOT_JOLT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_"
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
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.physical_envelope_changed_from_r70": False,
            "critical_path_audit_policy.current_zero_world_worker_count": 7,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "ghost_and_canary_adequacy.short_native_instantiation_ghost_required": False,
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
            "focused_source_inventory_count": 74,
            "authored_source_path_count": 11,
            "qualified_physical_path_count": 50,
            "bound_predecessor_count": 2,
            "current_zero_world_worker_count": 7,
            "behavior_worker_parse_count": 1,
            "supervisor_forced_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_campaign_source_audit_mechanics_added_count": 0,
            "additional_physical_canary_count": 0,
            "native_runtime_observation_collection_executed": False,
        },
        "PREFLIGHT",
    )
    verify_exact_paths(
        closure,
        {
            "qualification.check_count": len(CHECKS),
            "qualification.checks_passed": len(CHECKS),
            "qualification.current_zero_world_worker_count": 7,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "physical_authorization.zero_world_qualification_passed": True,
            "physical_authorization.source_freeze_commit": SOURCE,
            "physical_authorization.maximum_model_construction_count": 2,
            "physical_authorization.maximum_world_build_count": 2,
            "physical_authorization.maximum_outer_solver_steps": 2400,
            "physical_authorization.physical_execution_authorized": True,
            "decision.physical_behavior_attempt_authorized": True,
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

    expected = {
        "r24d76_source_commit": SOURCE,
        "r24d76_source_status": STATUS,
        "r24d76_official_qualification_attempt_count": 1,
        "r24d76_zero_world_qualification_pending": False,
        "r24d76_zero_world_qualified": True,
        "r24d76_model_construction_count": 0,
        "r24d76_world_attempt_count": 0,
        "r24d76_world_build_count": 0,
        "r24d76_solver_step_count": 0,
        "r24d76_physical_execution_authorized": True,
        "r24d76_physical_attempt_consumed": False,
        "r24d76_physical_execution_blocked": False,
        "physical_execution_blocked_pending_r24d76_declaration_and_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d76_zero_world_qualification": False,
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", closure_relative
    )
    assert isinstance(publication, str)
    if publication:
        closure_blob = git(
            ROOT, "show", f"{publication}:{closure_relative}", text=False
        )
    else:
        closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        if publication:
            authority_raw = git(
                ROOT, "show", f"{publication}:{relative}", text=False
            )
            assert isinstance(authority_raw, bytes)
            authority = json.loads(authority_raw)
        else:
            authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d76_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{relative}",
        )
        exact(
            record["r24d76_zero_world_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{relative}",
        )
        exact(
            record["r24d76_zero_world_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{relative}",
        )
    print(
        "QSDK_R24D76_GODOT_JOLT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_ZERO_WORLD_"
        "CLOSURE_PASS sources=74 checks=9/9 workers=7 historical_audits=0 "
        "models=0 worlds=0 steps=0 authorized=2x2400 evaluator=1 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
