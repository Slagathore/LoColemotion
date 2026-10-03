"""Compact audit of the consumed one-step-invalid R24D61 route ghost."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, require_ordered_markers, sha256,
    source_bytes, verify_boolean_partition, verify_exact_paths,
    verify_legacy_live_gate_paths, verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / "sdk/recovery/r24d61_godot_native_recovery_route_ghost_invalid_closure_v1.json"
SOURCE = "8dfe91f1d332ddc4caa3fcde4a5c1655b66cb0a6"
STATUS = "closed_consumed_invalid_candidate_bootstrap_arm_identity_after_one_solver_step"
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source", "model_construction_completed",
    "world_build_completed", "one_solver_step_completed", "physics_state_modified",
    "contact_identity_projection_advanced_past_prior_refusal",
    "native_collection_refusal_recorded", "bootstrap_arm_identity_mismatch_established",
    "distinct_successor_source_required", "candidate_bootstrap_arm_identity_repair_required",
)
DECISION_FALSE = (
    "native_observation_completed", "portable_command_applied",
    "controller_behavior_evaluated", "integration_ghost_passed",
    "same_identity_rerun_permitted", "r24d61_requalification_permitted",
    "historical_threshold_changed", "historical_selector_changed",
    "historical_evaluator_changed", "historical_result_rewritten",
    "prone_to_standing_claimed", "physical_acceptance_authority", "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source", "invalid_integration_result",
    "model_construction_completed", "world_build_completed", "solver_step_executed",
    "physics_state_modified", "termination_protocol_valid",
    "contact_identity_projection_advanced_past_prior_refusal",
    "bootstrap_arm_identity_mismatch_established",
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
        "schema_version": "sporespore_qsdk_r24d61_godot_native_recovery_route_ghost_invalid_closure_v1",
        "gate_id": "QSDK-R24D61", "stage_id": "R24D61-GHOST",
        "closure_status": STATUS, "question_class": "development",
        "physical_question_declared": True, "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False, "source.commit": SOURCE,
        "source.parent_commit": "50a1c3822aea46ef7af63fcb768be9b6ec46734e",
        "source.tree": "e5c00a1d189274e8e5137310c0b5a405ed4fc14e",
        "source.subject": "[recovery/godot] Close R61 published authorization control",
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")
    bound = {item["path"]: verify_source_binding(ROOT, SOURCE, item)
             for item in closure["source"]["bindings"]}

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical, gate_id="QSDK-R24D61", source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d61_ghost_attempt_v1",
            "raw": "sporespore_qsdk_r24d61_godot_native_recovery_route_ghost_raw_v1",
            "terminal": "sporespore_qsdk_r24d61_ghost_terminal_v1",
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
        "QSDK_R24D61_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
        physical["native_collection_refusal_reason"], physical["outer_failure_code"],
        "QSDK_R24D61_GODOT_SUPERVISOR_TERMINATION_READY ",
    ), "STDOUT")

    world = bound["sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"].decode()
    route = bound["sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"].decode()
    core = bound["sdk/core/src/recovery.rs"].decode()
    mujoco = bound[
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
    ].decode()
    worker = bound["tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"].decode()
    require_ordered_markers(world, (
        "static func initial_zero_application_v1(",
        "joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)",
        '"zero_command": true',
    ), "WORLD_CAUSE")
    require_ordered_markers(route, (
        "static func initial_native_application_v1(",
        "return NativeWorldScript.initial_zero_application_v1(sdk, model)",
        "static func collect_and_plan_v1(",
        'context, bound, "candidate_command", phase',
    ), "ROUTE_CAUSE")
    require_ordered_markers(worker, (
        "_application_intent = RouteScript.initial_native_application_v1(_sdk, _model)",
        "var native := RouteScript.collect_native_world_observation_v1(",
        "var portable := RouteScript.collect_and_plan_v1(",
    ), "WORKER_CAUSE")
    require_ordered_markers(core, (
        "if applied.zero_command != (memory.arm_kind == RecoveryArmKindV1::MatchedZeroCommand)",
        'return Err("actuation_arm_identity_invalid".to_owned());',
    ), "CORE_CAUSE")
    require_ordered_markers(mujoco, (
        "def _bootstrap_control(", '"arm_kind": arm_kind',
        '"no_actuation_requested": True',
        '"matched_zero_command": arm_kind == "matched_zero_command"',
        'control = _bootstrap_control(core, arm_kind, phase)',
    ), "MUJOCO_REFERENCE")
    verify_exact_paths(closure["causal_diagnosis"], {
        "classification": "deterministic_candidate_bootstrap_applied_actuation_arm_identity_mismatch",
        "core_refusal_reason": "actuation_arm_identity_invalid",
        "godot_initializer_disables_all_motors": True,
        "godot_initializer_application_zero_command": True,
        "godot_collection_request_arm_kind": "candidate_command",
        "core_requires_zero_command_exactly_for_matched_zero_arm": True,
        "first_observation_arm_identity_predicate_is_deterministically_false": True,
        "candidate_bootstrap_may_be_actuation_free_without_being_the_matched_zero_arm": True,
        "mujoco_candidate_bootstrap_is_actuation_free_and_not_matched_zero": True,
        "contact_identity_projection_advanced_past_prior_r24d60_refusal": True,
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
        "r24d61_ghost_invalid_closure_raw_sha256": sha256(raw_closure),
    }, revision=revision)
    print("QSDK_R24D61_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_PASS "
          "attempts=1 models=1 worlds=1 steps=1 observations=0 commands=0 "
          "cause=candidate_bootstrap_arm_identity next=R24D62 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D61_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
