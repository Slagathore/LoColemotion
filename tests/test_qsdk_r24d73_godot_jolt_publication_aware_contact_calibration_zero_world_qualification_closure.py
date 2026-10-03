#!/usr/bin/env python3
"""Audit the compact R73 zero-world qualification closure."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact, git, records_with_key, sha256,
    verify_declared_zero_world_qualification_authority, verify_exact_paths,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_calibration_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "94ac327a25809bceb8582e8004a35c2c37b6216e"
STATUS = (
    "closed_complete_zero_world_publication_aware_contact_calibration_qualified_"
    "one_two_step_development_calibration_authorized"
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
        root=ROOT, closure_path=CLOSURE,
        schema_version=(
            "sporespore_qsdk_r24d73_godot_jolt_publication_aware_contact_"
            "calibration_zero_world_qualification_closure_v1"
        ), gate_id="QSDK-R24D73", closure_status=STATUS,
        source_commit=SOURCE,
        source_subject="[recovery/godot] Declare R73: bind publication-aware calibration",
        source_binding_names=(
            "source_audit", "shared_helper", "physical_runner",
            "shared_supervisor", "worker",
        ),
        predecessor_status=(
            "closed_complete_zero_world_minimal_native_contact_calibration_"
            "qualified_one_two_step_development_calibration_authorized"
        ),
        attempt_schema=(
            "sporespore_qsdk_r24d73_godot_publication_aware_contact_"
            "calibration_zero_world_attempt_v1"
        ),
        receipt_schema=(
            "sporespore_qsdk_r24d73_godot_publication_aware_contact_"
            "calibration_zero_world_receipt_v1"
        ),
        qualification_directory_prefix=(
            "qsdk-r24d73-godot-jolt-publication-aware-contact-calibration-"
            "qualification-"
        ), expected_checks=CHECKS, checkout_only_metadata=(),
        retained_log_markers={
            "source_audit.log": (
                "QSDK_R24D73_GODOT_JOLT_PUBLICATION_AWARE_CONTACT_"
                "CALIBRATION_SOURCE_PASS"
            ),
        }, physical_question_declared=True,
    )
    verify_exact_paths(contract, {
        "status": "prospective_complete_zero_world_qualification_required_physics_blocked",
        "question_class": "development",
        "physical_question_declared": True,
        "controlled_change.physical_worker_changed": False,
        "controlled_change.shared_physical_supervisor_changed": False,
        "physical_envelope.maximum_world_build_count": 1,
        "physical_envelope.maximum_outer_solver_steps": 2,
        "authorization_boundary.physical_execution_authorized": False,
    }, "CONTRACT")
    verify_exact_paths(preflight, {
        "ok": True, "focused_source_inventory_count": 15,
        "authored_source_path_count": 12, "qualified_physical_path_count": 31,
        "bound_predecessor_count": 2,
        "publication_binding_regression_control_count": 1,
        "exact_runtime_pair_count": 1, "worker_parse_count": 1,
        "forced_failure_projection_control_count": 1,
        "historical_closure_audits_executed_count": 0,
    }, "PREFLIGHT")
    verify_exact_paths(closure, {
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
        "claim_boundary.publication_binding_regression_control_passed": True,
        "claim_boundary.prone_to_standing_claimed": False,
        "sdk_status.sdk1_completed_steps": 11,
        "next_boundary.physical_execution_authorized": True,
    }, "CLOSURE")
    invalid = Path(closure["retained_r24d72_pre_execution_invalid"]["path"])
    exact((invalid.stat().st_size, sha256(invalid.read_bytes())),
          (closure["retained_r24d72_pre_execution_invalid"]["byte_length"],
           closure["retained_r24d72_pre_execution_invalid"]["raw_sha256"]),
          "R72_INVALID")
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected = {
        "next_gate_id": "QSDK-R24D73", "r24d73_source_status": STATUS,
        "r24d73_source_commit": SOURCE,
        "r24d73_official_qualification_attempt_count": 1,
        "r24d73_zero_world_qualification_pending": False,
        "r24d73_zero_world_qualified": True,
        "r24d73_model_construction_count": 0,
        "r24d73_world_attempt_count": 0,
        "r24d73_world_build_count": 0,
        "r24d73_solver_step_count": 0,
        "r24d73_physical_execution_authorized": True,
        "physical_execution_blocked_until_r24d73_zero_world_qualification": False,
    }
    relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{relative}", text=False)
    assert isinstance(closure_blob, bytes)
    for relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d73_zero_world_qualified")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact({key: record[key] for key in expected}, expected,
              f"LIVE_PROJECTION:{relative}")
        exact(record["r24d73_zero_world_closure_raw_sha256"], sha256(closure_blob),
              f"LIVE_CLOSURE_HASH:{relative}")
        exact(record["r24d73_zero_world_closure_byte_length"], len(closure_blob),
              f"LIVE_CLOSURE_LENGTH:{relative}")
    print(
        "QSDK_R24D73_GODOT_JOLT_PUBLICATION_AWARE_CONTACT_CALIBRATION_ZERO_"
        "WORLD_CLOSURE_PASS sources=15 checks=9/9 retained=9 publication=1 "
        "historical_audits=0 models=0 worlds=0 steps=0 authorized=1x2 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
