"""Production-shaped zero-world trace tests for QSDK-R23D18."""

from __future__ import annotations

import copy
from pathlib import Path
import sys
import unittest


MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d18_physical_trace as trace


SUPPORTED = (True, True, True, True)
PARTIAL = (True, True, True, False)


class R23D18PhysicalTraceTests(unittest.TestCase):
    def test_matrix_identity_order_and_horizons_are_exact(self) -> None:
        cells = trace.matrix_cells()
        self.assertEqual(len(cells), 9)
        self.assertEqual(
            [cell.engine_id for cell in cells],
            ["godot_jolt"] * 3 + ["rapier_parry"] * 3 + ["mujoco"] * 3,
        )
        self.assertEqual(
            [cell.arm_id for cell in cells],
            list(trace.MATRIX_ARMS) * 3,
        )
        self.assertEqual(trace.CONTROLLER_STEPS, 2_992)
        self.assertEqual(trace.TERMINAL_STEPS, 960)
        self.assertEqual(trace.TOTAL_TRACE_STEPS, 3_952)

    def test_all_nine_synthetic_traces_replay_exactly(self) -> None:
        for cell in trace.matrix_cells():
            result = trace.validate_trace(cell, trace.synthetic_trace(cell))
            self.assertTrue(result["ok"], (cell.cell_id, result["failure_codes"][:6]))
            self.assertEqual(result["row_count"], 3_952)
            self.assertEqual(result["phase_counts"]["terminal_neutral_acquisition"], 1)
            self.assertEqual(result["phase_counts"]["terminal_quiescent_taper"], 120)
            self.assertEqual(
                result["phase_counts"]["terminal_irreversible_zero_actuation"],
                839,
            )
            self.assertTrue(result["taper_outcome"]["quiescent_taper_gate_passed"])
            self.assertEqual(result["taper_outcome"]["passive_step_count"], 839)
            self.assertEqual(
                result["authority_outcome"]["passive_exact_zero_row_count"], 839
            )

    def test_retained_positive_and_negative_timing_shapes_pass(self) -> None:
        cell = trace.matrix_cells()[0]
        shapes = (
            (318, 438, 521),
            (459, 579, 380),
        )
        for coarse_steps, handoff, passive_steps in shapes:
            observations = trace.observations(
                (coarse_steps, SUPPORTED, 0.02, 0.25),
                (960 - coarse_steps, SUPPORTED, 0.005, 0.1),
            )
            result = trace.validate_trace(cell, trace.synthetic_trace(cell, observations))
            self.assertTrue(result["ok"], result["failure_codes"][:6])
            outcome = result["taper_outcome"]
            self.assertTrue(outcome["quiescent_taper_gate_passed"])
            self.assertEqual(outcome["handoff_after_active_step"], handoff)
            self.assertEqual(outcome["passive_step_count"], passive_steps)

    def test_deadline_reset_and_contact_loss_are_valid_negative_traces(self) -> None:
        cell = trace.matrix_cells()[0]
        deadline = trace.validate_trace(
            cell,
            trace.synthetic_trace(
                cell, trace.observations((960, SUPPORTED, 0.03, 0.30))
            ),
        )
        self.assertTrue(deadline["ok"], deadline["failure_codes"][:6])
        self.assertFalse(deadline["taper_outcome"]["quiescent_taper_gate_passed"])
        self.assertEqual(deadline["taper_outcome"]["handoff_after_active_step"], 599)
        self.assertEqual(deadline["taper_outcome"]["passive_step_count"], 360)

        reset = trace.validate_trace(
            cell,
            trace.synthetic_trace(
                cell,
                trace.observations(
                    (10, SUPPORTED, 0.005, 0.1),
                    (1, PARTIAL, 0.005, 0.1),
                    (949, SUPPORTED, 0.005, 0.1),
                ),
            ),
        )
        self.assertTrue(reset["ok"], reset["failure_codes"][:6])
        self.assertEqual(reset["taper_outcome"]["taper_reset_count"], 1)
        self.assertTrue(reset["taper_outcome"]["quiescent_taper_gate_passed"])

        loss = trace.validate_trace(
            cell,
            trace.synthetic_trace(
                cell,
                trace.observations(
                    (500, SUPPORTED, 0.005, 0.1),
                    (1, PARTIAL, 0.005, 0.1),
                    (459, SUPPORTED, 0.005, 0.1),
                ),
            ),
        )
        self.assertTrue(loss["ok"], loss["failure_codes"][:6])
        self.assertFalse(loss["taper_outcome"]["quiescent_taper_gate_passed"])

    def test_schema_time_order_authority_and_passive_rewrites_fail_closed(self) -> None:
        cell = trace.matrix_cells()[0]
        baseline = trace.synthetic_trace(cell)
        active_index = trace.CONTROLLER_STEPS + 60
        passive_index = trace.CONTROLLER_STEPS + 500
        cases: list[list[dict[str, object]]] = []

        missing_field = copy.deepcopy(baseline)
        del missing_field[active_index]["tight_pose_satisfied"]
        cases.append(missing_field)

        wrong_feedback_step = copy.deepcopy(baseline)
        wrong_feedback_step[active_index]["command_time_feedback_trace_step"] -= 1
        cases.append(wrong_feedback_step)

        wrong_floor = copy.deepcopy(baseline)
        wrong_floor[active_index]["pose_authority_floor_numerator"] = 120
        cases.append(wrong_floor)

        wrong_vector = copy.deepcopy(baseline)
        wrong_vector[active_index]["ordered_final_canonical_velocities_rad_s"][0] = 0.3
        cases.append(wrong_vector)

        passive_reactivation = copy.deepcopy(baseline)
        passive_reactivation[passive_index][
            "ordered_final_canonical_velocities_rad_s"
        ][0] = 0.01
        cases.append(passive_reactivation)

        for rows in cases:
            result = trace.validate_trace(cell, rows)
            self.assertFalse(result["ok"])
            self.assertTrue(result["failure_codes"])
            self.assertTrue(
                all("R23D13" not in failure for failure in result["failure_codes"])
            )

    def test_zero_world_receipt_has_no_physical_authority(self) -> None:
        receipt = trace.zero_world_receipt()
        self.assertEqual(receipt["matrix_cell_count"], 9)
        self.assertEqual(receipt["trace_row_count_per_cell"], 3_952)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertFalse(receipt["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
