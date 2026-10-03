"""Independent placement properties and invalid-input controls for the model."""
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10aj_hip_recenter_model as model

D = dict(upper_length_fraction=.5,hip_span_scale=1.,foot_radius_scale=1.)
Q = dict(x=0.,y=0.,z=math.sin(.3/2),w=math.cos(.3/2))


class Recenter(unittest.TestCase):
    def test_projected_gravity_fixed_point(self):
        # Symmetric links yield hip = -pitch - knee/2 independently of planner.
        joints=[-.3-.5*.8,.8]*4
        result=model.plan(D,Q,joints,[True]*4)
        self.assertLess(max(abs(a-b) for a,b in zip(result['targets'],joints)),1e-12)

    def test_lowering_and_arc_bound(self):
        joints=[.8,.8]*4;result=model.plan(D,Q,joints,[True]*4)
        for delta in model.displacement(D,Q,joints,result['targets']):
            self.assertLess(delta[1],0.)
            self.assertLessEqual(math.sqrt(sum(v*v for v in delta)),model.FOOT_SPEED*model.DT+1e-12)

    def test_bearing_mask_preserves_inactive_hips(self):
        joints=[.8,.8]*4;result=model.plan(D,Q,joints,[False,True,False,True])
        self.assertEqual(result['targets'][::4],joints[::4])
        self.assertLess(result['targets'][2],joints[2])
        self.assertEqual(result['targets'][1::2],joints[1::2])

    def test_boundary_return_preserves_source(self):
        joints=[1.6001,-1.101]*4;before=joints[:]
        result=model.plan(D,Q,joints,[True]*4)
        self.assertEqual(joints,before)
        self.assertTrue(all(abs(v)<= (1.6 if j%2==0 else 1.1) for j,v in enumerate(result['targets'])))
        self.assertLessEqual(max(abs(a-b) for a,b in zip(joints,result['targets'])),4*model.DT)

    def test_normal_plane_refuses_alignment(self):
        q=dict(x=math.sin(math.pi/4),y=0.,z=0.,w=math.cos(math.pi/4))
        result=model.plan(D,q,[.8,.8]*4,[True]*4)
        self.assertEqual(result['hold_reason'],'gravity_normal_to_joint_plane')
        self.assertEqual(result['targets'],[.8,.8]*4)

    def test_invalid_sources_refused(self):
        cases=[([0.]*7,Q,[True]*4),([float('nan')]*8,Q,[True]*4),
            ([0.]*8,dict(x=0.,y=0.,z=0.,w=2.),[True]*4),([1.9]*8,Q,[True]*4),
            ([0.]*8,Q,[1]*4)]
        for joints,q,mask in cases:
            with self.subTest(joints=joints,q=q,mask=mask),self.assertRaises(ValueError):model.plan(D,q,joints,mask)


if __name__=='__main__':unittest.main()
