"""Zero-world controls for the complete native residual training closure."""
import copy
from contextlib import ExitStack
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_residual_training_closure as audit
from gpu_measurement_probe import write_new


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.evidence=audit.ROOT.parent/"SporeSpore_Evidence"
        cls.record=audit.read(audit.CLOSURE)
        cls.attempts=audit.header(cls.record,cls.evidence)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.guards=ExitStack();cls.addClassCleanup(cls.guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            cls.guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Training closure control opened physics")))

    def test_complete_artifacts_raw_rewards_moments_and_update_lineage(self):
        value=audit.verify_record(audit.CLOSURE,self.evidence,self.core,self.baseline)
        self.assertTrue(value["ok"])
        self.assertEqual(value["original_constructed_cpu_worlds"],91)
        self.assertEqual(value["original_controller_rows"],127080)
        self.assertEqual(value["original_internal_rows"],635400)
        self.assertEqual((value["reader_world_build_count"],value["reader_solver_steps"]),(0,0))
        self.assertTrue(value["rewards_moments_updates_recomputed"])
        self.assertFalse(value["control_decisions_replayed_again"])
        self.assertTrue(all(value[k] is False for k in audit.DENIALS))
        write_new(self.out/"complete-reconstruction.json",value)

    def test_closure_authority_synthetic_and_lane_population_refuse(self):
        mutations=[lambda v:v.__setitem__("synthetic",True),lambda v:v["attempts"].reverse(),
            lambda v:v["attempts"].pop()]
        for flag in audit.DENIALS:mutations.append(lambda v,key=flag:v.__setitem__(key,True))
        for mutate in mutations:
            value=copy.deepcopy(self.record);mutate(value)
            with self.assertRaises(ValueError):audit.header(value,self.evidence)

    def test_changed_contract_reader_and_receipt_digests_refuse(self):
        mutations=[lambda v:v.__setitem__("contract_sha256","0"*64),
            lambda v:v.__setitem__("closure_reader_sha256","0"*64),
            lambda v:v["attempts"][0].__setitem__("receipt_sha256","0"*64)]
        for mutate in mutations:
            value=copy.deepcopy(self.record);mutate(value)
            with self.assertRaises(ValueError):audit.header(value,self.evidence)

    def test_attempt_path_cannot_escape_evidence_root(self):
        for identity in ("../elsewhere","sdk2-residual-training-a/../b","sdk2-residual-training-a\\..\\b"):
            value=copy.deepcopy(self.record);value["attempts"][0]["attempt_id"]=identity
            with self.assertRaises(ValueError):audit.header(value,self.evidence)

    def test_missing_duplicate_changed_or_reordered_artifacts_refuse(self):
        rows=audit.read(self.attempts[0]/"receipt.json")["artifacts"]
        audit.verify_population(rows,copy.deepcopy(rows))
        for mutate in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v.reverse(),
                lambda v:v[0].__setitem__("sha256","0"*64)):
            changed=copy.deepcopy(rows);mutate(changed)
            with self.assertRaisesRegex(ValueError,"artifact population"):audit.verify_population(rows,changed)

    def stage_documents(self):
        attempt=self.attempts[1];folder=attempt/"stages/iteration_00"
        c=audit.declaration("pilot")
        return (audit.read(folder/"stage.json"),audit.read(folder/"physical/worker-result.json"),
            audit.read(folder/"audit.json"),c,"iteration_00",self.record["source_commit"])

    def test_incomplete_native_and_independent_stage_populations_refuse(self):
        docs=self.stage_documents()
        audit.validate_stage_documents(*docs)
        mutations=[lambda v:v[1].__setitem__("ok",False),lambda v:v[1].__setitem__("constructed_cpu_worlds",31),
            lambda v:v[2]["trials"].pop(),lambda v:v[2]["trials"].reverse(),
            lambda v:v[2].__setitem__("reader_world_build_count",1),
            lambda v:v[2].__setitem__("training_data_authority",False),
            lambda v:v[2].__setitem__("controller_rows",1)]
        for mutate in mutations:
            value=copy.deepcopy(list(docs));mutate(value)
            with self.assertRaises(ValueError):audit.validate_stage_documents(*value)

    def test_changed_rewards_moments_and_uncensored_failures_refuse(self):
        docs=self.stage_documents();rows=docs[2]["trials"]
        row=rows[0]
        keys=("training_reward","reward_denominator","reward_samples_sha256","first_reward_failure",
            "failure_padded_samples","observations","supported_feature_rows","unsupported_feature_rows",
            "official_quality_m_s","official_windows","comparison_data_used_for_training")
        expected={k:row[k] for k in keys}
        audit.compare_score(row,expected)
        for mutate in (lambda v:v.__setitem__("training_reward",.5),
                lambda v:v["observations"].__setitem__("count",0),
                lambda v:v.__setitem__("reward_denominator",1)):
            value=copy.deepcopy(row);mutate(value)
            with self.assertRaises(ValueError):audit.compare_score(value,expected)
        route_rows=audit.read(self.attempts[0]/"stages/iteration_00/audit.json")["trials"]
        failed=next(r for r in route_rows if not r["diagnostic_eligible"])
        expected={k:failed[k] for k in keys}
        value=copy.deepcopy(failed);value["official_quality_m_s"]=0.
        with self.assertRaises(ValueError):audit.compare_score(value,expected)

    def test_summary_cannot_hide_negative_trials_or_change_fixed_comparison(self):
        attempt=self.attempts[1];receipt=audit.read(attempt/"receipt.json")
        audits=[audit.read(attempt/"stages"/s/"audit.json") for s in receipt["completed_stages"]]
        value=audit.summarize(receipt,audits)
        self.assertEqual(value,self.record["attempts"][1]["summary"])
        changed=copy.deepcopy(audits);changed[0]["trials"].pop()
        self.assertNotEqual(audit.summarize(receipt,changed),value)
        changed=copy.deepcopy(receipt);changed["final_comparison"]["finite_development_screen_passed"]=not changed["final_comparison"]["finite_development_screen_passed"]
        self.assertNotEqual(audit.summarize(changed,audits),value)


if __name__=="__main__":unittest.main()
