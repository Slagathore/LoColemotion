from __future__ import annotations

import copy
import unittest

import r23d9_support_handoff as design


DOWN = (False, False, False, False)
PARTIAL = (True, True, True, False)
SUPPORTED = (True, True, True, True)


class R23D9SupportHandoffTests(unittest.TestCase):
    def test_zero_world_preflight_covers_all_controls(self) -> None:
        report = design.run_zero_world_preflight()
        self.assertTrue(report["ok"])
        self.assertEqual(report["oracle_canary_count"], 5)
        self.assertEqual(report["mutation_control_count"], 12)
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physical_execution_authorized"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_confirming_observation_changes_the_following_step(self) -> None:
        state = design.initial_state()
        for step in range(design.SUPPORT_CONFIRMATION_STEPS):
            directive = design.plan_step(state)
            self.assertEqual(directive.step, step)
            self.assertEqual(directive.mode, design.ACTIVE_MODE)
            self.assertTrue(directive.apply_neutral_commands)
            state, receipt = design.observe_completed_step(
                state,
                directive,
                SUPPORTED,
                design.ACTUATOR_COUNT,
            )
        self.assertTrue(receipt["transition_after_step"])
        self.assertEqual(receipt["handoff_reason"], design.SUPPORT_CONFIRMED_REASON)
        self.assertEqual(state.handoff_after_active_step, 29)
        self.assertEqual(state.first_passive_step, 30)
        next_directive = design.plan_step(state)
        self.assertEqual(next_directive.mode, design.PASSIVE_MODE)
        self.assertFalse(next_directive.apply_neutral_commands)
        self.assertEqual(next_directive.expected_native_application_count, 0)

    def test_contact_counter_resets_and_transients_do_not_handoff(self) -> None:
        sequence = design._rows(
            (100, DOWN),
            (23, SUPPORTED),
            (1, PARTIAL),
            (16, SUPPORTED),
            (1, PARTIAL),
            (159, DOWN),
            (480, SUPPORTED),
        )
        receipts, observed = design.simulate(sequence)
        self.assertEqual(receipts[122]["post_step_support_counter"], 23)
        self.assertEqual(receipts[123]["post_step_support_counter"], 0)
        self.assertEqual(receipts[139]["post_step_support_counter"], 16)
        self.assertEqual(receipts[140]["post_step_support_counter"], 0)
        self.assertEqual(observed["handoff_after_active_step"], 329)
        self.assertEqual(observed["first_passive_step"], 330)
        self.assertTrue(observed["irreversible_handoff_gate_passed"])

    def test_deadline_forces_zero_actuation_but_cannot_pass(self) -> None:
        receipts, observed = design.simulate([DOWN] * design.TERMINAL_STEPS)
        self.assertEqual(observed["handoff_after_active_step"], 419)
        self.assertEqual(observed["first_passive_step"], 420)
        self.assertEqual(observed["handoff_reason"], design.DEADLINE_FORCED_REASON)
        self.assertFalse(observed["support_confirmed"])
        self.assertFalse(observed["irreversible_handoff_gate_passed"])
        self.assertEqual(observed["passive_step_count"], 360)
        self.assertEqual(receipts[420]["mode"], design.PASSIVE_MODE)
        self.assertEqual(receipts[420]["native_application_count"], 0)

    def test_post_handoff_contact_loss_fails_without_reactivation(self) -> None:
        sequence = design._rows(
            (30, SUPPORTED),
            (10, SUPPORTED),
            (1, PARTIAL),
            (739, SUPPORTED),
        )
        receipts, observed = design.simulate(sequence)
        self.assertFalse(observed["irreversible_handoff_gate_passed"])
        self.assertEqual(observed["post_handoff_contact_loss_step_count"], 1)
        self.assertEqual(observed["first_post_handoff_contact_loss_step"], 40)
        self.assertTrue(all(row["mode"] == design.PASSIVE_MODE for row in receipts[30:]))
        self.assertTrue(
            all(row["native_application_count"] == 0 for row in receipts[30:])
        )

    def test_invalid_contact_and_application_shapes_fail_closed(self) -> None:
        with self.assertRaises(design.R23D9Error):
            design._contacts((True, True, True))
        with self.assertRaises(design.R23D9Error):
            design._contacts((True, True, True, 1))  # type: ignore[arg-type]
        state = design.initial_state()
        directive = design.plan_step(state)
        with self.assertRaises(design.R23D9Error):
            design.observe_completed_step(state, directive, SUPPORTED, 0)
        with self.assertRaises(design.R23D9Error):
            design.observe_completed_step(
                state,
                copy.copy(directive).__class__(
                    step=1,
                    mode=directive.mode,
                    apply_neutral_commands=True,
                    expected_native_application_count=design.ACTUATOR_COUNT,
                    pre_step_support_counter=0,
                ),
                SUPPORTED,
                design.ACTUATOR_COUNT,
            )

    def test_every_named_mutation_is_rejected_by_exact_replay(self) -> None:
        failures = design._mutation_control_failures()
        self.assertEqual(list(failures), [
            "transitioned_after_one_contact_step",
            "transitioned_after_twenty_nine_contact_steps",
            "did_not_reset_counter_on_contact_loss",
            "counted_partial_contact_as_all_four",
            "applied_transition_to_confirming_step_instead_of_next_step",
            "reactivated_after_post_handoff_contact_loss",
            "applied_native_actuation_after_handoff",
            "forced_deadline_before_420_active_steps",
            "allowed_active_step_after_deadline",
            "allowed_deadline_forced_handoff_to_pass",
            "stopped_outcome_execution_early",
            "changed_total_terminal_horizon",
        ])
        self.assertTrue(all(value for value in failures.values()))


if __name__ == "__main__":
    unittest.main()
