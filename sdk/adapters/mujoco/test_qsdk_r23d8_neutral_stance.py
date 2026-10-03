
"""Zero-world tests for the QSDK-R23D8 MuJoCo worker."""

from __future__ import annotations

import os
import unittest
from unittest import mock

from sporespore_mujoco_adapter import qsdk_r23d8_neutral_stance as worker


class R23D8MujocoWorkerTests(unittest.TestCase):
    def test_all_mujoco_entrypoints_preflight_without_worlds(self) -> None:
        cases = [
            ("mujoco_neutral_stance_screen", "positive_heading"),
            ("mujoco_neutral_stance_screen", "negative_heading"),
            ("three_engine_confirmation", "reference_zero"),
            ("three_engine_confirmation", "positive_heading"),
            ("three_engine_confirmation", "negative_heading"),
        ]
        execution_identities: list[tuple[str, str]] = []
        for stage_id, arm_id in cases:
            receipt = worker.run_preflight(stage_id, arm_id)
            execution_identities.append((receipt["stage_id"], receipt["cell_id"]))
            self.assertEqual(receipt["model_construction_count"], 0)
            self.assertEqual(receipt["world_attempt_count"], 0)
            self.assertEqual(receipt["world_build_count"], 0)
            self.assertEqual(receipt["fixed_controller_horizon_step_count"], 2992)
            self.assertEqual(receipt["fixed_terminal_stance_step_count"], 540)
            self.assertEqual(receipt["fixed_passive_settle_step_count"], 240)
            self.assertEqual(receipt["fixed_total_trace_step_count"], 3772)
            self.assertEqual(receipt["neutral_stance_algebra_canary_count"], 5)
            self.assertEqual(receipt["neutral_stance_mutation_control_count"], 10)
            self.assertEqual(receipt["production_shaped_signed_arm_count"], 2)
            self.assertFalse(receipt["physical_execution_authorized"])
        # Stage A and Stage B intentionally reuse the two signed human-readable
        # neutral-stance cell labels. Authorization, evaluator lookup, retained
        # filenames, and supervisor directories all key the execution by the
        # composite (stage_id, cell_id) identity.
        self.assertEqual(len(set(execution_identities)), 5)

    def test_trace_rows_match_controller_restoration_and_passive_schema(self) -> None:
        cell = worker._cell(
            "mujoco_neutral_stance_screen", "positive_heading"
        )
        metrics = {
            "x": 0.0,
            "y": 0.4,
            "z": 0.0,
            "yaw_rad": 0.1,
            "tilt_rad": 0.1,
            "ground_contact": False,
        }
        contacts = {limb_id: True for limb_id in worker.design.LIMB_IDS}
        controller = worker._trace_row(
            cell=cell,
            trace_step=0,
            metrics=metrics,
            contacts=contacts,
            native_application_count=8,
        )
        restoration = worker._trace_row(
            cell=cell,
            trace_step=worker.design.CONTROLLER_STEPS,
            metrics=metrics,
            contacts=contacts,
            native_application_count=8,
            neutral_target_activation_count=8,
            maximum_absolute_joint_position_error_rad=0.2,
            maximum_absolute_commanded_joint_velocity_rad_s=0.35,
        )
        passive = worker._trace_row(
            cell=cell,
            trace_step=worker.design.ACTIVE_STEPS,
            metrics=metrics,
            contacts=contacts,
            native_application_count=0,
        )
        self.assertEqual(controller["command_composition_mode"], "balanced_wave_turning_v1")
        self.assertFalse(controller["restoration_receipt_present"])
        self.assertEqual(
            restoration["command_composition_mode"], worker.design.RESTORATION_POLICY_ID
        )
        self.assertTrue(restoration["restoration_receipt_present"])
        self.assertTrue(passive["zero_actuation"])
        self.assertEqual(passive["native_actuation_application_count"], 0)

    def test_direct_physical_call_refuses_before_world_construction(self) -> None:
        names = [
            worker.FREEZE_PATH_ENV,
            worker.ATTEMPT_PATH_ENV,
            worker.AUTHORIZATION_TOKEN_ENV,
            worker.ATTEMPT_ROOT_ENV,
        ]
        environment = {key: value for key, value in os.environ.items() if key not in names}
        with mock.patch.dict(os.environ, environment, clear=True):
            with self.assertRaises(worker.R23D8MujocoError) as raised:
                worker.run_physical(
                    "mujoco_neutral_stance_screen",
                    "positive_heading",
                    "0" * 40,
                )
        error = raised.exception
        self.assertEqual(
            error.code, "QSDK_R23D8_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
        self.assertEqual(error.world_attempt_count, 0)
        self.assertEqual(error.world_build_count, 0)
        self.assertIsNotNone(error.terminal_receipt)
        self.assertEqual(error.terminal_receipt["world_attempt_count"], 0)
        self.assertEqual(error.terminal_receipt["world_build_count"], 0)

    def test_cell_identity_is_exact(self) -> None:
        with self.assertRaises(worker.R23D8MujocoError):
            worker._cell("mujoco_neutral_stance_screen", "reference_zero")
        with self.assertRaises(worker.R23D8MujocoError):
            worker._cell("wrong", "positive_heading")


if __name__ == "__main__":
    unittest.main()
