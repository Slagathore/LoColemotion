"""Sequence transitions, rigid-body mechanics and shared-reader controls."""
import copy
from contextlib import ExitStack
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_righting as righting
import creature_righting_sequence as subject
from actuation_recovery_mechanics import RigidTree, quaternion_rotation, xyz
from creature_batch import bridge
from showcase_model import S169, generated
from test_creature_batch import fixture, observation
import test_creature_righting as existing
from test_creature_righting import population, profiles
from test_portable_search import _fixture


def candidate(staggered=True):
    poses = [[.8, .8, -.4, -.4, -.8, -.8, .4, .4],
             [-.8, .4, .8, -.4, .4, .8, -.4, -.8],
             [.4, -.8, -.4, .8, -.8, .4, .8, -.4], [0.]*8]
    return dict(id="staggered" if staggered else "synchronous", mode=subject.MODE,
        axis_body=[1., 0., 0.], minimum_progress_rate_rad_s=.01,
        position_gain_s_inv=10., maximum_speed_rad_s=3.5, maximum_slew_rad_s_per_step=.2,
        phases=[dict(id=name, pose=pose, limb_delay_steps=[0, 1, 2, 3] if staggered else [0]*4,
            minimum_hold_steps=12, maximum_hold_steps=16, advance_when=gate, threshold=threshold)
            for name, pose, gate, threshold in zip(("windup", "drive", "follow_through", "catch"), poses,
                ("pose", "progress", "progress", "contact"), (.1, 25., 100., 2), strict=True)])


class SequenceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.core = bridge.LocomotionCore(cls.core_path)
        cls.template = _fixture(cls.core)["provider_request"]["state"]
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"])/"creature-righting-sequence"
        cls.root.mkdir()

    def setUp(self):
        trap = ExitStack(); self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in sequence controls")))

    def batch(self, spec=None):
        if spec is None:
            spec = population(); spec["profiles"] += [candidate()]
        result = righting.RightingBatch(self.core, righting.expand(spec)["cells"], seed=1061119)
        self.addCleanup(result.close)
        return result

    def observations(self, batch, step=0):
        return existing.RightingControls.observations(self, batch, step)

    def test_mechanics_match_scalar_jacobians_and_analytic_translation(self):
        rng = np.random.Generator(np.random.PCG64(1061119))
        batch = self.batch(population([S169]+[generated(i) for i in range(12000, 12007)]))
        for cell in batch.controllers[::4]:
            state = observation(cell, fixture(cell.creature, self.template), 0)["state"]
            tree = RigidTree(cell.spec)
            for joint in state["ordered_joint_observations"]:
                joint.update(position_rad=float(rng.uniform(-.5, .5)), velocity_rad_s=float(rng.uniform(-1., 1.)))
            q = rng.normal(size=4); q /= np.linalg.norm(q)
            state["base_pose_world"]["orientation_xyzw"] = dict(zip("xyzw", q.tolist()))
            state["base_twist_world"] = dict(linear_velocity_m_s=dict(x=.2, y=-.1, z=.3),
                                            angular_velocity_rad_s=dict(x=.3, y=.2, z=-.1))
            frame = tree.kinematics(xyz(state["base_pose_world"]["position_m"]), q,
                [j["position_rad"] for j in state["ordered_joint_observations"]])
            rates = np.asarray([j["velocity_rad_s"] for j in state["ordered_joint_observations"]])
            velocity, angular, spin = [], [], []
            base_v, base_w = [xyz(state["base_twist_world"][k]) for k in ("linear_velocity_m_s", "angular_velocity_rad_s")]
            for i, body in enumerate(tree.bodies):
                jv, jw = tree.jacobian(frame, body["body_id"], frame["centers"][i])
                velocity.append(base_v+np.cross(base_w, frame["centers"][i]-frame["positions"][0])+jv @ rates)
                angular.append(base_w+jw @ rates)
                spin.append(frame["rotations"][i] @ np.diag(xyz(body["inertia_diagonal_kg_m2"])) @ frame["rotations"][i].T @ angular[-1])
            velocity = np.asarray(velocity); com_v = np.average(velocity, axis=0, weights=tree.mass)
            momentum = np.sum(np.asarray(spin)+np.cross(frame["centers"]-frame["whole_body_com"], tree.mass[:, None]*(velocity-com_v)), axis=0)
            kinetic = .5*sum(m*float(v @ v)+float(w @ s) for m, v, w, s in zip(tree.mass, velocity, angular, spin, strict=True))
            actual = subject.mechanics(tree, state, [1., 0., 0.])
            np.testing.assert_allclose(actual["com_velocity_world_m_s"], com_v, rtol=0., atol=1e-13)
            np.testing.assert_allclose(actual["angular_momentum_world_kg_m2_s"], momentum, rtol=0., atol=1e-13)
            self.assertAlmostEqual(actual["kinetic_energy_j"], kinetic, places=13)
            for j in state["ordered_joint_observations"]: j["velocity_rad_s"] = 0.
            state["base_twist_world"]["angular_velocity_rad_s"] = dict(x=0., y=0., z=0.)
            actual = subject.mechanics(tree, state, [1., 0., 0.])
            self.assertAlmostEqual(actual["kinetic_energy_j"], .5*sum(tree.mass)*float(base_v @ base_v), places=13)
            np.testing.assert_allclose(actual["angular_momentum_world_kg_m2_s"], [0.]*3, rtol=0., atol=1e-13)

    def test_delay_measured_gates_timeout_cycle_and_upright_reset(self):
        batch = self.batch(); cell = batch.controllers[2]; state = self.observations(batch)[2]["state"]
        p = candidate(); tree = cell.sequence_tree; rotation = quaternion_rotation([1., 0., 0., 0.])
        decision = subject.plan(p, tree, state, rotation, 0, None, False)
        self.assertEqual(decision["normalized_targets"][2:], subject.normalized_pose(cell.spec,
            [j["position_rad"] for j in state["ordered_joint_observations"]])[2:])
        for j, q in zip(state["ordered_joint_observations"], subject.angles(cell.spec, p["phases"][0]["pose"]), strict=True): j["position_rad"] = float(q)
        memory = dict(phase=0, elapsed=12, cycle=0, held_pose=[0.]*8)
        before = copy.deepcopy(memory)
        d = subject.plan(p, tree, state, rotation, 0, memory, False)
        self.assertEqual((d["state_after"]["phase"], d["selection_reason"]), (1, "measured_pose"))
        self.assertEqual(d["normalized_targets"][2:], p["phases"][0]["pose"][2:]); self.assertEqual(memory, before)
        roll = math.pi+math.radians(30)
        state["base_pose_world"]["orientation_xyzw"] = dict(x=math.sin(roll/2), y=0., z=0., w=math.cos(roll/2))
        rotation = quaternion_rotation([state["base_pose_world"]["orientation_xyzw"][k] for k in "xyzw"])
        state["base_twist_world"]["angular_velocity_rad_s"] = dict(x=.2, y=0., z=0.)
        memory.update(phase=1)
        d = subject.plan(p, tree, state, rotation, 0, memory, False)
        self.assertEqual((d["state_after"]["phase"], d["selection_reason"]), (2, "measured_progress"))
        state["base_twist_world"]["angular_velocity_rad_s"]["x"] = -.2
        self.assertEqual(subject.plan(p, tree, state, rotation, 0, memory, False)["state_after"]["phase"], 1)
        memory["elapsed"] = 16
        self.assertEqual(subject.plan(p, tree, state, rotation, 0, memory, False)["selection_reason"], "bounded_fallback")
        memory.update(phase=3, elapsed=12)
        d = subject.plan(p, tree, state, rotation, 2, memory, False)
        self.assertEqual((d["state_after"]["phase"], d["state_after"]["cycle"], d["selection_reason"]), (0, 1, "measured_contact"))
        d = subject.plan(p, tree, state, rotation, 0, memory, True)
        self.assertEqual(d["normalized_targets"], [0.]*8); self.assertEqual(d["state_after"]["elapsed"], 0)

    def test_profile_refusals_and_behavior_aliases(self):
        for key, value in (("axis_body", [0., 1., 0.]), ("maximum_speed_rad_s", 3.6),
                ("minimum_progress_rate_rad_s", True), ("phases", [])):
            p = candidate(); p[key] = value
            with self.assertRaises(ValueError): subject.profile(p)
        for key, value in (("pose", [1.]*8), ("limb_delay_steps", [0, True, 0, 0]),
                ("limb_delay_steps", [12]*4), ("minimum_hold_steps", 16), ("maximum_hold_steps", 241),
                ("advance_when", "teleport"), ("threshold", math.nan), ("id", "drive")):
            p = candidate(); p["phases"][0][key] = value
            with self.assertRaises(ValueError): subject.profile(p)
        p = candidate(); p["phases"][1]["pose"] = p["phases"][0]["pose"][:]
        with self.assertRaises(ValueError): subject.profile(p)
        spec = population(); a, b = candidate(), candidate(); b["id"] = "alias"
        for i, phase in enumerate(b["phases"]): phase["id"] = f"renamed_{i}"
        spec["profiles"] += [a, b]
        with self.assertRaises(ValueError): righting.expand(spec)

    def test_geometry_seed_selection_preserves_ties_diversity_and_scope(self):
        poses = np.asarray([[v]*8 for v in (0., .1, .3, .6, -.6)])
        heights = np.full((8, 37, 5), 10.)
        rows = subject.geometry_seeds(heights, poses)
        self.assertEqual([r["azimuth_degrees"] for r in rows], list(range(0, 360, 45)))
        self.assertTrue(all(r["pose_indices"] == [1, 2, 3] for r in rows))
        heights[:, 4, 4] = 9.
        self.assertTrue(all(r["pose_indices"] == [1, 4, 2] for r in subject.geometry_seeds(heights, poses)))
        rows[0]["poses"][0][0] = 99.; self.assertEqual(poses[1, 0], .1)
        for bad in (np.zeros((8, 36, 5)), np.full((8, 37, 5), math.nan)):
            with self.assertRaises(ValueError): subject.geometry_seeds(bad, poses)
        with self.assertRaises(ValueError): subject.geometry_seeds(heights, np.zeros((5, 8)))

    def test_32_shapes_batch_scalar_caps_and_atomic_refusal(self):
        spec = population([S169]+[generated(i) for i in range(12000, 12031)])
        spec["profiles"] += [candidate(), candidate(False)]
        batch = self.batch(spec)
        scalars = [righting.RightingController(self.core, row, seed=1061119) for row in righting.expand(spec)["cells"]]
        self.addCleanup(lambda: [c.close() for c in scalars])
        self.assertEqual((len(batch.controllers), len({c.binding["body_shape_sha256"] for c in batch.controllers})), (256, 32))
        for step in range(67):
            observations = self.observations(batch, step)
            rows = batch.step(observations)
            self.assertEqual(rows, [c.step(o) for c, o in zip(scalars, observations, strict=True)])
            self.assertTrue(all(abs(v) <= 3.5 for row in rows for v in row["native_targets"]))
        before = [(c.step_index, copy.deepcopy(c.sequence_state), c.previous[:]) for c in batch.controllers]
        observations = self.observations(batch, 67)
        observations[-1]["state"]["base_twist_world"]["linear_velocity_m_s"]["x"] = math.nan
        with self.assertRaises(ValueError): batch.step(observations)
        self.assertEqual(before, [(c.step_index, c.sequence_state, c.previous) for c in batch.controllers])

    def test_yaw_covariance_and_input_output_ownership(self):
        left, right = self.batch(), self.batch(); yaw = .73
        turn = quaternion_rotation([0., math.sin(yaw/2), 0., math.cos(yaw/2)])
        for step in range(18):
            a, b = self.observations(left, step), self.observations(right, step)
            for o in a:
                o["state"]["base_twist_world"]["angular_velocity_rad_s"] = dict(x=.2, y=0., z=0.)
                o["state"]["base_twist_world"]["linear_velocity_m_s"] = dict(x=.2, y=0., z=.1)
            for o in b:
                o["state"]["base_pose_world"]["orientation_xyzw"] = dict(x=math.cos(yaw/2), y=0., z=-math.sin(yaw/2), w=0.)
                o["state"]["base_twist_world"]["angular_velocity_rad_s"] = dict(zip("xyz", (turn @ np.asarray([.2, 0., 0.])).tolist()))
                o["state"]["base_twist_world"]["linear_velocity_m_s"] = dict(zip("xyz", (turn @ np.asarray([.2, 0., .1])).tolist()))
            aa, bb = left.step(a)[2], right.step(b)[2]
            self.assertEqual(aa["native_targets"], bb["native_targets"])
            ma, mb = [r["resolution"]["sequence"]["mechanics"] for r in (aa, bb)]
            np.testing.assert_allclose(ma["angular_momentum_body_kg_m2_s"], mb["angular_momentum_body_kg_m2_s"], rtol=0., atol=1e-12)
            self.assertAlmostEqual(ma["kinetic_energy_j"], mb["kinetic_energy_j"], places=12)
        aa["resolution"]["sequence"]["state_after"]["held_pose"][0] = 99.
        self.assertLessEqual(abs(left.controllers[2].sequence_state["held_pose"][0]), .9)
        left.close()
        with self.assertRaises(ValueError): left.step(self.observations(left, 18))

    def test_sampled_work_uses_force_and_displacement_with_signed_channels(self):
        metric = subject.initial_work()
        row = dict(joint_force_nm=[2., -3., 1., 0., 0., 0., 0., 0.], qpos=[0.]*7+[.1, .2, -.3, 0., 0., 0., 0., 0.], before_qpos=[0.]*15)
        subject.measure_work(metric, row)
        self.assertAlmostEqual(metric["sampled_joint_actuator_work_j"], -.7)
        self.assertAlmostEqual(metric["sampled_positive_joint_actuator_work_j"], .2)
        self.assertAlmostEqual(metric["sampled_negative_joint_actuator_work_j"], -.9)
        self.assertEqual(metric["sampled_work_intervals"], 1)
        before = copy.deepcopy(metric); row["joint_force_nm"][0] = math.nan
        with self.assertRaises(ValueError): subject.measure_work(metric, row)
        self.assertEqual(metric, before)

    def test_shortlist_uses_all_sequence_poses_without_changing_eligibility(self):
        spec = population(); a, b, c = candidate(), candidate(False), candidate()
        c["id"] = "reversed"
        for p in c["phases"]: p["pose"] = [-v for v in p["pose"]]
        spec["profiles"] = [profiles()[0], a, b, c]
        batch = self.batch(spec)
        contract = dict(righting_spec=spec, righting_selection=righting.SELECTION, outer_steps=120,
                        **righting.expand(spec))
        metrics = [dict(righting.initial_metrics(), terminal_upright_dwell_steps=300,
                        longest_upright_dwell_steps=300) for _ in batch.controllers]
        report = righting.assess(contract, metrics, batch.bindings)
        self.assertEqual([c["candidate_id"] for c in report["shortlists"][0]["candidates"]], [a["id"], c["id"]])
        metrics[1]["joint_limit_violation_steps"] = 1
        self.assertFalse(righting.assess(contract, metrics, batch.bindings)["episodes"][1]["eligible"])

    def test_full_shared_reader_replays_sequence_mechanics_and_rejects_forgery(self):
        existing.RightingControls._reader_case(self, False, sequence_profile=candidate())


if __name__ == "__main__":
    unittest.main()
