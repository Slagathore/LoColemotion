from __future__ import annotations

import unittest

from .conformance import _load_contract, run_adaptation_provider_conformance


class AdaptationProviderConformanceTest(unittest.TestCase):
    def test_machine_contract_has_no_world_or_acceptance_authority(self) -> None:
        contract = _load_contract()
        self.assertTrue(contract["provider_optional_at_runtime"])
        self.assertFalse(
            contract["trained_provider_required_for_first_public_release"]
        )
        self.assertEqual(contract["world_build_count"], 0)
        self.assertFalse(contract["physics_state_modified"])
        self.assertFalse(contract["physical_acceptance_authority"])

    def test_public_dynamic_library_passes_all_zero_world_cells(self) -> None:
        report = run_adaptation_provider_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 8)
        self.assertEqual(report["failed_cells"], 0)
        self.assertTrue(report["deterministic_baseline_oracle_passed"])
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
