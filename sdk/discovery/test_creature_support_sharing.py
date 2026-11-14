"""Synthetic sharing invariants, force limits and complete prospective route."""
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
from creature_support_sharing_bounds import bounded_load_scale
import creature_body_moment_search as parent
import creature_righting as righting
import creature_support_exchange as exchange
import creature_support_sharing as sharing
import creature_support_sharing_search as search
import creature_native as native
import creature_trajectory_search as trajectory
import run_creature_native as owner
from creature_batch import bridge
from test_creature_batch import fixture, observation
from test_portable_search import _fixture


class SupportSharingControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template=_fixture(cls.core)["provider_request"]["state"]
        cls.descriptor=parent.spec(parent.RECIPE)["descriptors"][16]
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-support-sharing"
        cls.root.mkdir()

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in sharing controls")))

    def cell(self, *, plain=False, rock=False):
        p=copy.deepcopy(parent.proposals()[20 if rock else 16])
        p.update(id="sharing_fixture",support_sharing=copy.deepcopy(sharing.DEFAULT_POLICY))
        if plain:p.pop("support_sharing")
        cell=righting.RightingController(self.core,dict(cell_id="sharing_control",descriptor=self.descriptor,
            profile=p,motor_effectiveness=[1.]*8),seed=1)
        self.addCleanup(cell.close)
        row=observation(cell,fixture(cell.creature,self.template),0)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
        row["state"]["base_pose_world"]["position_m"]["y"]=float(righting.initial_arrays([cell.creature],[math.pi])[0][0,2])
        for i,c in enumerate(row["state"]["ordered_contact_observations"]):
            c.update(presence=i==1,bears_support=i==1)
        return cell,row

    def phase(self, cell, row, phase="seek", elapsed=1, dwell=6, **kw):
        memory=sharing.initial(0.)
        memory.update(phase=phase,elapsed=elapsed,support_limbs=[1],replacement_limb=3,
            hold_positions_rad=[.3]*8,axis_body=[1.,0.,0.],contact_count=dwell,cycles=1,
            target=dict(joint_targets_rad=[-.7,-.4],endpoint_nonadjacent_gap_m=.1),
            last_replacement_torque_nm=[0.,0.],last_request_fraction=.8)
        memory.update(kw);cell.moment_state=memory
        for i,c in enumerate(row["state"]["ordered_contact_observations"]):
            c.update(presence=i in (1,3),bears_support=i in (1,3))
        return memory

    @staticmethod
    def state_machine_proposal(p,g,state,rotation,previous,old,replacement,phase,fraction,targets,axis):
        # Isolate the state machine from mechanics. Separate controls below
        # exercise real geometry, force projection and the production resolver.
        weights={i:1. for i in old}
        if phase!="seek":weights[replacement]=fraction if phase=="load" else 1.
        if phase=="unload":weights[old[0]]=1.-fraction
        if phase=="transfer":weights.pop(old[0])
        return dict(phase="contact_force",normalized_targets=(targets/g.upper).tolist(),
            proposed_velocities_rad_s=[0.]*8,active_limbs=list(weights),requested_wrenches=[],
            force_projection=dict(requested_torque=[0.]*8),
            sharing_requests=[dict(limb=i,requested_weight=w,request_fraction=w) for i,w in weights.items()])

    def decision(self,cell,row):
        with patch.object(sharing,"proposal",side_effect=self.state_machine_proposal):
            return cell.plan(row)

    def test_01_strict_policy_and_mutually_exclusive_modes(self):
        cell,_=self.cell()
        for key,value in (("load_steps",True),("unload_steps",91),("maximum_share_steps",179),
                ("minimum_request_fraction",.1),("response_error_fraction",math.nan),("torque_reserve_weight",1.1)):
            p=copy.deepcopy(cell.candidate);p["support_sharing"][key]=value
            with self.assertRaises(ValueError):moment.profile(p)
        for key in ("handoff","support_exchange"):
            p=copy.deepcopy(cell.candidate);p[key]={}
            with self.assertRaises(ValueError):moment.profile(p)
        p=copy.deepcopy(cell.candidate);p["support_sharing"]["unknown"]=0
        with self.assertRaises(ValueError):moment.profile(p)

    def test_02_untriggered_drive_and_rock_references_are_exact(self):
        for rock in (False,True):
            a,row=self.cell(rock=rock);b,_=self.cell(rock=rock,plain=True)
            a.candidate["support_sharing"]["minimum_reference_steps"]=240
            for step in range(200):
                row["state"].update(semantic_step=step,sample_time_s=step*bridge.CONTROLLER_DT_S)
                x,y=a.step(row),b.step(row)
                self.assertEqual(x["native_targets"],y["native_targets"])
                self.assertEqual(x["resolution"]["ordered_commands"],y["resolution"]["ordered_commands"])
                for k in ("normalized_targets","requested_wrenches","force_projection"):
                    self.assertEqual(x["resolution"]["body_moment"][k],y["resolution"]["body_moment"][k])

    def test_03_affine_force_bounds_cover_signs_empty_and_nonzero_lower_bound(self):
        solve=bounded_load_scale
        self.assertEqual(solve([0.],[2.],[[-1.,1.]]),[0.,.5])
        self.assertEqual(solve([2.],[-2.],[[-1.,1.]]),[.5,1.])
        self.assertEqual(solve([0.,0.],[2.,-4.],[[-1.,1.],[-1.,1.]]),[0.,.25])
        self.assertIsNone(solve([2.],[0.],[[-1.,1.]]))
        self.assertIsNone(solve([0.,2.],[2.,-2.],[[0.,0.],[0.,0.]]))
        rng=np.random.default_rng(1640)
        for _ in range(100):
            g,c=rng.normal(size=(2,2));bounds=np.array([[-.5,.7],[-.8,.4]])
            got=solve(g,c,bounds)
            grid=np.linspace(0.,1.,1001);torque=-g[:,None]-c[:,None]*grid
            feasible=np.all((torque>=bounds[:,0,None])&(torque<=bounds[:,1,None]),axis=0)
            if got is None:self.assertFalse(feasible.any())
            else:
                for x in got:
                    self.assertTrue(np.all(-g-c*x>=bounds[:,0]-1e-12))
                    self.assertTrue(np.all(-g-c*x<=bounds[:,1]+1e-12))
                self.assertTrue(np.all((grid[feasible]>=got[0]-1e-12)&(grid[feasible]<=got[1]+1e-12)))

    def test_04_guarded_envelope_matches_resolver_image_at_and_beyond_limits(self):
        cell,_=self.cell();g=cell.moment_geometry;p=cell.candidate
        for position in (g.lower-.01,g.lower+.01,np.zeros(8),g.upper-.01,g.upper+.01):
            for velocity in (-np.ones(8),np.zeros(8),np.ones(8)):
                for previous in (-np.ones(8)*3.,np.zeros(8),np.ones(8)*3.):
                    env=sharing.guarded_envelope(p,g,position,velocity,previous)
                    for t in np.linspace(0.,1.,9):
                        targets=env["lower_target"]*(1-t)+env["upper_target"]*t
                        final=[]
                        for j,v in enumerate(targets):
                            bounded=max(-3.5,min(3.5,float(v)))
                            slewed=max(previous[j]-.2,min(previous[j]+.2,bounded))
                            shaped=moment.braking.shape(float(position[j]),float(velocity[j]),float(slewed),
                                3.5,float(g.lower[j]),float(g.upper[j]),1/120,p["joint_braking"])["shaped_velocity_rad_s"]
                            final.append(max(min(0.,(g.lower[j]-position[j])*120),
                                             min(max(0.,(g.upper[j]-position[j])*120),shaped)))
                        np.testing.assert_allclose(final,targets,atol=1e-12,rtol=0.)

    def test_05_real_force_requests_survive_production_command_guards(self):
        cell,row=self.cell();self.phase(cell,row)
        cell.previous=[0.]*8
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_sharing"]["phase"],"load")
        self.assertEqual(d["active_limbs"],[1,3])
        js=[2,3,6,7]
        np.testing.assert_allclose(np.array(d["force_projection"]["requested_torque"])[js],
            np.array(d["post_guard_predicted_torque_nm"])[js],atol=1e-8,rtol=0.)
        self.assertFalse(d["forces_are_measured"])
        self.assertTrue(all(0<=x["chosen_scale"]<=1 for x in d["sharing_requests"]))

    def test_06_target_ranking_contains_independently_bounded_static_request(self):
        cell,row=self.cell();g=cell.moment_geometry;state=row["state"]
        target=sharing.replacement_target(cell.candidate,g,state,np.diag([1.,-1.,-1.]),[1],3,np.array([1.,0.,0.]))
        self.assertIsNotNone(target)
        lo,hi=target["static_force_cap_scale_interval"]
        self.assertTrue(0<=lo<=hi<=1)
        self.assertGreater(target["proposed_bounded_normal_n"],0)
        self.assertFalse(target["dynamic_feasibility_established"])
        self.assertGreaterEqual(target["endpoint_nonadjacent_gap_m"],-1e-9)
        self.assertEqual(target,sharing.replacement_target(cell.candidate,g,state,np.diag([1.,-1.,-1.]),[1],3,np.array([1.,0.,0.])))

    def test_07_impossible_static_torque_and_unclear_endpoints_are_rejected(self):
        cell,row=self.cell();g=cell.moment_geometry
        args=(cell.candidate,g,row["state"],np.diag([1.,-1.,-1.]),[1],3,np.array([1.,0.,0.]))
        with patch.object(sharing,"bounded_load_scale",return_value=None):
            self.assertIsNone(sharing.replacement_target(*args))
        real=g.measured
        with patch.object(g,"measured",side_effect=lambda f:(real(f)[0],-.01)):
            self.assertIsNone(sharing.replacement_target(*args))
        row["state"]["ordered_joint_observations"][0]["position_rad"]=g.upper[0]+.01
        self.assertIsNone(sharing.replacement_target(*args))

    def test_08_seek_keeps_old_request_and_unmoving_limb_positions(self):
        cell,row=self.cell();self.phase(cell,row,dwell=0)
        row["state"]["ordered_contact_observations"][3].update(presence=False,bears_support=False)
        d=self.decision(cell,row)["resolution"]["body_moment"]
        self.assertEqual(d["active_limbs"],[1])
        self.assertEqual(d["support_sharing"]["phase"],"seek")
        self.assertEqual(d["sharing_requests"],[dict(limb=1,requested_weight=1.,request_fraction=1.)])
        self.assertTrue(all(v!=0. for v in d["normalized_targets"]))

    def test_09_load_requires_consecutive_contact_observations(self):
        cell,row=self.cell();self.phase(cell,row,dwell=5)
        row["state"]["ordered_contact_observations"][3].update(presence=False,bears_support=False)
        d=self.decision(cell,row)["resolution"]["body_moment"]
        self.assertEqual(d["state_after"]["contact_count"],0)
        self.assertEqual(d["support_sharing"]["phase"],"seek")
        row["state"]["ordered_contact_observations"][3].update(presence=True,bears_support=True)
        d=self.decision(cell,row)["resolution"]["body_moment"]
        self.assertEqual(d["support_sharing"]["reason"],"measured_replacement_contact")
        self.assertEqual(d["active_limbs"],[1,3])

    def test_10_loading_ramps_replacement_without_reducing_old_weight(self):
        cell,row=self.cell()
        for elapsed in (0,11,23,60):
            self.phase(cell,row,phase="load",elapsed=elapsed)
            d=self.decision(cell,row)["resolution"]["body_moment"]
            requests={v["limb"]:v for v in d["sharing_requests"]}
            self.assertEqual(requests[1]["requested_weight"],1.)
            self.assertEqual(requests[3]["requested_weight"],min(1.,(elapsed+1)/24))
            self.assertEqual(d["support_sharing"]["phase"],"load")

    def test_11_loading_requires_sustained_and_current_prepared_response(self):
        cell,row=self.cell()
        for ready,error,expected in ((5,0.,"load"),(6,20.,"load"),(6,0.,"unload")):
            self.phase(cell,row,phase="load",elapsed=24,ready_count=ready,last_replacement_torque_nm=[error,error])
            d=self.decision(cell,row)["resolution"]["body_moment"]
            self.assertEqual(d["support_sharing"]["phase"],expected)
        self.phase(cell,row,phase="load",elapsed=24,ready_count=6,last_request_fraction=.1)
        self.assertEqual(self.decision(cell,row)["resolution"]["body_moment"]["support_sharing"]["phase"],"load")

    def test_12_unloading_advances_or_restores_using_prepared_velocity(self):
        cell,row=self.cell()
        for error,expected,reason in ((0.,.5+1/24,"continue"),(20.,.5-1/24,"restore_old_request")):
            self.phase(cell,row,phase="unload",unload_fraction=.5,last_replacement_torque_nm=[error,error])
            d=self.decision(cell,row)["resolution"]["body_moment"]
            self.assertAlmostEqual(d["state_after"]["unload_fraction"],expected)
            self.assertEqual(d["support_sharing"]["reason"],reason)
        self.phase(cell,row,phase="unload",unload_fraction=.5)
        row["state"]["ordered_joint_observations"][6]["velocity_rad_s"]=3.
        d=self.decision(cell,row)["resolution"]["body_moment"]
        self.assertFalse(d["support_sharing"]["prepared_motor_response_ok"])
        self.assertLess(d["state_after"]["unload_fraction"],.5)

    def test_13_release_requires_committed_zero_old_request(self):
        cell,row=self.cell()
        self.phase(cell,row,phase="unload",unload_fraction=1.,last_old_request_fraction=0.)
        d=self.decision(cell,row)["resolution"]["body_moment"]
        self.assertEqual(d["support_sharing"]["phase"],"transfer")
        self.assertEqual(d["active_limbs"],[3])
        self.assertEqual(d["normalized_targets"][2:4],[0.,0.])

    def test_14_positive_guarded_old_request_blocks_scheduled_release(self):
        cell,row=self.cell()
        self.phase(cell,row,phase="unload",unload_fraction=1.,last_old_request_fraction=.2)
        d=self.decision(cell,row)["resolution"]["body_moment"]
        self.assertEqual(d["support_sharing"]["phase"],"unload")
        self.assertEqual(d["support_sharing"]["reason"],"await_old_request_release")
        self.assertEqual(d["active_limbs"],[1,3])
        self.assertEqual(d["state_after"]["last_old_request_fraction"],0.)

    def test_15_lost_required_contact_restores_reference_in_every_phase(self):
        cell,row=self.cell()
        for phase,limb in (("seek",1),("load",3),("unload",1),("transfer",3)):
            self.phase(cell,row,phase=phase)
            row["state"]["ordered_contact_observations"][limb].update(presence=False,bears_support=False)
            d=self.decision(cell,row)["resolution"]["body_moment"]
            self.assertEqual(d["support_sharing"]["reason"],"lost_required_contact")
            self.assertEqual(d["state_after"]["cooldown"],60)

    def test_16_all_active_phases_have_bounded_timeouts(self):
        cell,row=self.cell()
        for phase,elapsed,reason in (("seek",180,"replacement_timeout"),("load",240,"load_response_timeout"),
                ("unload",240,"unload_response_timeout"),("transfer",36,"transfer_complete")):
            self.phase(cell,row,phase=phase,elapsed=elapsed,dwell=0)
            if phase=="seek":
                row["state"]["ordered_contact_observations"][3].update(presence=False,bears_support=False)
            d=self.decision(cell,row)["resolution"]["body_moment"]
            self.assertEqual(d["support_sharing"]["reason"],reason)
            self.assertEqual(d["support_sharing"]["phase"],"reference")
            self.assertEqual(d["state_after"]["cooldown"],60)

    def test_17_missing_pose_or_guarded_force_interval_restores_reference(self):
        cell,row=self.cell()
        for method,reason in (("replacement_target","no_clear_force_bounded_pose"),("proposal","no_guarded_force_interval")):
            self.phase(cell,row,dwell=0,elapsed=0 if method=="replacement_target" else 1)
            row["state"]["ordered_contact_observations"][3].update(presence=False,bears_support=False)
            with patch.object(sharing,method,return_value=None):
                d=cell.plan(row)["resolution"]["body_moment"]
            self.assertEqual(d["support_sharing"]["reason"],reason)
            self.assertEqual(d["state_after"]["cooldown"],60)

    def test_18_upright_resets_response_history_and_sharing_state(self):
        cell,row=self.cell();self.phase(cell,row,phase="unload",unload_fraction=.5)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=0.,z=0.,w=1.)
        row["state"]["base_pose_world"]["position_m"]["y"]=1.
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["support_sharing"]["reason"],"upright_reset")
        self.assertIsNone(d["state_after"]["last_replacement_torque_nm"])
        self.assertEqual(d["state_after"]["unload_fraction"],0.)
        self.assertEqual(d["active_limbs"],[])

    def test_19_plans_are_pure_and_joint_protection_remains_authoritative(self):
        cell,row=self.cell();self.phase(cell,row,dwell=0)
        before=copy.deepcopy(cell.moment_state)
        a=cell.plan(row);self.assertEqual(a,cell.plan(row));self.assertEqual(before,cell.moment_state)
        cell.previous=[.2]*8
        for j,spec in zip(row["state"]["ordered_joint_observations"],cell.spec["joints"],strict=True):
            j.update(position_rad=spec["upper_limit_rad"]+.01,velocity_rad_s=1.)
        d=cell.plan(row)
        self.assertTrue(all(d["resolution"]["observed_joint_limit_breaches"]))
        self.assertTrue(all(-3.5<=v<=0. for v in d["native_targets"]))

    def test_20_rejected_batch_does_not_commit_any_command_or_state(self):
        spec=search.spec(route=True);spec["profiles"]=spec["profiles"][:5]
        batch=righting.RightingBatch(self.core,righting.expand(spec)["cells"],seed=search.RECIPE["seed"])
        self.addCleanup(batch.close)
        rows=[observation(c,fixture(c.creature,self.template),0) for c in batch.controllers]
        rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]=math.nan
        with self.assertRaises(ValueError):batch.step(rows)
        self.assertTrue(all(c.step_index==0 and c.moment_state is None and c.previous==[0.]*8 for c in batch.controllers))

    def test_21_factored_breadth_balances_bodies_ramps_scores_and_fresh_comparators(self):
        spec=search.spec();rows=search.assignments();recipes=search.recipes()
        self.assertEqual((len(recipes),len(spec["profiles"]),len(righting.expand(spec)["cells"])),(12,50,192))
        self.assertEqual(spec["descriptors"],parent.spec(parent.RECIPE)["descriptors"])
        refs=search.parent.parent.references();failed=search.failed_references()
        old=parent.spec(parent.RECIPE)["profiles"];prior=search.parent.spec()["profiles"]
        for body,indices in enumerate(rows):
            self.assertEqual(len(set(indices)),4)
            for field,values in (("torque_reserve_weight",[0.,.5]),("load_steps",[24,60])):
                self.assertEqual([sum(recipes[i][field]==v for i in indices) for v in values],[2,2])
            self.assertEqual(sorted(sum(recipes[i]["limb_relation"]==v for i in indices) for v in search.RECIPE["limb_relations"]),[1,1,2])
            assigned=spec["profiles_by_body"][body]
            self.assertEqual(assigned[:2],[0,1])
            self.assertEqual(spec["profiles"][assigned[2]],old[refs[body]["candidate_index"]])
            self.assertEqual(spec["profiles"][assigned[3]],prior[failed[body]["candidate_index"]])
            for i,index in zip(indices,assigned[4:],strict=True):
                self.assertEqual(spec["profiles"][index],search.proposal(old[refs[body]["candidate_index"]],i))
        for recipe in range(12):
            self.assertEqual([sum(recipe in r for r in rows[start:start+12]) for start in (0,12)],[4,4])
        self.assertEqual({i for r in spec["profiles_by_body"] for i in r},set(range(50)))

    def test_22_declarations_bind_complete_gate_and_refuse_population_drift(self):
        for name,count in (("creature_support_sharing_route_v1.json",12),("creature_support_sharing_v1.json",192)):
            path=search.ROOT/"sdk/discovery"/name;c=native.declaration(path)
            self.assertEqual(len(c["cells"]),count)
            self.assertEqual(sum(k for _,_,k in native.gates(c)),278)
            paths={p.relative_to(search.ROOT).as_posix() for p in owner.source_paths(path,c)}
            self.assertTrue({"sdk/discovery/"+n for n in search.SOURCES}<=paths)
            self.assertTrue(native.work_enabled(c))
            for change in (lambda v:v.pop("support_sharing_search"),lambda v:v.update(outer_steps=1),
                    lambda v:v["failed_exchange_reference_selection"][0].update(candidate_id="unexposed"),
                    lambda v:v["trajectory_reference_by_body"].__setitem__(0,True),
                    lambda v:v["post_native_path_screen"].update(required_before_lead_promotion=False),
                    lambda v:v["righting_spec"]["profiles"][-1]["support_sharing"].update(load_steps=12)):
                broken=copy.deepcopy(c);change(broken)
                with self.assertRaises((ValueError,KeyError)):search.validate(broken)

    def route_rows(self):
        cell,row=self.cell();rows=[]
        self.phase(cell,row,dwell=0)
        row["state"]["ordered_contact_observations"][3].update(presence=False,bears_support=False)
        rows.append(copy.deepcopy(self.decision(cell,row)))
        self.phase(cell,row,dwell=5)
        rows.append(copy.deepcopy(self.decision(cell,row)))
        self.phase(cell,row,phase="unload",unload_fraction=.4)
        rows.append(copy.deepcopy(self.decision(cell,row)))
        self.phase(cell,row,phase="load",elapsed=240)
        rows.append(copy.deepcopy(self.decision(cell,row)))
        return rows

    def test_23_full_route_requires_loading_unloading_response_and_bounded_fallback(self):
        rows=self.route_rows();folder=self.root/"route";stream=folder/"native/batch_0/controller.jsonl"
        stream.parent.mkdir(parents=True)
        receipt=dict(contract=dict(mode="route_ghost",support_sharing_search=search.RECIPE),
            audit=dict(batches=[dict(batch_id="batch_0")],
                capture=dict(controller_replay_verified=True,within_run_projection_verified=True)))
        def write(values):stream.write_bytes(("".join(json.dumps(r)+"\n" for r in values)).encode())
        write(rows);self.assertTrue(search.verify_route(folder,receipt)["complete"])
        for omitted in range(len(rows)):
            write(rows[:omitted]+rows[omitted+1:])
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        for change in (lambda v:v[0]["resolution"]["body_moment"].update(active_limbs=[]),
                lambda v:v[1]["request"]["state"]["ordered_contact_observations"][3].update(presence=False),
                lambda v:v[1]["resolution"]["body_moment"]["state_after"].update(contact_count=0),
                lambda v:v[1]["resolution"]["body_moment"]["sharing_requests"][0].update(requested_weight=.5),
                lambda v:v[2]["resolution"]["body_moment"]["force_projection"]["requested_torque"].__setitem__(6,20.),
                lambda v:v[3]["resolution"]["body_moment"]["state_after"].update(cooldown=0)):
            broken=copy.deepcopy(rows);change(broken);write(broken)
            with self.assertRaises(ValueError):search.verify_route(folder,receipt)
        write(rows);receipt["artifacts"]=[dict(path="native/batch_0/controller.jsonl",bytes=stream.stat().st_size,sha256="0"*64)]
        with self.assertRaises(ValueError):search.verify_route(folder,receipt)

    def test_24_fresh_reference_gain_and_limb_diversity_still_gate_progress(self):
        spec=search.spec(route=True);reference=spec["profiles"][2]
        spec["profiles"]=spec["profiles"][:3]+[search.proposal(reference,i) for i in (0,3,1)]
        c=dict(mode="development_discovery",righting_spec=spec,trajectory_screen=trajectory.POLICY,
            support_sharing_search=search.RECIPE,trajectory_reference_by_body=[2],outer_steps=1,**righting.expand(spec))
        metrics=[dict(righting.initial_metrics(),**trajectory.initial_metrics()) for _ in c["cells"]]
        for m,angle in zip(metrics,(0.,14.,30.,38.,37.,36.),strict=True):
            m.update(trajectory_samples=5,trajectory_maximum_up_dot=-math.cos(math.radians(angle)))
        group=trajectory.assess(c,metrics)["groups"][0]
        self.assertEqual([r["candidate_index"] for r in group["progress_leads"]],[3,5])
        metrics[3]["joint_limit_violation_steps"]=1
        self.assertEqual([r["candidate_index"] for r in trajectory.assess(c,metrics)["groups"][0]["progress_leads"]],[4,5])


if __name__=="__main__":
    unittest.main()
