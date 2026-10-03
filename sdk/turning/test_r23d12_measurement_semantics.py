from __future__ import annotations

from dataclasses import replace
import json
import math
import unittest

from . import r23d12_measurement_semantics as semantics


class R23D12MeasurementSemanticsTest(unittest.TestCase):
    def test_seven_declared_valid_canaries(self) -> None:
        canaries = semantics.declared_valid_canaries()
        self.assertEqual(len(canaries), 7)
        receipts = [semantics.validate_diagnostic_semantics(item) for item in canaries]
        self.assertTrue(
            all(item["planner_and_support_margin_availability_are_independent"] for item in receipts)
        )
        critical = receipts[2]
        self.assertEqual(
            critical["stability_planning_availability"],
            semantics.PLANNER_OBSERVATION_UNAVAILABLE,
        )
        self.assertEqual(
            critical["minimum_dynamic_support_margin_availability"],
            semantics.SUPPORT_MARGIN_MEASURED,
        )
        self.assertEqual(critical["minimum_dynamic_support_margin_m"], -0.01)
        self.assertTrue(critical["stability_fallback_exact_zero_required"])

    def test_all_active_planner_and_margin_availability_pairs_are_independent(self) -> None:
        zeros = (0.0,) * semantics.ACTUATOR_COUNT
        nonzero = (0.01,) * semantics.ACTUATOR_COUNT
        count = 0
        for planner in semantics.PLANNER_AVAILABILITY_VALUES:
            for margin_availability, margin in (
                (semantics.SUPPORT_MARGIN_MEASURED, 0.03),
                (semantics.SUPPORT_MARGIN_UNAVAILABLE, None),
            ):
                deltas = nonzero if planner == semantics.PLANNER_AVAILABLE else zeros
                receipt = semantics.validate_diagnostic_semantics(
                    semantics.DiagnosticSemanticsInput(
                        semantics.ACTIVE_CONTROL,
                        planner,
                        margin_availability,
                        margin,
                        deltas,
                    )
                )
                self.assertEqual(
                    receipt["minimum_dynamic_support_margin_availability"],
                    margin_availability,
                )
                count += 1
        self.assertEqual(count, 6)

    def test_fourteen_declared_mutations_fail_closed(self) -> None:
        baseline = semantics.declared_valid_canaries()[0]
        zeros = (0.0,) * semantics.ACTUATOR_COUNT
        mutations = (
            replace(baseline, phase_class="terminal"),
            replace(baseline, stability_planning_availability=None),
            replace(baseline, stability_planning_availability="arm_specific"),
            replace(
                baseline,
                phase_class=semantics.PASSIVE_OBSERVATION,
                stability_planning_availability=semantics.PLANNER_AVAILABLE,
            ),
            replace(baseline, minimum_dynamic_support_margin_availability="estimated"),
            replace(baseline, minimum_dynamic_support_margin_m=None),
            replace(baseline, minimum_dynamic_support_margin_m=True),
            replace(baseline, minimum_dynamic_support_margin_m=math.nan),
            replace(
                baseline,
                minimum_dynamic_support_margin_availability=semantics.SUPPORT_MARGIN_UNAVAILABLE,
                minimum_dynamic_support_margin_m=0.01,
            ),
            replace(baseline, ordered_applied_stability_velocity_deltas_rad_s=zeros[:-1]),
            replace(
                baseline,
                ordered_applied_stability_velocity_deltas_rad_s=(0.0,) * 7 + (math.inf,),
            ),
            replace(
                baseline,
                stability_planning_availability=semantics.PLANNER_OBSERVATION_UNAVAILABLE,
            ),
            replace(
                baseline,
                stability_planning_availability=semantics.PLANNER_INFEASIBLE,
            ),
            replace(
                baseline,
                phase_class=semantics.PASSIVE_OBSERVATION,
                stability_planning_availability=None,
            ),
        )
        self.assertEqual(len(mutations), 14)
        for value in mutations:
            with self.assertRaises(semantics.ContractError):
                semantics.validate_diagnostic_semantics(value)

    def test_receipt_is_deterministic_and_has_no_physical_authority(self) -> None:
        canary = semantics.declared_valid_canaries()[2]
        first = semantics.validate_diagnostic_semantics(canary)
        second = semantics.validate_diagnostic_semantics(canary)
        self.assertEqual(
            json.dumps(first, sort_keys=True, separators=(",", ":")),
            json.dumps(second, sort_keys=True, separators=(",", ":")),
        )
        self.assertEqual(first["decision_threshold_count"], 0)
        self.assertEqual(first["physical_process_launch_count"], 0)
        self.assertEqual(first["model_construction_count"], 0)
        self.assertEqual(first["world_build_count"], 0)
        self.assertFalse(first["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
