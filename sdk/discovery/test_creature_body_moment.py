"""Force direction, clear targets, bounded commands, atomic memory and route controls."""
import copy
from contextlib import ExitStack
import hashlib
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

import creature_body_moment as subject
import creature_body_moment_diagnosis as diagnosis
import creature_body_moment_search as search
import creature_native as native
import creature_righting as righting
import run_creature_native as owner
from creature_batch import bridge
from creature_contact_moment import PoseContacts
from test_creature_batch import fixture, observation
from test_portable_search import _fixture


class BodyMomentControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template=_fixture(cls.core)["provider_request"]["state"]
        cls.spec=search.spec(search.RECIPE,route=True)
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-body-moment"
        cls.root.mkdir()

    def setUp(self):
        trap=ExitStack();self.addCleanup(trap.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in moment controls")))

    def cell(self, index=0):
        declaration=dict(cell_id="moment_control",descriptor=self.spec["descriptors"][0],
                         profile=search.proposals()[index],motor_effectiveness=[1.]*8)
        cell=righting.RightingController(self.core,declaration,seed=search.RECIPE["seed"])
        self.addCleanup(cell.close)
        row=observation(cell,fixture(cell.creature,self.template),0)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
        row["state"]["base_pose_world"]["position_m"]=dict(x=0.,y=float(righting.initial_arrays([cell.creature],[math.pi])[0][0,2]),z=0.)
        for c in row["state"]["ordered_contact_observations"]:c.update(presence=False,bears_support=False)
        return cell,row

    def test_01_profile_bounds_and_numeric_aliases(self):
        p=search.proposals()[0]
        for key,value in (("axis_body",[True,0.,0.]),("friction_ratio",.96),("normal_load_ratio",math.nan),
                          ("maximum_speed_rad_s",3.6),("target_update_steps",True),("minimum_hold_steps",240),
                          ("strategy","oracle"),("moment_weight_length_ratio",0.)):
            with self.assertRaises(ValueError):righting.profile(dict(p,**{key:value}))
        q=copy.deepcopy(p);q.pop("joint_braking")
        with self.assertRaises(ValueError):righting.profile(q)
        self.assertEqual(righting.behavior_key(p),righting.behavior_key(dict(p,id="alias",axis_body=[1,0,0])))

    def test_02_population_has_fresh_comparators_and_balanced_strata(self):
        spec=search.spec(search.RECIPE);expanded=righting.expand(spec)
        self.assertEqual(len(expanded["cells"]),240)
        self.assertEqual(len({tuple(v[k] for k in native.population.FIELDS) for v in spec["descriptors"]}),24)
        for i in range(2,26):
            assigned=[b for b,row in enumerate(spec["profiles_by_body"]) if i in row]
            self.assertEqual((len(assigned),sum(b<12 for b in assigned)),(8,4))
        route=search.spec(search.RECIPE,route=True)
        self.assertEqual(len(righting.expand(route)["cells"]),10)
        self.assertEqual({(tuple(p["axis_body"]),p["strategy"]) for p in route["profiles"][2:]},
                         {(tuple(a),s) for a in subject.AXES for s in ("drive","rock")})

    def test_03_friction_direction_matches_scalar_cross_products(self):
        rng=np.random.default_rng(1061135)
        for _ in range(60):
            points=rng.normal(size=(4,3));center=rng.normal(size=3)
            up=rng.normal(size=3);up/=np.linalg.norm(up)
            axis=rng.normal(size=3);axis/=np.linalg.norm(axis)
            forces,arms=subject.force_direction(points,center,axis,up,.7)
            np.testing.assert_allclose(forces @ up,1.,rtol=0.,atol=1e-14)
            self.assertTrue(np.all(np.linalg.norm(forces-up,axis=1)<=.7+1e-14))
            for i in range(4):
                self.assertAlmostEqual(arms[i],float(np.dot(np.cross(points[i]-center,forces[i]),axis)),places=13)
                self.assertGreaterEqual(arms[i]+1e-14,float(np.dot(np.cross(points[i]-center,up),axis)))

    def test_04_selected_targets_are_clear_at_varied_orientations(self):
        cell,row=self.cell();g=cell.moment_geometry
        rng=np.random.default_rng(1061135)
        for _ in range(24):
            quaternion=rng.normal(size=4);quaternion/=np.linalg.norm(quaternion)
            rotation=subject.mechanics.quaternion_rotation(quaternion)
            d=g.target(np.array([0.,.1,0.]),rotation,np.zeros(8),np.array(subject.AXES[_%4]),cell.candidate)
            explicit=PoseContacts(cell.spec,np.asarray([d["normalized_targets"]]))
            self.assertTrue(explicit.clear[0]);self.assertGreaterEqual(d["target_nonadjacent_gap_m"],-1e-9)
            self.assertAlmostEqual(d["target_nonadjacent_gap_m"],float(explicit.minimum_gap[0]),places=12)

    def test_05_measured_geometry_uses_actual_joints_without_clipping(self):
        cell,row=self.cell();g=cell.moment_geometry
        for pose in (np.full(8,.6),np.array([.9,-.9]*4)):
            q=np.where(pose>=0,pose*g.upper,-pose*g.lower)
            frame=g.tree.kinematics([.3,.2,-.1],[1.,0.,0.,0.],q)
            points,gap=g.measured(frame);exact=PoseContacts(cell.spec,pose[None,:])
            self.assertAlmostEqual(gap,float(exact.minimum_gap[0]),places=12)
            for i,b in enumerate(g.bank.distal):
                shape=g.tree.bodies[b]["collision"]
                self.assertAlmostEqual(points[i,1],frame["positions"][b,1]-abs(frame["rotations"][b,1,1])*shape["length_m"]/2-shape["radius_m"],places=12)
        frame=g.tree.kinematics([0.,.2,0.],[1.,0.,0.,0.],g.upper*1.05)
        self.assertTrue(np.isfinite(g.measured(frame)[0]).all())

    def test_06_plan_is_pure_and_commit_advances_once(self):
        cell,row=self.cell(12);first=cell.plan(row);second=cell.plan(row)
        self.assertEqual(first,second);self.assertIsNone(cell.moment_state);self.assertEqual(cell.step_index,0)
        cell.commit(first);self.assertEqual(cell.step_index,1)
        self.assertEqual(cell.moment_state,first["resolution"]["body_moment"]["state_after"])
        with self.assertRaises(ValueError):cell.plan(row)

    def test_07_no_contact_cannot_request_reaction_force(self):
        cell,row=self.cell(16);record=cell.plan(row);d=record["resolution"]["body_moment"]
        self.assertEqual(d["requested_wrenches"],[]);self.assertIsNone(d["force_projection"])
        self.assertEqual(d["phase"],"reach");self.assertGreater(max(map(abs,record["native_targets"])),0.)

    def test_08_measured_contacts_bound_force_and_moment_requests(self):
        cell,row=self.cell(16);g=cell.moment_geometry
        first=cell.plan(row)["resolution"]["body_moment"]
        pose=np.asarray(first["normalized_targets"]);q=np.where(pose>=0,pose*g.upper,-pose*g.lower)
        for j,v in zip(row["state"]["ordered_joint_observations"],q):j["position_rad"]=float(v)
        for c in row["state"]["ordered_contact_observations"]:c.update(presence=True,bears_support=True)
        record=cell.plan(row);d=record["resolution"]["body_moment"]
        self.assertTrue(d["active_limbs"]);self.assertLessEqual(sum(w["force"][1] for w in d["requested_wrenches"]),g.weight*cell.candidate["normal_load_ratio"]+1e-12)
        self.assertLessEqual(d["proposed_moment_nm"],d["requested_moment_nm"]+1e-12)
        for w in d["requested_wrenches"]:
            self.assertLessEqual(math.hypot(w["force"][0],w["force"][2]),.9*w["force"][1]+1e-12)
        for i in set(range(4))-set(d["active_limbs"]):
            self.assertNotIn(g.tree.body_ids[g.bank.distal[i]],[w["body_id"] for w in d["requested_wrenches"]])

    def test_09_applied_prediction_binds_post_guard_velocities(self):
        cell,row=self.cell(20)
        for c in row["state"]["ordered_contact_observations"]:c.update(presence=True,bears_support=True)
        for j in row["state"]["ordered_joint_observations"]:j["velocity_rad_s"]=.7
        record=cell.plan(row)
        expected=subject.mechanics.motor_torque(record["native_targets"],[.7]*8,
            cell.creature["spec"]["velocity_gains"],cell.creature["spec"]["force_ranges"])
        np.testing.assert_array_equal(record["resolution"]["body_moment"]["post_guard_predicted_torque_nm"],expected)

    def test_10_rocking_requires_hold_then_reversal_or_deadline(self):
        cell,row=self.cell(4);cell.moment_state=dict(sign=1,elapsed=29,switches=0,target=None)
        row["state"]["base_twist_world"]["angular_velocity_rad_s"]=dict(x=-.2,y=0.,z=0.)
        self.assertEqual(cell.plan(row)["resolution"]["body_moment"]["state_after"]["sign"],1)
        cell.moment_state["elapsed"]=30
        self.assertEqual(cell.plan(row)["resolution"]["body_moment"]["selection_reason"],"measured_reversal")
        row["state"]["base_twist_world"]["angular_velocity_rad_s"]=dict(x=0.,y=0.,z=0.)
        cell.moment_state["elapsed"]=180
        self.assertEqual(cell.plan(row)["resolution"]["body_moment"]["selection_reason"],"bounded_reversal")

    def test_11_upright_stance_releases_force_and_rock_memory(self):
        cell,row=self.cell(4);cell.moment_state=dict(sign=-1,elapsed=99,switches=4,target=None)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=0.,z=0.,w=1.)
        row["state"]["base_pose_world"]["position_m"]["y"]=1.
        for c in row["state"]["ordered_contact_observations"]:c.update(presence=True,bears_support=True)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual((d["phase"],d["normalized_targets"],d["requested_wrenches"]),("upright_stance",[0.]*8,[]))
        self.assertEqual((d["state_after"]["sign"],d["state_after"]["elapsed"]),(1,0))

    def test_12_joint_guards_override_slew_and_retain_breaches(self):
        cell,row=self.cell();cell.previous=[.2]*8
        for j,spec in zip(row["state"]["ordered_joint_observations"],cell.spec["joints"]):
            j.update(position_rad=spec["upper_limit_rad"]+.01,velocity_rad_s=1.)
        result=cell.plan(row)
        self.assertTrue(all(result["resolution"]["observed_joint_limit_breaches"]))
        self.assertTrue(all(-3.5<=v<=0. for v in result["native_targets"]))

    def test_13_legacy_contact_and_comparator_plans_remain_exact(self):
        raw=subprocess.check_output(["git","show","bf8af4a95d0fc692b7923b09558d1e0d67c97699:sdk/discovery/creature_righting.py"],cwd=search.ROOT)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),"558eea4b08c164bd8929e68a4fb4c80392c5a63c13b1528f0e85fd533b5d72df")
        legacy=types.ModuleType("frozen_righting");exec(compile(raw,"frozen_righting","exec"),legacy.__dict__)
        old=search.source("creature_torso_target_v1.json")["righting_spec"]
        for i in (0,1,2,3,4):
            declaration=dict(cell_id=f"legacy_{i}",descriptor=old["descriptors"][0],profile=old["profiles"][i],motor_effectiveness=[1.]*8)
            a=legacy.RightingController(self.core,declaration,seed=1);b=righting.RightingController(self.core,declaration,seed=1)
            self.addCleanup(a.close);self.addCleanup(b.close)
            for step in range(48):
                row=observation(a,fixture(a.creature,self.template),step)
                row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
                self.assertEqual(a.step(row),b.step(row))

    def test_14_native_declarations_bind_complete_gate_and_source_inputs(self):
        for name in ("creature_body_moment_v1.json","creature_body_moment_route_v1.json"):
            path=search.ROOT/"sdk/discovery"/name
            # Consumed declarations retain their original 16-control gate.
            # A future launch must explicitly declare the four new controls.
            with self.assertRaises(ValueError):native.declaration(path)
            fixture=json.loads(path.read_bytes())
            fixture["safety_controls"]=[dict(name=n,module=m,count=k) for n,m,k in native.gates(fixture)]
            view=types.SimpleNamespace(resolve=path.resolve,read_text=lambda **kwargs:json.dumps(fixture))
            c=native.declaration(view)
            paths={str(p.relative_to(search.ROOT)).replace("\\","/") for p in owner.source_paths(path,c)}
            self.assertTrue({"sdk/discovery/"+n for n in search.SOURCES}<=paths)
            self.assertIn("sdk/discovery/test_creature_body_moment.py",paths)
            self.assertIn("sdk/discovery/creature_body_moment_diagnosis.py",paths)
            for key in ("body_moment_search","trajectory_screen"):
                broken=copy.deepcopy(c);broken.pop(key)
                with self.assertRaises((ValueError,KeyError)):search.validate(broken)
            broken=copy.deepcopy(c);broken["outer_steps"]+=1
            with self.assertRaises(ValueError):search.validate(broken)
            self.assertTrue(native.work_enabled(c))

    def test_15_partial_route_coverage_refuses_compact_launch(self):
        folder=self.root/"route-coverage";stream=folder/"native/batch_0/controller.jsonl"
        stream.parent.mkdir(parents=True)
        cell,row=self.cell(20)
        cell.moment_state=dict(sign=1,elapsed=180,switches=0,target=None)
        for c in row["state"]["ordered_contact_observations"]:c.update(presence=True,bears_support=True)
        record=cell.plan(row)
        # Synthetic route fixtures exercise the reader's refusals only.
        d=record["resolution"]["body_moment"]
        d.update(active_limbs=[0],requested_wrenches=[dict(force=[1.,2.,0.])])
        stream.write_text(json.dumps(record)+'\n',encoding="utf-8")
        receipt=dict(contract=dict(mode="route_ghost"),audit=dict(batches=[dict(batch_id="batch_0")],
            capture=dict(controller_replay_verified=True,within_run_projection_verified=True)))
        self.assertTrue(search.verify_route(folder,receipt)["complete"])
        for field,value in (("active_limbs",[]),("requested_wrenches",[]),("selection_reason","hold")):
            broken=copy.deepcopy(record);broken["resolution"]["body_moment"][field]=value
            stream.write_text(json.dumps(broken)+'\n',encoding="utf-8")
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        stream.write_text(json.dumps(record)+'\n',encoding="utf-8")
        receipt["artifacts"]=[dict(path="native/batch_0/controller.jsonl",bytes=stream.stat().st_size,sha256="0"*64)]
        with self.assertRaises(ValueError):search.verify_route(folder,receipt)

    def test_16_batch_rejection_keeps_every_moment_state_uncommitted(self):
        spec=copy.deepcopy(self.spec);spec["profiles"]=spec["profiles"][:2]+spec["profiles"][2:4]
        batch=righting.RightingBatch(self.core,righting.expand(spec)["cells"],seed=search.RECIPE["seed"])
        self.addCleanup(batch.close)
        rows=[]
        for cell in batch.controllers:
            row=observation(cell,fixture(cell.creature,self.template),0)
            row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
            rows.append(row)
        rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]=math.nan
        with self.assertRaises(ValueError):batch.step(rows)
        self.assertTrue(all(c.step_index==0 and c.moment_state is None and c.previous==[0.]*8 for c in batch.controllers))

    def test_17_batched_geometry_preserves_frozen_outputs_across_bodies(self):
        raw=subprocess.check_output(["git","show","23f48892216d0f57e34c02b9605a23b76e5be514:sdk/discovery/creature_body_moment.py"],cwd=search.ROOT)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),"ecdf354897afe0f333e174b586da78c86c1fea9d08a2f384e4c954945e2cadd2")
        frozen=types.ModuleType("frozen_moment");exec(compile(raw,"frozen_moment","exec"),frozen.__dict__)
        spec=search.spec(search.RECIPE);rng=np.random.default_rng(1061136)
        for index in (0,11,12,23):
            c=dict(cell_id=f"geometry_{index}",descriptor=spec["descriptors"][index],
                   profile=search.proposals()[0],motor_effectiveness=[1.]*8)
            cell=righting.RightingController(self.core,c,seed=1);self.addCleanup(cell.close)
            g=cell.moment_geometry
            for _ in range(16):
                # Include actual angles outside both the pose-bank and joint-limit envelopes.
                q=rng.uniform(-1.1,1.1,8)*g.upper
                orientation=rng.normal(size=4);orientation/=np.linalg.norm(orientation)
                frame=g.tree.kinematics(rng.normal(size=3),orientation,q)
                before,after=frozen.Geometry.measured(g,frame),g.measured(frame)
                self.assertEqual(before[0].tobytes(),after[0].tobytes())
                self.assertEqual(np.float64(before[1]).tobytes(),np.float64(after[1]).tobytes())
                intrinsic=g.measured(g.tree.kinematics([0.,0.,0.],[0.,0.,0.,1.],q))[1]
                self.assertAlmostEqual(intrinsic,after[1],places=12)

    def path_fixture(self, gaps):
        g=types.SimpleNamespace(tree=types.SimpleNamespace(kinematics=lambda p,r,q:q))
        values=iter(gaps);g.measured=lambda frame:(None,next(values))
        return diagnosis.PathClearance(g)

    def path_sample(self, degrees):
        angle=math.radians(180-degrees)/2
        return [0.,0.,.1,math.cos(angle),math.sin(angle),0.,0.]+[0.]*8

    def test_18_clear_prefix_does_not_restart_after_overlap(self):
        motion=self.path_fixture([.01,.002,-.003,.02])
        for i,angle in enumerate((0.,10.,20.,30.)):
            motion.observe(self.path_sample(angle),i/600)
        result=motion.finish(3,30.)
        self.assertEqual(result["first_overlap"]["sample_number"],2)
        self.assertAlmostEqual(result["peak_before_first_overlap"]["rotation_degrees"],10.)
        self.assertEqual(result["minimum_nonadjacent_gap_m"],-.003)
        self.assertFalse(result["sampled_path_clear"])

    def test_19_initial_overlap_and_numeric_tolerance_are_explicit(self):
        motion=self.path_fixture([-.01,.02]);motion.observe(self.path_sample(0.),0.)
        motion.observe(self.path_sample(10.),1/600)
        result=motion.finish(1,10.)
        self.assertEqual(result["first_overlap"]["sample_number"],0)
        self.assertIsNone(result["peak_before_first_overlap"])
        clear=self.path_fixture([-diagnosis.TOLERANCE_M,0.])
        clear.observe(self.path_sample(0.),0.);clear.observe(self.path_sample(10.),1/600)
        self.assertTrue(clear.finish(1,10.)["sampled_path_clear"])

    def test_20_path_diagnosis_refuses_missing_samples_or_changed_peak(self):
        motion=self.path_fixture([.01,.01]);motion.observe(self.path_sample(0.),0.)
        with self.assertRaises(ValueError):motion.observe(self.path_sample(0.),0.)
        bad=self.path_sample(0.);bad[7]=math.nan
        with self.assertRaises(ValueError):motion.observe(bad,1/600)
        with self.assertRaises(ValueError):motion.finish(1,0.)
        with self.assertRaises(ValueError):motion.finish(0,10.)
        motion.observe(self.path_sample(10.),1/600)
        self.assertTrue(motion.finish(1,10.)["sampled_path_clear"])


if __name__=="__main__":unittest.main()
