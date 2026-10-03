"""Audit the retained QSDK-R24D30 qualification and physical negative."""

from __future__ import annotations

from copy import deepcopy
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
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_retained_commit,
    verify_retained_file_manifest,
    verify_source_receipt_manifest,
)


CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/"
    "r24d30_natural_recovery_progression_physical_closure_v1.json"
)
SOURCE = "876131bd8aca2f1fe70f59d53157d1f285322c71"
CAMPAIGN = "QSDK-R24D30-MUJOCO-NATURAL-RECOVERY-PROGRESSION-DEVELOPMENT"


def verify_binding(binding: dict[str, Any]) -> bytes:
    relative = str(binding["path"])
    raw = source_bytes(ROOT, SOURCE, relative)
    exact(len(raw), binding["byte_length"], f"SOURCE_LENGTH:{relative}")
    exact(sha256(raw), binding["raw_sha256"], f"SOURCE_HASH:{relative}")
    exact(
        git(ROOT, "rev-parse", f"{SOURCE}:{relative}"),
        binding["git_blob_oid"],
        f"SOURCE_OID:{relative}",
    )
    return raw


def verify_inventory(root: Path, artifacts: list[dict[str, Any]]) -> None:
    exact(
        {path.name for path in root.iterdir() if path.is_file()},
        {str(item["path"]) for item in artifacts},
        f"INVENTORY:{root}",
    )
    verify_retained_file_manifest(root, artifacts)


def matching_roots(
    parent: Path,
    pattern: str,
    receipt_name: str,
    gate_id: str,
    source_commit: str,
) -> list[Path]:
    matches: list[Path] = []
    for directory in sorted(parent.glob(pattern)):
        candidate = directory / receipt_name
        if not candidate.is_file():
            continue
        value = load(candidate)
        if (
            value.get("gate_id") == gate_id
            and value.get("source_commit") == source_commit
        ):
            matches.append(directory)
    return matches


def transition_projection(receipts: list[dict[str, Any]]) -> tuple[list[list[str]], list[int]]:
    transitioned = [
        (index, receipt)
        for index, receipt in enumerate(receipts)
        if receipt["transitioned"] is True
    ]
    return (
        [
            [str(receipt["prior_phase"]), str(receipt["next_phase"])]
            for _, receipt in transitioned
        ],
        [index for index, _ in transitioned],
    )


