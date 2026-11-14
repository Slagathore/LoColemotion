"""Support continuity, exact reference behavior, hinge geometry and atomic state."""
import copy
from contextlib import ExitStack
import hashlib
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_body_moment as moment
import creature_body_moment_search as parent
import creature_righting as righting
import creature_support_exchange as exchange
import creature_support_exchange_search as search
import creature_native as native
import creature_trajectory_search as trajectory
import run_creature_native as owner
from creature_batch import bridge
from test_creature_batch import fixture, observation
from test_portable_search import _fixture


class SupportExchangeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template = _fixture(cls.core)["provider_request"]["state"]
        cls.descriptor = parent.spec(parent.RECIPE)["descriptors"][16]
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-support-exchange"
        cls.root.mkdir()

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in exchange controls")))

    def profile(self, *, rock=False):
        p=copy.deepcopy(parent.proposals()[20 if rock else 16])
        p.update(id="exchange_fixture",support_exchange=copy.deepcopy(exchange.DEFAULT_POLICY))
        return p

    def cell(self, *, rock=False, plain=False, warmup=120):
        p=self.profile(rock=rock)
        p["support_exchange"]["minimum_reference_steps"]=warmup
        if plain:p.pop("support_exchange")
        cell=righting.RightingController(self.core,dict(cell_id="exchange_control",descriptor=self.descriptor,
            profile=p,motor_effectiveness=[1.]*8),seed=1)
        self.addCleanup(cell.close)
        row=observation(cell,fixture(cell.creature,self.template),0)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
        row["state"]["base_pose_world"]["position_m"]["y"]=float(righting.initial_arrays([cell.creature],[math.pi])[0][0,2])
        for i,c in enumerate(row["state"]["ordered_contact_observations"]):c.update(presence=i==1,bears_support=i==1)
        return cell,row

    def seek(self, cell, *, phase="seek", elapsed=0, dwell=0):
        state=exchange.initial(0.)
        state.update(phase=phase,elapsed=elapsed,support_limbs=[1],replacement_limb=3,
            hold_positions_rad=[.3]*8,axis_body=[1.,0.,0.],contact_count=dwell,cycles=1,
            target=dict(joint_targets_rad=[-.7,-.4],endpoint_nonadjacent_gap_m=.1))
        cell.moment_state=state

    def test_01_policy_bounds_and_combined_modes_are_refused(self):
        for key,value in (("stall_steps",True),("target_joint_margin_rad",.001),
                ("target_floor_height_m",-.1),("mass_shift_weight",math.nan),("limb_relation","oracle")):
            p=self.profile();p["support_exchange"][key]=value
            with self.assertRaises(ValueError):moment.profile(p)
        p=self.profile();p["handoff"]={}
        with self.assertRaises(ValueError):moment.profile(p)
        p=self.profile();p["joint_braking"]["margin_rad"]=.08
        with self.assertRaises(ValueError):moment.profile(p)

    def test_02_drive_and_rock_references_remain_exact_before_trigger(self):
        for rock in (False,True):
            a,row=self.cell(rock=rock,warmup=240);b,_=self.cell(rock=rock,plain=True)
            for step in range(200):
                row["state"]["semantic_step"]=step;row["state"]["sample_time_s"]=step*bridge.CONTROLLER_DT_S
                new,old=a.step(row),b.step(row)
                self.assertEqual(new["native_targets"],old["native_targets"])
                self.assertEqual(new["resolution"]["ordered_commands"],old["resolution"]["ordered_commands"])
                for key in ("normalized_targets","requested_wrenches","force_projection"):
                    self.assertEqual(new["resolution"]["body_moment"][key],old["resolution"]["body_moment"][key])

    def test_03_replacement_selection_uses_only_unloaded_limbs(self):
        contacts=[dict(presence=i==1) for i in range(4)]
        for relation,expected in (("opposite_side",0),("other_end",3),("diagonal",2)):
            self.assertEqual(exchange.replacement_limb([1],contacts,relation),expected)
        contacts[0]["presence"]=True
        self.assertEqual(exchange.replacement_limb([1],contacts,"opposite_side"),2)
        self.assertIsNone(exchange.replacement_limb([1],[dict(presence=True)]*4,"other_end"))

    def test_04_hinge_roots_match_independent_rotation_for_oblique_axis(self):
        axis=np.array([.3,.4,.5]);axis/=np.linalg.norm(axis)
        anchor=np.array([.1,.2,-.1]);point=np.array([.5,-.3,.2]);angle=.72
        height=(anchor+moment.mechanics.rotation(axis,angle) @ (point-anchor))[1]
        roots=exchange.hinge_height_roots(anchor,axis,point,float(height),-1.5,1.5)
        self.assertTrue(any(abs(r-angle)<1e-12 for r in roots))
        for r in roots:
            self.assertAlmostEqual((anchor+moment.mechanics.rotation(axis,r) @ (point-anchor))[1],height,places=12)
        self.assertEqual(exchange.hinge_height_roots(anchor,axis,point,100.,-1.5,1.5),[])

    def test_05_vertical_axis_continuum_and_bounds_are_explicit(self):
        a=np.zeros(3);axis=np.array([0.,1.,0.]);point=np.array([1.,.3,0.])
        self.assertEqual(exchange.hinge_height_roots(a,axis,point,.3,.1,.9),[.1])
        self.assertEqual(exchange.hinge_height_roots(a,axis,point,.4,-1.,1.),[])

    def test_06_target_search_keeps_measured_nonmoving_joints_unclipped(self):
        cell,row=self.cell();g=cell.moment_geometry;s=row["state"]
        s["ordered_joint_observations"][0]["position_rad"]=.97*g.upper[0]
        original=np.array([j["position_rad"] for j in s["ordered_joint_observations"]]);calls=[]
        real=g.tree.kinematics
        def observe(p,q,joints):
            calls.append(np.asarray(joints).copy());return real(p,q,joints)
        with patch.object(g.tree,"kinematics",side_effect=observe):
            exchange.replacement_target(g,s,np.diag([1.,-1.,-1.]),np.array([1.,0.,0.]),[1],3,cell.candidate)
        self.assertGreater(len(calls),1)
        for q in calls:np.testing.assert_array_equal(q[:6],original[:6])
        s["ordered_joint_observations"][0]["position_rad"]=g.upper[0]+.01
        self.assertIsNone(exchange.replacement_target(g,s,np.diag([1.,-1.,-1.]),np.array([1.,0.,0.]),[1],3,cell.candidate))

    def test_07_overlapping_endpoint_candidates_are_rejected(self):
        cell,row=self.cell();g=cell.moment_geometry;real=g.measured
        with patch.object(g,"measured",side_effect=lambda f:(real(f)[0],-.01)):
            self.assertIsNone(exchange.replacement_target(g,row["state"],np.diag([1.,-1.,-1.]),np.array([1.,0.,0.]),[1],3,cell.candidate))

    def test_08_plateau_requires_contact_and_reference_warmup(self):
        for contact,elapsed in ((False,200),(True,10)):
            cell,row=self.cell();cell.moment_state=exchange.initial(0.)
            cell.moment_state.update(elapsed=elapsed,stall_count=35)
            row["state"]["ordered_contact_observations"][1].update(presence=contact,bears_support=contact)
            d=cell.plan(row)["resolution"]["body_moment"]["support_exchange"]
            self.assertEqual(d["phase"],"reference")

    def test_09_measured_progress_resets_plateau_counter(self):
        cell,row=self.cell();cell.moment_state=exchange.initial(0.)
        cell.moment_state.update(elapsed=200,stall_count=35)
        angle=math.radians(170)/2
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(angle),y=0.,z=0.,w=math.cos(angle))
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_exchange"]["phase"],"reference")
        self.assertEqual(d["state_after"]["stall_count"],0)

    def test_10_seek_keeps_old_contact_and_does_not_release_early(self):
        cell,row=self.cell();self.seek(cell,elapsed=1)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_exchange"]["phase"],"seek")
        self.assertEqual(d["active_limbs"],[1])
        self.assertEqual(d["normalized_targets"][2:4],[.3/cell.moment_geometry.upper[2],.3/cell.moment_geometry.upper[3]])

    def test_11_transfer_requires_consecutive_measured_replacement_contact(self):
        cell,row=self.cell();self.seek(cell,elapsed=1,dwell=5)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["state_after"]["contact_count"],0)
        self.assertEqual(d["support_exchange"]["phase"],"seek")
        row["state"]["ordered_contact_observations"][3].update(presence=True,bears_support=True)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_exchange"]["reason"],"measured_replacement_contact")
        self.assertEqual(d["active_limbs"],[3])
        self.assertEqual(d["normalized_targets"][2:4],[0.,0.])
        self.assertTrue(all(d["normalized_targets"][i]!=0. for i in (0,1,4,5,6,7)))

    def test_12_lost_required_contact_and_timeout_restore_reference(self):
        for lost in (True,False):
            cell,row=self.cell();self.seek(cell,elapsed=180)
            if lost:row["state"]["ordered_contact_observations"][1].update(presence=False,bears_support=False)
            d=cell.plan(row)["resolution"]["body_moment"]
            self.assertEqual(d["support_exchange"]["phase"],"reference")
            self.assertEqual(d["support_exchange"]["reason"],"lost_required_contact" if lost else "replacement_timeout")
            self.assertEqual(d["state_after"]["cooldown"],60)

    def test_13_clearance_and_force_direction_failures_restore_reference(self):
        for method,reason in (("replacement_target","no_clear_replacement_pose"),
                              ("supported_proposal","unsupported_moment_direction")):
            cell,row=self.cell();self.seek(cell,elapsed=0 if method=="replacement_target" else 1)
            with patch.object(exchange,method,return_value=None):
                d=cell.plan(row)["resolution"]["body_moment"]
            self.assertEqual(d["support_exchange"]["phase"],"reference")
            self.assertEqual(d["support_exchange"]["reason"],reason)

    def test_14_transfer_is_bounded_and_upright_resets_exchange(self):
        cell,row=self.cell();self.seek(cell,phase="transfer",elapsed=36,dwell=6)
        row["state"]["ordered_contact_observations"][3].update(presence=True,bears_support=True)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_exchange"]["reason"],"transfer_complete")
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=0.,z=0.,w=1.)
        row["state"]["base_pose_world"]["position_m"]["y"]=1.
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_exchange"]["reason"],"upright_reset")
        self.assertEqual(d["active_limbs"],[])
        self.assertEqual(d["state_after"]["cycles"],0)

    def test_15_plans_are_pure_and_protection_still_overrides_slew(self):
        cell,row=self.cell();self.seek(cell,elapsed=1);before=copy.deepcopy(cell.moment_state)
        a=cell.plan(row);self.assertEqual(cell.plan(row),a);self.assertEqual(cell.moment_state,before)
        cell.previous=[.2]*8
        for j,spec in zip(row["state"]["ordered_joint_observations"],cell.spec["joints"]):
            j.update(position_rad=spec["upper_limit_rad"]+.01,velocity_rad_s=1.)
        d=cell.plan(row)
        self.assertTrue(all(d["resolution"]["observed_joint_limit_breaches"]))
        self.assertTrue(all(-3.5<=v<=0. for v in d["native_targets"]))

    def test_16_rejected_batch_does_not_commit_commands_or_exchange_memory(self):
        spec=search.spec(route=True);spec["profiles"]=spec["profiles"][:4]
        batch=righting.RightingBatch(self.core,righting.expand(spec)["cells"],seed=search.RECIPE["seed"])
        self.addCleanup(batch.close)
        rows=[observation(c,fixture(c.creature,self.template),0) for c in batch.controllers]
        rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]=math.nan
        with self.assertRaises(ValueError):batch.step(rows)
        self.assertTrue(all(c.step_index==0 and c.moment_state is None and c.previous==[0.]*8
                            for c in batch.controllers))

    def test_17_factorial_assignments_preserve_bodies_references_and_diversity(self):
        spec=search.spec();rows=search.assignments();recipes=search.recipes()
        self.assertEqual(spec["descriptors"],parent.spec(parent.RECIPE)["descriptors"])
        self.assertEqual((len(recipes),len(spec["profiles"]),len(righting.expand(spec)["cells"])),(18,58,216))
        old=parent.spec(parent.RECIPE)["profiles"]
        refs=search.parent.references()
        for body,indices in enumerate(rows):
            self.assertEqual(len(indices),6);self.assertEqual(len(set(indices)),6)
            for field,values in (("limb_relation",search.RECIPE["limb_relations"]),
                                 ("mass_shift_weight",search.RECIPE["mass_shift_weights"]),
                                 ("stall_steps",search.RECIPE["stall_steps"])):
                self.assertEqual([sum(recipes[i][field]==v for i in indices) for v in values],[6//len(values)]*len(values))
            assigned=spec["profiles_by_body"][body]
            self.assertEqual(assigned[:2],[0,1])
            self.assertEqual(spec["profiles"][assigned[2]],old[refs[body]["candidate_index"]])
            for i,index in zip(indices,assigned[3:],strict=True):
                self.assertEqual(spec["profiles"][index],search.proposal(old[refs[body]["candidate_index"]],i))
        for recipe in range(18):
            self.assertEqual([sum(recipe in row for row in rows[start:start+12]) for start in (0,12)],[4,4])
        self.assertEqual({i for row in spec["profiles_by_body"] for i in row},set(range(len(spec["profiles"]))))

    def test_18_declarations_bind_complete_gate_and_refuse_population_drift(self):
        for name,count in (("creature_support_exchange_route_v1.json",12),("creature_support_exchange_v1.json",216)):
            path=search.ROOT/"sdk/discovery"/name;c=native.declaration(path)
            self.assertEqual(len(c["cells"]),count);self.assertEqual(sum(n for _,_,n in native.gates(c)),254)
            paths={p.relative_to(search.ROOT).as_posix() for p in owner.source_paths(path,c)}
            self.assertTrue({"sdk/discovery/"+n for n in search.SOURCES}<=paths)
            self.assertTrue({"sdk/discovery/"+n for n in ("creature_support_exchange.py",
                "creature_support_exchange_search.py","test_creature_support_exchange.py",
                "creature_support_exchange_route_v1.json","creature_support_exchange_v1.json")}<=paths)
            self.assertTrue(native.work_enabled(c))
            for change in (lambda v:v.pop("support_exchange_search"),
                lambda v:v.update(outer_steps=1),
                lambda v:v["trajectory_reference_by_body"].__setitem__(0,True),
                lambda v:v["reference_selection"][0].update(reason="unexposed"),
                lambda v:v["post_native_path_screen"].update(required_before_lead_promotion=False),
                lambda v:v["righting_spec"]["profiles"][-1]["support_exchange"].update(stall_steps=24)):
                broken=copy.deepcopy(c);change(broken)
                with self.assertRaises((ValueError,KeyError)):search.validate(broken)

    def test_19_full_route_requires_retained_support_measured_transfer_and_fallback(self):
        cell,row=self.cell();self.seek(cell,elapsed=1)
        seek=copy.deepcopy(cell.plan(row))
        self.seek(cell,elapsed=1,dwell=5)
        row["state"]["ordered_contact_observations"][3].update(presence=True,bears_support=True)
        transfer=copy.deepcopy(cell.plan(row))
        self.seek(cell,elapsed=180)
        row["state"]["ordered_contact_observations"][3].update(presence=False,bears_support=False)
        fallback=copy.deepcopy(cell.plan(row))
        rows=[seek,transfer,fallback]
        folder=self.root/"route";stream=folder/"native/batch_0/controller.jsonl"
        stream.parent.mkdir(parents=True)
        receipt=dict(contract=dict(mode="route_ghost",support_exchange_search=search.RECIPE),
            audit=dict(batches=[dict(batch_id="batch_0")],
                capture=dict(controller_replay_verified=True,within_run_projection_verified=True)))
        def write(values):stream.write_bytes(("".join(json.dumps(r)+"\n" for r in values)).encode())
        write(rows);self.assertTrue(search.verify_route(folder,receipt)["complete"])
        for omitted in range(3):
            write(rows[:omitted]+rows[omitted+1:])
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        for change in (lambda v:v[0]["resolution"]["body_moment"].update(active_limbs=[]),
            lambda v:v[0]["request"]["state"]["ordered_contact_observations"][1].update(presence=False),
            lambda v:v[1]["resolution"]["body_moment"]["state_after"].update(contact_count=2),
            lambda v:v[0]["resolution"]["body_moment"]["state_after"]["target"].update(endpoint_nonadjacent_gap_m=-.01),
            lambda v:v[2]["resolution"]["body_moment"]["state_after"].update(cooldown=0)):
            broken=copy.deepcopy(rows);change(broken);write(broken)
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        write(rows)
        receipt["artifacts"]=[dict(path="native/batch_0/controller.jsonl",bytes=stream.stat().st_size,sha256="0"*64)]
        with self.assertRaises(ValueError):search.verify_route(folder,receipt)

    def test_20_screen_uses_fresh_reference_gain_and_limb_family_diversity(self):
        spec=search.spec(route=True)
        # Two proposals from one limb family plus one from a different family.
        reference=spec["profiles"][2]
        spec["profiles"]=spec["profiles"][:3]+[search.proposal(reference,i) for i in (0,3,1)]
        c=dict(mode="development_discovery",righting_spec=spec,trajectory_screen=trajectory.POLICY,
            support_exchange_search=search.RECIPE,trajectory_reference_by_body=[2],outer_steps=1,
            **righting.expand(spec))
        metrics=[dict(righting.initial_metrics(),**trajectory.initial_metrics()) for _ in c["cells"]]
        for m,angle in zip(metrics,(0.,14.,30.,38.,37.,36.),strict=True):
            m.update(trajectory_samples=5,trajectory_maximum_up_dot=-math.cos(math.radians(angle)))
        group=trajectory.assess(c,metrics)["groups"][0]
        self.assertEqual([r["candidate_index"] for r in group["progress_leads"]],[3,5])
        self.assertEqual(group["reference_candidate_index"],2)
        self.assertAlmostEqual(group["observations"][4]["peak_gain_against_timed_degrees"],23.)
        self.assertAlmostEqual(group["observations"][4]["peak_gain_against_reference_degrees"],7.)
        metrics[3]["joint_limit_violation_steps"]=1
        self.assertEqual([r["candidate_index"] for r in trajectory.assess(c,metrics)["groups"][0]["progress_leads"]],[4,5])
        metrics[4]["trajectory_maximum_up_dot"]=-math.cos(math.radians(34.))
        self.assertEqual([r["candidate_index"] for r in trajectory.assess(c,metrics)["groups"][0]["progress_leads"]],[5])


if __name__ == "__main__":
    unittest.main()
