"""Complete synthetic two-stage reader controls with the real controller ABI."""
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
from motor_effectiveness_task import declaration, trial_plan, condition_inputs, expected_actuator_arrays, select_profiles
from gpu_motor_effectiveness import load_selection
from audit_gpu_motor_effectiveness import audit_phase, audit_trial, compare_confirmation
from gpu_quadruped_model import FLAGS, sha, f32
from repertoire_control import RepertoireController
from audit_gpu_batch_execution import SECTIONS


def put(path, value):
    path.write_text(json.dumps(value, allow_nan=False, separators=(",", ":")), encoding="utf-8", newline="\n")


class MotorRouteControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass()
        cls.f = fixtures.RepertoireControls
        cls.core, cls.oracle = cls.f.core, cls.f.oracle
        cls.core_path, cls.baseline = cls.f.core_path, cls.f.baseline
        cls.c = dict(declaration(), outer_steps=2, synthetic=True, training_data_authority=False)
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("motor-route-fixture-"+uuid.uuid4().hex)
        cls.root.mkdir(); (cls.root/"physical").mkdir()
        put(cls.root/"declaration.json", dict(contract=cls.c, synthetic=True))
        cls.models = {}
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("data")):
            cls.make_phase("discovery")
            cls.discovery = audit_phase(cls.root/"physical/discovery", cls.core_path, cls.baseline, "discovery")
            cls.selection = select_profiles(cls.discovery, cls.c)
            cls.make_phase("confirmation", cls.selection)
        put(cls.root/"discovery-audit.json", cls.discovery)
        put(cls.root/"selection.json", dict(selection=cls.selection, discovery_audit_sha256=sha(cls.root/"discovery-audit.json")))

    @classmethod
    def make_phase(cls, phase, selection=None):
        folder = cls.root/"physical"/phase
        folder.mkdir()
        plans = trial_plan(cls.c, phase, selection)
        for condition in cls.c["conditions"]:
            cid = condition["condition_id"]
            directory = folder/cid
            directory.mkdir()
            compiled, xml, spec = condition_inputs(cls.core_path, cls.c, cid)
            put(directory/"compiled.json", compiled); put(directory/"inputs.json", spec)
            (directory/"model.xml").write_text(xml, encoding="utf-8", newline="\n")
            metadata = dict(model_sha256=sha(directory/"model.xml"), compiled_sha256=sha(directory/"compiled.json"),
                inputs_sha256=sha(directory/"inputs.json"), ordered_bodies=cls.f.f.names, body_rootid=[0]+[1]*9,
                force_ranges=spec["force_ranges"], actuator_profile=expected_actuator_arrays(spec), condition_id=cid,
                observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")
            put(directory/"native-model.json", metadata)
            put(directory/"gpu-actuator-profile.json", {k: [np.asarray(expected_actuator_arrays(spec)[k], np.float32).tolist()]
                for k in ["gainprm", "biasprm", "forcerange"]})
            selected = [p for p in plans if p["condition_id"] == cid]
            results = [cls.make_trial(directory/p["trial_id"], p) for p in selected]
            put(directory/"worker-result.json", dict(ok=True, synthetic=True, phase=phase, condition_id=cid,
                status="complete_motor_effectiveness_condition", controller_sessions_closed=True, total_wall_s=.01,
                constructed_gpu_worlds=sum(p["nworld"] for p in selected), cpu_readback_views=sum(p["nworld"] for p in selected),
                stepped_cpu_worlds=0, trials=results, **{k: False for k in FLAGS}))
            cls.models[cid] = (compiled, spec, metadata)

    @classmethod
    def make_trial(cls, folder, plan):
        folder.mkdir(); put(folder/"plan.json", plan)
        natives = [cls.f.native(plan, cell) for cell in range(plan["nworld"])]
        controls, trace = [], []
        batch = RepertoireController(cls.core, cls.f.compiled, dict(cls.c, seed=plan["seed"]), plan["candidate_indices"])
        try:
            for outer in range(cls.c["outer_steps"]):
                rows = batch.step([cls.f.observations(n, outer) for n in natives])
                for cell, row in enumerate(rows):
                    native = copy.deepcopy(natives[cell]); native["time_s"] = outer*5*cls.c["timestep_s"]
                    row.update(backend="gpu", cell=cell, outer_step=outer, native_observation=native)
                    controls.append(row)
                for sub in range(5):
                    for cell, row in enumerate(rows):
                        native = natives[cell]
                        trace.append(dict(backend="gpu", cell=cell, step=5*outer+sub+1,
                            before_qpos=native["qpos"], before_qvel=native["qvel"], qpos=native["qpos"], qvel=native["qvel"],
                            ctrl=list(map(f32, row["native_targets"])), actuator_force_nm=[0.]*8, joint_force_nm=[0.]*8,
                            on_force_cap=[False]*8, time_s=(5*outer+sub+1)*cls.c["timestep_s"], contacts=native["contacts"],
                            batch_contacts=plan["nworld"]*4, nefc=12, overflow=0, warnings=[]))
        finally:
            batch.close()
        timing = [dict(outer_step=i, measured=True, **{key: .01 for key in SECTIONS}, outer_total_s=.1)
            for i in range(cls.c["outer_steps"])]
        for name, rows in [("controller", controls), ("trace", trace), ("timing", timing)]:
            (folder/(name+".jsonl")).write_text("".join(json.dumps(r, allow_nan=False)+"\n" for r in rows), encoding="utf-8", newline="\n")
        result = dict(plan, completed=True, setup_s=.01, graph_capture_s=.01,
            outer_rows=len(controls), internal_rows=len(trace), hashes={name: sha(folder/(name+".jsonl")) for name in ["controller", "trace", "timing"]})
        put(folder/"result.json", result)
        return result

    def setUp(self):
        self.world = patch.object(mujoco, "MjModel", side_effect=AssertionError("world"))
        self.data = patch.object(mujoco, "MjData", side_effect=AssertionError("data"))
        self.world.start(); self.data.start()
        self.addCleanup(self.world.stop); self.addCleanup(self.data.stop)

    def copied(self):
        folder = self.root.parent/("motor-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.root, folder)
        return folder

    def test_full_two_stage_reader_and_rotated_action_identity(self):
        self.assertEqual(self.discovery["constructed_gpu_worlds"], 90)
        self.assertEqual(self.discovery["controller_rows"], 180)
        self.assertEqual(self.discovery["internal_rows"], 900)
        self.assertEqual(self.discovery["eligible_episodes"], 90)
        for trial in self.discovery["trials"]:
            self.assertEqual([e["action_id"] for e in trial["episodes"]],
                [self.c["provider"]["candidates"][i]["id"] for i in trial["candidate_indices"]])
        confirmed = audit_phase(self.root/"physical/confirmation", self.core_path, self.baseline, "confirmation", self.selection)
        self.assertEqual((confirmed["constructed_gpu_worlds"], confirmed["controller_rows"], confirmed["internal_rows"]), (30, 60, 300))
        self.assertFalse(confirmed["training_data_authority"])
        comparison = compare_confirmation(confirmed, self.selection, self.c)
        self.assertFalse(comparison["finite_conditioning_value"])
        self.assertEqual(comparison["degraded_group_denominator"], 8)
        put(self.root/"confirmation-audit.json", confirmed)
        put(self.root/"comparison.json", comparison)

    def test_nonidentity_confirmation_indices_bind_to_executed_actions(self):
        selection = copy.deepcopy(self.selection)
        selection["conditions"]["left_075"]["executed_action_index"] = 8
        selection["shared"]["executed_action_index"] = 1
        plan = next(p for p in trial_plan(self.c, "confirmation", selection) if p["condition_id"] == "left_075")
        folder = self.root/"extra"/"left_075"/plan["trial_id"]
        folder.parent.mkdir(parents=True)
        self.make_trial(folder, plan)
        compiled, spec, metadata = self.models["left_075"]
        result = audit_trial(folder, plan, self.c, spec, compiled, metadata, self.oracle)
        self.assertEqual([e["action_id"] for e in result["episodes"]],
            [self.c["provider"]["candidates"][i]["id"] for i in plan["candidate_indices"]])

    def test_changed_model_or_gpu_profile_and_missing_condition_refuse(self):
        for kind in ["cpu", "gpu", "missing"]:
            folder = self.copied(); phase = folder/"physical/discovery"
            if kind == "missing":
                (phase/"right_075").rename(folder/"retained-removed-condition")
            else:
                path = phase/"left_075"/("native-model.json" if kind == "cpu" else "gpu-actuator-profile.json")
                record = json.loads(path.read_text())
                if kind == "cpu": record["actuator_profile"]["gainprm"][0][0] = 10.
                else: record["biasprm"][0][0][2] = -10.
                put(path, record)
            with self.assertRaisesRegex(ValueError, "profile|population"):
                audit_phase(phase, self.core_path, self.baseline, "discovery")

    def test_force_cap_and_continuity_corruption_fail_even_after_rehash(self):
        plan = trial_plan(self.c, "discovery")[2]
        compiled, spec, metadata = self.models[plan["condition_id"]]
        original = self.root/"physical/discovery"/plan["condition_id"]/plan["trial_id"]
        for kind in ["force", "state"]:
            folder = self.root.parent/("motor-trace-corruption-"+uuid.uuid4().hex)
            shutil.copytree(original, folder)
            rows = [json.loads(line) for line in (folder/"trace.jsonl").read_text().splitlines()]
            if kind == "force":
                rows[0]["actuator_force_nm"][0] = 100.
                rows[0]["joint_force_nm"][0] = 100.
                rows[0]["on_force_cap"][0] = True
            else: rows[0]["before_qpos"][0] += .01
            (folder/"trace.jsonl").write_text("".join(json.dumps(r)+"\n" for r in rows), encoding="utf-8", newline="\n")
            result = json.loads((folder/"result.json").read_text())
            result["hashes"]["trace"] = sha(folder/"trace.jsonl"); put(folder/"result.json", result)
            with self.assertRaisesRegex(ValueError, "Force cap|continuity"):
                audit_trial(folder, plan, self.c, spec, compiled, metadata, self.oracle)

    def test_worker_refuses_synthetic_or_crossed_selection_before_physics(self):
        with self.assertRaisesRegex(ValueError, "Selection replay"):
            load_selection(self.root/"selection.json", self.c)
        folder = self.copied()
        path = folder/"selection.json"; record = json.loads(path.read_text())
        record["discovery_audit_sha256"] = "0"*64; put(path, record)
        with self.assertRaisesRegex(ValueError, "Selection replay"):
            load_selection(path, self.c)


if __name__ == "__main__":
    unittest.main()
