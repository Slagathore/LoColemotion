"""Retained native parent scope and numerical-recovery provenance controls."""
import copy,unittest
import audit_proximal_primary_component as a

class AuditControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=a.read(a.PARENT_RESULT);p=a.EVIDENCE/cls.result["attempt_id"]
        cls.report=a.read(p/"audit.json");cls.receipt=a.read(p/"receipt.json")
        cls.contract=a.native_parent.declaration()
    def test_01_exact_declaration(self):
        self.assertEqual(a.declaration(),a.expected_contract())
        self.assertEqual(a.CONTROLS,136)
        self.assertEqual(sum(e-s for _,_,s,e in a.WINDOWS),180)
    def test_02_parent_scope(self):
        a.validate_parent_scope(self.result,self.report,self.receipt,self.contract)
    def test_03_authority_promotions_refused(self):
        for key in a.native_parent.DENIALS:
            result=dict(self.result);result[key]=True
            with self.subTest(key=key),self.assertRaises(ValueError):
                a.validate_parent_scope(result,self.report,self.receipt,self.contract)
    def test_04_population_and_success_promotions_refused(self):
        for key,value in (("retained_controller_rows",1531),("retained_internal_rows",7654),
            ("original_worlds_opened",4),("original_native_ok",True),("terminal_transferred",True),
            ("terminal_command",90),("complete_reader_invocations",1),("controls_passed",19),("worlds_opened",1)):
            result=dict(self.result);result[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                a.validate_parent_scope(result,self.report,self.receipt,self.contract)
    def test_05_crossed_schema_scope_or_freeze_refused(self):
        for key,value in (("schema_version","crossed"),("ledger_scope",{}),("original_source_commit","0"*40),
            ("original_attempt","crossed"),("original_receipt_sha256","0"*64)):
            result=dict(self.result);result[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                a.validate_parent_scope(result,self.report,self.receipt,self.contract)
    def test_06_accepted_previous_cannot_be_replaced(self):
        value=dict(primary_backend_fallback_attempted=True,previous_refusal=dict(accepted=True,
            status="bounded hierarchical search refused",total_qp_solves=4),solver_route="proximal_primary",
            total_qp_solves=6,attempts=[{},{}])
        with self.assertRaises(ValueError):a.previous_result(value)
    def test_07_preserved_result_extraction(self):
        previous=dict(accepted=True,solver_route="refined_primary",total_qp_solves=4,attempts=[{},{}])
        value=dict(previous,primary_backend_fallback_attempted=False,previous_refusal=None)
        self.assertEqual(a.previous_result(value),previous)
        value["previous_refusal"]={}
        with self.assertRaises(ValueError):a.previous_result(value)
    def test_08_domain_and_work_provenance_refused(self):
        value=dict(primary_backend_fallback_attempted=True,previous_refusal=dict(accepted=False,
            status="bounded hierarchical search refused",total_qp_solves=4),solver_route="proximal_primary",
            total_qp_solves=6,attempts=[{},{}])
        self.assertEqual(a.previous_result(value),value["previous_refusal"])
        for mutate in (lambda v:v.__setitem__("total_qp_solves",5),
            lambda v:v.__setitem__("primary_backend_fallback_attempted",1),
            lambda v:v["previous_refusal"].__setitem__("status","native joint limit already active")):
            changed=copy.deepcopy(value);mutate(changed)
            with self.assertRaises(ValueError):a.previous_result(changed)

if __name__=="__main__":unittest.main()
