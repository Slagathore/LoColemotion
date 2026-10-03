"""Audit the zero-world R24D32 implicit-step retained-trace diagnosis."""

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
    exact_bools,
    git,
    load,
    loads,
    require,
    sha256,
    verify_retained_commit,
    verify_source_binding,
)
from sdk.conformance.retained_energy_trace_diagnosis import (  # noqa: E402
    RetainedEnergyTraceError,
    endpoint_centered_actuator_projection_v1,
)


REPORT_PATH = ROOT / "sdk/recovery/r24d32_implicit_step_energy_diagnosis_v1.json"
SOURCE = "326dd1d22b40b675f12372089d77d7724dc20a9a"
CLOSURE_COMMIT = "7332992980d58ea1cc5e5dfb345e19fe4d1ad224"


def _mutations_rejected(arm: dict[str, Any]) -> None:
    cases: list[tuple[str, Any]] = []
    missing_impulse = deepcopy(arm)
    missing_impulse["native_receipts"][0]["application"][
        "ordered_signed_applied_impulse_nms"
    ].pop()
    cases.append(("RETAINED_ENERGY_IMPULSE_COUNT:0", missing_impulse))
    wrong_joint_order = deepcopy(arm)
    wrong_joint_order["observations"][1]["state"]["ordered_joint_observations"].reverse()
    cases.append(("RETAINED_ENERGY_JOINT_ORDER:1", wrong_joint_order))
    broken_identity = deepcopy(arm)
    broken_identity["observations"][0]["energy_balance"][
        "cumulative_applied_actuator_work_j"
    ] += 1.0
    cases.append(("RETAINED_ENERGY_ACTUATOR_IDENTITY:0", broken_identity))
    for expected, value in cases:
        caught: RetainedEnergyTraceError | None = None
        try:
            endpoint_centered_actuator_projection_v1(value)
        except RetainedEnergyTraceError as error:
            caught = error
        exact(str(caught), expected, f"MUTATION:{expected}")


