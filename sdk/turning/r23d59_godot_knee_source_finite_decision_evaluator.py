"""Retained-trace evaluator for the QSDK-R23D59 finite decision.

R23D59 reuses the already accepted fixed-horizon, task-origin, full-precision
trace, actuator-application, cap-binding, and common physical-gate algorithms.
It changes only the prospective matrix and the predeclared finite decision:
two knee-cap-source profiles across three fresh matched seeds.  No turning,
superiority, equivalence, repeatability-rate, robustness, or population test is
performed here.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d58_godot_cap_source_factorial_evaluator as accepted
import r23d59_godot_knee_source_finite_decision as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d59_godot_knee_source_finite_decision_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    ROOT / "r23d59_godot_knee_source_finite_decision_implementation_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d48_trace.ps1"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
REPORT_SCHEMA = "sporespore_qsdk_r23d59_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d59_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d59_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d59_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = (
    "sporespore_qsdk_r23d59_complete_finite_decision_evaluation_v1"
)
FALSE_CLAIMS = {
    "r23d59_finite_profile_selected": False,
    "r23d60_campaign_opened": False,
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


class R23D59EvaluationError(RuntimeError):
    """The declaration, retained evidence, or six-cell result is invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D59EvaluationError(code)


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
        raise R23D59EvaluationError(
            f"R23D59_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    try:
        design.validate_declaration(value)
    except design.DeclarationError as error:
        raise R23D59EvaluationError(f"R23D59_DECLARATION_INVALID:{error}") from error
    return value


def load_implementation() -> dict[str, Any]:
    try:
        value = json.loads(IMPLEMENTATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D59EvaluationError(
            f"R23D59_IMPLEMENTATION_UNREADABLE:{type(error).__name__}"
        ) from error
    worker = value.get("worker", {})
    evaluator = value.get("evaluator", {})
    claims = value.get("claims", {})
    dependency = value.get("dependency_closure", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d59_godot_knee_source_finite_decision_implementation_v1"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("question_class") != design.QUESTION_CLASS
        or value.get("physical_campaign_opened") is not False
        or value.get("declared_world_count") != 6
        or worker.get("path")
        != "tests/test_sdk_qsdk_r23d59_godot_jolt_physical_worker.gd"
        or evaluator.get("path")
        != "sdk/turning/r23d59_godot_knee_source_finite_decision_evaluator.py"
        or evaluator.get("all_six_cells_required_in_frozen_order") is not True
        or evaluator.get("complete_execution_valid_matrix_required_before_selection")
        is not True
        or evaluator.get("turning_gate_invoked") is not False
        or evaluator.get("superiority_or_equivalence_evaluator_invoked") is not False
        or dependency.get("policy_id")
        != "r23d59_declared_roots_recursive_local_language_closure_v1"
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
        raise R23D59EvaluationError("R23D59_IMPLEMENTATION_IDENTITY_INVALID")
    return value


def _bind_accepted_core() -> None:
    """Rebind the accepted algorithms to the prospective R23D59 identities."""

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
        return ["R23D59_ENTRY_TYPE"]
    failures: list[str] = []
    if entry.get("campaign_seed") != item.campaign_seed:
        failures.append("R23D59_CAMPAIGN_SEED_IDENTITY")
    if entry.get("profile_id") != item.profile_id:
        failures.append("R23D59_PROFILE_IDENTITY")
    if entry.get("hip_cap_source") != item.hip_cap_source:
        failures.append("R23D59_HIP_CAP_SOURCE_IDENTITY")
    if entry.get("knee_cap_source") != item.knee_cap_source:
        failures.append("R23D59_KNEE_CAP_SOURCE_IDENTITY")
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
    return evaluation, rows


def _validate_complete_order(entries: Sequence[Any]) -> None:
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, Mapping)
        or entry.get("cell_id") != item.cell_id
        or entry.get("campaign_seed") != item.campaign_seed
        or entry.get("profile_id") != item.profile_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D59EvaluationError("R23D59_COMPLETE_ENTRY_ORDER_INVALID")


def _decision_projection(
    evaluations: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    _require(len(evaluations) == 6, "R23D59_DECISION_EVALUATION_COUNT")
    by_profile: dict[str, list[Mapping[str, Any]]] = {
        profile_id: [] for profile_id in design.ORDERED_PROFILE_IDS
    }
    for evaluation, item in zip(evaluations, design.cells(), strict=True):
        _require(
            evaluation.get("cell_id") == item.cell_id
            and evaluation.get("campaign_seed") == item.campaign_seed
            and evaluation.get("profile_id") == item.profile_id,
            "R23D59_DECISION_EVALUATION_IDENTITY",
        )
        by_profile[item.profile_id].append(evaluation)
    _require(
        all(len(values) == len(design.DECISION_SEEDS) for values in by_profile.values()),
        "R23D59_DECISION_PROFILE_COHORT_COUNT",
    )
    matrix_execution_valid = all(
        evaluation.get("execution_valid") is True for evaluation in evaluations
    )
    profile_adequacy = {
        profile_id: all(
            evaluation.get("execution_valid") is True
            and evaluation.get("common_physical_gate_passed") is True
            for evaluation in values
        )
        for profile_id, values in by_profile.items()
    }
    decision = design.decide_profile(
        matrix_execution_valid=matrix_execution_valid,
        portable_adequate=profile_adequacy[design.PROFILE_PORTABLE],
        fixture_knee_adequate=profile_adequacy[design.PROFILE_FIXTURE_KNEE],
    )
    return {
        "matrix_execution_valid": matrix_execution_valid,
        "profile_adequacy": profile_adequacy,
        "decision_id": decision["decision_id"],
        "selected_profile_id": decision["selected_profile_id"],
        "r23d60_may_be_preregistered_from_this_result": (
            matrix_execution_valid and decision["selected_profile_id"] is not None
        ),
        "strict_finite_conjunction_used": True,
        "pass_rate_estimated": False,
        "superiority_test_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
    }


def _paired_descriptive_context(
    entries: Sequence[Mapping[str, Any]],
    evaluations: Sequence[Mapping[str, Any]],
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for seed_index, seed in enumerate(design.DECISION_SEEDS):
        pair_entries = entries[seed_index * 2 : seed_index * 2 + 2]
        pair_evaluations = evaluations[seed_index * 2 : seed_index * 2 + 2]
        if not all(value.get("execution_valid") is True for value in pair_evaluations):
            output.append(
                {
                    "campaign_seed": seed,
                    "status": "not_computed_because_one_or_both_matched_cells_execution_invalid",
                    "acceptance_authority": False,
                }
            )
            continue
        measurements = [entry.get("measurements", {}) for entry in pair_entries]
        portable, fixture = measurements
        contacts_portable = portable.get("contact_cycle_count_by_limb", {})
        contacts_fixture = fixture.get("contact_cycle_count_by_limb", {})
        output.append(
            {
                "campaign_seed": seed,
                "status": "computed_descriptive_context_only",
                "fixture_knee_minus_portable_knee": {
                    "final_forward_displacement_m": float(
                        fixture["final_forward_displacement_m"]
                    )
                    - float(portable["final_forward_displacement_m"]),
                    "maximum_tilt_rad": float(fixture["maximum_tilt_rad"])
                    - float(portable["maximum_tilt_rad"]),
                    "minimum_torso_height_m": float(
                        fixture["minimum_torso_height_m"]
                    )
                    - float(portable["minimum_torso_height_m"]),
                    "contact_cycle_count_by_limb": {
                        limb_id: int(contacts_fixture[limb_id])
                        - int(contacts_portable[limb_id])
                        for limb_id in design.LIMB_IDS
                    },
                },
                "contrast_margin_declared": False,
                "superiority_interpretation_authorized": False,
                "equivalence_interpretation_authorized": False,
                "acceptance_authority": False,
            }
        )
    return output


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    load_declaration()
    load_implementation()
    _require(_source_commit(expected_source_commit), "R23D59_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    _require((authority_root / ".git").exists(), "R23D59_AUTHORITY_REPO_ROOT_INVALID")
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

    projection = _decision_projection(evaluations)
    characterizations = {
        item.cell_id: accepted.characterize_rows(rows_by_cell[item.cell_id], item)
        for item, evaluation in zip(design.cells(), evaluations, strict=True)
        if evaluation["execution_valid"]
    }
    selected = projection["selected_profile_id"]
    if not projection["matrix_execution_valid"]:
        classification = "invalid_complete_no_selection_r23d59_finite_decision"
    elif selected is None:
        classification = "valid_complete_neither_profile_adequate_r23d59_finite_decision"
    elif selected == design.PROFILE_PORTABLE:
        classification = "valid_complete_portable_profile_selected_r23d59_finite_decision"
    else:
        classification = "valid_complete_fixture_knee_profile_selected_r23d59_finite_decision"
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["r23d59_finite_profile_selected"] = selected is not None
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
        "paired_descriptive_context": _paired_descriptive_context(entries, evaluations),
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_decision_seed_count": len(design.DECISION_SEEDS),
        "matched_profile_count_per_seed": len(design.ORDERED_PROFILE_IDS),
        "reserved_r23d60_seed_consumed": False,
        "turning_gate_invoked": False,
        "posthoc_threshold_or_selector_change_performed": False,
        "cross_engine_equivalence_test_invoked": False,
        "population_inference_attempted": False,
        "physical_acceptance_authority": False,
        "claims": claims,
    }


def _synthetic_evaluations(
    *, portable: bool, fixture: bool, matrix_valid: bool = True
) -> list[dict[str, Any]]:
    output = []
    for item in design.cells():
        adequate = portable if item.profile_id == design.PROFILE_PORTABLE else fixture
        output.append(
            {
                "cell_id": item.cell_id,
                "campaign_seed": item.campaign_seed,
                "profile_id": item.profile_id,
                "execution_valid": matrix_valid,
                "common_physical_gate_passed": matrix_valid and adequate,
            }
        )
    if not matrix_valid:
        output[0]["execution_valid"] = False
        output[0]["common_physical_gate_passed"] = False
    return output


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    load_implementation()
    _bind_accepted_core()
    items = design.cells()
    traces = {item.cell_id: accepted._synthetic_rows(item) for item in items}
    validations = [validate_trace(item.cell_id, traces[item.cell_id]) for item in items]
    _require(all(value["ok"] for value in validations), "R23D59_TRACE_POSITIVE_CANARY")

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
    _require(cap_positive == 6, "R23D59_CAP_BINDING_POSITIVE_CANARY")

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
    _require(base_rejections == len(base_mutations), "R23D59_TRACE_MUTATION_ACCEPTED")

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
        "R23D59_OBSERVATION_MUTATION_ACCEPTED",
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
    _require(cap_rejections == 21, "R23D59_CAP_BINDING_MUTATION_ACCEPTED")

    decision_cases = (
        (_synthetic_evaluations(portable=True, fixture=True), design.PROFILE_PORTABLE),
        (_synthetic_evaluations(portable=True, fixture=False), design.PROFILE_PORTABLE),
        (_synthetic_evaluations(portable=False, fixture=True), design.PROFILE_FIXTURE_KNEE),
        (_synthetic_evaluations(portable=False, fixture=False), None),
        (
            _synthetic_evaluations(
                portable=True, fixture=True, matrix_valid=False
            ),
            None,
        ),
    )
    for evaluations, expected in decision_cases:
        _require(
            _decision_projection(evaluations)["selected_profile_id"] == expected,
            "R23D59_DECISION_TABLE_CANARY",
        )
    conjunction_rejections = 0
    for index, item in enumerate(items):
        evaluations = _synthetic_evaluations(portable=True, fixture=True)
        evaluations[index]["common_physical_gate_passed"] = False
        projection = _decision_projection(evaluations)
        conjunction_rejections += int(
            projection["profile_adequacy"][item.profile_id] is False
        )
    _require(conjunction_rejections == 6, "R23D59_CONJUNCTION_MUTATION_ACCEPTED")

    entries = [
        {
            "cell_id": item.cell_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
        }
        for item in items
    ]
    _validate_complete_order(entries)
    order_rejections = 0
    order_mutations = []
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
    wrong_profile[0]["profile_id"] = design.PROFILE_FIXTURE_KNEE
    order_mutations.append(wrong_profile)
    for candidate in order_mutations:
        try:
            _validate_complete_order(candidate)
        except R23D59EvaluationError:
            order_rejections += 1
    _require(order_rejections == 5, "R23D59_COMPLETE_ORDER_MUTATION_ACCEPTED")

    return {
        "schema_version": "sporespore_qsdk_r23d59_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "declared_cell_count": len(items),
        "valid_trace_canary_count": len(validations),
        "trace_mutation_rejection_count": base_rejections + observation_rejections,
        "observation_mutation_rejection_count": observation_rejections,
        "live_fixture_cap_binding_projection_positive_control_count": cap_positive,
        "live_fixture_cap_binding_projection_mutation_rejection_count": cap_rejections,
        "finite_decision_table_positive_control_count": len(decision_cases),
        "strict_profile_conjunction_mutation_rejection_count": conjunction_rejections,
        "complete_matrix_order_mutation_rejection_count": order_rejections,
        "observation_row_count_per_trace": design.CONTROLLER_STEPS,
        "observation_application_count_per_trace": (
            design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        ),
        "turning_gate_invoked": False,
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
        raise R23D59EvaluationError("R23D59_TERMINAL_MANIFEST_INVALID")
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
            marker = "QSDK_R23D59_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D59_TRACE_RETAINED "
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
            marker = "QSDK_R23D59_COMPLETE_EVALUATION "
        print(
            marker
            + json.dumps(
                value, allow_nan=False, separators=(",", ":"), sort_keys=True
            )
        )
        return 0
    except (
        R23D59EvaluationError,
        design.DeclarationError,
        accepted.R23D58EvaluationError,
        accepted.inherited.R23D34EvaluationError,
        accepted.inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D59_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
