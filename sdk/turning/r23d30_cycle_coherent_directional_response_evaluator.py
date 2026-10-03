"""R23D30 zero-world trace retention and cycle-coherent evaluation."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
from typing import Any, Sequence

os.environ["SPORESPORE_QSDK_R23_PREDICTIVE_VARIANT"] = "r23d30"

import r23d27_stability_guarded_steering_evaluator as base
from r23d30_cycle_coherent_measurement import (
    CycleCoherentMeasurementError,
    measure_cycle_coherent_response,
)


def _trace_rows(entry: dict[str, Any]) -> list[dict[str, Any]]:
    artifact = entry.get("trace_artifact", {})
    path = Path(str(artifact.get("payload_path", "")))
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
        rows = [json.loads(line) for line in lines]
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise base.R23D27EvaluationError(
            f"R23D30_TRACE_PAYLOAD_UNREADABLE:{type(error).__name__}"
        ) from error
    if not all(isinstance(row, dict) for row in rows):
        raise base.R23D27EvaluationError("R23D30_TRACE_PAYLOAD_INVALID")
    summary = base.validate_trace(str(entry.get("cell_id", "")), rows)
    if (
        summary.get("raw_sha256") != artifact.get("sha256")
        or summary.get("byte_length") != artifact.get("byte_length")
    ):
        raise base.R23D27EvaluationError("R23D30_TRACE_REVALIDATION_MISMATCH")
    return rows


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    declaration = base.load_declaration()
    if not base.valid_source_commit(expected_source_commit):
        raise base.R23D27EvaluationError("R23D30_SOURCE_COMMIT_INVALID")
    expected = base.expected_cells()
    if len(entries) != len(expected):
        raise base.R23D27EvaluationError("R23D30_COMPLETE_ENTRY_COUNT_INVALID")
    if any(
        not isinstance(entry, dict) or entry.get("cell_id") != cell_id
        for entry, cell_id in zip(entries, expected, strict=True)
    ):
        raise base.R23D27EvaluationError("R23D30_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations = [
        base.evaluate_entry(
            entry,
            expected_cell_id=cell_id,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
        for entry, cell_id in zip(entries, expected, strict=True)
    ]
    all_execution_valid = all(row["execution_valid"] for row in evaluations)
    measurement: dict[str, Any] | None = None
    if all_execution_valid:
        rows_by_arm = {
            str(entry["arm_id"]): _trace_rows(entry) for entry in entries
        }
        measurement = measure_cycle_coherent_response(rows_by_arm)
        measurement_failures = [
            name for name, passed in measurement["gates"].items() if not passed
        ]
        for row in evaluations:
            if row["arm_id"] != "reference_zero" and measurement_failures:
                row["failure_codes"] = [
                    *row["failure_codes"],
                    *[f"cycle_coherent_{name}" for name in measurement_failures],
                ]
                row["gate_passed"] = False
            row["cycle_coherent_measurement_applied"] = True
    else:
        for row in evaluations:
            row["cycle_coherent_measurement_applied"] = False

    common_physical_passed = all(row["gate_passed"] for row in evaluations)
    measurement_passed = measurement is not None and measurement["passed"] is True
    eligible = all_execution_valid and common_physical_passed and measurement_passed
    if not all_execution_valid:
        classification = "invalid_complete_execution_failure"
    elif eligible:
        classification = "valid_complete_positive_measurement_validation_candidate"
    else:
        classification = "valid_complete_negative_no_measurement_validation_candidate"
    candidate_id = next(iter(base.CANDIDATES))
    return {
        "schema_version": base.COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": base.CAMPAIGN_ID,
        "gate_id": base.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": base.raw_sha256(base.DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "all_cells_execution_valid": all_execution_valid,
        "all_common_physical_gates_passed": common_physical_passed,
        "cycle_coherent_measurement": measurement,
        "eligible_candidate_ids": [candidate_id] if eligible else [],
        "selected_candidate_id": candidate_id if eligible else None,
        "selected_controller_policy_id": (
            base.CANDIDATES[candidate_id]["policy_id"] if eligible else None
        ),
        "selection_is_controller_validation": False,
        "selection_is_measurement_validation": eligible,
        "distinct_cross_engine_validation_required": eligible,
        "all_cells_run_regardless_of_intermediate_outcome": declaration[
            "frozen_matrix"
        ]["all_cells_run_regardless_of_intermediate_outcome"],
        "claims": {
            "finite_rapier_cycle_coherent_measurement_validation": eligible,
            "finite_rapier_turning_validation": False,
            "portable_basic_turning": False,
            "finite_three_engine_turning": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--source-root", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--source-commit", required=True)
    evaluate.add_argument("--allow-test-artifacts", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "retain-trace":
            receipt = base.retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                source_root=args.source_root,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root_override,
            )
            print(
                base.MARKER_STEM
                + "_TRACE_RETENTION "
                + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            )
        else:
            manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
            if not isinstance(manifest, list):
                raise base.R23D27EvaluationError("R23D30_MANIFEST_INVALID")
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8"))
                for path in manifest
            ]
            result = evaluate_complete_entries(
                entries,
                expected_source_commit=args.source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
            print(
                base.MARKER_STEM
                + "_COMPLETE_EVALUATION "
                + json.dumps(result, sort_keys=True, separators=(",", ":"))
            )
        return 0
    except (
        base.R23D27EvaluationError,
        CycleCoherentMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
    ) as error:
        print(f"{base.MARKER_STEM}_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
