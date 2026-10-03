"""Controls for post-exposure mathematics; no native runtime or physics."""
import copy
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10af_rise_tracking_analysis as tracking
import r10af_rise_model_rollout as rollout


DESCRIPTOR = dict(upper_length_fraction=.52, hip_span_scale=1., foot_radius_scale=1.)
IDENTITY = dict(x=0., y=0., z=0., w=1.)


def pose(position=None, q=None, joints=None):
    row = dict(position=position or [0., .3, 0.], orientation_xyzw=q or IDENTITY,
        joint_positions_rad=joints or [0., .2]*4)
    row['modeled_cap_centers'] = [[row['position'][i]+tracking.rotate(row['orientation_xyzw'], f)[i]
        for i in range(3)] for f in tracking.fk(DESCRIPTOR, row['joint_positions_rad'])]
    row['measured_cap_centers'] = copy.deepcopy(row['modeled_cap_centers'])
    return row


class RiseAnalysisTests(unittest.TestCase):
    def test_support_threshold_and_missing_contact_cannot_pass(self):
        observation = dict(state=dict(ordered_contact_observations=[dict(presence=True, bears_support=True) for _ in range(4)]),
            ordered_foot_bearing_observations=[dict(ordinary_unilateral_contact=True, bearing_normal_impulse_ns=tracking.LOAD_THRESHOLD) for _ in range(4)])
        self.assertEqual(tracking.qualified_support(observation), [True]*4)
        observation['ordered_foot_bearing_observations'][0]['bearing_normal_impulse_ns'] = math.nextafter(tracking.LOAD_THRESHOLD, 0.)
        observation['state']['ordered_contact_observations'][1]['presence'] = False
        observation['state']['ordered_contact_observations'][2]['bears_support'] = False
        observation['ordered_foot_bearing_observations'][3]['ordinary_unilateral_contact'] = False
        self.assertEqual(tracking.qualified_support(observation), [False]*4)

    def test_translation_is_not_counted_as_joint_motion(self):
        a, b = pose(), pose(position=[0., .31, 0.])
        parts = tracking.motion_components(DESCRIPTOR, a, b, 0)
        self.assertAlmostEqual(parts['actual_world_dy_m'], .01)
        self.assertAlmostEqual(parts['torso_translation_dy_m'], .01)
        self.assertEqual(parts['modeled_measured_joint_dy_m'], 0.)
        self.assertEqual(parts['modeled_torso_rotation_dy_m'], 0.)

    def test_rotation_is_not_counted_as_joint_motion(self):
        a = pose()
        b = pose(q=dict(x=0., y=0., z=math.sin(.1), w=math.cos(.1)))
        parts = tracking.motion_components(DESCRIPTOR, a, b, 0)
        self.assertAlmostEqual(parts['actual_world_dy_m'], parts['modeled_torso_rotation_dy_m'])
        self.assertNotEqual(parts['actual_world_dy_m'], 0.)
        self.assertEqual(parts['modeled_measured_joint_dy_m'], 0.)

    def test_joint_and_fk_residual_motion_are_distinct(self):
        a, b = pose(), pose(joints=[.02, .19]*4)
        b['measured_cap_centers'][0][1] += .001
        parts = tracking.motion_components(DESCRIPTOR, a, b, 0)
        self.assertAlmostEqual(parts['fk_residual_change_dy_m'], .001)
        self.assertAlmostEqual(parts['actual_world_dy_m'], parts['modeled_measured_joint_dy_m']+.001)

    def test_inconsistent_model_coordinates_refuse(self):
        a, b = pose(), pose()
        b['modeled_cap_centers'][0][1] += .01
        with self.assertRaises(AssertionError):
            tracking.motion_components(DESCRIPTOR, a, b, 0)

    def test_hypothetical_advance_preserves_original_and_strips_source(self):
        observation = dict(state=dict(base_pose_world=dict(position_m=dict(x=0., y=.3, z=0.), orientation_xyzw=IDENTITY),
            ordered_joint_observations=[dict(position_rad=q) for q in [0., .2]*4],
            ordered_contact_observations=[dict(presence=True, bears_support=True) for _ in range(4)]),
            center_of_mass=dict(position_world_m=dict(x=0., y=.29, z=0.)),
            ordered_foot_bearing_observations=[dict(ordinary_unilateral_contact=True, bearing_normal_impulse_ns=.03) for _ in range(4)])
        model = rollout.geometry.Model(observation, DESCRIPTOR)
        before = copy.deepcopy(model.__dict__)
        advanced = rollout.advance(model, dict(translation=[.001, .001, 0.], blend=0., targets=[.001, .199]*4))
        self.assertEqual(model.__dict__, before)
        self.assertIsNone(advanced.o)
        self.assertNotEqual(advanced.p, model.p)
        self.assertEqual(advanced.com_local, model.com_local)


if __name__ == '__main__':
    unittest.main()
