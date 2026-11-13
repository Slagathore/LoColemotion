"""Paired intervention invariants, joins and real-interface zero-world checks."""
import copy
from contextlib import ExitStack
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco

import creature_native as native
import creature_righting as righting
import creature_trajectory_search as trajectory
import creature_trajectory_retiming as subject
import run_creature_native as owner


class RetimingControls(unittest.TestCase):
    def setUp(self):
        trap = ExitStack()
        self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in retiming controls")))

    def contract(self, route=False):
        spec = subject.spec(subject.RECIPE, route=route)
        return dict(mode="route_ghost" if route else "development_discovery",
            righting_spec=spec, righting_selection=righting.SELECTION,
            trajectory_screen=trajectory.POLICY, trajectory_retiming=subject.RECIPE,
            outer_steps=2 if route else 1440, maximum_worlds_per_batch=14,
            seed=subject.RECIPE["seed"], **righting.expand(spec))

    def outcomes(self):
        c = self.contract()
        metrics = [{**righting.initial_metrics(), **trajectory.initial_metrics(),
                    "trajectory_samples": 7200} for _ in c["cells"]]
        bindings = [dict(cell_id=m["cell_id"], body_shape_sha256="fixture") for m in c["righting_metadata"]]
        return c, metrics, bindings

    def test_01_only_clocks_change_and_exposed_failures_stay_in_population(self):
        profiles = subject.proposals(subject.RECIPE)
        original = {p["id"]: p for p in subject.source()["profiles"]}
        self.assertEqual(len(profiles), 48)
        self.assertEqual(len({righting.behavior_key(p) for p in profiles}), 48)
        for old, slow in zip(profiles[::2], profiles[1::2], strict=True):
            base = old["id"].removesuffix("_original")
            self.assertEqual({k:v for k,v in old.items() if k != "id"},
                             {k:v for k,v in original[base].items() if k != "id"})
            expected = copy.deepcopy(old)
            expected["id"] = base + "_slow3"
            for p in expected["phases"]:
                p["minimum_hold_steps"] *= 3
                p["maximum_hold_steps"] *= 3
                p["limb_delay_steps"] = [v * 3 for v in p["limb_delay_steps"]]
            self.assertEqual(slow, expected)
            self.assertEqual(righting.profile(slow), slow)
        for family in ("wave", "impulse", "waypoint"):
            rows = [p for p in profiles[::2] if p["id"].startswith(family)]
            self.assertEqual(len(rows), 8)
            self.assertEqual({len(p["phases"]) for p in rows}, {3, 4, 5, 6})
            self.assertEqual({p["maximum_speed_rad_s"] for p in rows}, {2., 3.5})
            self.assertEqual({p["maximum_slew_rad_s_per_step"] for p in rows}, {.08, .2})
        self.assertTrue({"wave_05_original", "impulse_05_original", "waypoint_01_original", "waypoint_13_original"}
                        <= {p["id"] for p in profiles})

    def test_02_balanced_pairs_keep_both_comparators_and_four_body_replicates(self):
        c = self.contract()
        subject.validate(c)
        self.assertEqual(len(c["cells"]), 224)
        rows = c["righting_spec"]["profiles_by_body"]
        self.assertEqual([len(r) for r in rows], [14] * 16)
        for i in range(2, 50, 2):
            self.assertEqual(sum(i in r for r in rows), 4)
            self.assertTrue(all((i in r) == (i + 1 in r) for r in rows))
        for r in rows:
            self.assertEqual(r[:2], [0, 1])
            for family in ("wave", "impulse", "waypoint"):
                self.assertEqual(sum(c["righting_spec"]["profiles"][i]["id"].startswith(family) for i in r), 4)

    def test_03_paired_progress_never_changes_recovery_eligibility(self):
        c, metrics, bindings = self.outcomes()
        metrics[3]["trajectory_maximum_up_dot"] = -math.cos(math.radians(20))
        metrics[3]["trajectory_distal_contact_samples"] = 10
        assessment = righting.assess(c, metrics, bindings)
        report = subject.assess(c, metrics, assessment)
        self.assertEqual(report["paired_groups"], 96)
        self.assertAlmostEqual(report["pairs"][0]["rotation_gain_degrees"], 20.)
        self.assertEqual(report["pairs"][0]["distal_contact_sample_gain"], 10)
        self.assertEqual(report["slow_eligible"], 0)
        self.assertTrue(report["diagnostic_only"])
        for key in ("trained", "physical_acceptance_authority", "training_data_authority", "release_authority", "equivalence_authority"):
            self.assertFalse(report[key])
        metrics[3]["joint_limit_violation_steps"] = 7
        report = subject.assess(c, metrics, righting.assess(c, metrics, bindings))
        self.assertEqual(report["pairs"][0]["joint_violation_sample_gain"], 7)
        self.assertFalse(report["pairs"][0]["slow3"]["eligible"])

    def test_04_missing_crossed_and_duplicate_outcomes_refused(self):
        c, metrics, bindings = self.outcomes()
        assessment = righting.assess(c, metrics, bindings)
        bad = copy.deepcopy(assessment)
        bad["episodes"][2]["cell_id"] = "crossed"
        with self.assertRaises(ValueError): subject.assess(c, metrics, bad)
        bad = copy.deepcopy(c)
        bad["righting_metadata"][3]["candidate_id"] = bad["righting_metadata"][2]["candidate_id"]
        with self.assertRaises(ValueError): subject.assess(bad, metrics, assessment)
        bad = copy.deepcopy(c)
        bad["righting_metadata"].pop(3)
        short = copy.deepcopy(assessment); short["episodes"].pop(3)
        partial = copy.deepcopy(metrics); partial.pop(3)
        with self.assertRaises(ValueError): subject.assess(bad, partial, short)

    def test_05_actual_declarations_preflight_all_worlds_without_physics(self):
        core = Path(os.environ["QUADRUPED_TEST_CORE"])
        for filename, count, bodies, batches in (("creature_trajectory_retiming_route_v1.json", 14, 1, 1),
                                                 ("creature_trajectory_retiming_v1.json", 224, 16, 16)):
            c = native.declaration(native.HERE / filename)
            report = native.preflight(c, core)
            self.assertEqual(report["world_build_count"], 0)
            self.assertEqual(report["solver_steps"], 0)
            self.assertEqual(report["planned_gpu_worlds"], count)
            self.assertEqual(report["distinct_body_shapes"], bodies)
            self.assertEqual(len(report["batches"]), batches)
            self.assertTrue(all(len(g["cell_indices"]) == 14 for g in report["batches"]))

    def test_06_pairing_drift_refused_and_complete_gate_preserves_legacy(self):
        c = self.contract()
        changes = [lambda v:v["righting_spec"]["profiles"][3].update(position_gain_s_inv=7.),
            lambda v:v["righting_spec"]["profiles_by_body"][0].pop(),
            lambda v:v.update(outer_steps=720), lambda v:v.update(seed=1),
            lambda v:v.update(maximum_worlds_per_batch=4),
            lambda v:v["trajectory_retiming"].update(multiplier=2),
            lambda v:v["righting_spec"]["starts"][0].update(id="changed")]
        for change in changes:
            bad = copy.deepcopy(c); change(bad)
            with self.assertRaises(ValueError): subject.validate(bad)
        for name in ("creature_trajectory_retiming_route_v1.json", "creature_trajectory_retiming_v1.json"):
            declared = native.declaration(native.HERE / name)
            self.assertEqual(sum(k for _, _, k in native.gates(declared)), 172)
        old = native.declaration(native.HERE / "creature_trajectory_search_v1.json")
        self.assertEqual(sum(k for _, _, k in native.gates(old)), 159)

    def test_07_source_inventory_retains_both_tested_declarations_without_duplicates(self):
        base = subject.ROOT / subject.SOURCE["path"]
        broad = native.HERE / "creature_trajectory_retiming_v1.json"
        route = native.HERE / "creature_trajectory_retiming_route_v1.json"
        for path in (route, broad):
            c = native.declaration(path)
            sources = owner.source_paths(path, c)
            self.assertEqual(len(sources), len(set(sources)))
            self.assertTrue({base, broad, route} <= set(sources))
            self.assertTrue(all(p.is_relative_to(native.ROOT) and p.is_file() for p in sources))
        old = native.declaration(native.HERE / "creature_trajectory_search_v1.json")
        self.assertEqual(subject.source_dependencies(old), [])


if __name__ == "__main__":
    unittest.main()
