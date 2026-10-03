"""Cold saved-input diagnosis: full population, ordered algebra and refusals."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_v37_reference_diagnosis as d


class V37ReferenceDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads((ROOT/'sdk/development/recovery_reference_velocity_diagnosis_v1.json').read_bytes())
        cls.observed = d.observe()
        cls.data = cls.observed['diagnosis']
        cls.report = json.loads(Path(cls.record['source_report']['path']).read_bytes())
        cls.entries = cls.report['development_walking_entry']['rows']
        descriptor = cls.report['configuration']['base_descriptor']
        upper = .35*descriptor['upper_length_fraction']
        cls.dimensions = (upper,.35-upper,.04*descriptor['foot_radius_scale'],descriptor['hip_span_scale'])

    def test_exact_full_population_and_unchanged_evaluation(self):
        self.assertEqual(json.dumps(self.record,sort_keys=True),json.dumps(self.observed,sort_keys=True))
        self.assertEqual((400,3200),tuple(self.data[k] for k in ('command_count','joint_command_count')))
        self.assertEqual(list(range(1,401)),[r[0] for r in self.data['all_command_timeline']])
        self.assertEqual(25,len(self.data['original_contact_cycles']))
        self.assertEqual(20,sum(not c['original_minimum_relocation_passed'] for c in self.data['original_contact_cycles']))
        self.assertEqual(17,sum(c['scheduled_swing_or_landing_command_overlap_count']==0 for c in self.data['original_contact_cycles']))
        self.assertFalse(self.data['original_walking_evaluation']['behavior_passed'])
        for key in ('original_evaluation_changed','physical_cause_proven','alternate_physical_outcome_predicted','physical_acceptance_authority','release_authority'):
            self.assertFalse(self.record[key])
        for key in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count'):
            self.assertEqual(0,self.record[key])

    def test_full_goal_motor_and_two_order_reconstruction(self):
        self.assertLess(self.data['maximum_goal_error_rad'],1e-12)
        self.assertLess(self.data['maximum_height_interval_error_m'],1e-12)
        self.assertLess(self.data['maximum_motor_velocity_error_rad_s'],1e-12)
        self.assertLess(self.data['maximum_rate_decomposition_error_rad_s'],1e-10)
        # Check both telescoping sums independently from the retained components.
        for m in self.data['initial_eight_commands']:
            p=m['parts']
            self.assertAlmostEqual(p['total'],p['catch_up']+p['activation']+p['wave']+p['pose'],delta=1e-12)
            self.assertAlmostEqual(p['total'],p['catch_up']+p['activation']+p['pose_first']+p['wave_last'],delta=1e-12)
        for c in self.data['original_contact_cycles']:
            parts=c['decomposition']['forward_components_m']
            self.assertEqual(c['distal_body_origin_forward_relocation_m'],parts['actual'])
            self.assertAlmostEqual(parts['actual'],sum(v for k,v in parts.items() if k!='actual'),delta=1e-15)

    def test_activation_stance_losses_and_order_dependence_are_not_hidden(self):
        groups={r['group']:r for r in self.data['rate_groups']}
        self.assertEqual((3200,465,1470),tuple(groups['all'][k] for k in ('count','velocity_saturated_count','feedforward_reverses_feedback_count')))
        self.assertEqual((8,8),tuple(groups['activation'][k] for k in ('count','velocity_saturated_count')))
        self.assertEqual((2474,260),tuple(groups['scheduled_stance_after_activation'][k] for k in ('count','velocity_saturated_count')))
        for label in ('after_activation','scheduled_stance_after_activation'):
            p=groups[label]['reference_rate_components']
            self.assertEqual(0.,p['activation']['rms'])
            self.assertGreater(p['pose']['rms'],p['wave']['rms'])
            self.assertGreater(p['pose_first']['rms'],p['wave_last']['rms'])
            self.assertNotEqual(p['pose']['rms'],p['pose_first']['rms'])
        losses=self.data['all_contact_losses']
        self.assertEqual((42,34),(len(losses),sum(r['scheduled_stance'] for r in losses)))
        self.assertEqual((4,'rear_right',True),tuple(losses[0][k] for k in ('command_local','limb','scheduled_stance')))
        self.assertEqual((51,369),tuple(self.data[k] for k in ('first_empty_height_interval_command','first_original_tilt_failure_command')))

    def test_proposed_rate_removes_static_wave_catchup_and_pose_motion(self):
        _,wave=d.inputs(self.entries[30])
        previous=[0.]*8; caps=[3.5]*8; dt=1/120
        # Every measured pose, not a convenient subset; no native call.
        for entry in self.entries:
            pose,_=d.inputs(entry)
            self.assertEqual([0.]*8,d.proposed_wave_rates(pose,wave,wave,self.dimensions,previous,caps,dt))
        pose,_=d.inputs(self.entries[30])
        self.assertNotEqual(previous,d.bounded_targets(d.goals(pose,wave,self.dimensions)[0],previous,caps,dt))
        for prior,current,time in ((None,wave,dt),(dict(wave,active=False),wave,dt),(wave,dict(wave,active=False),dt),(wave,wave,0.)):
            self.assertEqual([0.]*8,d.proposed_wave_rates(pose,prior,current,self.dimensions,previous,caps,time))
        new=copy.deepcopy(wave)
        new['limbs'][0]=(new['limbs'][0][0]+.01,new['limbs'][0][1],new['limbs'][0][2])
        actual=d.proposed_wave_rates(pose,wave,new,self.dimensions,previous,caps,dt)
        ga=d.goals(pose,wave,self.dimensions)[0];gb=d.goals(pose,new,self.dimensions)[0]
        expected=[max(-c,min(c,(max(-c*dt,min(c*dt,b))-max(-c*dt,min(c*dt,a)))/dt)) for a,b,c in zip(ga,gb,caps)]
        self.assertEqual(expected,actual)
        # Both far-away goals can hit the SAME slew endpoint. That correctly
        # gives zero transport; do not mistake a clamped fixture for no motion.
        self.assertEqual([0.]*8,actual)
        close=d.proposed_wave_rates(pose,wave,new,self.dimensions,ga,caps,dt)
        self.assertTrue(any(v!=0. for v in close))
        self.assertEqual([max(-c,min(c,(max(-c*dt,min(c*dt,b-a)))/dt)) for a,b,c in zip(ga,gb,caps)],close)

    def test_prospective_commands_are_bounded_not_a_new_trajectory(self):
        p=self.data['prospective_wave_rate_sketch']
        self.assertEqual((3200,1491,79,8,8,0),tuple(p[k] for k in ('joint_commands',
            'changed_command_count_above_arithmetic_allowance','velocity_saturated_count',
            'unchanged_initial_command_count','activation_reference_rate_zero_count','activation_velocity_saturated_count')))
        self.assertTrue(p['all_rates_and_velocities_inside_existing_caps'])
        self.assertFalse(p['native_component_implemented'])
        self.assertFalse(p['alternate_physical_trajectory_evaluated'])

    def test_crossed_source_floor_and_malformed_inputs_refuse(self):
        with self.assertRaisesRegex(ValueError,'SOURCE_CROSSED'):
            d.summarize(dict(self.report,source_commit='wrong'))
        changed=dict(self.report);entries=list(self.entries)
        entry=copy.deepcopy(entries[10]);entry['request']['floor_reference']['height_world_m']=1.
        entries[10]=entry;changed['development_walking_entry']=dict(self.report['development_walking_entry'],rows=entries)
        with self.assertRaises(AssertionError):
            d.summarize(changed)
        with mock.patch.object(d,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'CLOSURE_DRIFT'):
            d.observe()
        pose,wave=d.inputs(self.entries[30])
        for bad in ((math.nan,pose[1]),(pose[0],(0.,0.,0.,0.))):
            with self.assertRaises(ValueError): d.goals(bad,wave,self.dimensions)
        with self.assertRaises(ValueError): d.goals(pose,dict(wave,limbs=[]),self.dimensions)
        for dt in (-1.,math.nan):
            with self.assertRaises(ValueError): d.bounded_targets([0.],[0.],[3.5],dt)
        with self.assertRaises(ValueError): d.bounded_targets([0.],[0.],[0.],.1)


if __name__=='__main__':
    unittest.main()
