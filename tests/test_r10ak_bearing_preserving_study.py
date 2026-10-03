"""Guard the model's contact distinction and unchanged inactive-leg limits."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10ak_bearing_preserving_study as study


class ModelBoundaries(unittest.TestCase):
    def observation(self):
        return dict(state=dict(ordered_contact_observations=[dict(presence=True,bears_support=True) for _ in range(4)]),
            ordered_foot_bearing_observations=[dict(ordinary_unilateral_contact=True,bearing_normal_impulse_ns=v)
                for v in (0.,0.001,0.019293,0.02)])

    def test_positive_bearing_is_not_qualified_support(self):
        self.assertEqual(study.masks(self.observation()),dict(
            preserve_qualified_bearing=[True,True,False,False],
            preserve_positive_bearing=[True,False,False,False]))

    def test_absent_or_nonordinary_contact_never_anchors(self):
        o=self.observation();o['state']['ordered_contact_observations'][2]['presence']=False
        o['ordered_foot_bearing_observations'][3]['ordinary_unilateral_contact']=False
        for mask in study.masks(o).values():self.assertEqual(mask[2:],[True,True])

    def test_inactive_leg_motion_refused(self):
        with self.assertRaises(AssertionError):
            study.validate_targets([0.]*8,dict(targets=[0.001]+[0.]*7),[False]*4)

    def test_joint_speed_increase_refused(self):
        with self.assertRaises(AssertionError):
            study.validate_targets([0.]*8,dict(targets=[0.04]+[0.]*7),[True]*4)

    def test_no_active_feet_is_zero_update_geometry_only(self):
        descriptor=dict(upper_length_fraction=0.5,hip_span_scale=1.)
        o=dict(state=dict(base_pose_world=dict(orientation_xyzw=dict(x=0.,y=0.,z=0.,w=1.)),
            ordered_joint_observations=[dict(position_rad=0.) for _ in range(8)]))
        result=study.fixed_body(descriptor,o,[False]*4)
        self.assertEqual(result['updates'],0)
        self.assertEqual(result['fixed_torso_foot_displacement_m'],[[0.,0.,0.]]*4)
        self.assertFalse(study.closure.read(study.CONTRACT)['claim_boundary']['physical_execution_authorized'])


if __name__ == '__main__':unittest.main()
