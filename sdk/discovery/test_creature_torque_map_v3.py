"""Geometric narrow-cone and exact planning-state controls; zero worlds."""
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
import test_creature_torque_map_v2 as previous


class GeometricControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=legacy.bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template=legacy._fixture(cls.core)["provider_request"]["state"]
        cls.descriptor=legacy.parent.spec(legacy.parent.RECIPE)["descriptors"][16]
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"torque-map-v3";cls.root.mkdir()

    cell=legacy.TorqueMapControls.cell
    constraints=previous.StableControls.constraints

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in geometric-cone controls")))

    def force(self,*args):
        return subject.cone_force(*args,stable_basis=True,geometric_cone=True)

    def test_01_retained_zero_friction_refusal_and_prior_witnesses(self):
        closed=json.loads((search.ROOT/"sdk/discovery/creature_torque_map_native_failure_v2.json").read_text())
        case=closed["diagnostic"]["representative_witness"]
        args=[case[k] for k in ("linear","lever","up","friction")]
        with self.assertRaisesRegex(ValueError,"Torque-map cone construction"):
            subject.cone_force(*args,stable_basis=True)
        result=self.force(*args);self.assertFalse(result["feasible"])
        np.testing.assert_array_equal(result["direction"],[0.,0.,0.])
        prior=json.loads((search.ROOT/"sdk/discovery/creature_torque_map_numerical_witnesses_v1.json").read_text())
        for case in prior["cases"]:
            result=self.force(*(case[k] for k in ("linear","lever","up","friction")))
            self.constraints(result,np.asarray(case["up"]),case["friction"])

    def test_02_rotated_zero_friction_distinguishes_roundoff_from_empty_cones(self):
        rng=np.random.default_rng(1061145)
        for _ in range(48):
            rotation,_=np.linalg.qr(rng.normal(size=(3,3)))
            for slope in (0.,-1e-12,1e-12,-1e-9,1e-9,-1e-7,1e-7):
                linear=rotation @ np.array([[slope,0.],[1.,0.],[0.,1.]])
                up=rotation @ np.array([0.,1.,0.]);lever=rotation @ np.array([1.,1.,1.])
                result=self.force(linear,lever,up,0.)
                self.assertEqual(bool(result["feasible"]),slope==0.)
                self.constraints(result,up,0.)
                if slope==0.:np.testing.assert_allclose(result["direction"],up,atol=8e-15,rtol=0.)

    def test_03_narrow_plane_endpoints_use_analytic_unsquared_geometry(self):
        rng=np.random.default_rng(1061146)
        for _ in range(24):
            rotation,_=np.linalg.qr(rng.normal(size=(3,3)))
            for mu in (1e-12,1e-9,1e-7,1e-4,.1,.9):
                for ratio in (.5,1.,1.5):
                    slope=mu*ratio;up=rotation @ np.array([0.,1.,0.])
                    linear=rotation @ np.array([[slope,0.],[1.,0.],[0.,1.]])
                    result=self.force(linear,rotation @ np.array([.2,0.,1.]),up,mu)
                    self.assertEqual(bool(result["feasible"]),ratio<=1.)
                    self.constraints(result,up,mu)
                    if ratio<1.:
                        expected=rotation @ np.array([slope,1.,math.sqrt(mu*mu-slope*slope)])
                        np.testing.assert_allclose(result["direction"],expected,atol=3e-12,rtol=1e-10)

    def test_04_legacy_v1_and_v2_arithmetic_is_byte_exact(self):
        raw=subprocess.check_output(["git","show","17682a1511f32831ba79f51094fb180709136911:sdk/discovery/creature_torque_map.py"],cwd=search.ROOT)
        frozen=types.ModuleType("frozen_torque_map_v2");exec(compile(raw,"frozen_torque_map_v2","exec"),frozen.__dict__)
        rng=np.random.default_rng(1061147);linear=rng.normal(size=(512,3,2));lever=rng.normal(size=(512,3));up=np.array([0.,1.,0.])
        for stable in (False,True):
            old=frozen.cone_force(linear,lever,up,.9,stable_basis=stable)
            now=subject.cone_force(linear,lever,up,.9,stable_basis=stable)
            for key in old:np.testing.assert_array_equal(old[key],now[key])

    def test_05_rank_and_scalar_batch_boundaries_and_invalid_version(self):
        matrices=np.array([np.zeros((3,2)),[[0.,0.],[1.,2.],[0.,0.]],[[1.,0.],[0.,0.],[0.,0.]],
                           [[.5,0.],[1.,0.],[0.,0.]],[[.50001,0.],[1.,0.],[0.,0.]],[[1.,0.],[0.,1.],[0.,0.]]])
        lever=np.tile([1.,1.,1.],(6,1));up=np.array([0.,1.,0.]);result=self.force(matrices,lever,up,.5)
        self.assertEqual(result["rank"].tolist(),[0,1,1,1,1,2])
        self.assertEqual(result["feasible"].tolist(),[False,True,False,True,False,True])
        self.constraints(result,up,.5)
        for i in range(6):
            scalar=self.force(matrices[i],lever[i],up,.5)
            for key in result:np.testing.assert_allclose(result[key][i],scalar[key],atol=1e-12)
        for options in (dict(geometric_cone=True),dict(stable_basis=True,geometric_cone=1)):
            with self.assertRaises(ValueError):subject.cone_force(matrices[-1],lever[-1],up,.5,**options)

    def test_06_real_v3_dispatch_keeps_guarded_forces_and_pure_planning(self):
        cell,row=self.cell(configuration=subject.GEOMETRIC_POLICY)
        before=(cell.step_index,copy.deepcopy(cell.moment_state),cell.previous[:])
        with patch.object(subject,"cone_force",wraps=subject.cone_force) as calls:record=cell.plan(row)
        self.assertGreaterEqual(len(calls.call_args_list),2)
        self.assertTrue(all(c.kwargs["stable_basis"] and c.kwargs["geometric_cone"] for c in calls.call_args_list))
        self.assertEqual(before,(cell.step_index,cell.moment_state,cell.previous))
        decision=record["resolution"]["body_moment"];info=decision["torque_map"]
        self.assertTrue(decision["state_after"]["target"]["torque_map_target"]);self.assertTrue(info["active_limbs"])
        for limb in info["active_limbs"]:
            for j in (2*limb,2*limb+1):
                self.assertLessEqual(abs(decision["force_projection"]["requested_torque"][j]-decision["post_guard_predicted_torque_nm"][j]),1e-8)

    def batch(self):
        cell,_=self.cell(configuration=subject.GEOMETRIC_POLICY)
        declarations=[dict(cell_id=f"planning_capture_{i}",descriptor=self.descriptor,profile=cell.candidate,motor_effectiveness=[1.]*8) for i in range(2)]
        batch=legacy.righting.RightingBatch(self.core,declarations,seed=1);self.addCleanup(batch.close)
        return batch,declarations

    def observations(self,batch,step):
        return [legacy.observation(c,legacy.fixture(c.creature,self.template),step) for c in batch.controllers]

    def test_07_failed_planning_keeps_exact_memory_and_reconstructs_next_decision(self):
        batch,declarations=self.batch();batch.step(self.observations(batch,0))
        batch.controllers[0].previous[0]=.12345678901234567
        before=native.planning_states(batch);rows=self.observations(batch,1);broken=copy.deepcopy(rows)
        broken[-1]["state"]["ordered_joint_observations"][0]["position_rad"]="invalid"
        folder=self.root/"planning_failure";folder.mkdir()
        with self.assertRaisesRegex(ValueError,"joint observation"):
            native.prepared_step(batch,broken,folder,1,retain_planning_state=True)
        saved=json.loads((folder/"failed-prepared-observations.json").read_text())
        self.assertEqual(saved["planning_states_before"],before);self.assertEqual(saved["planning_states_after"],before)
        self.assertEqual(saved["observations"],broken);self.assertEqual(saved["schema_version"],"locolemotion_failed_prepared_observations_v2")
        self.assertNotEqual(before[0]["state"]["previous"][0],float(np.float32(before[0]["state"]["previous"][0])))
        restored=legacy.righting.RightingBatch(self.core,declarations,seed=1);self.addCleanup(restored.close)
        for cell,state in zip(restored.controllers,saved["planning_states_before"],strict=True):
            self.assertEqual(cell.binding,state["binding"]);self.assertEqual(cell.candidate,state["profile"])
            for k,v in state["state"].items():setattr(cell,k,copy.deepcopy(v))
        success=self.root/"success";success.mkdir()
        expected=native.prepared_step(batch,rows,success,1,retain_planning_state=True)
        self.assertEqual(expected,restored.step(rows));self.assertFalse((success/"failed-prepared-observations.json").exists())

    def test_08_pre_call_memory_survives_a_commit_exception(self):
        batch,_=self.batch();before=native.planning_states(batch);folder=self.root/"commit_failure";folder.mkdir()
        with patch.object(batch.controllers[-1],"commit",side_effect=RuntimeError("injected commit refusal")):
            with self.assertRaisesRegex(RuntimeError,"injected"):
                native.prepared_step(batch,self.observations(batch,0),folder,0,retain_planning_state=True)
        saved=json.loads((folder/"failed-prepared-observations.json").read_text())
        self.assertEqual(saved["planning_states_before"],before)
        self.assertEqual([s["state"]["step_index"] for s in saved["planning_states_after"]],[1,0])

    def test_09_route_scope_complete_gate_and_frozen_predecessors(self):
        path=search.ROOT/"sdk/discovery/creature_torque_map_route_v3.json";c=native.declaration(path)
        self.assertEqual(len(c["cells"]),36);self.assertEqual(sum(n for _,_,n in native.gates(c)),330)
        self.assertEqual(c["torque_map_search"]["route_body_indices"],[0,16,21])
        self.assertTrue(c["retain_planning_state"])
        for p in c["righting_spec"]["profiles"]:
            if "torque_map" in p:self.assertEqual(p["torque_map"]["schema_version"],subject.GEOMETRIC_POLICY["schema_version"])
        with self.assertRaises(ValueError):search.population(stable_basis=True,geometric_cone=True)
        raw=json.loads(path.read_text());read=Path.read_text
        for change in (lambda v:v.update(retain_planning_state=False),lambda v:v.pop("contact_reactions"),
                lambda v:v["predecessor"].update(sha256="0"*64),lambda v:v["safety_controls"].pop(),
                lambda v:v["contact_reactions"].update(sampling_stage="prepared_before_control"),
                lambda v:v["righting_spec"]["profiles"][-1]["torque_map"].update(schema_version=subject.STABLE_POLICY["schema_version"])):
            broken=copy.deepcopy(raw);change(broken)
            with patch.object(Path,"read_text",lambda p,*a,**kw:json.dumps(broken) if p==path else read(p,*a,**kw)):
                with self.assertRaises(ValueError):native.declaration(path)

    def test_10_capture_option_refuses_unsupported_batches_before_planning(self):
        folder=self.root/"refusal";folder.mkdir();fake=types.SimpleNamespace(step=lambda _:self.fail("Unexpected planning"))
        for value in (1,True):
            with self.assertRaises(ValueError):native.prepared_step(fake,[],folder,0,retain_planning_state=value)
        self.assertFalse((folder/"failed-prepared-observations.json").exists())


if __name__ == "__main__":
    unittest.main()
