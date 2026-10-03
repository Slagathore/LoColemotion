"""Audit the retained QSDK-R24D32 qualification and physical negative."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    exact_bools,
    git,
    load,
    loads,
    native_energy_terms,
    require,
    sha256,
    verify_exact_retained_inventory,
    verify_native_energy_ledger_arm,
    verify_physical_attempt_closure,
    verify_portable_arm_projection,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)


CLOSURE_PATH = ROOT / "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json"
SOURCE = "326dd1d22b40b675f12372089d77d7724dc20a9a"
GATE = "QSDK-R24D32"
CAMPAIGN = "QSDK-R24D32-MUJOCO-CORRECTED-ENERGY-PROGRESSION-DEVELOPMENT"
STATUS = (
    "closed_consumed_execution_valid_development_negative_corrected_"
    "energy_residual_above_unchanged_limit_no_handoff"
)
ENERGY_PROFILE = "mujoco_independent_constraint_and_passive_work_energy_ledger_v2"


def _exact_claim_boundary(closure: dict[str, Any]) -> None:
    positive = {
        "complete_zero_world_gate_passed",
        "official_zero_world_qualification_passed",
        "physical_question_opened",
        "complete_physical_development_trace_observed",
        "execution_valid_development_negative_observed",
        "matched_zero_negative_control_observed",
        "controller_application_beyond_first_command_observed",
        "distal_support_transition_observed",
        "raised_body_geometry_observed",
        "corrected_native_component_mapping_executed",
        "all_in_run_energy_component_invariants_passed",
    }
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive, f"CLAIM_{key.upper()}")


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d32_corrected_energy_progression_physical_closure_v1",
        "SCHEMA",
    )
    for key, expected in (
        ("gate_id", GATE),
        ("campaign_id", CAMPAIGN),
        ("closure_status", STATUS),
        ("question_class", "development"),
        ("physical_question_declared", True),
    ):
        exact(closure[key], expected, f"CLOSURE_{key.upper()}")
    exact_bools(
        closure,
        (
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "DECLARATION",
    )

    source = closure["source"]
    exact(source["commit"], SOURCE, "SOURCE")
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), source["tree"], "TREE")
    exact(len(source["bindings"]), 5, "SOURCE_BINDING_COUNT")
    exact(len({item["path"] for item in source["bindings"]}), 5, "SOURCE_BINDING_UNIQUE")
    bound = {
        str(item["path"]): verify_source_binding(ROOT, SOURCE, item)
        for item in source["bindings"]
    }
    contract_path = "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json"
    contract = loads(bound[contract_path])
    exact(contract["gate_id"], GATE, "CONTRACT_GATE")
    exact(contract["campaign_id"], CAMPAIGN, "CONTRACT_CAMPAIGN")
    exact(contract["physical_question_declared"], True, "CONTRACT_PHYSICAL")
    exact(
        contract["qualification_and_physical_authority"]["qualification_result_pending"],
        True,
        "CONTRACT_PROSPECTIVE",
    )

    predecessors = closure["predecessors"]
    for prefix in ("physical", "correction"):
        path = ROOT / predecessors[f"{prefix}_closure_path"]
        exact(
            sha256(path.read_bytes()),
            predecessors[f"{prefix}_closure_raw_sha256"],
            f"PREDECESSOR_{prefix.upper()}_HASH",
        )
    exact(
        load(ROOT / predecessors["physical_closure_path"])["closure_status"],
        predecessors["physical_historical_result"],
        "PREDECESSOR_RESULT",
    )
    exact_bools(
        predecessors,
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
            "same_identity_rerun_permitted",
            "same_identity_requalification_permitted",
        ),
        False,
        "PREDECESSOR",
    )

    qualification = closure["qualification"]
    verify_exact_retained_inventory(
        Path(qualification["evidence_root"]), qualification["retained_artifacts"]
    )
    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d32_corrected_energy_progression_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d32_corrected_energy_progression_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d32-qualification-",
        contract_inventory=contract["source_inventory"],
    )
    exact(receipt["contract_raw_sha256"], sha256(bound[contract_path]), "QUAL_CONTRACT")
    exact(
        (preflight["negative_control_count"], preflight["negative_controls_passed"]),
        (17, 17),
        "QUAL_CONTROLS",
    )
    exact(preflight["historical_r24d30_controls_reexecuted"], False, "QUAL_HISTORY")
    exact(preflight["executed_r24d31_control_count"], 12, "QUAL_R31_CONTROLS")
    exact(preflight["r24d32_integration_control_count"], 5, "QUAL_R32_CONTROLS")
    require(all(preflight["energy_ledger_controls"].values()), "QUAL_ENERGY_CONTROL")
    require(all(preflight["r24d32_integration_controls"].values()), "QUAL_R32_CONTROL")

    retained = verify_physical_attempt_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        campaign_id=CAMPAIGN,
        source_commit=SOURCE,
        physical_directory_prefix="qsdk-r24d32-mujoco-corrected-energy-progression-",
        schemas={
            "reservation": "sporespore_qsdk_r24d32_corrected_energy_progression_attempt_reservation_v1",
            "manifest": "sporespore_qsdk_r24d32_corrected_energy_progression_manifest_v1",
            "full": "sporespore_qsdk_r24d32_corrected_energy_progression_full_result_v1",
            "summary": "sporespore_qsdk_r24d32_corrected_energy_progression_compact_projection_v1",
            "completion": "sporespore_qsdk_r24d32_corrected_energy_progression_supervisor_completion_v1",
            "lock": "sporespore_locomotion_operation_lock_receipt_v1",
        },
        qualification_receipt_raw_sha256=qualification["receipt_raw_sha256"],
    )
    reservation, manifest = retained["reservation"], retained["manifest"]
    full, summary = retained["full"], retained["summary"]
    exact(reservation["contract_raw_sha256"], sha256(bound[contract_path]), "RESERVATION_CONTRACT")
    exact(full["contract_raw_sha256"], sha256(bound[contract_path]), "FULL_CONTRACT")
    exact(
        (manifest["execution_valid"], manifest["decision_positive"], manifest["energy_invariants_passed"]),
        (True, False, True),
        "MANIFEST_DECISION",
    )
    exact(
        (summary["execution_valid"], summary["decision_positive"], summary["valid_negative_if_decision_not_positive"]),
        (True, False, True),
        "SUMMARY_DECISION",
    )

    result, observed = full["result"], closure["observed_result"]
    evaluation = result["evaluation"]
    exact(evaluation["support_status"], observed["portable_evaluation_support_status"], "EVALUATION_SUPPORT")
    exact(evaluation["physical_development_trace_valid"], True, "EVALUATION_VALID")
    exact(evaluation["verdict"], observed["portable_evaluation_verdict"], "EVALUATION_VERDICT")
    exact(evaluation["physical_result"], False, "EVALUATION_RESULT")
    exact(evaluation["refusal_reason"], None, "EVALUATION_REFUSAL")
    exact(result["physical_development_result_observed"], False, "RESULT_POSITIVE")
    exact_bools(
        result,
        (
            "controller_physical_viability_proven",
            "population_claimed",
            "repeatability_rate_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "RESULT_CLAIM",
    )
    candidate, matched_zero = result["candidate"], result["matched_zero_command"]
    verify_portable_arm_projection(candidate, observed["candidate"], "CANDIDATE")
    verify_portable_arm_projection(matched_zero, observed["matched_zero_command"], "MATCHED_ZERO")
    for identity in ("canonical_pre_step_state_sha256", "initializer_manifest_sha256"):
        exact(candidate[identity], matched_zero[identity], f"PAIR_{identity.upper()}")
    active = [
        index
        for index, value in enumerate(candidate["native_receipts"])
        if value["application"]["no_actuation_requested"] is False
    ]
    candidate_claim = observed["candidate"]
    exact(
        (len(active), active[0], active[-1]),
        (
            candidate_claim["active_application_count"],
            candidate_claim["first_active_outer_index_zero_based"],
            candidate_claim["last_active_outer_index_zero_based"],
        ),
        "CANDIDATE_ACTIVE",
    )
    require(
        all(value["application"]["no_actuation_requested"] for value in matched_zero["native_receipts"])
        and all(value["applied_actuation"]["zero_command"] for value in matched_zero["observations"]),
        "MATCHED_ZERO_ACTUATED",
    )

    invariant = closure["energy_invariant_result"]
    tolerance = invariant["native_component_identity_tolerance_j"]
    candidate_ledger = verify_native_energy_ledger_arm(
        candidate, "CANDIDATE", ENERGY_PROFILE, tolerance
    )
    zero_ledger = verify_native_energy_ledger_arm(
        matched_zero, "MATCHED_ZERO", ENERGY_PROFILE, tolerance
    )
    candidate_residuals = candidate_ledger["residuals"]
    zero_residuals = zero_ledger["residuals"]
    exact(len(candidate_residuals) + len(zero_residuals), invariant["validated_step_count"], "ENERGY_STEPS")
    expected_components = {"constraint": True, "damper": False, "fluid": False, "adhesion": False}
    exact(candidate_ledger["observed_nonzero"], expected_components, "CANDIDATE_COMPONENTS")
    exact(zero_ledger["observed_nonzero"], expected_components, "MATCHED_ZERO_COMPONENTS")
    full_invariants = full["energy_invariants"]
    exact(summary["energy_invariants"], full_invariants, "ENERGY_PROJECTION")
    exact(full_invariants["energy_ledger_profile_id"], ENERGY_PROFILE, "ENERGY_PROFILE")
    exact(full_invariants["ok"], True, "ENERGY_OK")
    exact(full_invariants["validated_step_count"], invariant["validated_step_count"], "ENERGY_COUNT")
    exact_bools(
        full_invariants,
        (
            "all_component_identities_exact",
            "all_components_finite",
            "cumulative_dissipation_nonnegative",
            "native_portable_energy_identity_exact",
        ),
        True,
        "ENERGY",
    )

    diagnosis = closure["exact_gate_diagnosis"]
    classifications = [value["classification"] for value in candidate["portable_step_receipts"]]
    raised = [(i, value) for i, value in enumerate(classifications) if value["raised_body_gate"]]
    exact((len(raised), raised[0][0]), (diagnosis["raised_body_observation_count"], diagnosis["first_raised_body_outer_index_zero_based"]), "RAISED_IDENTITY")
    exact(min(value["energy_balance_residual_j"] for _, value in raised), diagnosis["minimum_raised_absolute_residual_j"], "RAISED_MINIMUM")
    exact((max(candidate_residuals), candidate_residuals.index(max(candidate_residuals))), (diagnosis["maximum_absolute_residual_j"], diagnosis["maximum_absolute_residual_outer_index_zero_based"]), "CANDIDATE_MAXIMUM")
    exact(candidate_residuals[-1], diagnosis["terminal_energy_balance_residual_j"], "CANDIDATE_TERMINAL")
    exact((max(zero_residuals), zero_residuals.index(max(zero_residuals))), (diagnosis["matched_zero_maximum_absolute_residual_j"], diagnosis["matched_zero_maximum_absolute_residual_outer_index_zero_based"]), "ZERO_MAXIMUM")
    failures = {
        "raised_body_joint_limit_failure_count": sum(not value["joint_limits_respected"] for _, value in raised),
        "raised_body_actuator_budget_failure_count": sum(not value["actuator_budget_respected"] for _, value in raised),
        "raised_body_forbidden_contact_impulse_failure_count": sum(value["maximum_nonfoot_contact_impulse_ns"] > 0.0 for _, value in raised),
        "raised_body_energy_balance_residual_failure_count": sum(value["energy_balance_residual_j"] > diagnosis["maximum_energy_balance_residual_j"] for _, value in raised),
        "raised_body_safety_conjunction_pass_count": sum(value["safety_gate"] for _, value in raised),
    }
    for key, value in failures.items():
        exact(value, diagnosis[key], f"DIAGNOSIS_{key.upper()}")
    for arm, index, key in (
        (candidate, diagnosis["first_raised_body_outer_index_zero_based"], "first_raised_energy_terms_j"),
        (candidate, len(candidate_residuals) - 1, "terminal_candidate_energy_terms_j"),
        (matched_zero, len(zero_residuals) - 1, "terminal_matched_zero_energy_terms_j"),
    ):
        exact(native_energy_terms(arm, index), diagnosis[key], f"DIAGNOSIS_{key.upper()}")
    for key, value in diagnosis["terminal_classification"].items():
        exact(classifications[-1][key], value, f"TERMINAL_{key.upper()}")
    require(diagnosis["minimum_raised_absolute_residual_j"] > diagnosis["maximum_energy_balance_residual_j"], "RAISED_LIMIT")
    exact_bools(
        diagnosis,
        (
            "recovery_to_stance_handoff_observed",
            "remaining_residual_physical_cause_established",
            "controller_fault_established",
            "native_energy_component_mapping_fault_established",
            "numerical_integration_error_established",
            "threshold_inadequacy_established",
            "threshold_or_margin_changed",
            "historical_result_reinterpreted",
        ),
        False,
        "DIAGNOSIS",
    )

    comparison = closure["predecessor_comparison"]
    exact(comparison["r24d30_minimum_raised_absolute_residual_j"] - comparison["r24d32_minimum_raised_absolute_residual_j"], comparison["minimum_absolute_reduction_j"], "MINIMUM_REDUCTION")
    exact(comparison["r24d30_terminal_residual_j"] - comparison["r24d32_terminal_residual_j"], comparison["terminal_absolute_reduction_j"], "TERMINAL_REDUCTION")
    exact((comparison["finite_descriptive_comparison_only"], comparison["superiority_or_population_inference_claimed"]), (True, False), "COMPARISON_SCOPE")
    sdk = closure["sdk_status"]
    exact((sdk["sdk1_completed_steps"], sdk["sdk1_total_steps"]), (11, 20), "SDK1_SCORE")
    exact((sdk["full_program_completed_steps"], sdk["full_program_total_steps"]), (11, 25), "PROGRAM_SCORE")
    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D33", "NEXT_GATE")
    exact(next_boundary["status"], "not_yet_declared_zero_world_diagnosis_required_physical_execution_blocked", "NEXT_STATUS")
    exact_bools(
        next_boundary,
        (
            "same_identity_rerun_permitted",
            "r24d32_may_be_requalified",
            "new_threshold_or_margin_selected",
            "next_physical_execution_authorized",
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "NEXT",
    )
    _exact_claim_boundary(closure)
    print(
        "QSDK_R24D32_CORRECTED_ENERGY_PHYSICAL_CLOSURE_PASS "
        "result=valid_negative candidate=failed:raise_body raised_observations=439 "
        "energy_invariants=1520/1520 minimum_raised_residual_j=0.7256340038771327 "
        "limit_j=0.25 matched_zero_maximum_residual_j=0.07633092795183449 "
        "worlds=2 outer_steps=1520 solver_steps=7600 heldout_access=0 "
        "sdk1=11/20 next=QSDK-R24D33:zero_world_diagnosis"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        OSError,
        KeyError,
        IndexError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(f"QSDK_R24D32_CORRECTED_ENERGY_PHYSICAL_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
