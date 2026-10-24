"""Both-core retained-input controls for residuals; no native worlds or training."""
import copy
from contextlib import ExitStack
from dataclasses import FrozenInstanceError
import hashlib
from itertools import islice
import json
import math
import os
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

import mujoco
from adaptation_provider import bounded_residual_ars_v1 as ars
from adaptation_provider import bounded_residual_provider_v1 as provider
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import same_bits
import portable_search_control as portable
import residual_control as host
from sporespore_locomotion import LocomotionCore

ROOT=Path(__file__).resolve().parents[2]
PARENT=ROOT/"sdk/discovery/cpu_committed_feedback_closure_v1.json"
PARENT_SHA="5aeb46084f5431386656a029f3a887433945c0df97f3180a6ac58d0ba2b5d633"
ROLES=(("absent","absent","probe"),("disabled","disabled","probe"),
       ("zero","frozen","zero"),("probe","frozen","probe"))
STEPS=40


def sha(path):
    with path.open("rb") as stream:return hashlib.file_digest(stream,"sha256").hexdigest()


def read(path):return json.loads(path.read_text(encoding="utf-8"))


def write(path,value):
    with path.open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(value,stream,allow_nan=False,sort_keys=True);stream.write("\n")


def policy(probe=False):
    rows=[[0.]*provider.features.DIMENSION for _ in range(8)]
    if probe:
        for i,row in enumerate(rows):
            # Deliberate test stimulus, not fitted weights or a selected controller.
            row[provider.features.NAMES.index("height_m")]=(-1.)**i*.8
            row[provider.features.NAMES.index(provider.features.JOINTS[i]+"_velocity_rad_s")]=-.02
            row[provider.features.NAMES.index(provider.features.LEGS[i//2]+"_phase_sin")]=.1
    return ars.Policy(tuple(tuple(row) for row in rows),ars.Moments.empty(provider.features.DIMENSION),(3.5,)*8,1e-8)


def artifact(probe=False,ceiling=1.):
    return provider.artifact(policy(probe),dict(corpus_id="untrained_residual_interface_stimulus",
        kind="untrained_development_probe",source_record_sha256=None,training_data_authority=False),ceiling)


class ResidualControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        guards=ExitStack();cls.addClassCleanup(guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual controls forbid all worlds")))
        if sha(PARENT)!=PARENT_SHA:raise ValueError("Residual retained-input parent changed")
        parent=read(PARENT)
        root=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
        attempt=root/parent["attempt_id"]
        inventory={a["evidence_relative_path"]:a for a in parent["artifacts"]}
        if len(inventory)!=len(parent["artifacts"]):raise ValueError("Repeated source artifact")
        cls.input_bindings={str(PARENT.relative_to(ROOT)):PARENT_SHA}
        def verified(path):
            relative=path.relative_to(root).as_posix()
            expected=inventory[relative];actual=sha(path)
            if actual!=expected["sha256"] or path.stat().st_size!=expected["byte_length"]:
                raise ValueError("Retained residual input changed: "+relative)
            cls.input_bindings[relative]=actual
            return path
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.compiled={condition:read(verified(attempt/"physical/models"/condition/"compiled.json"))
                      for condition in ("left_075","nominal")}
        cls.inputs={}
        for condition in ("left_075","nominal"):
            for start in ("train_001","train_003","train_004","train_006"):
                group=condition+"_"+start
                directory=attempt/"physical"/(group+"_baseline")
                result=read(verified(directory/"result.json"))
                path=verified(directory/"controller.jsonl")
                if result["hashes"]["controller"]!=cls.input_bindings[path.relative_to(root).as_posix()]:
                    raise ValueError("Residual source result/controller binding")
                with path.open(encoding="utf-8") as stream:
                    cls.inputs[group]=[json.loads(line) for line in islice(stream,STEPS)]
                if len(cls.inputs[group])!=STEPS or [r["outer_step"] for r in cls.inputs[group]]!=list(range(STEPS)):
                    raise ValueError("Residual input prefix clock/completeness")
        cls.cores=[]
        for variable,key in (("QUADRUPED_TEST_CORE","core_sha256"),("PORTABLE_BATCH_BASELINE_CORE","baseline_core_sha256")):
            path=Path(os.environ[variable])
            if sha(path)!=parent[key]:raise ValueError("Residual core binding")
            cls.input_bindings[str(path)]=sha(path)
            cls.cores.append(LocomotionCore(path))
        cls.models=[{name:provider.FrozenModel.load(core,artifact(probe))
                     for name,probe in (("zero",False),("probe",True))} for core in cls.cores]
        cls.c=portable.contract();cls.c["seed"]=104232601
        cls.rows={}
        write(cls.out/"residual-input-bindings.json",dict(source_closure_sha256=PARENT_SHA,
            input_bindings=cls.input_bindings,retained_input_groups=list(cls.inputs),
            steps_per_group=STEPS,roles=ROLES,worlds_opened=0,training_data_authority=False))
        for ci,core in enumerate(cls.cores):
            for group,rows in cls.inputs.items():
                condition="left_075" if group.startswith("left_075_") else "nominal"
                for name,mode,model_key in ROLES:
                    model=cls.models[ci][model_key]
                    c=dict(cls.c,provider=host.expected_provider(model))
                    controller=host.ResidualController(core,cls.compiled[condition],c,model,mode,group+"_"+name)
                    try:
                        observed=[controller.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in rows]
                    finally:controller.close()
                    cls.rows[ci,group,name]=observed
                    write(cls.out/(str(ci)+"_"+group+"_"+name+".json"),dict(
                        synthetic_control=True,retained_native_inputs=True,new_physical_outcomes=False,
                        constructed_worlds=0,rows=observed))

    def controller(self,ci=0,mode="frozen",model=None,episode="private_episode"):
        model=model or self.models[ci]["probe"]
        c=dict(self.c,provider=host.expected_provider(model))
        value=host.ResidualController(self.cores[ci],self.compiled["left_075"],c,model,mode,episode)
        self.addCleanup(value.close)
        return value

    def request(self,ci=0,step=1,role="probe"):
        return copy.deepcopy(self.rows[ci,"left_075_train_001",role][step]["resolution_request"]["provider_request"])

    def resolve(self,core,request,response):
        return core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=response))

    def test_both_real_cores_replay_all_eight_groups_and_four_roles_bit_identically(self):
        for group in self.inputs:
            for name,_,_ in ROLES:
                self.assertTrue(same_bits(self.rows[0,group,name],self.rows[1,group,name]),(group,name))
        self.assertEqual(sum(len(rows) for rows in self.rows.values()),2560)

    def test_absent_disabled_and_zero_residual_preserve_baseline_command_bits(self):
        for ci in range(2):
            for group,source in self.inputs.items():
                for name in ("absent","disabled","zero"):
                    for row,original in zip(self.rows[ci,group,name],source,strict=True):
                        for key in ("output","composition","native_targets"):
                            self.assertTrue(same_bits(row[key],original[key]),(ci,group,name,key))
                        self.assertIsNone(row["residual"]["terminal_error"])
                        self.assertFalse(any(c["applied_correction_rad_s"] for c in row["resolution"]["ordered_commands"]))
                        self.assertEqual(row["resolution"]["world_build_count"],0)
                        self.assertFalse(row["resolution"]["physics_state_modified"])
                        if name=="absent":
                            self.assertEqual(row["resolution"]["fallback_reason"],"provider_absent")
                            self.assertIsNone(row["resolution"]["provider_status"])
                            self.assertEqual(row["residual"]["history_boundary"],"v1_unrepresentable_provider_status")
                            self.assertEqual(row["residual"]["ongoing_history_entries"],0)
                        else:
                            self.assertIsNone(row["residual"]["history_boundary"])

    def test_continuous_history_joins_actual_receipts_positions_and_issued_commands(self):
        for ci,core in enumerate(self.cores):
            for group in self.inputs:
                for name in ("disabled","zero","probe"):
                    rows=self.rows[ci,group,name]
                    for step,row in enumerate(rows):
                        request=row["resolution_request"]["provider_request"]
                        entries=request["history"]["ordered_entries"]
                        feature=row["residual"]["decision"]["features"]
                        self.assertIsNotNone(feature,(ci,group,name,step,row["residual"]["decision"]))
                        self.assertEqual(len(entries),int(step>0))
                        values=dict(zip(feature["names"],feature["values"],strict=True))
                        self.assertEqual(len(values),88)
                        self.assertFalse(feature["confidence_is_calibrated"])
                        if not step:
                            self.assertEqual(values["previous_action_available"],0.)
                            continue
                        prior=rows[step-1];entry=entries[0]
                        self.assertEqual(entry["resolution_receipt_sha256"],provider.digest(core,prior["resolution"]))
                        self.assertEqual(entry["request_sha256"],provider.digest(core,prior["resolution_request"]["provider_request"]))
                        self.assertEqual(entry["state"],prior["request"]["state"])
                        self.assertEqual(feature["previous_semantic_step"],step-1)
                        self.assertEqual(values["previous_action_available"],1.)
                        for i,joint in enumerate(provider.features.JOINTS):
                            self.assertEqual(values[joint+"_maximum_command_speed_rad_s"],
                                request["deterministic_baseline"]["ordered_commands"][i]["maximum_target_speed_rad_s"])
                            issued=prior["resolution"]["ordered_commands"][i]
                            position=row["request"]["state"]["ordered_joint_observations"][i]["position_rad"]
                            old=prior["request"]["state"]["ordered_joint_observations"][i]["position_rad"]
                            self.assertEqual(values[joint+"_previous_final_command_rad_s"],issued["final_canonical_target_velocity_rad_s"])
                            self.assertEqual(values[joint+"_previous_correction_rad_s"],issued["applied_correction_rad_s"])
                            self.assertAlmostEqual(values[joint+"_previous_response_error_rad_s"],
                                (position-old)*120-issued["final_canonical_target_velocity_rad_s"],places=12)
                        self.assertEqual(row["resolution"]["next_memory"]["sequence"],step+1)
                        self.assertFalse(row["resolution"]["next_memory"]["weights_mutated"])

    def test_nonzero_probe_passes_independent_slew_and_final_speed_projection(self):
        slew_count=final_count=applied_count=0
        for ci in range(2):
            for group in self.inputs:
                previous=[0.]*8
                for step,row in enumerate(self.rows[ci,group,"probe"]):
                    receipt=row["resolution"];raw=row["residual"]["decision"]["raw_correction_rad_s"]
                    self.assertTrue(all(math.isfinite(x) and abs(x)<=3.5 for x in raw))
                    for i,command in enumerate(receipt["ordered_commands"]):
                        wanted=0. if step==0 else raw[i]
                        expected=0. if step==0 else min(previous[i]+.08,max(previous[i]-.08,min(3.5,max(-3.5,wanted))))
                        cap=command["maximum_target_speed_rad_s"]
                        final=min(cap,max(-cap,command["baseline_canonical_target_velocity_rad_s"]+expected))
                        self.assertEqual(command["applied_correction_rad_s"],expected)
                        self.assertEqual(command["final_canonical_target_velocity_rad_s"],final)
                        previous[i]=expected
                        slew_count+=command["slew_clamped"];final_count+=command["final_speed_clamped"]
                    applied_count+=receipt["adaptation_applied"]
                    self.assertIsNone(row["residual"]["terminal_error"])
        self.assertGreater(slew_count,0)
        self.assertEqual(applied_count,2*8*(STEPS-1))
        # The retained prefix does not naturally reach final-speed projection.
        # Inject excessive proposals against unchanged, actually saturated
        # baseline commands, including the real 3.0 knee limit.
        forced=[]
        for ci,core in enumerate(self.cores):
            request=self.request(ci,step=2,role="zero")
            response,_=provider.respond(core,request,self.models[ci]["zero"],"frozen")
            self.assertEqual(response["status"],"applied")
            for i,correction in enumerate(response["ordered_corrections"]):
                baseline=request["deterministic_baseline"]["ordered_commands"][i]["combined_canonical_target_velocity_rad_s"]
                correction["canonical_velocity_delta_rad_s"]=math.copysign(100.,baseline)
            receipt=self.resolve(core,request,response)
            for i,command in enumerate(receipt["ordered_commands"]):
                prior=request["safety_envelope"]["ordered_actuator_limits"][i]["previous_applied_correction_rad_s"]
                sign=math.copysign(1.,response["ordered_corrections"][i]["canonical_velocity_delta_rad_s"])
                bounded=prior+sign*.08;cap=command["maximum_target_speed_rad_s"]
                unbounded=command["baseline_canonical_target_velocity_rad_s"]+bounded
                final=min(cap,max(-cap,unbounded))
                self.assertTrue(command["absolute_correction_clamped"])
                self.assertTrue(command["slew_clamped"])
                self.assertEqual(command["final_speed_clamped"],unbounded!=final)
                self.assertEqual(command["applied_correction_rad_s"],bounded)
                self.assertEqual(command["final_canonical_target_velocity_rad_s"],final)
                final_count+=command["final_speed_clamped"]
            self.assertEqual(receipt["ordered_commands"][5]["maximum_target_speed_rad_s"],3.)
            self.assertTrue(receipt["ordered_commands"][5]["final_speed_clamped"])
            forced.append(dict(core_index=ci,request=request,response=response,receipt=receipt))
        self.assertGreaterEqual(final_count,2)
        write(self.out/"residual-forced-projection.json",dict(
            synthetic_control=True,proposals_injected=True,worlds_opened=0,records=forced))

    def test_exact_phase_offsets_wrap_and_body_coordinates_do_not_use_native_state(self):
        core=self.cores[0];request=self.request(step=0)
        state=request["state"]
        theta=.3
        state["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=math.sin(theta/2),z=0.,w=math.cos(theta/2))
        state["base_twist_world"]["linear_velocity_m_s"]=dict(x=2.,y=.1,z=0.)
        feature=provider.features.extract(core,request)
        values=dict(zip(feature["names"],feature["values"],strict=True))
        self.assertAlmostEqual(values["linear_velocity_body_m_s_x"],2*math.cos(theta),places=13)
        self.assertAlmostEqual(values["linear_velocity_body_m_s_z"],2*math.sin(theta),places=13)
        self.assertEqual(values["linear_velocity_body_m_s_y"],.1)
        for gait,expected in [(359,[269,89,359,179]),(360,[270,90,0,180])]:
            context=request["controller_context"]
            for limb in context["controller_memory"]["ordered_limb_memory"]:limb["gait_step"]=gait
            context["controller_memory_sha256"]=provider.digest(core,context["controller_memory"])
            feature=provider.features.extract(core,request)
            self.assertEqual(feature["exact_local_phase_commands"],expected)
            values=dict(zip(feature["names"],feature["values"],strict=True))
            for leg,phase_step in zip(provider.features.LEGS,expected,strict=True):
                self.assertEqual(values[leg+"_phase_sin"],math.sin(2*math.pi*phase_step/360))
                self.assertEqual(values[leg+"_phase_cos"],math.cos(2*math.pi*phase_step/360))
        self.assertFalse(provider.definition()["observation"]["privileged_motor_parameters"])
        self.assertFalse(provider.definition()["observation"]["engine_specific_inputs"])

    def test_domain_refusals_use_actual_core_baseline_fallback(self):
        mutations=[
            lambda r:r["state"]["base_pose_world"]["position_m"].__setitem__("y",.1),
            lambda r:r["state"]["base_twist_world"]["linear_velocity_m_s"].__setitem__("x",11.),
            lambda r:r["state"]["base_twist_world"]["angular_velocity_rad_s"].__setitem__("x",21.),
            lambda r:r["state"]["ordered_joint_observations"][0].__setitem__("velocity_rad_s",21.),
            lambda r:r["descriptor"].__setitem__("torso_length_scale",1.005),
            lambda r:r["history"]["ordered_entries"].clear(),
        ]
        for ci,core in enumerate(self.cores):
            for mutation in mutations:
                request=self.request(ci);mutation(request)
                response,detail=provider.respond(core,request,self.models[ci]["probe"],"frozen")
                self.assertEqual(response["status"],"unsupported")
                self.assertTrue(detail["reason"].startswith("unsupported_observation:"))
                self.assertEqual(response["ordered_corrections"],[])
                result=self.resolve(core,request,response)
                self.assertEqual(result["fallback_reason"],"provider_unsupported")
                for got,base in zip(result["ordered_commands"],request["deterministic_baseline"]["ordered_commands"],strict=True):
                    self.assertEqual(struct.pack("d",got["final_canonical_target_velocity_rad_s"]),
                                     struct.pack("d",base["combined_canonical_target_velocity_rad_s"]))

    def test_malformed_features_and_crossed_past_observations_are_refused(self):
        mutations=[
            lambda r:r["state"]["ordered_joint_observations"].reverse(),
            lambda r:r["state"]["ordered_joint_observations"][0]["validity"].__setitem__("velocity",False),
            lambda r:r["state"].__setitem__("sample_time_s",0.),
            lambda r:r["state"]["task_frame"].__setitem__("reference_yaw_rad",.2),
            lambda r:r["state"]["gravity_world_m_s2"].__setitem__("y",-8.),
            lambda r:r["state"]["ordered_contact_observations"].reverse(),
            lambda r:r["command"].__setitem__("gait_amplitude",.5),
            lambda r:r["controller_context"].__setitem__("controller_memory_sha256","sha256:"+"0"*64),
            lambda r:r["safety_envelope"]["ordered_actuator_limits"][0].__setitem__("maximum_slew_per_step_rad_s",.09),
            lambda r:r["history"]["ordered_entries"][0]["state"]["ordered_joint_observations"][0].__setitem__("position_rad",.2),
            lambda r:r["history"]["ordered_entries"][0].__setitem__("semantic_step",1),
            lambda r:r["history"]["ordered_entries"][0]["ordered_applied_corrections"][0].__setitem__("canonical_velocity_delta_rad_s",.08),
            lambda r:r["history"]["ordered_entries"][0]["deterministic_baseline"]["ordered_commands"][0].__setitem__("valid_through_step",4),
        ]
        core=self.cores[0]
        for mutation in mutations:
            request=self.request();mutation(request)
            response,detail=provider.respond(core,request,self.models[0]["probe"],"frozen")
            self.assertEqual(response["status"],"unsupported",detail)
            self.assertEqual(response["ordered_corrections"],[])

    def test_artifacts_are_owned_immutable_and_refuse_changed_shape_lineage_or_pins(self):
        core=self.cores[0];value=artifact(True)
        model=provider.FrozenModel.load(core,value);before=model.document()
        loaded=provider.FrozenModel.load(core,json.loads(json.dumps(before)))
        self.assertEqual((loaded.sha256,loaded.policy.sha256),(model.sha256,model.policy.sha256))
        exact=artifact(True);exact["policy"]["weights"][0][0]=.123456789012345
        next_bit=copy.deepcopy(exact)
        next_bit["policy"]["weights"][0][0]=math.nextafter(exact["policy"]["weights"][0][0],math.inf)
        self.assertNotEqual(provider.FrozenModel.load(core,exact).sha256,
                            provider.FrozenModel.load(core,next_bit).sha256)
        value["policy"]["weights"][0][0]=999.
        value["corpus"]["corpus_id"]="mutated"
        self.assertEqual(model.document(),before)
        with self.assertRaises(FrozenInstanceError):model.confidence_ceiling=0.
        mutations=[
            lambda v:v["policy"]["weights"][0].pop(),
            lambda v:v["policy"]["weights"][0].__setitem__(0,float("nan")),
            lambda v:v["policy"].__setitem__("count",True),
            lambda v:v["policy"]["output_limits"].__setitem__(0,4.),
            lambda v:v["definition"]["observation"]["feature_names"].reverse(),
            lambda v:v["definition"]["source_implementations"].__setitem__("bounded_residual_ars_v1.py","0"*64),
            lambda v:v["corpus"].__setitem__("training_data_authority",True),
            lambda v:v.__setitem__("confidence_ceiling",1.01),
        ]
        for mutation in mutations:
            corrupt=artifact(True);mutation(corrupt)
            with self.assertRaises(ValueError):provider.FrozenModel.load(core,corrupt)
        changed=provider.expected_definition()
        changed["source_implementations"]["bounded_residual_ars_v1.py"]="0"*64
        with patch.object(provider,"expected_definition",return_value=changed):
            with self.assertRaisesRegex(ValueError,"bindings changed"):provider.FrozenModel.load(core,before)
        self.assertEqual(model.policy.moments.count,0)
        for field in ("physical_launch_authority","physical_acceptance_authority","release_authority",
                      "training_data_authority","tier3_benefit_established","weights_updated_online"):
            self.assertIs(provider.definition()[field],False)

    def test_stale_cross_episode_seed_and_model_memory_become_reasoned_absence(self):
        mutations=[
            lambda r:r["provider_memory"].__setitem__("sequence",0),
            lambda r:r["provider_memory"].__setitem__("opaque_state_sha256","sha256:"+"0"*64),
            lambda r:r.__setitem__("request_id","residual_another_episode_1"),
            lambda r:r.__setitem__("seed",r["seed"]+1),
            lambda r:r.__setitem__("expected_model_sha256","sha256:"+"0"*64),
            lambda r:r["safety_envelope"].__setitem__("minimum_confidence",.5),
        ]
        for ci,core in enumerate(self.cores):
            for mutation in mutations:
                request=self.request(ci);mutation(request)
                called=provider.call_provider(core,request,self.models[ci]["probe"],"frozen")
                self.assertIsNotNone(called["provider_error"])
                self.assertIsNone(called["provider_response"])
                # A malformed digest is a host request error, independently of
                # provider absence. Use valid host requests for resolver checks.
                if request["provider_memory"]["opaque_state_sha256"]==provider.digest(core,request["provider_memory"]["opaque_state"]):
                    result=self.resolve(core,request,None)
                    self.assertEqual(result["fallback_reason"],"provider_absent")
                    self.assertFalse(result["adaptation_applied"])

    def test_uncertain_model_preserves_actual_history_and_never_issues_residual(self):
        for ci,core in enumerate(self.cores):
            model=provider.FrozenModel.load(core,artifact(True,.5))
            controller=self.controller(ci,model=model,episode="uncertain")
            for step,source in enumerate(self.inputs["left_075_train_001"][:5]):
                row=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
                self.assertEqual(row["resolution"]["fallback_reason"],"provider_no_proposal" if not step else "provider_uncertain")
                self.assertTrue(same_bits(row["native_targets"],source["native_targets"]))
                self.assertEqual(row["residual"]["ongoing_history_entries"],1)
                self.assertFalse(row["resolution"]["adaptation_applied"])

    def test_host_private_reset_close_and_unexpected_provider_failure_are_terminal(self):
        source=self.inputs["left_075_train_001"]
        for ci in range(2):
            a=self.controller(ci,episode="episode_a");b=self.controller(ci,episode="episode_b")
            first=a.step(source[0]["request"]["state"],source[0]["stability"],source[0]["kinematics"])
            a.step(source[1]["request"]["state"],source[1]["stability"],source[1]["kinematics"])
            fresh=b.step(source[0]["request"]["state"],source[0]["stability"],source[0]["kinematics"])
            self.assertEqual(fresh["residual"]["decision"]["features"]["history_entries"],0)
            self.assertTrue(same_bits(fresh["native_targets"],first["native_targets"]))
            self.assertNotEqual(fresh["resolution"]["request_id"],first["resolution"]["request_id"])
            with self.assertRaisesRegex(ValueError,"lifecycle/clock"):
                b.step(source[0]["request"]["state"],source[0]["stability"],source[0]["kinematics"])
            self.assertTrue(b.closed)
            a.close();a.close()
            with self.assertRaisesRegex(ValueError,"lifecycle/clock"):
                a.step(source[2]["request"]["state"],source[2]["stability"],source[2]["kinematics"])
            failed=self.controller(ci,episode="failing_provider")
            with patch.object(provider,"respond",side_effect=RuntimeError("injected provider failure")):
                row=failed.step(source[0]["request"]["state"],source[0]["stability"],source[0]["kinematics"])
            self.assertTrue(failed.closed)
            self.assertEqual(row["residual"]["terminal_error"]["type"],"RuntimeError")
            self.assertEqual(row["resolution"]["fallback_reason"],"provider_absent")
            self.assertTrue(same_bits(row["native_targets"],source[0]["native_targets"]))

    def test_invalid_provider_response_keeps_original_receipt_and_closes_host(self):
        source=self.inputs["left_075_train_001"][0]
        for ci in range(2):
            controller=self.controller(ci,episode="invalid_response")
            response=copy.deepcopy(self.rows[ci,"left_075_train_001","probe"][0]["resolution_request"]["provider_response"])
            response["request_id"]="crossed_request"
            with patch.object(provider,"call_provider",return_value=dict(provider_response=response,decision=None,provider_error=None)):
                row=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
            self.assertTrue(controller.closed)
            self.assertIsNotNone(row["residual"]["terminal_error"])
            self.assertTrue(row["resolution"]["deterministic_baseline_fallback_used"])
            self.assertIn(row["resolution"]["fallback_reason"],("request_identity_mismatch","invalid_provider_response"))
            self.assertTrue(same_bits(row["native_targets"],source["native_targets"]))


if __name__=="__main__":unittest.main()
