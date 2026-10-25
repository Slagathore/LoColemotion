"""Independent equality-elimination and full-coordinate checks for the secondary solve."""
import copy,unittest
import numpy as np
import hierarchical_nullspace_component as h
import hierarchical_contact_component as parent
import switching_contact_component as switching
import test_contact_priority_component as fixtures

class NullspaceControls(unittest.TestCase):
    def setUp(self):
        self.fixture=fixtures.PriorityControls();self.fixture.setUp()
        self.support,self.active=self.fixture.contact()
        self.base=self.fixture.build("combined",items=[self.fixture.item,self.support],active=[self.active])
        self.pattern=np.zeros((5,2),dtype=int)
    def prepare(self,base=None):
        base=self.base if base is None else base
        first=parent.priority_problem(base,self.pattern);primary=parent.solve_priority(first)
        self.assertTrue(primary["accepted"]);second=h.build_secondary(base,self.pattern,primary)
        result=h.solve_secondary(second);self.assertTrue(result["accepted"])
        return first,primary,second,result
    def test_01_directions_preserve_every_full_equality(self):
        _,_,q,_=self.prepare();e=q["full"]["A"][q["equality_indices"]]
        np.testing.assert_allclose(e @ q["transform"],0.,atol=1e-10,rtol=0)
        self.assertLess(q["transform"].shape[1],3*self.base["k"]+self.base["j"])
    def test_02_origin_satisfies_original_equalities(self):
        _,_,q,_=self.prepare();indices=q["equality_indices"]
        np.testing.assert_allclose(q["full"]["A"][indices] @ q["offset"],q["full"]["lower"][indices],atol=1e-9,rtol=0)
    def test_03_objective_congruence_preserves_full_cost(self):
        _,_,q,_=self.prepare();f=q["full"];r=q["reduced"];off=q["offset"]
        constant=.5*off @ f["P"] @ off+f["q"] @ off
        z=np.linspace(-.01,.02,len(r["q"]));x=q["transform"] @ z+off
        self.assertAlmostEqual(.5*x @ f["P"] @ x+f["q"] @ x,.5*z @ r["P"] @ z+r["q"] @ z+constant,places=9)
    def test_04_full_stationarity_including_reconstructed_duals(self):
        _,_,q,r=self.prepare();f=q["full"]
        np.testing.assert_allclose(f["P"] @ r["full_x"]+f["q"]+f["A"].T @ r["full_y"],0.,atol=2e-7,rtol=0)
        self.assertTrue(r["full_certificate"]["accepted"])
    def test_05_agreement_with_unreduced_secondary_when_both_solve(self):
        first,primary,_,r=self.prepare()
        old=switching.build(parent.freeze_contact(self.base,primary["full_x"]),self.pattern)
        other=switching.solve_pattern(old);self.assertTrue(other["accepted"])
        np.testing.assert_allclose(r["full_x"],other["full_x"],atol=2e-6,rtol=0)
    def test_06_duplicate_support_rows_have_a_valid_nullspace(self):
        s2=copy.deepcopy(self.support);s2["name"]="support_second"
        a2=copy.deepcopy(self.active);a2["contact_site_id"]="second"
        b=self.fixture.build("combined",items=[self.fixture.item,self.support,s2],active=[self.active,a2])
        first,primary,second,r=self.prepare(b)
        self.assertLess(second["support_rank"],6);p=parent.verify(first,primary,second,r)
        self.assertLessEqual(p["maximum_transferred_priority_error"],2e-6)
    def test_07_empty_support_preserves_full_dynamics(self):
        b=self.fixture.build("combined");first,primary,second,r=self.prepare(b)
        self.assertEqual(second["support_rank"],0);parent.verify(first,primary,second,r)
    def test_08_hierarchy_survives_conflicting_posture_goal(self):
        task=copy.deepcopy(self.fixture.item);task["target"][1]=-100.
        b=self.fixture.build("combined",items=[task,self.support],active=[self.active])
        r=h.compute(b);self.assertTrue(r["accepted"])
        self.assertLessEqual(r["prediction"]["maximum_priority_preservation_error"],2e-6)
    def test_09_corrupted_full_solution_cannot_pass(self):
        first,primary,second,r=self.prepare();r["full_x"][0]+=.01
        with self.assertRaises(ValueError):parent.verify(first,primary,second,r)
    def test_10_input_constraints_are_unchanged(self):
        before=copy.deepcopy(self.base);self.prepare()
        np.testing.assert_equal(before["A"],self.base["A"])
        np.testing.assert_equal(before["lower"],self.base["lower"]);np.testing.assert_equal(before["upper"],self.base["upper"])
    def test_11_original_command_bounds_and_force_caps_hold(self):
        r=h.compute(self.base);self.assertTrue(r["accepted"]);p=r["prediction"]
        self.assertTrue(np.all(p["target"]<=self.base["envelope"]["upper_target"]+2e-6))
        self.assertTrue(np.all(p["target"]>=self.base["envelope"]["lower_target"]-2e-6))
        self.assertTrue(np.all(p["predicted_forces"][:,1]<=70.+2e-6))
        for row in p["predicted_steps"]:
            self.assertTrue(np.all(row["torque"]>=self.base["force_ranges"][:,0]-2e-6))
            self.assertTrue(np.all(row["torque"]<=self.base["force_ranges"][:,1]+2e-6))
    def test_12_active_native_joint_limit_still_refuses(self):
        b=self.fixture.build("combined",joints=[2.001,0.]);r=h.compute(b)
        self.assertFalse(r["accepted"]);self.assertIsNone(r["selected"]);self.assertEqual(r["attempts"],[])

if __name__=="__main__":unittest.main()
