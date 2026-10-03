from __future__ import annotations

import unittest

from .mujoco_warp_equivalence_calibration import (
    compile_calibration_plan,
    compile_calibration_summary,
    load_calibration_contract,
    minimum_zero_exceedance_condition_count,
)
from .mujoco_warp_equivalence_calibration_conformance import (
    calibration_plan_fixture,
    calibration_summary_fixture,
    run_calibration_conformance,
)


class MuJoCoWarpEquivalenceCalibrationTest(unittest.TestCase):
    def test_contract_keeps_every_physical_and_release_authority_sealed(
        self,
    ) -> None:
        contract = load_calibration_contract()
        self.assertEqual(contract["question_class"], "development")
        self.assertEqual(
            contract["scientific_roles"][
                "future_cpu_vs_warp_supported_subset_question"
            ],
            "equivalence_non_inferiority",
        )
        self.assertFalse(
            contract["production_plan_requirements"]["production_plan_exists"]
        )
        self.assertFalse(
            contract["production_plan_requirements"]["physical_calibration_series_open"]
        )
        self.assertFalse(
            contract["production_plan_requirements"][
                "heldout_qualification_series_open"
            ]
        )
        self.assertTrue(all(not value for value in contract["claims"].values()))
        self.assertEqual(contract["source_conformance"]["world_build_count"], 0)

    def test_distribution_free_adequacy_formula_is_exact(self) -> None:
        self.assertEqual(minimum_zero_exceedance_condition_count(0.95, 0.95), 59)

    def test_positive_and_negative_fixture_results_remain_distinct(self) -> None:
        plan = compile_calibration_plan(calibration_plan_fixture())
        positive = compile_calibration_summary(plan, calibration_summary_fixture(plan))
        negative = compile_calibration_summary(
            plan, calibration_summary_fixture(plan, negative=True)
        )
        self.assertTrue(positive["all_metrics_resolvable"])
        self.assertFalse(positive["negative_result_retained"])
        self.assertFalse(negative["all_metrics_resolvable"])
        self.assertTrue(negative["negative_result_retained"])
        self.assertFalse(positive["production_margin_authority"])
        self.assertFalse(negative["production_margin_authority"])

    def test_mjcal0_through_mjcal7_pass_at_zero_worlds(self) -> None:
        report = run_calibration_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 8)
        self.assertEqual(report["failed_cells"], 0)
        self.assertGreaterEqual(report["mutation_control_count"], 10)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["step_invocation_count"], 0)
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["scientific_result"])
        self.assertFalse(report["physical_acceptance_authority"])
        self.assertFalse(report["release_authority"])


if __name__ == "__main__":
    unittest.main()
