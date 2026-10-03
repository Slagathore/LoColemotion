import copy, sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "sdk/conformance"))
import development_v49_cycle_stop_diagnosis as d
class Diagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.value, cls.reader = d.read_source()
        cls.result = d.analyze(cls.rows, cls.value, cls.reader)
    def test_four_endpoint_cycles_and_settled_tail(self):
        self.assertEqual([231,690,1011,524], [c["first_supported_stance"] for c in self.result["cycles"]])
        self.assertTrue(all(c["endpoint_forward_m"] > .012 for c in self.result["cycles"]))
        self.assertTrue(self.result["final_30_postcommand_all_four_support"])
        self.assertEqual(0, self.result["new_world_count"])
        self.assertFalse(self.result["physical_acceptance_authority"])
    def test_unplanned_support_losses_remain_visible(self):
        self.assertEqual(62, self.result["contact_loss_episode_count"])
        self.assertEqual(20, self.result["required_support_onset_episode_count"])
        self.assertEqual(6, self.result["required_support_maximum_absent_samples"])
        self.assertLess(self.result["required_support_minimum_endpoint_forward_m"], -.003)
        self.assertFalse(self.result["original_observation_regraded"])
    def test_clock_stop_contact_and_cycle_corruption_refused(self):
        for kind in ("clock", "stop", "contact", "cycle"):
            rows = list(self.rows); rows[-1] = copy.deepcopy(rows[-1]); reader = copy.deepcopy(self.reader)
            if kind == "clock": rows[-1]["command"] = 3
            elif kind == "stop": rows[-1]["stopping"] = False
            elif kind == "contact": rows[-1]["physics"]["last_substep_bearing"]["front_left"] = None
            else: reader["cycle_progress"]["completed"].pop("rear_left")
            with self.assertRaises(ValueError): d.analyze(rows, self.value, reader)
if __name__ == "__main__": unittest.main()