def audit() -> None:
    report = load(REPORT_PATH)
    exact(
        report["schema_version"],
        "sporespore_qsdk_r24d32_implicit_step_energy_diagnosis_v1",
        "SCHEMA",
    )
    exact(
        report["analysis_class"],
        "repeatable_zero_world_retained_trace_development_diagnosis",
        "ANALYSIS_CLASS",
    )
    exact(report["authored_parent_commit"], CLOSURE_COMMIT, "AUTHORED_PARENT")
    exact(report["physical_question_declared"], False, "PHYSICAL_QUESTION")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(report[key], 0, f"COUNT_{key.upper()}")

    predecessor = report["predecessor"]
    exact(predecessor["gate_id"], "QSDK-R24D32", "PREDECESSOR_GATE")
    exact(predecessor["source_commit"], SOURCE, "PREDECESSOR_SOURCE")
    exact(predecessor["closure_commit"], CLOSURE_COMMIT, "PREDECESSOR_CLOSURE_COMMIT")
    verify_retained_commit(ROOT, CLOSURE_COMMIT, SOURCE)
    closure_path = ROOT / predecessor["closure_path"]
    exact(sha256(closure_path.read_bytes()), predecessor["closure_raw_sha256"], "CLOSURE_HASH")
    exact_bools(
        predecessor,
        (
            "same_identity_rerun_permitted",
            "same_identity_requalification_permitted",
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
        ),
        False,
        "PREDECESSOR",
    )

    bindings = {
        str(value["path"]): verify_source_binding(ROOT, SOURCE, value)
        for value in report["frozen_source_bindings"]
    }
    exact(len(bindings), 4, "SOURCE_BINDING_COUNT")
    runtime_path = "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
    model_path = "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py"
    profile_path = "sdk/adapters/mujoco/sporespore_mujoco_adapter/actuator_cap_profile.py"
    runtime = bindings[runtime_path].decode("utf-8")
    model = bindings[model_path].decode("utf-8")
    profile = bindings[profile_path].decode("utf-8")
    step1 = runtime.index("mujoco.mj_step1(self.model, self.data)")
    pre_velocity = runtime.index("pre_step_qvel =", step1)
    step2 = runtime.index("mujoco.mj_step2(self.model, self.data)", pre_velocity)
    force_read = runtime.index("forces = np.asarray(self.data.actuator_force", step2)
    work_call = runtime.index("energy_work = measure_native_energy_work_v2(", force_read)
    require(step1 < pre_velocity < step2 < force_read < work_call, "FROZEN_STEP_ORDER")
    require(
        "generalized_velocity=pre_step_qvel" in runtime[work_call : work_call + 1200]
        and "np.dot(qfrc_actuator, qvel) * dt" in runtime
        and "np.dot(qfrc_constraint, qvel) * dt" in runtime,
        "FROZEN_LEFT_ENDPOINT_LEDGER",
    )
    require(
        '"integrator": "implicitfast"' in model
        and '"damping": "0"' in model
        and '"velocity"' in model
        and "VELOCITY_GAIN_NM_S_PER_RAD = 10.0" in profile,
        "FROZEN_MODEL_IDENTITY",
    )
    exact(
        [value["supports"] for value in report["primary_source_basis"]],
        [
            "mj_step1_control_assignment_mj_step2_and_integration_stage_order",
            "implicit_and_implicitfast_use_velocity_derivatives_of_smooth_forces_including_actuation",
            "native_force_and_energy_field_semantics",
        ],
        "PRIMARY_SOURCE_SCOPE",
    )

    evidence = report["retained_evidence"]
    full_path = Path(evidence["evidence_root"]) / evidence["full_result_path"]
    raw = full_path.read_bytes()
    exact(len(raw), evidence["full_result_byte_length"], "TRACE_LENGTH")
    exact(sha256(raw), evidence["full_result_raw_sha256"], "TRACE_HASH")
    result = loads(raw)["result"]
    candidate = result["candidate"]
    matched_zero = result["matched_zero_command"]
    exact(len(candidate["observations"]), evidence["candidate_outer_step_count"], "CANDIDATE_COUNT")
    exact(len(matched_zero["observations"]), evidence["matched_zero_outer_step_count"], "ZERO_COUNT")
    active = [
        index
        for index, value in enumerate(candidate["native_receipts"])
        if value["application"]["no_actuation_requested"] is False
    ]
    exact(
        (len(active), active[0], active[-1]),
        (
            evidence["candidate_active_application_count"],
            evidence["candidate_first_active_outer_index_zero_based"],
            evidence["candidate_last_active_outer_index_zero_based"],
        ),
        "ACTIVE_APPLICATIONS",
    )
    physical_equal = [
        candidate["observations"][index]["state"] == matched_zero["observations"][index]["state"]
        and candidate["observations"][index]["center_of_mass"]
        == matched_zero["observations"][index]["center_of_mass"]
        and candidate["observations"][index]["energy_balance"]
        == matched_zero["observations"][index]["energy_balance"]
        for index in range(min(len(candidate["observations"]), len(matched_zero["observations"])))
    ]
    divergence = next(index for index, value in enumerate(physical_equal) if not value)
    exact(divergence, evidence["paired_physical_state_and_energy_equal_prefix_outer_step_count"], "EQUAL_PREFIX")
    exact(
        divergence,
        evidence["first_candidate_matched_zero_physical_state_or_energy_divergence_outer_index_zero_based"],
        "FIRST_DIVERGENCE",
    )

    candidate_projection = endpoint_centered_actuator_projection_v1(candidate)
    zero_projection = endpoint_centered_actuator_projection_v1(matched_zero)
    declared = report["endpoint_centered_actuator_projection"]
    for key, expected in declared["candidate"].items():
        if key in candidate_projection:
            exact(candidate_projection[key], expected, f"CANDIDATE_PROJECTION_{key.upper()}")
    exact(
        declared["candidate"]["minimum_raised_original_absolute_residual_j"]
        - declared["candidate"]["minimum_raised_projected_absolute_residual_j"],
        declared["candidate"]["minimum_raised_residual_reduction_j"],
        "CANDIDATE_RAISED_REDUCTION",
    )
    exact(
        declared["candidate"]["minimum_raised_residual_reduction_j"]
        / declared["candidate"]["minimum_raised_original_absolute_residual_j"],
        declared["candidate"]["minimum_raised_residual_reduction_fraction"],
        "CANDIDATE_RAISED_REDUCTION_FRACTION",
    )
    exact(
        declared["candidate"]["additional_projected_actuator_work_j"]
        / declared["candidate"]["terminal_original_signed_residual_j"],
        declared["candidate"]["terminal_residual_reduction_fraction"],
        "CANDIDATE_TERMINAL_REDUCTION_FRACTION",
    )
    exact(
        candidate_projection["phase_contributions"],
        declared["candidate_phase_contributions"],
        "CANDIDATE_PHASES",
    )
    for key, expected in declared["matched_zero"].items():
        if key in zero_projection:
            exact(zero_projection[key], expected, f"ZERO_PROJECTION_{key.upper()}")
    exact(
        candidate_projection["minimum_raised_projected_absolute_residual_j"]
        - declared["unchanged_maximum_absolute_residual_j"],
        declared["projected_minimum_raised_excess_above_unchanged_limit_j"],
        "PROJECTED_EXCESS",
    )
    require(
        candidate_projection["minimum_raised_projected_absolute_residual_j"]
        > declared["unchanged_maximum_absolute_residual_j"],
        "PROJECTION_STILL_NEGATIVE",
    )
    _mutations_rejected(
        {
            **candidate,
            "observations": deepcopy(candidate["observations"][:2]),
            "native_receipts": deepcopy(candidate["native_receipts"][:2]),
            "portable_step_receipts": deepcopy(candidate["portable_step_receipts"][:2]),
        }
    )

    diagnosis = report["diagnosis"]
    exact_bools(
        diagnosis,
        (
            "pre_integration_continuous_power_was_mislabeled_as_complete_discrete_actuator_work",
            "implicitfast_velocity_derivative_term_is_absent_from_the_retained_v2_work_ledger",
            "retained_projection_materially_localizes_the_candidate_residual_to_force_velocity_staging",
        ),
        True,
        "DIAGNOSIS_POSITIVE",
    )
    exact_bools(
        diagnosis,
        (
            "retained_projection_alone_fully_establishes_the_correct_per_native_substep_work_formula",
            "retained_projection_alone_establishes_the_complete_remaining_residual_cause",
            "missing_independent_physical_force_term_established",
            "controller_fault_established",
            "constraint_work_measurement_adequacy_established",
            "matched_zero_effective_implicit_actuator_work_established_zero",
            "numerical_integration_error_fully_quantified",
            "threshold_inadequacy_established",
            "threshold_or_margin_changed",
            "r24d32_result_or_interpretation_changed",
        ),
        False,
        "DIAGNOSIS_LIMIT",
    )
    next_boundary = report["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D33", "NEXT_GATE")
    exact(
        next_boundary["status"],
        "eligible_for_distinct_zero_world_implicit_step_energy_measurement_declaration_physics_still_blocked",
        "NEXT_STATUS",
    )
    exact_bools(
        next_boundary,
        (
            "physical_question_declared",
            "same_identity_rerun_permitted",
            "new_threshold_or_margin_selected",
            "next_physical_execution_authorized",
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "NEXT",
    )
    claim = report["claim_boundary"]
    exact(claim["retained_trace_and_frozen_source_diagnosed"], True, "CLAIM_DIAGNOSED")
    exact(claim["specific_successor_measurement_boundary_identified"], True, "CLAIM_BOUNDARY")
    for key, value in claim.items():
        if key not in {
            "retained_trace_and_frozen_source_diagnosed",
            "specific_successor_measurement_boundary_identified",
        }:
            exact(value, False, f"CLAIM_{key.upper()}")
    exact(
        git(ROOT, "merge-base", "--is-ancestor", CLOSURE_COMMIT, "HEAD"),
        "",
        "DIAGNOSIS_PARENT_ANCESTOR",
    )
    print(
        "QSDK_R24D32_IMPLICIT_STEP_ENERGY_DIAGNOSIS_PASS "
        "worlds=0 solver_steps=0 active_start=12 additional_centered_work_j=0.7473909068066504 "
        "terminal_projected_residual_j=0.3240640021946284 "
        "minimum_raised_projected_residual_j=0.2796674345822936 limit_j=0.25 "
        "r24d32_rewritten=false next=QSDK-R24D33:zero_world_design"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        RetainedEnergyTraceError,
        OSError,
        KeyError,
        IndexError,
        StopIteration,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(f"QSDK_R24D32_IMPLICIT_STEP_ENERGY_DIAGNOSIS_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
