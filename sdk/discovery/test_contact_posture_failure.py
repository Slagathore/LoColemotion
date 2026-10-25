"""Refuse promotion, population loss and displaced terminal failures."""
import copy
import unittest
import audit_contact_posture_failure as a
from contact_posture_failure_trial import validate_terminal,TERMINAL

class FailureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=a.task.declaration();p=a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT
        cls.owner=a.read(p/"receipt.json");cls.declared=a.read(p/"declaration.json")
        cls.worker=a.read(p/"physical/worker-result.json")
    def reject_owner(self,key,value):
        r=copy.deepcopy(self.owner);r[key]=value
        with self.assertRaises(ValueError):a.validate_owner(r,self.declared,self.c)
    def test_01_exact_contract(self):self.assertEqual(a.declaration(),a.expected_contract())
    def test_02_original_owner(self):a.validate_owner(self.owner,self.declared,self.c)
    def test_03_success_promotion(self):self.reject_owner("ok",True)
    def test_04_world_population(self):
        for n in (0,1,3,4):
            with self.subTest(n=n):self.reject_owner("constructed_cpu_worlds",n)
    def test_05_gate_population(self):
        r=copy.deepcopy(self.owner["safety_controls"]);r["posture-route"]-=1
        self.reject_owner("safety_controls",r)
    def test_06_authority_promotion(self):
        for key in a.FLAGS:
            with self.subTest(key=key):self.reject_owner(key,True)
    def test_07_original_worker(self):a.validate_worker(self.worker,self.c)
    def test_08_invented_completed_trials(self):
        w=copy.deepcopy(self.worker);w["trials"]*=2
        with self.assertRaises(ValueError):a.validate_worker(w,self.c)
    def test_09_erased_worker_failure(self):
        w=copy.deepcopy(self.worker);w["error"]=None
        with self.assertRaises(ValueError):a.validate_worker(w,self.c)
    def terminal(self):
        return dict(force_reference=dict(terminal_error=TERMINAL,provider_error=TERMINAL,decision=None),
            resolution=dict(fallback_reason="provider_absent",adaptation_applied=False))
    def test_10_exact_terminal(self):validate_terminal(self.terminal(),1230)
    def test_11_displaced_terminal(self):
        with self.assertRaises(ValueError):validate_terminal(self.terminal(),1229)
    def test_12_erased_or_applied_terminal(self):
        for key,value in (("fallback_reason","none"),("adaptation_applied",True)):
            row=self.terminal();row["resolution"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_terminal(row,1230)

if __name__=="__main__":unittest.main()
