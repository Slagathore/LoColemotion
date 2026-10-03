"""Zero-world production-evaluator tests for QSDK-R23D9."""

from __future__ import annotations

import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import r23d9_physical_evaluator as evaluator
import r23d9_support_handoff as design


class R23D9PhysicalEvaluatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._temporary = tempfile.TemporaryDirectory(prefix="r23d9-evaluator-")
        cls.root = Path(cls._temporary.name)
        cls.evidence_root = cls.root / "evidence"
        cls.evidence_root.mkdir()
        cls.powershell = shutil.which("pwsh")
        if not cls.powershell:
            raise RuntimeError("pwsh is required for the R23D9 CAS tests")
        cls.reports: dict[tuple[str, str], dict[str, object]] = {}
        for cell in design.all_cells():
            attempt = cls.root / "attempts" / cell.stage_id / cell.cell_id
            attempt.mkdir(parents=True)
            rows_path = attempt / "rows.json"
            rows_path.write_text(
                json.dumps(design.synthetic_trace(cell), allow_nan=False),
                encoding="utf-8",
            )
            retained = evaluator.retain_trace(
                stage_id=cell.stage_id,
                cell_id=cell.cell_id,
                rows_json_path=rows_path,
                repo_root=evaluator.REPO_ROOT,
                attempt_root=attempt,
                powershell=cls.powershell,
                test_only=True,
                evidence_root_override=cls.evidence_root,
            )
            cls.reports[(cell.stage_id, cell.cell_id)] = cls._report(
                cell, retained
            )

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temporary.cleanup()

    @staticmethod
    def _report(
        cell: design.Cell, retained: dict[str, object]
    ) -> dict[str, object]:
        summary = copy.deepcopy(retained["trace_summary"])
        replay = summary["handoff_outcome"]
        applications = (
            design.CONTROLLER_STEPS + replay["active_step_count"]
        ) * design.ACTUATOR_COUNT
        execution = {
            "integrity_passed": True,
            "worker_failure_code": "",
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_support_handoff_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": applications,
            "native_actuation_application_count": applications,
            "post_handoff_native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": True,
            "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        }
        measurements = {
            "final_forward_displacement_m": 1.0,
            "turn_phase_yaw_delta_rad": (
                0.0
                if cell.arm_id == "reference_zero"
                else cell.turn_heading_offset_rad * 0.5
            ),
            "maximum_absolute_requested_steering_fraction": 0.2,
            "maximum_absolute_held_steering_fraction": 0.2,
            "maximum_tilt_rad": 0.2,
            "minimum_torso_height_m": 0.4,
            "contact_cycle_count_by_limb": {
                limb: 2 for limb in design.LIMB_IDS
            },
            "torso_ground_contact_step_count": 0,
            "controller_error_count": 0,
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_support_handoff_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": applications,
            "native_actuation_application_count": applications,
            "post_handoff_native_actuation_application_count": 0,
            "support_confirmed": replay["support_confirmed"],
            "handoff_after_active_step": replay["handoff_after_active_step"],
            "first_passive_step": replay["first_passive_step"],
            "handoff_reason": replay["handoff_reason"],
            "active_terminal_step_count": replay["active_step_count"],
            "passive_terminal_step_count": replay["passive_step_count"],
            "first_post_handoff_contact_loss_step": replay[
                "first_post_handoff_contact_loss_step"
            ],
            "post_handoff_contact_loss_step_count": replay[
                "post_handoff_contact_loss_step_count"
            ],
            "terminal_receipt_validation_failure_count": 0,
            "maximum_absolute_terminal_active_joint_velocity_rad_s": 0.35,
        }
        return {
            "schema_version": evaluator.REPORT_SCHEMA,
            "campaign_id": evaluator.CAMPAIGN_ID,
            "gate_id": evaluator.GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": cell.engine_id,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": "a" * 40,
            "trace_artifact": copy.deepcopy(retained["trace_artifact"]),
            "trace_summary": summary,
            "execution": execution,
            "measurements": measurements,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }

    def _stage_a(self) -> list[dict[str, object]]:
        return [
            copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
            for cell in design.stage_a_cells()
        ]

    def _stage_b(self) -> list[dict[str, object]]:
        return [
            copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
            for cell in design.stage_b_cells()
        ]

    def test_trace_retention_is_content_addressed_and_replayed(self) -> None:
        cell = design.stage_a_cells()[0]
        report = copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
        evaluation = evaluator.evaluate_entry(
            report, cell, allow_test_artifacts=True
        )
        self.assertTrue(evaluation["entry_valid"], evaluation["failure_codes"])
        self.assertTrue(evaluation["outcome"]["outcome_gate_passed"])

    def test_stage_a_selects_only_when_both_signed_cells_pass(self) -> None:
        result = evaluator.evaluate_stage_a_entries(
            self._stage_a(), allow_test_artifacts=True
        )
        self.assertTrue(result["valid"])
        self.assertEqual(result["classification"], "valid_selected_stage_a")
        self.assertEqual(result["selected_terminal_policy_id"], design.POLICY_ID)
        self.assertTrue(result["stage_b_launch_authorized"])

    def test_valid_stage_a_none_preserves_negative_without_stage_b(self) -> None:
        entries = self._stage_a()
        entries[1]["measurements"]["final_forward_displacement_m"] = 0.0
        result = evaluator.evaluate_complete_entries(
            entries, [], allow_test_artifacts=True
        )
        self.assertEqual(result["classification"], "valid_none_stage_a")
        self.assertFalse(result["stage_a"]["stage_b_launch_authorized"])
        self.assertIsNone(result["stage_b"])

    def test_complete_eleven_cell_positive_is_exact(self) -> None:
        result = evaluator.evaluate_complete_entries(
            self._stage_a(), self._stage_b(), allow_test_artifacts=True
        )
        self.assertEqual(result["classification"], "valid_complete_positive")
        self.assertEqual(result["world_build_count"], 11)
        self.assertEqual(result["stage_b"]["outcome_failure_count"], 0)

    def test_stage_b_after_valid_none_is_invalid(self) -> None:
        entries = self._stage_a()
        entries[0]["measurements"]["maximum_tilt_rad"] = 0.7
        result = evaluator.evaluate_complete_entries(
            entries, self._stage_b(), allow_test_artifacts=True
        )
        self.assertEqual(
            result["classification"], "invalid_or_incomplete_complete_campaign"
        )
        self.assertIn("R23D9_STAGE_B_OPENED_AFTER_VALID_NONE", result["failure_codes"])

    def test_trace_summary_or_measurement_rewrite_is_rejected(self) -> None:
        cell = design.stage_a_cells()[0]
        report = copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
        report["trace_summary"]["handoff_outcome"]["first_passive_step"] = 31
        result = evaluator.evaluate_entry(report, cell, allow_test_artifacts=True)
        self.assertFalse(result["entry_valid"])
        self.assertIn("R23D9_REPORT_TRACE_SUMMARY", result["failure_codes"])

        report = copy.deepcopy(self.reports[(cell.stage_id, cell.cell_id)])
        report["measurements"]["active_terminal_step_count"] = 31
        result = evaluator.evaluate_entry(report, cell, allow_test_artifacts=True)
        self.assertTrue(result["entry_valid"])
        self.assertFalse(result["outcome"]["outcome_gate_passed"])
        self.assertIn(
            "R23D9_HANDOFF_REPLAY:active_terminal_step_count",
            result["outcome"]["failed_gate_ids"],
        )

    def test_failure_entry_is_validly_retained_but_not_selected(self) -> None:
        cell = design.stage_a_cells()[0]
        failure = {
            "schema_version": evaluator.FAILURE_SCHEMA,
            "campaign_id": evaluator.CAMPAIGN_ID,
            "gate_id": evaluator.GATE_ID,
            "stage_id": cell.stage_id,
            "cell_id": cell.cell_id,
            "engine_id": cell.engine_id,
            "arm_id": cell.arm_id,
            "turn_heading_offset_rad": cell.turn_heading_offset_rad,
            "source_commit": "b" * 40,
            "failure_stage": "before_world",
            "failure_code": "SYNTHETIC_FAILURE",
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": None,
            "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
        }
        evaluation = evaluator.evaluate_entry(failure, cell)
        self.assertEqual(evaluation["entry_kind"], "worker_failure")
        self.assertFalse(evaluation["entry_valid"])
        self.assertEqual(evaluation["failure_codes"], ["SYNTHETIC_FAILURE"])

    def test_identity_order_duplicates_and_unknown_fields_fail_closed(self) -> None:
        reversed_entries = list(reversed(self._stage_a()))
        result = evaluator.evaluate_stage_a_entries(
            reversed_entries, allow_test_artifacts=True
        )
        self.assertFalse(result["valid"])
        self.assertIn("R23D9_STAGE_A_ORDER_OR_IDENTITY", result["failure_codes"])

        entry = self._stage_a()[0]
        entry["undeclared"] = True
        evaluation = evaluator.evaluate_entry(
            entry, design.stage_a_cells()[0], allow_test_artifacts=True
        )
        self.assertFalse(evaluation["entry_valid"])
        self.assertIn("R23D9_REPORT_FIELDS", evaluation["failure_codes"])


if __name__ == "__main__":
    unittest.main()
