"""Accepted predecessor routes survive unchanged; extra work stays bounded."""
import copy,unittest
from unittest.mock import patch
import proximal_primary_fallback_component_v2 as c
import test_contact_priority_component as fixtures

def previous(accepted=False,status="bounded hierarchical search refused",count=4):
    return dict(accepted=accepted,status=status,attempts=[{}]*2,total_qp_solves=count,
        solver_route="refined_primary" if accepted else "refined_primary_refused",original_refusal={"accepted":False})

class RoutingControls(unittest.TestCase):
    def test_01_certified_previous_is_exact(self):
        first=previous(True);saved=copy.deepcopy(first)
        with patch.object(c.previous,"compute",return_value=first),patch.object(c.alternate,"compute",side_effect=AssertionError):
            r=c.compute({})
        self.assertEqual({k:r[k] for k in first},saved);self.assertEqual(first,saved)
        self.assertFalse(r["primary_backend_fallback_attempted"])
    def test_02_explicit_refusal_can_recover(self):
        first=previous();second=dict(accepted=True,attempts=[{},{}])
        with patch.object(c.previous,"compute",return_value=first),patch.object(c.alternate,"compute",return_value=second):r=c.compute({})
        self.assertTrue(r["accepted"]);self.assertEqual(r["previous_refusal"],first)
        self.assertEqual(r["solver_route"],"proximal_primary");self.assertEqual(r["total_qp_solves"],6)
    def test_03_all_refusals_retained(self):
        first=previous();second=dict(accepted=False,attempts=[{},{}])
        with patch.object(c.previous,"compute",return_value=first),patch.object(c.alternate,"compute",return_value=second):r=c.compute({})
        self.assertFalse(r["accepted"]);self.assertEqual(r["previous_refusal"],first)
        self.assertEqual(r["solver_route"],"proximal_primary_refused")
    def test_04_domain_refusal_is_not_retried(self):
        with patch.object(c.previous,"compute",return_value=previous(status="native joint limit already active",count=0)),patch.object(c.alternate,"compute",side_effect=AssertionError):r=c.compute({})
        self.assertFalse(r["accepted"]);self.assertFalse(r["primary_backend_fallback_attempted"])
    def test_05_previous_exception_is_not_hidden(self):
        with patch.object(c.previous,"compute",side_effect=ValueError("unexpected")),patch.object(c.alternate,"compute",side_effect=AssertionError):
            with self.assertRaisesRegex(ValueError,"unexpected"):c.compute({})
    def test_06_alternate_exception_is_not_hidden(self):
        with patch.object(c.previous,"compute",return_value=previous()),patch.object(c.alternate,"compute",side_effect=ValueError("unexpected")):
            with self.assertRaisesRegex(ValueError,"unexpected"):c.compute({})
    def test_07_total_work_bound_is_enforced(self):
        for count in (16,17):
            with patch.object(c.previous,"compute",return_value=previous(count=32)),patch.object(c.alternate,"compute",return_value=dict(accepted=False,attempts=[{}]*count)):
                if count==16:self.assertEqual(c.compute({})["total_qp_solves"],48)
                else:
                    with self.assertRaises(ValueError):c.compute({})
    def test_08_real_predecessor_is_bitwise_preserved(self):
        from audit_gpu_batch_execution import same_bits
        from causal_force_policy import plain
        f=fixtures.PriorityControls();f.setUp();support,active=f.contact()
        base=f.build("combined",items=[f.item,support],active=[active]);first=plain(c.previous.compute(base));r=plain(c.compute(base))
        self.assertTrue(first["accepted"]);self.assertTrue(same_bits(first,{k:r[k] for k in first}))

if __name__=="__main__":unittest.main()
