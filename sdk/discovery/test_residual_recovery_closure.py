"""Zero-world controls for the complete fixed-artifact native comparison closure."""
import copy
from contextlib import ExitStack
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_residual_recovery_closure as audit
from gpu_measurement_probe import write_new


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.evidence=audit.ROOT.parent/"SporeSpore_Evidence"
        cls.record=audit.read(audit.CLOSURE);cls.attempt=audit.header(cls.record,cls.evidence)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.guards=ExitStack();cls.addClassCleanup(cls.guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            cls.guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Recovery closure control opened physics")))

    def documents(self):
        p=self.attempt;f=p/"stages/comparison"
        return [audit.read(p/"receipt.json"),audit.read(p/"declaration.json"),audit.read(f/"stage.json"),
            audit.read(f/"physical/worker-result.json"),audit.read(f/"audit.json"),
            audit.task.declaration(),self.record["source_commit"]]

    def test_complete_native_files_raw_scores_and_fixed_comparison(self):
        result=audit.verify_record(audit.CLOSURE,self.evidence,self.core,self.baseline)
        self.assertTrue(result["ok"])
        self.assertEqual((result["original_constructed_cpu_worlds"],result["original_controller_rows"],
            result["original_internal_rows"]),(14,20160,100800))
        self.assertEqual((result["reader_world_build_count"],result["reader_solver_steps"]),(0,0))
        self.assertTrue(result["raw_rewards_quality_and_comparison_recomputed"])
        self.assertTrue(result["original_actor_warning_identities_reconstructed"])
        self.assertTrue(result["fresh_paired_prefixes_recomputed"])
        self.assertTrue(result["original_control_replay_receipt_preserved"])
        self.assertFalse(result["control_decisions_replayed_again"])
        self.assertTrue(all(result[k] is False for k in audit.DENIALS))
        write_new(self.out/"complete-reconstruction.json",result)

    def test_closure_authority_synthetic_and_contract_reader_digests_refuse(self):
        changes=[lambda v:v.__setitem__("synthetic",True),
            lambda v:v.__setitem__("contract_sha256","0"*64),
            lambda v:v.__setitem__("closure_reader_sha256","0"*64),
            lambda v:v.__setitem__("closure_reader_path","elsewhere.py"),
            lambda v:v.__setitem__("status","unearned_success")]
        for flag in audit.DENIALS:changes.append(lambda v,k=flag:v.__setitem__(k,True))
        for change in changes:
            v=copy.deepcopy(self.record);change(v)
            with self.assertRaises(ValueError):audit.header(v,self.evidence)

    def test_selected_model_fit_and_evidence_identity_are_bound(self):
        for change in (lambda v:v.__setitem__("selection_record_sha256","0"*64),
                lambda v:v.__setitem__("model_sha256","sha256:"+"0"*64),
                lambda v:v.__setitem__("receipt_sha256","0"*64),
                lambda v:v.__setitem__("contract_path","elsewhere.json")):
            v=copy.deepcopy(self.record);change(v)
            with self.assertRaises(ValueError):audit.header(v,self.evidence)
        for key in ("receipt_sha256","declaration_sha256","gate_receipt_sha256","audit_sha256"):
            v=copy.deepcopy(self.record);v[key]="0"*64
            with self.assertRaisesRegex(ValueError,"evidence record digest"):audit.validate_evidence_links(v,self.attempt)
        for identity in ("../elsewhere","sdk2-residual-recovery-a/../b","sdk2-residual-recovery-a\\..\\b"):
            v=copy.deepcopy(self.record);v["attempt_id"]=identity
            with self.assertRaises(ValueError):audit.header(v,self.evidence)

    def test_missing_duplicate_changed_or_reordered_artifacts_refuse(self):
        rows=self.documents()[0]["artifacts"]
        audit.verify_population(rows,copy.deepcopy(rows))
        for change in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v.reverse(),
                lambda v:v[0].__setitem__("sha256","0"*64)):
            v=copy.deepcopy(rows);change(v)
            with self.assertRaisesRegex(ValueError,"artifact population"):audit.verify_population(rows,v)

    def test_owner_source_gate_population_and_fitting_authority_refuse(self):
        docs=self.documents();audit.validate_documents(*docs)
        changes=[lambda v:v[0].__setitem__("ok",False),
            lambda v:v[0].__setitem__("zero_world_gate_passed",False),
            lambda v:v[0].__setitem__("source_status",["modified"]),
            lambda v:v[0].__setitem__("source_commit","0"*40),
            lambda v:v[0].__setitem__("challenge_choice_is_retrospective",False),
            lambda v:v[0].__setitem__("recovery_choice_is_retrospective",False),
            lambda v:v[0].__setitem__("comparison_data_used_for_fitting",True),
            lambda v:v[0].__setitem__("training_data_authority",True),
            lambda v:v[0]["planned_trials"].pop(),
            lambda v:v[1].__setitem__("binding",{})]
        for change in changes:
            v=copy.deepcopy(docs);change(v)
            with self.assertRaises(ValueError):audit.validate_documents(*v)

    def test_native_and_independent_audit_population_cannot_shrink_or_cross(self):
        docs=self.documents();audit.validate_documents(*docs)
        changes=[lambda v:v[3].__setitem__("constructed_cpu_worlds",23),
            lambda v:v[3]["trials"].pop(),lambda v:v[4]["trials"].reverse(),
            lambda v:v[4].__setitem__("reader_world_build_count",1),
            lambda v:v[4].__setitem__("training_data_authority",True),
            lambda v:v[4].__setitem__("controller_rows",1)]
        for change in changes:
            v=copy.deepcopy(docs);change(v)
            with self.assertRaises(ValueError):audit.validate_documents(*v)

    def test_changed_reward_quality_or_uncensored_failure_refuses(self):
        row=self.documents()[4]["trials"][0]
        keys=("training_reward","reward_denominator","reward_samples_sha256","first_reward_failure",
            "failure_padded_samples","observations","supported_feature_rows","unsupported_feature_rows",
            "official_quality_m_s","official_windows","comparison_data_used_for_training")
        expected={k:row[k] for k in keys}
        audit.compare_score(row,expected)
        for change in (lambda v:v.__setitem__("training_reward",.5),
                lambda v:v.__setitem__("reward_denominator",1),
                lambda v:v.__setitem__("observations",{})):
            v=copy.deepcopy(row);change(v)
            with self.assertRaises(ValueError):audit.compare_score(v,expected)
        # Explicit synthetic corruption input, independent of the observed outcome.
        negative=copy.deepcopy(row);negative.update(diagnostic_eligible=False,
            first_reward_failure=dict(internal_step=1),official_quality_m_s=None)
        expected={k:negative[k] for k in keys}
        audit.compare_score(negative,expected)
        negative["official_quality_m_s"]=0.
        with self.assertRaises(ValueError):audit.compare_score(negative,expected)

    def test_summary_cannot_hide_trials_or_regrade_the_fixed_comparison(self):
        docs=self.documents();receipt,raw=docs[0],docs[4]
        summary=audit.summarize(receipt,[raw])
        self.assertEqual(summary,self.record["summary"])
        v=copy.deepcopy(raw);v["trials"].pop()
        self.assertNotEqual(audit.summarize(receipt,[v]),summary)
        v=copy.deepcopy(receipt)
        v["final_comparison"]["groups"][0]["interventions"][0]["eligible"]=not v["final_comparison"]["groups"][0]["interventions"][0]["eligible"]
        self.assertNotEqual(audit.summarize(v,[raw]),summary)



    def test_changed_warning_scheduled_request_or_handoff_cannot_be_relabelled(self):
        row=self.documents()[4]["trials"][0];expected=copy.deepcopy(row["recovery"])
        audit.compare_recovery(row,expected)
        for change in (lambda v:v.__setitem__("actual_baseline_commands",-1),
            lambda v:v.__setitem__("scheduled_request_commands",[0]),
            lambda v:v.__setitem__("handoff",dict(command=1)),
            lambda v:v.__setitem__("safe_backup_established",True)):
            changed=copy.deepcopy(expected);change(changed)
            with self.assertRaises(ValueError):audit.compare_recovery(row,changed)


    def test_fresh_paired_prefix_cannot_be_crossed_or_relabelled(self):
        row=next(r for r in self.documents()[4]["trials"] if "paired_prefix" in r)
        expected=copy.deepcopy(row["paired_prefix"]);audit.compare_prefix(row,expected)
        for change in (lambda v:v.__setitem__("reference_trial_id","crossed"),
            lambda v:v.__setitem__("compared_internal_samples",1),
            lambda v:v.__setitem__("prefix_trace_sha256","0"*64),
            lambda v:v.__setitem__("identical_before_handoff",False)):
            bad=copy.deepcopy(expected);change(bad)
            with self.assertRaises(ValueError):audit.compare_prefix(row,bad)


if __name__=="__main__":unittest.main()
