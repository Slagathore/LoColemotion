"""Synthetic native streams, independent replay and confirmation refusal controls."""
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
import test_cpu_body_height_discovery as prior
import test_gpu_repertoire_v2 as fixtures
from test_gpu_motor_effectiveness import put
import cpu_height_confirmation_task as task
from cpu_body_height_confirmation import preflight
from audit_cpu_body_height_confirmation import audit
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from gpu_quadruped_model import FLAGS, sha, f32


class ConfirmationControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass();cls.f=fixtures.RepertoireControls
        cls.core_path,cls.baseline=cls.f.core_path,cls.f.baseline
        cls.c=dict(task.declaration(),outer_steps=2,synthetic=True)
        cls.root=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("cpu-height-confirmation-fixture-"+uuid.uuid4().hex)
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
            results=[prior.CpuBodyHeightControls.make_trial.__func__(proxy,cls.folder/p["trial_id"],p) for p in task.trial_plan(cls.c)]
            put(cls.folder/"worker-result.json",dict(ok=True,synthetic=True,ledger_scope=cls.c["ledger_scope"],
                status="complete_native_cpu_body_height_confirmation",controller_sessions_closed=True,total_wall_s=.1,
                constructed_cpu_worlds=12,constructed_gpu_worlds=0,trials=results,**{k:False for k in FLAGS}))
            cls.result=audit(cls.folder,cls.core_path,cls.baseline)

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in controls"))
            guard.start();self.addCleanup(guard.stop)

    def copied(self):
        root=self.root.parent/("cpu-height-confirmation-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.root,root);return root

    def verify(self,root):return audit(root/"physical",self.core_path,self.baseline)

    def rehash(self,root,index,name):
        folder=root/"physical";trial=folder/task.trial_plan(self.c)[index]["trial_id"]
        result=json.loads((trial/"result.json").read_text());result["hashes"][name]=sha(trial/(name+".jsonl"));put(trial/"result.json",result)
        worker=json.loads((folder/"worker-result.json").read_text());worker["trials"][index]=result;put(folder/"worker-result.json",worker)

    def scored(self):
        trials=copy.deepcopy(self.result["trials"])
        for trial in trials:
            trial["episodes"][0]["metrics"]["quality_m_s"]=-.1 if trial["candidate_indices"] == [2] else -.2
        return trials

    def test_twelve_fresh_roles_fixed_selection_and_no_fitting(self):
        c=task.declaration();plans=task.trial_plan(c)
        self.assertEqual(len({p["trial_id"] for p in plans}),12)
        self.assertEqual(c["outer_steps"],1440);self.assertEqual(c["challenge"]["horizon_s"],12.)
        self.assertEqual([p["candidate_indices"][0] for p in plans],[0,1,2]*4)
        self.assertEqual({p["seed"] for p in plans},{104232200})
        self.assertTrue(all(p["partition"] == "development_confirmation" and not p["training_data_authority"] for p in plans))
        self.assertTrue(all(c[k] is False for k in FLAGS))
        self.assertEqual(c["provider"],task.parent_declaration()["provider"])
        self.assertEqual(c["selection"],task.parent_declaration()["selection"])

    def test_real_abi_preflight_opens_no_world(self):
        value=preflight(self.core_path,self.baseline)
        self.assertEqual((value["world_build_count"],value["solver_steps"]),(0,0))
        self.assertEqual((value["planned_cpu_worlds"],value["planned_controller_rows"],value["planned_internal_rows"]),(12,17280,86400))

    def test_complete_reader_replays_both_conditions_and_all_roles(self):
        result=self.result
        self.assertEqual((result["controller_rows"],result["internal_rows"]),(24,120))
        self.assertEqual((result["eligible_episodes"],result["negative_episodes"]),(12,0))
        self.assertTrue(all(result[k] is False for k in FLAGS))
        self.assertFalse(result["controller_selection_authority"])
        self.assertEqual(result["confirmation"]["pair_count"],8)
        self.assertTrue(all(p["quality_change_if_both_eligible_m_s"] is None for p in result["confirmation"]["pairs"]))
        self.assertIsNone(result["confirmation"]["nominal_quality_at_least_baseline_on_both"])

    def test_nominal_and_degraded_profile_crossing_refused(self):
        for kind in ["identity","force","xml"]:
            root=self.copied();directory=root/"physical/models/nominal"
            if kind == "xml":shutil.copyfile(root/"physical/models/left_075/model.xml",directory/"model.xml")
            else:
                path=directory/"native-model.json";value=json.loads(path.read_text())
                if kind == "identity":value["condition_id"]="left_075"
                else:value["actuator_profile"]["forcerange"][0][0] *= .75
                put(path,value)
            with self.assertRaises(ValueError):self.verify(root)

    def test_missing_population_dtype_and_input_binding_refused(self):
        for kind in ["trial","condition","dtype","input"]:
            root=self.copied();folder=root/"physical"
            if kind == "trial":(folder/task.trial_plan(self.c)[0]["trial_id"]).rename(root/"retained-missing-trial")
            elif kind == "condition":(folder/"models/nominal").rename(root/"retained-missing-model")
            else:
                path=folder/"models/nominal/native-model.json";value=json.loads(path.read_text())
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

    def test_rehashed_height_decision_corruption_refused(self):
        root=self.copied();trial=root/"physical"/task.trial_plan(self.c)[8]["trial_id"]
        path=trial/"controller.jsonl";rows=[json.loads(s) for s in path.read_text().splitlines()]
        rows[0]["feedback"]["height_control"]["target_height_m"] += .1
        path.write_text("".join(json.dumps(row)+"\n" for row in rows),encoding="utf-8",newline="\n")
        self.rehash(root,8,"controller")
        with self.assertRaisesRegex(ValueError,"Scalar decision/memory replay"):self.verify(root)

    def test_healthy_regression_censoring_and_no_reselection(self):
        trials=self.scored();result=task.assess(trials,self.c)
        self.assertTrue(result["nominal_quality_at_least_baseline_on_both"])
        trials[8]["episodes"][0]["metrics"]["quality_m_s"]=-.3
        result=task.assess(trials,self.c)
        self.assertFalse(result["nominal_quality_at_least_baseline_on_both"])
        self.assertEqual(result["selected_candidate_index"],2);self.assertFalse(result["selection_changed"])
        trials[8]["episodes"][0].update(outcome="negative",failure_code="tilt",metrics=dict(quality_m_s=None))
        result=task.assess(trials,self.c)
        self.assertIsNone(result["nominal_quality_at_least_baseline_on_both"])
        self.assertEqual(result["conditions"][1]["selected_eligible"],1)
        pairs=[p for p in result["pairs"] if p["selected_trial"] == trials[8]["trial_id"]]
        self.assertTrue(all(p["eligibility_change"] == -1 and p["quality_change_if_both_eligible_m_s"] is None for p in pairs))
        self.assertFalse(result["noninferiority_authority"])

    def test_comparison_population_nonfinite_quality_and_lineage_refused(self):
        trials=self.scored()
        with self.assertRaises(ValueError):task.assess(trials[:-1],self.c)
        trials[0]["episodes"][0]["metrics"]["quality_m_s"]=float("nan")
        with self.assertRaises(ValueError):task.assess(trials,self.c)
        with patch.object(task,"PREDECESSOR_SHA","0"*64):
            with self.assertRaises(ValueError):task.declaration()


if __name__ == "__main__":unittest.main()
