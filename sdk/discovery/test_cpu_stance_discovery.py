"""CPU stance family, full synthetic replay, corruption and ranking controls."""
import copy
import json
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid
import mujoco
import numpy as np
import test_gpu_repertoire_v2 as fixtures
from test_gpu_motor_effectiveness import put
from cpu_stance_task import declaration, trial_plan, initial_arrays, rank
from cpu_stance_discovery import preflight
from audit_cpu_stance_discovery import audit
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from stance_feedback_control import StanceFeedbackController
from gpu_quadruped_model import FLAGS, sha, f32
from audit_gpu_batch_execution import SECTIONS


class CpuStanceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass(); cls.f=fixtures.RepertoireControls
        cls.core_path,cls.baseline=cls.f.core_path,cls.f.baseline
        cls.c=dict(declaration(),outer_steps=2,synthetic=True)
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("cpu-stance-fixture-"+uuid.uuid4().hex)
        cls.root.mkdir(); cls.folder=cls.root/"physical";cls.folder.mkdir()
        put(cls.root/"declaration.json",dict(contract=cls.c,synthetic=True))
        with patch.object(mujoco,"MjModel",side_effect=AssertionError("world")), \
                patch.object(mujoco,"MjData",side_effect=AssertionError("data")):
            compiled,xml,spec=condition_inputs(cls.core_path,cls.c,"left_075");cls.spec=spec
            put(cls.folder/"compiled.json",compiled);put(cls.folder/"inputs.json",spec)
            (cls.folder/"model.xml").write_text(xml,encoding="utf-8",newline="\n")
            metadata=dict(model_sha256=sha(cls.folder/"model.xml"),inputs_sha256=sha(cls.folder/"inputs.json"),
                compiled_sha256=sha(cls.folder/"compiled.json"),condition_id="left_075",actuator_profile=expected_actuator_arrays(spec),
                ordered_bodies=cls.f.f.names,body_rootid=[0]+[1]*9,force_ranges=spec["force_ranges"],
                observation_stage="prepared_before_control",force_stage="completed_step_before_next_prepare",
                dynamics_dtype="float64",initial_values=cls.c["challenge"]["initial_values"])
            put(cls.folder/"native-model.json",metadata)
            results=[cls.make_trial(cls.folder/p["trial_id"],p) for p in trial_plan(cls.c)]
            put(cls.folder/"worker-result.json",dict(ok=True,synthetic=True,ledger_scope=cls.c["ledger_scope"],
                status="complete_native_cpu_stance_discovery",controller_sessions_closed=True,total_wall_s=.1,
                constructed_cpu_worlds=24,constructed_gpu_worlds=0,trials=results,**{k:False for k in FLAGS}))
            cls.result=audit(cls.folder,cls.core_path,cls.baseline)

    @classmethod
    def make_trial(cls,folder,plan):
        folder.mkdir();put(folder/"plan.json",plan)
        native=cls.f.native(plan,0);native.pop("contact_compatibility_copy",None)
        controller=StanceFeedbackController(cls.f.core,cls.f.compiled,dict(cls.c,seed=plan["seed"]),plan["candidate_indices"][0])
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
        folder=self.root.parent/("cpu-stance-corruption-"+uuid.uuid4().hex);shutil.copytree(self.root,folder);return folder

    def test_complete_family_and_declared_discovery_authority(self):
        c=declaration();plans=trial_plan(c)
        self.assertEqual(len(plans),24);self.assertEqual(sum(p["nworld"] for p in plans),24)
        self.assertEqual({p["seed"] for p in plans},{104232100})
        self.assertEqual([p["candidate_indices"] for p in plans],[[i] for _ in range(2) for i in range(12)])
        self.assertTrue(c["training_data_authority"]);self.assertTrue(all(c[k] is False for k in FLAGS if k != "training_data_authority"))

    def test_real_abi_preflight_opens_no_world(self):
        value=preflight(self.core_path,self.baseline)
        self.assertEqual((value["world_build_count"],value["solver_steps"],value["planned_cpu_worlds"],value["planned_gpu_worlds"]),(0,0,24,0))

    def test_initial_values_equal_gpu_float32_values_but_cpu_storage_is_double(self):
        for p in trial_plan(self.c):
            qpos,qvel=initial_arrays(self.spec,p)
            self.assertEqual(qpos.dtype,np.float64);self.assertEqual(qvel.dtype,np.float64)
            self.assertEqual(qpos.tolist(),list(map(f32,self.spec["initial_qpos"])))
            self.assertEqual(qvel[1],f32(p["initial_native_lateral_velocity_m_s"]))
            self.assertNotEqual(qvel[1],p["initial_native_lateral_velocity_m_s"])

    def test_complete_cpu_reader_replays_all_roles_with_no_gpu_copy(self):
        self.assertEqual((self.result["constructed_cpu_worlds"],self.result["constructed_gpu_worlds"]),(24,0))
        self.assertEqual((self.result["controller_rows"],self.result["internal_rows"]),(48,240))
        self.assertEqual((self.result["eligible_episodes"],self.result["negative_episodes"]),(24,0))
        self.assertFalse(self.result["training_data_authority"])

    def test_missing_population_wrong_dtype_or_motor_profile_refuse(self):
        for kind in ["missing","dtype","profile"]:
            root=self.copied();folder=root/"physical"
            if kind=="missing":(folder/trial_plan(self.c)[0]["trial_id"]).rename(root/"retained-missing-trial")
            else:
                path=folder/"native-model.json";value=json.loads(path.read_text())
                if kind=="dtype":value["dynamics_dtype"]="float32"
                else:value["actuator_profile"]["gainprm"][0][0]=10.
                put(path,value)
            with self.assertRaises(ValueError):audit(folder,self.core_path,self.baseline)

    def test_rehashed_precision_force_warning_and_initial_state_corruption_refuse(self):
        for kind in ["precision","force","warning","state"]:
            root=self.copied();folder=root/"physical";trial=folder/trial_plan(self.c)[1]["trial_id"]
            path=trial/"trace.jsonl";rows=[json.loads(line) for line in path.read_text().splitlines()]
            if kind=="precision":
                self.assertTrue(any(f32(x)!=x for x in rows[0]["ctrl"]))
                rows[0]["ctrl"]=list(map(f32,rows[0]["ctrl"]))
            elif kind=="force":rows[0]["actuator_force_nm"][0]=100.;rows[0]["joint_force_nm"][0]=100.;rows[0]["on_force_cap"][0]=True
            elif kind=="warning":rows[0]["warnings"][0]=1
            else:rows[0]["before_qvel"][1]=self.c["challenge"]["starts"][0]["lateral_velocity_m_s"]
            path.write_text("".join(json.dumps(r)+"\n" for r in rows),encoding="utf-8",newline="\n")
            result=json.loads((trial/"result.json").read_text());result["hashes"]["trace"]=sha(path);put(trial/"result.json",result)
            worker=json.loads((folder/"worker-result.json").read_text());worker["trials"][1]=result;put(folder/"worker-result.json",worker)
            with self.assertRaises(ValueError):audit(folder,self.core_path,self.baseline)

    def test_rehashed_feedback_receipt_refuses(self):
        root=self.copied();folder=root/"physical";trial=folder/trial_plan(self.c)[4]["trial_id"]
        path=trial/"controller.jsonl";rows=[json.loads(line) for line in path.read_text().splitlines()]
        rows[0]["feedback"]["requested_angular_velocity_body_rad_s"][0]+=.1
        path.write_text("".join(json.dumps(r)+"\n" for r in rows),encoding="utf-8",newline="\n")
        result=json.loads((trial/"result.json").read_text());result["hashes"]["controller"]=sha(path);put(trial/"result.json",result)
        worker=json.loads((folder/"worker-result.json").read_text());worker["trials"][4]=result;put(folder/"worker-result.json",worker)
        with self.assertRaisesRegex(ValueError,"Scalar decision/memory replay"):
            audit(folder,self.core_path,self.baseline)

    def test_ranking_requires_two_complete_eligible_episodes(self):
        c=declaration();trials=[]
        for plan in trial_plan(c):
            i=plan["candidate_indices"][0];candidate=c["provider"]["candidates"][i]
            positive=i in (0,1,4)
            episode=dict(action_id=candidate["id"],outcome="positive" if positive else "negative",
                failure_code=None if positive else "tilt",metrics=dict(quality_m_s=.02 if i==4 else (0. if positive else None)))
            trials.append(dict(plan,episodes=[episode]))
        result=rank(trials,c)
        self.assertEqual(result["selected_feedback_index"],4)
        self.assertEqual(result["ranked_feedback_indices"],[4])
        trials[16]["episodes"][0].update(outcome="negative",failure_code="tilt",metrics=dict(quality_m_s=None))
        self.assertIsNone(rank(trials,c)["selected_feedback_index"])
        with self.assertRaises(ValueError):rank(trials[:-1],c)

    def test_crossed_plan_and_false_authority_refuse(self):
        for kind in ["plan","authority"]:
            root=self.copied();folder=root/"physical"
            path=folder/"worker-result.json" if kind=="authority" else folder/trial_plan(self.c)[0]["trial_id"]/"plan.json"
            value=json.loads(path.read_text())
            if kind=="authority":value["training_data_authority"]=True
            else:value["seed"]+=1
            put(path,value)
            with self.assertRaises(ValueError):audit(folder,self.core_path,self.baseline)


if __name__ == "__main__":unittest.main()
