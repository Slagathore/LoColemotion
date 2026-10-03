"""Tests for the zero-world MuJoCo-Warp semantic-ceiling readiness gate."""

from __future__ import annotations

import unittest

from .mujoco_warp_semantic_ceiling_readiness import (
    compile_current_unresolved_inventory,
    load_readiness_contract,
)
from .mujoco_warp_semantic_ceiling_readiness_conformance import (
    run_semantic_ceiling_conformance,
)


class MuJoCoWarpSemanticCeilingReadinessTest(unittest.TestCase):
    def test_contract_retains_all_authority_as_false(self) -> None:
        contract = load_readiness_contract()
        self.assertEqual(contract["question_class"], "development")
        self.assertEqual(
            contract["current_inventory"]["accepted_production_source_count"], 0
        )
        self.assertEqual(contract["current_inventory"]["unresolved_metric_count"], 5)
        self.assertTrue(all(not value for value in contract["claims"].values()))

    def test_current_inventory_retains_five_unresolved_metrics(self) -> None:
        inventory = compile_current_unresolved_inventory()
        self.assertEqual(inventory["required_metric_count"], 5)
        self.assertEqual(inventory["accepted_source_count"], 0)
        self.assertEqual(inventory["unresolved_metric_count"], 5)
        self.assertTrue(
            all(item["unresolved_reason"] for item in inventory["metric_readiness"])
        )
        self.assertFalse(inventory["production_semantic_ceiling_sources_complete"])

    def test_mjsc0_through_mjsc7_pass_at_zero_worlds(self) -> None:
        report = run_semantic_ceiling_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 8)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(report["mutation_control_count"], 25)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["step_invocation_count"], 0)
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)

    def test_positive_fixture_never_becomes_production_authority(self) -> None:
        report = run_semantic_ceiling_conformance()
        self.assertEqual(report["positive_fixture_accepted_source_count"], 5)
        self.assertTrue(report["fixture_only"])
        self.assertFalse(report["production_semantic_ceiling_sources_complete"])
        self.assertFalse(report["production_plan_frozen"])
        self.assertFalse(report["calibration_executed"])
        self.assertFalse(report["release_authority"])


if __name__ == "__main__":
    unittest.main()
