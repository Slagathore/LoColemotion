"""Retained manifest/source/runtime/summary controls; no repeated physical work."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import audit_gpu_repertoire_negative_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("gpu_repertoire_negative_closure_v1.json")
        cls.record = json.loads(cls.path.read_text())
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("gpu-repertoire-negative-controls-" + uuid.uuid4().hex)
        cls.output.mkdir()

    def altered(self, change):
        record = copy.deepcopy(self.record)
        change(record)
        path = self.output / (uuid.uuid4().hex + ".json")
        path.write_text(json.dumps(record), encoding="utf-8", newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path, self.root, self.core, self.baseline)

    def test_all_artifacts_sources_runtime_and_timing_are_verified(self):
        # The full independent reader already ran at the prospective freeze.
        # This default checker must accurately state that it does not repeat it.
        with patch.object(reader, "audit", side_effect=AssertionError("Unexpected repeat of complete reader")):
            result = self.verify(self.path)
        self.assertEqual(result["artifact_count"], 759)
        self.assertEqual(result["original_independent_reader_controller_rows"], 17280)
        self.assertEqual(result["original_independent_reader_internal_rows"], 86400)
        self.assertTrue(result["timing_summary_recomputed"])
        self.assertFalse(result["full_controller_replay_performed"])

    def test_claim_source_population_and_inventory_changes_refuse(self):
        changes = [lambda r: r.__setitem__("training_data_authority", False),
            lambda r: r.__setitem__("trained_provider", True),
            lambda r: r.__setitem__("source_commit", "0" * 40),
            lambda r: r.__setitem__("controller_rows", 17281),
            lambda r: r["artifacts"].pop(),
            lambda r: r["artifacts"].__setitem__(1, r["artifacts"][0]),
            lambda r: r["complete_zero_world_gate"].__setitem__("graph_execution_tests", 70)]
        for change in changes:
            with self.assertRaises(ValueError):
                self.verify(self.altered(change))

    def test_digest_and_eligible_case_corruption_refuse(self):
        for change in [lambda r: r["artifacts"][0].__setitem__("sha256", "0" * 64),
                       lambda r: r.__setitem__("eligible_episodes", 1)]:
            with self.assertRaises(ValueError):
                self.verify(self.altered(change))

    def test_runtime_and_frozen_source_corruption_refuse(self):
        attempt = self.root / self.record["attempt_id"]
        bindings = json.loads((attempt / "declaration.json").read_text())["binding"]
        source = dict(bindings["source"])
        source[next(iter(source))] = "0" * 64
        with self.assertRaisesRegex(ValueError, "Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"], source)
        runtime = Path(next(iter(bindings["runtime"])))
        real_sha = reader.sha
        with patch.object(reader, "sha", side_effect=lambda path: "0" * 64 if Path(path) == runtime else real_sha(path)):
            with self.assertRaisesRegex(ValueError, "Runtime bytes"):
                self.verify(self.path)


if __name__ == "__main__":
    unittest.main()
