"""Focused zero-world integration tests for the R23D30 retained-trace gate."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import tempfile
import unittest

import r23d30_cycle_coherent_directional_response_evaluator as evaluator


def _phase(step: int) -> str:
    if step < 600:
        return "reference_warmup"
    if step < 1_800:
        return "commanded_turn"
    if step < 2_400:
        return "reference_recovery"
    return "reference_continuation"


def trace_rows(cell_id: str, arm_id: str) -> list[dict[str, object]]:
    response_by_arm = {
        "reference_zero": 0.003,
        "positive_heading": 0.023,
        "negative_heading": -0.019,
    }
    rows: list[dict[str, object]] = []
    remaining = 0
    for step in range(evaluator.base.CONTROLLER_STEPS):
        trigger = step == 700
        actual_tilt = 0.15 if trigger else 0.05
        tilt_rate = 0.10 if trigger else 0.0
        predicted_tilt = actual_tilt + 0.6 * tilt_rate
        instantaneous_fraction = (
            0.0
            if predicted_tilt >= 0.20
            else 1.0
            if predicted_tilt <= 0.10
            else (0.20 - predicted_tilt) / 0.10
        )
        instantaneous_effective = 0.20 + 0.08 * instantaneous_fraction
        triggered = instantaneous_effective <= 0.20 + evaluator.base.TOLERANCE
        before = remaining
        if triggered:
            remaining = 144
        active = remaining > 0
        after = remaining - 1 if active else 0
        final_fraction = 0.0 if active else instantaneous_fraction
        final_effective = 0.20 if active else instantaneous_effective
        raw_requested = 0.28 if 600 <= step < 1_800 else 0.0
        requested = min(raw_requested, final_effective)
        oscillator = 0.006 * math.sin(2.0 * math.pi * step / 360.0)
        response = response_by_arm[arm_id] if 600 <= step < 1_800 else 0.0
        rows.append(
            {
                "schema_version": evaluator.base.TRACE_ROW_SCHEMA,
                "cell_id": cell_id,
                "campaign_seed": 21_504,
                "trace_step": step,
                "phase_id": _phase(step),
                "controller_semantic_step": step,
                "requested_steering_fraction": requested,
                "held_steering_fraction": requested,
                "steering_saturated": requested != raw_requested,
                "steering_authority_guard": {
                    "schema_version": "sporespore_steering_authority_guard_receipt_v3",
                    "mode_id": "persistent_predicted_tilt_and_contact_steering_authority_guard_v1",
                    "torso_tilt_rad": actual_tilt,
                    "torso_tilt_rate_rad_s": tilt_rate,
                    "worsening_torso_tilt_rate_rad_s": tilt_rate,
                    "prediction_horizon_s": 0.6,
                    "prediction_horizon_scheduler_swing_steps": 72,
                    "predicted_torso_tilt_rad": predicted_tilt,
                    "tilt_rate_source_id": "state_frame_base_twist_world_angular_velocity_v1",
                    "prediction_horizon_basis_id": "one_balanced_wave_scheduler_swing_v1",
                    "support_contact_count": 4,
                    "contact_authority_permitted": True,
                    "minimum_support_contact_count": 2,
                    "tilt_authority_fraction": final_fraction,
                    "baseline_maximum_steering_fraction": 0.20,
                    "expanded_maximum_steering_fraction": 0.28,
                    "effective_maximum_steering_fraction": final_effective,
                    "instantaneous_tilt_authority_fraction": instantaneous_fraction,
                    "instantaneous_effective_maximum_steering_fraction": instantaneous_effective,
                    "floor_hold_duration_steps": 144,
                    "floor_hold_scheduler_swing_count": 2,
                    "floor_hold_steps_remaining_before_step": before,
                    "floor_hold_steps_remaining_after_step": after,
                    "floor_hold_triggered_this_step": triggered,
                    "floor_hold_active_this_step": active,
                    "floor_hold_basis_id": "two_balanced_wave_scheduler_swings_v1",
                    "direction_neutral": True,
                    "engine_identity_input_count": 0,
                },
                "measured_yaw_rad": math.remainder(
                    math.pi - 0.004 + oscillator + response, 2.0 * math.pi
                ),
                "torso_tilt_rad": actual_tilt,
                "torso_height_m": 0.5,
                "torso_ground_contact": False,
                "ordered_foot_contacts": {
                    "front_left": True,
                    "front_right": True,
                    "rear_left": True,
                    "rear_right": True,
                },
                "ordered_final_canonical_velocities_rad_s": [0.5] * 8,
                "ordered_actuator_velocity_limits_rad_s": [3.5] * 8,
            }
        )
        remaining = after
    return rows


def passing_report(root: Path, cell_id: str, source_commit: str) -> dict[str, object]:
    candidate_id, arm_id, cap = evaluator.base.identity(cell_id)
    rows = trace_rows(cell_id, arm_id)
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
        "campaign_seed": 21_504,
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


class R23D30EvaluatorTests(unittest.TestCase):
    def test_positive_matrix_validates_measurement_not_turning_release(self) -> None:
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
            "valid_complete_positive_measurement_validation_candidate",
        )
        self.assertTrue(result["selection_is_measurement_validation"])
        self.assertFalse(result["selection_is_controller_validation"])
        self.assertTrue(
            result["claims"]["finite_rapier_cycle_coherent_measurement_validation"]
        )
        self.assertFalse(result["claims"]["finite_rapier_turning_validation"])
        self.assertFalse(result["claims"]["cross_engine_equivalence"])

    def test_persistent_receipt_and_common_physical_mutations_fail_closed(self) -> None:
        cell_id = evaluator.base.expected_cells()[1]
        rows = trace_rows(cell_id, "positive_heading")
        mutated = copy.deepcopy(rows)
        mutated[701]["steering_authority_guard"][
            "floor_hold_steps_remaining_before_step"
        ] = 142
        with self.assertRaises(evaluator.base.R23D27EvaluationError):
            evaluator.base.validate_trace(cell_id, mutated)

        source_commit = "b" * 40
        with tempfile.TemporaryDirectory() as directory:
            reports = [
                passing_report(Path(directory), candidate, source_commit)
                for candidate in evaluator.base.expected_cells()
            ]
            reports[0]["measurements"]["minimum_torso_height_m"] = 0.1
            result = evaluator.evaluate_complete_entries(
                reports,
                expected_source_commit=source_commit,
                allow_test_artifacts=True,
            )
        self.assertEqual(
            result["classification"],
            "valid_complete_negative_no_measurement_validation_candidate",
        )
        self.assertIsNone(result["selected_candidate_id"])

    def test_incomplete_or_reordered_matrix_refuses(self) -> None:
        source_commit = "c" * 40
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
