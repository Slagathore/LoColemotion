"""Retained-data component checks; no new physics or old-run acceptance."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "sdk/conformance"), str(ROOT / "sdk/python")]
import development_v50_godot_cycle_stop_diagnosis as source
import finite_recovery_walking as walking
from sporespore_locomotion import LocomotionCore


class FiniteWalking(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report, cls.reader = source.read_source()
        source.analyze(cls.report, cls.reader)  # Reopen the already closed observation as it is.
        binding = json.loads((ROOT / "sdk/development/recovery_candidates/v50-startup-reference-velocity-core-v1.runtime.json").read_text())
        core = LocomotionCore(binding["runtime"]["path"])
        cls.compiled = core.compile_bounded_quadruped(cls.report["configuration"]["base_descriptor"])
        cls.contract = json.loads((ROOT / "sdk/recovery/r10g_finite_cycle_kick_recovery_contract_v1.json").read_text())
        initial = core.balanced_wave_policy_initial_memory(cls.contract["controller_composition"]["post_interaction_walking"], cls.report["configuration"]["base_descriptor"])
        assert [m["limb_id"] for m in initial["ordered_limb_memory"]] == cls.contract["controller_composition"]["ordered_native_limb_memory_ids"]
        cls.result = walking.measure(cls.report, cls.compiled, cls.contract)

    def altered_row(self, index=0):
        report = dict(self.report)
        entry = dict(report["development_walking_entry"])
        entry["rows"] = list(entry["rows"])
        entry["rows"][index] = copy.deepcopy(entry["rows"][index])
        report["development_walking_entry"] = entry
        return report, entry["rows"][index]

    def altered_post(self, index=-1):
        report = dict(self.report)
        retained = dict(report["development_cycle_stop"])
        retained["rows"] = list(retained["rows"])
        retained["rows"][index] = copy.deepcopy(retained["rows"][index])
        report["development_cycle_stop"] = retained
        return report, retained["rows"][index]

    def test_independent_endpoint_geometry_and_old_negative_coexist(self):
        self.assertTrue(self.result["planned_cycle_predicate"])
        self.assertTrue(self.result["complete_stop_predicate"])
        self.assertTrue(self.result["body_forward_predicate"])
        expected = [.05813759161084364, .05979159497290071, .06464244231480237, .07124157712640303]
        for cycle, advance in zip(self.result["planned_cycles"], expected):
            self.assertAlmostEqual(cycle["measured_endpoint_forward_m"], advance, places=12)
            self.assertGreaterEqual(cycle["maximum_consecutive_absent_samples"], 3)
        old = next(s["evaluation"] for s in self.report["retained_arm"]["walking_sessions"] if s["evaluation_segment_id"] == "walking_resume")
        self.assertEqual(["every_limb_forward_relocation"], old["false_walking_receipts"])
        self.assertFalse(self.result["source_run_regraded"])
        self.assertFalse(self.result["physical_acceptance_authority"])
        self.assertEqual("component_measurement_only", self.result["scope"])

    def test_controller_reported_geometry_cannot_make_a_step(self):
        report, row = self.altered_row()
        measurement = row["native_output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]["measurement"]
        measurement["ordered_measured_capsule_endpoints_world_m"] = [{"x": 1000, "y": 1000, "z": 1000}]*4
        measurement["anatomical_forward_horizontal_world_unit"] = {"x": 0, "y": 1, "z": 0}
        self.assertEqual(self.result, walking.measure(report, self.compiled, self.contract))

    def test_every_required_support_loss_remains_visible(self):
        episodes = self.result["all_contact_loss_episodes"]
        required = [e for e in episodes if e["required_support_at_onset"]]
        self.assertEqual((33, 17), (len(episodes), len(required)))
        self.assertEqual(15, max(e["absent_samples"] for e in required))
        self.assertAlmostEqual(-.0030536371528606674, min(e["measured_endpoint_forward_m"] for e in required), places=12)
        self.assertAlmostEqual(.002634891742461537, max(e["maximum_nominal_gap_m"] for e in required), places=12)

    def test_stopping_uses_native_motion_and_contact_not_success_flags(self):
        for kind in ("speed", "angular", "contact"):
            report, post = self.altered_post()
            state = post["post_native_source"]["observation"]
            if kind == "speed": state["center_of_mass"]["linear_velocity_world_m_s"]["x"] = .04
            elif kind == "angular": state["state"]["base_twist_world"]["angular_velocity_rad_s"]["x"] = .2
            else: state["state"]["ordered_contact_observations"][0]["presence"] = False
            self.assertTrue(post["advance_receipt"]["postcommand_settled"])
            self.assertFalse(walking.measure(report, self.compiled, self.contract)["complete_stop_predicate"])

    def test_missing_flight_cannot_inherit_the_original_cutoff(self):
        report = dict(self.report)
        retained = dict(report["development_cycle_stop"])
        retained["rows"] = list(retained["rows"])
        for index in range(147, 247):
            retained["rows"][index] = copy.deepcopy(retained["rows"][index])
            contact = retained["rows"][index]["post_native_source"]["observation"]["state"]["ordered_contact_observations"][0]
            contact["presence"] = contact["bears_support"] = True
        report["development_cycle_stop"] = retained
        with self.assertRaisesRegex(ValueError, "STOP_BOUNDARY"):
            walking.measure(report, self.compiled, self.contract)

    def test_foot_cycles_cannot_substitute_for_body_advance(self):
        report, post = self.altered_post()
        initial = report["development_walking_entry"]["rows"][0]["request"]["state"]["base_pose_world"]["position_m"]
        post["post_native_source"]["observation"]["state"]["base_pose_world"]["position_m"] = dict(initial)
        measured = walking.measure(report, self.compiled, self.contract)
        self.assertTrue(measured["planned_cycle_predicate"])
        self.assertFalse(measured["body_forward_predicate"])

    def test_clock_body_contact_and_nonfinite_corruption_refused(self):
        for kind in ("clock", "duplicate_body", "duplicate_limb", "fractional_clock", "nonfinite", "contact"):
            if kind == "contact":
                report, post = self.altered_post()
                post["post_native_source"]["observation"]["state"]["ordered_contact_observations"][0]["presence"] = None
            else:
                report, row = self.altered_row()
                bodies = row["request"]["measured_body_frame"]["ordered_body_states"]
                limbs = row["native_output"]["next_memory"]["ordered_limb_memory"]
                if kind == "clock": row["measured_global_step"] += 1
                elif kind == "duplicate_body": bodies[2]["body_id"] = bodies[1]["body_id"]
                elif kind == "duplicate_limb": limbs[1]["limb_id"] = limbs[0]["limb_id"]
                elif kind == "fractional_clock": limbs[0]["gait_step"] = 90.5
                else: bodies[2]["pose_world"]["position_m"]["x"] = float("nan")
            with self.assertRaises(ValueError):
                walking.measure(report, self.compiled, self.contract)


if __name__ == "__main__":
    unittest.main()
