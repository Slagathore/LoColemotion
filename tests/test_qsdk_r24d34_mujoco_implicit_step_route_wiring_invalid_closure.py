"""Compact audit of the retained invalid QSDK-R24D34 route smoke."""

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

CLOSURE_PATH = ROOT / "sdk/recovery/r24d34_mujoco_implicit_step_route_wiring_invalid_closure_v1.json"
SOURCE = "d7b477d0d92575fe1b1fe819591099cc5a02a86f"
GATE = "QSDK-R24D34"
CAMPAIGN = "QSDK-R24D34-MUJOCO-IMPLICIT-STEP-ROUTE-WIRING"
STATUS = "closed_consumed_invalid_incomplete_sparse_actuator_moment_representation_mismatch"


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
        attempt_schema="sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d34-qualification-",
        contract_inventory=contract["source_inventory"],
    )
    verify_exact_retained_inventory(Path(closure["qualification"]["evidence_root"]), closure["qualification"]["retained_artifacts"])
    exact((receipt["contract_path"], receipt["contract_raw_sha256"]), (source["contract"]["path"], source["contract"]["raw_sha256"]), "RECEIPT_CONTRACT")
    exact((preflight["negative_control_count"], preflight["negative_controls_passed"]), (10, 10), "PREFLIGHT_COUNTS")
    exact(set(preflight["route_wiring_controls"]), set(contract["complete_zero_world_gate"]["required_controls"]), "CONTROL_SET")
    require(all(preflight["route_wiring_controls"].values()), "CONTROL_FAILURE")

    values = verify_invalid_physical_attempt_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        campaign_id=CAMPAIGN,
        source_commit=SOURCE,
        physical_directory_prefix="qsdk-r24d34-mujoco-implicit-step-route-smoke-",
        schemas={
            "reservation": "sporespore_qsdk_r24d34_implicit_step_route_smoke_attempt_reservation_v1",
            "invalid": "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_invalid_v1",
            "completion": "sporespore_qsdk_r24d34_implicit_step_route_smoke_supervisor_completion_v1",
            "lock": "sporespore_locomotion_operation_lock_receipt_v1",
        },
        qualification_receipt_raw_sha256=closure["qualification"]["receipt_raw_sha256"],
    )
    physical = closure["physical_attempt"]
    exact(physical["official_physical_attempt_count_for_source"], 1, "PHYSICAL_ATTEMPT_COUNT")
    traceback = values["invalid"]["traceback"]
    for marker in ("candidate = _run_arm(", "world.step_native(", "advance_implicitfast_after_control_v3(", "QSDK_R24D34_PREINTEGRATION_ACTUATOR_SHAPE_MISMATCH"):
        require(marker in traceback, f"TRACEBACK_MARKER:{marker}")
    exact((Path(physical["evidence_root"]) / "worker_stderr.log").stat().st_size, 0, "STDERR_EMPTY")

    markers = (
        "mujoco.mj_fwdActuation(model, data)",
        "actuator_moment = np.asarray(data.actuator_moment, dtype=np.float64).copy()",
        '"QSDK_R24D34_PREINTEGRATION_ACTUATOR_SHAPE_MISMATCH"',
        "mujoco.mj_implicit(model, data)",
    )
    require(all(marker in runtime for marker in markers), "SOURCE_MARKER")
    require([runtime.index(marker) for marker in markers] == sorted(runtime.index(marker) for marker in markers), "SOURCE_INTEGRATION_ORDER")
    require(runtime.index("candidate = _run_arm(") < runtime.index("matched_zero = _run_arm("), "SOURCE_ARM_ORDER")

    exact_bools(physical, ("candidate_arm_entered_by_traceback", "native_world_was_constructed_by_source_order", "first_candidate_native_substep_entered", "preintegration_forward_stages_completed_by_source_order", "invalid_or_incomplete_retained"), True, "PHYSICAL_OBSERVED")
    exact_bools(physical, ("matched_zero_arm_entered_by_source_order", "native_integrator_called_by_source_order", "complete_native_substep_observed", "current_observation_published", "native_receipt_published", "collector_invoked", "portable_evaluator_invoked", "durable_complete_result_published", "valid_behavior_result_observed", "exact_execution_counts_published"), False, "PHYSICAL_LIMIT")
    for key in ("model_construction_count", "world_attempt_count", "world_build_count", "outer_step_count", "solver_step_count", "physics_state_modified"):
        exact(physical[key], None, f"UNPUBLISHED_{key.upper()}")

    failure = closure["observed_failure"]
    exact(failure["class"], "sparse_actuator_moment_misread_as_dense_matrix", "FAILURE_CLASS")
    exact_bools(failure, ("integration_failure_established",), True, "FAILURE")
    exact_bools(failure, ("physics_behavior_failure_established", "threshold_failure_established", "selector_failure_established", "evaluator_failure_established", "controller_failure_established", "model_failure_established", "runtime_sparse_value_count_published", "runtime_dense_shape_published", "native_integration_advanced", "recovery_progression_observed", "result_interpretation_rewritten"), False, "FAILURE_LIMIT")
    storage = failure["mujoco_3_11_storage_contract"]
    exact((storage["actuator_moment_storage"], storage["nonzero_count"], storage["public_dense_expansion_function"]), ("sparse_flat_nJmom_values", "MjModel.nJmom", "mju_sparse2dense"), "MUJOCO_STORAGE")

    postmortem = closure["zero_world_gate_postmortem"]
    exact_bools(postmortem, ("gate_passed_for_declared_controls", "physical_opening_conditions_were_satisfied", "physical_opening_was_contract_compliant", "smallest_route_smoke_fulfilled_fail_closed_role"), True, "POSTMORTEM")
    exact_bools(postmortem, ("gate_result_rewritten", "field_presence_preflight_was_adequate", "sparse_representation_control_was_present", "full_seeded_ghost_required", "additional_full_physical_canary_required"), False, "POSTMORTEM_LIMIT")
    exact(len(postmortem["required_successor_controls"]), 8, "SUCCESSOR_CONTROL_COUNT")

    decision = closure["decision"]
    exact((decision["result"], decision["sdk1_completed_steps"], decision["sdk1_total_steps"], decision["full_program_completed_steps"], decision["full_program_total_steps"]), ("consumed_invalid_incomplete_and_retained", 11, 20, 11, 25), "DECISION")
    exact_bools(decision, ("official_zero_world_qualification_passed", "all_ten_declared_zero_world_controls_passed"), True, "DECISION_POSITIVE")
    exact_bools(decision, ("r24d34_may_be_rerun", "same_source_may_be_reused_for_another_r24d34_result", "valid_physical_route_result_observed", "native_implicit_step_completed", "v2_v3_physical_trace_observed", "energy_residual_acceptance_observed", "recovery_to_stance_handoff_observed", "controller_physical_viability_proven", "prone_to_standing_claimed", "sdk1_milestone_advanced"), False, "DECISION_LIMIT")

    next_boundary = closure["next_boundary"]
    exact((next_boundary["gate_id"], next_boundary["maximum_outer_steps_per_smoke_arm"], next_boundary["paired_arm_count"]), ("QSDK-R24D35", 2, 2), "NEXT")
    exact_bools(next_boundary, ("new_physical_identity_required", "distinct_clean_pushed_source_freeze_required", "complete_zero_world_qualification_required_before_physics", "actuator_moment_representation_adapter_changed", "held_out_cells_remain_sealed"), True, "NEXT")
    exact_bools(next_boundary, ("full_seeded_ghost_required", "r24d34_may_rerun", "controller_changed", "native_physics_changed", "morphology_changed", "initializer_changed", "observer_formula_changed", "behavior_thresholds_changed", "margins_changed", "selector_changed", "cell_changed", "seed_changed", "horizon_changed", "portable_evaluator_changed"), False, "NEXT_LIMIT")

    positive_claims = {"official_zero_world_qualification_passed", "declared_r24d34_zero_world_controls_passed", "physical_question_opened", "invalid_incomplete_result_retained", "sparse_representation_integration_failure_established"}
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")
    require("QSDK_R24D34_MUJOCO_IMPLICIT_STEP_ROUTE_WIRING_SOURCE_PASS" in (Path(closure["qualification"]["evidence_root"]) / "source_audit.log").read_text(encoding="utf-8"), "SOURCE_AUDIT_MARKER")
    print("QSDK_R24D34_MUJOCO_IMPLICIT_STEP_ROUTE_WIRING_INVALID_CLOSURE_PASS qualification=10/10 physical=consumed_invalid cause=sparse_actuator_moment native_steps_complete=0 exact_counts=unpublished heldout=0 sdk1=11/20 next=QSDK-R24D35")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D34_MUJOCO_IMPLICIT_STEP_ROUTE_WIRING_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
