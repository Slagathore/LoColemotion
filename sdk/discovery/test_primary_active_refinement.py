"""Primary refinement preserves constraints and refuses uncertified active guesses."""
import copy
import unittest
import numpy as np
import primary_active_refinement as r

class RefinementControls(unittest.TestCase):
    def run_case(self,c,d,a,lower,upper,x,y,accepted=True):
        return r.refine(np.array(c,float),np.array(d,float),np.array(a,float),
            np.array(lower,float),np.array(upper,float),
            dict(accepted=accepted,x=np.array(x,float),y=np.array(y,float)))
    def test_01_upper_residual_removed(self):
        v=self.run_case([[1]],[1],[[1]],[-np.inf],[0],[2e-10],[1])
        self.assertTrue(v["accepted"]);self.assertEqual(v["x"][0],0.)
        self.assertEqual(v["diagnostic"]["active_sides"],["upper"])
    def test_02_lower_residual_removed(self):
        v=self.run_case([[1]],[-1],[[1]],[0],[np.inf],[-2e-10],[-1])
        self.assertTrue(v["accepted"]);self.assertEqual(v["x"][0],0.)
    def test_03_interior_optimum(self):
        v=self.run_case([[1]],[.25],[[1]],[-1],[1],[.250001],[0])
        self.assertTrue(v["accepted"]);self.assertEqual(v["x"][0],.25)
    def test_04_unobservable_direction_preserved(self):
        v=self.run_case([[1,0]],[1],[[1,0]],[-np.inf],[0],[2e-10,.7],[1])
        self.assertTrue(v["accepted"]);np.testing.assert_array_equal(v["x"],[0.,.7])
    def test_05_redundant_active_rows(self):
        v=self.run_case([[1]],[1],[[1],[2]],[-np.inf,-np.inf],[0,0],[2e-10],[.5,.25])
        self.assertTrue(v["accepted"]);self.assertEqual(v["diagnostic"]["rank"],1)
    def test_06_inconsistent_equalities_refused(self):
        v=self.run_case([[1]],[0],[[1],[1]],[0,1],[0,1],[0],[0,0])
        self.assertFalse(v["accepted"]);self.assertIsNone(v["x"])
    def test_07_wrong_active_guess_refused(self):
        v=self.run_case([[1]],[-1],[[1]],[-np.inf],[0],[0],[1])
        self.assertFalse(v["accepted"]);self.assertFalse(v["diagnostic"]["multiplier_signs_valid"])
    def test_08_initial_refusal_not_rescued(self):
        v=self.run_case([[1]],[1],[[1]],[-np.inf],[0],[0],[1],False)
        self.assertFalse(v["accepted"]);self.assertIsNone(v["x"])
    def test_09_empty_task_refines_violated_bound(self):
        c=np.zeros((0,1));a=np.ones((1,1))
        v=r.refine(c,np.zeros(0),a,np.array([-np.inf]),np.array([0.]),
            dict(accepted=True,x=np.array([2e-10]),y=np.zeros(1)))
        self.assertTrue(v["accepted"]);self.assertEqual(v["x"][0],0.)
    def test_10_inputs_preserved(self):
        c=np.eye(1);d=np.ones(1);a=np.eye(1);lo=np.array([-np.inf]);hi=np.zeros(1)
        initial=dict(accepted=True,x=np.array([2e-10]),y=np.ones(1));saved=copy.deepcopy(initial)
        r.refine(c,d,a,lo,hi,initial)
        np.testing.assert_array_equal(initial["x"],saved["x"]);np.testing.assert_array_equal(initial["y"],saved["y"])
    def test_11_original_certificate_required(self):
        v=self.run_case([[1,1]],[3],[[1,0],[0,1]],[-1,-1],[1,1],[1,1],[1,1])
        self.assertTrue(v["accepted"]);self.assertTrue(v["certificate"]["accepted"])
        self.assertLessEqual(v["certificate"]["maximum_bound_violation"],1e-12)
    def test_12_no_regularization_or_iteration_expansion(self):
        self.assertEqual(r.parameters()["objective_regularization"],0.)
        self.assertEqual(r.parameters()["refinement_passes"],1)
if __name__=="__main__":unittest.main()
