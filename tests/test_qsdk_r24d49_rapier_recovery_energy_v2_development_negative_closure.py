"""Closure audit for the valid-negative QSDK-R24D49-B Rapier result."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
import subprocess
import sys


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
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_rapier_recovery_energy_v2_arm,
    verify_retained_file_tree,
    verify_source_binding,
    verify_staged_physical_runner_closure,
)


CLOSURE_PATH = ROOT / (
    "sdk/recovery/"
    "r24d49_rapier_recovery_energy_v2_development_negative_closure_v1.json"
)
SOURCE = "5b00ad16943e552f851ef31c4032bb6140362b15"
QUALIFICATION_SOURCE = "a6b9f77577e36236685db8b20badd0ddc39b5017"
GATE = "QSDK-R24D49"
STATUS = (
    "closed_valid_complete_development_negative_candidate_reached_"
    "stance_dwell_energy_residual_gate_timed_out"
)
RUNTIME_BINDING = (
    "sha256:946d9f1dda22658c989b59daf7f75b32d82586009288baca0207b8ca8c01ea28"
)


def _transitions(arm: dict[str, object]) -> tuple[list[int], list[list[str]]]:
    records = [
        (index, receipt)
        for index, receipt in enumerate(arm["portable_step_receipts"])
        if receipt["transitioned"]
    ]
    return (
        [index for index, _ in records],
        [[value["prior_phase"], value["next_phase"]] for _, value in records],
    )


def _maximum_true_streak(values: list[bool]) -> tuple[int, int | None, int | None]:
    maximum = current = 0
    start = end = current_start = None
    for index, value in enumerate(values):
        if value:
            current_start = index if current == 0 else current_start
            current += 1
            if current > maximum:
                maximum, start, end = current, current_start, index
        else:
            current = 0
            current_start = None
    return maximum, start, end


def audit() -> None:
    closure = load(CLOSURE_PATH)
    verify_exact_paths(closure, {
        "schema_version": (
            "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
            "development_negative_closure_v1"
        ),
        "gate_id": GATE,
        "stage_id": "R24D49-B",
        "closure_status": STATUS,
        "question_class": "development",
        "physical_question_declared": True,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "source.commit": SOURCE,
        "source.parent_commit": "d079da0b3fd6049e12ee8b509819680887d55045",
        "source.tree": "943d301824437c82c0c587ccb317bbdfe50c614a",
        "source.subject": "[recovery/rapier] Repair R49 Stage B ghost authority",
        "source.qualification_source_commit": QUALIFICATION_SOURCE,
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")

    source = closure["source"]
    names = (
        "contract", "core_recovery", "runtime_binding_route", "behavior_route",
        "shared_physical_runner", "physical_wrapper", "qualification_closure",
        "ghost_closure", "stage_authority_contract", "stage_authority_audit",
    )
    bound = {name: verify_source_binding(ROOT, SOURCE, source[name]) for name in names}
    qualification = loads(bound["qualification_closure"])
    ghost = loads(bound["ghost_closure"])
    stage_authority = loads(bound["stage_authority_contract"])
    verify_exact_paths(qualification, {
        "source.commit": QUALIFICATION_SOURCE,
        "qualification.runtime_binding_sha256": RUNTIME_BINDING,
        "decision.official_zero_world_qualification_passed": True,
    }, "QUALIFICATION")
    verify_exact_paths(ghost, {
        "source.commit": "686cf0ab5ff41c20504118e202b2329b264830f2",
        "decision.integration_ghost_passed": True,
        "decision.paired_development_authorized": True,
        "claim_boundary.prone_to_standing_claimed": False,
    }, "GHOST")
    verify_exact_paths(stage_authority, {
        "gate_id": GATE, "stage_id": "R24D49-B",
        "qualification_dependency.runtime_binding_sha256": RUNTIME_BINDING,
        "ghost_authority.closure_raw_sha256": source["ghost_closure"]["raw_sha256"],
        "observed_pre_world_rejection.paired_development_attempt_consumed": False,
        "claim_boundary.additional_physical_canary_required": False,
    }, "STAGE_AUTHORITY")

    values = verify_staged_physical_runner_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        qualification_source_commit=QUALIFICATION_SOURCE,
        physical_directory_prefix=(
            "qsdk-r24d49-rapier-recovery-energy-v2-physical-"
        ),
        mode="development",
        schemas={
            "attempt": (
                "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
                "physical_attempt_v1"
            ),
            "result": (
                "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
                "development_result_v1"
            ),
            "receipt": (
                "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
                "physical_receipt_v1"
            ),
        },
        runtime_binding_field="runtime_binding_sha256",
    )
    attempt, result, receipt = (
        values["attempt"], values["result"], values["receipt"]
    )
    verify_exact_paths(attempt, {
        "branch": "main",
        "remote": "https://github.com/Slagathore/sporespore.git",
        "environment_sha256": closure["physical_attempt"]["environment_sha256"],
        "ghost_authority_path": closure["physical_attempt"]["ghost_authority_path"],
    }, "ATTEMPT")
    verify_exact_paths(receipt, {
        "candidate_outer_steps": 967,
        "matched_zero_outer_steps": 252,
        "ghost_authority_path": closure["physical_attempt"]["ghost_authority_path"],
    }, "RECEIPT")
    verify_exact_paths(result, {
        "ok": True,
        "gate_id": GATE,
        "route_id": "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1",
        "question_class": "development",
        "runtime_qualification_sha256": RUNTIME_BINDING,
        "runtime_binding_sha256": RUNTIME_BINDING,
        "behavior_lineage_gate_id": "QSDK-R24D48",
        "cell_id": "r24d48_rapier_development_nominal",
        "cell_seed": 260226999,
        "candidate_outer_steps": 967,
        "matched_zero_outer_steps": 252,
        "actual_total_outer_steps": 1219,
        "maximum_outer_steps_per_arm": 1200,
        "maximum_total_outer_steps": 2400,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "result_may_satisfy_r24d49": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }, "RESULT")
    evaluation = result["evaluation"]
    verify_exact_paths(evaluation, {
        "schema_version": "sporespore_recovery_evaluation_receipt_v1",
        "support_status": "supported_exact",
        "refusal_reason": None,
        "verdict": "physical_development_failed",
        "physical_development_trace_valid": True,
        "physical_question_opened": True,
        "physical_result": False,
        "candidate_physical_path_completed": False,
        "candidate_trace.final_phase": "failed",
        "candidate_trace.terminal_failure_code": "phase_timeout:stance_dwell",
        "matched_zero_command_physical_control_failed_to_complete": True,
        "matched_zero_command_trace.final_phase": "failed",
        "matched_zero_command_trace.terminal_failure_code": (
            "phase_timeout:establish_distal_support"
        ),
        "initial_state_identity_matched": True,
        "prone_to_standing_claimed": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }, "EVALUATION")

    candidate = result["candidate"]
    matched = result["matched_zero_command"]
    candidate_chain = verify_rapier_recovery_energy_v2_arm(candidate, "CANDIDATE")
    matched_chain = verify_rapier_recovery_energy_v2_arm(matched, "MATCHED_ZERO")
    observed = closure["observed_result"]
    for arm, claim, chain in (
        (candidate, observed["candidate"], candidate_chain),
        (matched, observed["matched_zero_command"], matched_chain),
    ):
        exact((chain["outer_step_count"], chain["native_solver_step_count"],
               chain["final_phase"], chain["terminal_failure_code"]),
              (claim["outer_step_count"], claim["native_solver_step_count"],
               claim["final_phase"], claim["terminal_failure_code"]),
              f"ARM_CHAIN:{arm['arm_kind']}")
        indices, pairs = _transitions(arm)
        exact((indices, pairs),
              (claim["transition_indices_zero_based"], claim["transition_pairs"]),
              f"TRANSITIONS:{arm['arm_kind']}")
        exact(dict(Counter(
            value["prior_phase"] for value in arm["portable_step_receipts"]
        )), claim["phase_counts"], f"PHASE_COUNTS:{arm['arm_kind']}")
    exact(candidate["declared_initial_state_sha256"],
          matched["declared_initial_state_sha256"], "PAIR_INITIAL_STATE")
    exact(candidate["declared_initial_state_sha256"],
          observed["paired_initial_state_sha256"], "PAIR_INITIAL_CLAIM")
    candidate_owners = Counter(
        value["controller_ownership"]["owner"]
        for value in candidate["trace"]["observations"]
    )
    matched_owners = Counter(
        value["controller_ownership"]["owner"]
        for value in matched["trace"]["observations"]
    )
    exact((candidate_owners["recovery"], candidate_owners["stance"]),
          (observed["candidate"]["recovery_owner_observation_count"],
           observed["candidate"]["stance_owner_observation_count"]),
          "CANDIDATE_OWNERS")
    exact(matched_owners, Counter({"none": 252}), "MATCHED_OWNERS")
    active_applications = [
        index for index, value in enumerate(candidate["invariant_receipts"])
        if value["application"]["native_load_bearing_application_count"] > 0
    ]
    exact(
        (len(active_applications), active_applications[0], active_applications[-1],
         candidate_chain["active_control_count"], matched_chain["active_control_count"]),
        (955, 12, 966, 955, 0),
        "ACTIVE_CONTROL",
    )

    diagnosis = closure["exact_gate_diagnosis"]
    stance = [
        (index, value["classification"])
        for index, value in enumerate(candidate["portable_step_receipts"])
        if value["prior_phase"] == "stance_dwell"
    ]
    stable = [value["stable_stance_gate"] for _, value in stance]
    maximum, local_start, local_end = _maximum_true_streak(stable)
    start = stance[local_start][0] if local_start is not None else None
    end = stance[local_end][0] if local_end is not None else None
    threshold = closure["frozen_threshold_provenance"]
    first_failure = next(
        (index, value) for index, value in stance
        if value["energy_balance_residual_j"]
        > threshold["maximum_energy_balance_residual_j"]
    )
    non_energy = [
        (
            value["torso_height_ratio"] >= 0.75
            and value["torso_up_dot"] >= 0.95
            and value["all_four_distal_sites_bearing"]
            and not value["any_nonfoot_contact"]
            and value["minimum_nonfoot_clearance_m"] >= 0.005
            and value["terminal_linear_speed_m_s"] <= 0.10
            and value["terminal_angular_speed_rad_s"] <= 0.20
            and value["exclusive_stance_handoff_gate"]
            and value["joint_limits_respected"]
            and value["actuator_budget_respected"]
            and value["maximum_nonfoot_contact_impulse_ns"] <= 0.0
            and value["no_cheat_gate"]
        )
        for _, value in stance
    ]
    residuals = candidate_chain["residuals_j"]
    final = candidate["portable_step_receipts"][-1]["classification"]
    verify_exact_paths(diagnosis, {
        "candidate_reached_stance_handoff": True,
        "candidate_reached_stance_dwell": True,
        "candidate_stance_dwell_observation_count": len(stance),
        "required_consecutive_stable_stance_steps": threshold[
            "required_stance_dwell_steps"
        ],
        "observed_maximum_consecutive_stable_stance_steps": maximum,
        "stable_stance_deficit_steps": (
            threshold["required_stance_dwell_steps"] - maximum
        ),
        "stable_stance_streak_start_index_zero_based": start,
        "stable_stance_streak_end_index_zero_based": end,
        "first_stance_dwell_energy_residual_j": stance[0][1][
            "energy_balance_residual_j"
        ],
        "first_failing_energy_residual_index_zero_based": first_failure[0],
        "first_failing_energy_residual_j": first_failure[1][
            "energy_balance_residual_j"
        ],
        "terminal_energy_balance_residual_j": residuals[-1],
        "maximum_energy_balance_residual_j": max(residuals),
        "maximum_energy_balance_residual_index_zero_based": residuals.index(
            max(residuals)
        ),
        "stance_dwell_non_energy_prerequisite_pass_count": sum(non_energy),
        "stance_dwell_energy_gate_pass_count": sum(
            value["energy_balance_residual_j"] <= 0.25 for _, value in stance
        ),
        "stance_dwell_safety_gate_pass_count": sum(
            value["safety_gate"] for _, value in stance
        ),
        "stance_dwell_stable_stance_gate_pass_count": sum(stable),
        "terminal_candidate_pose_class": final["pose_class"],
        "terminal_candidate_torso_height_ratio": final["torso_height_ratio"],
        "terminal_candidate_torso_up_dot": final["torso_up_dot"],
        "terminal_candidate_linear_speed_m_s": final["terminal_linear_speed_m_s"],
        "terminal_candidate_angular_speed_rad_s": final["terminal_angular_speed_rad_s"],
        "terminal_candidate_minimum_nonfoot_clearance_m": final[
            "minimum_nonfoot_clearance_m"
        ],
        "terminal_candidate_maximum_nonfoot_contact_impulse_ns": final[
            "maximum_nonfoot_contact_impulse_ns"
        ],
        "terminal_candidate_intervention_counter_total": final[
            "intervention_counter_total"
        ],
        "observed_gate_failure_is_energy_residual_only_during_stance_dwell": True,
    }, "DIAGNOSIS")
    exact_bools(diagnosis, (
        "remaining_residual_physical_cause_established", "controller_fault_established",
        "native_energy_component_mapping_fault_established",
        "numerical_integration_error_established", "threshold_inadequacy_established",
        "threshold_or_margin_changed", "historical_result_reinterpreted",
    ), False, "DIAGNOSIS_LIMITS")
    exact((sum(non_energy), maximum, start, end, first_failure[0]),
          (240, 19, 727, 745, 746), "STANCE_DIAGNOSIS")

    core = bound["core_recovery"].decode("utf-8")
    require_ordered_markers(core, (
        "stance_dwell_steps: 60",
        "stance_dwell: 240",
        "maximum_energy_balance_residual_j: 0.25",
        "let safety_gate = joint_limits_respected",
        "energy_balance_residual_j <= thresholds.maximum_energy_balance_residual_j",
        "if classification.stable_stance_gate",
        "memory.stance_dwell_steps_observed >= context.threshold_profile.stance_dwell_steps",
    ), "FROZEN_THRESHOLD_SOURCE")
    verify_exact_paths(threshold, {
        "profile_sha256": evaluation["threshold_profile_sha256"],
        "maximum_energy_balance_residual_j": 0.25,
        "required_stance_dwell_steps": 60,
        "stance_dwell_timeout_steps": 240,
        "maximum_outer_steps_per_arm": 1200,
        "threshold_selected_after_observation": False,
        "threshold_changed": False,
        "margin_selected_or_changed": False,
        "population_claim_permitted": False,
    }, "THRESHOLD")

    physical = closure["physical_attempt"]
    evidence_root = Path(physical["evidence_root"])
    exact(sorted(
        path.relative_to(evidence_root).as_posix()
        for path in evidence_root.rglob("*") if path.is_file()
    ), [
        "01-worker.log", "isolated-harness/Cargo.lock",
        "isolated-harness/Cargo.toml", "isolated-harness/src/main.rs",
        "physical_attempt.json", "physical_receipt.json", "physical_result.json",
    ], "RETAINED_PATHS")
    exact(
        (
            sum(arm["model_construction_count"] for arm in (candidate, matched)),
            sum(arm["world_attempt_count"] for arm in (candidate, matched)),
            sum(arm["world_build_count"] for arm in (candidate, matched)),
            sum(arm["native_solver_step_count"] for arm in (candidate, matched)),
            sum(arm["outer_step_count"] for arm in (candidate, matched)),
        ),
        (2, 2, 2, 1219, 1219),
        "PHYSICAL_COUNTS",
    )
    log_claim = physical["worker_log"]
    log_raw = (evidence_root / log_claim["path"]).read_bytes()
    exact((len(log_raw), sha256(log_raw)),
          (log_claim["byte_length"], log_claim["raw_sha256"]), "WORKER_LOG")
    require_ordered_markers(log_raw.decode("utf-8"), (
        "Finished `dev` profile", "Running `",
        "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_DEVELOPMENT {",
    ), "WORKER_RESULT_ORDER")

    exact_bools(closure["decision"], (
        "paired_development_attempt_consumed_for_exact_source", "stage_valid",
        "execution_complete", "physical_question_opened",
        "complete_in_run_chain_observed", "all_in_run_physical_invariants_passed",
        "paired_initial_state_exact", "matched_zero_negative_control_observed",
        "candidate_reached_stance_dwell",
        "candidate_produced_nineteen_consecutive_stable_stance_frames",
    ), True, "DECISION_TRUE")
    exact_bools(closure["decision"], (
        "candidate_completed_required_stance_dwell", "decision_positive",
        "prone_to_standing_observed", "same_source_or_identity_rerun_permitted",
        "r24d49_may_be_requalified", "controller_changed", "threshold_changed",
        "selector_changed", "evaluator_changed", "morphology_changed",
        "initializer_changed", "physical_acceptance_authority", "release_authority",
    ), False, "DECISION_FALSE")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["audit_economy"], {
        "common_staged_physical_runner_closure_helper_reused": True,
        "common_rapier_recovery_energy_v2_arm_helper_reused": True,
        "historical_closure_audit_execution_count": 0,
        "physical_reexecution_count": 0,
        "new_campaign_specific_physical_canary_count": 0,
    }, "AUDIT_ECONOMY")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D50",
        "physical_execution_authorized": False,
        "maximum_physical_steps_authorized": 0,
        "same_identity_rerun_permitted": False,
        "additional_physical_canary_required": False,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }, "NEXT")

    rejected = 0
    tree = physical["retained_tree"]
    for mutation in (
        {**tree, "file_count": tree["file_count"] + 1},
        {**tree, "manifest_canonical_sha256": "sha256:" + "0" * 64},
    ):
        try:
            verify_retained_file_tree(evidence_root, mutation)
        except ClosureAuditError:
            rejected += 1
    exact(rejected, 2, "TREE_MUTATION_REJECTIONS")

    relative = CLOSURE_PATH.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H",
                      "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    closure_raw = (CLOSURE_PATH.read_bytes() if revision is None else
                   source_bytes(ROOT, revision, relative))
    live = {
        **closure["live_gate_expectations"],
        "r24d49_paired_development_closure_raw_sha256": sha256(closure_raw),
    }
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45", live,
        revision=revision,
    )
    print(
        "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_DEVELOPMENT_NEGATIVE_CLOSURE_PASS "
        "files=7 models=2 worlds=2 solver_steps=1219 outer_steps=1219 "
        "candidate=failed:stance_dwell stable_streak=19/60 "
        "first_failing_residual_j=0.2500120323811643 matched_zero=failed:support "
        "sdk1=11/20 next=QSDK-R24D50:zero_world_diagnosis"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError, OSError, KeyError, IndexError, TypeError, ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_DEVELOPMENT_NEGATIVE_CLOSURE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
