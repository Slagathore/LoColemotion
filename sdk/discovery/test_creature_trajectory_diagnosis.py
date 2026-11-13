"""Analytical motion cases and refusal controls; no simulator imports."""
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest

from creature_trajectory_diagnosis import Archive, Motion, f32


def fixture():
    joints = [dict(lower_limit_rad=-1., upper_limit_rad=1.) for _ in range(8)]
    spec = dict(joints=joints, actuators=[dict(maximum_target_speed_rad_s=1.) for _ in joints],
                contact_sites=[dict(body_id="foot")])
    creature = dict(compiled=dict(morphology=dict(morphology_spec=spec)),
                    spec=dict(geom_names=["ground", "torso", "foot_geom"], force_ranges=[[-2., 2.]] * 8))
    profile = dict(id="test", mode="rock", pose_a=[.5] * 8, pose_b=[-.5] * 8,
                   half_period_steps=12, position_gain_s_inv=1., maximum_speed_rad_s=1.,
                   maximum_slew_rad_s_per_step=.2)
    identity = dict(cell_id="test_cell", candidate_id="test", candidate_index=2, body_id="body", body_index=0)
    return profile, creature, identity


def row(command=.2, prepared=0., sampled=None, step=0):
    # Inverted stationary root, with a separately prescribed joint trajectory.
    base = [0., 0., .1, 0., 1., 0., 0.]
    samples = [dict(qpos=base + [sampled if sampled is not None else .2 * (i + 1) / 600] * 8,
        qvel=[0.] * 6 + [f32(.2)] * 8, actuator_force_nm=[2.] * 8,
        contacts=[dict(geom=[0, 2])]) for i in range(5)]
    return dict(outer_step=step, binding=dict(cell_id="test_cell", candidate_id="test"),
        safe_no_actuation=False, prepared_qpos=base + [prepared] * 8,
        native_targets=[f32(command)] * 8, samples=samples)


class DiagnosisTests(unittest.TestCase):
    def test_analytical_constant_velocity_and_force_response(self):
        motion = Motion(*fixture())
        motion.consume(row())
        out = motion.finish(dict(trajectory_samples=5, joint_limit_violation_steps=0,
                                 trajectory_distal_contact_samples=5))
        self.assertAlmostEqual(out["mean_absolute_position_error_rad"], .499)
        self.assertEqual(out["mean_absolute_velocity_error_rad_s"], 0.)
        self.assertEqual(out["counts"]["force_saturated_joint_samples"], 40)
        self.assertEqual(out["counts"]["distal_contact_samples"], 5)
        self.assertEqual(out["velocity_commands_matched"], 8)

    def test_measured_exit_minimum_hold_delay_and_timeout(self):
        profile, creature, identity = fixture()
        profile.update(mode="pose_sequence", phases=[dict(id=f"p{i}", pose=[target] * 8,
            minimum_hold_steps=12, maximum_hold_steps=14, limb_delay_steps=[2, 0, 0, 0],
            advance_when="pose", threshold=.03) for i, target in enumerate((0., .5, -.5))])
        motion = Motion(profile, creature, identity)
        for i in range(13):
            motion.step = i
            targets = motion.targets([0.] * 8)
        self.assertEqual(motion.phase, 1)
        self.assertEqual(targets, [0., 0.] + [.5] * 6)
        self.assertEqual(motion.phase_reports[0]["exit_reason"], "measured_pose")
        self.assertEqual(motion.phase_reports[0]["elapsed_steps"], 12)
        for i in range(13, 27):
            motion.step = i
            motion.targets([0.] * 8)
        self.assertEqual(motion.phase, 2)
        phase = motion.phase_reports[1]
        self.assertEqual(phase["exit_reason"], "bounded_fallback")
        self.assertEqual(phase["exit_maximum_pose_error_rad"], .5)
        self.assertEqual(phase["joints_missing_deadline_at_ideal_target_speed"], 8)
        self.assertEqual(phase["elapsed_steps"], 14)

    def test_joint_guard_overrides_outward_slew_and_retains_overshoot(self):
        motion = Motion(*fixture())
        motion.previous = [1.] * 8
        motion.consume(row(command=0., prepared=1.1, sampled=1.05))
        out = motion.finish(dict(trajectory_samples=5, joint_limit_violation_steps=5,
                                 trajectory_distal_contact_samples=5))
        self.assertEqual(out["counts"]["joint_guard_commands"], 8)
        self.assertEqual(out["counts"]["outward_commands_at_or_beyond_bound"], 0)
        self.assertAlmostEqual(out["maxima"]["joint_limit_excess_rad"], .05)

    def test_changed_commands_identity_and_unsupported_scope_refused(self):
        for key, value in (("native_targets", [.3] * 8), ("outer_step", 1), ("safe_no_actuation", True)):
            bad = row()
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                Motion(*fixture()).consume(bad)
        profile, creature, identity = fixture()
        profile.update(mode="pose_sequence", phases=[dict(advance_when="contact")])
        with self.assertRaisesRegex(ValueError, "pose-only"):
            Motion(profile, creature, identity)
        bad = row()
        bad["prepared_qpos"][3:7] = [1., 0., 0., 0.]
        with self.assertRaisesRegex(ValueError, "upright"):
            Motion(*fixture()).consume(bad)

    def test_bound_archive_corruption_and_unbound_paths_refused(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("EXPLORER_TEST_OUTPUT")) as directory:
            root = Path(directory)
            payload = b'{"value": 3}\n'
            (root / "data.json").write_bytes(payload)
            receipt = dict(artifacts=[dict(path="data.json", bytes=len(payload),
                                          sha256=hashlib.sha256(payload).hexdigest())])
            archive = Archive(root, receipt)
            self.assertEqual(archive.document("data.json"), dict(value=3))
            (root / "data.json").write_bytes(payload.replace(b'3', b'4'))
            with self.assertRaisesRegex(ValueError, "hash"):
                archive.document("data.json")
            with self.assertRaisesRegex(ValueError, "unbound"):
                archive.document("../data.json")

    def test_contact_and_violation_summary_disagreement_refused(self):
        motion = Motion(*fixture())
        motion.consume(row())
        expected = dict(trajectory_samples=5, joint_limit_violation_steps=0,
                        trajectory_distal_contact_samples=5)
        for key in expected:
            bad = copy.deepcopy(expected)
            bad[key] += 1
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "retained outcome"):
                motion.finish(bad)


if __name__ == "__main__":
    unittest.main()
