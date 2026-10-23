"""Native-corpus closure controls without constructing or rerunning a world."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
import audit_gpu_repertoire_fit_closure_v2 as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("gpu_repertoire_fit_closure_v2.json")
        cls.record = json.loads(cls.path.read_text())
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("gpu-repertoire-fit-controls-" + uuid.uuid4().hex)
        cls.output.mkdir()

    def altered(self, change):
        record = copy.deepcopy(self.record)
        change(record)
        path = self.output / (uuid.uuid4().hex + ".json")
        path.write_text(json.dumps(record), encoding="utf-8", newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path, self.root, self.core, self.baseline)

    def test_full_inventory_frozen_sources_runtime_and_pure_refit(self):
        with patch.object(reader, "audit", side_effect=AssertionError("Unexpected full replay")), \
                patch.object(mujoco, "MjModel", side_effect=AssertionError("Reader world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Reader data")):
            result = self.verify(self.path)
        self.assertEqual(result["artifact_count"], 768)
        self.assertEqual(result["original_independent_reader_controller_rows"], 17280)
        self.assertEqual(result["original_independent_reader_internal_rows"], 86400)
        self.assertTrue(result["timing_summary_recomputed"])
        self.assertTrue(result["pure_candidate_refit_performed"])
        self.assertFalse(result["full_controller_replay_performed"])
        self.assertFalse(result["native_influence_evaluated"])
        self.assertFalse(result["provider_promotion_authority"])
        self.assertEqual(result["fitted_cases"], 576)
        self.assertEqual(result["occupied_archive_cells"], 2)

    def test_claim_source_population_and_inventory_changes_refuse(self):
        changes = [lambda r: r.__setitem__("training_data_authority", False),
            lambda r: r.__setitem__("native_influence_evaluated", True),
            lambda r: r.__setitem__("provider_promotion_authority", True),
            lambda r: r.__setitem__("source_commit", "0" * 40),
            lambda r: r.__setitem__("controller_rows", 17281),
            lambda r: r["artifacts"].pop(),
            lambda r: r["artifacts"].__setitem__(1, r["artifacts"][0]),
            lambda r: r["complete_zero_world_gate"].__setitem__("retrieval_tests", 8)]
        for change in changes:
            with self.assertRaises(ValueError):
                self.verify(self.altered(change))

    def test_digest_case_counts_and_model_identity_changes_refuse(self):
        changes = [lambda r: r["artifacts"][0].__setitem__("sha256", "0" * 64),
            lambda r: r.__setitem__("eligible_episodes", 35),
            lambda r: r.__setitem__("fitted_cases", 575),
            lambda r: r.__setitem__("occupied_archive_cells", 3),
            lambda r: r.__setitem__("fitted_model_sha256", "sha256:" + "0" * 64)]
        for change in changes:
            with self.assertRaises(ValueError):
                self.verify(self.altered(change))

    def test_refit_rejects_crossed_raw_data_and_changed_measured_outcome(self):
        attempt = self.root / self.record["attempt_id"]
        receipt = json.loads((attempt / "receipt.json").read_text())
        retained = json.loads((attempt / "independent-audit.json").read_text())
        mutations = [lambda a: a["trials"][0]["raw_bindings"][0].__setitem__("seed", 1),
            lambda a: a["trials"][0]["episodes"][0].__setitem__("group_id", "calibration_0"),
            lambda a: a["trials"][0]["episodes"][0]["metrics"].__setitem__("mean_height_m", .5)]
        for change in mutations:
            altered = copy.deepcopy(retained)
            change(altered)
            with self.assertRaises(ValueError):
                reader.verify_fit(self.record, attempt, receipt, altered, self.core)

    def test_runtime_and_frozen_source_corruption_refuse(self):
        attempt = self.root / self.record["attempt_id"]
        bindings = json.loads((attempt / "declaration.json").read_text())["binding"]
        source = dict(bindings["source"])
        source[next(iter(source))] = "0" * 64
        with self.assertRaisesRegex(ValueError, "Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"], source)
        runtime = Path(next(iter(bindings["runtime"])))
        real_sha = reader.sha
        with patch.object(reader, "sha", side_effect=lambda p: "0" * 64 if Path(p) == runtime else real_sha(p)):
            with self.assertRaisesRegex(ValueError, "Runtime bytes"):
                self.verify(self.path)


if __name__ == "__main__":
    unittest.main()
