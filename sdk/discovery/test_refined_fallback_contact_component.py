"""Controller recovery routing cannot replace a valid solve or bypass refusal."""
import copy
import unittest
from unittest.mock import patch
import refined_fallback_contact_component as c
import test_contact_priority_component as fixtures

def result(accepted,status="bounded hierarchical search refused",count=2):
    return dict(accepted=accepted,status=status,attempts=[dict(index=i) for i in range(count)])

class RoutingControls(unittest.TestCase):
    def test_01_certified_original_preserved(self):
        first=result(True,"certified");saved=copy.deepcopy(first)
        with patch.object(c.original,"compute",return_value=first),patch.object(c.refined,"compute",side_effect=AssertionError):
            v=c.compute({})
        self.assertEqual({k:v[k] for k in first},saved);self.assertFalse(v["fallback_attempted"]);self.assertEqual(first,saved)
    def test_02_explicit_refusal_can_recover(self):
        first=result(False);second=result(True,"certified")
        with patch.object(c.original,"compute",return_value=first),patch.object(c.refined,"compute",return_value=second):
            v=c.compute({})
        self.assertTrue(v["accepted"]);self.assertEqual(v["original_refusal"],first);self.assertEqual(v["solver_route"],"refined_primary")
    def test_03_both_refusals_retained(self):
        first=result(False);second=result(False)
        with patch.object(c.original,"compute",return_value=first),patch.object(c.refined,"compute",return_value=second):
            v=c.compute({})
        self.assertFalse(v["accepted"]);self.assertEqual(v["original_refusal"],first);self.assertEqual(v["attempts"],second["attempts"])
    def test_04_domain_refusal_not_retried(self):
        with patch.object(c.original,"compute",return_value=result(False,"outside native joint range",0)),patch.object(c.refined,"compute",side_effect=AssertionError):
            v=c.compute({})
        self.assertFalse(v["accepted"]);self.assertFalse(v["fallback_attempted"])
    def test_05_unexpected_exception_not_hidden(self):
        with patch.object(c.original,"compute",side_effect=ValueError("unexpected")),patch.object(c.refined,"compute",side_effect=AssertionError):
            with self.assertRaisesRegex(ValueError,"unexpected"):c.compute({})
    def test_06_complete_bounded_solve_count(self):
        with patch.object(c.original,"compute",return_value=result(False,count=16)),patch.object(c.refined,"compute",return_value=result(False,count=16)):
            v=c.compute({})
        self.assertEqual(v["total_qp_solves"],32);self.assertEqual(c.parameters()["maximum_total_qp_solves"],32)
    def test_07_fallback_exception_not_hidden(self):
        with patch.object(c.original,"compute",return_value=result(False)),patch.object(c.refined,"compute",side_effect=ValueError("unexpected")):
            with self.assertRaisesRegex(ValueError,"unexpected"):c.compute({})
    def test_08_real_certified_solution_unchanged(self):
        f=fixtures.PriorityControls();f.setUp();support,active=f.contact()
        base=f.build("combined",items=[f.item,support],active=[active])
        first=c.original.compute(base);v=c.compute(base)
        self.assertTrue(first["accepted"]);self.assertFalse(v["fallback_attempted"])
        import numpy as np
        np.testing.assert_array_equal(v["selected"]["full_x"],first["selected"]["full_x"])
        self.assertEqual(v["selected"]["full_certificate"],first["selected"]["full_certificate"])
if __name__=="__main__":unittest.main()
