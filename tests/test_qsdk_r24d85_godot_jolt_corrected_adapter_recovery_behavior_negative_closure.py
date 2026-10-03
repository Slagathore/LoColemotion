#!/usr/bin/env python3
"""Audit the consumed valid finite R85 corrected-adapter recovery negative."""

from __future__ import annotations

import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    canonical_bytes,
    exact,
    git,
    records_with_key,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d85_godot_jolt_corrected_adapter_recovery_behavior_"
    "negative_closure_v1.json"
)
SOURCE = "26c00beaf486d63bcb2208e574777c46bac39515"
STATUS = (
    "closed_consumed_valid_finite_negative_corrected_adapter_raise_body_"
    "timeout_after_distal_support"
)
EVIDENCE_ROOT = (
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d85-godot-jolt-corrected-adapter-recovery-behavior/"
    "20260831T081337442Z-26c00bea-888087e3"
)
DECISION_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "valid_complete_behavior_result_observed",
    "scientific_negative_observed",
    "both_models_constructed",
    "both_worlds_built",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_accepted",
    "all_acceptance_checks_passed",
    "all_in_run_physical_invariants_passed",
    "candidate_distal_support_completed",
    "candidate_raise_body_timeout_observed",
    "matched_zero_distal_support_timeout_observed",
    "candidate_progress_beyond_matched_zero_observed",
    "combined_r83_adapter_correction_materially_changed_candidate_trace",
    "distinct_successor_required",
)
DECISION_FALSE = (
    "same_identity_rerun_permitted",
    "r24d85_requalification_permitted",
    "recovery_success_observed",
    "portable_controller_general_failure_claimed",
    "native_physics_fault_claimed",
    "actuator_cap_inadequacy_claimed",
    "behavior_threshold_inadequacy_claimed",
    "energy_ledger_defect_claimed",
    "historical_threshold_changed",
    "historical_margin_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "repeatability_rate_claimed",
    "population_claimed",
    "held_out_validation_claimed",
    "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "valid_complete_behavior_result_observed",
    "scientific_negative_observed",
    "both_models_constructed",
    "both_worlds_built",
    "physics_state_modified",
    "termination_protocol_valid",
    "portable_evaluator_receipt_accepted",
    "all_acceptance_checks_passed",
    "all_1004_in_run_physical_invariants_passed",
    "retained_candidate_distal_support_completion",
    "retained_candidate_raise_body_timeout_observation",
    "retained_matched_zero_distal_support_timeout_observation",
    "candidate_progress_beyond_matched_zero_observed",
    "combined_r83_adapter_correction_materially_changed_candidate_trace",
    "distinct_successor_required",
)
CLAIM_FALSE = (
    "recovery_success_observed",
    "portable_controller_general_failure_claimed",
    "native_physics_fault_claimed",
    "actuator_cap_inadequacy_claimed",
    "behavior_threshold_inadequacy_claimed",
    "energy_ledger_defect_claimed",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "repeatability_rate_claimed",
    "population_claimed",
    "held_out_validation_claimed",
    "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def verify_invariant_population(
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
            and item["controller_ownership"]["fallback_controller_active"] is False
            and item["controller_ownership"]["source_measurement"] is True
            for item in receipts
        ),
        f"{arm_kind}:IN_RUN_INVARIANTS",
    )
    exact(
        sha256(canonical_bytes(receipts)),
        summary["in_run_invariant_population_sha256"],
        f"{arm_kind}:POPULATION_HASH",
    )
    exact(summary["trace_v3_sha256"], arm["trace_v3_sha256"], f"{arm_kind}:TRACE")


