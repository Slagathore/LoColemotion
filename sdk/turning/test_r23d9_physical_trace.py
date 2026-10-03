"""Production-shaped zero-world trace tests for QSDK-R23D9."""

from __future__ import annotations

import copy
import unittest

import r23d9_support_handoff as design


class R23D9PhysicalTraceTests(unittest.TestCase):
    def test_declared_cell_identity_and_order_are_exact(self) -> None:
        self.assertEqual(
            [cell.cell_id for cell in design.stage_a_cells()],
            [
                "mujoco__support_handoff__positive_heading",
                "mujoco__support_handoff__negative_heading",
            ],
        )
        self.assertEqual(len(design.stage_b_cells()), 9)
        self.assertEqual(
            [cell.engine_id for cell in design.stage_b_cells()],
            ["godot_jolt"] * 3 + ["rapier_parry"] * 3 + ["mujoco"] * 3,
        )

    def test_all_eleven_synthetic_traces_replay_exactly(self) -> None:
        for cell in design.all_cells():
            result = design.validate_trace(cell, design.synthetic_trace(cell))
            self.assertTrue(result["ok"], (cell.cell_id, result["failure_codes"][:4]))
            self.assertEqual(result["row_count"], design.TOTAL_TRACE_STEPS)
            self.assertEqual(
                result["phase_counts"]["terminal_neutral_acquisition"], 30
            )
            self.assertEqual(
                result["phase_counts"][
                    "terminal_irreversible_zero_actuation"
                ],
                750,
            )
            self.assertTrue(
                result["handoff_outcome"]["irreversible_handoff_gate_passed"]
            )

    def test_valid_deadline_and_contact_loss_traces_remain_negative(self) -> None:
        cell = design.stage_a_cells()[0]
        deadline_rows = design.synthetic_trace(
            cell,
            [(False, False, False, False)] * design.TERMINAL_STEPS,
        )
        deadline = design.validate_trace(cell, deadline_rows)
        self.assertTrue(deadline["ok"], deadline["failure_codes"][:4])
        self.assertFalse(
            deadline["handoff_outcome"]["irreversible_handoff_gate_passed"]
        )
        self.assertEqual(
            deadline["handoff_outcome"]["handoff_reason"],
            design.DEADLINE_FORCED_REASON,
        )

        contacts = [(True, True, True, True)] * design.TERMINAL_STEPS
        contacts[40] = (True, True, True, False)
        loss = design.validate_trace(cell, design.synthetic_trace(cell, contacts))
        self.assertTrue(loss["ok"], loss["failure_codes"][:4])
        self.assertFalse(
            loss["handoff_outcome"]["irreversible_handoff_gate_passed"]
        )
        self.assertEqual(
            loss["handoff_outcome"]["first_post_handoff_contact_loss_step"],
            40,
        )

    def test_terminal_mutations_fail_closed(self) -> None:
        cell = design.stage_a_cells()[0]
        baseline = design.synthetic_trace(cell)
        cases: list[list[dict[str, object]]] = []

        changed_counter = copy.deepcopy(baseline)
        changed_counter[design.CONTROLLER_STEPS + 12][
            "post_step_support_counter"
        ] = 99
        cases.append(changed_counter)

        hidden_application = copy.deepcopy(baseline)
        hidden_application[design.CONTROLLER_STEPS + 40][
            "native_actuation_application_count"
        ] = design.ACTUATOR_COUNT
        cases.append(hidden_application)

        same_step_transition = copy.deepcopy(baseline)
        same_step_transition[design.CONTROLLER_STEPS + 29]["phase_id"] = (
            "terminal_irreversible_zero_actuation"
        )
        cases.append(same_step_transition)

        contact_rewrite = copy.deepcopy(baseline)
        contact_rewrite[design.CONTROLLER_STEPS + 10]["ordered_foot_contacts"][
            "rear_right"
        ] = False
        cases.append(contact_rewrite)

        for rows in cases:
            result = design.validate_trace(cell, rows)
            self.assertFalse(result["ok"])
            self.assertTrue(result["failure_codes"])

    def test_short_or_noncanonical_shape_fails_closed(self) -> None:
        cell = design.stage_a_cells()[0]
        shortened = design.synthetic_trace(cell)[:-1]
        result = design.validate_trace(cell, shortened)
        self.assertFalse(result["ok"])
        self.assertIn("R23D9_TRACE_ROW_COUNT", result["failure_codes"])

        extra = design.synthetic_trace(cell)
        extra[0]["undeclared"] = True
        result = design.validate_trace(cell, extra)
        self.assertFalse(result["ok"])
        self.assertIn("R23D9_TRACE_ROW_FIELDS:0", result["failure_codes"])


if __name__ == "__main__":
    unittest.main()
