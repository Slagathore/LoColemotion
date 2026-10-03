#!/usr/bin/env python3
"""Audit the compact R71 zero-world qualification closure."""

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
    "sdk/recovery/r24d71_godot_jolt_solved_contact_telemetry_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "09fcdf581afbd10a018e07e855e1cc1742d5037b"
STATUS = (
    "closed_complete_zero_world_solved_contact_source_qualified_"
    "native_calibration_declaration_required_physics_blocked"
)
CHECKS = (
    "core_dynamic_library_rebuilt", "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed", "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed", "versioning_conformance_passed",
    "source_contract_audit_passed", "production_preflight_passed",
    "worktree_unchanged",
)


def main() -> None:
    closure, contract, receipt, preflight = verify_declared_zero_world_qualification_authority(
        root=ROOT,
        closure_path=CLOSURE,
        schema_version=(
            "sporespore_qsdk_r24d71_godot_jolt_solved_contact_telemetry_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D71",
        closure_status=STATUS,
        source_commit=SOURCE,
        source_subject=(
            "[recovery/godot] Implement R71: exact post-solve contact telemetry"
        ),
        source_binding_names=("source_audit", "native_patch", "native_world", "capability"),
        predecessor_status="closed_consumed_valid_finite_negative_distal_support_timeout",
        attempt_schema="sporespore_qsdk_r24d71_godot_solved_contact_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d71_godot_solved_contact_zero_world_receipt_v1",
        qualification_directory_prefix=(
            "qsdk-r24d71-godot-solved-contact-telemetry-qualification-"
        ),
        expected_checks=CHECKS,
        checkout_only_metadata=(),
        retained_log_markers={
            "source_audit.log": (
                "QSDK_R24D71_GODOT_JOLT_SOLVED_CONTACT_TELEMETRY_SOURCE_PASS"
            ),
        },
    )
    verify_exact_paths(contract, {
        "status": "prospective_zero_world_source_qualification_required",
        "question_class": "development",
        "physical_question_declared": False,
        "authorization_boundary.physical_execution_authorized": False,
    }, "CONTRACT")
    verify_exact_paths(preflight, {
        "ok": True,
        "focused_source_inventory_count": 18,
        "bound_predecessor_count": 1,
        "native_patch_path_count": 15,
        "current_zero_world_worker_count": 4,
        "historical_closure_audits_executed_count": 0,
        "r71_binding_receipt.passed_assertion_count": 7,
        "r71_binding_receipt.invalid_rid_refusal_count": 1,
        "r71_contract_receipt.positive_exact_count": 2,
        "r71_contract_receipt.exact_mutation_rejection_count": 18,
        "r71_contract_receipt.missing_variant_rejection_count": 1,
        "profile_capability_receipt.instrumented_profile_selected": True,
        "portable_route_receipt.ok": True,
    }, "PREFLIGHT")
    verify_exact_paths(closure, {
        "ledger_scope.question_class": "development",
        "qualification.check_count": len(CHECKS),
        "qualification.checks_passed": len(CHECKS),
        "qualification.model_construction_count": 0,
        "qualification.world_build_count": 0,
        "qualification.solver_step_count": 0,
        "decision.result": "positive_zero_world_exact_post_solve_contact_source_qualified",
        "decision.native_contact_accuracy_observed": False,
        "decision.physical_attempted": False,
        "decision.prone_to_standing_claimed": False,
        "sdk_status.sdk1_completed_steps": 11,
        "sdk_status.sdk1_total_steps": 20,
        "next_boundary.gate_id": "QSDK-R24D72",
        "next_boundary.physical_execution_authorized": False,
    }, "CLOSURE")
    predecessor = ROOT / closure["predecessor"]["closure_path"]
    exact(predecessor.stat().st_size, closure["predecessor"]["closure_byte_length"],
          "PREDECESSOR_LENGTH")
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    live_expected = {
        "next_gate_id": "QSDK-R24D72",
        "r24d71_distinct_successor_required": False,
        "r24d71_source_status": STATUS,
        "r24d71_source_commit": SOURCE,
        "r24d71_official_qualification_attempt_count": 1,
        "r24d71_zero_world_qualified": True,
        "r24d71_physical_execution_authorized": False,
        "physical_execution_blocked_until_r24d71_zero_world_qualification": False,
        "r24d72_distinct_successor_required": True,
        "physical_execution_blocked_pending_r24d72_declaration_and_zero_world_qualification": True,
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{closure_relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        # Preserve unrelated retained duplicate keys in these legacy ledgers.
        authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d71_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact({key: record[key] for key in live_expected}, live_expected,
              f"LIVE_PROJECTION:{relative}")
        exact(record["r24d71_zero_world_closure_raw_sha256"],
              sha256(closure_blob), f"LIVE_CLOSURE_HASH:{relative}")
        exact(record["r24d71_zero_world_closure_byte_length"],
              len(closure_blob), f"LIVE_CLOSURE_LENGTH:{relative}")

    print(
        "QSDK_R24D71_GODOT_JOLT_SOLVED_CONTACT_ZERO_WORLD_CLOSURE_PASS "
        "retained_file_count=9 source_inventory_count=18 current_worker_count=4 "
        "historical_closure_audits_executed_count=0 physical_step_count=0"
    )


if __name__ == "__main__":
    main()