def collect_complete_invariants(value: object) -> dict[str, object]:
    numbers: list[float] = []
    validity_records: list[dict[str, object]] = []
    source_measurements: list[bool] = []
    external_interventions: list[dict[str, object]] = []

    def walk(current: object) -> None:
        if isinstance(current, dict):
            if isinstance(current.get("validity"), dict):
                validity_records.append(current["validity"])
            if isinstance(current.get("source_measurement"), bool):
                source_measurements.append(current["source_measurement"])
            if isinstance(current.get("external_interventions"), dict):
                external_interventions.append(current["external_interventions"])
            for child in current.values():
                walk(child)
        elif isinstance(current, list):
            for child in current:
                walk(child)
        elif isinstance(current, (int, float)) and not isinstance(current, bool):
            numbers.append(float(current))

    walk(value)
    return {
        "complete_raw_numeric_scalar_count": len(numbers),
        "all_raw_numeric_scalars_finite": all(math.isfinite(v) for v in numbers),
        "validity_record_count": len(validity_records),
        "validity_field_count": sum(len(item) for item in validity_records),
        "all_validity_fields_true": all(
            all(field is True for field in item.values())
            for item in validity_records
        ),
        "source_measurement_flag_count": len(source_measurements),
        "all_source_measurement_flags_true": all(source_measurements),
        "external_intervention_receipt_count": len(external_interventions),
        "external_intervention_field_count": sum(
            len(item) for item in external_interventions
        ),
        "external_intervention_total": sum(
            float(field)
            for item in external_interventions
            for field in item.values()
        ),
    }


def verify_live_projection(closure: dict) -> None:
    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    closure_blob = (
        source_bytes(ROOT, publication, relative)
        if publication
        else CLOSURE.read_bytes()
    )
    expected = {
        "next_gate_id": "QSDK-R24D86",
        "r24d85_source_status": STATUS,
        "r24d85_physical_attempt_consumed": True,
        "r24d85_physical_attempt_disposition": (
            "valid_finite_negative_corrected_adapter_raise_body_timeout_after_"
            "distal_support"
        ),
        "r24d85_behavior_negative_closure_path": relative,
        "r24d85_behavior_negative_closure_raw_sha256": sha256(closure_blob),
        "r24d85_behavior_negative_closure_byte_length": len(closure_blob),
        "r24d85_behavior_evidence_root": EVIDENCE_ROOT,
        "r24d85_invocation_source_commit": SOURCE,
        "r24d85_attempt_id": "888087e38401467ca16e5a70ddaa9d27",
        "r24d85_observed_model_construction_count": 2,
        "r24d85_observed_world_attempt_count": 2,
        "r24d85_observed_world_build_count": 2,
        "r24d85_observed_solver_step_count": 1004,
        "r24d85_observed_behavior_evaluator_invocation_count": 1,
        "r24d85_observed_in_run_invariant_receipt_count": 1004,
        "r24d85_observed_scientific_outcome": "negative",
        "r24d85_valid_complete_behavior_result_observed": True,
        "r24d85_recovery_success_observed": False,
        "r24d85_all_in_run_physical_invariants_passed": True,
        "r24d85_candidate_completed_distal_support": True,
        "r24d85_candidate_terminal_failure_code": "phase_timeout:raise_body",
        "r24d85_candidate_maximum_com_height_gain_m": 0.1675409972667694,
        "r24d85_matched_zero_terminal_failure_code": (
            "phase_timeout:establish_distal_support"
        ),
        "r24d85_combined_adapter_correction_changed_candidate_trace": True,
        "r24d85_physical_execution_authorized": False,
        "r24d85_physical_execution_blocked": True,
        "r24d86_distinct_successor_required": True,
        "r24d86_question_class": "development",
        "r24d86_physical_question_declared": False,
        "physical_execution_blocked_pending_r24d86_declaration": True,
        "physical_execution_blocked_until_r24d86_zero_world_qualification": True,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    for authority_path in closure["live_authority_paths"]:
        raw = (
            source_bytes(ROOT, publication, authority_path)
            if publication
            else (ROOT / authority_path).read_bytes()
        )
        authority = json.loads(raw)
        records = records_with_key(authority, "r24d85_behavior_negative_closure_path")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_path}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_path}",
        )


