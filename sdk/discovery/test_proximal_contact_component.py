"""Rank-deficient QP and strict hierarchy controls with incompatible task goals."""
import copy,unittest
from unittest.mock import patch
import numpy as np
import hierarchical_least_squares_qp as least
import proximal_contact_component as h
import switching_contact_component as switching
import dynamic_qp_solver_v2 as oldqp
import test_contact_priority_component as fixtures

class HierarchyControls(unittest.TestCase):
    def setUp(self):
        self.fixture=fixtures.PriorityControls();self.fixture.setUp()
        self.support,self.active=self.fixture.contact()
        self.base=self.fixture.build("combined",items=[self.fixture.item,self.support],active=[self.active])
        self.pattern=np.zeros((5,2),dtype=int)
    def stages(self,base=None):
        base=self.base if base is None else base
        first=h.priority_problem(base,self.pattern);r=h.solve_priority(first)
        self.assertTrue(r["accepted"])
        second=switching.build(h.freeze_contact(base,r["full_x"]),self.pattern);s=h.solve_secondary(second)
        self.assertTrue(s["accepted"]);return first,r,second,s
    def test_01_rank_deficient_objective(self):
        r=least.solve([[1.,0.]],[1.],np.eye(2),[-2.,-2.],[2.,2.])
        self.assertTrue(r["accepted"]);self.assertAlmostEqual(r["x"][0],1.,places=8)
    def test_02_zero_objective_is_feasibility_only(self):
        r=least.solve(np.zeros((0,2)),[],np.eye(2),[1.,2.],[3.,4.])
        self.assertTrue(r["accepted"]);self.assertTrue(np.all(r["x"]>=[1.-2e-6,2.-2e-6]))
    def test_03_inconsistent_constraints_refuse(self):
        r=least.solve([[1.]],[0.],[[1.],[1.]],[2.,-np.inf],[np.inf,1.])
        self.assertFalse(r["accepted"]);self.assertIsNone(r["x"])
    def test_04_full_rank_certificate_matches_existing_acceptance(self):
        c=np.diag([2.,3.]);d=np.array([1.,2.]);a=np.eye(2);lo=np.array([-1.,-1.]);hi=np.array([1.,1.])
        r=least.solve(c,d,a,lo,hi);self.assertTrue(r["accepted"])
        self.assertEqual(r["certificate"],oldqp.certificate(c.T @ c,-c.T @ d,a,lo,hi,r["x"],r["y"]))
    def test_05_nonfinite_task_refused(self):
        with self.assertRaises(ValueError):least.solve([[float("nan")]],[0.],[[1.]],[-1.],[1.])
    def test_06_solver_settings_unchanged(self):
        self.assertEqual(least.settings(),oldqp.settings())
        self.assertEqual(least.settings()["max_iter"],20000)
    def test_07_corrupt_rank_deficient_dual_refused(self):
        c=np.array([[1.,0.]]);d=np.array([1.]);a=np.eye(2);r=least.solve(c,d,a,[-2.,-2.],[2.,2.])
        dual=r["y"].copy();dual[0]+=.1
        self.assertFalse(least.certificate(c,d,a,[-2.,-2.],[2.,2.],r["x"],dual)["accepted"])
    def test_08_unattainable_target_has_certified_nonzero_error(self):
        r=least.solve([[1.,0.]],[2.],np.eye(2),[-1.,-1.],[1.,1.])
        self.assertTrue(r["accepted"]);self.assertAlmostEqual(r["x"][0],1.,places=8)
        self.assertAlmostEqual((np.array([[1.,0.]]) @ r["x"]-2.).item(),-1.,places=8)
    def test_09_empty_support_still_preserves_motor_joint_constraints(self):
        b=self.fixture.build("combined");r=h.compute(b)
        self.assertTrue(r["accepted"]);self.assertEqual(len(r["prediction"]["optimal_support_vector"]),0)
    def test_10_unreachable_support_goal_does_not_drop_hard_limits(self):
        goal=copy.deepcopy(self.support);goal["target"][1]=1000.
        b=self.fixture.build("combined",items=[self.fixture.item,goal],active=[self.active])
        r=h.compute(b);self.assertTrue(r["accepted"])
        self.assertGreater(np.linalg.norm(r["prediction"]["requested_support_error"]),1.)
        self.assertLessEqual(r["prediction"]["predicted_forces"][0,1],70.+2e-6)
    def test_11_secondary_objective_cannot_worsen_attained_support(self):
        first,r,second,s=self.stages();p=h.verify(first,r,second,s)
        self.assertLessEqual(p["maximum_priority_preservation_error"],2e-6)
        task=copy.deepcopy(self.fixture.item);task["target"][1]=-100.
        b=self.fixture.build("combined",items=[task,self.support],active=[self.active])
        other=h.compute(b);self.assertTrue(other["accepted"])
        np.testing.assert_allclose(other["prediction"]["attained_support_vector"],p["attained_support_vector"],atol=2e-6,rtol=0)
    def test_12_every_predicted_joint_state_is_bounded(self):
        r=h.compute(self.base);self.assertTrue(r["accepted"]);margin=3.5/600.
        for row in r["prediction"]["predicted_steps"]:
            self.assertTrue(np.all(row["joint_position"]<=self.base["joint_ranges"][:,1]-margin+2e-6))
            self.assertTrue(np.all(row["joint_position"]>=self.base["joint_ranges"][:,0]+margin-2e-6))
            self.assertTrue(np.all(np.abs(row["velocity"][6:])<=3.5+2e-6))
    def test_13_corrupt_primary_solution_refused(self):
        first,r,second,s=self.stages();r["full_x"][0]+=.01
        with self.assertRaises(ValueError):h.verify(first,r,second,s)
    def test_14_corrupt_secondary_solution_refused(self):
        first,r,second,s=self.stages();s["full_x"][0]+=.01
        with self.assertRaises(ValueError):h.verify(first,r,second,s)
    def test_15_relaxed_pattern_cannot_issue_command(self):
        first,r,second,s=self.stages();first["strict"]=False
        with self.assertRaises(ValueError):h.verify(first,r,second,s)
    def test_16_active_joint_limit_refuses_before_optimization(self):
        b=self.fixture.build("combined",joints=[2.001,0.]);r=h.compute(b)
        self.assertFalse(r["accepted"]);self.assertEqual(r["attempts"],[]);self.assertIsNone(r["selected"])
    def test_17_first_level_has_no_diagonal_regularization(self):
        qp=h.priority_problem(self.base,self.pattern);c=qp["task_matrix"]
        np.testing.assert_equal(qp["full"]["P"],c.T @ c)
        self.assertLess(np.linalg.matrix_rank(qp["full"]["P"]),len(qp["full"]["q"]))
    def test_18_freezing_support_preserves_original_input_and_command_rows(self):
        first,r,_,_=self.stages();before=copy.deepcopy(self.base);b=h.freeze_contact(self.base,r["full_x"])
        np.testing.assert_equal(self.base["lower"],before["lower"])
        indices=[i for i,name in enumerate(b["row_names"]) if name=="command"]
        np.testing.assert_equal(b["lower"][indices],before["lower"][indices])
        np.testing.assert_equal(b["upper"][indices],before["upper"][indices])
    def test_19_search_has_a_finite_pattern_bound(self):
        patterns=[]
        for i in range(9):
            a=self.pattern.copy();a[0]=[i%3-1,i//3-1];patterns.append((str(i),a))
        with patch.object(switching,"initial_patterns",return_value=patterns),patch.object(h,"solve_priority",return_value=dict(accepted=False)):
            r=h.compute(self.base)
        self.assertFalse(r["accepted"]);self.assertEqual(r["patterns_tried"],8);self.assertEqual(len(r["attempts"]),16)
    def test_20_contact_error_is_explicit_and_not_physical_authority(self):
        r=h.compute(self.base);self.assertTrue(r["accepted"])
        self.assertTrue(r["prediction"]["nonzero_contact_error_is_permitted"])
        self.assertFalse(r["prediction"]["physical_acceptance_authority"])
        self.assertFalse(r["prediction"]["contact_persistence_established"])

if __name__=="__main__":unittest.main()
