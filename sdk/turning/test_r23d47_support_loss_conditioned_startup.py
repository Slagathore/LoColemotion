from __future__ import annotations

import unittest

import r23d46_support_loss_conditioned_startup as parent
import r23d47_support_loss_conditioned_startup as design


class R23D47SupportLossConditionedStartupTest(unittest.TestCase):
    def test_identity_is_distinct_and_scientific_candidate_is_unchanged(self) -> None:
        self.assertNotEqual(design.CAMPAIGN_ID, parent.CAMPAIGN_ID)
        self.assertNotEqual(design.GATE_ID, parent.GATE_ID)
        for name in (
            "POLICY_ID",
            "CANDIDATE_ID",
            "CAMPAIGN_SEED",
            "INITIAL_PERTURBATION",
            "PHASE_OFFSETS",
            "STARTUP_TRANSFORM_ID",
        ):
            self.assertEqual(getattr(design, name), getattr(parent, name))

    def test_support_loss_transform_is_unchanged(self) -> None:
        current = design.SupportLossConditionedStartup()
        previous = parent.SupportLossConditionedStartup()
        for step in range(400):
            support = (4, 4, 2, 0)[step] if step < 4 else 4
            contacts = {
                limb_id: index < support
                for index, limb_id in enumerate(design.LIMB_IDS)
            }
            self.assertEqual(current.step(step, contacts), previous.step(step, contacts))

    def test_inherited_design_surface_remains_complete(self) -> None:
        item = design.cells()[0]
        self.assertEqual(design.PHASE_OFFSETS, (0, 90, 180, 270))
        self.assertEqual(design.stage_a_cells(), [item])
        self.assertEqual(design.stage_b_cells("onset_600"), [item])
        self.assertEqual(
            design.expected_segment_counts(item),
            {"reference_walk": design.CONTROLLER_STEPS},
        )


if __name__ == "__main__":
    unittest.main()
