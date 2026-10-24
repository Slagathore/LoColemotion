"""Retained-input host replay: actual history, experts, fallback and private state."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco

import test_gpu_repertoire_v2 as fixtures
import conditioned_feedback_dense_control as host
from conditioned_feedback_dense_control import ConditionedFeedbackController, ROLES, provider
from cpu_phase_release_task import declaration as old_declaration
from phase_release_control import PhaseReleaseController
from audit_gpu_batch_execution import same_bits
from audit_conditioned_feedback import validate_proposal, influence
from test_conditioned_feedback_dense_provider import sources,retained_rows


class ConditionedHostControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass();cls.f=fixtures.RepertoireControls
        cls.models=[provider.ConditionedModel.load(c) for c in [cls.f.core,cls.f.oracle]]
        cls.c=old_declaration();cls.c.update(seed=104232601)
        cls.c["provider"]=dict(kind=host.PROVIDER_KIND,definition=provider.definition(),model_sha256=cls.models[0].sha256)
        result,_=sources();cls.groups=result["groups"]
        cls.inputs={g["group_id"]:retained_rows(g,18) for g in cls.groups};cls.rows={}
        guards=[]
        try:
            for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
                guard=patch.object(mujoco,name,side_effect=AssertionError("Retained-input replay opens no world"));guard.start();guards.append(guard)
            for core_index,core in enumerate([cls.f.core,cls.f.oracle]):
                for group in cls.groups:
                    group_id=group["group_id"]
                    for role_index in range(5):
                        controller=ConditionedFeedbackController(core,cls.f.compiled,cls.c,role_index,cls.models[core_index])
                        try:
                            cls.rows[core_index,group_id,role_index]=[controller.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in cls.inputs[group_id]]
                        finally:controller.close()
        finally:
            for guard in reversed(guards):guard.stop()
        path=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"conditioned-host-retained-inputs.json"
        with path.open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(dict(synthetic_control=True,worlds_opened=0,new_physical_outcomes=False,
                records=[dict(core_index=k[0],group_id=k[1],role=ROLES[k[2]]["id"],rows=v) for k,v in cls.rows.items()]),stream,allow_nan=False);stream.write("\n")

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No host test worlds"));guard.start();self.addCleanup(guard.stop)

    def controller(self,index=2,c=None):return ConditionedFeedbackController(self.f.core,self.f.compiled,c or self.c,index,self.models[0])

    def test_both_cores_replay_every_host_result_identically(self):
        for group in self.groups:
            for index in range(5):self.assertTrue(same_bits(self.rows[0,group["group_id"],index],self.rows[1,group["group_id"],index]))

    def test_baseline_disabled_and_healthy_choices_preserve_actual_baseline_bits(self):
        for group in self.groups:
            identity=group["group_id"]
            for index in [0,1]+([2,3] if group["condition_id"]=="nominal" else []):
                for actual,expected in zip(self.rows[0,identity,index],self.inputs[identity],strict=True):
                    for name in ["output","composition","native_targets"]:self.assertTrue(same_bits(actual[name],expected[name]))
                    self.assertFalse(actual["resolution"]["adaptation_applied"])

    def test_reference_uses_unchanged_phase_controller_on_identical_observations(self):
        for group in self.groups:
            identity=group["group_id"];controller=PhaseReleaseController(self.f.core,self.f.compiled,dict(old_declaration(),seed=self.c["seed"]),2)
            try:
                for actual,source in zip(self.rows[0,identity,4],self.inputs[identity],strict=True):
                    expected=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
                    self.assertTrue(all(same_bits(value,actual[k]) for k,value in expected.items()))
            finally:controller.close()

    def test_actual_one_command_history_and_private_inferred_context(self):
        for group in self.groups:
            identity=group["group_id"]
            for index in range(4):
                rows=self.rows[0,identity,index];entry=rows[1]["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]
                self.assertEqual(entry["state"],rows[0]["request"]["state"])
                self.assertEqual(entry["resolution_receipt_sha256"],self.f.core.canonicalize_json(rows[0]["resolution"])["sha256"])
                self.assertFalse(entry["adaptation_applied"])
                self.assertEqual(rows[2]["resolution_request"]["provider_request"]["history"]["ordered_entries"],[])
                if index:
                    self.assertEqual(rows[1]["selection"]["decision"]["context"]["condition_id"],group["condition_id"])
                    self.assertEqual(rows[-1]["resolution"]["next_memory"]["sequence"],18)
                    self.assertFalse(rows[-1]["resolution"]["next_memory"]["weights_mutated"])

    def test_selection_shuffle_opportunities_and_actual_application_are_distinct(self):
        for group in self.groups:
            identity=group["group_id"];frozen,disabled,shuffled=[self.rows[0,identity,i] for i in [2,1,3]]
            for a,b,c in zip(frozen,disabled,shuffled,strict=True):
                da,db,dc=[r["selection"]["decision"] for r in [a,b,c]]
                self.assertEqual(da["logical_action_index"],db["logical_action_index"])
                self.assertEqual(da["logical_action_index"],dc["logical_action_index"])
                if da["logical_action_index"] is not None:self.assertEqual(dc["proposed_action_index"],[0,2,1][da["logical_action_index"]])
            if group["condition_id"]=="left_075":
                self.assertEqual(influence(frozen)["first_nonzero_step"],1)
                self.assertGreater(influence(disabled)["selection_opportunities"],0)
                self.assertEqual(influence(disabled)["nonzero_correction_steps"],0)
            else:self.assertEqual(influence(frozen)["nonzero_correction_steps"],0)

    def test_independent_cases_experts_envelopes_and_rehashed_corruptions(self):
        for group in self.groups:
            for index in range(5):
                previous=[0.]*8
                for row in self.rows[0,group["group_id"],index]:
                    validate_proposal(row,self.c,index,previous,self.models[0])
                    previous=[r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
        for change in [lambda r:r["selection"]["decision"].__setitem__("logical_action_index",0),
            lambda r:r["selection"]["decision"]["predictions"][0]["case_ids"].__setitem__(0,"crossed_case"),
            lambda r:r["selection"]["decision"]["query"]["vector"].__setitem__(0,99.),
            lambda r:r["native_targets"].__setitem__(0,99.)]:
            row=copy.deepcopy(self.rows[0,"left_075_train_001",2][1]);change(row)
            with self.assertRaises(ValueError):validate_proposal(row,self.c,2,[0.]*8,self.models[0])

    def test_lifecycle_model_identity_and_partial_failure_close(self):
        for index in [-1,5,True]:
            with self.assertRaises(ValueError):self.controller(index)
        c=copy.deepcopy(self.c);c["provider"]["model_sha256"]="sha256:"+"0"*64
        with self.assertRaises(ValueError):self.controller(c=c)
        row=self.inputs["left_075_train_001"][0];controller=self.controller()
        with patch.object(host,"map_resolution",side_effect=ValueError("injected mapping failure")):
            with self.assertRaisesRegex(ValueError,"injected mapping failure"):controller.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertTrue(controller.closed)
        with self.assertRaisesRegex(ValueError,"lifecycle/clock"):controller.step(row["request"]["state"],row["stability"],row["kinematics"])
        controller.close()

    def test_provider_fault_uses_current_baseline_and_retains_error(self):
        source=self.inputs["left_075_train_001"][0];controller=self.controller()
        try:
            with patch.object(provider,"call_provider",return_value=dict(provider_response=None,decision=None,provider_error=dict(type="Injected",message="fault"))):
                row=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
            self.assertEqual(row["selection"]["provider_error"]["type"],"Injected")
            self.assertFalse(row["resolution"]["adaptation_applied"])
            self.assertTrue(same_bits(row["native_targets"],source["native_targets"]))
        finally:controller.close()


if __name__=="__main__":unittest.main()
