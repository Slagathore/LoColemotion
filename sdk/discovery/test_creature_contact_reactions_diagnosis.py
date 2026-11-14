"""Physical-frame and retained-stream controls for reaction comparisons."""
import copy
from contextlib import ExitStack
import io
import json
import math
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_contact_reactions_diagnosis as subject
from actuation_recovery_mechanics import RigidTree
from test_creature_contact_reactions import fixture as reaction_fixture


def fixture():
    vector = lambda x, y, z: dict(x=x, y=y, z=z)
    spec = dict(schema_version="sporespore_morphology_spec_v1",
        coordinate_frame_id="right_handed_x_forward_y_up_z_right_si_v1", joints=[], bodies=[dict(
            body_id="torso", parent_body_id=None, mass_kg=1., center_of_mass_local_m=vector(0., 0., 0.),
            inertia_diagonal_kg_m2=vector(1., 1., 1.))])
    profile = dict(id="fixture", axis_body=[0., 0., 1.], torque_map={})
    decision = dict(torque_map=dict(policy={}, active_limbs=[0]), state_after=dict(sign=1), active_limbs=[0],
        requested_wrenches=[dict(body_id="front_left_distal", point=[1., 0., 0.], force=[0., 2., 0.], torque=[0., 0., 0.])],
        proposed_moment_nm=2., post_guard_predicted_torque_nm=[0.]*8)
    reaction, native, binding, _ = reaction_fixture()
    native.update(before_qvel=[0.]*14, qpos=native["before_qpos"][:], qvel=[0.]*14, ctrl=[0.]*8, actuator_force_nm=[0.]*8)
    native["contacts"][0]["geom"] = [0, 3]
    row = dict(cell=0, outer_step=0, binding=dict(binding, cell_id="fixture", candidate_id="fixture"), native_targets=[0.]*8,
        request=dict(state=dict(semantic_step=0, ordered_joint_observations=[], base_pose_world=dict(
            position_m=vector(0., 0., 0.), orientation_xyzw=dict(x=0., y=0., z=0., w=1.)))),
        resolution=dict(body_moment=decision), native_observation=dict(qpos=native["before_qpos"][:],
            qvel=[0.]*14, subtree_com=[[0., 0., 0.], [0., 0., 0.]]))
    return row, profile, RigidTree(spec), reaction, native, binding