def audit() -> None:
    closure = json.loads(CLOSURE.read_bytes())
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d85_godot_jolt_corrected_adapter_recovery_"
                "behavior_negative_closure_v1"
            ),
            "gate_id": "QSDK-R24D85",
            "stage_id": "R24D85-BEHAVIOR",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": "physical_development_closure",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "eeca7cacd0cdda66b2448a96698a12a7541a6d75",
            "source.tree": "0da2de07d7b2dd424361cbe0860a87ebb72c1e9c",
            "source.subject": (
                "[recovery/godot] Close R85 qualification: authorize finite "
                "behavior pair"
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
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D85",
        source_commit=SOURCE,
        status="valid_complete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d85_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d85_godot_corrected_adapter_recovery_"
                "behavior_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d85_behavior_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "complete_trace_count",
            "in_run_invariant_receipt_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "scientific_outcome": "negative",
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
            "evaluation_acceptance_receipt.verdict": "physical_development_failed",
            "evaluation_acceptance_receipt.common_check_count": 22,
            "evaluation_acceptance_receipt.common_pass_count": 22,
            "evaluation_acceptance_receipt.verdict_check_count": 9,
            "evaluation_acceptance_receipt.verdict_pass_count": 9,
            "candidate_arm.outer_step_count": 736,
            "candidate_arm.final_phase": "failed",
            "candidate_arm.terminal_failure_code": "phase_timeout:raise_body",
            "matched_zero_arm.outer_step_count": 268,
            "matched_zero_arm.final_phase": "failed",
            "matched_zero_arm.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "arm_execution_summary.status": "population_consistent",
            "arm_execution_summary.completed_arm_count": 2,
            "arm_execution_summary.summarized_solver_step_count": 1004,
            "arm_execution_summary.ordered_arm_summaries_sha256": (
                "sha256:72d95721f602d1943c5ad6174a95d277abaceed30e36578647b4183f38994fed"
            ),
        },
        "RAW_RESULT",
    )
    require(
        all(raw["evaluation_acceptance_receipt"]["common_checks"].values()),
        "COMMON_CHECKS",
    )
    require(
        all(raw["evaluation_acceptance_receipt"]["verdict_checks"].values()),
        "VERDICT_CHECKS",
    )
    exact(
        raw["candidate_arm"]["declared_initial_state_sha256"],
        raw["matched_zero_arm"]["declared_initial_state_sha256"],
        "INITIAL_STATE_IDENTITY",
    )
    summaries = raw["arm_execution_summary"]["ordered_arm_summaries"]
    exact(
        sha256(canonical_bytes(summaries)),
        raw["arm_execution_summary"]["ordered_arm_summaries_sha256"],
        "SUMMARY_HASH",
    )
    verify_invariant_population(
        raw["candidate_arm"], summaries[0], "candidate_command", 736
    )
    verify_invariant_population(
        raw["matched_zero_arm"], summaries[1], "matched_zero_command", 268
    )

    candidate = raw["candidate_arm"]
    matched_zero = raw["matched_zero_arm"]
    candidate_classifications = [
        item["classification"] for item in candidate["portable_step_receipts"]
    ]
    zero_classifications = [
        item["classification"] for item in matched_zero["portable_step_receipts"]
    ]
    exact(
        candidate["final_memory"]["ordered_completed_phases"],
        ["confirm_prone", "establish_distal_support"],
        "CANDIDATE_COMPLETED_PHASES",
    )
    exact(
        matched_zero["final_memory"]["ordered_completed_phases"],
        ["confirm_prone"],
        "ZERO_COMPLETED_PHASES",
    )
    exact(
        (
            sum(item["distal_support_gate"] for item in candidate_classifications),
            sum(item["raised_body_gate"] for item in candidate_classifications),
            sum(item["safety_gate"] for item in candidate_classifications),
            sum(item["stable_stance_gate"] for item in candidate_classifications),
            sum(item["no_cheat_gate"] for item in candidate_classifications),
        ),
        (567, 0, 0, 0, 736),
        "CANDIDATE_GATE_COUNTS",
    )
    exact(
        sum(item["distal_support_gate"] for item in zero_classifications),
        0,
        "ZERO_DISTAL_SUPPORT_COUNT",
    )
    exact(
        max(
            item["center_of_mass_height_gain_m"]
            for item in candidate_classifications
        ),
        0.1675409972667694,
        "CANDIDATE_MAX_COM_GAIN",
    )
    observations = candidate["trace_v3"]["observations"]

    def maximum_joint_position(joint_id: str) -> float:
        return max(
            next(
                item["position_rad"]
                for item in observation["state"]["ordered_joint_observations"]
                if item["joint_id"] == joint_id
            )
            for observation in observations
        )

    exact(
        (
            maximum_joint_position("rear_left_knee"),
            maximum_joint_position("rear_right_knee"),
        ),
        (0.704059362411499, 0.7897877097129822),
        "REAR_KNEE_MAXIMA",
    )
    invariant_projection = collect_complete_invariants(raw)
    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            **invariant_projection,
            "classification": (
                "valid_finite_negative_corrected_adapter_candidate_raise_body_"
                "timeout_after_distal_support_while_zero_timed_out_distal_support"
            ),
            "integration_or_evidence_failure_established": False,
            "portable_evaluator_verdict": "physical_development_failed",
            "candidate_observation_count": 736,
            "candidate_terminal_failure_code": "phase_timeout:raise_body",
            "candidate_distal_support_gate_true_count": 567,
            "candidate_raised_body_gate_true_count": 0,
            "candidate_maximum_com_height_gain_m": 0.1675409972667694,
            "candidate_com_height_gain_shortfall_m": 0.05245900273323059,
            "candidate_maximum_torso_height_ratio": 0.6337044820397678,
            "candidate_final_energy_balance_residual_j": 4683.50068431707,
            "candidate_rear_left_knee_maximum_position_rad": 0.704059362411499,
            "candidate_rear_right_knee_maximum_position_rad": 0.7897877097129822,
            "matched_zero_observation_count": 268,
            "matched_zero_terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "all_1004_in_run_physical_invariants_passed": True,
            "candidate_maximum_com_height_gain_change_from_r81_m": (
                0.005496978759765625
            ),
            "candidate_final_energy_balance_residual_reduction_from_r81_j": (
                91145.40606958434
            ),
            "combined_r83_adapter_correction_materially_changed_candidate_trace": True,
            "individual_joint_limit_vs_collision_filter_effect_isolated": False,
            "portable_controller_general_failure_established": False,
            "actuator_cap_inadequacy_established": False,
            "energy_ledger_defect_established": False,
        },
        "CAUSE",
    )
    r81 = json.loads(
        bound[
            "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
            "negative_closure_v1.json"
        ]
    )
    exact(
        (
            r81["causal_diagnosis"]["candidate_maximum_com_height_gain_m"],
            r81["causal_diagnosis"]["candidate_final_energy_balance_residual_j"],
        ),
        (0.16204401850700378, 95828.9067539014),
        "R81_COMPARISON_SOURCE",
    )
    verify_exact_paths(
        terminal,
        {
            "behavior_development_completed": True,
            "completed_utc": physical["completed_utc"],
            "source.head": SOURCE,
            "source.live_origin_main": SOURCE,
            "authorization.control": None,
            "worker.semantic_exit_code": 0,
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.termination_protocol_failure_code": "",
            "recovery_success_observed": False,
            "same_identity_rerun_permitted": False,
        },
        "TERMINAL",
    )
    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D85_GODOT_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_RAW ",
            '"scientific_outcome":"negative"',
            "QSDK_R24D85_GODOT_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_READY ",
        ),
        "STDOUT",
    )
    supervisor = bound[
        "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
    ].decode()
    require_ordered_markers(
        supervisor,
        (
            "authorization_path_required",
            "Enter-SporeSporeLocomotionOperationLock -Role physical_development",
            '$attemptId = [guid]::NewGuid().ToString("N")',
        ),
        "PRE_ATTEMPT_REFUSAL_ORDER",
    )
    verify_exact_paths(
        closure["operator_observed_pre_attempt_refusal"],
        {
            "authority_mode": "non_evidentiary_operational_note",
            "failure_code": "authorization_path_required",
            "shared_supervisor_refusal_precedes_operation_lock": True,
            "shared_supervisor_refusal_precedes_attempt_id_and_evidence_root_creation": True,
            "retained_attempt_artifact_created": False,
            "additional_physical_evidence_root_created": False,
            "scientific_attempt_consumed": False,
            "claim_authority": False,
        },
        "OPERATIONAL_NOTE",
    )
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
    verify_exact_paths(
        closure["next_boundary"],
        {
            "gate_id": "QSDK-R24D86",
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "diagnostic_reuse_of_consumed_r81_and_r85_evidence_permitted": True,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "r24d85_may_be_rerun_or_requalified": False,
        },
        "NEXT",
    )
    verify_live_projection(closure)
    print(
        "QSDK_R24D85_GODOT_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_NEGATIVE_"
        "CLOSURE_PASS attempts=1 models=2 worlds=2 steps=1004 evaluator=1 "
        "invariants=1004/1004 candidate=raise_body_timeout "
        "zero=distal_support_timeout outcome=negative next=R24D86 sdk1=11/20"
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
            "QSDK_R24D85_GODOT_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_NEGATIVE_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
