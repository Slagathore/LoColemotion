"""Analytical, real-interface and paired-population controls; never step physics."""
import copy
from contextlib import ExitStack
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco

import creature_joint_braking as guard
import creature_joint_braking_search as search
import creature_native as native
import creature_righting as righting
import run_creature_native as owner
from creature_batch import bridge
from creature_trajectory_diagnosis import Motion, f32
from test_creature_batch import fixture, observation
from test_creature_righting import profiles, population
from test_creature_trajectory_diagnosis import fixture as motion_fixture, row as motion_row
from test_portable_search import _fixture


class BrakingControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.core = bridge.LocomotionCore(cls.core_path)
        cls.template = _fixture(cls.core)["provider_request"]["state"]

    def setUp(self):
        trap = ExitStack()
        self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in braking controls")))

    def batch(self, sequence=False):
        spec = population()
        base = search.spec(search.RECIPE)["profiles"][2] if sequence else profiles()[1]
        guarded = copy.deepcopy(base)
        guarded.update(id=base["id"] + "_guard", joint_braking=copy.deepcopy(search.POLICY))
        spec["starts"] = [spec["starts"][0]]
        template = righting.expand(spec)["cells"][1]
        # The pair is a controller-unit fixture, not a discovery population.
        cells = [dict(copy.deepcopy(template), cell_id="braking_fixture_" + str(i), profile=p)
                 for i, p in enumerate((base, guarded))]
        batch = righting.RightingBatch(self.core, cells, seed=1061123)
        self.addCleanup(batch.close)
        return batch

    def observations(self, batch, step=0):
        result = [observation(c, fixture(c.creature, self.template), step) for c in batch.controllers]
        for o in result:
            o["state"]["base_pose_world"]["orientation_xyzw"] = dict(x=1., y=0., z=0., w=0.)
        return result

    def test_01_analytical_projection_and_mirrored_envelopes(self):
        args = dict(speed=2., lower=-1., upper=1., dt=1/120, settings=search.POLICY)
        high = guard.shape(.95, 1., 2., **args)
        self.assertAlmostEqual(high["shaped_velocity_rad_s"], math.sqrt(.1), places=13)
        self.assertAlmostEqual(high["predicted_position_rad"], .95 + 1/60)
        low = guard.shape(-.95, -1., -2., **args)
        self.assertEqual(low["shaped_velocity_rad_s"], -high["shaped_velocity_rad_s"])
        stopped = guard.shape(.95, 0., 2., **args)
        self.assertAlmostEqual(stopped["shaped_velocity_rad_s"], math.sqrt(.3), places=13)
        self.assertGreater(stopped["shaped_velocity_rad_s"], high["shaped_velocity_rad_s"])
        self.assertEqual(guard.shape(.99, 1., 2., **args)["shaped_velocity_rad_s"], 0.)
        self.assertEqual(guard.shape(.99, 1., -2., **args)["shaped_velocity_rad_s"], -2.)
        self.assertEqual(guard.shape(0., 0., .2, **args)["shaped_velocity_rad_s"], .2)

    def test_02_nonfinite_type_and_policy_refusals(self):
        for key, value in (("schema_version", "changed"), ("margin_rad", True), ("margin_rad", math.nan),
                ("margin_rad", 0.), ("lookahead_steps", 1.), ("lookahead_steps", 0),
                ("braking_acceleration_rad_s2", math.inf), ("braking_acceleration_rad_s2", 0.)):
            bad = dict(search.POLICY); bad[key] = value
            with self.assertRaises(ValueError): guard.policy(bad)
        for bad in ({}, dict(search.POLICY, extra=1)):
            with self.assertRaises(ValueError): guard.policy(bad)
        values = [.95, 1., 2., 2., -1., 1., 1/120]
        for i in range(len(values)):
            for bad in (True, math.nan, math.inf):
                args = values[:]; args[i] = bad
                with self.assertRaises(ValueError): guard.shape(*args, search.POLICY)
        with self.assertRaises(ValueError):
            guard.shape(1.79e308, 1.79e308, 1., 2., -1., 1., .1,
                        dict(search.POLICY, lookahead_steps=4))

    def test_03_profile_identity_ownership_and_legacy_record(self):
        batch = self.batch()
        a, b = batch.controllers
        self.assertNotEqual(righting.behavior_key(a.candidate), righting.behavior_key(b.candidate))
        candidate = copy.deepcopy(b.candidate)
        validated = righting.profile(candidate)
        candidate["joint_braking"]["margin_rad"] = .08
        self.assertEqual(validated["joint_braking"]["margin_rad"], .025)
        for key, value in (("margin_rad", .03), ("lookahead_steps", 3), ("braking_acceleration_rad_s2", 7.)):
            changed = copy.deepcopy(b.candidate); changed["joint_braking"][key] = value
            self.assertNotEqual(righting.behavior_key(b.candidate), righting.behavior_key(changed))
        rows = batch.step(self.observations(batch))
        self.assertEqual(rows[0]["native_targets"], rows[1]["native_targets"])
        for old, new in zip(rows[0]["resolution"]["ordered_commands"], rows[1]["resolution"]["ordered_commands"], strict=True):
            self.assertNotIn("anticipatory_joint_braking", old)
            self.assertFalse(new["anticipatory_joint_braking"]["applied"])
            self.assertEqual(old, {k:v for k,v in new.items() if k != "anticipatory_joint_braking"})
        with self.assertRaises(ValueError):
            righting.profile(dict(profiles()[0], joint_braking=search.POLICY))

    def test_04_real_observation_overrides_outward_slew_before_limit(self):
        batch = self.batch()
        for c in batch.controllers: c.previous = [1.] * 8
        obs = self.observations(batch)
        for o, c in zip(obs, batch.controllers, strict=True):
            for joint, bounds in zip(o["state"]["ordered_joint_observations"], c.spec["joints"], strict=True):
                joint.update(position_rad=bounds["upper_limit_rad"]-.01, velocity_rad_s=2.)
        rows = batch.step(obs)
        self.assertTrue(all(v > 0 for v in rows[0]["native_targets"]))
        self.assertEqual(rows[1]["native_targets"], [0.] * 8)
        self.assertTrue(all(c["joint_guard_applied"] and not c["observed_joint_limit_breach"]
                            for c in rows[1]["resolution"]["ordered_commands"]))
        self.assertTrue(all(c["anticipatory_joint_braking"]["applied"]
                            for c in rows[1]["resolution"]["ordered_commands"]))

    def test_05_observed_bound_rule_remains_after_prediction(self):
        batch = self.batch()
        for c in batch.controllers: c.previous = [1.] * 8
        obs = self.observations(batch)
        for o, c in zip(obs, batch.controllers, strict=True):
            for joint, bounds in zip(o["state"]["ordered_joint_observations"], c.spec["joints"], strict=True):
                joint.update(position_rad=bounds["upper_limit_rad"]+.01, velocity_rad_s=-10.)
        rows = batch.step(obs)
        self.assertTrue(all(v <= 0 for r in rows for v in r["native_targets"]))
        self.assertTrue(all(c["observed_joint_limit_breach"] for r in rows for c in r["resolution"]["ordered_commands"]))

    def test_06_invalid_late_observation_does_not_commit_any_controller(self):
        batch = self.batch(sequence=True)
        for c in batch.controllers: c.previous = [1.] * 8
        before = [(copy.deepcopy(c.previous), c.step_index, copy.deepcopy(c.sequence_state)) for c in batch.controllers]
        obs = self.observations(batch)
        obs[-1]["state"]["ordered_joint_observations"][-1]["velocity_rad_s"] = math.nan
        with self.assertRaises(ValueError): batch.step(obs)
        self.assertEqual(before, [(c.previous, c.step_index, c.sequence_state) for c in batch.controllers])
        rows = batch.step(self.observations(batch))
        self.assertEqual(rows[0]["resolution"]["sequence"], rows[1]["resolution"]["sequence"])
        self.assertTrue(all(c.step_index == 1 for c in batch.controllers))

    def test_07_independent_reader_matches_analytical_guard_and_refuses_wrong_command(self):
        p, creature, identity = motion_fixture()
        p["joint_braking"] = copy.deepcopy(search.POLICY)
        reader = Motion(p, creature, identity)
        reader.previous = [1.] * 8
        r = motion_row(command=math.sqrt(.1), prepared=.95, sampled=.96)
        r["prepared_qvel"] = [0.] * 6 + [1.] * 8
        reader.consume(r)
        self.assertEqual(reader.counts["anticipatory_braking_commands"], 8)
        wrong = Motion(p, creature, identity); wrong.previous = [1.] * 8
        r["native_targets"] = [f32(.8)] * 8
        with self.assertRaises(ValueError): wrong.consume(r)

    def test_08_paired_population_preserves_every_pose_clock_and_failure(self):
        original = search.source()
        spec = search.spec(search.RECIPE)
        self.assertEqual(len(righting.expand(spec)["cells"]), 224)
        self.assertEqual(spec["profiles_by_body"], original["profiles_by_body"])
        for old, unbraked, braked in zip(original["profiles"][3::2], spec["profiles"][2::2], spec["profiles"][3::2], strict=True):
            self.assertEqual({k:v for k,v in old.items() if k != "id"},
                             {k:v for k,v in unbraked.items() if k != "id"})
            self.assertEqual({k:v for k,v in unbraked.items() if k != "id"},
                             {k:v for k,v in braked.items() if k not in ("id", "joint_braking")})
        rows = spec["profiles_by_body"]
        for i in range(2, 50, 2):
            self.assertEqual(sum(i in r for r in rows), 4)
            self.assertTrue(all((i in r) == (i+1 in r) for r in rows))
        self.assertEqual([len(r) for r in rows], [14]*16)
        self.assertTrue({"wave_05_slow3_braked", "impulse_05_slow3_braked",
                         "waypoint_01_slow3_braked", "waypoint_13_slow3_braked"}
                        <= {p["id"] for p in spec["profiles"]})
        self.assertEqual(len({righting.behavior_key(p) for p in spec["profiles"]}), 50)

    def test_09_actual_declarations_preflight_and_archive_all_inputs(self):
        expected = {native.HERE / n for n in ("creature_trajectory_search_v1.json",
                    "creature_trajectory_retiming_v1.json", "creature_joint_braking_route_v1.json",
                    "creature_joint_braking_v1.json")}
        for name, count, bodies in (("creature_joint_braking_route_v1.json", 14, 1),
                                    ("creature_joint_braking_v1.json", 224, 16)):
            path = native.HERE / name
            c = native.declaration(path)
            report = native.preflight(c, self.core_path)
            self.assertEqual((report["world_build_count"], report["solver_steps"]), (0, 0))
            self.assertEqual((report["planned_gpu_worlds"], report["distinct_body_shapes"]), (count, bodies))
            self.assertTrue(all(len(g["cell_indices"]) == 14 for g in report["batches"]))
            paths = owner.source_paths(path, c)
            self.assertEqual(len(paths), len(set(paths)))
            self.assertTrue(expected <= set(paths))
            self.assertTrue(all(p.is_file() and p.is_relative_to(native.ROOT) for p in paths))
            self.assertEqual(sum(k for _,_,k in native.gates(c)), 175)

    def test_10_declared_pairing_gate_and_legacy_scope_refuse_drift(self):
        c = native.declaration(native.HERE / "creature_joint_braking_v1.json")
        for change in (lambda x:x["righting_spec"]["profiles"][3]["joint_braking"].update(margin_rad=.03),
                lambda x:x["righting_spec"]["profiles_by_body"][0].pop(),
                lambda x:x.update(outer_steps=720), lambda x:x.update(seed=1),
                lambda x:x.update(maximum_worlds_per_batch=4), lambda x:x.pop("joint_braking_search")):
            bad = copy.deepcopy(c); change(bad)
            with self.assertRaises(ValueError): search.validate(bad)
        old = native.declaration(native.HERE / "creature_trajectory_search_v1.json")
        self.assertEqual(sum(k for _,_,k in native.gates(old)), 159)
        self.assertEqual(search.source_dependencies(old), [])
        self.assertEqual(righting.SELECTION, c["righting_selection"])


if __name__ == "__main__":
    unittest.main()
