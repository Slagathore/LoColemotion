"""Controls for retrospective feedback diagnosis, never alternative outcomes."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import episode_feedback_diagnostic as diagnostic


class FeedbackDiagnosticControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline_path=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.model=diagnostic.load_candidate(diagnostic.bridge.LocomotionCore(cls.core_path),diagnostic.declaration())
        cls.closure=diagnostic.ROOT/"sdk/discovery/gpu_retrieval_influence_closure_v1.json"
        cls.evidence=diagnostic.ROOT.parent/"SporeSpore_Evidence"
        cls.record=json.loads(cls.closure.read_text())
        path=cls.evidence/cls.record["attempt_id"]/"physical/influence_calibration_1/controller.jsonl"
        cls.rows=[]
        with path.open() as stream:
            for line in stream:
                row=json.loads(line)
                if row["outer_step"]>60:
                    break
                if row["mode"] in ["episodic","episodic_shuffled"]:
                    cls.rows.append(row)

    def test_phase_contact_and_distance_each_constrain_feedback_reuse(self):
        plan=self.model.plan()
        q=dict(phase=[0]*4,contact_mask=15,vector=[0.]*6)
        self.assertTrue(diagnostic.compatible(q,q,plan))
        for field,value in [("phase",[1]*4),("contact_mask",7),("vector",[10.]*6)]:
            other=copy.deepcopy(q);other[field]=value
            self.assertFalse(diagnostic.compatible(q,other,plan))

    def test_original_feedback_and_choice_denominators_without_worlds(self):
        with patch.object(mujoco,"MjModel",side_effect=AssertionError("world")),patch.object(mujoco,"MjData",side_effect=AssertionError("data")):
            result=diagnostic.analyze(self.closure,self.evidence,self.core_path,self.baseline_path)
        self.assertEqual(result["totals"]["controller_rows"],2880)
        self.assertEqual(result["totals"]["completed_feedback_updates"],87)
        self.assertEqual(result["totals"]["changed_selections"],35)
        self.assertEqual(result["world_build_count"],0)
        self.assertFalse(result["counterfactual_outcome_authority"])
        self.assertFalse(result["training_data_authority"])
        self.assertEqual(set(result["groups"]),{"calibration_1","calibration_2","calibration_3"})

    def test_missing_crossed_and_corrupted_feedback_refuse(self):
        rows=copy.deepcopy(self.rows);rows.pop(0)
        with self.assertRaisesRegex(ValueError,"clock"):
            diagnostic.diagnose_rows(rows,self.model)
        rows=copy.deepcopy(self.rows)
        row=next(r for r in rows if r["outer_step"]==30 and r["mode"]=="episodic")
        row["resolution"]["next_memory"]["opaque_state"]["offsets"][2]+=.01
        with self.assertRaisesRegex(ValueError,"arithmetic"):
            diagnostic.diagnose_rows(rows,self.model)
        rows=copy.deepcopy(self.rows)
        row=next(r for r in rows if r["outer_step"]==30 and r["mode"]=="episodic")
        row["resolution_request"]["provider_request"]["provider_memory"]["opaque_state"]["active"]["start_step"]=1
        with self.assertRaisesRegex(ValueError,"join"):
            diagnostic.diagnose_rows(rows,self.model)

    def test_shuffled_credit_preserves_applied_action_identity(self):
        result=diagnostic.diagnose_rows(self.rows,self.model)
        ordinary=result["episodic"]["feedback"][0]
        shuffled=result["episodic_shuffled"]["feedback"][0]
        self.assertEqual(ordinary["applied_action"],ordinary["credited_action"])
        self.assertEqual(shuffled["applied_action"],ordinary["applied_action"])
        self.assertNotEqual(shuffled["credited_action"],shuffled["applied_action"])


if __name__=="__main__":
    unittest.main()
