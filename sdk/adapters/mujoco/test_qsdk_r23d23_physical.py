"""Zero-world tests for the dormant MuJoCo R23D23 physical worker."""

from __future__ import annotations

import os
import unittest
from unittest import mock

from sporespore_locomotion import LocomotionCore
from sporespore_mujoco_adapter import (
    qsdk_r23d13_residual_pose_authority_physical as predecessor,
)
from sporespore_mujoco_adapter import qsdk_r23d8_neutral_stance_composition as restoration
from sporespore_mujoco_adapter import qsdk_r23d23_physical as physical


class R23D23MujocoPhysicalZeroWorldTests(unittest.TestCase):
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
        self.assertEqual(physical.GATE_ID, "QSDK-R23D23")
        self.assertEqual(physical.design.TERMINAL_STEPS, 960)
        self.assertIsNot(predecessor, physical._core)

    def test_physical_route_refuses_before_model_after_closure(self) -> None:
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
            with self.assertRaises(physical.R23D23MujocoPhysicalError) as raised:
                physical.run_physical(
                    physical.design.MATRIX_STAGE_ID,
                    "positive_heading",
                    "a" * 40,
                )
        error = raised.exception
        self.assertEqual(error.code, "QSDK_R23D23_MJC_CLOSED")
        self.assertEqual(error.world_attempt_count, 0)
        self.assertEqual(error.world_build_count, 0)
        self.assertIsNotNone(error.terminal_receipt)
        self.assertEqual(error.terminal_receipt["failure_stage"], "before_world")

    def test_unknown_identity_fails_closed(self) -> None:
        with self.assertRaises(physical.R23D23MujocoPhysicalError) as raised:
            physical.worker_preflight(
                physical.design.MATRIX_STAGE_ID, "unknown_arm"
            )
        self.assertIn("CELL_IDENTITY_INVALID", raised.exception.code)

    def test_heading_aligned_nonzero_receipt_matches_core_and_rejects_legacy_axis(
        self,
    ) -> None:
        base = physical._core.inherited.base
        core = LocomotionCore()
        compiled, profile = base._compile_boundary(core)
        canary = {
            "task_lateral_axis_world_unit": [0.0, 0.0, 1.0],
            "base_position_world_m": [0.37, 0.5, 0.23],
            "base_linear_velocity_world_m_s": [0.19, 0.0, -0.11],
            "measured_heading_world_rad": 0.07,
            "task_origin_world_m": [0.0, 0.0, 0.0],
            "reference_yaw_rad": 0.0,
        }
        state = base._state_for_canary(compiled, canary)
        command = base._command("qsdk_r23d23_nonzero_receipt", 0.2)
        output = core.balanced_wave_policy_step(
            physical.CONTROLLER_POLICY_ID,
            {
                "descriptor": base.bridge.s169_descriptor(),
                "memory": core.balanced_wave_initial_memory(),
                "state": state,
                "command": command,
            },
        )
        receipt = output["actuation"]["receipt"]
        expected = base._independent_oracle(state, command, profile)
        self.assertEqual(base._predicate_failures(expected, receipt), [])

        legacy = dict(expected)
        legacy["cross_track_error_m"] = 0.23
        legacy["cross_track_velocity_m_s"] = -0.11
        legacy_desired = max(
            -0.25,
            min(
                0.25,
                0.2
                - float(profile["cross_track_heading_gain_rad_per_m"]) * 0.23
                - float(profile["cross_track_velocity_heading_gain_rad_per_m_s"])
                * -0.11,
            ),
        )
        legacy["desired_heading_error_rad"] = legacy_desired
        legacy["yaw_tracking_error_rad"] = base._wrap_angle(
            float(expected["measured_yaw_error_rad"]) - legacy_desired
        )
        self.assertNotEqual(base._predicate_failures(expected, legacy), [])
        for field in base.RECEIPT_FIELDS:
            mutated = dict(expected)
            mutated[field] += 1.0e-6
            self.assertEqual(
                base._predicate_failures(expected, mutated),
                [f"{field}:mismatch"],
            )

    def test_restoration_policy_binding_accepts_successor_and_rejects_predecessor(
        self,
    ) -> None:
        actuation = {
            "receipt": {"policy_id": physical.CONTROLLER_POLICY_ID},
            "ordered_commands": [{"actuator_id": str(index)} for index in range(8)],
        }
        accepted = restoration._validate_source_actuation(
            actuation,
            supported_policy_id=physical.CONTROLLER_POLICY_ID,
        )
        self.assertEqual(accepted["policy_id"], physical.CONTROLLER_POLICY_ID)
        with self.assertRaisesRegex(RuntimeError, "NEUTRAL_SOURCE_POLICY_ID"):
            restoration._validate_source_actuation(actuation)
        historical_actuation = {
            "receipt": {"policy_id": restoration.SUPPORTED_POLICY_ID},
            "ordered_commands": [{"actuator_id": str(index)} for index in range(8)],
        }
        historical = restoration._validate_source_actuation(historical_actuation)
        self.assertEqual(historical["policy_id"], restoration.SUPPORTED_POLICY_ID)

        bound = physical._core.inherited.restoration
        with mock.patch.object(
            bound._inherited_restoration,
            "terminal_restoration_composition",
            return_value={"ok": True},
        ) as composition:
            self.assertEqual(bound.terminal_restoration_composition(), {"ok": True})
            self.assertEqual(
                composition.call_args.kwargs["supported_policy_id"],
                physical.CONTROLLER_POLICY_ID,
            )
        with mock.patch.object(
            bound._inherited_restoration,
            "terminal_receipt_failures",
            return_value=[],
        ) as validator:
            self.assertEqual(bound.terminal_receipt_failures(), [])
            self.assertEqual(
                validator.call_args.kwargs["supported_policy_id"],
                physical.CONTROLLER_POLICY_ID,
            )


if __name__ == "__main__":
    unittest.main()
