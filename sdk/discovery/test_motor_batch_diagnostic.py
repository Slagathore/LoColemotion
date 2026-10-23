"""Zero-world route, population, paired-comparison and corruption controls."""
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
import test_gpu_motor_effectiveness as motor_fixtures
from motor_batch_diagnostic_task import declaration, trial_plan, comparison_pairs
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from gpu_motor_batch_diagnostic import preflight
from audit_motor_batch_diagnostic import audit, trajectory_difference
from gpu_quadruped_model import FLAGS, sha

put = motor_fixtures.put


class MatchedDiagnosticControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass()
        cls.f = fixtures.RepertoireControls
        cls.core, cls.oracle = cls.f.core, cls.f.oracle
        cls.core_path, cls.baseline = cls.f.core_path, cls.f.baseline
        cls.c = dict(declaration(), outer_steps=2, synthetic=True)
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("motor-matched-fixture-"+uuid.uuid4().hex)
        cls.root.mkdir(); (cls.root/"physical").mkdir()
        put(cls.root/"declaration.json", dict(contract=cls.c, synthetic=True))
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("data")):
            for layout in cls.c["diagnostic"]["layouts"]:
                directory = cls.root/"physical"/layout["id"]
                directory.mkdir()
                compiled, xml, spec = condition_inputs(cls.core_path, cls.c, "left_075")
                put(directory/"compiled.json", compiled); put(directory/"inputs.json", spec)
                (directory/"model.xml").write_text(xml, encoding="utf-8", newline="\n")
                metadata = dict(model_sha256=sha(directory/"model.xml"), compiled_sha256=sha(directory/"compiled.json"),
                    inputs_sha256=sha(directory/"inputs.json"), ordered_bodies=cls.f.f.names, body_rootid=[0]+[1]*9,
                    force_ranges=spec["force_ranges"], actuator_profile=expected_actuator_arrays(spec), condition_id="left_075",
                    observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")
                put(directory/"native-model.json", metadata)
                put(directory/"gpu-actuator-profile.json", {k: [np.asarray(expected_actuator_arrays(spec)[k], np.float32).tolist()]
                    for k in ["gainprm", "biasprm", "forcerange"]})
                plans = [p for p in trial_plan(cls.c) if p["layout"] == layout["id"]]
                results = [motor_fixtures.MotorRouteControls.make_trial.__func__(cls, directory/p["trial_id"], p) for p in plans]
                put(directory/"worker-result.json", dict(ok=True, synthetic=True, phase="matched_diagnostic",
                    condition_id="left_075", layout=layout["id"], status="complete_motor_batch_diagnostic_layout",
                    controller_sessions_closed=True, total_wall_s=.01,
                    constructed_gpu_worlds=sum(p["nworld"] for p in plans), cpu_readback_views=sum(p["nworld"] for p in plans),
                    stepped_cpu_worlds=0, trials=results, **{k: False for k in FLAGS}))
            cls.result = audit(cls.root/"physical", cls.core_path, cls.baseline)

    def setUp(self):
        for name in ["MjModel", "MjData", "mj_step", "mj_forward"]:
            trap = patch.object(mujoco, name, side_effect=AssertionError("No physical worlds in controls"))
            trap.start(); self.addCleanup(trap.stop)

    def copied(self):
        folder = self.root.parent/("motor-matched-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.root, folder)
        return folder

    def test_fixed_population_and_same_focus_seed_with_no_training_authority(self):
        c = declaration(); plans = trial_plan(c)
        self.assertEqual((len(plans), sum(p["nworld"] for p in plans)), (8, 48))
        self.assertEqual({p["seed"] for p in plans}, {104231700})
        self.assertEqual({p["candidate_indices"][1] for p in plans}, {6})
        self.assertTrue(all(not p["training_data_authority"] for p in plans))
        self.assertTrue(all(c[k] is False for k in FLAGS))
        self.assertEqual(len(comparison_pairs(c)), 16)
        self.assertEqual(len({p["trial_id"] for p in plans}), 8)

    def test_real_abi_preflight_constructs_no_worlds(self):
        result = preflight(self.core_path, self.baseline)
        self.assertEqual((result["world_build_count"], result["solver_steps"], result["planned_gpu_worlds"]), (0, 0, 48))

    def test_complete_reader_and_fixed_comparison_denominators(self):
        self.assertEqual((self.result["constructed_gpu_worlds"], self.result["controller_rows"], self.result["internal_rows"]), (48, 96, 480))
        self.assertEqual((self.result["eligible_episodes"], self.result["negative_episodes"]), (48, 0))
        self.assertEqual(len(self.result["comparisons"]), 16)
        self.assertFalse(self.result["training_data_authority"])
        self.assertFalse(self.result["controller_selection_authority"])
        for pair in self.result["comparisons"]:
            if pair["kind"] != "start_state":
                self.assertIsNone(pair["trajectory"]["qpos"]["first_differing_step"])

    def test_missing_layout_crossed_plan_and_authority_refuse(self):
        for kind in ["missing", "plan", "authority"]:
            folder = self.copied(); physical = folder/"physical"
            if kind == "missing":
                (physical/"repeat_three").rename(folder/"retained-missing-layout")
            elif kind == "authority":
                path = physical/"mixed_nine/worker-result.json"
                row = json.loads(path.read_text()); row["training_data_authority"] = True; put(path, row)
            else:
                path = physical/"mixed_nine/mixed_nine_start_002/plan.json"
                row = json.loads(path.read_text()); row["seed"] += 1; put(path, row)
            with self.assertRaises(ValueError): audit(physical, self.core_path, self.baseline)

    def test_changed_native_profile_and_rehashed_state_refuse(self):
        for kind in ["profile", "state"]:
            folder = self.copied(); physical = folder/"physical"
            if kind == "profile":
                path = physical/"mixed_nine/gpu-actuator-profile.json"
                row = json.loads(path.read_text()); row["gainprm"][0][0][0] = 10.; put(path, row)
            else:
                trial = physical/"mixed_nine/mixed_nine_start_002"
                path = trial/"trace.jsonl"
                rows = [json.loads(line) for line in path.read_text().splitlines()]
                rows[0]["before_qpos"][0] += .01
                path.write_text("".join(json.dumps(r)+"\n" for r in rows), encoding="utf-8", newline="\n")
                result = json.loads((trial/"result.json").read_text()); result["hashes"]["trace"] = sha(path)
                put(trial/"result.json", result)
                worker = json.loads((physical/"mixed_nine/worker-result.json").read_text())
                worker["trials"][0] = result; put(physical/"mixed_nine/worker-result.json", worker)
            with self.assertRaises(ValueError): audit(physical, self.core_path, self.baseline)

    def test_difference_reports_first_clock_and_all_fields_without_tolerance_regrading(self):
        rows = [dict(step=i+1, qpos=[0., 1.], qvel=[0.], ctrl=[0.], actuator_force_nm=[0.]) for i in range(3)]
        changed = copy.deepcopy(rows)
        changed[1]["qpos"][0] = 1.e-8; changed[2]["ctrl"][0] = .1
        result = trajectory_difference(rows, changed)
        self.assertEqual(result["qpos"]["first_differing_step"], 2)
        self.assertEqual(result["ctrl"]["first_differing_step"], 3)
        self.assertEqual(result["ctrl"]["maximum_absolute_difference"], .1)
        with self.assertRaises(ValueError): trajectory_difference(rows, changed[:-1])
        changed[0]["step"] = 2
        with self.assertRaises(ValueError): trajectory_difference(rows, changed)


if __name__ == "__main__":
    unittest.main()
