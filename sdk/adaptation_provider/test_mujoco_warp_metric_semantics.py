"""Tests for the zero-world MuJoCo-Warp metric-semantics gate."""

from __future__ import annotations

import math
import unittest

from .mujoco_warp_metric_semantics import (
    compile_current_metric_semantics_inventory,
    compile_metric_suite,
    evaluate_fixture_pair,
    load_metric_semantics_contract,
)
from .mujoco_warp_metric_semantics_conformance import (
    metric_suite_fixture,
    paired_trace_fixture,
    run_metric_semantics_conformance,
)


class MuJoCoWarpMetricSemanticsTest(unittest.TestCase):
    def test_contract_retains_development_only_zero_world_boundary(self) -> None:
        contract = load_metric_semantics_contract()
        self.assertEqual(contract["question_class"], "development")
        self.assertEqual(
            contract["source_conformance"]["exact_mutation_control_count"], 52
        )
        self.assertEqual(
            contract["current_inventory"]["production_metric_definition_count"], 0
        )
        self.assertEqual(contract["current_inventory"]["unresolved_metric_count"], 5)
        self.assertTrue(all(not value for value in contract["claims"].values()))

    def test_current_inventory_retains_all_five_unresolved_definitions(self) -> None:
        inventory = compile_current_metric_semantics_inventory()
        self.assertEqual(inventory["required_metric_count"], 5)
        self.assertEqual(inventory["production_metric_definition_count"], 0)
        self.assertEqual(inventory["unresolved_metric_count"], 5)
        self.assertTrue(
            all(item["unresolved_reason"] for item in inventory["metric_readiness"])
        )
        self.assertFalse(inventory["production_metric_semantics_complete"])
        self.assertFalse(inventory["calibration_authorized"])

    def test_fixture_metrics_and_trace_content_addresses_are_exact(self) -> None:
        suite = compile_metric_suite(metric_suite_fixture())
        reference, candidate = paired_trace_fixture(suite["suite_sha256"])
        result = evaluate_fixture_pair(suite, reference, candidate)
        metrics = result["metrics"]
        self.assertTrue(result["valid_metric_vector"])
        self.assertIsNotNone(metrics)
        assert metrics is not None
        self.assertTrue(
            math.isclose(metrics["one_step_state_linf_normalized"], 0.1, abs_tol=1e-12)
        )
        self.assertTrue(
            math.isclose(
                metrics["one_step_actuator_linf_normalized"], 0.05, abs_tol=1e-12
            )
        )
        self.assertTrue(
            math.isclose(
                metrics["bounded_horizon_pose_velocity_rms_normalized"],
                math.sqrt((0.1**2 + 0.2**2) / 6.0),
                abs_tol=1e-12,
            )
        )
        self.assertTrue(
            math.isclose(
                metrics["bounded_horizon_energy_relative_error"],
                0.05,
                abs_tol=1e-12,
            )
        )
        self.assertEqual(metrics["contact_event_time_error_steps"], 1)
        for key in (
            "reference_trace_sha256",
            "candidate_trace_sha256",
            "evaluation_sha256",
        ):
            self.assertRegex(result[key], r"^sha256:[0-9a-f]{64}$")

    def test_mjms0_through_mjms7_pass_with_all_controls_at_zero_worlds(self) -> None:
        report = run_metric_semantics_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 8)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(report["mutation_control_count"], 52)
        self.assertEqual(len(report["rejected_mutations"]), 52)
        self.assertTrue(all(report["rejected_mutations"].values()))
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["step_invocation_count"], 0)
        self.assertEqual(report["world_attempt_count"], 0)
        self.assertEqual(report["world_build_count"], 0)

    def test_fixture_compiler_cannot_promote_production_authority(self) -> None:
        report = run_metric_semantics_conformance()
        self.assertEqual(report["positive_fixture_metric_count"], 5)
        self.assertTrue(report["fixture_only"])
        self.assertFalse(report["production_metric_semantics_complete"])
        self.assertFalse(report["production_semantic_ceiling_sources_complete"])
        self.assertFalse(report["production_plan_frozen"])
        self.assertFalse(report["calibration_executed"])
        self.assertFalse(report["heldout_execution_authorized"])
        self.assertFalse(report["release_authority"])


if __name__ == "__main__":
    unittest.main()
