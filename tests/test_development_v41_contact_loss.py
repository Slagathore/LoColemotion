"""Full saved population and crossed-input controls; no native execution."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_v41_contact_loss_diagnosis as diagnosis


class ContactLoss(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.full=diagnosis.observe()
        cls.report=json.loads(Path(cls.full['source_report']['path']).read_bytes())

    def test_entire_population_preserves_original_negative(self):
        d=self.full['diagnosis']
        self.assertEqual((400,1600,3200),(d['command_count'],d['limb_command_count'],d['joint_command_count']))
        self.assertEqual((55,50,108),(d['contact_loss_count'],d['stance_loss_count'],d['selector_limb_transition_count']))
        self.assertEqual(55,len(d['all_contact_losses']))
        self.assertEqual(1600,len(d['all_limb_command_timeline']))
        self.assertFalse(d['original_walking_evaluation']['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],d['original_walking_evaluation']['false_walking_receipts'])
        self.assertTrue(all(self.full[k]==0 for k in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count')))

    def test_onset_is_separate_from_reaction_and_terminal_pose_is_absent(self):
        d=self.full['diagnosis']; ls=d['all_contact_losses']
        onset=next(r for r in ls if r['limb']=='front_left' and r['loss_trace_local']==85)
        self.assertEqual((0,2),(onset['onset_clamped_joints'],onset['first_following_command_clamped_joints']))
        self.assertTrue(onset['first_following_command_goal_transition']['mask_changed'])
        self.assertEqual([('front_left',356),('rear_right',398)],[(r['limb'],r['loss_trace_local']) for r in ls if r['recontact_trace_local'] is None])
        for r in d['all_limb_command_timeline']:
            if r['command_local']==400:
                self.assertIsNone(r['postcommand_nominal_capsule_bottom_m'])
                self.assertFalse(r['measured_response_decomposition']['available'])

    def test_both_selector_substitution_orders_reconstruct_total(self):
        for row in self.full['diagnosis']['all_limb_command_timeline']:
            t=row['goal_transition']
            if t is None: continue
            for selector,remainder in [('selector_change_at_current_pose_and_wave_rad','pose_and_wave_change_with_previous_selector_rad'),('selector_change_at_previous_pose_and_wave_rad','pose_and_wave_change_with_current_selector_rad')]:
                for a,b,c in zip(t[selector],t[remainder],t['total_goal_change_rad']):
                    self.assertAlmostEqual(a+b,c,places=14)
            if not t['mask_changed']:
                self.assertEqual([0.,0.],t['selector_change_at_current_pose_and_wave_rad'])

    def test_crossed_command_and_trace_refuse_without_changing_evidence(self):
        rows=self.report['development_walking_entry']['rows']; old=rows[383]
        for kind,code in [('motor','V41_LOSS_COMMAND_RECONSTRUCTION_motor'),('clamp','V41_LOSS_SATURATION')]:
            rows[383]=copy.deepcopy(old); command=rows[383]['native_output']['actuation']['ordered_commands'][6]
            if kind=='motor': command['target_velocity_rad_s']+=.1
            else: command['velocity_saturated']=not command['velocity_saturated']
            try:
                with self.subTest(kind=kind),self.assertRaisesRegex(ValueError,code): diagnosis.summarize(self.report)
            finally: rows[383]=old
        session=next(s for s in self.report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
        trace=next(r for r in self.report['retained_arm']['trace_rows'] if r.get('walking_session_id')==session['session_id'] and r['walking_session_local_step']==384)
        old_contact=trace['contact_by_limb']['rear_right']
        trace['contact_by_limb']['rear_right']=not old_contact
        try:
            with self.assertRaisesRegex(ValueError,'V41_LOSS_POST_PRE_ALIGNMENT'): diagnosis.summarize(self.report)
        finally: trace['contact_by_limb']['rear_right']=old_contact


if __name__=='__main__': unittest.main()
