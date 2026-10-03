"""Zero-world tests for the QSDK-R23D9 classic-MuJoCo route."""

from __future__ import annotations

import os
import unittest
from unittest import mock

from sporespore_mujoco_adapter import qsdk_r23d9_support_handoff as worker
from sporespore_mujoco_adapter import qsdk_r23d9_support_handoff_physical as physical


class R23D9MujocoWorkerTests(unittest.TestCase):
    def test_all_declared_mujoco_routes_preflight_without_worlds(self) -> None:
        cells = [
            ("mujoco_support_handoff_screen", "positive_heading"),
            ("mujoco_support_handoff_screen", "negative_heading"),
            ("three_engine_confirmation", "reference_zero"),
            ("three_engine_confirmation", "positive_heading"),
            ("three_engine_confirmation", "negative_heading"),
        ]
        for stage_id, arm_id in cells:
            receipt = worker.run_preflight(stage_id, arm_id)
            self.assertEqual(receipt["fixed_controller_horizon_step_count"], 2992)
            self.assertEqual(receipt["fixed_terminal_handoff_step_count"], 780)
            self.assertEqual(receipt["fixed_total_trace_step_count"], 3772)
            self.assertEqual(receipt["maximum_active_neutral_acquisition_step_count"], 420)
            self.assertEqual(receipt["support_confirmation_step_count"], 30)
            self.assertEqual(receipt["minimum_post_handoff_zero_actuation_step_count"], 360)
            self.assertEqual(receipt["support_handoff_oracle_canary_count"], 5)
            self.assertEqual(receipt["support_handoff_mutation_control_count"], 12)
            self.assertTrue(receipt["native_temporal_mirror"])
            self.assertTrue(receipt["physical_worker_implemented"])
            self.assertTrue(
                receipt["physical_worker_dormant_behind_supervisor_authorization"]
            )
            self.assertEqual(receipt["model_construction_count"], 0)
            self.assertEqual(receipt["world_attempt_count"], 0)
            self.assertEqual(receipt["world_build_count"], 0)

    def test_production_trace_row_constructors_replay_complete_horizon(self) -> None:
        cell = physical._cell(
            "mujoco_support_handoff_screen", "positive_heading"
        )
        metrics = {
            "x": 0.0,
            "y": 0.4,
            "z": 0.0,
            "yaw_rad": 0.1,
            "tilt_rad": 0.1,
            "ground_contact": False,
        }
        contacts = {limb_id: True for limb_id in physical.design.LIMB_IDS}
        rows = [
            physical._controller_row(
                cell, trace_step, metrics, contacts, physical.design.ACTUATOR_COUNT
            )
            for trace_step in range(physical.design.CONTROLLER_STEPS)
        ]
        state = physical.design.initial_state()
        for terminal_step in range(physical.design.TERMINAL_STEPS):
            directive = physical.design.plan_step(state)
            state, receipt = physical.design.observe_completed_step(
                state,
                directive,
                tuple(contacts.values()),
                directive.expected_native_application_count,
            )
            active = directive.mode == physical.design.ACTIVE_MODE
            rows.append(
                physical._terminal_row(
                    cell,
                    physical.design.CONTROLLER_STEPS + terminal_step,
                    directive,
                    receipt,
                    metrics,
                    contacts,
                    0.05 if active else None,
                    0.35 if active else None,
                )
            )
        replay = physical.design.validate_trace(cell, rows)
        self.assertTrue(replay["ok"], replay["failure_codes"])
        self.assertEqual(replay["row_count"], physical.design.TOTAL_TRACE_STEPS)
        self.assertEqual(
            replay["handoff_outcome"]["first_passive_step"],
            physical.design.SUPPORT_CONFIRMATION_STEPS,
        )
        self.assertTrue(
            replay["handoff_outcome"]["irreversible_handoff_gate_passed"]
        )

    def test_physical_route_refuses_before_model_without_supervisor(self) -> None:
        authorization_names = {
            physical.FREEZE_PATH_ENV,
            physical.ATTEMPT_PATH_ENV,
            physical.AUTHORIZATION_TOKEN_ENV,
            physical.ATTEMPT_ROOT_ENV,
            physical.STAGE_ID_ENV,
            physical.CELL_ID_ENV,
            physical.ENGINE_ID_ENV,
        }
        environment = {
            key: value
            for key, value in os.environ.items()
            if key not in authorization_names
        }
        with (
            mock.patch.dict(os.environ, environment, clear=True),
            mock.patch.object(
                physical.inherited.base.bridge,
                "MujocoBw19vRobot",
                side_effect=AssertionError("model construction bypassed authorization"),
            ) as constructor,
        ):
            with self.assertRaises(physical.R23D9MujocoPhysicalError) as raised:
                physical.run_physical(
                    "mujoco_support_handoff_screen",
                    "positive_heading",
                    "0" * 40,
                )
        self.assertEqual(constructor.call_count, 0)
        receipt = raised.exception.terminal_receipt
        self.assertIsNotNone(receipt)
        assert receipt is not None
        self.assertEqual(
            receipt["failure_code"],
            "QSDK_R23D9_MJC_PHYSICAL_AUTHORIZATION_REQUIRED",
        )
        self.assertEqual(receipt["failure_stage"], "before_world")
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_identity_fails_closed(self) -> None:
        with self.assertRaises(worker.R23D9MujocoError):
            worker._cell("mujoco_support_handoff_screen", "reference_zero")
        with self.assertRaises(worker.R23D9MujocoError):
            worker._cell("unknown", "positive_heading")


if __name__ == "__main__":
    unittest.main()
