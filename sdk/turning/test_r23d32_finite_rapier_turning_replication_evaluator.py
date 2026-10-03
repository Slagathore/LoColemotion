"""Focused zero-world integration tests for the R23D32 replication gate."""

from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest

import r23d32_finite_rapier_turning_replication_evaluator as evaluator
import test_r23d31_cycle_integrated_directional_response_evaluator as inherited_test


def passing_report(
    root: Path,
    cell_id: str,
    source_commit: str,
    response_by_arm: dict[str, float] | None = None,
) -> dict[str, object]:
    candidate_id, arm_id, cap = evaluator.base.identity(cell_id)
    rows = inherited_test.trace_rows(cell_id, arm_id, response_by_arm)
    for row in rows:
        row["campaign_seed"] = 21_506
    payload_bytes = evaluator.base.canonical_ndjson(rows)
    payload = root / f"{arm_id}.ndjson"
    payload.write_bytes(payload_bytes)
    digest = "sha256:" + hashlib.sha256(payload_bytes).hexdigest()
    summary = evaluator.base.validate_trace(cell_id, rows)
    return {
        "schema_version": evaluator.base.REPORT_SCHEMA,
        "campaign_id": evaluator.base.CAMPAIGN_ID,
        "gate_id": evaluator.base.GATE_ID,
        "stage_id": evaluator.base.STAGE_ID,
        "cell_id": cell_id,
        "engine_id": evaluator.base.ENGINE_ID,
        "candidate_id": candidate_id,
        "controller_policy_id": evaluator.base.CANDIDATES[candidate_id]["policy_id"],
        "maximum_steering_fraction": cap,
        "arm_id": arm_id,
        "campaign_seed": 21_506,
        "source_commit": source_commit,
        "trace_artifact": {
            "schema_version": evaluator.base.TRACE_ARTIFACT_SCHEMA,
            "payload_path": str(payload),
            "sha256": digest,
            "byte_length": len(payload_bytes),
            "test_only": True,
            "physical_acceptance_authority": False,
        },
        "trace_summary": summary,
        "execution": {
            "integrity_passed": True,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "controller_semantic_step_count": evaluator.base.CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": 0,
        },
        "measurements": {
            "final_forward_displacement_m": 0.5,
            "turn_phase_yaw_delta_rad": 0.0,
            "maximum_tilt_rad": 0.15,
            "minimum_torso_height_m": 0.5,
            "contact_cycle_count_by_limb": {
                "front_left": 3,
                "front_right": 3,
                "rear_left": 3,
                "rear_right": 3,
            },
            "torso_ground_contact_step_count": 0,
            "controller_error_count": 0,
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "maximum_absolute_requested_steering_fraction": cap,
            "maximum_absolute_held_steering_fraction": cap,
        },
        "claims": {"physical_acceptance_authority": False},
    }


class R23D32EvaluatorTests(unittest.TestCase):
    def test_positive_matrix_validates_only_finite_rapier_turning(self) -> None:
        source_commit = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            reports = [
                passing_report(Path(directory), cell_id, source_commit)
                for cell_id in evaluator.base.expected_cells()
            ]
            result = evaluator.evaluate_complete_entries(
                reports,
                expected_source_commit=source_commit,
                allow_test_artifacts=True,
            )
        self.assertEqual(
            result["classification"],
            "valid_complete_positive_finite_rapier_turning_validation",
        )
        self.assertTrue(result["selection_is_controller_validation"])
        self.assertFalse(result["selection_is_measurement_validation"])
        self.assertTrue(result["claims"]["finite_rapier_turning_validation"])
        self.assertFalse(result["claims"]["portable_basic_turning"])
        self.assertFalse(result["claims"]["cross_engine_equivalence"])
        self.assertEqual(
            result["finite_scope"]["validated_seed_ids_if_positive"],
            [21505, 21506],
        )

    def test_measurement_failure_preserves_common_physical_verdict(self) -> None:
        source_commit = "b" * 40
        too_small = {
            "reference_zero": 0.001,
            "positive_heading": 0.006,
            "negative_heading": -0.004,
        }
        with tempfile.TemporaryDirectory() as directory:
            reports = [
                passing_report(Path(directory), cell_id, source_commit, too_small)
                for cell_id in evaluator.base.expected_cells()
            ]
            result = evaluator.evaluate_complete_entries(
                reports,
                expected_source_commit=source_commit,
                allow_test_artifacts=True,
            )
        self.assertEqual(
            result["classification"],
            "valid_complete_negative_no_finite_rapier_turning_validation",
        )
        self.assertTrue(result["all_common_physical_gates_passed"])
        self.assertFalse(result["claims"]["finite_rapier_turning_validation"])

    def test_physical_failure_cannot_select_replication(self) -> None:
        source_commit = "c" * 40
        with tempfile.TemporaryDirectory() as directory:
            reports = [
                passing_report(Path(directory), cell_id, source_commit)
                for cell_id in evaluator.base.expected_cells()
            ]
            reports[0]["measurements"]["minimum_torso_height_m"] = 0.1
            result = evaluator.evaluate_complete_entries(
                reports,
                expected_source_commit=source_commit,
                allow_test_artifacts=True,
            )
        self.assertFalse(result["all_common_physical_gates_passed"])
        self.assertFalse(result["claims"]["finite_rapier_turning_validation"])
        self.assertIsNone(result["selected_candidate_id"])

    def test_incomplete_or_reordered_matrix_refuses(self) -> None:
        source_commit = "d" * 40
        with tempfile.TemporaryDirectory() as directory:
            reports = [
                passing_report(Path(directory), cell_id, source_commit)
                for cell_id in evaluator.base.expected_cells()
            ]
            with self.assertRaises(evaluator.base.R23D27EvaluationError):
                evaluator.evaluate_complete_entries(
                    reports[:-1],
                    expected_source_commit=source_commit,
                    allow_test_artifacts=True,
                )
            reports[1], reports[2] = reports[2], reports[1]
            with self.assertRaises(evaluator.base.R23D27EvaluationError):
                evaluator.evaluate_complete_entries(
                    reports,
                    expected_source_commit=source_commit,
                    allow_test_artifacts=True,
                )


if __name__ == "__main__":
    unittest.main()
