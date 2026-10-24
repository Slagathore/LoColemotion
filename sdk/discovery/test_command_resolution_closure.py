"""Reproduce dense fitting and reject changed evidence or expanded claims."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco
import audit_command_resolution_repertoire as reader


class CommandResolutionClosureControls(unittest.TestCase):
    def setUp(self):
        self.core=Path(os.environ["QUADRUPED_TEST_CORE"]);self.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        self.record=reader.read(reader.RECORD)
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No closure worlds"))
            guard.start();self.addCleanup(guard.stop)

    def verify(self):return reader.verify_record(reader.RECORD,reader.ROOT.parent/"SporeSpore_Evidence",self.core,self.baseline)

    def changed(self,change,message):
        altered=copy.deepcopy(self.record);change(altered);original=reader.read
        with patch.object(reader,"read",side_effect=lambda p:altered if Path(p)==reader.RECORD else original(p)):
            with self.assertRaisesRegex(ValueError,message):self.verify()

    def test_complete_dense_fit_reproduces_and_all_cases_have_independent_raw_joins(self):
        result=self.verify()
        self.assertEqual((result["source_trials"],result["fitted_episodes"],result["eligible_episodes"],result["negative_episodes"]),(32,24,15,9))
        self.assertEqual(result["cases"],21165);self.assertEqual(result["first_response_supported_groups"],8)
        self.assertEqual(result["worlds_opened"],0);self.assertFalse(result["adaptation_benefit"])
        with (Path(os.environ["EXPLORER_TEST_OUTPUT"])/"verified-closure.json").open("x",encoding="utf-8",newline="\n") as f:
            json.dump(result,f,indent=2);f.write("\n")

    def test_scope_source_inventory_and_retained_result_changes_refuse(self):
        for key,value in [("worlds_opened",1),("source_trials",21165),("cases",720),
            ("context_estimator_refitted",True),("overlapping_cases_are_independent_trials",True),("adaptation_benefit",True)]:
            self.changed(lambda r:r.__setitem__(key,value),"scope/identity")
        self.changed(lambda r:r["artifacts"].pop(),"artifact inventory")
        self.changed(lambda r:r["tested_sources"].clear(),"tested source inventory")
        self.changed(lambda r:r["result"]["model"]["ordered_cases"][0].__setitem__("quality_m_s",0.),"retained result changed")
        self.changed(lambda r:r["artifacts"][0].__setitem__("sha256","0"*64),"retained artifact changed")

    def test_independent_case_reader_refuses_crossed_contact_outcome_action_and_denominator(self):
        for change in [lambda r:r["model"]["ordered_cases"][0]["cue"].__setitem__("contact_mask",-1),
            lambda r:r["model"]["ordered_cases"][0].__setitem__("quality_m_s",1.),
            lambda r:r["model"]["ordered_cases"][0].__setitem__("action_index",99),
            lambda r:r["model"]["ordered_cases"].pop()]:
            result=copy.deepcopy(self.record["result"]);change(result)
            with self.assertRaises(ValueError):reader.independent_cases(result,reader.ROOT.parent/"SporeSpore_Evidence")


if __name__ == "__main__":unittest.main()
