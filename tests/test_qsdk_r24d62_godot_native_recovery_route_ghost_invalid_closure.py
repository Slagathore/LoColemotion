"""Compact audit of the consumed two-step-invalid R24D62 route ghost."""

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

CLOSURE = ROOT / "sdk/recovery/r24d62_godot_native_recovery_route_ghost_invalid_closure_v1.json"
SOURCE = "cae7ce4da712b158814fbd13a1d13a652c7dd9fa"
STATUS = "closed_consumed_invalid_second_step_front_left_hip_motor_telemetry_invariant"
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source", "model_construction_completed",
    "world_build_completed", "two_solver_steps_completed", "physics_state_modified",
    "bootstrap_identity_repair_advanced_past_prior_refusal",
    "first_native_observation_completed", "first_portable_route_completed",
    "portable_command_applied", "second_sample_telemetry_refusal_recorded",
    "failing_actuator_identity_established", "distinct_successor_source_required",
    "structured_telemetry_failure_receipt_required",
)
DECISION_FALSE = (
    "second_native_observation_completed", "second_portable_route_completed",
    "controller_behavior_evaluated", "integration_ghost_passed",
    "same_identity_rerun_permitted", "r24d62_requalification_permitted",
    "exact_failed_telemetry_subpredicate_established", "physics_failure_established",
    "historical_threshold_changed", "historical_selector_changed",
    "historical_evaluator_changed", "historical_result_rewritten",
    "prone_to_standing_claimed", "physical_acceptance_authority", "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source", "invalid_integration_result",
    "model_construction_completed", "world_build_completed", "two_solver_steps_executed",
    "physics_state_modified", "termination_protocol_valid",
    "bootstrap_identity_repair_advanced_past_prior_refusal",
    "first_native_observation_completed", "first_portable_route_completed",
    "portable_command_applied", "second_sample_telemetry_refusal_recorded",
    "failing_actuator_identity_established",
)
CLAIM_FALSE = (
    "second_native_observation_completed", "second_portable_route_completed",
    "controller_behavior_evaluated", "integration_ghost_passed",
    "exact_failed_telemetry_subpredicate_established", "physics_failure_established",
    "prone_to_standing_claimed", "population_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": "sporespore_qsdk_r24d62_godot_native_recovery_route_ghost_invalid_closure_v1",
        "gate_id": "QSDK-R24D62", "stage_id": "R24D62-GHOST",
        "closure_status": STATUS, "question_class": "development",
        "physical_question_declared": True, "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False, "source.commit": SOURCE,
        "source.parent_commit": "0f56024f2716fda76e40f08f5775f87ec8224167",
        "source.tree": "903d470639df8c426d04f950719305175f15bdfb",
        "source.subject": "[recovery/godot] Close R62 published authorization control",
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
        physical=physical, gate_id="QSDK-R24D62", source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d62_ghost_attempt_v1",
            "raw": "sporespore_qsdk_r24d62_godot_native_recovery_route_ghost_raw_v1",
            "terminal": "sporespore_qsdk_r24d62_ghost_terminal_v1",
        },
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(raw, {
        "failure_code": physical["outer_failure_code"],
        "detail.failure_code": physical["native_world_failure_code"],
        "detail.detail": {},
        "model_construction_attempt_count": 1,
        "model_construction_count": 1, "world_attempt_count": 1,
        "world_build_count": 1, "solver_step_count": 2,
        "native_scene_node_construction_attempted": True,
        "physics_state_modified": True, "physics_failure_is_valid_evidence": True,
        "full_seeded_world_demo": False, "recovery_success_required": False,
        "behavior_evaluator_invocation_count": 0, "threshold_count": 0,
        "margin_count": 0, "held_out_cell_access_count": 0,
    }, "RAW_RESULT")
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / physical["artifacts"]["stdout"]["path"]).read_text(encoding="utf-8")
    require_ordered_markers(stdout, (
        "Godot Engine v4.7.stable.custom_build",
        "QSDK_R24D62_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
        physical["native_world_failure_code"], physical["outer_failure_code"],
        "QSDK_R24D62_GODOT_SUPERVISOR_TERMINATION_READY ",
    ), "STDOUT")

    world = bound["sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"].decode()
    worker = bound["tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"].decode()
    require_ordered_markers(world, (
        "static func native_motor_telemetry_contract_v1(",
        'var read_sequence := int(telemetry.get("read_space_step_sequence", -1))',
        'var net_work := float(telemetry.get("net_motor_work_j", NAN))',
        'return _failure("QSDK_R24D57_WORLD_TELEMETRY_INVALID:%s" % actuator_id)',
        "static func sample_native_step_v1(",
        "JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())",
        "var telemetry_contract := native_motor_telemetry_contract_v1(",
        "return telemetry_contract",
    ), "WORLD_FAILURE_SHAPE")
    require_ordered_markers(worker, (
        "func _capture_first_step() -> void:",
        "var native := RouteScript.collect_native_world_observation_v1(",
        "var portable := RouteScript.collect_and_plan_v1(",
        "var application := RouteScript.apply_control_v1(",
        '"application_intent": application',
        "_application_intent = application",
        "func _capture_second_step_and_finish() -> void:",
        "var native := RouteScript.collect_native_world_observation_v1(",
        '_abort(_failure_code("GHOST_SECOND_NATIVE_SAMPLE_FAILED"), native)',
    ), "WORKER_PROGRESS")
    verify_exact_paths(closure["causal_diagnosis"], {
        "classification": "second_step_front_left_hip_motor_telemetry_invariant_conjunction_failed_exact_subpredicate_unretained",
        "outer_failure_code": "QSDK_R24D62_GHOST_SECOND_NATIVE_SAMPLE_FAILED",
        "native_world_failure_code": "QSDK_R24D57_WORLD_TELEMETRY_INVALID:front_left_hip_motor",
        "failing_actuator_id": "front_left_hip_motor",
        "failing_actuator_is_first_in_declared_order": True,
        "first_native_observation_completed": True,
        "first_portable_route_completed": True,
        "first_portable_command_application_completed": True,
        "second_solver_step_completed": True,
        "failure_occurs_inside_in_run_native_motor_telemetry_contract": True,
        "failed_telemetry_value_retained": False,
        "failed_invariant_identifier_retained": False,
        "exact_failed_subpredicate_established": False,
        "physics_failure_established": False,
        "integration_transport_failure_established": False,
        "behavior_evaluator_invoked": False,
        "bootstrap_identity_repair_advanced_past_r24d61_refusal": True,
        "successor_requires_structured_telemetry_failure_receipt_before_another_world": True,
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
        "r24d62_ghost_invalid_closure_raw_sha256": sha256(raw_closure),
    }, revision=revision)
    print("QSDK_R24D62_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_PASS "
          "attempts=1 models=1 worlds=1 steps=2 observations=1 commands=1 "
          "cause=front_left_hip_motor_telemetry_unresolved next=R24D63 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D62_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
