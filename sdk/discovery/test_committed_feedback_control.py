"""Retained-input checks for the six-role committed-selection host."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
from contextlib import ExitStack
import mujoco

import test_gpu_repertoire_v2 as fixtures
import committed_feedback_control as host
from committed_feedback_control import CommittedFeedbackController,ROLES,provider
from cpu_phase_release_task import declaration as parent_declaration
from audit_gpu_batch_execution import same_bits
from audit_committed_feedback import validate_proposal,influence
from test_conditioned_feedback_dense_provider import sources,retained_rows


class CommittedHostControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass();cls.f=fixtures.RepertoireControls
        cls.c=parent_declaration();cls.c.update(seed=104232601,provider=host.expected_provider())
        cls.cores=[cls.f.core,cls.f.oracle]
        cls.models=[provider.ConditionedModel.load(c) for c in cls.cores]
        cls.old_models=[host.current.provider.ConditionedModel.load(c) for c in cls.cores]
        result,_=sources();cls.groups=result["groups"]
        cls.inputs={g["group_id"]:retained_rows(g,35) for g in cls.groups};cls.rows={}
        with ExitStack() as guards:
            for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No worlds in committed host controls")))
            for ci,core in enumerate(cls.cores):
                for group in cls.groups:
                    gid=group["group_id"]
                    for index in range(6):
                        controller=CommittedFeedbackController(core,cls.f.compiled,cls.c,index,cls.models[ci])
                        try:
                            cls.rows[ci,gid,index]=[controller.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in cls.inputs[gid]]
                        finally:controller.close()
        with (Path(os.environ["EXPLORER_TEST_OUTPUT"])/"committed-host-retained-inputs.json").open("x",encoding="utf-8",newline="\n") as f:
            json.dump(dict(synthetic_control=True,worlds_opened=0,new_physical_outcomes=False,
                records=[dict(core_index=k[0],group_id=k[1],role=ROLES[k[2]]["id"],rows=v) for k,v in cls.rows.items()]),
                f,allow_nan=False);f.write("\n")

    def setUp(self):
        guards=ExitStack();self.addCleanup(guards.close)
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No committed host test worlds")))

    def controller(self,index=4,c=None):
        return CommittedFeedbackController(self.f.core,self.f.compiled,c or self.c,index,self.models[0])

    def test_both_cores_replay_all_six_roles_identically(self):
        for group in self.groups:
            for index in range(6):
                self.assertTrue(same_bits(self.rows[0,group["group_id"],index],self.rows[1,group["group_id"],index]))

    def test_baseline_disabled_and_every_healthy_role_preserve_baseline_bits(self):
        for group in self.groups:
            gid=group["group_id"]
            for index in [0,1]+(list(range(2,6)) if group["condition_id"]=="nominal" else []):
                for actual,expected in zip(self.rows[0,gid,index],self.inputs[gid],strict=True):
                    for name in ["output","composition","native_targets"]:
                        self.assertTrue(same_bits(actual[name],expected[name]))
                    self.assertFalse(actual["resolution"]["adaptation_applied"])

    def test_current_roles_retain_the_exact_original_host_behavior(self):
        for group in self.groups:
            gid=group["group_id"]
            for index in [2,3]:
                role=ROLES[index];model=self.old_models[0]
                controller=host.current.ConditionedFeedbackController(self.f.core,self.f.compiled,
                    host.role_contract(self.c,role,model),role["delegate_role_index"],model)
                try:
                    for actual,source in zip(self.rows[0,gid,index],self.inputs[gid],strict=True):
                        expected=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
                        expected["selection"]["role"]=role
                        self.assertTrue(same_bits(actual,expected))
                finally:controller.close()

    def test_all_roles_use_one_actual_command_and_private_sequential_context(self):
        for group in self.groups:
            gid=group["group_id"]
            for index in range(6):
                rows=self.rows[0,gid,index]
                entry=rows[1]["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]
                self.assertEqual(entry["state"],rows[0]["request"]["state"])
                self.assertEqual(entry["resolution_receipt_sha256"],self.f.core.canonicalize_json(rows[0]["resolution"])["sha256"])
                self.assertFalse(entry["adaptation_applied"])
                self.assertEqual(rows[2]["resolution_request"]["provider_request"]["history"]["ordered_entries"],[])
                if index:
                    self.assertEqual(rows[1]["selection"]["decision"]["context"]["condition_id"],group["condition_id"])
                    self.assertEqual(rows[-1]["resolution"]["next_memory"]["sequence"],35)
                    self.assertFalse(rows[-1]["resolution"]["next_memory"]["weights_mutated"])

    def test_logical_shuffle_and_disabled_opportunities_remain_distinct_from_influence(self):
        for group in self.groups:
            gid=group["group_id"]
            for index_a,index_b in [(2,3),(4,5),(1,4)]:
                for a,b in zip(self.rows[0,gid,index_a],self.rows[0,gid,index_b],strict=True):
                    da,db=a["selection"]["decision"],b["selection"]["decision"]
                    self.assertEqual(da["logical_action_index"],db["logical_action_index"])
                    if index_b in [3,5] and da["logical_action_index"] is not None:
                        self.assertEqual(db["proposed_action_index"],[0,2,1][da["logical_action_index"]])
            disabled=influence(self.rows[0,gid,1])
            self.assertEqual(disabled["nonzero_correction_steps"],0)
            if group["condition_id"]=="left_075":
                self.assertGreater(disabled["selection_opportunities"],0)
                for index in range(2,6):self.assertEqual(influence(self.rows[0,gid,index])["first_nonzero_step"],1)

    def test_independent_cases_commitment_experts_and_envelopes_reject_corruption(self):
        for group in self.groups:
            for index in range(6):
                model=self.old_models[0] if index in [2,3] else self.models[0]
                previous=[0.]*8
                for row in self.rows[0,group["group_id"],index]:
                    validate_proposal(row,self.c,index,previous,model)
                    previous=[r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
        for change in [
            lambda r:r["selection"]["decision"].__setitem__("logical_action_index",0),
            lambda r:r["selection"]["decision"]["commitment"].__setitem__("until_step",32),
            lambda r:r["selection"]["decision"]["commitment"].__setitem__("event","expired"),
            lambda r:r["resolution"]["next_memory"]["opaque_state"].__setitem__("committed_until_step",32),
            lambda r:r["selection"]["decision"]["predictions"][0]["case_ids"].__setitem__(0,"crossed_case"),
            lambda r:r["selection"]["decision"]["query"]["vector"].__setitem__(0,99.),
            lambda r:r["native_targets"].__setitem__(0,99.),
            lambda r:r["selection"].__setitem__("role",ROLES[2])]:
            row=copy.deepcopy(self.rows[0,"left_075_train_001",4][1]);change(row)
            with self.assertRaises(ValueError):validate_proposal(row,self.c,4,[0.]*8,self.models[0])

        for index in range(6):
            row=copy.deepcopy(self.rows[0,"left_075_train_001",index][1])
            row["resolution"]["next_memory"]["sequence"]+=1
            model=self.old_models[0] if index in [2,3] else self.models[0]
            with self.assertRaisesRegex(ValueError,"resolver memory join"):
                validate_proposal(row,self.c,index,[0.]*8,model)

    def test_real_host_keeps_option_until_exact_expiry(self):
        calls=0
        def predictions(query,label):
            nonlocal calls
            calls+=1
            return {1:dict(quality_m_s=-.1 if calls==1 else -.2,support_distance=.1,case_ids=["synthetic-one"]),
                2:dict(quality_m_s=-.2 if calls==1 else -.1,support_distance=.1,case_ids=["synthetic-two"])}
        controller=self.controller();rows=[]
        try:
            with patch.object(provider.ConditionedModel,"predictions",side_effect=predictions):
                for source in self.inputs["left_075_train_001"]:
                    rows.append(controller.step(source["request"]["state"],source["stability"],source["kinematics"]))
        finally:controller.close()
        self.assertEqual(calls,34)
        for row in rows[1:31]:
            self.assertEqual(row["selection"]["decision"]["logical_action_index"],1)
            self.assertEqual(row["selection"]["decision"]["commitment"]["until_step"],31)
        self.assertEqual(rows[31]["selection"]["decision"]["logical_action_index"],2)
        self.assertEqual(rows[31]["selection"]["decision"]["commitment"],dict(event="expired",until_step=61,commands=30))

    def test_lifecycle_crossed_models_and_mapping_failure_close_the_delegate(self):
        for index in [-1,6,True]:
            with self.assertRaises(ValueError):self.controller(index)
        for key in ["model_sha256","current_model_sha256"]:
            c=copy.deepcopy(self.c);c["provider"][key]="sha256:"+"0"*64
            with self.assertRaises(ValueError):self.controller(c=c)
        with self.assertRaises(ValueError):
            CommittedFeedbackController(self.f.core,self.f.compiled,self.c,4,self.old_models[0])
        source=self.inputs["left_075_train_001"][0]
        for index,runtime in [(2,host.current),(4,host._committed)]:
            controller=self.controller(index)
            with patch.object(runtime,"map_resolution",side_effect=ValueError("injected mapping failure")):
                with self.assertRaisesRegex(ValueError,"injected mapping failure"):
                    controller.step(source["request"]["state"],source["stability"],source["kinematics"])
            self.assertTrue(controller.closed)
            with self.assertRaisesRegex(ValueError,"lifecycle/clock"):
                controller.step(source["request"]["state"],source["stability"],source["kinematics"])
            controller.close()

    def test_absent_provider_preserves_current_baseline_and_error(self):
        source=self.inputs["left_075_train_001"][0];controller=self.controller()
        try:
            with patch.object(provider,"call_provider",return_value=dict(provider_response=None,decision=None,
                    provider_error=dict(type="Injected",message="fault"))):
                row=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
            self.assertEqual(row["selection"]["provider_error"]["type"],"Injected")
            self.assertFalse(row["resolution"]["adaptation_applied"])
            self.assertTrue(same_bits(row["native_targets"],source["native_targets"]))
        finally:controller.close()


if __name__=="__main__":unittest.main()
