"""Cold anatomical-axis diagnosis of the complete V16 standing population."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_leg_geometry as geometry


class StanceMotion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = geometry.observe_stance_motion_v16()

    def test_complete_motion_population_and_native_speed_recomputation(self):
        r = self.result
        self.assertEqual(240, r['observed_stance_steps'])
        self.assertTrue(r['complete_speed_recomputation'])
        self.assertEqual([60]*4, [w['sample_count'] for w in r['ordered_windows']])
        self.assertEqual(['front_rear_hip_axis_x','torso_up_axis_y','left_right_axis_z'], r['body_axes'])
        print('V16_STANCE_MOTION', json.dumps(r, separators=(',', ':'), allow_nan=False))

    def test_late_motion_is_hip_axis_translation_not_vertical_bouncing(self):
        a, b = self.result['ordered_windows'][-2:]
        self.assertAlmostEqual(.9926065701207978, a['hip_axis_squared_speed_fraction'], places=14)
        self.assertAlmostEqual(.9919870246713411, b['hip_axis_squared_speed_fraction'], places=14)
        self.assertAlmostEqual(.004415050528341968, b['world_vertical_rms_m_s'], places=14)
        self.assertAlmostEqual(.0855751186210974, b['body_axis_rms_m_s'][0], places=14)
        self.assertAlmostEqual(-.990395629023495, b['hip_axis_velocity_mean_hip_joint_velocity_correlation'], places=14)
        # Retain actual direction reversals, not just a small signed average.
        samples = {r['step']: r for r in self.result['selected_samples']}
        self.assertLess(samples[840]['body_velocity_m_s'][0], -.1)
        self.assertGreater(samples[868]['body_velocity_m_s'][0], 0)

    def test_description_cannot_become_a_native_or_causal_claim(self):
        for key in ('causal_attribution_proven','original_results_reclassified','physical_acceptance_authority','release_authority'):
            self.assertIs(self.result[key], False)
        for key in ('world_build_count','native_physics_read_count','solver_step_count'):
            self.assertEqual(0, self.result[key])


if __name__ == '__main__':
    unittest.main()
