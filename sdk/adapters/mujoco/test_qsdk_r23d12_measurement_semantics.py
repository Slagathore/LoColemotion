"""Zero-world tests for the independent MuJoCo/Python R23D12 mirror."""

from __future__ import annotations

import json
import unittest

from sporespore_mujoco_adapter import qsdk_r23d12_measurement_semantics as semantics


class R23D12NativeMeasurementSemanticsTests(unittest.TestCase):
    def test_seven_valid_canaries_and_critical_shape(self) -> None:
        receipts = [
            semantics.validate_diagnostic_semantics(row)
            for row in semantics._valid_canaries()
        ]
        self.assertEqual(len(receipts), 7)
        critical = receipts[2]
        self.assertEqual(
            critical["stability_planning_availability"],
            semantics.PLANNER_OBSERVATION_UNAVAILABLE,
        )
        self.assertEqual(
            critical["minimum_dynamic_support_margin_availability"],
            semantics.MARGIN_MEASURED,
        )
        self.assertEqual(critical["minimum_dynamic_support_margin_m"], -0.01)
        self.assertTrue(critical["stability_fallback_exact_zero_required"])

    def test_complete_active_cross_product(self) -> None:
        receipts = [
            semantics.validate_diagnostic_semantics(row)
            for row in semantics._cross_product_inputs()
        ]
        self.assertEqual(len(receipts), 6)
        self.assertEqual(
            {
                (
                    row["stability_planning_availability"],
                    row["minimum_dynamic_support_margin_availability"],
                )
                for row in receipts
            },
            {
                (planner, margin)
                for planner in semantics.PLANNER_VALUES
                for margin in semantics.MARGIN_VALUES
            },
        )

    def test_fourteen_mutations_fail_with_exact_codes(self) -> None:
        codes: list[str] = []
        for row in semantics._mutations():
            with self.assertRaises(semantics.NativeSemanticsError) as caught:
                semantics.validate_diagnostic_semantics(row)
            codes.append(str(caught.exception))
        self.assertEqual(tuple(codes), semantics.EXPECTED_MUTATION_CODES)

    def test_preflight_is_deterministic_and_nonphysical(self) -> None:
        first = semantics.preflight()
        second = semantics.preflight()
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
