"""Zero-world controls for complete sparse confirmation and frozen choice."""
import copy
from contextlib import ExitStack
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import mujoco_warp as mjw

import creature_confirmation as confirmation
import creature_native as route
import creature_readback as readback
import test_creature_native as fixtures


class CreatureConfirmationControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = route.HERE / "creature_confirmation_v1.json"
        cls.raw = json.loads(cls.path.read_text())
        cls.c = route.declaration(cls.path)
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.parent, cls.parent_result = confirmation.source_records(cls.raw["confirmation_spec"])

    def setUp(self):
        self.traps = ExitStack(); self.addCleanup(self.traps.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            self.traps.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in confirmation control")))
        for name in ("put_model", "put_data", "make_data", "step1", "step2"):
            self.traps.enter_context(patch.object(mjw, name, side_effect=AssertionError("Native confirmation in control")))

    def declare(self, c):
        original = Path.read_text
        def read(path, *args, **kwargs):
            return json.dumps(c) if path == self.path else original(path, *args, **kwargs)
        with patch.object(Path, "read_text", read):
            return route.declaration(self.path)

    def metrics(self, c=None):
        c = self.c if c is None else c
        duration = c["outer_steps"]*5*c["timestep_s"]
        return [dict(minimum_height_m=.4, maximum_tilt_rad=.1, torso_contact_steps=0,
            safe_no_actuation_steps=0, ground_contact_steps=10, nonzero_force_steps=10,
            forward_displacement_m=(.15 if m["candidate_index"] == 0 else .18)*duration,
            lateral_displacement_m=0.) for m in c["confirmation_metadata"]]

    def bindings(self, c=None):
        return route.preflight(self.c if c is None else c, self.core_path)["bindings"]

    def test_sparse_expansion_keeps_all_shortlists_baselines_fixed_and_empty_groups(self):
        c = self.c
        self.assertEqual((len(c["cells"]), len(c["confirmation_plan"])), (284, 48))
        self.assertEqual(sum(len(g["shortlist_candidate_indices"]) for g in c["confirmation_plan"]), 69)
        self.assertEqual(sum(not g["shortlist_candidate_indices"] for g in c["confirmation_plan"]), 11)
        for group in c["confirmation_plan"]:
            self.assertEqual(set(group["candidate_indices"]), {0, 4, *group["shortlist_candidate_indices"]})
            self.assertEqual(group["frozen_choice_candidate_index"],
                group["shortlist_candidate_indices"][0] if group["shortlist_candidate_indices"] else 0)
        changed = copy.deepcopy(c); changed["cells"][0]["profile"]["ordered_coefficients"][0] = .1
        self.assertEqual(c["cells"][0]["profile"]["ordered_coefficients"][0], 0.)
        with self.assertRaises(ValueError): confirmation.verify_expansion(changed)

    def test_parent_body_condition_omission_crossing_and_profile_censoring_refuse(self):
        for mutation in ("omit", "cross", "profile", "shortlist", "denominator"):
            result = copy.deepcopy(self.parent_result)
            if mutation == "omit": result["body_condition_outcomes"].pop()
            if mutation == "cross": result["body_condition_outcomes"].reverse()
            if mutation == "profile": result["body_condition_outcomes"][0]["eligible_profiles"].pop()
            if mutation == "shortlist": result["body_condition_outcomes"][1]["shortlist"][0]["candidate_id"] = "baseline"
            if mutation == "denominator": result["constructed_gpu_worlds"] -= 1
            with patch.object(confirmation, "source_records", return_value=(self.parent, result)):
                with self.assertRaises(ValueError): confirmation.expand(self.c["confirmation_spec"])

    def test_declaration_refuses_competing_expansion_scope_and_excess_resources(self):
        for key, value in [("cells", []), ("selection", {}), ("confirmation_plan", []), ("population_spec", {}),
                           ("mode", "development_discovery"), ("batch_partition", "single"),
                           ("outer_steps", 240), ("maximum_worlds_per_batch", 3),
                           ("maximum_trace_bytes_per_stream", 2**30), ("maximum_worker_wall_seconds", 14401),
                           ("maximum_reader_wall_seconds", True), ("minimum_free_storage_bytes", 2**30),
                           ("readback", dict(mode="shared_snapshot", reference_check=True)), ("safety_controls", [])]:
            c = copy.deepcopy(self.raw); c[key] = value
            with self.assertRaises(ValueError): self.declare(c)

    def test_new_starts_and_fixed_choice_rule_are_required(self):
        for mutation in ("old", "duplicate", "one", "nonfinite", "fixed", "rule"):
            spec = copy.deepcopy(self.c["confirmation_spec"])
            if mutation == "old": spec["starts"][0]["lateral_velocity_m_s"] = .001
            if mutation == "duplicate": spec["starts"][1] = copy.deepcopy(spec["starts"][0])
            if mutation == "one": spec["starts"].pop()
            if mutation == "nonfinite": spec["starts"][0]["lateral_velocity_m_s"] = float("nan")
            if mutation == "fixed": spec["fixed_candidate_id"] = "baseline"
            if mutation == "rule": spec["choice_rule"] = "best_confirmation_outcome"
            with self.assertRaises(ValueError): confirmation.expand(spec)

    def test_declared_284_worlds_compile_with_bounded_host_sessions_and_native_chunks(self):
        c = self.c; result = route.preflight(c, self.core_path)
        self.assertEqual((result["world_build_count"], result["solver_steps"]), (0, 0))
        self.assertEqual((result["planned_gpu_worlds"], result["distinct_body_shapes"], len(result["batches"])), (284, 24, 142))
        self.assertEqual([len(g["cell_indices"]) for g in result["batches"]], [2]*142)
        self.assertEqual(sorted(i for g in result["batches"] for i in g["cell_indices"]), list(range(284)))
        self.assertEqual(sum(k for _, _, k in route.gates(c)), 139)

    def test_choice_stays_frozen_when_an_alternative_wins_or_one_start_fails(self):
        c = self.c; metrics = self.metrics(); bindings = self.bindings()
        selected = c["confirmation_plan"][0]["frozen_choice_candidate_index"]
        for m, metric in zip(c["confirmation_metadata"], metrics, strict=True):
            if (m["body_index"], m["condition_index"], m["candidate_index"], m["start_index"]) == (0, 0, selected, 1):
                metric["maximum_tilt_rad"] = .7
        result = confirmation.assess(c, metrics, bindings); group = result["body_conditions"][0]
        self.assertEqual(group["policies"]["frozen_choice"]["candidate_index"], selected)
        self.assertFalse(group["policies"]["frozen_choice"]["eligible"])
        self.assertIsNone(group["policies"]["frozen_choice"]["mean_velocity_error_m_s"])
        self.assertEqual(group["comparisons"]["fixed"], dict(outcome="comparator_only_eligible", comparator_minus_choice_error_m_s=None))
        self.assertFalse(result["choice_refit_on_confirmation"] or result["trained"])

    def test_comparisons_keep_failures_and_pair_quality_on_common_eligible_groups(self):
        summaries = [dict(eligible=True, mean_velocity_error_m_s=.02), dict(eligible=True, mean_velocity_error_m_s=.03),
                     dict(eligible=False, mean_velocity_error_m_s=None)]
        pairs = [(0, 1), (0, 2), (2, 0), (2, 2)]
        groups = [dict(comparisons=dict(fixed=confirmation.contrast(summaries[i], summaries[j]))) for i,j in pairs]
        r = confirmation.aggregate(groups, "fixed")
        self.assertEqual(list(r["counts"].values()), [1, 1, 1, 1])
        self.assertEqual(r["paired_eligible_quality_groups"], 1)
        self.assertAlmostEqual(r["mean_paired_comparator_minus_choice_error_m_s"], .01)
        self.assertFalse(r["finite_choice_signal"])
        self.assertTrue(confirmation.aggregate(groups[:2], "fixed")["finite_choice_signal"])
        self.assertIsNone(confirmation.aggregate(groups[1:], "fixed")["mean_paired_comparator_minus_choice_error_m_s"])

    def test_missing_crossed_impossible_metrics_and_changed_policy_refuse(self):
        c = self.c; metrics = self.metrics(); bindings = self.bindings()
        with self.assertRaises(ValueError): confirmation.assess(c, metrics[:-1], bindings)
        with self.assertRaises(ValueError): confirmation.assess(c, metrics, bindings[::-1])
        for key,value in (("minimum_height_m", float("inf")), ("nonzero_force_steps", 7201)):
            bad = copy.deepcopy(metrics); bad[0][key] = value
            with self.assertRaises(ValueError): confirmation.assess(c, bad, bindings)
        bad = copy.deepcopy(c); bad["confirmation_plan"][0]["frozen_choice_candidate_index"] = 4
        with self.assertRaises(ValueError): confirmation.assess(bad, metrics, bindings)

    def test_full_reader_confirms_sparse_fixture_without_reference_capture(self):
        parent = copy.deepcopy(self.parent)
        parent["population_spec"].update(descriptors=parent["population_spec"]["descriptors"][:1],
            conditions=parent["population_spec"]["conditions"][:1],
            profiles=[parent["population_spec"]["profiles"][i] for i in [0,4]])
        result = copy.deepcopy(self.parent_result)
        result.update(constructed_gpu_worlds=2, eligible_worlds=2, performance_failed_worlds=0,
            body_condition_outcomes=[dict(body_index=0, body_id=parent["population_spec"]["descriptors"][0]["morphology_id"],
                condition_id="nominal", eligible_profiles=["baseline", "joint_population_27"], failed_profiles=[],
                shortlist=[dict(candidate_id="joint_population_27")])])
        with patch.object(confirmation, "source_records", return_value=(parent, result)):
            c = copy.deepcopy(self.c); c.update(confirmation.expand(c["confirmation_spec"])); c.update(outer_steps=3,naconmax=256)
            with patch.object(route, "declaration", return_value=c): fixtures.CreatureNativeControls.setUpClass()
            fixture = fixtures.CreatureNativeControls(); c, folder = fixture.grouped_fixture()
            root_result = json.loads((folder / "worker-result.json").read_text())
            for group in root_result["groups"]:
                directory = folder / group["batch_id"]; n = len(group["cell_indices"])
                names = sorted(set(readback.CAPTURE_FIELDS + readback.VIEW_FIELDS))
                rows = [dict(outer_step=i, device_arrays_read=len(names), numpy_requests=n*len(names),
                    fields=[dict(path=name,shape=[n,1],dtype="<f4",bytes=4*n) for name in names],
                    order=["shared"],reference=[]) for i in range(3)]
                path = directory / "readback.jsonl"; path.write_bytes("".join(json.dumps(r)+"\n" for r in rows).encode())
                group["result"]["stream_sha256"]["readback"] = route.sha(path)
                (directory / "worker-result.json").write_bytes(json.dumps(group["result"]).encode())
            (folder / "worker-result.json").write_bytes(json.dumps(root_result).encode())
            report = route.audit(folder, c, self.core_path, synthetic=True)
            self.assertEqual((report["controller_rows_replayed"],report["native_rows_verified"],report["reader_world_build_count"]), (12,60,0))
            self.assertEqual(report["readback"]["reference_observations_checked"], 0)
            self.assertEqual(report["assessment"]["performance_failed_worlds"], 4)
            self.assertFalse(report["assessment"]["comparisons"]["fixed"]["finite_choice_signal"])
            with self.assertRaises(ValueError): route.audit(folder, c, self.core_path)

    def test_changed_source_bytes_and_authority_promotion_refuse(self):
        for name in ("discovery_contract", "discovery_result"):
            spec = copy.deepcopy(self.c["confirmation_spec"]); spec[name]["sha256"] = "0"*64
            with self.assertRaises(ValueError): confirmation.source_records(spec)
        for key in ("physical_acceptance_authority", "release_authority", "training_data_authority", "equivalence_authority"):
            c = copy.deepcopy(self.raw); c[key] = True
            with self.assertRaises(ValueError): self.declare(c)


if __name__ == "__main__":
    unittest.main()
