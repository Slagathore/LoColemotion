"""Retained duration/nominal confirmation and refusal controls; zero new physics."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import mujoco
import audit_cpu_height_confirmation_closure as reader


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path=Path(__file__).with_name("cpu_body_height_confirmation_closure_v1.json")
        cls.record=reader.read(cls.path);cls.root=Path(cls.record["evidence_root"])
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"]);cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("height-confirmation-closure-corruptions-"+uuid.uuid4().hex);cls.output.mkdir()

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No new worlds in closure controls"))
            guard.start();self.addCleanup(guard.stop)

    def altered(self,change):
        value=copy.deepcopy(self.record);change(value);path=self.output/(uuid.uuid4().hex+".json")
        path.write_text(json.dumps(value),encoding="utf-8",newline="\n");return path

    def verify(self,path):return reader.verify_record(path,self.root,self.core,self.baseline)

    def test_complete_inventory_four_selected_passes_and_nominal_cost(self):
        with patch.object(reader,"audit",side_effect=AssertionError("Unexpected full replay")):result=self.verify(self.path)
        self.assertTrue(result["ok"]);self.assertFalse(result["full_controller_replay_performed"])
        self.assertEqual((result["original_independent_reader_controller_rows"],result["original_independent_reader_internal_rows"]),(17280,86400))
        self.assertEqual(result["reader_world_build_count"],0)
        s=result["finite_outcomes"];self.assertEqual((s["eligible"],s["negative"],s["denominator"]),(9,3,12))
        selected=[t for t in s["trials"] if t["action_index"]==2]
        self.assertEqual([t["outcome"] for t in selected],["positive"]*4)
        self.assertEqual([t["native_metrics"]["forward_displacement_m"] for t in selected],
            [1.2087883044999923,1.2427213770982208,1.262716325365085,1.318781540146089])
        self.assertTrue(all(t["native_metrics"]["torso_contact_steps"]==0 and t["eligible_window_count"]==48 for t in selected))
        c=s["confirmation"];self.assertEqual(c["selected_candidate_index"],2);self.assertFalse(c["selection_changed"])
        self.assertEqual(c["pair_count"],8);self.assertFalse(c["nominal_quality_at_least_baseline_on_both"])
        nominal=[p for p in c["pairs"] if p["condition_id"]=="nominal" and p["comparator_index"]==0]
        self.assertEqual([p["quality_change_if_both_eligible_m_s"] for p in nominal],[-.05385526281308112,-.012389456962780987])
        self.assertFalse(result["training_data_authority"]);self.assertFalse(result["controller_selection_authority"])
        self.assertFalse(result["qualification_or_release_authority"])

    def test_authority_population_and_inventory_refuse(self):
        changes=[lambda r:r.__setitem__("training_data_authority",True),lambda r:r.__setitem__("controller_selection_authority",True),
            lambda r:r.__setitem__("adaptive_provider_benefit",True),lambda r:r.__setitem__("noninferiority_authority",True),
            lambda r:r.__setitem__("constructed_cpu_worlds",11),lambda r:r.__setitem__("internal_rows",86399),
            lambda r:r["complete_zero_world_gate"].__setitem__("cpu-height-confirmation",9),
            lambda r:r["artifacts"].pop(),lambda r:r["artifacts"].__setitem__(1,r["artifacts"][0]),
            lambda r:r.__setitem__("artifact_bytes",r["artifact_bytes"]-1)]
        for change in changes:
            value=copy.deepcopy(self.record);change(value)
            with self.assertRaises(ValueError):reader.header(value,self.root)

    def test_changed_proofs_reselection_and_erased_nominal_cost_refuse(self):
        changes=[lambda r:r.__setitem__("receipt_sha256","0"*64),lambda r:r.__setitem__("audit_sha256","0"*64),
            lambda r:r["finite_outcomes"].__setitem__("negative",0),
            lambda r:r["finite_outcomes"]["confirmation"].__setitem__("selected_candidate_index",1),
            lambda r:r["finite_outcomes"]["confirmation"].__setitem__("nominal_quality_at_least_baseline_on_both",True),
            lambda r:r["finite_outcomes"]["confirmation"]["pairs"][4].__setitem__("quality_change_if_both_eligible_m_s",0.),
            lambda r:r.__setitem__("comparison_reader_sha256","0"*64)]
        for change in changes:
            with self.assertRaises(ValueError):self.verify(self.altered(change))

    def test_positive_quality_and_negative_interpretation_are_recomputed(self):
        target=self.root/self.record["attempt_id"]/"independent-audit.json";original=reader.read
        changes=[(lambda a:a["trials"][2]["episodes"][0]["windows"][0].__setitem__("quality_m_s",0.),"Eligible tracking quality changed"),
            (lambda a:a["trials"][0]["episodes"][0].__setitem__("outcome","positive"),"Failed episode interpretation changed"),
            (lambda a:a["trials"][2]["episodes"][0]["windows"].pop(),"Eligible window denominator")]
        for change,message in changes:
            altered=original(target);change(altered)
            with patch.object(reader,"read",side_effect=lambda p:altered if Path(p)==target else original(p)):
                with self.assertRaisesRegex(ValueError,message):self.verify(self.path)

    def test_nominal_and_degraded_model_records_cannot_be_crossed(self):
        target=self.root/self.record["attempt_id"]/"physical/models/nominal/native-model.json";original=reader.read
        changes=[lambda m:m.__setitem__("condition_id","left_075"),
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
