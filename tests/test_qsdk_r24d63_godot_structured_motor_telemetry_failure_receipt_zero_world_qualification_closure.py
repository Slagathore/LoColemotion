"""Compact audit of the retained zero-world R24D63 qualification closure."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, sha256, source_bytes,
    verify_boolean_partition, verify_declared_zero_world_qualification_authority,
    verify_exact_paths, verify_legacy_live_gate_paths,
)

CLOSURE = ROOT / "sdk/recovery/r24d63_godot_structured_motor_telemetry_failure_receipt_zero_world_qualification_closure_v1.json"
SOURCE = "a81c5da756fa7b21d3c6751bdda6ff4017e9f181"
STATUS = "closed_complete_zero_world_structured_motor_telemetry_failure_receipt_qualified_published_closure_control_required_physics_blocked"
CHECKS = (
    "core_dynamic_library_rebuilt", "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed", "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed", "versioning_conformance_passed",
    "source_contract_audit_passed", "production_preflight_passed",
    "worktree_unchanged",
)
TRUE = (
    "r62_invalid_result_preserved", "r62_same_identity_not_rerun",
    "structured_failure_evidence_implemented",
    "exact_first_failed_invariant_retained",
    "all_failed_invariants_retained_in_original_order",
    "native_telemetry_values_retained_json_safely",
    "validation_inputs_and_tolerances_retained",
    "legacy_failure_codes_unchanged", "success_receipt_unchanged",
    "predicate_order_unchanged", "telemetry_tolerances_unchanged",
    "same_pure_validator_used_by_zero_world_and_physical_sampler",
    "zero_world_successor_qualified", "all_declared_mutations_rejected",
    "both_tolerance_boundaries_accepted", "nonfinite_evidence_json_safe",
    "inherited_route_authorization_controls_passed",
    "supervisor_forced_failure_preserved", "missing_physical_switch_refusal_proven",
    "source_population_content_addressed", "retained_evidence_tree_content_addressed",
    "published_closure_control_required",
    "physical_execution_blocked_until_published_closure_control",
)
DECISION_FALSE = (
    "published_closure_control_executed", "physical_ghost_authorized",
    "physical_attempted", "native_world_constructed", "solver_step_executed",
    "native_runtime_observation_collection_executed",
    "portable_command_application_executed", "controller_behavior_evaluated",
    "exact_nominal_godot_prone_to_standing_observed", "prone_to_standing_claimed",
    "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed",
    "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority",
)
CLAIM_FALSE = tuple(
    "controller_physical_viability_proven" if key == "controller_behavior_evaluated" else key
    for key in DECISION_FALSE
)


def audit() -> None:
    closure, contract, receipt, preflight = verify_declared_zero_world_qualification_authority(
        root=ROOT, closure_path=CLOSURE,
        schema_version="sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_zero_world_qualification_closure_v1",
        gate_id="QSDK-R24D63", closure_status=STATUS, source_commit=SOURCE,
        source_subject="[recovery/godot] Freeze R63: structured telemetry receipt",
        source_binding_names=(
            "shared_zero_world_controls", "source_audit", "native_world",
            "native_route", "ghost_binding", "zero_world_worker",
        ),
        predecessor_status="closed_consumed_invalid_second_step_front_left_hip_motor_telemetry_invariant",
        attempt_schema="sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_qualification_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_qualification_receipt_v1",
        qualification_directory_prefix="qsdk-r24d63-godot-structured-telemetry-failure-receipt-qualification-",
        expected_checks=CHECKS, checkout_only_metadata=(), physical_question_declared=False,
        retained_log_markers={
            "source_audit.log": "QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_RECEIPT_SOURCE_PASS",
            "cargo_targeted_tests.log": "test result: ok. 1 passed; 0 failed",
            "production_preflight.log": '"schema_version":"sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_preflight_v1"',
            "versioning_conformance.log": "Ran 6 tests",
        },
    )

    verify_exact_paths(contract, {
        "gate_id": "QSDK-R24D63", "question_class": "development",
        "physical_question_declared": False,
        "telemetry_failure_receipt_contract.validator_function": "native_motor_telemetry_contract_v1",
        "telemetry_failure_receipt_contract.failure_projection_function": "_native_motor_telemetry_failure_v1",
        "telemetry_failure_receipt_contract.success_schema_version": "sporespore_qsdk_r24d60_godot_native_motor_telemetry_contract_v1",
        "telemetry_failure_receipt_contract.failure_detail_schema_version": "sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1",
        "telemetry_failure_receipt_contract.telemetry_impulse_tolerance_nms": 0.000001,
        "telemetry_failure_receipt_contract.net_work_identity_tolerance_j": 1e-12,
        "telemetry_failure_receipt_contract.distinct_invariant_id_count": 21,
        "telemetry_failure_receipt_contract.first_failed_invariant_retained": True,
        "telemetry_failure_receipt_contract.all_failed_invariants_retained": True,
        "telemetry_failure_receipt_contract.full_flat_telemetry_dictionary_retained": True,
        "telemetry_failure_receipt_contract.nonfinite_values_classified_without_invalid_json": True,
        "telemetry_failure_receipt_contract.physical_sampler_calls_exact_validator": True,
        "zero_world_controls.positive_control_count": 4,
        "zero_world_controls.success_schema_unchanged_count": 4,
        "zero_world_controls.mutation_count": 22,
        "zero_world_controls.exact_failure_receipt_count": 22,
        "zero_world_controls.distinct_invariant_id_count": 21,
        "zero_world_controls.cap_boundary_acceptance_count": 1,
        "zero_world_controls.work_identity_boundary_acceptance_count": 1,
        "zero_world_controls.cap_evidence_exact": True,
        "zero_world_controls.nonfinite_evidence_exact": True,
        "published_closure_authorization_control.mode": "AuthorizationControl",
        "published_closure_authorization_control.control_must_close_before_physical_authority": True,
        "complete_zero_world_gate.official_qualification_run_count": 1,
        "next_boundary_if_positive.physical_execution_authorized": False,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 71, "SOURCE_COUNT")
    exact(len(contract["telemetry_failure_receipt_contract"]["ordered_invariant_ids"]),
          21, "INVARIANT_COUNT")

    verify_exact_paths(preflight, {
        "schema_version": "sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_preflight_v1",
        "runtime_id": "sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1",
        "runtime_version": "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2",
        "source_inventory_count": 71, "bound_predecessor_count": 3,
        "inherited_source_inventory_count": 60,
        "telemetry_positive_control_count": 4,
        "telemetry_mutation_count": 22,
        "telemetry_exact_failure_receipt_count": 22,
        "telemetry_distinct_invariant_id_count": 21,
        "structured_telemetry_receipt.positive_control_count": 4,
        "structured_telemetry_receipt.success_schema_unchanged_count": 4,
        "structured_telemetry_receipt.mutation_count": 22,
        "structured_telemetry_receipt.exact_failure_receipt_count": 22,
        "structured_telemetry_receipt.cap_boundary_acceptance_count": 1,
        "structured_telemetry_receipt.work_identity_boundary_acceptance_count": 1,
        "structured_telemetry_receipt.cap_evidence_exact": True,
        "structured_telemetry_receipt.nonfinite_evidence_exact": True,
        "supervisor_forced_failure_control_count": 1,
        "supervisor_projection_receipt.status": "forced_failure_projection_control",
        "missing_physical_switch_refusal_count": 1,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physical_question_opened": False, "prone_to_standing_claimed": False,
    }, "PREFLIGHT")
    q = closure["qualification"]
    exact((q["check_count"], q["checks_passed"], q["source_inventory_count"],
           q["retained_tree"]["file_count"], receipt["held_out_cell_access_count"]),
          (9, 9, 71, 9, 0), "QUALIFICATION_COUNTS")

    exact(closure["physical_authorization"], {
        "schema_version": "sporespore_qsdk_physical_route_authorization_projection_v1",
        "gate_id": "QSDK-R24D63", "question_class": "development",
        "zero_world_qualification_passed": True, "source_freeze_commit": SOURCE,
        "seed": 1935201670, "seed_label": "QSDK-R24D63/ghost/godot/route-smoke-v1",
        "seed_sha256": "sha256:7358d586863168d221b1201486555199304d4336f3df260b9f3f08015e782dbb",
        "held_out": False, "maximum_model_construction_attempt_count": 1,
        "maximum_model_construction_count": 1, "maximum_world_attempt_count": 1,
        "maximum_world_build_count": 1, "maximum_outer_solver_steps": 2,
        "physics_ticks_per_second": 120,
        "outer_step_duration_s": 0.008333333333333333,
        "same_identity_rerun_permitted": False, "recovery_success_required": False,
        "physical_execution_authorized": True, "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "PHYSICAL_AUTHORIZATION")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_zero_world_structured_motor_telemetry_failure_receipt_qualified",
        "new_behavior_threshold_count": 0, "new_empirical_threshold_count": 0,
        "new_margin_count": 0, "observed_physical_cohort_count": 0,
        "held_out_cohort_count": 0, "population_claim_count": 0,
    }, "DECISION")
    verify_boolean_partition(decision, TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"],
                             ("official_zero_world_qualification_passed",) + TRUE,
                             CLAIM_FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D63", "question_class": "development",
        "mode": "AuthorizationControl", "exact_control_execution_limit": 1,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "maximum_physical_steps_authorized": 0, "held_out": False,
        "same_identity_rerun_permitted": False, "physical_execution_authorized": False,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d63_zero_world_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D63_GODOT_STRUCTURED_MOTOR_TELEMETRY_FAILURE_RECEIPT_ZERO_WORLD_"
          "QUALIFICATION_CLOSURE_PASS sources=71 checks=9/9 retained=9 "
          "positive=4 mutations=22/22 invariants=21 boundaries=2 supervisor_exit=23 "
          "models=0 worlds=0 steps=0 authorization_control_required=1 "
          "physics_authorized=0 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D63_GODOT_STRUCTURED_MOTOR_TELEMETRY_FAILURE_RECEIPT_ZERO_WORLD_QUALIFICATION_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