def validate_claim_boundary(closure: dict[str, Any]) -> None:
    claims = closure["claim_boundary"]
    for key in (
        "complete_zero_world_gate_passed",
        "official_zero_world_qualification_passed",
        "physical_question_opened",
        "complete_physical_development_trace_observed",
        "execution_valid_development_negative_observed",
        "matched_zero_negative_control_observed",
        "controller_application_beyond_first_command_observed",
        "distal_support_transition_observed",
        "raised_body_geometry_observed",
    ):
        exact(claims[key], True, f"CLAIM_{key.upper()}")
    for key in (
        "safety_gate_passed",
        "recovery_to_stance_handoff_observed",
        "controller_progression_to_stance_handoff_proven",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "repeatability_rate_claimed",
        "population_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims[key], False, f"CLAIM_{key.upper()}")


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d30_natural_recovery_progression_"
        "physical_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D30", "GATE")
    exact(closure["campaign_id"], CAMPAIGN, "CAMPAIGN")
    exact(closure["question_class"], "development", "QUESTION")
    exact(
        closure["closure_status"],
        "closed_consumed_execution_valid_development_negative_"
        "raised_body_energy_safety_blocked",
        "STATUS",
    )
    exact(closure["source_commit"], SOURCE, "SOURCE")
    for key, expected in (
        ("physical_question_declared", True),
        ("superiority_question_declared", False),
        ("equivalence_or_non_inferiority_question_declared", False),
        ("population_inference_declared", False),
    ):
        exact(closure[key], expected, f"DECLARATION_{key.upper()}")
    verify_retained_commit(ROOT, SOURCE, closure["source_parent_commit"])
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), closure["source_tree"], "TREE")

    bindings = closure["frozen_source_bindings"]
    exact(len(bindings), 5, "BINDING_COUNT")
    exact(len({item["path"] for item in bindings}), 5, "BINDING_UNIQUE")
    bound = {str(item["path"]): verify_binding(item) for item in bindings}
    contract_path = "sdk/recovery/r24d30_natural_recovery_progression_contract_v1.json"
    contract = loads(bound[contract_path])
    exact(contract["gate_id"], "QSDK-R24D30", "CONTRACT_GATE")
    exact(contract["question_class"], "development", "CONTRACT_CLASS")
    exact(contract["physical_question_declared"], True, "CONTRACT_PHYSICAL")
    exact(
        contract["qualification_and_physical_authority"]["qualification_result_pending"],
        True,
        "CONTRACT_PROSPECTIVE",
    )
    exact(contract["prospective_freeze"]["source_inventory_count"], 83, "CONTRACT_SOURCES")
    exact(contract["prospective_freeze"]["expected_total_negative_control_count"], 48, "CONTRACT_CONTROLS")
    exact(contract["decision_rule"]["prone_to_standing_result_required"], False, "CONTRACT_STANDING")

    threshold_path = "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
    threshold_contract = loads(source_bytes(ROOT, SOURCE, threshold_path))
    thresholds = {
        item["threshold_id"]: item["value"]
        for item in threshold_contract["threshold_profile"]["thresholds"]
    }
    diagnosis = closure["exact_gate_diagnosis"]
    exact(
        threshold_contract["threshold_profile"]["profile_id"],
        diagnosis["threshold_profile_id"],
        "THRESHOLD_PROFILE",
    )
    exact(
        thresholds["maximum_energy_balance_residual_j"],
        diagnosis["maximum_energy_balance_residual_j"],
        "ENERGY_THRESHOLD",
    )
    exact(
        threshold_contract["threshold_profile"]["post_outcome_rethresholding_permitted"],
        False,
        "RETHRESHOLDING",
    )

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    verify_inventory(qualification_root, qualification["retained_artifacts"])
    attempt_path = qualification_root / qualification["attempt_path"]
    receipt_path = qualification_root / qualification["receipt_path"]
    exact(attempt_path.stat().st_size, qualification["attempt_byte_length"], "QUAL_ATTEMPT_LENGTH")
    exact(sha256(attempt_path.read_bytes()), qualification["attempt_raw_sha256"], "QUAL_ATTEMPT_HASH")
    exact(receipt_path.stat().st_size, qualification["receipt_byte_length"], "QUAL_RECEIPT_LENGTH")
    exact(sha256(receipt_path.read_bytes()), qualification["receipt_raw_sha256"], "QUAL_RECEIPT_HASH")
    qualification_matches = matching_roots(
        qualification_root.parent,
        "qsdk-r24d30-qualification-*",
        "qualification_attempt.json",
        "QSDK-R24D30",
        SOURCE,
    )
    exact(
        len(qualification_matches),
        qualification["official_qualification_attempt_count_for_source"],
        "QUALIFICATION_ATTEMPT_COUNT",
    )
    exact(qualification_matches, [qualification_root], "QUALIFICATION_ATTEMPT_IDENTITY")
    attempt = load(attempt_path)
    receipt = load(receipt_path)
    exact(attempt["mode"], "qualification", "QUAL_ATTEMPT_MODE")
    exact(attempt["source_commit"], SOURCE, "QUAL_ATTEMPT_SOURCE")
    exact(attempt["upstream_commit"], SOURCE, "QUAL_ATTEMPT_UPSTREAM")
    exact(attempt["live_remote_commit"], SOURCE, "QUAL_ATTEMPT_LIVE")
    exact(attempt["worktree_clean_at_start"], True, "QUAL_ATTEMPT_CLEAN")
    exact(attempt["operation_lock"]["acquired"], True, "QUAL_ATTEMPT_LOCK")
    exact(receipt["mode"], "qualification", "QUAL_RECEIPT_MODE")
    exact(receipt["ok"], True, "QUAL_RECEIPT_OK")
    exact(receipt["source_commit"], SOURCE, "QUAL_RECEIPT_SOURCE")
    exact(receipt["upstream_commit"], SOURCE, "QUAL_RECEIPT_UPSTREAM")
    exact(receipt["live_remote_commit"], SOURCE, "QUAL_RECEIPT_LIVE")
    exact(receipt["contract_raw_sha256"], sha256(bound[contract_path]), "QUAL_CONTRACT_HASH")
    exact(receipt["toolchain"], qualification["toolchain"], "QUAL_TOOLCHAIN")
    exact(receipt["operation_lock_released"], True, "QUAL_LOCK_RELEASED")
    exact(len(receipt["source_manifest"]), qualification["source_manifest_entry_count"], "QUAL_SOURCE_COUNT")
    exact(
        [item["path"] for item in receipt["source_manifest"]],
        contract["source_inventory"],
        "QUAL_SOURCE_ORDER",
    )
    verify_source_receipt_manifest(ROOT, SOURCE, receipt["source_manifest"])
    preflight = receipt["production_preflight"]
    exact(preflight["ok"], True, "PREFLIGHT_OK")
    exact(preflight["negative_control_count"], qualification["negative_control_count"], "PREFLIGHT_CONTROLS")
    exact(preflight["negative_controls_passed"], qualification["negative_controls_passed"], "PREFLIGHT_PASSED")
    exact(preflight["inherited_r24d29_control_count"], 45, "PREFLIGHT_INHERITED")
    exact(preflight["successor_integration_control_count"], 3, "PREFLIGHT_SUCCESSOR")
    require(all(preflight["successor_integration_controls"].values()), "PREFLIGHT_SUCCESSOR_FAILURE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(attempt[key], 0, f"QUAL_ATTEMPT_{key.upper()}")
        exact(receipt[key], 0, f"QUAL_RECEIPT_{key.upper()}")
        exact(preflight[key], 0, f"PREFLIGHT_{key.upper()}")
        exact(qualification[key], 0, f"QUAL_CLOSURE_{key.upper()}")
    for key in (
        "physics_state_modified",
        "physical_question_opened",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(receipt[key], False, f"QUAL_CLAIM_{key.upper()}")

    physical = closure["physical_attempt"]
    physical_root = Path(physical["evidence_root"])
    verify_inventory(physical_root, physical["retained_artifacts"])
    physical_matches = matching_roots(
        physical_root.parent,
        "qsdk-r24d30-mujoco-natural-recovery-progression-*",
        "attempt_reservation.json",
        "QSDK-R24D30",
        SOURCE,
    )
    exact(physical_matches, [physical_root], "PHYSICAL_ATTEMPT_IDENTITY")
    reservation = load(physical_root / "attempt_reservation.json")
    manifest = load(physical_root / "manifest.json")
    full = load(physical_root / "paired_full_result.json")
    summary = load(physical_root / "paired_summary.json")
    completion = load(physical_root / "supervisor_completion.json")
    lock = load(physical_root / "operation_lock.json")
    exact(reservation["campaign_id"], CAMPAIGN, "RESERVATION_CAMPAIGN")
    exact(reservation["question_class"], "development", "RESERVATION_CLASS")
    exact(reservation["source_commit"], SOURCE, "RESERVATION_SOURCE")
    exact(reservation["selected_cell_id"], physical["selected_cell_id"], "RESERVATION_CELL")
    exact(reservation["selected_seed"], physical["selected_seed"], "RESERVATION_SEED")
    exact(reservation["horizon_steps_per_arm"], physical["horizon_steps_per_arm"], "RESERVATION_HORIZON")
    exact(reservation["paired_arm_count"], physical["paired_arm_count"], "RESERVATION_ARMS")
    exact(reservation["qualification_receipt_raw_sha256"], qualification["receipt_raw_sha256"], "RESERVATION_QUALIFICATION")
    exact(reservation["held_out_cell_access_count"], 0, "RESERVATION_HELDOUT")
    exact(reservation["held_out_selector_invocation_count"], 0, "RESERVATION_SELECTOR")
    exact(completion["worker_started"], physical["worker_started"], "WORKER_STARTED")
    exact(completion["worker_exit_code"], physical["worker_exit_code"], "WORKER_EXIT")
    exact(completion["invalid_or_incomplete_retained"], False, "WORKER_COMPLETE")
    exact(completion["operation_lock_released"], physical["operation_lock_released"], "PHYSICAL_LOCK_RELEASED")
    exact(completion["caught_error"], None, "WORKER_ERROR")
    exact(lock["acquired"], True, "PHYSICAL_LOCK_ACQUIRED")
    exact(lock["role"], "physical", "PHYSICAL_LOCK_ROLE")
    exact(lock["test_only"], False, "PHYSICAL_LOCK_TEST")

    full_hash = sha256((physical_root / "paired_full_result.json").read_bytes())
    summary_hash = sha256((physical_root / "paired_summary.json").read_bytes())
    exact(manifest["source_commit"], SOURCE, "MANIFEST_SOURCE")
    exact(manifest["campaign_id"], CAMPAIGN, "MANIFEST_CAMPAIGN")
    exact(manifest["execution_valid"], True, "MANIFEST_VALID")
    exact(manifest["decision_positive"], False, "MANIFEST_DECISION")
    exact(manifest["complete_trace_retained"], True, "MANIFEST_TRACE")
    exact(
        manifest["artifacts"],
        [
            {
                "byte_length": (physical_root / "paired_full_result.json").stat().st_size,
                "path": "paired_full_result.json",
                "raw_sha256": full_hash,
            },
            {
                "byte_length": (physical_root / "paired_summary.json").stat().st_size,
                "path": "paired_summary.json",
                "raw_sha256": summary_hash,
            },
        ],
        "MANIFEST_ARTIFACTS",
    )
    exact(summary["full_result_raw_sha256"], full_hash, "SUMMARY_FULL_HASH")
    exact(full["source_commit"], SOURCE, "FULL_SOURCE")
    exact(full["campaign_id"], CAMPAIGN, "FULL_CAMPAIGN")
    exact(full["contract_raw_sha256"], sha256(bound[contract_path]), "FULL_CONTRACT")
    exact(full["qualification_receipt_raw_sha256"], qualification["receipt_raw_sha256"], "FULL_QUALIFICATION")
    exact(full["held_out_cell_access_count"], 0, "FULL_HELDOUT")
    exact(full["held_out_selector_invocation_count"], 0, "FULL_SELECTOR")
    exact(full["prone_to_standing_claimed"], False, "FULL_STANDING")
    exact(full["physical_acceptance_authority"], False, "FULL_ACCEPTANCE")
    exact(full["release_authority"], False, "FULL_RELEASE")

    result = full["result"]
    exact(result["route_id"], physical["route_id"], "RESULT_ROUTE")
    exact(result["model_xml_byte_length"], physical["model_xml_byte_length"], "MODEL_LENGTH")
    exact(result["model_xml_sha256"], physical["model_xml_sha256"], "MODEL_HASH")
    exact(result["initializer_identity_matched"], physical["initializer_identity_matched"], "INITIALIZER")
    for key in ("model_construction_count", "world_attempt_count", "world_build_count"):
        exact(result[key], physical[key], f"RESULT_{key.upper()}")
    exact(result["outer_step_count"], physical["outer_step_count"], "RESULT_OUTER_STEPS")
    exact(result["native_solver_step_count"], physical["native_solver_step_count"], "RESULT_SOLVER_STEPS")
    exact(result["physics_state_modified"], True, "RESULT_PHYSICS")
    exact(result["physical_development_result_observed"], False, "RESULT_POSITIVE")
    for key in (
        "controller_physical_viability_proven",
        "population_claimed",
        "repeatability_rate_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "prone_to_standing_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(result[key], False, f"RESULT_CLAIM_{key.upper()}")
    evaluation = result["evaluation"]
    observed = closure["observed_result"]
    exact(evaluation["support_status"], observed["portable_evaluation_support_status"], "EVALUATION_SUPPORT")
    exact(evaluation["physical_development_trace_valid"], True, "EVALUATION_VALID")
    exact(evaluation["verdict"], observed["portable_evaluation_verdict"], "EVALUATION_VERDICT")
    exact(evaluation["physical_result"], False, "EVALUATION_RESULT")
    exact(evaluation["refusal_reason"], None, "EVALUATION_REFUSAL")
    exact(evaluation["initial_state_identity_matched"], True, "EVALUATION_INITIALIZER")
    exact(evaluation["matched_zero_command_physical_control_failed_to_complete"], True, "EVALUATION_CONTROL")
    exact(evaluation["threshold_profile_sha256"], diagnosis["threshold_profile_sha256"], "EVALUATION_THRESHOLD")

    candidate = result["candidate"]
    control = result["matched_zero_command"]
    candidate_claim = observed["candidate"]
    control_claim = observed["matched_zero_command"]
    for arm, claim, label in (
        (candidate, candidate_claim, "CANDIDATE"),
        (control, control_claim, "CONTROL"),
    ):
        exact(arm["outer_step_count"], claim["outer_step_count"], f"{label}_OUTER")
        exact(arm["native_solver_step_count"], claim["native_solver_step_count"], f"{label}_SOLVER")
        exact(len(arm["observations"]), claim["observation_count"], f"{label}_OBSERVATIONS")
        exact(len(arm["native_receipts"]), claim["native_receipt_count"], f"{label}_NATIVE")
        exact(len(arm["collector_receipts"]), claim["collector_receipt_count"], f"{label}_COLLECTOR")
        exact(len(arm["portable_step_receipts"]), claim["portable_receipt_count"], f"{label}_PORTABLE")
        exact(arm["final_phase"], claim["final_phase"], f"{label}_FINAL_PHASE")
        require(
            all(receipt["support_status"] == "supported_exact" for receipt in arm["portable_step_receipts"]),
            f"{label}_SUPPORT",
        )
        require(
            all(receipt["refusal_reason"] is None for receipt in arm["portable_step_receipts"]),
            f"{label}_REFUSAL",
        )
        pairs, indices = transition_projection(arm["portable_step_receipts"])
        exact(pairs, claim["transition_pairs"], f"{label}_TRANSITIONS")
        exact(indices, claim["transition_indices_zero_based"], f"{label}_TRANSITION_INDICES")
        exact(
            arm["portable_step_receipts"][-1]["memory"]["terminal_failure_code"],
            claim["terminal_failure_code"],
            f"{label}_FAILURE",
        )
    exact(
        candidate["canonical_pre_step_state_sha256"],
        control["canonical_pre_step_state_sha256"],
        "PAIR_INITIAL_STATE",
    )
    exact(candidate["initializer_manifest_sha256"], control["initializer_manifest_sha256"], "PAIR_INITIALIZER")

    candidate_active = [
        index
        for index, receipt in enumerate(candidate["native_receipts"])
        if receipt["application"]["no_actuation_requested"] is False
    ]
    exact(len(candidate_active), candidate_claim["active_application_count"], "CANDIDATE_ACTIVE_COUNT")
    exact(candidate_active[0], candidate_claim["first_active_outer_index_zero_based"], "CANDIDATE_ACTIVE_FIRST")
    exact(candidate_active[-1], candidate_claim["last_active_outer_index_zero_based"], "CANDIDATE_ACTIVE_LAST")
    require(
        all(observation["applied_actuation"]["zero_command"] is True for observation in control["observations"]),
        "CONTROL_NOT_ZERO",
    )
    exact(control_claim["active_application_count"], 0, "CONTROL_ACTIVE_COUNT")
    exact(control_claim["observations_all_zero_command"], True, "CONTROL_ZERO_CLAIM")
    require(
        all(receipt["classification"]["joint_limits_respected"] is True for receipt in candidate["portable_step_receipts"]),
        "CANDIDATE_JOINT_LIMIT",
    )
    require(
        all(receipt["classification"]["joint_limits_respected"] is True for receipt in control["portable_step_receipts"]),
        "CONTROL_JOINT_LIMIT",
    )

    checks = summary["execution_checks"]
    exact(set(checks), set(observed["execution_checks_passed"]), "EXECUTION_CHECK_SET")
    require(all(checks.values()), "EXECUTION_CHECK_FAILURE")
    exact(summary["execution_valid"], observed["execution_valid"], "SUMMARY_VALID")
    exact(summary["decision_positive"], observed["decision_positive"], "SUMMARY_DECISION")
    exact(summary["valid_negative_if_decision_not_positive"], True, "SUMMARY_VALID_NEGATIVE")
    exact(summary["target_checks"]["candidate_reaches_stance_handoff_without_phase_skip"], False, "TARGET_HANDOFF")
    exact(summary["target_checks"]["candidate_transition_gates_are_measured_true"], False, "TARGET_GATES")
    exact(summary["target_checks"]["candidate_controller_continues_beyond_first_application"], True, "TARGET_APPLICATION")
    exact(summary["target_checks"]["matched_zero_remains_unactuated"], True, "TARGET_ZERO")

    classifications = [receipt["classification"] for receipt in candidate["portable_step_receipts"]]
    raised = [(index, value) for index, value in enumerate(classifications) if value["raised_body_gate"] is True]
    safety = [(index, value) for index, value in enumerate(classifications) if value["safety_gate"] is True]
    raised_and_safety = [(index, value) for index, value in raised if value["safety_gate"] is True]
    exact(len(raised), candidate_claim["raised_body_observation_count"], "RAISED_COUNT")
    exact(raised[0][0], candidate_claim["first_raised_body_outer_index_zero_based"], "RAISED_FIRST")
    exact(raised[-1][0], candidate_claim["last_raised_body_outer_index_zero_based"], "RAISED_LAST")
    exact(len(safety), candidate_claim["safety_true_observation_count"], "SAFETY_COUNT")
    exact(len(raised_and_safety), candidate_claim["raised_body_and_safety_true_observation_count"], "RAISED_SAFETY_COUNT")
    exact(raised[0][1]["energy_balance_residual_j"], diagnosis["first_raised_body_energy_balance_residual_j"], "RAISED_FIRST_ENERGY")
    exact(
        min(value["energy_balance_residual_j"] for _, value in raised),
        diagnosis["minimum_energy_balance_residual_j_across_raised_body_observations"],
        "RAISED_MIN_ENERGY",
    )
    exact(
        sum(value["joint_limits_respected"] is False for _, value in raised),
        diagnosis["raised_body_joint_limit_failure_count"],
        "RAISED_JOINT_FAILURES",
    )
    exact(
        sum(value["actuator_budget_respected"] is False for _, value in raised),
        diagnosis["raised_body_actuator_budget_failure_count"],
        "RAISED_BUDGET_FAILURES",
    )
    exact(
        sum(value["maximum_nonfoot_contact_impulse_ns"] > 0.0 for _, value in raised),
        diagnosis["raised_body_forbidden_contact_impulse_failure_count"],
        "RAISED_CONTACT_FAILURES",
    )
    exact(
        sum(
            value["energy_balance_residual_j"] > diagnosis["maximum_energy_balance_residual_j"]
            for _, value in raised
        ),
        diagnosis["raised_body_energy_balance_residual_failure_count"],
        "RAISED_ENERGY_FAILURES",
    )
    exact(len(raised_and_safety), diagnosis["raised_body_safety_conjunction_pass_count"], "RAISED_CONJUNCTION")
    terminal = classifications[-1]
    terminal_claim = diagnosis["terminal_classification"]
    for key, expected in terminal_claim.items():
        exact(terminal[key], expected, f"TERMINAL_{key.upper()}")
    exact(terminal["energy_balance_residual_j"], diagnosis["terminal_energy_balance_residual_j"], "TERMINAL_ENERGY")

    formula_source = source_bytes(ROOT, SOURCE, diagnosis["safety_formula_authority_path"]).decode("utf-8")
    for fragment in (
        "let safety_gate = joint_limits_respected",
        "&& actuator_budget_respected",
        "maximum_nonfoot_contact_impulse_ns <= thresholds.maximum_forbidden_contact_impulse_ns",
        "energy_balance_residual_j <= thresholds.maximum_energy_balance_residual_j",
    ):
        require(fragment in formula_source, f"SAFETY_FORMULA:{fragment}")
    exact(diagnosis["diagnostic_class"], "unchanged_energy_balance_residual_threshold_blocks_every_observed_raised_body_safety_conjunction", "DIAGNOSIS")
    exact(diagnosis["raised_body_geometry_observed"], True, "DIAGNOSIS_RAISED")
    for key in (
        "recovery_to_stance_handoff_observed",
        "root_cause_of_energy_balance_residual_established",
        "controller_fault_established",
        "native_energy_ledger_fault_established",
        "threshold_inadequacy_established",
        "threshold_or_margin_changed",
        "historical_result_reinterpreted",
    ):
        exact(diagnosis[key], False, f"DIAGNOSIS_{key.upper()}")

    sdk = closure["sdk_status"]
    exact(sdk["sdk1_completed_steps"], 11, "SDK1_SCORE")
    exact(sdk["sdk1_total_steps"], 20, "SDK1_TOTAL")
    exact(sdk["full_program_completed_steps"], 11, "PROGRAM_SCORE")
    exact(sdk["full_program_total_steps"], 25, "PROGRAM_TOTAL")
    exact(sdk["sdk1_milestone_advanced"], False, "SDK_ADVANCE")
    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D31", "NEXT_GATE")
    exact(next_boundary["status"], "not_yet_frozen_physical_execution_blocked", "NEXT_STATUS")
    exact(next_boundary["distinct_clean_pushed_source_freeze_required"], True, "NEXT_FREEZE")
    exact(next_boundary["same_identity_rerun_permitted"], False, "NEXT_RERUN")
    exact(next_boundary["r24d30_may_be_requalified"], False, "NEXT_REQUALIFY")
    exact(next_boundary["new_threshold_or_margin_selected"], False, "NEXT_THRESHOLD")
    exact(next_boundary["next_physical_execution_authorized"], False, "NEXT_PHYSICAL")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    validate_claim_boundary(closure)
    for dotted, value in (
        ("claim_boundary.execution_valid_development_negative_observed", False),
        ("claim_boundary.safety_gate_passed", True),
        ("claim_boundary.prone_to_standing_claimed", True),
        ("claim_boundary.release_authority", True),
    ):
        mutated = deepcopy(closure)
        cursor = mutated
        parts = dotted.split(".")
        for part in parts[:-1]:
            cursor = cursor[part]
        cursor[parts[-1]] = value
        try:
            validate_claim_boundary(mutated)
        except ClosureAuditError:
            continue
        raise ClosureAuditError(f"CLAIM_MUTATION_ACCEPTED:{dotted}")

    print(
        "QSDK_R24D30_PHYSICAL_CLOSURE_PASS result=valid_negative "
        "candidate=failed:raise_body raised_observations=439 safety=0 "
        "energy_min_raised_j=11.630772800838084 energy_limit_j=0.25 "
        "matched_zero=unactuated_failed worlds=2 outer_steps=1520 "
        "solver_steps=7600 heldout_access=0 sdk1=11/20 next=QSDK-R24D31"
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
        print(f"QSDK_R24D30_PHYSICAL_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
