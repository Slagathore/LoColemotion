from __future__ import annotations

import unittest

try:
    from . import terminal_tight_first_horizon_development as candidate
except ImportError:  # pragma: no cover - direct invocation route
    import terminal_tight_first_horizon_development as candidate


class TightFirstHorizonDevelopmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tight = candidate.Observation((True, True, True, True), 0.005, 0.1)
        self.coarse = candidate.Observation((True, True, True, True), 0.02, 0.25)

    def test_horizons_are_exact_and_thresholds_are_inherited(self) -> None:
        self.assertEqual(candidate.MAXIMUM_ACTIVE_STEPS, 600)
        self.assertEqual(candidate.TERMINAL_STEPS, 960)
        self.assertEqual(candidate.MINIMUM_TAPER_STEPS, 120)
        self.assertEqual(candidate.MINIMUM_PASSIVE_STEPS, 360)
        self.assertTrue(candidate.tight_pose_satisfied(self.tight))
        self.assertFalse(candidate.tight_pose_satisfied(self.coarse))

    def test_retained_v1_timing_now_finishes_confirmation(self) -> None:
        observations = [self.coarse] * 459 + [self.tight] * 501
        result = candidate.simulate(observations)
        self.assertEqual(result["outcome"]["handoff_after_active_step"], 579)
        self.assertEqual(result["outcome"]["first_passive_step"], 580)
        self.assertEqual(result["outcome"]["passive_step_count"], 380)
        self.assertTrue(result["outcome"]["quiescent_taper_gate_passed"])

    def test_coarse_only_uses_new_deadline_without_passing(self) -> None:
        result = candidate.simulate([self.coarse] * 960)
        self.assertEqual(result["outcome"]["handoff_after_active_step"], 599)
        self.assertEqual(result["outcome"]["passive_step_count"], 360)
        self.assertFalse(result["outcome"]["quiescent_taper_gate_passed"])

    def test_outcome_refuses_old_or_incomplete_horizon(self) -> None:
        with self.assertRaises(candidate.ContractError):
            candidate.outcome(candidate.State(next_step=900))

    def test_zero_world_preflight_has_no_authority(self) -> None:
        receipt = candidate.run_zero_world_preflight()
        self.assertEqual(receipt["check_count"], 8)
        self.assertEqual(receipt["observed_first_tight_active_index"], 459)
        self.assertEqual(receipt["predicted_confirmation_active_index"], 579)
        self.assertEqual(receipt["active_margin_steps"], 20)
        self.assertEqual(receipt["predicted_passive_steps"], 380)
        self.assertTrue(receipt["development_only"])
        self.assertFalse(receipt["validation_authority"])
        self.assertFalse(receipt["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
