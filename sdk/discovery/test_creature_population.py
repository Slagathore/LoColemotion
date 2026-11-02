"""Zero-world population construction, censoring and full-reader controls."""
import copy
from contextlib import ExitStack
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import mujoco_warp as mjw

import creature_native as route
import creature_population as population
from showcase_model import S169, generated


class CreaturePopulationControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.base = json.loads((route.HERE / "creature_route_v2.json").read_text())
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.profiles = [
            dict(id="baseline", factor=None, ordered_coefficients=[0.]*8),
            dict(id="candidate_a", factor=0., ordered_coefficients=[.10]*8),
            dict(id="candidate_b", factor=0., ordered_coefficients=[.11]*8),
            dict(id="candidate_c", factor=0., ordered_coefficients=[-.10]*8),
        ]

    def setUp(self):
        self.traps = ExitStack()
        self.addCleanup(self.traps.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            self.traps.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in population gate")))
        for name in ("put_model", "put_data", "make_data", "step1", "step2"):
            self.traps.enter_context(patch.object(mjw, name, side_effect=AssertionError("Native population in gate")))

    def contract(self, *, bodies=2, profiles=4, starts=2):
        spec = dict(schema_version="locolemotion_creature_population_v1",
            descriptors=[copy.deepcopy(S169), generated(6100)][:bodies],
            profiles=copy.deepcopy(self.profiles[:profiles]),
            conditions=[dict(id="nominal", motor_effectiveness=[1.]*8),
                        dict(id="left_075", motor_effectiveness=[.75,.75,1.,1.,.75,.75,1.,1.])],
            starts=[dict(id="exposed_001", lateral_velocity_m_s=.001),
                    dict(id="exposed_003", lateral_velocity_m_s=.003)][:starts])
        c = copy.deepcopy(self.base)
        c.update(mode="development_discovery", batch_partition="body_shape", population_spec=spec,
                 selection=copy.deepcopy(population.DEFAULT_SELECTION), outer_steps=240)
        c["ledger_scope"]["authority_mode"] = "development_discovery"
        c.update(population.expand(spec))
        c["naconmax"] = len(c["cells"])*64
        c["safety_controls"] = [dict(name=n, module=m, count=k) for n, m, k in route.gates(c)]
        return c

    def metrics(self, c):
        return [dict(minimum_height_m=.4, maximum_tilt_rad=.1, torso_contact_steps=0,
            safe_no_actuation_steps=0, ground_contact_steps=10, nonzero_force_steps=10,
            forward_displacement_m=[.2,.3,.3,.28][m["candidate_index"]], lateral_displacement_m=0.)
            for m in c["population_metadata"]]

    def test_cartesian_expansion_is_complete_deterministic_and_isolated(self):
        c = self.contract()
        self.assertEqual(len(c["cells"]), 32)
        self.assertEqual(population.expand(c["population_spec"]), {k:c[k] for k in
            ("cells", "initial_lateral_velocities_m_s", "population_metadata")})
        self.assertEqual(len({v["cell_id"] for v in c["cells"]}), 32)
        self.assertEqual(c["population_metadata"][8]["condition_id"], "left_075")
        c["cells"][0]["profile"]["ordered_coefficients"][0] = .2
        c["cells"][0]["descriptor"]["torso_length_scale"] = 1.
        self.assertEqual(c["population_spec"]["profiles"][0]["ordered_coefficients"], [0.]*8)
        with self.assertRaises(ValueError): population.verify_expansion(c)

    def test_duplicate_shapes_profiles_conditions_starts_and_excess_budget_refuse(self):
        base = self.contract()["population_spec"]
        for kind in ("shape", "profile", "condition", "start", "baseline", "budget", "nonfinite"):
            spec = copy.deepcopy(base)
            if kind == "shape":
                spec["descriptors"][1] = dict(spec["descriptors"][0], morphology_id="alias")
            if kind == "profile": spec["profiles"][1] = copy.deepcopy(spec["profiles"][0])
            if kind == "condition": spec["conditions"][1]["motor_effectiveness"] = [1.]*8
            if kind == "start": spec["starts"][1]["lateral_velocity_m_s"] = .001
            if kind == "baseline": spec["profiles"][0]["factor"] = 0.
            if kind == "budget": spec["descriptors"] = [generated(i) for i in range(65)]
            if kind == "nonfinite": spec["conditions"][1]["motor_effectiveness"][0] = math.nan
            with self.assertRaises(ValueError): population.expand(spec)

    def test_declaration_refuses_forged_expansion_missing_gate_and_selection(self):
        path = route.HERE / "creature_breadth_v1.json"
        original = json.loads(path.read_text())
        for key, value in (("cells", []), ("population_metadata", []), ("mode", "route_ghost"),
                           ("batch_partition", "single"), ("safety_controls", []), ("selection", {})):
            c = copy.deepcopy(original); c[key] = value
            with patch.object(Path, "read_text", return_value=json.dumps(c)):
                with self.assertRaises(ValueError): route.declaration(path)
        for key, value in (("minimum_height_m", math.nan), ("maximum_tilt_rad", 4.),
                           ("minimum_ground_contact_steps", 0), ("shortlist_per_body_condition", 0),
                           ("target_planar_velocity_m_s", [9., 0.])):
            selection = copy.deepcopy(population.DEFAULT_SELECTION); selection[key] = value
            with self.assertRaises(ValueError): population.validate_selection(selection)

    def test_declared_240_cells_compile_to_24_shapes_without_native_construction(self):
        c = route.declaration(route.HERE / "creature_breadth_v1.json")
        result = route.preflight(c, self.core_path)
        self.assertEqual((result["world_build_count"], result["solver_steps"]), (0, 0))
        self.assertEqual((result["planned_gpu_worlds"], result["distinct_body_shapes"], len(result["batches"])), (240, 24, 24))
        self.assertEqual([len(g["cell_indices"]) for g in result["batches"]], [10]*24)
        self.assertEqual(len({b["model_xml_sha256"] for b in result["bindings"]}), 48)
        self.assertEqual(sum(k for _, _, k in route.gates(c)), 117)

    def test_selection_censors_failures_keeps_hard_bodies_and_requires_all_starts(self):
        c = self.contract(); metrics = self.metrics(c)
        for meta, metric in zip(c["population_metadata"], metrics, strict=True):
            bi, ci, pi, si = [meta[k] for k in ("body_index", "condition_index", "candidate_index", "start_index")]
            if (bi, ci) == (1, 0) or (bi, ci, pi, si) in ((0, 1, 0, 1), (1, 1, 1, 1)):
                metric["minimum_height_m"] = .1
        bindings = route.preflight(c, self.core_path)["bindings"]
        result = population.assess(c, metrics, bindings)
        self.assertEqual(len(result["episodes"]), 32)
        self.assertEqual(result["performance_failed_worlds"], 10)
        groups = result["body_conditions"]
        self.assertEqual([g["shortlist_candidate_indices"] for g in groups], [[1, 3], [1, 3], [], [2, 3]])
        self.assertEqual(groups[0]["ranked_candidate_indices"], [1, 2, 3])
        self.assertTrue(all(r["baseline_minus_error_m_s"] is None for r in groups[1]["candidates"]))
        self.assertIsNone(groups[3]["candidates"][1]["mean_velocity_error_m_s"])
        self.assertTrue(all(e["velocity_error_m_s"] is None for e in result["episodes"] if not e["eligible"]))
        self.assertFalse(result["trained"] or result["physical_acceptance_authority"])

    def test_incomplete_crossed_nonfinite_and_impossible_metrics_refuse(self):
        c = self.contract(); metrics = self.metrics(c)
        bindings = route.preflight(c, self.core_path)["bindings"]
        with self.assertRaises(ValueError): population.assess(c, metrics[:-1], bindings)
        with self.assertRaises(ValueError): population.assess(c, metrics, bindings[::-1])
        for key, value in (("minimum_height_m", math.inf), ("safe_no_actuation_steps", -1),
                           ("ground_contact_steps", 1201), ("maximum_tilt_rad", 4.)):
            changed = copy.deepcopy(metrics); changed[0][key] = value
            with self.assertRaises(ValueError): population.assess(c, changed, bindings)

    def test_full_reader_derives_censored_population_from_retained_synthetic_streams(self):
        import test_creature_native as fixtures
        c = self.contract(bodies=1, profiles=2, starts=1)
        c["outer_steps"] = 3
        with patch.object(route, "declaration", return_value=copy.deepcopy(c)):
            fixtures.CreatureNativeControls.setUpClass()
        fixture = fixtures.CreatureNativeControls()
        c, folder = fixture.grouped_fixture()
        result = route.audit(folder, c, self.core_path, synthetic=True)
        self.assertEqual((result["controller_rows_replayed"], result["native_rows_verified"]), (12, 60))
        self.assertEqual(result["assessment"]["world_count"], 4)
        self.assertEqual(result["assessment"]["performance_failed_worlds"], 4)
        self.assertTrue(all(e["failure_codes"] == ["no_actuator_force"] and e["velocity_error_m_s"] is None
                            for e in result["assessment"]["episodes"]))
        self.assertTrue(all(g["shortlist_candidate_indices"] == [] for g in result["assessment"]["body_conditions"]))
        with self.assertRaises(ValueError): route.audit(folder, c, self.core_path)


if __name__ == "__main__":
    unittest.main()
