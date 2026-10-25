"""Negative controls for bounded retrospective posture/actuation observations."""
import copy,itertools,json,unittest
from pathlib import Path
import numpy as np
import posture_tracking_diagnostic_metrics as d
from actuation_recovery_mechanics import RigidTree

class PostureTrackingControls(unittest.TestCase):
    def test_01_zero_reference(self):
        r=d.joint_tracking([0,0],[0,0],[0,0]);self.assertEqual(r["final_error_norm_rad"],0)
        self.assertFalse(r["distance_to_fixed_reference_decreased"])
    def test_02_closer_is_not_deadline(self):
        r=d.joint_tracking([1,2],[0,0],[.1,.2]);self.assertTrue(r["distance_to_fixed_reference_decreased"])
        self.assertTrue(r["reference_is_not_one_step_deadline"]);self.assertFalse(r["physical_feasibility_established"])
    def test_03_opposite_motion(self):
        r=d.joint_tracking([1,2],[0,0],[-.1,-.2]);self.assertFalse(r["distance_to_fixed_reference_decreased"])
        self.assertGreater(r["final_error_norm_rad"],r["initial_error_norm_rad"])
    def test_04_missing_or_nonfinite_joints(self):
        for args in (([],[],[]),([1],[0,0],[0]),([1],[0],[float("nan")])):
            with self.subTest(args=args),self.assertRaises(ValueError):d.joint_tracking(*args)
    def motion(self,p1,r1,point):return d.material_point_motion([0,0,0],np.eye(3),p1,r1,point)
    def test_05_fixed_material_point(self):np.testing.assert_array_equal(self.motion([0,0,0],np.eye(3),[1,2,3]),[0,0,0])
    def test_06_translation(self):np.testing.assert_allclose(self.motion([.1,.2,.3],np.eye(3),[1,2,3]),[.1,.2,.3],atol=1e-15)
    def test_07_rotation(self):np.testing.assert_allclose(self.motion([0,0,0],[[0,-1,0],[1,0,0],[0,0,1]],[1,0,0]),[-1,1,0],atol=1e-15)
    def test_08_invalid_rotation_or_point(self):
        for rot,point in ((np.zeros((3,3)),[1,2,3]),(np.diag([-1,1,1]),[1,2,3]),(np.eye(3),[0,float("inf"),0])):
            with self.subTest(rot=rot.tolist()),self.assertRaises(ValueError):self.motion([0,0,0],rot,point)
    def test_09_common_complete_window(self):
        r=d.validate_window([dict(internal_step=695),dict(internal_step=633)],60,126)
        self.assertEqual(r["commands_per_trial"],66);self.assertFalse(r["includes_first_failing_command"])
    def test_10_future_or_changed_failure(self):
        for start,end,first in ((60,127,633),(59,126,633),(60,126,630),(60,126,634)):
            with self.subTest(first=first,end=end),self.assertRaises(ValueError):d.validate_window([dict(internal_step=695),dict(internal_step=first)],start,end)
    def fixture(self):
        p=Path(__file__).resolve().parents[3]/"SporeSpore_Evidence"/"sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"/"physical/posture_hold_left_075_train_001"
        profile=json.loads((p/"force-profile.json").read_text())
        with (p/"controller.jsonl").open() as f:row=json.loads(next(itertools.islice(f,60,61)))
        with (p/"trace.jsonl").open() as f:trace=json.loads(next(itertools.islice(f,304,305)))
        return row,trace,RigidTree(profile["morphology_spec"]),profile
    def test_11_actual_handoff_reference_join(self):
        r=d.posture_snapshot(*self.fixture());self.assertAlmostEqual(r["observed_interval_s"],1/120)
        self.assertFalse(r["held_contact_guaranteed"]);self.assertFalse(r["virtual_reference"]["root_motion_issued"])
    def test_12_changed_posture_torque_refused(self):
        row,trace,tree,profile=self.fixture();row["force_reference"]["decision"]["posture_torque"][0]+=.01
        with self.assertRaises(ValueError):d.posture_snapshot(row,trace,tree,profile)

if __name__=="__main__":unittest.main()
