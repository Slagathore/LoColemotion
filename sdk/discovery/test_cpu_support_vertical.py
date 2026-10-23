"""Synthetic vertical-composition streams and split, history and authority refusals."""
import copy
from contextlib import ExitStack
import json
import os
from pathlib import Path
import shutil
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid
import mujoco
from support_vertical_control import SupportVerticalController
from audit_gpu_batch_execution import SECTIONS
import test_gpu_repertoire_v2 as fixtures
from test_gpu_motor_effectiveness import put
import cpu_support_vertical_task as task
from cpu_support_vertical import preflight
from audit_cpu_support_vertical import audit
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from gpu_quadruped_model import FLAGS, sha, f32


class SupportVerticalRouteControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass();cls.f=fixtures.RepertoireControls
        cls.core_path,cls.baseline=cls.f.core_path,cls.f.baseline
        cls.c=dict(task.declaration(),outer_steps=2,synthetic=True,training_data_authority=False)
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("cpu-support-vertical-fixture-"+uuid.uuid4().hex)
        cls.root.mkdir();cls.folder=cls.root/"physical";cls.folder.mkdir()
        put(cls.root/"declaration.json",dict(contract=cls.c,synthetic=True))
        with ExitStack() as guards:
            for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Synthetic controls cannot open worlds")))
            (cls.folder/"models").mkdir()
            for condition in cls.c["challenge"]["conditions"]:
                directory=cls.folder/"models"/condition;directory.mkdir()
                compiled,xml,spec=condition_inputs(cls.core_path,cls.c,condition)
                put(directory/"compiled.json",compiled);put(directory/"inputs.json",spec)
                (directory/"model.xml").write_text(xml,encoding="utf-8",newline="\n")
                metadata=dict(model_sha256=sha(directory/"model.xml"),inputs_sha256=sha(directory/"inputs.json"),
                    compiled_sha256=sha(directory/"compiled.json"),condition_id=condition,actuator_profile=expected_actuator_arrays(spec),
                    ordered_bodies=cls.f.f.names,body_rootid=[0]+[1]*9,force_ranges=spec["force_ranges"],
                    observation_stage="prepared_before_control",force_stage="completed_step_before_next_prepare",
                    dynamics_dtype="float64",initial_values=cls.c["challenge"]["initial_values"])
                put(directory/"native-model.json",metadata)
            proxy=SimpleNamespace(c=cls.c,f=cls.f)
            results=[cls.make_trial(cls.folder/p["trial_id"],p) for p in task.trial_plan(cls.c)]
            put(cls.folder/"worker-result.json",dict(ok=True,synthetic=True,ledger_scope=cls.c["ledger_scope"],
                status="complete_native_cpu_support_vertical",controller_sessions_closed=True,total_wall_s=.1,
                constructed_cpu_worlds=16,constructed_gpu_worlds=0,trials=results,**{k:False for k in FLAGS}))
            cls.result=audit(cls.folder,cls.core_path,cls.baseline)

    @classmethod
    def make_trial(cls,folder,plan):
        folder.mkdir();put(folder/"plan.json",plan)
        native=cls.f.native(plan,0);native.pop("contact_compatibility_copy",None)
        controller=SupportVerticalController(cls.f.core,cls.f.compiled,dict(cls.c,seed=plan["seed"]),plan["activation_role_index"])
        controls=[];trace=[]
        try:
            for outer in range(cls.c["outer_steps"]):
                row=controller.step(*cls.f.observations(native,outer))
                view=copy.deepcopy(native);view["time_s"]=outer*5*cls.c["timestep_s"]
                row.update(backend="cpu",cell=0,outer_step=outer,native_observation=view);controls.append(row)
                for sub in range(5):
                    trace.append(dict(backend="cpu",cell=0,step=outer*5+sub+1,
                        before_qpos=native["qpos"],before_qvel=native["qvel"],qpos=native["qpos"],qvel=native["qvel"],
                        ctrl=list(row["native_targets"]),actuator_force_nm=[0.]*8,joint_force_nm=[0.]*8,
                        on_force_cap=[False]*8,time_s=(outer*5+sub+1)*cls.c["timestep_s"],contacts=native["contacts"],
                        batch_contacts=4,nefc=12,overflow=0,warnings=[0]*cls.c["cpu_warning_count"]))
        finally:controller.close()
        timings=[dict(outer_step=i,measured=True,**{key:.01 for key in SECTIONS},outer_total_s=.1) for i in range(cls.c["outer_steps"])]
        for name,rows in [("controller",controls),("trace",trace),("timing",timings)]:
            (folder/(name+".jsonl")).write_text("".join(json.dumps(r)+"\n" for r in rows),encoding="utf-8",newline="\n")
        result=dict(plan,completed=True,setup_s=.01,graph_capture_s=0.,outer_rows=len(controls),internal_rows=len(trace),
            hashes={name:sha(folder/(name+".jsonl")) for name in ["controller","trace","timing"]})
        put(folder/"result.json",result);return result

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in controls"))
            guard.start();self.addCleanup(guard.stop)

    def copied(self):
        root=self.root.parent/("cpu-support-vertical-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.root,root);return root

    def verify(self,root):return audit(root/"physical",self.core_path,self.baseline)

    def rehash(self,root,index,name):
        folder=root/"physical";trial=folder/task.trial_plan(self.c)[index]["trial_id"]
        result=json.loads((trial/"result.json").read_text());result["hashes"][name]=sha(trial/(name+".jsonl"));put(trial/"result.json",result)
        worker=json.loads((folder/"worker-result.json").read_text());worker["trials"][index]=result;put(folder/"worker-result.json",worker)

    def scored(self):
        trials=copy.deepcopy(self.result["trials"])
        for trial in trials:
            trial["episodes"][0]["metrics"]["quality_m_s"]=-.1 if trial["candidate_indices"] == [3] else -.2
        return trials

    def test_training_population_and_disjoint_reserved_start_groups(self):
        c=task.declaration();plans=task.trial_plan(c)
        self.assertEqual(len({p["trial_id"] for p in plans}),16)
        self.assertEqual(len({p["group_id"] for p in plans}),4)
        self.assertTrue(all(p["partition"] == "training" and p["training_data_authority"] for p in plans))
        self.assertEqual({p["seed"] for p in plans},{104232500})
        values=[s["lateral_velocity_m_s"] for rows in c["challenge"]["partitions"].values() for s in rows]
        self.assertEqual(len(set(values)),8)
        self.assertTrue(set(values).isdisjoint(c["challenge"]["excluded_confirmation_starts"]))
        self.assertTrue(c["training_data_authority"])
        self.assertTrue(all(c[k] is False for k in FLAGS if k != "training_data_authority"))
        self.assertFalse(c["challenge"]["confirmation_fitting_permitted"])
        self.assertEqual(c["selection"],task.parent_declaration()["selection"])
        with patch.object(task,"PREDECESSOR_SHA","0"*64):
            with self.assertRaises(ValueError):task.declaration()

    def test_real_abi_preflight_opens_no_world(self):
        value=preflight(self.core_path,self.baseline)
        self.assertEqual((value["world_build_count"],value["solver_steps"]),(0,0))
        self.assertEqual((value["planned_cpu_worlds"],value["planned_controller_rows"],value["planned_internal_rows"]),(16,23040,115200))

    def test_complete_reader_replays_all_roles_without_synthetic_training_authority(self):
        result=self.result
        self.assertEqual((result["controller_rows"],result["internal_rows"]),(32,160))
        self.assertEqual((result["eligible_episodes"],result["negative_episodes"]),(16,0))
        self.assertTrue(all(result[k] is False for k in FLAGS))
        self.assertFalse(result["controller_selection_authority"])
        self.assertEqual(len(result["groups"]),4)
        self.assertTrue(all(g["features"] is None and g["matching_baseline_prefixes"] == 2 for g in result["groups"]))
        self.assertIsNone(result["repertoire"]["selected_role_index"])

    def test_condition_force_and_xml_crossing_refused(self):
        for kind in ["identity","force","xml"]:
            root=self.copied();directory=root/"physical/models/left_075"
            if kind == "xml":
                _,xml,_=condition_inputs(self.core_path,self.c,"nominal")
                (directory/"model.xml").write_text(xml,encoding="utf-8",newline="\n")
            else:
                path=directory/"native-model.json";value=json.loads(path.read_text())
                if kind == "identity":value["condition_id"]="nominal"
                else:value["actuator_profile"]["forcerange"][0][0] *= .75
                put(path,value)
            with self.assertRaises(ValueError):self.verify(root)

    def test_missing_population_dtype_and_input_binding_refused(self):
        for kind in ["trial","condition","dtype","input"]:
            root=self.copied();folder=root/"physical"
            if kind == "trial":(folder/task.trial_plan(self.c)[0]["trial_id"]).rename(root/"retained-missing-trial")
            elif kind == "condition":(folder/"models/left_075").rename(root/"retained-missing-model")
            else:
                path=folder/"models/left_075/native-model.json";value=json.loads(path.read_text())
                value["dynamics_dtype" if kind == "dtype" else "inputs_sha256"]="float32" if kind == "dtype" else "0"*64
                put(path,value)
            with self.assertRaises(ValueError):self.verify(root)

    def test_horizon_false_authority_and_crossed_plan_refused(self):
        for kind in ["horizon","authority","plan"]:
            root=self.copied();folder=root/"physical"
            path=root/"declaration.json" if kind == "horizon" else folder/"worker-result.json"
            value=json.loads(path.read_text())
            if kind == "horizon":value["contract"]["outer_steps"]=1441
            elif kind == "authority":value["training_data_authority"]=True
            else:value["trials"][0],value["trials"][6]=value["trials"][6],value["trials"][0]
            put(path,value)
            with self.assertRaises(ValueError):self.verify(root)

    def test_rehashed_native_state_force_and_target_corruption_refused(self):
        for kind in ["state","force","target"]:
            root=self.copied();trial=root/"physical"/task.trial_plan(self.c)[8]["trial_id"]
            path=trial/"trace.jsonl";rows=[json.loads(s) for s in path.read_text().splitlines()]
            if kind == "state":rows[0]["before_qvel"][1]=.002
            elif kind == "force":rows[0]["actuator_force_nm"][0]=100.;rows[0]["joint_force_nm"][0]=100.;rows[0]["on_force_cap"][0]=True
            else:rows[0]["ctrl"][0] += .01
            path.write_text("".join(json.dumps(row)+"\n" for row in rows),encoding="utf-8",newline="\n")
            self.rehash(root,8,"trace")
            with self.assertRaises(ValueError):self.verify(root)

    def test_rehashed_history_and_false_feature_corruption_refused(self):
        for kind in ["history","feature"]:
            root=self.copied();trial=root/"physical"/task.trial_plan(self.c)[8]["trial_id"]
            path=trial/"controller.jsonl";rows=[json.loads(s) for s in path.read_text().splitlines()]
            if kind == "history":rows[1]["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]["state"]["ordered_joint_observations"][0]["position_rad"] += .01
            else:rows[0]["activation_probe"]["features"]={"future_outcome":"positive"}
            path.write_text("".join(json.dumps(row)+"\n" for row in rows),encoding="utf-8",newline="\n")
            self.rehash(root,8,"controller")
            with self.assertRaises(Exception):self.verify(root)

    def test_training_rank_and_matched_contrasts_preserve_all_starts_and_failures(self):
        trials=self.scored()
        for t in trials:t["episodes"][0]["metrics"]["quality_m_s"]=-.1 if t["activation_role_index"]==3 else -.2
        result=task.assess(trials,self.c)
        self.assertEqual(result["selected_role_index"],3);self.assertEqual(len(result["contrasts"]),20)
        self.assertTrue(all(row["both_eligible"] for row in result["contrasts"]))
        self.assertAlmostEqual(result["contrasts"][4]["quality_difference_m_s"],.1)
        trials[3]["episodes"][0].update(outcome="negative",failure_code="tilt",metrics=dict(quality_m_s=None))
        result=task.assess(trials,self.c)
        self.assertEqual(result["selected_role_index"],0);self.assertEqual(result["roles"][3]["eligible"],3)
        self.assertIsNone(result["roles"][3]["mean_quality_m_s"]);self.assertIsNone(result["contrasts"][4]["quality_difference_m_s"])
        trials[0]["episodes"][0]["metrics"]["quality_m_s"]=float("nan")
        with self.assertRaises(ValueError):task.assess(trials,self.c)
        with self.assertRaises(ValueError):task.assess(trials[:-1],self.c)
        trials=self.scored();trials[0]["partition"]="evaluation"
        with self.assertRaises(ValueError):task.assess(trials,self.c)

    def test_independent_reader_covers_full_prefix_transition_and_feature_corruption(self):
        from audit_cpu_support_vertical import audit_trial
        c=dict(self.c,outer_steps=18)
        proxy=SimpleNamespace(c=c,f=self.f)
        plan=task.trial_plan(c)[3]
        folder=self.root.parent/("support-vertical-full-prefix-"+uuid.uuid4().hex)
        self.make_trial.__func__(proxy,folder,plan)
        directory=self.folder/"models"/plan["condition_id"]
        compiled,xml,spec=condition_inputs(self.core_path,c,plan["condition_id"])
        metadata=json.loads((directory/"native-model.json").read_text())
        result=audit_trial(folder,plan,c,spec,compiled,metadata,self.f.oracle)
        self.assertEqual((result["controller_rows"],result["internal_rows"]),(18,90))
        self.assertEqual(result["probe_features"]["past_entries"],16)
        self.assertEqual(len(result["probe_features"]["values"]),16)
        path=folder/"controller.jsonl";rows=[json.loads(s) for s in path.read_text().splitlines()]
        rows[16]["activation_probe"]["features"]["values"][0] += .01
        path.write_text("".join(json.dumps(row)+"\n" for row in rows),encoding="utf-8",newline="\n")
        recorded=json.loads((folder/"result.json").read_text());recorded["hashes"]["controller"]=sha(path);put(folder/"result.json",recorded)
        with self.assertRaisesRegex(ValueError,"causal feature/onset"):
            audit_trial(folder,plan,c,spec,compiled,metadata,self.f.oracle)


if __name__ == "__main__":unittest.main()
