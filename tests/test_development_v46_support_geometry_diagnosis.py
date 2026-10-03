import copy
import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"sdk/conformance"))
import development_v46_support_geometry_diagnosis as d
class Geometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rows,cls.value=d.read_source();cls.result=d.analyze(cls.rows,cls.value)
    def test_all_limb_geometry_and_preparation_not_scheduled_stance(self):
        r=self.result;self.assertEqual(241,r["command_count"]);self.assertEqual(964,r["limb_samples"])
        self.assertLess(r["maximum_native_fk_bottom_error_m"],1e-12)
        self.assertGreater(r["missing_preparation_contact_samples"]["front_left"],100)
        self.assertFalse(r["causal_attribution_proven"])
    def test_lowering_targets_rise_in_actual_pose_and_terminal_reach_is_impossible(self):
        r=self.result
        for s in r["all_samples"]:
            if s["command"]>1 and s["lowering_participant"] and not s["joint_projection"]:
                self.assertAlmostEqual(s["common_lowering_m"],s["target_bottom_m"],places=12)
        c=r["all_commands"][-1];self.assertGreater(c["common_minimum_m"],c["common_maximum_m"])
        f=next(s for s in r["all_samples"] if s["command"]==241 and s["limb"]=="front_left")
        self.assertTrue(f["link_reach_projection"]);self.assertFalse(f["speed_clipped"])
        self.assertGreater(f["target_bottom_m"],.014);self.assertLess(abs(f["hip_position_error_rad"]),.003)
    def test_crossed_clock_joint_body_and_phase_fail(self):
        for kind in ("clock","joint","body","phase"):
            rows=copy.deepcopy(self.rows[:1]);r=rows[0]
            if kind=="clock":r["request"]["state"]["semantic_step"]=8
            elif kind=="joint":r["request"]["state"]["ordered_joint_observations"][0]["position_rad"]+=.1
            elif kind=="body":r["request"]["measured_body_frame"]["ordered_body_states"][2]["pose_world"]["position_m"]["y"]+=.01
            else:r["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]["effective_selected_phases"][0]=1
            with self.assertRaises(ValueError):d.analyze(rows,self.value)
if __name__=="__main__":unittest.main()
