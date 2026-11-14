"""No-world force-cone controls and production controller integration checks."""
import copy
from contextlib import ExitStack
import hashlib
import itertools
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
import creature_body_moment_search as parent
import creature_righting as righting
import creature_torque_map as subject
from creature_batch import bridge
from creature_support_sharing_bounds import bounded_load_scale
from test_creature_batch import fixture, observation
from test_portable_search import _fixture


class ForceConeControls(unittest.TestCase):
    def test_01_null_moment_cannot_influence_requested_direction(self):
        linear=np.array([[1.,0.],[0.,1.],[0.,0.]])
        a=subject.cone_force(linear,[1.,0.,0.],[0.,1.,0.],.7)
        b=subject.cone_force(linear,[1.,0.,100.],[0.,1.,0.],.7)
        np.testing.assert_allclose(a["direction"],[.7,1.,0.],atol=1e-12)
        np.testing.assert_array_equal(a["direction"],b["direction"])
        self.assertEqual(float(a["moment_arm"]),float(b["moment_arm"]))

    def test_02_rank_zero_one_and_two_are_explicit(self):
        matrices=np.array([np.zeros((3,2)),[[0.,0.],[1.,2.],[0.,0.]],[[1.,0.],[0.,0.],[0.,0.]],[[1.,0.],[0.,1.],[0.,0.]]])
        r=subject.cone_force(matrices,np.tile([1.,1.,1.],(4,1)),[0.,1.,0.],.5)
        self.assertEqual(r["rank"].tolist(),[0,1,1,2])
        self.assertEqual(r["feasible"].tolist(),[False,True,False,True])
        np.testing.assert_allclose(r["direction"][1],[0.,1.,0.],atol=1e-12)

    def test_03_empty_and_boundary_cones(self):
        for tilt,expected in ((.5,True),(.50001,False)):
            linear=np.array([[tilt,0.],[1.,0.],[0.,0.]])
            r=subject.cone_force(linear,[1.,0.,0.],[0.,1.,0.],.5)
            self.assertEqual(bool(r["feasible"]),expected)
            if expected:np.testing.assert_allclose(r["direction"],[.5,1.,0.],atol=1e-12)
        r=subject.cone_force(np.array([[1.,0.],[0.,1.],[0.,0.]]),[1.,0.,1.],[0.,1.,0.],0.)
        np.testing.assert_allclose(r["direction"],[0.,1.,0.],atol=1e-12)

    def test_04_independent_circle_search_bounds_the_optimum(self):
        rng=np.random.default_rng(1061141)
        theta=np.linspace(0.,2*math.pi,4097)
        for _ in range(24):
            basis,_=np.linalg.qr(rng.normal(size=(3,3)))
            linear=basis[:,:2]*rng.uniform(.1,2.,size=2)
            lever=rng.normal(size=3);up=np.array([0.,1.,0.]);mu=.9
            r=subject.cone_force(linear,lever,up,mu)
            normal=basis[:,2];horizontal=normal.copy();horizontal[1]=0.
            denominator=float(horizontal@horizontal)
            if denominator<1e-12:continue
            center=-normal[1]*horizontal/denominator
            remaining=mu*mu-float(center@center)
            self.assertEqual(bool(r["feasible"]),remaining>=-1e-12)
            if remaining<0.:continue
            tangent=np.cross(up,horizontal);tangent/=np.linalg.norm(tangent)
            # The plane/cone intersection is a line segment, whose two ends
            # independently give the optimum of the linear moment objective.
            candidates=up+center+np.cos(theta)[:,None]*math.sqrt(remaining)*tangent
            self.assertAlmostEqual(float(r["moment_arm"]),float(np.max(candidates@lever)),places=10)

    def test_05_rigid_frame_covariance(self):
        q=np.array([.2,-.3,.1,.9]);q/=np.linalg.norm(q)
        rotation=moment.mechanics.quaternion_rotation(q)
        linear=np.array([[1.,0.],[0.,1.],[0.,0.]])
        lever=np.array([.3,.2,.7]);up=np.array([0.,1.,0.])
        a=subject.cone_force(linear,lever,up,.8)
        b=subject.cone_force(rotation@linear,rotation@lever,rotation@up,.8)
        np.testing.assert_allclose(b["direction"],rotation@a["direction"],atol=1e-12)
        self.assertAlmostEqual(float(a["moment_arm"]),float(b["moment_arm"]),places=12)

    def test_06_batched_and_scalar_results_agree(self):
        rng=np.random.default_rng(11);linear=rng.normal(size=(3,4,3,2));lever=rng.normal(size=(3,4,3))
        batch=subject.cone_force(linear,lever,[0.,1.,0.],.7)
        for i,j in itertools.product(range(3),range(4)):
            one=subject.cone_force(linear[i,j],lever[i,j],[0.,1.,0.],.7)
            for key in batch:np.testing.assert_allclose(batch[key][i,j],one[key],atol=1e-12)

    def test_07_invalid_numeric_inputs_are_refused(self):
        good=[np.eye(3)[:,:2],[1.,0.,0.],[0.,1.,0.],.5]
        for index,value in ((0,np.zeros((3,3))),(0,np.full((3,2),np.nan)),(0,np.ones((3,2),bool)),
                            (1,[1.,math.inf,0.]),(2,[0.,2.,0.]),(3,True),(3,-.1),(3,1.)):
            arguments=copy.deepcopy(good);arguments[index]=value
            with self.assertRaises(ValueError):subject.cone_force(*arguments)

    def test_08_vector_bounds_match_independent_scalar_intersections(self):
        rng=np.random.default_rng(19);gravity=rng.normal(size=(100,4,2))*3;contact=rng.normal(size=(100,4,2))*10
        contact[::3,:,0]=0.;ranges=np.broadcast_to(np.array([-2.,3.]),(1,4,2,2))
        low,high,valid=subject.load_intervals(gravity,contact,ranges)
        for i,j in itertools.product(range(100),range(4)):
            result=bounded_load_scale(gravity[i,j],contact[i,j],ranges[0,j])
            self.assertEqual(bool(valid[i,j]),result is not None)
            if result is not None:np.testing.assert_allclose([low[i,j],high[i,j]],result,atol=1e-12)


class TorqueMapControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.template=_fixture(cls.core)["provider_request"]["state"]
        cls.descriptor=parent.spec(parent.RECIPE)["descriptors"][16]
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-torque-map"
        cls.root.mkdir()

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in torque-map controls")))

    def cell(self, *, configuration=None, plain=False, axis=None):
        p=copy.deepcopy(parent.proposals()[16]);p["id"]="torque_fixture"
        if not plain:p["torque_map"]=copy.deepcopy(configuration or subject.DEFAULT_POLICY)
        if axis is not None:p["axis_body"]=axis
        cell=righting.RightingController(self.core,dict(cell_id="torque_control",descriptor=self.descriptor,
            profile=p,motor_effectiveness=[1.]*8),seed=1)
        self.addCleanup(cell.close)
        row=observation(cell,fixture(cell.creature,self.template),0)
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=1.,y=0.,z=0.,w=0.)
        row["state"]["base_pose_world"]["position_m"]["y"]=float(righting.initial_arrays([cell.creature],[math.pi])[0][0,2])
        for joint,value in zip(row["state"]["ordered_joint_observations"],[.3,-.6]*4):
            joint.update(position_rad=value,velocity_rad_s=0.)
        for contact in row["state"]["ordered_contact_observations"]:contact.update(presence=True,bears_support=True)
        return cell,row

    def test_09_schema_and_conflicting_modes(self):
        cell,_=self.cell()
        for key,value in (("pose_score","invalid"),("normalization",True),("contact_set","invalid"),("extra",0)):
            p=copy.deepcopy(cell.candidate);p["torque_map"][key]=value
            with self.assertRaises(ValueError):moment.profile(p)
        for key in ("handoff","support_exchange","support_sharing"):
            p=copy.deepcopy(cell.candidate);p[key]={}
            with self.assertRaises(ValueError):moment.profile(p)

    def test_10_batched_kinematics_and_gravity_match_scalar_tree(self):
        cell,_=self.cell();g=cell.moment_geometry
        up=np.array([.2,-.9,.3]);up/=np.linalg.norm(up)
        for index in (0,len(g.pool_indices)//3,len(g.pool_indices)-1):
            frame=g.tree.kinematics([0.,0.,0.],[0.,0.,0.,1.],g.bank.geometry.joints[index])
            np.testing.assert_allclose(g.anchors[index],frame["anchors"],atol=1e-12)
            np.testing.assert_allclose(g.axes[index],frame["axes"],atol=1e-12)
            np.testing.assert_allclose(-9.81*(g.gravity_coefficients[index]@up),g.tree.gravity_torques(frame,-9.81*up),atol=1e-12)

    def test_11_target_force_and_static_cap_are_independently_reconstructed(self):
        cell,row=self.cell();g=cell.moment_geometry;decision=cell.plan(row)["resolution"]["body_moment"]
        target=decision["state_after"]["target"];self.assertTrue(target["torque_map_target"])
        index,limb=target["bank_index"],target["limb"]
        q=g.bank.geometry.joints[index];frame=g.tree.kinematics([0.,0.,0.],[0.,0.,0.,1.],q)
        up=np.array([0.,-1.,0.]);point=g.bank.points[index,g.features[limb]]
        radii=g.bank.radii[g.features[limb]];endpoint=int(np.argmin(point@up-radii))
        point=point[endpoint]-radii[endpoint]*up
        linear=g.tree.jacobian(frame,g.tree.body_ids[g.bank.distal[limb]],point)[0]
        force=np.array(target["proposed_direction_body"]);normal=target["proposed_bounded_normal_n"]
        self.assertAlmostEqual(float(force@up),1.,places=10)
        self.assertLessEqual(np.linalg.norm(force-up),cell.candidate["friction_ratio"]+1e-10)
        np.testing.assert_allclose(np.linalg.pinv(linear.T)@(linear.T@force),force,atol=1e-9)
        torque=-g.tree.gravity_torques(frame,-9.81*up)-linear.T@(normal*force)
        bounds=np.asarray(g.creature["spec"]["force_ranges"]);js=[2*limb,2*limb+1]
        self.assertTrue(np.all(torque[js]>=bounds[js,0]-1e-9) and np.all(torque[js]<=bounds[js,1]+1e-9))
        self.assertGreaterEqual(target["target_nonadjacent_gap_m"],-1e-9)

    def test_12_every_contact_is_requested_or_quiet_with_original_guards(self):
        cell,row=self.cell();d=cell.plan(row)["resolution"]["body_moment"];info=d["torque_map"]
        self.assertTrue(d["active_limbs"])
        self.assertEqual(sorted(info["active_limbs"]+info["quiet_limbs"]),[0,1,2,3])
        self.assertTrue(set(info["active_limbs"]).isdisjoint(info["quiet_limbs"]))
        for i in info["active_limbs"]:
            for j in (2*i,2*i+1):self.assertAlmostEqual(d["force_projection"]["requested_torque"][j],d["post_guard_predicted_torque_nm"][j],places=8)
        for i in info["quiet_limbs"]:
            for j in (2*i,2*i+1):self.assertEqual(d["force_projection"]["requested_torque"][j],0.)
        self.assertLessEqual(info["total_normal_request_n"],cell.moment_geometry.weight*cell.candidate["normal_load_ratio"]+1e-9)
        self.assertFalse(info["forces_are_measured"]);self.assertFalse(info["torso_reactions_modeled"])

    def test_13_requested_forces_retain_cone_and_row_space(self):
        cell,row=self.cell();g=cell.moment_geometry
        d=cell.plan(row)["resolution"]["body_moment"]
        frame=g.tree.kinematics([row["state"]["base_pose_world"]["position_m"][k] for k in "xyz"],[1.,0.,0.,0.],
                               [j["position_rad"] for j in row["state"]["ordered_joint_observations"]])
        for wrench in d["requested_wrenches"]:
            force=np.array(wrench["force"]);linear=g.tree.jacobian(frame,wrench["body_id"],wrench["point"])[0]
            self.assertGreater(force[1],0.)
            self.assertLessEqual(np.linalg.norm(force[[0,2]]),cell.candidate["friction_ratio"]*force[1]+1e-9)
            np.testing.assert_allclose(np.linalg.pinv(linear.T)@(linear.T@force),force,atol=1e-8)

    def test_14_pose_scores_and_normalization_change_real_actions(self):
        cells=[]
        for score,normal in itertools.product(("visible_arm","bounded_moment"),("moment","load")):
            cells.append(self.cell(configuration=dict(subject.DEFAULT_POLICY,pose_score=score,normalization=normal)))
        witnesses=dict(pose=False,normal=False)
        for degrees in (0.,15.,30.,45.):
            results=[]
            for cell,original in cells:
                row=copy.deepcopy(original);angle=math.radians(180-degrees)/2
                row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(angle),y=0.,z=0.,w=math.cos(angle))
                results.append(cell.plan(row)["resolution"]["body_moment"])
            witnesses["pose"] |= results[0]["normalized_targets"]!=results[2]["normalized_targets"]
            witnesses["normal"] |= results[0]["post_guard_predicted_torque_nm"]!=results[1]["post_guard_predicted_torque_nm"]
        self.assertTrue(all(witnesses.values()),witnesses)

    def test_15_legacy_controller_is_byte_identical(self):
        raw=subprocess.check_output(["git","show","364ea7ee30393a60cc89c3f9984bfd8cf88f7eb4:sdk/discovery/creature_body_moment.py"],cwd=parent.ROOT)
        frozen=types.ModuleType("frozen_moment");exec(compile(raw,"frozen_moment","exec"),frozen.__dict__)
        cell,row=self.cell(plain=True);state=row["state"]
        args=(cell.candidate,cell.moment_geometry,state,np.diag([1.,-1.,-1.]),state["ordered_contact_observations"],None,cell.previous,False)
        self.assertEqual(json.dumps(frozen.plan(*args),sort_keys=True),json.dumps(moment.plan(*args),sort_keys=True))

    def test_16_preparation_does_not_commit_and_batch_failure_rolls_back(self):
        cell,row=self.cell();before=(copy.deepcopy(cell.moment_state),cell.previous[:],cell.step_index)
        first=cell.plan(row);self.assertEqual(first,cell.plan(row))
        self.assertEqual(before,(cell.moment_state,cell.previous,cell.step_index))
        spec=copy.deepcopy(parent.spec(parent.RECIPE));spec["descriptors"]=[self.descriptor]
        spec["schema_version"]=righting.SCHEMA;spec.pop("profiles_by_body",None)
        spec["profiles"]=spec["profiles"][:2]+[cell.candidate]
        batch=righting.RightingBatch(self.core,righting.expand(spec)["cells"],seed=1);self.addCleanup(batch.close)
        rows=[observation(c,fixture(c.creature,self.template),0) for c in batch.controllers]
        rows[-1]["state"]["ordered_joint_observations"][0]["position_rad"]=math.nan
        with self.assertRaises(ValueError):batch.step(rows)
        self.assertTrue(all(c.step_index==0 and c.previous==[0.]*8 and c.moment_state is None for c in batch.controllers))

    def test_17_upright_and_no_contact_paths(self):
        cell,row=self.cell()
        for contact in row["state"]["ordered_contact_observations"]:contact.update(presence=False,bears_support=False)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["requested_wrenches"],[]);self.assertEqual(d["torque_map"]["quiet_limbs"],[])
        row["state"]["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=0.,z=0.,w=1.)
        row["state"]["base_pose_world"]["position_m"]["y"]=cell.creature["compiled"]["geometry"]["initial_torso_center_y_m"]
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["torque_map"]["reason"],"upright_stance")
        self.assertEqual(d["normalized_targets"],[0.]*8)

    def test_18_joint_limits_remain_observed_and_guarded(self):
        cell,row=self.cell();g=cell.moment_geometry
        row["state"]["ordered_joint_observations"][0].update(position_rad=float(g.upper[0]+.001),velocity_rad_s=.4)
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertTrue(all(math.isfinite(v) for v in d["proposed_velocities_rad_s"]))
        self.assertEqual(row["state"]["ordered_joint_observations"][0]["position_rad"],float(g.upper[0]+.001))

    def test_19_straight_singular_legs_do_not_invent_normal_force(self):
        cell,row=self.cell()
        for joint in row["state"]["ordered_joint_observations"]:joint["position_rad"]=0.
        d=cell.plan(row)["resolution"]["body_moment"]
        self.assertEqual(d["torque_map"]["ranks"],[1]*4)
        self.assertEqual(d["active_limbs"],[])
        self.assertEqual(d["torque_map"]["quiet_limbs"],[0,1,2,3])
        self.assertEqual(d["requested_wrenches"],[])

    def test_20_contact_variants_change_guarded_commands(self):
        pairs=[self.cell(configuration=dict(subject.DEFAULT_POLICY,contact_set=mode))
               for mode in ("primary","all")]
        outputs=[cell.plan(row)["resolution"]["body_moment"] for cell,row in pairs]
        self.assertEqual(len(outputs[0]["active_limbs"]),1)
        self.assertGreater(len(outputs[1]["active_limbs"]),1)
        self.assertNotEqual(outputs[0]["post_guard_predicted_torque_nm"],outputs[1]["post_guard_predicted_torque_nm"])
        witness=dict(joint_positions_rad=[.3,-.6]*4,active_limbs=[d["active_limbs"] for d in outputs],
                     predicted_torques_nm=[d["post_guard_predicted_torque_nm"] for d in outputs])
        (self.root/"contact-set-witness.json").write_text(json.dumps(witness,indent=2)+"\n",encoding="utf-8",newline="\n")

    def test_21_factored_breadth_keeps_both_strata_and_fresh_comparators(self):
        import creature_torque_map_search as search
        spec,refs=search.population();recipes=search.recipes();rows=search.assignments()
        old=search.parent.spec();sharing=search.sharing_references()
        self.assertEqual(len(spec["descriptors"]),24)
        self.assertEqual(len(righting.expand(spec)["cells"]),240)
        self.assertEqual(len(spec["profiles"]),88)
        for body,assigned in enumerate(spec["profiles_by_body"]):
            self.assertEqual(len(assigned),10);self.assertEqual(assigned[2],refs[body])
            self.assertEqual(spec["profiles"][assigned[3]],old["profiles"][sharing[body]["candidate_index"]])
            for key,values in (("pose_score",search.RECIPE["pose_scores"]),("normalization",search.RECIPE["normalizations"]),
                               ("contact_set",search.RECIPE["contact_sets"])):
                self.assertEqual([sum(recipes[i][key]==value for i in rows[body]) for value in values],[3,3])
        for recipe in range(8):
            self.assertEqual([sum(recipe in row for row in rows[start:start+12]) for start in (0,12)],[9,9])

    def test_22_complete_declarations_and_mutation_refusals(self):
        import creature_native as native
        import creature_torque_map_search as search
        import run_creature_native as owner
        for suffix,count in (("route_v1",24),("v1",240)):
            path=search.ROOT/"sdk/discovery"/f"creature_torque_map_{suffix}.json"
            c=native.declaration(path);self.assertEqual(len(c["cells"]),count)
            self.assertEqual(sum(k for _,_,k in native.gates(c)),304)
            paths={p.relative_to(search.ROOT).as_posix() for p in owner.source_paths(path,c)}
            self.assertTrue({"sdk/discovery/"+n for n in ("creature_torque_map.py","creature_torque_map_search.py","test_creature_torque_map.py")}<=paths)
            raw=json.loads(path.read_text());read=Path.read_text
            for change in (lambda v:v.pop("torque_map_search"),lambda v:v.update(outer_steps=1),
                    lambda v:v["sharing_reference_selection"][0].update(candidate_id="unexposed"),
                    lambda v:v["trajectory_reference_by_body"].__setitem__(0,True),
                    lambda v:v["post_native_path_screen"].update(required_before_lead_promotion=False),
                    lambda v:v["safety_controls"].pop(),lambda v:v.update(training_data_authority=True)):
                broken=copy.deepcopy(raw);change(broken)
                with patch.object(Path,"read_text",lambda p,*a,**kw:json.dumps(broken) if p==path else read(p,*a,**kw)):
                    with self.assertRaises((ValueError,KeyError)):native.declaration(path)

    def test_23_profile_capacity_does_not_expand_world_budget(self):
        import creature_torque_map_search as search
        spec,_=search.population();self.assertGreater(len(spec["profiles"]),64)
        too_many=copy.deepcopy(spec);too_many["profiles"]*=2
        with self.assertRaisesRegex(ValueError,"population budget"):righting.expand(too_many)
        too_many=copy.deepcopy(spec);too_many["starts"].append(dict(id="second",roll_rad=2.9))
        with self.assertRaisesRegex(ValueError,"world budget"):righting.expand(too_many)
        legacy=copy.deepcopy(spec)
        for p in legacy["profiles"]:p.pop("torque_map",None)
        with self.assertRaisesRegex(ValueError,"population budget"):righting.expand(legacy)

    def test_24_predecessor_bytes_are_required(self):
        import creature_torque_map_search as search
        c=json.loads((search.ROOT/"sdk/discovery/creature_torque_map_route_v1.json").read_text())
        bad=dict(search.SOURCES);bad["creature_support_sharing_diagnosis_v1.json"]="0"*64
        with patch.object(search,"SOURCES",bad):
            with self.assertRaisesRegex(ValueError,"predecessor binding"):search.validate(c)

    def route_fixture(self):
        import creature_torque_map_search as search
        rows=[];profiles=[];metadata=[]
        for index,mode in enumerate(("primary","all")):
            cell,row=self.cell(configuration=dict(subject.DEFAULT_POLICY,contact_set=mode))
            cell.cell_id=f"route_fixture_{index}";row["cell_id"]=cell.cell_id
            profiles.append(cell.candidate);metadata.append(dict(cell_id=cell.cell_id,candidate_index=index))
            for step in range(2):
                row["state"].update(semantic_step=step,sample_time_s=step*bridge.CONTROLLER_DT_S)
                for joint,value in zip(row["state"]["ordered_joint_observations"],[0.]*8 if step==0 else [.3,-.6]*4):
                    joint["position_rad"]=value
                output=cell.step(row);output["outer_step"]=step;rows.append(output)
        receipt=dict(contract=dict(mode="route_ghost",torque_map_search=search.RECIPE,outer_steps=2,
                         righting_spec=dict(profiles=profiles),righting_metadata=metadata),
            audit=dict(batches=[dict(batch_id="batch_0")],capture=dict(controller_replay_verified=True,within_run_projection_verified=True)))
        return rows,receipt

    def retained_route(self,name,rows,receipt):
        folder=self.root/name;stream=folder/"native/batch_0/controller.jsonl";stream.parent.mkdir(parents=True)
        raw=("".join(json.dumps(r)+"\n" for r in rows)).encode();stream.write_bytes(raw)
        receipt=copy.deepcopy(receipt)
        receipt["artifacts"]=[dict(path="native/batch_0/controller.jsonl",bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())]
        return folder,receipt

    def test_25_full_route_requires_actual_force_and_contact_branches(self):
        import creature_torque_map_search as search
        rows,receipt=self.route_fixture();folder,receipt=self.retained_route("route_pass",rows,receipt)
        result=search.verify_route(folder,receipt)
        self.assertTrue(result["complete"])
        self.assertEqual(result["counts"],dict(quiet_contact_rows=4,coordinated_contact_rows=1,no_force_rows=2))
        self.assertTrue(all(v==dict(rows=2,force=1,target=2) for v in result["cells"].values()))

    def test_26_route_refuses_missing_rows_forged_torques_scope_and_hashes(self):
        import creature_torque_map_search as search
        rows,receipt=self.route_fixture()
        for index,change in enumerate((lambda v:v.pop(),
            lambda v:v[0]["resolution"]["body_moment"]["torque_map"].update(forces_are_measured=True),
            lambda v:v[1]["resolution"]["body_moment"]["force_projection"]["requested_torque"].__setitem__(0,1.),
            lambda v:v[1]["resolution"]["body_moment"]["post_guard_predicted_torque_nm"].__setitem__(2,100.),
            lambda v:v[1].update(outer_step=2))):
            broken=copy.deepcopy(rows);change(broken);folder,trial=self.retained_route(f"route_refusal_{index}",broken,receipt)
            with self.assertRaises(ValueError):search.verify_route(folder,trial)
        folder,trial=self.retained_route("route_bad_hash",rows,receipt);trial["artifacts"][0]["sha256"]="0"*64
        with self.assertRaises(ValueError):search.verify_route(folder,trial)
        trial["audit"]["capture"]["controller_replay_verified"]=False
        with self.assertRaises(ValueError):search.verify_route(folder,trial)


if __name__ == "__main__":
    unittest.main()
