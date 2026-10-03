#!/usr/bin/env python3
"""Audit the consumed integration-invalid R76 behavior invocation."""

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
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_behavior_"
    "incomplete_closure_v1.json"
)
SOURCE = "bded7ab19df142b8c946b30ef19474a840a32927"
STATUS = (
    "closed_consumed_invalid_incomplete_unqualified_supervisor_runtime_"
    "binding_before_model_construction"
)


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d76_godot_jolt_solved_contact_recovery_"
                "behavior_incomplete_closure_v1"
            ),
            "gate_id": "QSDK-R24D76",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "be5da9ea1a38167b480cf494c22adad3f23e3247",
            "source.tree": "d29e93ffce862b5a9e20c7cc767d4d21d2297220",
            "source.subject": (
                "[recovery/godot] Close R76 control: physical pair authorized"
            ),
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D76",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d76_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d76_godot_solved_contact_recovery_"
                "behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d76_behavior_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": False,
            "failure_code": "QSDK_R24D76_BEHAVIOR_CONTEXT_FAILED",
            "detail.failure_code": "QSDK_R24D57_EXACT_INSTRUMENTED_PROFILE_REQUIRED",
            "detail.native_runtime_observation_collection_executed": False,
            "arm_execution_summary.completed_arm_count": 0,
            "arm_execution_summary.ordered_arm_summaries": [],
            "arm_execution_summary.summarized_solver_step_count": 0,
            "physical_question_opened": False,
            "physics_state_modified": False,
        },
        "RAW",
    )
    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": False,
            "worker.semantic_exit_code": 1,
            "worker.termination_protocol_valid": True,
            "worker.raw_binding_valid": True,
            "recovery_success_observed": False,
            "prone_to_standing_claimed": False,
        },
        "TERMINAL",
    )

    diagnosis = closure["runtime_binding_diagnosis"]
    wrapper = source_bytes(
        ROOT,
        SOURCE,
        "sdk/run_qsdk_r24d76_godot_jolt_solved_contact_recovery_behavior.ps1",
    ).decode("utf-8")
    shared = source_bytes(
        ROOT, SOURCE, "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
    ).decode("utf-8")
    require("ConsolePath" not in wrapper, "WRAPPER_CONSOLE_BINDING_ABSENT")
    require("ExpectedConsoleSha256" not in wrapper, "WRAPPER_SHA_BINDING_ABSENT")
    require(
        "ExpectedConsoleByteLength" not in wrapper,
        "WRAPPER_LENGTH_BINDING_ABSENT",
    )
    require(
        "qsdk-r24d10-exact-step-numerical-telemetry" in shared
        and "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
        in shared,
        "SHARED_DEFAULT_BINDING",
    )
    for key in ("actual_selected_default_runtime", "qualified_intended_runtime"):
        claim = diagnosis[key]
        path = Path(claim["path"])
        exact(
            (path.stat().st_size, sha256(path.read_bytes())),
            (claim["byte_length"], claim["raw_sha256"]),
            f"RUNTIME:{key}",
        )
    exact(
        diagnosis["qualified_intended_runtime"]["raw_sha256"],
        "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8",
        "QUALIFIED_RUNTIME",
    )
    stderr = (Path(physical["evidence_root"]) / "godot.stderr.log").read_text()
    require_ordered_markers(
        stderr,
        (
            'Static function "space_get_solved_contact_telemetry()" not found',
            "recovery_native_world_v1.gd:2661",
            "Failed to compile depended scripts",
            "test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd",
        ),
        "STDERR",
    )
    stdout = (Path(physical["evidence_root"]) / "godot.stdout.log").read_text()
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build.5b4e0cb0f",
            "QSDK_R24D76_GODOT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_RAW ",
            '"failure_code":"QSDK_R24D76_BEHAVIOR_CONTEXT_FAILED"',
            "QSDK_R24D76_GODOT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )
    verify_exact_paths(
        diagnosis,
        {
            "wrapper_forwarded_console_path": False,
            "wrapper_forwarded_expected_console_sha256": False,
            "wrapper_forwarded_expected_console_byte_length": False,
            "shared_supervisor_default_selected_by_omitted_arguments": True,
            "version_banner_distinguishes_binaries": False,
            "binary_digest_distinguishes_binaries": True,
            "termination_protocol_valid": True,
            "raw_binding_valid": True,
            "failure_occurred_before_model_construction": True,
            "failure_occurred_before_world_attempt": True,
            "failure_occurred_before_solver_step": True,
            "physics_failure_observed": False,
            "controller_behavior_observed": False,
        },
        "DIAGNOSIS",
    )

    verify_boolean_partition(
        closure["decision"],
        (
            "physical_invocation_retained",
            "physical_invocation_consumed_for_exact_source",
            "authorization_and_control_valid",
            "termination_protocol_valid",
            "raw_result_bound",
            "integration_or_evidence_failure_observed",
        ),
        (
            "physics_state_modified",
            "physical_question_opened",
            "model_constructed",
            "world_attempted",
            "world_constructed",
            "solver_step_executed",
            "controller_behavior_evaluated",
            "valid_behavior_result_observed",
            "scientific_positive_observed",
            "scientific_negative_observed",
            "same_identity_rerun_permitted",
            "r24d76_requalification_permitted",
            "historical_result_rewritten",
            "prone_to_standing_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        "DECISION",
    )
    verify_exact_paths(
        closure,
        {
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "next_boundary.gate_id": "QSDK-R24D77",
            "next_boundary.physical_execution_blocked": True,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "next_boundary.full_seeded_ghost_required": False,
            "next_boundary.additional_physical_canary_required": False,
            "next_boundary.r24d76_may_be_rerun_or_requalified": False,
        },
        "BOUNDARY",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    if publication:
        closure_blob = git(ROOT, "show", f"{publication}:{relative}", text=False)
    else:
        closure_blob = git(ROOT, "show", f":{relative}", text=False)
    assert isinstance(closure_blob, bytes)
    expected = {
        "next_gate_id": "QSDK-R24D77",
        "r24d76_source_status": STATUS,
        "r24d76_physical_attempt_consumed": True,
        "r24d76_physical_attempt_count": 1,
        "r24d76_physical_invocation_source_commit": SOURCE,
        "r24d76_physical_result_status": "invalid_or_incomplete_behavior_development",
        "r24d76_physical_failure_code": "QSDK_R24D76_BEHAVIOR_CONTEXT_FAILED",
        "r24d76_observed_model_construction_count": 0,
        "r24d76_observed_world_attempt_count": 0,
        "r24d76_observed_world_build_count": 0,
        "r24d76_observed_solver_step_count": 0,
        "r24d76_valid_behavior_result_observed": False,
        "r24d76_physical_execution_authorized": False,
        "r24d77_distinct_successor_required": True,
    }
    for authority_relative in closure["live_authority_paths"]:
        if publication:
            authority_raw = git(
                ROOT, "show", f"{publication}:{authority_relative}", text=False
            )
            assert isinstance(authority_raw, bytes)
            authority = json.loads(authority_raw)
        else:
            authority = json.loads(
                (ROOT / authority_relative).read_text(encoding="utf-8")
            )
        records = records_with_key(authority, "r24d76_physical_attempt_consumed")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_relative}",
        )
        exact(
            record["r24d76_incomplete_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_relative}",
        )
        exact(
            record["r24d76_incomplete_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{authority_relative}",
        )
    print(
        "QSDK_R24D76_GODOT_JOLT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_INCOMPLETE_"
        "CLOSURE_PASS attempts=1 models=0 worlds=0 steps=0 physics=0 "
        "failure=runtime_binding_invalid next=R24D77 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
