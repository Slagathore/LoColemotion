from __future__ import annotations

import unittest

import r23d48_support_loss_conditioned_three_engine_turning as design


class R23D48DesignTest(unittest.TestCase):
    def test_matrix_is_exact_and_engine_neutral(self) -> None:
        self.assertEqual(len(design.cells()), 9)
        self.assertEqual(
            [item.engine_id for item in design.cells()[::3]],
            list(design.ENGINE_IDS),
        )
        self.assertEqual(
            {item.arm_id for item in design.cells()},
            set(design.ARM_OFFSETS),
        )
        self.assertEqual(design.CAMPAIGN_SEED, 21512)

    def test_schedule_is_unchanged_from_the_frozen_turning_design(self) -> None:
        item = design.cells()[0]
        self.assertEqual(
            design.expected_segment_counts(item),
            {
                "reference_warmup": 600,
                "commanded_turn": 1200,
                "reference_recovery": 600,
                "after_declared_schedule": 592,
            },
        )
        self.assertEqual(design.segment_for_step(item, 599), ("reference_warmup", 0.0))
        self.assertEqual(design.segment_for_step(item, 600), ("commanded_turn", 0.0))
        self.assertEqual(design.segment_for_step(item, 1800), ("reference_recovery", 0.0))

    def test_transform_has_trigger_and_identity_branches_without_engine_input(self) -> None:
        trigger = design.SupportLossConditionedStartup()
        identity = design.SupportLossConditionedStartup()
        triggered_scales: list[float] = []
        identity_scales: list[float] = []
        for step in range(363):
            support = (4, 4, 2, 0)[step] if step < 4 else 4
            triggered_contacts = {
                limb_id: index < support
                for index, limb_id in enumerate(design.LIMB_IDS)
            }
            identity_contacts = {limb_id: True for limb_id in design.LIMB_IDS}
            triggered_scales.append(
                float(trigger.step(step, triggered_contacts)["startup_velocity_scale"])
            )
            identity_scales.append(
                float(identity.step(step, identity_contacts)["startup_velocity_scale"])
            )
        self.assertEqual(trigger.trigger_step, 3)
        self.assertIsNone(identity.trigger_step)
        self.assertEqual(triggered_scales[3], 0.0)
        self.assertEqual(triggered_scales[362], 1.0)
        self.assertTrue(all(scale == 1.0 for scale in identity_scales))


if __name__ == "__main__":
    unittest.main()
