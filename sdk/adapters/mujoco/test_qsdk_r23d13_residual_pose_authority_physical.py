from __future__ import annotations

import unittest

from sporespore_mujoco_adapter import qsdk_r23d13_residual_pose_authority_physical as physical


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


class R23D13MujocoPhysicalZeroWorldTests(unittest.TestCase):
    def test_worker_preflight_is_dormant_and_uses_inherited_physics(self):
        receipt = physical.worker_preflight(
            "mujoco_residual_pose_authority_screen",
            "positive_heading",
        )
        self.assertTrue(receipt["inherited_r23d11_controller_and_physics"])
        self.assertTrue(receipt["independent_diagnostic_availability_semantics"])
        self.assertTrue(receipt["residual_pose_authority_enabled"])
        self.assertTrue(receipt["physical_worker_implemented"])
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_physical_contract_reads_the_frozen_taper(self):
        declaration = physical._contract()
        policy = declaration["inherited_temporal_contract"]
        composition = declaration["inherited_whole_body_composition"]
        authority = declaration["residual_pose_authority_contract"]
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
        self.assertEqual(authority["scale_denominator"], 120)
        self.assertTrue(
            authority["complete_combined_velocity_scaled_once_before_host_mapping"]
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

    def test_r23d11_failure_shape_is_valid_and_retained_as_measured(self):
        receipt = physical._diagnostic_receipt(
            active=True,
            support_margin=-0.01,
            planning_availability=physical.native.OBSERVATION_UNAVAILABLE,
            applied_stability_deltas=[0.0] * 8,
        )
        self.assertEqual(
            receipt["stability_planning_availability"],
            physical.native.OBSERVATION_UNAVAILABLE,
        )
        self.assertEqual(
            receipt["minimum_dynamic_support_margin_availability"],
            physical.diagnostics.MARGIN_MEASURED,
        )
        self.assertEqual(receipt["minimum_dynamic_support_margin_m"], -0.01)

    def test_passive_margin_availability_is_independent_and_explicit(self):
        measured = physical._diagnostic_receipt(
            active=False,
            support_margin=0.02,
            planning_availability=None,
            applied_stability_deltas=[0.0] * 8,
        )
        unavailable = physical._diagnostic_receipt(
            active=False,
            support_margin=None,
            planning_availability=None,
            applied_stability_deltas=[0.0] * 8,
        )
        self.assertEqual(
            measured["minimum_dynamic_support_margin_availability"],
            physical.diagnostics.MARGIN_MEASURED,
        )
        self.assertEqual(
            unavailable["minimum_dynamic_support_margin_availability"],
            physical.diagnostics.MARGIN_UNAVAILABLE,
        )
        self.assertIsNone(measured["stability_planning_availability"])
        self.assertIsNone(unavailable["stability_planning_availability"])

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

        next_memory, receipt, authority_receipt, canonical, host, maximum = (
            physical._stability_assisted_terminal_mapping(
                robot=robot,
                base_actuation=base_actuation,
                composed=composed,
                raw_stability_deltas=[0.04] * 8,
                availability=physical.native.AVAILABLE,
                numerator=60,
                denominator=120,
                mode=physical.terminal.TAPER_MODE,
                command_feedback=physical.terminal.Observation(
                    (True, True, True, True), 0.005, 0.1
                ),
                semantic_step=2992,
                memory=physical.native.CompositionMemory(),
            )
        )
        pre_taper = [value + 0.01 for value in bounded_velocities]
        expected = [value * 0.5 for value in pre_taper]
        self.assertAlmostEqual(maximum, 0.18, places=15)
        self.assertEqual(authority_receipt["applied_scale_numerator"], 60)
        self.assertEqual(
            authority_receipt["combined_pre_taper_velocities_rad_s"],
            pre_taper,
        )
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
            canonical["ordered_commands"],
            host["ordered_commands"],
            expected,
            strict=True,
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
            physical.R23D13MujocoPhysicalError,
            "QSDK_R23D13_MJC_TAPER_SCALE_INVALID",
        ):
            physical._stability_assisted_terminal_mapping(
                robot=robot,
                base_actuation={"ordered_commands": []},
                composed={"terminal_receipt": {"ordered_actuator_solutions": []}},
                raw_stability_deltas=[0.0] * 8,
                availability=physical.native.AVAILABLE,
                numerator=0,
                denominator=120,
                mode=physical.terminal.TAPER_MODE,
                command_feedback=physical.terminal.Observation(
                    (True, True, True, True), 0.005, 0.1
                ),
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
            physical.R23D13MujocoPhysicalError,
            "QSDK_R23D13_MJC_STABILITY_AVAILABILITY_INVALID",
        ):
            physical._normalize_planning_availability("arm_specific")


if __name__ == "__main__":
    unittest.main()
