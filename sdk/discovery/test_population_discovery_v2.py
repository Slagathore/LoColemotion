"""Controls for exact within-run projection without cross-run identity claims."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco

import population_discovery_task_v1 as previous
import test_population_discovery_v1 as fixture
from population_discovery_task_v2 import declaration, plans, GATES, FAILURE, FAILURE_SHA, sha
from population_discovery_v2 import preflight
from audit_population_discovery_v2 import finish_canaries, verify_full_projection


class ProjectionSuccessorControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture.PopulationControls.setUpClass()
        cls.f = fixture.PopulationControls

    def observed(self):
        c = declaration()
        rows = []
        for plan in plans(c, "canaries"):
            row = dict(plan=plan, compact_capture_validated=True, compact_sha256=("a" if plan["capture_mode"] == "full" else "b")*64,
                episodes=[dict(candidate_index=i, eligible=False, failure_codes=["tilt"], first_failure_native_step=600)
                    for i in plan["candidate_indices"]], stream_bytes=dict(compact=100),
                timings=dict(measured=dict(outer_total_s=1.)), setup_s=.1, graph_capture_s=.1)
            if plan["capture_mode"] == "full":
                row["full_replay"] = dict(projection_verified=True, controller_rows=plan["nworld"]*plan["outer_steps"],
                    internal_rows=plan["nworld"]*plan["outer_steps"]*5)
            rows.append(row)
        return c, rows

    def test_01_v1_failure_stays_bound_and_unpromoted(self):
        self.assertEqual(sha(FAILURE), FAILURE_SHA)
        c = declaration()
        self.assertFalse(c["challenge"]["former_attempt_reinterpreted"])
        self.assertFalse(c["challenge"]["cross_run_equivalence_claim"])
        self.assertEqual(sum(n for _, _, n in GATES), 108)

    def test_02_population_and_native_envelope_are_unchanged(self):
        old, new = previous.declaration(), declaration()
        self.assertEqual(plans(old, "population"), plans(new, "population"))
        self.assertEqual(plans(old, "canaries"), plans(new, "canaries"))
        for name in ("provider", "conditions", "condition_model_sha256", "selection", "core_sha256", "runtime"):
            self.assertEqual(old[name], new[name])

    def test_03_actual_successor_preflight_is_zero_world(self):
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("World")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Data")):
            value = preflight(self.f.core_path, self.f.baseline)
        self.assertEqual((value["world_build_count"], value["solver_steps"]), (0, 0))

    def test_04_different_fresh_run_hashes_are_reported_without_equivalence(self):
        c, rows = self.observed()
        result = finish_canaries(rows, c)
        self.assertTrue(result["within_run_projection_verified"])
        self.assertFalse(result["compact_pairs_match"])
        self.assertFalse(result["cross_run_equivalence_claim"])
        rows[1]["episodes"][0]["first_failure_native_step"] += 1
        result = finish_canaries(rows, c)
        self.assertFalse(result["telemetry_comparisons"][0]["recorded_outcomes_equal"])

    def test_05_missing_full_projection_or_replay_cannot_open_population(self):
        c, rows = self.observed()
        for key, value in (("projection_verified", False), ("controller_rows", 0), ("internal_rows", 0)):
            damaged = copy.deepcopy(rows)
            damaged[0]["full_replay"][key] = value
            with self.assertRaises(ValueError):
                finish_canaries(damaged, c)

    def test_06_crossed_plan_or_seed_refuses(self):
        c, rows = self.observed()
        rows[1]["plan"]["seed"] += 1
        with self.assertRaises(ValueError):
            finish_canaries(rows, c)

    def test_07_missing_mode_or_compact_reconstruction_refuses(self):
        c, rows = self.observed()
        with self.assertRaises(ValueError):
            finish_canaries(rows[:-1], c)
        rows[1]["compact_capture_validated"] = False
        with self.assertRaises(ValueError):
            finish_canaries(rows, c)

    def test_08_exact_same_run_fields_still_reject_corruption(self):
        verify_full_projection(self.f.folder, self.f.plan)
        original = self.f.folder / "compact.jsonl"
        rows = [json.loads(line) for line in original.read_text().splitlines()]
        import audit_population_discovery_v2 as reader
        real = reader.read_jsonl
        for field in ("native_targets", "prepared_qpos", "completed_qvel"):
            corrupted = copy.deepcopy(rows)
            corrupted[0][field][0] += .001
            with patch.object(reader, "read_jsonl", side_effect=lambda path, data=corrupted: iter(data) if path == original else real(path)):
                with self.assertRaises(ValueError):
                    verify_full_projection(self.f.folder, self.f.plan)


if __name__ == "__main__":
    unittest.main()
