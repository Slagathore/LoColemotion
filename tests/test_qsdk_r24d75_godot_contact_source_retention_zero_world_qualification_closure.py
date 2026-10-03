#!/usr/bin/env python3
"""Audit the compact R75 contact-source retention zero-world closure."""

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
    "sdk/recovery/r24d75_godot_contact_source_retention_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "4ceadcf1c9ae04420b9f3d1787056cf8c7614346"
STATUS = (
    "closed_complete_zero_world_contact_source_retention_qualified_"
    "one_two_step_development_calibration_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_declared_contact_point_classifier_not_"
    "retained_after_valid_two_step_route"
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
                "sporespore_qsdk_r24d75_godot_contact_source_retention_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D75",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R75: retain exact contact classifier source"
            ),
            source_binding_names=(
                "source_audit",
                "production_world",
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
                "sporespore_qsdk_r24d75_godot_contact_source_retention_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d75_godot_contact_source_retention_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d75-godot-contact-source-retention-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_SOURCE_PASS"
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
            "controlled_change.exact_contact_source_receipt_retained_beside_existing_digest": True,
            "controlled_change.contact_source_receipt_deep_copy_required": True,
            "controlled_change.contact_source_digest_semantics_unchanged": True,
            "controlled_change.production_retention_helper_shared_with_zero_world_worker": True,
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
            "focused_source_inventory_count": 20,
            "authored_source_path_count": 13,
            "qualified_physical_path_count": 36,
            "bound_predecessor_count": 1,
            "physical_component_assembly_source_control_count": 1,
            "production_retention_populated_positive_count": 1,
            "production_retention_zero_positive_count": 1,
            "canonical_digest_recompute_count": 2,
            "deep_copy_isolation_count": 1,
            "retention_mutation_population_count": 8,
            "exact_retention_mutation_rejection_count": 8,
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
            "claim_boundary.production_contact_source_retention_passed": True,
            "claim_boundary.populated_and_zero_classifier_shapes_passed": True,
            "claim_boundary.canonical_digest_recomputation_passed": True,
            "claim_boundary.deep_copy_isolation_passed": True,
            "claim_boundary.all_retention_mutations_rejected": True,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.physical_execution_authorized": True,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected = {
        "r24d75_source_commit": SOURCE,
        "r24d75_official_qualification_attempt_count": 1,
        "r24d75_zero_world_qualification_pending": False,
        "r24d75_zero_world_qualified": True,
        "r24d75_model_construction_count": 0,
        "r24d75_world_attempt_count": 0,
        "r24d75_world_build_count": 0,
        "r24d75_solver_step_count": 0,
        "physical_execution_blocked_until_r24d75_zero_world_qualification": False,
    }
    closure_relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{closure_relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{closure_relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d75_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{relative}",
        )
        exact(
            record["r24d75_zero_world_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{relative}",
        )
        exact(
            record["r24d75_zero_world_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{relative}",
        )
    print(
        "QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_ZERO_WORLD_CLOSURE_PASS "
        "sources=20 checks=9/9 retained=9 shapes=2 mutations=8 digests=2 "
        "historical_audits=0 models=0 worlds=0 steps=0 authorized=1x2 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
