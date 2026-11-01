"""Mixed-creature public-ABI controls. Every physics constructor is trapped."""
import copy
from contextlib import ExitStack
from dataclasses import asdict
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import mujoco
import numpy as np

import creature_batch as subject
import test_portable_search as fixture_methods
from test_portable_batch import assert_bits
from repertoire_control import ScalarRepertoireController
from gpu_quadruped_model import ROOT, sha
from showcase_model import FIELDS, S169, generated

CORE_SHA = "f88cb47a720802ac95d3f4553bd238f5812a6e9b291b17f5e2717708aa3d5b99"


def declaration(index, descriptor, candidate, factors=None):
    row = dict(cell_id=f"cell_{index}", descriptor=descriptor, profile=candidate)
    if factors is not None:
        row["motor_effectiveness"] = factors
    return row


def fixture(creature, template):
    """Derive separate synthetic geometry from each real compiler/XML result."""
    f = SimpleNamespace(compiled=creature["compiled"], spec=copy.deepcopy(creature["spec"]),
                        template=template, names=["world"], positions=[np.zeros(3)],
                        anchors=[np.asarray(creature["spec"]["initial_qpos"][:3])], axes=[np.zeros(3)])
    f.spec["initial_lateral_velocities"] = [.001]
    def walk(body, parent):
        position = parent + np.asarray(list(map(float, body.attrib["pos"].split())))
        f.names.append(body.attrib["name"]); f.positions.append(position)
        for joint in body.findall("joint"):
            f.anchors.append(position + np.asarray(list(map(float, joint.attrib.get("pos", "0 0 0").split()))))
            f.axes.append(np.asarray(list(map(float, joint.attrib["axis"].split()))))
        for child in body.findall("body"):
            walk(child, position)
    walk(ET.fromstring(creature["model_xml"]).find("worldbody/body"), np.zeros(3))
    return f


def observation(cell, f, step, support=True):
    native = fixture_methods.PortableSearchControls.native.__func__(f, "gpu", 0)
    state, stability, kinematics = fixture_methods.PortableSearchControls.observations.__func__(f, native, step)
    for contact in stability["ordered_support_contacts"]:
        contact["bears_support"] = support
    b = cell.binding
    return dict(cell_id=cell.cell_id, descriptor_sha256=b["descriptor_sha256"],
                model_xml_sha256=b["model_xml_sha256"], state=state, stability=stability, kinematics=kinematics)


def memories(batch):
    return copy.deepcopy([(c.memory, asdict(c.composition_memory), c.provider_memory, c.previous)
                          for c in batch.controllers])


class CreatureBatchControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        if sha(cls.core_path) != CORE_SHA:
            raise ValueError("Creature test core differs from the declared batch runtime")
        cls.core = subject.bridge.LocomotionCore(cls.core_path)
        cls.population = json.loads((ROOT / "sdk/discovery/population_discovery_v1.json").read_text())["population"]
        cls.descriptors = [S169] + [generated(seed) for seed in range(1000, 1031)]
        cls.template = fixture_methods._fixture(cls.core)["provider_request"]["state"]

    def setUp(self):
        self.traps = ExitStack()
        self.addCleanup(self.traps.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            self.traps.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in component control")))
        self.cells = [declaration(i, d, self.population[27 if i % 2 else 0])
                      for i, d in enumerate(self.descriptors[:4])]

    def batch(self, cells=None):
        b = subject.CreatureBatch(self.core, self.cells if cells is None else cells, seed=1061103)
        self.addCleanup(b.close)
        return b

    def observations(self, batch, step=0, support=True):
        return [observation(c, fixture(c.creature, self.template), step, support) for c in batch.controllers]

    def test_64_cells_32_creatures_match_scalar_with_and_without_support(self):
        cells = [declaration(2*i+j, d, self.population[0 if j == 0 else [8, 18, 55, 27][i % 4]])
                 for i, d in enumerate(self.descriptors) for j in range(2)]
        batch = self.batch(cells)
        scalar = [subject.CreatureController(self.core, row, seed=1061103) for row in cells]
        self.addCleanup(lambda: [c.close() for c in scalar])
        self.assertEqual(len({b["body_shape_sha256"] for b in batch.bindings}), 32)
        self.assertEqual(len({b["model_xml_sha256"] for b in batch.bindings}), 32)
        fixtures = [fixture(c.creature, self.template) for c in batch.controllers]
        for step, support in enumerate((True, False, None, True)):
            observations = [observation(c, f, step, support) for c, f in zip(batch.controllers, fixtures, strict=True)]
            expected = [c.step(o) for c, o in zip(scalar, observations, strict=True)]
            actual = batch.step(observations)
            assert_bits(self, expected, actual)
            for c, record in zip(batch.controllers, actual, strict=True):
                self.assertEqual(record["resolution_request"]["provider_request"]["descriptor"], c.descriptor)
                self.assertEqual(record["binding"], c.binding)
            assert_bits(self, memories(SimpleNamespace(controllers=scalar)), memories(batch))

    def test_s169_preserves_existing_baseline_and_profile_native_commands(self):
        contract = json.loads((ROOT / "sdk/discovery/gpu_motor_effectiveness_v1.json").read_text())
        contract["provider"]["candidates"] = [self.population[0], self.population[27]]
        batch = self.batch([declaration(i, S169, p) for i, p in enumerate(contract["provider"]["candidates"])])
        old = [ScalarRepertoireController(self.core, batch.controllers[i].creature["compiled"], contract, i) for i in range(2)]
        self.addCleanup(lambda: [c.close() for c in old])
        for step in range(3):
            observations = self.observations(batch, step)
            legacy = [c.step(o["state"], o["stability"], o["kinematics"]) for c, o in zip(old, observations, strict=True)]
            current = batch.step(observations)
            for before, after in zip(legacy, current, strict=True):
                for key in ("request", "output", "stability", "kinematics", "composition", "native_targets"):
                    assert_bits(self, before[key], after[key], key)

    def test_missing_duplicate_and_crossed_observations_leave_memory_unchanged(self):
        b = self.batch()
        observations = self.observations(b)
        damaged = [observations[:-1], observations[::-1], [observations[0]] * len(observations)]
        for key in ("descriptor_sha256", "model_xml_sha256"):
            wrong = copy.deepcopy(observations)
            wrong[1][key] = wrong[0][key]
            damaged.append(wrong)
        for rows in damaged:
            before = memories(b)
            with self.assertRaises(ValueError):
                b.step(rows)
            assert_bits(self, before, memories(b))
        b.step(observations)

    def test_failed_core_cell_is_atomic_and_retryable(self):
        b = self.batch()
        bad = self.observations(b)
        bad[2]["state"]["semantic_step"] = 9
        before = memories(b)
        with self.assertRaises(ValueError):
            b.step(bad)
        assert_bits(self, before, memories(b))
        b.step(self.observations(b))

    def test_late_mapping_failure_does_not_commit_earlier_cells(self):
        b = self.batch()
        before = memories(b)
        original = subject.map_resolution
        count = 0
        def fail_second(*args):
            nonlocal count
            count += 1
            if count == 2:
                raise ValueError("Injected final mapping failure")
            return original(*args)
        with patch.object(subject, "map_resolution", side_effect=fail_second):
            with self.assertRaises(ValueError):
                b.step(self.observations(b))
        assert_bits(self, before, memories(b))
        b.step(self.observations(b))

    def test_scalar_resolution_failure_keeps_composition_and_provider_memory(self):
        c = self.batch().controllers[0]
        before = memories(SimpleNamespace(controllers=[c]))
        with patch.object(self.core, "resolve_adaptation_v1", side_effect=ValueError("Injected refusal")):
            with self.assertRaises(ValueError):
                c.step(observation(c, fixture(c.creature, self.template), 0))
        assert_bits(self, before, memories(SimpleNamespace(controllers=[c])))
        c.step(observation(c, fixture(c.creature, self.template), 0))

    def test_invalid_profiles_and_declared_limits_refuse(self):
        invalid = []
        for field, value in [("ordered_coefficients", [0.] * 7), ("ordered_coefficients", [float("nan")] * 8),
                             ("ordered_coefficients", [.251] * 8), ("ordered_coefficients", [True] * 8),
                             ("factor", .1), ("factor", True), ("id", "")]:
            p = copy.deepcopy(self.population[27]); p[field] = value; invalid.append(p)
        p = copy.deepcopy(self.population[0]); p["ordered_coefficients"][0] = .1; invalid.append(p)
        for p in invalid:
            with self.assertRaises(ValueError):
                self.batch([declaration(0, S169, p)])
        for value in ([], [.49] * 8, [1.01] * 8, [float("inf")] * 8, [True] * 8):
            with self.assertRaises(ValueError):
                subject.compile_creature(self.core, S169, value)

    def test_invalid_descriptors_and_batches_refuse(self):
        for field in FIELDS:
            d = dict(S169); d[field] = float("nan")
            with self.assertRaises(ValueError):
                self.batch([declaration(0, d, self.population[0])])
        for cells in ([], self.cells * 2, [self.cells[0]] * 257, [None]):
            with self.assertRaises(ValueError):
                self.batch(cells)

    def test_constructor_failure_closes_already_created_sessions(self):
        created = []
        original = self.core.create_balanced_wave_policy_session
        def track(*args):
            session = original(*args); created.append(session); return session
        bad = copy.deepcopy(self.cells)
        # Two declarations deliberately reuse a profile. Damage only the last
        # cell so the test exercises cleanup after three successful creations.
        bad[-1]["profile"] = copy.deepcopy(bad[-1]["profile"])
        bad[-1]["profile"]["ordered_coefficients"] = [999.] * 8
        with patch.object(self.core, "create_balanced_wave_policy_session", side_effect=track):
            with self.assertRaises(ValueError):
                subject.CreatureBatch(self.core, bad, seed=1061103)
        self.assertEqual(len(created), len(self.cells) - 1)
        self.assertTrue(all(s.closed for s in created))

    def test_caller_mutation_and_returned_bindings_do_not_change_owned_inputs(self):
        source = copy.deepcopy(self.cells)
        b = self.batch(source)
        before = b.bindings
        source[0]["descriptor"]["torso_length_scale"] = .9
        source[0]["profile"]["ordered_coefficients"][0] = .2
        view = b.bindings
        view[0]["descriptor_sha256"] = "forged"
        self.assertEqual(before, b.bindings)
        b.step(self.observations(b))

    def test_shape_aliases_do_not_count_as_different_creatures(self):
        alias = dict(S169, morphology_id="same_shape_alias")
        a = subject.compile_creature(self.core, S169)
        b = subject.compile_creature(self.core, alias)
        self.assertNotEqual(a["binding"]["descriptor_sha256"], b["binding"]["descriptor_sha256"])
        self.assertEqual(a["binding"]["body_shape_sha256"], b["binding"]["body_shape_sha256"])
        self.assertEqual(a["binding"]["model_xml_sha256"], b["binding"]["model_xml_sha256"])

    def test_returned_receipts_do_not_alias_owned_controller_memory(self):
        b = self.batch()
        rows = b.step(self.observations(b))
        before = memories(b)
        rows[0]["output"]["next_memory"].clear()
        rows[0]["resolution"]["next_memory"].clear()
        assert_bits(self, before, memories(b))
        b.step(self.observations(b, 1))

    def test_motor_condition_changes_only_declared_actuator_fields(self):
        nominal = subject.compile_creature(self.core, self.descriptors[1])
        factors = [.75, .75, 1., 1., .75, .75, 1., 1.]
        weak = subject.compile_creature(self.core, self.descriptors[1], factors)
        self.assertEqual(nominal["compiled"], weak["compiled"])
        self.assertEqual(nominal["binding"]["body_shape_sha256"], weak["binding"]["body_shape_sha256"])
        a, b = ET.fromstring(nominal["model_xml"]), ET.fromstring(weak["model_xml"])
        for old, new in zip(a.findall("actuator/velocity"), b.findall("actuator/velocity"), strict=True):
            for key in ("kv", "forcerange"):
                new.set(key, old.attrib[key])
        self.assertEqual(ET.tostring(a), ET.tostring(b))
        for limits, previous, factor in zip(weak["spec"]["force_ranges"], nominal["spec"]["force_ranges"], factors, strict=True):
            self.assertEqual(limits, [v * factor for v in previous])

    def test_closed_batch_and_scalar_refuse(self):
        b = self.batch()
        rows = self.observations(b)
        b.close()
        with self.assertRaises(ValueError):
            b.step(rows)
        with self.assertRaises(ValueError):
            b.controllers[0].step(rows[0])


if __name__ == "__main__":
    unittest.main()
