"""Prepared model, canonical state, runtime separation and provenance controls."""
import copy
from contextlib import ExitStack
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import numpy as np
import mujoco
from audit_gpu_batch_execution import read_jsonl
from audit_predictive_numeric_backend import DLL,DLL_SHA,read,compare
from test_held_contact_rollout import FOLDER
from contact_force_observer_task import bridge
from predictive_command_selection_v2 import packet
from predictive_numeric_backend import KernelSelector
from prepare_predictive_model_mujoco import prepare
from prepared_predictive_model import PreparedSelector,canonical_packet,validate_model,law
from actuation_recovery_mechanics import quaternion_rotation


class PreparedControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile=read(FOLDER/"force-profile.json");cls.xml=(FOLDER/"model.xml").read_text()
        cls.prepared=prepare(cls.profile,cls.xml);cls.rows=list(read_jsonl(FOLDER/"controller.jsonl"))
        cls.model=PreparedSelector(cls.prepared,DLL,DLL_SHA);cls.reference=KernelSelector(cls.profile,cls.xml,DLL,DLL_SHA)
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))

    def inputs(self,command=60):
        row=self.rows[command];value=packet(row)
        return copy.deepcopy(row["request"]["state"]),{k:v for k,v in value.items() if k not in ("qpos","qvel")}

    def test_01_exact_preparation_and_weight_join(self):
        p=self.model.rollout.contact_model;r=self.reference.rollout.contact_model
        np.testing.assert_array_equal(p.dof_weight,r.dof_weight);self.assertEqual(p.body_weight,r.body_weight)
        self.assertEqual(self.prepared["law"],law())

    def test_02_all_canonical_state_joins(self):
        for command in range(60,119):
            observation,commands=self.inputs(command);value=canonical_packet(observation,commands,self.model.model.tree.joint_ids)
            original=packet(self.rows[command])
            np.testing.assert_allclose(value["qpos"],original["qpos"],atol=1e-12,rtol=0)
            np.testing.assert_allclose(value["qvel"],original["qvel"],atol=1e-12,rtol=0)

    def test_03_complete_key_decisions_match(self):
        for command in (60,92,118):
            observation,commands=self.inputs(command)
            compare(self.reference.select(packet(self.rows[command])),self.model.select_canonical(observation,commands))

    def test_04_runtime_cannot_parse_xml_or_open_world(self):
        observation,commands=self.inputs()
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No native access")))
            guards.enter_context(patch("xml.etree.ElementTree.fromstring",side_effect=AssertionError("No XML at runtime")))
            guards.enter_context(patch("xml.etree.ElementTree.parse",side_effect=AssertionError("No XML at runtime")))
            m=PreparedSelector(self.prepared,DLL,DLL_SHA)
            self.assertTrue(m.select_canonical(observation,commands)["accepted"])

    def test_05_prepared_model_and_inputs_immutable(self):
        value=copy.deepcopy(self.prepared);observation,commands=self.inputs()
        originals=copy.deepcopy((value,observation,commands))
        m=PreparedSelector(value,DLL,DLL_SHA);m.select_canonical(observation,commands)
        self.assertEqual(originals,(value,observation,commands))
        value["velocity_gains"][0]*=2
        self.assertNotEqual(m.prepared,value)

    def test_06_unknown_model_fields_refused(self):
        for key in ("engine_id","native_model","current_forces","future_qpos"):
            p=copy.deepcopy(self.prepared);p[key]=None
            with self.assertRaises(ValueError):validate_model(p)

    def test_07_missing_model_fields_refused(self):
        for key in self.prepared:
            p=copy.deepcopy(self.prepared);del p[key]
            with self.assertRaises(ValueError):validate_model(p)

    def test_08_law_changes_refused(self):
        for key,value in law().items():
            p=copy.deepcopy(self.prepared)
            p["law"][key]=value+" altered" if isinstance(value,str) else ([0.,0.,0.] if isinstance(value,list) else value+1)
            with self.assertRaises(ValueError):validate_model(p)

    def test_09_frame_schema_and_boolean_law_refused(self):
        for key in ("schema_version","coordinate_frame_id"):
            p=copy.deepcopy(self.prepared);p[key]="other"
            with self.assertRaises(ValueError):validate_model(p)
        p=copy.deepcopy(self.prepared);p["law"]["damping_ratio"]=True
        with self.assertRaises(ValueError):validate_model(p)

    def test_10_geometry_identity_and_shape_refused(self):
        for change in ("order","count","kind","extra","offset"):
            p=copy.deepcopy(self.prepared);g=p["ordered_geometry"]
            if change=="order":g[1],g[2]=g[2],g[1]
            elif change=="count":g.pop()
            elif change=="kind":g[1]["kind"]="box"
            elif change=="extra":g[1]["rotation"]=[0.,0.,0.]
            else:g[1]["endpoints_local_m"][0][0]=.01
            with self.assertRaises(ValueError):validate_model(p)

    def test_11_invalid_coefficients_refused(self):
        for key,value in (("velocity_gains",[0.]*8),("joint_inertia_kg_m2",[-.01]*8),
                          ("force_ranges",[[1.,2.]]*8),("reference_position_m",[0.,0.,0.])):
            p=copy.deepcopy(self.prepared);p[key]=value
            with self.assertRaises(ValueError):validate_model(p)
        for key in ("velocity_gains","joint_inertia_kg_m2"):
            p=copy.deepcopy(self.prepared);p[key][0]=float("nan")
            with self.assertRaises(ValueError):validate_model(p)

    def test_12_stale_clock_and_time_refused(self):
        for key,value in (("semantic_step",61),("semantic_step",True),("sample_time_s",.51),("sample_time_s",float("nan"))):
            s,c=self.inputs();s[key]=value
            with self.assertRaises(ValueError):canonical_packet(s,c,self.model.model.tree.joint_ids)

    def test_13_gravity_refused(self):
        s,c=self.inputs();s["gravity_world_m_s2"]["y"]=-9.81
        with self.assertRaises(ValueError):canonical_packet(s,c,self.model.model.tree.joint_ids)

    def test_14_joint_order_validity_refused(self):
        for change in ("order","position","velocity"):
            s,c=self.inputs();j=s["ordered_joint_observations"]
            if change=="order":j[0],j[1]=j[1],j[0]
            else:j[0]["validity"][change]=False
            with self.assertRaises(ValueError):canonical_packet(s,c,self.model.model.tree.joint_ids)

    def test_15_quaternion_and_numeric_domains_refused(self):
        s,c=self.inputs();s["base_pose_world"]["orientation_xyzw"]={k:0. for k in "xyzw"}
        with self.assertRaises(ValueError):canonical_packet(s,c,self.model.model.tree.joint_ids)
        s,c=self.inputs();s["base_twist_world"]["linear_velocity_m_s"]["x"]=float("nan")
        with self.assertRaises(ValueError):canonical_packet(s,c,self.model.model.tree.joint_ids)

    def test_16_future_command_fields_refused(self):
        for key in ("native_observation","future_state","engine_id"):
            s,c=self.inputs();c[key]={}
            with self.assertRaises(ValueError):canonical_packet(s,c,self.model.model.tree.joint_ids)

    def test_17_body_local_angular_conversion(self):
        s,c=self.inputs();s["base_pose_world"]["orientation_xyzw"]={"x":0.,"y":.6,"z":0.,"w":.8}
        s["base_twist_world"]["angular_velocity_rad_s"]={"x":1.,"y":2.,"z":3.}
        value=canonical_packet(s,c,self.model.model.tree.joint_ids)
        from held_contact_rollout import C
        expected=C.T @ quaternion_rotation([0.,.6,0.,.8]).T @ [1.,2.,3.]
        np.testing.assert_array_equal(value["qvel"][3:6],expected)

    def test_18_measured_loads_and_adapter_labels_unused(self):
        s,c=self.inputs();a=canonical_packet(s,c,self.model.model.tree.joint_ids)
        s["adapter_capability_sha256"]="different_adapter"
        for item in s["ordered_contact_observations"]:item["normal_load_n"]=999999.
        s["native_observation"]={"future_forces":[999.]}
        self.assertEqual(a,canonical_packet(s,c,self.model.model.tree.joint_ids))

    def test_19_adapter_rejects_unsupported_contact_law(self):
        with self.assertRaises(ValueError):prepare(self.profile,self.xml.replace('solref=".02 1"','solref=".03 1"'))

    def test_20_adapter_rejects_morphology_mismatch(self):
        p=copy.deepcopy(self.profile);p["morphology_spec"]["bodies"][0]["mass_kg"]+=1.
        with self.assertRaises(ValueError):prepare(p,self.xml)

    def test_21_adapter_rejects_extra_geometry_feature(self):
        with self.assertRaises(ValueError):prepare(self.profile,self.xml.replace('name="ground"','name="ground" margin=".001"'))

    def test_22_wrong_kernel_refused(self):
        with self.assertRaises(ValueError):PreparedSelector(self.prepared,DLL,"0"*64)

    def test_23_original_public_response_is_applied(self):
        r=self.core.resolve_adaptation_v1(copy.deepcopy(self.rows[60]["resolution_request"]))
        self.assertEqual(r["provider_status"],"applied")

    def test_24_public_engine_specific_response_is_refused(self):
        request=copy.deepcopy(self.rows[60]["resolution_request"])
        request["provider_response"]["provenance"]["engine_specific_logic_used"]=True
        result=self.core.resolve_adaptation_v1(request)
        self.assertNotEqual(result["provider_status"],"applied")
        self.assertTrue(result["fallback_reason"])
        self.assertTrue(all(c["applied_correction_rad_s"]==0. for c in result["ordered_commands"]))


if __name__=="__main__":unittest.main()
