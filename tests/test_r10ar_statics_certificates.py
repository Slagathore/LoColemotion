"""Adversarial checks of R10AR certificates, without retained or physical input."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10ar_multicontact_statics as model


class CertificateControls(unittest.TestCase):
    def problem(self):
        n=model.np
        return model.lp(n.array([1.]),n.array([[1.]]),n.array([1.]),
            n.array([[1.]]),n.array([3.]),[(0.,2.)])

    def altered(self,change):
        original=model.linprog
        def solve(*args,**kwargs):
            result=original(*args,**kwargs)
            change(result)
            return result
        return patch.object(model,'linprog',side_effect=solve)

    def test_success_flag_does_not_admit_wrong_primal_solution(self):
        with self.altered(lambda r:r.x.__setitem__(0,r.x[0]+.1)):
            with self.assertRaises(AssertionError):self.problem()

    def test_success_flag_does_not_admit_wrong_dual_multiplier(self):
        with self.altered(lambda r:r.eqlin.marginals.__setitem__(0,r.eqlin.marginals[0]+.25)):
            with self.assertRaises(AssertionError):self.problem()

    def test_failed_optimizer_status_is_not_model_infeasibility(self):
        with self.altered(lambda r:setattr(r,'success',False)):
            with self.assertRaises(AssertionError):self.problem()

    def test_objective_is_recomputed_from_solution(self):
        with self.altered(lambda r:setattr(r,'fun',-999.)):
            x,receipt=self.problem()
        self.assertEqual(x.tolist(),[1.])
        self.assertEqual(receipt['primal_objective'],1.)
        self.assertEqual(receipt['dual_objective'],1.)
        self.assertEqual(receipt['objective_gap'],0.)


if __name__=='__main__':unittest.main()
