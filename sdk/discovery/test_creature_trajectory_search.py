"""Proposal coverage, sparse assignments, progress semantics and capture controls."""
import copy
from contextlib import ExitStack
import hashlib
import json
import math
import unittest
from unittest.mock import patch

import mujoco

import creature_trajectory_search as subject
import creature_righting as righting
import creature_native as route
import creature_capture as capture
import test_creature_capture as capture_fixtures
from showcase_model import generated


class TrajectoryControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        capture_fixtures.CaptureControls.setUpClass()
        cls.fixture = capture_fixtures.CaptureControls()
        cls.profiles = subject.proposals(subject.RECIPE)

    def setUp(self):
        trap = ExitStack(); self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in trajectory controls")))

    def spec(self):
        base = json.loads((route.HERE / "creature_righting_sequence_v1.json").read_bytes())["righting_spec"]
        base.update(schema_version=righting.ASSIGNED_SCHEMA,
            descriptors=[generated(i) for i in range(14000, 14016)],
            profiles=base["profiles"][:2]+copy.deepcopy(self.profiles),
            profiles_by_body=subject.assignments(subject.RECIPE))
        return base

    def test_01_proposals_reproduce_diverse_bounded_motion_families(self):
        self.assertEqual(self.profiles, subject.proposals(copy.deepcopy(subject.RECIPE)))
        self.assertEqual(len(self.profiles), 48)
        self.assertEqual(len({righting.behavior_key(p) for p in self.profiles}), 48)
        for family in ("wave", "impulse", "waypoint"):
            rows = [p for p in self.profiles if p["id"].startswith(family+"_")]
            self.assertEqual(len(rows), 16)
            self.assertEqual({len(p["phases"]) for p in rows}, {3, 4, 5, 6})
            for p in rows:
                self.assertEqual(righting.profile(p), p)
                self.assertLessEqual(sum(v["maximum_hold_steps"] for v in p["phases"]), 432)
        with self.assertRaises(ValueError):
            subject.proposals(dict(subject.RECIPE, seed=1))
        c=dict(mode="development_discovery", righting_spec=self.spec(),
               trajectory_proposal=subject.RECIPE, trajectory_screen=subject.POLICY)
        subject.validate(c)
        c["righting_spec"]["profiles"][2]["phases"][0]["pose"][0]+=.01
        with self.assertRaises(ValueError): subject.validate(c)

    def test_02_assigned_population_balances_bodies_and_refuses_missing_comparators(self):
        spec=self.spec(); expanded=righting.expand(spec)
        self.assertEqual(len(expanded["cells"]),224)
        self.assertEqual([len(v) for v in spec["profiles_by_body"]],[14]*16)
        for index in range(2,50):
            self.assertEqual(sum(index in row for row in spec["profiles_by_body"]),4)
        changes=[lambda s:s["profiles_by_body"].pop(),
            lambda s:s["profiles_by_body"][0].pop(0),
            lambda s:s["profiles_by_body"][0].append(2),
            lambda s:s["profiles_by_body"][0].append(99),
            lambda s:s.update(profiles_by_body=[list(range(50)) for _ in range(16)]),
            lambda s:s.update(profiles_by_body=[[0,1] for _ in range(16)])]
        for change in changes:
            changed=copy.deepcopy(spec);change(changed)
            with self.assertRaises(ValueError):righting.expand(changed)
        legacy=copy.deepcopy(spec);legacy.pop("profiles_by_body");legacy["schema_version"]=righting.SCHEMA
        legacy["profiles"]=legacy["profiles"][:4]
        self.assertEqual(len(righting.expand(legacy)["cells"]),64)

    def test_03_rotation_observation_counts_every_sample_and_distal_support(self):
        creature=self.fixture.base[2][0]
        metric=subject.initial_metrics()
        row=dict(qpos=[0.,0.,.1,0.,1.,0.,0.]+[0.]*8,contacts=[])
        subject.measure(metric,row,creature)
        self.assertEqual(metric["trajectory_maximum_up_dot"],-1.)
        row["qpos"][3:7]=[math.sqrt(.5),math.sqrt(.5),0.,0.]
        row["contacts"]=[dict(geom=[0,1])]
        subject.measure(metric,row,creature)
        self.assertAlmostEqual(subject.rotation_degrees(metric["trajectory_maximum_up_dot"]),90.)
        self.assertEqual(metric["trajectory_distal_contact_samples"],0)
        site=creature["compiled"]["morphology"]["morphology_spec"]["contact_sites"][0]
        geom=creature["spec"]["geom_names"].index(site["body_id"]+"_geom")
        row["contacts"]=[dict(geom=[0,geom])]*2
        subject.measure(metric,row,creature)
        self.assertEqual(metric["trajectory_samples"],3)
        self.assertEqual(metric["trajectory_distal_contact_samples"],1)
        self.assertAlmostEqual(subject.rotation_degrees(metric["trajectory_maximum_distal_supported_up_dot"]),90.)

    def test_04_progress_leads_do_not_change_supported_upright_eligibility(self):
        spec=self.spec();spec["schema_version"]=righting.SCHEMA;spec.pop("profiles_by_body")
        spec["descriptors"]=spec["descriptors"][:1]
        spec["profiles"]=spec["profiles"][:4]+[copy.deepcopy(self.profiles[16])]
        c=dict(mode="development_discovery",righting_spec=spec,righting_selection=righting.SELECTION,
               trajectory_screen=subject.POLICY,outer_steps=720,**righting.expand(spec))
        metrics=[{**righting.initial_metrics(), **subject.initial_metrics(), "trajectory_samples":3600}
                 for _ in c["cells"]]
        for i in (2,3,4):metrics[i]["trajectory_maximum_up_dot"]=.2
        bindings=[dict(cell_id=v["cell_id"],body_shape_sha256="fixture") for v in c["cells"]]
        self.assertEqual(righting.assess(c,metrics,bindings)["eligible_worlds"],0)
        result=subject.assess(c,metrics)
        self.assertEqual([r["candidate_index"] for r in result["groups"][0]["progress_leads"]],[2,4])
        self.assertTrue(result["diagnostic_only"]);self.assertFalse(result["recovery_qualified"])
        metrics[2]["joint_limit_violation_steps"]=1
        self.assertEqual([r["candidate_index"] for r in subject.assess(c,metrics)["groups"][0]["progress_leads"]],[3,4])
        metrics[0]["trajectory_samples"]-=1
        with self.assertRaises(ValueError):subject.assess(c,metrics)
        changed=copy.deepcopy(c);changed["trajectory_screen"]["qualification_authority"]=True
        with self.assertRaises(ValueError):subject.validate(changed)

    def test_05_full_and_compact_readers_reconstruct_progress_and_refuse_forgery(self):
        for full in (True,False):
            folder,c,result=self.fixture.case(full)
            c["trajectory_screen"]=copy.deepcopy(subject.POLICY)
            _,_,creatures,metadata,controls,trace,_=self.fixture.base
            validator=route.StreamValidator(c,creatures,metadata)
            for outer in range(c["outer_steps"]):
                for row in controls[2*outer:2*outer+2]:validator.control(row)
                for sub in range(5):validator.native(trace[10*outer+2*sub:10*outer+2*sub+2])
            result["metrics"]=validator.finish();self.fixture.write_result(folder,result)
            report=route.audit_batch(folder,c,self.fixture.core_path,synthetic=True)
            self.assertEqual(report["metrics"],result["metrics"])
            self.assertEqual([m["trajectory_samples"] for m in report["metrics"]],[330,330])
            result["metrics"][0]["trajectory_maximum_up_dot"]=1.
            self.fixture.write_result(folder,result)
            with self.assertRaises(ValueError):route.audit_batch(folder,c,self.fixture.core_path,synthetic=True)

    def test_06_broader_capture_requires_same_freeze_runtime_reference_and_interface(self):
        path,c,bindings,owner=self.fixture.prerequisite()
        owner["contract"]["trajectory_screen"]=copy.deepcopy(subject.POLICY)
        owner["contract"]["readback"]=dict(mode="shared_snapshot",reference_check=False)
        c["readback"]=copy.deepcopy(owner["contract"]["readback"])
        reference=path.parent/"reference.json"
        reference.write_bytes(json.dumps(owner["contract"]).encode())
        digest=hashlib.sha256(reference.read_bytes()).hexdigest()
        owner["bindings"]["source"]={"reference.json":digest}
        path.write_bytes(json.dumps(owner).encode())
        c.update(mode="development_discovery",outer_steps=720,trajectory_screen=copy.deepcopy(subject.POLICY),
                 capture_reference=dict(path="reference.json",sha256=digest))
        with patch.object(capture,"ROOT",path.parent.resolve()):
            self.assertEqual(capture.canary_receipt(path,c,"fixture",bindings,self.fixture.root)["full_native_rows_verified"],660)
            changes=[lambda v:v.update(mode="development_confirmation"),lambda v:v.update(njmax=256),
                lambda v:v["capture_reference"].update(sha256="0"*64),
                lambda v:v["righting_spec"]["profiles"][1].update(mode="uncovered")]
            for change in changes:
                changed=copy.deepcopy(c);change(changed)
                with self.assertRaises(ValueError):capture.canary_receipt(path,changed,"fixture",bindings,self.fixture.root)
            with self.assertRaises(ValueError):capture.canary_receipt(path,c,"other",bindings,self.fixture.root)
            changed=copy.deepcopy(bindings);changed["runtime"]={}
            with self.assertRaises(ValueError):capture.canary_receipt(path,c,"fixture",changed,self.fixture.root)


if __name__ == "__main__":
    unittest.main()
