"""R23D32 zero-world trace retention and finite Rapier turning replication."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any, Sequence

import r23d31_cycle_integrated_directional_response_evaluator as inherited


base = inherited.base
base.VARIANT = "r23d32"
base.R23D31 = True
base.CYCLE_COHERENT = True
base.PERSISTENT = True
base.PREDICTIVE = True
base.DECLARATION_PATH = (
    base.ROOT / "r23d32_finite_rapier_turning_replication_preregistration_v1.json"
)
base.TRACE_PUBLISHER_PATH = base.SDK_ROOT / "publish_qsdk_r23d32_trace.ps1"
base.CAMPAIGN_ID = "QSDK-R23D32-RAPIER-FINITE-TURNING-REPLICATION-VALIDATION"
base.GATE_ID = "QSDK-R23D32"
base.STAGE_ID = "rapier_finite_turning_replication_validation"
base.SCHEMA_STEM = "r23d32"
base.REPORT_SCHEMA = "sporespore_qsdk_r23d32_engine_cell_report_v1"
base.FAILURE_SCHEMA = "sporespore_qsdk_r23d32_worker_failure_v1"
base.TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d32_physical_trace_row_v1"
base.TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d32_trace_retention_v1"
base.COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d32_complete_evaluation_v1"
base.TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d32_trace_summary_v1"
base.DECLARATION_SCHEMA = (
    "sporespore_qsdk_r23d32_finite_rapier_turning_replication_preregistration_v1"
)
base.CAMPAIGN_SEED = 21_506
base.MARKER_STEM = "QSDK_R23D32"


def _load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(base.DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise base.R23D27EvaluationError(
            f"R23D32_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    family = value.get("candidate_family", {})
    candidates = family.get("ordered_candidates", [])
    measurement = value.get("cycle_integrated_measurement", {})
    invalid = (
        value.get("schema_version") != base.DECLARATION_SCHEMA
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != base.CAMPAIGN_ID
        or value.get("gate_id") != base.GATE_ID
        or family.get("behavioral_controller_change_set") != []
        or family.get("measurement_change_set") != []
        or family.get("finite_difference_trace_window_selected") is not False
        or family.get("engine_specific_gait_logic_permitted") is not False
        or family.get("candidate_or_outcome_branching_permitted") is not False
        or [row.get("candidate_id") for row in candidates] != list(base.CANDIDATES)
        or [row.get("controller_policy_id") for row in candidates]
        != [item["policy_id"] for item in base.CANDIDATES.values()]
        or [row.get("maximum_steering_fraction") for row in candidates]
        != [item["cap"] for item in base.CANDIDATES.values()]
        or len(candidates) != 1
        or candidates[0].get("floor_hold_duration_steps") != 144
        or candidates[0].get("floor_hold_scheduler_swing_count") != 2
        or matrix.get("stage_id") != base.STAGE_ID
        or matrix.get("ordered_candidate_ids") != list(base.CANDIDATES)
        or matrix.get("ordered_arm_ids") != list(base.ARMS)
        or matrix.get("declared_cell_count") != 3
        or matrix.get("controller_step_count") != base.CONTROLLER_STEPS
        or matrix.get("turn_start_step") != base.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != base.TURN_END_STEP_EXCLUSIVE
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or matrix.get("seed") != base.CAMPAIGN_SEED
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("baseline_start_step_inclusive") != 240
        or measurement.get("baseline_end_step_exclusive") != 600
        or measurement.get("terminal_start_step_inclusive") != 1_440
        or measurement.get("terminal_end_step_exclusive") != 1_800
        or measurement.get("scheduler_swing_steps") != 72
        or measurement.get("scheduler_cycle_steps") != 360
        or value.get("selector", {}).get("selected_candidate_is_validation")
        is not True
        or value.get("selector", {}).get("selected_measurement_is_validation")
        is not False
        or value.get("claims", {}).get("turning_validation") is not False
        or value.get("claims", {}).get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise base.R23D27EvaluationError("R23D32_DECLARATION_IDENTITY_INVALID")
    return value


base.load_declaration = _load_declaration


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    """Apply the unchanged R23D31 gate, then interpret only fresh replication."""
    result = inherited.evaluate_complete_entries(
        entries,
        expected_source_commit=expected_source_commit,
        allow_test_artifacts=allow_test_artifacts,
    )
    positive = (
        result["classification"]
        == "valid_complete_positive_measurement_validation_candidate"
    )
    result["classification"] = (
        "valid_complete_positive_finite_rapier_turning_validation"
        if positive
        else "valid_complete_negative_no_finite_rapier_turning_validation"
        if result["classification"]
        == "valid_complete_negative_no_measurement_validation_candidate"
        else result["classification"]
    )
    result["selection_is_controller_validation"] = positive
    result["selection_is_measurement_validation"] = False
    result["replicates_r23d31_selected_measurement"] = positive
    result["combined_independently_held_out_positive_fixture_count"] = (
        2 if positive else 1
    )
    result["finite_scope"] = {
        "engine_id": "rapier_parry",
        "morphology_id": "qsdk_r05_generated_s169",
        "validated_seed_ids_if_positive": [21505, 21506],
        "population_inference": False,
        "portable_inference": False,
    }
    result["claims"] = {
        "finite_rapier_cycle_integrated_measurement_validation": positive,
        "finite_rapier_turning_validation": positive,
        "finite_three_engine_turning": False,
        "portable_basic_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }
    return result


def main(argv: Sequence[str] | None = None) -> int:
    args = inherited.arguments(sys.argv[1:] if argv is None else argv)
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
                raise base.R23D27EvaluationError("R23D32_MANIFEST_INVALID")
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
        inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
    ) as error:
        print(f"{base.MARKER_STEM}_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
