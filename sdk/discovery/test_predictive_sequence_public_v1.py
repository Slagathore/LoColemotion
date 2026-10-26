"""Bounds, history, memory, refusal and public-transfer negative controls."""
import copy
from itertools import islice
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
from test_predictive_sequence_v1 import synthetic_value,SyntheticSelector
import predictive_sequence_online_v1 as online
from predictive_sequence_selection_audit_v1 import verify_selection
from predictive_sequence_policy_v1 import Policy,make_profile,digest,PredictiveRefusal
from predictive_sequence_control_v1 import PredictiveSequenceController,terminal_error,transfer_targets
from predictive_sequence_row_audit_v1 import verify_row
from predictive_sequence_task_v1 import FOLDER,DLL,DLL_SHA,read
from audit_gpu_batch_execution import read_jsonl
from hierarchical_force_policy_v8 import make_profile as nominal_profile,HierarchyRefusal
from prepare_predictive_model_mujoco import prepare
from contact_force_observer_task import bridge
from hold_horizon_task import controller_contract,frozen_model,declaration


class OnlineControls(unittest.TestCase):
    def setUp(self):
        self.value=synthetic_value();self.model=SyntheticSelector()
    def pair(self):
        selection=online.select(self.model,self.value,None)
        plan=online.next_plan(self.value,selection,"0"*64)
        value=copy.deepcopy(self.value);value["command"]=61;value["previous_correction"]=plan["correction"]
        return value,plan
    def test_01_cold_full_search_and_reader(self):
        s=online.select(self.model,self.value,None)
        self.assertTrue(s["accepted"]);self.assertEqual(s["evaluated_candidates"],102)
        verify_selection(s,self.value,None,self.model)
    def test_02_warm_is_repredicted_once(self):
        v,p=self.pair();s=online.select(self.model,v,p)
        self.assertEqual((s["reason"],s["evaluated_candidates"]),("warm_valid",1))
        verify_selection(s,v,p,self.model)
    def test_03_scheduled_search_is_bounded(self):
        v,p=self.pair();v["command"]=72;p["command"]=71
        s=online.select(self.model,v,p);self.assertEqual((s["reason"],s["evaluated_candidates"]),("scheduled",103))
        verify_selection(s,v,p,self.model)
    def test_04_failed_warm_triggers_search_without_permission(self):
        v,p=self.pair();v["qpos"][2]=.1
        s=online.select(self.model,v,p)
        self.assertEqual((s["reason"],s["evaluated_candidates"],s["accepted"]),("warm_refused",103,False))
        verify_selection(s,v,p,self.model)
        with self.assertRaises(ValueError):online.next_plan(v,s,"0"*64)
    def test_05_warm_reconciles_actual_baseline(self):
        v,p=self.pair();p["targets"]=[[i*.01]*8 for i in range(66)];v["baseline"]=[1.]*8
        k=online.warm_knots(v,p);np.testing.assert_allclose(k[0],[-.99]*8,rtol=0,atol=1e-14)
    def test_06_warm_holds_last_target_at_tail(self):
        v,p=self.pair();p["targets"]=[[i*.01]*8 for i in range(66)]
        np.testing.assert_allclose(online.warm_knots(v,p)[-1],[.65]*8,rtol=0,atol=1e-14)
    def test_07_stale_clock_refused(self):
        v,p=self.pair();p["command"]-=1
        with self.assertRaises(ValueError):online.select(self.model,v,p)
    def test_08_changed_actual_correction_refused(self):
        v,p=self.pair();v["previous_correction"][0]+=.01
        with self.assertRaises(ValueError):online.select(self.model,v,p)
    def test_09_future_observation_in_memory_refused(self):
        v,p=self.pair();p["future_observation"]=[]
        with self.assertRaises(ValueError):online.select(self.model,v,p)
    def test_10_target_domain_and_shape_refused(self):
        v,p=self.pair()
        for shape in ("overspeed","short","nan"):
            bad=copy.deepcopy(p)
            if shape=="short":bad["targets"].pop()
            else:bad["targets"][1][0]=4. if shape=="overspeed" else float("nan")
            with self.assertRaises(ValueError):online.select(self.model,v,bad)
    def test_11_digest_and_first_target_refused(self):
        v,p=self.pair()
        for key in ("digest","first"):
            bad=copy.deepcopy(p)
            if key=="digest":bad["request_sha256"]="x"*64
            else:bad["targets"][0][0]+=.01
            with self.assertRaises(ValueError):online.select(self.model,v,bad)
    def test_12_handoff_and_missing_prior_refused(self):
        v,p=self.pair()
        with self.assertRaises(ValueError):online.select(self.model,self.value,p)
        with self.assertRaises(ValueError):online.select(self.model,v,None)
    def test_13_inputs_are_immutable(self):
        v,p=self.pair();before=copy.deepcopy((v,p));online.select(self.model,v,p);self.assertEqual(before,(v,p))
    def test_14_foreign_selection_input_refused(self):
        self.value["future"]=True
        with self.assertRaises(ValueError):online.select(self.model,self.value,None)
    def test_15_memory_first_target_and_authority(self):
        v,p=self.pair();s=online.select(self.model,v,p);n=online.next_plan(v,s,"1"*64)
        self.assertEqual(n["targets"][0],s["selected_target"]);self.assertFalse(s["planning_memory_is_learning"])
    def test_16_reader_rejects_corrupted_population_and_claims(self):
        v,p=self.pair();s=online.select(self.model,v,p)
        for field in ("count","knots","guard","cost","target","authority","best"):
            bad=copy.deepcopy(s)
            if field=="count":bad["evaluated_candidates"]+=1
            elif field=="knots":bad["evaluations"][0]["option"]["knots"][0][0]+=.1
            elif field=="guard":bad["evaluations"][0]["result"]["rows"][0]["guard_reasons"]=["invented"]
            elif field=="cost":bad["evaluations"][0]["result"]["rows"][0]["objective"]["total"]+=1
            elif field=="target":bad["selected_target"][0]+=.1
            elif field=="authority":bad["planning_memory_is_learning"]=True
            else:bad["best"]["result"]["valid_intervals"]-=1
            with self.assertRaises(ValueError):verify_selection(bad,v,p,self.model)


class PublicControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.rows=list(islice(read_jsonl(FOLDER/"controller.jsonl"),62));cls.compiled=read(FOLDER/"compiled.json")
        n=nominal_profile(cls.compiled,read(FOLDER/"inputs.json"));m=prepare(n,(FOLDER/"model.xml").read_text(encoding="utf-8"))
        cls.profile=make_profile(n,m,DLL_SHA);cls.model=frozen_model(cls.core)
        cls.contract=controller_contract(declaration(),cls.model)
    def setUp(self):
        self.policy=Policy(self.core,self.profile,DLL)
        self.request=self.policy.bind(self.rows[60]["resolution_request"]["provider_request"],
            self.rows[60]["stability"],self.policy.memory("sequence_test"),"sequence_test")
        # These controls isolate the provider protocol. The retained reader
        # separately exercises the actual numerical predictor and all forecasts.
        patched=patch("predictive_sequence_policy_v1.select",side_effect=lambda model,value,plan:online.select(SyntheticSelector(),value,plan))
        patched.start();self.addCleanup(patched.stop)
    def resolve(self):
        response,decision=self.policy.respond(self.request)
        r=self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=self.request,provider_response=response))
        return response,decision,r
    def host(self):
        h=PredictiveSequenceController(self.core,self.compiled,self.contract,self.model,"sequence_host",self.profile,DLL)
        self.addCleanup(h.close)
        for i in range(60):
            row=self.step(h,i);self.assertEqual(row["native_targets"],self.rows[i]["native_targets"])
        return h,row
    def step(self,h,i):
        old=self.rows[i]
        return h.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
    def test_17_profile_bindings_and_authority_refused(self):
        for key in ("trained","tier2_qualified","tier3_benefit_established","cross_engine_equivalence"):
            p=copy.deepcopy(self.profile);p[key]=True
            with self.assertRaises(ValueError):Policy(self.core,p,DLL)
        p=copy.deepcopy(self.profile);p["source_bindings"]["predictive_sequence_online_v1.py"]="0"*64
        with self.assertRaises(ValueError):Policy(self.core,p,DLL)
    def test_18_kernel_and_model_identity_refused(self):
        p=copy.deepcopy(self.profile);p["kernel_sha256"]="0"*64
        with self.assertRaises(ValueError):Policy(self.core,p,DLL)
        p=copy.deepcopy(self.profile);p["prepared_model"]["velocity_gains"][0]*=2
        with self.assertRaises(ValueError):Policy(self.core,p,DLL)
    def test_19_wrong_public_identity_refused(self):
        for key in ("provider_id","expected_provider_version","expected_model_sha256","request_id"):
            r=copy.deepcopy(self.request);r[key]="other"
            with self.assertRaises(ValueError):self.policy.respond(r)
    def test_20_memory_digest_and_domain_refused(self):
        r=copy.deepcopy(self.request);r["provider_memory"]["opaque_state"]["plan"]={}
        with self.assertRaises(ValueError):self.policy.respond(r)
        r["provider_memory"]["opaque_state_sha256"]=digest(self.core,r["provider_memory"]["opaque_state"])
        with self.assertRaises(ValueError):self.policy.respond(r)
    def test_21_missing_actual_history_refused(self):
        r=copy.deepcopy(self.request);r["history"]["ordered_entries"]=[]
        with self.assertRaises(ValueError):self.policy.respond(r)
        r=copy.deepcopy(self.request);r["safety_envelope"]["ordered_actuator_limits"][0]["previous_applied_correction_rad_s"]+=.01
        with self.assertRaises(ValueError):self.policy.respond(r)
    def test_22_request_authority_refused(self):
        for key in ("provider_may_build_worlds","provider_may_modify_physics_state","provider_has_physical_acceptance_authority"):
            r=copy.deepcopy(self.request);r[key]=True
            with self.assertRaises(ValueError):self.policy.respond(r)
    def test_23_prior_plan_binding_refused(self):
        h,_=self.host();self.step(h,60)
        h.force_memory["opaque_state"]["plan"]["request_sha256"]="0"*64
        h.force_memory["opaque_state_sha256"]=digest(self.core,h.force_memory["opaque_state"])
        row=self.step(h,61);self.assertTrue(h.closed);self.assertIsNotNone(terminal_error(row))
    def test_24_safe_no_actuation_prevents_planning(self):
        r=copy.deepcopy(self.request);r["deterministic_baseline"]["safe_no_actuation"]=True
        with patch.object(self.policy.nominal,"respond",side_effect=AssertionError("Must not plan")):
            with self.assertRaises(PredictiveRefusal):self.policy.respond(r)
    def test_25_nominal_refusal_preserved(self):
        with patch.object(self.policy.nominal,"respond",side_effect=HierarchyRefusal(dict(reason="diagnostic"))):
            with self.assertRaises(PredictiveRefusal) as exc:self.policy.respond(self.request)
        self.assertEqual(exc.exception.decision["stage"],"nominal_refusal")
    def test_26_selection_refusal_and_error_preserved(self):
        with patch("predictive_sequence_policy_v1.select",return_value=dict(accepted=False)):
            with self.assertRaises(PredictiveRefusal):self.policy.respond(self.request)
        with patch("predictive_sequence_policy_v1.select",side_effect=ValueError("numerical")):
            with self.assertRaises(PredictiveRefusal) as exc:self.policy.respond(self.request)
        self.assertEqual(exc.exception.decision["stage"],"selection_error")
    def test_27_real_core_exact_first_command_and_memory(self):
        response,d,r=self.resolve();self.assertEqual(r["provider_status"],"applied")
        self.assertEqual([x["final_canonical_target_velocity_rad_s"] for x in r["ordered_commands"]],d["selection"]["selected_target"])
        self.assertEqual(r["next_memory"]["opaque_state"]["plan"]["request_sha256"],r["request_sha256"])
        self.assertFalse(response["provenance"]["weights_mutated"])
    def test_28_host_warm_start_uses_actual_resolved_history(self):
        h,_=self.host();first=self.step(h,60);second=self.step(h,61)
        self.assertIsNone(terminal_error(second));d=second["force_reference"]["decision"]
        self.assertEqual(d["selection"]["reason"],"warm_valid")
        self.assertEqual(second["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]["request_sha256"],
            first["resolution"]["request_sha256"])
    def test_29_projection_mismatch_prevents_transfer(self):
        h,_=self.host();original=h.force_policy.respond
        def altered(r):
            response,d=original(r);response["ordered_corrections"][0]["canonical_velocity_delta_rad_s"]+=.005
            return response,d
        with patch.object(h.force_policy,"respond",side_effect=altered):row=self.step(h,60)
        self.assertTrue(h.closed);self.assertIsNotNone(terminal_error(row))
        with self.assertRaises(ValueError):transfer_targets(row,SimpleNamespace(ctrl=np.zeros(8)))
    def test_30_refusal_closes_and_preserves_native_input(self):
        h,_=self.host();data=SimpleNamespace(ctrl=np.zeros(8))
        with patch("predictive_sequence_policy_v1.select",return_value=dict(accepted=False)):row=self.step(h,60)
        self.assertTrue(h.closed)
        with self.assertRaises(ValueError):transfer_targets(row,data)
        np.testing.assert_array_equal(data.ctrl,np.zeros(8))
    def test_31_episode_reset_has_no_cached_plan(self):
        self.resolve();m=self.policy.memory("new_episode")
        self.assertIsNone(m["opaque_state"]["plan"]);self.assertEqual(m["sequence"],0)
    def test_32_public_row_reader_and_corruption(self):
        h,previous=self.host();row=self.step(h,60)
        verify_row(self.core,row,previous,self.rows[60],self.profile,SyntheticSelector())
        for field in ("target","memory","marker"):
            bad=copy.deepcopy(row)
            if field=="target":bad["native_targets"][0]+=.1
            elif field=="memory":bad["resolution"]["next_memory"]["opaque_state"]["plan"]["command"]-=1
            else:bad["predictive_sequence"]["selected_prediction_matches_final_public_command"]=False
            with self.assertRaises(ValueError):
                verify_row(self.core,bad,previous,self.rows[60],self.profile,SyntheticSelector())


if __name__=="__main__":unittest.main()
