"""Capture omission, projection, outcome and authority controls without physics."""
import copy
from contextlib import ExitStack
import json
import math
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid

import mujoco
import numpy as np

import creature_capture as subject
import creature_native as route
import creature_righting as righting
import test_creature_righting as fixtures
import test_creature_righting_sequence as sequence_fixtures
import test_creature_native as walking_fixtures
from test_portable_search import _fixture
from creature_batch import bridge
from showcase_model import generated
from gpu_quadruped_model import sha


class CaptureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.core=bridge.LocomotionCore(cls.core_path)
        cls.template=_fixture(cls.core)["provider_request"]["state"]
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-capture"
        cls.root.mkdir()
        helper=unittest.TestCase()
        for key in ("core_path","core","template","root"):setattr(helper,key,getattr(cls,key))
        with ExitStack() as trap:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
                trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Capture fixture physics")))
            try:cls.base=fixtures.RightingControls._reader_case(helper,False,sequence_profile=sequence_fixtures.candidate(),fixture_only=True)
            finally:helper.doCleanups()
        folder,c,creatures,metadata,controls,trace,result=cls.base
        cls.rows=[]
        for outer in range(c["outer_steps"]):
            cls.rows.extend(subject.project(controls[2*outer:2*outer+2],
                [trace[10*outer+2*sub:10*outer+2*sub+2] for sub in range(5)]))

    def setUp(self):
        trap=ExitStack();self.addCleanup(trap.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in capture controls")))

    def reader(self,c=None,creatures=None):
        c=copy.deepcopy(self.base[1] if c is None else c)
        creatures=self.base[2] if creatures is None else creatures
        return subject.Reader(c,creatures,*route.initial_arrays(creatures,c))

    def consume(self,rows):
        reader=self.reader()
        for i in range(0,len(rows),2):reader.consume(rows[i:i+2])
        return reader.finish()

    def case(self,full):
        folder=self.root/uuid.uuid4().hex
        shutil.copytree(self.base[0],folder)
        c=copy.deepcopy(self.base[1]);c.update(capture_mode="full" if full else "compact_v1",compact_capture=copy.deepcopy(subject.POLICY))
        self.write_rows(folder,"compact",self.rows)
        result=copy.deepcopy(self.base[6]);result["stream_sha256"]["compact"]=sha(folder/"compact.jsonl")
        if not full:
            for name in ("controller","trace"):
                (folder/(name+".jsonl")).unlink();del result["stream_sha256"][name]
        self.write_result(folder,result)
        return folder,c,result

    @staticmethod
    def write_rows(folder,name,rows):
        (folder/(name+".jsonl")).write_bytes(("".join(json.dumps(r,allow_nan=False)+"\n" for r in rows)).encode())

    @staticmethod
    def write_result(folder,result):
        (folder/"worker-result.json").write_bytes(json.dumps(result,allow_nan=False).encode())

    def test_01_policy_refuses_confirmation_omissions_and_authority_changes(self):
        self.assertEqual(subject.options(dict(capture_mode="full")),dict(active=False,full=True))
        c=dict(mode="development_discovery",capture_mode="compact_v1",compact_capture=copy.deepcopy(subject.POLICY))
        self.assertEqual(subject.options(c),dict(active=True,full=False))
        variants=[dict(c,compact_capture=None),dict(c,capture_mode="unknown"),dict(c,mode="development_confirmation"),
            dict(c,confirmation_spec={}),dict(c,readback=dict(reference_check=True))]
        for key in subject.POLICY:
            v=copy.deepcopy(c);v["compact_capture"][key]="changed";variants.append(v)
        for v in variants:
            with self.assertRaises(ValueError):subject.options(v)
        path,c,bindings,owner=self.prerequisite()
        self.assertTrue(subject.canary_receipt(path,c,"fixture",bindings,self.root)["within_run_projection_verified"])
        for key,value in [("ok",False),("synthetic",True),("source_commit","other"),("source_runtime_unchanged",False)]:
            damaged=copy.deepcopy(owner);damaged[key]=value;path.write_bytes(json.dumps(damaged).encode())
            with self.assertRaises(ValueError):subject.canary_receipt(path,c,"fixture",bindings,self.root)
        path.write_bytes(json.dumps(owner).encode());changed=copy.deepcopy(c);changed["outer_steps"]+=1
        with self.assertRaises(ValueError):subject.canary_receipt(path,changed,"fixture",bindings,self.root)
        damaged=copy.deepcopy(owner);damaged["audit"]["capture"]["within_run_projection_verified"]=False
        path.write_bytes(json.dumps(damaged).encode())
        with self.assertRaises(ValueError):subject.canary_receipt(path,c,"fixture",bindings,self.root)

    def prerequisite(self):
        folder=self.root/uuid.uuid4().hex;folder.mkdir()
        c=copy.deepcopy(self.base[1]);c.update(capture_mode="compact_v1",compact_capture=copy.deepcopy(subject.POLICY))
        full=copy.deepcopy(c);full["capture_mode"]="full"
        audit=dict(ok=True,synthetic=False,reader_world_build_count=0,gpu_worlds=2,
            controller_rows_replayed=132,native_rows_verified=660,capture=subject.report(132,True))
        (folder/"independent-audit.json").write_bytes(json.dumps(audit).encode())
        bindings=dict(runtime={"fixture":"runtime"},gpu={"fixture":"gpu"})
        owner=dict(contract=full,source_commit="fixture",source_status=[],synthetic=False,ok=True,
            source_runtime_unchanged=True,bindings=bindings,audit=audit,
            artifacts=[dict(path="independent-audit.json",sha256=sha(folder/"independent-audit.json"),
                bytes=(folder/"independent-audit.json").stat().st_size)])
        path=folder/"receipt.json";path.write_bytes(json.dumps(owner).encode())
        return path,c,bindings,owner

    def test_02_full_projection_and_compact_readers_preserve_outcomes_and_scope(self):
        for full in (True,False):
            folder,c,_=self.case(full)
            report=route.audit_batch(folder,c,self.core_path,synthetic=True)
            self.assertEqual(report["metrics"],self.base[6]["metrics"])
            self.assertEqual(report["controller_rows_replayed"],132 if full else 0)
            self.assertEqual(report["native_rows_verified"],660 if full else 0)
            self.assertEqual(report["capture"],subject.report(132,full))
            self.assertEqual(report["reader_world_build_count"],0)

    def test_03_full_projection_refuses_changed_raw_fields_and_solver_inputs(self):
        controls=self.base[4][:2];samples=[self.base[5][2*i:2*i+2] for i in range(5)]
        subject.verify_projection(self.rows[:2],controls,samples)
        changes=[lambda r:r[0]["native_targets"].__setitem__(0,.5),lambda r:r[0]["binding"].update(candidate_id="other"),
            lambda r:r[0]["prepared_qpos"].__setitem__(2,.5),lambda r:r[0]["samples"][0]["joint_force_nm"].__setitem__(0,.1),
            lambda r:r[0]["samples"][0].update(contacts=[dict(native_index=0,geom=[0,1])]),
            lambda r:r[0]["samples"][0].update(nefc=1)]
        for change in changes:
            r=copy.deepcopy(self.rows[:2]);change(r)
            with self.assertRaises(ValueError):subject.verify_projection(r,controls,samples)
        r=subject.project(controls,samples);r[0]["prepared_qpos"][2]=999.
        self.assertNotEqual(controls[0]["native_observation"]["qpos"][2],999.)

    def test_04_compact_identity_shape_boundary_and_order_refuse(self):
        changes=[lambda r:r[0].update(cell=1),lambda r:r[0].update(outer_step=1),lambda r:r[0].update(binding={}),
            lambda r:r[0]["prepared_qpos"].__setitem__(2,.5),lambda r:r[0].update(prepared_time_s=.1),
            lambda r:r[0].update(native_targets=[99.]*8),lambda r:r[0].update(safe_no_actuation=1),
            lambda r:r[0].update(extra=True),lambda r:r[0]["prepared_qvel"].pop()]
        for change in changes:
            r=copy.deepcopy(self.rows[:2]);change(r)
            with self.assertRaises(ValueError):self.reader().consume(r)
        reader=self.reader();reader.consume(self.rows[:2])
        with self.assertRaises(ValueError):reader.consume(self.rows[:2])

    def test_05_native_finite_clock_quaternion_capacity_and_force_controls(self):
        changes=[lambda s:s["qpos"].__setitem__(0,math.nan),lambda s:s["qvel"].pop(),lambda s:s.update(time_s=99.),
            lambda s:s["qpos"].__setitem__(3,2.),lambda s:s.update(overflow=1),lambda s:s.update(nefc=999),
            lambda s:s.update(warnings=[0]),lambda s:s["actuator_force_nm"].__setitem__(0,999.),
            lambda s:s["joint_force_nm"].__setitem__(0,1.)]
        for change in changes:
            rows=copy.deepcopy(self.rows[:2]);change(rows[0]["samples"][0])
            with self.assertRaises(ValueError):self.reader().consume(rows)

    def test_06_missing_samples_contacts_and_incomplete_or_extra_streams_refuse(self):
        for change in [lambda r:r.pop(),lambda r:r[0]["samples"].pop(),
            lambda r:r[0]["samples"][0].update(contacts=[dict(native_index=0,geom=[0,1])]),
            lambda r:r[0]["samples"][0].update(batch_contacts=1),
            lambda r:r[0]["samples"][0].update(contacts=[dict(native_index=0,geom=[1,2])])]:
            rows=copy.deepcopy(self.rows[:2]);change(rows)
            with self.assertRaises(ValueError):self.reader().consume(rows)
        with self.assertRaises(ValueError):self.consume(self.rows[:-2])
        with self.assertRaises(ValueError):self.consume(self.rows+self.rows[:2])

    def test_07_signed_work_reconstructs_from_all_substeps_without_relaxed_eligibility(self):
        c=copy.deepcopy(self.base[1]);c["outer_steps"]=1
        rows=copy.deepcopy(self.rows[:2])
        for row in rows:
            for sub,s in enumerate(row["samples"]):
                s["qpos"][7]+=.01*(sub+1)
                s["actuator_force_nm"][0]=s["joint_force_nm"][0]=.2
        reader=self.reader(c);reader.consume(rows)
        for m in reader.finish():
            self.assertAlmostEqual(m["sampled_joint_actuator_work_j"],.01)
            self.assertAlmostEqual(m["sampled_positive_joint_actuator_work_j"],.01)
            self.assertEqual(m["sampled_negative_joint_actuator_work_j"],0.)
            self.assertEqual(m["sampled_work_intervals"],5)
            self.assertEqual(m["terminal_upright_dwell_steps"],0)

    def test_08_32_distinct_shapes_reconstruct_fresh_compact_states(self):
        spec=fixtures.population([generated(i) for i in range(13000,13032)])
        spec["starts"]=spec["starts"][:1]
        c=copy.deepcopy(self.base[1]);c.update(righting_spec=spec,outer_steps=1,**righting.expand(spec))
        batch=righting.RightingBatch(self.core,c["cells"],seed=c["seed"]);self.addCleanup(batch.close)
        creatures=[cell.creature for cell in batch.controllers]
        self.assertEqual(len({v["binding"]["body_shape_sha256"] for v in creatures}),32)
        positions,velocities=route.initial_arrays(creatures,c);rows=[]
        for i,cell in enumerate(batch.controllers):
            r=copy.deepcopy(self.rows[0]);r.update(cell=i,binding=cell.binding,prepared_qpos=positions[i].tolist(),prepared_qvel=velocities[i].tolist(),native_targets=[0.]*8)
            for s in r["samples"]:s.update(qpos=positions[i].tolist(),qvel=velocities[i].tolist())
            rows.append(r)
        reader=subject.Reader(c,creatures,positions,velocities);reader.consume(rows)
        self.assertEqual(len(reader.finish()),64)
        self.assertTrue(all(m["joint_limit_violation_steps"]==0 for m in reader.finish()))

    def test_09_walking_capture_matches_original_live_metrics(self):
        walking_fixtures.CreatureNativeControls.setUpClass()
        fixture=walking_fixtures.CreatureNativeControls
        validator=route.StreamValidator(fixture.c,fixture.creatures,fixture.metadata)
        reader=subject.Reader(fixture.c,fixture.creatures,*route.initial_arrays(fixture.creatures,fixture.c))
        n=len(fixture.creatures)
        for outer in range(fixture.c["outer_steps"]):
            controls=fixture.controls[n*outer:n*(outer+1)]
            for row in controls:validator.control(row)
            samples=[fixture.native[n*(5*outer+j):n*(5*outer+j+1)] for j in range(5)]
            for block in samples:validator.native(block)
            projected=subject.project(controls,samples);subject.verify_projection(projected,controls,samples);reader.consume(projected)
        self.assertEqual(reader.finish(),validator.finish())

    def test_10_independent_reader_refuses_hashes_outcomes_and_projection_forgery(self):
        folder,c,result=self.case(False)
        result["metrics"][0]["minimum_height_m"]+=1.
        self.write_result(folder,result)
        with self.assertRaises(ValueError):route.audit_batch(folder,c,self.core_path,synthetic=True)
        folder,c,result=self.case(False);result["stream_sha256"]["compact"]="0"*64;self.write_result(folder,result)
        with self.assertRaises(ValueError):route.audit_batch(folder,c,self.core_path,synthetic=True)
        folder,c,result=self.case(True);rows=copy.deepcopy(self.rows);rows[0]["samples"][0]["qpos"][0]+=.1
        self.write_rows(folder,"compact",rows);result["stream_sha256"]["compact"]=sha(folder/"compact.jsonl");self.write_result(folder,result)
        with self.assertRaises(ValueError):route.audit_batch(folder,c,self.core_path,synthetic=True)
        folder,c,_=self.case(False);(folder/"unexpected.jsonl").write_bytes(b"{}\n")
        with self.assertRaises(ValueError):route.audit_batch(folder,c,self.core_path,synthetic=True)


if __name__ == "__main__":
    unittest.main()
