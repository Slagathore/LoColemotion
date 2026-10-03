"""Zero-world regression tests for the prospective R23D33 evaluator."""

from __future__ import annotations

import copy
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d31_cycle_integrated_measurement as measurement  # noqa: E402
import r23d33_native_r23d29_transfer as design  # noqa: E402
import r23d33_native_r23d29_transfer_evaluator as evaluator  # noqa: E402


class R23D33EvaluatorTests(unittest.TestCase):
    def test_declaration_and_exact_order(self) -> None:
        declaration = evaluator.load_declaration()
        self.assertEqual(declaration["campaign_id"], design.CAMPAIGN_ID)
        self.assertEqual(len(design.cells()), 6)
        self.assertEqual(
            [item.engine_id for item in design.cells()],
            ["godot_jolt"] * 3 + ["mujoco"] * 3,
        )

    def test_inherited_trace_vocabulary_is_validated_exactly(self) -> None:
        item = design.cells()[0]
        rows = [
            evaluator._synthetic_row(item, step)
            for step in range(design.CONTROLLER_STEPS)
        ]
        result = evaluator.validate_trace(item.cell_id, rows)
        self.assertTrue(result["ok"])
        self.assertEqual(result["segment_counts"], design.expected_segment_counts(item))
        self.assertEqual(rows[2400]["segment_id"], "after_declared_schedule")
        mutated = copy.deepcopy(rows)
        mutated[2400]["segment_id"] = "reference_continuation"
        self.assertFalse(evaluator.validate_trace(item.cell_id, mutated)["ok"])

    def test_measurement_boundary_translates_only_the_post_schedule_name(self) -> None:
        rows_by_arm = {}
        for arm_id in design.ARM_OFFSETS:
            item = design.cell(design.STAGE_ID, "mujoco", arm_id)
            rows = [
                evaluator._synthetic_row(item, step)
                for step in range(design.CONTROLLER_STEPS)
            ]
            translated = evaluator._measurement_rows(rows)
            self.assertEqual(translated[2399]["phase_id"], "reference_recovery")
            self.assertEqual(translated[2400]["phase_id"], "reference_continuation")
            rows_by_arm[arm_id] = translated
        self.assertTrue(measurement.measure_cycle_integrated_response(rows_by_arm)["passed"])

    def test_complete_zero_world_preflight(self) -> None:
        receipt = evaluator.run_zero_world_preflight()
        self.assertEqual(receipt["declared_cell_count"], 6)
        self.assertEqual(receipt["trace_mutation_rejection_count"], 1)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)


if __name__ == "__main__":
    unittest.main()
