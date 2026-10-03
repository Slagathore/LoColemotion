"""Zero-world canaries and mutation controls for QSDK-R23D13 stage zero."""

from __future__ import annotations

from dataclasses import replace
import math
import unittest

from . import r23d10_quiescent_taper as temporal
from . import r23d13_residual_pose_authority as policy


IDS = tuple(f"actuator_{index}" for index in range(policy.ACTUATOR_COUNT))
VELOCITIES = (0.2, -0.1, 0.3, -0.2, 0.1, -0.3, 0.4, -0.4)
TIGHT = policy.PoseFeedback((True, True, True, True), 0.005, 0.1)
NEGATIVE_BEST = policy.PoseFeedback(
    (True, True, True, True),
    0.02039827933466296,
    0.2375508558310486,
)
NEGATIVE_FINAL = policy.PoseFeedback(
    (True, True, True, True),
    0.027166660831829642,
    0.2706423272295883,
)


class R23D13ResidualPoseAuthorityTest(unittest.TestCase):
    def apply(self, **changes: object) -> dict[str, object]:
        values: dict[str, object] = {
            "mode": temporal.TAPER_MODE,
            "temporal_scale_numerator": 2,
            "temporal_scale_denominator": 120,
            "feedback": NEGATIVE_BEST,
            "actuator_ids": IDS,
            "combined_pre_taper_velocities_rad_s": VELOCITIES,
        }
        values.update(changes)
        return policy.apply_residual_pose_authority(**values)  # type: ignore[arg-type]

    def expect_error(self, code: str, **changes: object) -> None:
        with self.assertRaisesRegex(policy.ContractError, f"^{code}$"):
            self.apply(**changes)

    def test_ten_declared_canaries(self) -> None:
        receipt = policy.run_zero_world_preflight()
        self.assertEqual(receipt["canary_count"], 10)
        self.assertEqual(receipt["new_tunable_gain_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])

    def test_floor_is_bounded_monotone_and_uses_worst_pose_channel(self) -> None:
        states = (
            (policy.PoseFeedback((True,) * 4, 0.005, 0.1), 1),
            (policy.PoseFeedback((True,) * 4, 0.015, 0.1), 24),
            (policy.PoseFeedback((True,) * 4, 0.0225, 0.1), 60),
            (policy.PoseFeedback((True,) * 4, 0.035, 0.1), 120),
            (policy.PoseFeedback((True,) * 4, 0.005, 0.26), 60),
            (policy.PoseFeedback((True,) * 4, 0.015, 0.29), 90),
            (policy.PoseFeedback((True, False, True, True), 0.005, 0.1), 120),
        )
        for feedback, expected in states:
            self.assertEqual(
                policy.pose_authority_floor(feedback)[
                    "pose_authority_floor_numerator"
                ],
                expected,
            )

    def test_retained_r23d12_failure_shape_maps_to_declared_floor(self) -> None:
        best = policy.pose_authority_floor(NEGATIVE_BEST)
        final = policy.pose_authority_floor(NEGATIVE_FINAL)
        self.assertEqual(best["tilt_floor_numerator"], 50)
        self.assertEqual(best["joint_error_floor_numerator"], 38)
        self.assertEqual(best["pose_authority_floor_numerator"], 50)
        self.assertEqual(final["tilt_floor_numerator"], 83)
        self.assertEqual(final["joint_error_floor_numerator"], 71)
        self.assertEqual(final["pose_authority_floor_numerator"], 83)
        self.assertFalse(best["arm_identity_or_heading_sign_used"])

    def test_floor_never_reduces_temporal_authority_and_scales_all_eight(self) -> None:
        raised = self.apply()
        self.assertEqual(raised["temporal_scale_numerator"], 2)
        self.assertEqual(raised["pose_authority_floor_numerator"], 50)
        self.assertEqual(raised["applied_scale_numerator"], 50)
        for source, row in zip(
            VELOCITIES,
            raised["ordered_actuator_commands"],  # type: ignore[arg-type]
            strict=True,
        ):
            self.assertTrue(
                math.isclose(
                    row["final_canonical_velocity_rad_s"],  # type: ignore[index]
                    source * 50.0 / 120.0,
                    rel_tol=0.0,
                    abs_tol=1.0e-15,
                )
            )
        temporal_dominant = self.apply(temporal_scale_numerator=100)
        self.assertEqual(temporal_dominant["applied_scale_numerator"], 100)

    def test_tight_positive_shape_and_passive_boundary_are_unchanged(self) -> None:
        positive = self.apply(feedback=TIGHT, temporal_scale_numerator=1)
        self.assertEqual(positive["pose_authority_floor_numerator"], 1)
        self.assertEqual(positive["applied_scale_numerator"], 1)
        passive = self.apply(
            mode=temporal.PASSIVE_MODE,
            temporal_scale_numerator=0,
            feedback=NEGATIVE_FINAL,
            combined_pre_taper_velocities_rad_s=(None,) * policy.ACTUATOR_COUNT,
        )
        self.assertFalse(passive["residual_pose_recovery_invoked"])
        self.assertTrue(passive["passive_mode_exact_zero_actuation"])
        self.assertEqual(passive["pose_authority_floor_numerator"], 0)
        self.assertTrue(
            all(
                row["final_canonical_velocity_rad_s"] == 0.0
                for row in passive["ordered_actuator_commands"]  # type: ignore[union-attr]
            )
        )

    def test_twenty_mutation_controls_fail_closed(self) -> None:
        controls: list[tuple[str, dict[str, object]]] = [
            (
                "R23D13_CONTACT_SHAPE_INVALID",
                {"feedback": replace(NEGATIVE_BEST, contacts=(True, True, True))},
            ),
            (
                "R23D13_CONTACT_TYPE_INVALID",
                {"feedback": replace(NEGATIVE_BEST, contacts=(True, True, True, 1))},
            ),
            (
                "R23D13_POSE_MEASUREMENT_INVALID",
                {"feedback": replace(NEGATIVE_BEST, torso_tilt_rad=math.nan)},
            ),
            (
                "R23D13_POSE_MEASUREMENT_INVALID",
                {"feedback": replace(NEGATIVE_BEST, torso_tilt_rad=-0.001)},
            ),
            (
                "R23D13_POSE_MEASUREMENT_INVALID",
                {
                    "feedback": replace(
                        NEGATIVE_BEST,
                        maximum_absolute_joint_position_error_rad=math.inf,
                    )
                },
            ),
            (
                "R23D13_POSE_MEASUREMENT_INVALID",
                {
                    "feedback": replace(
                        NEGATIVE_BEST,
                        maximum_absolute_joint_position_error_rad=-0.001,
                    )
                },
            ),
            ("R23D13_MODE_INVALID", {"mode": "negative_heading_recovery"}),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"mode": temporal.ACTIVE_MODE, "temporal_scale_numerator": 119},
            ),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"temporal_scale_numerator": 0},
            ),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"temporal_scale_numerator": 121},
            ),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"temporal_scale_numerator": True},
            ),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"temporal_scale_denominator": 119},
            ),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"temporal_scale_denominator": True},
            ),
            (
                "R23D13_TEMPORAL_FRACTION_INVALID",
                {"mode": temporal.PASSIVE_MODE, "temporal_scale_numerator": 1},
            ),
            ("R23D13_ACTUATOR_ORDER_INVALID", {"actuator_ids": IDS[:-1]}),
            (
                "R23D13_ACTUATOR_ORDER_INVALID",
                {"actuator_ids": IDS[:-1] + (IDS[0],)},
            ),
            (
                "R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID",
                {"combined_pre_taper_velocities_rad_s": VELOCITIES[:-1]},
            ),
            (
                "R23D13_ACTIVE_VELOCITY_INVALID",
                {"combined_pre_taper_velocities_rad_s": (math.nan,) + VELOCITIES[1:]},
            ),
            (
                "R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND",
                {"combined_pre_taper_velocities_rad_s": (0.426,) + VELOCITIES[1:]},
            ),
            (
                "R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT",
                {
                    "mode": temporal.PASSIVE_MODE,
                    "temporal_scale_numerator": 0,
                    "combined_pre_taper_velocities_rad_s": (0.0,) * 8,
                },
            ),
        ]
        self.assertEqual(len(controls), 20)
        for code, changes in controls:
            self.expect_error(code, **changes)


if __name__ == "__main__":
    unittest.main()
