"""Compact audit of the consumed R24D67 native-behavior attempt."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
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
    "sdk/recovery/r24d67_godot_portable_contact_identity_"
    "behavior_invalid_closure_v1.json"
)
SOURCE = "001bd02a8314b3eb36db08a1570d83292353437c"
STATUS = (
    "closed_consumed_invalid_candidate_step_90_actuator_budget_predicate_"
    "mismatch"
)
CAP_NMS = 0.05637374829312699
TOLERANCE_NMS = 1.0e-6
UPPER_BOUND_NMS = 0.05637474829312699
DECISION_TRUE = (
    "behavior_attempt_consumed_for_exact_source",
    "model_construction_completed",
    "candidate_world_build_completed",
    "ninety_solver_steps_completed",
    "physics_state_modified",
    "quaternion_projection_repair_held",
    "portable_contact_identity_projection_repair_held",
    "structured_collection_refusal_retained",
    "failing_actuator_id_established",
    "native_in_run_budget_predicate_accepted",
    "portable_core_budget_predicate_refused",
    "actuator_budget_predicate_mismatch_established",
    "integration_validation_failure_established",
    "distinct_successor_source_required",
    "exact_rejected_budget_diagnostics_successor_required",
    "strict_budget_predicate_alignment_successor_required",
)
DECISION_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "exact_applied_angular_impulse_retained",
    "engine_solver_overshoot_established",
    "host_cap_mapping_fault_established",
    "physics_failure_established",
    "controller_failure_established",
    "same_identity_rerun_permitted",
    "r24d67_requalification_permitted",
    "historical_threshold_changed",
    "historical_margin_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "invalid_integration_result",
    "model_construction_completed",
    "candidate_world_build_completed",
    "ninety_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "quaternion_projection_repair_held",
    "portable_contact_identity_projection_repair_held",
    "structured_collection_refusal_retained",
    "failing_actuator_id_established",
    "native_in_run_budget_predicate_accepted",
    "portable_core_budget_predicate_refused",
    "actuator_budget_predicate_mismatch_established",
    "integration_validation_failure_established",
)
CLAIM_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "exact_applied_angular_impulse_retained",
    "engine_solver_overshoot_established",
    "host_cap_mapping_fault_established",
    "physics_failure_established",
    "controller_failure_established",
    "exact_nominal_godot_prone_to_standing_observed",
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
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D67",
            "stage_id": "R24D67-BEHAVIOR",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "7a77d9c6187a546c777c0651d767a6c37f55dfb7"
            ),
            "source.tree": "9e8f4f91821a2f06d74bfcbeca8ed5a768ef252b",
            "source.subject": (
                "[recovery/godot] Close R67: published authorization control"
            ),
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%T", SOURCE),
        closure["source"]["tree"],
        "SOURCE_TREE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%s", SOURCE),
        closure["source"]["subject"],
        "SOURCE_SUBJECT",
    )
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D67",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d67_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d67_behavior_terminal_v1",
        },
        raw_count_keys=(
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
            "failure_code": physical["outer_failure_code"],
            "detail.failure_code": physical["route_failure_code"],
            "detail.detail.schema_version": (
                "sporespore_recovery_native_collection_receipt_v2"
            ),
            "detail.detail.support_status": "invalid_observation",
            "detail.detail.refusal_reason": physical["collector_refusal_reason"],
            "detail.detail.observation": None,
            "detail.detail.observation_sha256": None,
            "detail.detail.supplied_native_post_step_observation_validated": False,
            "detail.detail.base_orientation_diagnostic.schema_version": (
                "sporespore_qsdk_r24d66_godot_quaternion_scalar_diagnostic_v1"
            ),
            "detail.detail.base_orientation_diagnostic.norm_squared": 1.0,
            "detail.detail.base_orientation_diagnostic.unit_delta": 0.0,
            "detail.detail.base_orientation_diagnostic.within_core_unit_contract": True,
            "model_construction_attempt_count": 1,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 90,
            "maximum_solver_step_count": 2400,
            "behavior_evaluator_invocation_count": 0,
            "held_out_cell_access_count": 0,
            "physical_question_opened": True,
            "physics_state_modified": True,
            "physics_failure_is_valid_evidence": True,
            "recovery_success_required_for_valid_result": False,
        },
        "RAW_RESULT",
    )
    verify_exact_paths(
        terminal,
        {
            "physical_question_kind": "behavior_development",
            "integration_ghost_passed": False,
            "behavior_development_completed": False,
            "completed_utc": physical["completed_utc"],
            "worker.termination_protocol_failure_code": "",
            "recovery_success_observed": False,
        },
        "TERMINAL",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (
        evidence / physical["artifacts"]["stdout"]["path"]
    ).read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_RAW ",
            physical["collector_refusal_reason"],
            physical["route_failure_code"],
            physical["outer_failure_code"],
            "QSDK_R24D67_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )

    world = bound[
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
    ].decode()
    core = bound["sdk/core/src/recovery_runtime.rs"].decode()
    cap_binding = bound[
        "sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
    ].decode()
    worker = bound[
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    ].decode()
    require_ordered_markers(
        world,
        (
            "const TELEMETRY_IMPULSE_TOLERANCE_NMS := 1.0e-6",
            "static func native_motor_telemetry_contract_v1(",
            '"signed_motor_impulse_within_outer_step_cap": (',
            "absf(signed_impulse)",
            "<= maximum_outer_step_impulse_nms + TELEMETRY_IMPULSE_TOLERANCE_NMS",
            "var telemetry_contract := native_motor_telemetry_contract_v1(",
            'var signed_impulse := float(telemetry_contract["signed_motor_impulse_nms"])',
            "ordered_applied_impulses.append(",
            '"applied_angular_impulse_nms": signed_impulse',
        ),
        "GODOT_NATIVE_PREDICATE_AND_FORWARDING",
    )
    require_ordered_markers(
        world,
        (
            "static func portable_contact_identity_v1(raw_contact_id: String)",
            "static func native_contact_identity_projection_v2(raw_contact_ids: Array)",
            "var identity_projection := native_contact_identity_projection_v2(raw_ids)",
        ),
        "GODOT_PORTABLE_CONTACT_IDENTITY_PROJECTION",
    )
    require_ordered_markers(
        core,
        (
            "fn validate_observation<O: RecoveryObservationLike>(",
            ".state",
            ".validate(&compiled.morphology)",
            "let applied = &observation.applied_actuation;",
            'finite(item.applied_angular_impulse_nms, "applied_angular_impulse")?;',
            "if item.applied_angular_impulse_nms.abs() > cap.maximum_outer_step_impulse_nms",
            '"published_actuator_budget_exceeded:{}"',
        ),
        "PORTABLE_CORE_STRICT_PREDICATE",
    )
    require_ordered_markers(
        cap_binding,
        (
            "const ORDERED_ACTUATOR_IDS := [",
            '"front_left_hip_motor"',
            '"front_left_knee_motor"',
            '"front_right_hip_motor"',
            '"front_right_knee_motor"',
            '"rear_left_hip_motor"',
            "const ORDERED_CAPS_NMS := [",
            "0.05362625170687301",
            "0.4567500054836273",
            "0.05362625170687301",
            "0.4567500054836273",
            "0.05637374829312699",
        ),
        "PUBLISHED_REAR_LEFT_HIP_CAP",
    )
    require_ordered_markers(
        worker,
        (
            "func _capture_completed_step() -> void:",
            "var native := RouteScript.collect_native_world_observation_v1(",
            "_total_solver_step_count += 1",
            "var advanced := RouteScript.advance_behavior_v4(",
            '_abort(_failure_code("BEHAVIOR_PORTABLE_ADVANCE_FAILED"), advanced)',
        ),
        "WORKER_FAILURE_ORDER",
    )

    exact(
        CAP_NMS + TOLERANCE_NMS,
        UPPER_BOUND_NMS,
        "DECLARED_IMPULSE_INTERVAL_ARITHMETIC",
    )
    verify_exact_paths(
        physical,
        {
            "published_maximum_outer_step_impulse_nms": CAP_NMS,
            "native_telemetry_impulse_tolerance_nms": TOLERANCE_NMS,
            "inferred_absolute_impulse_strict_lower_bound_nms": CAP_NMS,
            "inferred_absolute_impulse_inclusive_upper_bound_nms": UPPER_BOUND_NMS,
            "exact_applied_angular_impulse_retained": False,
        },
        "PHYSICAL_INTERVAL",
    )
    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "classification": (
                "candidate_step_90_core_strict_actuator_budget_refusal_after_"
                "tolerant_native_validation"
            ),
            "failed_after_solver_step_count": 90,
            "candidate_world_opened": True,
            "matched_zero_world_opened": False,
            "portable_collection_validation_failed": True,
            "behavior_evaluator_invoked": False,
            "quaternion_projection_satisfied_core_contract": True,
            "base_orientation_norm_squared": 1.0,
            "base_orientation_unit_delta": 0.0,
            "contact_identity_projection_repair_held_at_later_refusal": True,
            "same_published_actuator_profile_identity_bound": True,
            "published_maximum_outer_step_impulse_nms": CAP_NMS,
            "native_telemetry_impulse_tolerance_nms": TOLERANCE_NMS,
            "unchanged_measurement_forwarded_from_native_validator_to_core": True,
            "native_in_run_budget_predicate_passed": True,
            "portable_core_budget_predicate_refused": True,
            "exact_applied_angular_impulse_retained": False,
            "inferred_absolute_impulse_strict_lower_bound_nms": CAP_NMS,
            "inferred_absolute_impulse_inclusive_upper_bound_nms": UPPER_BOUND_NMS,
            "actuator_budget_predicate_mismatch_established": True,
            "integration_validation_failure_established": True,
            "engine_solver_overshoot_established": False,
            "host_cap_mapping_fault_established": False,
            "physics_failure_established": False,
            "controller_failure_established": False,
            "successor_requires_exact_rejected_budget_diagnostics": True,
            "successor_requires_one_identical_strict_published_budget_predicate": True,
            "successor_solution_selected": False,
        },
        "CAUSE",
    )

    verify_boolean_partition(
        closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION"
    )
    verify_boolean_partition(
        closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM"
    )
    exact(
        closure["sdk_status"],
        {
            "sdk1_milestone_advanced": False,
            "sdk1_completed_steps": 11,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": 11,
            "full_program_total_steps": 25,
        },
        "SDK_STATUS",
    )
    verify_exact_paths(
        closure["next_boundary"],
        {
            "gate_id": "QSDK-R24D68",
            "question_class": "development_integration_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "exact_rejected_budget_diagnostics_required": True,
            "native_and_core_acceptance_predicate_identity_required": True,
            "strict_published_cap_preserved": True,
            "raw_measurement_clamping_permitted": False,
            "published_budget_change_permitted": False,
            "repair_mechanism_not_yet_selected": True,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "r24d67_may_be_rerun_or_requalified": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    revision = publication or None
    raw_closure = CLOSURE.read_bytes() if revision is None else source_bytes(
        ROOT, revision, relative
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d67_behavior_invalid_closure_raw_sha256": sha256(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_BEHAVIOR_INVALID_"
        "CLOSURE_PASS attempts=1 models=1 worlds=1 steps=90 evaluator=0 "
        "identity=valid failure=actuator_budget_predicate_mismatch "
        "next=R24D68 sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        OSError,
        KeyError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_BEHAVIOR_"
            f"INVALID_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
