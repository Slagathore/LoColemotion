"""Physical-parameter, causal split, selector and finite-comparison controls."""
import copy
import hashlib
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import mujoco
import numpy as np

import motor_effectiveness_task as task
from audit_gpu_motor_effectiveness import compare_confirmation
from gpu_motor_effectiveness import preflight


def synthetic_discovery(c):
    trials = []
    for plan in task.trial_plan(c, "discovery"):
        best = 4 if plan["condition_id"] == "nominal" else (1 if plan["condition_id"].startswith("left") else 8)
        episodes = [dict(group_id=plan["group_id"], action_id=c["provider"]["candidates"][a]["id"],
            outcome="positive", synthetic=True, metrics=dict(quality_m_s=-.07 if a == best else -.1))
            for a in plan["candidate_indices"]]
        trials.append(dict(plan, episodes=episodes))
    return dict(ok=True, phase="discovery", synthetic=True, reader_world_build_count=0, trials=trials)


def synthetic_confirmation(c, selection):
    trials = []
    for plan in task.trial_plan(c, "confirmation", selection):
        episodes = [dict(group_id=plan["group_id"], action_id=c["provider"]["candidates"][a]["id"],
            outcome="positive", synthetic=True, metrics=dict(quality_m_s={"baseline": -.2, "condition_known": -.1, "shared_profile": -.12}[role]))
            for role, a in zip(plan["role_order"], plan["candidate_indices"], strict=True)]
        trials.append(dict(plan, episodes=episodes))
    return dict(ok=True, phase="confirmation", synthetic=True, reader_world_build_count=0, training_data_authority=False, trials=trials)


class TaskControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.c = task.declaration()

    def setUp(self):
        self.world = patch.object(mujoco, "MjModel", side_effect=AssertionError("world"))
        self.data = patch.object(mujoco, "MjData", side_effect=AssertionError("data"))
        self.world.start(); self.data.start()
        self.addCleanup(self.world.stop); self.addCleanup(self.data.stop)

    def test_all_five_models_change_only_declared_gain_caps_and_name(self):
        _, nominal, nominal_spec = task.build_inputs(self.core, self.c)
        original = ET.fromstring(nominal)
        original_motors = list(original.findall("actuator/velocity"))
        for condition in task.CONDITIONS:
            compiled, xml, spec = task.condition_inputs(self.core, self.c, condition["condition_id"])
            self.assertEqual(hashlib.sha256(xml.encode()).hexdigest(), self.c["condition_model_sha256"][condition["condition_id"]])
            self.assertEqual(compiled["world_build_count"], 0)
            tree = ET.fromstring(xml)
            self.assertEqual(tree.attrib["model"], "sdk2_motor_effectiveness_v1_"+condition["condition_id"])
            tree.set("model", original.attrib["model"])
            count = 0
            for i, (motor, source) in enumerate(zip(tree.findall("actuator/velocity"), original_motors, strict=True)):
                factor = spec["effectiveness_factors"][i]
                count += int(factor != 1.)
                self.assertEqual(float(motor.attrib["kv"]), 10.*factor)
                self.assertEqual([float(x) for x in motor.attrib["forcerange"].split()],
                    [v*factor for v in nominal_spec["force_ranges"][i]])
                motor.set("kv", source.attrib["kv"]); motor.set("forcerange", source.attrib["forcerange"])
            self.assertEqual(count, 0 if condition["side"] == "none" else 4)
            self.assertEqual(ET.tostring(tree), ET.tostring(original))

    def test_native_and_gpu_parameter_identity_reject_wrong_transmission_or_derating(self):
        _, _, spec = task.condition_inputs(self.core, self.c, "left_075")
        expected = task.expected_actuator_arrays(spec)
        def model():
            return SimpleNamespace(nq=15, nv=14, nu=8, nbody=10, ngeom=10, njnt=9, nsensordata=16,
                opt=SimpleNamespace(timestep=task.bridge.INTERNAL_DT_S, integrator=mujoco.mjtIntegrator.mjINT_IMPLICITFAST),
                actuator=lambda i: SimpleNamespace(name=spec["ordered_actuators"][i]),
                joint=lambda i: SimpleNamespace(name=spec["ordered_joints"][i-1]),
                **{"actuator_"+k: np.asarray(v) for k, v in expected.items()})
        self.assertEqual(task.validate_native_profile(model(), spec), expected)
        for field, index, value in [("gainprm", (0, 0), 10.), ("biasprm", (0, 2), -10.),
                                    ("gear", (0, 0), -1.), ("forcerange", (0, 1), 6.5)]:
            bad = model(); getattr(bad, "actuator_"+field)[index] = value
            with self.assertRaisesRegex(ValueError, "actuator identity"):
                task.validate_native_profile(bad, spec)
        arrays = {k: np.asarray([expected[k]], np.float32) for k in ["gainprm", "biasprm", "forcerange"]}
        gpu = SimpleNamespace(**{"actuator_"+k: SimpleNamespace(numpy=lambda k=k: arrays[k]) for k in arrays})
        task.validate_gpu_profile(gpu, spec)
        arrays["gainprm"] = arrays["gainprm"].astype(np.float64)
        with self.assertRaisesRegex(ValueError, "GPU actuator"):
            task.validate_gpu_profile(gpu, spec)

    def test_actual_preflight_has_no_worlds_and_complete_two_stage_population(self):
        result = preflight(self.core, self.baseline)
        self.assertEqual(result["world_build_count"], 0)
        self.assertEqual(result["planned_gpu_worlds"], 120)
        discovery = task.trial_plan(self.c, "discovery")
        selection = task.select_profiles(synthetic_discovery(self.c), self.c)
        confirmation = task.trial_plan(self.c, "confirmation", selection)
        self.assertEqual(sum(p["nworld"] for p in discovery), 90)
        self.assertEqual(sum(p["nworld"] for p in confirmation), 30)
        self.assertFalse({p["seed"] for p in discovery} & {p["seed"] for p in confirmation})
        self.assertTrue(all(sorted(p["candidate_indices"]) == list(range(9)) for p in discovery))
        self.assertTrue(all(not p["training_data_authority"] for p in confirmation))
        self.assertTrue(all(p["source_start_family"] not in ["evaluation_"+str(i) for i in range(4)] for p in discovery+confirmation))

    def test_selector_uses_complete_discovery_and_retains_failed_candidates(self):
        screen = synthetic_discovery(self.c)
        selected = task.select_profiles(screen, self.c)
        self.assertEqual(selected["conditions"]["nominal"]["selected_action_index"], 4)
        self.assertEqual(selected["conditions"]["left_090"]["selected_action_index"], 1)
        self.assertEqual(selected["conditions"]["right_075"]["selected_action_index"], 8)
        self.assertEqual(selected["shared"]["selected_action_index"], 1)
        for trial in screen["trials"]:
            if trial["condition_id"] == "left_075":
                for episode in trial["episodes"]:
                    episode.update(outcome="negative", metrics=dict(quality_m_s=0.))
        selected = task.select_profiles(screen, self.c)
        self.assertIsNone(selected["conditions"]["left_075"]["selected_action_index"])
        self.assertEqual(selected["conditions"]["left_075"]["executed_action_index"], 0)
        self.assertIsNone(selected["shared"]["selected_action_index"])
        self.assertEqual(len(selected["shared"]["action_summaries"]), 9)

    def test_missing_crossed_confirmation_and_nonfinite_selection_inputs_refuse(self):
        for kind in ["phase", "trial", "episode", "group", "number"]:
            screen = synthetic_discovery(self.c)
            if kind == "phase": screen["phase"] = "confirmation"
            elif kind == "trial": screen["trials"].pop()
            elif kind == "episode": screen["trials"][0]["episodes"].pop()
            elif kind == "group": screen["trials"][0]["episodes"][0]["group_id"] = "evaluation_0"
            else: screen["trials"][0]["episodes"][0]["metrics"]["quality_m_s"] = float("nan")
            with self.assertRaises(ValueError): task.select_profiles(screen, self.c)

    def test_confirmation_requires_individual_and_healthy_guards_and_changed_policy(self):
        selected = task.select_profiles(synthetic_discovery(self.c), self.c)
        data = synthetic_confirmation(self.c, selected)
        before = copy.deepcopy(selected)
        result = compare_confirmation(data, selected, self.c)
        self.assertTrue(result["finite_conditioning_value"])
        self.assertEqual(result["oracle_baseline_gain_groups"], 8)
        self.assertEqual(selected, before)
        for cid in ["nominal", "left_075"]:
            changed = copy.deepcopy(data)
            trial = next(t for t in changed["trials"] if t["condition_id"] == cid)
            trial["episodes"][trial["role_order"].index("condition_known")]["metrics"]["quality_m_s"] = -.13
            self.assertFalse(compare_confirmation(changed, selected, self.c)["finite_conditioning_value"])
        for row in selected["conditions"].values():
            row["selected_action_index"] = row["executed_action_index"] = selected["shared"]["selected_action_index"]
        self.assertFalse(compare_confirmation(synthetic_confirmation(self.c, selected), selected, self.c)["finite_conditioning_value"])

    def test_a_failed_confirmation_arm_is_not_zero_score_success(self):
        selected = task.select_profiles(synthetic_discovery(self.c), self.c)
        data = synthetic_confirmation(self.c, selected)
        trial = data["trials"][3]
        episode = trial["episodes"][trial["role_order"].index("condition_known")]
        episode.update(outcome="negative", metrics=dict(quality_m_s=0.))
        result = compare_confirmation(data, selected, self.c)
        self.assertFalse(result["finite_conditioning_value"])
        self.assertIsNone(result["mean_degraded_oracle_minus_shared_m_s"])
        self.assertIsNone(result["groups"][3]["oracle_minus_baseline_m_s"])


if __name__ == "__main__":
    unittest.main()
