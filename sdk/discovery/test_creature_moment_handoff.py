"""Measured steering, released support, fresh references and retained path controls."""
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

import creature_body_moment as moment
import creature_body_moment_diagnosis as diagnosis
import creature_moment_handoff as subject
import creature_moment_handoff_search as search
import creature_native as native
import creature_righting as righting
import creature_trajectory_search as trajectory
import run_creature_native as owner
from creature_batch import bridge
from test_creature_batch import fixture, observation
from test_portable_search import _fixture


class HandoffControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template=_fixture(cls.core)["provider_request"]["state"]
        cls.spec=search.spec(route=True)
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-moment-handoff"
        cls.root.mkdir()

    def setUp(self):
        trap=ExitStack();self.addCleanup(trap.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in handoff controls")))

    def cell(self, index=0, profile=None):
        declaration=dict(cell_id="handoff_control",descriptor=self.spec["descriptors"][0],
                         profile=profile or search.proposals()[index],motor_effectiveness=[1.]*8)
        cell=righting.RightingController(self.core,declaration,seed=search.RECIPE["seed"])
        self.addCleanup(cell.close)
        row=observation(cell,fixture(cell.creature,self.template),0)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
        row["state"]["base_pose_world"]["position_m"]=dict(x=0.,y=.15,z=0.)
        for c in row["state"]["ordered_contact_observations"]:c.update(presence=False,bears_support=False)
        return cell,row

    def decision(self, cell, row):
        return cell.plan(row)["resolution"]["body_moment"]

    def memory(self, cell, **changes):
        result=dict(phase="push",elapsed=0,stall_count=0,cycles=0,
                    axis_body=cell.candidate["axis_body"][:],inner=None)
        result.update(changes)
        return result

    def test_01_policy_refuses_aliases_unknown_fields_and_unbounded_clocks(self):
        p=search.proposals()[0]
        changes=(("steering_bias",True),("steering_bias",.76),("minimum_tilt_sine",math.nan),
            ("axis_slew_rad_per_step",.21),("progress_deadband_rad_s",0.),("schedule","oracle"),
            ("minimum_push_steps",True),("minimum_push_steps",181),("maximum_push_steps",241),
            ("release_steps",0),("stall_steps",61),("unknown",1))
        for key,value in changes:
            bad=copy.deepcopy(p);bad["handoff"][key]=value
            with self.assertRaises(ValueError):righting.profile(bad)
        bad=copy.deepcopy(p);bad["handoff"].update(minimum_push_steps=120,maximum_push_steps=60)
        with self.assertRaises(ValueError):righting.profile(bad)
        with self.assertRaises(ValueError):righting.profile(dict(p,strategy="rock"))
        good=righting.profile(p);good["handoff"]["schedule"]="clock"
        self.assertEqual(p["handoff"]["schedule"],"continuous")
        self.assertNotEqual(righting.behavior_key(p),righting.behavior_key(good))

    def test_02_factored_assignments_cover_each_body_and_both_strata(self):
        proposals=search.proposals();spec=search.spec()
        self.assertEqual((len(proposals),len({righting.behavior_key(p) for p in proposals})),(36,36))
        self.assertEqual(len(righting.expand(spec)["cells"]),216)
        self.assertEqual(len(righting.expand(self.spec)["cells"]),12)
        for row,ref in zip(spec["profiles_by_body"],search.reference_indices(),strict=True):
            self.assertEqual(row[:3],[0,1,ref])
            chosen=[spec["profiles"][i] for i in row[3:]]
            self.assertEqual(len(chosen),6)
            self.assertEqual({tuple(p["axis_body"]) for p in chosen},{tuple(a) for a in moment.AXES})
            self.assertEqual({p["handoff"]["schedule"] for p in chosen},set(search.RECIPE["schedules"]))
            self.assertEqual({p["handoff"]["steering_bias"] for p in chosen},set(search.RECIPE["steering_biases"]))
        for i in range(10,46):
            bodies=[b for b,row in enumerate(spec["profiles_by_body"]) if i in row]
            self.assertEqual((len(bodies),sum(b<12 for b in bodies)),(4,2))
        refs=search.references()
        self.assertEqual(refs[5]["reason"],"exposed_clear_prefix_only")
        self.assertEqual([r["body_index"] for r in refs if r["reason"].endswith("unexamined")],[3,21])

    def test_03_steering_rate_matches_independent_upright_derivative(self):
        rng=np.random.default_rng(1061137);p=search.proposals()[12]["handoff"]
        for _ in range(80):
            q=rng.normal(size=4);q/=np.linalg.norm(q)
            rotation=moment.mechanics.quaternion_rotation(q);omega=rng.normal(size=3)
            old=np.array(moment.AXES[_%4]);angular=dict(zip(("x","y","z"),omega,strict=True))
            axis,rate,available=subject.steering(rotation,angular,old,old,p)
            self.assertAlmostEqual(float(axis@axis),1.,places=14)
            self.assertLessEqual(math.acos(np.clip(old@axis,-1.,1.)),p["axis_slew_rad_per_step"]+1e-12)
            if available:
                sine=math.sqrt(max(0.,1.-rotation[1,1]**2))
                derivative=np.cross(omega,rotation[:,1])[1]
                self.assertAlmostEqual(rate*sine,float(derivative),places=12)

    def test_04_inverted_seed_and_bias_are_bounded_and_deterministic(self):
        zero=dict(x=0.,y=0.,z=0.);seed=np.array([1.,0.,0.]);rotation=np.diag([1.,-1.,-1.])
        p=search.proposals()[0]["handoff"]
        axis,rate,available=subject.steering(rotation,zero,seed,seed,p)
        np.testing.assert_array_equal(axis,seed);self.assertFalse(available);self.assertEqual(rate,0.)
        rotation=moment.mechanics.quaternion_rotation([math.sin(.6),0.,0.,math.cos(.6)])
        targets=[]
        for bias in (-.65,.65):
            policy=dict(p,steering_bias=bias);axis=seed.copy()
            for _ in range(80):axis,_,available=subject.steering(rotation,zero,seed,axis,policy)
            self.assertTrue(available);targets.append(axis)
        self.assertAlmostEqual(targets[0][0],targets[1][0],places=12)
        self.assertAlmostEqual(targets[0][2],-targets[1][2],places=12)
        self.assertGreater(abs(targets[0][2]),.4)

    def test_05_clock_releases_for_exact_duration_then_reacquires(self):
        cell,row=self.cell(4)
        h=cell.candidate["handoff"]
        cell.moment_state=self.memory(cell,elapsed=h["maximum_push_steps"]-1)
        d=self.decision(cell,row);self.assertEqual(d["handoff"]["phase"],"push")
        cell.moment_state=d["state_after"]
        for i in range(h["release_steps"]):
            d=self.decision(cell,row)
            self.assertEqual(d["handoff"]["phase"],"release")
            self.assertEqual((d["active_limbs"],d["requested_wrenches"],d["normalized_targets"]),([],[],[0.]*8))
            self.assertEqual(d["handoff"]["reason"],"bounded_release" if i==0 else "continue")
            cell.moment_state=d["state_after"]
        d=self.decision(cell,row)
        self.assertEqual(d["handoff"]["reason"],"reacquire")
        self.assertIsNotNone(d["state_after"]["inner"]["target"])
        self.assertEqual(d["state_after"]["cycles"],1)

    def test_06_stall_requires_measured_contact_hold_and_consecutive_low_rate(self):
        cell,row=self.cell(8);h=cell.candidate["handoff"]
        cell.moment_state=self.memory(cell,elapsed=h["minimum_push_steps"],stall_count=h["stall_steps"]-1)
        d=self.decision(cell,row)
        self.assertEqual(d["handoff"]["phase"],"push");self.assertEqual(d["state_after"]["stall_count"],0)
        row["state"]["ordered_contact_observations"][0].update(presence=True,bears_support=True)
        cell.moment_state["elapsed"]-=1
        self.assertEqual(self.decision(cell,row)["handoff"]["phase"],"push")
        cell.moment_state["elapsed"]+=1
        self.assertEqual(self.decision(cell,row)["handoff"]["reason"],"measured_stall_release")
        row["state"]["base_twist_world"]["angular_velocity_rad_s"]["x"]=1.
        self.assertEqual(self.decision(cell,row)["state_after"]["stall_count"],0)
        row["state"]["ordered_contact_observations"][0].update(presence=False,bears_support=False)
        cell.moment_state["elapsed"]=h["maximum_push_steps"]
        self.assertEqual(self.decision(cell,row)["handoff"]["reason"],"bounded_release")
        cell.candidate["handoff"]["schedule"]="continuous"
        self.assertEqual(self.decision(cell,row)["handoff"]["phase"],"push")

    def test_07_upright_resets_direction_and_release_without_requested_load(self):
        cell,row=self.cell(8);cell.moment_state=self.memory(cell,phase="release",elapsed=9,stall_count=3)
        row["state"]["base_pose_world"].update(orientation_xyzw=dict(x=0.,y=0.,z=0.,w=1.),position_m=dict(x=0.,y=1.,z=0.))
        for contact in row["state"]["ordered_contact_observations"]:contact.update(presence=True,bears_support=True)
        d=self.decision(cell,row)
        self.assertEqual(d["handoff"]["reason"],"upright_reset")
        self.assertEqual((d["phase"],d["active_limbs"],d["requested_wrenches"]),("upright_stance",[],[]))
        self.assertEqual((d["state_after"]["elapsed"],d["state_after"]["stall_count"]),(0,0))
        self.assertIsNone(d["state_after"]["inner"]["target"])
        self.assertEqual(d["state_after"]["axis_body"],cell.candidate["axis_body"])

    def test_08_planning_is_pure_and_batch_rejection_preserves_all_memory(self):
        cell,row=self.cell(8);first=cell.plan(row)
        self.assertEqual(first,cell.plan(row));self.assertIsNone(cell.moment_state)
        cell.commit(first);self.assertEqual(cell.step_index,1)
        self.assertEqual(cell.moment_state,first["resolution"]["body_moment"]["state_after"])
        with self.assertRaises(ValueError):cell.plan(row)
        spec=copy.deepcopy(self.spec);spec["profiles"]=spec["profiles"][:4]
        batch=righting.RightingBatch(self.core,righting.expand(spec)["cells"],seed=1);self.addCleanup(batch.close)
        rows=[observation(c,fixture(c.creature,self.template),0) for c in batch.controllers]
        rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]=math.nan
        with self.assertRaises(ValueError):batch.step(rows)
        self.assertTrue(all(c.step_index==0 and c.moment_state is None and c.previous==[0.]*8 for c in batch.controllers))

    def test_09_release_keeps_speed_slew_joint_guards_and_post_guard_torque(self):
        cell,row=self.cell(4);cell.moment_state=self.memory(cell,phase="release")
        for j in row["state"]["ordered_joint_observations"]:j.update(position_rad=.05,velocity_rad_s=0.)
        record=cell.plan(row);d=record["resolution"]["body_moment"]
        self.assertEqual(record["resolution"]["phase"],"contact_release")
        self.assertTrue(all(-.2<=v<0 for v in record["native_targets"]))
        self.assertEqual(d["requested_wrenches"],[]);self.assertIsNone(d["force_projection"])
        for j,spec in zip(row["state"]["ordered_joint_observations"],cell.spec["joints"],strict=True):
            j.update(position_rad=spec["upper_limit_rad"]+.01,velocity_rad_s=1.)
        cell.previous=[.2]*8;record=cell.plan(row)
        self.assertTrue(all(record["resolution"]["observed_joint_limit_breaches"]))
        self.assertTrue(all(-3.5<=v<=0. for v in record["native_targets"]))
        predicted=moment.mechanics.motor_torque(record["native_targets"],[1.]*8,
            cell.creature["spec"]["velocity_gains"],cell.creature["spec"]["force_ranges"])
        np.testing.assert_array_equal(record["resolution"]["body_moment"]["post_guard_predicted_torque_nm"],predicted)

    def test_10_legacy_plans_remain_exact_against_published_source(self):
        raw=subprocess.check_output(["git","show","a4907a1e3e571e8d0a55ac29546c9d8ae984df82:sdk/discovery/creature_body_moment.py"],cwd=search.ROOT)
        legacy=types.ModuleType("frozen_moment");exec(compile(raw,"frozen_moment","exec"),legacy.__dict__)
        for index in (0,4,12,16,20,23):
            cell,row=self.cell(profile=search.parent.proposals()[index])
            for step in range(8):
                row["state"].update(semantic_step=step,sample_time_s=step*bridge.CONTROLLER_DT_S)
                for c in row["state"]["ordered_contact_observations"]:c.update(presence=bool(step%2),bears_support=bool(step%2))
                current=cell.plan(row)
                with patch.object(moment,"plan",legacy.plan):old=cell.plan(row)
                self.assertEqual(current,old);cell.commit(current)

    def test_11_progress_compares_fresh_reference_and_preserves_old_scores(self):
        spec=copy.deepcopy(self.spec);spec["profiles"]=spec["profiles"][:5]
        c=dict(mode="development_discovery",righting_spec=spec,trajectory_screen=trajectory.POLICY,
               moment_handoff_search=search.RECIPE,trajectory_reference_by_body=[2],outer_steps=1,**righting.expand(spec))
        metrics=[dict(righting.initial_metrics(),**trajectory.initial_metrics()) for _ in c["cells"]]
        for m,angle in zip(metrics,(0.,14.,30.,34.,36.),strict=True):
            m.update(trajectory_samples=5,trajectory_maximum_up_dot=-math.cos(math.radians(angle)))
        result=trajectory.assess(c,metrics);group=result["groups"][0]
        self.assertEqual([r["candidate_index"] for r in group["progress_leads"]],[4])
        self.assertEqual(group["reference_candidate_index"],2)
        self.assertAlmostEqual(group["observations"][3]["peak_gain_against_timed_degrees"],20.)
        self.assertAlmostEqual(group["observations"][3]["peak_gain_against_reference_degrees"],4.)
        metrics[4]["joint_limit_violation_steps"]=1
        self.assertEqual(trajectory.assess(c,metrics)["progress_lead_count"],0)
        c.pop("trajectory_reference_by_body");c.pop("moment_handoff_search")
        raw=subprocess.check_output(["git","show","a4907a1e3e571e8d0a55ac29546c9d8ae984df82:sdk/discovery/creature_trajectory_search.py"],cwd=search.ROOT)
        old=types.ModuleType("frozen_trajectory");exec(compile(raw,"frozen_trajectory","exec"),old.__dict__)
        self.assertEqual(trajectory.assess(c,metrics),old.assess(c,metrics))

    def test_12_route_requires_steering_release_reacquire_stall_deadline_and_force(self):
        folder=self.root/"route";stream=folder/"native/batch_0/controller.jsonl";stream.parent.mkdir(parents=True)
        rows=[]
        for reason,phase in (("measured_stall_release","release"),("bounded_release","release"),("reacquire","push")):
            rows.append(dict(resolution=dict(body_moment=dict(handoff=dict(reason=reason,phase=phase,
                upright_steering_available=True),active_limbs=[0] if phase=="push" else [],
                requested_wrenches=[dict(force=[0.,1.,0.])] if phase=="push" else [],
                state_after=dict(inner=dict(target=None))))))
        receipt=dict(contract=dict(mode="route_ghost"),audit=dict(batches=[dict(batch_id="batch_0")],
            capture=dict(controller_replay_verified=True,within_run_projection_verified=True)))
        def write(values):stream.write_bytes((''.join(json.dumps(r)+'\n' for r in values)).encode())
        write(rows);self.assertTrue(search.verify_route(folder,receipt)["complete"])
        for omitted in range(3):
            write(rows[:omitted]+rows[omitted+1:])
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        for mutate in (lambda d:d["handoff"].update(upright_steering_available=False),
                       lambda d:d.update(active_limbs=[]),
                       lambda d:d["state_after"]["inner"].update(target=dict(target_nonadjacent_gap_m=-.001))):
            broken=copy.deepcopy(rows)
            for r in broken:mutate(r["resolution"]["body_moment"])
            write(broken)
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        broken=copy.deepcopy(rows);broken[0]["resolution"]["body_moment"]["active_limbs"]=[0];write(broken)
        with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        write(rows)
        receipt["artifacts"]=[dict(path="native/batch_0/controller.jsonl",bytes=stream.stat().st_size,sha256="0"*64)]
        with self.assertRaises(ValueError):search.verify_route(folder,receipt)

    def test_13_declarations_bind_complete_gate_references_and_source_inputs(self):
        for name,count in (("creature_moment_handoff_route_v1.json",12),("creature_moment_handoff_v1.json",216)):
            path=search.ROOT/"sdk/discovery"/name;c=native.declaration(path)
            self.assertEqual(len(c["cells"]),count);self.assertEqual(sum(v[2] for v in native.gates(c)),248)
            paths={p.relative_to(search.ROOT).as_posix() for p in owner.source_paths(path,c)}
            self.assertTrue({"sdk/discovery/"+n for n in search.SOURCES}<=paths)
            self.assertTrue({"sdk/discovery/"+n for n in ("test_creature_moment_handoff.py","test_creature_body_moment.py",
                "creature_moment_handoff.py","creature_moment_handoff_search.py","creature_body_moment_diagnosis.py")}<=paths)
            for change in (lambda v:v.pop("moment_handoff_search"),lambda v:v.update(outer_steps=1),
                lambda v:v["trajectory_reference_by_body"].__setitem__(0,True),
                lambda v:v["reference_selection"][0].update(reason="unexposed"),
                lambda v:v["post_native_path_screen"].update(required_before_lead_promotion=False)):
                broken=copy.deepcopy(c);change(broken)
                with self.assertRaises((ValueError,KeyError)):search.validate(broken)
            self.assertTrue(native.work_enabled(c))

    def test_14_clearance_uses_fresh_reference_and_accepts_empty_shortlist(self):
        episodes=[dict(cell_id=f"cell_{i}",candidate_id=f"profile_{i}",candidate_index=i,
                       metrics=dict(trajectory_samples=5)) for i in range(4)]
        observations=[dict(e,peak_rotation_degrees=50.) for e in episodes]
        group=dict(reference_candidate_index=2,observations=observations,progress_leads=[observations[3]])
        receipt=dict(source_commit="fixture",contract=dict(capture_mode="compact_v1",outer_steps=1),
            audit=dict(trajectory_screen=dict(groups=[group]),assessment=dict(episodes=episodes)),
            worker=dict(groups=[dict(batch_id="batch_0",cell_indices=list(range(4)))]))
        def qpos(degrees):
            angle=math.radians(180-degrees)/2
            return [0.,0.,.1,math.cos(angle),math.sin(angle),0.,0.]+[0.]*8
        rows=[dict(cell=i,outer_step=0,binding=episodes[i],prepared_qpos=qpos(0.),prepared_time_s=0.,
                   safe_no_actuation=False,samples=[dict(qpos=qpos(10*k),time_s=k/600) for k in range(1,6)]) for i in range(4)]
        archive=types.SimpleNamespace(verified={},document=lambda _:None,lines=lambda _:iter(json.dumps(r) for r in rows))
        geometry=types.SimpleNamespace(tree=types.SimpleNamespace(kinematics=lambda p,r,q:q),measured=lambda _:(None,.01))
        with patch.object(diagnosis,"bound_archive",return_value=(archive,receipt)),patch.object(moment,"Geometry",return_value=geometry):
            result=diagnosis.diagnose_clearance(self.root,"fixture")
            self.assertEqual([r["role"] for r in result["outcomes"]],["reference_comparator","raw_progress_lead"])
            self.assertEqual((result["native_samples"],result["initial_states"]),(10,2))
            group["reference_candidate_index"]=9
            with self.assertRaises(ValueError):diagnosis.diagnose_clearance(self.root,"fixture")
            group["progress_leads"]=[]
            result=diagnosis.diagnose_clearance(self.root,"fixture")
            self.assertEqual((result["outcomes"],result["native_samples"],result["initial_states"]),([],0,0))


if __name__=="__main__":unittest.main()
