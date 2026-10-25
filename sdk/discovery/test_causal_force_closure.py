"""Refusal controls for finite force-recovery closure; no new worlds."""
import copy
import unittest
import audit_causal_force_closure as a


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record=a.read(a.CLOSURE)
        cls.attempt=a.ROOT.parent/"SporeSpore_Evidence"/cls.record["attempt_id"]
        cls.receipt=a.read(cls.attempt/"receipt.json")
        cls.declared=a.read(cls.attempt/"declaration.json")
        cls.original=a.read(cls.attempt/"audit.json")

    def test_original_header_links_and_owner(self):
        self.assertEqual(a.header(self.record,a.ROOT.parent/"SporeSpore_Evidence"),self.attempt.resolve())
        a.validate_owner(self.receipt,self.declared,self.record,a.task.declaration())

    def test_every_authority_escalation_is_refused(self):
        for key in a.DENIALS:
            r=copy.deepcopy(self.record);r[key]=True
            with self.assertRaises(ValueError):a.validate_header(r)

    def test_crossed_source_contract_or_reader_is_refused(self):
        for key in ("source_commit","contract_sha256","component_result_sha256"):
            r=copy.deepcopy(self.record);r[key]="0"*64
            with self.assertRaises(ValueError):a.validate_header(r)
        r=copy.deepcopy(self.record);r["closure_source_bindings"][a.SOURCES[0]]="0"*64
        with self.assertRaises(ValueError):a.validate_header(r)

    def test_incomplete_denominators_or_new_reserved_scope_are_refused(self):
        for key in ("complete_safety_controls","closure_controls_required","source_binding_count",
            "runtime_binding_count","reserved_starts_opened","training_worlds_opened"):
            r=copy.deepcopy(self.record);r[key]+=1
            with self.assertRaises(ValueError):a.validate_header(r)

    def test_attempt_cannot_escape_evidence_root(self):
        for identity in ("../escape","sdk2-causal-force-native-x/../escape","sdk2-causal-force-native-x\\..\\escape"):
            r=copy.deepcopy(self.record);r["attempt_id"]=identity
            with self.assertRaises(ValueError):a.validate_header(r)

    def test_incomplete_or_dirty_owner_cannot_be_closed(self):
        for key,value in (("ok",False),("zero_world_gate_passed",False),("component_only",True),
            ("constructed_cpu_worlds",3),("source_status",[" M unexpected.py"]),("source_runtime_unchanged",False)):
            r=copy.deepcopy(self.receipt);r[key]=value
            with self.assertRaises(ValueError):a.validate_owner(r,self.declared,self.record,a.task.declaration())

    def test_failed_outcome_cannot_be_erased_or_retimed(self):
        for change in (None,dict(internal_step=600,time_s=1.,failure_codes=["tilt"])):
            value=copy.deepcopy(self.original)
            value["trials"][1]["diagnostic_metrics"]["first_physical_violation"]=change
            with self.assertRaises(ValueError):a.compare_reconstruction(self.original,value)

    def test_missing_duplicate_or_changed_artifact_is_refused(self):
        expected=[dict(path="a",sha256="a",byte_length=1),dict(path="b",sha256="b",byte_length=2)]
        for observed in (expected[:1],[expected[0],expected[0]],[expected[0],dict(expected[1],sha256="changed")]):
            with self.assertRaises(ValueError):a.verify_population(expected,observed)


if __name__=="__main__":unittest.main()
