"""Corruption controls for retained native force capture; every test opens zero worlds."""
import copy
from contextlib import ExitStack
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_contact_force_observer as observer
import audit_contact_force_observer_closure as audit
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
            cls.guards.enter_context(patch.object(mujoco,name,
                side_effect=AssertionError("Contact closure control opened physics")))

    def documents(self):
        p=self.attempt
        return [audit.read(p/name) for name in ("receipt.json","declaration.json","gate-receipt.json",
            "consumed.json","physical/worker-result.json","audit.json")]+[
                audit.task.declaration(),self.record["source_commit"]]

    def reject_document_changes(self,changes):
        docs=self.documents();audit.validate_documents(*docs)
        for change in changes:
            value=copy.deepcopy(docs);change(value)
            with self.assertRaises(ValueError):audit.validate_documents(*value)

    def native_sample(self):
        folder=self.attempt/"physical/observer_on_left_075_train_001"
        samples=list(audit.read_jsonl(folder/"contact-force.jsonl"))
        traces=list(audit.read_jsonl(folder/"trace.jsonl"))
        index=next(i for i,row in enumerate(samples)
                   if any(c["efc_address"]>=0 for c in row["contacts"]))
        return samples[index],traces[index],audit.read(folder/"contact-metadata.json"),audit.task.declaration()

    def test_complete_retained_population_and_raw_reconstruction(self):
        result=audit.verify_record(audit.CLOSURE,self.evidence,self.core,self.baseline)
        self.assertEqual((result["original_constructed_cpu_worlds"],result["original_controller_rows"],
            result["original_internal_rows"],result["original_contact_rows"]),(4,480,2400,1200))
        self.assertEqual((result["reader_world_build_count"],result["reader_solver_steps"]),(0,0))
        self.assertTrue(all(result[k] for k in ("ok","complete_artifact_population_verified",
            "all_contact_forces_reconstructed","capture_stage_geometry_and_state_rejoined",
            "complete_off_on_pairs_recompared","control_decisions_replayed_again")))
        self.assertTrue(all(result[k] is False for k in audit.DENIALS))
        write_new(self.out/"complete-reconstruction.json",result)

    def test_header_authority_and_synthetic_claims_refuse(self):
        for key in (*audit.DENIALS,"synthetic"):
            value=copy.deepcopy(self.record);value[key]=True
            with self.assertRaises(ValueError):audit.header(value,self.evidence)
        for key,value in (("status","unearned_recovery"),("source_commit","0"*40),
                          ("closure_controls_required",0)):
            changed=copy.deepcopy(self.record);changed[key]=value
            with self.assertRaises(ValueError):audit.header(changed,self.evidence)

    def test_contract_model_predecessor_and_reader_identity_refuse(self):
        for key in ("contract_sha256","model_sha256","parent_closure_sha256","diagnosis_sha256"):
            value=copy.deepcopy(self.record);value[key]="0"*64
            with self.assertRaises(ValueError):audit.header(value,self.evidence)
        value=copy.deepcopy(self.record);value["contract_path"]="elsewhere.json"
        with self.assertRaises(ValueError):audit.header(value,self.evidence)
        value=copy.deepcopy(self.record);value["closure_source_bindings"][audit.SOURCES[0]]="0"*64
        with self.assertRaises(ValueError):audit.header(value,self.evidence)

    def test_evidence_digests_and_path_escape_refuse(self):
        for key in audit.LINKS:
            value=copy.deepcopy(self.record);value[key]="0"*64
            with self.assertRaisesRegex(ValueError,"evidence record digest"):
                audit.validate_evidence_links(value,self.attempt)
        for identity in ("../elsewhere","sdk2-contact-observer-a/../b","sdk2-contact-observer-a\\..\\b"):
            value=copy.deepcopy(self.record);value["attempt_id"]=identity
            with self.assertRaises(ValueError):audit.header(value,self.evidence)

    def test_missing_duplicate_changed_or_reordered_artifacts_refuse(self):
        rows=self.documents()[0]["artifacts"];audit.verify_population(rows,copy.deepcopy(rows))
        for change in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v.reverse(),
                       lambda v:v[0].__setitem__("sha256","0"*64)):
            value=copy.deepcopy(rows);change(value)
            with self.assertRaisesRegex(ValueError,"artifact population"):audit.verify_population(rows,value)

    def test_owner_freeze_and_component_only_cannot_replace_native_run(self):
        self.reject_document_changes([
            lambda v:v[0].__setitem__("ok",False),
            lambda v:v[0].__setitem__("source_runtime_unchanged",False),
            lambda v:v[0].__setitem__("source_status",["changed"]),
            lambda v:v[0].__setitem__("physical_launch_requested",False),
            lambda v:v[0].__setitem__("component_only",True),
            lambda v:v[1].__setitem__("binding",{}),
            lambda v:v[1].__setitem__("physical_started",True)])

    def test_gate_missing_controls_and_crossed_claim_refuse(self):
        self.reject_document_changes([
            lambda v:v[0].__setitem__("zero_world_gate_passed",False),
            lambda v:v[0]["safety_controls"].pop("containment"),
            lambda v:v[2].__setitem__("ok",False),
            lambda v:v[2]["safety_controls"].pop("contact-measurement"),
            lambda v:v[2]["preflight"].__setitem__("world_build_count",1),
            lambda v:v[3].__setitem__("source_commit","0"*40),
            lambda v:v[3]["trials"].reverse()])

    def test_missing_crossed_or_promoted_native_population_refuse(self):
        self.reject_document_changes([
            lambda v:v[4].__setitem__("constructed_cpu_worlds",3),
            lambda v:v[4].__setitem__("constructed_model_count",3),
            lambda v:v[4].__setitem__("constructed_gpu_worlds",1),
            lambda v:v[4]["trials"].pop(),
            lambda v:v[4]["trials"].reverse(),
            lambda v:v[4].__setitem__("physical_acceptance_authority",True)])

    def test_reader_population_clock_and_qualification_refuse(self):
        self.reject_document_changes([
            lambda v:v[5].__setitem__("contact_rows",1199),
            lambda v:v[5].__setitem__("reader_solver_steps",1),
            lambda v:v[5].__setitem__("controller_load_fields_changed",True),
            lambda v:v[5].__setitem__("tier2_qualified",True),
            lambda v:v[5]["trials"].reverse(),
            lambda v:v[5]["pairs"][0].__setitem__("exact_native_trace_match",False),
            lambda v:v[5]["trials"][0].__setitem__("official_quality_m_s",0.)])

    def test_original_source_and_runtime_bytes_are_checked(self):
        binding=dict(source={audit.task.CONTRACT.relative_to(audit.ROOT).as_posix():audit.sha(audit.task.CONTRACT)},
                     runtime={str(self.core):audit.sha(self.core)},gpu=self.documents()[0]["binding"]["gpu"])
        audit.validate_bindings(binding)
        for category in ("source","runtime"):
            value=copy.deepcopy(binding);value[category][next(iter(value[category]))]="0"*64
            with self.assertRaisesRegex(ValueError,"original "+category+" bytes"):audit.validate_bindings(value)
        value=copy.deepcopy(binding);value["source"]={str(self.core):audit.sha(self.core)}
        with self.assertRaisesRegex(ValueError,"original source bytes"):audit.validate_bindings(value)

    def test_changed_local_constraint_or_world_force_refuses(self):
        row,trace,metadata,c=self.native_sample();audit.validate_sample(row,trace,metadata,c)
        index=next(i for i,x in enumerate(row["contacts"]) if x["efc_address"]>=0)
        for field in ("local_force_n","force_on_geom2_world_n","force_on_geom2_canonical_n"):
            changed=copy.deepcopy(row);changed["contacts"][index][field][0]+=1.
            with self.assertRaises(ValueError):audit.validate_sample(changed,trace,metadata,c)
        changed=copy.deepcopy(row);changed["efc_force"][row["contacts"][index]["efc_address"]]+=1.
        with self.assertRaises(ValueError):audit.validate_sample(changed,trace,metadata,c)

    def test_changed_stage_state_or_zero_load_mapping_refuses(self):
        row,trace,metadata,c=self.native_sample()
        for change in (lambda v:v.__setitem__("stage","unverified_stage"),
            lambda v:v.__setitem__("prepared_time_s",v["prepared_time_s"]+c["timestep_s"]),
            lambda v:v["qpos"].__setitem__(0,v["qpos"][0]+.01),
            lambda v:v["mapped_distal_ground_loads"][0].__setitem__("normal_load_n",12345.)):
            changed=copy.deepcopy(row);change(changed)
            with self.assertRaises(ValueError):audit.validate_sample(changed,trace,metadata,c)

    def test_raw_pair_state_and_commands_cannot_be_crossed(self):
        off=self.attempt/"physical/observer_off_left_075_train_001"
        on=self.attempt/"physical/observer_on_left_075_train_001";c=audit.task.declaration()
        originals={path:list(audit.read_jsonl(path)) for folder in (off,on)
                   for path in (folder/"trace.jsonl",folder/"controller.jsonl")}
        audit.compare_pair(off,on,c)
        for filename in ("trace.jsonl","controller.jsonl"):
            changed=copy.deepcopy(originals)
            if filename=="trace.jsonl":changed[on/filename][0]["qpos"][0]+=.01
            else:changed[on/filename][0]["native_targets"][0]+=.01
            with patch.object(observer,"read_jsonl",side_effect=lambda p:iter(changed[p])):
                with self.assertRaises(ValueError):audit.compare_pair(off,on,c)

    def test_complete_result_cannot_hide_capture_cost_or_negative_outcomes(self):
        original=self.documents()[5];audit.compare_reconstruction(original,copy.deepcopy(original))
        for change in (lambda v:v["trials"].pop(),
            lambda v:v["trials"][0].__setitem__("diagnostic_failure_codes",["invented"]),
            lambda v:v["trials"][1]["contact_capture"].__setitem__("rows",599),
            lambda v:v["trials"][1]["contact_capture"]["timing_s"].__setitem__("serialization_s",-1.)):
            changed=copy.deepcopy(original);change(changed)
            with self.assertRaisesRegex(ValueError,"complete raw reconstruction"):
                audit.compare_reconstruction(original,changed)
        self.assertEqual(audit.summarize(original),self.record["summary"])


if __name__=="__main__":unittest.main()
