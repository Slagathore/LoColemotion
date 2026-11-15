"""Fixed candidate identity, both-start accounting and short-route refusals."""
import copy
from contextlib import ExitStack
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_native as native
import creature_response_confirmation as subject
import creature_response_search as search
import creature_righting as righting
import creature_trajectory_search as trajectory


class ResponseConfirmationControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.full = native.declaration(subject.ROOT / subject.DECLARATION)
        cls.route = native.declaration(subject.ROOT / subject.ROUTE_DECLARATION)

    def setUp(self):
        traps = ExitStack()
        self.addCleanup(traps.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            traps.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in response confirmation controls")))

    @staticmethod
    def metrics(c):
        metrics = []
        for meta in c["righting_metadata"]:
            pi = meta["candidate_index"]
            m = dict(righting.initial_metrics(), **trajectory.initial_metrics(), **search.initial_metrics(c))
            m.update(trajectory_samples=c["outer_steps"]*5,
                trajectory_maximum_up_dot=-math.cos(math.radians(20. if pi > 2 else 10.)))
            if pi >= 2:
                m["response_search_rows"] = c["outer_steps"]
                m["response_search_unchanged" if pi == 2 else "response_search_replans"] = c["outer_steps"]
            if pi > 2: m["response_search_constraint_rows"] = c["outer_steps"]
            metrics.append(m)
        return metrics

    def assess(self, c, metrics):
        return subject.assess(c, trajectory.assess(c, metrics))

    def test_exact_population_preserves_all_source_recipes_and_legacy_gates(self):
        original, pairs = subject.source_data()
        self.assertEqual(len(pairs), 13)
        self.assertEqual(len({b for b, _ in pairs}), 11)
        self.assertEqual(len(self.full["cells"]), 92)
        self.assertEqual(sum(m["candidate_index"] > 2 for m in self.full["righting_metadata"]), 26)
        self.assertEqual(len(self.route["cells"]), 10)
        self.assertEqual(self.route["outer_steps"], 2)
        for route, c in ((False, self.full), (True, self.route)):
            _, selected, bodies, profiles = subject.population(route=route)
            self.assertEqual(c["righting_spec"]["profiles"], [original["righting_spec"]["profiles"][p] for p in profiles])
            self.assertEqual(c["righting_spec"]["descriptors"], [original["righting_spec"]["descriptors"][b] for b in bodies])
            self.assertEqual(len(c["cells"]), 2*(len(selected)+3*len(bodies)))
            self.assertEqual(sum(k for _, _, k in native.gates(c)), 256)
        for version, count in (("v1", 216), ("v2", 248)):
            old = native.declaration(subject.ROOT / f"sdk/discovery/creature_response_search_{version}.json")
            self.assertEqual(sum(k for _, _, k in native.gates(old)), count)
        self.assertEqual(set(subject.source_dependencies()), set(search.source_dependencies(self.full)) & set(subject.source_dependencies()))

    def test_changed_source_result_or_bound_declaration_is_refused(self):
        read = Path.read_bytes
        for suffix in (subject.SOURCE["path"], "sdk/discovery/creature_response_search_v2.json"):
            def changed(path, target=subject.ROOT / suffix):
                raw = read(path)
                return raw+b" " if path == target else raw
            with self.subTest(source=suffix), patch.object(Path, "read_bytes", changed):
                with self.assertRaisesRegex(ValueError, "source binding"): subject.source_data()

    def test_declaration_refuses_seed_start_pair_recipe_threshold_and_opt_in_drift(self):
        changes = [
            lambda c: c.update(seed=c["seed"]+1),
            lambda c: c.update(outer_steps=1439),
            lambda c: c.update(response_confirmation={}),
            lambda c: c["response_confirmation"].update(release_authority=True),
            lambda c: c["response_confirmation"].update(minimum_peak_rotation_gain_degrees=4.),
            lambda c: c["predecessor"].update(sha256="0"*64),
            lambda c: c["righting_spec"]["starts"][0].update(roll_rad=math.pi-.06),
            lambda c: c["righting_spec"]["profiles_by_body"][0].pop(),
            lambda c: c["righting_spec"]["profiles"][3]["response_search"].update(maximum_rate_rad_s=2.),
            lambda c: c["trajectory_reference_by_body"].__setitem__(0, 3),
            lambda c: c.pop("response_search"),
        ]
        for change in changes:
            bad = copy.deepcopy(self.full)
            change(bad)
            with self.assertRaises(ValueError): search.validate(bad)
        bad = {"response_confirmation": copy.deepcopy(subject.POLICY), "righting_spec": {"profiles": []}}
        with self.assertRaises(ValueError): search.validate(bad)

    def test_same_pair_must_pass_both_starts_without_borrowing_another_profile(self):
        metrics = self.metrics(self.full)
        positive = self.assess(self.full, metrics)
        self.assertEqual(len(positive["confirmed_pairs"]), 13)
        self.assertEqual(positive["bodies_with_confirmed_pair"], 11)
        _, _, bodies, profiles = subject.population()
        body = bodies.index(14)
        for meta, metric in zip(self.full["righting_metadata"], metrics, strict=True):
            if meta["body_index"] == body and ((meta["candidate_index"] == profiles.index(5) and meta["start_index"] == 1)
                or (meta["candidate_index"] == profiles.index(10) and meta["start_index"] == 0)):
                metric["trajectory_maximum_up_dot"] = -math.cos(math.radians(12.))
        result = self.assess(self.full, metrics)
        self.assertEqual(len(result["confirmed_pairs"]), 11)
        self.assertEqual(result["bodies_with_confirmed_pair"], 10)
        affected = [p for p in result["pairs"] if p["source_body_index"] == 14]
        self.assertEqual([p["starts_passed"] for p in affected], [1, 1])
        self.assertTrue(all(not p["confirmed"] for p in affected))

    def test_joint_failure_disqualifies_large_progress_at_either_start(self):
        for start in (0, 1):
            metrics = self.metrics(self.full)
            for meta, metric in zip(self.full["righting_metadata"], metrics, strict=True):
                if meta["body_index"] == 0 and meta["candidate_index"] > 2 and meta["start_index"] == start:
                    metric.update(joint_limit_violation_steps=1, trajectory_maximum_up_dot=0.)
            result = self.assess(self.full, metrics)
            self.assertEqual(len(result["confirmed_pairs"]), 12)
            self.assertIn("joint_limit_violation", result["pairs"][0]["starts"][start]["failure_codes"])

    def test_model_withdrawal_and_gain_against_only_one_reference_disqualify(self):
        metrics = self.metrics(self.full)
        for meta, metric in zip(self.full["righting_metadata"], metrics, strict=True):
            if meta["body_index"] == 0 and meta["candidate_index"] > 2 and meta["start_index"] == 0:
                metric.update(response_search_failures=1, response_search_replans=self.full["outer_steps"]-1)
            if meta["body_index"] == 1 and meta["candidate_index"] == 2 and meta["start_index"] == 1:
                metric["trajectory_maximum_up_dot"] = -math.cos(math.radians(17.))
        result = self.assess(self.full, metrics)
        self.assertEqual(len(result["confirmed_pairs"]), 11)
        self.assertIn("response_model_withdrawal", result["pairs"][0]["starts"][0]["failure_codes"])
        self.assertEqual(result["pairs"][1]["starts"][1]["failure_codes"], ["insufficient_gain_against_unchanged"])
        self.assertFalse(result["recovery_qualified"] or result["trained"] or result["release_authority"])

    def test_missing_duplicate_crossed_and_nonfinite_observations_refuse(self):
        screen = trajectory.assess(self.full, self.metrics(self.full))
        changes = [lambda s: s["groups"].pop(),
            lambda s: s["groups"][0]["observations"].pop(),
            lambda s: s["groups"][0]["observations"].append(copy.deepcopy(s["groups"][0]["observations"][0])),
            lambda s: s["groups"][0]["observations"][0].update(start_index=1),
            lambda s: s["groups"][0]["observations"][0].update(candidate_id="crossed"),
            lambda s: s["groups"][0].update(reference_candidate_index=1),
            lambda s: s["groups"].append(dict(body_index=99, condition_index=0, start_index=0, reference_candidate_index=2, observations=[])),
            lambda s: s["groups"][0]["observations"][0].update(peak_gain_against_timed_degrees=float("nan"))]
        for change in changes:
            bad = copy.deepcopy(screen)
            change(bad)
            with self.assertRaises(ValueError): subject.assess(self.full, bad)

    def test_short_route_checks_new_rolls_replay_counts_and_protected_coverage(self):
        metrics = self.metrics(self.route)
        screen = trajectory.assess(self.route, metrics)
        assessed = subject.assess(self.route, screen)
        self.assertEqual(assessed["confirmed_pairs"], [])
        self.assertFalse(assessed["full_horizon"])
        audit = dict(ok=True, synthetic=False, reader_world_build_count=0, gpu_worlds=10,
            controller_rows_replayed=20, native_rows_verified=100, metrics=metrics,
            trajectory_screen=screen, response_confirmation=assessed)
        receipt = dict(contract=self.route, audit=audit)
        self.assertTrue(subject.verify_route(receipt)["complete"])
        for change in (lambda r: r["audit"].update(controller_rows_replayed=19),
                lambda r: r["audit"].update(native_rows_verified=99),
                lambda r: r["audit"].update(reader_world_build_count=1),
                lambda r: r["audit"]["metrics"][3].update(response_search_replans=0, response_search_brakes=2),
                lambda r: r["contract"]["initial_roll_angles_rad"].__setitem__(0, math.pi)):
            bad = copy.deepcopy(receipt)
            change(bad)
            with self.assertRaises(ValueError): subject.verify_route(bad)
        core = native.bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        with ExitStack() as cleanup:
            controllers = [search.SearchController(core, c, seed=self.route["seed"]) for c in self.route["cells"]]
            for c in controllers: cleanup.callback(c.close)
            qpos, qvel = native.initial_arrays([c.creature for c in controllers], self.route)
            self.assertEqual(qvel.tolist(), [[0.]*14]*10)
            for row, roll in zip(qpos, self.route["initial_roll_angles_rad"], strict=True):
                self.assertEqual(row[3:7].tolist(), np.asarray([math.cos(roll/2), math.sin(roll/2), 0., 0.], np.float32).tolist())


if __name__ == "__main__":
    unittest.main()
