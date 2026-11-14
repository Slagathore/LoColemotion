"""Synthetic controls for retained-command diagnosis; no physics is constructed."""
import copy
import json
import math
from pathlib import Path
import unittest
from unittest import mock

import creature_body_moment_diagnosis as diagnosis


class MomentDiagnosisTests(unittest.TestCase):
    def motion(self, steps=3):
        return diagnosis.MomentCommands(dict(id="fixture", mode="body_moment"),
            dict(spec=dict(velocity_gains=[10.]*8, force_ranges=[[-20.,20.]]*8)),
            dict(cell_id="fixture_cell", candidate_id="fixture"), steps)

    def row(self, step, degrees=10., *, release=False):
        targets = [0.]*8 if release else [.1,.1]+[0.]*6
        projection = None if release else dict(target=[.2,.2]+[0.]*6,
            predicted_torque=[2.,2.]+[0.]*6, requested_torque=[3.,3.]+[0.]*6)
        decision = dict(phase="contact_release" if release else "contact_force",
            active_limbs=[] if release else [0], force_projection=projection,
            requested_wrenches=[] if release else [dict(force=[0.,1.,0.])],
            normalized_targets=[0.]*8, post_guard_predicted_torque_nm=[10.*x for x in targets],
            state_after=dict(inner=dict(target=None if release else dict(bank_index=7))),
            handoff=dict(reason="bounded_release" if release else "continue", upright_steering_available=False))
        return dict(outer_step=step, binding=dict(cell_id="fixture_cell", candidate_id="fixture"),
            request=dict(state=dict(semantic_step=step,
                ordered_contact_observations=[dict(presence=True)]+[dict(presence=False)]*3,
                ordered_joint_observations=[dict(velocity_rad_s=0.)]*8)),
            native_targets=targets, resolution=dict(body_moment=decision, observed_up_dot=-math.cos(math.radians(degrees)),
                ordered_commands=[dict(canonical_velocity_rad_s=x, joint_guard_applied=(i==0)) for i,x in enumerate(targets)]))

    def native_rows(self, motion):
        for step, frame in enumerate(motion.frames):
            for substep in range(5):
                motion.native(dict(step=5*step+substep+1, ctrl=[diagnosis.f32(v) for v in frame["targets"]],
                    actuator_force_nm=[.8,.8]+[0.]*6))

    def finish(self, motion):
        self.native_rows(motion)
        result=motion.finish(dict(trajectory_maximum_up_dot=-math.cos(math.radians(12.))))
        # Exercise the actual output boundary, including NumPy-derived counts.
        return json.loads(json.dumps(result,allow_nan=False))

    def test_torque_requests_predictions_and_observations_stay_distinct(self):
        motion=self.motion(1);motion.consume(self.row(0));r=self.finish(motion)
        self.assertEqual(r["mean_requested_abs_torque_nm"],3.)
        self.assertEqual(r["mean_pre_guard_torque_error_nm"],1.)
        self.assertEqual(r["mean_post_guard_torque_error_nm"],2.)
        self.assertAlmostEqual(r["mean_observed_active_joint_force_abs_nm"],.8)
        self.assertAlmostEqual(r["mean_observed_force_to_prepared_request_error_nm"],2.2)
        self.assertEqual(r["counts"]["active_joint_error_increased_after_guard"],2)

    def test_release_loss_uses_entry_to_reacquisition_and_keeps_sign(self):
        motion=self.motion()
        for row in (self.row(0,10.),self.row(1,12.,release=True),self.row(2,2.)):motion.consume(row)
        r=self.finish(motion);event=r["releases"][0]
        self.assertTrue(event["complete"])
        self.assertAlmostEqual(event["observed_rotation_change_degrees"],-10.)
        self.assertEqual(event["observed_duration_s"],diagnosis.DT)

    def test_terminal_release_does_not_invent_an_exit_observation(self):
        motion=self.motion()
        for row in (self.row(0,10.),self.row(1,12.,release=True),self.row(2,5.,release=True)):motion.consume(row)
        event=self.finish(motion)["releases"][0]
        self.assertFalse(event["complete"])
        self.assertEqual(event["exit"]["outer_step"],2)
        self.assertEqual(event["observed_duration_s"],diagnosis.DT)

    def test_changed_torque_prediction_or_native_command_is_refused(self):
        for field in ("post_guard_predicted_torque_nm","predicted_torque"):
            motion=self.motion(1);row=self.row(0)
            target=row["resolution"]["body_moment"]
            if field=="predicted_torque":target=target["force_projection"]
            target[field][0]+=.01
            with self.assertRaisesRegex(ValueError,"guard torque"):motion.consume(row)
        motion=self.motion(1);motion.consume(self.row(0))
        with self.assertRaisesRegex(ValueError,"native command binding"):
            motion.native(dict(step=1,ctrl=[0.]*8,actuator_force_nm=[0.]*8))

    def test_missing_rows_wrong_identity_and_sample_order_are_refused(self):
        motion=self.motion();row=self.row(0);row["binding"]["cell_id"]="different"
        with self.assertRaisesRegex(ValueError,"identity/order"):motion.consume(row)
        with self.assertRaisesRegex(ValueError,"identity/order"):motion.consume(self.row(1))
        motion.consume(self.row(0))
        for step in (0,2):
            with self.assertRaisesRegex(ValueError,"sample order"):
                motion.native(dict(step=step,ctrl=[diagnosis.f32(v) for v in motion.frames[0]["targets"]]))
        with self.assertRaisesRegex(ValueError,"incomplete capture"):motion.finish({})

    def test_release_force_nonfinite_orientation_and_duplicate_contacts_are_refused(self):
        row=self.row(0,release=True);row["resolution"]["body_moment"]["requested_wrenches"]=[{}]
        with self.assertRaisesRegex(ValueError,"release must"):self.motion(1).consume(row)
        row=self.row(0);row["resolution"]["observed_up_dot"]=math.nan
        with self.assertRaisesRegex(ValueError,"finite orientation"):self.motion(1).consume(row)
        row=self.row(0);row["resolution"]["body_moment"]["active_limbs"]=[0,0]
        with self.assertRaisesRegex(ValueError,"active contacts"):self.motion(1).consume(row)

    def test_no_force_rows_report_no_mean_torque(self):
        motion=self.motion(1);motion.consume(self.row(0,release=True));r=self.finish(motion)
        self.assertIsNone(r["mean_requested_abs_torque_nm"])
        self.assertIsNone(r["mean_post_guard_torque_error_nm"])
        self.assertIsNone(r["mean_observed_active_joint_force_abs_nm"])

    def test_compact_or_unreplayed_archives_are_refused(self):
        receipt=dict(contract=dict(capture_mode="full"),audit=dict(capture=dict(
            controller_replay_verified=True,detailed_native_capture_verified=True)))
        for kind in ("compact","unreplayed","missing_native"):
            r=copy.deepcopy(receipt)
            if kind=="compact":r["contract"]["capture_mode"]="compact_v1"
            else:r["audit"]["capture"]["controller_replay_verified" if kind=="unreplayed" else "detailed_native_capture_verified"]=False
            with mock.patch.object(diagnosis,"bound_archive",return_value=(None,r)):
                with self.assertRaisesRegex(ValueError,"replayed full capture"):
                    diagnosis.diagnose_commands(Path("unused"),"unused")


if __name__ == "__main__":
    unittest.main()
