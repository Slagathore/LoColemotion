"""Public integration declaration and component authority boundaries."""
import copy,unittest
from unittest.mock import patch
import audit_hierarchical_public_v8 as a

class PublicAuditControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=a.read(a.PARENT_RESULT);folder=a.EVIDENCE/cls.result["attempt_id"]
        cls.report=a.read(folder/"audit.json");cls.receipt=a.read(folder/"receipt.json")
        cls.declared=a.read(folder/"declaration.json");cls.contract=a.parent.declaration()
    def verify(self,result):
        a.validate_parent_scope(result,self.report,self.receipt,self.declared,self.contract)
    def test_01_declared_population(self):
        c=a.declaration();self.assertEqual(c,a.expected_contract());self.assertEqual(a.CONTROLS,295)
        self.assertEqual(sum(x["commands"]*2 for x in a.cases()),322)
    def test_02_verified_component_scope(self):self.verify(self.result)
    def test_03_authority_promotions_refused(self):
        for key in a.parent.DENIALS:
            r=dict(self.result);r[key]=True
            with self.subTest(key=key),self.assertRaises(ValueError):self.verify(r)
    def test_04_population_corruption_refused(self):
        for key,value in (("states",218),("accepted_states",215),("previous_accepted_outputs_preserved",213),
                ("newly_accepted_states",3),("controls_passed",211),("complete_reader_invocations",1),("worlds_opened",1)):
            r=dict(self.result);r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):self.verify(r)
    def test_05_schema_scope_or_source_crossing_refused(self):
        for key,value in (("schema_version","crossed"),("status","partial"),("ledger_scope",{}),("source_commit","0"*40)):
            r=dict(self.result);r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):self.verify(r)
    def test_06_incomplete_component_refused(self):
        for key in ("component_accepted","readers_byte_identical"):
            r=dict(self.result);r[key]=False
            with self.subTest(key=key),self.assertRaises(ValueError):self.verify(r)
    def test_07_contract_cannot_change_scientific_guards(self):
        c=a.read(a.CONTRACT);c["parameters"]["hierarchy"]["alternate"]["primary_refinement"]["primary_feasibility_absolute_guard"]=1e-6
        original=a.read
        with patch.object(a,"read",side_effect=lambda p:c if p==a.CONTRACT else original(p)):
            with self.assertRaises(ValueError):a.declaration()
    def test_08_contract_cannot_shorten_replay_or_launch_worlds(self):
        original=a.read
        for mutate in (lambda c:c["input_cases"][0].__setitem__("commands",98),
                lambda c:c.__setitem__("native_successor_launch_authorized",True)):
            c=copy.deepcopy(original(a.CONTRACT));mutate(c)
            with patch.object(a,"read",side_effect=lambda p:c if p==a.CONTRACT else original(p)):
                with self.assertRaises(ValueError):a.declaration()

if __name__=="__main__":unittest.main()
