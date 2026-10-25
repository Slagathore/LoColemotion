"""Refuse promotion, population loss and displaced terminal failures."""
import copy
import unittest
import audit_hierarchical_native_failure_v4 as a
from hierarchical_native_failure_trial_v4 import validate_terminal,TERMINAL

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
    def test_10_exact_terminal(self):validate_terminal(self.terminal(),119)
    def test_11_displaced_terminal(self):
        with self.assertRaises(ValueError):validate_terminal(self.terminal(),97)
    def test_12_erased_or_applied_terminal(self):
        for key,value in (("fallback_reason","none"),("adaptation_applied",True)):
            row=self.terminal();row["resolution"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_terminal(row,119)


    def test_13_missing_changed_or_duplicate_artifacts(self):
        original=self.owner["artifacts"]
        for mutate in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v[0].__setitem__("sha256","0"*64)):
            value=copy.deepcopy(original);mutate(value)
            with self.assertRaises(ValueError):a.verify_population(original,value)
    def test_14_original_freeze_crossed(self):self.reject_owner("source_commit","0"*40)
    def test_15_binding_population_crossed(self):
        binding=copy.deepcopy(self.owner["binding"]);binding["runtime"].pop(next(iter(binding["runtime"])))
        self.reject_owner("binding",binding)


    def profile(self):
        return a.read(a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT/"physical/hierarchy_hold_left_075_train_001/force-profile.json")

    def test_16_domain_refusal_cannot_be_recast_as_solver_failure(self):
        for key,value in (("status","bounded hierarchical search refused"),("total_qp_solves",1),
            ("solver_route","scaled_primary_refused"),("patterns_tried",1),("accepted",True)):
            row=self.terminal();row["force_reference"]["decision"]["allocation"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_terminal(row,119)

    def test_17_no_fallback_no_prediction_and_exact_boolean_flags(self):
        for key,value in (("fallback_attempted",True),("scaled_primary_fallback_attempted",1),
            ("primary_backend_fallback_attempted",True),("prediction",{}),("selected",{}),("attempts",[{}])):
            row=self.terminal();row["force_reference"]["decision"]["allocation"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_terminal(row,119)

    def test_18_native_limit_witness_is_exact(self):
        from hierarchical_native_failure_trial_v4 import joint_limit_witness
        v=joint_limit_witness(self.terminal(),self.profile())
        self.assertEqual(v["outside_joint_limits"][0]["joint_id"],"rear_left_hip")
        self.assertEqual(v["outside_joint_limits"][0]["upper_limit_rad"],.72)
        self.assertEqual(v["outside_joint_limits"][0]["position_rad"],.7202513120289704)
        self.assertFalse(v["solver_infeasibility_established"])

    def test_19_nonfinite_or_crossed_joint_witness_refused(self):
        from hierarchical_native_failure_trial_v4 import joint_limit_witness
        for mutate in (lambda r:r["request"]["state"]["ordered_joint_observations"][4].update(position_rad=float("nan")),
            lambda r:r["request"]["state"]["ordered_joint_observations"][4].update(joint_id="crossed"),
            lambda r:r["native_observation"]["qpos"].__setitem__(11,.71)):
            r=self.terminal();mutate(r)
            with self.assertRaises(ValueError):joint_limit_witness(r,self.profile())

    def test_20_exact_boundary_has_no_added_tolerance(self):
        from hierarchical_native_failure_trial_v4 import joint_limit_witness
        for q,outside in ((.72,False),(.7200000000000001,True),(-.72,False),(-.7200000000000001,True)):
            r=self.terminal();r["request"]["state"]["ordered_joint_observations"][4]["position_rad"]=q
            r["native_observation"]["qpos"][11]=q
            self.assertEqual(bool(joint_limit_witness(r,self.profile())["outside_joint_limits"]),outside)

    def test_21_complete_causal_extension(self):
        p=a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT/"physical";v=a.verify_extension(p)
        self.assertEqual(v["prior_native_steps_bitwise_identical"],490)
        self.assertEqual(v["additional_native_steps"],105)
        self.assertEqual(v["additional_applied_commands"],21);self.assertFalse(v["recovery_benefit_established"])

    def gap_inputs(self):
        p=a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT/"physical/hierarchy_hold_left_075_train_001"
        return list(a.read_jsonl(p/"controller.jsonl")),list(a.read_jsonl(p/"trace.jsonl")),self.profile()

    def test_22_complete_prediction_gap_and_no_robustness_claim(self):
        from hierarchical_native_failure_trial_v4 import prediction_gap
        v=prediction_gap(*self.gap_inputs())
        self.assertEqual(v["internal_samples"],295);self.assertEqual(v["joint_comparisons"],2360)
        last=v["last_five_steps"][-1]
        self.assertLess(last["predicted_position_rad"][4],.72)
        self.assertGreater(last["observed_position_rad"][4],.72)
        self.assertGreater(last["observed_minus_predicted_rad"][4],v["planning_margin_rad"])
        self.assertFalse(v["robust_error_bound_established"]);self.assertFalse(v["physical_joint_limit_guarantee"])

    def test_23_incomplete_or_crossed_prediction_population_refused(self):
        from hierarchical_native_failure_trial_v4 import prediction_gap
        for kind in ("trace","controls","order","prediction"):
            rows,trace,profile=self.gap_inputs()
            if kind=="trace":trace.pop()
            elif kind=="controls":rows.pop()
            elif kind=="order":trace[-1]["step"]-=1
            else:rows[-2]["force_reference"]["decision"]["allocation"]["prediction"]["predicted_steps"].pop()
            with self.subTest(kind=kind),self.assertRaises(ValueError):prediction_gap(rows,trace,profile)

    def test_24_terminal_constructor_guards_are_live(self):
        from hierarchical_native_failure_trial_v4 import capture_failure
        import osqp
        import generic_proximal_qp_solver as proximal
        with capture_failure([],self.terminal(),self.profile()):
            with self.assertRaises(AssertionError):osqp.OSQP()
            with self.assertRaises(AssertionError):proximal.proxsuite.proxqp.dense.QP(1,0,0)

if __name__=="__main__":unittest.main()
