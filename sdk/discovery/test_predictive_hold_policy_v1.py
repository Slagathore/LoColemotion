"""Public predictive provider identity, actual history and fail-closed transfer."""
import copy
from contextlib import ExitStack
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import mujoco
import numpy as np
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import read_jsonl
from audit_predictive_numeric_backend import DLL,DLL_SHA,read
from test_held_contact_rollout import FOLDER
from contact_force_observer_task import bridge
from prepare_predictive_model_mujoco import prepare
from predictive_hold_policy_v1 import Policy,make_profile,digest,PROVIDER,PredictiveRefusal
from predictive_hold_control_v1 import PredictiveHoldController,terminal_error,transfer_targets
from hold_horizon_task import controller_contract,frozen_model,declaration


class PredictivePolicyControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.rows=list(read_jsonl(FOLDER/"controller.jsonl"));cls.compiled=read(FOLDER/"compiled.json")
        n=read(FOLDER/"force-profile.json");m=prepare(n,(FOLDER/"model.xml").read_text())
        cls.profile=make_profile(n,m,DLL_SHA);cls.model=frozen_model(cls.core)
        cls.contract=controller_contract(declaration(),cls.model)

    def setUp(self):
        self.policy=Policy(self.core,self.profile,DLL)
        self.request=self.policy.bind(self.rows[60]["resolution_request"]["provider_request"],
            self.rows[60]["stability"],self.policy.memory("predictive_test"),"predictive_test")

    def resolve(self,request=None):
        request=self.request if request is None else request
        response,decision=self.policy.respond(request)
        result=self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=response))
        return response,decision,result

    def host(self):
        return PredictiveHoldController(self.core,self.compiled,self.contract,self.model,"predictive_host_test",self.profile,DLL)

    def handoff(self,host):
        for old in self.rows[:60]:
            row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
            self.assertEqual(row["native_targets"],old["native_targets"])

    def step(self,host,index):
        old=self.rows[index]
        return host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))

    def rehash_memory(self,request):
        m=request["provider_memory"];m["opaque_state_sha256"]=digest(self.core,m["opaque_state"])

    def test_01_selected_command_applied_by_real_core(self):
        response,d,r=self.resolve();self.assertEqual(r["provider_status"],"applied")
        self.assertEqual([x["final_canonical_target_velocity_rad_s"] for x in r["ordered_commands"]],d["selection"]["selected_target"])
        self.assertEqual(response["provenance"]["provider_id"],PROVIDER)
        self.assertNotEqual(d["selection"]["selected_index"],0)

    def test_02_nominal_certificate_is_not_selected_certificate(self):
        _,d,_=self.resolve()
        self.assertFalse(d["nominal_prediction_applies_to_transfer"])
        self.assertNotEqual(d["nominal"]["projection"]["target"],d["selection"]["selected_target"])

    def test_03_inputs_and_profile_immutable(self):
        before=copy.deepcopy((self.profile,self.request));self.resolve()
        self.assertEqual(before,(self.profile,self.request))
        p=copy.deepcopy(self.profile);candidate=Policy(self.core,p,DLL);p["prepared_model"]["velocity_gains"][0]*=2
        self.assertNotEqual(p,candidate.profile)

    def test_04_bound_source_refused(self):
        p=copy.deepcopy(self.profile);p["source_bindings"]["predictive_hold_policy_v1.py"]="0"*64
        with self.assertRaises(ValueError):Policy(self.core,p,DLL)

    def test_05_crossed_nominal_model_refused(self):
        p=copy.deepcopy(self.profile);p["prepared_model"]["velocity_gains"][0]*=2
        with self.assertRaises(ValueError):Policy(self.core,p,DLL)

    def test_06_authority_and_origin_refused(self):
        for key in ("trained","physical_acceptance_authority","tier2_qualified","cross_engine_equivalence","model_origin"):
            p=copy.deepcopy(self.profile);p[key]=True
            with self.assertRaises(ValueError):Policy(self.core,p,DLL)

    def test_07_wrong_kernel_refused(self):
        p=copy.deepcopy(self.profile);p["kernel_sha256"]="0"*64
        with self.assertRaises(ValueError):Policy(self.core,p,DLL)

    def test_08_crossed_request_identity_refused(self):
        for key in ("provider_id","expected_provider_version","expected_model_id","expected_model_sha256","expected_training_corpus_id"):
            r=copy.deepcopy(self.request);r[key]="other"
            with self.assertRaises(ValueError):self.policy.respond(r)

    def test_09_wrong_clock_episode_refused(self):
        for change in ("step","request","sequence"):
            r=copy.deepcopy(self.request)
            if change=="step":r["state"]["semantic_step"]=61
            elif change=="request":r["request_id"]="predictive_other_60"
            else:r["provider_memory"]["sequence"]=1
            with self.assertRaises(ValueError):self.policy.respond(r)

    def test_10_mutated_memory_digest_refused(self):
        r=copy.deepcopy(self.request);r["provider_memory"]["opaque_state"]["last_step"]=58
        with self.assertRaises(ValueError):self.policy.respond(r)

    def test_11_missing_history_refused(self):
        r=copy.deepcopy(self.request);r["history"]["ordered_entries"]=[]
        with self.assertRaises(ValueError):self.policy.respond(r)

    def test_12_changed_actual_correction_refused(self):
        r=copy.deepcopy(self.request);r["safety_envelope"]["ordered_actuator_limits"][0]["previous_applied_correction_rad_s"]+=.01
        with self.assertRaises(ValueError):self.policy.respond(r)

    def test_13_crossed_model_context_refused(self):
        r=copy.deepcopy(self.request);host=r["controller_context"]["controller_memory"]
        host["prepared_model_sha256"]="0"*64;r["controller_context"]["controller_memory_sha256"]=digest(self.core,host)
        with self.assertRaises(ValueError):self.policy.respond(r)

    def test_14_forbidden_request_authority_refused(self):
        for key in ("provider_may_build_worlds","provider_may_modify_physics_state","provider_has_physical_acceptance_authority"):
            r=copy.deepcopy(self.request);r[key]=True
            with self.assertRaises(ValueError):self.policy.respond(r)

    def test_15_no_xml_or_simulator_at_provider_runtime(self):
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No native access")))
            guards.enter_context(patch("xml.etree.ElementTree.fromstring",side_effect=AssertionError("No runtime XML")))
            self.policy=Policy(self.core,self.profile,DLL);self.resolve()

    def test_16_engine_specific_response_still_rejected(self):
        response,_,_=self.resolve();response["provenance"]["engine_specific_logic_used"]=True
        r=self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=self.request,provider_response=response))
        self.assertEqual(r["fallback_reason"],"invalid_provider_response")
        self.assertTrue(all(x["applied_correction_rad_s"]==0. for x in r["ordered_commands"]))

    def test_17_selected_history_binds_actual_external_request(self):
        response,_,r=self.resolve();following,boundary=history.append_resolved(self.core,self.request,r)
        self.assertIsNone(boundary);following["ordered_entries"]=following["ordered_entries"][-1:]
        current=self.policy.bind(self.rows[61]["resolution_request"]["provider_request"],self.rows[61]["stability"],
            r["next_memory"],"predictive_test")
        for limit,applied in zip(current["safety_envelope"]["ordered_actuator_limits"],r["ordered_commands"],strict=True):
            limit["previous_applied_correction_rad_s"]=applied["applied_correction_rad_s"]
        current=history.attach(current,following);_,d,second=self.resolve(current)
        self.assertEqual(second["provider_status"],"applied")
        self.assertEqual(d["starting_packet"]["previous_correction"],[x["applied_correction_rad_s"] for x in r["ordered_commands"]])
        self.assertEqual(response["next_memory"]["opaque_state"]["nominal_memory"]["opaque_state"]["previous_binding"],digest(self.core,self.request))

    def test_18_internal_nominal_binding_cannot_replace_actual_history(self):
        _,d,r=self.resolve();m=copy.deepcopy(r["next_memory"])
        m["opaque_state"]["nominal_memory"]["opaque_state"]["previous_binding"]=d["nominal_request_sha256"]
        m["opaque_state"]["nominal_memory"]["opaque_state_sha256"]=digest(self.core,m["opaque_state"]["nominal_memory"]["opaque_state"])
        m["opaque_state_sha256"]=digest(self.core,m["opaque_state"])
        current=self.policy.bind(self.rows[61]["resolution_request"]["provider_request"],self.rows[61]["stability"],m,"predictive_test")
        following,_=history.append_resolved(self.core,self.request,r);following["ordered_entries"]=following["ordered_entries"][-1:]
        current=history.attach(current,following)
        with self.assertRaises(ValueError):self.policy.respond(current)

    def test_19_safe_no_actuation_stops_before_planning(self):
        r=copy.deepcopy(self.request);r["deterministic_baseline"]["safe_no_actuation"]=True
        with patch.object(self.policy.nominal,"respond",side_effect=AssertionError("No nominal planning")):
            with self.assertRaises(PredictiveRefusal) as error:self.policy.respond(r)
        self.assertEqual(error.exception.decision["stage"],"safe_no_actuation")

    def test_20_nominal_refusal_preserved(self):
        from hierarchical_force_policy_v8 import HierarchyRefusal
        detail=dict(allocation=dict(accepted=False))
        with patch.object(self.policy.nominal,"respond",side_effect=HierarchyRefusal(detail)):
            with self.assertRaises(PredictiveRefusal) as error:self.policy.respond(self.request)
        self.assertEqual(error.exception.decision["stage"],"nominal_refusal")
        self.assertEqual(error.exception.decision["nominal"],detail)

    def test_21_selector_refusal_has_no_response(self):
        refused=dict(accepted=False,selected_index=None,reason="no_eligible_candidate",candidates=[])
        with patch.object(self.policy.selector,"select_canonical",return_value=refused):
            with self.assertRaises(PredictiveRefusal) as error:self.policy.respond(self.request)
        self.assertEqual(error.exception.decision["selection"],refused)
        with patch.object(self.policy.selector,"select_canonical",side_effect=ValueError("numerical domain")):
            with self.assertRaises(PredictiveRefusal) as error:self.policy.respond(self.request)
        self.assertEqual(error.exception.decision["stage"],"selection_error")
        self.assertIsNotNone(error.exception.decision["nominal"])

    def test_22_full_host_prefix_and_two_selected_history_entries(self):
        host=self.host()
        try:
            self.handoff(host);first=self.step(host,60);second=self.step(host,61)
            self.assertIsNone(terminal_error(second))
            previous=second["resolution_request"]["provider_request"]["history"]["ordered_entries"]
            self.assertEqual(len(previous),1);self.assertEqual(previous[0]["request_sha256"],first["resolution"]["request_sha256"])
            self.assertEqual(previous[0]["ordered_applied_corrections"],[
                dict(actuator_id=x["actuator_id"],canonical_velocity_delta_rad_s=x["applied_correction_rad_s"])
                for x in first["resolution"]["ordered_commands"]])
            self.assertEqual(host.next_step,62)
        finally:host.close()

    def test_23_terminal_selector_refusal_prevents_native_transfer(self):
        host=self.host();data=SimpleNamespace(ctrl=np.zeros(8))
        try:
            self.handoff(host)
            with patch.object(host.force_policy.selector,"select_canonical",return_value=dict(accepted=False)):
                row=self.step(host,60)
            self.assertTrue(host.closed);self.assertIsNotNone(terminal_error(row))
            self.assertFalse(row["predictive_hold"]["actual_resolved_history_continues"])
            self.assertEqual(host.history["ordered_entries"],[])
            with self.assertRaises(ValueError):transfer_targets(row,data)
            np.testing.assert_array_equal(data.ctrl,np.zeros(8))
        finally:host.close()

    def test_24_core_projection_mismatch_stops_transfer(self):
        host=self.host();data=SimpleNamespace(ctrl=np.zeros(8))
        try:
            self.handoff(host);original=host.force_policy.respond
            def altered(request):
                response,decision=original(request);response["ordered_corrections"][0]["canonical_velocity_delta_rad_s"]+=.005
                return response,decision
            with patch.object(host.force_policy,"respond",side_effect=altered):row=self.step(host,60)
            self.assertTrue(host.closed);self.assertEqual(terminal_error(row)["type"],"PredictiveResolutionMismatch")
            with self.assertRaises(ValueError):transfer_targets(row,data)
        finally:host.close()

    def test_25_valid_selected_native_transfer_is_exact(self):
        host=self.host();data=SimpleNamespace(ctrl=np.zeros(8))
        try:
            self.handoff(host);row=self.step(host,60);transfer_targets(row,data)
            np.testing.assert_array_equal(data.ctrl,row["native_targets"])
        finally:host.close()

    def test_26_host_exception_closes_session(self):
        host=self.host()
        try:
            self.handoff(host)
            with patch.object(host.force_policy,"respond",side_effect=RuntimeError("diagnostic exception")):
                row=self.step(host,60)
            self.assertTrue(host.closed);self.assertEqual(terminal_error(row)["type"],"RuntimeError")
        finally:host.close()

    def test_27_current_measured_load_not_consumed(self):
        _,d,_=self.resolve();r=copy.deepcopy(self.request)
        for item in r["state"]["ordered_contact_observations"]:item["normal_load_n"]=99999.
        _,changed=self.policy.respond(r)
        self.assertEqual(d["selection"],changed["selection"])

    def test_28_prepared_state_clock_refusal_reaches_host(self):
        host=self.host()
        try:
            self.handoff(host);old=copy.deepcopy(self.rows[60])
            old["request"]["state"]["sample_time_s"]+=.01
            row=host.step(old["request"]["state"],old["stability"],old["kinematics"])
            self.assertTrue(host.closed);self.assertIsNotNone(terminal_error(row))
        finally:host.close()


if __name__=="__main__":unittest.main()
