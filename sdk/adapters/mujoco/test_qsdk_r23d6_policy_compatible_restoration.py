from __future__ import annotations

import copy
import unittest
from unittest import mock

from sporespore_mujoco_adapter import qsdk_r23d6_policy_compatible_restoration as restoration


class QsdkR23d6PolicyCompatibleRestorationTests(unittest.TestCase):
    def test_declared_algebra_mutants_and_signed_production_shapes(self) -> None:
        with mock.patch(
            "mujoco.MjModel.from_xml_string",
            side_effect=AssertionError("R23D6 zero-world preflight constructed a model"),
        ) as constructor:
            report = restoration.run_zero_world_preflight()
        constructor.assert_not_called()

        self.assertEqual(report["gate_id"], "QSDK-R23D6")
        self.assertEqual(report["algebra"]["canary_count"], 5)
        self.assertEqual(report["algebra"]["mutation_control_count"], 8)
        self.assertTrue(
            all(report["algebra"]["mutation_controls_rejected"].values())
        )
        self.assertEqual(report["signed_arm_count"], 2)
        self.assertEqual(report["production_restoration_composition_complete_count"], 2)
        self.assertEqual(report["source_actuator_command_count"], 16)
        self.assertEqual(report["terminal_solution_count"], 16)
        self.assertEqual(report["physics_adapter_start_count"], 0)
        self.assertEqual(report["physical_process_launch_count"], 0)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["command_conditioned_turning"])
        self.assertFalse(report["physical_acceptance_authority"])

        by_arm = {item["arm_id"]: item for item in report["signed_arms"]}
        self.assertGreater(by_arm["positive_heading"]["held_steering_fraction"], 0.0)
        self.assertLess(by_arm["negative_heading"]["held_steering_fraction"], 0.0)
        for arm in by_arm.values():
            self.assertEqual(arm["source_actuator_command_count"], 8)
            self.assertEqual(arm["terminal_solution_count"], 8)
            self.assertEqual(arm["canonical_command_count"], 8)
            self.assertEqual(arm["host_command_count"], 8)
            self.assertFalse(arm["source_forward_velocity_member_present"])
            self.assertNotIn(
                restoration.FORWARD_VELOCITY_RECEIPT_MEMBER,
                arm["source_receipt_member_names"],
            )
            self.assertTrue(arm["terminal_receipt_complete"])

    def test_policy_identity_forward_member_and_transform_fail_closed(self) -> None:
        actuation = {
            "receipt": {
                "policy_id": restoration.SUPPORTED_POLICY_ID,
                "held_steering_fraction": 0.2,
            }
        }
        command = {"requested_target_position_rad": 0.3}
        profile = restoration._policy_profile_fixture()

        wrong_policy = copy.deepcopy(actuation)
        wrong_policy["receipt"]["policy_id"] = (
            "sporespore_balanced_wave_bw15f_b_v1"
        )
        with self.assertRaisesRegex(RuntimeError, "QSDK_R23D6_BW5R_B_POLICY_ID"):
            restoration.portable_heading_target_delta(
                wrong_policy,
                command,
                profile,
                "front_right",
                "front_right_hip",
                0.3,
            )

        unexpected_forward = copy.deepcopy(actuation)
        unexpected_forward["receipt"][
            restoration.FORWARD_VELOCITY_RECEIPT_MEMBER
        ] = {"ordered_limb_corrections": []}
        with self.assertRaisesRegex(
            RuntimeError, "QSDK_R23D6_BW5R_B_UNEXPECTED_FORWARD_RECEIPT"
        ):
            restoration.portable_heading_target_delta(
                unexpected_forward,
                command,
                profile,
                "front_right",
                "front_right_hip",
                0.3,
            )

        wrong_transform = copy.deepcopy(profile)
        wrong_transform["steering_stride_transform_id"] = "mutated_transform"
        with self.assertRaisesRegex(
            RuntimeError, "QSDK_R23D6_BW5R_B_STRIDE_TRANSFORM"
        ):
            restoration.portable_heading_target_delta(
                actuation,
                command,
                wrong_transform,
                "front_right",
                "front_right_hip",
                0.3,
            )


if __name__ == "__main__":
    unittest.main()
