"""Compact audit of the retained invalid QSDK-R24D35 route smoke."""

from __future__ import annotations

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
    verify_exact_retained_inventory,
    verify_invalid_physical_attempt_closure,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)

CLOSURE_PATH = ROOT / "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_invalid_closure_v1.json"
SOURCE = "4d4abdcf4439c8c40f6f24816126fc9f4261853a"
GATE = "QSDK-R24D35"
CAMPAIGN = "QSDK-R24D35-MUJOCO-SPARSE-ACTUATOR-MOMENT"
STATUS = "closed_consumed_invalid_incomplete_historical_dissipation_invariant_rejection"


def _ordered(source: str, markers: tuple[str, ...], code: str) -> None:
    require(all(marker in source for marker in markers), f"{code}_MARKER")
    offsets = [source.index(marker) for marker in markers]
    require(offsets == sorted(offsets), f"{code}_ORDER")


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        (closure["gate_id"], closure["campaign_id"], closure["closure_status"], closure["question_class"]),
        (GATE, CAMPAIGN, STATUS, "development"),
        "CLOSURE_IDENTITY",
    )
    exact_bools(closure, ("physical_question_declared",), True, "DECLARATION")
    exact_bools(closure, ("superiority_question_declared", "equivalence_or_non_inferiority_question_declared", "population_inference_declared"), False, "DECLARATION")

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact((source["commit"], git(ROOT, "show", "-s", "--format=%T", SOURCE)), (SOURCE, source["tree"]), "SOURCE_IDENTITY")
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    runtime = verify_source_binding(ROOT, SOURCE, source["runtime"]).decode("utf-8")
    for key in ("sparse_adapter", "worker", "source_audit"):
        verify_source_binding(ROOT, SOURCE, source[key])
    exact(
        (contract["gate_id"], contract["campaign_id"], contract["question_class"], contract["physical_question_declared"], contract["behavior_question_declared"]),
        (GATE, CAMPAIGN, "development", True, False),
        "CONTRACT_IDENTITY",
    )

    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d35-qualification-",
        contract_inventory=contract["source_inventory"],
    )
    verify_exact_retained_inventory(Path(closure["qualification"]["evidence_root"]), closure["qualification"]["retained_artifacts"])
    exact((receipt["contract_path"], receipt["contract_raw_sha256"]), (source["contract"]["path"], source["contract"]["raw_sha256"]), "RECEIPT_CONTRACT")
    exact((preflight["negative_control_count"], preflight["negative_controls_passed"]), (9, 9), "PREFLIGHT_COUNTS")
    exact(set(preflight["sparse_actuator_moment_controls"]), set(contract["complete_zero_world_gate"]["required_controls"]), "CONTROL_SET")
    require(all(preflight["sparse_actuator_moment_controls"].values()), "CONTROL_FAILURE")

    values = verify_invalid_physical_attempt_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        campaign_id=CAMPAIGN,
        source_commit=SOURCE,
        physical_directory_prefix="qsdk-r24d35-mujoco-sparse-actuator-moment-smoke-",
        schemas={
            "reservation": "sporespore_qsdk_r24d35_sparse_actuator_moment_smoke_attempt_reservation_v1",
            "invalid": "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_invalid_v1",
            "completion": "sporespore_qsdk_r24d35_sparse_actuator_moment_smoke_supervisor_completion_v1",
            "lock": "sporespore_locomotion_operation_lock_receipt_v1",
        },
        qualification_receipt_raw_sha256=closure["qualification"]["receipt_raw_sha256"],
        absent_complete_paths=("manifest.json", "smoke_result.json", "smoke_summary.json"),
    )
    physical = closure["physical_attempt"]
    exact(physical["official_physical_attempt_count_for_source"], 1, "PHYSICAL_ATTEMPT_COUNT")
    for marker in ("candidate = _run_arm(", "world.step_native(", "QSDK_R24D31_CUMULATIVE_DISSIPATION_NEGATIVE"):
        require(marker in values["invalid"]["traceback"], f"TRACEBACK_MARKER:{marker}")
    exact((Path(physical["evidence_root"]) / "worker_stderr.log").stat().st_size, 0, "STDERR_EMPTY")

    _ordered(runtime, (
        "actuator_moment_expansion = expand_sparse_actuator_moment_v1(",
        "mujoco.mj_implicit(model, data)",
        "implicit_substep_receipts.append(",
        "self._capture_contacts(",
        "self.solver_step_count += 1",
        "self.cumulative_dissipated_energy_j += step_dissipated_energy_j",
        "self.cumulative_dissipated_energy_j >= 0.0",
        "observation = {",
    ), "SOURCE_NATIVE")
    _ordered(runtime, ("candidate = _run_arm(", "matched_zero = _run_arm("), "SOURCE_ARMS")
    exact_bools(physical, ("worker_started", "operation_lock_released", "invalid_or_incomplete_retained", "candidate_arm_entered_by_traceback", "native_world_was_constructed_by_source_order", "first_outer_step_native_loop_reached_exit_by_source_order", "sparse_expansion_returned_by_source_order", "native_integrator_called_by_source_order", "implicit_substep_receipts_accumulated_in_memory_by_source_order"), True, "PHYSICAL_OBSERVED")
    exact_bools(physical, ("route_coverage_passed", "matched_zero_arm_entered_by_source_order", "current_observation_published", "native_receipt_published", "collector_invoked", "portable_evaluator_invoked", "durable_complete_result_published", "valid_behavior_result_observed", "exact_execution_counts_published"), False, "PHYSICAL_LIMIT")
    for key in ("model_construction_count", "world_attempt_count", "world_build_count", "outer_step_count", "solver_step_count", "physics_state_modified"):
        exact(physical[key], None, f"UNPUBLISHED_{key.upper()}")

    failure = closure["observed_failure"]
    exact(failure["class"], "historical_v2_nonnegative_dissipation_invariant_rejection_after_native_integration", "FAILURE_CLASS")
    exact((failure["source_formula"], failure["source_guard"]), ("dissipated_energy_j = -(constraint_work_j + damper_work_j + fluid_work_j + adhesion_work_j)", "cumulative_dissipated_energy_j >= 0.0"), "FAILURE_FORMULA")
    exact_bools(failure, ("in_run_physical_invariant_rejection_observed", "public_sparse_expansion_returned_by_source_order", "native_integration_advanced_by_source_order", "historical_v2_cumulative_dissipation_guard_reached", "historical_v2_cumulative_dissipation_was_negative_according_to_guard", "signed_constraint_and_passive_work_sum_was_positive_according_to_frozen_formula"), True, "FAILURE_OBSERVED")
    exact_bools(failure, ("sparse_actuator_moment_adapter_failure_established", "exact_cumulative_dissipation_value_published", "exact_constraint_work_value_published", "exact_passive_work_values_published", "v3_centered_cumulative_guard_reached", "portable_observation_published", "physical_behavior_failure_established", "energy_threshold_failure_established", "selector_failure_established", "evaluator_failure_established", "controller_failure_established", "model_failure_established", "recovery_progression_observed", "result_interpretation_rewritten"), False, "FAILURE_LIMIT")

    postmortem = closure["zero_world_gate_postmortem"]
    exact_bools(postmortem, ("gate_passed_for_declared_controls", "physical_opening_conditions_were_satisfied", "physical_opening_was_contract_compliant", "sparse_representation_coverage_was_adequate", "smallest_route_smoke_fulfilled_fail_closed_role"), True, "POSTMORTEM")
    exact_bools(postmortem, ("gate_result_rewritten", "historical_closure_audits_reexecuted", "full_seeded_ghost_required", "additional_full_physical_canary_required"), False, "POSTMORTEM_LIMIT")
    exact(len(postmortem["required_successor_controls"]), 8, "SUCCESSOR_CONTROL_COUNT")

    decision = closure["decision"]
    exact((decision["result"], decision["sdk1_completed_steps"], decision["sdk1_total_steps"], decision["full_program_completed_steps"], decision["full_program_total_steps"]), ("consumed_invalid_incomplete_and_retained", 11, 20, 11, 25), "DECISION")
    exact_bools(decision, ("official_zero_world_qualification_passed", "all_nine_declared_zero_world_controls_passed", "historical_v2_nonnegative_dissipation_invariant_rejected"), True, "DECISION_POSITIVE")
    exact_bools(decision, ("r24d35_may_be_rerun", "same_source_may_be_reused_for_another_r24d35_result", "valid_physical_route_result_observed", "sparse_actuator_moment_integration_failure_observed", "complete_portable_observation_observed", "energy_residual_acceptance_observed", "recovery_to_stance_handoff_observed", "controller_physical_viability_proven", "prone_to_standing_claimed", "sdk1_milestone_advanced"), False, "DECISION_LIMIT")

    next_boundary = closure["next_boundary"]
    exact((next_boundary["gate_id"], next_boundary["question_class"], next_boundary["physical_question_declared"], next_boundary["behavior_question_declared"]), ("QSDK-R24D36", "development", False, False), "NEXT")
    exact_bools(next_boundary, ("distinct_source_declaration_required", "complete_zero_world_gate_required_before_physics", "held_out_cells_remain_sealed"), True, "NEXT_POSITIVE")
    exact_bools(next_boundary, ("r24d35_may_rerun", "full_seeded_ghost_required", "additional_physical_canary_required", "controller_changed", "native_physics_changed", "morphology_changed", "initializer_changed", "observer_values_may_be_rewritten", "behavior_thresholds_changed", "margins_changed", "selector_changed", "cell_changed", "seed_changed", "horizon_changed", "portable_evaluator_changed"), False, "NEXT_LIMIT")

    positive_claims = {"official_zero_world_qualification_passed", "declared_r24d35_zero_world_controls_passed", "physical_question_opened", "invalid_incomplete_result_retained", "sparse_representation_seam_cleared_by_source_order", "historical_v2_nonnegative_dissipation_invariant_rejected"}
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")
    require("QSDK_R24D35_MUJOCO_SPARSE_ACTUATOR_MOMENT_SOURCE_PASS" in (Path(closure["qualification"]["evidence_root"]) / "source_audit.log").read_text(encoding="utf-8"), "SOURCE_AUDIT_MARKER")
    print("QSDK_R24D35_MUJOCO_SPARSE_ACTUATOR_MOMENT_INVALID_CLOSURE_PASS qualification=9/9 physical=consumed_invalid cause=historical_v2_nonnegative_dissipation_invariant sparse_seam=cleared exact_counts=unpublished heldout=0 sdk1=11/20 next=QSDK-R24D36")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D35_MUJOCO_SPARSE_ACTUATOR_MOMENT_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
