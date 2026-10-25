"""Refuse promotion, population loss and displaced terminal failures."""
import copy
import unittest
import audit_hierarchical_native_failure_v3 as a
from hierarchical_native_failure_trial_v3 import validate_terminal,TERMINAL

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
        r=copy.deepcopy(self.owner["safety_controls"]);r["hierarchy-route"]-=1
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
        p=a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT/"physical/hierarchy_hold_left_075_train_001/controller.jsonl"
        return list(a.read_jsonl(p))[-1]
    def test_10_exact_terminal(self):validate_terminal(self.terminal(),98)
    def test_11_displaced_terminal(self):
        with self.assertRaises(ValueError):validate_terminal(self.terminal(),97)
    def test_12_erased_or_applied_terminal(self):
        for key,value in (("fallback_reason","none"),("adaptation_applied",True)):
            row=self.terminal();row["resolution"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_terminal(row,98)


    def test_13_missing_changed_or_duplicate_artifacts(self):
        original=self.owner["artifacts"]
        for mutate in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v[0].__setitem__("sha256","0"*64)):
            value=copy.deepcopy(original);mutate(value)
            with self.assertRaises(ValueError):a.verify_population(original,value)
    def test_14_original_freeze_crossed(self):self.reject_owner("source_commit","0"*40)
    def test_15_binding_population_crossed(self):
        binding=copy.deepcopy(self.owner["binding"]);binding["runtime"].pop(next(iter(binding["runtime"])))
        self.reject_owner("binding",binding)

    def test_16_primary_status_acceptance_and_work_are_exact(self):
        from hierarchical_native_failure_trial_v3 import validate_solver_failure
        value=dict(self.terminal()["force_reference"]["decision"]["allocation"]["original_refusal"]["attempts"][0]["result"]["reduced"],
            isolated_refusal_reproduced=True)
        validate_solver_failure(value)
        for key,bad in (("status","solved"),("accepted",True),("iterations",19999),("polishing_status",1),
            ("isolated_refusal_reproduced",False),("certificate",{}),("backend","crossed")):
            changed=dict(value);changed[key]=bad
            with self.subTest(key=key),self.assertRaises(ValueError):validate_solver_failure(changed)

    def witness_problem(self):
        return dict(P=[[1.]],q=[0.],A=[[1.],[1.],[1.]],
            lower=[1.,None,0.],upper=[1.,2.,None],
            null_lower_means_negative_infinity=True,null_upper_means_positive_infinity=True)

    def test_17_witness_distinguishes_equality_and_unbounded_inequalities(self):
        from hierarchical_native_failure_trial_v3 import constraint_witness
        result=constraint_witness(self.witness_problem(),[1.])
        self.assertEqual(result["maximum_bound_violation"],0.)
        self.assertFalse(result["feasibility_established"]);self.assertFalse(result["solver_acceptance_granted"])
        result=constraint_witness(self.witness_problem(),[3.])
        self.assertEqual(result["maximum_equality_error"],2.)
        self.assertEqual(result["maximum_inequality_violation"],1.)
        self.assertEqual(result["violated_row_indices"],[0,1])

    def test_18_nonfinite_or_misencoded_witness_refused(self):
        from hierarchical_native_failure_trial_v3 import constraint_witness
        for x in ([float("nan")],[],[float("inf")]):
            with self.assertRaises(ValueError):constraint_witness(self.witness_problem(),x)
        changed=self.witness_problem();changed["null_lower_means_negative_infinity"]=False
        with self.assertRaises(ValueError):constraint_witness(changed,[1.])

    def test_19_terminal_routes_and_no_refinement_bypass(self):
        for mutate in (
            lambda v:v.__setitem__("solver_route","original_generic"),
            lambda v:v.__setitem__("total_qp_solves",3),
            lambda v:v.__setitem__("fallback_attempted",False),
            lambda v:v["original_refusal"].__setitem__("accepted",True),
            lambda v:v["attempts"][0]["result"]["primary_refinement"].__setitem__("accepted",True)):
            row=self.terminal();mutate(row["force_reference"]["decision"]["allocation"])
            with self.assertRaises(ValueError):validate_terminal(row,98)

    def test_20_prior_native_prefix_and_actual_seven_command_extension(self):
        p=a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT/"physical"
        value=a.verify_extension(p)
        self.assertEqual(value["prior_native_steps_bitwise_identical"],455)
        self.assertEqual(value["additional_native_steps"],35)
        self.assertFalse(value["recovery_benefit_established"])



    def test_21_seed_guard_cannot_be_bypassed(self):
        row=self.terminal()
        row["force_reference"]["decision"]["allocation"]["attempts"][0]["result"]["initial_primary"]["full_certificate"]["maximum_bound_violation"]=0.
        with self.assertRaises(ValueError):validate_terminal(row,98)
    def test_22_new_route_flag_cannot_be_erased(self):
        row=self.terminal();row["force_reference"]["decision"]["allocation"]["primary_backend_fallback_attempted"]=False
        with self.assertRaises(ValueError):validate_terminal(row,98)
    def test_23_previous_refusal_must_join_original(self):
        row=self.terminal();row["force_reference"]["decision"]["allocation"]["previous_refusal"]["original_refusal"]["patterns_tried"]=2
        with self.assertRaises(ValueError):validate_terminal(row,98)
    def test_24_refinement_must_have_been_performed_and_refused(self):
        for key,value in (("performed",False),("accepted",True),("status","refined primary certified")):
            row=self.terminal();row["force_reference"]["decision"]["allocation"]["attempts"][0]["result"]["primary_refinement"][key]=value
            with self.assertRaises(ValueError):validate_terminal(row,98)

if __name__=="__main__":unittest.main()
