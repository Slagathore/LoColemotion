"""Zero-world tests for the independent MuJoCo/Python R23D11 mirror."""

from __future__ import annotations

import unittest

from sporespore_mujoco_adapter import qsdk_r23d11_stability_assisted_taper as policy


class StabilityAssistedTaperTests(unittest.TestCase):
    def test_complete_native_preflight(self) -> None:
        receipt = policy.preflight(
            "mujoco_stability_assisted_taper_screen", "negative_heading"
        )
        self.assertEqual(receipt["composition_canary_count"], 7)
        self.assertEqual(receipt["mutation_control_count"], 18)
        self.assertEqual(receipt["inherited_temporal_canary_count"], 5)
        self.assertTrue(receipt["native_composition_mirror"])
        self.assertTrue(receipt["physical_worker_implemented"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_identity_is_finite_and_fail_closed(self) -> None:
        for stage_id, arm_id in (
            ("mujoco_stability_assisted_taper_screen", "reference_zero"),
            ("three_engine_confirmation", "unknown"),
            ("wrong", "positive_heading"),
        ):
            with self.assertRaisesRegex(
                policy.NativeContractError, "R23D11_MJC_CELL_IDENTITY_INVALID"
            ):
                policy.preflight(stage_id, arm_id)

    def test_passive_composition_is_exact_zero(self) -> None:
        receipt = policy.compose_passive_step(tuple(f"actuator_{i}" for i in range(8)))
        self.assertEqual(receipt["native_actuation_application_count"], 0)
        self.assertTrue(
            all(row["canonical_velocity_rad_s"] == 0.0 for row in receipt["ordered_actuator_commands"])
        )
        self.assertFalse(receipt["neutral_composition_invoked"])
        self.assertFalse(receipt["stability_composition_invoked"])


if __name__ == "__main__":
    unittest.main()
