"""Accepted predecessor routes survive unchanged; extra work stays bounded."""
import copy,unittest
from unittest.mock import patch
import scaled_primary_fallback_component as c
import test_contact_priority_component as fixtures

def previous(accepted=False,status="bounded hierarchical search refused",count=4):
    return dict(accepted=accepted,status=status,attempts=[{}]*2,total_qp_solves=count,
        solver_route="refined_primary" if accepted else "refined_primary_refused",original_refusal={"accepted":False},previous_refusal={"accepted":False})

class RoutingControls(unittest.TestCase):
    def test_01_certified_previous_is_exact(self):
        first=previous(True);saved=copy.deepcopy(first)
        with patch.object(c.previous,"compute",return_value=first),patch.object(c.alternate,"compute",side_effect=AssertionError):
            r=c.compute({})
        self.assertEqual({k:r[k] for k in first},saved);self.assertEqual(first,saved)
        self.assertFalse(r["scaled_primary_fallback_attempted"])
    def test_02_explicit_refusal_can_recover(self):
        first=previous();second=dict(accepted=True,attempts=[{},{}],total_qp_solves=2)
        with patch.object(c.previous,"compute",return_value=first),patch.object(c.alternate,"compute",return_value=second):r=c.compute({})
        self.assertTrue(r["accepted"]);self.assertEqual(r["scaling_previous_refusal"],first)
        self.assertEqual(r["solver_route"],"scaled_primary");self.assertEqual(r["total_qp_solves"],6)
    def test_03_all_refusals_retained(self):
        first=previous();second=dict(accepted=False,attempts=[{},{}],total_qp_solves=2)
        with patch.object(c.previous,"compute",return_value=first),patch.object(c.alternate,"compute",return_value=second):r=c.compute({})
        self.assertFalse(r["accepted"]);self.assertEqual(r["scaling_previous_refusal"],first)
        self.assertEqual(r["solver_route"],"scaled_primary_refused")
    def test_04_domain_refusal_is_not_retried(self):
        with patch.object(c.previous,"compute",return_value=previous(status="native joint limit already active",count=0)),patch.object(c.alternate,"compute",side_effect=AssertionError):r=c.compute({})
        self.assertFalse(r["accepted"]);self.assertFalse(r["scaled_primary_fallback_attempted"])
    def test_05_previous_exception_is_not_hidden(self):
        with patch.object(c.previous,"compute",side_effect=ValueError("unexpected")),patch.object(c.alternate,"compute",side_effect=AssertionError):
            with self.assertRaisesRegex(ValueError,"unexpected"):c.compute({})
    def test_06_alternate_exception_is_not_hidden(self):
        with patch.object(c.previous,"compute",return_value=previous()),patch.object(c.alternate,"compute",side_effect=ValueError("unexpected")):
            with self.assertRaisesRegex(ValueError,"unexpected"):c.compute({})
    def test_07_total_work_bound_is_enforced(self):
        for count in (64,65):
            with patch.object(c.previous,"compute",return_value=previous(count=48)),patch.object(c.alternate,"compute",return_value=dict(accepted=False,attempts=[{},{}],total_qp_solves=count)):
                if count==64:self.assertEqual(c.compute({})["total_qp_solves"],112)
                else:
                    with self.assertRaises(ValueError):c.compute({})
    def test_08_real_predecessor_is_bitwise_preserved(self):
        from audit_gpu_batch_execution import same_bits
        from causal_force_policy import plain
        f=fixtures.PriorityControls();f.setUp();support,active=f.contact()
        base=f.build("combined",items=[f.item,support],active=[active]);first=plain(c.previous.compute(base));r=plain(c.compute(base))
        self.assertTrue(first["accepted"]);self.assertTrue(same_bits(first,{k:r[k] for k in first}))

if __name__=="__main__":unittest.main()
