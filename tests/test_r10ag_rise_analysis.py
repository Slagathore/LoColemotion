"""Reject crossed tracking data and distinguish commanded from measured motion."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10ag_rise_tracking_analysis as tracking
from test_r10af_rise_analysis import DESCRIPTOR, pose


def pair():
    a, b = pose(), pose()
    a.update(semantic_step=10, next_command_sha256='command-A',
        next_control=dict(target_positions_rad=a['joint_positions_rad'][:]),
        plan=dict(virtual_translation_world_m=[0., .001, 0.]))
    b.update(semantic_step=11, applied_command_sha256='command-A',
        applied_target_velocities_rad_s=[0.]*8, applied_impulses=[.01]*8, caps=[.1]*8,
        qualified_support=[True]*4, bearing_impulses=[.03]*4)
    return a, b


class AGTrackingTests(unittest.TestCase):
    def test_crossed_commands_refuse(self):
        a, b = pair()
        tracking.check_links([a, b])
        b['applied_command_sha256'] = 'command-B'
        with self.assertRaisesRegex(AssertionError, 'COMMAND_LINK_MISMATCH'):
            tracking.check_links([a, b])

    def test_missing_step_refuses(self):
        a, b = pair(); b['semantic_step'] += 1
        with self.assertRaisesRegex(AssertionError, 'NONCONTIGUOUS_OBSERVATIONS'):
            tracking.check_links([a, b])

    def test_virtual_rise_does_not_count_as_measured_rise(self):
        a, b = pair(); result = tracking.pair_metrics(DESCRIPTOR, a, b)
        self.assertEqual(.001, result['planned_virtual_torso_dy_m'])
        self.assertEqual(0., result['measured_torso_dy_m'])
        self.assertEqual([0.]*4, result['joint_motion_error_dy_m'])
        self.assertEqual([True]*4, result['qualified_after'])
        self.assertAlmostEqual(.1, result['cap_fractions'][0])

    def test_untracked_target_is_visible_even_with_exact_velocity_mapping(self):
        a, b = pair()
        a['next_control']['target_positions_rad'][0] += .01
        b['applied_target_velocities_rad_s'][0] = .01/tracking.geometry.DT
        result = tracking.pair_metrics(DESCRIPTOR, a, b)
        self.assertAlmostEqual(0., result['mapping_errors'][0])
        self.assertAlmostEqual(-.01, result['target_errors'][0])
        self.assertNotEqual(0., result['joint_motion_error_dy_m'][0])

    def test_mapping_clips_both_speed_extremes_and_detects_wrong_sign(self):
        a, b = pair()
        a['next_control']['target_positions_rad'] = [100., -100.]*4
        b['applied_target_velocities_rad_s'] = [4., -4.]*4
        self.assertEqual([0.]*8, tracking.pair_metrics(DESCRIPTOR, a, b)['mapping_errors'])
        b['applied_target_velocities_rad_s'][1] = 4.
        self.assertEqual(8., tracking.pair_metrics(DESCRIPTOR, a, b)['mapping_errors'][1])

    def test_support_loss_and_cap_overrun_remain_visible(self):
        a, b = pair(); original = copy.deepcopy(a)
        b['qualified_support'][2] = False; b['applied_impulses'][3] = -.2
        result = tracking.pair_metrics(DESCRIPTOR, a, b)
        self.assertFalse(result['qualified_after'][2])
        self.assertEqual(2., result['cap_fractions'][3])
        self.assertEqual(original, a)


if __name__ == '__main__':
    unittest.main()
