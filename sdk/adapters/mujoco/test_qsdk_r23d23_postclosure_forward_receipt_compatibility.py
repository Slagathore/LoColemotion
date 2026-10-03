"""Zero-world tests for the R23D23 post-closure receipt repair."""

from __future__ import annotations

import unittest
from unittest import mock

from sporespore_mujoco_adapter import (
    qsdk_r23d8_neutral_stance_composition as restoration,
)
from sporespore_mujoco_adapter import (
    qsdk_r23d23_postclosure_forward_receipt_compatibility as repair,
)


class R23D23PostclosureForwardReceiptCompatibilityTests(unittest.TestCase):
    def test_real_r23d21_source_shape_and_mutations_open_no_model(self) -> None:
        with mock.patch(
            "mujoco.MjModel.from_xml_string",
            side_effect=AssertionError("post-closure repair constructed a model"),
        ) as constructor:
            report = repair.run_zero_world_preflight()
        constructor.assert_not_called()

        self.assertEqual(
            report["status"], "zero_world_compatibility_repair_passed"
        )
        self.assertEqual(report["arm_count"], 3)
        self.assertEqual(report["mutation_control_count"], 22)
        self.assertTrue(all(report["mutation_controls"].values()))
        self.assertTrue(report["historical_r23d8_default_preserved"])
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physical_execution_authorized"])
        self.assertFalse(report["turning_acceptance"])
        self.assertFalse(report["physical_acceptance_authority"])

        self.assertEqual(
            {item["arm_id"] for item in report["arm_receipts"]},
            set(repair.ARM_OFFSETS),
        )
        for arm in report["arm_receipts"]:
            self.assertEqual(
                arm["controller_receipt_schema"],
                "sporespore_controller_step_receipt_v5",
            )
            self.assertEqual(
                arm["forward_receipt_schema"],
                restoration.R23D21_FORWARD_VELOCITY_RECEIPT_SCHEMA,
            )
            self.assertEqual(
                arm["forward_mode_id"],
                restoration.R23D21_FORWARD_VELOCITY_MODE_ID,
            )
            self.assertEqual(
                arm["forward_error_orientation_id"],
                restoration.R23D21_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
            )
            self.assertEqual(arm["ordered_limb_correction_count"], 4)
            self.assertEqual(
                arm["terminal_source_contract_id"], repair.SOURCE_CONTRACT_ID
            )
            self.assertTrue(arm["terminal_source_member_present"])
            self.assertEqual(arm["terminal_solution_count"], 8)

    def test_historical_r23d8_default_preflight_remains_green(self) -> None:
        report = restoration.run_zero_world_preflight()
        self.assertEqual(report["gate_id"], "QSDK-R23D8")
        self.assertEqual(report["signed_arm_count"], 2)
        self.assertTrue(
            all(
                not item["source_forward_velocity_member_present"]
                for item in report["signed_arms"]
            )
        )
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["world_build_count"], 0)


if __name__ == "__main__":
    unittest.main()
