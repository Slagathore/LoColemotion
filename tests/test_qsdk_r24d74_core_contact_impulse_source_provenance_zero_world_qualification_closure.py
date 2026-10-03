#!/usr/bin/env python3
"""Audit the compact R74 paired-provenance zero-world closure."""

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
    "sdk/recovery/r24d74_core_contact_impulse_source_provenance_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "454dbd0268a4729efe58ec800ecc2e8b3ad15eac"
STATUS = (
    "closed_complete_zero_world_paired_contact_impulse_source_provenance_"
    "qualified_one_two_step_development_calibration_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_core_contact_provenance_schema_"
    "rejection_after_one_step"
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
                "sporespore_qsdk_r24d74_core_contact_impulse_source_"
                "provenance_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D74",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Declare R74: qualify paired contact provenance"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "qualification_runner",
                "physical_runner",
                "shared_supervisor",
                "physical_worker",
                "zero_world_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d74_core_contact_impulse_source_"
                "provenance_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d74_core_contact_impulse_source_"
                "provenance_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d74-core-contact-impulse-source-provenance-"
                "qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D74_CORE_CONTACT_IMPULSE_SOURCE_PROVENANCE_SOURCE_PASS"
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
            "controlled_change.contact_provenance_impulse_source_profile_id_added": True,
            "controlled_change.contact_provenance_impulse_source_kind_added": True,
            "controlled_change.paired_presence_required": True,
            "controlled_change.unknown_field_refusal_preserved": True,
            "controlled_change.physical_worker_changed": False,
            "physical_envelope.maximum_world_build_count": 1,
            "physical_envelope.maximum_outer_solver_steps": 2,
            "authorization_boundary.physical_execution_authorized": False,
        },
        "CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "focused_source_inventory_count": 23,
            "authored_source_path_count": 18,
            "qualified_physical_path_count": 36,
            "bound_predecessor_count": 1,
            "rust_paired_provenance_contract_test_count": 1,
            "godot_production_decoder_positive_count": 1,
            "missing_half_mutation_count": 2,
            "missing_half_mutation_rejection_count": 2,
            "unknown_field_mutation_rejection_count": 1,
            "publication_binding_regression_control_count": 1,
            "exact_runtime_pair_count": 1,
            "worker_parse_count": 2,
            "forced_failure_projection_control_count": 1,
            "historical_closure_audits_executed_count": 0,
        },
        "PREFLIGHT",
    )
    verify_exact_paths(
        closure,
        {
            "qualification.check_count": len(CHECKS),
            "qualification.checks_passed": len(CHECKS),
            "qualification.model_construction_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.physical_ghost_authorized": True,
            "decision.maximum_world_build_count": 1,
            "decision.maximum_outer_solver_steps": 2,
            "decision.seed": 1752993918,
            "decision.physical_attempted": False,
            "claim_boundary.paired_contact_provenance_contract_passed": True,
            "claim_boundary.production_decoder_paired_shape_passed": True,
            "claim_boundary.missing_half_mutations_rejected": True,
            "claim_boundary.unknown_field_mutation_rejected": True,
            "claim_boundary.publication_binding_regression_control_passed": True,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.physical_execution_authorized": True,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected = {
        "r24d74_source_commit": SOURCE,
        "r24d74_official_qualification_attempt_count": 1,
        "r24d74_zero_world_qualification_pending": False,
        "r24d74_zero_world_qualified": True,
        "r24d74_model_construction_count": 0,
        "r24d74_world_attempt_count": 0,
        "r24d74_world_build_count": 0,
        "r24d74_solver_step_count": 0,
        "physical_execution_blocked_until_r24d74_zero_world_qualification": False,
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{closure_relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d74_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{relative}",
        )
        exact(
            record["r24d74_zero_world_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{relative}",
        )
        exact(
            record["r24d74_zero_world_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{relative}",
        )
    print(
        "QSDK_R24D74_CORE_CONTACT_IMPULSE_SOURCE_PROVENANCE_ZERO_WORLD_"
        "CLOSURE_PASS sources=23 checks=9/9 retained=9 paired=1 mutations=3 "
        "historical_audits=0 models=0 worlds=0 steps=0 authorized=1x2 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
