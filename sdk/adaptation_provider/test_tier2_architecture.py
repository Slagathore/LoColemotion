from __future__ import annotations

import unittest

from .tier2_architecture import load_tier2_architecture
from .tier2_conformance import run_tier2_architecture_conformance


class Tier2ArchitectureConformanceTest(unittest.TestCase):
    def test_architecture_requires_successor_not_live_rewrite(self) -> None:
        architecture = load_tier2_architecture()
        self.assertFalse(
            architecture["promotion_requirements"][
                "in_place_rewrite_permitted"
            ]
        )
        self.assertFalse(
            architecture["promotion_requirements"][
                "training_plane_alone_sufficient"
            ]
        )
        self.assertTrue(
            architecture["tier3_extension"][
                "required_program_destination"
            ]
        )

    def test_executable_architecture_passes_t0_through_t6(self) -> None:
        report = run_tier2_architecture_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 7)
        self.assertEqual(report["failed_cells"], 0)
        self.assertTrue(report["training_plane_only_promotion_rejected"])
        self.assertFalse(report["engine_qualification_executed"])
        self.assertTrue(report["architecture_fixture_only"])
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
