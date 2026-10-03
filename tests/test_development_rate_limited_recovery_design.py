"""Retained-data reconstruction; no model, world or native sampler."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_rate_limited_recovery as candidate


class RateLimitedDesign(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.actual = candidate.observe()
        cls.record = candidate.prior.entry.read(candidate.RECORD)

    def test_exact_original_record_and_diagnosis(self):
        self.assertTrue(candidate.prior.entry.packet.same(self.actual, self.record))
        self.assertEqual([8.0] * 8, self.actual['observations'][2]['commanded_joint_velocities_rad_s'])
        self.assertEqual([22.0] * 8, self.actual['observations'][3]['commanded_joint_velocities_rad_s'])
        self.assertGreater(self.actual['observations'][2]['angular_speed_rad_s'], 3.0)

    def test_forged_speed_or_success_is_not_the_selected_record(self):
        for key, value in [('physical_acceptance_authority', True), ('causal_attribution_proven', True),
                           ('new_solver_step_count', 1)]:
            changed = copy.deepcopy(self.record)
            changed[key] = value
            self.assertFalse(candidate.prior.entry.packet.same(changed, self.actual))
        changed = copy.deepcopy(self.record)
        changed['prospective_controller']['raise_maximum_target_speed_rad_s'] = 8.0
        self.assertFalse(candidate.prior.entry.packet.same(changed, self.actual))

    def test_one_exploratory_ceiling_and_unchanged_diagnostic_bound(self):
        profile = self.actual['prospective_controller']
        self.assertEqual(4.0, profile['support_maximum_target_speed_rad_s'])
        self.assertEqual(4.0, profile['raise_maximum_target_speed_rad_s'])
        self.assertEqual([-0.6, 1.05] * 4, profile['support_targets_rad'])
        self.assertEqual(480, self.actual['diagnostic_coverage']['after_interaction_steps'])
        self.assertIs(profile['physical_suitability_proven'], False)


if __name__ == '__main__':
    unittest.main()
