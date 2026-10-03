"""Zero-world canaries and mutations for the R23D14 temporal oracle."""

from __future__ import annotations

from dataclasses import replace
import math
import unittest

from . import r23d14_tight_gated_horizon as policy


class R23D14TightGatedHorizonTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tight = policy.Observation((True, True, True, True), 0.005, 0.1)
        self.coarse = policy.Observation((True, True, True, True), 0.02, 0.25)
        self.unsupported = policy.Observation(
            (True, True, True, False), 0.005, 0.1
        )

    def advance(
        self, state: policy.State, observation: policy.Observation
    ) -> tuple[policy.State, dict[str, object]]:
        numerator, denominator = policy.expected_velocity_scale_fraction(state)
        applications = 0 if state.mode == policy.PASSIVE_MODE else 8
        return policy.observe_completed_step(
            state, observation, applications, numerator, denominator
        )

    def test_twelve_declared_canaries_have_zero_world_authority(self) -> None:
        receipt = policy.run_zero_world_preflight()
        self.assertEqual(receipt["check_count"], 12)
        self.assertTrue(all(receipt["checks"].values()))
        self.assertFalse(receipt["arm_identity_or_heading_sign_used"])
        self.assertEqual(receipt["native_engine_route_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])

    def test_only_tight_pose_enters_and_sustains_taper(self) -> None:
        state, coarse_receipt = self.advance(policy.State(), self.coarse)
        self.assertEqual(state.mode, policy.ACTIVE_MODE)
        self.assertFalse(coarse_receipt["transition_after_step"])
        state, tight_receipt = self.advance(state, self.tight)
        self.assertEqual(state.mode, policy.TAPER_MODE)
        self.assertTrue(tight_receipt["transition_after_step"])
        state, reset = self.advance(state, self.unsupported)
        self.assertEqual(state.mode, policy.ACTIVE_MODE)
        self.assertTrue(reset["taper_reset_after_step"])
        self.assertEqual(state.taper_reset_count, 1)

    def test_retained_positive_and_negative_timings_complete(self) -> None:
        positive = policy.simulate([self.coarse] * 318 + [self.tight] * 642)
        negative = policy.simulate([self.coarse] * 459 + [self.tight] * 501)
        self.assertEqual(positive["outcome"]["handoff_after_active_step"], 438)
        self.assertEqual(positive["outcome"]["passive_step_count"], 521)
        self.assertEqual(negative["outcome"]["handoff_after_active_step"], 579)
        self.assertEqual(negative["outcome"]["passive_step_count"], 380)
        self.assertTrue(positive["outcome"]["quiescent_taper_gate_passed"])
        self.assertTrue(negative["outcome"]["quiescent_taper_gate_passed"])

    def test_deadline_control_preserves_passive_horizon_but_fails(self) -> None:
        result = policy.simulate([self.coarse] * 960)
        self.assertEqual(result["outcome"]["handoff_after_active_step"], 599)
        self.assertEqual(result["outcome"]["first_passive_step"], 600)
        self.assertEqual(result["outcome"]["passive_step_count"], 360)
        self.assertFalse(result["outcome"]["quiescent_taper_gate_passed"])

    def test_post_handoff_contact_loss_is_observed_and_fails(self) -> None:
        observations = [self.tight] * 121 + [self.unsupported] + [self.tight] * 838
        result = policy.simulate(observations)
        self.assertEqual(result["outcome"]["first_post_handoff_contact_loss_step"], 121)
        self.assertEqual(result["outcome"]["post_handoff_contact_loss_step_count"], 1)
        self.assertFalse(result["outcome"]["quiescent_taper_gate_passed"])

    def test_fourteen_mutation_controls_fail_closed(self) -> None:
        invalid_observations = (
            (
                "R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
                replace(self.tight, contacts=(True, True, True)),
            ),
            (
                "R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
                replace(self.tight, contacts=(True, True, True, 1)),
            ),
            (
                "R23D14_OBSERVATION_NUMERIC_TYPE_INVALID",
                replace(self.tight, torso_tilt_rad="0.005"),
            ),
            (
                "R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
                replace(self.tight, torso_tilt_rad=math.nan),
            ),
            (
                "R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
                replace(
                    self.tight,
                    maximum_absolute_joint_position_error_rad=-0.1,
                ),
            ),
        )
        for code, observation in invalid_observations:
            with self.assertRaisesRegex(policy.ContractError, f"^{code}$"):
                self.advance(policy.State(), observation)  # type: ignore[arg-type]

        controls = (
            (
                "R23D14_STEP_OUTSIDE_HORIZON",
                policy.State(next_step=960),
                self.tight,
                8,
                120,
                120,
            ),
            (
                "R23D14_STATE_MODE_INVALID",
                policy.State(mode="negative_heading_recovery"),
                self.tight,
                8,
                120,
                120,
            ),
            (
                "R23D14_VELOCITY_SCALE_MISMATCH",
                policy.State(),
                self.tight,
                8,
                119,
                120,
            ),
            (
                "R23D14_VELOCITY_SCALE_MISMATCH",
                policy.State(),
                self.tight,
                8,
                120,
                119,
            ),
            (
                "R23D14_APPLICATION_COUNT_MISMATCH",
                policy.State(),
                self.tight,
                0,
                120,
                120,
            ),
            (
                "R23D14_APPLICATION_COUNT_MISMATCH",
                policy.State(mode=policy.PASSIVE_MODE),
                self.tight,
                8,
                0,
                120,
            ),
        )
        for code, state, observation, applications, numerator, denominator in controls:
            with self.assertRaisesRegex(policy.ContractError, f"^{code}$"):
                policy.observe_completed_step(
                    state, observation, applications, numerator, denominator
                )
        with self.assertRaisesRegex(
            policy.ContractError, "^R23D14_OBSERVATION_HORIZON_INVALID$"
        ):
            policy.simulate([self.tight] * 959)
        with self.assertRaisesRegex(
            policy.ContractError, "^R23D14_OBSERVATION_HORIZON_INVALID$"
        ):
            policy.simulate([self.tight] * 961)
        with self.assertRaisesRegex(
            policy.ContractError, "^R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON$"
        ):
            policy.outcome(policy.State(next_step=959))
        self.assertEqual(len(invalid_observations) + len(controls) + 3, 14)


if __name__ == "__main__":
    unittest.main()
