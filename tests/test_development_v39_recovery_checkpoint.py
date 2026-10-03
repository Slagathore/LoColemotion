"""Cold V39 closure and complete saved-population audit; no native calls."""
import copy
from pathlib import Path
import unittest
from unittest import mock

import test_development_v27_recovery_checkpoint as prior
import development_recovery_airborne_reference_observation as observation

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '681e45b2b4784caba4018cac4e6c2b61'
SOURCE = '529682476a3865aa928368bd73f6a96e28e2cacb'


class AirborneReferenceCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT+'.json')
        cls.record = closure.smoke.read(cls.path)
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.entries = cls.report['development_walking_entry']['rows']
        cls.summary = closure.smoke.read(ROOT/'sdk/development/recovery_airborne_reference_observation_v1.json')

    def test_complete_publication_population_and_original_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual((113,1,1258), tuple(self.record[k] for k in ('safety_test_count','world_count','solver_step_count')))
        self.assertEqual((63,1084807628), tuple(self.record['retained_population'][k] for k in ('file_count','byte_length')))
        self.assertEqual('sha256:4ebbed468d172de6e887286a4e549fbb9951af95575e01f29c82f32988d233f5', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:65c27b92134702e1af871a899e6cec5be796cad5ebc30b42ff81f87e6a8db612', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258,467,119,1), tuple(replay[k] for k in ('transition_count','canonical_observation_count','entry_observation_count','canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(observation.POLICY, replay['walking_policy_validation']['policy_id'])
        for key in ('world_build_count','solver_step_count','native_physics_read_count'):
            self.assertEqual(0, replay[key])

    def test_unchanged_standing_dwell_commands_and_same_body(self):
        prior.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual(observation.POLICY, self.resume['start_receipt']['selected_policy_id'])
        self.assertEqual({90}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual((859,1258,400), (self.entries[0]['commanded_global_step'],self.entries[-1]['commanded_global_step'],len(self.entries)))

    def test_all_commands_reconstructed_and_full_extension_grouping(self):
        result = observation.command_audit(self.report)
        self.assertEqual(self.summary['command_audit'], result)
        self.assertEqual((3200,1600,424,2776,82,31,51), tuple(result[k] for k in (
            'joint_commands','lift_goals','selected_joint_commands','fallback_joint_commands',
            'saturated_joint_commands','selected_saturated_joint_commands','fallback_saturated_joint_commands')))
        # The first cold analysis failed here. Reproduce the exact arithmetic
        # discrepancy, then check native coordinate grouping without tolerance growth.
        row = self.entries[83]; a = observation.algebra
        pose, _ = a.inputs(row); wr = row['native_output']['actuation']['receipt']['recovery_support_plane']['wave_velocity']
        snapshot = wr['previous_wave']
        wave = dict(active=snapshot['active'],limbs=[(p['nominal_leg_direction_rad'],p['walking_knee_fraction'],p['scheduled_phase_step']) for p in snapshot['ordered_limbs']])
        descriptor = self.report['configuration']['base_descriptor']; upper=.35*descriptor['upper_length_fraction']
        dimensions=(upper,.35-upper,.04*descriptor['foot_radius_scale'],descriptor['hip_span_scale'])
        old=a.goals(pose,wave,dimensions)[0]; new=observation.support_goals(pose,wave,dimensions)[0]
        self.assertGreater(old[7],1e-12)
        self.assertEqual(0.,new[7])
        self.assertEqual(new[6:8],wr['ordered_comparison_reference_rad'][6:8])
        print('V39_COLD_COMMAND_AUDIT', result, flush=True)

    def test_every_cycle_loss_and_original_failure_preserved(self):
        self.assertEqual(self.summary, observation.observe(Path(self.summary['source_closure']['path'])))
        data=self.summary['observation']; evaluation=self.resume['evaluation']
        self.assertEqual(evaluation,data['original_walking_evaluation'])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],evaluation['false_walking_receipts'])
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(.1624619133871903,evaluation['forward_advance_m'])
        self.assertEqual(.07302774472354995,evaluation['maximum_tilt_rad'])
        self.assertEqual(0,evaluation['torso_contact_step_count'])
        cycles=[c for limb in data['per_limb'] for c in limb['contact_cycles']]
        self.assertEqual((19,14,13),(len(cycles),sum(not c['original_minimum_relocation_passed'] for c in cycles),sum(c['scheduled_swing_or_landing_command_overlap_count']==0 for c in cycles)))
        self.assertEqual([2,2,2,4],[limb['recontact_hold_intervals'][0]['count'] for limb in data['per_limb']])
        self.assertEqual((139,0,430),tuple(data[k] for k in ('lowering_requested_steps','empty_common_intersection_steps','lowering_participant_limb_commands')))
        timing=self.summary['contact_timing']
        self.assertEqual((24,18),tuple(timing[k] for k in ('contact_loss_count','contact_losses_starting_in_scheduled_stance')))
        per={p['limb']:p for p in timing['per_limb']}
        self.assertEqual((False,'swing',35.),tuple(per['front_left'][k] for k in ('terminal_contact','terminal_requested_activity','terminal_requested_phase')))
        self.assertEqual((False,'stance',303.),tuple(per['rear_right'][k] for k in ('terminal_contact','terminal_requested_activity','terminal_requested_phase')))
        self.assertEqual(376,per['rear_right']['contact_losses'][-1]['liftoff_local_step'])
        self.assertEqual(0,timing['amplitude_decrease_command_count'])
        self.assertTrue(timing['terminal_still_requests_maximum_walking_amplitude'])
        self.assertEqual(0,self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])

    def test_corrupt_selector_provenance_targets_and_claims_refuse(self):
        index=next(i for i,row in enumerate(self.entries) if any(l['full_reference_rate_selected'] for l in row['native_output']['actuation']['receipt']['recovery_support_plane']['airborne_reference']['ordered_limbs']))
        for mutation in ('selector','contact','source_step','source_time','full_rate','comparison','target','motor','floor','memory'):
            rows=list(self.entries); row=copy.deepcopy(rows[index]); rows[index]=row
            act=row['native_output']['actuation']; support=act['receipt']['recovery_support_plane']; air=support['airborne_reference']
            if mutation=='selector':
                limb=next(l for l in air['ordered_limbs'] if l['full_reference_rate_selected']);limb['full_reference_rate_selected']=False
            elif mutation=='contact': air['ordered_limbs'][0]['precommand_contact']['presence']=not air['ordered_limbs'][0]['precommand_contact']['presence']
            elif mutation=='source_step': air['source_semantic_step']+=1
            elif mutation=='source_time': air['source_sample_time_s']+=.01
            elif mutation=='full_rate': air['ordered_full_reference_velocity_rad_s'][0]+=.01
            elif mutation=='comparison': support['wave_velocity']['ordered_comparison_reference_rad'][0]+=.01
            elif mutation=='target': act['ordered_commands'][0]['requested_target_position_rad']+=.01
            elif mutation=='motor': act['ordered_commands'][0]['target_velocity_rad_s']+=.01
            elif mutation=='floor': row['request']['floor_reference']['height_world_m']+=1.
            else: row['request']['memory']['support_reference']['ordered_target_positions_rad'][0]+=.01
            changed=dict(self.report,development_walking_entry=dict(self.report['development_walking_entry'],rows=rows))
            with self.subTest(mutation=mutation),self.assertRaises(AssertionError): observation.command_audit(changed)
        with mock.patch.object(observation.base,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'REPORT_DRIFT'):
            observation.observe(self.path)
        for key in ('successful_recovery_proven','complete_route_proven','physical_acceptance_authority','release_authority','repeat_consumed_attempt_permitted'):
            with self.subTest(key=key),self.assertRaises(ValueError): closure.smoke.validate_checkpoint(dict(self.record,**{key:True}),self.observed)

    def test_v38_r173_unchanged_and_no_new_physics_or_authority(self):
        for path,sha in (
            ('sdk/development/recovery_attempts/db53de264ab04bc29157f8a1524e73d0.json','d0988c97ab0ec59be9bc3dcb1a9865104222a7322c2cb025530ee1f69d9534f7'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json','c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:'+sha,closure.smoke.sha(ROOT/path))
        for key in ('new_world_build_count','new_solver_step_count','new_native_physics_read_count'):
            self.assertEqual(0,self.summary[key])
        for key in ('original_evaluation_changed','physical_cause_proven','alternate_outcome_predicted','physical_acceptance_authority','release_authority'):
            self.assertFalse(self.summary[key])


if __name__ == '__main__':
    unittest.main()
