"""Native-free inference, real-ABI fallback, case support and immutable context."""
import copy
from dataclasses import FrozenInstanceError
from itertools import islice
import json
import math
import os
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

import mujoco
from adaptation_provider.retrieval import conditioned_feedback_v2 as provider
from adaptation_provider.retrieval import causal_history_v1 as history
from portable_search_control import bridge
from audit_gpu_batch_execution import read_jsonl, same_bits
import first_response_v1 as fitted_context


def sources():
    record = json.loads(provider.FIT_RECORD.read_text())
    result = record["result"]
    attempt = provider.ROOT.parent/"SporeSpore_Evidence"/result["parent_attempt_id"]
    return result,attempt


def retained_rows(group, count=2):
    _,attempt = sources()
    path = attempt/"physical"/group["sources"][0]["trial_id"]/"controller.jsonl"
    require = provider.require
    require(provider.sha(path) == group["sources"][0]["controller_sha256"], "Retained provider fixture changed")
    return list(islice(read_jsonl(path),count))


def bound_call(core, model, row, mode, memory, previous, window):
    request = provider.bind_request(core,row["resolution_request"]["provider_request"],model,mode,memory,previous)
    request = history.attach(request,window)
    call = provider.call_provider(core,request,model,mode)
    resolved = core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
        provider_request=request,provider_response=call["provider_response"]))
    return request,call,resolved


class ConditionedDenseProviderControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cores = [bridge.LocomotionCore(Path(os.environ[name])) for name in ["QUADRUPED_TEST_CORE","PORTABLE_BATCH_BASELINE_CORE"]]
        cls.models = [provider.ConditionedModel.load(core) for core in cls.cores]
        cls.result,cls.attempt = sources()
        cls.rows = {g["group_id"]:retained_rows(g,3) for g in cls.result["groups"]}

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in provider controls"))
            guard.start();self.addCleanup(guard.stop)

    def pair(self, core, model, group_id, mode):
        rows=self.rows[group_id]
        first=bound_call(core,model,rows[0],mode,provider.empty_memory(core,model),[0.]*8,history.empty())
        window,boundary=history.append_resolved(core,first[0],first[2]);self.assertIsNone(boundary)
        second=bound_call(core,model,rows[1],mode,first[2]["next_memory"],[r["applied_correction_rad_s"] for r in first[2]["ordered_commands"]],window)
        return first,second

    def assert_baseline(self, request, resolved):
        self.assertFalse(resolved["adaptation_applied"])
        for original,actual in zip(request["deterministic_baseline"]["ordered_commands"],resolved["ordered_commands"],strict=True):
            self.assertEqual(actual["applied_correction_rad_s"],0.)
            self.assertEqual(struct.pack("d",original["combined_canonical_target_velocity_rad_s"]),struct.pack("d",actual["final_canonical_target_velocity_rad_s"]))

    def test_runtime_features_and_classification_match_every_retained_group_on_both_cores(self):
        self.assertEqual(self.models[0].sha256,self.models[1].sha256)
        for group in self.result["groups"]:
            request=self.rows[group["group_id"]][1]["resolution_request"]["provider_request"]
            feature=provider.context.features(request)
            self.assertTrue(same_bits(feature,group["features"]))
            self.assertTrue(same_bits(feature,fitted_context.features(request)))
            for model in self.models:
                inferred=model.infer(feature)
                self.assertTrue(inferred["feature_supported"])
                self.assertEqual(inferred["condition_id"],group["condition_id"])
                self.assertFalse(inferred["confidence_is_calibrated"])

    def test_context_support_refuses_extrapolation_and_ignores_privileged_labels(self):
        group=self.result["groups"][0];request=copy.deepcopy(self.rows[group["group_id"]][1]["resolution_request"]["provider_request"])
        expected=provider.context.features(request)
        request.update(condition_id="nominal",engine_id="invented",future_outcome="positive")
        self.assertEqual(provider.context.features(request),expected)
        outside=copy.deepcopy(expected);outside["values"][0]=1.e6
        self.assertFalse(self.models[0].infer(outside)["feature_supported"])
        self.assertIsNone(self.models[0].infer(outside)["condition_id"])

    def test_condition_filter_keeps_case_identity_and_never_requires_failed_baseline_cases(self):
        model=self.models[0]
        self.assertEqual([len(r) for r in model.condition_rows],[4233,16932])
        document=model.casebook.document();ledger={e["episode_id"]:e for e in document["ordered_episode_ledger"]}
        cases={c["case_id"]:c for c in document["ordered_cases"]}
        for label,rows in zip(provider.context.LABELS,model.condition_rows,strict=True):
            for row in rows:
                self.assertTrue(ledger[cases[row[-1]]["episode_id"]]["group_id"].startswith(label+"_"))
            query=cases[rows[0][-1]]["cue"];predictions=model.predictions(query,label)
            self.assertTrue(predictions)
            self.assertTrue(all(case in {r[-1] for r in rows} for p in predictions.values() for case in p["case_ids"]))
            if label=="left_075":self.assertNotIn(0,predictions)
        with self.assertRaises(ValueError):model.predictions(query,"unseen")

    def test_frozen_model_and_consumed_fitting_contracts_stay_immutable(self):
        model=self.models[0];before=model.sha256
        with self.assertRaises(FrozenInstanceError):model.sha256="changed"
        document=model.casebook.document();document["ordered_cases"][0]["quality_m_s"]=-99.
        self.assertNotEqual(model.casebook.document()["ordered_cases"][0]["quality_m_s"],-99.)
        self.assertEqual(model.sha256,before)
        from adaptation_provider.retrieval import flat_v2,learner
        self.assertEqual(flat_v2.CONTRACT.name,"flat_contract_v2.json")
        self.assertEqual(learner.CONTRACT.name,"contract_v1.json")
        from adaptation_provider.retrieval import conditioned_feedback_v1 as sparse
        self.assertEqual(sparse.FIT_RECORD.name,"first_response_repertoire_closure_v1.json")
        self.assertEqual(provider.FIT_RECORD.name,"command_resolution_repertoire_closure_v1.json")
        self.assertEqual(sum(map(len,sparse.ConditionedModel.load(self.cores[0]).condition_rows)),720)
        self.assertEqual(sum(map(len,model.condition_rows)),21165)

    def test_selection_hysteresis_default_and_unsupported_cases_are_explicit(self):
        plan=self.models[0].plan()
        p={1:dict(quality_m_s=-.2),2:dict(quality_m_s=-.1)}
        self.assertEqual(provider.choose(p,1,None,plan)[0],2)
        p[2]["quality_m_s"]=-.1995
        self.assertEqual(provider.choose(p,1,None,plan)[0],1)
        self.assertEqual(provider.choose(p,None,None,plan)[0],2)
        self.assertEqual(provider.choose(p,2,0,plan)[0],0)
        self.assertIsNone(provider.choose({},2,None,plan)[0])
        p[2]["quality_m_s"]=-.2
        self.assertEqual(provider.choose(p,None,None,plan)[0],1)

    def test_actual_abi_baseline_prefix_healthy_preservation_and_expert_shuffle(self):
        retained=[]
        for core,model in zip(self.cores,self.models,strict=True):
            for group in self.result["groups"]:
                decisions={}
                for mode in provider.MODES:
                    first,second=self.pair(core,model,group["group_id"],mode)
                    self.assertIsNone(first[1]["provider_error"]);self.assertIsNone(second[1]["provider_error"])
                    self.assert_baseline(first[0],first[2])
                    detail=second[1]["decision"];decisions[mode]=detail
                    self.assertEqual(detail["context"]["condition_id"],group["condition_id"])
                    if mode=="disabled" or group["condition_id"]=="nominal":self.assert_baseline(second[0],second[2])
                    else:
                        self.assertTrue(second[2]["adaptation_applied"])
                        self.assertIn(detail["candidate_index"],[3,4])
                        self.assertTrue(all(abs(r["applied_correction_rad_s"])<=.08 for r in second[2]["ordered_commands"]))
                    retained.append(dict(group_id=group["group_id"],mode=mode,call=second[1],resolved=second[2]))
                logical=decisions["frozen"]["logical_action_index"]
                self.assertEqual(logical,decisions["shuffled"]["logical_action_index"])
                self.assertEqual(decisions["shuffled"]["proposed_action_index"],provider.RULE["shuffled_action_indices"][logical])
        with (Path(os.environ["EXPLORER_TEST_OUTPUT"])/"conditioned-dense-provider-abi.json").open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(dict(synthetic_control=True,worlds_opened=0,comparisons=retained),stream,indent=2);stream.write("\n")

    def test_provider_faults_resolve_absence_and_invalid_host_requests_still_refuse(self):
        core,model=self.cores[0],self.models[0]
        _,second=self.pair(core,model,"left_075_train_001","frozen")
        request=copy.deepcopy(second[0]);request["expected_model_sha256"]="sha256:"+"0"*64
        called=provider.call_provider(core,request,model,"frozen")
        self.assertIsNone(called["provider_response"]);self.assertIsNotNone(called["provider_error"])
        resolved=core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",provider_request=request,provider_response=None))
        self.assert_baseline(request,resolved)
        request=copy.deepcopy(second[0]);request["history"]=history.empty()
        called=provider.call_provider(core,request,model,"frozen")
        self.assertIsNone(called["provider_response"])
        resolved=core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",provider_request=request,provider_response=None))
        self.assert_baseline(request,resolved)
        request=copy.deepcopy(second[0]);request["state"]["sample_time_s"]=-1.
        called=provider.call_provider(core,request,model,"frozen")
        self.assertIsNone(called["provider_response"])
        with self.assertRaises(Exception):core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",provider_request=request,provider_response=None))

    def test_context_memory_is_private_sequential_and_checksum_bound(self):
        core,model=self.cores[0],self.models[0];first,second=self.pair(core,model,"left_075_train_001","frozen")
        for mutate in [lambda r:r["provider_memory"].__setitem__("sequence",2),
            lambda r:r["provider_memory"].__setitem__("opaque_state_sha256","sha256:"+"0"*64),
            lambda r:r.__setitem__("seed",r["seed"]+1)]:
            request=copy.deepcopy(second[0]);mutate(request)
            self.assertIsNotNone(provider.call_provider(core,request,model,"frozen")["provider_error"])
        request=provider.bind_request(core,second[0],model,"disabled",first[2]["next_memory"],[0.]*8)
        self.assertIsNotNone(provider.call_provider(core,request,model,"disabled")["provider_error"])
        for mode in provider.MODES:
            self.assertEqual(provider.empty_memory(core,model)["opaque_state"],{})

    def test_current_posture_and_missing_case_support_withdraw_without_mutating_model(self):
        core,model=self.cores[0],self.models[0];_,second=self.pair(core,model,"left_075_train_001","frozen")
        row=copy.deepcopy(self.rows["left_075_train_001"][2]);state=row["resolution_request"]["provider_request"]["state"]
        state["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(.45),y=0.,z=0.,w=math.cos(.45))
        before=model.sha256
        request,called,resolved=bound_call(core,model,row,"frozen",second[2]["next_memory"],[r["applied_correction_rad_s"] for r in second[2]["ordered_commands"]],history.empty())
        self.assertEqual(called["provider_response"]["status"],"unsupported");self.assert_baseline(request,resolved)
        with patch.object(provider.ConditionedModel,"predictions",return_value={}):
            _,second=self.pair(core,model,"left_075_train_001","frozen")
            self.assertEqual(second[1]["decision"]["selection_reason"],"no_current_case_support")
            self.assert_baseline(second[0],second[2])
        self.assertEqual(model.sha256,before)


if __name__ == "__main__":unittest.main()
