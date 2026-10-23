"""Zero-world scalar/batch conformance, including all retained v2 observations."""
import copy
import ctypes
from dataclasses import asdict
import json
import os
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

import mujoco
import test_portable_search as fixtures
from portable_batch_control import BatchController, pure_batch, values
from portable_search_control import ROOT, Controller, bridge, contract, inputs, sha
from sporespore_locomotion import LocomotionCore, LocomotionCoreError


def assert_bits(test, expected, actual, path="root"):
    if isinstance(expected, float):
        test.assertIsInstance(actual, float, path)
        test.assertEqual(struct.pack("<d", expected), struct.pack("<d", actual), path)
    elif isinstance(expected, dict):
        test.assertEqual(set(expected), set(actual), path)
        for key in expected:
            assert_bits(test, expected[key], actual[key], path + "." + key)
    elif isinstance(expected, list):
        test.assertEqual(len(expected), len(actual), path)
        for index, (left, right) in enumerate(zip(expected, actual, strict=True)):
            assert_bits(test, left, right, path + f"[{index}]")
    else:
        test.assertEqual(type(expected), type(actual), path)
        test.assertEqual(expected, actual, path)


class PortableBatchControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Rebind only an in-memory synthetic fixture to this candidate DLL.
        # The consumed v2 declaration and original physical evidence stay intact.
        synthetic = contract()
        synthetic["core_sha256"] = sha(Path(os.environ["QUADRUPED_TEST_CORE"]))
        with patch.object(fixtures, "contract", return_value=synthetic):
            fixtures.PortableSearchControls.setUpClass()
        cls.fixture = fixtures.PortableSearchControls
        cls.core = cls.fixture.core
        cls.compiled = cls.fixture.compiled
        cls.c = contract()

    def observations(self, backend="gpu", outer=0):
        return [self.fixture.observations(self.fixture.native(backend, cell), outer) for cell in range(4)]

    def cells(self, batch, observations=None):
        observations = self.observations() if observations is None else observations
        return [dict(cell_id=str(i), session_handle=c.session.batch_handle, request=dict(
            memory=c.memory, state=state, command=bridge._motion_command(state["semantic_step"], self.c["phase_mode"]),
            stability=stability, kinematics=kinematics, composition_memory=asdict(c.composition_memory),
            host_profile=bridge._mujoco_host_profile(c.context.profile_id)))
            for i, (c, (state, stability, kinematics)) in enumerate(zip(batch.controllers, observations, strict=True))]

    def test_complete_synthetic_path_and_unavailable_support_are_bit_exact(self):
        for support in (True, False, None):
            batch = BatchController(self.core, self.compiled, self.c)
            scalar = [Controller(self.core, self.compiled, self.c, cell) for cell in range(4)]
            try:
                for outer in range(3):
                    observations = self.observations(outer=outer)
                    for _, stability, _ in observations:
                        for contact in stability["ordered_support_contacts"]:
                            contact["bears_support"] = support
                    expected = [c.step(*obs) for c, obs in zip(scalar, observations, strict=True)]
                    actual = batch.step(observations)
                    assert_bits(self, expected, actual)
                    for a, b in zip(scalar, batch.controllers, strict=True):
                        assert_bits(self, asdict(a.composition_memory), asdict(b.composition_memory))
            finally:
                batch.close()
                for c in scalar:
                    c.close()

    def test_complete_retained_population_replays_without_physics(self):
        closure = json.loads((ROOT / "sdk/discovery/gpu_portable_search_closure_v2.json").read_text())
        folder = Path(closure["evidence_root"]) / closure["attempt_id"] / "physical"
        worker = json.loads((folder / "worker-result.json").read_text())
        self.assertEqual(sha(folder / "controller.jsonl"), worker["controller_sha256"])
        batch = None
        current = None
        pending = []
        counts = dict(gpu=0, cpu=0)
        try:
            with patch.object(mujoco, "MjModel", side_effect=AssertionError("world")), \
                    patch.object(mujoco, "MjData", side_effect=AssertionError("data")), \
                    patch.object(mujoco, "mj_step", side_effect=AssertionError("physics")), \
                    (folder / "controller.jsonl").open() as stream:
                for line in stream:
                    row = json.loads(line)
                    group = (row["backend"], None if row["backend"] == "gpu" else row["cell"])
                    if group != current:
                        self.assertFalse(pending)
                        if batch is not None:
                            batch.close()
                        batch = BatchController(self.core, self.compiled, self.c,
                                                None if group[0] == "gpu" else [group[1]])
                        current = group
                    pending.append(row)
                    if len(pending) == len(batch.controllers):
                        observed = [(r["request"]["state"], r["stability"], r["kinematics"]) for r in pending]
                        actual = batch.step(observed)
                        for original, result in zip(pending, actual, strict=True):
                            expected = {key: original[key] for key in result}
                            assert_bits(self, expected, result, f"{original['backend']}/{original['cell']}/{original['outer_step']}")
                            counts[original["backend"]] += 1
                        pending.clear()
            self.assertFalse(pending)
            self.assertEqual(counts, dict(gpu=1920, cpu=1920))
        finally:
            if batch is not None:
                batch.close()

    def test_failed_cell_is_retained_and_does_not_poison_other_cells(self):
        batch = BatchController(self.core, self.compiled, self.c)
        try:
            cells = self.cells(batch)
            cells[1]["session_handle"] = 2 ** 63
            receipt = self.core.bw19v_composition_batch_v1(cells)
            self.assertEqual([r["cell_id"] for r in receipt["ordered_results"]], ["0", "1", "2", "3"])
            self.assertEqual([r["outcome"]["ok"] for r in receipt["ordered_results"]], [True, False, True, True])
            self.assertIn("handle_unknown", receipt["ordered_results"][1]["outcome"]["detail"])
            with self.assertRaises(ValueError):
                values(receipt, ["0", "1", "2", "3"])
            for rows in ([], [cells[0], cells[0]], [dict(cells[0], cell_id=str(i)) for i in range(257)]):
                with self.assertRaises(LocomotionCoreError):
                    self.core.bw19v_composition_batch_v1(rows)
        finally:
            batch.close()

    def test_refused_batch_leaves_all_host_memory_unchanged(self):
        batch = BatchController(self.core, self.compiled, self.c)
        try:
            before = [(copy.deepcopy(c.memory), asdict(c.composition_memory), copy.deepcopy(c.provider_memory), list(c.previous)) for c in batch.controllers]
            observations = self.observations()
            observations[2][0]["semantic_step"] = 8
            with self.assertRaises(ValueError):
                batch.step(observations)
            after = [(c.memory, asdict(c.composition_memory), c.provider_memory, c.previous) for c in batch.controllers]
            self.assertEqual(before, after)
            batch.step(self.observations())
        finally:
            batch.close()

    def test_pure_batches_match_scalar_and_retain_malformed_provider_cell(self):
        objects = [dict(value=-0.0), dict(value=0.0), dict(value=1.2345678901234567), {"unicode": "test"}]
        assert_bits(self, [self.core.canonicalize_json(obj) for obj in objects], pure_batch(self.core, "canonicalize_json", objects))
        original = self.fixture.controls[0]["resolution_request"]
        requests = [copy.deepcopy(original), {}, copy.deepcopy(original)]
        response = self.core.pure_json_batch_v1("resolve_adaptation_v1", [dict(cell_id=str(i), request=r) for i, r in enumerate(requests)])
        self.assertEqual([r["outcome"]["ok"] for r in response["ordered_results"]], [True, False, True])
        expected = self.core.resolve_adaptation_v1(original)
        for index in (0, 2):
            assert_bits(self, expected, response["ordered_results"][index]["outcome"]["value"])
        with self.assertRaises(LocomotionCoreError):
            self.core.pure_json_batch_v1("unknown", [dict(cell_id="0", request={})])

    def test_buffer_growth_then_single_call_and_legacy_runtime_refusal(self):
        core = LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        name = "ss_pure_json_batch_v1_json"
        native = getattr(core._library, name)
        cells = [dict(cell_id="0", request={"text": "a" * 70000})]
        with patch.object(core._library, name, wraps=native) as measured:
            first = core.pure_json_batch_v1("canonicalize_json", cells)
            self.assertEqual(measured.call_count, 2)
            second = core.pure_json_batch_v1("canonicalize_json", cells)
            self.assertEqual(measured.call_count, 3)
            assert_bits(self, first, second)
        old = LocomotionCore(Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        with self.assertRaisesRegex(LocomotionCoreError, "ABI_BATCH_API_UNAVAILABLE"):
            old.pure_json_batch_v1("canonicalize_json", cells)

    def test_closed_session_and_crossed_receipts_refuse(self):
        batch = BatchController(self.core, self.compiled, self.c)
        cells = self.cells(batch)
        batch.close()
        receipt = self.core.bw19v_composition_batch_v1(cells)
        self.assertTrue(all(r["outcome"]["ok"] is False for r in receipt["ordered_results"]))
        with self.assertRaises(LocomotionCoreError):
            _ = batch.controllers[0].session.batch_handle
        for changed in [dict(receipt, ordered_results=[]), dict(receipt, world_build_count=1)]:
            with self.assertRaises(ValueError):
                values(changed, ["0", "1", "2", "3"])


if __name__ == "__main__":
    unittest.main()
