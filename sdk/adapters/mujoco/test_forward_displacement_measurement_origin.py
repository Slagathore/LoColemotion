"""Zero-world tests for prospective forward-displacement measurement parity."""

from __future__ import annotations

import unittest

import numpy as np

from sporespore_mujoco_adapter import qsdk_r23d3_phase_balanced as worker


class ForwardDisplacementMeasurementOriginTests(unittest.TestCase):
    def test_evidence_window_preflight_is_exact_and_zero_world(self) -> None:
        plan = worker.evidence_window_forward_displacement_measurement_origin_plan()
        receipt = worker.run_forward_displacement_measurement_origin_preflight(plan)

        self.assertEqual(
            receipt["measurement_origin"]["schema_version"],
            worker.FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_SCHEMA,
        )
        self.assertEqual(
            receipt["measurement_origin"]["policy_id"],
            worker.EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
        )
        self.assertEqual(
            receipt["measurement_origin"]["semantic_step"],
            worker.EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        )
        self.assertEqual(
            receipt["measurement_origin"]["origin_world_m"],
            [0.4, 0.42, -0.01],
        )
        self.assertTrue(
            receipt["measurement_origin"]["captured_before_controller_step"]
        )
        self.assertFalse(
            receipt["measurement_origin"]
            ["task_frame_reanchors_change_measurement_origin"]
        )
        self.assertTrue(receipt["controller_task_origin_unchanged"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])

    def test_existing_routes_remain_legacy_until_explicit_opt_in(self) -> None:
        legacy_displacement, legacy_receipt = (
            worker._project_forward_displacement_measurement(
                plan=worker.LEGACY_FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_PLAN,
                mutable_task_origin_world_m=np.asarray(
                    [1.9, 0.42, 0.02], dtype=np.float64
                ),
                evidence_window_origin_world_m=None,
                final_position_world_m=np.asarray(
                    [1.901, 0.42, 0.02], dtype=np.float64
                ),
                reference_heading_rad=0.0,
            )
        )
        self.assertAlmostEqual(legacy_displacement, 0.001, places=12)
        self.assertIsNone(legacy_receipt)

        default = worker.run_preflight(
            "mujoco_onset_screen", "onset_600", "positive_heading"
        )
        self.assertNotIn("forward_displacement_measurement_origin", default)

        plan = worker.evidence_window_forward_displacement_measurement_origin_plan()
        prospective = worker.run_preflight(
            "mujoco_onset_screen",
            "onset_600",
            "positive_heading",
            forward_displacement_measurement_origin_plan=plan,
        )
        self.assertTrue(
            prospective["forward_displacement_measurement_origin_preflight_passed"]
        )
        self.assertEqual(
            prospective["forward_displacement_measurement_origin"]["semantic_step"],
            worker.EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        )
        self.assertEqual(prospective["model_construction_count"], 0)
        self.assertEqual(prospective["world_attempt_count"], 0)
        self.assertEqual(prospective["world_build_count"], 0)

    def test_evidence_origin_projects_from_immutable_capture(self) -> None:
        plan = worker.evidence_window_forward_displacement_measurement_origin_plan()
        displacement, receipt = worker._project_forward_displacement_measurement(
            plan=plan,
            mutable_task_origin_world_m=np.asarray(
                [1.9, 0.42, 0.02], dtype=np.float64
            ),
            evidence_window_origin_world_m=np.asarray(
                [0.4, 0.42, -0.01], dtype=np.float64
            ),
            final_position_world_m=np.asarray(
                [1.901, 0.42, 0.02], dtype=np.float64
            ),
            reference_heading_rad=0.0,
        )
        self.assertAlmostEqual(displacement, 1.501, places=12)
        self.assertIsNotNone(receipt)
        self.assertEqual(receipt["origin_world_m"], [0.4, 0.42, -0.01])
        self.assertFalse(receipt["task_frame_reanchors_change_measurement_origin"])

    def test_plan_and_capture_mutations_fail_closed(self) -> None:
        invalid_plans = (
            worker.ForwardDisplacementMeasurementOriginPlan(
                policy_id="unknown_policy", semantic_step=None
            ),
            worker.ForwardDisplacementMeasurementOriginPlan(
                policy_id=worker.EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
                semantic_step=None,
            ),
            worker.ForwardDisplacementMeasurementOriginPlan(
                policy_id=worker.EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
                semantic_step=True,
            ),
            worker.evidence_window_forward_displacement_measurement_origin_plan(
                worker.CONTROLLER_STEPS
            ),
        )
        for plan in invalid_plans:
            with self.subTest(plan=plan):
                with self.assertRaisesRegex(
                    worker.R23D3MujocoError,
                    "QSDK_MJC_FORWARD_MEASUREMENT_PLAN_INVALID",
                ):
                    worker._validated_forward_displacement_measurement_origin_plan(
                        plan, controller_steps=worker.CONTROLLER_STEPS
                    )

        evidence_plan = (
            worker.evidence_window_forward_displacement_measurement_origin_plan()
        )
        common = {
            "mutable_task_origin_world_m": np.asarray(
                [1.9, 0.42, 0.02], dtype=np.float64
            ),
            "final_position_world_m": np.asarray(
                [1.901, 0.42, 0.02], dtype=np.float64
            ),
            "reference_heading_rad": 0.0,
        }
        with self.assertRaisesRegex(
            worker.R23D3MujocoError,
            "QSDK_MJC_FORWARD_MEASUREMENT_EVIDENCE_CAPTURE_MISSING",
        ):
            worker._project_forward_displacement_measurement(
                plan=evidence_plan,
                evidence_window_origin_world_m=None,
                **common,
            )
        with self.assertRaisesRegex(
            worker.R23D3MujocoError,
            "QSDK_MJC_FORWARD_MEASUREMENT_LEGACY_CAPTURE_AMBIGUOUS",
        ):
            worker._project_forward_displacement_measurement(
                plan=worker.LEGACY_FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_PLAN,
                evidence_window_origin_world_m=np.asarray(
                    [0.4, 0.42, -0.01], dtype=np.float64
                ),
                **common,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
