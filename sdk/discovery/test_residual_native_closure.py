"""Corruption controls for the retained three-world route closure; no new physics."""
import copy
from contextlib import ExitStack
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import audit_residual_native_closure as audit


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.root=audit.ROOT.parent/"SporeSpore_Evidence"
        cls.record=audit.read(audit.CLOSURE)
        cls.attempt,cls.paths=audit.header(cls.record,cls.root)
        cls.documents=[audit.read(cls.attempt/name) for name in
            ("declaration.json","receipt.json","physical/worker-result.json",
             "independent-audit.json","gate-receipt.json","consumed.json")]
        cls.output=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.output.mkdir(exist_ok=True)
        cls.guards=ExitStack()
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            cls.guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Closure control opened physics")))

    @classmethod
    def tearDownClass(cls):
        cls.guards.close()

    def test_complete_retained_replay_opens_no_new_worlds(self):
        value=audit.verify_record(audit.CLOSURE,self.root,self.core,self.baseline)
        self.assertTrue(value["ok"])
        self.assertEqual((value["original_constructed_cpu_worlds"],value["controller_rows"],value["internal_rows"]),(3,360,1800))
        self.assertEqual((value["reader_world_build_count"],value["reader_solver_steps"]),(0,0))
        self.assertTrue(value["native_route_verified"])
        self.assertTrue(all(value[k] is False for k in audit.AUTHORITY_FLAGS))
        audit.write_new(self.output/"complete-replay.json",value)

    def test_authority_synthetic_and_population_cannot_be_promoted(self):
        mutations={**{k:True for k in audit.AUTHORITY_FLAGS},"synthetic":True,
            "constructed_cpu_worlds":4,"constructed_gpu_worlds":1,"training_worlds":1,
            "evaluation_worlds":1,"controller_rows":359,"internal_rows":1799,
            "native_route_verified":False,"complete_zero_world_gate":{}}
        for key,value in mutations.items():
            with self.subTest(key=key):
                record=copy.deepcopy(self.record);record[key]=value
                with self.assertRaises(ValueError):audit.header(record,self.root)

    def test_inventory_paths_population_bytes_and_digests_are_exact(self):
        record=copy.deepcopy(self.record)
        record["artifacts"][0]["evidence_relative_path"]="../LoColemotion/README.md"
        with self.assertRaisesRegex(ValueError,"escaped"):audit.header(record,self.root)
        record=copy.deepcopy(self.record);record["artifacts"][0]=record["artifacts"][1]
        with self.assertRaisesRegex(ValueError,"incomplete/duplicate"):audit.header(record,self.root)
        record=copy.deepcopy(self.record);removed=record["artifacts"].pop()
        record["artifact_count"]-=1;record["artifact_bytes"]-=removed["byte_length"]
        with self.assertRaisesRegex(ValueError,"incomplete/duplicate"):audit.header(record,self.root)
        for key,value in (("sha256","0"*64),("byte_length",-1)):
            record=copy.deepcopy(self.record);record["artifacts"][0][key]=value
            with self.assertRaises(ValueError):
                if key=="byte_length":audit.header(record,self.root)
                else:audit.verify_artifacts(record,self.paths)

    def test_crossed_frozen_records_and_incomplete_workers_are_refused(self):
        cases=((0,"source_commit","0"*40),(0,"source_status",[" M source"]),
            (1,"source_runtime_unchanged",False),(1,"physical_started",False),
            (2,"ok",False),(2,"constructed_cpu_worlds",2),(3,"reader_world_build_count",1),
            (3,"reader_solver_steps",1),(4,"safety_controls",{}),(5,"trials",[]))
        for index,key,value in cases:
            with self.subTest(index=index,key=key):
                documents=copy.deepcopy(self.documents);documents[index][key]=value
                with self.assertRaises(ValueError):audit.verify_joins(self.record,*documents)
        documents=copy.deepcopy(self.documents);documents[2]["trials"][0]["completed"]=False
        with self.assertRaisesRegex(ValueError,"trial completion"):audit.verify_joins(self.record,*documents)

    def test_official_quality_and_route_outcomes_cannot_be_rewritten(self):
        documents=copy.deepcopy(self.documents);documents[3]["trials"][0]["official_quality_m_s"]=.2
        record=copy.deepcopy(self.record);record["finite_outcomes"]=audit.finite_summary(documents[3])
        with self.assertRaisesRegex(ValueError,"outcome/quality"):audit.verify_joins(record,*documents)
        record=copy.deepcopy(self.record)
        record["finite_outcomes"]["native_path_comparison"]["locomotion_benefit_established"]=True
        with self.assertRaisesRegex(ValueError,"outcome/quality"):audit.verify_joins(record,*self.documents)

    def test_changed_reader_and_missing_historical_source_are_refused(self):
        record=copy.deepcopy(self.record);record["closure_reader_sha256"]="0"*64
        original=audit.read
        def read(path):return record if Path(path)==audit.CLOSURE else original(path)
        with patch.object(audit,"read",side_effect=read),self.assertRaisesRegex(ValueError,"reader changed"):
            audit.verify_record(audit.CLOSURE,self.root,self.core,self.baseline)
        name=next(iter(self.documents[0]["binding"]["source"]))
        with self.assertRaisesRegex(ValueError,"Frozen source bytes differ"):
            audit.verify_frozen_sources(self.record["source_commit"],{name:"0"*64})
        with self.assertRaisesRegex(ValueError,"Frozen source missing"):
            audit.verify_frozen_sources("0"*40,{name:self.documents[0]["binding"]["source"][name]})


if __name__=="__main__":unittest.main()
