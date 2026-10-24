"""Refuse changed fitting evidence, leakage, scores and expanded authority."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_first_response_repertoire as reader


class FirstResponseClosureControls(unittest.TestCase):
    def setUp(self):
        self.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        self.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        self.record = reader.read(reader.RECORD)
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guard = patch.object(mujoco, name, side_effect=AssertionError("No worlds in fit closure"))
            guard.start(); self.addCleanup(guard.stop)

    def verify(self):
        return reader.verify_record(reader.RECORD, reader.ROOT.parent/"SporeSpore_Evidence", self.core, self.baseline)

    def changed(self, change, message):
        value = copy.deepcopy(self.record); change(value); original = reader.read
        with patch.object(reader, "read", side_effect=lambda p:value if Path(p) == reader.RECORD else original(p)):
            with self.assertRaisesRegex(ValueError, message): self.verify()

    def test_complete_fit_reproduces_with_all_failed_and_excluded_trials(self):
        result = self.verify()
        self.assertEqual((result["internal_correct"], result["constant_nominal_correct"], result["synthetic_swapped_association_correct"]), (8,4,0))
        self.assertEqual((result["source_trials"], result["fitted_episodes"], result["eligible_fitted_episodes"], result["failed_fitted_episodes"]), (32,24,15,9))
        self.assertEqual(result["fitted_cases"],720)
        self.assertEqual(result["parent_artifacts_verified"],14636)
        self.assertEqual(result["worlds_opened"],0)
        self.assertFalse(result["runtime_selection_implemented"])
        self.assertFalse(result["adaptation_benefit"])
        with (Path(os.environ["EXPLORER_TEST_OUTPUT"])/"verified-closure.json").open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(result,stream,indent=2);stream.write("\n")

    def test_scope_parent_sources_and_missing_artifacts_refuse(self):
        for key,value in [("control_authority",True),("worlds_opened",1),("training_groups",32),
            ("source_trials",24),("fitted_episodes",32),("runtime_selection_implemented",True),("qualification_or_release_authority",True)]:
            self.changed(lambda r:r.__setitem__(key,value),"identity/scope")
        self.changed(lambda r:r.__setitem__("parent_closure_sha256","0"*64),"parent/reader binding")
        self.changed(lambda r:r["artifacts"].pop(),"inventory")
        self.changed(lambda r:r["tested_sources"].__setitem__(reader.TESTED[0],"0"*64),"tested source changed")
        self.changed(lambda r:r["tested_sources"].clear(),"tested source inventory")

    def test_retained_labels_cases_defaults_and_byte_changes_refuse(self):
        self.changed(lambda r:r["result"]["evaluation"].__setitem__("correct",7),"retained result changed")
        self.changed(lambda r:r["result"]["model"]["ordered_cases"][0].__setitem__("quality_m_s",0.),"retained result changed")
        self.changed(lambda r:r["result"]["groups"][0].__setitem__("condition_id","nominal"),"retained result changed")
        self.changed(lambda r:r["result"]["complete_condition_defaults"][0].__setitem__("default_action_index",2),"retained result changed")
        self.changed(lambda r:r["artifacts"][0].__setitem__("sha256","0"*64),"retained artifact changed")

    def test_independent_scoring_refuses_fold_leakage_centroids_and_invented_accuracy(self):
        original = self.record["result"]
        reader.check_evaluation(original)
        changes = [lambda r:r["evaluation"]["folds"][0]["model"]["training_group_ids"].append("left_075_train_001"),
            lambda r:r["evaluation"]["folds"][0]["model"]["centroids"][0]["values"].__setitem__(0,99.),
            lambda r:r["evaluation"].__setitem__("correct",7),
            lambda r:r["evaluation"]["folds"][0]["predictions"][0].__setitem__("swapped_association_correct",True),
            lambda r:r["evaluation"]["folds"].pop()]
        for change in changes:
            altered=copy.deepcopy(original);change(altered)
            with self.assertRaises(ValueError):reader.check_evaluation(altered)


if __name__ == "__main__": unittest.main()
