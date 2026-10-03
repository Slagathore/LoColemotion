"""Independent geometry and refusal checks before retained-input evaluation."""
import copy
import math
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10al_support_anchored_model as kernel
import r10af_rise_tracking_analysis as independent


def fixture(bearing=(False,False,True,True)):
    descriptor=dict(upper_length_fraction=.52,hip_span_scale=1.,foot_radius_scale=1.)
    observation=dict(state=dict(base_pose_world=dict(position_m=dict(x=0.,y=.25,z=0.),
        orientation_xyzw=dict(x=0.,y=0.,z=math.sin(.15),w=math.cos(.15))),
        ordered_joint_observations=[dict(position_rad=x) for x in [0.,-.7]*4],
        ordered_contact_observations=[dict(presence=b,bears_support=b) for b in bearing]),
        center_of_mass=dict(position_world_m=dict(x=0.,y=.25,z=0.)),
        ordered_foot_bearing_observations=[dict(ordinary_unilateral_contact=b,bearing_normal_impulse_ns=.04 if b else 0.) for b in bearing])
    return kernel.G.Model(observation,descriptor)


class GeometryChecks(unittest.TestCase):
    def test_jacobian_matches_independent_fk_difference(self):
        m=fixture();h,k=.2,-.7;epsilon=1e-6;j=kernel.jacobian(m,h,k)
        for column in range(2):
            left=[h,k];right=[h,k];left[column]-=epsilon;right[column]+=epsilon
            a=independent.fk(m.d,left*4)[0];b=independent.fk(m.d,right*4)[0]
            for axis in range(2):self.assertAlmostEqual((b[axis]-a[axis])/(2*epsilon),j[axis][column],places=9)

    def test_anchored_solution_preserves_original_world_endpoint(self):
        m=fixture();position=kernel.G.add(m.p,[0.,-.0001,0.])
        solution=kernel.anchor(m,2,position,m.q);self.assertIsNotNone(solution)
        joints=m.measured[:];joints[4:6]=solution
        endpoint=kernel.G.add(position,kernel.G.rotate(m.q,independent.fk(m.d,joints)[2]))
        self.assertLess(math.dist(endpoint,m.feet[2]),1e-12)

    def test_selected_plan_has_downward_free_feet_and_anchored_rear_feet(self):
        m=fixture();result=kernel.search(m);self.assertEqual(result['candidates'],90)
        self.assertIsNotNone(result['selected'])
        plan=result['selected'];position=kernel.G.add(m.p,plan['translation'])
        q=kernel.G.blend(m.q,m.flat,plan['blend'])
        feet=[kernel.G.add(position,kernel.G.rotate(q,f)) for f in independent.fk(m.d,plan['targets'])]
        for i in (2,3):self.assertLessEqual(math.dist(feet[i],m.feet[i]),kernel.LATERAL+1e-12)
        for i in (0,1):self.assertLessEqual(feet[i][1],m.feet[i][1]+1e-12)
        self.assertGreaterEqual(kernel.G.rotate(q,[0.,1.,0.])[1],kernel.G.rotate(m.q,[0.,1.,0.])[1]-1e-12)

    def test_no_contacts_refuses(self):
        result=kernel.search(fixture((False,)*4))
        self.assertIsNone(result['selected']);self.assertEqual(result['refusal'],'no_positive_bearing_plane')

    def test_nonfinite_pose_refuses(self):
        m=fixture();m.p[0]=float('nan')
        with self.assertRaisesRegex(ValueError,'NONFINITE'):kernel.search(m)

    def test_corrupted_anchor_target_refuses(self):
        m=fixture();plan=copy.deepcopy(kernel.search(m)['selected']);plan['targets'][4]+=.1
        with self.assertRaises(AssertionError):kernel.verify(m,plan)


if __name__ == '__main__':unittest.main()
