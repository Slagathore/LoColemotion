"""Zero-world tests for the dormant MuJoCo R23D22 physical worker."""

from __future__ import annotations

import os
import unittest
from unittest import mock

from sporespore_mujoco_adapter import (
    qsdk_r23d13_residual_pose_authority_physical as predecessor,
)
from sporespore_mujoco_adapter import qsdk_r23d22_physical as physical


class R23D22MujocoPhysicalZeroWorldTests(unittest.TestCase):
    def test_all_three_mujoco_matrix_identities_preflight_without_world(self) -> None:
        for arm_id in physical.design.MATRIX_ARMS:
            with self.subTest(arm_id=arm_id):
                receipt = physical.worker_preflight(
                    physical.design.MATRIX_STAGE_ID, arm_id
                )
                self.assertEqual(receipt["engine_id"], "mujoco")
                self.assertEqual(receipt["arm_id"], arm_id)
                self.assertTrue(receipt["physical_worker_implemented"])
                self.assertTrue(
                    receipt["physical_worker_dormant_behind_supervisor_authorization"]
                )
                self.assertFalse(receipt["physical_execution_authorized"])
                self.assertEqual(receipt["model_construction_count"], 0)
                self.assertEqual(receipt["world_attempt_count"], 0)
                self.assertEqual(receipt["world_build_count"], 0)

    def test_private_rebinding_does_not_mutate_r23d13_worker(self) -> None:
        self.assertEqual(predecessor.GATE_ID, "QSDK-R23D13")
        self.assertEqual(predecessor.design.TERMINAL_STEPS, 900)
        self.assertEqual(physical.GATE_ID, "QSDK-R23D22")
        self.assertEqual(physical.design.TERMINAL_STEPS, 960)
        self.assertIsNot(predecessor, physical._core)

    def test_physical_route_refuses_before_model_without_authorization(self) -> None:
        environment_names = (
            physical.FREEZE_PATH_ENV,
            physical.ATTEMPT_PATH_ENV,
            physical.AUTHORIZATION_TOKEN_ENV,
            physical.STAGE_ID_ENV,
            physical.CELL_ID_ENV,
            physical.ENGINE_ID_ENV,
            physical.ATTEMPT_ROOT_ENV,
        )
        environment = dict(os.environ)
        for name in environment_names:
            environment.pop(name, None)
        with mock.patch.dict(os.environ, environment, clear=True):
            with self.assertRaises(physical.R23D22MujocoPhysicalError) as raised:
                physical.run_physical(
                    physical.design.MATRIX_STAGE_ID,
                    "positive_heading",
                    "a" * 40,
                )
        error = raised.exception
        self.assertEqual(
            error.code, "QSDK_R23D22_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
        self.assertEqual(error.world_attempt_count, 0)
        self.assertEqual(error.world_build_count, 0)
        self.assertIsNotNone(error.terminal_receipt)
        self.assertEqual(error.terminal_receipt["failure_stage"], "before_world")

    def test_unknown_identity_fails_closed(self) -> None:
        with self.assertRaises(physical.R23D22MujocoPhysicalError) as raised:
            physical.worker_preflight(
                physical.design.MATRIX_STAGE_ID, "unknown_arm"
            )
        self.assertIn("CELL_IDENTITY_INVALID", raised.exception.code)


if __name__ == "__main__":
    unittest.main()
