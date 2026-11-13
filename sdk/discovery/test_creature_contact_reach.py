"""Geometry, atomic contact state, retained replay and prospective inventory controls."""
import copy
from contextlib import ExitStack
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_contact_reach as subject
import creature_contact_reach_search as search
import creature_joint_braking_search as braking
import creature_native as native
import creature_righting as righting
import run_creature_native as owner
from actuation_recovery_mechanics import quaternion_rotation, xyz
from creature_batch import bridge
from gpu_quadruped_model import sha
from showcase_model import S169, generated
import test_creature_righting as existing
from test_portable_search import _fixture


class ContactReachControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.core = bridge.LocomotionCore(cls.core_path)
        cls.template = _fixture(cls.core)["provider_request"]["state"]
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-contact-reach"
        cls.root.mkdir()

    def setUp(self):
        trap = ExitStack(); self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in contact controls")))

    def batch(self, profiles=None, bodies=None):
        spec = existing.population(bodies)
        spec["starts"] = spec["starts"][:1]
        spec["profiles"] += profiles or [search.proposals()[8]]
        result = righting.RightingBatch(self.core, righting.expand(spec)["cells"], seed=search.RECIPE["seed"])
        self.addCleanup(result.close)
        return result

    def observations(self, batch, step=0):
        rows = existing.RightingControls.observations(self, batch, step)
        for row, cell in zip(rows, batch.controllers, strict=True):
            row["state"]["base_pose_world"]["position_m"] = dict(x=0.,y=float(righting.initial_arrays([cell.creature],[math.pi])[0][0,2]),z=0.)
            for c in row["state"]["ordered_contact_observations"]: c.update(presence=False, bears_support=False)
        return rows

    def case(self, index=8):
        cell = self.batch([search.proposals()[index]]).controllers[-1]
        state = self.observations(type("Batch", (), {"controllers":[cell]})())[0]["state"]
        return cell, state, quaternion_rotation([1.,0.,0.,0.])

    def test_01_profiles_refuse_unsafe_or_undeclared_behavior(self):
        p = search.proposals()[8]
        for key, value in (("axis_body",[1.,1.,0.]),("axis_body",[True,0.,0.]),
            ("active_limb_count",True),("push_depth_m",.061),("sweep_fraction",.1),
            ("strategy","teleport"),("reach_timeout_steps",59),("push_steps",241),
            ("target_update_steps",0),("reset_steps",11),("pose_b",[1.]*8),
            ("position_gain_s_inv",math.nan),("maximum_speed_rad_s",3.6)):
            bad=copy.deepcopy(p);bad[key]=value
            with self.assertRaises(ValueError):righting.profile(bad)
        bad=copy.deepcopy(p);bad.pop("joint_braking")
        with self.assertRaises(ValueError):righting.profile(bad)
        self.assertEqual(righting.behavior_key(p),righting.behavior_key(dict(p,id="alias")))
        self.assertEqual(righting.behavior_key(p),righting.behavior_key(dict(p,axis_body=[1,0,0])))

    def test_02_vector_geometry_matches_scalar_tree_for_varied_bodies_and_rotations(self):
        rng=np.random.Generator(np.random.PCG64(1061124))
        batch=self.batch(bodies=[S169]+[generated(i) for i in range(12000,12007)])
        for cell in batch.controllers[2::3]:
            g=cell.contact_geometry
            for _ in range(4):
                q=rng.normal(size=4);q/=np.linalg.norm(q)
                rot=quaternion_rotation(q);position=rng.uniform(-1.,1.,size=3)
                index=int(rng.integers(0,subject.GRID**2))
                for limb in range(4):
                    angles=[0.]*8
                    for k in range(2):
                        j=cell.spec["joints"][2*limb+k];v=g.poses[index,k]
                        angles[2*limb+k]=v*(j["upper_limit_rad"] if v>=0 else -j["lower_limit_rad"])
                    frame=g.tree.kinematics(position,q,angles);bi=g.distal[limb]
                    offset=frame["rotations"][bi][:,1]*cell.spec["bodies"][bi]["collision"]["length_m"]/2
                    ends=np.asarray([frame["positions"][bi]-offset,frame["positions"][bi]+offset])
                    expected=ends[int(np.argmin(ends[:,1]))]
                    np.testing.assert_allclose(g.candidates(limb,position,rot)[index],expected,rtol=0.,atol=1e-12)

    def test_03_reachable_floor_and_unreachable_targets_keep_residuals(self):
        cell,state,rot=self.case()
        g=cell.contact_geometry;position=xyz(state["base_pose_world"]["position_m"])
        self.assertTrue((g.measured_points(state)[:,1]-g.radii>0).all())
        for limb in range(4):
            selected=g.select(limb,position,rot,[0.,0.],"outward",.015)
            self.assertLessEqual(selected["predicted_capsule_clearance_m"],-.015+1e-12)
            self.assertTrue(all(abs(v)<=.9 for v in selected["normalized_pose"]))
            high=g.select(limb,position+np.array([0.,10.,0.]),rot,[0.,0.],"outward",.015,[100.,0.,100.])
            self.assertGreater(high["anchor_error_m"],100.)
            self.assertGreater(high["predicted_capsule_clearance_m"],9.)
            again=g.select(limb,position,rot,[0.,0.],"outward",.015)
            self.assertEqual(selected,again)

    def test_04_limb_selection_matches_floor_reaction_moment_direction(self):
        cell,state,rot=self.case()
        g=cell.contact_geometry;contacts=state["ordered_contact_observations"]
        for axis in ([1.,0.,0.],[-1.,0.,0.],[0.,0.,1.],[0.,0.,-1.]):
            p=dict(cell.candidate,axis_body=axis)
            d=subject.plan(p,g,state,rot,contacts,None,False)
            for limb in d["state_after"]["active_limbs"]:
                lever=rot @ g.hips[limb]
                self.assertGreater(float(np.dot(np.cross(lever,[0.,1.,0.]),rot @ axis)),0.)

    def test_05_only_measured_contact_latches_and_world_anchor_survives_motion(self):
        cell,state,rot=self.case();p=cell.candidate;g=cell.contact_geometry
        contacts=state["ordered_contact_observations"]
        d=subject.plan(p,g,state,rot,contacts,None,False)
        self.assertEqual((d["phase"],d["anchor_updates"]),("reach",0))
        memory=copy.deepcopy(d["state_after"]);limb=memory["active_limbs"][0]
        contacts[limb].update(presence=True,bears_support=True)
        before=copy.deepcopy(memory)
        d=subject.plan(p,g,state,rot,contacts,memory,False)
        self.assertEqual(memory,before)
        self.assertEqual((d["phase"],d["selection_reason"],d["anchor_updates"]),("push","measured_contact",1))
        anchor=copy.deepcopy(d["state_after"]["anchors"][limb])
        state["base_pose_world"]["position_m"]["x"]+=.2
        contacts[limb].update(presence=False,bears_support=False)
        memory=d["state_after"];memory["elapsed"]=6
        d=subject.plan(p,g,state,rot,contacts,memory,False)
        self.assertEqual(d["state_after"]["anchors"][limb],anchor)
        self.assertEqual(d["anchor_updates"],0)
        self.assertEqual(d["state_after"]["choices"][limb]["desired_anchor_world_m"][0],anchor[0])

    def test_06_sweep_is_bounded_tangent_and_anchor_is_not_overwritten(self):
        cell,state,rot=self.case(16);p=cell.candidate;g=cell.contact_geometry
        contacts=state["ordered_contact_observations"]
        d=subject.plan(p,g,state,rot,contacts,None,False)
        for limb in d["state_after"]["active_limbs"]:contacts[limb].update(presence=True,bears_support=True)
        d=subject.plan(p,g,state,rot,contacts,d["state_after"],False)
        memory=copy.deepcopy(d["state_after"]);memory["elapsed"]=60
        result=subject.plan(p,g,state,rot,contacts,memory,False)
        tangent=np.cross(rot @ np.asarray(p["axis_body"]),[0.,1.,0.])
        for limb in memory["active_limbs"]:
            anchor=np.asarray(memory["anchors"][limb])
            expected=anchor+tangent*p["sweep_fraction"]*g.lengths[limb]*.5
            expected[1]=g.radii[limb]-p["push_depth_m"]
            np.testing.assert_allclose(result["state_after"]["choices"][limb]["desired_anchor_world_m"],expected,rtol=0.,atol=1e-12)
            self.assertEqual(result["state_after"]["anchors"][limb],anchor.tolist())

    def test_07_timeouts_bounded_push_cycle_and_upright_reset(self):
        cell,state,rot=self.case();p=cell.candidate;g=cell.contact_geometry;contacts=state["ordered_contact_observations"]
        d=subject.plan(p,g,state,rot,contacts,None,False);memory=d["state_after"]
        memory["elapsed"]=p["reach_timeout_steps"]
        d=subject.plan(p,g,state,rot,contacts,memory,False)
        self.assertEqual((d["phase"],d["selection_reason"]),("reset","reach_timeout"))
        memory=d["state_after"];memory["elapsed"]=p["reset_steps"]
        d=subject.plan(p,g,state,rot,contacts,memory,False)
        self.assertEqual((d["phase"],d["state_after"]["cycle"],d["selection_reason"]),("reach",1,"new_cycle"))
        self.assertEqual(d["state_after"]["anchors"],[None]*4)
        memory=d["state_after"];memory.update(phase="push",elapsed=p["push_steps"])
        d=subject.plan(p,g,state,rot,contacts,memory,False)
        self.assertEqual((d["phase"],d["selection_reason"]),("reset","bounded_push"))
        d=subject.plan(p,g,state,rot,contacts,d["state_after"],True)
        self.assertEqual(d["normalized_targets"],[0.]*8)
        self.assertEqual(d["state_after"]["anchors"],[None]*4)

    def test_08_invalid_late_observation_and_returned_mutation_are_atomic(self):
        batch=self.batch([search.proposals()[8],search.proposals()[16]])
        for change in ("position","joint","contact"):
            obs=self.observations(batch);state=obs[-1]["state"]
            if change=="position":state["base_pose_world"]["position_m"]["x"]=math.nan
            if change=="joint":state["ordered_joint_observations"][-1]["velocity_rad_s"]=math.inf
            if change=="contact":state["ordered_contact_observations"][0].update(presence=False,bears_support=True)
            with self.assertRaises(ValueError):batch.step(obs)
            self.assertTrue(all(c.step_index==0 and c.previous==[0.]*8 and c.contact_state is None for c in batch.controllers))
        rows=batch.step(self.observations(batch))
        rows[-1]["resolution"]["contact_reach"]["state_after"]["targets"][0]=999.
        self.assertNotEqual(batch.controllers[-1].contact_state["targets"][0],999.)
        self.assertTrue(all(c.step_index==1 for c in batch.controllers))

    def test_09_braking_and_observed_bound_remain_in_contact_commands(self):
        batch=self.batch();obs=self.observations(batch)
        for c,o in zip(batch.controllers,obs,strict=True):
            c.previous=[1.]*8
            for joint,bound in zip(o["state"]["ordered_joint_observations"],c.spec["joints"],strict=True):
                joint.update(position_rad=bound["upper_limit_rad"]-.01,velocity_rad_s=2.)
        row=batch.step(obs)[-1]
        self.assertEqual(row["native_targets"],[0.]*8)
        self.assertTrue(all(c["anticipatory_joint_braking"]["applied"] for c in row["resolution"]["ordered_commands"]))
        self.assertTrue(all(not c["observed_joint_limit_breach"] for c in row["resolution"]["ordered_commands"]))

    def test_10_actual_declarations_preflight_and_complete_test_input_inventory(self):
        expected={native.HERE/n for n in ("creature_trajectory_search_v1.json","creature_trajectory_retiming_v1.json",
            "creature_joint_braking_v1.json","creature_joint_braking_route_v1.json",
            "creature_contact_reach_v1.json","creature_contact_reach_route_v1.json")}
        for name,worlds,bodies in (("creature_contact_reach_route_v1.json",8,1),("creature_contact_reach_v1.json",128,16)):
            path=native.HERE/name;c=native.declaration(path);report=native.preflight(c,self.core_path)
            self.assertEqual((report["world_build_count"],report["solver_steps"]),(0,0))
            self.assertEqual((report["planned_gpu_worlds"],report["distinct_body_shapes"]),(worlds,bodies))
            self.assertTrue(all(len(g["cell_indices"])==8 for g in report["batches"]))
            paths=owner.source_paths(path,c)
            self.assertEqual(len(paths),len(set(paths)));self.assertTrue(expected<=set(paths))
            self.assertTrue(all(p.is_file() and p.is_relative_to(native.ROOT) for p in paths))
            self.assertEqual(sum(k for _,_,k in native.gates(c)),172)

    def test_11_balanced_population_and_fixed_eligibility_refuse_drift(self):
        spec=search.spec(search.RECIPE);rows=spec["profiles_by_body"]
        self.assertEqual(len(righting.expand(spec)["cells"]),128)
        self.assertEqual(spec["profiles"][:2],search.source()["profiles"][:2])
        self.assertEqual([len(r) for r in rows],[8]*16)
        self.assertEqual(len({righting.behavior_key(p) for p in spec["profiles"]}),26)
        for i in range(2,26):self.assertEqual(sum(i in r for r in rows),4)
        for row in rows:
            for family in subject.STRATEGIES:self.assertEqual(sum(spec["profiles"][i].get("strategy")==family for i in row),2)
        c=native.declaration(native.HERE/"creature_contact_reach_v1.json")
        for change in (lambda x:x["righting_spec"]["profiles"][2].update(push_depth_m=.02),
            lambda x:x["righting_spec"]["profiles_by_body"][0].pop(),lambda x:x.update(outer_steps=720),
            lambda x:x.update(seed=1),lambda x:x.pop("contact_reach_search")):
            bad=copy.deepcopy(c);change(bad)
            with self.assertRaises(ValueError):search.validate(bad)
        self.assertEqual(c["righting_selection"],righting.SELECTION)

    def test_12_full_shared_reader_replays_targets_and_refuses_forged_memory(self):
        folder,c,creatures,metas,controls,trace,result=existing.RightingControls._reader_case(
            self,False,sequence_profile=search.proposals()[8],fixture_only=True)
        report=native.audit_batch(folder,c,self.core_path,synthetic=True)
        self.assertEqual((report["controller_rows_replayed"],report["native_rows_verified"]),(132,660))
        self.assertEqual(report["reader_world_build_count"],0)
        with self.assertRaises(ValueError):
            search.route_report(controls,c["righting_spec"]["profiles"])
        for field,value in (("native_targets",[99.]*8),("contact_memory",None)):
            changed=copy.deepcopy(controls)
            if field=="contact_memory":changed[1]["resolution"]["contact_reach"]["state_after"]["anchors"][0]=[1.,2.,3.]
            else:changed[1][field]=value
            (folder/"controller.jsonl").write_text("".join(json.dumps(r)+"\n" for r in changed),encoding="utf-8")
            result["stream_sha256"]["controller"]=sha(folder/"controller.jsonl")
            (folder/"worker-result.json").write_text(json.dumps(result),encoding="utf-8")
            with self.assertRaises(ValueError):native.audit_batch(folder,c,self.core_path,synthetic=True)


if __name__=="__main__":
    unittest.main()
