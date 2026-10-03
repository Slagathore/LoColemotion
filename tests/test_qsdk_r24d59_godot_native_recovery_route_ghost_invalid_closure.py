"""Compact audit of the consumed one-step-invalid R24D59 route ghost."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)


CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d59_godot_native_recovery_route_ghost_invalid_closure_v1.json"
)
SOURCE = "72bc5b33d84abb1765a41eabe573e524df072d22"
STATUS = (
    "closed_consumed_invalid_native_telemetry_schema_key_mismatch_"
    "after_one_solver_step"
)
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source",
    "model_construction_completed",
    "world_build_completed",
    "one_solver_step_completed",
    "physics_state_modified",
    "telemetry_dictionary_was_present",
    "distinct_successor_source_required",
    "telemetry_schema_consumer_repair_required",
)
DECISION_FALSE = (
    "native_observation_completed",
    "portable_command_applied",
    "controller_behavior_evaluated",
    "integration_ghost_passed",
    "same_identity_rerun_permitted",
    "r24d59_requalification_permitted",
    "historical_threshold_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source",
    "invalid_integration_result",
    "model_construction_completed",
    "world_build_completed",
    "solver_step_executed",
    "physics_state_modified",
    "termination_protocol_valid",
)
CLAIM_FALSE = (
    "native_runtime_observation_collection_executed",
    "portable_command_applied",
    "integration_ghost_passed",
    "controller_behavior_evaluated",
    "physics_failure_observed",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d59_godot_native_recovery_route_"
                "ghost_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D59",
            "stage_id": "R24D59-GHOST",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "dd68a58082e326a6f2af19230b234a873b41065f",
            "source.tree": "6d5d8a61f35b6f32fe6ea2fee6c8897d97844af9",
            "source.subject": "[recovery/godot] Close R59 published authorization control",
        },
        "CLOSURE",
    )
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D59",
        source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d59_ghost_attempt_v1",
            "raw": "sporespore_qsdk_r24d59_godot_native_recovery_route_ghost_raw_v1",
            "terminal": "sporespore_qsdk_r24d59_ghost_terminal_v1",
        },
    )
    attempt, raw, terminal = values["attempt"], values["raw"], values["terminal"]
    verify_exact_paths(
        attempt,
        {
            "created_utc": physical["created_utc"],
            "completed_utc": physical["completed_utc"],
        },
        "ATTEMPT_TIME",
    )
    verify_exact_paths(
        raw,
        {
            "failure_code": physical["outer_failure_code"],
            "detail.failure_code": physical["native_world_failure_code"],
            "detail.native_runtime_observation_collection_executed": False,
            "detail.physics_state_modified": False,
            "model_construction_attempt_count": 1,
            "native_scene_node_construction_attempted": True,
            "physics_state_modified": True,
            "physics_failure_is_valid_evidence": True,
            "full_seeded_world_demo": False,
            "recovery_success_required": False,
        },
        "RAW_RESULT",
    )
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / physical["artifacts"]["stdout"]["path"]).read_text(
        encoding="utf-8"
    )
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D59_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
            physical["native_world_failure_code"],
            physical["outer_failure_code"],
            "QSDK_R24D59_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )

    world = bound["sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"].decode()
    patch = bound[
        "sdk/adapters/godot/engine_patches/"
        "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
    ].decode()
    require_ordered_markers(
        world,
        (
            'if not (telemetry_value is Dictionary):',
            'QSDK_R24D57_WORLD_TELEMETRY_MISSING:%s',
            'String(telemetry.get("schema_version", ""))',
            'QSDK_R24D57_WORLD_TELEMETRY_INVALID:%s',
        ),
        "CONSUMER_CAUSE",
    )
    require(
        'result["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v2";'
        in patch,
        "BINDING_SCHEMA_KEY",
    )
    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "classification": (
                "deterministic_native_telemetry_consumer_schema_key_mismatch"
            ),
            "first_rejected_actuator_id": "front_left_hip_motor",
            "binding_emitted_key": "schema",
            "consumer_expected_key": "schema_version",
            "telemetry_dictionary_was_present": True,
            "missing_telemetry_failure_was_not_observed": True,
            "invalid_telemetry_failure_was_observed": True,
            "consumer_predicate_is_deterministically_false_for_bound_binding": True,
            "physics_or_controller_behavior_did_not_cause_refusal": True,
        },
        "CAUSE",
    )

    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE,
                             "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False,
        "sdk1_completed_steps": 11, "sdk1_total_steps": 20,
        "full_program_completed_steps": 11, "full_program_total_steps": 25,
    }, "SDK_STATUS")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--",
                      relative)
    revision = publication or None
    closure_raw = CLOSURE.read_bytes() if revision is None else source_bytes(
        ROOT, revision, relative
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d59_ghost_invalid_closure_raw_sha256": sha256(closure_raw),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D59_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_PASS "
        "attempts=1 models=1 worlds=1 steps=1 observations=0 commands=0 "
        "cause=telemetry_schema_key next=R24D60 sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError, OSError, KeyError, TypeError, ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D59_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
