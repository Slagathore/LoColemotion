from __future__ import annotations

import unittest

from sporespore_mujoco_adapter import qsdk_r23d10_quiescent_taper_physical as physical


class _FakeCore:
    def canonical_velocity_compose_v1(self, request):
        source = request["source_actuation"]["ordered_commands"]
        residuals = request["ordered_stability_residuals"]
        commands = []
        for command, residual in zip(source, residuals, strict=True):
            self.assert_identity(command, residual)
            canonical_source = -float(command["target_velocity_rad_s"])
            commands.append(
                {
                    "actuator_id": command["actuator_id"],
                    "combined_canonical_target_velocity_rad_s": canonical_source
                    + float(residual["canonical_velocity_delta_rad_s"]),
                }
            )
        return {"ordered_commands": commands}

    def canonical_velocity_host_map_v1(self, request):
        return {
            "ordered_commands": [
                {
                    "actuator_id": command["actuator_id"],
                    "host_target_velocity_rad_s": command[
                        "combined_canonical_target_velocity_rad_s"
                    ],
                    "native_target_position_rad": None,
                }
                for command in request["canonical_actuation"]["ordered_commands"]
            ]
        }

    @staticmethod
    def assert_identity(command, residual):
        if command["actuator_id"] != residual["actuator_id"]:
            raise AssertionError("actuator order changed")


class _FakeRobot:
    def __init__(self, actuator_ids):
        self.core = _FakeCore()
        self.descriptor = {"schema_version": "test_descriptor"}
        self.morphology = {"ordered_actuator_ids": list(actuator_ids)}


class R23D10MujocoPhysicalZeroWorldTests(unittest.TestCase):
    def test_physical_contract_reads_the_frozen_taper(self):
        declaration = physical._contract()
        policy = declaration["terminal_policy_contract"]
        self.assertEqual(policy["terminal_step_count"], 900)
        self.assertEqual(policy["maximum_active_step_count"], 540)
        self.assertEqual(policy["minimum_quiescent_taper_step_count"], 120)
        self.assertEqual(policy["minimum_passive_step_count"], 360)
        self.assertFalse(
            declaration["stage_zero_authority"]["physical_execution_authorized"]
        )

    def test_taper_scales_canonical_velocity_before_host_mapping(self):
        actuator_ids = [f"actuator_{index}" for index in range(8)]
        robot = _FakeRobot(actuator_ids)
        source_velocities = [0.04 * (index - 3) for index in range(8)]
        bounded_velocities = [-0.35, -0.25, -0.1, 0.0, 0.08, 0.2, 0.3, 0.35]
        base_actuation = {
            "ordered_commands": [
                {
                    "actuator_id": actuator_id,
                    "target_velocity_rad_s": source_velocity,
                }
                for actuator_id, source_velocity in zip(
                    actuator_ids, source_velocities, strict=True
                )
            ]
        }
        composed = {
            "terminal_receipt": {
                "ordered_actuator_solutions": [
                    {
                        "actuator_id": actuator_id,
                        "bounded_velocity_rad_s": bounded_velocity,
                    }
                    for actuator_id, bounded_velocity in zip(
                        actuator_ids, bounded_velocities, strict=True
                    )
                ]
            }
        }

        canonical, host, maximum = physical._scaled_terminal_mapping(
            robot, base_actuation, composed, 60, 120
        )
        expected = [value * 0.5 for value in bounded_velocities]
        self.assertAlmostEqual(maximum, 0.175, places=15)
        self.assertEqual(
            [row["actuator_id"] for row in canonical["ordered_commands"]],
            actuator_ids,
        )
        for canonical_row, host_row, desired in zip(
            canonical["ordered_commands"], host["ordered_commands"], expected, strict=True
        ):
            self.assertAlmostEqual(
                canonical_row["combined_canonical_target_velocity_rad_s"],
                desired,
                places=15,
            )
            self.assertAlmostEqual(
                host_row["host_target_velocity_rad_s"], desired, places=15
            )
            self.assertIsNone(host_row["native_target_position_rad"])

    def test_zero_scale_is_refused_before_mapping(self):
        robot = _FakeRobot([f"actuator_{index}" for index in range(8)])
        with self.assertRaisesRegex(
            physical.R23D10MujocoPhysicalError,
            "QSDK_R23D10_MJC_TAPER_SCALE_INVALID",
        ):
            physical._scaled_terminal_mapping(
                robot,
                {"ordered_commands": []},
                {"terminal_receipt": {"ordered_actuator_solutions": []}},
                0,
                120,
            )


if __name__ == "__main__":
    unittest.main()
