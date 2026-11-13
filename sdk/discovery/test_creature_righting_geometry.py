"""Geometry reconstruction and screening controls; all physics calls are trapped."""
import copy
from contextlib import ExitStack
import itertools
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_righting_geometry as subject
from creature_batch import bridge, compile_creature
from creature_righting import recovery_descriptor
from actuation_recovery_mechanics import quaternion_rotation
from showcase_model import S169, generated


class GeometryControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))

    def setUp(self):
        trap = ExitStack()
        self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in geometry controls")))

    def spec(self, descriptor=S169):
        creature = compile_creature(self.core, descriptor, recovery_descriptor=recovery_descriptor(descriptor))
        return creature["compiled"]["morphology"]["morphology_spec"]

    def test_batched_support_and_com_match_scalar_tree_across_32_shapes(self):
        rng = np.random.Generator(np.random.PCG64(1061118))
        poses = np.vstack((np.zeros(8), np.full(8, .9), np.full(8, -.9), rng.uniform(-.9, .9, (9, 8))))
        directions = [subject.gravity_direction(p, a) for p, a in ((0, 0), (15, 45), (45, 90), (90, 135), (135, 270), (180, 315))]
        for descriptor in [S169]+[generated(i) for i in range(12000, 12031)]:
            spec = self.spec(descriptor)
            model = subject.PoseGeometry(spec, poses)
            for up in directions:
                actual = model.evaluate(up)
                for i, pose in enumerate(poses):
                    expected = subject.scalar_reference(spec, pose, up)
                    for key in ("floor_height_m", "com_height_m"):
                        self.assertAlmostEqual(actual[key][i], expected[key], places=12)

    def test_zero_pose_support_has_independent_analytic_values(self):
        spec = self.spec()
        model = subject.PoseGeometry(spec, np.zeros((1, 8)))
        half = spec["bodies"][0]["collision"]["size_m"]["y"]/2
        inverted = model.evaluate([0., -1., 0.])
        self.assertAlmostEqual(inverted["floor_height_m"][0], half, places=14)
        self.assertEqual(inverted["lowest_body_indices"][0], 0)
        upper, distal = spec["bodies"][1:3]
        reach = upper["collision"]["length_m"]+distal["collision"]["length_m"]+distal["collision"]["radius_m"]
        self.assertAlmostEqual(model.evaluate([0., 1., 0.])["floor_height_m"][0], reach, places=14)

    def test_asymmetric_limits_and_input_ownership(self):
        spec = self.spec()
        spec["joints"][0].update(lower_limit_rad=-.8, upper_limit_rad=1.2)
        poses = np.asarray([[.9]*8, [-.9]*8])
        model = subject.PoseGeometry(spec, poses)
        self.assertAlmostEqual(model.joints[0, 0], 1.08)
        self.assertAlmostEqual(model.joints[1, 0], -.72)
        before = model.evaluate([0., -1., 0.])["com_height_m"].copy()
        poses[:] = 0.; spec["bodies"][0]["mass_kg"] = 100.
        result = model.evaluate([0., -1., 0.]); result["com_height_m"][:] = 0.
        np.testing.assert_array_equal(model.evaluate([0., -1., 0.])["com_height_m"], before)
        with self.assertRaises(ValueError): model.poses[0, 0] = 0.

    def test_general_revolute_axes_and_body_centers_are_preserved(self):
        spec = self.spec()
        spec["joints"][0]["axis_parent_unit"] = dict(x=1., y=0., z=0.)
        spec["bodies"][2]["center_of_mass_local_m"] = dict(x=.01, y=.02, z=-.01)
        pose = np.asarray([[.4, -.6, .8, -.2, -.5, .3, .1, .7]])
        model = subject.PoseGeometry(spec, pose)
        quaternion = np.asarray([.2, .3, -.1, .8]); quaternion /= np.linalg.norm(quaternion)
        up = quaternion_rotation(quaternion)[1]
        expected = subject.scalar_reference(spec, pose[0], up)
        for key in expected: self.assertAlmostEqual(model.evaluate(up)[key][0], expected[key], places=13)

    def test_factored_and_random_pools_are_bounded_unique_and_reproducible(self):
        states = [[0., 0.], [.9, .9], [-.9, -.9]]
        poses = subject.pose_pool(states, 64, 64, 41)
        self.assertEqual(poses.shape, (81+128, 8))
        expected = np.asarray([sum((states[i] for i in row), []) for row in itertools.product(range(3), repeat=4)])
        np.testing.assert_array_equal(poses[:81], expected)
        np.testing.assert_array_equal(poses, subject.pose_pool(states, 64, 64, 41))
        self.assertFalse(np.array_equal(poses[81:], subject.pose_pool(states, 64, 64, 42)[81:]))
        self.assertTrue(np.isfinite(poses).all() and np.max(np.abs(poses)) <= .9)

    def test_bad_pools_geometry_and_orientations_refuse(self):
        spec = self.spec()
        for poses in ([], [[True]*8], [[0.]*7], [[math.nan]*8], [[.9001]*8]):
            with self.assertRaises(ValueError): subject.PoseGeometry(spec, poses)
        for states, uniform, edge, seed in (([[0, 0]]*2, 0, 0, 1), ([[0, 0], [1, 1]], 0, 0, 1),
                ([[0, 0], [.9, .9]], True, 0, 1), ([[0, 0], [.9, .9]], 32768, 0, 1),
                ([[0, 0], [.9, .9]], 0, 0, -1)):
            with self.assertRaises(ValueError): subject.pose_pool(states, uniform, edge, seed)
        model = subject.PoseGeometry(spec, [[0.]*8])
        for direction in ([0, 0, 0], [0, 2, 0], [0, math.nan, 0], [True, False, False]):
            with self.assertRaises(ValueError): model.evaluate(direction)
        for kind in ("mesh", "sphere"):
            wrong = copy.deepcopy(spec); wrong["bodies"][0]["collision"]["kind"] = kind
            with self.assertRaises(ValueError): subject.PoseGeometry(wrong, [[0.]*8])

    def test_interval_minima_ties_and_numerical_band_are_explicit(self):
        table = np.asarray([[.1, .2, .3], [.12, .19, .29], [.13, .21, .33], [.13, .21, .33]])
        result = subject.interval_summary(table)
        self.assertEqual([r["classification"] for r in result],
            ["descending_sample_exists", "ascending_for_all_sampled_poses", "numerically_unresolved"])
        self.assertEqual(result[0]["witness_pose_index"], 1)
        self.assertEqual(result[1]["witness_pose_index"], 0)
        self.assertAlmostEqual(result[0]["minimum_delta_com_height_m"], -.01)
        for wrong in ([[0, 0]], [[0, math.inf], [0, 0]], [[True, False], [False, True]]):
            with self.assertRaises(ValueError): subject.interval_summary(wrong)
        with self.assertRaises(ValueError): subject.interval_summary(table, 1e-12, 1e-9)


if __name__ == "__main__":
    unittest.main()
