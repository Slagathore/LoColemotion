"""Zero-world controls for shared readback and bounded native batch splitting."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import numpy as np

import creature_native as route
import creature_readback as readback
import test_creature_native as fixtures


class CreatureReadbackControls(unittest.TestCase):
    # Reuse the existing retained fixture without inheriting its test methods.
    @classmethod
    def setUpClass(cls):
        fixtures.CreatureNativeControls.setUpClass.__func__(cls)

    setUp = fixtures.CreatureNativeControls.setUp
    validator = fixtures.CreatureNativeControls.validator
    validate = fixtures.CreatureNativeControls.validate
    retained_fixture = fixtures.CreatureNativeControls.retained_fixture
    grouped_fixture = fixtures.CreatureNativeControls.grouped_fixture

    def shared_fixture(self):
        c = copy.deepcopy(self.c)
        c.update(readback=dict(mode="shared_snapshot", reference_check=True), native_reads_reduced=True)
        folder = self.retained_fixture()
        controls = [json.loads(line) for line in (folder / "controller.jsonl").read_text().splitlines()]
        rows = []
        for outer in range(c["outer_steps"]):
            refs = []
            for control in controls[outer*4:(outer+1)*4]:
                b = control["binding"]
                refs.append(dict(cell=control["cell"], observation=dict(cell_id=b["cell_id"],
                    descriptor_sha256=b["descriptor_sha256"], model_xml_sha256=b["model_xml_sha256"],
                    state=control["request"]["state"], stability=control["stability"], kinematics=control["kinematics"]),
                    native_observation=control["native_observation"], contact_compatibility_copy=control["contact_compatibility_copy"]))
            names = sorted(set(readback.CAPTURE_FIELDS + readback.VIEW_FIELDS))
            # Synthetic metadata; the native route must record actual field shapes.
            rows.append(dict(outer_step=outer, device_arrays_read=len(names), numpy_requests=4*len(names),
                fields=[dict(path=n, shape=[4, 1], dtype="<f4", bytes=16) for n in names],
                order=readback.reference_order(outer), reference=refs))
        self.rewrite(folder, "readback", rows)
        timing = [json.loads(line) for line in (folder / "timing.jsonl").read_text().splitlines()]
        for row in timing:
            row.update(reference_readback_s=.002, outer_total_s=.015)
        self.rewrite(folder, "timing", timing)
        return c, folder, rows

    def rewrite(self, folder, stream, rows):
        path = folder / (stream + ".jsonl")
        path.write_bytes("".join(json.dumps(row)+"\n" for row in rows).encode())
        path = folder / "worker-result.json"
        result = json.loads(path.read_text())
        result["stream_sha256"][stream] = route.sha(folder / (stream + ".jsonl"))
        path.write_bytes(json.dumps(result).encode())

    def test_single_use_lease_owns_nested_readonly_arrays(self):
        source = fixtures.example(1.)
        lease = readback.PreparedReadback(source)
        with self.assertRaises(ValueError): lease.data.body_pos.numpy()
        with lease:
            a = lease.data.body_pos.numpy()
            self.assertIs(a, lease.data.body_pos.numpy())
            self.assertEqual(lease.data.stat.meaninertia.numpy().tolist(), [2.])
            self.assertEqual(lease.data.tables[0].numpy().tolist(), [0, 1])
            source.body_pos.zero_()
            self.assertEqual(a[0, 0, 0], 1.)
            with self.assertRaises(ValueError): a[0, 0, 0] = 9.
        self.assertEqual((lease.report()["device_arrays_read"], lease.report()["numpy_requests"]), (3, 4))
        with self.assertRaises(ValueError): lease.data.body_pos.numpy()
        with self.assertRaises(ValueError): lease.__enter__()

    def test_next_lease_observes_changed_native_state(self):
        source = fixtures.example(1.)
        with readback.PreparedReadback(source) as first:
            before = first.data.body_pos.numpy().copy()
        source.body_pos.zero_()
        with readback.PreparedReadback(source) as second:
            self.assertFalse(np.array_equal(before, second.data.body_pos.numpy()))
            self.assertFalse(second.data.body_pos.numpy().any())

    def test_unsupported_native_field_refuses(self):
        source = fixtures.example(1.); source.count = object()
        with self.assertRaises(ValueError): readback.PreparedReadback(source)

    def test_declaration_requires_matching_reduction_and_reference_scope(self):
        original = json.loads((route.HERE / "creature_readback_v1.json").read_text())
        self.assertEqual(readback.options(route.declaration(route.HERE / "creature_readback_v1.json")), original["readback"])
        for key, value in [("native_reads_reduced", False), ("readback", {}),
                           ("readback", dict(mode="partial", reference_check=True)),
                           ("readback", dict(mode="shared_snapshot", reference_check=1)),
                           ("mode", "development_discovery"), ("safety_controls", [])]:
            c = copy.deepcopy(original); c[key] = value
            with patch.object(Path, "read_text", return_value=json.dumps(c)):
                with self.assertRaises(ValueError): route.declaration(route.HERE / "creature_readback_v1.json")
        self.assertEqual(readback.options(self.c), dict(mode="per_world", reference_check=False))

    def test_chunks_preserve_every_original_cell_condition_and_velocity(self):
        c = route.declaration(route.HERE / "creature_readback_v1.json")
        plan = route.preflight(c, self.core_path)
        indices = [g["cell_indices"] for g in plan["batches"]]
        self.assertEqual(indices, [[0], [1, 3], [4, 5], [2]])
        self.assertEqual(sorted(i for group in indices for i in group), list(range(6)))
        self.assertEqual(plan["distinct_body_shapes"], 3)
        self.assertEqual((plan["world_build_count"], plan["solver_steps"]), (0, 0))
        for group in indices:
            local = route.batch_contract(c, group)
            self.assertEqual(local["cells"], [c["cells"][i] for i in group])
            self.assertEqual(local["initial_lateral_velocities_m_s"], [c["initial_lateral_velocities_m_s"][i] for i in group])
            self.assertEqual(local["naconmax"], 64*len(group))

    def test_invalid_and_oversized_batch_limits_refuse(self):
        for value in (True, 0, -1, 257, 1.5, float("nan")):
            with self.assertRaises(ValueError): route.batch_limit(dict(self.c, maximum_worlds_per_batch=value))
        with self.assertRaises(ValueError): route.batch_limit(dict(self.c, maximum_worlds_per_batch=2))
        with self.assertRaises(ValueError): route.batch_contract(dict(self.c, maximum_worlds_per_batch=1), [1, 3])

    def test_retained_reference_replays_all_inputs_and_denominators(self):
        c, folder, rows = self.shared_fixture()
        result = route.audit(folder, c, self.core_path, synthetic=True)
        self.assertEqual(result["readback"], dict(reference_observations_checked=12,
            device_arrays_read=sum(r["device_arrays_read"] for r in rows), numpy_requests=sum(r["numpy_requests"] for r in rows)))
        self.assertEqual((result["reader_world_build_count"], result["controller_rows_replayed"], result["native_rows_verified"]), (0, 12, 60))
        with self.assertRaises(ValueError): route.audit(folder, c, self.core_path)

    def test_rehashed_changed_observation_native_and_contact_copy_refuse(self):
        for key in ("observation", "native_observation", "contact_compatibility_copy", "cell"):
            c, folder, rows = self.shared_fixture()
            rows[0]["reference"][0][key] = 99
            self.rewrite(folder, "readback", rows)
            with self.assertRaises(ValueError): route.audit(folder, c, self.core_path, synthetic=True)

    def test_rehashed_missing_fields_and_forged_transfer_accounting_refuse(self):
        for mutation in ("field", "duplicate", "bytes", "world", "count", "requests"):
            c, folder, rows = self.shared_fixture()
            row = rows[0]
            if mutation == "field": row["fields"].pop()
            if mutation == "duplicate": row["fields"].append(row["fields"][0])
            if mutation == "bytes": row["fields"][0]["bytes"] += 1
            if mutation == "world":
                entry = next(e for e in row["fields"] if e["path"] == "qpos")
                entry.update(shape=[3, 1], bytes=12)
            if mutation == "count": row["device_arrays_read"] += 1
            if mutation == "requests": row["numpy_requests"] = 0
            self.rewrite(folder, "readback", rows)
            with self.assertRaises(ValueError): route.audit(folder, c, self.core_path, synthetic=True)

    def test_rehashed_journal_missing_extra_crossed_and_reference_scope_refuse(self):
        for mutation in ("missing", "extra", "cross", "reference", "order", "mode"):
            c, folder, rows = self.shared_fixture()
            if mutation == "missing": rows.pop()
            if mutation == "extra": rows.append(rows[-1])
            if mutation == "cross": rows.reverse()
            if mutation == "reference": rows[0]["reference"].pop()
            if mutation == "order": rows[1]["order"].reverse()
            if mutation == "mode": c["readback"]["reference_check"] = False
            self.rewrite(folder, "readback", rows)
            with self.assertRaises((ValueError, StopIteration)): route.audit(folder, c, self.core_path, synthetic=True)

    def test_reference_timing_is_required_and_accounted(self):
        c, folder, _ = self.shared_fixture()
        rows = [json.loads(line) for line in (folder / "timing.jsonl").read_text().splitlines()]
        for value in (None, -1., float("nan"), 10.):
            bad = copy.deepcopy(rows)
            if value is None: bad[0].pop("reference_readback_s")
            else: bad[0]["reference_readback_s"] = value
            with self.assertRaises(ValueError): route.validate_timing(bad, c)

    def test_chunked_reader_preserves_mapping_and_refuses_omitted_or_crossed_groups(self):
        with patch.object(self, "c", dict(self.c, maximum_worlds_per_batch=1)):
            c, folder = self.grouped_fixture()
            result = route.audit(folder, c, self.core_path, synthetic=True)
            self.assertEqual((result["gpu_batches"], result["gpu_worlds"]), (4, 4))
            self.assertEqual(result["metrics"], self.validate())
            path = folder / "worker-result.json"
            original = json.loads(path.read_text())
            for mutation in ("omit", "cross"):
                bad = copy.deepcopy(original)
                if mutation == "omit": bad["groups"].pop()
                else: bad["groups"].reverse()
                path.write_bytes(json.dumps(bad).encode())
                with self.assertRaises(ValueError): route.audit(folder, c, self.core_path, synthetic=True)


if __name__ == "__main__":
    unittest.main()
