"""Corruption controls for the independent public route reader."""
import copy
import os
from pathlib import Path
import unittest
from unittest.mock import patch
from contact_force_observer_task import bridge
from audit_gpu_batch_execution import read_jsonl
from audit_predictive_numeric_backend import DLL,DLL_SHA,read
from test_held_contact_rollout import FOLDER
from prepare_predictive_model_mujoco import prepare
from predictive_hold_policy_v1 import make_profile
from predictive_hold_control_v1 import PredictiveHoldController
from predictive_public_row_audit_v1 import verify_row
from predictive_command_selection_v2 import PredictiveSelector
from hold_horizon_task import controller_contract,frozen_model,declaration


class PredictiveReaderControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.original=list(read_jsonl(FOLDER/"controller.jsonl"))
        n=read(FOLDER/"force-profile.json");xml=(FOLDER/"model.xml").read_text()
        cls.profile=make_profile(n,prepare(n,xml),DLL_SHA);cls.reference=PredictiveSelector(n,xml)
        model=frozen_model(cls.core);host=PredictiveHoldController(cls.core,read(FOLDER/"compiled.json"),
            controller_contract(declaration(),model),model,"reader_control",cls.profile,DLL)
        cls.rows=[]
        try:
            for old in cls.original[:62]:
                cls.rows.append(host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"])))
        finally:host.close()

    def verify(self,row,reference=None):
        return verify_row(self.core,row,self.rows[59],self.original[60],self.profile,reference)

    def bad(self,edit,reference=None):
        row=copy.deepcopy(self.rows[60]);edit(row)
        with self.assertRaises((ValueError,RuntimeError)):self.verify(row,reference)

    def test_01_full_reference_and_public_row(self):
        result=self.verify(self.rows[60],self.reference)
        self.assertTrue(result["applied"]);self.assertTrue(result["differs_from_nominal"])

    def test_02_changed_actual_history_refused(self):
        self.bad(lambda r:r["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]
            ["ordered_applied_corrections"][0].__setitem__("canonical_velocity_delta_rad_s",123.))

    def test_03_changed_model_binding_refused(self):
        self.bad(lambda r:r["force_reference"]["decision"].__setitem__("profile_sha256","0"*64))

    def test_04_changed_nominal_diagnostic_identity_refused(self):
        self.bad(lambda r:r["force_reference"]["decision"].__setitem__("nominal_request_sha256","0"*64))

    def test_05_missing_candidate_refused(self):
        self.bad(lambda r:r["force_reference"]["decision"]["selection"]["candidates"].pop())

    def test_06_changed_guard_refused(self):
        self.bad(lambda r:r["force_reference"]["decision"]["selection"]["candidates"][0]["rejection_reasons"].append("invented"))

    def test_07_selected_target_substitution_refused(self):
        self.bad(lambda r:r["force_reference"]["decision"]["selection"]["selected_target"].__setitem__(0,99.))

    def test_08_changed_actual_native_transfer_refused(self):
        self.bad(lambda r:r["native_targets"].__setitem__(0,99.))

    def test_09_forged_forecast_force_refused(self):
        def edit(row):
            force=row["force_reference"]["decision"]["selection"]["candidates"][0]["forecast"]["rows"][0]["prediction"]["actuator_force"]
            force[0]+=.1
        self.bad(edit,self.reference)

    def test_10_contract_population_and_provenance_cannot_change(self):
        import audit_predictive_public_v1 as a
        c=a.declaration();self.assertEqual(a.CONTROLS,170)
        for edit in (lambda x:x.__setitem__("worlds_opened",1),
                     lambda x:x.__setitem__("maximum_public_commands_per_reader",363),
                     lambda x:x["provenance_contract"].__setitem__("engine_specific_logic_used",True)):
            changed=copy.deepcopy(c);edit(changed);original=a.read
            with patch.object(a,"read",side_effect=lambda p:changed if p==a.CONTRACT else original(p)):
                with self.assertRaises(ValueError):a.declaration()


if __name__=="__main__":unittest.main()
