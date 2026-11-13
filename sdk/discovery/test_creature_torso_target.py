"""Analytic virtual poses, contact-gated projection, legacy replay and population controls."""
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import types
import unittest

import numpy as np
import creature_contact_reach as contact
import creature_native as native
import creature_righting as righting
import creature_torso_target as subject
import creature_torso_target_search as search
import run_creature_native as owner
from actuation_recovery_mechanics import quaternion_rotation, xyz
from creature_batch import bridge
from gpu_quadruped_model import sha
import test_creature_contact_reach as base
import test_creature_righting as existing
from test_portable_search import _fixture


class TorsoTargetControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.core=bridge.LocomotionCore(cls.core_path)
        cls.template=_fixture(cls.core)["provider_request"]["state"]
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-torso-target";cls.root.mkdir()

    setUp=base.ContactReachControls.setUp
    batch=base.ContactReachControls.batch
    observations=base.ContactReachControls.observations

    def candidate(self,pivot="root"):
        return next(p for p in search.spec(search.RECIPE)["profiles"]
                    if p.get("torso_target",{}).get("pivot")==pivot)

    def case(self,pivot="root"):
        cell=self.batch([self.candidate(pivot)]).controllers[-1]
        state=self.observations(types.SimpleNamespace(controllers=[cell]))[0]["state"]
        return cell,state,quaternion_rotation([1.,0.,0.,0.])

    def test_01_policy_bounds_aliases_and_strategy_scope(self):
        p=self.candidate()
        for key,value in (("pivot","foot"),("maximum_rotation_rad",0.),("maximum_rotation_rad",math.pi/3+.001),
                          ("maximum_rotation_rad",True),("ramp_steps",11),("ramp_steps",True),
                          ("rise_m",-.001),("rise_m",math.inf),("rise_m",.041)):
            bad=copy.deepcopy(p);bad["torso_target"][key]=value
            with self.assertRaises(ValueError):righting.profile(bad)
        bad=copy.deepcopy(p);bad["strategy"]="ground"
        with self.assertRaises(ValueError):righting.profile(bad)
        self.assertEqual(righting.behavior_key(p),righting.behavior_key(dict(p,id="alias")))
        self.assertNotEqual(righting.behavior_key(p),righting.behavior_key(self.candidate("torso_edge")))

    def test_02_analytic_rotation_ramp_and_box_clearance(self):
        config=dict(self.candidate()["torso_target"],maximum_rotation_rad=math.pi/6,ramp_steps=60,rise_m=.02)
        position=np.array([.2,.065,-.1]);rotation=quaternion_rotation([1.,0.,0.,0.]);size=[.45,.12,.352]
        f=subject.frame(position,rotation,[1.,0.,0.],[[.2,.036,-.3]],60,config,size)
        expected=quaternion_rotation([math.sin((math.pi+math.pi/6)/2),0.,0.,math.cos((math.pi+math.pi/6)/2)])
        np.testing.assert_allclose(f["rotation_matrix"],expected,rtol=0.,atol=1e-12)
        self.assertAlmostEqual(f["position_m"][1],max(.085,.06*math.cos(math.pi/6)+.176*math.sin(math.pi/6)),places=12)
        self.assertAlmostEqual(f["applied_rotation_rad"],math.pi/6,places=12)
        half=subject.frame(position,rotation,[1.,0.,0.],[[.2,.036,-.3]],30,config,size)
        self.assertAlmostEqual(half["applied_rotation_rad"],math.pi/12,places=12)
        self.assertGreaterEqual(f["virtual_torso_minimum_height_m"],-1e-12)
        near=quaternion_rotation([math.sin(-.1/2),0.,0.,math.cos(-.1/2)])
        end=subject.frame(position,near,[1.,0.,0.],[[.2,.036,-.3]],60,config,size)
        self.assertAlmostEqual(end["applied_rotation_rad"],.1,places=12)
        self.assertAlmostEqual(end["virtual_up_dot"],1.,places=12)

    def test_03_edge_pivot_and_yaw_covariance(self):
        config=dict(self.candidate("torso_edge")["torso_target"],maximum_rotation_rad=math.pi/6,rise_m=0.)
        position=np.array([.2,.065,-.1]);rotation=quaternion_rotation([1.,0.,0.,0.]);size=np.array([.45,.12,.352])
        anchor=[.2,.036,-.3]
        f=subject.frame(position,rotation,[1.,0.,0.],[anchor],120,config,size)
        self.assertAlmostEqual(f["pivot_world_m"][1],.005,places=12)
        self.assertAlmostEqual(f["pivot_world_m"][2],.076,places=12)
        self.assertAlmostEqual(f["position_m"][1],.005+.06*math.cos(math.pi/6)+.176*math.sin(math.pi/6),places=12)
        yaw=quaternion_rotation([0.,math.sin(.73/2),0.,math.cos(.73/2)])
        turned=subject.frame(yaw @ position,yaw @ rotation,[1.,0.,0.],[yaw @ np.asarray(anchor)],120,config,size)
        np.testing.assert_allclose(turned["position_m"],yaw @ np.asarray(f["position_m"]),rtol=0.,atol=1e-12)
        np.testing.assert_allclose(turned["rotation_matrix"],yaw @ np.asarray(f["rotation_matrix"]),rtol=0.,atol=1e-12)

    def test_04_virtual_and_actual_projection_are_separate_and_legal(self):
        cell,state,rotation=self.case();g=cell.contact_geometry;p=cell.candidate
        contacts=state["ordered_contact_observations"]
        first=contact.plan(p,g,state,rotation,contacts,None,False);memory=first["state_after"]
        for i in memory["active_limbs"]:contacts[i].update(presence=True,bears_support=True)
        d=contact.plan(p,g,state,rotation,contacts,memory,False);memory=d["state_after"];memory["elapsed"]=60
        d=contact.plan(p,g,state,rotation,contacts,memory,False)
        changed=False
        for i in memory["active_limbs"]:
            choice=d["state_after"]["choices"][i];projection=choice["torso_target_projection"]
            self.assertTrue(projection["active"]);self.assertFalse(projection["virtual_frame"]["root_is_actuated_or_teleported"])
            self.assertTrue(all(abs(v)<=.9 for v in choice["normalized_pose"]))
            actual=g.candidates(i,xyz(state["base_pose_world"]["position_m"]),rotation)[choice["grid_index"]]
            np.testing.assert_allclose(projection["actual_root_geometric_low_endpoint_world_m"],actual,rtol=0.,atol=1e-12)
            f=projection["virtual_frame"]
            virtual=g.candidates(i,np.asarray(f["position_m"]),np.asarray(f["rotation_matrix"]))[choice["grid_index"]]
            np.testing.assert_allclose(choice["geometric_low_endpoint_world_m"],virtual,rtol=0.,atol=1e-12)
            changed |= float(np.linalg.norm(actual-virtual))>.001
        self.assertTrue(changed)

    def test_05_measured_contact_required_and_loss_disables_virtual_target(self):
        cell,state,rotation=self.case();g=cell.contact_geometry;p=cell.candidate
        contacts=state["ordered_contact_observations"]
        first=contact.plan(p,g,state,rotation,contacts,None,False)
        self.assertTrue(all(not c["torso_target_projection"]["active"] for c in first["state_after"]["choices"] if c))
        memory=first["state_after"];limb=memory["active_limbs"][0]
        contacts[limb].update(presence=True,bears_support=True)
        d=contact.plan(p,g,state,rotation,contacts,memory,False);memory=d["state_after"]
        anchor=copy.deepcopy(memory["anchors"][limb]);memory["elapsed"]=6
        contacts[limb].update(presence=False,bears_support=False)
        before=copy.deepcopy((state,memory))
        d=contact.plan(p,g,state,rotation,contacts,memory,False)
        self.assertFalse(d["state_after"]["choices"][limb]["torso_target_projection"]["active"])
        self.assertEqual(d["state_after"]["anchors"][limb],anchor)
        self.assertEqual((state,memory),before)

    def test_06_bad_frames_and_late_observations_do_not_commit(self):
        c=self.candidate()["torso_target"]
        for rotation,anchors,elapsed in ((np.eye(3)*2,[[0.,0.,0.]],60),(np.eye(3),[[0.,math.nan,0.]],60),
                                        (np.eye(3),[],60),(np.eye(3),[[0.,0.,0.]],True)):
            with self.assertRaises(ValueError):subject.frame(np.zeros(3),rotation,[1.,0.,0.],anchors,elapsed,c,[.45,.12,.352])
        batch=self.batch([self.candidate(),self.candidate("torso_edge")])
        obs=self.observations(batch);obs[-1]["state"]["ordered_joint_observations"][-1]["velocity_rad_s"]=math.nan
        with self.assertRaises(ValueError):batch.step(obs)
        self.assertTrue(all(x.step_index==0 and x.contact_state is None and x.previous==[0.]*8 for x in batch.controllers))
        rows=batch.step(self.observations(batch))
        rows[-1]["resolution"]["contact_reach"]["state_after"]["targets"][0]=999.
        self.assertNotEqual(batch.controllers[-1].contact_state["targets"][0],999.)

    def test_07_frozen_pairing_keeps_old_profiles_and_all_body_assignments(self):
        spec=search.spec(search.RECIPE);original=search.source();rows=spec["profiles_by_body"]
        self.assertEqual(len(righting.expand(spec)["cells"]),224)
        self.assertEqual(len(spec["profiles"]),50);self.assertEqual([len(r) for r in rows],[14]*16)
        old_by_id={p["id"]:p for p in original["profiles"]}
        for i in range(2,50,3):
            base_profile=spec["profiles"][i]
            self.assertEqual(base_profile,old_by_id[base_profile["id"]])
            for j in (i+1,i+2):
                new=spec["profiles"][j]
                self.assertEqual({k:v for k,v in new.items() if k not in ("id","torso_target")},
                                 {k:v for k,v in base_profile.items() if k!="id"})
                self.assertEqual([b for b,r in enumerate(rows) if j in r],[b for b,r in enumerate(rows) if i in r])
            self.assertEqual(sum(i in r for r in rows),4)
        self.assertEqual(len({righting.behavior_key(p) for p in spec["profiles"]}),50)

    def test_08_actual_declarations_and_complete_source_inventory_refuse_drift(self):
        expected={native.HERE/n for n in ("creature_trajectory_search_v1.json","creature_trajectory_retiming_v1.json",
            "creature_joint_braking_v1.json","creature_joint_braking_route_v1.json","creature_contact_reach_v1.json",
            "creature_contact_reach_route_v1.json","creature_torso_target_v1.json","creature_torso_target_route_v1.json")}
        for name,n,b in (("creature_torso_target_route_v1.json",14,1),("creature_torso_target_v1.json",224,16)):
            path=native.HERE/name;c=native.declaration(path);pre=native.preflight(c,self.core_path)
            self.assertEqual((pre["world_build_count"],pre["solver_steps"]),(0,0))
            self.assertEqual((pre["planned_gpu_worlds"],pre["distinct_body_shapes"]),(n,b))
            paths=owner.source_paths(path,c);self.assertTrue(expected<=set(paths));self.assertEqual(len(paths),len(set(paths)))
            self.assertEqual(sum(k for _,_,k in native.gates(c)),182)
        for change in (lambda x:x["righting_spec"]["profiles"][3]["torso_target"].update(rise_m=.03),
                       lambda x:x.update(seed=1),lambda x:x.update(outer_steps=720),lambda x:x.pop("torso_target_search")):
            bad=copy.deepcopy(c);change(bad)
            with self.assertRaises(ValueError):search.validate(bad)
        self.assertEqual(c["righting_selection"],righting.SELECTION)

    def test_09_full_reader_replays_new_profile_and_refuses_forged_projection(self):
        folder,c,creatures,metas,controls,trace,result=existing.RightingControls._reader_case(
            self,False,sequence_profile=self.candidate(),fixture_only=True)
        report=native.audit_batch(folder,c,self.core_path,synthetic=True)
        self.assertEqual((report["controller_rows_replayed"],report["native_rows_verified"]),(132,660))
        with self.assertRaises(ValueError):search.route_report(controls,c["righting_spec"]["profiles"])
        changed=copy.deepcopy(controls)
        choice=next(x for x in changed[1]["resolution"]["contact_reach"]["state_after"]["choices"] if x)
        choice["torso_target_projection"]["active"]=True
        (folder/"controller.jsonl").write_text("".join(json.dumps(x)+"\n" for x in changed),encoding="utf-8")
        result["stream_sha256"]["controller"]=sha(folder/"controller.jsonl")
        (folder/"worker-result.json").write_text(json.dumps(result),encoding="utf-8")
        with self.assertRaises(ValueError):native.audit_batch(folder,c,self.core_path,synthetic=True)

    def test_10_legacy_contact_plans_match_frozen_published_source(self):
        bound=search.LEGACY_SOURCE
        raw=subprocess.check_output(["git","show",bound["commit"]+":"+bound["path"]],cwd=native.ROOT)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),bound["sha256"])
        (self.root/"legacy_contact_reach_at_b18.py").write_bytes(raw)
        legacy=types.ModuleType("legacy_contact_reach")
        exec(compile(raw,"legacy_contact_reach_at_b18.py","exec"),legacy.__dict__)
        cell,state,rotation=self.case();current_geometry=cell.contact_geometry;old_geometry=legacy.LimbGeometry(cell.spec)
        for p in search.source()["profiles"][2:]:
            self.assertEqual(contact.profile(p),legacy.profile(p))
            self.assertEqual(contact.behavior_key(p),legacy.behavior_key(p))
            new_memory=old_memory=None
            for step in range(200):
                for i,c in enumerate(state["ordered_contact_observations"]):c.update(presence=step%33>i+3,bears_support=step%33>i+3)
                for i,j in enumerate(state["ordered_joint_observations"]):j["position_rad"]=.3*math.sin(step*.03+i)
                current=contact.plan(p,current_geometry,state,rotation,state["ordered_contact_observations"],new_memory,step==199)
                old=legacy.plan(p,old_geometry,state,rotation,state["ordered_contact_observations"],old_memory,step==199)
                self.assertEqual(current,old)
                new_memory=current["state_after"];old_memory=old["state_after"]


if __name__=="__main__":
    unittest.main()
