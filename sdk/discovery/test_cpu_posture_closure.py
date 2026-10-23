"""Retained posture factorial closure controls; no new physics."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import mujoco
import audit_cpu_posture_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("cpu_posture_discovery_closure_v1.json")
        cls.record = reader.read(cls.path)
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("cpu-posture-closure-corruptions-"+uuid.uuid4().hex)
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
        self.assertEqual(result["original_independent_reader_controller_rows"], 8640)
        self.assertEqual(result["original_independent_reader_internal_rows"], 43200)
        summary = result["finite_outcomes"]
        self.assertEqual((summary["eligible"], summary["negative"], summary["denominator"]), (1, 17, 18))
        positive = [t for t in summary["trials"] if t["outcome"] == "positive"]
        self.assertEqual(len(positive), 1)
        self.assertEqual(positive[0]["trial_id"], "start_005_feedback_a350_s008_p8")
        self.assertEqual(positive[0]["eligible_window_count"], 16)
        self.assertEqual(positive[0]["native_metrics"]["forward_displacement_m"], .3803999597149302)
        self.assertEqual(positive[0]["episode_metrics"]["quality_m_s"], -.12938342609786962)
        self.assertIsNone(positive[0]["native_metrics"]["first_physical_violation"])
        negatives = [t for t in summary["trials"] if t["outcome"] == "negative"]
        self.assertEqual(len(negatives), 17)
        self.assertTrue(all("tilt" in t["failure_code"] and "torso_contact" in t["failure_code"] for t in negatives))
        self.assertTrue(all(t["episode_metrics"]["quality_m_s"] is None and t["eligible_window_count"] == 0 for t in negatives))
        self.assertIsNone(summary["ranking"]["selected_feedback_index"])
        self.assertEqual(summary["ranking"]["ranked_feedback_indices"], [])
        self.assertTrue(result["training_data_authority"])
        self.assertFalse(result["qualification_or_release_authority"])

    def test_authority_population_and_incomplete_inventory_refuse(self):
        changes = [lambda r: r.__setitem__("training_data_authority", False),
            lambda r: r.__setitem__("adaptive_provider_benefit", True),
            lambda r: r.__setitem__("noninferiority_authority", True),
            lambda r: r.__setitem__("constructed_cpu_worlds", 3),
            lambda r: r.__setitem__("internal_rows", 43199),
            lambda r: r["complete_zero_world_gate"].__setitem__("posture-feedback", 7),
            lambda r: r["artifacts"].pop(), lambda r: r["artifacts"].__setitem__(1, r["artifacts"][0]),
            lambda r: r.__setitem__("artifact_bytes", r["artifact_bytes"]-1)]
        for change in changes:
            value = copy.deepcopy(self.record); change(value)
            with self.assertRaises(ValueError): reader.header(value, self.root)

    def test_changed_receipt_audit_or_erased_outcomes_refuse(self):
        changes = [lambda r: r.__setitem__("receipt_sha256", "0"*64),
            lambda r: r.__setitem__("audit_sha256", "0"*64),
            lambda r: r["finite_outcomes"].__setitem__("negative", 0),
            lambda r: r["finite_outcomes"]["trials"][0].__setitem__("failure_code", None),
            lambda r: r["artifacts"][0].__setitem__("sha256", "0"*64),
            lambda r: r["finite_outcomes"]["ranking"].__setitem__("selected_feedback_index", 8),
            lambda r: r["finite_outcomes"]["trials"][-1]["episode_metrics"].__setitem__("quality_m_s", 0.),
            lambda r: r["finite_outcomes"]["factorial_diagnostics"]["pairs"][0].__setitem__("eligibility_change", 1),
            lambda r: r["finite_outcomes"]["trials"][-1]["pre_violation_activity"].__setitem__("controller_rows", 0),
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

    def test_positive_quality_and_negative_interpretations_are_recomputed(self):
        target = self.root/self.record["attempt_id"]/"independent-audit.json"
        original = reader.read
        changes = [
            (lambda a: a["trials"][-1]["episodes"][0]["windows"][0].__setitem__("quality_m_s", 0.), "Eligible tracking quality changed"),
            (lambda a: a["trials"][0]["episodes"][0].__setitem__("outcome", "positive"), "Failed episode interpretation changed"),
            (lambda a: a["trials"][-1]["episodes"][0]["windows"].pop(), "Eligible window denominator")]
        for change, message in changes:
            altered = original(target); change(altered)
            with patch.object(reader, "read", side_effect=lambda p: altered if Path(p) == target else original(p)):
                with self.assertRaisesRegex(ValueError, message): self.verify(self.path)

    def test_all_factorial_pairs_preserve_censoring_and_do_not_select_on_failure_time(self):
        c = reader.declaration()
        observed = reader.read(self.root/self.record["attempt_id"]/"independent-audit.json")
        diagnostic = reader.factorial_pairs(c, reader.trial_plan(c), observed["trials"])
        self.assertEqual(diagnostic, self.record["finite_outcomes"]["factorial_diagnostics"])
        self.assertEqual(diagnostic["pair_count"], 24)
        self.assertTrue(diagnostic["prospective"])
        self.assertFalse(diagnostic["failure_timing_used_for_selection"])
        self.assertTrue(all(p["quality_change_if_both_eligible_m_s"] is None for p in diagnostic["pairs"]))
        for axis in c["challenge"]["factorial_axes"]:
            pairs = [p for p in diagnostic["pairs"] if p["axis"] == axis]
            self.assertEqual(len(pairs), 8)
            self.assertEqual(sum(p["eligibility_change"] for p in pairs), 1)
            censored = [p for p in pairs if p["high_first_physical_violation"] is None]
            self.assertEqual(len(censored), 1)
            self.assertIsNone(censored[0]["physical_violation_time_change_if_both_observed_s"])
        changed = copy.deepcopy(observed["trials"])
        for trial in changed:
            first = trial["metrics"][0]["first_physical_violation"]
            if first is not None: first["time_s"] += 1000.
        self.assertEqual(reader.rank(changed, c), observed["ranking"])
        with self.assertRaisesRegex(ValueError, "ranking population"): reader.rank(changed[:-1], c)
        with self.assertRaisesRegex(ValueError, "Factorial pair population"):
            reader.factorial_pairs(c, reader.trial_plan(c), changed[:-1])


if __name__ == "__main__":
    unittest.main()