class ComparisonControls(unittest.TestCase):
    def setUp(self):
        traps = ExitStack(); self.addCleanup(traps.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            traps.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Unexpected physics")))

    def test_rotated_signed_axis_and_wrench_reconstruct_same_moment(self):
        row, profile, tree, *_ = fixture()
        for angle in (0., .7, math.pi):
            row["request"]["state"]["base_pose_world"]["orientation_xyzw"] = dict(x=math.sin(angle/2), y=0., z=0., w=math.cos(angle/2))
            row["resolution"]["body_moment"]["requested_wrenches"][0]["force"] = [0., 2*math.cos(angle), 2*math.sin(angle)]
            model = subject.prepared(row, profile, tree)
            self.assertAlmostEqual(model["proposed"], 2.)
            np.testing.assert_allclose(model["axis"], [0., -math.cos(angle), -math.sin(angle)], atol=1e-14)
        row["resolution"]["body_moment"]["state_after"]["sign"] = -1
        row["resolution"]["body_moment"]["requested_wrenches"][0]["force"] = [0., 2., 0.]
        model = subject.prepared(row, profile, tree)
        np.testing.assert_allclose(model["axis"], [0., -1., 0.], atol=1e-14)
        self.assertAlmostEqual(model["proposed"], 2.)

    def test_torso_cancels_identical_foot_moment(self):
        row, profile, tree, reaction, native, binding = fixture()
        model = subject.prepared(row, profile, tree)
        decoded = subject.reactions.verify(reaction, native, binding, 1, subject.GEOMS)
        before = subject.measured(model, decoded, reaction, native)
        decoded["moment_by_geom"][1] = -decoded["moment_by_geom"][3]
        after = subject.measured(model, decoded, reaction, native)
        self.assertEqual(before["moment_by_role_nm"], [2., 0., 0., 0., 2.])
        self.assertEqual(after["moment_by_role_nm"], [2., 0., -2., 0., 0.])

    def test_reference_shift_and_translation_do_not_change_physical_moment(self):
        row, profile, tree, reaction, native, binding = fixture()
        model = subject.prepared(row, profile, tree)
        decoded = subject.reactions.verify(reaction, native, binding, 1, subject.GEOMS)
        expected = subject.measured(model, decoded, reaction, native)
        shift = np.array([.4, -.2, .7])
        reaction["center_of_mass"] = shift.tolist()
        decoded["moment_by_geom"] -= np.cross(shift, decoded["force_by_geom"])
        shifted = subject.measured(model, decoded, reaction, native)
        np.testing.assert_allclose(shifted["moment_by_role_nm"], expected["moment_by_role_nm"], atol=1e-14)
        model["center"] += [3., 2., -1.]
        reaction["center_of_mass"] = (shift+[3., 2., -1.]).tolist()
        np.testing.assert_allclose(subject.measured(model, decoded, reaction, native)["moment_by_role_nm"], expected["moment_by_role_nm"], atol=1e-14)

    def test_first_sample_is_distinct_from_held_interval(self):
        row, profile, tree, reaction, native, binding = fixture()
        model = subject.prepared(row, profile, tree)
        decoded = subject.reactions.verify(reaction, native, binding, 1, subject.GEOMS)
        sample = subject.measured(model, decoded, reaction, native)
        later = copy.deepcopy(sample); later["moment_by_role_nm"] = [0.]*5
        summary = subject.Summary(); summary.add(dict(proposed_moment_nm=2., samples=[sample]+[later]*4))
        result = summary.finish()["positive_request"]
        self.assertEqual(result["first_moment_mean_by_role_nm"]["net"], 2.)
        self.assertEqual(result["held_moment_mean_by_role_nm"]["net"], .4)
        with self.assertRaisesRegex(ValueError, "five solved"):
            summary.add(dict(proposed_moment_nm=2., samples=[sample]*4))

    def test_zero_request_remains_separate_and_has_no_active_error(self):
        row, profile, tree, reaction, native, binding = fixture()
        d = row["resolution"]["body_moment"]
        d.update(active_limbs=[], requested_wrenches=[], proposed_moment_nm=0.)
        d["torque_map"]["active_limbs"] = []
        model = subject.prepared(row, profile, tree)
        decoded = subject.reactions.verify(reaction, native, binding, 1, subject.GEOMS)
        sample = subject.measured(model, decoded, reaction, native)
        self.assertIsNone(sample["active_torque_error_nm"])
        self.assertEqual(sample["moment_by_role_nm"], [0., 2., 0., 0., 2.])
        summary = subject.Summary(); summary.add(dict(proposed_moment_nm=0., samples=[sample]*5))
        self.assertEqual(summary.finish()["positive_request"], dict(intervals=0))
        self.assertEqual(summary.finish()["no_request"]["intervals"], 1)

    def test_wrong_profile_body_scalar_sign_or_nonfinite_force_refused(self):
        row, profile, tree, *_ = fixture()
        for mutate in (lambda d:d["torque_map"].update(policy={"different": True}),
                       lambda d:d["requested_wrenches"][0].update(body_id="torso"),
                       lambda d:d.update(proposed_moment_nm=3.),
                       lambda d:d["state_after"].update(sign=0),
                       lambda d:d["requested_wrenches"][0].update(force=[float("nan")]*3)):
            bad = copy.deepcopy(row); mutate(bad["resolution"]["body_moment"])
            with self.assertRaises(ValueError): subject.prepared(bad, profile, tree)

    def test_crossed_stale_and_changed_command_rows_refused(self):
        row, _, _, reaction, native, _ = fixture()
        subject.joined(row, native, reaction, 0, 0, 0, None)
        for change in (dict(cell=1), dict(step=2), dict(before_qpos=[1.]*15),
                       dict(before_qvel=[1.]*14), dict(ctrl=[1.]*8)):
            with self.assertRaises(ValueError):
                subject.joined(row, dict(native, **change), reaction, 0, 0, 0, None)
        with self.assertRaises(ValueError):
            subject.joined(row, native, reaction, 0, 0, 0, dict(qpos=[1.]*15, qvel=[0.]*14))

    def test_complete_stream_and_truncated_or_extra_population(self):
        row, profile, tree, reaction, native, binding = fixture()
        creature = dict(binding=binding, spec=dict(geom_names=subject.GEOMS),
            compiled=dict(morphology=dict(morphology_spec=tree.spec)), model_xml='<mujoco><option cone="elliptic"/></mujoco>')
        episode = dict(cell_id="fixture", eligible=False, failure_codes=["no_recovery"])
        receipt = dict(source_commit="fixture", contract=dict(contact_reactions=subject.reactions.POLICY, mode="route_ghost",
            capture_mode="full", righting_spec={}, internal_steps_per_outer=5, outer_steps=1,
            cells=[dict(cell_id="fixture", profile=profile)]), worker=dict(groups=[dict(batch_id="test", cell_indices=[0])]),
            audit=dict(capture=dict(controller_replay_verified=True, detailed_native_capture_verified=True),
                assessment=dict(episodes=[episode]), controller_rows_replayed=1, native_rows_verified=5))
        streams = dict(controller=[row], trace=[], reactions=[])
        for step in range(1, 6):
            streams["trace"].append(dict(native, step=step, time_s=step/600))
            streams["reactions"].append(dict(reaction, step=step, time_s=step/600))
        class Archive:
            verified = {}
            def document(self, _): return creature
            def lines(self, name):
                for value in streams[Path(name).stem]: yield json.dumps(value)
        with patch.object(subject, "bound_archive", return_value=(Archive(), receipt)):
            output = io.StringIO(); result = subject.diagnose(Path("fixture"), "fixture", output)
            self.assertEqual(result["counts"], dict(controller=1, native=5, modeled=1))
            self.assertEqual(result["outcomes"][0]["frozen_episode"], episode)
            self.assertEqual(len(json.loads(output.getvalue())["samples"]), 5)
            streams["reactions"].append(reaction)
            with self.assertRaisesRegex(ValueError, "extra stream"):
                subject.diagnose(Path("fixture"), "fixture", io.StringIO())
            streams["reactions"] = streams["reactions"][:4]
            with self.assertRaises(StopIteration):
                subject.diagnose(Path("fixture"), "fixture", io.StringIO())


if __name__ == "__main__":
    unittest.main()
