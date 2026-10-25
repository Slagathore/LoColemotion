"""Analytic optima and corrupt/refused solution controls; no simulation."""
import unittest
from unittest.mock import patch
import numpy as np
import proximal_qp_solver as qp


class QPControls(unittest.TestCase):
    def close(self,a,b):np.testing.assert_allclose(a,b,atol=2e-7,rtol=2e-7)
    def test_01_unconstrained_optimum(self):
        r=qp.solve([[2.]],[-4.],np.zeros((0,1)),[],[]);self.assertTrue(r["accepted"]);self.close(r["x"],[2.])
    def test_02_active_upper_bound(self):
        r=qp.solve([[2.]],[-4.],[[1.]],[-np.inf],[1.]);self.assertTrue(r["accepted"]);self.close(r["x"],[1.]);self.close(r["y"],[2.])
    def test_03_active_lower_bound(self):
        r=qp.solve([[2.]],[4.],[[1.]],[-1.],[np.inf]);self.assertTrue(r["accepted"]);self.close(r["x"],[-1.]);self.close(r["y"],[-2.])
    def test_04_equality_analytic_optimum(self):
        r=qp.solve(np.eye(2),[0.,0.],[[1.,1.]],[3.],[3.]);self.assertTrue(r["accepted"]);self.close(r["x"],[1.5,1.5])
    def test_05_rank_deficient_equalities(self):
        r=qp.solve(np.eye(2),[0.,0.],[[1.,1.],[2.,2.]],[3.,6.],[3.,6.]);self.assertTrue(r["accepted"]);self.close(r["x"],[1.5,1.5])
    def test_06_infeasible_has_no_command_solution(self):
        r=qp.solve([[1.]],[0.],[[1.],[1.]],[-np.inf,1.],[0.,np.inf])
        self.assertFalse(r["accepted"]);self.assertIsNone(r["x"]);self.assertIn(r["status"],("primal infeasible","max iter reached"))
    def test_07_iteration_exhaustion_is_refused(self):
        settings=dict(qp.settings(),max_iter=1,max_iter_in=1)
        with patch.object(qp,"settings",return_value=settings):r=qp.solve([[2.]],[-400.],[[1.]],[-np.inf],[1.])
        self.assertFalse(r["accepted"]);self.assertIsNone(r["x"])
    def test_08_corrupted_primal_refused(self):
        self.assertFalse(qp.certificate([[2.]],[-4.],[[1.]],[-np.inf],[1.],[2.],[2.])["accepted"])
    def test_09_corrupted_dual_refused(self):
        self.assertFalse(qp.certificate([[2.]],[-4.],[[1.]],[-np.inf],[1.],[1.],[0.])["accepted"])
    def test_10_invalid_problem_refused(self):
        for p,q,a,l,u in (([[-1.]],[0.],[[1.]],[0.],[1.]),([[1.]],[float("nan")],[[1.]],[0.],[1.]),
            ([[1.]],[0.],[[1.]],[2.],[1.]),([[1.]],[0.],[[1.]],[0.],[float("nan")])):
            with self.assertRaises((ValueError,np.linalg.LinAlgError)):qp.solve(p,q,a,l,u)
    def test_11_repeat_solve_is_identical(self):
        args=(np.eye(2),[3.,-2.],[[1.,1.],[1.,0.]],[0.,-.2],[0.,.4])
        a=qp.solve(*args);b=qp.solve(*args);self.assertTrue(a["accepted"]);np.testing.assert_array_equal(a["x"],b["x"])
        self.assertEqual(a["iterations"],b["iterations"]);self.assertEqual(a["problem_sha256"],b["problem_sha256"])
    def test_12_certificate_rejects_nonfinite_solution(self):
        with self.assertRaises(ValueError):qp.certificate([[1.]],[0.],[[1.]],[-1.],[1.],[float("nan")],[0.])

    def test_13_unbounded_rows_preserve_zero_duals(self):
        r=qp.solve([[2.]],[-4.],[[1.],[7.]],[-np.inf,-np.inf],[1.,np.inf])
        self.assertTrue(r["accepted"]);self.close(r["x"],[1.]);self.close(r["y"],[2.,0.])
    def test_14_closest_feasible_status_never_returns_a_command(self):
        from types import SimpleNamespace as N
        native=qp.proxsuite.proxqp.dense.QP(1,0,0)
        info=N(status=type(native.results.info.status).PROXQP_SOLVED_CLOSEST_PRIMAL_FEASIBLE,
            iter=1,iter_ext=1,pri_res=1.,dua_res=0.,duality_gap=0.)
        fake=N(settings=N(initial_guess=native.settings.initial_guess),init=lambda *args:None,solve=lambda:None,
            results=N(info=info,x=np.zeros(1),y=np.zeros(0),z=np.zeros(1)))
        with patch.object(qp.proxsuite.proxqp.dense,"QP",return_value=fake):
            result=qp.solve([[1.]],[0.],[[1.]],[1.],[np.inf])
        self.assertFalse(result["accepted"]);self.assertIsNone(result["x"]);self.assertIsNone(result["certificate"])

if __name__=="__main__":unittest.main()
