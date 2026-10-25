"""Refuse promotion, population loss and displaced terminal failures."""
import copy
import unittest
import audit_dynamic_control_native_failure as a
from dynamic_control_native_failure_trial import validate_terminal,TERMINAL

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
        r=copy.deepcopy(self.owner["safety_controls"]);r["dynamic-route"]-=1
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
    def test_10_exact_terminal(self):validate_terminal(self.terminal(),316)
    def test_11_displaced_terminal(self):
        with self.assertRaises(ValueError):validate_terminal(self.terminal(),315)
    def test_12_erased_or_applied_terminal(self):
        for key,value in (("fallback_reason","none"),("adaptation_applied",True)):
            row=self.terminal();row["resolution"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_terminal(row,316)


    def test_13_missing_changed_or_duplicate_artifacts(self):
        original=self.owner["artifacts"]
        for mutate in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v[0].__setitem__("sha256","0"*64)):
            value=copy.deepcopy(original);mutate(value)
            with self.assertRaises(ValueError):a.verify_population(original,value)
    def test_14_original_freeze_crossed(self):self.reject_owner("source_commit","0"*40)
    def test_15_binding_population_crossed(self):
        binding=copy.deepcopy(self.owner["binding"]);binding["runtime"].pop(next(iter(binding["runtime"])))
        self.reject_owner("binding",binding)
    def test_16_inaccurate_or_accepted_solver_cannot_be_refusal(self):
        from dynamic_control_native_failure_trial import validate_solver_failure
        from dynamic_qp_solver_v2 import settings
        value=dict(status="maximum iterations reached",status_value=7,iterations=20000,
            settings=settings(),accepted=False,certificate=None,x=None,y=None,
            isolated_refusal_reproduced=True,problem_sha256="a"*64)
        validate_solver_failure(value)
        for key,bad in (("status_value",2),("accepted",True),("iterations",19999),("isolated_refusal_reproduced",False)):
            changed=dict(value);changed[key]=bad
            with self.subTest(key=key),self.assertRaises(ValueError):validate_solver_failure(changed)

if __name__=="__main__":unittest.main()
