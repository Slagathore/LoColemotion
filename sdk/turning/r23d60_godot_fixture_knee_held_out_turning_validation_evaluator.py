"""Retained-trace evaluator for the QSDK-R23D60 finite decision.

R23D60 reuses the already accepted fixed-horizon, task-origin, full-precision
trace, actuator-application, cap-binding, common physical-gate, and R23D31
cycle-integrated directional-response algorithms. It changes only the frozen
profile, reserved seed, and prospective three-arm matrix. No superiority,
equivalence, repeatability-rate, robustness, or population test is performed.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d58_godot_cap_source_factorial_evaluator as accepted
import r23d31_cycle_integrated_measurement as measurement
import r23d60_godot_fixture_knee_held_out_turning_validation as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d60_godot_fixture_knee_held_out_turning_validation_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    ROOT / "r23d60_godot_fixture_knee_held_out_turning_validation_implementation_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d48_trace.ps1"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
REPORT_SCHEMA = "sporespore_qsdk_r23d60_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d60_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d60_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d60_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = (
    "sporespore_qsdk_r23d60_complete_held_out_turning_evaluation_v1"
)
FALSE_CLAIMS = {
    "r23d60_held_out_turning_positive": False,
    "godot_jolt_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "q_sdk_r23_satisfied": False,
    "release_authority": False,
    "physical_acceptance_authority": False,
}


class R23D60EvaluationError(RuntimeError):
    """The declaration, retained evidence, or three-arm result is invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D60EvaluationError(code)


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D60EvaluationError(
            f"R23D60_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    try:
        design.validate_declaration(value)
    except design.DeclarationError as error:
        raise R23D60EvaluationError(f"R23D60_DECLARATION_INVALID:{error}") from error
    return value


def load_implementation() -> dict[str, Any]:
    try:
        value = json.loads(IMPLEMENTATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D60EvaluationError(
            f"R23D60_IMPLEMENTATION_UNREADABLE:{type(error).__name__}"
        ) from error
    worker = value.get("worker", {})
    evaluator = value.get("evaluator", {})
    claims = value.get("claims", {})
    dependency = value.get("dependency_closure", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d60_godot_fixture_knee_held_out_turning_validation_implementation_v1"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("question_class") != design.QUESTION_CLASS
        or value.get("physical_campaign_opened") is not False
        or value.get("declared_world_count") != 3
        or worker.get("path")
        != "tests/test_sdk_qsdk_r23d60_godot_jolt_physical_worker.gd"
        or evaluator.get("path")
        != "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_evaluator.py"
        or evaluator.get("all_three_cells_required_in_frozen_order") is not True
        or evaluator.get("complete_execution_valid_three_arm_matrix_required")
        is not True
        or evaluator.get("turning_gate_invoked") is not True
        or evaluator.get("raw_and_reference_conditioned_directional_floors_required")
        is not True
        or evaluator.get("superiority_or_equivalence_evaluator_invoked") is not False
        or dependency.get("policy_id")
        != "r23d60_declared_roots_recursive_local_language_closure_v1"
        or dependency.get("expected_transitive_path_set_required") is not True
        or claims.get("implementation_complete") is not True
        or claims.get("complete_zero_world_gate_passed") is not True
        or claims.get("physical_world_opened") is not False
        or claims.get("godot_jolt_turning") is not False
        or claims.get("prone_to_standing") is not False
        or claims.get("release_authority") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D60EvaluationError("R23D60_IMPLEMENTATION_IDENTITY_INVALID")
    return value


def _bind_accepted_core() -> None:
    """Rebind the accepted algorithms to the prospective R23D60 identities."""

    # The accepted R58 implementation names its finite profile surface in the
    # plural. R60 freezes exactly one of those profiles, so provide explicit
    # runtime aliases without mutating either immutable declaration source.
    design.CAP_SOURCE_PORTABLE_COMPILED = (
        design.reservation.CAP_SOURCE_PORTABLE_COMPILED
    )
    design.CAP_SOURCE_FIXTURE_PREBINDING = (
        design.reservation.CAP_SOURCE_FIXTURE_PREBINDING
    )
    design.ORDERED_PROFILE_IDS = (design.PROFILE_ID,)
    design.PROFILE_DEFINITIONS = {
        design.PROFILE_ID: copy.deepcopy(design.PROFILE_DEFINITION)
    }
    design.PROFILE_FIXTURE_HIP_FIXTURE_KNEE = (
        design.reservation.PROFILE_FIXTURE_HIP_FIXTURE_KNEE
    )

    accepted.design = design
    accepted.DECLARATION_PATH = DECLARATION_PATH
    accepted.PUBLISHER_PATH = PUBLISHER_PATH
    accepted.PUBLISHER_MARKER = PUBLISHER_MARKER
    accepted.REPORT_SCHEMA = REPORT_SCHEMA
    accepted.FAILURE_SCHEMA = FAILURE_SCHEMA
    accepted.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
    accepted.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
    accepted.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
    accepted.FALSE_CLAIMS = FALSE_CLAIMS
    accepted.load_declaration = load_declaration

    inherited = accepted.inherited
    inherited.design = design
    inherited.DECLARATION_PATH = DECLARATION_PATH
    inherited.PUBLISHER_PATH = PUBLISHER_PATH
    inherited.PUBLISHER_MARKER = PUBLISHER_MARKER
    inherited.REPORT_SCHEMA = REPORT_SCHEMA
    inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
    inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
    inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
    inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
    inherited.FALSE_CLAIMS = FALSE_CLAIMS
    inherited.load_declaration = load_declaration
    inherited.validate_trace = accepted.validate_trace


_bind_accepted_core()


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    _bind_accepted_core()
    summary = accepted.validate_trace(cell_id, rows)
    summary["schema_version"] = TRACE_SUMMARY_SCHEMA
    summary["campaign_seed"] = design.cell_by_id(cell_id).campaign_seed
    return summary


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    _bind_accepted_core()
    value = accepted.retain_trace(**kwargs)
    value["schema_version"] = TRACE_RETENTION_SCHEMA
    value["campaign_seed"] = design.cell_by_id(str(value["cell_id"])).campaign_seed
    return value


def _entry_identity_failures(entry: Any, item: design.Cell) -> list[str]:
    if not isinstance(entry, Mapping):
        return ["R23D60_ENTRY_TYPE"]
    failures: list[str] = []
    if entry.get("campaign_seed") != item.campaign_seed:
        failures.append("R23D60_CAMPAIGN_SEED_IDENTITY")
    if entry.get("profile_id") != item.profile_id:
        failures.append("R23D60_PROFILE_IDENTITY")
    if entry.get("hip_cap_source") != item.hip_cap_source:
        failures.append("R23D60_HIP_CAP_SOURCE_IDENTITY")
    if entry.get("knee_cap_source") != item.knee_cap_source:
        failures.append("R23D60_KNEE_CAP_SOURCE_IDENTITY")
    if entry.get("arm_id") != item.arm_id:
        failures.append("R23D60_ARM_IDENTITY")
    if entry.get("turn_heading_offset_rad") != item.turn_heading_offset_rad:
        failures.append("R23D60_HEADING_OFFSET_IDENTITY")
    return failures


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    _bind_accepted_core()
    evaluation, rows = accepted.evaluate_entry(
        entry,
        item,
        expected_source_commit=expected_source_commit,
        authority_repo_root=authority_repo_root,
    )
    identity_failures = _entry_identity_failures(entry, item)
    if identity_failures:
        evaluation["execution_valid"] = False
        evaluation["common_physical_gate_passed"] = False
        evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + identity_failures
    evaluation["campaign_seed"] = item.campaign_seed
    evaluation["profile_id"] = item.profile_id
    evaluation["hip_cap_source"] = item.hip_cap_source
    evaluation["knee_cap_source"] = item.knee_cap_source
    evaluation["arm_id"] = item.arm_id
    evaluation["turn_heading_offset_rad"] = item.turn_heading_offset_rad
    return evaluation, rows


def _validate_complete_order(entries: Sequence[Any]) -> None:
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, Mapping)
        or entry.get("cell_id") != item.cell_id
        or entry.get("campaign_seed") != item.campaign_seed
        or entry.get("profile_id") != item.profile_id
        or entry.get("arm_id") != item.arm_id
        or entry.get("turn_heading_offset_rad") != item.turn_heading_offset_rad
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D60EvaluationError("R23D60_COMPLETE_ENTRY_ORDER_INVALID")


def _turning_projection(
    evaluations: Sequence[Mapping[str, Any]],
    rows_by_cell: Mapping[str, Sequence[Mapping[str, Any]]],
) -> dict[str, Any]:
    _require(len(evaluations) == 3, "R23D60_DECISION_EVALUATION_COUNT")
    for evaluation, item in zip(evaluations, design.cells(), strict=True):
        _require(
            evaluation.get("cell_id") == item.cell_id
            and evaluation.get("campaign_seed") == item.campaign_seed
            and evaluation.get("profile_id") == item.profile_id
            and evaluation.get("arm_id") == item.arm_id,
            "R23D60_DECISION_EVALUATION_IDENTITY",
        )
    matrix_execution_valid = all(
        evaluation.get("execution_valid") is True for evaluation in evaluations
    )
    all_common_physical_gates_passed = all(
        evaluation.get("common_physical_gate_passed") is True
        for evaluation in evaluations
    )
    cycle_measurement: dict[str, Any] | None = None
    measurement_failure_codes: list[str] = []
    if matrix_execution_valid:
        cycle_measurement = measurement.measure_cycle_integrated_response(
            {
                item.arm_id: accepted.inherited._measurement_rows(
                    rows_by_cell[item.cell_id]
                )
                for item in design.cells()
            }
        )
        measurement_failure_codes = [
            gate_id
            for gate_id, passed in cycle_measurement["gates"].items()
            if passed is not True
        ]
    turning_positive = bool(
        matrix_execution_valid
        and all_common_physical_gates_passed
        and cycle_measurement is not None
        and cycle_measurement.get("passed") is True
    )
    return {
        "matrix_execution_valid": matrix_execution_valid,
        "all_common_physical_gates_passed": all_common_physical_gates_passed,
        "cycle_integrated_measurement": cycle_measurement,
        "measurement_failure_codes": measurement_failure_codes,
        "held_out_turning_positive": turning_positive,
        "strict_finite_three_arm_conjunction_used": True,
        "minimum_raw_signed_cycle_shift_rad": (
            design.MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
        ),
        "minimum_reference_conditioned_cycle_shift_rad": (
            design.MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD
        ),
        "pass_rate_estimated": False,
        "superiority_test_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
    }


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    load_declaration()
    load_implementation()
    _require(_source_commit(expected_source_commit), "R23D60_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    _require((authority_root / ".git").exists(), "R23D60_AUTHORITY_REPO_ROOT_INVALID")
    _validate_complete_order(entries)

    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, design.cells(), strict=True):
        evaluation, rows = evaluate_entry(
            entry,
            item,
            expected_source_commit=expected_source_commit,
            authority_repo_root=authority_root,
        )
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows

    projection = _turning_projection(evaluations, rows_by_cell)
    characterizations = {
        item.cell_id: accepted.characterize_rows(rows_by_cell[item.cell_id], item)
        for item, evaluation in zip(design.cells(), evaluations, strict=True)
        if evaluation["execution_valid"]
    }
    if not projection["matrix_execution_valid"]:
        classification = (
            "invalid_or_incomplete_exact_held_out_godot_jolt_turning_validation"
        )
    elif projection["held_out_turning_positive"]:
        classification = (
            "valid_complete_positive_exact_held_out_godot_jolt_turning_validation"
        )
    else:
        classification = (
            "valid_complete_negative_exact_held_out_godot_jolt_turning_validation"
        )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["r23d60_held_out_turning_positive"] = bool(
        projection["held_out_turning_positive"]
    )
    claims["godot_jolt_turning"] = bool(projection["held_out_turning_positive"])
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": accepted.raw_sha256(DECLARATION_PATH),
        "implementation_raw_sha256": accepted.raw_sha256(IMPLEMENTATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "finite_decision": projection,
        "descriptive_characterization_by_cell": characterizations,
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_held_out_seed_count": 1,
        "fresh_held_out_seed_consumed": True,
        "selected_profile_id": design.PROFILE_ID,
        "turning_gate_invoked": True,
        "posthoc_threshold_or_selector_change_performed": False,
        "cross_engine_equivalence_test_invoked": False,
        "population_inference_attempted": False,
        "physical_acceptance_authority": False,
        "claims": claims,
    }


def _synthetic_evaluations(
    *, matrix_valid: bool = True, common_gates_passed: bool = True
) -> list[dict[str, Any]]:
    output = [
        {
            "cell_id": item.cell_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "arm_id": item.arm_id,
            "execution_valid": matrix_valid,
            "common_physical_gate_passed": (
                matrix_valid and common_gates_passed
            ),
        }
        for item in design.cells()
    ]
    if not matrix_valid:
        output[0]["execution_valid"] = False
        output[0]["common_physical_gate_passed"] = False
    return output


def _measurement_rows_by_cell(
    traces: Mapping[str, Sequence[Mapping[str, Any]]],
) -> dict[str, list[dict[str, Any]]]:
    return {
        item.cell_id: [dict(row) for row in traces[item.cell_id]]
        for item in design.cells()
    }


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    load_implementation()
    _bind_accepted_core()
    items = design.cells()
    traces = {item.cell_id: accepted._synthetic_rows(item) for item in items}
    validations = [validate_trace(item.cell_id, traces[item.cell_id]) for item in items]
    _require(all(value["ok"] for value in validations), "R23D60_TRACE_POSITIVE_CANARY")

    cap_positive = 0
    for item in items:
        projection = accepted._synthetic_cap_binding_projection(
            item, traces[item.cell_id]
        )
        cap_positive += int(
            not accepted._cap_binding_projection_failures(
                projection, traces[item.cell_id], item
            )
        )
    _require(cap_positive == 3, "R23D60_CAP_BINDING_POSITIVE_CANARY")

    first = items[0]
    base_mutations = (
        "missing_origin",
        "wrong_origin",
        "missing_transition",
        "extra_transition",
        "wrong_count",
        "wrong_policy",
        "initial_reanchor",
        "warmup_origin_drift",
        "startup",
        "segment",
    )
    base_rejections = 0
    for mutation_id in base_mutations:
        candidate = copy.deepcopy(traces[first.cell_id])
        accepted._base_mutation(candidate, mutation_id)
        base_rejections += int(not validate_trace(first.cell_id, candidate)["ok"])
    _require(base_rejections == len(base_mutations), "R23D60_TRACE_MUTATION_ACCEPTED")

    observation_mutations = (
        "missing",
        "schema",
        "semantic_step",
        "digest",
        "application_schema",
        "actuator_order",
        "actuator_identity",
        "limb_identity",
        "phase",
        "contact_before",
        "contact_after",
        "target_readback",
        "impulse_readback",
        "configured_nonclaim",
        "torque_nonclaim",
        "cardinality",
        "tolerance",
        "host_clamp",
        "match_flag",
        "nonfinite",
    )
    observation_rejections = 0
    for mutation_id in observation_mutations:
        candidate = copy.deepcopy(traces[first.cell_id])
        accepted._observation_mutation(candidate, mutation_id)
        try:
            rejected = not validate_trace(first.cell_id, candidate)["ok"]
        except (accepted.inherited.R23D34EvaluationError, ValueError):
            rejected = True
        observation_rejections += int(rejected)
    _require(
        observation_rejections == len(observation_mutations),
        "R23D60_OBSERVATION_MUTATION_ACCEPTED",
    )

    cap_mutations = (
        "missing_projection",
        "missing_summary",
        "wrong_projected_policy",
        "wrong_projected_profile",
        "integrity_false",
        "missing_receipt",
        "receipt_schema",
        "receipt_policy",
        "receipt_profile",
        "receipt_source",
        "validated_count",
        "write_count",
        "readback_count",
        "excessive_readback_error",
        "readback_flag",
        "actuator_order",
        "binding_source",
        "binding_cap",
        "binding_source_delta",
    )
    cap_projection = accepted._synthetic_cap_binding_projection(
        first, traces[first.cell_id]
    )
    cap_rejections = 0
    for mutation_id in cap_mutations:
        candidate = copy.deepcopy(cap_projection)
        accepted._cap_projection_mutation(candidate, mutation_id)
        cap_rejections += int(
            bool(
                accepted._cap_binding_projection_failures(
                    candidate, traces[first.cell_id], first
                )
            )
        )
    for field in (
        "declared_maximum_impulse_nms",
        "motor_maximum_impulse_readback_nms",
    ):
        candidate_rows = copy.deepcopy(traces[first.cell_id])
        candidate_rows[0]["actuator_phase_observation"]["ordered_applications"][0][
            field
        ] = "0.5"
        cap_rejections += int(
            bool(
                accepted._cap_binding_projection_failures(
                    cap_projection, candidate_rows, first
                )
            )
        )
    _require(cap_rejections == 21, "R23D60_CAP_BINDING_MUTATION_ACCEPTED")

    passing = _turning_projection(
        _synthetic_evaluations(),
        _measurement_rows_by_cell(traces),
    )
    _require(
        passing["held_out_turning_positive"] is True,
        "R23D60_TURNING_POSITIVE_CANARY",
    )
    decision_rejections = 0
    common_failure = _synthetic_evaluations()
    common_failure[0]["common_physical_gate_passed"] = False
    decision_rejections += int(
        not _turning_projection(
            common_failure, _measurement_rows_by_cell(traces)
        )["held_out_turning_positive"]
    )
    invalid_matrix = _turning_projection(
        _synthetic_evaluations(matrix_valid=False),
        _measurement_rows_by_cell(traces),
    )
    decision_rejections += int(
        not invalid_matrix["matrix_execution_valid"]
        and not invalid_matrix["held_out_turning_positive"]
    )
    reversed_traces = _measurement_rows_by_cell(traces)
    positive = items[1].cell_id
    negative = items[2].cell_id
    reversed_traces[positive], reversed_traces[negative] = (
        reversed_traces[negative],
        reversed_traces[positive],
    )
    reversed_result = _turning_projection(
        _synthetic_evaluations(), reversed_traces
    )
    decision_rejections += int(
        reversed_result["cycle_integrated_measurement"]["passed"] is False
        and not reversed_result["held_out_turning_positive"]
    )
    zero_traces = _measurement_rows_by_cell(traces)
    for rows in zero_traces.values():
        for row in rows:
            row["measured_yaw_rad"] = 0.0
    zero_result = _turning_projection(_synthetic_evaluations(), zero_traces)
    decision_rejections += int(
        zero_result["cycle_integrated_measurement"]["passed"] is False
        and not zero_result["held_out_turning_positive"]
    )
    _require(
        decision_rejections == 4,
        "R23D60_TURNING_DECISION_MUTATION_ACCEPTED",
    )

    entries = [
        {
            "cell_id": item.cell_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "arm_id": item.arm_id,
            "turn_heading_offset_rad": item.turn_heading_offset_rad,
        }
        for item in items
    ]
    _validate_complete_order(entries)
    order_mutations: list[list[dict[str, Any]]] = []
    omitted = copy.deepcopy(entries)
    omitted.pop()
    order_mutations.append(omitted)
    swapped = copy.deepcopy(entries)
    swapped[0], swapped[1] = swapped[1], swapped[0]
    order_mutations.append(swapped)
    duplicate = copy.deepcopy(entries)
    duplicate[-1] = copy.deepcopy(duplicate[0])
    order_mutations.append(duplicate)
    wrong_seed = copy.deepcopy(entries)
    wrong_seed[0]["campaign_seed"] = 21512
    order_mutations.append(wrong_seed)
    wrong_profile = copy.deepcopy(entries)
    wrong_profile[0]["profile_id"] = "portable_hip__portable_knee"
    order_mutations.append(wrong_profile)
    wrong_arm = copy.deepcopy(entries)
    wrong_arm[0]["arm_id"] = "positive_heading"
    order_mutations.append(wrong_arm)
    wrong_offset = copy.deepcopy(entries)
    wrong_offset[0]["turn_heading_offset_rad"] = 0.2
    order_mutations.append(wrong_offset)
    order_rejections = 0
    for candidate in order_mutations:
        try:
            _validate_complete_order(candidate)
        except R23D60EvaluationError:
            order_rejections += 1
    _require(order_rejections == 7, "R23D60_COMPLETE_ORDER_MUTATION_ACCEPTED")

    return {
        "schema_version": "sporespore_qsdk_r23d60_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "declared_cell_count": len(items),
        "valid_trace_canary_count": len(validations),
        "trace_mutation_rejection_count": (
            base_rejections + observation_rejections
        ),
        "observation_mutation_rejection_count": observation_rejections,
        "live_fixture_cap_binding_projection_positive_control_count": (
            cap_positive
        ),
        "live_fixture_cap_binding_projection_mutation_rejection_count": (
            cap_rejections
        ),
        "cycle_integrated_positive_control_count": 1,
        "turning_decision_mutation_rejection_count": decision_rejections,
        "complete_matrix_order_mutation_rejection_count": order_rejections,
        "observation_row_count_per_trace": design.CONTROLLER_STEPS,
        "observation_application_count_per_trace": (
            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        ),
        "turning_gate_invoked": True,
        "minimum_raw_signed_cycle_shift_rad": (
            design.MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
        ),
        "minimum_reference_conditioned_cycle_shift_rad": (
            design.MINIMUM_REFERENCE_CONDITIONED_CYCLE_SHIFT_RAD
        ),
        "superiority_test_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _manifest_paths(value: Any) -> list[str]:
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise R23D60EvaluationError("R23D60_TERMINAL_MANIFEST_INVALID")
    return list(value)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--expected-source-commit", required=True)
    evaluate.add_argument("--repo-root", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D60_EVALUATOR_PREFLIGHT "
        elif args.command == "retain-trace":
            value = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root_override,
            )
            marker = "QSDK_R23D60_TRACE_RETAINED "
        else:
            manifest_value = json.loads(args.manifest.read_text(encoding="utf-8"))
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8"))
                for path in _manifest_paths(manifest_value)
            ]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.expected_source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D60_COMPLETE_EVALUATION "
        print(
            marker
            + json.dumps(
                value, allow_nan=False, separators=(",", ":"), sort_keys=True
            )
        )
        return 0
    except (
        R23D60EvaluationError,
        design.DeclarationError,
        accepted.R23D58EvaluationError,
        accepted.inherited.R23D34EvaluationError,
        accepted.inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D60_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
