"""Retained allocation comparisons include the provider's five derived fields."""
import copy
import unittest
import numpy as np
import audit_refined_fallback_component_v2 as audit
import generic_proximal_contact_component as original
import test_contact_priority_component as fixtures
from causal_force_policy import plain

class NativeFieldsControls(unittest.TestCase):
    def setUp(self):
        f=fixtures.PriorityControls();f.setUp();support,active=f.contact()
        self.base=f.build("combined",items=[f.item,support],active=[active])
        self.allocation=plain(original.compute(self.base));self.assertTrue(self.allocation["accepted"])
    def test_01_complete_provider_fields(self):
        value=audit.native_allocation(self.allocation,self.base)
        self.assertEqual(set(value)-set(self.allocation),{"requested_torque","forces","acceleration",
            "transferred_dynamics_residual","dynamic_feasibility_established"})
        np.testing.assert_array_equal(value["forces"],self.allocation["prediction"]["predicted_forces"])
        np.testing.assert_array_equal(value["acceleration"],self.allocation["prediction"]["predicted_steps"][0]["acceleration"])
    def test_02_original_computation_not_mutated(self):
        before=copy.deepcopy(self.allocation);audit.native_allocation(self.allocation,self.base)
        self.assertEqual(before,self.allocation)
    def test_03_refusal_has_no_provider_transfer(self):
        value=dict(accepted=False,status="bounded hierarchical search refused",attempts=[])
        self.assertEqual(audit.native_allocation(value,self.base),value)
    def test_04_implicit_transfer_and_authority(self):
        value=audit.native_allocation(self.allocation,self.base)
        self.assertLessEqual(np.max(np.abs(value["transferred_dynamics_residual"])),4e-6)
        self.assertFalse(value["dynamic_feasibility_established"])
        expected=audit.mechanics.motor_torque(np.asarray(self.allocation["prediction"]["target"]),
            self.base["state_velocity"][6:],self.base["gains"],self.base["force_ranges"])
        np.testing.assert_array_equal(value["requested_torque"],expected)
if __name__=="__main__":unittest.main()
