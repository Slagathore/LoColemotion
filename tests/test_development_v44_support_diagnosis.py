"""Cold V44 population, actual command algebra, and crossed-data refusals."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_v44_support_diagnosis as diagnosis


class SupportDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report=diagnosis.report()
        cls.result=diagnosis.summarize(cls.report)

    def test_complete_population_original_cycles_and_no_regrading(self):
        d=self.result
        self.assertEqual((400,1600,3200,258,13,53,44,26),tuple(d[k] for k in
            ('command_count','limb_sample_count','joint_command_count','held_command_count','released_hold_count',
             'maximum_held_window_commands','contact_loss_count','stance_onset_loss_count')))
        self.assertEqual([14,3,2,11],[r['counted_cycles'] for r in d['per_limb']])
        self.assertLess(d['maximum_motor_reconstruction_error_rad_s'],1e-10)
        self.assertLess(d['maximum_frame_axis_error'],16*2**-23)
        self.assertFalse(d['original_walking_evaluation']['behavior_passed'])
        print('V44_COMPLETE_RETAINED_SUPPORT',json.dumps({k:v for k,v in d.items() if k not in
            ('all_limb_samples','original_walking_evaluation','all_contact_losses','hold_windows')}))

    def test_absence_geometry_and_two_distinct_terminal_phases(self):
        d=self.result
        self.assertEqual([42,35,40,131],[r['absent_scheduled_stance_precommand_count'] for r in d['per_limb']])
        self.assertEqual([0,0,0,0],[r['absent_stance_with_raw_contacts'] for r in d['per_limb']])
        opened=[r for r in d['all_contact_losses'] if r['recontact_trace_local'] is None]
        self.assertEqual([('front_left',397,True),('rear_right',388,False)],
                         [(r['limb'],r['loss_trace_local'],r['onset_scheduled_stance']) for r in opened])
        self.assertFalse(d['hold_windows'][-1]['released'])
        self.assertEqual(3,d['hold_windows'][-1]['held_command_count'])

    def test_crossed_clock_memory_contact_and_motor_refuse(self):
        rows=self.report['development_walking_entry']['rows']; old=rows[25]
        for kind,code in [('clock','CLOCK'),('memory','MEMORY'),('contact','CONTACT_LINK'),('motor','MOTOR_RECONSTRUCTION')]:
            rows[25]=copy.deepcopy(old); r=rows[25]
            if kind=='clock':r['commanded_global_step']+=1
            elif kind=='memory':r['request']['memory']['support_reference']['ordered_target_positions_rad'][0]+=.001
            elif kind=='contact':r['request']['state']['ordered_contact_observations'][0]['bears_support']^=True
            else:r['native_output']['actuation']['ordered_commands'][0]['target_velocity_rad_s']+=.1
            try:
                with self.subTest(kind=kind),self.assertRaisesRegex(ValueError,'V44_SUPPORT_'+code):
                    diagnosis.summarize(self.report)
            finally:rows[25]=old
        session=next(s for s in self.report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
        minima=session['evaluation']['minimum_cycle_forward_relocation_by_limb_m']; original=minima['rear_right']
        minima['rear_right']=0.
        try:
            with self.assertRaisesRegex(ValueError,'V44_SUPPORT_ORIGINAL_CYCLES'):diagnosis.summarize(self.report)
        finally:minima['rear_right']=original


if __name__=='__main__':unittest.main()
