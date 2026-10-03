from __future__ import annotations

import os
import unittest

from sporespore_mujoco_adapter import qsdk_r23d3_phase_balanced as worker


class R23D3MujocoWorkerTests(unittest.TestCase):
    def test_every_declared_mujoco_identity_proves_fixed_horizon_pre_world(self) -> None:
        receipts = []
        for cell in worker.design.stage_a_cells():
            receipts.append(
                worker.run_preflight(cell.stage_id, cell.onset_id, cell.arm_id)
            )
        for onset_id in worker.design.ONSET_IDS:
            for cell in worker.design.stage_b_cells(onset_id):
                if cell.engine_id == worker.ENGINE_ID:
                    receipts.append(
                        worker.run_preflight(
                            cell.stage_id, cell.onset_id, cell.arm_id
                        )
                    )
        self.assertEqual(len(receipts), 20)
        self.assertTrue(
            all(
                receipt["fixed_controller_horizon_step_count"] == 2992
                and receipt[
                    "fixed_horizon_configuration_proved_before_fixture_insertion"
                ]
                and receipt["model_construction_count"] == 0
                and receipt["world_attempt_count"] == 0
                and receipt["world_build_count"] == 0
                and not receipt["physical_execution_authorized"]
                for receipt in receipts
            )
        )

    def test_stage_a_rejects_reference_arm(self) -> None:
        with self.assertRaisesRegex(
            worker.R23D3MujocoError, "QSDK_R23D3_MJC_CELL_IDENTITY_INVALID"
        ):
            worker.run_preflight(
                "mujoco_onset_screen", "onset_600", "reference_zero"
            )

    def test_unknown_onset_and_stage_fail_before_world(self) -> None:
        for stage_id, onset_id in (
            ("unknown_stage", "onset_600"),
            ("mujoco_onset_screen", "onset_unknown"),
        ):
            with self.assertRaises(worker.R23D3MujocoError):
                worker.run_preflight(stage_id, onset_id, "positive_heading")

    def test_direct_physical_call_refuses_without_freeze_or_attempt(self) -> None:
        names = (
            worker.FREEZE_PATH_ENV,
            worker.ATTEMPT_PATH_ENV,
            worker.AUTHORIZATION_TOKEN_ENV,
            worker.STAGE_ID_ENV,
            worker.CELL_ID_ENV,
            worker.ENGINE_ID_ENV,
            worker.ATTEMPT_ROOT_ENV,
        )
        saved = {name: os.environ.get(name) for name in names}
        try:
            for name in names:
                os.environ.pop(name, None)
            with self.assertRaises(worker.R23D3MujocoError) as raised:
                worker.run_physical(
                    "mujoco_onset_screen",
                    "onset_600",
                    "positive_heading",
                    "0" * 40,
                )
            receipt = raised.exception.terminal_receipt
            self.assertIsNotNone(receipt)
            self.assertEqual(
                receipt["failure_code"],
                "QSDK_R23D3_MJC_CLOSED",
            )
            self.assertEqual(receipt["failure_stage"], "before_world")
            self.assertEqual(receipt["world_attempt_count"], 0)
            self.assertEqual(receipt["world_build_count"], 0)
            self.assertIsNone(receipt["trace_artifact"])
        finally:
            for name, value in saved.items():
                if value is None:
                    os.environ.pop(name, None)
                else:
                    os.environ[name] = value


if __name__ == "__main__":
    unittest.main()
