"""Reject lost assertions, crossed identities and invented launch authority."""
import copy
import unittest
import audit_hierarchical_gate_coverage as a

class CoverageControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        p=a.ROOT.parent/"SporeSpore_Evidence"/a.ATTEMPT
        cls.r=a.read(p/"receipt.json");cls.d=a.read(p/"declaration.json");cls.c=a.task.declaration()
        cls.log=(p/(a.FAILED_GATE+"-gate")/"stderr.log").read_text(encoding="utf-8")
    def test_01_exact_contract_and_full_module_parity(self):
        self.assertEqual(a.declaration(),a.expected_contract())
        self.assertEqual(sum(x["legacy_controls"] for x in a.coverage()),51)
        self.assertEqual(sum(x["active_controls"] for x in a.coverage()),53)
    def test_02_changed_removed_or_weakened_assertion_is_refused(self):
        pair=a.PAIRS[2];old=(a.HERE/(pair[1]+".py")).read_text(encoding="utf-8")
        new=(a.HERE/(pair[3]+".py")).read_text(encoding="utf-8")
        for changed in (new.replace("self.assertEqual(d,changed)","self.assertTrue(True)"),
            new.replace("self.assertEqual(d,changed)","self.assertAlmostEqual(d,changed)"),
            new.replace("test_05_current_measured_load_is_unused","removed_05"),
            new.replace("12345.","54321.")):
            self.assertNotEqual(changed,new)
            with self.subTest(changed=changed!=new),self.assertRaises(ValueError):a.coverage_pair(old,changed,pair)
    def test_03_changed_import_fixture_or_extra_control_is_refused(self):
        pair=a.PAIRS[0];old=(a.HERE/(pair[1]+".py")).read_text(encoding="utf-8")
        new=(a.HERE/(pair[3]+".py")).read_text(encoding="utf-8")
        for changed in (new.replace("generic_proximal_qp_solver","proximal_qp_solver"),
            new.replace("atol=2e-7","atol=2e-6"),new.replace("test_15_","removed_15_"),
            new.replace("class QPControls","class ChangedControls")):
            with self.assertRaises(ValueError):a.coverage_pair(old,changed,pair)
    def test_04_original_owner_and_failure(self):
        a.validate_owner(self.r,self.d,self.c);a.validate_failure_log(self.log)
    def test_05_promotion_and_world_or_gate_population_is_refused(self):
        for key,value in [(k,True) for k in (*a.task.FLAGS,"ok","physical_started","component_only","physical_launch_requested")]+[
            ("constructed_cpu_worlds",1),("constructed_gpu_worlds",1),("source_commit","0"*40),
            ("source_status",[" M other.py"]),("safety_controls",{}),("planned_trials",[])]:
            r=copy.deepcopy(self.r);r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):a.validate_owner(r,self.d,self.c)
    def test_06_crossed_binding_or_erased_failure_is_refused(self):
        for key,value in (("binding",{}),("error",None),("contract",{}),("planned_worlds",dict(cpu=0,gpu=0))):
            r=copy.deepcopy(self.r);r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):a.validate_owner(r,self.d,self.c)
    def test_07_incomplete_or_promoted_failure_log_is_refused(self):
        for value in (self.log.replace("Ran 17 tests","Ran 16 tests"),
            self.log.replace("FAILED (failures=1)","OK"),self.log.replace("... FAIL","... ok"),
            self.log.replace("self.assertEqual(d,changed)","assert False"),
            self.log.replace(a.FAILED_TEST,"test_other")):
            with self.assertRaises(ValueError):a.validate_failure_log(value)
    def test_08_missing_duplicate_or_changed_artifacts_are_refused(self):
        original=self.r["artifacts"]
        for mutate in (lambda x:x.pop(),lambda x:x.append(x[0]),lambda x:x[0].update(sha256="0"*64)):
            changed=copy.deepcopy(original);mutate(changed)
            with self.assertRaises(ValueError):a.verify_population(original,changed)

if __name__=="__main__":unittest.main()
