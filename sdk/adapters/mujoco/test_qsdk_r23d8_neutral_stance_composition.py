from __future__ import annotations

import copy
import unittest
from unittest import mock

from sporespore_mujoco_adapter import qsdk_r23d8_neutral_stance_composition as stance


class QsdkR23d7NeutralStanceCompositionTests(unittest.TestCase):
    def test_mutants_and_signed_production_shapes_open_no_model(self) -> None:
        with mock.patch(
            "mujoco.MjModel.from_xml_string",
            side_effect=AssertionError("R23D8 zero-world preflight constructed a model"),
        ) as constructor:
            report = stance.run_zero_world_preflight()
        constructor.assert_not_called()

        self.assertEqual(report["gate_id"], "QSDK-R23D8")
        self.assertEqual(report["policy_id"], stance.RESTORATION_POLICY_ID)
        self.assertEqual(report["algebra"]["canary_count"], 5)
        self.assertEqual(report["algebra"]["mutation_control_count"], 10)
        self.assertTrue(all(report["algebra"]["mutation_controls_rejected"].values()))
        self.assertEqual(report["signed_arm_count"], 2)
        self.assertEqual(report["production_restoration_composition_complete_count"], 2)
        self.assertEqual(report["source_actuator_command_count"], 16)
        self.assertEqual(report["terminal_solution_count"], 16)
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
            self.assertEqual(arm["neutral_target_activation_count"], 8)
            self.assertFalse(arm["source_forward_velocity_member_present"])
            self.assertNotIn(
                stance.FORWARD_VELOCITY_RECEIPT_MEMBER,
                arm["source_receipt_member_names"],
            )
            self.assertTrue(arm["terminal_receipt_complete"])

    def test_source_policy_and_forward_member_fail_closed(self) -> None:
        actuation = {
            "receipt": {
                "policy_id": stance.SUPPORTED_POLICY_ID,
                "held_steering_fraction": 0.2,
            },
            "ordered_commands": [{} for _ in range(8)],
        }
        self.assertEqual(
            stance._validate_source_actuation(actuation)["policy_id"],
            stance.SUPPORTED_POLICY_ID,
        )

        wrong_policy = copy.deepcopy(actuation)
        wrong_policy["receipt"]["policy_id"] = "sporespore_balanced_wave_bw15f_b_v1"
        with self.assertRaisesRegex(RuntimeError, "SOURCE_POLICY_ID"):
            stance._validate_source_actuation(wrong_policy)

        unexpected_forward = copy.deepcopy(actuation)
        unexpected_forward["receipt"][stance.FORWARD_VELOCITY_RECEIPT_MEMBER] = {}
        with self.assertRaisesRegex(RuntimeError, "UNEXPECTED_FORWARD_RECEIPT"):
            stance._validate_source_actuation(unexpected_forward)


if __name__ == "__main__":
    unittest.main()
