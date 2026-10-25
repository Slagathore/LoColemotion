"""Zero-world contract, replay, corruption and launch-boundary controls."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import xml.etree.ElementTree as ET

import contact_force_observer_task as task
import contact_force_observer_native as worker
import audit_contact_force_observer as reader
from test_contact_force_measurement import captured


class ContactObserverControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=task.declaration()
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.core=task.bridge.LocomotionCore(cls.core_path)
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("observer-fixtures-"+uuid.uuid4().hex)
        cls.root.mkdir()

    def setUp(self):
        self.metadata,self.sample,self.trace,self.timing=captured()

    def test_contract_scope_and_fresh_population(self):
        self.assertEqual(task.plans(self.c),task.plans(self.c))
        self.assertEqual(len(task.plans(self.c)),4);self.assertEqual(self.c["outer_steps"],120)
        self.assertTrue(all(self.c[k] is False for k in task.FLAGS))
        self.assertEqual({p["seed"] for p in task.plans(self.c)},{104242001})
        for field in ("physical_acceptance_authority","outer_steps"):
            changed=copy.deepcopy(self.c);changed[field]=True if field.endswith("authority") else 121
            with patch.object(task,"read",return_value=changed):
                with self.assertRaises(ValueError):task.declaration()

    def test_frozen_model_identity_and_other_core(self):
        first=task.frozen_model(self.core)
        second=task.frozen_model(task.bridge.LocomotionCore(self.baseline))
        self.assertEqual(first,second);self.assertEqual(first.sha256,"sha256:"+task.MODEL_SHA)

    def test_real_controller_preflight_is_zero_world(self):
        result=worker.preflight(self.core_path,self.baseline)
        self.assertTrue(result["ok"]);self.assertEqual(result["world_build_count"],0)
        self.assertEqual(result["solver_steps"],0);self.assertEqual(result["contact_sample_rows"],1200)
        for condition in ("left_075","nominal"):
            compiled,xml,spec=worker.condition_inputs(self.core_path,self.c,condition)
            metadata=reader.expected_metadata(compiled,spec,self.c)
            self.assertEqual(metadata["cone"],ET.fromstring(xml).find("option").get("cone"))
            self.assertEqual(metadata["cone"],"elliptic")

    def test_analytical_sample_reconstructs(self):
        c=copy.deepcopy(self.c);c["timestep_s"]=.01
        reader.validate_sample(self.sample,self.trace,self.metadata,c)

    def rejects(self,sample=None,metadata=None):
        c=copy.deepcopy(self.c);c["timestep_s"]=.01
        with self.assertRaises(ValueError):
            reader.validate_sample(sample or self.sample,self.trace,metadata or self.metadata,c)

    def test_wrong_force_and_torque_sign_refused(self):
        for field in ("local_force_n","force_on_geom2_world_n","force_on_geom2_canonical_n",
                      "local_torque_nm","torque_on_geom2_world_nm","torque_on_geom2_canonical_nm"):
            row=copy.deepcopy(self.sample);row["contacts"][0][field][0]+=1.;self.rejects(row)

    def test_wrong_constraint_force_or_identity_refused(self):
        for field in ("efc_force","efc_id","efc_type"):
            row=copy.deepcopy(self.sample);row[field][0]+=1;self.rejects(row)
        row=copy.deepcopy(self.sample);row["contacts"][0]["efc_address"]=-1;self.rejects(row)

    def test_frame_or_contact_geometry_crossing_refused(self):
        for field in ("frame","position_m","geom"):
            row=copy.deepcopy(self.sample);row["contacts"][0][field][0]+=1;self.rejects(row)

    def test_missing_or_duplicate_contacts_refused(self):
        for value in ([],self.sample["contacts"]*2):
            row=copy.deepcopy(self.sample);row["contacts"]=value;self.rejects(row)
        row=copy.deepcopy(self.sample);row["efc_force"]=[];self.rejects(row)

    def test_wrong_body_attribution_refused(self):
        row=copy.deepcopy(self.sample);row["contacts"][0]["body_names"][1]="torso";self.rejects(row)

    def test_stale_or_mixed_stage_refused(self):
        for field,value in (("stage","prepared_before_control"),("prepared_time_s",.01),
                            ("step",2),("integrated_time_s",.02)):
            row=copy.deepcopy(self.sample);row[field]=value;self.rejects(row)
        row=copy.deepcopy(self.sample);row["before_qpos"][0]=row["qpos"][0];self.rejects(row)

    def test_missing_zero_load_or_misattributed_load_refused(self):
        for mutation in ("missing","value","other"):
            row=copy.deepcopy(self.sample)
            if mutation=="missing":row["mapped_distal_ground_loads"].pop()
            elif mutation=="value":row["mapped_distal_ground_loads"][1]["normal_load_n"]=1.
            else:row["other_contact_indices"]=[0]
            self.rejects(row)

    def test_pair_comparison_rejects_changed_motion_and_commands(self):
        c=copy.deepcopy(self.c);c["outer_steps"]=1
        root=self.root/uuid.uuid4().hex;root.mkdir()
        off,on=root/"off",root/"on";off.mkdir();on.mkdir()
        control={k:[] for k in c["pair_comparison"]["controller_fields"]}
        control.update(request=dict(state={}),resolution=dict(ordered_commands=[]))
        def put(path,rows):
            with path.open("w",encoding="utf-8",newline="\n") as stream:
                for row in rows:stream.write(json.dumps(row)+"\n")
        for path in (off,on):
            put(path/"trace.jsonl",[dict(step=i,qpos=[0.]) for i in range(5)])
            put(path/"controller.jsonl",[control])
        self.assertTrue(reader.compare_pair(off,on,c)["exact_native_trace_match"])
        changed=[dict(step=i,qpos=[0.]) for i in range(5)];changed[-1]["qpos"][0]=1.
        put(on/"trace.jsonl",changed)
        with self.assertRaises(ValueError):reader.compare_pair(off,on,c)
        put(on/"trace.jsonl",[dict(step=i,qpos=[0.]) for i in range(5)])
        control["native_targets"]=[1.];put(on/"controller.jsonl",[control])
        with self.assertRaises(ValueError):reader.compare_pair(off,on,c)

    def test_uncontained_worker_refused_before_world(self):
        with self.assertRaises(ValueError):
            worker.run(self.root/"physical",self.root/"missing.permit",self.core_path,self.baseline)

    def test_missing_gate_and_consumed_identity_refused(self):
        from gpu_measurement_probe import write_new
        c=self.c;source="f"*40
        fake_root=self.root/"workspace"
        attempt=self.root/"SporeSpore_Evidence"/("sdk2-contact-observer-"+uuid.uuid4().hex)
        physical=attempt/"physical";physical.mkdir(parents=True)
        owner=dict(source_commit=source,contract=c,planned_trials=task.plans(c),source_status=[],component_only=False,
                   **{k:False for k in task.FLAGS})
        write_new(attempt/"declaration.json",owner)
        gate=dict(ok=True,source_commit=source,declaration_sha256=task.sha(attempt/"declaration.json"),
            safety_controls={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1},
            preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        write_new(attempt/"gate-receipt.json",gate)
        consumed=dict(attempt_id=attempt.name,source_commit=source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256=task.sha(attempt/"declaration.json"),
            gate_receipt_sha256=task.sha(attempt/"gate-receipt.json"),trials=task.plans(c))
        write_new(attempt/"consumed.json",consumed)
        with patch.object(task,"ROOT",fake_root):
            self.assertEqual(task.launch_records(physical,c,source),owner)
            for name,original,field,value in (("gate-receipt.json",gate,"ok",False),
                    ("gate-receipt.json",gate,"safety_controls",{}),
                    ("consumed.json",consumed,"attempt_id","crossed"),
                    ("consumed.json",consumed,"trials",[]),
                    ("declaration.json",owner,"physical_acceptance_authority",True),
                    ("declaration.json",owner,"component_only",True)):
                changed=copy.deepcopy(original);changed[field]=value
                (attempt/name).write_text(json.dumps(changed),encoding="utf-8",newline="\n")
                with self.assertRaises(ValueError):task.launch_records(physical,c,source)
                # Preserve the exact original bytes for the next independent corruption.
                (attempt/name).write_text(json.dumps(original,indent=2)+"\n",encoding="utf-8",newline="\n")


if __name__=="__main__":unittest.main()
