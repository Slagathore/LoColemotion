#!/usr/bin/env python3
"""Audit the compact R79 finite command-transport closure."""

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
    "sdk/recovery/r24d79_recovery_command_transport_population_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "3ec6f4043f9dea85e1ce59816f6b3516bffca676"
STATUS = (
    "closed_complete_zero_world_finite_recovery_command_transport_population_"
    "qualified_physics_blocked_pending_distinct_successor"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_command_digest_before_pair_completion"
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
                "sporespore_qsdk_r24d79_recovery_command_transport_population_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D79",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[recovery/godot] Freeze R79 command transport gate",
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "qualification_runner",
                "command_population_worker",
                "canonical_projection",
                "recovery_runtime",
                "godot_route",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d79_recovery_command_transport_population_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d79_recovery_command_transport_population_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d79-recovery-command-transport-population-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(
                {
                    "path": "sdk/python/test_ctypes_smoke.py",
                    "cause": "existing_windows_checkout_mixed_line_ending_materialization",
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D79_RECOVERY_COMMAND_TRANSPORT_POPULATION_SOURCE_PASS"
                ),
            },
        )
    )
    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_complete_finite_command_transport_qualification_"
                "required_physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "controlled_change.guarded_transport_projection_significant_decimal_digits": 13,
            "controlled_change.canonical_digest_significant_decimal_digits": 14,
            "controlled_change.guard_digit_count": 1,
            "controlled_change.portable_recovery_phase_or_threshold_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "finite_command_population.total_active_command_cell_count": 603,
            "finite_command_population.total_validated_command_count": 4824,
            "finite_command_population.expected_unique_command_digest_count": 362,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "authorization_boundary.physical_execution_authorized": False,
        },
        "CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "focused_source_inventory_count": 32,
            "authored_source_path_count": 5,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 1,
            "active_command_cell_count": 603,
            "application_pass_count": 603,
            "forced_digest_failure_rejection_count": 1,
            "historical_closure_audits_executed_count": 0,
            "published_closure_observed": 0,
            "command_population_receipt.validated_command_count": 4824,
            "command_population_receipt.host_write_count": 4824,
            "command_population_receipt.host_readback_count": 4824,
            "command_population_receipt.digest_mismatch_count": 0,
            "command_population_receipt.unique_expected_digest_count": 362,
            "command_population_receipt.unique_recomputed_digest_count": 362,
            "command_population_receipt.population_sha256": (
                "sha256:0285fcd60dd739084fa6131d58ce7d389d556a9da1d4dae1239d98293228dc46"
            ),
            "command_population_receipt.forced_digest_failure_rejected": True,
            "command_population_receipt.forced_digest_failure_detail.host_write_count": 0,
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
            "qualification.active_command_cell_count": 603,
            "qualification.validated_command_count": 4824,
            "qualification.host_write_count": 4824,
            "qualification.host_readback_count": 4824,
            "qualification.digest_mismatch_count": 0,
            "qualification.historical_closure_audits_executed_count": 0,
            "command_transport_observation.status": (
                "complete_finite_population_transport_stable"
            ),
            "decision.command_transport_defect_closed": True,
            "decision.distinct_physical_successor_declaration_required": True,
            "decision.physical_execution_authorized": False,
            "decision.physical_attempted": False,
            "claim_boundary.complete_finite_command_transport_population_passed": True,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.gate_id": "QSDK-R24D80",
            "next_boundary.physical_question_declared": False,
            "next_boundary.maximum_physical_steps_authorized": 0,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected = {
        "r24d79_source_status": STATUS,
        "r24d79_source_commit": SOURCE,
        "r24d79_official_qualification_attempt_count": 1,
        "r24d79_zero_world_qualification_pending": False,
        "r24d79_zero_world_qualified": True,
        "r24d79_active_command_cell_count": 603,
        "r24d79_validated_command_count": 4824,
        "r24d79_host_write_count": 4824,
        "r24d79_host_readback_count": 4824,
        "r24d79_digest_mismatch_count": 0,
        "r24d79_model_construction_count": 0,
        "r24d79_world_build_count": 0,
        "r24d79_solver_step_count": 0,
        "r24d79_physical_execution_authorized": False,
        "r24d79_physical_execution_blocked": True,
        "next_gate_id": "QSDK-R24D80",
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{closure_relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d79_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{relative}",
        )
        exact(
            record["r24d79_zero_world_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{relative}",
        )
        exact(
            record["r24d79_zero_world_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{relative}",
        )
    print(
        "QSDK_R24D79_RECOVERY_COMMAND_TRANSPORT_POPULATION_ZERO_WORLD_"
        "CLOSURE_PASS sources=32 checks=9/9 retained=9 cells=603/603 "
        "commands=4824 writes=4824 readbacks=4824 mismatches=0 mutations=1 "
        "historical_audits=0 models=0 worlds=0 steps=0 physical=blocked sdk1=11/20"
    )


if __name__ == "__main__":
    main()
