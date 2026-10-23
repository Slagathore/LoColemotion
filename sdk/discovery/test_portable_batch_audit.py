"""Corruption controls for the retained zero-world host benchmark."""
import copy
import json
import unittest
from audit_portable_batch import ROOT, RECORD, audit_benchmark, verify_component


class BatchEvidenceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads(RECORD.read_text())
        cls.folder = ROOT.parent / "SporeSpore_Evidence" / cls.record["attempt_id"] / "benchmark-01"
        cls.declaration = json.loads((cls.folder / "declaration.json").read_text())
        cls.result = json.loads((cls.folder / "result.json").read_text())
        cls.trials = [json.loads(line) for line in (cls.folder / "trials.jsonl").read_text().splitlines()]

    def test_complete_component_rehashes_and_recomputes(self):
        self.assertTrue(verify_component()["ok"])

    def test_missing_crossed_and_different_output_trials_refuse(self):
        wrong_digest = copy.deepcopy(self.trials)
        wrong_digest[0]["output_sha256"] = "0" * 64
        for trials in [self.trials[:-1], self.trials[::-1], wrong_digest]:
            with self.assertRaises(ValueError):
                audit_benchmark(self.declaration, trials, self.result)

    def test_timing_summary_and_authority_corruptions_refuse(self):
        for field, value in [("full_comparison_steps", 1), ("throughput_qualification", True), ("summaries", [])]:
            with self.assertRaises(ValueError):
                audit_benchmark(self.declaration, self.trials, dict(self.result, **{field: value}))

    def test_runtime_artifact_and_source_corruptions_refuse(self):
        for field in ["artifacts", "source_bindings"]:
            record = copy.deepcopy(self.record)
            record[field][0]["sha256"] = "0" * 64
            with self.assertRaises(ValueError):
                verify_component(record)
        with self.assertRaises(ValueError):
            verify_component(dict(self.record, attempt_id=".."))


if __name__ == "__main__":
    unittest.main()
