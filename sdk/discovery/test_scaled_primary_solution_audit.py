"""Synthetic independent-reader branch controls, including refused and multiple corrections."""
import copy,os,unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
import scaled_primary_refinement as producer
import scaled_primary_solution_audit as reader
import scaled_primary_contact_component as component
import hierarchical_least_squares_qp as least
from test_scaled_primary_refinement import fixture
from dynamic_qp_solver_v2 import problem_digest
from causal_force_policy import plain
from gpu_measurement_probe import write_new

def raw(c,d,a,lo,hi,x=None,y=None):
    p,q,a,lo,hi=least.problem(c,d,a,lo,hi)
    r=dict(backend="ProxQP 0.7.2 generic dense PrimalDualLDLT",settings=component.solver_settings()["priority"],
        initial_guess="NO_INITIAL_GUESS",hessian_source="exact least-squares Gram matrix; no regularization",
        problem_sha256=problem_digest(p,q,a,lo,hi),iterations=1,status="solved" if x is not None else "max iter reached",
        accepted=False,x=x,y=y,certificate=None)
    if x is not None:
        cert=least.certificate(c,d,a,lo,hi,x,y);r.update(accepted=cert["accepted"],certificate=cert)
    return r

def seed(qp,x=None,y=None):
    b=qp["reduced"];f=qp["full"]
    r=raw(qp["reduced_task_matrix"],qp["reduced_task_target"],b["A"],b["lower"],b["upper"],x,y)
    if not r["accepted"]:
        return dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
            full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]))
    fx=qp["transform"]@x+qp["offset"];fy=y.copy()
    cert=least.certificate(qp["task_matrix"],qp["task_target"],f["A"],f["lower"],f["upper"],fx,fy)
    return dict(reduced=r,accepted=cert["accepted"],full_x=fx,full_y=fy,full_certificate=cert,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]))

class SolutionControls(unittest.TestCase):
    def make(self,qp,initial,oracle):
        with patch.object(producer.previous,"initial_priority",return_value=initial),patch.object(producer.solver,"solve",side_effect=oracle):
            result=plain(producer.solve_priority(qp))
        if os.environ.get("EXPLORER_TEST_OUTPUT"):
            write_new(Path(os.environ["EXPLORER_TEST_OUTPUT"])/(self._testMethodName+"-scaled-reader.json"),result)
        return result
    def verify(self,qp,result):
        with patch.object(producer,"solve_priority",side_effect=AssertionError),patch.object(producer,"mapped_solution",side_effect=AssertionError):
            return reader.verify_primary(qp,result,component.solver_settings())
    def test_01_strict_seed_without_corrections(self):
        qp=fixture();r=self.make(qp,seed(qp,np.array([1.]),np.array([1.])),lambda *args: self.fail("No correction"))
        self.assertEqual(self.verify(qp,r),1)
    def test_02_certified_original_correction_mapping(self):
        qp=fixture()
        def oracle(c,d,a,lo,hi):return raw(c,d,a,lo,hi,np.array([hi[0]]),np.array([d[0]-hi[0]]))
        r=self.make(qp,seed(qp,np.array([1.+2e-10]),np.array([1.-2e-10])),oracle)
        self.assertEqual(self.verify(qp,r),2);self.assertTrue(r["accepted"])
    def test_03_refused_initial_opens_no_correction(self):
        qp=fixture();r=self.make(qp,seed(qp),lambda *args:self.fail("Refused initial"))
        self.assertEqual(self.verify(qp,r),1);self.assertFalse(r["accepted"])
    def test_04_three_refusals_preserve_budget(self):
        qp=fixture();r=self.make(qp,seed(qp,np.array([1.+2e-10]),np.array([1.-2e-10])),raw)
        self.assertEqual(self.verify(qp,r),4);self.assertFalse(r["accepted"])
    def test_05_refusal_then_second_scale_acceptance(self):
        qp=fixture();calls=[]
        def oracle(c,d,a,lo,hi):
            calls.append(1)
            return raw(c,d,a,lo,hi) if len(calls)==1 else raw(c,d,a,lo,hi,np.array([hi[0]]),np.array([d[0]-hi[0]]))
        r=self.make(qp,seed(qp,np.array([1.+2e-10]),np.array([1.-2e-10])),oracle)
        self.assertEqual(self.verify(qp,r),3);self.assertTrue(r["accepted"])
    def test_06_accepted_nonstrict_correction_updates_origin(self):
        qp=fixture(c=[[0.]],d=[0.]);calls=[]
        def oracle(c,d,a,lo,hi):
            calls.append(1);delta=1.5e-12*2**20 if len(calls)==1 else 0.
            return raw(c,d,a,lo,hi,np.array([hi[0]+delta]),np.array([0.]))
        r=self.make(qp,seed(qp,np.array([1.+2e-10]),np.array([0.])),oracle)
        self.assertEqual(self.verify(qp,r),3);self.assertTrue(r["accepted"])
        self.assertNotEqual(r["scaled_corrections"][0]["problem"]["origin"],r["scaled_corrections"][1]["problem"]["origin"])
    def test_07_truncated_refusal_budget_rejected(self):
        qp=fixture();r=self.make(qp,seed(qp,np.array([1.+2e-10]),np.array([1.-2e-10])),raw)
        r["scaled_corrections"].pop();r["qp_solves"]=3
        with self.assertRaises(ValueError):self.verify(qp,r)
    def test_08_reduced_success_cannot_bypass_full_refusal(self):
        qp=fixture();qp["full"]["upper"]=np.array([0.])
        r=self.make(qp,seed(qp,np.array([1.]),np.array([1.])),lambda *args:self.fail("Full refusal"))
        self.assertEqual(self.verify(qp,r),1);self.assertFalse(r["accepted"])
        r["accepted"]=True
        with self.assertRaises(ValueError):self.verify(qp,r)

if __name__=="__main__":unittest.main()
