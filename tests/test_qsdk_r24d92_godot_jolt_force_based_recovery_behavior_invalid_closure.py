#!/usr/bin/env python3
"""Audit consumed R92 and its post-run native-engine invalidation."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    canonical_bytes,
    complete_in_run_physical_invariant_projection,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_force_based_joint_impulse_application,
    verify_legacy_live_gate_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "invalid_closure_v1.json"
)
SOURCE = "d242d92dfe968e2a5f4fe8a24acb096ef704cd8e"
STATUS = (
    "closed_consumed_complete_producer_negative_invalid_for_physical_"
    "inference_native_angular_velocity_limit_assertions"
)
COUNT_KEYS = tuple(
    """
model_construction_attempt_count model_construction_count world_attempt_count
world_build_count solver_step_count behavior_evaluator_invocation_count
complete_trace_count in_run_invariant_receipt_count held_out_cell_access_count
""".split()
)
DECISION_TRUE = tuple(
    """
behavior_attempt_retained behavior_attempt_consumed_for_exact_source
producer_complete_negative_observed portable_evaluator_receipt_accepted
all_declared_in_run_physical_invariants_passed
native_angular_velocity_limit_assertions_observed
unmodeled_native_engine_health_failure_established
in_run_physical_invariant_coverage_gap_established
closure_invalid_for_behavioral_inference shared_engine_diagnostic_invariant_required
distinct_successor_required
""".split()
)
DECISION_FALSE = tuple(
    """
same_identity_rerun_permitted r24d92_requalification_permitted
scientific_behavior_negative_accepted recovery_success_observed
force_based_controller_failure_established force_based_adapter_failure_established
native_jolt_general_failure_established actuator_cap_inadequacy_established
behavior_threshold_inadequacy_established
raising_native_angular_velocity_limit_authorized historical_threshold_changed
historical_margin_changed historical_selector_changed historical_evaluator_changed
historical_result_rewritten exact_nominal_godot_prone_to_standing_observed
prone_to_standing_claimed repeatability_rate_claimed population_claimed
held_out_validation_claimed cross_engine_recovery_claimed
cross_engine_equivalence_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split()
)
CLAIM_TRUE = tuple(
    """
behavior_attempt_retained behavior_attempt_consumed_for_exact_source
producer_complete_negative_observed portable_evaluator_receipt_accepted
all_536_declared_in_run_physical_invariants_passed
native_angular_velocity_limit_assertions_observed
unmodeled_native_engine_health_failure_established
closure_invalid_for_behavioral_inference distinct_successor_required
""".split()
)
CLAIM_FALSE = tuple(
    """
clean_physical_behavior_negative_established
force_based_controller_failure_established force_based_adapter_failure_established
native_jolt_general_failure_established actuator_cap_inadequacy_established
exact_nominal_godot_prone_to_standing_observed prone_to_standing_claimed
repeatability_rate_claimed population_claimed held_out_validation_claimed
cross_engine_recovery_claimed cross_engine_equivalence_claimed
sdk1_milestone_advanced physical_acceptance_authority release_authority
""".split()
)


def verify_arm_invariants(
    arm: dict, summary: dict, arm_kind: str, expected_count: int
) -> None:
    receipts = arm["in_run_invariant_receipts"]
    exact(len(receipts), expected_count, f"{arm_kind}:INVARIANT_COUNT")
    exact(
        [item["semantic_step"] for item in receipts],
        list(range(1, expected_count + 1)),
        f"{arm_kind}:SEMANTIC_STEPS",
    )
    exact(
        [item["native_space_step_sequence"] for item in receipts],
        list(range(1, expected_count + 1)),
        f"{arm_kind}:NATIVE_STEPS",
    )
    require(
        all(
            item["schema_version"]
            == "sporespore_qsdk_r24d65_godot_in_run_invariant_receipt_v1"
            and item["arm_kind"] == arm_kind
            and item["all_in_run_physical_invariants_passed"] is True
            and item["missing_measurement_synthesis_count"] == 0
            and item["adapter_side_discrete_staging_event_count"] == 0
            and sum(item["external_interventions"].values()) == 0
            and item["controller_ownership"]["fallback_controller_active"]
            is False
            and item["controller_ownership"]["source_measurement"] is True
            for item in receipts
        ),
        f"{arm_kind}:DECLARED_IN_RUN_INVARIANTS",
    )
    exact(
        sha256(canonical_bytes(receipts)),
        summary["in_run_invariant_population_sha256"],
        f"{arm_kind}:INVARIANT_POPULATION",
    )
    exact(summary["trace_v3_sha256"], arm["trace_v3_sha256"], f"{arm_kind}:TRACE")


