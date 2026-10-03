from __future__ import annotations

import json
import unittest

from .conformance import (
    REPO_ROOT,
    _load_contract,
    run_heading_command_conformance,
)


class HeadingCommandConformanceTest(unittest.TestCase):
    def test_contract_is_source_only_and_requires_physical_r23(self) -> None:
        contract = _load_contract()
        self.assertEqual(contract["release_gate_id"], "QSDK-R23")
        self.assertFalse(
            contract["release_boundary"][
                "source_conformance_may_satisfy_qsdk_r23"
            ]
        )
        self.assertTrue(
            contract["release_boundary"]["prospective_physical_campaign_required"]
        )
        self.assertEqual(contract["world_build_count"], 0)
        self.assertFalse(contract["turning_acceptance"])
        self.assertFalse(contract["physical_acceptance_authority"])

    def test_public_dynamic_library_passes_all_source_cells(self) -> None:
        report = run_heading_command_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 9)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(report["descriptor_vertex_count"], 64)
        self.assertTrue(report["zero_command_source_compatibility_passed"])
        self.assertTrue(report["bounded_heading_source_mechanism_passed"])
        self.assertFalse(report["release_gate_satisfied"])
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["turning_acceptance"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_release_authority_remains_fail_closed(self) -> None:
        release_contract = json.loads(
            (REPO_ROOT / "sdk/release/quadruped_release_contract.json").read_text(
                encoding="utf-8"
            )
        )
        gate = next(
            item
            for item in release_contract["gates"]
            if item["gate_id"] == "QSDK-R23"
        )
        self.assertEqual(gate["proof"]["kind"], "missing")
        support_matrix = json.loads(
            (REPO_ROOT / "sdk/release/quadruped_support_matrix.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertFalse(
            support_matrix["locomotion_modes"]["command_conditioned_turning"]
        )


if __name__ == "__main__":
    unittest.main()
