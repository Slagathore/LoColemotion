"""Full-population V38 diagnosis and bounded, non-native V39 rate sketch."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_v38_landing_diagnosis as d


class V38LandingDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads((ROOT/'sdk/development/recovery_wave_velocity_landing_diagnosis_v1.json').read_bytes())
        cls.complete_path = Path(cls.record['complete_diagnosis']['path'])
        cls.full = json.loads(cls.complete_path.read_bytes())
        cls.observed = d.observe()
        cls.data = cls.full['diagnosis']
        cls.timeline = cls.data['all_limb_command_timeline']
        cls.report = json.loads(Path(cls.record['source_report']['path']).read_bytes())

    def test_exact_complete_population_and_original_outcome(self):
        self.assertEqual(self.full, self.observed)
        self.assertEqual(self.record, d.compact(self.observed,self.complete_path))
        binding = self.record['complete_diagnosis']
        self.assertEqual(binding['byte_length'],self.complete_path.stat().st_size)
        self.assertEqual(binding['raw_sha256'],d.digest(self.complete_path.read_bytes()))
        self.assertEqual((400,1600,3200),tuple(self.data[k] for k in ('command_count','limb_command_count','joint_command_count')))
        self.assertEqual({(n,limb) for n in range(1,401) for limb in d.tracking.geometry.LIMBS},
                         {(r['command_local'],r['limb']) for r in self.timeline})
        self.assertTrue(all(r['measured_trace_local']==r['command_local']-1 for r in self.timeline))
        self.assertEqual(399,max(r['measured_trace_local'] for r in self.timeline))
        self.assertFalse(self.data['original_walking_evaluation']['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation','every_limb_two_contact_cycles','terminal_four_contact_recovery'],
                         self.data['original_walking_evaluation']['false_walking_receipts'])

    def test_rear_right_wait_and_actual_clock_propagation(self):
        per = {r['limb']:r for r in self.data['per_limb']}
        rr = per['rear_right']
        self.assertEqual((90,88,0,7),tuple(rr[k] for k in ('recontact_hold_commands',
            'recontact_hold_no_raw_contact_commands','recontact_hold_saturated_commands','recontact_hold_joint_slew_limited_commands')))
        holds = [r for r in self.timeline if r['limb']=='rear_right' and r['gate_hold_delta']]
        self.assertEqual(list(range(166,256)),[r['command_local'] for r in holds])
        self.assertTrue(all(r['raw_contact_count']==0 for r in holds[:88]))
        self.assertTrue(all(r['pre_contact'] for r in holds[88:]))
        self.assertTrue(all(r['phase']==72 for r in holds))
        self.assertLess(max(abs(r['ideal_goal_bottom_m']) for r in holds),1e-8)
        self.assertTrue(all(r['current_reference_rad']==r['goal_joint_rad'] for r in holds[7:]))
        self.assertEqual({'front_left':76,'front_right':80,'rear_left':80,'rear_right':0},
                         {k:v['phase_sync_hold_during_rear_right_landing'] for k,v in per.items()})
        # Native contacts, not the sign of nominal clearance, decide contact.
        self.assertTrue(all(r['nominal_actual_bottom_m']>0 for r in holds[88:]))

    def test_stance_loss_unreachable_targets_and_all_cycles(self):
        losses = self.data['all_contact_losses']
        self.assertEqual((21,17),(len(losses),sum(r['scheduled_stance'] for r in losses)))
        rl = next(r for r in self.data['per_limb'] if r['limb']=='rear_left')
        self.assertEqual([286],rl['contact_loss_commands'])
        self.assertEqual((65,45),tuple(rl[k] for k in ('stance_missing_contact_commands','stance_unreachable_goal_commands')))
        self.assertEqual(.024134021167772468,rl['maximum_stance_goal_bottom_m'])
        original = next(r for r in self.data['original_per_limb_cycles'] if r['limb']=='rear_left')
        self.assertEqual((352,49,48),(original['first_scheduled_swing_command'],original['scheduled_swing_command_count'],original['terminal_scheduled_phase_step']))
        self.assertFalse(original['terminal_contact']);self.assertEqual([],original['contact_cycles'])
        cycles = self.data['original_contact_cycles']
        self.assertEqual((13,9,9),(len(cycles),sum(not c['original_minimum_relocation_passed'] for c in cycles),
            sum(c['scheduled_swing_or_landing_command_overlap_count']==0 for c in cycles)))
        for c in cycles:
            self.assertTrue(c['decomposition']['available'])
            parts = c['decomposition']['forward_components_m']
            self.assertEqual(c['distal_body_origin_forward_relocation_m'],parts['actual'])
            self.assertAlmostEqual(parts['actual'],sum(v for k,v in parts.items() if k!='actual'),delta=1e-15)

    def test_proposal_changes_only_explicit_airborne_swing_or_landing(self):
        p = self.data['prospective_airborne_reference_sketch']
        self.assertEqual((550,474,120),tuple(p[k] for k in ('selected_joint_commands','changed_joint_commands','velocity_saturated_commands')))
        self.assertTrue(p['all_unselected_velocities_exact']);self.assertTrue(p['all_rates_and_velocities_inside_existing_caps'])
        self.assertFalse(p['native_component_implemented']);self.assertFalse(p['alternate_physical_trajectory_evaluated'])
        self.assertEqual(19,self.data['original_saturated_commands'])
        self.assertLess(self.data['maximum_motor_velocity_error_rad_s'],1e-12)
        for row in self.timeline:
            for m in row['motors']:
                if m['selected']:
                    self.assertLessEqual(row['phase'],72);self.assertFalse(row['pre_contact'])
                else:
                    self.assertEqual(m['current_velocity'],m['proposed_velocity'])
        for active,phase,presence,bearing,dt in [(False,72,False,False,.01),(True,73,False,False,.01),
                (True,72,True,False,.01),(True,72,False,True,.01),(True,72,False,False,0.)]:
            self.assertEqual((False,.2),d.proposed_rate(active,phase,presence,bearing,.3,.1,dt,3.5,.2))
        self.assertEqual((True,3.5),d.proposed_rate(True,72,False,False,.3,.1,.01,3.5,0.))
        self.assertEqual((True,-3.5),d.proposed_rate(True,0,False,False,.1,.3,.01,3.5,0.))

    def test_crossed_source_floor_timing_and_bad_proposal_refuse(self):
        with self.assertRaisesRegex(ValueError,'SOURCE_CROSSED'):
            d.summarize(dict(self.report,source_commit='wrong'))
        for field,value in [('measured_global_step',0),('floor_reference',dict(height_world_m=1.))]:
            changed=dict(self.report);entries=list(self.report['development_walking_entry']['rows'])
            row=copy.deepcopy(entries[10])
            if field=='floor_reference': row['request'][field]=value
            else: row[field]=value
            entries[10]=row;changed['development_walking_entry']=dict(self.report['development_walking_entry'],rows=entries)
            with self.assertRaises(AssertionError): d.summarize(changed)
        with mock.patch.object(d,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'CLOSURE_DRIFT'):
            d.observe()
        valid=[True,72,False,False,.3,.1,.01,3.5,0.]
        for index,value in [(0,None),(1,72.5),(1,360),(2,None),(3,0),(4,math.nan),(6,-.1),(7,0.),(8,4.)]:
            bad=list(valid);bad[index]=value
            with self.subTest(index=index,value=value),self.assertRaises(ValueError):d.proposed_rate(*bad)

    def test_zero_native_scope_and_immutable_parent(self):
        self.assertEqual(d.CLOSURE_SHA,d.digest((ROOT/'sdk/development/recovery_attempts'/ (d.ATTEMPT+'.json')).read_bytes()))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            d.digest((ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))
        for key in ('original_evaluation_changed','physical_cause_proven','alternate_physical_outcome_predicted','physical_acceptance_authority','release_authority'):
            self.assertFalse(self.full[key])
        for key in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count'):
            self.assertEqual(0,self.full[key])


if __name__ == '__main__':
    unittest.main()
