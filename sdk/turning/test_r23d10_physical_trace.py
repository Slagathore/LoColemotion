"""Production-shaped zero-world trace tests for QSDK-R23D10."""

from __future__ import annotations

import copy
from pathlib import Path
import sys
import unittest


MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d10_physical_trace as trace


SUPPORTED = (True, True, True, True)
PARTIAL = (True, True, True, False)


class R23D10PhysicalTraceTests(unittest.TestCase):
    def test_declared_cell_identity_and_order_are_exact(self) -> None:
        self.assertEqual(
            [cell.cell_id for cell in trace.stage_a_cells()],
            [
                "mujoco__quiescent_taper__positive_heading",
                "mujoco__quiescent_taper__negative_heading",
            ],
        )
        self.assertEqual(len(trace.stage_b_cells()), 9)
        self.assertEqual(
            [cell.engine_id for cell in trace.stage_b_cells()],
            ["godot_jolt"] * 3 + ["rapier_parry"] * 3 + ["mujoco"] * 3,
        )

    def test_all_eleven_synthetic_traces_replay_exactly(self) -> None:
        for cell in trace.all_cells():
            result = trace.validate_trace(cell, trace.synthetic_trace(cell))
            self.assertTrue(result["ok"], (cell.cell_id, result["failure_codes"][:4]))
            self.assertEqual(result["row_count"], 3_892)
            self.assertEqual(result["phase_counts"]["terminal_neutral_acquisition"], 1)
            self.assertEqual(result["phase_counts"]["terminal_quiescent_taper"], 120)
            self.assertEqual(result["phase_counts"]["terminal_irreversible_zero_actuation"], 779)
            outcome = result["taper_outcome"]
            self.assertTrue(outcome["quiescent_taper_gate_passed"])
            self.assertEqual(outcome["handoff_after_active_step"], 120)

    def test_deadline_reset_and_contact_loss_remain_valid_negatives(self) -> None:
        cell = trace.stage_a_cells()[0]
        deadline_rows = trace.observations((900, SUPPORTED, 0.03, 0.30))
        deadline = trace.validate_trace(cell, trace.synthetic_trace(cell, deadline_rows))
        self.assertTrue(deadline["ok"], deadline["failure_codes"][:4])
        self.assertFalse(deadline["taper_outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(deadline["taper_outcome"]["handoff_after_active_step"], 539)

        reset_rows = trace.observations(
            (10, PARTIAL, 0.005, 0.18),
            (51, SUPPORTED, 0.005, 0.18),
            (1, PARTIAL, 0.005, 0.18),
            (838, SUPPORTED, 0.005, 0.18),
        )
        reset = trace.validate_trace(cell, trace.synthetic_trace(cell, reset_rows))
        self.assertTrue(reset["ok"], reset["failure_codes"][:4])
        self.assertEqual(reset["taper_outcome"]["taper_reset_count"], 1)
        self.assertTrue(reset["taper_outcome"]["quiescent_taper_gate_passed"])

        loss_rows = trace.observations(
            (500, SUPPORTED, 0.005, 0.18),
            (1, PARTIAL, 0.005, 0.18),
            (399, SUPPORTED, 0.005, 0.18),
        )
        loss = trace.validate_trace(cell, trace.synthetic_trace(cell, loss_rows))
        self.assertTrue(loss["ok"], loss["failure_codes"][:4])
        self.assertFalse(loss["taper_outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(loss["taper_outcome"]["first_post_handoff_contact_loss_step"], 500)

    def test_terminal_receipt_and_actuation_mutations_fail_closed(self) -> None:
        cell = trace.stage_a_cells()[0]
        baseline = trace.synthetic_trace(cell)
        cases: list[list[dict[str, object]]] = []

        changed_count = copy.deepcopy(baseline)
        changed_count[trace.CONTROLLER_STEPS + 50]["post_step_taper_count"] = 99
        cases.append(changed_count)

        changed_scale = copy.deepcopy(baseline)
        changed_scale[trace.CONTROLLER_STEPS + 50]["velocity_scale_numerator"] = 99
        cases.append(changed_scale)

        early_phase = copy.deepcopy(baseline)
        early_phase[trace.CONTROLLER_STEPS + 120]["phase_id"] = (
            "terminal_irreversible_zero_actuation"
        )
        cases.append(early_phase)

        hidden_application = copy.deepcopy(baseline)
        hidden_application[trace.CONTROLLER_STEPS + 500][
            "native_actuation_application_count"
        ] = 8
        cases.append(hidden_application)

        changed_pose = copy.deepcopy(baseline)
        changed_pose[trace.CONTROLLER_STEPS + 10]["torso_tilt_rad"] = 0.04
        cases.append(changed_pose)

        excessive_velocity = copy.deepcopy(baseline)
        excessive_velocity[trace.CONTROLLER_STEPS + 60][
            "maximum_absolute_commanded_joint_velocity_rad_s"
        ] = 0.35
        cases.append(excessive_velocity)

        for rows in cases:
            result = trace.validate_trace(cell, rows)
            self.assertFalse(result["ok"])
            self.assertTrue(result["failure_codes"])

    def test_short_or_noncanonical_shape_fails_closed(self) -> None:
        cell = trace.stage_a_cells()[0]
        result = trace.validate_trace(cell, trace.synthetic_trace(cell)[:-1])
        self.assertFalse(result["ok"])
        self.assertIn("R23D10_TRACE_ROW_COUNT", result["failure_codes"])

        extra = trace.synthetic_trace(cell)
        extra[0]["undeclared"] = True
        result = trace.validate_trace(cell, extra)
        self.assertFalse(result["ok"])
        self.assertIn("R23D10_TRACE_ROW_FIELDS:0", result["failure_codes"])


if __name__ == "__main__":
    unittest.main()
