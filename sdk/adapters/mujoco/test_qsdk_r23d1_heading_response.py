from __future__ import annotations

import unittest
from unittest.mock import patch

from sporespore_mujoco_adapter.qsdk_r23d1_heading_response import (
    HOST_PROFILE_ID,
    QsdkR23d1WorkerError,
    run_physical,
    run_preflight,
)


class QsdkR23d1HeadingResponseTests(unittest.TestCase):
    def test_all_three_arms_cross_the_native_zero_world_route(self) -> None:
        expected_offsets = {
            "reference_zero": 0.0,
            "positive_heading": 0.2,
            "negative_heading": -0.2,
        }
        held: dict[str, float] = {}
        for arm_id, expected_offset in expected_offsets.items():
            with self.subTest(arm_id=arm_id):
                with patch(
                    "sporespore_mujoco_adapter.qsdk_r23d1_heading_response."
                    "bridge.MujocoBw19vRobot",
                    side_effect=AssertionError("preflight constructed a robot"),
                ):
                    receipt = run_preflight(arm_id)
                native = receipt["native_heading_preflight"]
                validation = native["command_validation_receipt"]
                model_xml = native["model_xml_receipt"]
                report = receipt["production_normalized_report"]
                self.assertTrue(receipt["ok"])
                self.assertEqual(receipt["engine_id"], "mujoco")
                self.assertEqual(receipt["arm_id"], arm_id)
                self.assertEqual(receipt["turn_heading_offset_rad"], expected_offset)
                self.assertEqual(receipt["actual_world_build_count"], 0)
                self.assertEqual(receipt["model_construction_count"], 0)
                self.assertFalse(receipt["locomotion_outcome_exposed"])
                self.assertFalse(receipt["physical_execution_authorized"])
                self.assertFalse(receipt["q_sdk_r23_satisfied"])
                self.assertEqual(native["native_controller_command_count"], 8)
                self.assertEqual(native["actual_world_build_count"], 0)
                self.assertEqual(native["model_construction_count"], 0)
                self.assertEqual(
                    native["host_mapping"]["host_profile_id"], HOST_PROFILE_ID
                )
                self.assertEqual(
                    native["host_mapping"]["native_position_stiffness"], 0.0
                )
                self.assertTrue(validation["heading_command_conditioned"])
                self.assertFalse(validation["legacy_command_parity_applicable"])
                self.assertFalse(validation["legacy_command_parity_checked"])
                self.assertFalse(validation["legacy_command_parity_waived"])
                self.assertEqual(model_xml["native_actuator_count"], 8)
                self.assertTrue(model_xml["native_actuator_order_exact"])
                self.assertEqual(model_xml["model_construction_count"], 0)
                self.assertEqual(
                    report["schema_version"],
                    "sporespore_qsdk_r23d1_engine_cell_report_v2",
                )
                self.assertEqual(report["source_commit"], "0" * 40)
                self.assertFalse(report["claims"]["q_sdk_r23_satisfied"])
                held[arm_id] = float(
                    native["controller_receipt"]["held_steering_fraction"]
                )
        self.assertEqual(held["reference_zero"], 0.0)
        self.assertLess(held["positive_heading"], 0.0)
        self.assertGreater(held["negative_heading"], 0.0)
        self.assertAlmostEqual(
            held["positive_heading"], -held["negative_heading"], places=12
        )

    def test_unknown_arm_fails_before_world_construction(self) -> None:
        with self.assertRaises(QsdkR23d1WorkerError) as caught:
            run_preflight("undeclared_arm")
        self.assertEqual(
            caught.exception.code,
            "QSDK_R23D1_MJC_ARM_UNKNOWN:undeclared_arm",
        )
        self.assertEqual(caught.exception.world_attempt_count, 0)
        self.assertEqual(caught.exception.world_build_count, 0)

    def test_direct_physical_bypass_fails_before_world_construction(self) -> None:
        with self.assertRaises(QsdkR23d1WorkerError) as caught:
            run_physical("reference_zero", "0" * 40)
        self.assertEqual(
            caught.exception.code,
            "QSDK_R23D1_MJC_PHYSICAL_IDENTITY_CLOSED",
        )
        self.assertEqual(caught.exception.world_attempt_count, 0)
        self.assertEqual(caught.exception.world_build_count, 0)


if __name__ == "__main__":
    unittest.main()
