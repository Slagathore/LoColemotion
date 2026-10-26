"""Public refusal fallback, truthful memory, bounds and transfer controls."""
import copy
from itertools import islice
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import mujoco
import numpy as np
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_sequence_seed_diagnostic_v3 import inputs,EVIDENCE,ORIGINAL,DLL,DLL_SHA,read
from audit_gpu_batch_execution import read_jsonl
from contact_force_observer_task import bridge
from hold_horizon_task import controller_contract,frozen_model,declaration
from predictive_sequence_policy_v4 import Policy,make_profile,digest,PROVIDER,VERSION,CONTEXT,MEMORY,PredictiveRefusal
from predictive_sequence_control_v4 import PredictiveSequenceController,terminal_error,transfer_targets
from predictive_sequence_row_audit_v4 import verify_row
from predictive_history_seed_v1 import STRATEGY,prepare,reference
from hierarchical_force_policy_v8 import HierarchyRefusal
from predictive_sequence_online_v2 import warm_knots,select
from predictive_sequence_v1 import commands
from test_predictive_sequence_v1 import SyntheticSelector


class FallbackControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.original,old,_=inputs();cls.profile=make_profile(old["nominal_profile"],old["prepared_model"],DLL_SHA)
        cls.rows=list(islice(read_jsonl(ORIGINAL/"controller.jsonl"),70));cls.compiled=read(ORIGINAL/"compiled.json")
        cls.model=frozen_model(cls.core);cls.contract=controller_contract(declaration(),cls.model)
        cls.proved=read(EVIDENCE/"sdk2-sequence-seed-diagnostic-v3-a78f0fa2d5df4b90961dbbc68ed35dd6"/"audit-capture/diagnosis.json")["selection"]
    def setUp(self):
        self.policy=Policy(self.core,self.profile,DLL);r=copy.deepcopy(self.original["resolution_request"]["provider_request"])
        r.update(provider_id=PROVIDER,expected_provider_version=VERSION,expected_model_id=self.policy.model_id,
            expected_model_sha256=self.policy.sha)
        m=r["provider_memory"];m["provider_id"]=PROVIDER;o=m["opaque_state"]
        o.update(schema_version=MEMORY,model_sha256=self.policy.sha,last_nominal_allocation_accepted=True)
        m["opaque_state_sha256"]=digest(self.core,o)
        c=r["controller_context"];h=c["controller_memory"]
        h.update(schema_version=CONTEXT,profile_sha256=self.policy.sha,prepared_model_sha256=self.policy.prepared_sha)
        c.update(controller_memory_schema_version=CONTEXT,controller_memory_sha256=digest(self.core,h))
        self.request=r
    def failure(self,policy,request):
        # Protocol fixture: the real numerical refusal/forecast is reconstructed
        # by the retained owner. Other synthetic requests reuse its refused
        # allocation only to isolate the outer provider's state transitions.
        d=copy.deepcopy(self.original["force_reference"]["decision"]["nominal"])
        target,ref=reference(policy.nominal,request)
        d.update(step=request["state"]["semantic_step"],profile_sha256=policy.nominal.sha,
            request_sha256=digest(self.core,request),target_com=target,support_reference=ref)
        return d
    def refuse(self,policy,request):
        raise HierarchyRefusal(self.failure(policy,request))
    def admit(self,selector,value,plan):
        # No physics claim: this fixture isolates public protocol and memory.
        knots=warm_knots(value,plan);correction,target=commands(value,knots,66)
        return dict(accepted=True,best=dict(option=dict(knots=knots)),
            selected_correction=correction[0],selected_target=target[0])
    def respond(self,request=None,proved=False):
        request=self.request if request is None else request
        with patch.object(self.policy.nominal,"respond",side_effect=lambda r:self.refuse(self.policy,r)):
            with patch("predictive_sequence_policy_v4.select",return_value=copy.deepcopy(self.proved)) if proved else                     patch("predictive_sequence_policy_v4.select",side_effect=self.admit):
                return self.policy.respond(request)
    def resolve(self,request,response):
        return self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=response))
    def following(self,resolved):
        m=resolved["next_memory"];episode=m["opaque_state"]["episode_id"]
        r=self.policy.bind(self.rows[69]["resolution_request"]["provider_request"],self.rows[69]["stability"],m,episode)
        entries,boundary=history.append_resolved(self.core,self.request,resolved);self.assertIsNone(boundary)
        entries["ordered_entries"]=entries["ordered_entries"][-1:]
        for limit,applied in zip(r["safety_envelope"]["ordered_actuator_limits"],resolved["ordered_commands"],strict=True):
            limit["previous_applied_correction_rad_s"]=applied["applied_correction_rad_s"]
        return history.attach(r,entries)
    def host(self):
        h=PredictiveSequenceController(self.core,self.compiled,self.contract,self.model,"fallback_host",self.profile,DLL)
        self.addCleanup(h.close);previous=None
        for i in range(60):
            previous=self.step(h,i);self.assertEqual(previous["native_targets"],self.rows[i]["native_targets"])
        return h,previous
    def step(self,h,i):
        old=self.rows[i]
        return h.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
    def test_01_profile_strategy_and_source_binding(self):
        for field in ("nominal_refusal_strategy","trained","source_bindings"):
            p=copy.deepcopy(self.profile)
            if field=="source_bindings":p[field]["predictive_history_seed_v1.py"]="0"*64
            else:p[field]="other" if field=="nominal_refusal_strategy" else True
            with self.assertRaises(ValueError):Policy(self.core,p,DLL)
    def test_02_wrong_public_identity_refused(self):
        for field in ("provider_id","expected_provider_version","expected_model_sha256"):
            r=copy.deepcopy(self.request);r[field]="other"
            with self.assertRaises(ValueError):self.respond(r)
    def test_03_verified_command68_forecast_applies_exactly(self):
        response,d=self.respond(proved=True);r=self.resolve(self.request,response)
        self.assertEqual(r["provider_status"],"applied")
        self.assertEqual([x["final_canonical_target_velocity_rad_s"] for x in r["ordered_commands"]],self.proved["selected_target"])
        self.assertFalse(d["proposal"]["nominal_allocation_available"])
    def test_04_original_refusal_preserved_without_certificate(self):
        response,d=self.respond()
        self.assertEqual(d["nominal"],self.failure(self.policy,self.policy.nominal_request(self.request)))
        self.assertEqual(d["proposal"]["kind"],STRATEGY)
        self.assertFalse(d["proposal"]["force_certificate_for_selected_sequence"])
        self.assertFalse(response["provenance"]["weights_mutated"])
    def test_05_changed_geometric_reference_refused(self):
        internal=self.policy.nominal_request(self.request)
        for field in ("target_com","support_reference"):
            d=self.failure(self.policy,internal)
            if field=="target_com":d[field][0]+=.01
            else:d[field]["reference_joint_positions_rad"][0]+=.01
            with self.assertRaises(ValueError):prepare(self.policy.nominal,internal,d)
    def test_06_accepted_or_incomplete_allocation_is_not_refusal(self):
        internal=self.policy.nominal_request(self.request)
        for field in ("accepted","selected","missing"):
            d=self.failure(self.policy,internal)
            if field=="missing":d["allocation"]={}
            else:d["allocation"][field]=True if field=="accepted" else {}
            with self.assertRaises(ValueError):prepare(self.policy.nominal,internal,d)
    def test_07_crossed_nominal_refusal_identity(self):
        internal=self.policy.nominal_request(self.request)
        for field in ("step","profile_sha256","request_sha256","physical_acceptance_authority"):
            d=self.failure(self.policy,internal);d[field]=True if field=="physical_acceptance_authority" else 67 if field=="step" else "other"
            with self.assertRaises(ValueError):prepare(self.policy.nominal,internal,d)
    def test_08_other_errors_do_not_enter_fallback(self):
        with patch.object(self.policy.nominal,"respond",side_effect=ValueError("invalid request")):
            with patch("predictive_sequence_policy_v4.select",side_effect=AssertionError("No forecast")):
                with self.assertRaisesRegex(ValueError,"invalid request"):self.policy.respond(self.request)
    def test_09_safe_no_actuation_prevents_nominal_and_forecast(self):
        r=copy.deepcopy(self.request);r["deterministic_baseline"]["safe_no_actuation"]=True
        with patch.object(self.policy.nominal,"respond",side_effect=AssertionError("No nominal solve")):
            with self.assertRaises(PredictiveRefusal) as e:self.policy.respond(r)
        self.assertEqual(e.exception.decision["stage"],"safe_no_actuation")
    def test_10_failed_forecast_has_no_response_or_memory_mutation(self):
        before=copy.deepcopy(self.request)
        with patch.object(self.policy.nominal,"respond",side_effect=lambda r:self.refuse(self.policy,r)):
            with patch("predictive_sequence_policy_v4.select",return_value=dict(accepted=False)):
                with self.assertRaises(PredictiveRefusal) as e:self.policy.respond(self.request)
        self.assertEqual(before,self.request);self.assertFalse(e.exception.decision["nominal"]["allocation"]["accepted"])
    def test_11_numerical_refusal_retains_original_nominal_refusal(self):
        with patch.object(self.policy.nominal,"respond",side_effect=lambda r:self.refuse(self.policy,r)):
            with patch("predictive_sequence_policy_v4.select",side_effect=ValueError("forecast domain")):
                with self.assertRaises(PredictiveRefusal) as e:self.policy.respond(self.request)
        self.assertEqual(e.exception.decision["stage"],"selection_error")
        self.assertFalse(e.exception.decision["proposal"]["nominal_allocation_available"])
    def test_12_nominal_success_remains_identified(self):
        h,_=self.host()
        with patch("predictive_sequence_policy_v4.select",side_effect=self.admit):row=self.step(h,60)
        self.assertIsNone(terminal_error(row));d=row["force_reference"]["decision"]
        self.assertTrue(d["proposal"]["nominal_allocation_available"])
        self.assertTrue(row["resolution"]["next_memory"]["opaque_state"]["last_nominal_allocation_accepted"])
    def test_13_fallback_memory_is_truthful_and_actual(self):
        response,d=self.respond();r=self.resolve(self.request,response);o=r["next_memory"]["opaque_state"]
        self.assertFalse(o["last_nominal_allocation_accepted"])
        self.assertEqual(o["nominal_memory"]["opaque_state"]["previous_forces"],{})
        self.assertEqual(o["nominal_memory"]["opaque_state"]["target_com"],d["nominal"]["target_com"])
        self.assertEqual(o["nominal_memory"]["opaque_state"]["previous_binding"],r["request_sha256"])
    def test_14_following_request_uses_resolved_fallback_memory(self):
        response,_=self.respond();r=self.resolve(self.request,response);following=self.following(r)
        response,d=self.respond(following);r2=self.resolve(following,response)
        self.assertEqual(r2["provider_status"],"applied")
        self.assertEqual(response["next_memory"]["sequence"],10)
        self.assertEqual(d["starting_packet"]["previous_correction"],[x["applied_correction_rad_s"] for x in r["ordered_commands"]])
    def test_15_fabricated_nominal_forces_after_refusal_rejected(self):
        response,_=self.respond();r=self.resolve(self.request,response);following=self.following(r)
        m=following["provider_memory"];inner=m["opaque_state"]["nominal_memory"]
        inner["opaque_state"]["previous_forces"]={"invented":[1.,0.,0.]}
        inner["opaque_state_sha256"]=digest(self.core,inner["opaque_state"]);m["opaque_state_sha256"]=digest(self.core,m["opaque_state"])
        with self.assertRaises(ValueError):self.policy.nominal_request(following)
    def test_16_missing_or_mistyped_allocation_status_rejected(self):
        for value in (None,"false",0):
            r=copy.deepcopy(self.request);m=r["provider_memory"];m["opaque_state"]["last_nominal_allocation_accepted"]=value
            m["opaque_state_sha256"]=digest(self.core,m["opaque_state"])
            with self.assertRaises(ValueError):self.policy.nominal_request(r)
    def test_17_crossed_plan_binding_refused(self):
        r=copy.deepcopy(self.request);m=r["provider_memory"];m["opaque_state"]["plan"]["request_sha256"]="sha256:"+"0"*64
        m["opaque_state_sha256"]=digest(self.core,m["opaque_state"])
        with self.assertRaises(ValueError):self.respond(r)
    def test_18_history_correction_mismatch_refused(self):
        r=copy.deepcopy(self.request);r["history"]["ordered_entries"][0]["ordered_applied_corrections"][0]["canonical_velocity_delta_rad_s"]+=.01
        with self.assertRaises(ValueError):self.respond(r)
    def test_19_current_envelope_cannot_expand(self):
        r=copy.deepcopy(self.request);r["safety_envelope"]["ordered_actuator_limits"][0]["maximum_slew_per_step_rad_s"]=.09
        with self.assertRaises(ValueError):self.respond(r)
    def test_20_host_prefix_and_public_transfer(self):
        h,_=self.host()
        with patch("predictive_sequence_policy_v4.select",side_effect=self.admit):row=self.step(h,60)
        data=SimpleNamespace(ctrl=np.zeros(8));transfer_targets(row,data)
        np.testing.assert_array_equal(data.ctrl,row["native_targets"])
    def test_21_host_fallback_refusal_closes_before_transfer(self):
        h,_=self.host();data=SimpleNamespace(ctrl=np.zeros(8))
        with patch.object(h.force_policy.nominal,"respond",side_effect=lambda r:self.refuse(h.force_policy,r)):
            with patch("predictive_sequence_policy_v4.select",return_value=dict(accepted=False)):row=self.step(h,60)
        self.assertTrue(h.closed)
        with self.assertRaises(ValueError):transfer_targets(row,data)
        np.testing.assert_array_equal(data.ctrl,np.zeros(8))
    def test_22_host_projection_mismatch_prevents_transfer(self):
        h,_=self.host();original=h.force_policy.respond
        def altered(request):
            response,d=original(request);response["ordered_corrections"][0]["canonical_velocity_delta_rad_s"]+=.005
            return response,d
        with patch("predictive_sequence_policy_v4.select",side_effect=self.admit):
            with patch.object(h.force_policy,"respond",side_effect=altered):row=self.step(h,60)
        self.assertTrue(h.closed);self.assertIsNotNone(terminal_error(row))
        with self.assertRaises(ValueError):transfer_targets(row,SimpleNamespace(ctrl=np.zeros(8)))
    def test_23_runtime_needs_no_native_api_or_xml(self):
        from contextlib import ExitStack
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No native access")))
            for name in ("fromstring","parse"):
                guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("No runtime XML")))
            self.respond(proved=True)
    def test_24_reader_reconstructs_fallback_and_rejects_false_memory(self):
        h,previous=self.host()
        with patch.object(h.force_policy.nominal,"respond",side_effect=lambda r:self.refuse(h.force_policy,r)):
            with patch("predictive_sequence_policy_v4.select",side_effect=lambda _,v,p:select(SyntheticSelector(),v,p)):
                row=self.step(h,60)
        self.assertIsNone(terminal_error(row))
        verify_row(self.core,row,previous,self.rows[60],self.profile,SyntheticSelector())
        for kind in ("refusal","target","status","forces"):
            bad=copy.deepcopy(row)
            if kind=="refusal":bad["force_reference"]["decision"]["nominal"]["allocation"]["accepted"]=True
            elif kind=="target":bad["force_reference"]["decision"]["proposal"]["projection"]["target"][0]+=.01
            else:
                m=bad["resolution_request"]["provider_response"]["next_memory"];o=m["opaque_state"]
                if kind=="status":o["last_nominal_allocation_accepted"]=True
                else:
                    inner=o["nominal_memory"];inner["opaque_state"]["previous_forces"]={"invented":[1.,0.,0.]}
                    inner["opaque_state_sha256"]=digest(self.core,inner["opaque_state"])
                m["opaque_state_sha256"]=digest(self.core,o)
                bad["resolution"]=self.core.resolve_adaptation_v1(bad["resolution_request"])
            with self.assertRaises(ValueError):
                verify_row(self.core,bad,previous,self.rows[60],self.profile,SyntheticSelector())

    def test_25_refinement_strategy_and_source_bound(self):
        for kind in ("strategy","source"):
            profile=copy.deepcopy(self.profile)
            if kind=="strategy":profile["sequence_refinement_strategy"]="other"
            else:profile["source_bindings"]["predictive_sequence_refinement_v1.py"]="0"*64
            with self.assertRaises(ValueError):Policy(self.core,profile,DLL)

    def test_26_following_fixture_preserves_actual_resolution(self):
        from predictive_sequence_following_request_v1 import following_request
        response,_=self.respond(proved=True);resolved=self.resolve(self.request,response)
        row=dict(resolution_request=dict(provider_request=self.request),resolution=resolved)
        fixture=following_request(self.core,self.policy,row,self.rows[69])
        self.assertEqual(fixture["request"],self.following(resolved))
        self.assertTrue(fixture["synthetic_protocol_fixture"])
        self.assertFalse(fixture["native_continuation_verified"])
        self.assertFalse(fixture["observation_generated_by_refined_action"])

    def test_27_following_fixture_wrong_clock_refused(self):
        from predictive_sequence_following_request_v1 import following_request
        response,_=self.respond();resolved=self.resolve(self.request,response)
        row=dict(resolution_request=dict(provider_request=self.request),resolution=resolved)
        with self.assertRaises(ValueError):following_request(self.core,self.policy,row,self.rows[68])

    def test_28_following_fixture_forged_plan_refused(self):
        from predictive_sequence_following_request_v1 import following_request
        response,_=self.respond();resolved=self.resolve(self.request,response)
        resolved["next_memory"]["opaque_state"]["plan"]["correction"][0]+=.01
        row=dict(resolution_request=dict(provider_request=self.request),resolution=resolved)
        with self.assertRaises(ValueError):following_request(self.core,self.policy,row,self.rows[69])


class RefinementControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import predictive_sequence_refinement_v1 as refinement
        from test_predictive_sequence_v1 import synthetic_value
        cls.value=synthetic_value()
        # Deliberate protocol fixture: original numerical reconstruction is
        # covered by the retained owner, not claimed by this synthetic parent.
        cls.original=dict(accepted=False,horizon=66,evaluated_candidates=102,
            best=dict(option=dict(knots=[[0.]*8 for _ in range(4)]),result=dict(eligible=False)))
        with patch.object(refinement,"original_select",return_value=cls.original):
            cls.selection=refinement.select(SyntheticSelector(),cls.value,None)

    def verify(self,selection):
        from predictive_sequence_refinement_audit_v1 import verify_selection
        with patch("predictive_sequence_refinement_audit_v1.verify_original",return_value=None):
            return verify_selection(selection,self.value,None,SyntheticSelector())

    def test_01_accepted_original_is_returned_unchanged(self):
        import predictive_sequence_refinement_v1 as refinement
        original=dict(accepted=True,sentinel="unchanged")
        with patch.object(refinement,"original_select",return_value=original):
            with patch.object(refinement,"search",side_effect=AssertionError("No refinement")):
                self.assertIs(refinement.select(None,None,None),original)

    def test_02_original_error_does_not_enter_refinement(self):
        import predictive_sequence_refinement_v1 as refinement
        with patch.object(refinement,"original_select",side_effect=ValueError("original invalid")):
            with patch.object(refinement,"search",side_effect=AssertionError("No refinement")):
                with self.assertRaisesRegex(ValueError,"original invalid"):refinement.select(None,None,None)

    def test_03_refinement_denominator_and_first_command(self):
        selected=self.selection;result=selected["refinement"]["result"]
        self.assertEqual(selected["evaluated_candidates"],418)
        self.assertEqual(len(selected["refinement"]["evaluations"]),316)
        self.assertTrue(selected["accepted"])
        self.assertEqual(selected["selected_target"],result["best"]["result"]["rows"][0]["target"])
        self.assertEqual(selected["original"],self.original)

    def test_04_failed_refinement_has_no_selected_action(self):
        import predictive_sequence_refinement_v1 as refinement
        value=copy.deepcopy(self.value);value["qpos"][2]=.1
        with patch.object(refinement,"original_select",return_value=self.original):
            selected=refinement.select(SyntheticSelector(),value,None)
        self.assertFalse(selected["accepted"]);self.assertIsNone(selected["selected_target"])
        self.assertIsNone(selected["selected_correction"])

    def test_05_complete_refinement_reader(self):
        self.assertIsNone(self.verify(self.selection))

    def test_06_candidate_guard_order_and_unknown_field_refused(self):
        for kind in ("order","guard","unknown"):
            selected=copy.deepcopy(self.selection)
            if kind=="unknown":selected["future_observation"]=[]
            else:
                record=selected["refinement"]["evaluations"][0]
                if kind=="order":record["option"]["index"]=9
                else:record["result"]["rows"][0]["guard_reasons"]=["tilt"]
            with self.assertRaises(ValueError):self.verify(selected)

    def test_07_false_admission_incomplete_capture_and_target_refused(self):
        for kind in ("accepted_parent","truncated","target"):
            selected=copy.deepcopy(self.selection)
            if kind=="accepted_parent":selected["original"]["accepted"]=True
            elif kind=="truncated":selected["refinement"]["evaluations"]=selected["refinement"]["evaluations"][:-1]
            else:selected["selected_target"][0]+=.01
            with self.assertRaises(ValueError):self.verify(selected)

    def test_08_unwrapped_original_uses_original_verifier(self):
        from predictive_sequence_refinement_audit_v1 import verify_selection
        value=dict(accepted=True)
        with patch("predictive_sequence_refinement_audit_v1.verify_original",return_value={"verified":True}) as old:
            self.assertEqual(verify_selection(value,None,None,None),{"verified":True})
            old.assert_called_once_with(value,None,None,None,None)


if __name__=="__main__":unittest.main()
