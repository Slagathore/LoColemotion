"""Zero-world reconstruction and corruption controls for both recovery-training lanes."""
import copy
from contextlib import ExitStack
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_residual_recovery_training_closure as audit
from gpu_measurement_probe import write_new


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.evidence=audit.ROOT.parent/"SporeSpore_Evidence"
        cls.record=audit.read(audit.CLOSURE);cls.attempts=audit.header(cls.record,cls.evidence)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.guards=ExitStack();cls.addClassCleanup(cls.guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            cls.guards.enter_context(patch.object(mujoco,name,
                side_effect=AssertionError("Recovery training closure control opened physics")))
        cls.library=audit.task.bridge.LocomotionCore(cls.baseline)

    def documents(self,lane="pilot",stage="comparison"):
        p=self.attempts[lane];f=p/"stages"/stage
        return dict(receipt=audit.read(p/"receipt.json"),declared=audit.read(p/"declaration.json"),
            claim=audit.read(f/"stage.json"),worker=audit.read(f/"physical/worker-result.json"),
            audited=audit.read(f/"audit.json"),c=audit.task.declaration(lane),source=self.record["source_commit"])

    def test_complete_native_raw_population_and_learning_lineage(self):
        result=audit.verify_record(audit.CLOSURE,self.evidence,self.core,self.baseline)
        self.assertTrue(result["ok"])
        self.assertEqual(result["original_counts"],dict(constructed_cpu_worlds=119,constructed_gpu_worlds=0,
            controller_rows=162120,internal_rows=810600,exact_paired_prefixes=93))
        self.assertEqual((result["reader_world_build_count"],result["reader_solver_steps"]),(0,0))
        for key in ("raw_rewards_moments_quality_and_comparison_recomputed",
                "all_updates_and_training_selection_reconstructed","fresh_challenge_prefixes_recomputed",
                "original_control_replay_receipts_preserved"):
            self.assertTrue(result[key])
        for key in (*audit.DENIALS,"input_normalizer_updated","route_data_initialized_pilot",
                "control_decisions_replayed_again"):
            self.assertFalse(result[key])
        write_new(self.out/"complete-reconstruction.json",result)

    def test_closure_authority_contract_model_and_reader_identity_refuse(self):
        changes=[lambda v:v.__setitem__("synthetic",True),
            lambda v:v.__setitem__("status","unearned_success"),
            lambda v:v.__setitem__("contract_path","elsewhere.json"),
            lambda v:v.__setitem__("closure_reader_path","elsewhere.py")]
        for key in ("contract_sha256","predecessor_closure_sha256","warm_start_model_sha256",
                "challenge_actor_sha256","warm_start_recovery_actor_sha256","warning_model_sha256",
                "closure_reader_sha256"):
            changes.append(lambda v,k=key:v.__setitem__(k,"0"*64))
        for key in (*audit.DENIALS,"route_data_initialized_pilot","comparison_data_used_for_fitting",
                "comparison_data_used_for_selection","return_to_challenge_permitted","input_normalizer_updated"):
            changes.append(lambda v,k=key:v.__setitem__(k,True))
        for change in changes:
            value=copy.deepcopy(self.record);change(value)
            with self.subTest(change=change),self.assertRaises(ValueError):audit.header(value,self.evidence)

    def test_exact_lanes_attempt_boundaries_and_evidence_links_refuse(self):
        for identity in ("../elsewhere","sdk2-recovery-training-a/../b","sdk2-recovery-training-a\\..\\b"):
            value=copy.deepcopy(self.record);value["attempts"][0]["attempt_id"]=identity
            with self.assertRaises(ValueError):audit.header(value,self.evidence)
        for change in (lambda v:v["attempts"].pop(),lambda v:v["attempts"].reverse(),
                lambda v:v["attempts"].__setitem__(1,dict(v["attempts"][0],lane="pilot"))):
            value=copy.deepcopy(self.record);change(value)
            with self.assertRaises(ValueError):audit.header(value,self.evidence)
        item=self.record["attempts"][0]
        for key in ("receipt_sha256","declaration_sha256","gate_receipt_sha256","consumed_sha256",
                "selection_sha256","verified_selection_sha256","selected_model_sha256"):
            value=copy.deepcopy(item);value[key]="0"*64
            with self.assertRaises(ValueError):audit.validate_evidence_links(value,self.attempts["route"])

    def test_missing_duplicate_changed_or_reordered_artifacts_refuse(self):
        rows=self.documents()["receipt"]["artifacts"]
        audit.verify_population(rows,copy.deepcopy(rows))
        for change in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v.reverse(),
                lambda v:v[0].__setitem__("sha256","0"*64),lambda v:v[0].__setitem__("byte_length",-1)):
            value=copy.deepcopy(rows);change(value)
            with self.assertRaises(ValueError):audit.verify_population(rows,value)

    def test_owner_source_gate_population_and_scope_refuse(self):
        docs=self.documents()
        def check(v):audit.validate_owner(v["receipt"],v["declared"],v["c"],v["source"])
        check(docs)
        changes=[lambda v:v["receipt"].__setitem__("ok",False),
            lambda v:v["receipt"].__setitem__("zero_world_gate_passed",False),
            lambda v:v["receipt"].__setitem__("physical_launch_requested",False),
            lambda v:v["receipt"].__setitem__("source_status",["modified"]),
            lambda v:v["receipt"].__setitem__("source_commit","0"*40),
            lambda v:v["receipt"].__setitem__("training_data_scope","other"),
            lambda v:v["receipt"].__setitem__("training_data_authority",False),
            lambda v:v["receipt"]["planned_trials"].pop(),
            lambda v:v["receipt"]["completed_stages"].pop(),
            lambda v:v["declared"].__setitem__("binding",{})]
        for change in changes:
            value=copy.deepcopy(docs);change(value)
            with self.assertRaises(ValueError):check(value)

    def test_stage_population_and_nonsearch_fitting_refuse(self):
        for stage in ("iteration_00","comparison"):
            docs=self.documents(stage=stage)
            def check(v):audit.validate_stage(v["claim"],v["worker"],v["audited"],v["c"],v["source"],stage)
            check(docs)
            changes=[lambda v:v["worker"].__setitem__("constructed_cpu_worlds",1),
                lambda v:v["worker"]["trials"].pop(),lambda v:v["audited"]["trials"].reverse(),
                lambda v:v["audited"].__setitem__("reader_world_build_count",1),
                lambda v:v["audited"].__setitem__("controller_rows",1),
                lambda v:v["audited"].__setitem__("training_data_scope","other"),
                lambda v:v["audited"]["trials"][0].__setitem__("observations",{}),
                lambda v:v["audited"]["trials"][0].__setitem__("training_data_authority",True)]
            for change in changes:
                value=copy.deepcopy(docs);change(value)
                with self.assertRaises(ValueError):check(value)

    def test_raw_objective_moments_and_uncensored_failure_refuse(self):
        row=next(r for r in self.documents(stage="iteration_00")["audited"]["trials"] if r["role"]=="search")
        keys=("training_reward","reward_denominator","reward_samples_sha256","first_reward_failure",
            "failure_padded_samples","observations","supported_feature_rows","unsupported_feature_rows",
            "official_quality_m_s","official_windows","comparison_data_used_for_training",
            "recovery_objective","walking_reward_diagnostic")
        expected={k:row[k] for k in keys};audit.compare_score(row,expected)
        changes=[lambda v:v.__setitem__("training_reward",.5),lambda v:v.__setitem__("reward_denominator",1),
            lambda v:v.__setitem__("observations",{}),
            lambda v:v["recovery_objective"].__setitem__("first_scored_internal_step",1),
            lambda v:v["walking_reward_diagnostic"].__setitem__("training_reward",.5)]
        for change in changes:
            value=copy.deepcopy(row);change(value)
            with self.assertRaises(ValueError):audit.compare_score(value,expected)
        # Synthetic corruption checks censorship independently of the actual outcome.
        negative=copy.deepcopy(row);negative.update(diagnostic_eligible=False,
            first_reward_failure=dict(internal_step=1),official_quality_m_s=None)
        expected={k:negative[k] for k in keys};audit.compare_score(negative,expected)
        negative["official_quality_m_s"]=0.
        with self.assertRaises(ValueError):audit.compare_score(negative,expected)

    def test_handoff_and_fresh_prefix_cannot_be_relabelled(self):
        row=next(r for r in self.documents()["audited"]["trials"] if r["role"]=="training_selected")
        recovery=copy.deepcopy(row["recovery"]);prefix=copy.deepcopy(row["paired_prefix"])
        audit.compare_recovery(row,recovery);audit.compare_prefix(row,prefix)
        for key,value in (("actual_baseline_commands",-1),("scheduled_request_commands",[0]),
                ("handoff",dict(command=1)),("safe_backup_established",True)):
            changed=copy.deepcopy(recovery);changed[key]=value
            with self.assertRaises(ValueError):audit.compare_recovery(row,changed)
        for key,value in (("reference_trial_id","elsewhere"),("identical_before_handoff",False),
                ("handoff_observation_identical",False),("compared_commands",-1)):
            changed=copy.deepcopy(prefix);changed[key]=value
            with self.assertRaises(ValueError):audit.compare_prefix(row,changed)

    def test_update_and_fixed_scaling_checkpoint_corruption_refuse(self):
        folder=self.attempts["route"]/"stages/iteration_00";c=audit.task.declaration("route")
        read_original=audit.task.read
        for filename,change in (("update.json",lambda v:v.__setitem__("synthetic",True)),
                ("next-model.json",lambda v:v.__setitem__("schema_version","changed")),
                ("verified-update.json",lambda v:v.__setitem__("normalizer_updated",True))):
            target=(folder/filename).resolve()
            def changed_read(path):
                value=read_original(path)
                if Path(path).resolve()==target:change(value)
                return value
            with patch.object(audit.task,"read",side_effect=changed_read),self.assertRaises(ValueError):
                audit.task.verify_update(folder,c,self.library,require_verification=True)

    def test_selection_model_or_missing_training_row_cannot_pass(self):
        attempt=self.attempts["route"];c=audit.task.declaration("route");read_original=audit.task.read
        changes=(("training-selection.json",lambda v:v["selection"].__setitem__("comparison_data_used_for_selection",True)),
            ("selected-model.json",lambda v:v.__setitem__("schema_version","changed")),
            ("verified-selection.json",lambda v:v.__setitem__("model_sha256","sha256:"+"0"*64)),
            ("stages/iteration_00/audit.json",lambda v:v["trials"].pop()))
        for filename,change in changes:
            target=(attempt/filename).resolve()
            def changed_read(path):
                value=read_original(path)
                if Path(path).resolve()==target:change(value)
                return value
            with patch.object(audit.task,"read",side_effect=changed_read),self.assertRaises(ValueError):
                audit.task.verify_selection(attempt,c,self.library,require_verification=True)

    def test_route_is_prerequisite_but_cannot_initialize_pilot(self):
        owner=__import__("run_residual_recovery_training")
        docs=self.documents();route=self.attempts["route"]
        read_original=owner.read
        for change in (lambda v:v.__setitem__("ok",False),
                lambda v:v.__setitem__("source_commit","0"*40),
                lambda v:v.__setitem__("binding",{}),
                lambda v:v["selection_verification"].__setitem__("comparison_data_used_for_selection",True)):
            def changed_read(path):
                value=read_original(path)
                if Path(path).resolve()==(route/"receipt.json").resolve():change(value)
                return value
            with patch.object(owner,"read",side_effect=changed_read),self.assertRaises(ValueError):
                owner.validate_route_attempt(route,self.record["source_commit"],docs["c"],docs["receipt"]["binding"])
        claim=self.documents(stage="iteration_00")["claim"];audit.validate_initialization(claim,docs["c"])
        for change in (lambda v:v.__setitem__("parent_model_sha256","sha256:"+"0"*64),
                lambda v:v.__setitem__("previous_verified_update_sha256","0"*64)):
            value=copy.deepcopy(claim);change(value)
            with self.assertRaises(ValueError):audit.validate_initialization(value,docs["c"])

    def test_summary_conserves_both_populations_and_every_negative(self):
        for item in self.record["attempts"]:
            lane=item["lane"];p=self.attempts[lane];receipt=audit.read(p/"receipt.json")
            audits=[audit.read(p/"stages"/s/"audit.json") for s in audit.task.stages(audit.task.declaration(lane))]
            selected=audit.read(p/"training-selection.json");result=audit.summary(receipt,audits,selected)
            self.assertEqual(result,item["summary"])
            self.assertEqual(result["eligible_trials"]+result["negative_trials"],result["constructed_cpu_worlds"])
            self.assertEqual(result["training_worlds"]+result["comparison_worlds"]+
                result["development_reference_worlds"],result["constructed_cpu_worlds"])
            changed=copy.deepcopy(audits);changed[0]["trials"].pop()
            self.assertNotEqual(audit.summary(receipt,changed,selected),result)
            changed=copy.deepcopy(receipt)
            changed["final_comparison"]["finite_development_screen_passed"]=not result["final_comparison"]["finite_development_screen_passed"]
            self.assertNotEqual(audit.summary(changed,audits,selected),result)


if __name__=="__main__":unittest.main()
