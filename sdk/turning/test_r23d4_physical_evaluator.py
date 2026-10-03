"""Zero-world tests for the cold QSDK-R23D4 physical evaluator."""

from __future__ import annotations

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path

from . import r23d4_physical_evaluator as evaluator
from . import r23d4_terminal_stabilization as design


class R23D4PhysicalEvaluatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._temporary = tempfile.TemporaryDirectory(prefix="r23d4-evaluator-")
        cls.root = Path(cls._temporary.name)
        cls.attempt_root = cls.root / "attempt"
        cls.evidence_root = cls.root / "evidence"
        cls.attempt_root.mkdir(parents=True)
        cls.evidence_root.mkdir(parents=True)
        cls.retained: dict[str, dict] = {}
        for cell in design.all_cells():
            rows_path = cls.root / f"{cell.cell_id}.json"
            rows_path.write_text(
                json.dumps(design.synthetic_trace(cell), allow_nan=False),
                encoding="utf-8",
            )
            cls.retained[cell.cell_id] = evaluator.retain_trace(
                stage_id=cell.stage_id,
                cell_id=cell.cell_id,
                rows_json_path=rows_path,
                repo_root=evaluator.REPO_ROOT,
                attempt_root=cls.attempt_root,
                powershell="pwsh",
                test_only=True,
                evidence_root_override=cls.evidence_root,
            )

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temporary.cleanup()

    def _report(self, cell: design.Cell, *, passing: bool = True) -> dict:
        active_commands = design.ACTIVE_STEPS * design.ACTUATOR_COUNT
        measurements = {
            "final_forward_displacement_m": 1.0,
            "turn_phase_yaw_delta_rad": (
                0.0
                if cell.arm_id == "reference_zero"
                else cell.turn_heading_offset_rad * 0.5
            ),
            "maximum_absolute_requested_steering_fraction": 0.2,
            "maximum_absolute_held_steering_fraction": 0.2,
            "maximum_tilt_rad": 0.2 if passing else 0.7,
            "minimum_torso_height_m": 0.4,
            "contact_cycle_count_by_limb": {
                limb_id: 2 for limb_id in sorted(design.LIMB_IDS)
            },
            "torso_ground_contact_step_count": 0,
            "controller_error_count": 0,
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_restoration_step_count": design.RESTORATION_STEPS,
            "passive_settle_step_count": design.PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": active_commands,
            "native_actuation_application_count": active_commands,
            "passive_native_actuation_application_count": 0,
            "restoration_receipt_count": design.RESTORATION_STEPS,
            "terminal_receipt_validation_failure_count": 0,
            "first_all_four_contact_restoration_step": 0,
            "consecutive_all_four_contact_hold_step_count": design.CONTACT_HOLD_STEPS,
            "captured_pose_memory_transition_count": design.ACTUATOR_COUNT,
            "captured_pose_memory_transition_failure_count": 0,
            "maximum_absolute_restoration_joint_velocity_rad_s": 0.35,
            "heading_correction_receipt_count": design.RESTORATION_STEPS,
            "passive_settle_trace_row_count": design.PASSIVE_SETTLE_STEPS,
        }
        execution = {
            "integrity_passed": True,
            "worker_failure_code": "",
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_restoration_step_count": design.RESTORATION_STEPS,
            "passive_settle_step_count": design.PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": active_commands,
            "native_actuation_application_count": active_commands,
            "passive_native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": True,
            "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        }
        godot = None
        if cell.engine_id == "godot_jolt":
            godot = evaluator.project_godot_execution_predicates(
                {
                    "engine_id": "godot_jolt",
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                    "controller_semantic_step_count": design.CONTROLLER_STEPS,
                    "terminal_restoration_step_count": design.RESTORATION_STEPS,
                    "passive_settle_step_count": design.PASSIVE_SETTLE_STEPS,
                    "validated_portable_command_count": active_commands,
                    "native_actuation_application_count": active_commands,
                    "passive_native_actuation_application_count": 0,
                    "trace_row_count": design.TOTAL_TRACE_STEPS,
                    "fixed_horizon_configuration_proved_before_fixture_insertion": True,
                }
            )
        retained = self.retained[cell.cell_id]
        return {
            "schema_version": evaluator.REPORT_SCHEMA,
            "campaign_id": design.CAMPAIGN_ID,
            "gate_id": design.GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": cell.engine_id,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": "1" * 40,
            "trace_artifact": copy.deepcopy(retained["trace_artifact"]),
            "trace_summary": copy.deepcopy(retained["trace_summary"]),
            "execution": execution,
            "measurements": measurements,
            "godot_execution_predicates": godot,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }

    def test_every_cell_report_is_independently_accepted(self) -> None:
        for cell in design.all_cells():
            result = evaluator.evaluate_entry(
                self._report(cell), cell, allow_test_artifacts=True
            )
            self.assertTrue(result["entry_valid"], result["failure_codes"])
            self.assertTrue(result["outcome"]["outcome_gate_passed"])

    def test_stage_a_selected_none_and_invalid_are_distinct(self) -> None:
        cells = design.stage_a_cells()
        selected = evaluator.evaluate_stage_a_entries(
            [self._report(cell) for cell in cells], allow_test_artifacts=True
        )
        self.assertEqual(selected["classification"], "valid_selected_stage_a")
        self.assertTrue(selected["stage_b_launch_authorized"])

        none = evaluator.evaluate_stage_a_entries(
            [self._report(cells[0]), self._report(cells[1], passing=False)],
            allow_test_artifacts=True,
        )
        self.assertEqual(none["classification"], "valid_none_stage_a")
        self.assertEqual(none["selected_terminal_restoration_policy_id"], "NONE")
        self.assertFalse(none["stage_b_launch_authorized"])

        invalid = evaluator.evaluate_stage_a_entries(
            [self._report(cells[0])], allow_test_artifacts=True
        )
        self.assertEqual(invalid["classification"], "invalid_or_incomplete_stage_a")
        self.assertEqual(invalid["selected_terminal_restoration_policy_id"], "INVALID")

    def test_complete_positive_and_valid_negative_are_distinct(self) -> None:
        stage_a = [self._report(cell) for cell in design.stage_a_cells()]
        stage_b = [self._report(cell) for cell in design.stage_b_cells()]
        positive = evaluator.evaluate_complete_entries(
            stage_a, stage_b, allow_test_artifacts=True
        )
        self.assertEqual(positive["classification"], "valid_complete_positive")
        self.assertEqual(positive["world_build_count"], 11)

        negative = copy.deepcopy(stage_b)
        negative[-1]["measurements"]["maximum_tilt_rad"] = 0.7
        result = evaluator.evaluate_complete_entries(
            stage_a, negative, allow_test_artifacts=True
        )
        self.assertEqual(result["classification"], "valid_complete_negative")
        self.assertEqual(result["stage_b"]["outcome_failure_count"], 1)

    def test_worker_cannot_author_outcome_or_restoration_gate(self) -> None:
        cell = design.stage_a_cells()[0]
        report = self._report(cell)
        report["measurements"]["maximum_absolute_restoration_joint_velocity_rad_s"] = (
            0.350000000002
        )
        result = evaluator.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertTrue(result["entry_valid"])
        self.assertFalse(result["outcome"]["outcome_gate_passed"])
        self.assertIn(
            "R23D4_RESTORATION_JOINT_VELOCITY",
            result["outcome"]["failed_gate_ids"],
        )
        self.assertNotIn("outcome", report)

    def test_trace_and_execution_counters_must_agree(self) -> None:
        cell = design.stage_a_cells()[0]
        report = self._report(cell)
        report["measurements"]["terminal_restoration_step_count"] -= 1
        result = evaluator.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertFalse(result["entry_valid"])
        self.assertTrue(
            any("MEASUREMENT_EXECUTION" in code for code in result["failure_codes"])
        )

    def test_test_artifact_requires_explicit_test_mode(self) -> None:
        cell = design.stage_a_cells()[0]
        result = evaluator.evaluate_entry(self._report(cell), cell)
        self.assertFalse(result["entry_valid"])
        self.assertIn("R23D4_TRACE_ARTIFACT_RECEIPT", result["failure_codes"])

    def test_godot_predicates_are_recomputed(self) -> None:
        cell = design.stage_b_cells()[0]
        report = self._report(cell)
        report["godot_execution_predicates"]["checks"]["trace_horizon"] = False
        result = evaluator.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertFalse(result["entry_valid"])
        self.assertIn("R23D4_REPORT_GODOT_PREDICATES", result["failure_codes"])

    def test_exact_empty_manifest_runs_through_cli_and_blank_manifest_fails(self) -> None:
        cells = design.stage_a_cells()
        reports = [self._report(cells[0]), self._report(cells[1], passing=False)]
        paths: list[str] = []
        for index, report in enumerate(reports):
            path = self.root / f"stage-a-{index}.json"
            path.write_text(json.dumps(report), encoding="utf-8")
            paths.append(str(path))
        stage_a_manifest = self.root / "stage-a-manifest.json"
        stage_b_manifest = self.root / "stage-b-empty.json"
        stage_a_manifest.write_bytes(evaluator.design.serialize_terminal_paths(paths))
        stage_b_manifest.write_bytes(b"[]\n")

        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            exit_code = evaluator.main(
                [
                    "evaluate-complete",
                    "--stage-a-manifest",
                    str(stage_a_manifest),
                    "--stage-b-manifest",
                    str(stage_b_manifest),
                    "--allow-test-artifacts",
                ]
            )
        self.assertEqual(exit_code, 0)
        self.assertTrue(output.getvalue().startswith("QSDK_R23D4_COMPLETE_EVALUATION "))
        self.assertIn('"classification":"valid_none_stage_a"', output.getvalue())

        stage_b_manifest.write_bytes(b"\n")
        error = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(error):
            exit_code = evaluator.main(
                [
                    "evaluate-complete",
                    "--stage-a-manifest",
                    str(stage_a_manifest),
                    "--stage-b-manifest",
                    str(stage_b_manifest),
                    "--allow-test-artifacts",
                ]
            )
        self.assertEqual(exit_code, 1)
        self.assertIn("R23D4_PHYSICAL_EVALUATOR_FAILURE", error.getvalue())


if __name__ == "__main__":
    unittest.main()
