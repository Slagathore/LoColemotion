"""Retained CPU stance closure and descriptive diagnostic controls; no new physics."""
import copy
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import mujoco
import audit_cpu_stance_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("cpu_stance_discovery_closure_v1.json")
        cls.record = reader.read(cls.path)
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("cpu-stance-closure-corruptions-"+uuid.uuid4().hex)
        cls.output.mkdir()

    def altered(self, change):
        value = copy.deepcopy(self.record); change(value)
        path = self.output/(uuid.uuid4().hex+".json")
        path.write_text(json.dumps(value), encoding="utf-8", newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path, self.root, self.core, self.baseline)

    def test_complete_bytes_and_original_audit_with_zero_world_construction(self):
        with patch.object(reader, "audit", side_effect=AssertionError("Unexpected full replay")), \
                patch.object(mujoco, "MjModel", side_effect=AssertionError("World")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Data")):
            result = self.verify(self.path)
        self.assertTrue(result["ok"])
        self.assertFalse(result["full_controller_replay_performed"])
        self.assertEqual(result["original_independent_reader_controller_rows"], 11520)
        self.assertEqual(result["original_independent_reader_internal_rows"], 57600)
        summary = result["finite_outcomes"]
        self.assertEqual((summary["eligible"], summary["negative"], summary["denominator"]), (0, 24, 24))
        self.assertTrue(all("tilt" in t["failure_code"] and "torso_contact" in t["failure_code"] for t in summary["trials"]))
        self.assertIsNone(summary["ranking"]["selected_feedback_index"])
        self.assertEqual(summary["ranking"]["ranked_feedback_indices"], [])
        self.assertTrue(result["training_data_authority"])
        self.assertEqual(result["pre_failure_diagnostic"]["feedback_only_denominator"], 20)
        self.assertTrue(all(t["episode_metrics"]["quality_m_s"] is None for t in summary["trials"]))
        self.assertFalse(result["qualification_or_release_authority"])

    def test_authority_population_and_incomplete_inventory_refuse(self):
        changes = [lambda r: r.__setitem__("training_data_authority", False),
            lambda r: r.__setitem__("adaptive_provider_benefit", True),
            lambda r: r.__setitem__("noninferiority_authority", True),
            lambda r: r.__setitem__("constructed_cpu_worlds", 3),
            lambda r: r.__setitem__("internal_rows", 57599),
            lambda r: r["complete_zero_world_gate"].__setitem__("cpu-motor", 6),
            lambda r: r["artifacts"].pop(), lambda r: r["artifacts"].__setitem__(1, r["artifacts"][0]),
            lambda r: r.__setitem__("artifact_bytes", r["artifact_bytes"]-1)]
        for change in changes:
            value = copy.deepcopy(self.record); change(value)
            with self.assertRaises(ValueError): reader.header(value, self.root)

    def test_changed_receipt_audit_or_erased_negatives_refuse(self):
        changes = [lambda r: r.__setitem__("receipt_sha256", "0"*64),
            lambda r: r.__setitem__("audit_sha256", "0"*64),
            lambda r: r["finite_outcomes"].__setitem__("negative", 0),
            lambda r: r["finite_outcomes"]["trials"][0].__setitem__("failure_code", None),
            lambda r: r["artifacts"][0].__setitem__("sha256", "0"*64),
            lambda r: r["finite_outcomes"]["ranking"].__setitem__("selected_feedback_index", 2),
            lambda r: r["pre_failure_diagnostic"]["feedback_only_totals"].__setitem__("absolute_clamped_commands", 0),
            lambda r: r.__setitem__("diagnostic_reader_sha256", "0"*64)]
        for change in changes:
            with self.assertRaises(ValueError): self.verify(self.altered(change))

    def test_frozen_source_runtime_and_closure_reader_refuse_tampering(self):
        binding = reader.read(self.root/self.record["attempt_id"]/"declaration.json")["binding"]
        sources = dict(binding["source"]); sources[next(iter(sources))] = "0"*64
        with self.assertRaisesRegex(ValueError, "Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"], sources)
        target = Path(next(iter(binding["runtime"]))); original = reader.sha
        with patch.object(reader, "sha", side_effect=lambda p: "0"*64 if Path(p) == target else original(p)):
            with self.assertRaisesRegex(ValueError, "Runtime bytes"): self.verify(self.path)
        with self.assertRaisesRegex(ValueError, "Closure reader changed"):
            self.verify(self.altered(lambda r: r.__setitem__("closure_reader_sha256", "0"*64)))


    def test_diagnostic_cutoff_counts_support_and_all_limit_stages(self):
        from stance_pre_failure_diagnostic import first_violation, control_counts
        samples = [dict(step=i, time_s=i/600, qpos=[0.,0.,.4,1.,0.,0.,0.], contacts=[]) for i in [1,2,3]]
        samples[1]["qpos"][3:7] = [math.cos(.35),math.sin(.35),0.,0.]
        samples[2]["qpos"][2] = .1
        cutoff = first_violation(samples, dict(minimum_height_m=.25, maximum_tilt_rad=.6, maximum_torso_contact_steps=0))
        self.assertEqual(cutoff, dict(internal_step=2, time_s=2/600, failure_codes=["tilt"]))
        commands = [dict(absolute_correction_clamped=False, slew_clamped=False, final_speed_clamped=False,
            proposed_correction_rad_s=0., applied_correction_rad_s=0.) for _ in range(8)]
        commands[0].update(absolute_correction_clamped=True, slew_clamped=True, proposed_correction_rad_s=-2., applied_correction_rad_s=-.02)
        commands[1].update(final_speed_clamped=True)
        state = dict(ordered_joint_observations=[dict(joint_id="front_left_knee", position_rad=.05),
            dict(joint_id="rear_left_knee", position_rad=1.2)], ordered_contact_observations=[
            dict(contact_site_id="front_left_foot", presence=True, bears_support=True),
            dict(contact_site_id="rear_left_foot", presence=True, bears_support=False)])
        row = dict(outer_step=0, output=dict(actuation=dict(safe_no_actuation=False)),
            resolution=dict(ordered_commands=commands), request=dict(state=state), feedback=dict(status="supported"))
        later = copy.deepcopy(row); later["outer_step"] = 1
        result = control_counts([row,later], cutoff)
        for key in ["controller_rows", "absolute_clamped_commands", "slew_clamped_commands", "final_speed_clamped_commands",
            "steps_with_absolute_clamp", "supported_leg_observations", "near_straight_supported_knees"]:
            self.assertEqual(result[key], 1, key)
        self.assertEqual(result["actuator_commands"], 8)
        self.assertEqual(result["maximum_absolute_proposed_rad_s"], 2.)
        self.assertEqual(result["maximum_absolute_applied_rad_s"], .02)
        self.assertEqual((result["minimum_supported_knee_rad"], result["maximum_supported_knee_rad"]), (.05,.05))
        row["output"]["actuation"]["safe_no_actuation"] = True
        with self.assertRaisesRegex(ValueError, "Earlier controller eligibility"):
            control_counts([row], cutoff)

    def test_post_hoc_diagnostic_cannot_change_ranking_or_authority(self):
        diagnostic = self.record["pre_failure_diagnostic"]
        self.assertTrue(diagnostic["post_hoc"])
        self.assertTrue(all(diagnostic[k] is False for k in ["causal_authority", "selection_authority", "acceptance_authority"]))
        self.assertEqual(len(diagnostic["trials"]), 24)
        self.assertTrue(all(t["first_physical_violation"]["failure_codes"] == ["tilt"] for t in diagnostic["trials"]))
        c = reader.declaration()
        observed = reader.read(self.root/self.record["attempt_id"]/"independent-audit.json")
        self.assertEqual(reader.rank(observed["trials"], c), self.record["finite_outcomes"]["ranking"])
        missing = copy.deepcopy(observed["trials"]); missing.pop()
        with self.assertRaisesRegex(ValueError, "ranking population"):
            reader.rank(missing, c)


if __name__ == "__main__":
    unittest.main()
