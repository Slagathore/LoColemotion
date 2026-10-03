"""Zero-world mutation tests for the R23D26 trace gate and selector."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
MODULE_PATH = ROOT / "r23d26_rapier_steering_cap_evaluator.py"
SPEC = importlib.util.spec_from_file_location("r23d26_evaluator_under_test", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
evaluator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = evaluator
SPEC.loader.exec_module(evaluator)


def trace_rows(cell_id: str, cap: float) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for step in range(evaluator.CONTROLLER_STEPS):
        requested = cap if evaluator.TURN_START_STEP <= step < evaluator.TURN_END_STEP_EXCLUSIVE else 0.0
        rows.append(
            {
                "schema_version": evaluator.TRACE_ROW_SCHEMA,
                "cell_id": cell_id,
                "trace_step": step,
                "controller_semantic_step": step,
                "requested_steering_fraction": requested,
                "held_steering_fraction": requested,
                "steering_saturated": requested != 0.0,
                "measured_yaw_rad": step * 0.00001,
                "torso_tilt_rad": 0.05,
                "torso_height_m": 0.5,
                "torso_ground_contact": False,
                "ordered_foot_contacts": {
                    "front_left": True,
                    "front_right": True,
                    "rear_left": True,
                    "rear_right": True,
                },
            }
        )
    return rows


def passing_report(
    root: Path,
    cell_id: str,
    source_commit: str,
) -> dict[str, object]:
    candidate_id, arm_id, cap = evaluator.identity(cell_id)
    payload = root / f"{cell_id}.ndjson"
    payload.write_bytes((cell_id + "\n").encode("utf-8"))
    digest = "sha256:" + hashlib.sha256(payload.read_bytes()).hexdigest()
    yaw_delta = {
        "reference_zero": 0.0,
        "positive_heading": 0.03,
        "negative_heading": -0.03,
    }[arm_id]
    return {
        "schema_version": evaluator.REPORT_SCHEMA,
        "campaign_id": evaluator.CAMPAIGN_ID,
        "gate_id": evaluator.GATE_ID,
        "stage_id": evaluator.STAGE_ID,
        "cell_id": cell_id,
        "engine_id": evaluator.ENGINE_ID,
        "candidate_id": candidate_id,
        "controller_policy_id": evaluator.CANDIDATES[candidate_id]["policy_id"],
        "maximum_steering_fraction": cap,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "trace_artifact": {
            "schema_version": evaluator.TRACE_ARTIFACT_SCHEMA,
            "payload_path": str(payload),
            "sha256": digest,
            "byte_length": payload.stat().st_size,
            "test_only": True,
            "physical_acceptance_authority": False,
        },
        "trace_summary": {
            "raw_sha256": digest,
            "byte_length": payload.stat().st_size,
            "row_count": evaluator.CONTROLLER_STEPS,
        },
        "execution": {
            "integrity_passed": True,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "controller_semantic_step_count": evaluator.CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": 0,
        },
        "measurements": {
            "final_forward_displacement_m": 0.5,
            "turn_phase_yaw_delta_rad": yaw_delta,
            "maximum_tilt_rad": 0.1,
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


class R23D26EvaluatorTests(unittest.TestCase):
    def test_trace_accepts_exact_cap_and_rejects_cap_violation(self) -> None:
        cell_id = "rapier_parry__cap_0p10__positive_heading"
        rows = trace_rows(cell_id, 0.10)
        summary = evaluator.validate_trace(cell_id, rows)
        self.assertTrue(summary["ok"])
        self.assertEqual(summary["row_count"], evaluator.CONTROLLER_STEPS)
        mutated = copy.deepcopy(rows)
        mutated[evaluator.TURN_START_STEP]["requested_steering_fraction"] = 0.100001
        with self.assertRaises(evaluator.R23D26EvaluationError):
            evaluator.validate_trace(cell_id, mutated)

    def test_selector_chooses_largest_complete_pass_and_falls_back(self) -> None:
        source_commit = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            reports = [
                passing_report(root, cell_id, source_commit)
                for cell_id in evaluator.expected_cells()
            ]
            selected = evaluator.evaluate_complete_entries(
                reports,
                expected_source_commit=source_commit,
                allow_test_artifacts=True,
            )
            self.assertEqual(selected["classification"], "valid_complete_positive")
            self.assertEqual(selected["selected_candidate_id"], "cap_0p30")
            self.assertFalse(selected["selection_is_validation"])

            mutated = copy.deepcopy(reports)
            cap_0p30_positive = evaluator.expected_cells().index(
                "rapier_parry__cap_0p30__positive_heading"
            )
            mutated[cap_0p30_positive]["measurements"]["maximum_tilt_rad"] = 0.7
            fallback = evaluator.evaluate_complete_entries(
                mutated,
                expected_source_commit=source_commit,
                allow_test_artifacts=True,
            )
            self.assertEqual(fallback["selected_candidate_id"], "cap_0p20")

    def test_incomplete_matrix_refuses(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports = [
                passing_report(Path(directory), cell_id, "b" * 40)
                for cell_id in evaluator.expected_cells()[:-1]
            ]
            with self.assertRaises(evaluator.R23D26EvaluationError):
                evaluator.evaluate_complete_entries(
                    reports,
                    expected_source_commit="b" * 40,
                    allow_test_artifacts=True,
                )


if __name__ == "__main__":
    unittest.main()
