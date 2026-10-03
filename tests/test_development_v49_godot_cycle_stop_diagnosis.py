import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "sdk/conformance"))
import development_v49_godot_cycle_stop_diagnosis as d


class Diagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report, cls.reader = d.read_source()
        cls.result = d.analyze(cls.report, cls.reader)

    def test_planned_cycles_and_original_evaluation_both_retained(self):
        self.assertEqual([238, 717, 1045, 557], [c["first_supported_stance"] for c in self.result["cycles"]])
        self.assertTrue(all(.059 < c["endpoint_forward_m"] < .067 for c in self.result["cycles"]))
        self.assertEqual(["every_limb_forward_relocation"], self.result["original_walking_evaluation"]["false_walking_receipts"])
        self.assertTrue(self.result["final_30_commands_settled"])
        self.assertFalse(self.result["historical_fixed_tail_coverage_complete"])
        self.assertFalse(self.result["physical_acceptance_authority"])

    def test_required_support_losses_are_not_censored(self):
        self.assertEqual(36, self.result["contact_loss_episode_count"])
        self.assertEqual(21, self.result["required_support_onset_episode_count"])
        self.assertEqual(17, self.result["required_support_maximum_absent_samples"])
        self.assertLess(self.result["required_support_minimum_endpoint_forward_m"], -.012)
        self.assertFalse(self.result["original_observation_regraded"])
        self.assertEqual(0, self.result["new_world_count"])

    def test_crossed_clock_contact_stop_and_reader_refused(self):
        for kind in ("clock", "contact", "stop", "reader"):
            # Copy only the modified branch of the large immutable source.
            report = dict(self.report)
            retained = dict(report["development_cycle_stop"])
            retained["rows"] = list(retained["rows"])
            retained["rows"][-1] = copy.deepcopy(retained["rows"][-1])
            report["development_cycle_stop"] = retained
            last = retained["rows"][-1]
            reader = copy.deepcopy(self.reader)
            if kind == "clock": last["session_local_step"] = 3
            elif kind == "contact": last["post_native_source"]["observation"]["state"]["ordered_contact_observations"][0]["presence"] = None
            elif kind == "stop": last["advance_receipt"]["postcommand_settled"] = False
            else: reader["walking_control_replay"]["cycle_stop_final_memory"]["completed"].pop("rear_left")
            with self.assertRaises(ValueError):
                d.analyze(report, reader)


if __name__ == "__main__":
    unittest.main()
