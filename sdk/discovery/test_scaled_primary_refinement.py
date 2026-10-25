"""Analytic correction mapping, strict guards, refusals and bounded inner work."""
import copy,unittest
from unittest.mock import patch
import numpy as np
import scaled_primary_refinement as s
import hierarchical_least_squares_qp as least
from dynamic_qp_solver_v2 import problem_digest
from causal_force_policy import plain

def fixture(c=None,d=None,a=None,lo=None,hi=None):
    c=np.array([[1.]] if c is None else c,dtype=float);d=np.array([2.] if d is None else d,dtype=float)
    a=np.array([[1.]] if a is None else a,dtype=float);lo=np.array([-np.inf] if lo is None else lo,dtype=float);hi=np.array([1.] if hi is None else hi,dtype=float)
    p,q,a,lo,hi=least.problem(c,d,a,lo,hi);block=dict(P=p,q=q,A=a,lower=lo,upper=hi)
    return dict(reduced=block,full=copy.deepcopy(block),transform=np.eye(len(q)),offset=np.zeros(len(q)),base=dict(n=0),
        task_matrix=c,task_target=d,reduced_task_matrix=c,reduced_task_target=d)
def seed(qp,x,y):
    b=qp["reduced"];x=np.array(x);y=np.array(y)
    cert=least.certificate(qp["task_matrix"],qp["task_target"],b["A"],b["lower"],b["upper"],x,y)
    digest=problem_digest(b["P"],b["q"],b["A"],b["lower"],b["upper"])
    return dict(accepted=cert["accepted"],full_x=x,full_y=y,full_certificate=cert,full_problem_sha256=digest,
        reduced=dict(accepted=cert["accepted"],status="solved",x=x,y=y,certificate=cert,problem_sha256=digest))
class ScaledControls(unittest.TestCase):
    def setUp(self):
        self.qp=fixture();self.initial=seed(self.qp,[1.+2e-10],[1.-2e-10]);self.assertTrue(self.initial["accepted"])
    def run_seed(self,qp=None,initial=None):
        with patch.object(s.previous,"initial_priority",return_value=self.initial if initial is None else initial):
            return s.solve_priority(self.qp if qp is None else qp)
    def test_01_upper_bound_refined_without_relaxation(self):
        r=self.run_seed();self.assertTrue(s.strict(r));self.assertEqual(r["primary_selection_mode"],"scaled_correction")
        self.assertLessEqual(r["qp_solves"],4);np.testing.assert_allclose(r["full_x"],[1.],atol=1e-12,rtol=0)
    def test_02_lower_bound_and_dual_sign(self):
        qp=fixture(d=[-2.],lo=[-1.],hi=[np.inf]);r=self.run_seed(qp,seed(qp,[-1.-2e-10],[-1.+2e-10]))
        self.assertTrue(s.strict(r));self.assertLess(r["full_y"][0],0)
    def test_03_strict_seed_preserved(self):
        initial=seed(self.qp,[1.],[1.])
        with patch.object(s.solver,"solve",side_effect=AssertionError("No correction required")):
            r=self.run_seed(initial=initial)
        self.assertEqual(r["qp_solves"],1);self.assertEqual(r["scaled_corrections"],[])
        np.testing.assert_array_equal(r["full_x"],initial["full_x"])
    def test_04_refused_initial_cannot_open_correction(self):
        initial=dict(self.initial,accepted=False)
        with patch.object(s.solver,"solve",side_effect=AssertionError("Refused initial")):r=self.run_seed(initial=initial)
        self.assertFalse(r["accepted"]);self.assertEqual(r["qp_solves"],1)
    def test_05_affine_objective_and_bounds(self):
        p=s.correction_problem(self.qp,np.array([1.+2e-10]),20);z=np.array([.03])
        x=p["origin"]+z/p["scale"]
        np.testing.assert_allclose(self.qp["task_matrix"]@x-self.qp["task_target"],
            (p["task_matrix"]@z-p["task_target"])/p["scale"],atol=3e-16,rtol=0)
        np.testing.assert_allclose(self.qp["reduced"]["upper"]-self.qp["reduced"]["A"]@x,
            (p["upper"]-p["A"]@z)/p["scale"],atol=3e-16,rtol=0)
        self.assertTrue(np.isneginf(p["lower"][0]))
    def test_06_original_dual_and_certificate_required(self):
        r=self.run_seed();b=self.qp["reduced"]
        cert=least.certificate(self.qp["task_matrix"],self.qp["task_target"],b["A"],b["lower"],b["upper"],r["full_x"],r["full_y"])
        self.assertEqual(cert,r["full_certificate"]);self.assertTrue(cert["accepted"])
    def test_07_exact_three_refusals_are_bounded(self):
        with patch.object(s.solver,"solve",return_value=dict(accepted=False,status="iteration limit")) as solver:r=self.run_seed()
        self.assertFalse(r["accepted"]);self.assertEqual(solver.call_count,3);self.assertEqual(r["qp_solves"],4)
        self.assertEqual([x["exponent"] for x in r["scaled_corrections"]],[20,30,40])
    def test_08_inputs_unchanged(self):
        before=plain(self.qp);initial=plain(self.initial);self.run_seed()
        self.assertEqual(plain(self.qp),before);self.assertEqual(plain(self.initial),initial)
    def test_09_deterministic_repeat(self):self.assertEqual(plain(self.run_seed()),plain(self.run_seed()))
    def test_10_rank_deficient_objective(self):
        qp=fixture(c=[[1.,1.]],d=[2.],a=[[1.,0.]],lo=[-np.inf],hi=[.5])
        r=self.run_seed(qp,seed(qp,[.5+2e-10,1.5-2e-10],[0.]))
        self.assertTrue(s.strict(r));self.assertLessEqual(r["full_x"][0],.5+1e-12)
    def test_11_equality_and_duplicate_rows(self):
        qp=fixture(a=[[1.],[2.]],lo=[1.,2.],hi=[1.,2.])
        r=self.run_seed(qp,seed(qp,[1.+2e-10],[1.-2e-10,0.]))
        self.assertTrue(s.strict(r));np.testing.assert_allclose(r["full_x"],[1.],atol=1e-12,rtol=0)
    def test_12_undeclared_scale_and_nonfinite_origin_refused(self):
        for origin,exponent in (([1.],19),([float("nan")],20),([],20)):
            with self.assertRaises(ValueError):s.correction_problem(self.qp,np.array(origin),exponent)
    def test_13_corrupt_scaled_certificate_refused(self):
        p=s.correction_problem(self.qp,self.initial["reduced"]["x"],20)
        r=s.solver.solve(p["task_matrix"],p["task_target"],p["A"],p["lower"],p["upper"]);r["certificate"]={}
        with self.assertRaises(ValueError):s.mapped_solution(self.qp,p,r)
    def test_14_crossed_problem_or_unsolved_status_refused(self):
        p=s.correction_problem(self.qp,self.initial["reduced"]["x"],20)
        r=s.solver.solve(p["task_matrix"],p["task_target"],p["A"],p["lower"],p["upper"])
        for change in (dict(problem_sha256="0"*64),dict(status="solved inaccurate"),dict(accepted=False)):
            with self.assertRaises(ValueError):s.mapped_solution(self.qp,p,dict(r,**change))
if __name__=="__main__":unittest.main()
