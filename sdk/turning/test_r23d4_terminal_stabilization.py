"""Zero-world tests for the prospective QSDK-R23D4 design."""

from __future__ import annotations

import copy
import json
import unittest

from . import r23d4_terminal_stabilization as r23d4


class R23D4TerminalStabilizationTests(unittest.TestCase):
    def test_contract_and_cell_order_are_frozen(self) -> None:
        contract = r23d4.load_contract()
        self.assertEqual(contract["gate_id"], "QSDK-R23D4")
        self.assertEqual(
            [cell.cell_id for cell in r23d4.stage_a_cells()],
            [
                "mujoco__terminal_restoration__positive_heading",
                "mujoco__terminal_restoration__negative_heading",
            ],
        )
        self.assertEqual(len(r23d4.stage_b_cells()), 9)
        self.assertEqual(len(r23d4.all_cells()), 11)

    def test_schedule_keeps_active_and_passive_phases_distinct(self) -> None:
        cell = r23d4.stage_a_cells()[0]
        expected = [
            (0, "reference_warmup", 0),
            (599, "reference_warmup", 599),
            (600, "commanded_turn", 600),
            (1799, "commanded_turn", 1799),
            (1800, "reference_recovery", 1800),
            (2399, "reference_recovery", 2399),
            (2400, "reference_continuation", 2400),
            (2991, "reference_continuation", 2991),
            (2992, "terminal_contact_acquisition", None),
            (3171, "terminal_contact_acquisition", None),
            (3172, "terminal_captured_pose_hold", None),
            (3531, "terminal_captured_pose_hold", None),
            (3532, "passive_zero_actuation_settle", None),
            (3771, "passive_zero_actuation_settle", None),
        ]
        for step, phase, controller_step in expected:
            observed = r23d4.phase_for_trace_step(cell, step)
            self.assertEqual(observed[0], phase)
            self.assertEqual(observed[1], controller_step)
        self.assertEqual(sum(r23d4.expected_phase_counts().values()), 3772)

    def test_complete_synthetic_traces_validate(self) -> None:
        for cell in r23d4.all_cells():
            result = r23d4.validate_trace(cell, r23d4.synthetic_trace(cell))
            self.assertTrue(result["ok"], result["failure_codes"][:3])
            self.assertEqual(result["row_count"], 3772)
            self.assertEqual(result["phase_counts"], r23d4.expected_phase_counts())

    def test_trace_rejects_passive_actuation_and_missing_restoration_receipt(
        self,
    ) -> None:
        cell = r23d4.stage_a_cells()[0]
        passive_actuation = r23d4.synthetic_trace(cell)
        passive_actuation[r23d4.ACTIVE_STEPS]["native_actuation_application_count"] = 8
        self.assertFalse(r23d4.validate_trace(cell, passive_actuation)["ok"])

        missing_receipt = r23d4.synthetic_trace(cell)
        missing_receipt[r23d4.CONTROLLER_STEPS]["restoration_receipt_present"] = False
        self.assertFalse(r23d4.validate_trace(cell, missing_receipt)["ok"])

    def test_stage_a_selected_none_and_invalid_are_distinct(self) -> None:
        cells = r23d4.stage_a_cells()
        selected = r23d4.evaluate_stage_a(
            [r23d4.synthetic_report(cell) for cell in cells]
        )
        self.assertEqual(selected["classification"], "valid_selected_stage_a")
        self.assertTrue(selected["stage_b_launch_authorized"])

        none_reports = [r23d4.synthetic_report(cell) for cell in cells]
        none_reports[1] = r23d4.synthetic_report(cells[1], passing=False)
        none_result = r23d4.evaluate_stage_a(none_reports)
        self.assertEqual(none_result["classification"], "valid_none_stage_a")
        self.assertEqual(none_result["selected_terminal_restoration_policy_id"], "NONE")
        self.assertFalse(none_result["stage_b_launch_authorized"])

        invalid = r23d4.evaluate_stage_a(none_reports[:1])
        self.assertEqual(invalid["classification"], "invalid_or_incomplete_stage_a")
        self.assertEqual(invalid["selected_terminal_restoration_policy_id"], "INVALID")

    def test_worker_authored_outcome_bits_are_not_authority(self) -> None:
        cells = r23d4.stage_a_cells()
        reports = [r23d4.synthetic_report(cell) for cell in cells]
        reports[0]["outcome"]["outcome_gate_passed"] = False
        result = r23d4.evaluate_stage_a(reports)
        self.assertFalse(result["valid"])
        self.assertTrue(
            any(
                "R23D4_REPORT_OUTCOME_RECOMPUTE" in code
                for code in result["failure_codes"]
            )
        )

    def test_every_frozen_outcome_gate_is_recomputed(self) -> None:
        cell = r23d4.stage_a_cells()[1]
        mutations = {
            "turn_phase_yaw_delta_rad": 0.1,
            "maximum_absolute_steering_fraction": 0.5,
            "final_forward_displacement_m": 0.0,
            "maximum_tilt_rad": 0.7,
            "minimum_torso_height_m": 0.2,
            "contact_cycle_count_by_limb": {
                "rear_left": 1,
                "front_left": 2,
                "rear_right": 2,
                "front_right": 2,
            },
            "torso_ground_contact_step_count": 1,
            "controller_error_count": 1,
            "active_safe_no_actuation_count": 1,
            "nonfinite_observation_count": 1,
            "actuator_application_mismatch_count": 1,
            "native_actuation_application_count": 1,
            "first_all_four_contact_restoration_step": 180,
            "consecutive_all_four_contact_hold_step_count": 359,
            "captured_pose_memory_valid": False,
            "bounded_joint_velocity_valid": False,
            "heading_correction_receipt_valid": False,
            "passive_native_actuation_application_count": 1,
            "passive_settle_trace_row_count": 239,
        }
        for key, value in mutations.items():
            report = r23d4.synthetic_report(cell)
            report["measurements"][key] = copy.deepcopy(value)
            report["outcome"]["outcome_gate_passed"] = False
            report["outcome"]["failed_gate_ids"] = r23d4._outcome_failures(
                cell, report["measurements"]
            )
            result = r23d4.evaluate_stage_a(
                [r23d4.synthetic_report(r23d4.stage_a_cells()[0]), report]
            )
            self.assertEqual(result["classification"], "valid_none_stage_a", key)

    def test_empty_manifest_and_transport_repair_are_exercised(self) -> None:
        empty = r23d4.serialize_terminal_paths([])
        self.assertEqual(empty, b"[]\n")
        self.assertEqual(json.loads(empty), [])
        self.assertTrue(
            r23d4.evaluator_transport_decision(
                stdout="marker",
                stderr="",
                exit_code=0,
                output_manifest_retained=True,
            )["marker_parse_authorized"]
        )
        self.assertFalse(
            r23d4.evaluator_transport_decision(
                stdout="",
                stderr="parse error",
                exit_code=1,
                output_manifest_retained=True,
            )["marker_parse_authorized"]
        )

    def test_preflight_remains_zero_world_and_claim_false(self) -> None:
        receipt = r23d4.run_preflight()
        self.assertEqual(receipt["trace_validation_count"], 11)
        self.assertEqual(receipt["trace_row_validation_count"], 41492)
        self.assertEqual(receipt["trace_negative_control_rejection_count"], 8)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertFalse(receipt["command_conditioned_turning"])
        self.assertFalse(receipt["q_sdk_r23_satisfied"])


if __name__ == "__main__":
    unittest.main()