def force_application_projection(raw: dict) -> dict[str, object]:
    candidate = raw["candidate_arm"]
    zero = raw["matched_zero_arm"]
    active = [
        item
        for item in candidate["command_application_receipts"]
        if item.get("validated_command_count") == 8
    ]
    exact(len(active), 240, "FORCE_ACTIVE_APPLICATIONS")
    projections = [
        verify_force_based_joint_impulse_application(
            item,
            actuator_mapping_id=raw["actuator_mapping_id"],
            work_mapping_id=raw["work_mapping_id"],
            joint_count=8,
        )
        for item in active
    ]
    observations = {
        item["semantic_step"]: item
        for item in candidate["trace_v3"]["observations"]
    }
    applied_bindings = 0
    for application, projection in zip(active, projections, strict=True):
        applied = observations[application["semantic_step"]]["applied_actuation"]
        exact(applied["source_measurement"], True, "FORCE_APPLIED_SOURCE")
        exact(
            [
                (item["actuator_id"], item["applied_signed_joint_impulse_nms"])
                for item in projection["receipts"]
            ],
            [
                (item["actuator_id"], item["applied_angular_impulse_nms"])
                for item in applied["ordered_applied_impulses"]
            ],
            "FORCE_APPLIED_BINDING",
        )
        applied_bindings += 1

    zero_impulses = [
        impulse
        for observation in zero["trace_v3"]["observations"]
        for impulse in observation["applied_actuation"]["ordered_applied_impulses"]
    ]
    require(
        all(item["applied_angular_impulse_nms"] == 0.0 for item in zero_impulses),
        "MATCHED_ZERO_IMPULSES",
    )
    require(
        all(
            item["motor_enabled_count"] == 0
            and item.get("root_actuation_count", 0) == 0
            for item in candidate["command_application_receipts"]
        ),
        "CANDIDATE_NO_HARD_MOTOR_OR_ROOT_ACTUATION",
    )
    return {
        "force_application_active_step_count": len(active),
        "force_application_receipt_count": sum(
            len(item["receipts"]) for item in projections
        ),
        "force_application_positive_impulse_count": sum(
            item["positive_impulse_count"] for item in projections
        ),
        "force_application_negative_impulse_count": sum(
            item["negative_impulse_count"] for item in projections
        ),
        "force_application_saturated_count": sum(
            item["saturated_count"] for item in projections
        ),
        "force_application_representation_projection_count": sum(
            item["representation_projection_count"] for item in projections
        ),
        "force_application_minimum_absolute_impulse_nms": min(
            item["minimum_absolute_applied_impulse_nms"] for item in projections
        ),
        "force_application_maximum_absolute_impulse_nms": max(
            item["maximum_absolute_applied_impulse_nms"] for item in projections
        ),
        "force_application_minimum_published_cap_nms": min(
            item["minimum_published_cap_nms"] for item in projections
        ),
        "force_application_maximum_published_cap_nms": max(
            item["maximum_published_cap_nms"] for item in projections
        ),
        "force_application_maximum_pairing_residual_component_nms": max(
            item["maximum_pairing_residual_component_nms"] for item in projections
        ),
        "force_application_equal_and_opposite_body_impulse_write_count": sum(
            item["body_impulse_write_count"] for item in active
        ),
        "force_application_hard_constraint_motor_disabled_count": sum(
            item["hard_constraint_motor_disabled_count"] for item in active
        ),
        "force_application_hard_constraint_motor_target_write_count": sum(
            item["hard_constraint_motor_target_write_count"] for item in active
        ),
        "force_application_applied_impulse_binding_count": applied_bindings,
        "matched_zero_nonzero_applied_impulse_count": sum(
            item["applied_angular_impulse_nms"] != 0.0 for item in zero_impulses
        ),
    }


