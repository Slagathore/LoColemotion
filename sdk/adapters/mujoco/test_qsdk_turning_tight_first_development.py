from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from sporespore_mujoco_adapter import qsdk_turning_tight_first_development as dev


class TightFirstMujocoDevelopmentTests(unittest.TestCase):
    def test_preflight_keeps_frozen_worker_closed(self) -> None:
        receipt = dev.preflight("0" * 40)
        self.assertEqual(
            receipt["frozen_r23d13_production_refusal"], "QSDK_R23D13_MJC_CLOSED"
        )
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["validation_authority"])

    def test_output_must_be_new_and_under_durable_development_root(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(dev.TightFirstDevelopmentError):
                dev._validated_new_output_root(Path(directory) / "candidate")

    def test_screen_conjunction_is_development_only_math(self) -> None:
        report = {
            "execution": {
                "integrity_passed": True,
                "world_attempt_count": 1,
                "world_build_count": 1,
            },
            "measurements": {
                "turn_phase_yaw_delta_rad": -0.1,
                "final_forward_displacement_m": 1.0,
                "maximum_tilt_rad": 0.2,
                "minimum_torso_height_m": 0.4,
                "torso_ground_contact_step_count": 0,
                "contact_cycle_count_by_limb": {
                    "front_left": 2,
                    "front_right": 2,
                    "rear_left": 2,
                    "rear_right": 2,
                },
                "controller_error_count": 0,
                "active_safe_no_actuation_count": 0,
                "nonfinite_observation_count": 0,
                "actuator_application_mismatch_count": 0,
                "terminal_receipt_validation_failure_count": 0,
                "quiescent_taper_gate_passed": True,
            },
        }
        conjunction = dev._screen_conjunction(report, "negative_heading")
        self.assertTrue(conjunction["development_screen_passed"])
        report["measurements"]["turn_phase_yaw_delta_rad"] = 0.1
        self.assertFalse(
            dev._screen_conjunction(report, "negative_heading")[
                "development_screen_passed"
            ]
        )

    def test_development_injection_is_restored_after_failure(self) -> None:
        original_authorization = dev.frozen_worker.physical_authorization
        original_retention = dev.frozen_worker._retain_trace
        original_observer = dev.frozen_worker.terminal.observe_completed_step
        durable = dev._durable_development_root()
        output = durable / "unit-test-restoration"
        with patch.object(dev, "_validated_new_output_root", return_value=output):
            with patch.object(
                dev.frozen_worker,
                "run_physical",
                side_effect=RuntimeError("expected_test_failure"),
            ):
                with patch.object(Path, "write_text", return_value=1):
                    with self.assertRaises(RuntimeError):
                        dev.run_development(
                            arm_id="positive_heading",
                            source_commit="0" * 40,
                            output_root=output,
                        )
        self.assertIs(dev.frozen_worker.physical_authorization, original_authorization)
        self.assertIs(dev.frozen_worker._retain_trace, original_retention)
        self.assertIs(
            dev.frozen_worker.terminal.observe_completed_step, original_observer
        )


if __name__ == "__main__":
    unittest.main()
