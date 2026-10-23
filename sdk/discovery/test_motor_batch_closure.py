"""Retained matched-diagnostic closure controls; no new physics."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import mujoco
import audit_motor_batch_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("gpu_motor_batch_closure_v1.json")
        cls.record = reader.read(cls.path)
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("matched-closure-corruptions-"+uuid.uuid4().hex)
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
        self.assertEqual(result["original_independent_reader_controller_rows"], 23040)
        self.assertEqual(result["original_independent_reader_internal_rows"], 115200)
        summary = result["finite_outcomes"]
        self.assertEqual((summary["eligible"], summary["negative"], summary["denominator"]), (12, 36, 48))
        self.assertEqual(summary["action6_by_start"], dict(start_002=dict(eligible=11,negative=0,denominator=11),
            start_0035=dict(eligible=0,negative=11,denominator=11)))
        self.assertEqual((summary["start_change_eligibility_disagreements"], summary["other_eligibility_disagreements"]), (4, 0))
        self.assertFalse(result["qualification_or_release_authority"])

    def test_authority_population_and_missing_duplicate_inventory_refuse(self):
        changes = [lambda r: r.__setitem__("training_data_authority", True),
            lambda r: r.__setitem__("adaptive_provider_benefit", True),
            lambda r: r.__setitem__("noninferiority_authority", True),
            lambda r: r.__setitem__("constructed_gpu_worlds", 47),
            lambda r: r.__setitem__("internal_rows", 115199),
            lambda r: r["complete_zero_world_gate"].__setitem__("motor-batch", 5),
            lambda r: r["artifacts"].pop(), lambda r: r["artifacts"].__setitem__(1,r["artifacts"][0])]
        for change in changes:
            value=copy.deepcopy(self.record); change(value)
            with self.assertRaises(ValueError): reader.header(value, self.root)

    def test_changed_audit_comparison_or_erased_negatives_refuse(self):
        changes = [lambda r:r.__setitem__("audit_sha256", "0"*64),
            lambda r:r["comparisons"][0].__setitem__("eligibility_disagreement", True),
            lambda r:r["finite_outcomes"].__setitem__("negative", 0),
            lambda r:r["artifacts"][0].__setitem__("sha256", "0"*64)]
        for change in changes:
            with self.assertRaises(ValueError): self.verify(self.altered(change))

    def test_frozen_source_runtime_and_closure_reader_bytes_refuse_tampering(self):
        binding=reader.read(self.root/self.record["attempt_id"]/"declaration.json")["binding"]
        sources=dict(binding["source"]); sources[next(iter(sources))]="0"*64
        with self.assertRaisesRegex(ValueError,"Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"], sources)
        target=Path(next(iter(binding["runtime"]))); original=reader.sha
        with patch.object(reader,"sha",side_effect=lambda p:"0"*64 if Path(p)==target else original(p)):
            with self.assertRaisesRegex(ValueError,"Runtime bytes"): self.verify(self.path)
        with self.assertRaisesRegex(ValueError,"Closure reader changed"):
            self.verify(self.altered(lambda r:r.__setitem__("closure_reader_sha256","0"*64)))


if __name__ == "__main__":
    unittest.main()
