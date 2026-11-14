"""Stable force-cone numerics and exact failed-input retention; no worlds."""
import copy
from contextlib import ExitStack
import json
import math
import os
from pathlib import Path
import subprocess
import types
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_native as native
import creature_torque_map as subject
import creature_torque_map_search as search
import test_creature_torque_map as legacy


class StableControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=legacy.bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template=legacy._fixture(cls.core)["provider_request"]["state"]
        cls.descriptor=legacy.parent.spec(legacy.parent.RECIPE)["descriptors"][16]
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"torque-map-v2";cls.root.mkdir()

    cell=legacy.TorqueMapControls.cell

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in stable-cone controls")))

    def constraints(self,result,up,mu):
        force=result["direction"];feasible=result["feasible"]
        np.testing.assert_allclose(force@up,np.where(feasible,1.,0.),atol=1e-9,rtol=0.)
        self.assertTrue(np.all(np.linalg.norm(force-(force@up)[...,None]*up,axis=-1)<=np.where(feasible,mu,0.)+1e-9))
        self.assertTrue(np.all(np.linalg.norm((result["projector"]@force[...,None])[...,0]-force,axis=-1)<=1e-9))

    def test_01_all_six_retained_scalar_refusals_are_fixed(self):
        fixture=json.loads((search.ROOT/"sdk/discovery/creature_torque_map_numerical_witnesses_v1.json").read_text())
        self.assertFalse(fixture["exact_failed_native_prepared_observation"])
        self.assertEqual(len(fixture["cases"]),6)
        for case in fixture["cases"]:
            args=[case[k] for k in ("linear","lever","up","friction")]
            with self.assertRaisesRegex(ValueError,"Torque-map cone construction"):subject.cone_force(*args)
            self.constraints(subject.cone_force(*args,stable_basis=True),np.asarray(case["up"]),case["friction"])

    def test_02_near_cancelled_objectives_keep_the_analytic_direction(self):
        rng=np.random.default_rng(1061142)
        for _ in range(24):
            rotation,_=np.linalg.qr(rng.normal(size=(3,3)))
            for epsilon in (-1e-5,-1e-8,-1e-11,0.,1e-11,1e-8,1e-5):
                up=rotation @ np.array([0.,1.,0.]);linear=rotation @ np.array([[1.,0.],[0.,1.],[0.,0.]])
                result=subject.cone_force(linear,rotation @ np.array([epsilon,1.,.7]),up,.9,stable_basis=True)
                expected=rotation @ np.array([np.sign(epsilon)*.9,1.,0.])
                np.testing.assert_allclose(result["direction"],expected,atol=2e-12,rtol=0.)
                self.constraints(result,up,.9)

    def test_03_rank_degeneracy_and_cone_boundaries_remain_explicit(self):
        matrices=np.array([np.zeros((3,2)),[[0.,0.],[1.,2.],[0.,0.]],[[1.,0.],[0.,0.],[0.,0.]],
                           [[.5,0.],[1.,0.],[0.,0.]],[[.50001,0.],[1.,0.],[0.,0.]],[[1.,0.],[0.,1.],[0.,0.]]])
        lever=np.tile([1.,1.,1.],(6,1));up=np.array([0.,1.,0.])
        result=subject.cone_force(matrices,lever,up,.5,stable_basis=True)
        self.assertEqual(result["rank"].tolist(),[0,1,1,1,1,2])
        self.assertEqual(result["feasible"].tolist(),[False,True,False,True,False,True]);self.constraints(result,up,.5)
        for i in range(6):
            scalar=subject.cone_force(matrices[i],lever[i],up,.5,stable_basis=True)
            for key in result:np.testing.assert_allclose(result[key][i],scalar[key],atol=1e-12)
        zero=subject.cone_force(matrices[-1],lever[-1],up,0.,stable_basis=True)
        np.testing.assert_array_equal(zero["direction"],up)
        with self.assertRaises(ValueError):subject.cone_force(matrices[-1],lever[-1],up,.5,stable_basis=1)

    def test_04_independent_plane_endpoints_bound_random_optima(self):
        rng=np.random.default_rng(1061143);up=np.array([0.,1.,0.])
        for _ in range(256):
            basis,_=np.linalg.qr(rng.normal(size=(3,3)));linear=basis[:,:2]*rng.uniform(.01,1.,size=2)
            lever=rng.normal(size=3);mu=float(rng.uniform(.01,.95))
            result=subject.cone_force(linear,lever,up,mu,stable_basis=True);self.constraints(result,up,mu)
            normal=basis[:,2];horizontal=normal.copy();horizontal[1]=0.
            center=-normal[1]*horizontal/float(horizontal@horizontal);remaining=mu*mu-float(center@center)
            self.assertEqual(bool(result["feasible"]),remaining>=0.)
            if remaining<0.:continue
            tangent=np.cross(up,horizontal);tangent/=np.linalg.norm(tangent)
            ends=np.stack([up+center+sign*math.sqrt(remaining)*tangent for sign in (-1.,1.)])
            self.assertAlmostEqual(float(result["moment_arm"]),float(np.max(ends@lever)),places=10)

    def test_05_v1_arithmetic_is_exactly_preserved(self):
        raw=subprocess.check_output(["git","show","8b224a91e2ca4c0deec2d8f48e1af1da7ed3ce3d:sdk/discovery/creature_torque_map.py"],cwd=search.ROOT)
        frozen=types.ModuleType("frozen_torque_map");exec(compile(raw,"frozen_torque_map","exec"),frozen.__dict__)
        rng=np.random.default_rng(1061144)
        linear=rng.normal(size=(512,3,2));lever=rng.normal(size=(512,3));up=np.array([0.,1.,0.])
        old=frozen.cone_force(linear,lever,up,.9);current=subject.cone_force(linear,lever,up,.9)
        for key in old:np.testing.assert_array_equal(old[key],current[key])
        self.assertEqual(subject.policy(subject.DEFAULT_POLICY),frozen.policy(subject.DEFAULT_POLICY))
        with self.assertRaises(ValueError):subject.policy(dict(subject.STABLE_POLICY,schema_version="unversioned"))

    def test_06_v2_reaches_geometry_and_guarded_force_with_atomic_planning(self):
        cell,row=self.cell(configuration=subject.STABLE_POLICY);before=(cell.step_index,copy.deepcopy(cell.moment_state),cell.previous[:])
        with patch.object(subject,"cone_force",wraps=subject.cone_force) as calls:record=cell.plan(row)
        self.assertGreaterEqual(len(calls.call_args_list),2)
        self.assertTrue(all(call.kwargs["stable_basis"] is True for call in calls.call_args_list))
        self.assertEqual(before,(cell.step_index,cell.moment_state,cell.previous))
        decision=record["resolution"]["body_moment"];info=decision["torque_map"]
        self.assertTrue(decision["state_after"]["target"]["torque_map_target"]);self.assertTrue(info["active_limbs"])
        self.assertEqual(sorted(info["active_limbs"]+info["quiet_limbs"]),[0,1,2,3])
        for limb in info["active_limbs"]:
            for j in (2*limb,2*limb+1):self.assertLessEqual(abs(decision["force_projection"]["requested_torque"][j]-decision["post_guard_predicted_torque_nm"][j]),1e-8)

    def test_07_successor_preserves_population_bounds_and_complete_gate(self):
        for suffix,count in (("route_v2",24),("v2",240)):
            path=search.ROOT/"sdk/discovery"/f"creature_torque_map_{suffix}.json";c=native.declaration(path)
            self.assertEqual(len(c["cells"]),count);self.assertEqual(sum(n for _,_,n in native.gates(c)),312)
            spec=copy.deepcopy(c["righting_spec"])
            for p in spec["profiles"]:
                if "torque_map" in p:p["torque_map"]["schema_version"]=subject.DEFAULT_POLICY["schema_version"]
            self.assertEqual(spec,search.population(route=count==24)[0])
            raw=json.loads(path.read_text());read=Path.read_text
            for change in (lambda v:v["predecessor"].update(sha256="0"*64),lambda v:v["safety_controls"].pop(),
                    lambda v:v["righting_spec"]["profiles"][-1]["torque_map"].update(schema_version=subject.DEFAULT_POLICY["schema_version"])):
                broken=copy.deepcopy(raw);change(broken)
                with patch.object(Path,"read_text",lambda p,*a,**kw:json.dumps(broken) if p==path else read(p,*a,**kw)):
                    with self.assertRaises(ValueError):native.declaration(path)

    def test_08_failed_preparation_retains_exact_inputs_without_partial_commit(self):
        cell,_=self.cell(configuration=subject.STABLE_POLICY)
        declarations=[dict(cell_id=f"failed_input_{i}",descriptor=self.descriptor,profile=cell.candidate,motor_effectiveness=[1.]*8) for i in range(2)]
        batch=legacy.righting.RightingBatch(self.core,declarations,seed=1);self.addCleanup(batch.close)
        rows=[legacy.observation(c,legacy.fixture(c.creature,self.template),0) for c in batch.controllers]
        folder=self.root/"failure";folder.mkdir();rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]="invalid"
        prepared=dict(native_observations=[dict(marker=1),dict(marker=2)],contact_compatibility_copies=[[],[]],readback_journal=None)
        with self.assertRaisesRegex(ValueError,"joint observation"):native.prepared_step(batch,rows,folder,0,**prepared)
        saved=json.loads((folder/"failed-prepared-observations.json").read_text())
        self.assertEqual(saved["observations"],rows)
        for k,v in prepared.items():self.assertEqual(saved[k],v)
        self.assertTrue(all(c.step_index==0 and c.previous==[0.]*8 and c.moment_state is None for c in batch.controllers))
        rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]=0.
        success=self.root/"success";success.mkdir();native.prepared_step(batch,rows,success,0,**prepared)
        self.assertFalse((success/"failed-prepared-observations.json").exists())


if __name__ == "__main__":
    unittest.main()
