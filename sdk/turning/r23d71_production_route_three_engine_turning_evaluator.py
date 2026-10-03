#!/usr/bin/env python3
"""Canonical retained-evidence evaluator configured for QSDK-R23D71.

R23D71 reuses the accepted full-horizon R23D65 trace, physical-gate,
public-profile, CAS, and cycle-integrated algorithms.  This module binds those
algorithms to the new frozen campaign identity and adds only the R23D71 finite
outcome and public-claim projection.  Preflight is synthetic and constructs no
native model or world.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d58_godot_cap_source_factorial_evaluator as accepted
import r23d65_selected_profile_three_engine_turning_validation_evaluator as inherited
import r23d71_production_route_runtime as design
from r23d71_receipt_contract import project_retention_receipt


ROOT = Path(__file__).resolve().parent
DECLARATION_PATH = design.DECLARATION_PATH
REPORT_SCHEMA = "sporespore_qsdk_r23d71_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d71_worker_failure_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d71_turning_trace_row_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d71_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d71_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = (
    "sporespore_qsdk_r23d71_complete_three_engine_turning_evaluation_v1"
)
TRACE_TRANSPORT_ID = "sporespore_r23d71_full_precision_native_trace_transport_v1"

FALSE_CLAIMS = {
    "r23d71_finite_three_engine_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "arbitrary_quadruped_coverage": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}

EvaluationError = inherited.R23D65EvaluationError


def _configure_inherited_evaluator() -> None:
    """Bind the accepted evaluator process-locally to the frozen R23D71 view."""

    design.validate_runtime_projection()
    inherited.design = design
    inherited.DECLARATION_PATH = DECLARATION_PATH
    inherited.REPORT_SCHEMA = REPORT_SCHEMA
    inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
    inherited.TRACE_ROW_SCHEMA = TRACE_ROW_SCHEMA
    inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
    inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
    inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
    inherited.TRACE_TRANSPORT_ID = TRACE_TRANSPORT_ID
    inherited.DECLARED_SEGMENT_COUNTS = design.expected_segment_counts()
    inherited.FALSE_CLAIMS = copy.deepcopy(FALSE_CLAIMS)
    inherited.load_declaration = design.load_declaration


def _classification(projection: Mapping[str, Any]) -> str:
    if projection.get("matrix_execution_valid") is not True:
        return "invalid_or_incomplete_exact_seed_23191_three_engine_portable_turning"
    if projection.get("finite_three_engine_turning_positive") is True:
        return "valid_complete_positive_exact_seed_23191_three_engine_portable_turning"
    return "valid_complete_negative_exact_seed_23191_three_engine_portable_turning"


def _claims(positive: bool) -> dict[str, bool]:
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims.update(
        r23d71_finite_three_engine_turning=positive,
        finite_three_engine_turning=positive,
        portable_basic_turning=positive,
        q_sdk_r23_satisfied=positive,
    )
    return claims


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    _configure_inherited_evaluator()
    receipt = inherited.retain_trace(**kwargs)
    return project_retention_receipt(
        receipt, expected_row_count=design.CONTROLLER_STEPS
    )


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    _configure_inherited_evaluator()
    value = inherited.evaluate_complete_entries(
        entries,
        expected_source_commit=expected_source_commit,
        authority_repo_root=authority_repo_root,
    )
    projection = value["finite_decision"]
    positive = projection["finite_three_engine_turning_positive"] is True
    value.update(
        schema_version=COMPLETE_EVALUATION_SCHEMA,
        campaign_id=design.CAMPAIGN_ID,
        gate_id=design.GATE_ID,
        question_class=design.QUESTION_CLASS,
        declaration_raw_sha256=design.raw_sha256(DECLARATION_PATH),
        classification=_classification(projection),
        fresh_held_out_seed_count=1,
        fresh_held_out_seed_consumed=True,
        selected_public_profile_id=design.PROFILE_ID,
        cross_engine_equivalence_test_invoked=False,
        population_inference_attempted=False,
        physical_acceptance_authority=False,
        claims=_claims(positive),
    )
    return value


def _synthetic_outcome_controls() -> dict[str, Any]:
    """Exercise the four declared evaluator outcome classes without physics."""

    items = design.cells()
    traces = {item.cell_id: inherited._synthetic_rows(item) for item in items}
    rows_by_cell = inherited._measurement_rows_by_cell(traces)
    evaluations = inherited._synthetic_evaluations()

    positive = inherited._turning_projection(evaluations, rows_by_cell)
    if _classification(positive) != (
        "valid_complete_positive_exact_seed_23191_three_engine_portable_turning"
    ):
        raise EvaluationError("QSDK_R23D71_POSITIVE_OUTCOME_CONTROL_FAILED")

    negative_rows = copy.deepcopy(rows_by_cell)
    for item in items:
        if item.engine_id == "mujoco":
            for row in negative_rows[item.cell_id]:
                row["measured_yaw_rad"] = 0.0
    negative = inherited._turning_projection(evaluations, negative_rows)
    if _classification(negative) != (
        "valid_complete_negative_exact_seed_23191_three_engine_portable_turning"
    ):
        raise EvaluationError("QSDK_R23D71_NEGATIVE_OUTCOME_CONTROL_FAILED")

    invalid = inherited._turning_projection(
        inherited._synthetic_evaluations(matrix_valid=False),
        rows_by_cell,
    )
    if _classification(invalid) != (
        "invalid_or_incomplete_exact_seed_23191_three_engine_portable_turning"
    ):
        raise EvaluationError("QSDK_R23D71_INVALID_OUTCOME_CONTROL_FAILED")

    incomplete_entries = [
        {
            "cell_id": item.cell_id,
            "engine_id": item.engine_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "host_mapping_id": item.host_mapping_id,
            "arm_id": item.arm_id,
            "turn_heading_offset_rad": item.turn_heading_offset_rad,
        }
        for item in items[:-1]
    ]
    incomplete_rejected = False
    try:
        inherited._validate_complete_order(incomplete_entries)
    except EvaluationError:
        incomplete_rejected = True
    if not incomplete_rejected:
        raise EvaluationError("QSDK_R23D71_INCOMPLETE_OUTCOME_CONTROL_FAILED")

    return {
        "schema_version": "sporespore_qsdk_r23d71_evaluator_outcome_controls_v1",
        "positive_control_count": 1,
        "negative_control_count": 1,
        "invalid_control_count": 1,
        "incomplete_control_count": 1,
        "control_count": 4,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def run_zero_world_preflight() -> dict[str, Any]:
    _configure_inherited_evaluator()
    value = inherited.run_zero_world_preflight()
    controls = _synthetic_outcome_controls()
    value.update(
        schema_version="sporespore_qsdk_r23d71_evaluator_preflight_v1",
        campaign_id=design.CAMPAIGN_ID,
        gate_id=design.GATE_ID,
        question_class=design.QUESTION_CLASS,
        canonical_evaluator_implementation_id=(
            "sporespore_qsdk_r23d71_rebound_accepted_retained_evidence_evaluator_v1"
        ),
        inherited_algorithm_source=(
            "sdk/turning/"
            "r23d65_selected_profile_three_engine_turning_validation_evaluator.py"
        ),
        runtime_projection=design.validate_runtime_projection(),
        complete_outcome_controls=controls,
        model_construction_count=0,
        world_attempt_count=0,
        world_build_count=0,
        physical_execution_authorized=False,
        physical_acceptance_authority=False,
    )
    return value


def run_failure_terminal_transport_control() -> dict[str, Any]:
    _configure_inherited_evaluator()
    value = inherited.run_failure_terminal_transport_canary()
    value.update(
        schema_version="sporespore_qsdk_r23d71_failure_terminal_transport_control_v1",
        campaign_id=design.CAMPAIGN_ID,
        gate_id=design.GATE_ID,
        physical_acceptance_authority=False,
    )
    return value


def _manifest_paths(value: Any) -> list[str]:
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise EvaluationError("QSDK_R23D71_TERMINAL_MANIFEST_INVALID")
    return list(value)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    commands.add_parser("failure-terminal-control")
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
    evaluate.add_argument("--authority-repo-root", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if arguments.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D71_EVALUATOR_PREFLIGHT "
        elif arguments.command == "failure-terminal-control":
            value = run_failure_terminal_transport_control()
            marker = "QSDK_R23D71_FAILURE_TERMINAL_CONTROL "
        elif arguments.command == "retain-trace":
            value = retain_trace(
                stage_id=arguments.stage_id,
                cell_id=arguments.cell_id,
                rows_json_path=arguments.rows_json,
                repo_root=arguments.repo_root,
                attempt_root=arguments.attempt_root,
                powershell=arguments.powershell,
                test_only=arguments.test_only,
                evidence_root_override=arguments.evidence_root_override,
            )
            marker = "QSDK_R23D71_TRACE_RETAINED "
        else:
            manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8"))
                for path in _manifest_paths(manifest)
            ]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=arguments.expected_source_commit,
                authority_repo_root=arguments.authority_repo_root,
            )
            marker = "QSDK_R23D71_COMPLETE_EVALUATION "
        print(
            marker
            + json.dumps(
                value,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
    except (
        EvaluationError,
        accepted.R23D58EvaluationError,
        accepted.inherited.R23D34EvaluationError,
        design.DeclarationError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R23D71_EVALUATOR_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
