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


class ExchangeDiagnosisTests(unittest.TestCase):
    def motion(self, steps=3):
        creature = dict(spec=dict(velocity_gains=[10.]*8, force_ranges=[[-20.,20.]]*8),
            compiled=dict(morphology=dict(morphology_spec=dict(bodies=[dict(body_id=f"b{i}") for i in range(9)]))))
        return diagnosis.ExchangeCommands(dict(id="fixture", support_exchange=dict(contact_dwell_steps=2)),
            creature, dict(cell_id="fixture_cell", candidate_id="fixture"), steps)

    def row(self, step, phase, degrees=10., reason=None):
        r = MomentDiagnosisTests().row(step, degrees)
        d, state = r["resolution"]["body_moment"], r["request"]["state"]
        active = [1] if phase == "transfer" else [0]
        js = [2*active[0], 2*active[0]+1]
        target = [.1 if j in js else 0. for j in range(8)]
        request = [30. if j in js else 0. for j in range(8)]
        projected = [.2 if j in js else 0. for j in range(8)]
        d.update(active_limbs=active, phase="contact_force",
            geometric_contact_points_m=[[0.,-.002,0.]]*4,
            requested_wrenches=[dict(body_id=f"b{2+2*active[0]}",force=[0.,10.,0.])],
            force_projection=dict(target=projected, predicted_torque=[10.*x for x in projected],
                requested_torque=request, gravity_torque=[0.]*8, contact_torque=[-v for v in request],
                lower_torque=[-2.]*8, upper_torque=[2.]*8),
            post_guard_predicted_torque_nm=[10.*x for x in target],
            state_before=dict(phase="reference"),
            state_after=dict(phase=phase,base=dict(target=dict(bank_index=7)),
                             support_limbs=[0],replacement_limb=1,contact_count=2),
            support_exchange=dict(phase=phase,reason=reason or {"seek":"measured_plateau","transfer":"measured_replacement_contact","reference":"lost_required_contact"}[phase]))
        d.pop("handoff")
        state.update(base_pose_world=dict(position_m=dict(x=0.,y=.1,z=0.)),
            ordered_joint_observations=[dict(position_rad=.2,velocity_rad_s=0.) for _ in range(8)],
            ordered_contact_observations=[dict(presence=i==0 or (i==1 and phase!="reference")) for i in range(4)])
        r.update(native_targets=target)
        r["resolution"]["ordered_commands"]=[dict(canonical_velocity_rad_s=v,target_position_rad=0.,
            joint_guard_applied=False,slew_limited=False) for v in target]
        return r

    def consume(self, motion, row):
        if motion.previous_exchange_state is not None:
            row["resolution"]["body_moment"]["state_before"]=copy.deepcopy(motion.previous_exchange_state)
        motion.consume(row)

    def finish(self, motion):
        for index, frame in enumerate(motion.frames):
            for substep in range(5):
                motion.native(dict(step=5*index+substep+1,ctrl=[diagnosis.f32(v) for v in frame["targets"]],
                    actuator_force_nm=[.8]*8))
        return json.loads(json.dumps(motion.finish(dict(trajectory_maximum_up_dot=-.9)),allow_nan=False))

    def test_affine_scale_respects_both_signs_and_gravity(self):
        self.assertEqual(diagnosis.bounded_load_scale([0.,0.],[-30.,30.],[[-20.,20.]]*2),[0.,2/3])
        self.assertEqual(diagnosis.bounded_load_scale([-3.],[4.],[[-1.,1.]]),[.5,1.])
        self.assertEqual(diagnosis.bounded_load_scale([0.],[0.],[[-1.,1.]]),[0.,1.])

    def test_affine_empty_intersection_and_zero_slope(self):
        self.assertIsNone(diagnosis.bounded_load_scale([2.],[0.],[[-1.,1.]]))
        self.assertIsNone(diagnosis.bounded_load_scale([-3.,0.],[4.,-4.],[[-1.,1.]]*2))
        self.assertEqual(diagnosis.bounded_load_scale([0.],[-2.],[[1.,1.]]),[.5,.5])

    def test_affine_invalid_numeric_shape_and_ranges_are_refused(self):
        for args in (([math.nan],[1.],[[-1.,1.]]),([0.],[1.],[[1.,-1.]]),
                     ([0.],[True],[[-1.,1.]]),([],[],[]),([0.,0.],[1.],[[-1.,1.]])):
            with self.assertRaises(ValueError):diagnosis.bounded_load_scale(*args)

    def test_transfer_reconstructs_request_bounds_and_observed_actuator_force(self):
        m=self.motion()
        for r in (self.row(0,"seek",12.),self.row(1,"transfer",12.),self.row(2,"reference",2.)):self.consume(m,r)
        result=self.finish(m);event=result["transfers"][0]
        self.assertTrue(event["complete"]);self.assertEqual(event["command_intervals"],1)
        self.assertAlmostEqual(event["observed_duration_s"],diagnosis.DT)
        self.assertAlmostEqual(event["observed_rotation_change_degrees"],-10.)
        new=event["entry"]["limbs"]["replacement"]
        self.assertEqual(new["static_request_bounds"]["force_cap_scale_interval"],[0.,2/3])
        self.assertEqual(new["static_request_bounds"]["pre_guard_command_scale_interval"],[0.,1/15])
        self.assertEqual(new["requested_torque_outside_force_cap"],[True,True])
        self.assertAlmostEqual(event["native"]["replacement"]["mean_prepared_request_error_nm"],29.2)
        self.assertAlmostEqual(event["native"]["replacement"]["mean_absolute_force_nm"],.8)
        self.assertEqual(event["native"]["replacement"]["joint_samples"],10)
        self.assertEqual(result["exchange_phases"]["transfer"]["requests_outside_force_cap"],2)

    def test_terminal_transfer_has_no_invented_exit_or_extra_interval(self):
        m=self.motion()
        for r in (self.row(0,"seek"),self.row(1,"transfer"),self.row(2,"transfer",9.,reason="continue")):self.consume(m,r)
        event=self.finish(m)["transfers"][0]
        self.assertFalse(event["complete"]);self.assertIsNone(event["exit"])
        self.assertEqual(event["command_intervals"],2)
        self.assertEqual(event["observed_duration_s"],diagnosis.DT)

    def test_changed_state_identity_and_short_dwell_are_refused(self):
        m=self.motion();self.consume(m,self.row(0,"seek"))
        row=self.row(1,"transfer")
        with self.assertRaisesRegex(ValueError,"state continuity"):m.consume(row)
        for corruption in ("support","dwell","active"):
            m=self.motion();self.consume(m,self.row(0,"seek"));row=self.row(1,"transfer")
            d=row["resolution"]["body_moment"]
            if corruption=="support":d["state_after"]["replacement_limb"]=0
            elif corruption=="dwell":d["state_after"]["contact_count"]=1
            else:d["active_limbs"]=[0]
            with self.assertRaises(ValueError):self.consume(m,row)

    def test_corrupt_wrench_body_and_static_balance_are_refused(self):
        for field in ("body","balance","normal","point"):
            m=self.motion(1);row=self.row(0,"seek");d=row["resolution"]["body_moment"]
            if field=="body":d["requested_wrenches"][0]["body_id"]="different"
            elif field=="balance":d["force_projection"]["gravity_torque"][0]=1.
            elif field=="normal":d["requested_wrenches"][0]["force"][1]=-1.
            else:d["geometric_contact_points_m"][0][1]=math.nan
            with self.assertRaises(ValueError):self.consume(m,row)

    def test_zero_transfers_are_retained_without_inventing_a_mean(self):
        m=self.motion(1);self.consume(m,self.row(0,"seek"))
        result=self.finish(m)
        self.assertEqual(result["transfers"],[])
        self.assertNotIn("transfer",result["exchange_phases"])

    def test_exchange_requires_full_replayed_capture(self):
        receipt=dict(contract=dict(capture_mode="compact_v1"),
            audit=dict(capture=dict(controller_replay_verified=False,detailed_native_capture_verified=False)))
        with mock.patch.object(diagnosis,"bound_archive",return_value=(None,receipt)):
            with self.assertRaisesRegex(ValueError,"replayed full capture"):
                diagnosis.diagnose_commands(Path("unused"),"unused",exchange=True)



if __name__ == "__main__":
    unittest.main()
