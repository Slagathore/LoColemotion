"""Zero-world regression for native-transfer physical-entrypoint dispatch.

R23D33 is closed and is never rerun here.  Its worker is used only as the
smallest executable specimen of the production dispatch defect that the closed
attempt exposed.
"""

from __future__ import annotations

import unittest
from unittest import mock

from sporespore_mujoco_adapter import qsdk_r23d33_physical as worker


class NativeTransferImplementationRepairTests(unittest.TestCase):
    def test_generated_schedule_preflight_is_bound_into_physical_core(self) -> None:
        declaration = worker.evaluator.load_declaration()
        receipts = []
        with (
            mock.patch.object(worker, "_contract", return_value=declaration),
            mock.patch(
                "mujoco.MjModel.from_xml_string",
                side_effect=AssertionError("zero-world repair constructed a model"),
            ) as constructor,
        ):
            for arm_id in ("reference_zero", "positive_heading", "negative_heading"):
                receipts.append(
                    worker.run_preflight(
                        "native_r23d29_two_engine_transfer",
                        "onset_600",
                        arm_id,
                    )
                )
        constructor.assert_not_called()

        self.assertIs(worker._core.run_preflight, worker.run_preflight)
        self.assertEqual(len(receipts), 3)
        self.assertEqual(
            {receipt["arm_id"] for receipt in receipts},
            {"reference_zero", "positive_heading", "negative_heading"},
        )
        for receipt in receipts:
            self.assertEqual(receipt["fixed_controller_horizon_step_count"], 2992)
            self.assertEqual(
                receipt["controller_memory_schema"],
                "sporespore_balanced_wave_persistent_predictive_guard_memory_v1",
            )
            self.assertEqual(receipt["model_construction_count"], 0)
            self.assertEqual(receipt["world_attempt_count"], 0)
            self.assertEqual(receipt["world_build_count"], 0)
            self.assertFalse(receipt["physical_execution_authorized"])
            self.assertFalse(receipt["physical_acceptance_authority"])

    def test_inherited_preflight_reproduces_absent_command_schedule_defect(self) -> None:
        declaration = worker.evaluator.load_declaration()
        self.assertNotIn("command_schedule", declaration)
        with (
            mock.patch.object(worker._core, "_contract", return_value=declaration),
            mock.patch(
                "mujoco.MjModel.from_xml_string",
                side_effect=AssertionError("negative control constructed a model"),
            ) as constructor,
        ):
            with self.assertRaisesRegex(KeyError, "command_schedule"):
                worker.INHERITED_PREFLIGHT_NEGATIVE_CONTROL(
                    "native_r23d29_two_engine_transfer",
                    "onset_600",
                    "reference_zero",
                )
        constructor.assert_not_called()

    def test_physical_entrypoint_dispatches_through_bound_preflight_before_world(self) -> None:
        probe_code = "QSDK_NATIVE_TRANSFER_BOUND_PREFLIGHT_PROBE"

        def stop_at_bound_preflight(
            _stage_id: str,
            _onset_id: str,
            _arm_id: str,
        ) -> dict[str, object]:
            raise worker._core.R23D3MujocoError(probe_code)

        with (
            mock.patch.object(worker._core, "_contract", return_value={}),
            mock.patch.object(
                worker._core,
                "_physical_authorization",
                return_value={"zero_world_probe": True},
            ),
            mock.patch.object(
                worker._core,
                "run_preflight",
                side_effect=stop_at_bound_preflight,
            ) as dispatch,
            mock.patch(
                "mujoco.MjModel.from_xml_string",
                side_effect=AssertionError("dispatch probe constructed a model"),
            ) as constructor,
        ):
            with self.assertRaises(worker._core.R23D3MujocoError) as raised:
                worker.run_physical(
                    "native_r23d29_two_engine_transfer",
                    "onset_600",
                    "reference_zero",
                    "0" * 40,
                )
        dispatch.assert_called_once_with(
            "native_r23d29_two_engine_transfer",
            "onset_600",
            "reference_zero",
        )
        constructor.assert_not_called()
        receipt = raised.exception.terminal_receipt
        self.assertIsNotNone(receipt)
        self.assertEqual(receipt["failure_code"], probe_code)
        self.assertEqual(receipt["failure_stage"], "before_world")
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)


if __name__ == "__main__":
    unittest.main()
