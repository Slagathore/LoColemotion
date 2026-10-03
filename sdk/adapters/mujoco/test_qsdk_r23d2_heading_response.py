from __future__ import annotations

import math
import unittest
from unittest import mock

from sporespore_mujoco_adapter.qsdk_r23d2_heading_response import (
    HOST_PROFILE_ID,
    QsdkR23d2MujocoPhysicalFailure,
    QsdkR23d2MujocoWorkerError,
    run_physical,
    run_preflight,
)


class QsdkR23d2HeadingResponseTests(unittest.TestCase):
    def test_all_arms_cross_oracle_mapping_xml_and_signed_command_boundary(
        self,
    ) -> None:
        expected_offsets = {
            "reference_zero": 0.0,
            "positive_heading": 0.2,
            "negative_heading": -0.2,
        }
        for arm_id, expected_offset in expected_offsets.items():
            with self.subTest(arm_id=arm_id):
                with mock.patch(
                    "mujoco.MjModel.from_xml_string",
                    side_effect=AssertionError("preflight constructed an MjModel"),
                ):
                    report = run_preflight(arm_id)
                self.assertEqual(report["arm_id"], arm_id)
                self.assertEqual(report["host_profile_id"], HOST_PROFILE_ID)
                self.assertEqual(report["canary_count"], 7)
                self.assertEqual(report["nonzero_cross_track_canary_count"], 6)
                self.assertEqual(report["legacy_raw_offset_oracle_rejection_count"], 6)
                self.assertEqual(report["predicate_negative_control_count"], 35)
                self.assertEqual(report["native_controller_step_count"], 8)
                self.assertEqual(report["native_command_count"], 64)
                self.assertEqual(report["host_mapping_validation_count"], 8)
                self.assertEqual(report["model_xml_validation_count"], 1)
                self.assertEqual(report["model_construction_count"], 0)
                self.assertEqual(report["world_build_count"], 0)
                self.assertTrue(report["physical_implementation_present"])
                self.assertEqual(
                    report["worker_contract_status"],
                    "mujoco_supervisor_only_physical_authorized",
                )
                self.assertEqual(
                    report["development_contract_status"],
                    "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation",
                )
                self.assertEqual(
                    report["synthetic_physical_report"]["schema_version"],
                    "sporespore_qsdk_r23d2_engine_cell_report_v1",
                )
                self.assertEqual(len(report["synthetic_failure_receipts"]), 6)
                self.assertEqual(
                    {
                        entry["stage_id"]
                        for entry in report["synthetic_failure_receipts"]
                    },
                    {
                        "before_world",
                        "world_construction_failed",
                        "world_constructed",
                        "settlement_complete",
                        "controller_validation_failed",
                        "cell_report_complete",
                    },
                )
                self.assertTrue(
                    math.isclose(
                        report["arm_command_boundary"]["desired_heading_error_rad"],
                        expected_offset,
                        rel_tol=0.0,
                        abs_tol=1.0e-12,
                    )
                )

    def test_unknown_arm_and_direct_physical_bypass_fail_closed(self) -> None:
        with self.assertRaisesRegex(
            QsdkR23d2MujocoWorkerError,
            "QSDK_R23D2_MJC_ARM_UNKNOWN:undeclared_arm",
        ):
            run_preflight("undeclared_arm")
        with mock.patch(
            "sporespore_mujoco_adapter.qsdk_r23d2_heading_response."
            "bridge.MujocoBw19vRobot",
            side_effect=AssertionError("authorization bypass constructed a model"),
        ) as constructor:
            with self.assertRaises(QsdkR23d2MujocoPhysicalFailure) as caught:
                run_physical("reference_zero", "0" * 40)
        constructor.assert_not_called()
        failure = caught.exception.receipt
        self.assertEqual(
            failure["process_failure_code"],
            "QSDK_R23D2_MJC_PHYSICAL_IDENTITY_CLOSED",
        )
        self.assertEqual(failure["stage_id"], "before_world")
        self.assertEqual(failure["world_attempt_count"], 0)
        self.assertEqual(failure["world_build_count"], 0)
        self.assertIsNone(failure["rejected_controller_projection"])


if __name__ == "__main__":
    unittest.main()