def maximum_relative_joint_velocity(arm: dict) -> float:
    return max(
        abs(float(joint["velocity_rad_s"]))
        for observation in arm["trace_v3"]["observations"]
        for joint in observation["state"]["ordered_joint_observations"]
    )


def diagnostic_projection(raw: dict) -> dict[str, object]:
    candidate = raw["candidate_arm"]
    zero = raw["matched_zero_arm"]
    candidate_classes = [
        item["classification"] for item in candidate["portable_step_receipts"]
    ]
    zero_classes = [item["classification"] for item in zero["portable_step_receipts"]]
    summaries = raw["arm_execution_summary"]["ordered_arm_summaries"]
    return {
        "initial_state_identity_matched": (
            candidate["declared_initial_state_sha256"]
            == zero["declared_initial_state_sha256"]
        ),
        "candidate_observation_count": len(candidate["trace_v3"]["observations"]),
        "candidate_completed_phases": candidate["final_memory"][
            "ordered_completed_phases"
        ],
        "candidate_final_phase": candidate["final_phase"],
        "candidate_terminal_failure_code": candidate["terminal_failure_code"],
        "candidate_entry_prone_gate_true_count": sum(
            item["entry_prone_gate"] for item in candidate_classes
        ),
        "candidate_distal_support_gate_true_count": sum(
            item["distal_support_gate"] for item in candidate_classes
        ),
        "candidate_raised_body_gate_true_count": sum(
            item["raised_body_gate"] for item in candidate_classes
        ),
        "candidate_safety_gate_true_count": sum(
            item["safety_gate"] for item in candidate_classes
        ),
        "candidate_stable_stance_gate_true_count": sum(
            item["stable_stance_gate"] for item in candidate_classes
        ),
        "candidate_no_cheat_gate_true_count": sum(
            item["no_cheat_gate"] for item in candidate_classes
        ),
        "candidate_all_four_distal_sites_bearing_true_count": sum(
            item["all_four_distal_sites_bearing"] for item in candidate_classes
        ),
        "candidate_maximum_center_of_mass_height_gain_m": max(
            item["center_of_mass_height_gain_m"] for item in candidate_classes
        ),
        "candidate_final_center_of_mass_height_gain_m": candidate_classes[-1][
            "center_of_mass_height_gain_m"
        ],
        "candidate_maximum_torso_height_ratio": max(
            item["torso_height_ratio"] for item in candidate_classes
        ),
        "candidate_final_torso_height_ratio": candidate_classes[-1][
            "torso_height_ratio"
        ],
        "candidate_maximum_absolute_relative_joint_velocity_rad_s": (
            maximum_relative_joint_velocity(candidate)
        ),
        "candidate_final_applied_actuator_work_j": candidate["trace_v3"][
            "observations"
        ][-1]["energy_balance"]["cumulative_applied_actuator_work_j"],
        "candidate_maximum_energy_balance_residual_j": max(
            item["energy_balance_residual_j"] for item in candidate_classes
        ),
        "candidate_final_energy_balance_residual_j": candidate_classes[-1][
            "energy_balance_residual_j"
        ],
        "matched_zero_observation_count": len(zero["trace_v3"]["observations"]),
        "matched_zero_completed_phases": zero["final_memory"][
            "ordered_completed_phases"
        ],
        "matched_zero_final_phase": zero["final_phase"],
        "matched_zero_terminal_failure_code": zero["terminal_failure_code"],
        "matched_zero_entry_prone_gate_true_count": sum(
            item["entry_prone_gate"] for item in zero_classes
        ),
        "matched_zero_distal_support_gate_true_count": sum(
            item["distal_support_gate"] for item in zero_classes
        ),
        "matched_zero_no_cheat_gate_true_count": sum(
            item["no_cheat_gate"] for item in zero_classes
        ),
        "matched_zero_all_four_distal_sites_bearing_true_count": sum(
            item["all_four_distal_sites_bearing"] for item in zero_classes
        ),
        "matched_zero_maximum_center_of_mass_height_gain_m": max(
            item["center_of_mass_height_gain_m"] for item in zero_classes
        ),
        "matched_zero_maximum_absolute_relative_joint_velocity_rad_s": (
            maximum_relative_joint_velocity(zero)
        ),
        "matched_zero_final_applied_actuator_work_j": zero["trace_v3"][
            "observations"
        ][-1]["energy_balance"]["cumulative_applied_actuator_work_j"],
        "candidate_in_run_invariant_population_sha256": summaries[0][
            "in_run_invariant_population_sha256"
        ],
        "candidate_trace_v3_sha256": summaries[0]["trace_v3_sha256"],
        "matched_zero_in_run_invariant_population_sha256": summaries[1][
            "in_run_invariant_population_sha256"
        ],
        "matched_zero_trace_v3_sha256": summaries[1]["trace_v3_sha256"],
        "ordered_arm_summaries_sha256": raw["arm_execution_summary"][
            "ordered_arm_summaries_sha256"
        ],
        "all_536_declared_in_run_physical_invariants_passed": raw[
            "all_in_run_physical_invariants_passed"
        ],
        **complete_in_run_physical_invariant_projection(raw),
        **force_application_projection(raw),
        "diagnostic_values_granted_behavior_claim_authority": False,
    }


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D92",
            "stage_id": "R24D92-BEHAVIOR",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": "physical_development_invalid_closure",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "c8c8b07ea97107815e2538f51b2123fc19cf52b8",
            "source.tree": "e53fc2dc20c91f28c1f914fc03a7e040475c0b63",
            "source.subject": (
                "[recovery/godot] Close R92 control: authorize finite pair"
            ),
        },
        "CLOSURE",
    )
    for field, fmt in (("parent_commit", "%P"), ("tree", "%T"), ("subject", "%s")):
        exact(
            git(ROOT, "show", "-s", f"--format={fmt}", SOURCE),
            closure["source"][field],
            f"SOURCE_{field.upper()}",
        )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:7cb7b2af89f05b352a9d35701e2518bc2167f92d920e163c4d6497004816e241"
            ),
            "qualification_source_freeze_commit": (
                "dd938b1cc63a8dfb5dd86cfc410203d5ca2a82a1"
            ),
            "authorization_publication_commit": SOURCE,
            "authorization_control_source_commit": (
                "c8c8b07ea97107815e2538f51b2123fc19cf52b8"
            ),
            "authorization_control_raw_sha256": (
                "sha256:7ab979607eef7216f882f9e63617a5209c0814239e05cb338a9f737c7b58d8e4"
            ),
            "authorization_control_count": 1,
            "complete_zero_world_gate_satisfied": True,
            "published_closure_authorization_control_satisfied": True,
            "future_state_stable_one_receipt_preflight_satisfied": True,
            "qualified_physical_source_drift_check_passed": True,
            "qualified_physical_path_count": 47,
            "clean_pushed_remote_equality_passed": True,
            "same_identity_requalification_permitted": False,
        },
        "AUTHORIZATION",
    )

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D92",
        source_commit=SOURCE,
        status="valid_complete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d92_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d92_godot_force_based_recovery_behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d92_behavior_terminal_v1",
        },
        raw_count_keys=COUNT_KEYS,
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "scientific_outcome": "negative",
            "actuator_mode": "force_based_joint_impulse_v1",
            "physical_question_opened": True,
            "physics_failure_is_valid_evidence": True,
            "recovery_success_required_for_valid_result": False,
            "recovery_success_observed": False,
            "all_in_run_physical_invariants_passed": True,
            "evaluation_receipt.support_status": "supported_exact",
            "evaluation_receipt.verdict": "physical_development_failed",
            "evaluation_receipt.physical_development_trace_valid": True,
            "evaluation_receipt.candidate_physical_path_completed": False,
            "evaluation_receipt.matched_zero_command_physical_control_failed_to_complete": True,
            "evaluation_acceptance_receipt.ok": True,
            "evaluation_acceptance_receipt.status": "accepted",
            "evaluation_acceptance_receipt.scientific_outcome": "negative",
            "evaluation_acceptance_receipt.common_check_count": 22,
            "evaluation_acceptance_receipt.common_pass_count": 22,
            "evaluation_acceptance_receipt.verdict_check_count": 9,
            "evaluation_acceptance_receipt.verdict_pass_count": 9,
            "candidate_arm.outer_step_count": 268,
            "candidate_arm.final_phase": "failed",
            "candidate_arm.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "matched_zero_arm.outer_step_count": 268,
            "matched_zero_arm.final_phase": "failed",
            "matched_zero_arm.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 2,
            "arm_execution_summary.summarized_solver_step_count": 536,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:90f5d4aeb47ccea5c4fe50c61afc6586e64ad6c23e6f77f23569d9d086fe6395"
            ),
        },
        "PRODUCER_RAW",
    )
    require(
        all(raw["evaluation_acceptance_receipt"]["common_checks"].values()),
        "PRODUCER_COMMON_CHECKS",
    )
    require(
        all(raw["evaluation_acceptance_receipt"]["verdict_checks"].values()),
        "PRODUCER_VERDICT_CHECKS",
    )
    summaries = raw["arm_execution_summary"]["ordered_arm_summaries"]
    exact(
        sha256(canonical_bytes(summaries)),
        raw["arm_execution_summary"]["ordered_arm_summaries_sha256"],
        "ARM_SUMMARY_HASH",
    )
    verify_arm_invariants(raw["candidate_arm"], summaries[0], "candidate_command", 268)
    verify_arm_invariants(
        raw["matched_zero_arm"], summaries[1], "matched_zero_command", 268
    )
    exact(diagnostic_projection(raw), closure["diagnostic_observations"], "DIAGNOSTIC")

    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": True,
            "completed_utc": physical["completed_utc"],
            "source.head": SOURCE,
            "source.live_origin_main": SOURCE,
            "authorization.control.raw_sha256": (
                "sha256:7ab979607eef7216f882f9e63617a5209c0814239e05cb338a9f737c7b58d8e4"
            ),
            "worker.semantic_exit_code": 0,
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.termination_protocol_failure_code": "",
            "recovery_success_observed": False,
            "same_identity_rerun_permitted": False,
        },
        "PRODUCER_TERMINAL",
    )
    verify_exact_paths(
        closure["producer_observation"],
        {
            "producer_status": raw["status"],
            "producer_scientific_outcome": raw["scientific_outcome"],
            "producer_behavior_development_completed": True,
            "producer_recovery_success_observed": False,
            "producer_prone_to_standing_claimed": False,
            "portable_evaluator_support_status": "supported_exact",
            "portable_evaluator_verdict": "physical_development_failed",
            "portable_evaluator_trace_valid": True,
            "verdict_aware_consumer_acceptance_passed": True,
            "acceptance_common_check_count": 22,
            "acceptance_common_pass_count": 22,
            "acceptance_verdict_check_count": 9,
            "acceptance_verdict_pass_count": 9,
            "producer_declared_in_run_invariant_receipt_count": 536,
            "producer_declared_in_run_invariant_pass_count": 536,
            "producer_interpretation_preserved": True,
        },
        "PRODUCER_OBSERVATION",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D92_GODOT_FORCE_BASED_RECOVERY_BEHAVIOR_RAW ",
            '"scientific_outcome":"negative"',
            "QSDK_R24D92_GODOT_FORCE_BASED_RECOVERY_BEHAVIOR_READY ",
        ),
        "STDOUT",
    )
    stderr_lines = (evidence / "godot.stderr.log").read_text(
        encoding="utf-8"
    ).splitlines()
    assertion = (
        "ERROR: Jolt Physics assertion 'inAngularVelocity.Length() <= "
        "mMaxAngularVelocity' failed with message '' at 'thirdparty\\jolt_physics\\"
        "Jolt/Physics/Body/MotionProperties.h:55'"
    )
    site = "at: jolt_assert (modules\\jolt_physics\\jolt_globals.cpp:88)"
    exact(len(stderr_lines), 382, "STDERR_LINE_COUNT")
    exact(set(item.strip() for item in stderr_lines), {assertion, site}, "STDERR_LINES")
    exact(sum(item == assertion for item in stderr_lines), 191, "JOLT_ASSERTIONS")
    exact(sum(item.strip() == site for item in stderr_lines), 191, "JOLT_SITES")
    verify_exact_paths(
        closure["post_run_native_engine_health_audit"],
        {
            "classification": (
                "unmodeled_native_engine_health_failure_blocks_behavioral_inference"
            ),
            "stderr_line_count": 382,
            "stderr_unique_line_count": 2,
            "native_angular_velocity_limit_assertion_count": 191,
            "assertion_text": assertion,
            "assertion_site_text": site,
            "non_assertion_stderr_line_count": 0,
            "stderr_was_part_of_retained_attempt_tree": True,
            "stderr_was_part_of_frozen_producer_validity_partition": False,
            "native_engine_assertion_was_part_of_declared_in_run_invariant_population": False,
            "effective_runtime_max_angular_velocity_retained": False,
            "complete_ordered_body_angular_velocity_population_retained": False,
            "assertion_arm_and_step_identity_retained": False,
            "candidate_only_attribution_established": False,
            "producer_terminal_record_rewritten": False,
            "producer_scientific_outcome_rewritten": False,
            "post_run_closure_valid_physical_result": False,
            "scientific_negative_accepted_for_behavioral_inference": False,
            "native_engine_health_failure_established": True,
            "in_run_physical_invariant_coverage_gap_established": True,
        },
        "ENGINE_HEALTH",
    )

    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
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
            "gate_id": "QSDK-R24D93",
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "stderr_assertion_and_unallowlisted_engine_error_fail_closed_required": True,
            "effective_runtime_angular_velocity_limit_provenance_required": True,
            "complete_ordered_body_angular_velocity_measurement_required": True,
            "per_step_native_limit_invariant_required": True,
            "retained_r24d92_diagnostic_reuse_permitted": True,
            "r24d92_may_be_rerun_or_requalified": False,
            "full_seeded_behavior_ghost_required": False,
            "additional_physical_canary_required": False,
            "held_out_cells_remain_sealed": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    revision = publication or None
    closure_raw = (
        CLOSURE.read_bytes()
        if revision is None
        else source_bytes(ROOT, revision, relative)
    )
    live = {
        "next_gate_id": "QSDK-R24D93",
        "r24d92_source_status": STATUS,
        "r24d92_physical_attempt_consumed": True,
        "r24d92_physical_attempt_disposition": (
            "complete_producer_negative_invalid_for_physical_inference_native_"
            "angular_velocity_limit_assertions"
        ),
        "r24d92_behavior_invalid_closure_path": relative,
        "r24d92_behavior_invalid_closure_raw_sha256": sha256(closure_raw),
        "r24d92_behavior_invalid_closure_byte_length": len(closure_raw),
        "r24d92_behavior_evidence_root": str(physical["evidence_root"]),
        "r24d92_invocation_source_commit": SOURCE,
        "r24d92_attempt_id": physical["attempt_id"],
        "r24d92_model_construction_count": 2,
        "r24d92_world_attempt_count": 2,
        "r24d92_world_build_count": 2,
        "r24d92_solver_step_count": 536,
        "r24d92_observed_behavior_evaluator_invocation_count": 1,
        "r24d92_observed_in_run_invariant_receipt_count": 536,
        "r24d92_observed_scientific_outcome": "negative",
        "r24d92_producer_valid_complete_behavior_result_observed": True,
        "r24d92_all_declared_in_run_physical_invariants_passed": True,
        "r24d92_native_engine_health_passed": False,
        "r24d92_native_angular_velocity_limit_assertion_count": 191,
        "r24d92_in_run_physical_invariant_coverage_gap_established": True,
        "r24d92_closure_valid_physical_result": False,
        "r24d92_behavior_negative_accepted_for_inference": False,
        "r24d92_physical_execution_authorized": False,
        "r24d92_sdk1_milestone_advanced": False,
        "r24d93_distinct_successor_required": True,
        "r24d93_question_class": "development",
        "r24d93_physical_question_declared": False,
        "physical_execution_blocked_pending_r24d93_declaration": True,
        "physical_execution_blocked_until_r24d93_zero_world_qualification": True,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D92_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_INVALID_"
        "CLOSURE_PASS attempts=1 models=2 worlds=2 steps=536 evaluator=1 "
        "declared_invariants=536/536 jolt_angular_limit_assertions=191 "
        "producer_outcome=negative closure=invalid next=R24D93 sdk1=11/20"
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
            "QSDK_R24D92_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_INVALID_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
