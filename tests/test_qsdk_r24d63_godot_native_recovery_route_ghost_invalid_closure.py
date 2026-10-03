"""Compact audit of the consumed exact-invariant R24D63 route ghost."""

from pathlib import Path
import struct
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

CLOSURE = ROOT / "sdk/recovery/r24d63_godot_native_recovery_route_ghost_invalid_closure_v1.json"
SOURCE = "c9a09a67ec12bc653fd32149f90c3fd333f87c0a"
STATUS = "closed_consumed_invalid_second_step_net_motor_work_identity_float32_projection_mismatch"
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source", "model_construction_completed",
    "world_build_completed", "two_solver_steps_completed", "physics_state_modified",
    "first_native_observation_completed", "first_portable_route_completed",
    "portable_command_applied", "second_sample_telemetry_refusal_recorded",
    "structured_failure_receipt_retained", "failing_actuator_identity_established",
    "exact_failed_telemetry_subpredicate_established", "failed_native_values_retained",
    "float32_to_binary64_projection_mismatch_established",
    "integration_projection_failure_established", "distinct_successor_source_required",
    "exact_net_work_projection_successor_required",
)
DECISION_FALSE = (
    "second_native_observation_completed", "second_portable_route_completed",
    "controller_behavior_evaluated", "integration_ghost_passed",
    "same_identity_rerun_permitted", "r24d63_requalification_permitted",
    "physics_failure_established", "historical_threshold_changed",
    "historical_selector_changed", "historical_evaluator_changed",
    "historical_result_rewritten", "prone_to_standing_claimed",
    "physical_acceptance_authority", "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source", "invalid_integration_result",
    "model_construction_completed", "world_build_completed", "two_solver_steps_executed",
    "physics_state_modified", "termination_protocol_valid",
    "first_native_observation_completed", "first_portable_route_completed",
    "portable_command_applied", "second_sample_telemetry_refusal_recorded",
    "structured_failure_receipt_retained", "failing_actuator_identity_established",
    "exact_failed_telemetry_subpredicate_established", "failed_native_values_retained",
    "float32_to_binary64_projection_mismatch_established",
    "integration_projection_failure_established",
)
CLAIM_FALSE = (
    "second_native_observation_completed", "second_portable_route_completed",
    "controller_behavior_evaluated", "integration_ghost_passed",
    "physics_failure_established", "prone_to_standing_claimed", "population_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": "sporespore_qsdk_r24d63_godot_native_recovery_route_ghost_invalid_closure_v1",
        "gate_id": "QSDK-R24D63", "stage_id": "R24D63-GHOST",
        "closure_status": STATUS, "question_class": "development",
        "physical_question_declared": True, "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False, "source.commit": SOURCE,
        "source.parent_commit": "f38090c32fae2cac323ac1757773e981f3ac7c1c",
        "source.tree": "ae843423a415ddd3950742188496d03a1d9e6fdc",
        "source.subject": "[recovery/godot] Close R63: published authorization control",
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
        physical=physical, gate_id="QSDK-R24D63", source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d63_ghost_attempt_v1",
            "raw": "sporespore_qsdk_r24d63_godot_native_recovery_route_ghost_raw_v1",
            "terminal": "sporespore_qsdk_r24d63_ghost_terminal_v1",
        },
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(raw, {
        "failure_code": physical["outer_failure_code"],
        "detail.failure_code": physical["native_world_failure_code"],
        "detail.detail.schema_version": "sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1",
        "detail.detail.actuator_id": "front_left_hip_motor",
        "detail.detail.first_failed_invariant_id": "net_motor_work_identity",
        "detail.detail.failed_invariant_count": 1,
        "detail.detail.failed_invariant_ids": ["net_motor_work_identity"],
        "detail.detail.parsed_values.positive_motor_work_j": 0.0034130068961530924,
        "detail.detail.parsed_values.absorbed_motor_work_j": 0.000029909930162830278,
        "detail.detail.parsed_values.net_motor_work_j": 0.003383097006008029,
        "detail.detail.validation_inputs.net_work_identity_tolerance_j": 1e-12,
        "detail.detail.invariant_results.net_motor_work_identity": False,
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

    receipt = raw["detail"]["detail"]
    parsed = receipt["parsed_values"]
    positive = parsed["positive_motor_work_j"]
    absorbed = parsed["absorbed_motor_work_j"]
    reported_net = parsed["net_motor_work_j"]
    binary64_difference = positive - absorbed
    identity_delta = reported_net - binary64_difference
    exact((binary64_difference, identity_delta, abs(identity_delta),
           f32(f32(positive) - f32(absorbed))),
          (physical["binary64_component_difference_j"],
           physical["absolute_identity_delta_j"],
           physical["absolute_identity_delta_j"],
           physical["float32_component_difference_j"]),
          "ARITHMETIC_PROJECTION")
    exact(reported_net, physical["float32_component_difference_j"],
          "FLOAT32_NET_EXACT")
    exact(abs(identity_delta) / receipt["validation_inputs"]["net_work_identity_tolerance_j"],
          physical["identity_delta_over_tolerance"], "DELTA_RATIO")

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / physical["artifacts"]["stdout"]["path"]).read_text(encoding="utf-8")
    require_ordered_markers(stdout, (
        "Godot Engine v4.7.stable.custom_build",
        "QSDK_R24D63_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
        '"first_failed_invariant_id":"net_motor_work_identity"',
        physical["native_world_failure_code"], physical["outer_failure_code"],
        "QSDK_R24D63_GODOT_SUPERVISOR_TERMINATION_READY ",
    ), "STDOUT")

    patch = bound["sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"].decode()
    world = bound["sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"].decode()
    worker = bound["tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"].decode()
    require_ordered_markers(patch, (
        "float positive_motor_work_j = 0.0f;",
        "float absorbed_motor_work_j = 0.0f;",
        'result["positive_motor_work_j"] = motor_telemetry.positive_motor_work_j;',
        'result["absorbed_motor_work_j"] = motor_telemetry.absorbed_motor_work_j;',
        'result["net_motor_work_j"] = motor_telemetry.positive_motor_work_j - motor_telemetry.absorbed_motor_work_j;',
    ), "NATIVE_FLOAT_PROJECTION")
    require_ordered_markers(world, (
        "static func _native_motor_telemetry_failure_v1(",
        '"first_failed_invariant_id": (',
        "static func native_motor_telemetry_contract_v1(",
        'var positive_work := float(telemetry.get("positive_motor_work_j", NAN))',
        'var absorbed_work := float(telemetry.get("absorbed_motor_work_j", NAN))',
        'var net_work := float(telemetry.get("net_motor_work_j", NAN))',
        '"net_motor_work_identity": (',
        "absf(net_work - (positive_work - absorbed_work))",
        "return _native_motor_telemetry_failure_v1(",
        "static func sample_native_step_v1(",
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
        "classification": "second_step_front_left_hip_motor_net_work_identity_failed_at_float32_to_binary64_projection_seam",
        "first_failed_invariant_id": "net_motor_work_identity",
        "failed_invariant_count": 1,
        "failed_telemetry_values_retained": True,
        "failed_invariant_identifier_retained": True,
        "exact_failed_subpredicate_established": True,
        "reported_net_equals_float32_component_subtraction_exactly": True,
        "reported_net_differs_from_binary64_exported_component_subtraction": True,
        "identity_delta_exceeds_unchanged_tolerance": True,
        "identity_delta_j": 4.001776687800884e-11,
        "identity_tolerance_j": 1e-12,
        "identity_delta_over_tolerance": 40.01776687800884,
        "native_patch_subtracts_float_members_before_variant_conversion": True,
        "consumer_subtracts_binary64_variant_values": True,
        "float32_to_binary64_projection_mismatch_established": True,
        "integration_projection_failure_established": True,
        "physics_failure_established": False,
        "behavior_evaluator_invoked": False,
        "successor_requires_exact_net_work_projection_before_another_world": True,
    }, "CAUSE")

    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D64",
        "question_class": "development_integration_successor_not_yet_declared",
        "physical_execution_blocked": True, "maximum_world_attempt_count": 0,
        "maximum_world_build_count": 0, "maximum_physical_steps_authorized": 0,
        "complete_zero_world_gate_required": True,
        "distinct_clean_pushed_source_required": True,
        "full_seeded_ghost_required": False, "additional_physical_canary_required": False,
        "r24d63_may_be_rerun_or_requalified": False,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    revision = publication or None
    raw_closure = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"], "QSDK-R24D45", {
        **closure["live_gate_expectations"],
        "r24d63_ghost_invalid_closure_raw_sha256": sha256(raw_closure),
    }, revision=revision)
    print("QSDK_R24D63_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_PASS "
          "attempts=1 models=1 worlds=1 steps=2 observations=1 commands=1 "
          "invariant=net_motor_work_identity delta_j=4.001776687800884e-11 "
          "cause=float32_projection next=R24D64 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D63_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_INVALID_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
