"""Geometry controls for a zero-world candidate; no physical success assertions."""
import copy
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10ah_support_centering_model as candidate


class CenteringModelTests(unittest.TestCase):
    def test_signed_margin_and_corner_distance_are_distinct(self):
        feet=[[-1.,0.,-1.],[1.,0.,-1.],[1.,0.,1.],[-1.,0.,1.]]
        self.assertEqual(1.,candidate.margin(feet,[0.,10.,0.]))
        self.assertEqual(0.,candidate.margin(feet,[1.,0.,0.]))
        self.assertEqual(-1.,candidate.margin(feet,[2.,0.,2.]))

    def test_hull_ignores_order_duplicates_and_interior_points(self):
        points=[[-1.,-1.],[1.,-1.],[1.,1.],[-1.,1.],[0.,0.],[-1.,-1.]]
        expected=[(-1.,-1.),(1.,-1.),(1.,1.),(-1.,1.)]
        self.assertEqual(expected,candidate.hull(points))
        self.assertEqual(expected,candidate.hull(list(reversed(points))))

    def test_degenerate_support_refuses(self):
        for points in ([],[[0.,0.]],[[0.,0.],[1.,1.],[2.,2.]]):
            with self.assertRaisesRegex(ValueError,'DEGENERATE_SUPPORT_POLYGON'):
                candidate.hull(points)

    def test_margin_is_rigid_horizontal_transform_invariant(self):
        feet=[[-1.,0.,-.5],[1.,0.,-.5],[1.,0.,.5],[-1.,0.,.5]]
        com=[-.4,.7,.1]
        def transform(p):
            return [2.+p[0]*math.cos(.7)-p[2]*math.sin(.7),p[1]+3.,-4.+p[0]*math.sin(.7)+p[2]*math.cos(.7)]
        self.assertAlmostEqual(candidate.margin(feet,com),candidate.margin(list(map(transform,feet)),transform(com)))

    def test_centering_requires_qualified_support(self):
        from types import SimpleNamespace
        with self.assertRaises(AssertionError):
            candidate.center_search(SimpleNamespace(qualified=[True,True,False,True]),True)

    def test_candidate_count_and_no_rise_tie_preference(self):
        # A tiny analytic fixture tests selection without pretending it is a
        # validated native observation or a complete report-consumer fixture.
        class Model:
            qualified=[True]*4; p=[0.,.1,0.]; q=dict(x=0.,y=0.,z=0.,w=1.)
            com_local=[0.,0.,0.]; com=p; yaw=0.
            feet=[[.1,0.,-.2],[.5,0.,-.2],[.5,0.,.2],[.1,0.,.2]]
            def solve(self,feet,p,q):return ([0.]*8,0.)
            def cost(self,p,q,feet):return 1.
        model=Model(); original=copy.deepcopy(model.__dict__)
        for coupled,count in ((False,10),(True,30)):
            result=candidate.center_search(model,coupled)
            self.assertEqual(count,result['candidates'])
            self.assertEqual(count,result['feasible'])
            self.assertGreater(result['selected']['support_margin_m'],result['initial_support_margin_m'])
            self.assertEqual(0.,result['selected']['translation'][1])
            self.assertEqual(0.,result['selected']['blend'])
        self.assertEqual(original,model.__dict__)


if __name__=='__main__':unittest.main()
