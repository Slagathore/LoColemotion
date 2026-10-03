"""Compact audit of the consumed R24D66 native-behavior attempt."""

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
    "sdk/recovery/r24d66_godot_exact_quaternion_projection_"
    "behavior_invalid_closure_v1.json"
)
SOURCE = "c194a73b9a9df3316c05f160567738d7f4291ca2"
STATUS = (
    "closed_consumed_invalid_candidate_step_81_engine_contact_identity_"
    "validation_refusal"
)
DECISION_TRUE = (
    "behavior_attempt_consumed_for_exact_source",
    "model_construction_completed",
    "candidate_world_build_completed",
    "eighty_one_solver_steps_completed",
    "physics_state_modified",
    "quaternion_projection_repair_held",
    "raw_engine_contact_identity_retained",
    "structured_collection_refusal_retained",
    "failing_identity_field_established",
    "failing_engine_contact_id_established",
    "exact_identity_grammar_mismatch_established",
    "r61_raw_identity_projection_insufficient",
    "integration_validation_failure_established",
    "distinct_successor_source_required",
    "collision_safe_portable_contact_identity_projection_successor_required",
    "raw_to_portable_identity_diagnostics_successor_required",
)
DECISION_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "physics_failure_established",
    "controller_failure_established",
    "same_identity_rerun_permitted",
    "r24d66_requalification_permitted",
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
    "eighty_one_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "quaternion_projection_repair_held",
    "raw_engine_contact_identity_retained",
    "structured_collection_refusal_retained",
    "failing_identity_field_established",
    "failing_engine_contact_id_established",
    "exact_identity_grammar_mismatch_established",
    "integration_validation_failure_established",
)
CLAIM_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
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
                "sporespore_qsdk_r24d66_godot_exact_quaternion_projection_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D66",
            "stage_id": "R24D66-BEHAVIOR",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "e8d82516844b9f18ff74bd51d3e8770b40c95ac2"
            ),
            "source.tree": "5ea91829819a7852c11b768c234039c16495ed4c",
            "source.subject": (
                "[recovery/godot] Close R66: published authorization control"
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
        gate_id="QSDK-R24D66",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d66_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d66_godot_exact_quaternion_projection_"
                "raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d66_behavior_terminal_v1",
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
            "solver_step_count": 81,
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
            "QSDK_R24D66_GODOT_EXACT_QUATERNION_PROJECTION_RAW ",
            physical["collector_refusal_reason"],
            physical["route_failure_code"],
            physical["outer_failure_code"],
            "QSDK_R24D66_GODOT_SUPERVISOR_TERMINATION_READY ",
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
            "static func native_contact_identity_projection_v1(raw_contact_ids: Array)",
            "if seen.has(contact_id):",
            "seen[contact_id] = true",
            "engine_contact_ids.append(contact_id)",
            '"engine_contact_ids": engine_contact_ids',
            '"point_samples_modified": false',
        ),
        "GODOT_CONTACT_IDENTITY_PROJECTION",
    )
    require_ordered_markers(
        protocol,
        (
            "fn valid_id(value: &str) -> bool {",
            "matches!(characters.next(), Some('a'..='z'))",
            "character.is_ascii_lowercase() || character.is_ascii_digit()",
            "fn require_id(value: &str, field: &str) -> Result<()> {",
            'Err(CoreError::Identity(format!("{field}:{value}")))',
        ),
        "CORE_IDENTITY_VALIDATION",
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
                "candidate_step_81_portable_collection_refused_at_engine_"
                "contact_identity_grammar_boundary"
            ),
            "failed_after_solver_step_count": 81,
            "candidate_world_opened": True,
            "matched_zero_world_opened": False,
            "portable_collection_validation_failed": True,
            "behavior_evaluator_invoked": False,
            "quaternion_projection_satisfied_core_contract": True,
            "base_orientation_norm_squared": 1.0,
            "base_orientation_unit_delta": 0.0,
            "core_identity_grammar_bound": True,
            "failing_identity_contains_colon_and_pipe": True,
            "r61_contact_projection_deduplicates_only": True,
            "r61_contact_projection_preserves_raw_identity": True,
            "raw_engine_contact_identity_retained": True,
            "exact_identity_grammar_mismatch_established": True,
            "integration_validation_failure_established": True,
            "physics_failure_established": False,
            "controller_failure_established": False,
            "successor_requires_collision_safe_portable_contact_identity_projection": True,
            "successor_requires_raw_to_portable_identity_diagnostics": True,
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
            "gate_id": "QSDK-R24D67",
            "question_class": "development_integration_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "representative_engine_shape_pair_identity_controls_required": True,
            "collision_mutation_controls_required": True,
            "structured_raw_to_portable_identity_diagnostics_required": True,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "r24d66_may_be_rerun_or_requalified": False,
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
            "r24d66_behavior_invalid_closure_raw_sha256": sha256(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D66_GODOT_EXACT_QUATERNION_PROJECTION_BEHAVIOR_INVALID_"
        "CLOSURE_PASS attempts=1 models=1 worlds=1 steps=81 evaluator=0 "
        "quaternion=valid failure=engine_contact_id_grammar next=R24D67 "
        "sdk1=11/20"
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
            "QSDK_R24D66_GODOT_EXACT_QUATERNION_PROJECTION_BEHAVIOR_"
            f"INVALID_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
