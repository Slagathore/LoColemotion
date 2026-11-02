"""Zero-world controls for model transport, full capture and independent replay."""
import copy
from contextlib import ExitStack
from dataclasses import dataclass, fields
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import xml.etree.ElementTree as ET

import mujoco
import mujoco_warp as mjw
from mujoco_warp._src import types
import numpy as np
import warp as wp

import creature_native as route
import creature_native_model as model
from creature_batch import CreatureController, bridge
from gpu_quadruped_model import sha, f32
from test_creature_batch import fixture
import test_portable_search as fixtures


@dataclass(frozen=True)
class Stats:
    meaninertia: types.array("*", float)


@dataclass
class Example:
    body_pos: types.array("*", "nbody", wp.vec3)
    topology: wp.array[int]
    count: int
    stat: Stats
    tables: tuple


def example(value):
    return Example(wp.array(np.asarray([[[value, 0., 0.], [0., value, 0.]]], np.float32),
                            dtype=wp.vec3, device="cpu"),
        wp.array([0, 1], dtype=wp.int32, device="cpu"), 2,
        Stats(wp.array([value+1.], dtype=wp.float32, device="cpu")),
        (wp.array([0, 1], dtype=wp.int32, device="cpu"),))


def metadata(creature):
    tree = ET.fromstring(creature["model_xml"])
    return dict(binding=creature["binding"], ordered_bodies=["world"] + [b.attrib["name"] for b in tree.findall(".//body")],
        ordered_geoms=creature["spec"]["geom_names"], body_rootid=[0]+[1]*9,
        force_ranges=creature["spec"]["force_ranges"], native_fields=model.expected_native_fields(creature),
        observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")


def primary_snapshot(meta):
    annotations = {f.name: f.type for f in fields(types.Model)}
    result = {"$": dict(kind="object", value="SyntheticPrimaryFields")}
    for name, values in meta["native_fields"].items():
        annotation = annotations[name]
        batched = bool(getattr(annotation, "shape", ()) and annotation.shape[0] == "*")
        dtype = np.float32 if name in ("qpos0", "body_pos", "body_mass", "body_inertia", "body_ipos",
            "geom_size", "geom_pos", "jnt_pos", "actuator_gainprm", "actuator_biasprm", "actuator_forcerange", "actuator_gear") else np.int32
        data = np.asarray(values, dtype=dtype)
        if batched:
            data = data[None]
        result["$."+name] = model._array_record(data, logical_shape=data.shape, batchable=batched)
    return result


class CreatureNativeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.c = route.declaration(route.HERE / "creature_route_v2.json")
        cls.c["batch_partition"] = "single"
        if sha(cls.core_path) != cls.c["core_sha256"]:
            raise ValueError("Mixed-native control core binding")
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / "creature-native"
        cls.root.mkdir()
        wp.config.kernel_cache_dir = str(cls.root / "warp-cache")
        wp.init()
        cls.core = bridge.LocomotionCore(cls.core_path)
        cls.c["outer_steps"] = 3
        cls.creatures, cls.metadata, cls.controls, cls.native = [], [], [], []
        template = fixtures._fixture(cls.core)["provider_request"]["state"]
        with ExitStack() as trap:
            for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
                trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Synthetic constructor")))
            for index, declaration in enumerate(cls.c["cells"]):
                controller = CreatureController(cls.core, declaration, seed=cls.c["seed"])
                try:
                    creature = controller.creature
                    cls.creatures.append(creature); cls.metadata.append(metadata(creature))
                    f = fixture(creature, template)
                    f.spec["initial_lateral_velocities"] = [cls.c["initial_lateral_velocities_m_s"][index]]
                    native = fixtures.PortableSearchControls.native.__func__(f, "gpu", 0)
                    compatibility = native.pop("contact_compatibility_copy")
                    for slot, hit in enumerate(native["contacts"]):
                        hit.update(world=index, native_index=index*4+slot)
                    for outer in range(cls.c["outer_steps"]):
                        state, stability, kinematics = fixtures.PortableSearchControls.observations.__func__(f, native, outer)
                        observation = dict(cell_id=controller.cell_id, descriptor_sha256=controller.binding["descriptor_sha256"],
                            model_xml_sha256=controller.binding["model_xml_sha256"], state=state, stability=stability, kinematics=kinematics)
                        row = controller.step(observation)
                        row.update(cell=index, outer_step=outer, native_observation=dict(native, time_s=outer*5*cls.c["timestep_s"]),
                                   contact_compatibility_copy=copy.deepcopy(compatibility))
                        cls.controls.append(row)
                        for sub in range(5):
                            step = outer*5 + sub + 1
                            cls.native.append(dict(backend="gpu", cell=index, step=step,
                                before_qpos=native["qpos"], before_qvel=native["qvel"], qpos=native["qpos"], qvel=native["qvel"],
                                ctrl=[f32(v) for v in row["native_targets"]], actuator_force_nm=[0.]*8, joint_force_nm=[0.]*8,
                                on_force_cap=[False]*8, time_s=step*cls.c["timestep_s"], contacts=copy.deepcopy(native["contacts"]),
                                batch_contacts=16, nefc=12, overflow=0, warnings=[]))
                finally:
                    controller.close()
        cls.controls.sort(key=lambda r: (r["outer_step"], r["cell"]))
        cls.native.sort(key=lambda r: (r["step"], r["cell"]))
        cls.transport = dict(source_models=[primary_snapshot(m) for m in cls.metadata])
        packed, differing = model.merge_snapshots(cls.transport["source_models"])
        cls.transport.update(packed_model=packed, differing_fields=differing)

    def setUp(self):
        self.traps = ExitStack()
        self.addCleanup(self.traps.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            self.traps.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in component control")))
        for name in ("put_model", "put_data", "make_data", "step1", "step2"):
            self.traps.enter_context(patch.object(mjw, name, side_effect=AssertionError("Native batch in component control")))

    def validator(self):
        return route.StreamValidator(self.c, self.creatures, self.metadata)

    def validate(self, controls=None, native=None):
        control = iter(self.controls if controls is None else controls)
        trace = iter(self.native if native is None else native)
        validator = self.validator()
        for _ in range(self.c["outer_steps"]):
            for _ in self.creatures:
                validator.control(next(control))
            for _ in range(5):
                validator.native([next(trace) for _ in self.creatures])
        return validator.finish()

    def retained_fixture(self, *, controls=None, native=None, timing=None, transport=None, indices=None, folder=None):
        indices = list(range(len(self.creatures))) if indices is None else indices
        local = {global_index: i for i, global_index in enumerate(indices)}
        c = route.batch_contract(self.c, indices)
        creatures = [self.creatures[i] for i in indices]
        metas = [self.metadata[i] for i in indices]
        controls = copy.deepcopy([r for r in (self.controls if controls is None else controls) if r["cell"] in local])
        native = copy.deepcopy([r for r in (self.native if native is None else native) if r["cell"] in local])
        for row in controls + native:
            row["cell"] = local[row["cell"]]
            contacts = row["native_observation"]["contacts"] if "native_observation" in row else row["contacts"]
            for slot, hit in enumerate(contacts):
                hit.update(world=row["cell"], native_index=row["cell"]*4+slot)
            if "batch_contacts" in row:
                row["batch_contacts"] = len(indices)*4
        transport = copy.deepcopy(transport) if transport is not None else dict(
            source_models=[self.transport["source_models"][i] for i in indices])
        if "packed_model" not in transport:
            packed, differing = model.merge_snapshots(transport["source_models"])
            transport.update(packed_model=packed, differing_fields=differing)
        folder = self.root / uuid.uuid4().hex if folder is None else folder
        folder.mkdir()
        for index, (creature, meta) in enumerate(zip(creatures, metas, strict=True)):
            directory = folder / ("cell_" + str(index)); directory.mkdir()
            route.write_new(directory / "creature.json", creature)
            route.write_new(directory / "native-model.json", meta)
            (directory / "model.xml").write_bytes(creature["model_xml"].encode())
        route.write_new(folder / "source-models.json", transport["source_models"])
        route.write_new(folder / "model-transport.json", transport)
        route.write_new(folder / "model-after.json", transport["packed_model"])
        timings = [dict(outer_step=i, prepare_s=.001, observation_readback_s=.002, controller_s=.003,
            controller_capture_transfer_s=.001, integration_s=.003, capture_validation_write_s=.002, outer_total_s=.013)
            for i in range(self.c["outer_steps"])]
        for name, rows in [("controller", controls), ("trace", native), ("timing", timings if timing is None else timing)]:
            (folder / (name + ".jsonl")).write_bytes(("".join(json.dumps(row)+"\n" for row in rows)).encode())
        route.write_new(folder / "worker-result.json", dict(schema_version="locolemotion_creature_worker_v1",
            ledger_scope=self.c["ledger_scope"], ok=True, synthetic=True, model_unchanged=True,
            constructed_gpu_worlds=len(indices), native_model_constructions=len(indices), stepped_cpu_worlds=0,
            controller_rows=len(controls), native_rows=len(native), metrics=[self.validate()[i] for i in indices],
            stream_sha256={name: sha(folder / (name + ".jsonl")) for name in ("controller", "trace", "timing")},
            **{key: False for key in route.FLAGS}))
        return folder

    def grouped_fixture(self):
        c = dict(self.c, batch_partition="body_shape")
        plan = route.preflight(c, self.core_path)["batches"]
        folder = self.root / uuid.uuid4().hex; folder.mkdir()
        groups = []
        for group in plan:
            target = self.retained_fixture(indices=group["cell_indices"], folder=folder / group["batch_id"])
            groups.append(dict(group, result=json.loads((target / "worker-result.json").read_text())))
        route.write_new(folder / "worker-result.json", route.group_summary(c, groups, synthetic=True))
        return c, folder

    def test_32_model_transport_preserves_nested_constants_and_all_fields(self):
        inputs = [example(float(i)) for i in range(32)]
        packed, receipt = model.pack_models(inputs)
        self.assertEqual(packed.body_pos.shape, (32, 2))
        self.assertEqual(packed.stat.meaninertia.numpy().tolist(), [float(i+1) for i in range(32)])
        self.assertEqual(model.verify_transport(receipt, 32), ["$.body_pos", "$.stat.meaninertia"])
        self.assertTrue(packed.body_pos._is_batched and packed.stat.meaninertia._is_batched)
        self.assertEqual(model.model_snapshot(packed), receipt["packed_model"])

    def test_packed_arrays_do_not_alias_inputs(self):
        inputs = [example(1.), example(2.)]
        packed, receipt = model.pack_models(inputs)
        inputs[0].topology.fill_(9)
        inputs[0].body_pos.zero_()
        self.assertEqual(model.model_snapshot(packed), receipt["packed_model"])
        packed.topology.fill_(8)
        self.assertEqual(inputs[1].topology.numpy().tolist(), [0, 1])

    def test_different_static_array_refuses_without_changing_inputs(self):
        inputs = [example(1.), example(2.)]; inputs[1].topology.fill_(3)
        before = [model.model_snapshot(m) for m in inputs]
        with self.assertRaises(ValueError): model.pack_models(inputs)
        self.assertEqual(before, [model.model_snapshot(m) for m in inputs])

    def test_dimensions_dtype_population_and_prebatched_sources_refuse(self):
        snapshots = [model.model_snapshot(example(1.)), model.model_snapshot(example(2.))]
        variants = []
        a = copy.deepcopy(snapshots); a[1].pop("$.body_pos"); variants.append(a)
        for data in (np.ones((2, 2, 3), np.float32), np.ones((1, 3, 3), np.float32), np.ones((1, 2, 3), np.float64)):
            a = copy.deepcopy(snapshots)
            a[1]["$.body_pos"] = model._array_record(data, logical_shape=data.shape[:-1], batchable=True)
            variants.append(a)
        for rows in [[], snapshots * 129, *variants]:
            with self.assertRaises(ValueError): model.merge_snapshots(rows)

    def test_nonfinite_and_forged_array_records_refuse(self):
        with self.assertRaises(ValueError):
            model._array_record(np.asarray([float("nan")]), logical_shape=(1,), batchable=True)
        r = model.model_snapshot(example(1.))["$.body_pos"]
        r["data"][0][0][0] += 1
        with self.assertRaises(ValueError): model.array_value(r)

    def test_scalar_topology_tuple_and_signed_zero_differences_refuse(self):
        for field, value in (("count", 3), ("tables", ())):
            a, b = example(1.), example(2.); setattr(b, field, value)
            with self.assertRaises(ValueError): model.pack_models([a, b])
        a = {"x": dict(kind="scalar", value=dict(type="float", value=0.))}
        b = {"x": dict(kind="scalar", value=dict(type="float", value=-0.))}
        with self.assertRaises(ValueError): model.merge_snapshots([a, b])

    def test_transport_evidence_refuses_crossed_order_and_omitted_field(self):
        _, receipt = model.pack_models([example(1.), example(2.)])
        for change in ("order", "field", "count"):
            r = copy.deepcopy(receipt)
            if change == "order": r["source_models"].reverse()
            if change == "field": r["packed_model"].pop("$.stat.meaninertia")
            with self.assertRaises(ValueError): model.verify_transport(r, 3 if change == "count" else 2)

    def test_primary_geometry_and_condition_pair_reconstruct(self):
        for creature, meta, snap in zip(self.creatures, self.metadata, self.transport["source_models"], strict=True):
            model.validate_model_evidence(creature, meta, snap)
        self.assertEqual(len({v["binding"]["body_shape_sha256"] for v in self.creatures}), 3)
        self.assertNotEqual(self.transport["source_models"][1]["$.actuator_gainprm"],
                            self.transport["source_models"][3]["$.actuator_gainprm"])

    def test_native_model_and_gpu_primary_corruptions_refuse(self):
        for field in ("body_mass", "body_inertia", "body_pos", "geom_size", "actuator_gainprm"):
            meta = copy.deepcopy(self.metadata[0])
            values = np.asarray(meta["native_fields"][field], float); values.flat[-1] += .01
            meta["native_fields"][field] = values.tolist()
            with self.assertRaises(ValueError):
                model.validate_model_evidence(self.creatures[0], meta, self.transport["source_models"][0])
        with self.assertRaises(ValueError):
            model.validate_model_evidence(self.creatures[0], self.metadata[0], self.transport["source_models"][1])

    def test_capture_selected_cell_uses_own_caps(self):
        n = 4
        snap = dict(sensordata=np.zeros((n, 16)), qpos=np.zeros((n, 15)), qvel=np.zeros((n, 14)),
            before_qpos=np.zeros((n, 15)), before_qvel=np.zeros((n, 14)), ctrl=np.zeros((n, 8)),
            time=np.zeros(n), contacts=[[] for _ in range(n)], batch_contacts=0, nefc=np.zeros(n, int), overflow=np.zeros(n, int))
        snap["sensordata"][0, :2] = 1000.
        rows = list(route.trace_rows(snap, self.c, self.creatures[1]["spec"], 0, 0, n, cell_indices=[1]))
        self.assertEqual([r["cell"] for r in rows], [1])
        for indices in ([4], [-1], [True], [1, 1]):
            with self.assertRaises(ValueError):
                list(route.trace_rows(snap, self.c, self.creatures[1]["spec"], 0, 0, n, cell_indices=indices))

    def test_complete_mixed_streams_validate(self):
        self.assertEqual(len(self.validate()), 4)

    def test_crossed_controller_observation_or_identity_refuses(self):
        for key in ("binding", "native_observation"):
            rows = copy.deepcopy(self.controls); rows[1][key] = rows[0][key]
            with self.assertRaises(ValueError): self.validate(controls=rows)
        rows = copy.deepcopy(self.controls); rows[0]["cell"] = 1
        with self.assertRaises(ValueError): self.validate(controls=rows)
        rows = copy.deepcopy(self.controls); rows[0]["native_observation"]["time_s"] = .1
        with self.assertRaises(ValueError): self.validate(controls=rows)

    def test_solver_force_contact_clock_and_missing_denominators_refuse(self):
        for key, value in [("ctrl", [9.]*8), ("actuator_force_nm", [99999.]*8),
                           ("time_s", 99.), ("overflow", 1), ("step", 2)]:
            rows = copy.deepcopy(self.native); rows[0][key] = value
            with self.assertRaises(ValueError): self.validate(native=rows)
        rows = copy.deepcopy(self.native); rows[1]["contacts"][0]["native_index"] = 0
        with self.assertRaises(ValueError): self.validate(native=rows)
        with self.assertRaises(ValueError): self.validator().finish()

    def test_full_independent_scalar_reader_on_synthetic_retained_streams(self):
        result = route.audit(self.retained_fixture(), self.c, self.core_path, synthetic=True)
        self.assertTrue(result["ok"] and result["synthetic"])
        self.assertEqual((result["controller_rows_replayed"], result["native_rows_verified"]), (12, 60))
        self.assertEqual(result["reader_world_build_count"], 0)

    def test_reader_refuses_rehashed_corruptions_and_native_relabelling(self):
        folder = self.retained_fixture()
        with self.assertRaises(ValueError): route.audit(folder, self.c, self.core_path)
        rows = copy.deepcopy(self.controls); rows[0]["output"]["next_memory"]["semantic_step"] = 999
        with self.assertRaises(ValueError):
            route.audit(self.retained_fixture(controls=rows), self.c, self.core_path, synthetic=True)
        with self.assertRaises(ValueError):
            route.audit(self.retained_fixture(timing=[]), self.c, self.core_path, synthetic=True)
        rows = copy.deepcopy(self.native); rows[0]["ctrl"] = [99.]*8
        with self.assertRaises(ValueError):
            route.audit(self.retained_fixture(native=rows), self.c, self.core_path, synthetic=True)

    def test_missing_gate_and_containment_refuse_before_native_construction(self):
        folder = self.root / uuid.uuid4().hex; folder.mkdir()
        with self.assertRaises(ValueError):
            route.run(folder, folder / "absent.permit", self.c, route.HERE / "creature_route_v2.json", self.core_path)
        with self.assertRaises(FileNotFoundError):
            route.validate_launch(folder, self.c, route.HERE / "creature_route_v2.json")

    def test_declaration_scope_capacity_clock_and_control_population_refuse(self):
        original = json.loads((route.HERE / "creature_route_v2.json").read_text())
        for key, value in [("release_authority", True), ("training_data_authority", True), ("mode", "qualification"),
                           ("outer_steps", 0), ("outer_steps", 1441), ("njmax", 1), ("capture_mode", "compact"),
                           ("initial_lateral_velocities_m_s", []), ("safety_controls", []), ("batch_partition", "omit_constants")]:
            c = copy.deepcopy(original); c[key] = value
            with patch.object(Path, "read_text", return_value=json.dumps(c)):
                with self.assertRaises(ValueError): route.declaration(route.HERE / "creature_route_v2.json")

    def test_preflight_closes_real_sessions_without_native_construction(self):
        result = route.preflight(self.c, self.core_path)
        self.assertEqual((result["world_build_count"], result["solver_steps"], result["planned_gpu_worlds"]), (0, 0, 4))
        self.assertEqual(result["distinct_body_shapes"], 3)

    def test_shape_partition_preserves_aliases_and_32_real_compiled_bodies(self):
        c = dict(self.c, batch_partition="body_shape")
        self.assertEqual([g["cell_indices"] for g in route.preflight(c, self.core_path)["batches"]], [[0], [1, 3], [2]])
        from showcase_model import generated
        c = copy.deepcopy(c); c["cells"], c["initial_lateral_velocities_m_s"] = [], []
        for i in range(32):
            for j in range(2):
                descriptor = generated(1000+i)
                descriptor["morphology_id"] = f"shape_{i}_alias_{j}"
                c["cells"].append(dict(cell_id=f"cell_{i}_{j}", descriptor=descriptor, profile=self.c["cells"][j]["profile"]))
                c["initial_lateral_velocities_m_s"].append(.001)
        plan = route.preflight(c, self.core_path)
        self.assertEqual(plan["distinct_body_shapes"], 32)
        self.assertEqual([g["cell_indices"] for g in plan["batches"]], [[2*i, 2*i+1] for i in range(32)])

    def test_group_contract_preserves_conditions_clocks_and_refuses_bad_indices(self):
        c = route.batch_contract(self.c, [1, 3])
        self.assertEqual(c["cells"], [self.c["cells"][1], self.c["cells"][3]])
        self.assertEqual(c["initial_lateral_velocities_m_s"], [self.c["initial_lateral_velocities_m_s"][i] for i in [1, 3]])
        self.assertEqual(c["naconmax"], 128)
        self.assertEqual(c["outer_steps"], self.c["outer_steps"])
        for indices in ([], [0, 0], [4], [-1], [True]):
            with self.assertRaises(ValueError): route.batch_contract(self.c, indices)
        bindings = [dict(v["binding"], cell_id=self.c["cells"][i]["cell_id"]) for i, v in enumerate(self.creatures)]
        with self.assertRaises(ValueError): route.partition(self.c, bindings[::-1])

    def test_grouped_reader_replays_every_cell_and_original_mapping(self):
        c, folder = self.grouped_fixture()
        result = route.audit(folder, c, self.core_path, synthetic=True)
        self.assertEqual((result["gpu_batches"], result["gpu_worlds"], result["distinct_body_shapes"]), (3, 4, 3))
        self.assertEqual((result["controller_rows_replayed"], result["native_rows_verified"], result["reader_world_build_count"]), (12, 60, 0))
        self.assertEqual(result["metrics"], self.validate())
        with self.assertRaises(ValueError): route.audit(folder, c, self.core_path)

    def test_grouped_reader_refuses_omitted_crossed_counts_and_source_snapshots(self):
        for mutation in ("omit", "cross", "count", "source"):
            c, folder = self.grouped_fixture()
            path = folder / "worker-result.json"; r = json.loads(path.read_text())
            if mutation == "omit": r["groups"].pop()
            if mutation == "cross": r["groups"][1]["cell_indices"].reverse()
            if mutation == "count": r["constructed_gpu_worlds"] += 1
            if mutation == "source":
                (folder / "batch_000/source-models.json").write_text("[]")
            path.write_text(json.dumps(r))
            with self.assertRaises(ValueError): route.audit(folder, c, self.core_path, synthetic=True)


if __name__ == "__main__":
    unittest.main()
