"""Empty contact arrays must preserve the finite no-support state."""
import copy,unittest
from dynamic_control_empty_force_failure import fixture,verify_failure
from audit_dynamic_control_component_v4 import verify_row

class EmptyForceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.args=fixture()
    def test_01_original_reader_refusal(self):
        self.assertTrue(verify_failure()["refusal_reproduced"])
    def test_02_empty_force_state_verifies(self):
        self.assertEqual(verify_row(*self.args)["active_contacts"],0)
    def test_03_nonempty_forces_for_no_contact_refused(self):
        args=list(self.args);args[0]=copy.deepcopy(args[0])
        args[0]["force_reference"]["decision"]["allocation"]["forces"]=[[0.,1.,0.]]
        with self.assertRaises(ValueError):verify_row(*args)

if __name__=="__main__":unittest.main()
