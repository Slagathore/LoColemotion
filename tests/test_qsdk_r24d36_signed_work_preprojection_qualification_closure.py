"""Compact audit of the retained zero-world QSDK-R24D36 closure."""

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


CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/r24d36_signed_work_preprojection_qualification_closure_v1.json"
)
SOURCE = "7d1e357c8458d503985cafd31cfa6c0797bf350d"
GATE = "QSDK-R24D36"
SCHEMA = "sporespore_qsdk_r24d36_signed_work_preprojection_qualification_closure_v1"
STATUS = "closed_complete_zero_world_signed_work_preprojection_qualified_no_physical_question"


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (SCHEMA, GATE, STATUS, "development"),
        "CLOSURE_IDENTITY",
    )
    exact_bools(
        closure,
        (
            "physical_question_declared",
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "DECLARATION",
    )

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(
        (source["commit"], git(ROOT, "show", "-s", "--format=%T", SOURCE)),
        (SOURCE, source["tree"]),
        "SOURCE_IDENTITY",
    )
    for binding_name in (
        "projection_primitive",
        "runtime",
        "worker",
        "source_audit",
    ):
        verify_source_binding(ROOT, SOURCE, source[binding_name])
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    exact(
        (
            contract["gate_id"],
            contract["physical_question_declared"],
            contract["qualification_authority"]["qualification_result_pending"],
        ),
        (GATE, False, True),
        "CONTRACT_IDENTITY",
    )

    predecessor = closure["predecessor"]
    predecessor_path = ROOT / predecessor["closure_path"]
    predecessor_closure = load(predecessor_path)
    exact(
        sha256(predecessor_path.read_bytes()),
        predecessor["closure_raw_sha256"],
        "PREDECESSOR_HASH",
    )
    exact(
        predecessor_closure["closure_status"],
        predecessor["historical_result"],
        "PREDECESSOR_RESULT",
    )
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
    semantics = closure["qualified_semantics_predecessor"]
    semantics_path = ROOT / semantics["closure_path"]
    exact(
        sha256(semantics_path.read_bytes()),
        semantics["closure_raw_sha256"],
        "SEMANTICS_HASH",
    )
    exact(
        (
            semantics["zero_world_controls_passed"],
            semantics["joint_damping"],
            semantics["fluid_force"],
            semantics["adhesion_force"],
            semantics["nonzero_implicit_passive_force_supported"],
        ),
        (12, 0.0, 0.0, 0.0, False),
        "SEMANTICS_BOUNDARY",
    )

    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema=(
            "sporespore_qsdk_r24d36_signed_work_preprojection_zero_world_attempt_v1"
        ),
        receipt_schema=(
            "sporespore_qsdk_r24d36_signed_work_preprojection_zero_world_receipt_v1"
        ),
        qualification_directory_prefix="qsdk-r24d36-qualification-",
        contract_inventory=contract["source_inventory"],
    )
    exact(receipt["contract_path"], source["contract"]["path"], "RECEIPT_CONTRACT")
    exact(
        receipt["contract_raw_sha256"],
        source["contract"]["raw_sha256"],
        "RECEIPT_CONTRACT_HASH",
    )
    exact(
        (preflight["negative_control_count"], preflight["negative_controls_passed"]),
        (9, 9),
        "PREFLIGHT_COUNTS",
    )
    controls = preflight["signed_work_preprojection_controls"]
    exact(
        set(controls),
        set(contract["complete_zero_world_gate"]["required_controls"]),
        "PREFLIGHT_CONTROL_SET",
    )
    require(all(controls.values()), "PREFLIGHT_CONTROL_FAILURE")
    details = preflight["signed_work_preprojection_control_details"]
    exact(
        (
            details["projection_profile_id"],
            details["primitive_control_count"],
            details["signed_constraint_fixture_sum_j"],
            details["historical_positive_constraint_fixture_derived_dissipation_j"],
        ),
        ("mujoco_signed_work_portable_v1_preprojection_v1", 6, -0.25, -0.25),
        "PREFLIGHT_DETAILS",
    )

    decision = closure["decision"]
    exact_bools(
        decision,
        (
            "exact_zero_nonactuator_tuple_supported",
            "both_constraint_work_signs_retained",
            "nonzero_constraint_work_refused",
            "nonzero_unqualified_passive_work_refused",
            "historical_v2_and_portable_v3_receipts_retained",
            "typed_refusal_bound_before_portable_observation",
            "r24d36_closed_without_physics",
        ),
        True,
        "DECISION_POSITIVE",
    )
    exact_bools(
        decision,
        (
            "mechanical_energy_change_used_as_input",
            "energy_balance_residual_used_as_input",
            "absolute_value_applied",
            "negative_value_clamped",
            "post_outcome_relabelling_applied",
            "controller_changed",
            "native_physics_changed",
            "morphology_changed",
            "initializer_changed",
            "observer_values_changed",
            "portable_energy_ledger_v1_schema_changed",
            "portable_evaluator_changed",
            "r24d36_physical_execution_permitted",
        ),
        False,
        "DECISION_NEGATIVE",
    )
    exact(
        (
            decision["new_behavior_threshold_count"],
            decision["new_empirical_threshold_count"],
            decision["new_margin_count"],
            decision["physical_cohort_count"],
            decision["held_out_cohort_count"],
            decision["population_claim_count"],
        ),
        (0, 0, 0, 0, 0, 0),
        "DECISION_LIMITS",
    )
    exact(
        (
            closure["sdk_status"]["sdk1_completed_steps"],
            closure["sdk_status"]["full_program_completed_steps"],
        ),
        (11, 11),
        "SDK_SCORES",
    )

    next_boundary = closure["next_boundary"]
    exact(
        (next_boundary["gate_id"], next_boundary["maximum_physical_steps_authorized"]),
        ("QSDK-R24D37", 0),
        "NEXT_BOUNDARY",
    )
    exact_bools(
        next_boundary,
        (
            "physical_question_declared",
            "behavior_question_declared",
            "full_seeded_ghost_required",
            "additional_physical_canary_required",
            "r24d37_physical_execution_authorized",
            "r24d36_may_be_requalified",
            "r24d35_may_be_rerun",
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "NEXT_BOUNDARY",
    )
    positive_claims = {
        "official_zero_world_qualification_passed",
        "signed_work_preprojection_qualified",
        "typed_portable_v1_refusal_qualified",
        "exact_zero_portable_v1_projection_qualified",
        "both_constraint_work_signs_retained",
        "historical_v2_and_portable_v3_receipts_retained",
        "forbidden_value_transformations_absent",
        "r24d36_closed_without_physics",
    }
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")

    audit_log = (
        Path(closure["qualification"]["evidence_root"]) / "source_audit.log"
    ).read_text(encoding="utf-8")
    require(
        "QSDK_R24D36_SIGNED_WORK_PREPROJECTION_SOURCE_PASS" in audit_log,
        "SOURCE_AUDIT_MARKER",
    )
    print(
        "QSDK_R24D36_SIGNED_WORK_PREPROJECTION_QUALIFICATION_CLOSURE_PASS "
        "sources=22 controls=9/9 primitives=6/6 models=0 worlds=0 "
        "solver_steps=0 physical=false sdk1=11/20 next=QSDK-R24D37"
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
            "QSDK_R24D36_SIGNED_WORK_PREPROJECTION_QUALIFICATION_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
