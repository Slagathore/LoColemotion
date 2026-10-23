"""Retained native influence corruption controls; no new physical work."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import audit_gpu_contextual_influence_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("gpu_contextual_influence_closure_v1.json")
        cls.record = json.loads(cls.path.read_text())
        cls.root = Path(cls.record["evidence_root"])
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("contextual-closure-controls-" + uuid.uuid4().hex)
        cls.output.mkdir()

    def altered(self, change):
        record = copy.deepcopy(self.record)
        change(record)
        path = self.output / (uuid.uuid4().hex + ".json")
        path.write_text(json.dumps(record),encoding="utf-8",newline="\n")
        return path

    def verify(self, path):
        return reader.verify_record(path,self.root,self.core,self.baseline)

    def test_retained_inventory_source_model_runtime_and_finite_outcomes(self):
        with patch.object(reader,"audit",side_effect=AssertionError("Unexpected complete replay")):
            result=self.verify(self.path)
        self.assertEqual(result["artifact_count"],988)
        self.assertEqual(result["original_independent_reader_controller_rows"],17280)
        self.assertEqual(result["original_independent_reader_internal_rows"],86400)
        self.assertEqual(result["physical_provider_influence_rows"],10289)
        self.assertFalse(result["full_controller_replay_performed"])
        self.assertTrue(result["native_influence_evaluated"])
        self.assertFalse(result["training_data_authority"])
        outcomes=result["finite_outcomes"]
        self.assertEqual(len(outcomes["frozen_favorable_groups"]),3)
        self.assertEqual(outcomes["episodic_favorable_groups"],[])
        self.assertEqual(outcomes["matched_influence_memory_benefit_groups"],[])
        self.assertTrue(outcomes["native_episode_feedback_mechanism_verified"])
        self.assertEqual(outcomes["completed_episode_feedback_updates"],176)
        self.assertEqual(outcomes["same_input_choices_changed_by_episode_memory"],27)
        self.assertEqual(outcomes["selections_with_matching_context_feedback"],84)
        self.assertEqual(outcomes["selections_with_nonzero_context_offsets"],84)
        self.assertTrue(outcomes["native_context_reuse_mechanism_verified"])

    def test_authority_source_population_and_inventory_changes_refuse(self):
        changes=[lambda r:r.__setitem__("native_influence_evaluated",False),
            lambda r:r.__setitem__("training_data_authority",True),
            lambda r:r.__setitem__("statistical_superiority_authority",True),
            lambda r:r.__setitem__("noninferiority_authority",True),
            lambda r:r.__setitem__("source_commit","0"*40),
            lambda r:r.__setitem__("controller_rows",17279),
            lambda r:r.__setitem__("physical_provider_influence_rows",0),
            lambda r:r["artifacts"].pop(),
            lambda r:r["artifacts"].__setitem__(1,r["artifacts"][0]),
            lambda r:r["complete_zero_world_gate"].__setitem__("influence-route-gate",5)]
        for change in changes:
            with self.assertRaises(ValueError):self.verify(self.altered(change))

    def test_model_quality_feedback_and_memory_benefit_changes_refuse(self):
        changes=[lambda r:r["artifacts"][0].__setitem__("sha256","0"*64),
            lambda r:r.__setitem__("model_sha256","sha256:"+"0"*64),
            lambda r:r["group_summary"]["context_development_0"]["metrics"]["frozen"].__setitem__("mean_window_quality_m_s",0.),
            lambda r:r["group_summary"]["context_development_0"]["providers"]["episodic"].__setitem__("completed_feedback_updates",16),
            lambda r:r["group_summary"]["context_development_0"]["comparison"]["pairs"]["episodic_versus_frozen"]["influence"].__setitem__("matched_influence",True),
            lambda r:r["finite_outcomes"]["episodic_favorable_groups"].append("context_development_0"),
            lambda r:r["finite_outcomes"].__setitem__("completed_episode_feedback_updates",177),
            lambda r:r["finite_outcomes"].__setitem__("selections_with_matching_context_feedback",85),
            lambda r:r["group_summary"]["context_development_0"]["providers"]["episodic"].__setitem__("context_supported_action_selections",0),
            lambda r:r.__setitem__("contextual_contract_sha256","0"*64)]
        for change in changes:
            with self.assertRaises(ValueError):self.verify(self.altered(change))

    def test_frozen_source_runtime_and_external_candidate_bytes_are_checked(self):
        attempt=self.root/self.record["attempt_id"]
        bindings=json.loads((attempt/"declaration.json").read_text())["binding"]
        sources=dict(bindings["source"]);sources[next(iter(sources))]="0"*64
        with self.assertRaisesRegex(ValueError,"Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"],sources)
        real_sha=reader.sha
        for namespace,message in [("runtime","Runtime bytes"),("candidate_evidence","Retained candidate"),
                                  ("design_diagnostic","Retained design diagnostic")]:
            target=Path(next(iter(bindings[namespace])))
            with patch.object(reader,"sha",side_effect=lambda p:"0"*64 if Path(p)==target else real_sha(p)):
                with self.assertRaisesRegex(ValueError,message):self.verify(self.path)


if __name__=="__main__":unittest.main()
