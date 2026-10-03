"""Entry checks on retained poses and bounded counterexamples; no native world."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import development_recovery_refusal as retained
import recovery_walking_readiness as readiness
import test_development_passive_entry_replay as shared


class WalkingReadiness(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)
    @classmethod
    def setUpClass(cls):
        _, _, cls.failed, cls.core = retained.reopen(ROOT.parent / "SporeSpore_Evidence/development-recovery-smoke-28741bb836464b7194943c960a8f65bb")
        source = ROOT.parent / "SporeSpore_Evidence/r10h-readiness-source-5af1b33630f34484be9c418e42416eb3"
        for name, expected in [("first_v50_command.json", "27b28261113f51cf017684d9841a0afaed910203c32f73a97bfa3fa18b9c6ef0"),
                               ("first_v50_native_source.json", "7f25668a5d88b7629e4da3a5b273ce43bea9a55d72ba5a07ce16dc5d858e57a6")]:
            assert hashlib.sha256((source / name).read_bytes()).hexdigest() == expected
        cls.good = json.loads((source / "first_v50_command.json").read_bytes())
        cls.native = json.loads((source / "first_v50_native_source.json").read_bytes())
        assert cls.native["full_step_receipt_sha256"] == cls.good["row"]["full_step_receipt_sha256"]
        assert cls.native["commanded_global_step"] == cls.good["row"]["commanded_global_step"] == 859
        cls.descriptor = cls.good["configuration"]["base_descriptor"]
        cls.compiled = cls.core.compile_bounded_quadruped(cls.descriptor)
        cls.limits = json.loads((ROOT / "sdk/recovery/r10h_stance_entry_finite_cycle_contract_v1.json").read_bytes())["stance_entry"]
        cls.request = cls.good["row"]["request"]
        cls.com = cls.native["native_source"]["observation"]["center_of_mass"]
        cls.root = ROOT.parent / "SporeSpore_Evidence" / ("recovery-readiness-native-"+uuid.uuid4().hex)
        cls.root.mkdir()
        print("RECOVERY_READINESS_NATIVE_ROOT", cls.root, flush=True)

    def test_actual_godot_guard_matches_independent_reader(self):
        failed_source = self.failed["development_native_walking_contacts"]["rows"][-1]["native_source"]
        cases = [dict(request=self.request, center_of_mass=self.com),
                 dict(request=self.failed["development_walking_entry"]["rows"][0]["request"],
                      center_of_mass=failed_source["observation"]["center_of_mass"])]
        for kind in ("contact", "speed", "geometry"):
            item = copy.deepcopy(cases[0])
            if kind == "contact": item["request"]["state"]["ordered_contact_observations"][0]["bears_support"] = False
            elif kind == "speed": item["center_of_mass"]["linear_velocity_world_m_s"]["x"] = .04
            else: item["request"]["measured_body_frame"]["ordered_body_states"][-1]["pose_world"]["position_m"]["x"] += .5
            cases.append(item)
        crossed = copy.deepcopy(cases[0]); crossed["request"]["measured_body_frame"]["semantic_step"] += 1
        path = self.root / "readiness_input.json"
        path.write_text(json.dumps(dict(cases=cases+[crossed], compiled=self.compiled, limits=self.limits))+"\n", encoding="utf-8")
        run = self._run_retained("res://tests/test_recovery_walking_readiness.gd", ["--", str(path)], "guard", 60)
        result = shared.marker(run, "RECOVERY_WALKING_READINESS ")
        self.assertEqual(len(cases)+1, len(result["results"]))
        for case, actual in zip(cases, result["results"]):
            expected = readiness.measure(case["request"], case["center_of_mass"], self.compiled, self.limits)
            self.assertEqual(expected["checks"], actual["checks"])
            self.assertEqual(expected["ready"], actual["ready"])
            for a, e in zip(actual["ordered_legs"], expected["ordered_legs"]):
                self.assertEqual(e["failed_references"], a["failed_references"])
                self.assertAlmostEqual(e["maximum_required_reach_m"], a["maximum_required_reach_m"], places=12)
                self.assertAlmostEqual(e["sagittal_offset_m"], a["sagittal_offset_m"], places=12)
        self.assertFalse(result["results"][-1]["ok"])
        self.assertEqual("timeout", result["dwell"]["outcome"])
        self.assertFalse(result["terminal"]["ok"])

    def test_existing_successful_entry_is_ready_without_regrading(self):
        result = readiness.measure(self.request, self.com, self.compiled, self.limits)
        self.assertTrue(result["ready"])
        self.assertEqual(73, result["reference_height_count"])
        self.assertFalse(result["future_contact_guaranteed"])
        self.assertFalse(result["physical_acceptance_authority"])

    def test_exposed_failed_entry_is_rejected_before_v50_memory(self):
        q = self.failed["development_walking_entry"]["rows"][0]["request"]
        source = self.failed["development_native_walking_contacts"]["rows"][-1]["native_source"]
        result = readiness.measure(q, source["observation"]["center_of_mass"], self.compiled, self.limits)
        self.assertFalse(result["ready"])
        self.assertFalse(result["checks"]["zero_bias_reference_path_feasible"])
        self.assertFalse(result["ordered_legs"][3]["geometric_path_feasible"])

    def test_contact_speed_and_geometry_are_independent_requirements(self):
        for kind in ("contact", "speed", "geometry"):
            q, com = copy.deepcopy(self.request), copy.deepcopy(self.com)
            if kind == "contact": q["state"]["ordered_contact_observations"][0]["bears_support"] = False
            elif kind == "speed": com["linear_velocity_world_m_s"]["x"] = .04
            else: q["measured_body_frame"]["ordered_body_states"][-1]["pose_world"]["position_m"]["x"] += .5
            self.assertFalse(readiness.measure(q, com, self.compiled, self.limits)["ready"])

    def test_crossed_frame_and_nonfinite_pose_refused(self):
        for kind in ("clock", "nan"):
            q = copy.deepcopy(self.request)
            if kind == "clock": q["measured_body_frame"]["semantic_step"] += 1
            else: q["measured_body_frame"]["ordered_body_states"][-1]["pose_world"]["position_m"]["x"] = float("nan")
            with self.assertRaises(ValueError): readiness.measure(q, self.com, self.compiled, self.limits)

    def test_existing_bw5_zero_amplitude_requests_neutral_goals(self):
        policy = "sporespore_balanced_wave_bw5r_b_v1"
        q = {k: copy.deepcopy(self.request[k]) for k in ("state", "command")}
        q["descriptor"] = self.descriptor
        q["memory"] = self.core.balanced_wave_policy_initial_memory(policy, self.descriptor)
        result = self.core.balanced_wave_policy_step(policy, retained.integers(q))
        self.assertFalse(result["actuation"]["safe_no_actuation"])
        self.assertEqual([0.]*8, [c["requested_target_position_rad"] for c in result["actuation"]["ordered_commands"]])

    def test_dwell_resets_on_loss_and_timeout_cannot_extend(self):
        memory = dict(commands=0, consecutive_ready=0, last_source_step=272, outcome="pending")
        for n in range(240):
            measurement = dict(ready=n % 30 != 29, source_semantic_step=273+n)
            memory = readiness.advance(memory, measurement, self.limits)
        self.assertEqual("timeout", memory["outcome"])
        with self.assertRaises(ValueError): readiness.advance(memory, dict(ready=True, source_semantic_step=513), self.limits)
        memory = dict(commands=0, consecutive_ready=0, last_source_step=272, outcome="pending")
        for n in range(30): memory = readiness.advance(memory, dict(ready=True, source_semantic_step=273+n), self.limits)
        self.assertEqual("ready", memory["outcome"])
        with self.assertRaises(ValueError): readiness.advance(memory, dict(ready=True, source_semantic_step=303), self.limits)


if __name__ == "__main__":
    unittest.main()
