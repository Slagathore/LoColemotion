"""Dynamic provider, causal history and real public-resolver controls."""
import copy,itertools,os,unittest,json,sys
from pathlib import Path
from unittest.mock import patch
import numpy as np
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import read_jsonl
from contact_force_observer_task import ROOT,read,bridge
from hierarchical_force_policy_v5 import Policy,make_profile,digest,PROVIDER,HANDOFF,plain
from hierarchical_hold_control_v5 import HierarchicalHoldController
from hold_horizon_task import controller_contract,frozen_model,declaration
from recovery_hold_control import terminal_error
from actuation_recovery_mechanics import motor_torque


class HierarchicalPolicyControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        folder=ROOT.parent/"SporeSpore_Evidence/sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110/physical/reach_hold_left_075_train_001"
        cls.compiled=read(folder/"compiled.json");cls.inputs=read(folder/"inputs.json")
        cls.rows=list(itertools.islice(read_jsonl(folder/"controller.jsonl"),62));cls.profile=make_profile(cls.compiled,cls.inputs)

    def setUp(self):
        self.policy=Policy(self.core,self.profile)
        self.request=self.policy.bind(self.rows[60]["resolution_request"]["provider_request"],
            self.rows[60]["stability"],self.policy.memory("synthetic_dynamic_control"),"synthetic_dynamic_control")

    def resolve(self,request):
        try:response,detail=self.policy.respond(request)
        except Exception as exc:
            print(json.dumps(plain(dict(request=request,decision=getattr(exc,"decision",None))),allow_nan=False),file=sys.stderr)
            raise
        resolved=self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=response))
        return response,detail,resolved

    def test_01_real_core_accepts_exact_projection(self):
        response,d,r=self.resolve(self.request);self.assertEqual(r["provider_status"],"applied")
        self.assertEqual([x["final_canonical_target_velocity_rad_s"] for x in r["ordered_commands"]],d["projection"]["target"])
        self.assertEqual(response["provenance"]["provider_id"],PROVIDER)
    def test_02_transferred_motor_torque_and_unactuated_rows(self):
        _,d,r=self.resolve(self.request);velocity=[x["velocity_rad_s"] for x in self.request["state"]["ordered_joint_observations"]]
        torque=motor_torque([x["final_canonical_target_velocity_rad_s"] for x in r["ordered_commands"]],
            velocity,self.profile["velocity_gains"],self.profile["force_ranges"])
        np.testing.assert_allclose(torque,d["allocation"]["requested_torque"],atol=2e-6,rtol=0)
        self.assertLessEqual(max(abs(x) for x in d["allocation"]["transferred_dynamics_residual"]),4e-6)
        self.assertFalse(d["allocation"]["dynamic_feasibility_established"])
    def test_03_force_pyramid_and_caps(self):
        _,d,_=self.resolve(self.request)
        for x,y,z in d["allocation"]["forces"]:
            self.assertGreaterEqual(y,-2e-6);self.assertLessEqual(y,70.+2e-6)
            self.assertLessEqual(max(abs(x),abs(z)),.95/np.sqrt(2.)*y+2e-6)
    def test_04_inputs_and_profile_are_not_mutated(self):
        before=copy.deepcopy(self.request);self.resolve(self.request);self.assertEqual(before,self.request)
        profile=copy.deepcopy(self.profile);policy=Policy(self.core,profile);profile["parameters"]["joint_inertia_kg_m2"][0]=0.
        self.assertEqual(policy.p["joint_inertia_kg_m2"],[.01]*8)
    def test_05_current_measured_load_is_unused(self):
        _,d,_=self.resolve(self.request);other=copy.deepcopy(self.request)
        for r in other["state"]["ordered_contact_observations"]:r["normal_load_n"]=12345.
        _,changed=self.policy.respond(other);self.assertEqual(d,changed)
    def test_06_source_tampering_refused(self):
        p=copy.deepcopy(self.profile);p["source_bindings"]["hierarchical_force_policy_v5.py"]="0"*64
        with self.assertRaises(ValueError):Policy(self.core,p)
    def test_07_limits_and_runtime_mutation_refused(self):
        for key in ("parameters","solver_runtime"):
            p=copy.deepcopy(self.profile)
            if key=="parameters":p[key]["maximum_slew_per_command_rad_s"]=.09
            else:p[key]["osqp"]="changed"
            with self.assertRaises(ValueError):Policy(self.core,p)
    def test_08_authority_escalation_refused(self):
        for key in ("trained","tier2_qualified","held_interval_force_guaranteed"):
            p=copy.deepcopy(self.profile);p[key]=True
            with self.assertRaises(ValueError):Policy(self.core,p)
    def test_09_invalid_clock_refused(self):
        for step in (59,61,True):
            request=copy.deepcopy(self.request);request["state"]["semantic_step"]=step
            with self.assertRaises(ValueError):self.policy.respond(request)
    def test_10_crossed_episode_refused(self):
        request=copy.deepcopy(self.request);request["request_id"]="force_other_60"
        with self.assertRaises(ValueError):self.policy.respond(request)
    def test_11_missing_actual_history_refused(self):
        request=copy.deepcopy(self.request);request["history"]["ordered_entries"]=[]
        with self.assertRaises(ValueError):self.policy.respond(request)
    def test_12_crossed_contact_context_refused(self):
        request=copy.deepcopy(self.request);host=request["controller_context"]["controller_memory"]
        host["contact_packet"]["semantic_step"]=61;request["controller_context"]["controller_memory_sha256"]=digest(self.core,host)
        with self.assertRaises(ValueError):self.policy.respond(request)
    def test_13_solver_refusal_cannot_create_response(self):
        with patch("hierarchical_force_policy_v5.hierarchy.compute",side_effect=ValueError("solver refused")),self.assertRaisesRegex(ValueError,"solver refused"):
            self.policy.respond(self.request)
    def test_14_resolved_history_continues(self):
        _,_,resolved=self.resolve(self.request);following,boundary=history.append_resolved(self.core,self.request,resolved)
        self.assertIsNone(boundary);following["ordered_entries"]=following["ordered_entries"][-1:]
        request=self.policy.bind(self.rows[61]["resolution_request"]["provider_request"],self.rows[61]["stability"],
            resolved["next_memory"],"synthetic_dynamic_control")
        for limit,command in zip(request["safety_envelope"]["ordered_actuator_limits"],resolved["ordered_commands"]):
            limit["previous_applied_correction_rad_s"]=command["applied_correction_rad_s"]
        request=history.attach(request,following);_,_,next_resolution=self.resolve(request)
        self.assertEqual(next_resolution["provider_status"],"applied")
    def test_15_host_prefix_and_continuous_handoff(self):
        model=frozen_model(self.core)
        host=HierarchicalHoldController(self.core,self.compiled,controller_contract(declaration(),model),model,"synthetic_dynamic_host",self.profile)
        try:
            for i,old in enumerate(self.rows):
                row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                self.assertIsNone(terminal_error(row))
                if i<HANDOFF:self.assertEqual(row["native_targets"],old["native_targets"])
                else:self.assertEqual(row["resolution"]["provider_status"],"applied")
        finally:host.close()

    def test_16_refusal_retains_computation_and_request_binding(self):
        refused=dict(accepted=False,status="bounded hierarchical search refused",prediction=None,selected=None,attempts=[],patterns_tried=0)
        with patch("hierarchical_force_policy_v5.hierarchy.compute",return_value=refused):
            with self.assertRaises(ValueError) as error:self.policy.respond(self.request)
        self.assertEqual(error.exception.decision["allocation"],refused)
        self.assertEqual(error.exception.decision["request_sha256"],digest(self.core,self.request))
    def test_17_host_retains_refusal_before_native_transfer(self):
        from types import SimpleNamespace
        from dynamic_control_native_trial import transfer_targets
        model=frozen_model(self.core)
        host=HierarchicalHoldController(self.core,self.compiled,controller_contract(declaration(),model),model,"refused_hierarchy_host",self.profile)
        try:
            for old in self.rows[:60]:
                host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
            refused=dict(accepted=False,status="bounded hierarchical search refused",prediction=None,selected=None,attempts=[],patterns_tried=0)
            with patch("hierarchical_force_policy_v5.hierarchy.compute",return_value=refused):
                old=self.rows[60];row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
            self.assertIsNotNone(terminal_error(row));self.assertEqual(row["force_reference"]["decision"]["allocation"],refused)
            data=SimpleNamespace(ctrl=np.zeros(8))
            with self.assertRaises(ValueError):transfer_targets(row,data)
            np.testing.assert_equal(data.ctrl,np.zeros(8));self.assertTrue(host.closed)
        finally:host.close()


if __name__=="__main__":unittest.main()
