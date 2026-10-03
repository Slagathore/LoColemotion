from __future__ import annotations

import unittest

try:
    from . import terminal_tight_first_development as candidate
except ImportError:  # pragma: no cover - direct invocation route
    import terminal_tight_first_development as candidate


class TightFirstDevelopmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tight = candidate.Observation((True, True, True, True), 0.005, 0.1)
        self.coarse = candidate.Observation((True, True, True, True), 0.02, 0.25)

    def advance(
        self, state: candidate.State, observation: candidate.Observation
    ) -> tuple[candidate.State, dict[str, object]]:
        numerator, denominator = candidate.expected_velocity_scale_fraction(state)
        applications = 0 if state.mode == candidate.PASSIVE_MODE else 8
        return candidate.observe_completed_step(
            state, observation, applications, numerator, denominator
        )

    def test_coarse_without_tight_keeps_full_acquisition(self) -> None:
        state, receipt = self.advance(candidate.State(), self.coarse)
        self.assertEqual(state.mode, candidate.ACTIVE_MODE)
        self.assertEqual(
            candidate.expected_velocity_scale_fraction(state), (120, 120)
        )
        self.assertFalse(receipt["transition_after_step"])

    def test_tight_enters_taper_and_loss_resets(self) -> None:
        state, receipt = self.advance(candidate.State(), self.tight)
        self.assertEqual(receipt["next_mode"], candidate.TAPER_MODE)
        state, receipt = self.advance(state, self.coarse)
        self.assertEqual(receipt["next_mode"], candidate.ACTIVE_MODE)
        self.assertTrue(receipt["taper_reset_after_step"])
        self.assertEqual(state.taper_reset_count, 1)

    def test_continuous_tight_completes_frozen_handoff(self) -> None:
        result = candidate.simulate([self.tight] * candidate.TERMINAL_STEPS)
        self.assertTrue(result["outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(result["outcome"]["first_passive_step"], 121)
        self.assertEqual(result["outcome"]["passive_step_count"], 779)

    def test_coarse_only_reaches_unchanged_deadline_and_fails(self) -> None:
        result = candidate.simulate([self.coarse] * candidate.TERMINAL_STEPS)
        self.assertFalse(result["outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(result["outcome"]["handoff_after_active_step"], 539)
        self.assertEqual(result["outcome"]["passive_step_count"], 360)

    def test_scale_and_application_mismatches_fail_closed(self) -> None:
        with self.assertRaises(candidate.ContractError):
            candidate.observe_completed_step(
                candidate.State(), self.tight, 8, 119, 120
            )
        with self.assertRaises(candidate.ContractError):
            candidate.observe_completed_step(
                candidate.State(), self.tight, 0, 120, 120
            )

    def test_zero_world_preflight_has_no_authority(self) -> None:
        receipt = candidate.run_zero_world_preflight()
        self.assertEqual(receipt["check_count"], 6)
        self.assertTrue(receipt["development_only"])
        self.assertFalse(receipt["arm_identity_or_heading_sign_used"])
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["validation_authority"])
        self.assertFalse(receipt["physical_acceptance_authority"])
        self.assertFalse(receipt["release_authorized"])


if __name__ == "__main__":
    unittest.main()
