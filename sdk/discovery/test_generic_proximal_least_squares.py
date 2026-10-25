"""Analytic semidefinite primary optima, original certificates and refused statuses."""
import copy,unittest
from unittest.mock import patch
import numpy as np
import generic_proximal_least_squares as qp

class LeastSquaresControls(unittest.TestCase):
    def close(self,a,b):np.testing.assert_allclose(a,b,atol=2e-7,rtol=2e-7)
    def test_01_unconstrained_rank_deficient_task(self):
        r=qp.solve([[1.,1.]],[2.],np.zeros((0,2)),[],[])
        self.assertTrue(r["accepted"]);self.close(sum(r["x"]),2.)
    def test_02_active_upper_bound_and_dual(self):
        r=qp.solve([[1.]],[2.],[[1.]],[-np.inf],[1.])
        self.assertTrue(r["accepted"]);self.close(r["x"],[1.]);self.close(r["y"],[1.])
    def test_03_active_lower_bound_and_dual(self):
        r=qp.solve([[1.]],[-2.],[[1.]],[-1.],[np.inf])
        self.assertTrue(r["accepted"]);self.close(r["x"],[-1.]);self.close(r["y"],[-1.])
    def test_04_rank_deficient_task_with_equality(self):
        r=qp.solve([[1.,1.]],[2.],[[1.,0.]],[.5],[.5])
        self.assertTrue(r["accepted"]);self.close(r["x"],[.5,1.5])
    def test_05_duplicate_equalities(self):
        r=qp.solve([[1.,1.]],[2.],[[1.,0.],[2.,0.]],[.5,1.],[.5,1.])
        self.assertTrue(r["accepted"]);self.close(r["x"],[.5,1.5])
    def test_06_empty_task_has_no_added_regularization(self):
        c=np.zeros((0,2));r=qp.solve(c,[],np.eye(2),[1.,2.],[1.,2.])
        self.assertTrue(r["accepted"]);self.close(r["x"],[1.,2.])
        p,q,*_=qp.problem(c,[],np.eye(2),[1.,2.],[1.,2.])
        np.testing.assert_array_equal(p,np.zeros((2,2)));np.testing.assert_array_equal(q,[0.,0.])
    def test_07_infeasible_is_refused(self):
        r=qp.solve([[1.]],[0.],[[1.],[1.]],[-np.inf,1.],[0.,np.inf])
        self.assertFalse(r["accepted"]);self.assertIsNone(r["x"])
    def test_08_exhausted_iteration_is_refused(self):
        with patch.object(qp,"settings",return_value=dict(qp.settings(),max_iter=1,max_iter_in=1)):
            r=qp.solve([[1.]],[400.],[[1.]],[-np.inf],[1.])
        self.assertFalse(r["accepted"]);self.assertIsNone(r["x"])
    def test_09_corrupt_primal_and_dual_certificates(self):
        self.assertFalse(qp.certificate([[1.]],[2.],[[1.]],[-np.inf],[1.],[2.],[1.])["accepted"])
        self.assertFalse(qp.certificate([[1.]],[2.],[[1.]],[-np.inf],[1.],[1.],[0.])["accepted"])
    def test_10_invalid_problem_refused(self):
        for args in (([[float("nan")]],[0.],[[1.]],[0.],[1.]),([[1.]],[float("inf")],[[1.]],[0.],[1.]),
            ([[1.]],[0.],[[1.]],[2.],[1.]),([[1.]],[0.],[[1.]],[0.],[float("nan")])):
            with self.assertRaises(ValueError):qp.solve(*args)
    def test_11_complete_repeat_is_identical(self):
        from causal_force_policy import plain
        from audit_gpu_batch_execution import same_bits
        args=([[1.,2.]],[3.],[[1.,1.],[1.,0.]],[0.,-.2],[0.,.4])
        a=qp.solve(*args);b=qp.solve(*args);self.assertTrue(a["accepted"])
        self.assertTrue(same_bits(plain(a),plain(b)))
    def test_12_unbounded_rows_have_zero_duals(self):
        r=qp.solve([[1.]],[2.],[[1.],[7.]],[-np.inf,-np.inf],[1.,np.inf])
        self.assertTrue(r["accepted"]);self.close(r["y"],[1.,0.])
    def test_13_closest_feasible_cannot_issue_solution(self):
        from types import SimpleNamespace as N
        native=qp.proxsuite.proxqp.dense.QP(1,0,0)
        info=N(status=type(native.results.info.status).PROXQP_SOLVED_CLOSEST_PRIMAL_FEASIBLE,
            iter=1,iter_ext=1,pri_res=1.,dua_res=0.,duality_gap=0.)
        fake=N(settings=N(initial_guess=native.settings.initial_guess),init=lambda *args:None,solve=lambda:None,
            results=N(info=info,x=np.zeros(1),y=np.zeros(0),z=np.zeros(1)))
        with patch.object(qp.proxsuite.proxqp.dense,"QP",return_value=fake):
            r=qp.solve([[1.]],[0.],[[1.]],[1.],[np.inf])
        self.assertFalse(r["accepted"]);self.assertIsNone(r["x"]);self.assertIsNone(r["certificate"])
    def test_14_original_gram_and_digest_are_unchanged(self):
        from hierarchical_least_squares_qp import problem
        from dynamic_qp_solver_v2 import problem_digest
        args=(np.array([[1.,2.],[2.,4.]]),np.array([3.,6.]),np.eye(2),np.array([-1.,-1.]),np.array([1.,1.]))
        before=copy.deepcopy(args);r=qp.solve(*args)
        self.assertEqual(r["problem_sha256"],problem_digest(*problem(*args)))
        for x,y in zip(args,before,strict=True):np.testing.assert_array_equal(x,y)
    def test_15_strict_stopping_and_no_relaxation(self):
        settings=qp.settings();self.assertTrue(settings["check_duality_gap"])
        self.assertFalse(settings["primal_infeasibility_solving"]);self.assertEqual(settings["max_iter"],20000)
        r=qp.solve([[1.]],[0.],[[1.]],[-1.],[1.]);self.assertEqual(r["initial_guess"],"NO_INITIAL_GUESS")
    def test_16_generic_backend_and_nonfinite_certificate(self):
        from pathlib import Path
        self.assertEqual(Path(qp.proxsuite.__file__).name,"proxsuite_pywrap.cp311-win_amd64.pyd")
        with self.assertRaises(ValueError):qp.certificate([[1.]],[0.],[[1.]],[-1.],[1.],[float("nan")],[0.])

if __name__=="__main__":unittest.main()
