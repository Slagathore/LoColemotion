from __future__ import annotations

import copy
import math
import unittest

from r23d8_neutral_stance import (
    MAXIMUM_SPEED_RAD_S,
    POLICY_ID,
    R23D8Error,
    bounded_neutral_velocity,
    compose_neutral_stance,
    receipt_failures,
    run_zero_world_preflight,
)


def _actuators() -> list[dict[str, object]]:
    return [
        {
            "actuator_id": f"limb_{index}_motor",
            "joint_id": f"limb_{index}_joint",
            "minimum_target_position_rad": -0.8 if index % 2 == 0 else -0.1,
            "maximum_target_position_rad": 0.8 if index % 2 == 0 else 1.1,
        }
        for index in range(8)
    ]


def _observations() -> list[dict[str, object]]:
    return [
        {
            "joint_id": f"limb_{index}_joint",
            "position_rad": 0.05 - 0.01 * index,
            "velocity_rad_s": -0.2 + 0.05 * index,
        }
        for index in range(8)
    ]


class R23D8NeutralStanceTests(unittest.TestCase):
    def test_exact_equation_and_speed_bound(self) -> None:
        result = bounded_neutral_velocity(0.05, 0.0)
        self.assertTrue(
            math.isclose(result["unbounded_velocity_rad_s"], -0.4, abs_tol=1e-12)
        )
        self.assertEqual(result["bounded_velocity_rad_s"], -MAXIMUM_SPEED_RAD_S)

    def test_all_eight_targets_are_atomic_and_ordered(self) -> None:
        actuators = _actuators()
        receipt = compose_neutral_stance(actuators, _observations())
        self.assertEqual(receipt["policy_id"], POLICY_ID)
        self.assertEqual(receipt["neutral_target_activation_count"], 8)
        self.assertEqual(
            receipt_failures(receipt, [item["actuator_id"] for item in actuators]), []
        )

    def test_zero_target_outside_authored_limit_fails_closed(self) -> None:
        actuators = _actuators()
        actuators[0]["minimum_target_position_rad"] = 0.1
        with self.assertRaisesRegex(R23D8Error, "TARGET_OUTSIDE_LIMIT"):
            compose_neutral_stance(actuators, _observations())

    def test_nonzero_target_mutation_is_rejected(self) -> None:
        actuators = _actuators()
        receipt = compose_neutral_stance(actuators, _observations())
        mutated = copy.deepcopy(receipt)
        mutated["ordered_actuator_solutions"][0]["target_position_rad"] = 0.01
        self.assertIn(
            "target:limb_0_motor",
            receipt_failures(mutated, [item["actuator_id"] for item in actuators]),
        )

    def test_complete_preflight_opens_no_world(self) -> None:
        result = run_zero_world_preflight()
        self.assertTrue(result["ok"])
        self.assertEqual(result["neutral_target_activation_count"], 8)
        self.assertEqual(result["canary_count"], 5)
        self.assertEqual(result["mutation_control_count"], 10)
        self.assertEqual(result["model_construction_count"], 0)
        self.assertEqual(result["world_attempt_count"], 0)
        self.assertFalse(result["physical_execution_authorized"])
        self.assertFalse(result["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
