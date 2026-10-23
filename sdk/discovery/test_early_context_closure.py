"""Reproduce the native-derived fit and refuse expanded scope or changed proofs."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_early_context_feasibility as reader


class EarlyClosureControls(unittest.TestCase):
    def setUp(self):
        self.core=Path(os.environ["QUADRUPED_TEST_CORE"])
        self.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        self.record=reader.read(reader.RECORD)
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No physics in closure"))
            guard.start();self.addCleanup(guard.stop)

    def verify(self):
        return reader.verify_record(reader.RECORD,reader.ROOT.parent/"SporeSpore_Evidence",self.core,self.baseline)

    def changed(self,change,message):
        value=copy.deepcopy(self.record);change(value);original=reader.read
        with patch.object(reader,"read",side_effect=lambda p:value if Path(p)==reader.RECORD else original(p)):
            with self.assertRaisesRegex(ValueError,message):self.verify()

    def test_complete_analysis_reproduces_and_retains_finite_scope(self):
        result=self.verify()
        self.assertEqual(result["internal_correct"],8);self.assertEqual(result["parent_artifacts_verified"],9181)
        self.assertEqual(result["artifact_count"],9);self.assertEqual(result["worlds_opened"],0)
        self.assertFalse(result["learned_control_selection"]);self.assertFalse(result["adaptation_benefit"])
        with (Path(os.environ["EXPLORER_TEST_OUTPUT"])/"verified-closure.json").open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(result,stream,indent=2);stream.write("\n")

    def test_scope_parent_source_and_missing_proof_refuse(self):
        for key,value in [("control_authority",True),("worlds_opened",1),("training_groups",24),
                          ("qualification_or_release_authority",True),("action_mapping",{"left_075":2})]:
            self.changed(lambda r:r.__setitem__(key,value),"identity/scope")
        self.changed(lambda r:r.__setitem__("parent_closure_sha256","0"*64),"parent/reader binding")
        self.changed(lambda r:r["artifacts"].pop(),"inventory")
        self.changed(lambda r:r["tested_sources"].__setitem__("early_context_v1.py","0"*64),"tested source changed")
        self.changed(lambda r:r["tested_sources"].clear(),"tested source inventory")

    def test_changed_labels_model_scores_or_retained_bytes_refuse(self):
        self.changed(lambda r:r["result"]["evaluation"].__setitem__("correct",7),"differs from retained analysis")
        self.changed(lambda r:r["result"]["evaluation"]["all_training_model"]["centroids"][0]["values"].__setitem__(0,99.),"differs from retained analysis")
        self.changed(lambda r:r["result"]["groups"][0].__setitem__("condition_id","nominal"),"differs from retained analysis")
        self.changed(lambda r:r["artifacts"][0].__setitem__("sha256","0"*64),"retained artifact changed")


if __name__ == "__main__":unittest.main()
