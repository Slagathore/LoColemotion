"""Refuse missing or incompatible native dynamics parameters."""
import copy,itertools,unittest,xml.etree.ElementTree as ET
import numpy as np
from actuation_recovery_mechanics import xyz
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_inputs import verify_native_state
from pathlib import Path
import json
from floating_base_dynamics_inputs import native_parameters


class NativeParametersControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        p=Path(__file__).resolve().parents[3]/"SporeSpore_Evidence"/"sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"/"physical/reach_hold_left_075_train_001"
        cls.xml=(p/"model.xml").read_text();cls.spec=json.loads((p/"force-profile.json").read_text())["morphology_spec"]
        with (p/"controller.jsonl").open() as stream:cls.row=json.loads(next(itertools.islice(stream,60,61)))
    def changed(self,tag,attribute,value):
        doc=ET.fromstring(self.xml);node=next(doc.iter(tag))
        if value is None:del node.attrib[attribute]
        else:node.set(attribute,value)
        return ET.tostring(doc,encoding="unicode")
    def test_01_actual_explicit_parameters(self):
        r=native_parameters(self.xml,self.spec)
        self.assertEqual(r["joint_inertia_kg_m2"],[.01]*8);self.assertEqual(r["passive_damping_nms_per_rad"],[0.]*8)
    def test_02_missing_joint_inertia(self):
        with self.assertRaises(ValueError):native_parameters(self.changed("joint","armature",None),self.spec)
    def test_03_negative_or_nonfinite_joint_inertia(self):
        for value in ("-.01","nan","inf"):
            with self.subTest(value=value),self.assertRaises(ValueError):native_parameters(self.changed("joint","armature",value),self.spec)
    def test_04_incompatible_body_inertia(self):
        with self.assertRaises(ValueError):native_parameters(self.changed("inertial","diaginertia","1 1 1"),self.spec)
    def test_05_unmodeled_inertial_rotation(self):
        with self.assertRaises(ValueError):native_parameters(self.changed("inertial","quat","1 0 0 0"),self.spec)
    def test_06_incompatible_damping_or_axis(self):
        for field,value in (("damping",".1"),("axis","1 0 0")):
            with self.subTest(field=field),self.assertRaises(ValueError):native_parameters(self.changed("joint",field,value),self.spec)

    def native_case(self):
        m=FloatingDynamics(self.spec,native_parameters(self.xml,self.spec)["joint_inertia_kg_m2"])
        state=self.row["request"]["state"];pose=state["base_pose_world"]
        frame=m.tree.kinematics(xyz(pose["position_m"]),[pose["orientation_xyzw"][k] for k in "xyzw"],
            [j["position_rad"] for j in state["ordered_joint_observations"]])
        velocity=np.r_[xyz(state["base_twist_world"]["linear_velocity_m_s"]),xyz(state["base_twist_world"]["angular_velocity_rad_s"]),
            [j["velocity_rad_s"] for j in state["ordered_joint_observations"]]]
        return m,frame,velocity,copy.deepcopy(self.row["native_observation"])
    def test_07_original_native_spatial_velocities(self):
        self.assertLess(max(verify_native_state(*self.native_case()).values()),1e-12)
    def test_08_crossed_native_spatial_velocity_refused(self):
        m,f,v,o=self.native_case();o["cvel"][3][4]+=.01
        with self.assertRaises(ValueError):verify_native_state(m,f,v,o)
    def test_09_crossed_generalized_velocity_or_pose_refused(self):
        for field,index,axis in (("qvel",3,None),("xpos",2,0)):
            m,f,v,o=self.native_case()
            if axis is None:o[field][index]+=.01
            else:o[field][index][axis]+=.01
            with self.subTest(field=field),self.assertRaises(ValueError):verify_native_state(m,f,v,o)


if __name__=="__main__":unittest.main()
