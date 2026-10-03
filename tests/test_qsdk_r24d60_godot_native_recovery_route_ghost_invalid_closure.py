"""Compact audit of the consumed one-step-invalid R24D60 route ghost."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, require, require_ordered_markers, sha256,
    source_bytes, verify_boolean_partition, verify_exact_paths,
    verify_legacy_live_gate_paths, verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / "sdk/recovery/r24d60_godot_native_recovery_route_ghost_invalid_closure_v1.json"
SOURCE = "0d9afb8122a9f7a2d08047c7c4ce286ab405c2d7"
STATUS = "closed_consumed_invalid_duplicate_native_contact_identity_after_one_solver_step"
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source", "model_construction_completed",
    "world_build_completed", "one_solver_step_completed", "physics_state_modified",
    "native_collection_refusal_recorded", "duplicate_contact_identity_cause_established",
    "distinct_successor_source_required", "contact_identity_aggregation_repair_required",
)
DECISION_FALSE = (
    "native_observation_completed", "portable_command_applied",
    "controller_behavior_evaluated", "integration_ghost_passed",
    "same_identity_rerun_permitted", "r24d60_requalification_permitted",
    "historical_threshold_changed", "historical_selector_changed",
    "historical_evaluator_changed", "historical_result_rewritten",
    "prone_to_standing_claimed", "physical_acceptance_authority", "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source", "invalid_integration_result",
    "model_construction_completed", "world_build_completed", "solver_step_executed",
    "physics_state_modified", "termination_protocol_valid",
    "duplicate_contact_identity_cause_established",
)
CLAIM_FALSE = (
    "native_runtime_observation_collection_executed", "portable_command_applied",
    "integration_ghost_passed", "controller_behavior_evaluated",
    "physics_failure_observed", "prone_to_standing_claimed", "population_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": "sporespore_qsdk_r24d60_godot_native_recovery_route_ghost_invalid_closure_v1",
        "gate_id": "QSDK-R24D60", "stage_id": "R24D60-GHOST",
        "closure_status": STATUS, "question_class": "development",
        "physical_question_declared": True, "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False, "source.commit": SOURCE,
        "source.parent_commit": "9cb1cd22d58212bb90e5c8f76bdd4f1b3eb96dad",
        "source.tree": "99f1be3cde9f9b58856aceb7ad45dd6be2a545c1",
        "source.subject": "[recovery/godot] Close R60 published authorization control",
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    bound = {item["path"]: verify_source_binding(ROOT, SOURCE, item)
             for item in closure["source"]["bindings"]}

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical, gate_id="QSDK-R24D60", source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d60_ghost_attempt_v1",
            "raw": "sporespore_qsdk_r24d60_godot_native_recovery_route_ghost_raw_v1",
            "terminal": "sporespore_qsdk_r24d60_ghost_terminal_v1",
        },
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(raw, {
        "failure_code": physical["outer_failure_code"],
        "detail.failure_code": physical["native_world_failure_code"],
        "detail.detail.refusal_reason": physical["native_collection_refusal_reason"],
        "detail.detail.support_status": "invalid_observation",
        "detail.detail.native_runtime_observation_collection_executed": False,
        "model_construction_attempt_count": 1,
        "native_scene_node_construction_attempted": True,
        "physics_state_modified": True, "physics_failure_is_valid_evidence": True,
        "full_seeded_world_demo": False, "recovery_success_required": False,
    }, "RAW_RESULT")
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / physical["artifacts"]["stdout"]["path"]).read_text(encoding="utf-8")
    require_ordered_markers(stdout, (
        "Godot Engine v4.7.stable.custom_build",
        "QSDK_R24D60_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
        physical["native_collection_refusal_reason"], physical["outer_failure_code"],
        "QSDK_R24D60_GODOT_SUPERVISOR_TERMINATION_READY ",
    ), "STDOUT")

    observer = bound["scripts/lab/mechanics/semantic_contact_rigid_body.gd"].decode()
    world = bound["sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"].decode()
    core = bound["sdk/core/src/recovery.rs"].decode()
    require_ordered_markers(observer, (
        "for contact_index in state.get_contact_count():",
        "samples.append(", '"engine_contact_id":', '"%s:%d|%s:%d"',
    ), "OBSERVER_CAUSE")
    require_ordered_markers(world, (
        'var engine_contact_id := String(sample.get("engine_contact_id", ""))',
        "if engine_contact_id.is_empty():",
        'QSDK_R24D57_WORLD_CONTACT_ID_MISSING:%s',
        "(nonfoot_ids[body_id] as Array).append(engine_contact_id)",
    ), "AGGREGATOR_CAUSE")
    require_ordered_markers(core, (
        "let mut engine_ids = HashSet::new();",
        "id.trim().is_empty() || !engine_ids.insert(id.as_str())",
        'return Err("body_clearance_engine_contact_identity_invalid".to_owned());',
    ), "CORE_CAUSE")
    require("contact_index" not in observer.split('"engine_contact_id":', 1)[1].split("],", 1)[0],
            "CONTACT_ID_UNEXPECTEDLY_POINT_UNIQUE")
    verify_exact_paths(closure["causal_diagnosis"], {
        "classification": "duplicate_native_shape_pair_contact_identity_in_body_clearance_provenance",
        "core_refusal_reason": "body_clearance_engine_contact_identity_invalid",
        "native_sampler_rejects_empty_contact_ids_before_core_validation": True,
        "core_refusal_remaining_case_is_duplicate_contact_id": True,
        "engine_contact_id_is_shape_pair_without_contact_point_index": True,
        "semantic_observer_emits_one_sample_per_native_contact_point": True,
        "native_aggregator_appends_each_sample_identity_without_deduplication": True,
        "normal_impulses_are_aggregated_across_contact_points": True,
        "core_requires_unique_nonempty_engine_contact_ids_per_body": True,
        "first_rejected_body_id_retained": False,
        "physics_or_controller_behavior_did_not_cause_refusal": True,
    }, "CAUSE")

    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    revision = publication or None
    raw_closure = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"], "QSDK-R24D45", {
        **closure["live_gate_expectations"],
        "r24d60_ghost_invalid_closure_raw_sha256": sha256(raw_closure),
    }, revision=revision)
    print("QSDK_R24D60_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_PASS "
          "attempts=1 models=1 worlds=1 steps=1 observations=0 commands=0 "
          "cause=duplicate_shape_pair_contact_identity next=R24D61 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D60_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
