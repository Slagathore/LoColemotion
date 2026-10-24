"""Preserve the complete conditioned-feedback population and healthy-body comparison."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import mujoco
import audit_cpu_conditioned_feedback_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("cpu_conditioned_feedback_closure_v1.json")
        cls.record = reader.read(cls.path)
        cls.root = Path(cls.record["evidence_root"])
        cls.attempt = cls.root/cls.record["attempt_id"]
        cls.observed = reader.read(cls.attempt/"independent-audit.json")
        cls.c = reader.declaration()
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("conditioned-feedback-closure-corruptions-"+uuid.uuid4().hex)
        cls.output.mkdir()

    def setUp(self):
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guard = patch.object(mujoco, name, side_effect=AssertionError("No worlds in closure controls"))
            guard.start()
            self.addCleanup(guard.stop)

    def altered(self, change):
        value = copy.deepcopy(self.record)
        change(value)
        path = self.output/(uuid.uuid4().hex+".json")
        path.write_text(json.dumps(value), encoding="utf-8", newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path, self.root, self.core, self.baseline)

    def test_complete_population_and_finite_healthy_body_screen(self):
        with patch.object(reader, "audit", side_effect=AssertionError("Unexpected full replay")):
            result = self.verify(self.path)
        self.assertTrue(result["ok"])
        self.assertFalse(result["full_controller_replay_performed"])
        self.assertEqual((result["original_independent_reader_controller_rows"],
            result["original_independent_reader_internal_rows"]), (57600, 288000))
        self.assertEqual(result["reader_world_build_count"], 0)
        summary = result["finite_outcomes"]
        self.assertEqual((summary["eligible"], summary["negative"], summary["denominator"]), (26, 14, 40))
        table = {condition: [sum(t["condition_id"] == condition and t["selection_role_index"] == role
            and t["outcome"] == "positive" for t in summary["trials"]) for role in range(5)]
            for condition in ["left_075", "nominal"]}
        self.assertEqual(table, {"left_075": [0, 0, 2, 2, 2], "nominal": [4, 4, 4, 4, 4]})
        self.assertEqual(summary["repertoire"]["selected_role_index"], None)
        self.assertEqual(summary["repertoire"]["ranked_role_indices"], [])
        self.assertEqual(len(summary["repertoire"]["contrasts"]), 40)
        self.assertEqual(sum(c["both_eligible"] for c in summary["repertoire"]["contrasts"]), 23)
        self.assertTrue(all(t["eligible_window_count"] == (48 if t["outcome"] == "positive" else 0)
            for t in summary["trials"]))
        self.assertTrue(all(t["episode_metrics"]["quality_m_s"] is None
            for t in summary["trials"] if t["outcome"] == "negative"))
        self.assertEqual(len(summary["groups"]), 8)
        self.assertTrue(all(g["partition"] == "training" and g["matching_baseline_prefixes"] == 4
            and g["features"]["past_entries"] == 1 and not g["immediate_reference_has_baseline_prefix"]
            for g in summary["groups"]))
        self.assertTrue(result["training_data_authority"])
        self.assertTrue(result["controller_selection_authority"])
        self.assertFalse(result["qualification_or_release_authority"])

    def test_authority_population_and_inventory_refuse(self):
        changes = [
            lambda r: r.__setitem__("training_data_authority", False),
            lambda r: r.__setitem__("adaptive_provider_benefit", True),
            lambda r: r.__setitem__("noninferiority_authority", True),
            lambda r: r.__setitem__("evaluation_worlds", 1),
            lambda r: r.__setitem__("constructed_cpu_worlds", 39),
            lambda r: r.__setitem__("internal_rows", 287999),
            lambda r: r["complete_zero_world_gate"].__setitem__("cpu-conditioned-feedback", 11),
            lambda r: r["artifacts"].pop(),
            lambda r: r["artifacts"].__setitem__(1, r["artifacts"][0]),
            lambda r: r.__setitem__("artifact_bytes", r["artifact_bytes"]-1)]
        for change in changes:
            value = copy.deepcopy(self.record)
            change(value)
            with self.assertRaises(ValueError):
                reader.header(value, self.root)

    def test_finite_claims_erased_failures_and_healthy_comparisons_refuse(self):
        changes = [
            lambda r: r["finite_outcomes"].__setitem__("negative", 0),
            lambda r: r["finite_outcomes"]["repertoire"].__setitem__("selected_role_index", 99),
            lambda r: r["finite_outcomes"]["groups"][0].__setitem__("partition", "evaluation"),
            lambda r: r["finite_outcomes"]["repertoire"]["roles"][2].__setitem__(
                "nominal_observed_quality_preserved",
                not r["finite_outcomes"]["repertoire"]["roles"][2]["nominal_observed_quality_preserved"]),
            lambda r: r["finite_outcomes"]["repertoire"]["roles"][2]["nominal_preservation"][0].__setitem__(
                "quality_difference_m_s", 999.),
            lambda r: r["finite_outcomes"]["repertoire"]["contrasts"][0].__setitem__(
                "quality_difference_m_s", 999.)]
        for change in changes:
            value = copy.deepcopy(self.record)
            change(value)
            with self.assertRaisesRegex(ValueError, "Finite training selection"):
                reader.verify_finite_outcomes(value, self.observed, self.c)
        altered = copy.deepcopy(self.observed)
        altered["negative_episodes"] -= 1
        with self.assertRaisesRegex(ValueError, "Outcome denominator"):
            reader.verify_finite_outcomes(self.record, altered, self.c)

    def test_positive_windows_and_failure_censoring_are_recomputed(self):
        positive = next(t for t in self.observed["trials"] if t["episodes"][0]["outcome"] == "positive")
        negative = next(t for t in self.observed["trials"] if t["episodes"][0]["outcome"] == "negative")
        changes = [
            (positive, lambda t: t["episodes"][0]["windows"][0].__setitem__("quality_m_s", 999.),
                "Eligible tracking quality"),
            (positive, lambda t: t["episodes"][0]["windows"].pop(), "Eligible window denominator"),
            (positive, lambda t: t["episodes"][0]["metrics"].__setitem__("quality_m_s", 999.), "Eligible mean quality"),
            (negative, lambda t: t["episodes"][0].__setitem__("outcome", "positive"), "Failed episode interpretation"),
            (negative, lambda t: t["episodes"][0]["metrics"].__setitem__("quality_m_s", 0.), "Failed episode interpretation")]
        for original, change, message in changes:
            trial = copy.deepcopy(original)
            change(trial)
            with self.assertRaisesRegex(ValueError, message):
                reader.verify_episode(trial, self.c)

    def test_causal_values_and_actual_receipt_history_refuse(self):
        trial = self.observed["trials"][0]
        directory = self.attempt/"physical"/trial["trial_id"]
        core = reader.bridge.LocomotionCore(self.baseline)
        changed = copy.deepcopy(trial)
        changed["probe_features"]["values"][0] += .01
        with self.assertRaisesRegex(ValueError, "Causal feature values"):
            reader.verify_prefix(directory, changed, core)
        original = reader.read_jsonl
        rows = list(reader.islice(original(directory/"controller.jsonl"), 2))
        rows[1]["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]["resolution_receipt_sha256"] = "0"*64
        with patch.object(reader, "read_jsonl", return_value=iter(rows)):
            with self.assertRaisesRegex(ValueError, "Causal prefix original receipt"):
                reader.verify_prefix(directory, trial, core)
        immediate = self.observed["trials"][4]
        directory = self.attempt/"physical"/immediate["trial_id"]
        rows = list(reader.islice(original(directory/"controller.jsonl"), 2))
        rows[0]["activation_probe"]["features"] = {"invented_baseline_prefix": True}
        with patch.object(reader, "read_jsonl", return_value=iter(rows)):
            with self.assertRaisesRegex(ValueError, "Immediate reference cannot claim"):
                reader.verify_prefix(directory, immediate, core)

    def test_retained_artifact_source_and_runtime_bytes_refuse(self):
        changed = self.altered(lambda r: r["artifacts"][0].__setitem__("sha256", "0"*64))
        with self.assertRaisesRegex(ValueError, "Retained artifact changed"):
            self.verify(changed)
        binding = reader.read(self.attempt/"declaration.json")["binding"]
        sources = dict(binding["source"])
        sources[next(iter(sources))] = "0"*64
        with self.assertRaisesRegex(ValueError, "Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"], sources)
        target = Path(next(iter(binding["runtime"])))
        original = reader.sha
        with patch.object(reader, "sha", side_effect=lambda p: "0"*64 if Path(p) == target else original(p)):
            with self.assertRaisesRegex(ValueError, "Runtime bytes"):
                self.verify(self.path)

    def test_every_current_reader_binding_refuses_changes(self):
        for key in reader.READER_PATHS:
            value = copy.deepcopy(self.record)
            value["reader_bindings"][key] = "0"*64
            with self.assertRaises(ValueError):
                reader.verify_current_readers(value)
        value=copy.deepcopy(self.record)
        value["reader_bindings"].pop(reader.READER_PATHS[0])
        with self.assertRaises(ValueError):
            reader.verify_current_readers(value)

    def test_dynamic_sequences_influence_and_fixed_labels_cannot_be_substituted(self):
        trial=self.observed["trials"][2]
        directory=self.attempt/"physical"/trial["trial_id"]
        rows=list(reader.read_jsonl(directory/"controller.jsonl"))
        result=reader.read(directory/"result.json")
        core=reader.bridge.LocomotionCore(self.baseline)
        changed=copy.deepcopy(trial)
        changed["influence"]["nonzero_correction_steps"]+=1
        with self.assertRaisesRegex(ValueError,"Actual selection influence"):
            reader.verify_actions(rows,changed,result,self.c,core)
        changed=copy.deepcopy(trial)
        changed["episodes"][0]["action_id"]="phase_release"
        with self.assertRaisesRegex(ValueError,"Dynamic policy episode identity"):
            reader.verify_episode(changed,self.c)
        changed=copy.deepcopy(trial)
        changed["raw_bindings"][0]["policy_role_id"]="baseline"
        with self.assertRaisesRegex(ValueError,"Dynamic action/raw sequence"):
            reader.verify_actions(rows,changed,result,self.c,core)
        rows[1]["selection"]["decision"]["logical_action_index"]=0
        with self.assertRaisesRegex(ValueError,"Dynamic action/raw sequence"):
            reader.verify_actions(rows,trial,result,self.c,core)

    def test_healthy_and_degraded_native_models_cannot_be_crossed(self):
        original = reader.read
        for condition, wrong in [("left_075", "nominal"), ("nominal", "left_075")]:
            target = self.attempt/"physical/models"/condition/"native-model.json"
            altered = original(target)
            altered["condition_id"] = wrong
            with patch.object(reader, "read", side_effect=lambda p: altered if Path(p) == target else original(p)):
                with self.assertRaisesRegex(ValueError, "Condition native profile"):
                    self.verify(self.path)


if __name__ == "__main__":
    unittest.main()
