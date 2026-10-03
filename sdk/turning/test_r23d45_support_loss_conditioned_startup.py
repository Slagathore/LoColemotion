"""Zero-world unit tests for the QSDK-R23D45 startup transform."""

from __future__ import annotations

import copy
import unittest

import r23d45_support_loss_conditioned_startup as design


def contacts(count: int) -> dict[str, bool]:
    return {
        limb_id: index < count
        for index, limb_id in enumerate(design.LIMB_IDS)
    }


class SupportLossConditionedStartupTests(unittest.TestCase):
    def test_complete_probe_loss_latches_ramp_on_same_step(self) -> None:
        governor = design.SupportLossConditionedStartup()
        sequence = (4, 4, 2, 0)
        receipts = [
            governor.step(step, contacts(count))
            for step, count in enumerate(sequence)
        ]
        self.assertEqual(
            [receipt["startup_velocity_scale"] for receipt in receipts],
            [1.0, 1.0, 1.0, 0.0],
        )
        self.assertEqual(receipts[-1]["startup_ramp_trigger_step"], 3)
        for step in range(4, 363):
            receipt = governor.step(step, contacts(4))
        self.assertEqual(receipt["startup_ramp_local_step"], 359)
        self.assertEqual(receipt["startup_velocity_scale"], 1.0)
        self.assertFalse(receipt["startup_ramp_active"])

    def test_supported_probe_locks_identity_transform(self) -> None:
        governor = design.SupportLossConditionedStartup()
        for step in range(12):
            receipt = governor.step(step, contacts(2 if step in (2, 3, 7) else 4))
            self.assertEqual(receipt["startup_velocity_scale"], 1.0)
            self.assertFalse(receipt["startup_ramp_triggered"])
        self.assertTrue(receipt["startup_transform_decision_locked"])

    def test_support_loss_after_probe_cannot_change_decision(self) -> None:
        governor = design.SupportLossConditionedStartup()
        for step in range(4):
            governor.step(step, contacts(4))
        receipt = governor.step(4, contacts(0))
        self.assertEqual(receipt["startup_velocity_scale"], 1.0)
        self.assertFalse(receipt["startup_ramp_triggered"])

    def test_receipt_has_no_engine_or_arm_input(self) -> None:
        first = design.SupportLossConditionedStartup()
        second = copy.deepcopy(first)
        self.assertEqual(first.step(0, contacts(4)), second.step(0, contacts(4)))
        fields = set(first.__dataclass_fields__)
        self.assertNotIn("engine_id", fields)
        self.assertNotIn("arm_id", fields)

    def test_malformed_or_nonsequential_input_is_rejected(self) -> None:
        governor = design.SupportLossConditionedStartup()
        with self.assertRaises(design.StartupTransformError):
            governor.step(1, contacts(4))
        with self.assertRaises(design.StartupTransformError):
            design.SupportLossConditionedStartup().step(0, {"front_left": True})
        invalid = contacts(4)
        invalid[design.LIMB_IDS[0]] = 1  # type: ignore[assignment]
        with self.assertRaises(design.StartupTransformError):
            design.SupportLossConditionedStartup().step(0, invalid)

    def test_smoothstep_is_bounded_monotonic_and_exact_at_ends(self) -> None:
        values = [design.smoothstep_scale(step) for step in range(361)]
        self.assertEqual(values[0], 0.0)
        self.assertEqual(values[359], 1.0)
        self.assertEqual(values[360], 1.0)
        self.assertTrue(all(0.0 <= value <= 1.0 for value in values))
        self.assertTrue(all(left < right for left, right in zip(values[:359], values[1:360], strict=True)))


if __name__ == "__main__":
    unittest.main()
