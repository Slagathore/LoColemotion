"""Retain the empty four-role shortlist and its one eligible paired contrast."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import mujoco
import audit_cpu_support_vertical_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path=Path(__file__).with_name("cpu_support_vertical_closure_v1.json")
        cls.record=reader.read(cls.path);cls.root=Path(cls.record["evidence_root"])
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"]);cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("support-vertical-closure-corruptions-"+uuid.uuid4().hex);cls.output.mkdir()

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No new worlds in closure controls"))
            guard.start();self.addCleanup(guard.stop)

    def altered(self,change):
        value=copy.deepcopy(self.record);change(value);path=self.output/(uuid.uuid4().hex+".json")
        path.write_text(json.dumps(value),encoding="utf-8",newline="\n");return path

    def verify(self,path):return reader.verify_record(path,self.root,self.core,self.baseline)

    def test_complete_inventory_training_scope_and_empty_activation_shortlist(self):
        with patch.object(reader,"audit",side_effect=AssertionError("Unexpected full replay")):result=self.verify(self.path)
        self.assertTrue(result["ok"]);self.assertFalse(result["full_controller_replay_performed"])
        self.assertEqual((result["original_independent_reader_controller_rows"],result["original_independent_reader_internal_rows"]),(23040,115200))
        self.assertEqual(result["reader_world_build_count"],0)
        s=result["finite_outcomes"];self.assertEqual((s["eligible"],s["negative"],s["denominator"]),(2,14,16))
        positives=[t for t in s["trials"] if t["outcome"]=="positive"]
        self.assertEqual([row["trial_id"] for row in positives],
            ["left_075_train_001_height_immediate","left_075_train_001_vertical_immediate"])
        self.assertTrue(all(p["eligible_window_count"] == 48 for p in positives))
        self.assertTrue(all(t["eligible_window_count"]==0 and t["episode_metrics"]["quality_m_s"] is None for t in s["trials"] if t["outcome"]=="negative"))
        self.assertIsNone(s["repertoire"]["selected_role_index"]);self.assertEqual(s["repertoire"]["ranked_role_indices"],[])
        self.assertEqual([x["eligible"] for x in s["repertoire"]["roles"]],[0,1,1,0])
        self.assertEqual(len(s["repertoire"]["contrasts"]),20)
        paired=[x for x in s["repertoire"]["contrasts"] if x["both_eligible"]]
        self.assertEqual(len(paired),1)
        self.assertEqual((paired[0]["start_id"],paired[0]["contrast_id"]),("train_001","immediate_minus_height"))
        self.assertAlmostEqual(paired[0]["quality_difference_m_s"],.008855612902272436,places=15)
        self.assertTrue(all(x["quality_difference_m_s"] is None for x in s["repertoire"]["contrasts"] if not x["both_eligible"]))
        self.assertEqual(len(s["groups"]),4)
        self.assertTrue(all(g["partition"]=="training" and g["matching_baseline_prefixes"]==2
            and g["features"]["past_entries"]==16 and not g["immediate_roles_have_baseline_prefix"] for g in s["groups"]))
        self.assertTrue(result["training_data_authority"]);self.assertTrue(result["controller_selection_authority"])
        self.assertFalse(result["qualification_or_release_authority"])

    def test_authority_population_and_inventory_refuse(self):
        changes=[lambda r:r.__setitem__("training_data_authority",False),lambda r:r.__setitem__("controller_selection_authority",False),
            lambda r:r.__setitem__("adaptive_provider_benefit",True),lambda r:r.__setitem__("noninferiority_authority",True),
            lambda r:r.__setitem__("constructed_cpu_worlds",15),lambda r:r.__setitem__("internal_rows",115199),
            lambda r:r["complete_zero_world_gate"].__setitem__("cpu-support-vertical",9),
            lambda r:r["artifacts"].pop(),lambda r:r["artifacts"].__setitem__(1,r["artifacts"][0]),
            lambda r:r.__setitem__("artifact_bytes",r["artifact_bytes"]-1)]
        for change in changes:
            value=copy.deepcopy(self.record);change(value)
            with self.assertRaises(ValueError):reader.header(value,self.root)

    def test_changed_proofs_invented_winner_and_erased_failures_refuse(self):
        changes=[lambda r:r.__setitem__("receipt_sha256","0"*64),lambda r:r.__setitem__("audit_sha256","0"*64),
            lambda r:r["finite_outcomes"]["repertoire"].__setitem__("selected_role_index",1),
            lambda r:r["finite_outcomes"].__setitem__("negative",0),
            lambda r:r["finite_outcomes"]["groups"][0].__setitem__("partition","evaluation"),
            lambda r:r.__setitem__("comparison_reader_sha256","0"*64),
            lambda r:r["finite_outcomes"]["repertoire"]["contrasts"][0].__setitem__("quality_difference_m_s",0.),
            lambda r:r.__setitem__("activation_reader_sha256","0"*64),
            lambda r:r["finite_outcomes"]["repertoire"]["contrasts"][3].__setitem__("quality_difference_m_s",0.),
            lambda r:r.__setitem__("composition_provider_sha256","0"*64),
            lambda r:r.__setitem__("composition_model_sha256","0"*64)]
        for change in changes:
            with self.assertRaises(ValueError):self.verify(self.altered(change))

    def test_causal_values_receipt_binding_and_feature_reader_refuse(self):
        target=self.root/self.record["attempt_id"]/"independent-audit.json"
        observed=reader.read(target);trial=observed["trials"][0]
        directory=self.root/self.record["attempt_id"]/"physical"/trial["trial_id"]
        core=reader.bridge.LocomotionCore(self.baseline)
        checked=copy.deepcopy(trial);checked["probe_features"]["values"][0] += .01
        with self.assertRaisesRegex(ValueError,"Causal feature values"):
            reader.verify_prefix(directory,checked,core)
        original=reader.read_jsonl
        rows=list(reader.islice(original(directory/"controller.jsonl"),17))
        rows[16]["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]["resolution_receipt_sha256"]="0"*64
        with patch.object(reader,"read_jsonl",return_value=iter(rows)):
            with self.assertRaisesRegex(ValueError,"Causal prefix original receipt"):
                reader.verify_prefix(directory,trial,core)
        with self.assertRaisesRegex(ValueError,"Context feature reader changed"):
            self.verify(self.altered(lambda r:r.__setitem__("context_reader_sha256","0"*64)))

        immediate=observed["trials"][1]
        directory=self.root/self.record["attempt_id"]/"physical"/immediate["trial_id"]
        rows=list(reader.islice(original(directory/"controller.jsonl"),17))
        rows[0]["activation_probe"]["features"]={"invented_baseline_prefix":True}
        with patch.object(reader,"read_jsonl",return_value=iter(rows)):
            with self.assertRaisesRegex(ValueError,"Immediate roles cannot claim"):
                reader.verify_prefix(directory,immediate,core)

    def test_positive_quality_and_negative_interpretation_are_recomputed(self):
        target=self.root/self.record["attempt_id"]/"independent-audit.json";original=reader.read
        changes=[(lambda a:a["trials"][1]["episodes"][0]["windows"][0].__setitem__("quality_m_s",0.),"Eligible tracking quality changed"),
            (lambda a:a["trials"][0]["episodes"][0].__setitem__("outcome","positive"),"Failed episode interpretation changed"),
            (lambda a:a["trials"][1]["episodes"][0]["windows"].pop(),"Eligible window denominator"),
            (lambda a:a["trials"][2]["episodes"][0]["windows"][0].__setitem__("quality_m_s",0.),"Eligible tracking quality changed")]
        for change,message in changes:
            altered=original(target);change(altered)
            with patch.object(reader,"read",side_effect=lambda p:altered if Path(p)==target else original(p)):
                with self.assertRaisesRegex(ValueError,message):self.verify(self.path)

    def test_nominal_and_degraded_model_records_cannot_be_crossed(self):
        target=self.root/self.record["attempt_id"]/"physical/models/left_075/native-model.json";original=reader.read
        changes=[lambda m:m.__setitem__("condition_id","nominal"),
            lambda m:m["force_ranges"][0].__setitem__(0,m["force_ranges"][0][0]*.75),
            lambda m:m.__setitem__("dynamics_dtype","float32")]
        for change in changes:
            altered=original(target);change(altered)
            with patch.object(reader,"read",side_effect=lambda p:altered if Path(p)==target else original(p)):
                with self.assertRaisesRegex(ValueError,"Condition native profile"):self.verify(self.path)

    def test_frozen_source_runtime_and_reader_binding_refuse(self):
        binding=reader.read(self.root/self.record["attempt_id"]/"declaration.json")["binding"]
        sources=dict(binding["source"]);sources[next(iter(sources))]="0"*64
        with self.assertRaisesRegex(ValueError,"Frozen source bytes"):
            reader.verify_frozen_sources(self.record["source_commit"],sources)
        target=Path(next(iter(binding["runtime"])));original=reader.sha
        with patch.object(reader,"sha",side_effect=lambda p:"0"*64 if Path(p)==target else original(p)):
            with self.assertRaisesRegex(ValueError,"Runtime bytes"):self.verify(self.path)
        with self.assertRaisesRegex(ValueError,"Closure reader changed"):
            self.verify(self.altered(lambda r:r.__setitem__("closure_reader_sha256","0"*64)))


if __name__=="__main__":unittest.main()
