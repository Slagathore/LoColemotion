"""Zero-world graph scheduling, full-route reader and adversarial controls."""
import copy
import json
import os
from pathlib import Path
import shutil
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

import mujoco
import numpy as np

import test_portable_search as fixtures
from gpu_batch_execution import (
    declaration, trial_plan, preflight, SubstepHistory, integration_sequence,
    checked_snapshot, CAPTURE_FIELDS, trace_rows, ROOT, FLAGS, sha, bridge,
)
from audit_gpu_batch_execution import audit, audit_trial, timing_summary, SECTIONS
from portable_search_control import Controller
from portable_batch_control import BatchController


class Array:
    """In-memory stand-in: graph schedule tests never allocate a native world."""
    def __init__(self, values):
        self.values = np.asarray(values)
        self.shape = self.values.shape
        self.dtype = self.values.dtype
        self.device = "synthetic"

    def __getitem__(self, index):
        return Array(self.values[index])

    def numpy(self):
        return self.values.copy()


class FakeWarp:
    @staticmethod
    def empty(shape, dtype, device):
        return Array(np.empty(shape, dtype))

    @staticmethod
    def copy(target, source):
        target.values[...] = source.values


class GpuBatchControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = declaration()
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("gpu-batch-synthetic-" + uuid.uuid4().hex)
        cls.root.mkdir()
        fixture_c = copy.deepcopy(cls.c)
        with patch.object(fixtures, "contract", return_value=fixture_c):
            fixtures.PortableSearchControls.setUpClass()
        cls.fixture = fixtures.PortableSearchControls
        cls.core = cls.fixture.core
        cls.compiled = cls.fixture.compiled
        cls.spec = cls.fixture.spec
        cls.c.update(outer_steps=2, warmup_outer_steps=1)
        cls.parent = cls.root / "complete"
        cls.folder = cls.parent / "physical"
        cls.folder.mkdir(parents=True)
        def put(path, value):
            path.write_text(json.dumps(value, allow_nan=False), encoding="utf-8", newline="\n")
        put(cls.parent / "declaration.json", dict(contract=cls.c, synthetic=True))
        (cls.folder / "model.xml").write_text(cls.fixture.xml, encoding="utf-8", newline="\n")
        put(cls.folder / "compiled.json", cls.compiled)
        put(cls.folder / "inputs.json", cls.spec)
        cls.metadata = dict(model_sha256=sha(cls.folder / "model.xml"), compiled_sha256=sha(cls.folder / "compiled.json"),
            inputs_sha256=sha(cls.folder / "inputs.json"), ordered_bodies=cls.fixture.names,
            body_rootid=[0] + [1] * 9, observation_stage="prepared_before_control",
            force_stage="completed_step_before_next_prepare")
        put(cls.folder / "native-model.json", cls.metadata)
        trials = []
        for plan in trial_plan(cls.c):
            count = plan["nworld"]
            directory = cls.folder / plan["trial_id"]
            directory.mkdir()
            put(directory / "plan.json", plan)
            controllers = [Controller(cls.core, cls.compiled, cls.c, i) for i in plan["candidate_indices"]]
            batch = BatchController(cls.core, cls.compiled, cls.c, plan["candidate_indices"])
            controls, raw = [], []
            try:
                for outer in range(2):
                    natives = []
                    observations = []
                    for cell in range(count):
                        native = cls.fixture.native("gpu", cell % 4)
                        native["time_s"] = outer * 5 * cls.c["timestep_s"]
                        for i, contact in enumerate(native["contacts"]):
                            contact.update(world=cell, native_index=4 * cell + i)
                        natives.append(native)
                        observations.append(cls.fixture.observations(native, outer))
                    rows = batch.step(observations) if plan["arm"] == "batch_graph" else [
                        controller.step(*obs) for controller, obs in zip(controllers, observations, strict=True)]
                    for cell, row in enumerate(rows):
                        row.update(backend="gpu", cell=cell, outer_step=outer, native_observation=natives[cell])
                        controls.append(row)
                    for sub in range(5):
                        for cell, row in enumerate(rows):
                            native = natives[cell]
                            raw.append(dict(backend="gpu", cell=cell, step=5 * outer + sub + 1,
                                before_qpos=native["qpos"], before_qvel=native["qvel"], qpos=native["qpos"], qvel=native["qvel"],
                                ctrl=np.asarray(row["native_targets"], np.float32).astype(float).tolist(),
                                actuator_force_nm=[0.] * 8, joint_force_nm=[0.] * 8, on_force_cap=[False] * 8,
                                time_s=(5 * outer + sub + 1) * cls.c["timestep_s"], contacts=native["contacts"],
                                batch_contacts=count * 4, nefc=12, overflow=0, warnings=[]))
            finally:
                batch.close()
                for controller in controllers:
                    controller.close()
            timings = [dict(outer_step=i, measured=bool(i), **{name: .01 for name in SECTIONS}, outer_total_s=.1) for i in range(2)]
            for name, rows in [("controller", controls), ("trace", raw), ("timing", timings)]:
                (directory / (name + ".jsonl")).write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8", newline="\n")
            result = dict(plan, completed=True, setup_s=.1, graph_capture_s=.1 if plan["arm"] == "batch_graph" else 0.,
                          outer_rows=count * 2, internal_rows=count * 10,
                          hashes={name: sha(directory / (name + ".jsonl")) for name in ["controller", "trace", "timing"]})
            put(directory / "result.json", result)
            trials.append(result)
        worlds = sum(p["nworld"] for p in trial_plan(cls.c))
        put(cls.folder / "worker-result.json", dict(ok=True, synthetic=True, trials=trials,
            constructed_gpu_worlds=worlds, cpu_readback_views=worlds, stepped_cpu_worlds=0,
            controller_sessions_closed=True, **{k: False for k in FLAGS}))

    def mutated_trial(self, stream, change):
        plan = trial_plan(self.c)[1]
        folder = self.root / uuid.uuid4().hex
        shutil.copytree(self.folder / plan["trial_id"], folder)
        path = folder / (stream + ".jsonl")
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        change(rows)
        path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8", newline="\n")
        result = json.loads((folder / "result.json").read_text())
        result["hashes"][stream] = sha(path)
        (folder / "result.json").write_text(json.dumps(result))
        return folder, plan

    def assert_bad_trial(self, stream, change):
        folder, plan = self.mutated_trial(stream, change)
        with self.assertRaises(ValueError):
            audit_trial(folder, plan, self.c, self.spec, self.compiled, self.metadata, self.core)

    def test_complete_reader_replays_all_cells_without_worlds(self):
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("data")):
            result = audit(self.folder, self.core_path, self.baseline)
        self.assertTrue(result["synthetic"])
        self.assertEqual(result["constructed_gpu_worlds"], 126)
        self.assertEqual(result["controller_rows"], 252)
        self.assertEqual(result["internal_rows"], 1260)
        self.assertEqual([r["scalar_over_batch_ratio"] for r in result["comparisons"]], [1.] * 3)

    def test_actual_preflight_has_zero_worlds_and_exact_trial_plan(self):
        self.assertEqual(preflight(self.core_path, self.baseline)["world_build_count"], 0)
        plan = trial_plan(declaration())
        self.assertEqual(len(plan), 18)
        self.assertEqual(sum(row["nworld"] for row in plan), 126)
        self.assertEqual([p["arm"] for p in plan[:6]], ["scalar_direct", "batch_graph", "batch_graph", "scalar_direct", "scalar_direct", "batch_graph"])
        with self.assertRaisesRegex(ValueError, "runtime binding"):
            preflight(self.baseline, self.core_path)

    def test_graph_schedule_captures_forces_before_prepare_and_isolates_slots(self):
        data = SimpleNamespace(**{name: Array(np.zeros((2, 1), np.float32)) for name in CAPTURE_FIELDS if "." not in name})
        data.contact = SimpleNamespace(**{name.split(".")[1]: Array(np.zeros((3, 1), np.float32)) for name in CAPTURE_FIELDS if "." in name})
        history = SubstepHistory(FakeWarp, data)
        events = []
        class Steps:
            @staticmethod
            def step1(model, native):
                events.append("prepare")
                native.sensordata.values[:] = 0.
            @staticmethod
            def step2(model, native):
                events.append("integrate")
                native.qpos.values[:] += 1.
                native.qvel.values[:] += 2.
                native.sensordata.values[:] = native.qpos.values
        with patch.object(Array, "numpy", side_effect=AssertionError("Host read inside graph")):
            integration_sequence(Steps, None, data, history)
        self.assertEqual(events, ["integrate", "prepare", "integrate", "prepare", "integrate", "prepare", "integrate", "prepare", "integrate"])
        self.assertEqual(history.buffers["before_qpos"].numpy()[:, 0, 0].tolist(), [0., 1., 2., 3., 4.])
        self.assertEqual(history.buffers["sensordata"].numpy()[:, 0, 0].tolist(), [1., 2., 3., 4., 5.])
        data.sensordata.values[:] = 0.
        self.assertEqual(history.buffers["sensordata"].numpy()[:, 1, 0].tolist(), [1., 2., 3., 4., 5.])

    def test_missing_crossed_and_stale_history_refuses(self):
        self.assert_bad_trial("trace", lambda rows: rows.pop())
        self.assert_bad_trial("trace", lambda rows: rows.reverse())
        self.assert_bad_trial("controller", lambda rows: rows.pop())
        self.assert_bad_trial("controller", lambda rows: rows[1]["request"]["memory"].update(rows[0]["request"]["memory"]))
        self.assert_bad_trial("trace", lambda rows: rows[1]["before_qpos"].__setitem__(0, .1))

    def test_force_input_clock_contact_and_capacity_corruptions_refuse(self):
        for field, value in [("actuator_force_nm", [999.] * 8), ("joint_force_nm", [1.] * 8),
                             ("overflow", 1), ("nefc", 999), ("time_s", 100.), ("ctrl", [99.] * 8)]:
            self.assert_bad_trial("trace", lambda rows, key=field, value=value: rows[0].__setitem__(key, value))
        self.assert_bad_trial("trace", lambda rows: rows[0]["contacts"][0].__setitem__("world", 5))
        self.assert_bad_trial("trace", lambda rows: rows[0]["contacts"].pop())
        self.assert_bad_trial("controller", lambda rows: rows[0]["request"]["state"]["ordered_contact_observations"][0].__setitem__("presence", False))

    def test_timing_denominator_partition_and_nonfinite_refuse(self):
        self.assert_bad_trial("timing", lambda rows: rows.reverse())
        self.assert_bad_trial("timing", lambda rows: rows.pop())
        self.assert_bad_trial("timing", lambda rows: rows[0].__setitem__("measured", True))
        self.assert_bad_trial("timing", lambda rows: rows[0].__setitem__("prepare_s", float("nan")))
        self.assert_bad_trial("timing", lambda rows: rows[0].__setitem__("outer_total_s", .001))

    def test_live_snapshot_capacity_nonfinite_and_crossed_world_refuse(self):
        arrays = {"nacon": np.array([1]), "nefc": np.array([0]), "overflow": np.array([0]),
            "contact.worldid": np.array([0]), "contact.geom": np.array([[0, 3]]), "contact.dist": np.array([0.]),
            "contact.pos": np.array([[0., 0., 0.]]), "contact.frame": np.array([np.eye(3)])}
        cfg = dict(self.c, naconmax=64)
        self.assertEqual(checked_snapshot(arrays, cfg, 1)["batch_contacts"], 1)
        for key, value in [("nacon", np.array([65])), ("nefc", np.array([129])), ("overflow", np.array([1])),
                           ("contact.worldid", np.array([1])), ("contact.dist", np.array([float("nan")]))]:
            with self.assertRaises(ValueError):
                checked_snapshot(dict(arrays, **{key: value}), cfg, 1)


if __name__ == "__main__":
    unittest.main()
