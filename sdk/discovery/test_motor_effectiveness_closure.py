"""Corrupt the retained pilot closure without constructing new physics worlds."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
import audit_motor_effectiveness_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("gpu_motor_effectiveness_closure_v1.json")
        cls.record = reader.read(cls.path)
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("motor-closure-controls-"+uuid.uuid4().hex)
        cls.output.mkdir()

    def altered(self, change):
        record = copy.deepcopy(self.record)
        change(record)
        path = self.output/(uuid.uuid4().hex+".json")
        path.write_text(json.dumps(record), encoding="utf-8", newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path, self.root, self.core, self.baseline)

    def test_complete_retained_result_and_zero_world_verification(self):
        with patch.object(reader, "audit_phase", side_effect=AssertionError("Unexpected full replay")), \
                patch.object(mujoco, "MjModel", side_effect=AssertionError("World")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Data")):
            result = self.verify(self.path)
        self.assertTrue(result["ok"])
        self.assertEqual(result["original_independent_reader_controller_rows"], 57600)
        self.assertEqual(result["original_independent_reader_internal_rows"], 288000)
        self.assertEqual(result["reader_world_build_count"], 0)
        self.assertFalse(result["full_controller_replay_performed"])
        summary = result["finite_outcomes"]
        self.assertEqual((summary["discovery_eligible"], summary["discovery_negative"]), (75, 15))
        self.assertEqual((summary["confirmation_eligible"], summary["confirmation_negative"]), (24, 6))
        self.assertTrue(summary["healthy_guard_passed"])
        self.assertFalse(summary["finite_conditioning_value"])
        self.assertFalse(result["qualification_or_release_authority"])
        self.assertEqual({r["condition_id"] for r in summary["confirmation_failures"]}, {"left_075"})
        self.assertTrue(all(r == dict(eligible=8, negative=2, denominator=10)
                            for r in summary["confirmation_roles"].values()))

    def test_authority_population_and_inventory_corruption_refuse(self):
        changes = [lambda r: r.__setitem__("training_data_authority", False),
            lambda r: r.__setitem__("confirmation_training_authority", True),
            lambda r: r.__setitem__("adaptive_provider_benefit", True),
            lambda r: r.__setitem__("noninferiority_authority", True),
            lambda r: r.__setitem__("constructed_gpu_worlds", 119),
            lambda r: r.__setitem__("internal_rows", 287999),
            lambda r: r["complete_zero_world_gate"].__setitem__("motor-route", 4),
            lambda r: r["artifacts"].pop(),
            lambda r: r["artifacts"].__setitem__(1, r["artifacts"][0])]
        for change in changes:
            value = copy.deepcopy(self.record); change(value)
            with self.assertRaises(ValueError): reader.header(value, self.root)

    def test_selection_comparison_and_negative_outcome_changes_refuse(self):
        changes = [lambda r: r.__setitem__("discovery_audit_sha256", "0"*64),
            lambda r: r["selection"]["conditions"]["left_075"].__setitem__("executed_action_index", 7),
            lambda r: r["comparison"].__setitem__("finite_conditioning_value", True),
            lambda r: r["finite_outcomes"].__setitem__("confirmation_negative", 0),
            lambda r: r["finite_outcomes"]["confirmation_roles"]["condition_known"].__setitem__("eligible", 10),
            lambda r: r["artifacts"][0].__setitem__("sha256", "0"*64)]
        for change in changes:
            with self.assertRaises(ValueError): self.verify(self.altered(change))

    def test_frozen_source_runtime_and_reader_bytes_are_checked(self):
        bindings = reader.read(self.root/self.record["attempt_id"]/"declaration.json")["binding"]
        sources = dict(bindings["source"]); sources[next(iter(sources))] = "0"*64
        with self.assertRaisesRegex(ValueError, "Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"], sources)
        target = Path(next(iter(bindings["runtime"])))
        original = reader.sha
        with patch.object(reader, "sha", side_effect=lambda p: "0"*64 if Path(p) == target else original(p)):
            with self.assertRaisesRegex(ValueError, "Runtime bytes"): self.verify(self.path)
        with self.assertRaisesRegex(ValueError, "Closure reader changed"):
            self.verify(self.altered(lambda r: r.__setitem__("closure_reader_sha256", "0"*64)))


if __name__ == "__main__":
    unittest.main()
