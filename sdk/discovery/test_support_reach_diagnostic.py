"""Independent reach geometry and retained-source refusal controls; no physics."""
import copy
from contextlib import ExitStack
import itertools
import json
import math
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid
import xml.etree.ElementTree as ET
import mujoco
import support_reach_diagnostic as reader


def rotate_vector(q, v):
    """Independent quaternion-vector rotation for the numerical grid oracle."""
    xyz=[q[k] for k in ["x","y","z"]]
    def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    first=cross(xyz,v);second=cross(xyz,first)
    return [a+2*(q["w"]*b+c) for a,b,c in zip(v,first,second)]


class ReachControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path=Path(__file__).with_name("support_reach_diagnostic_v1.json")
        cls.record=reader.read(cls.path)
        cls.evidence=reader.ROOT.parent/"SporeSpore_Evidence"
        cls.physical=cls.evidence/cls.record["source_attempt"]/"physical"
        cls.model,cls.joints,cls.sites=reader.geometry_inputs(cls.physical)
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("reach-refusal-inputs-"+uuid.uuid4().hex)
        cls.output.mkdir()
        cls.trial=cls.physical/"start_002_feedback_kp3_kd05"
        with (cls.trial/"controller.jsonl").open(encoding="utf-8") as stream:
            cls.rows=[json.loads(line) for line in itertools.islice(stream,121)]

    def setUp(self):
        guards=ExitStack();self.addCleanup(guards.close)
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No worlds in retained reach analysis")))

    def test_full_native_geometry_and_original_closure_are_verified_without_worlds(self):
        result=reader.verify_record(self.path,self.evidence,self.core,self.baseline)
        self.assertTrue(result["ok"])
        self.assertEqual((result["controller_rows"],result["internal_samples"],result["leg_reach_evaluations"]),(1440,7200,5760))
        self.assertLess(result["maximum_native_endpoint_error_m"],1e-14)
        self.assertEqual((result["world_build_count"],result["solver_steps"]),(0,0))
        self.assertTrue(all(result[key] is False for key in reader.AUTHORITY))
        self.assertEqual([t["front_right_ground_below_minimum_rows"] for t in self.record["trials"]],[173,173,173,173,142,137,144,145])
        self.assertTrue(all(t["normal_load_observations_available"]==0 for t in self.record["trials"]))
        self.assertFalse(self.record["actuator_torques_are_contact_forces"])
        self.assertEqual(self.record["source_trial_count"],10)
        self.assertEqual(self.record["original_ranking"]["ranked_feedback_indices"],[])
        print(json.dumps(result,sort_keys=True))

    def test_analytic_minimum_against_independent_joint_grid_and_witness(self):
        checks=0;max_grid_gap=0.
        for axis,angle in itertools.product([[1.,0.,0.],[0.,1.,0.],[0.,0.,1.],[2/3,1/3,2/3]],[-.4,0.,.4]):
            q=dict(zip(["x","y","z"],[a*math.sin(angle/2) for a in axis]));q["w"]=math.cos(angle/2)
            pose=dict(position_m=dict(x=.2,y=.44,z=-.1),orientation_xyzw=q)
            for leg in self.model["legs"]:
                radius=self.sites[leg["id"]+"_foot"]["radius_m"]
                result=reader.bound(pose,leg,radius,[-.72,.72],[-.15,1.1])
                anchor=[leg["hip_anchor_body_m"][a] for a in ["x","y","z"]]
                def height(h,k):
                    point=[anchor[0]+leg["upper_length_m"]*math.sin(h)+leg["lower_length_m"]*math.sin(h+k),
                        anchor[1]-leg["upper_length_m"]*math.cos(h)-leg["lower_length_m"]*math.cos(h+k),anchor[2]]
                    return .44+rotate_vector(q,point)[1]-radius
                witness=height(result["attaining_hip_rad"],result["attaining_knee_rad"])
                self.assertAlmostEqual(witness,result["minimum_clearance_m"],delta=2e-15)
                values=[height(-.72+1.44*i/120,-.15+1.25*j/120) for i,j in itertools.product(range(121),repeat=2)]
                self.assertGreaterEqual(min(values),witness-2e-15)
                max_grid_gap=max(max_grid_gap,min(values)-witness);checks+=len(values)
        self.assertLess(max_grid_gap,2e-5)
        print(json.dumps(dict(independent_grid_points=checks,maximum_grid_minimum_gap_m=max_grid_gap)))

    def test_radius_height_and_illegal_witness_domain(self):
        pose=copy.deepcopy(self.rows[120]["request"]["state"]["base_pose_world"])
        leg=self.model["legs"][1];radius=self.sites[leg["id"]+"_foot"]["radius_m"]
        original=reader.bound(pose,leg,radius,[-.72,.72],[-.15,1.1])
        pose["position_m"]["y"]+=.13
        shifted=reader.bound(pose,leg,radius+.02,[-.72,.72],[-.15,1.1])
        self.assertAlmostEqual(shifted["minimum_clearance_m"]-original["minimum_clearance_m"],.11,places=14)
        for hip,knee in [([.4,.5],[-.15,1.1]),([-.72,.72],[.1,1.1])]:
            with self.assertRaisesRegex(ValueError,"outside joint limits"):reader.bound(pose,leg,radius,hip,knee)
        pose["position_m"]["y"]=float("nan")
        with self.assertRaises(ValueError):reader.bound(pose,leg,radius,[-.72,.72],[-.15,1.1])

    def test_native_capsule_centres_are_not_contact_points(self):
        original=reader.frame(self.rows[1],self.model,self.joints,self.sites)
        changed=copy.deepcopy(self.rows[1])
        for item in changed["kinematics"]:item["endpoint_world_m"]=dict(x=100.,y=-100.,z=100.)
        self.assertEqual(reader.frame(changed,self.model,self.joints,self.sites),original)
        distal=next(b for b in changed["stability"]["ordered_body_states"] if b["body_id"]=="front_right_distal")
        distal["pose_world"]["position_m"]["y"]+=.001
        with self.assertRaisesRegex(ValueError,"endpoint mismatch"):reader.frame(changed,self.model,self.joints,self.sites)

    def test_changed_floor_and_capsule_geometry_refuse(self):
        for label in ["floor","capsule"]:
            folder=self.output/label;folder.mkdir();shutil.copy2(self.physical/"compiled.json",folder/"compiled.json")
            tree=ET.fromstring((self.physical/"model.xml").read_text(encoding="utf-8"))
            if label=="floor":tree.find("worldbody/geom[@name='ground']").set("pos","0 0 0.1")
            else:tree.find(".//geom[@name='front_right_distal_geom']").set("size","0.1")
            (folder/"model.xml").write_text(ET.tostring(tree,encoding="unicode"),encoding="utf-8",newline="\n")
            with self.assertRaisesRegex(ValueError,"Ground plane domain|capsule geometry"):reader.geometry_inputs(folder)

    def test_source_bytes_and_raw_order_cannot_be_substituted(self):
        original=reader.sha
        for target,message in [(reader.PARENT,"Parent closure changed"),(self.physical/"model.xml","Original reach input changed")]:
            with patch.object(reader,"sha",side_effect=lambda p: "0"*64 if Path(p)==target else original(p)):
                with self.assertRaisesRegex(ValueError,message):reader.analyze(self.evidence)
        original_rows=reader.read_jsonl
        def altered(path):
            rows=list(original_rows(path))
            if Path(path)==self.trial/"controller.jsonl":rows[0],rows[1]=rows[1],rows[0]
            return rows
        with patch.object(reader,"read_jsonl",side_effect=altered):
            with self.assertRaisesRegex(ValueError,"population/order"):reader.analyze(self.evidence)

    def test_changed_scope_denominators_and_measurements_refuse(self):
        changes=[lambda r:r.__setitem__("causal_authority",True),
            lambda r:r.__setitem__("training_data_authority",True),
            lambda r:r.__setitem__("source_trial_count",8),
            lambda r:r["trials"][0]["actuator_torques"]["mean_absolute_nm"].__setitem__(0,0.),
            lambda r:r["trials"][0]["snapshots"][0]["legs"][0].__setitem__("minimum_clearance_m",1.),
            lambda r:r["original_ranking"]["ranked_feedback_indices"].append(1)]
        # The full parent is checked by the integration test. Each corruption
        # still recomputes this diagnostic directly from all retained raw rows.
        with patch.object(reader,"verify_parent",return_value=None):
            for change in changes:
                value=copy.deepcopy(self.record);change(value);path=self.output/(uuid.uuid4().hex+".json")
                path.write_text(json.dumps(value,allow_nan=False),encoding="utf-8",newline="\n")
                with self.assertRaisesRegex(ValueError,"record changed"):
                    reader.verify_record(path,self.evidence,self.core,self.baseline)
        with patch.object(reader,"verify_parent",side_effect=ValueError("Parent refusal")):
            with self.assertRaisesRegex(ValueError,"Parent refusal"):
                reader.verify_record(self.path,self.evidence,self.core,self.baseline)


if __name__=="__main__":unittest.main()
