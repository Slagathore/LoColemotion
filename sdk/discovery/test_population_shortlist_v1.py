"""Real ABI, synthetic full-reader population and adversarial shortlist controls."""
import copy
import json
import math
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid

import mujoco
import numpy as np

import population_shortlist_task_v1 as task
from population_shortlist_task_v1 import declaration, synthetic_contract, plans, summarize, assess, LiveBlock, FLAGS, GATES, sha, f32
from population_shortlist_v1 import preflight, validate_launch_records
from audit_population_shortlist_v1 import audit, full_trial
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from repertoire_control import RepertoireController
from audit_gpu_batch_execution import SECTIONS
from test_population_discovery_v1 import put, put_lines
import test_gpu_repertoire_v2 as fixtures


class ShortlistControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass()
        cls.f = fixtures.RepertoireControls
        cls.core_path, cls.baseline = cls.f.core_path, cls.f.baseline
        cls.c = synthetic_contract(declaration())
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("shortlist-synthetic-"+uuid.uuid4().hex)
        cls.root.mkdir()
        cls.folder = cls.root / "challenge"
        cls.folder.mkdir()
        put(cls.root / "declaration.json", dict(contract=cls.c, synthetic=True, **{k:False for k in FLAGS}))
        cls.models, results = {}, []
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("Fixture world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Fixture data")), \
                patch.object(mujoco, "mj_step", side_effect=AssertionError("Fixture physics")):
            for condition in cls.c["conditions"]:
                cid = condition["condition_id"]
                directory = cls.folder / cid
                directory.mkdir()
                compiled, xml, spec = condition_inputs(cls.core_path, cls.c, cid)
                put(directory / "compiled.json", compiled)
                put(directory / "inputs.json", spec)
                (directory / "model.xml").write_text(xml, encoding="utf-8", newline="\n")
                arrays = expected_actuator_arrays(spec)
                metadata = dict(model_sha256=sha(directory / "model.xml"), inputs_sha256=sha(directory / "inputs.json"),
                    compiled_sha256=sha(directory / "compiled.json"), condition_id=cid,
                    ordered_bodies=cls.f.f.names, body_rootid=[0]+[1]*9, force_ranges=spec["force_ranges"],
                    actuator_profile=arrays, gpu_actuator_profile={k:np.asarray([arrays[k]],np.float32).tolist()
                        for k in ("gainprm", "biasprm", "forcerange")},
                    observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")
                put(directory / "native-model.json", metadata)
                cls.models[cid] = (compiled, spec, metadata)
                for plan in plans(cls.c):
                    if plan["condition_id"] == cid:
                        results.append(cls.make_trial(directory / plan["trial_id"], plan, compiled, spec))
            put(cls.folder / "worker-result.json", dict(ok=True, synthetic=True, phase="challenge", trials=results,
                constructed_gpu_worlds=0, cpu_readback_views=0, stepped_cpu_worlds=0,
                controller_sessions_closed=True, **{k:False for k in FLAGS}))
            cls.observed = audit(cls.folder, cls.core_path, cls.baseline, allow_synthetic=True)
        put(cls.root / "synthetic-audit.json", cls.observed)

    @classmethod
    def make_trial(cls, folder, plan, compiled, spec):
        folder.mkdir()
        put(folder / "plan.json", plan)
        put(folder / "worlds-opened.json", dict(native_gpu_worlds=0, trial_id=plan["trial_id"]))
        native = [cls.f.native(plan, cell) for cell in range(plan["nworld"])]
        controls, trace, compact = [], [], []
        batch = RepertoireController(cls.f.core, compiled, dict(cls.c, seed=plan["seed"]), plan["candidate_indices"])
        live = LiveBlock(cls.c, plan, spec)
        try:
            for outer in range(plan["outer_steps"]):
                rows = batch.step([cls.f.observations(n, outer) for n in native])
                for cell, row in enumerate(rows):
                    n = copy.deepcopy(native[cell]); n["time_s"] = outer*5*cls.c["timestep_s"]
                    row.update(backend="gpu", cell=cell, outer_step=outer, native_observation=n)
                raw = []
                for sub in range(5):
                    for cell, row in enumerate(rows):
                        n = native[cell]
                        raw.append(dict(backend="gpu", cell=cell, step=outer*5+sub+1,
                            before_qpos=n["qpos"], before_qvel=n["qvel"], qpos=n["qpos"], qvel=n["qvel"],
                            ctrl=list(map(f32,row["native_targets"])), actuator_force_nm=[.01]*8, joint_force_nm=[.01]*8,
                            on_force_cap=[False]*8, time_s=(outer*5+sub+1)*cls.c["timestep_s"], contacts=n["contacts"],
                            batch_contacts=plan["nworld"]*4, nefc=12, overflow=0, warnings=[]))
                controls.extend(rows); trace.extend(raw); compact.extend(live.reduce(rows,raw))
        finally:
            batch.close()
        timing = [dict(outer_step=i, measured=True, **{k:.01 for k in SECTIONS}, outer_total_s=.1)
            for i in range(plan["outer_steps"])]
        for name,rows in [("controller",controls),("trace",trace),("compact",compact),("timing",timing)]:
            put_lines(folder / (name+".jsonl"),rows)
        names = ["controller", "trace", "compact", "timing"]
        result = dict(plan, completed=True, setup_s=.1, graph_capture_s=.1,
            outer_rows=len(controls), internal_rows=len(trace), episodes=summarize(compact,cls.c,plan,spec),
            hashes={name:sha(folder / (name+".jsonl")) for name in names},
            stream_bytes={name:(folder / (name+".jsonl")).stat().st_size for name in names})
        put(folder / "result.json",result)
        return result

    def setUp(self):
        for name in ("MjModel", "MjData", "mj_step"):
            trap = patch.object(mujoco,name,side_effect=AssertionError("Control constructed physics"))
            trap.start(); self.addCleanup(trap.stop)

    def copied(self):
        path = self.root.parent / ("shortlist-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.root,path)
        return path / "challenge"

    def trial(self, folder):
        plan = plans(self.c)[0]
        return folder / plan["condition_id"] / plan["trial_id"], plan

    def rebind_trial(self, folder, directory, result):
        put(directory / "result.json",result)
        worker = json.loads((folder / "worker-result.json").read_text())
        index = next(i for i,t in enumerate(worker["trials"]) if t["trial_id"]==result["trial_id"])
        worker["trials"][index] = result
        put(folder / "worker-result.json",worker)

    def damage_stream(self, name, change):
        folder = self.copied(); directory, plan = self.trial(folder)
        file = directory / (name+".jsonl")
        rows = [json.loads(line) for line in file.read_text().splitlines()]
        change(rows); put_lines(file,rows)
        result = json.loads((directory / "result.json").read_text())
        result["hashes"][name] = sha(file); result["stream_bytes"][name] = file.stat().st_size
        self.rebind_trial(folder,directory,result)
        with self.assertRaises(ValueError):
            audit(folder,self.core_path,self.baseline,allow_synthetic=True)

    def launch_records(self):
        path = self.root.parent / ("shortlist-launch-record-fixture-"+uuid.uuid4().hex)
        path.mkdir(); folder = path / "challenge"; folder.mkdir()
        c = declaration(); source = "a"*40
        owner = dict(contract=c,synthetic=False,source_status=[],source_commit=source,**{k:False for k in FLAGS})
        put(path / "declaration.json",owner)
        gate = dict(ok=True,source_commit=source,declaration_sha256=sha(path / "declaration.json"),
            safety_controls={n:k for n,_,k in GATES},preflight=dict(world_build_count=0,solver_steps=0,planned_challenge_worlds=20))
        put(path / "gate-receipt.json",gate)
        consumed = dict(attempt_id=path.name,source_commit=source,gate_receipt_sha256=sha(path / "gate-receipt.json"),
            contract_sha256=sha(task.CONTRACT),planned_trials={"challenge":plans(c)})
        put(path / "consumed.json",consumed)
        return folder,c,owner,gate,consumed

    def test_01_selected_provenance_is_pinned_without_promotion(self):
        c = declaration()
        self.assertEqual(sha(task.PREDECESSOR),task.PREDECESSOR_SHA)
        self.assertEqual(c["challenge"]["selected_by_condition"],{"nominal":[8,18],"left_075":[55,27]})
        self.assertEqual(sum(k for _,_,k in GATES),128)
        self.assertTrue(all(c[k] is False for k in FLAGS))

    def test_02_complete_cross_condition_plan_preserves_envelopes(self):
        c = declaration(); p = plans(c)
        self.assertEqual((len(p),sum(x["nworld"] for x in p)),(4,20))
        self.assertTrue(all(x["candidate_indices"]==[0,8,18,55,27] and x["capture_mode"]=="full" and x["outer_steps"]==1440 for x in p))
        self.assertEqual({x["initial_native_lateral_velocity_m_s"] for x in p},{.001,.003})
        self.assertEqual({x["seed"] for x in p},{1061102})
        old = task.parent.declaration()
        for key in ("provider","selection","conditions","condition_model_sha256","runtime"):
            self.assertEqual(c[key],old[key])

    def test_03_actual_preflight_constructs_zero_worlds(self):
        r = preflight(self.core_path,self.baseline)
        self.assertEqual((r["world_build_count"],r["solver_steps"],r["planned_challenge_worlds"]),(0,0,20))

    def test_04_complete_full_reader_replays_every_synthetic_cell(self):
        r = self.observed
        self.assertEqual((r["constructed_gpu_worlds"],r["audited_cells"],r["full_trials_replayed"]),(0,20,4))
        self.assertEqual((r["controller_rows"],r["internal_rows"]),(40,200))
        self.assertTrue(r["synthetic"])
        self.assertFalse(r["full_capture_native_evidence_verified"])
        self.assertTrue(all(t["full_replay"]["projection_verified"] for t in r["trials"]))

    def test_05_synthetic_reader_cannot_claim_native_evidence(self):
        with self.assertRaisesRegex(ValueError,"not native evidence"):
            audit(self.folder,self.core_path,self.baseline)

    def test_06_missing_condition_or_trial_refuses(self):
        for condition in (False,True):
            folder = self.copied(); directory,plan = self.trial(folder)
            target = directory.parent if condition else directory
            target.rename(folder.parent / "retained-removed")
            with self.assertRaises(ValueError):audit(folder,self.core_path,self.baseline,allow_synthetic=True)

    def test_07_missing_full_stream_or_insufficient_byte_budget_refuses(self):
        folder = self.copied(); directory,plan = self.trial(folder)
        (directory / "trace.jsonl").unlink()
        result = json.loads((directory / "result.json").read_text())
        for k in ("hashes","stream_bytes"):result[k].pop("trace")
        self.rebind_trial(folder,directory,result)
        with self.assertRaisesRegex(ValueError,"full streams"):
            audit(folder,self.core_path,self.baseline,allow_synthetic=True)
        directory,plan = self.trial(self.folder)
        compiled,spec,meta = self.models[plan["condition_id"]]
        with self.assertRaisesRegex(ValueError,"byte budget"):
            full_trial(directory,plan,dict(self.c,maximum_trace_bytes_per_trial=1),spec,compiled,meta,self.f.oracle)

    def test_08_rehashed_false_controller_decision_refuses(self):
        self.damage_stream("controller",lambda rows:rows[0]["native_targets"].__setitem__(0,999.))

    def test_09_rehashed_force_or_state_corruption_refuses(self):
        for change in (lambda rows:rows[0]["actuator_force_nm"].__setitem__(0,1e6),
                       lambda rows:rows[0]["before_qpos"].__setitem__(0,.1)):
            self.damage_stream("trace",change)

    def test_10_rehashed_incomplete_horizons_refuse(self):
        for name in ("controller","trace","compact"):
            self.damage_stream(name,lambda rows:rows.pop())

    def test_11_crossed_candidate_identity_refuses(self):
        self.damage_stream("compact",lambda rows:rows[0].update(candidate_id="joint_population_55"))

    def test_12_crossed_seed_or_start_plan_refuses(self):
        for key,value in (("seed",0),("start_id","reserved")):
            folder = self.copied(); directory,plan = self.trial(folder)
            plan[key]=value;put(directory / "plan.json",plan)
            with self.assertRaises(ValueError):audit(folder,self.core_path,self.baseline,allow_synthetic=True)

    def test_13_native_actuator_profile_corruption_refuses(self):
        folder = self.copied(); directory,plan = self.trial(folder)
        file = directory.parent / "native-model.json"; r=json.loads(file.read_text())
        r["gpu_actuator_profile"]["gainprm"][0][0][0]+=1.;put(file,r)
        with self.assertRaisesRegex(ValueError,"model profile"):
            audit(folder,self.core_path,self.baseline,allow_synthetic=True)

    def test_14_false_or_nonfinite_quality_refuses(self):
        for value in (.01,math.nan):
            rows=copy.deepcopy(self.observed["trials"])
            e=rows[0]["episodes"][0];e.update(eligible=False,failure_codes=["tilt"],velocity_error_m_s=value)
            with self.assertRaisesRegex(ValueError,"quality censoring"):assess(rows,self.c)

    def test_15_missing_full_replay_or_projection_refuses(self):
        for key,value in (("projection_verified",False),("controller_rows",0),("internal_rows",0)):
            rows=copy.deepcopy(self.observed["trials"]);rows[0]["full_replay"][key]=value
            with self.assertRaisesRegex(ValueError,"complete full replay"):assess(rows,self.c)

    def test_16_prefix_failure_cannot_be_erased_by_later_state(self):
        rows=copy.deepcopy(self.observed["trials"])
        e=rows[0]["prefix_episodes"][0]
        e.update(eligible=False,failure_codes=["tilt"],velocity_error_m_s=None,first_failure_native_step=1)
        e["metrics"]["maximum_tilt_rad"]=.7
        with self.assertRaisesRegex(ValueError,"prefix failure"):assess(rows,self.c)

    def test_17_failed_baselines_have_no_numeric_gain_and_do_not_reselect(self):
        rows=copy.deepcopy(self.observed["trials"])
        for row in rows:
            e=row["episodes"][0]
            e.update(eligible=False,failure_codes=["tilt"],velocity_error_m_s=None,first_failure_native_step=6)
            e["metrics"]["maximum_tilt_rad"]=.7
        result=assess(rows,self.c)
        self.assertFalse(result["selection_changed"])
        self.assertEqual(result["fixed_candidate_indices"],[0,8,18,55,27])
        self.assertTrue(all(p["whole"]["baseline_minus_candidate_error_m_s"] is None for c in result["conditions"] for p in c["pairs"]))
        self.assertTrue(all(result[k] is False for k in FLAGS))

    def test_18_missing_control_or_nonzero_gate_world_refuses_launch(self):
        for kind in ("controls","worlds"):
            folder,c,owner,gate,consumed=self.launch_records()
            validate_launch_records(folder,c,"challenge")
            if kind=="controls":gate["safety_controls"].pop("provider")
            else:gate["preflight"]["world_build_count"]=1
            put(folder.parent / "gate-receipt.json",gate)
            consumed["gate_receipt_sha256"]=sha(folder.parent / "gate-receipt.json")
            put(folder.parent / "consumed.json",consumed)
            with self.assertRaises(ValueError):validate_launch_records(folder,c,"challenge")

    def test_19_changed_attempt_source_or_candidate_plan_refuses_launch(self):
        for kind in ("attempt","source","plan"):
            folder,c,owner,gate,consumed=self.launch_records()
            if kind=="attempt":consumed["attempt_id"]="another-attempt"
            elif kind=="source":consumed["source_commit"]="b"*40
            else:consumed["planned_trials"]["challenge"][0]["candidate_indices"][1]=1
            put(folder.parent / "consumed.json",consumed)
            with self.assertRaises(ValueError):validate_launch_records(folder,c,"challenge")

    def test_20_reserved_start_or_changed_horizon_or_selection_refuses(self):
        for field,value in (("starts",[dict(id="reserved",lateral_velocity_m_s=.0025)]),
                            ("outer_steps",120),("candidate_indices",[0,1,2,3,4])):
            d=task.expected_declaration();d[field]=value
            file=self.root.parent / ("shortlist-declaration-corruption-"+uuid.uuid4().hex+".json")
            put(file,d)
            with patch.object(task,"CONTRACT",file):
                with self.assertRaises(ValueError):declaration()


if __name__ == "__main__":
    unittest.main()
