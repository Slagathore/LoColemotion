"""Compact audit of the consumed R24D65 native-behavior attempt."""

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
    "sdk/recovery/r24d65_godot_native_recovery_behavior_"
    "invalid_closure_v1.json"
)
SOURCE = "7f99a67775edf6f66dece4b39d4ab95ccc6e3a4e"
STATUS = (
    "closed_consumed_invalid_candidate_step_24_base_quaternion_"
    "unit_validation_refusal"
)
DECISION_TRUE = (
    "behavior_attempt_consumed_for_exact_source",
    "model_construction_completed",
    "candidate_world_build_completed",
    "twenty_four_solver_steps_completed",
    "physics_state_modified",
    "native_sample_completed_before_portable_refusal",
    "structured_collection_refusal_retained",
    "failing_state_path_established",
    "unit_quaternion_representation_contract_failure_established",
    "integration_validation_failure_established",
    "distinct_successor_source_required",
    "exact_quaternion_projection_successor_required",
    "rejected_quaternion_diagnostics_successor_required",
)
DECISION_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "exact_numerical_delta_established",
    "exact_low_level_numeric_cause_established",
    "physics_failure_established",
    "same_identity_rerun_permitted",
    "r24d65_requalification_permitted",
    "historical_threshold_changed",
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
    "twenty_four_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "native_sample_completed_before_portable_refusal",
    "structured_collection_refusal_retained",
    "failing_state_path_established",
    "unit_quaternion_representation_contract_failure_established",
    "integration_validation_failure_established",
)
CLAIM_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "exact_numerical_delta_established",
    "exact_low_level_numeric_cause_established",
    "physics_failure_established",
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
                "sporespore_qsdk_r24d65_godot_native_recovery_behavior_"
                "invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D65",
            "stage_id": "R24D65-BEHAVIOR",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "22268c51e63b460eeaf021757ca3f58ba0cedb30"
            ),
            "source.tree": "6956f02fbd6093ec389814f2a2829c718a2f23b3",
            "source.subject": (
                "[recovery/godot] Close R65: published authorization control"
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
        gate_id="QSDK-R24D65",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d65_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d65_godot_native_recovery_behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d65_behavior_terminal_v1",
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
            "model_construction_attempt_count": 1,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 24,
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
            "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_RAW ",
            physical["collector_refusal_reason"],
            physical["route_failure_code"],
            physical["outer_failure_code"],
            "QSDK_R24D65_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )

    world = bound[
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
    ].decode()
    protocol = bound["sdk/core/src/protocol.rs"].decode()
    worker = bound[
        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
    ].decode()
    require_ordered_markers(
        world,
        (
            '"base_pose_world": {',
            '"orientation_xyzw": _quaternion_json(',
            "torso_transform.basis.get_rotation_quaternion()",
            "static func _quaternion_json(value: Quaternion) -> Dictionary:",
            "var normalized := value.normalized()",
        ),
        "GODOT_QUATERNION_PROJECTION",
    )
    require_ordered_markers(
        protocol,
        (
            "pub fn validate(self, field: &str) -> Result<()> {",
            "let norm_squared = self.x * self.x + self.y * self.y",
            "if (norm_squared - 1.0).abs() > 1.0e-9 {",
            'CoreError::Frame(format!("{field}_quaternion_not_unit"))',
        ),
        "CORE_QUATERNION_VALIDATION",
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

    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "classification": (
                "candidate_step_24_portable_collection_refused_at_base_"
                "quaternion_unit_representation_boundary"
            ),
            "failed_after_solver_step_count": 24,
            "candidate_world_opened": True,
            "matched_zero_world_opened": False,
            "native_sample_completed_before_portable_refusal": True,
            "portable_collection_validation_failed": True,
            "behavior_evaluator_invoked": False,
            "godot_quaternion_projection_calls_normalized": True,
            "core_unit_norm_squared_tolerance": 1e-9,
            "core_unit_norm_squared_check_bound": True,
            "offending_quaternion_components_retained": False,
            "offending_quaternion_norm_squared_retained": False,
            "exact_numerical_delta_established": False,
            "exact_low_level_numeric_cause_established": False,
            "unit_quaternion_representation_contract_failure_established": True,
            "integration_validation_failure_established": True,
            "physics_failure_established": False,
            "successor_requires_exact_quaternion_projection": True,
            "successor_requires_structured_rejected_quaternion_diagnostics": True,
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
            "gate_id": "QSDK-R24D66",
            "question_class": "development_integration_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "representative_nonidentity_quaternion_controls_required": True,
            "structured_forced_refusal_control_required": True,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "r24d65_may_be_rerun_or_requalified": False,
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
            "r24d65_behavior_invalid_closure_raw_sha256": sha256(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_INVALID_CLOSURE_PASS "
        "attempts=1 models=1 worlds=1 steps=24 evaluator=0 "
        "failure=base_quaternion_not_unit exact_delta=unretained "
        "next=R24D66 sdk1=11/20"
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
            "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_INVALID_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
