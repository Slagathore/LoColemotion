"""Compact audit of the consumed positive R24D64 native route ghost."""

from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, require, require_ordered_markers,
    sha256, source_bytes, verify_boolean_partition, verify_exact_paths,
    verify_legacy_live_gate_paths, verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / "sdk/recovery/r24d64_godot_native_recovery_route_ghost_positive_closure_v1.json"
SOURCE = "37cd6cb3fc3a3d24fa207ceda93222c78c8df1da"
STATUS = "closed_valid_complete_integration_ghost_exact_net_work_projection_route_passed_distinct_r24d65_successor_required"
PROJECTION_SCHEMA = "sporespore_qsdk_r24d64_native_float32_to_binary64_net_work_projection_v1"
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source", "model_construction_completed",
    "world_build_completed", "two_solver_steps_completed", "physics_state_modified",
    "first_native_observation_completed", "first_portable_route_completed",
    "portable_command_applied", "second_native_observation_completed",
    "second_portable_route_completed", "integration_ghost_passed",
    "all_native_float32_work_identities_exact",
    "all_public_binary64_work_identities_exact", "all_projection_deltas_retained",
    "distinct_recovery_behavior_successor_required",
)
DECISION_FALSE = (
    "same_identity_rerun_permitted", "r24d64_requalification_permitted",
    "integration_refusal_observed", "physics_failure_observed",
    "controller_behavior_evaluated", "recovery_success_established",
    "historical_threshold_changed", "historical_selector_changed",
    "historical_evaluator_changed", "historical_result_rewritten",
    "prone_to_standing_claimed", "physical_acceptance_authority", "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained", "integration_ghost_attempt_consumed_for_exact_source",
    "valid_complete_integration_result", "model_construction_completed",
    "world_build_completed", "two_solver_steps_executed", "physics_state_modified",
    "termination_protocol_valid", "first_native_observation_completed",
    "first_portable_route_completed", "portable_command_applied",
    "second_native_observation_completed", "second_portable_route_completed",
    "integration_ghost_passed", "all_native_float32_work_identities_exact",
    "all_public_binary64_work_identities_exact", "all_projection_deltas_retained",
)
CLAIM_FALSE = (
    "physics_failure_observed", "controller_physical_viability_proven",
    "recovery_success_established", "prone_to_standing_claimed", "population_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def dictionaries_with_key(value: object, key: str) -> list[dict]:
    found: list[dict] = []
    if isinstance(value, dict):
        if key in value:
            found.append(value)
        for child in value.values():
            found.extend(dictionaries_with_key(child, key))
    elif isinstance(value, list):
        for child in value:
            found.extend(dictionaries_with_key(child, key))
    return found


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": "sporespore_qsdk_r24d64_godot_native_recovery_route_ghost_positive_closure_v1",
        "gate_id": "QSDK-R24D64", "stage_id": "R24D64-GHOST",
        "closure_status": STATUS, "question_class": "development",
        "physical_question_declared": True, "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False, "source.commit": SOURCE,
        "source.parent_commit": "518aafa0907e11398da35dab679df969ce2a97dc",
        "source.tree": "cd95d581e5bac9530ec32315ea29d7503d9bbafe",
        "source.subject": "[recovery/godot] Close R64: published authorization control",
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(closure["authorization_dependency"], {
        "qualification_closure_raw_sha256": "sha256:49768f2cdc6aa77f40f26b0e27d89a17962a4f00ac0bd91f98a166ebed4dcf1b",
        "qualification_source_commit": "1007801eb39a60044c9236d3485dfc2da913e4bb",
        "authorization_control_closure_raw_sha256": "sha256:61cb619f786460bd8800cbdae18e1584dd7eaa2e1c66c432a69253522cb1d54e",
        "authorization_control_source_commit": "518aafa0907e11398da35dab679df969ce2a97dc",
        "complete_zero_world_gate_satisfied": True,
        "published_closure_control_satisfied": True,
        "same_identity_requalification_permitted": False,
    }, "AUTHORIZATION")

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical, gate_id="QSDK-R24D64", source_commit=SOURCE,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d64_ghost_attempt_v1",
            "raw": "sporespore_qsdk_r24d64_godot_native_recovery_route_ghost_raw_v1",
            "terminal": "sporespore_qsdk_r24d64_ghost_terminal_v1",
        },
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(raw, {
        "ok": True, "model_construction_attempt_count": 1,
        "model_construction_count": 1, "world_attempt_count": 1,
        "world_build_count": 1, "solver_step_count": 2,
        "native_scene_node_construction_attempted": True,
        "physics_state_modified": True, "physics_failure_is_valid_evidence": True,
        "full_seeded_world_demo": False, "recovery_success_required": False,
        "behavior_evaluator_invocation_count": 0, "threshold_count": 0,
        "margin_count": 0, "held_out_cell_access_count": 0,
        "portable_collection_count": 2, "portable_control_plan_count": 2,
        "portable_command_application_count": 1, "validated_command_count": 8,
        "host_write_count": 8, "host_readback_count": 8,
        "adapter_side_discrete_staging_event_count": 0,
        "missing_measurement_synthesis_count": 0,
    }, "RAW_RESULT")
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")

    for name, solver_step, semantic_step in (
        ("first_step", 1, 1.0), ("second_step", 2, 2.0)
    ):
        step = raw[name]
        verify_exact_paths(step["native_route"], {
            "ok": True, "solver_step_count": solver_step,
            "world_attempt_count": 1, "world_build_count": 1,
            "physics_state_modified": True,
        }, f"{name.upper()}_NATIVE")
        verify_exact_paths(step["portable_route"], {
            "ok": True, "solver_step_count": 0, "world_attempt_count": 0,
            "world_build_count": 0, "physics_state_modified": False,
            "control_receipt.phase": "establish_distal_support",
            "control_receipt.semantic_step": semantic_step,
            "control_receipt.controller_implemented": True,
            "control_receipt.support_status": "supported_exact",
            "control_receipt.refusal_reason": None,
            "control_receipt.matched_zero_command": False,
            "control_receipt.no_actuation_requested": False,
        }, f"{name.upper()}_PORTABLE")
        exact(len(step["portable_route"]["control_receipt"]["ordered_commands"]),
              8, f"{name.upper()}_COMMAND_COUNT")

    application = raw["first_step"]["application_intent"]
    verify_exact_paths(application, {
        "ok": True, "phase": "establish_distal_support", "semantic_step": 2,
        "source_control_semantic_step": 1, "validated_command_count": 8,
        "host_write_count": 8, "host_readback_count": 8, "motor_enabled_count": 8,
        "fallback_control_count": 0, "root_actuation_count": 0,
    }, "APPLICATION")
    exact((len(application["ordered_intents"]), len(application["ordered_receipts"])),
          (8, 8), "APPLICATION_ORDERED_COUNTS")

    first = dictionaries_with_key(raw["first_step"], "net_motor_work_projection_schema")
    second = dictionaries_with_key(raw["second_step"], "net_motor_work_projection_schema")
    records = first + second
    exact((len(first), len(second), len(records)), (8, 8, 16), "PROJECTION_COUNTS")
    for index, record in enumerate(records):
        positive = record["positive_motor_work_j"]
        absorbed = record["absorbed_motor_work_j"]
        native = record["native_net_motor_work_j"]
        public = record["net_motor_work_j"]
        delta = record["net_motor_work_projection_delta_j"]
        exact(record["net_motor_work_projection_schema"], PROJECTION_SCHEMA,
              f"PROJECTION_SCHEMA_{index}")
        exact(native, f32(f32(positive) - f32(absorbed)),
              f"NATIVE_FLOAT32_IDENTITY_{index}")
        exact(public, positive - absorbed, f"PUBLIC_BINARY64_IDENTITY_{index}")
        exact(delta, native - public, f"PROJECTION_DELTA_{index}")
    exact(sum(record["net_motor_work_j"] == 0.0 for record in records),
          8, "ZERO_WORK_PROJECTION_COUNT")
    exact(sum(record["net_motor_work_j"] != 0.0 for record in records),
          8, "NONZERO_WORK_PROJECTION_COUNT")
    exact(sum(record["net_motor_work_projection_delta_j"] != 0.0 for record in records),
          8, "NONZERO_PROJECTION_DELTA_COUNT")
    exact(max(abs(record["net_motor_work_projection_delta_j"]) for record in records),
          physical["maximum_absolute_projection_delta_j"], "MAX_PROJECTION_DELTA")

    interventions = dictionaries_with_key(raw, "external_interventions")
    exact(len(interventions), 10, "EXTERNAL_INTERVENTION_RECEIPT_COUNT")
    require(all(sum(receipt["external_interventions"].values()) == 0
                for receipt in interventions), "EXTERNAL_INTERVENTIONS_NONZERO")

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / physical["artifacts"]["stdout"]["path"]).read_text(encoding="utf-8")
    require_ordered_markers(stdout, (
        "Godot Engine v4.7.stable.custom_build",
        "QSDK_R24D64_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
        '\"status\":\"valid_complete_integration_ghost\"',
        "QSDK_R24D64_GODOT_SUPERVISOR_TERMINATION_READY ",
    ), "STDOUT")

    verify_exact_paths(closure["observed_integration"], {
        "classification": "valid_complete_godot_jolt_two_step_engine_neutral_recovery_route",
        "native_observation_count": 2, "portable_collection_count": 2,
        "portable_control_plan_count": 2, "portable_command_application_count": 1,
        "ordered_command_count_per_plan": 8, "first_native_solver_step": 1,
        "second_native_solver_step": 2,
        "controller_phase_at_both_steps": "establish_distal_support",
        "projection_schema": PROJECTION_SCHEMA, "projection_record_count": 16,
        "native_float32_identity_count": 16, "public_binary64_identity_count": 16,
        "maximum_absolute_projection_delta_j": 1.1641532182693481e-10,
        "all_projection_deltas_retained": True, "integration_refusal_observed": False,
        "physics_failure_observed": False, "behavior_evaluator_invoked": False,
        "recovery_success_established": False, "prone_to_standing_established": False,
    }, "OBSERVED")
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D65",
        "question_class": "development_behavior_successor_not_yet_declared",
        "physical_execution_blocked": True, "maximum_world_attempt_count": 0,
        "maximum_world_build_count": 0, "maximum_physical_steps_authorized": 0,
        "complete_zero_world_gate_required": True,
        "distinct_clean_pushed_source_required": True,
        "r24d64_may_be_rerun_or_requalified": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    revision = publication or None
    raw_closure = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"], "QSDK-R24D45", {
        **closure["live_gate_expectations"],
        "r24d64_ghost_positive_closure_raw_sha256": sha256(raw_closure),
    }, revision=revision)
    print("QSDK_R24D64_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_POSITIVE_CLOSURE_PASS "
          "attempts=1 models=1 worlds=1 steps=2 observations=2 plans=2 commands=8 "
          "projection_records=16 next=R24D65 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D64_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_POSITIVE_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
