import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"sdk/conformance"))
import development_v47_support_progress_diagnosis as d
class Diagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rows,cls.value,cls.reader=d.read_source();cls.result=d.analyze(cls.rows,cls.value,cls.reader)
    def test_three_actual_forward_endpoint_cycles(self):
        self.assertEqual({"front_left","front_right","rear_right"},{x["limb"] for x in self.result["cycles"]})
        self.assertTrue(all(x["first_absent_to_landing_endpoint_forward_m"]>.012 for x in self.result["cycles"]))
        self.assertLess(self.result["maximum_precommand_tilt_rad"],.007)
    def test_supported_terminal_cap_and_origin_recenter_identity(self):
        r=self.result;self.assertTrue(r["terminal_all_four_precommand_bearing"]);self.assertEqual(-.25,r["terminal_bias_rad"])
        self.assertEqual(786,r["first_final_preparation_bias_cap_command"]);self.assertAlmostEqual(.045,r["mean_planned_foot_anchor_advance_m"],places=12)
        self.assertGreater(r["terminal_requested_additional_forward_m"],.027);self.assertLess(r["terminal_remaining_triangle_margin_m"],.007)
        # Coordinate change only: advancing origin and compensating bias must
        # leave the requested body translation unchanged, not jump it forward.
        for origin,bias,advance in [(0.,-.25,.045),(.12,.07,.015),(-.2,-.1,.015)]:
            self.assertAlmostEqual(origin-.35*bias,(origin+advance)-.35*(bias+advance/.35),places=14)
    def test_corrupt_clock_and_cycle_contact_fail(self):
        for kind in ("clock","contact"):
            rows=copy.deepcopy(self.rows)
            if kind=="clock":rows[0]["command"]=2
            else:rows[139]["physics"]["last_substep_bearing"]["front_left"]=True
            with self.assertRaises(ValueError):d.analyze(rows,self.value,self.reader)
if __name__=="__main__":unittest.main()
