from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

from analyze_retained_trace_lineage import TraceLineageError, run_analysis


SOURCE_COMMIT = "1" * 40
SCHEMA = "synthetic_trace_v1"
ACTUATORS = [f"a{index}" for index in range(8)]
LIMBS = ["front_left", "front_right", "rear_left", "rear_right"]


def _row(
    cell_id: str,
    step: int,
    phase: str,
    desired: float,
    yaw: float,
    *,
    final_commands: list[float] | None,
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA,
        "cell_id": cell_id,
        "trace_step": step,
        "phase_id": phase,
        "measured_yaw_rad": yaw,
        "desired_heading_offset_rad": desired,
        "base_angular_velocity_task_yaw_rad_s": yaw * 2.0,
        "requested_steering_fraction": desired,
        "held_steering_fraction": desired * min(1.0, (step + 1) / 3.0),
        "steering_saturated": phase == "commanded_turn" and desired != 0.0,
        "steering_authority_guard": {
            "schema_version": "synthetic_guard_v1",
            "mode_id": "synthetic_guard_mode_v1",
            "floor_hold_active_this_step": False,
            "floor_hold_triggered_this_step": False,
        },
        "torso_tilt_rad": 0.01 + step * 0.001,
        "torso_height_m": 0.45 - step * 0.001,
        "maximum_absolute_joint_position_error_rad": 0.1 + step * 0.01,
        "ordered_foot_contacts": {limb: limb != "rear_right" or step != 3 for limb in LIMBS},
        "torso_ground_contact": False,
        "minimum_dynamic_support_margin_availability": "measured",
        "minimum_dynamic_support_margin_m": 0.03 - step * 0.01,
        "ordered_applied_stability_velocity_deltas_rad_s": [
            (index + 1) * 0.001 * step for index in range(8)
        ],
        "ordered_final_canonical_velocities_rad_s": final_commands,
    }


def _rows(
    cell_id: str,
    command_sign: int,
    *,
    complete_commands: bool,
) -> list[dict[str, Any]]:
    desired = command_sign * 0.2
    if command_sign > 0:
        yaws = [0.0, 0.0, 0.01, 0.03, 0.06, 0.1]
    elif command_sign < 0:
        yaws = [0.0, 0.0, -0.02, -0.05, -0.08, -0.12]
    else:
        yaws = [0.0, 0.0, 0.001, 0.002, 0.003, 0.004]
    result = []
    for step, yaw in enumerate(yaws):
        phase = "warmup" if step < 2 else "commanded_turn"
        commands = (
            [(index + 1) * 0.1 + step * 0.01 for index in range(8)]
            if complete_commands
            else None
        )
        result.append(
            _row(
                cell_id,
                step,
                phase,
                desired if phase == "commanded_turn" else 0.0,
                yaw,
                final_commands=commands,
            )
        )
    return result


class RetainedTraceLineageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.evidence = self.root / "evidence"
        self.manifest_path = self.root / "manifest.json"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _publish(self, rows: list[dict[str, Any]]) -> tuple[str, int]:
        payload = (
            "\n".join(json.dumps(row, separators=(",", ":"), sort_keys=True) for row in rows)
            + "\n"
        ).encode("utf-8")
        digest = hashlib.sha256(payload).hexdigest()
        directory = self.evidence / "artifacts" / "sha256" / digest
        directory.mkdir(parents=True)
        (directory / "payload.bin").write_bytes(payload)
        (directory / "manifest.json").write_text(
            json.dumps(
                {
                    "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
                    "algorithm": "sha256",
                    "sha256": f"sha256:{digest}",
                    "byte_length": len(payload),
                    "payload_name": "payload.bin",
                    "media_type": "application/x-ndjson",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        return f"sha256:{digest}", len(payload)

    def _manifest(
        self,
        *,
        complete_commands: bool,
        mutation: Any | None = None,
    ) -> dict[str, Any]:
        cells = []
        identities = [
            ("candidate__reference", "reference_zero", 0),
            ("candidate__positive", "positive_heading", 1),
            ("candidate__negative", "negative_heading", -1),
        ]
        for cell_id, arm_id, sign in identities:
            rows = _rows(cell_id, sign, complete_commands=complete_commands)
            if mutation is not None and cell_id == "candidate__positive":
                mutation(rows)
            digest, length = self._publish(rows)
            cells.append(
                {
                    "cell_id": cell_id,
                    "engine_id": "synthetic",
                    "candidate_id": "candidate",
                    "arm_id": arm_id,
                    "command_sign": sign,
                    "steering_cap": 0.2,
                    "trace_sha256": digest,
                    "trace_byte_length": length,
                }
            )
        return {
            "schema_version": "sporespore_retained_trace_lineage_manifest_v1",
            "analysis_id": "SYNTHETIC-D1",
            "question_class": "postclosure_development_diagnosis",
            "source_closure": {"gate_id": "SYNTHETIC"},
            "trace_contract": {
                "trace_schema_version": SCHEMA,
                "expected_row_count": 6,
                "phase_order": [
                    {"phase_id": "warmup", "row_count": 2},
                    {"phase_id": "commanded_turn", "row_count": 4},
                ],
                "analysis_phase_id": "commanded_turn",
                "final_window_row_count": 2,
                "authority_reach_fraction": 0.95,
                "ordered_contact_limbs": LIMBS,
                "ordered_actuator_names": ACTUATORS,
                "ordered_actuator_velocity_limits_rad_s": (
                    [2.0] * 8 if complete_commands else None
                ),
                "directional_response_measurement": {
                    "enabled": True,
                    "scheduler_swing_steps": 2,
                    "scheduler_cycle_steps": 2,
                    "terminal_mean_window_steps": [1, 2],
                    "terminal_window_grid_provenance": (
                        "synthetic endpoint plus one complete two-step cycle"
                    ),
                    "trajectory_baseline_window_steps": 2,
                    "trajectory_baseline_provenance": (
                        "one synthetic precommand scheduler cycle"
                    ),
                    "expected_steering_sign_by_command_sign": {
                        "-1": -1,
                        "1": 1,
                    },
                    "steering_zero_tolerance": 1.0e-12,
                    "required_guard_schema_version": "synthetic_guard_v1",
                    "required_guard_mode_id": "synthetic_guard_mode_v1",
                },
            },
            "replayed_thresholds": {
                "minimum_command_conditioned_yaw_separation_rad": 0.01,
                "threshold_change_authorized": False,
            },
            "cells": cells,
            "comparison_groups": [
                {
                    "candidate_id": "candidate",
                    "reference_cell_id": "candidate__reference",
                    "positive_cell_id": "candidate__positive",
                    "negative_cell_id": "candidate__negative",
                }
            ],
            "claim_limits": {
                "closed_campaign_reinterpreted": False,
                "candidate_selection_authorized": False,
                "threshold_change_authorized": False,
                "physical_campaign_opened": False,
                "physical_execution_authorized": False,
                "turning_validation": False,
                "cross_engine_equivalence": False,
                "release_authorized": False,
                "physical_acceptance_authority": False,
            },
        }

    def _run(self, manifest: dict[str, Any]) -> dict[str, Any]:
        self.manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8")
        return run_analysis(self.manifest_path, self.evidence, SOURCE_COMMIT)

    def test_complete_projection_and_comparison(self) -> None:
        report = self._run(self._manifest(complete_commands=True))
        self.assertEqual(report["input_summary"]["cell_count"], 3)
        self.assertEqual(report["input_summary"]["total_trace_row_count"], 18)
        comparison = report["comparisons"][0]
        self.assertGreater(comparison["positive_margin_rad"], 0.0)
        self.assertGreater(comparison["negative_margin_rad"], 0.0)
        self.assertTrue(comparison["both_conditioned_thresholds_met"])
        measurement = comparison["directional_response_measurement"]
        self.assertEqual(
            [window["window_steps"] for window in measurement["windows"]],
            [1, 2],
        )
        self.assertAlmostEqual(
            measurement["windows"][0][
                "positive_reference_conditioned_mean_yaw_shift_rad"
            ],
            0.096,
        )
        self.assertAlmostEqual(
            measurement["windows"][0][
                "negative_reference_conditioned_mean_yaw_shift_rad"
            ],
            0.124,
        )
        self.assertEqual(
            measurement["response_trajectories"]["positive_heading"][
                "first_threshold_met_step"
            ],
            3,
        )
        self.assertEqual(
            measurement["response_trajectories"]["negative_heading"][
                "first_threshold_met_step"
            ],
            2,
        )
        self.assertTrue(
            measurement["direct_observations"][
                "both_commanded_arms_requested_sign_consistent_every_row"
            ]
        )
        self.assertIsNone(measurement["terminal_estimator_selected_for_successor"])
        self.assertFalse(measurement["closed_endpoint_verdict_changed"])
        self.assertEqual(report["observability"]["complete_limiting_actuator_cell_count"], 3)
        self.assertTrue(report["observability"]["limiting_actuator_claim_authorized"])
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["candidate_selection_authorized"])

    def test_missing_final_commands_are_explicitly_unavailable(self) -> None:
        report = self._run(self._manifest(complete_commands=False))
        self.assertEqual(report["observability"]["complete_limiting_actuator_cell_count"], 0)
        self.assertEqual(report["observability"]["limiting_actuator_unavailable_cell_count"], 3)
        self.assertFalse(report["observability"]["limiting_actuator_claim_authorized"])
        for cell in report["cells"]:
            self.assertEqual(cell["actuators"]["final_command_availability"], "unavailable")
            self.assertEqual(
                cell["actuators"]["limiting_actuator_unavailable_reason"],
                "ordered_final_commands_not_complete",
            )

    def test_trace_step_mutation_fails_closed(self) -> None:
        manifest = self._manifest(
            complete_commands=False,
            mutation=lambda rows: rows[3].__setitem__("trace_step", 99),
        )
        with self.assertRaisesRegex(TraceLineageError, "TRACE_LINEAGE_TRACE_STEP_SEQUENCE"):
            self._run(manifest)

    def test_phase_mutation_fails_closed(self) -> None:
        manifest = self._manifest(
            complete_commands=False,
            mutation=lambda rows: rows[3].__setitem__("phase_id", "warmup"),
        )
        with self.assertRaisesRegex(TraceLineageError, "TRACE_LINEAGE_TRACE_PHASE_SEQUENCE"):
            self._run(manifest)

    def test_nonfinite_mutation_fails_closed(self) -> None:
        manifest = self._manifest(
            complete_commands=False,
            mutation=lambda rows: rows[3].__setitem__("torso_tilt_rad", float("nan")),
        )
        with self.assertRaisesRegex(TraceLineageError, "TRACE_LINEAGE_ROW_TORSO_TILT_RAD"):
            self._run(manifest)

    def test_contact_identity_mutation_fails_closed(self) -> None:
        def mutate(rows: list[dict[str, Any]]) -> None:
            del rows[3]["ordered_foot_contacts"]["rear_right"]

        manifest = self._manifest(complete_commands=False, mutation=mutate)
        with self.assertRaisesRegex(TraceLineageError, "TRACE_LINEAGE_FOOT_CONTACT_IDENTITY"):
            self._run(manifest)

    def test_payload_mutation_fails_digest_gate(self) -> None:
        manifest = self._manifest(complete_commands=False)
        positive = manifest["cells"][1]
        digest = positive["trace_sha256"][7:]
        payload = self.evidence / "artifacts" / "sha256" / digest / "payload.bin"
        payload.write_bytes(payload.read_bytes() + b"x")
        with self.assertRaisesRegex(TraceLineageError, "TRACE_LINEAGE_CAS_PAYLOAD_LENGTH"):
            self._run(manifest)

    def test_claim_escalation_mutation_fails_closed(self) -> None:
        manifest = self._manifest(complete_commands=False)
        manifest["claim_limits"]["turning_validation"] = True
        with self.assertRaisesRegex(TraceLineageError, "TRACE_LINEAGE_CLAIM_LIMITS"):
            self._run(manifest)


if __name__ == "__main__":
    unittest.main()
