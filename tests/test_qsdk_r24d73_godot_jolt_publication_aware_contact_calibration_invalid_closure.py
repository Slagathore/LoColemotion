#!/usr/bin/env python3
"""Audit the consumed infrastructure-invalid R73 physical calibration."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact, git, records_with_key, require, require_ordered_markers, sha256,
    source_bytes, verify_boolean_partition, verify_exact_paths,
    verify_source_binding, verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_calibration_"
    "invalid_closure_v1.json"
)
SOURCE = "16b996e8e79ba36cab5544676df33f3b1cde2cb1"
STATUS = (
    "closed_consumed_invalid_incomplete_core_contact_provenance_schema_"
    "rejection_after_one_step"
)


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    verify_exact_paths(closure, {
        "schema_version": (
            "sporespore_qsdk_r24d73_godot_jolt_publication_aware_contact_"
            "calibration_invalid_closure_v1"
        ), "gate_id": "QSDK-R24D73", "closure_status": STATUS,
        "question_class": "development", "physical_question_declared": True,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "source.commit": SOURCE,
        "source.parent_commit": "94ac327a25809bceb8582e8004a35c2c37b6216e",
        "source.tree": "3e25dd2022a79730d62125e3ecaec48fae39584e",
        "source.subject": "[recovery/godot] Close R73: authorize publication-aware calibration",
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }
    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical, gate_id="QSDK-R24D73", source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d73_publication_aware_contact_calibration_attempt_v1",
            "raw": "sporespore_qsdk_r24d73_godot_publication_aware_contact_calibration_raw_v1",
            "terminal": "sporespore_qsdk_r24d73_publication_aware_contact_calibration_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count", "model_construction_count",
            "world_attempt_count", "world_build_count", "solver_step_count",
            "behavior_evaluator_invocation_count", "threshold_count", "margin_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(raw, {
        "ok": False, "physical_question_opened": True,
        "physics_state_modified": True,
        "failure_code": "QSDK_R24D73_GHOST_FIRST_PORTABLE_ROUTE_FAILED",
        "detail.failure_code": "QSDK_R24D57_NATIVE_COLLECTION_REFUSED",
        "detail.detail.failure_code": "SCHEMA_INVALID",
        "detail.detail.detail": (
            "unknown field `impulse_source_kind`, expected one of `adapter_id`, "
            "`engine_contact_ids`, `aggregation_rule_id`, `quality` at line 1 "
            "column 16354"
        ),
    }, "RAW")
    verify_exact_paths(terminal, {
        "integration_ghost_passed": False,
        "worker.semantic_exit_code": 1,
        "worker.termination_protocol_valid": True,
        "raw_result.raw_sha256": physical["artifacts"]["raw"]["raw_sha256"],
    }, "TERMINAL")
    stdout = (Path(physical["evidence_root"]) / "godot.stdout.log").read_text()
    require_ordered_markers(stdout, (
        "Godot Engine v4.7.stable.custom_build",
        "QSDK_R24D73_GODOT_PUBLICATION_AWARE_CONTACT_CALIBRATION_RAW ",
        '"failure_code":"SCHEMA_INVALID"',
        "QSDK_R24D73_GODOT_SUPERVISOR_TERMINATION_READY ",
    ), "STDOUT")
    native_world = bound[
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
    ].decode()
    protocol = bound["sdk/core/src/protocol.rs"].decode()
    require('"impulse_source_kind"' in native_world and
            '"impulse_source_profile_id"' in native_world, "GODOT_FIELDS")
    require("impulse_source_kind" not in protocol and
            "impulse_source_profile_id" not in protocol, "CORE_SCHEMA_GAP")
    verify_exact_paths(closure["causal_diagnosis"], {
        "rejected_field": "impulse_source_kind",
        "world_and_first_solver_step_executed": True,
        "portable_route_collection_completed": False,
        "contact_population_observed": False,
        "physics_positive_or_negative_classification_available": False,
        "distinct_schema_successor_required_before_any_new_world": True,
    }, "CAUSE")
    verify_boolean_partition(closure["decision"], (
        "physical_attempt_retained", "physical_attempt_consumed_for_exact_source",
        "world_constructed", "one_solver_step_executed", "physics_state_modified",
        "termination_protocol_valid", "raw_result_content_addressed",
        "terminal_content_addressed", "infrastructure_invalid_or_incomplete_observed",
        "distinct_successor_required",
    ), (
        "same_identity_rerun_permitted", "r24d73_requalification_permitted",
        "valid_contact_calibration_result_observed", "scientific_positive_observed",
        "scientific_negative_observed", "recovery_success_observed",
        "historical_result_rewritten", "prone_to_standing_claimed",
        "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority",
    ), "DECISION")
    verify_exact_paths(closure, {
        "sdk_status.sdk1_completed_steps": 11,
        "sdk_status.sdk1_total_steps": 20,
        "next_boundary.gate_id": "QSDK-R24D74",
        "next_boundary.physical_execution_blocked": True,
        "next_boundary.maximum_world_build_count": 0,
        "next_boundary.maximum_physical_steps_authorized": 0,
        "next_boundary.r24d73_may_be_rerun_or_requalified": False,
    }, "DECISION_BOUNDARY")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    try:
        closure_blob = git(ROOT, "show", f"HEAD:{relative}", text=False)
    except subprocess.CalledProcessError:
        closure_blob = git(ROOT, "show", f":{relative}", text=False)
    assert isinstance(closure_blob, bytes)
    expected = {
        "next_gate_id": "QSDK-R24D74", "r24d73_source_status": STATUS,
        "r24d73_physical_attempt_consumed": True,
        "r24d73_physical_result_status": "invalid_or_incomplete_integration_ghost",
        "r24d73_observed_world_build_count": 1,
        "r24d73_observed_solver_step_count": 1,
        "r24d73_valid_contact_calibration_result_observed": False,
        "r24d73_physical_execution_authorized": False,
        "r24d74_distinct_successor_required": True,
    }
    for relative in closure["live_authority_paths"]:
        authority = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(authority, "r24d73_physical_attempt_consumed")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{relative}")
        record = records[0]
        exact({key: record[key] for key in expected}, expected,
              f"LIVE_PROJECTION:{relative}")
        exact(record["r24d73_invalid_closure_raw_sha256"], sha256(closure_blob),
              f"LIVE_CLOSURE_HASH:{relative}")
    print(
        "QSDK_R24D73_GODOT_JOLT_PUBLICATION_AWARE_CONTACT_CALIBRATION_INVALID_"
        "CLOSURE_PASS attempts=1 models=1 worlds=1 steps=1 outcome=invalid "
        "cause=core_contact_provenance_schema next=R24D74 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
