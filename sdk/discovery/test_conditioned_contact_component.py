"""Conditioning preserves the feasible set, objective and full-coordinate certificates."""
import copy,unittest
import numpy as np
import conditioned_contact_component as c
import hierarchical_nullspace_component as prior
import hierarchical_contact_component as hierarchy
import test_contact_priority_component as fixtures
from dynamic_qp_solver_v2 import certificate

class ConditioningControls(unittest.TestCase):
    def setUp(self):
        self.fixture=fixtures.PriorityControls();self.fixture.setUp()
        self.support,self.active=self.fixture.contact()
        self.base=self.fixture.build("combined",items=[self.fixture.item,self.support],active=[self.active])
        self.pattern=np.zeros((5,2),dtype=int)
    def prepare(self,base=None):
        base=self.base if base is None else base
        first=c.priority_problem(base,self.pattern);primary=c.solve_priority(first)
        self.assertTrue(primary["accepted"])
        raw=prior.build_secondary(base,self.pattern,primary);qp=c.condition(raw);result=c.solve_secondary(qp)
        self.assertTrue(result["accepted"])
        return first,primary,raw,qp,result
    def test_01_hessian_is_conditioned_without_regularization(self):
        _,_,raw,qp,_=self.prepare()
        self.assertGreater(np.linalg.cond(raw["reduced"]["P"]),10.)
        self.assertLess(np.linalg.cond(qp["reduced"]["P"]),1.000001)
        self.assertEqual(c.parameters()["secondary_regularization"],0.)
    def test_02_full_equalities_remain_exact(self):
        _,_,_,qp,_=self.prepare();f=qp["full"];indices=qp["equality_indices"]
        np.testing.assert_allclose(f["A"][indices] @ qp["transform"],0.,atol=1e-10,rtol=0)
        np.testing.assert_allclose(f["A"][indices] @ qp["offset"],f["lower"][indices],atol=1e-9,rtol=0)
    def test_03_constraint_values_and_bounds_are_equivalent(self):
        _,_,raw,qp,_=self.prepare();w=np.linspace(-.2,.3,len(qp["reduced"]["q"]))
        z=qp["coordinate_change"] @ w
        np.testing.assert_allclose(raw["reduced"]["A"] @ z,qp["reduced"]["A"] @ w,atol=1e-10,rtol=0)
        np.testing.assert_array_equal(raw["reduced"]["lower"],qp["reduced"]["lower"])
        np.testing.assert_array_equal(raw["reduced"]["upper"],qp["reduced"]["upper"])
    def test_04_cost_preserved_in_full_coordinates(self):
        _,_,_,qp,_=self.prepare();f=qp["full"];r=qp["reduced"];off=qp["offset"]
        constant=.5*off @ f["P"] @ off+f["q"] @ off
        for w in (np.zeros(len(r["q"])),np.linspace(-.1,.2,len(r["q"]))):
            x=qp["transform"] @ w+off
            self.assertAlmostEqual(.5*x @ f["P"] @ x+f["q"] @ x,.5*w @ r["P"] @ w+r["q"] @ w+constant,places=8)
    def test_05_original_certificate_and_priority_are_required(self):
        first,primary,_,qp,result=self.prepare();f=qp["full"]
        cert=certificate(f["P"],f["q"],f["A"],f["lower"],f["upper"],result["full_x"],result["full_y"])
        self.assertEqual(cert,result["full_certificate"]);self.assertTrue(cert["accepted"])
        prediction=hierarchy.verify(first,primary,qp,result)
        self.assertLessEqual(prediction["maximum_transferred_priority_error"],2e-6)
    def test_06_same_optimum_when_both_solvers_converge(self):
        _,_,raw,_,result=self.prepare();old=prior.solve_secondary(raw);self.assertTrue(old["accepted"])
        np.testing.assert_allclose(old["full_x"],result["full_x"],atol=2e-6,rtol=0)
    def test_07_duplicate_support_rows_remain_valid(self):
        second=copy.deepcopy(self.support);second["name"]="support_second"
        active=copy.deepcopy(self.active);active["contact_site_id"]="second"
        b=self.fixture.build("combined",items=[self.fixture.item,self.support,second],active=[self.active,active])
        first,primary,_,qp,result=self.prepare(b)
        self.assertLess(qp["support_rank"],6);hierarchy.verify(first,primary,qp,result)
    def test_08_empty_support_retains_full_dynamics(self):
        first,primary,_,qp,result=self.prepare(self.fixture.build("combined"))
        self.assertEqual(qp["support_rank"],0);hierarchy.verify(first,primary,qp,result)
    def test_09_conflicting_posture_cannot_change_support_priority(self):
        task=copy.deepcopy(self.fixture.item);task["target"][1]=-100.
        b=self.fixture.build("combined",items=[task,self.support],active=[self.active])
        result=c.compute(b);self.assertTrue(result["accepted"])
        self.assertLessEqual(result["prediction"]["maximum_transferred_priority_error"],2e-6)
    def test_10_conditioning_does_not_mutate_predecessor(self):
        _,_,raw,_,_=self.prepare();before=copy.deepcopy(raw);c.condition(raw)
        for key in ("P","q","A","lower","upper"):np.testing.assert_array_equal(raw["reduced"][key],before["reduced"][key])
        np.testing.assert_array_equal(raw["transform"],before["transform"])
    def test_11_outside_native_joint_range_still_refuses(self):
        result=c.compute(self.fixture.build("combined",joints=[2.001,0.]))
        self.assertFalse(result["accepted"]);self.assertIsNone(result["selected"]);self.assertEqual(result["attempts"],[])
    def test_12_nonpositive_hessian_is_not_repaired(self):
        _,_,raw,_,_=self.prepare();raw["reduced"]["P"][0,0]=-1.
        with self.assertRaises(np.linalg.LinAlgError):c.condition(raw)

if __name__=="__main__":unittest.main()
