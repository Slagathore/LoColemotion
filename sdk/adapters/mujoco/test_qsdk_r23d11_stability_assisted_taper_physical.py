from __future__ import annotations

import unittest

from sporespore_mujoco_adapter import qsdk_r23d11_stability_assisted_taper_physical as physical


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


class R23D11MujocoPhysicalZeroWorldTests(unittest.TestCase):
    def test_physical_contract_reads_the_frozen_taper(self):
        declaration = physical._contract()
        policy = declaration["inherited_temporal_contract"]
        composition = declaration["stability_assisted_composition_contract"]
        self.assertEqual(policy["terminal_step_count"], 900)
        self.assertEqual(policy["maximum_active_step_count"], 540)
        self.assertEqual(policy["minimum_quiescent_taper_step_count"], 120)
        self.assertEqual(policy["minimum_passive_step_count"], 360)
        self.assertEqual(
            composition["maximum_pre_taper_combined_velocity_magnitude_rad_s"],
            0.425,
        )
        self.assertFalse(
            declaration["stage_zero_authority"]["physical_execution_authorized"]
        )

    def test_physical_report_uses_the_frozen_evaluator_taper_field_names(self):
        self.assertIn(
            physical.TERMINAL_STEP_COUNT_FIELD,
            physical.evaluator.EXECUTION_FIELDS,
        )
        self.assertIn(
            physical.TERMINAL_STEP_COUNT_FIELD,
            physical.evaluator.MEASUREMENT_FIELDS,
        )
        self.assertIn(
            physical.TAPER_STEP_COUNT_FIELD,
            physical.evaluator.MEASUREMENT_FIELDS,
        )
        self.assertIn(
            physical.TAPER_GATE_FIELD,
            physical.evaluator.MEASUREMENT_FIELDS,
        )
        inherited_outcome = physical.terminal.outcome(
            physical.terminal.State(next_step=physical.terminal.TERMINAL_STEPS)
        )
        self.assertIn(physical.TAPER_GATE_FIELD, inherited_outcome)

    def test_stability_is_composed_then_tapered_before_host_mapping(self):
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

        next_memory, receipt, canonical, host, maximum = (
            physical._stability_assisted_terminal_mapping(
                robot=robot,
                base_actuation=base_actuation,
                composed=composed,
                raw_stability_deltas=[0.04] * 8,
                availability=physical.native.AVAILABLE,
                numerator=60,
                denominator=120,
                semantic_step=2992,
                memory=physical.native.CompositionMemory(),
            )
        )
        expected = [(value + 0.01) * 0.5 for value in bounded_velocities]
        self.assertAlmostEqual(maximum, 0.18, places=15)
        self.assertEqual(next_memory.previous_semantic_step, 2992)
        self.assertTrue(
            all(
                row["applied_stability_velocity_delta_rad_s"] == 0.01
                for row in receipt["ordered_actuator_composition"]
            )
        )
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
            physical.R23D11MujocoPhysicalError,
            "QSDK_R23D11_MJC_TAPER_SCALE_INVALID",
        ):
            physical._stability_assisted_terminal_mapping(
                robot=robot,
                base_actuation={"ordered_commands": []},
                composed={"terminal_receipt": {"ordered_actuator_solutions": []}},
                raw_stability_deltas=[0.0] * 8,
                availability=physical.native.AVAILABLE,
                numerator=0,
                denominator=120,
                semantic_step=2992,
                memory=physical.native.CompositionMemory(),
            )

    def test_preexisting_upstream_infeasible_enum_is_normalized(self):
        self.assertEqual(
            physical._normalize_planning_availability("upstream_infeasible"),
            physical.native.PLANNING_INFEASIBLE,
        )
        self.assertEqual(
            physical._normalize_planning_availability("available"),
            physical.native.AVAILABLE,
        )
        with self.assertRaisesRegex(
            physical.R23D11MujocoPhysicalError,
            "QSDK_R23D11_MJC_STABILITY_AVAILABILITY_INVALID",
        ):
            physical._normalize_planning_availability("arm_specific")


if __name__ == "__main__":
    unittest.main()
