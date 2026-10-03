"""Zero-world schedule and trace tests for prospective QSDK-R23D8."""

from __future__ import annotations

import unittest

from . import r23d8_terminal_stance as design


class R23D8TerminalStanceTests(unittest.TestCase):
    def test_contract_and_cell_order_are_frozen(self) -> None:
        contract = design.load_contract()
        self.assertEqual(contract["gate_id"], "QSDK-R23D8")
        self.assertEqual(
            [cell.cell_id for cell in design.stage_a_cells()],
            [
                "mujoco__neutral_stance__positive_heading",
                "mujoco__neutral_stance__negative_heading",
            ],
        )
        self.assertEqual(
            [cell.cell_id for cell in design.stage_b_cells()],
            [
                f"{engine_id}__neutral_stance__{arm_id}"
                for engine_id in design.STAGE_B_ENGINES
                for arm_id in design.STAGE_B_ARMS
            ],
        )
        self.assertEqual(len(design.stage_b_cells()), 9)
        self.assertEqual(len(design.all_cells()), 11)
        self.assertEqual(
            len({(cell.stage_id, cell.cell_id) for cell in design.all_cells()}),
            11,
        )

    def test_schedule_keeps_controller_stance_and_passive_phases_distinct(self) -> None:
        cell = design.stage_a_cells()[0]
        expected = [
            (0, "reference_warmup", 0),
            (599, "reference_warmup", 599),
            (600, "commanded_turn", 600),
            (1799, "commanded_turn", 1799),
            (1800, "reference_recovery", 1800),
            (2399, "reference_recovery", 2399),
            (2400, "reference_continuation", 2400),
            (2991, "reference_continuation", 2991),
            (2992, "terminal_neutral_stance_acquisition", None),
            (3171, "terminal_neutral_stance_acquisition", None),
            (3172, "terminal_neutral_stance_hold", None),
            (3531, "terminal_neutral_stance_hold", None),
            (3532, "passive_zero_actuation_settle", None),
            (3771, "passive_zero_actuation_settle", None),
        ]
        for step, phase, controller_step in expected:
            observed = design.phase_for_trace_step(cell, step)
            self.assertEqual(observed[0], phase)
            self.assertEqual(observed[1], controller_step)
        self.assertEqual(sum(design.expected_phase_counts().values()), 3772)

    def test_complete_synthetic_traces_validate(self) -> None:
        for cell in design.all_cells():
            result = design.validate_trace(cell, design.synthetic_trace(cell))
            self.assertTrue(result["ok"], result["failure_codes"][:3])
            self.assertEqual(result["row_count"], 3772)
            self.assertEqual(result["phase_counts"], design.expected_phase_counts())

    def test_trace_rejects_passive_actuation_and_missing_neutral_target(self) -> None:
        cell = design.stage_a_cells()[0]
        passive_actuation = design.synthetic_trace(cell)
        passive_actuation[design.ACTIVE_STEPS]["native_actuation_application_count"] = 8
        self.assertFalse(design.validate_trace(cell, passive_actuation)["ok"])

        missing_target = design.synthetic_trace(cell)
        missing_target[design.CONTROLLER_STEPS]["neutral_target_activation_count"] = 7
        self.assertFalse(design.validate_trace(cell, missing_target)["ok"])

    def test_trace_rejects_over_speed_terminal_command(self) -> None:
        cell = design.stage_a_cells()[0]
        rows = design.synthetic_trace(cell)
        rows[design.CONTROLLER_STEPS][
            "maximum_absolute_commanded_joint_velocity_rad_s"
        ] = 0.350000000002
        self.assertFalse(design.validate_trace(cell, rows)["ok"])


if __name__ == "__main__":
    unittest.main()
