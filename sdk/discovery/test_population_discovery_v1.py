"""Synthetic corruption controls and actual scalar/batched controller replay."""
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

from population_discovery_task_v1 import declaration, population, plans, LiveBlock, summarize, select, sha, f32
from population_discovery_v1 import preflight
from audit_population_discovery_v1 import compact_trial, verify_full_projection
from audit_gpu_motor_effectiveness import audit_trial as full_audit
from audit_gpu_batch_execution import SECTIONS, same_bits
from repertoire_control import RepertoireController
from motor_effectiveness_task import condition_inputs
import test_gpu_repertoire_v2 as fixtures


def put(path, value):
    path.write_text(json.dumps(value, allow_nan=False, separators=(",", ":")), encoding="utf-8", newline="\n")


def put_lines(path, rows):
    path.write_text("".join(json.dumps(row, allow_nan=False, separators=(",", ":")) + "\n" for row in rows), encoding="utf-8", newline="\n")


class PopulationControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass()
        cls.f = fixtures.RepertoireControls
        cls.core, cls.oracle = cls.f.core, cls.f.oracle
        cls.core_path, cls.baseline = cls.f.core_path, cls.f.baseline
        cls.c = declaration()
        cls.c["outer_steps"] = cls.c["challenge"]["canaries"]["outer_steps"] = 2
        cls.plan = plans(cls.c, "canaries")[0]
        cls.compiled, cls.xml, cls.spec = condition_inputs(cls.core_path, cls.c, "nominal")
        cls.metadata = copy.deepcopy(cls.f.metadata)
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("population-synthetic-" + uuid.uuid4().hex)
        cls.root.mkdir()
        cls.folder = cls.root / "full"
        cls.folder.mkdir()
        cls.controls, cls.trace, cls.compact = [], [], []
        cls.blocks = []
        native = [cls.f.native(cls.plan, cell) for cell in range(cls.plan["nworld"])]
        batch = RepertoireController(cls.core, cls.compiled, cls.c, cls.plan["candidate_indices"])
        live = LiveBlock(cls.c, cls.plan, cls.spec)
        try:
            with patch.object(mujoco, "MjModel", side_effect=AssertionError("Synthetic world")), \
                    patch.object(mujoco, "MjData", side_effect=AssertionError("Synthetic data")):
                for outer in range(2):
                    rows = batch.step([cls.f.observations(n, outer) for n in native])
                    for cell, row in enumerate(rows):
                        n = copy.deepcopy(native[cell])
                        n["time_s"] = outer*5*cls.c["timestep_s"]
                        row.update(backend="gpu", cell=cell, outer_step=outer, native_observation=n)
                    raw = []
                    for sub in range(5):
                        for cell, row in enumerate(rows):
                            n = native[cell]
                            raw.append(dict(backend="gpu", cell=cell, step=outer*5+sub+1,
                                before_qpos=n["qpos"], before_qvel=n["qvel"], qpos=n["qpos"], qvel=n["qvel"],
                                ctrl=list(map(f32, row["native_targets"])), actuator_force_nm=[.01]*8, joint_force_nm=[.01]*8,
                                on_force_cap=[False]*8, time_s=(outer*5+sub+1)*cls.c["timestep_s"], contacts=n["contacts"],
                                batch_contacts=cls.plan["nworld"]*4, nefc=12, overflow=0, warnings=[]))
                    cls.blocks.append((copy.deepcopy(rows), copy.deepcopy(raw)))
                    cls.controls.extend(rows)
                    cls.trace.extend(raw)
                    cls.compact.extend(live.reduce(rows, raw))
        finally:
            batch.close()
        cls.timings = [dict(outer_step=i, measured=True, **{k:.01 for k in SECTIONS}, outer_total_s=.1) for i in range(2)]
        put(cls.folder / "plan.json", cls.plan)
        for name, rows in [("controller", cls.controls), ("trace", cls.trace), ("compact", cls.compact), ("timing", cls.timings)]:
            put_lines(cls.folder / (name + ".jsonl"), rows)
        result = dict(cls.plan, completed=True, setup_s=.1, graph_capture_s=.1,
            outer_rows=8, internal_rows=40, episodes=summarize(cls.compact, cls.c, cls.plan, cls.spec),
            hashes={name:sha(cls.folder / (name + ".jsonl")) for name in ("controller", "trace", "compact", "timing")},
            stream_bytes={name:(cls.folder / (name + ".jsonl")).stat().st_size for name in ("controller", "trace", "compact", "timing")})
        put(cls.folder / "result.json", result)

    def damage_live(self, change):
        controls, raw = copy.deepcopy(self.blocks[0])
        change(controls, raw)
        with self.assertRaises(ValueError):
            LiveBlock(self.c, self.plan, self.spec).reduce(controls, raw)

    def damage_compact(self, change):
        rows = copy.deepcopy(self.compact)
        change(rows)
        with self.assertRaises(ValueError):
            summarize(rows, self.c, self.plan, self.spec)

    def test_01_population_is_joint_stratified_and_immutable(self):
        rows = population()
        self.assertEqual(len(rows), 64)
        self.assertIsNone(rows[0]["factor"])
        self.assertEqual(len({tuple(r["ordered_coefficients"]) for r in rows}), 64)
        for axis in range(8):
            self.assertEqual(sorted(round((r["ordered_coefficients"][axis]+.25)*126-.5) for r in rows[1:]), list(range(63)))
        self.assertEqual(rows, declaration()["challenge"]["population"])

    def test_02_plans_cover_every_candidate_and_keep_reserved_starts_closed(self):
        c = declaration()
        search = plans(c, "population")
        self.assertEqual(sum(p["nworld"] for p in search), 256)
        self.assertEqual(sum(p["nworld"] for p in plans(c, "canaries")), 16)
        self.assertEqual({p["initial_native_lateral_velocity_m_s"] for p in search}, {.001, .003})
        for condition in ("nominal", "left_075"):
            for start in ("train_001", "train_003"):
                self.assertEqual([i for p in search if (p["condition_id"], p["start_id"]) == (condition, start) for i in p["candidate_indices"]], list(range(64)))

    def test_03_actual_preflight_constructs_zero_worlds(self):
        result = preflight(self.core_path, self.baseline)
        self.assertEqual((result["world_build_count"], result["solver_steps"]), (0, 0))
        self.assertEqual(result["planned_population_worlds"], 256)

    def test_04_full_canary_scalar_replay_matches_compact_metrics(self):
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("Reader world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Reader data")):
            full = full_audit(self.folder, self.plan, self.c, self.spec, self.compiled, self.metadata, self.oracle)
            reduced = compact_trial(self.folder, self.plan, self.c, self.spec)
            verify_full_projection(self.folder, self.plan)
        self.assertTrue(same_bits(full["metrics"], [e["metrics"] for e in reduced["episodes"]]))
        self.assertTrue(all(e["qualification_requires_fresh_full_capture"] for e in reduced["episodes"]))

    def test_05_missing_internal_sample_refuses(self):
        self.damage_live(lambda controls, raw: raw.pop())

    def test_06_crossed_world_refuses(self):
        self.damage_live(lambda controls, raw: raw[0].update(cell=1))

    def test_07_solver_input_change_refuses(self):
        self.damage_live(lambda controls, raw: raw[0]["ctrl"].__setitem__(0, 99.))

    def test_08_native_state_discontinuity_refuses(self):
        self.damage_live(lambda controls, raw: raw[0].update(before_qpos=[1.]*15))

    def test_09_capacity_and_force_corruptions_refuse(self):
        for change in (lambda controls, raw: raw[0].update(overflow=1),
                       lambda controls, raw: raw[0].update(actuator_force_nm=[1e6]*8),
                       lambda controls, raw: raw[0].update(joint_force_nm=[math.nan]*8)):
            with self.subTest(change=repr(change)):
                self.damage_live(change)

    def test_10_native_clock_change_refuses(self):
        self.damage_live(lambda controls, raw: raw[0].update(time_s=.9))

    def test_11_quaternion_and_contact_corruptions_refuse(self):
        for change in (lambda controls, raw: raw[0].update(qpos=[0.]*15),
                       lambda controls, raw: raw[0]["contacts"][0].update(world=1),
                       lambda controls, raw: raw[0]["contacts"].pop()):
            with self.subTest(change=repr(change)):
                self.damage_live(change)

    def test_12_missing_compact_trial_rows_refuse(self):
        self.damage_compact(lambda rows: rows.pop())

    def test_13_crossed_candidate_identity_refuses(self):
        self.damage_compact(lambda rows: rows[0].update(candidate_id="joint_population_01"))

    def test_14_compact_boundary_jump_refuses(self):
        self.damage_compact(lambda rows: rows[4].update(prepared_qpos=[1.]*15))

    def test_15_compact_nonfinite_and_incomplete_vectors_refuse(self):
        for change in (lambda rows: rows[0].update(native_targets=[math.nan]*8),
                       lambda rows: rows[0].update(completed_qvel=[0.]*13),
                       lambda rows: rows[0]["samples"][0].update(force_cap_count=9)):
            with self.subTest(change=repr(change)):
                self.damage_compact(change)

    def test_16_compact_clocks_and_endpoint_joins_refuse(self):
        for change in (lambda rows: rows[0].update(prepared_time_s=1.),
                       lambda rows: rows[0]["samples"][0].update(time_s=1.),
                       lambda rows: rows[0]["samples"][-1].update(height_m=99.)):
            with self.subTest(change=repr(change)):
                self.damage_compact(change)

    def test_17_rehashed_false_outcome_refuses(self):
        folder = self.root / uuid.uuid4().hex
        shutil.copytree(self.folder, folder)
        result = json.loads((folder / "result.json").read_text())
        result["episodes"][0]["velocity_error_m_s"] += 1.
        put(folder / "result.json", result)
        with self.assertRaises(ValueError):
            compact_trial(folder, self.plan, self.c, self.spec)
        rows = copy.deepcopy(self.compact)
        rows[0]["native_targets"][0] += .01
        put_lines(folder / "compact.jsonl", rows)
        with self.assertRaises(ValueError):
            verify_full_projection(folder, self.plan)

    def test_18_expected_failure_keeps_whole_episode_and_censors_quality(self):
        rows = copy.deepcopy(self.compact)
        rows[0]["samples"][0]["tilt_rad"] = .7
        episodes = summarize(rows, self.c, self.plan, self.spec)
        self.assertEqual(len(episodes), 4)
        self.assertFalse(episodes[0]["eligible"])
        self.assertEqual(episodes[0]["failure_codes"], ["tilt"])
        self.assertEqual(episodes[0]["first_failure_native_step"], 1)
        self.assertIsNone(episodes[0]["velocity_error_m_s"])

    def selection_fixture(self, eligible):
        c = declaration()
        trials = []
        for plan in plans(c, "population"):
            trials.append(dict(plan=plan, episodes=[dict(candidate_index=i,
                candidate_id=c["provider"]["candidates"][i]["id"], condition_id=plan["condition_id"],
                start_id=plan["start_id"], eligible=eligible, failure_codes=[] if eligible else ["tilt"],
                velocity_error_m_s=(.2 if i == 0 else .1) if eligible else None) for i in plan["candidate_indices"]]))
        return c, trials

    def test_19_incomplete_selection_refuses_and_all_negative_stays_empty(self):
        c, trials = self.selection_fixture(False)
        self.assertTrue(all(not r["shortlist_candidate_indices"] for r in select(trials, c)["conditions"]))
        with self.assertRaises(ValueError):
            select(trials[:-1], c)
        trials[0]["episodes"][0]["start_id"] = "reserved"
        with self.assertRaises(ValueError):
            select(trials, c)

    def test_20_selection_keeps_ties_diverse_and_requires_baseline_gain(self):
        c, trials = self.selection_fixture(True)
        result = select(trials, c)
        for row in result["conditions"]:
            self.assertEqual(row["ranked_candidate_indices"], list(range(1, 64)))
            self.assertEqual(row["shortlist_candidate_indices"][0], 1)
            self.assertEqual(len(row["shortlist_candidate_indices"]), 2)
        for trial in trials:
            for episode in trial["episodes"]:
                episode["velocity_error_m_s"] = .2
        self.assertTrue(all(not row["shortlist_candidate_indices"] for row in select(trials, c)["conditions"]))


if __name__ == "__main__":
    unittest.main()
