"""Zero-world tests for the independent MuJoCo/Python R23D13 mirror."""

from __future__ import annotations

import json
import unittest

from sporespore_mujoco_adapter import qsdk_r23d13_residual_pose_authority as policy


class R23D13NativeAuthorityTests(unittest.TestCase):
    def test_ten_canaries_cover_positive_negative_and_passive_shapes(self) -> None:
        receipt = policy.preflight()
        self.assertEqual(receipt["valid_canary_count"], 10)
        self.assertTrue(receipt["critical_r23d12_negative_shape_passed"])
        self.assertTrue(receipt["positive_tight_pose_no_regression_canary_passed"])
        self.assertTrue(receipt["passive_exact_zero_actuation_canary_passed"])
        self.assertEqual(len(receipt["valid_canary_vector"].splitlines()), 10)

    def test_twenty_mutations_fail_with_exact_codes(self) -> None:
        codes: list[str] = []
        for mutation in policy._mutations():
            with self.assertRaises(policy.NativeAuthorityError) as caught:
                policy.apply_residual_pose_authority(mutation)
            codes.append(str(caught.exception))
        self.assertEqual(tuple(codes), policy.EXPECTED_MUTATION_CODES)

    def test_authority_never_reduces_time_and_scales_once(self) -> None:
        base = policy._baseline()
        negative = policy.replace(
            base,
            torso_tilt_rad=0.02039827933466296,
            maximum_absolute_joint_position_error_rad=0.2375508558310486,
        )
        receipt = policy.apply_residual_pose_authority(negative)
        self.assertEqual(receipt["pose_authority_floor_numerator"], 50)
        self.assertEqual(receipt["applied_scale_numerator"], 50)
        for source, actual in zip(
            base.combined_pre_taper_velocities_rad_s,
            receipt["final_canonical_velocities_rad_s"],
            strict=True,
        ):
            self.assertAlmostEqual(actual, float(source) * 50.0 / 120.0, places=15)

    def test_preflight_is_deterministic_and_nonphysical(self) -> None:
        first = policy.preflight()
        second = policy.preflight()
        self.assertEqual(
            json.dumps(first, sort_keys=True, separators=(",", ":")),
            json.dumps(second, sort_keys=True, separators=(",", ":")),
        )
        self.assertFalse(first["reference_oracle_imported"])
        self.assertFalse(first["physical_worker_implemented"])
        self.assertFalse(first["physical_execution_authorized"])
        self.assertEqual(first["model_construction_count"], 0)
        self.assertEqual(first["world_build_count"], 0)


if __name__ == "__main__":
    unittest.main()
