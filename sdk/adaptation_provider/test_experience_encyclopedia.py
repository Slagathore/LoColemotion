from __future__ import annotations

import unittest

from .experience_encyclopedia import load_experience_encyclopedia_contract
from .experience_encyclopedia_conformance import (
    run_experience_encyclopedia_conformance,
)


class ExperienceEncyclopediaConformanceTest(unittest.TestCase):
    def test_contract_forbids_thresholds_rewrite_and_authority(self) -> None:
        contract = load_experience_encyclopedia_contract()
        self.assertFalse(
            contract["characterization"][
                "thresholds_or_outcome_classification_permitted"
            ]
        )
        self.assertFalse(
            contract["append_only_store"][
                "in_place_event_or_object_rewrite_permitted"
            ]
        )
        self.assertFalse(contract["authority"]["training_data_authority"])
        self.assertFalse(
            contract["authority"]["encyclopedia_promotion_authority"]
        )
        self.assertEqual(contract["world_build_count"], 0)

    def test_aec0_through_aec7_pass_at_zero_worlds(self) -> None:
        report = run_experience_encyclopedia_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 8)
        self.assertEqual(report["failed_cells"], 0)
        self.assertTrue(
            report[
                "positive_negative_rejected_invalid_incomplete_retained"
            ]
        )
        self.assertTrue(report["self_contained_experience_objects"])
        self.assertEqual(report["mutation_control_count"], 9)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["scientific_result"])
        self.assertFalse(report["physical_acceptance_authority"])
        self.assertFalse(report["release_authority"])


if __name__ == "__main__":
    unittest.main()
