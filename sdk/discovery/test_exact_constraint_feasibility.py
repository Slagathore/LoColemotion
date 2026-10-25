"""Exact certificate controls reject tolerance-based or crossed evidence."""
import copy
from fractions import Fraction as F
import unittest
import exact_constraint_feasibility as c

def problem(a,lower,upper):
    return dict(A=a,lower=lower,upper=upper)
def certificate(p,terms):
    return dict(problem_sha256=c.digest(p),terms=[
        dict(row=i,side=s,multiplier=c.encode(F(v))) for i,s,v in terms])

class CertificateControls(unittest.TestCase):
    def setUp(self):
        self.p=problem([[1.],[1.]],[1.,None],[None,0.])
        self.cert=certificate(self.p,[(0,"lower",F(1,2)),(1,"upper",F(1,2))])
    def test_01_contradiction_verified(self):
        self.assertEqual(c.verify(self.p,self.cert)["contradiction"],["-1","2"])
    def test_02_tiny_contradiction_is_exact(self):
        p=problem([[1.],[1.]],[1e-14,None],[None,0.])
        r=c.verify(p,certificate(p,[(0,"lower",F(1,2)),(1,"upper",F(1,2))]))
        self.assertLess(c.decode(r["contradiction"]),0)
    def test_03_zero_margin_refused(self):
        p=problem([[1.],[1.]],[0.,None],[None,0.])
        with self.assertRaisesRegex(ValueError,"strictly negative"):c.verify(p,certificate(p,[(0,"lower",F(1,2)),(1,"upper",F(1,2))]))
    def test_04_positive_margin_refused(self):
        p=problem([[1.],[1.]],[0.,None],[None,1.])
        with self.assertRaisesRegex(ValueError,"strictly negative"):c.verify(p,certificate(p,[(0,"lower",F(1,2)),(1,"upper",F(1,2))]))
    def test_05_negative_inequality_weight_refused(self):
        bad=copy.deepcopy(self.cert);bad["terms"][0]["multiplier"]=["-1","2"]
        with self.assertRaisesRegex(ValueError,"sign"):c.verify(self.p,bad)
    def test_06_nonzero_stationarity_refused(self):
        bad=certificate(self.p,[(0,"lower",F(1,3)),(1,"upper",F(2,3))])
        with self.assertRaisesRegex(ValueError,"zero coefficient"):c.verify(self.p,bad)
    def test_07_crossed_problem_refused(self):
        p=copy.deepcopy(self.p);p["lower"][0]=0.
        with self.assertRaisesRegex(ValueError,"identity"):c.verify(p,self.cert)
    def test_08_duplicate_row_refused(self):
        bad=copy.deepcopy(self.cert);bad["terms"].append(bad["terms"][0])
        with self.assertRaisesRegex(ValueError,"unique"):c.verify(self.p,bad)
    def test_09_unbounded_side_refused(self):
        bad=copy.deepcopy(self.cert);bad["terms"][0]["side"]="upper"
        with self.assertRaisesRegex(ValueError,"original constraint"):c.verify(self.p,bad)
    def test_10_denominator_refused(self):
        bad=copy.deepcopy(self.cert);bad["terms"][0]["multiplier"]=["1","0"]
        with self.assertRaisesRegex(ValueError,"denominator"):c.verify(self.p,bad)
    def test_11_free_equality_multiplier(self):
        p=problem([[1.,1.],[1.,0.],[0.,1.]],[0.,1.,1.],[0.,None,None])
        r=c.verify(p,certificate(p,[(0,"equal",F(1,2)),(1,"lower",F(1,2)),(2,"lower",F(1,2))]))
        self.assertEqual(r["contradiction"],["-1","1"])
    def test_12_rational_elimination(self):
        x,rank=c.solve_exact([[F(2),F(1)],[F(1),F(-1)]],[F(1),F(0)])
        self.assertEqual(x,[F(1,3),F(1,3)]);self.assertEqual(rank,2)
    def test_13_inconsistent_exact_system(self):
        with self.assertRaisesRegex(ValueError,"Inconsistent"):
            c.solve_exact([[F(1)],[F(1)]],[F(0),F(1,10**20)])
    def test_14_redundant_exact_rows(self):
        x,rank=c.solve_exact([[F(1),F(1)],[F(2),F(2)]],[F(1),F(2)])
        self.assertEqual(x,[F(1),F(0)]);self.assertEqual(rank,1)
    def test_15_floating_search_only_proposes(self):
        result=c.diagnose(self.p,[.5])
        self.assertTrue(result["exact_infeasibility_proved"]);self.assertFalse(result["feasibility_proved"])
        self.assertTrue(c.verify(self.p,result["certificate"])["verified"])
    def test_16_feasible_system_never_certified(self):
        p=problem([[1.],[1.]],[0.,None],[None,1.])
        self.assertFalse(c.diagnose(p,[.5])["exact_infeasibility_proved"])
    def test_17_binary_coefficients_not_decimal_approximations(self):
        self.assertEqual(c.exact(.1),F(*(.1).as_integer_ratio()))
        self.assertNotEqual(c.exact(.1),F(1,10))
    def test_18_nan_refused(self):
        with self.assertRaisesRegex(ValueError,"Finite"):c.canonical(problem([[float("nan")]],[None],[1.]))
    def test_19_problem_bytes_not_mutated(self):
        p=copy.deepcopy(self.p);c.diagnose(self.p,[.5]);self.assertEqual(self.p,p)
    def test_20_normalization_required(self):
        bad=certificate(self.p,[(0,"lower",F(1)),(1,"upper",F(1))])
        with self.assertRaisesRegex(ValueError,"normalized"):c.verify(self.p,bad)
if __name__=="__main__":unittest.main()
