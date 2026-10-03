import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"sdk/conformance"))
import development_v48_preparation_contact_diagnosis as d
class Diagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rows,cls.value,cls.reader=d.read_source();cls.result=d.analyze(cls.rows,cls.value,cls.reader)
    def test_recenter_preserves_pose_and_removes_final_bias_cap(self):
        self.assertEqual([231,524,690],[e["command"] for e in self.result["recenter_events"]])
        self.assertAlmostEqual(.045,sum(e["origin_advance_m"] for e in self.result["recenter_events"]),places=12)
        self.assertFalse(self.result["terminal_bias_capped"]);self.assertGreater(self.result["terminal_triangle_margin_m"],.02)
        self.assertTrue(all(c["endpoint_forward_m"]>.012 for c in self.result["cycles"]))
    def test_planned_foot_dwell_blocks_despite_remaining_three_support(self):
        r=self.result;self.assertEqual(922,r["first_counterfactual_six_command"]);self.assertEqual(15,r["longest_counterfactual_remaining_three_dwell"])
        self.assertEqual(1,r["maximum_original_four_contact_dwell"]);self.assertFalse(r["counterfactual_is_behavioral_evidence"]);self.assertFalse(r["original_observation_regraded"])
    def test_crossed_clock_recenter_and_original_readiness_refuse(self):
        for kind in ("clock","recenter","readiness"):
            rows=copy.deepcopy(self.rows)
            if kind=="clock":rows[0]["command"]=2
            elif kind=="recenter":rows[230]["output"]["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"]["origin_rebase"]["next_origin_world_m"]["x"]+=.01;rows[230]["output"]["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"]["origin_rebase"]["body_translation_after_recenter_world_m"]["x"]+=.01
            else:rows[918]["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]["readiness_conditions_met"]=True
            with self.assertRaises(ValueError):d.analyze(rows,self.value,self.reader)
if __name__=="__main__":unittest.main()
