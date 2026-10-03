"""Compact audit of the retained zero-world QSDK-R24D33 closure."""

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
    sha256,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)


CLOSURE_PATH = ROOT / "sdk/recovery/r24d33_mujoco_implicit_step_energy_measurement_qualification_closure_v1.json"
SOURCE = "4e7a94daebec600621cfeb6a1eaee54f43c8a196"
GATE = "QSDK-R24D33"
SCHEMA = "sporespore_qsdk_r24d33_mujoco_implicit_step_energy_measurement_qualification_closure_v1"
STATUS = "closed_complete_zero_world_implicit_step_energy_measurement_qualified_no_physical_question"


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        (closure["schema_version"], closure["gate_id"], closure["closure_status"], closure["question_class"]),
        (SCHEMA, GATE, STATUS, "development"),
        "CLOSURE_IDENTITY",
    )
    exact_bools(closure, ("physical_question_declared", "superiority_question_declared", "equivalence_or_non_inferiority_question_declared", "population_inference_declared"), False, "DECLARATION")

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact((source["commit"], git(ROOT, "show", "-s", "--format=%T", SOURCE)), (SOURCE, source["tree"]), "SOURCE_IDENTITY")
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    exact(
        (contract["gate_id"], contract["physical_question_declared"], contract["qualification_and_closure"]["qualification_result_pending"]),
        (GATE, False, True),
        "CONTRACT_IDENTITY",
    )

    predecessor = closure["predecessor"]
    predecessor_closure = load(ROOT / predecessor["closure_path"])
    diagnosis = load(ROOT / predecessor["diagnosis_path"])
    exact(sha256((ROOT / predecessor["closure_path"]).read_bytes()), predecessor["closure_raw_sha256"], "PREDECESSOR_HASH")
    exact(sha256((ROOT / predecessor["diagnosis_path"]).read_bytes()), predecessor["diagnosis_raw_sha256"], "DIAGNOSIS_HASH")
    exact(predecessor_closure["closure_status"], predecessor["historical_result"], "PREDECESSOR_RESULT")
    exact(diagnosis["next_boundary"]["gate_id"], GATE, "DIAGNOSIS_NEXT")
    exact_bools(
        predecessor,
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

    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d33_mujoco_implicit_step_energy_measurement_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d33_mujoco_implicit_step_energy_measurement_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d33-qualification-",
        contract_inventory=contract["source_inventory"],
    )
    exact(receipt["contract_path"], source["contract"]["path"], "RECEIPT_CONTRACT")
    exact(receipt["contract_raw_sha256"], source["contract"]["raw_sha256"], "RECEIPT_CONTRACT_HASH")
    exact((preflight["negative_control_count"], preflight["negative_controls_passed"]), (12, 12), "PREFLIGHT_COUNTS")
    controls = preflight["implicit_step_energy_controls"]
    exact(set(controls), set(contract["complete_zero_world_gate"]["required_controls"]), "PREFLIGHT_CONTROL_SET")
    require(all(controls.values()), "PREFLIGHT_CONTROL_FAILURE")
    details = preflight["implicit_step_energy_control_details"]
    exact(details["profile_id"], "mujoco_direct_velocity_servo_implicit_step_work_v3", "DETAIL_PROFILE")
    exact(details["r24d32_closure_raw_sha256"], predecessor["closure_raw_sha256"], "DETAIL_CLOSURE")
    exact(details["r24d32_diagnosis_raw_sha256"], predecessor["diagnosis_raw_sha256"], "DETAIL_DIAGNOSIS")
    exact((details["nominal_effective_work_j"], details["hidden_zero_pre_force_effective_work_j"], details["hidden_zero_pre_force_constraint_work_j"], details["unchanged_maximum_absolute_residual_j"]), (0.11111111111111112, -0.1422222222222222, 0.4266666666666667, 0.25), "DETAIL_VALUES")

    decision = closure["decision"]
    exact_bools(
        decision,
        (
            "mujoco_3_11_source_semantics_bound",
            "direct_velocity_servo_effective_force_mapping_qualified",
            "force_limit_derivative_branch_qualified",
            "actuator_moment_work_crosscheck_qualified",
            "midpoint_constraint_work_qualified",
            "zero_reported_pre_force_effective_work_control_passed",
            "unqualified_implicit_passive_force_refusal_qualified",
            "measurement_has_no_energy_residual_or_threshold_input",
            "v2_left_endpoint_terms_retained",
            "reusable_measurement_primitive_qualified",
            "r24d33_closed_without_physics",
        ),
        True,
        "DECISION",
    )
    exact_bools(
        decision,
        (
            "controller_changed",
            "native_physics_changed",
            "morphology_changed",
            "portable_phase_machine_changed",
            "portable_pose_classifier_changed",
            "portable_evaluator_changed",
            "measurement_wired_into_native_route",
            "physical_measurement_adequacy_established",
            "r24d33_physical_execution_permitted",
        ),
        False,
        "DECISION",
    )
    exact((decision["new_behavior_threshold_count"], decision["new_empirical_threshold_count"], decision["new_margin_count"]), (0, 0, 0), "DECISION_LIMITS")
    exact((closure["sdk_status"]["sdk1_completed_steps"], closure["sdk_status"]["full_program_completed_steps"]), (11, 11), "SDK_SCORES")

    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D34", "NEXT_GATE")
    exact(next_boundary["status"], "eligible_for_distinct_native_route_wiring_declaration_physics_still_blocked", "NEXT_STATUS")
    exact_bools(next_boundary, ("r24d34_physical_execution_authorized", "r24d33_may_be_requalified", "r24d32_may_be_rerun"), False, "NEXT")
    positive_claims = {
        "official_zero_world_qualification_passed",
        "mujoco_implicitfast_source_mapping_bound",
        "reusable_implicit_step_measurement_qualified",
        "zero_pre_force_effective_work_control_passed",
        "historical_v2_terms_retained",
    }
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")

    audit_log = (Path(closure["qualification"]["evidence_root"]) / "source_audit.log").read_text(encoding="utf-8")
    require("QSDK_R24D33_MUJOCO_IMPLICIT_STEP_ENERGY_MEASUREMENT_SOURCE_PASS" in audit_log, "SOURCE_AUDIT_MARKER")
    print("QSDK_R24D33_MUJOCO_IMPLICIT_STEP_ENERGY_QUALIFICATION_CLOSURE_PASS sources=104 controls=12/12 models=0 worlds=0 solver_steps=0 physical=false sdk1=11/20 next=QSDK-R24D34")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D33_MUJOCO_IMPLICIT_STEP_ENERGY_QUALIFICATION_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
