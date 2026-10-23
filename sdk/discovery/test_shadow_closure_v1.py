"""Retained native shadow corruption controls; no new physical work."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import audit_gpu_retrieval_shadow_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("gpu_retrieval_shadow_closure_v1.json")
        cls.record = json.loads(cls.path.read_text())
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("shadow-closure-controls-" + uuid.uuid4().hex)
        cls.output.mkdir()

    def altered(self, change):
        record = copy.deepcopy(self.record)
        change(record)
        path = self.output / (uuid.uuid4().hex + ".json")
        path.write_text(json.dumps(record),encoding="utf-8",newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path,self.root,self.core,self.baseline)

    def test_retained_inventory_source_model_runtime_and_timing(self):
        with patch.object(reader,"audit",side_effect=AssertionError("Unexpected complete replay")):
            result=self.verify(self.path)
        self.assertEqual(result["artifact_count"],770)
        self.assertEqual(result["original_independent_reader_controller_rows"],480)
        self.assertEqual(result["original_independent_reader_shadow_rows"],2400)
        self.assertEqual(result["physical_provider_influence_rows"],0)
        self.assertTrue(result["shadow_ready_for_distinct_influence_design"])
        self.assertFalse(result["full_controller_replay_performed"])
        self.assertFalse(result["native_influence_evaluated"])
        self.assertFalse(result["training_data_authority"])

    def test_authority_source_population_and_inventory_changes_refuse(self):
        changes=[lambda r:r.__setitem__("native_influence_evaluated",True),
            lambda r:r.__setitem__("training_data_authority",True),
            lambda r:r.__setitem__("source_commit","0"*40),
            lambda r:r.__setitem__("shadow_rows",2399),
            lambda r:r.__setitem__("physical_provider_influence_rows",1),
            lambda r:r["artifacts"].pop(),
            lambda r:r["artifacts"].__setitem__(1,r["artifacts"][0]),
            lambda r:r["complete_zero_world_gate"].__setitem__("shadow-gate",8)]
        for change in changes:
            with self.assertRaises(ValueError):self.verify(self.altered(change))

    def test_model_digest_and_shadow_memory_summaries_refuse_corruption(self):
        changes=[lambda r:r["artifacts"][0].__setitem__("sha256","0"*64),
            lambda r:r.__setitem__("model_sha256","sha256:"+"0"*64),
            lambda r:r["shadow_summary"]["frozen"].__setitem__("hypothetical_nonzero_rows",448),
            lambda r:r["shadow_summary"]["episodic"].__setitem__("final_sequence",480),
            lambda r:r["shadow_summary"]["episodic"]["operations"].pop()]
        for change in changes:
            with self.assertRaises(ValueError):self.verify(self.altered(change))

    def test_frozen_source_runtime_and_external_candidate_bytes_are_checked(self):
        attempt=self.root/self.record["attempt_id"]
        bindings=json.loads((attempt/"declaration.json").read_text())["binding"]
        sources=dict(bindings["source"]);sources[next(iter(sources))]="0"*64
        with self.assertRaisesRegex(ValueError,"Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"],sources)
        real_sha=reader.sha
        for namespace,message in [("runtime","Runtime bytes"),("candidate_evidence","Retained candidate")]:
            target=Path(next(iter(bindings[namespace])))
            with patch.object(reader,"sha",side_effect=lambda p:"0"*64 if Path(p)==target else real_sha(p)):
                with self.assertRaisesRegex(ValueError,message):self.verify(self.path)


if __name__=="__main__":unittest.main()
