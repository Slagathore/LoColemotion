"""Model, chronology, causal-input and public-resolver controls; zero worlds."""
import copy
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import numpy as np
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import read_jsonl
from contact_force_observer_task import ROOT,read,bridge,controller_contract,frozen_model,declaration
from causal_force_policy import Policy,make_profile,digest,PROVIDER,HANDOFF
from causal_force_control import ForceController,terminal_error


def fixture():
    closure=read(ROOT/"sdk/discovery/contact_force_observer_closure_v1.json")
    folder=ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical/observer_on_left_075_train_001"
    return read(folder/"compiled.json"),read(folder/"inputs.json"),list(read_jsonl(folder/"controller.jsonl"))


class ForcePolicyControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.compiled,cls.inputs,cls.rows=fixture()
        cls.profile=make_profile(cls.compiled,cls.inputs)

    def setUp(self):
        self.policy=Policy(self.core,self.profile)
        self.request=self.policy.bind(self.rows[HANDOFF]["resolution_request"]["provider_request"],
            self.rows[HANDOFF]["stability"],self.policy.memory("synthetic_policy_control"),"synthetic_policy_control")

    def resolve(self,request):
        response,detail=self.policy.respond(request)
        resolved=self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=response))
        return response,detail,resolved

    def test_real_core_accepts_new_provider_and_exact_projection(self):
        response,detail,resolved=self.resolve(self.request)
        self.assertEqual(resolved["provider_status"],"applied")
        self.assertEqual([r["final_canonical_target_velocity_rad_s"] for r in resolved["ordered_commands"]],detail["projection"]["target"])
        self.assertEqual(response["provenance"]["provider_id"],PROVIDER)

    def test_two_contact_support_returns_explicit_residual(self):
        _,detail,_=self.resolve(self.request)
        self.assertEqual(len(detail["active_contacts"]),2)
        self.assertEqual(detail["allocation"]["wrench_map_rank"],5)
        self.assertFalse(detail["allocation"]["dynamic_feasibility_established"])

    def test_force_cones_and_reachable_motor_intervals(self):
        _,d,_=self.resolve(self.request)
        for x,y,z in d["allocation"]["forces"]:
            self.assertGreaterEqual(y,0.);self.assertLessEqual(y,70.)
            self.assertLessEqual(np.hypot(x,z),.95*y+1e-12)
        for low,value,high in zip(d["projection"]["lower_torque"],d["projection"]["predicted_torque"],d["projection"]["upper_torque"]):
            self.assertLessEqual(low-1e-12,value);self.assertLessEqual(value,high+1e-12)

    def test_inputs_and_model_are_not_mutated(self):
        before=copy.deepcopy(self.request);self.resolve(self.request)
        self.assertEqual(before,self.request)
        original=self.policy.sha;self.profile_copy=copy.deepcopy(self.profile)
        policy=Policy(self.core,self.profile_copy);self.profile_copy["parameters"]["iterations"]=1
        self.assertEqual(policy.sha,original);self.assertEqual(policy.p["iterations"],80)

    def test_current_measured_load_is_unused(self):
        _,d,_=self.resolve(self.request);other=copy.deepcopy(self.request)
        for r in other["state"]["ordered_contact_observations"]:r["normal_load_n"]=12345.
        _,changed=self.policy.respond(other)
        self.assertEqual(d,changed)

    def test_profile_source_tampering_refused(self):
        profile=copy.deepcopy(self.profile);profile["source_bindings"]["causal_force_policy.py"]="0"*64
        with self.assertRaisesRegex(ValueError,"implementation"):Policy(self.core,profile)

    def test_profile_authority_escalation_refused(self):
        for key in ("trained","tier2_qualified","held_interval_force_guaranteed"):
            profile=copy.deepcopy(self.profile);profile[key]=True
            with self.assertRaises(ValueError):Policy(self.core,profile)

    def test_stale_future_or_restarted_sequence_refused(self):
        for step in (59,61,True):
            changed=copy.deepcopy(self.request);changed["state"]["semantic_step"]=step
            with self.assertRaises(ValueError):self.policy.respond(changed)

    def test_crossed_episode_and_model_refused(self):
        for key,value in (("request_id","force_other_60"),("expected_model_sha256","sha256:"+"0"*64)):
            changed=copy.deepcopy(self.request);changed[key]=value
            with self.assertRaises(ValueError):self.policy.respond(changed)

    def test_contact_context_hash_and_clock_refused(self):
        for key,value in (("semantic_step",61),("sample_time_s",.49)):
            changed=copy.deepcopy(self.request)
            host=changed["controller_context"]["controller_memory"];host["contact_packet"][key]=value
            changed["controller_context"]["controller_memory_sha256"]=digest(self.core,host)
            with self.assertRaises(ValueError):self.policy.respond(changed)
        changed=copy.deepcopy(self.request);changed["controller_context"]["controller_memory_sha256"]="sha256:"+"0"*64
        with self.assertRaises(ValueError):self.policy.respond(changed)

    def test_missing_actual_history_refused(self):
        changed=copy.deepcopy(self.request);changed["history"]["ordered_entries"]=[]
        with self.assertRaises(ValueError):self.policy.respond(changed)

    def test_proposal_history_cannot_replace_resolved_correction(self):
        changed=copy.deepcopy(self.request)
        changed["safety_envelope"]["ordered_actuator_limits"][0]["previous_applied_correction_rad_s"]+=.001
        with self.assertRaisesRegex(ValueError,"preceding corrections"):self.policy.respond(changed)

    def test_next_request_continues_actual_resolution_and_target(self):
        _,detail,resolved=self.resolve(self.request)
        following,boundary=history.append_resolved(self.core,self.request,resolved)
        self.assertIsNone(boundary);following["ordered_entries"]=following["ordered_entries"][-1:]
        row=self.rows[61]
        request=self.policy.bind(row["resolution_request"]["provider_request"],row["stability"],resolved["next_memory"],"synthetic_policy_control")
        for limit,command in zip(request["safety_envelope"]["ordered_actuator_limits"],resolved["ordered_commands"]):
            limit["previous_applied_correction_rad_s"]=command["applied_correction_rad_s"]
        request=history.attach(request,following)
        _,next_detail,next_resolution=self.resolve(request)
        self.assertEqual(next_resolution["provider_status"],"applied")
        self.assertEqual(next_detail["target_com"],detail["target_com"])
        request["history"]["ordered_entries"][0]["request_sha256"]="sha256:"+"0"*64
        with self.assertRaisesRegex(ValueError,"previous resolved"):self.policy.respond(request)

    def test_absent_support_does_not_invent_force(self):
        request=copy.deepcopy(self.request)
        host=request["controller_context"]["controller_memory"]
        for r in host["contact_packet"]["ordered_contacts"]:r.update(presence=False,bears_support=False,point_world_m=None,normal_world_unit=None)
        for r in request["state"]["ordered_contact_observations"]:r.update(presence=False,bears_support=False)
        request["controller_context"]["controller_memory_sha256"]=digest(self.core,host)
        _,detail=self.policy.respond(request)
        self.assertEqual(detail["allocation"]["forces"],[])
        self.assertGreater(np.linalg.norm(detail["allocation"]["wrench_error"]),0.)

    def test_host_retains_exact_prefix_and_continuous_handoff(self):
        model=frozen_model(self.core)
        host=ForceController(self.core,self.compiled,controller_contract(declaration(),model),model,"synthetic_host_control",self.profile)
        try:
            for i,original in enumerate(self.rows[:62]):
                row=host.step(copy.deepcopy(original["request"]["state"]),copy.deepcopy(original["stability"]),copy.deepcopy(original["kinematics"]))
                self.assertIsNone(terminal_error(row))
                if i<HANDOFF:self.assertEqual(row["native_targets"],original["native_targets"])
                else:
                    self.assertEqual(row["force_reference"]["handoff_command"],60)
                    self.assertEqual(row["resolution_request"]["provider_request"]["history"]["ordered_entries"][-1]["semantic_step"],i-1)
                self.assertEqual(host.previous,[r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]])
            with self.assertRaises(ValueError):host.step(self.rows[61]["request"]["state"],self.rows[61]["stability"],self.rows[61]["kinematics"])
            self.assertTrue(host.closed)
        finally:host.close()

    def test_host_provider_error_retains_baseline_receipt_and_closes(self):
        model=frozen_model(self.core)
        host=ForceController(self.core,self.compiled,controller_contract(declaration(),model),model,"synthetic_host_failure",self.profile)
        try:
            for original in self.rows[:HANDOFF]:host.step(original["request"]["state"],original["stability"],original["kinematics"])
            with patch.object(host.force_policy,"respond",side_effect=ValueError("synthetic failure")):
                row=host.step(self.rows[60]["request"]["state"],self.rows[60]["stability"],self.rows[60]["kinematics"])
            self.assertTrue(host.closed);self.assertIsNotNone(terminal_error(row))
            self.assertTrue(row["resolution"]["deterministic_baseline_fallback_used"])
            self.assertTrue(all(c["applied_correction_rad_s"]==0. for c in row["resolution"]["ordered_commands"]))
        finally:host.close()


if __name__=="__main__":unittest.main()
