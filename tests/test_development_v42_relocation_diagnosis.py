"""Retained population, timing, coordinate identities and crossed-data refusals."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_v42_relocation_diagnosis as diagnosis


class Relocation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.full = diagnosis.observe()
        cls.report = json.loads(Path(cls.full['source_report']['path']).read_bytes())

    def test_complete_population_and_original_negative(self):
        d = self.full['diagnosis']
        self.assertEqual((400,1600,3200,26,20,19), tuple(d[k] for k in
            ('command_count','limb_command_count','joint_command_count','contact_loss_count','stance_onset_loss_count','counted_cycle_count')))
        self.assertEqual([5,3,7,4], [p['counted_cycles'] for p in d['per_limb']])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'], d['original_walking_evaluation']['false_walking_receipts'])
        self.assertFalse(d['original_walking_evaluation']['behavior_passed'])
        for k in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count'):
            self.assertEqual(0, self.full[k])

    def test_worst_loss_and_terminal_have_different_phase_meanings(self):
        events = self.full['diagnosis']['all_contact_losses']
        worst = next(e for e in events if e['limb']=='rear_left' and e['loss_trace_local']==365)
        self.assertEqual((397,32,0,32), (worst['recontact_trace_local'],worst['observed_absent_trace_count'],
            worst['interval_speed_clamped_joint_commands'],worst['interval_latched_absent_inputs']))
        self.assertTrue(worst['all_interval_commands_scheduled_stance'])
        terminal = [e for e in events if e['recontact_trace_local'] is None]
        self.assertEqual([('front_left',395)], [(e['limb'],e['loss_trace_local']) for e in terminal])
        self.assertFalse(terminal[0]['original_evaluator_counted_cycle'])
        self.assertFalse(terminal[0]['measured_motion']['available'])
        self.assertFalse(terminal[0]['onset_scheduled_stance'])

    def test_coordinate_identity_for_every_available_event(self):
        for event in self.full['diagnosis']['all_contact_losses']:
            motion = event['measured_motion']
            if not motion['available']: continue
            self.assertAlmostEqual(event['forward_displacement_to_recontact_or_endpoint_m'],motion['actual_forward_m'],places=14)
            for order in motion['ordered_decompositions']:
                self.assertAlmostEqual(motion['actual_forward_m'],sum(order[k] for k in
                    ('torso_translation_forward_m','torso_rotation_forward_m','body_relative_motion_forward_m')), places=14)

    def test_synthetic_rigid_rotation_translation_and_relative_motion(self):
        pose = lambda x,q: dict(position_m=dict(zip('xyz',x)),orientation_xyzw=dict(zip('xyzw',q)))
        a = pose([0,0,0],[0,0,0,1])
        b = pose([2,0,0],[0,math.sin(math.pi/4),0,math.cos(math.pi/4)])
        result = diagnosis.measured_motion(a,b,[1,0,0],[2,0,-1],[1,0,0])
        for order in result['ordered_decompositions']:
            self.assertAlmostEqual(2,order['torso_translation_forward_m'])
            self.assertAlmostEqual(-1,order['torso_rotation_forward_m'])
            self.assertAlmostEqual(0,order['body_relative_motion_forward_m'])
        self.assertAlmostEqual(math.pi/2,result['signed_heading_change_rad'])
        # Same orientation: all non-translation motion belongs to relative motion.
        c = pose([0,0,0],[0,0,0,1])
        result = diagnosis.measured_motion(a,c,[1,0,0],[3,0,0],[1,0,0])
        self.assertEqual(2,result['ordered_decompositions'][0]['body_relative_motion_forward_m'])

    def test_initial_partial_and_open_flights_never_invent_cycles(self):
        rows = [dict(contact_by_limb=dict(foot=v)) for v in [False,False,True,False,True,False]]
        self.assertEqual([(4,5),(6,None)],diagnosis.loss_intervals(False,rows,'foot'))
        self.assertEqual([(1,3),(4,5),(6,None)],diagnosis.loss_intervals(True,rows,'foot'))

    def test_crossed_motor_memory_contact_and_original_numbers_refuse(self):
        rows = self.report['development_walking_entry']['rows']
        old = rows[383]
        for kind,code in [('motor','COMMAND_RECONSTRUCTION'),('clamp','CLIPPING'),('memory','MEMORY_LINK'),('phase','CONTACT_PHASE_BINDING')]:
            rows[383] = copy.deepcopy(old)
            row = rows[383]
            if kind=='motor': row['native_output']['actuation']['ordered_commands'][6]['target_velocity_rad_s'] += .1
            elif kind=='clamp': row['native_output']['actuation']['ordered_commands'][6]['velocity_saturated'] ^= True
            elif kind=='memory': row['request']['memory']['support_reference']['ordered_target_positions_rad'][0] += .01
            else: row['native_output']['actuation']['receipt']['recovery_support_plane']['stance_latch']['ordered_limbs'][0]['current_scheduled_phase_step'] += 1
            try:
                with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, 'V42_RELOCATION_'+code):
                    diagnosis.summarize(self.report)
            finally: rows[383] = old
        session = next(s for s in self.report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
        trace = next(t for t in self.report['retained_arm']['trace_rows'] if t.get('walking_session_id')==session['session_id'] and t['walking_session_local_step']==384)
        trace['contact_by_limb']['rear_left'] ^= True
        try:
            with self.assertRaisesRegex(ValueError,'V42_RELOCATION_PRE_POST_ALIGNMENT'): diagnosis.summarize(self.report)
        finally: trace['contact_by_limb']['rear_left'] ^= True
        minima = session['evaluation']['minimum_cycle_forward_relocation_by_limb_m']
        old_min = minima['rear_left']; minima['rear_left'] = 0.
        try:
            with self.assertRaisesRegex(ValueError,'V42_RELOCATION_ORIGINAL_CYCLE_RECONSTRUCTION'): diagnosis.summarize(self.report)
        finally: minima['rear_left'] = old_min


if __name__ == '__main__': unittest.main()
