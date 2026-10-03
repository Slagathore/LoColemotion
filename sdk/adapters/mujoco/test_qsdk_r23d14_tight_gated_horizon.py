"""Zero-world tests for the independent MuJoCo/Python R23D14 mirror."""

from __future__ import annotations

import json
import unittest

from sporespore_mujoco_adapter import qsdk_r23d14_tight_gated_horizon as policy


class R23D14NativeTemporalTests(unittest.TestCase):
    def test_twelve_canaries_cover_both_retained_timings_and_passive_zero(self) -> None:
        receipt = policy.preflight()
        self.assertEqual(receipt["valid_canary_count"], 12)
        self.assertEqual(len(receipt["valid_canary_vector"].splitlines()), 12)
        self.assertTrue(receipt["retained_positive_timing_shape_passed"])
        self.assertTrue(receipt["retained_negative_timing_shape_passed"])
        self.assertTrue(receipt["passive_exact_zero_actuation_canary_passed"])

    def test_fourteen_mutations_fail_with_exact_codes(self) -> None:
        codes: list[str] = []
        for action in policy._mutation_actions():
            with self.assertRaises(policy.NativeTemporalError) as caught:
                action()
            codes.append(str(caught.exception))
        self.assertEqual(tuple(codes), policy.EXPECTED_MUTATION_CODES)

    def test_tight_gating_resets_and_deadline_cannot_pass(self) -> None:
        state, _ = policy.observe_completed_step(
            policy.State(), policy.TIGHT, 8, 120, 120
        )
        self.assertEqual(state.mode, policy.TAPER_MODE)
        state, receipt = policy.observe_completed_step(
            state, policy.UNSUPPORTED, 8, 120, 120
        )
        self.assertEqual(state.mode, policy.ACTIVE_MODE)
        self.assertTrue(receipt["taper_reset_after_step"])
        deadline = policy.simulate([policy.COARSE] * policy.TERMINAL_STEPS)
        self.assertFalse(deadline["quiescent_taper_gate_passed"])
        self.assertEqual(deadline["passive_step_count"], 360)

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
