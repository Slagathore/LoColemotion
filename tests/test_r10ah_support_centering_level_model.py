"""Finite second-probe controls; all supplied inputs are mathematical fixtures."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10ah_support_centering_level_model as candidate


class LevelCenteringTests(unittest.TestCase):
    def test_enumeration_determinism_and_input_immutability(self):
        class Model:
            qualified=[True]*4;p=[0.,.1,0.];q=dict(x=0.,y=0.,z=0.,w=1.)
            flat=q;com_local=[0.,0.,0.];com=p;yaw=0.
            feet=[[.1,0.,-.2],[.5,0.,-.2],[.5,0.,.2],[.1,0.,.2]]
            def solve(self,feet,p,q):return ([0.]*8,0.)
            def cost(self,p,q,feet):return 1.
        model=Model();before=copy.deepcopy(model.__dict__)
        result=candidate.center_search(model)
        self.assertEqual(90,result['candidates']);self.assertEqual(90,result['feasible'])
        self.assertEqual(result,candidate.center_search(model))
        self.assertEqual(0.,result['selected']['translation'][1])
        self.assertEqual(before,model.__dict__)

    def test_unqualified_support_refuses(self):
        from types import SimpleNamespace
        with self.assertRaises(AssertionError):
            candidate.center_search(SimpleNamespace(qualified=[False]*4))

    def test_no_ik_solution_is_explicit(self):
        class Model:
            qualified=[True]*4;p=[0.,.1,0.];q=dict(x=0.,y=0.,z=0.,w=1.)
            flat=q;com_local=[0.,0.,0.];com=p;yaw=0.
            feet=[[.1,0.,-.2],[.5,0.,-.2],[.5,0.,.2],[.1,0.,.2]]
            def solve(self,feet,p,q):return None
        result=candidate.center_search(Model())
        self.assertIsNone(result['selected']);self.assertEqual(0,result['feasible'])
        self.assertEqual(90,result['candidates'])


if __name__=='__main__':unittest.main()
