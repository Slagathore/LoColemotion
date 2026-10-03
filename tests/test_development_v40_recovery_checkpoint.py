"""Cold V40 result, full command population and preserved negatives; no native calls."""
import copy
from pathlib import Path
import unittest
from unittest import mock

import test_development_v27_recovery_checkpoint as prior
import development_recovery_absent_contact_reference_observation as observation

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '9791149066cc43e2b42df2f1def7adc1'
SOURCE = '07fe6a9cf853136cca1ddaa2591c6537b85e0a4d'
COLD_ROOT = ROOT.parent/'SporeSpore_Evidence/development-v40-closure-d5d3bf6a6ce34157a88bfc0278a0ac16'


class AbsentContactReferenceCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
        cls.record = closure.smoke.read(cls.path)
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
        cls.entries = cls.report['development_walking_entry']['rows']
        cls.summary = closure.smoke.read(ROOT/'sdk/development/recovery_absent_contact_reference_observation_v1.json')

    def test_complete_publication_population_and_original_replay(self):
        closure.smoke.validate_checkpoint(self.record,self.observed)
        self.assertEqual(SOURCE,self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual((113,1,1258),tuple(self.record[k] for k in ('safety_test_count','world_count','solver_step_count')))
        self.assertEqual((63,1084642270),tuple(self.record['retained_population'][k] for k in ('file_count','byte_length')))
        self.assertEqual('sha256:1dcae02cd2b6e304251698e1a15bd8e9c0c209f208127d1e69b1f4730794ba47',self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:a1872bd14d79a844e48577bc5338fe7b46f1141d7a1c97460f84d52cb9c915bc',self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay=self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258,467,119,1),tuple(replay[k] for k in ('transition_count','canonical_observation_count','entry_observation_count','canonical_initialization_count')))
        self.assertEqual(430,replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400,replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(observation.POLICY,replay['walking_policy_validation']['policy_id'])
        for key in ('world_build_count','solver_step_count','native_physics_read_count'): self.assertEqual(0,replay[key])

    def test_unchanged_standing_dwell_commands_and_same_body(self):
        prior.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual(observation.POLICY,self.resume['start_receipt']['selected_policy_id'])
        self.assertEqual({90},set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual((859,1258,400),(self.entries[0]['commanded_global_step'],self.entries[-1]['commanded_global_step'],len(self.entries)))

    def test_all_commands_and_added_stance_selection_reconstructed(self):
        result=observation.command_audit(self.report)
        self.assertEqual(self.summary['command_audit'],result)
        self.assertEqual((3200,1600,874,2326,398,26,85,74,11),tuple(result[k] for k in (
            'joint_commands','lift_goals','selected_joint_commands','fallback_joint_commands',
            'selected_stance_joint_commands','selected_stance_saturated_joint_commands',
            'saturated_joint_commands','selected_saturated_joint_commands','fallback_saturated_joint_commands')))
        print('V40_COLD_COMMAND_AUDIT',result,flush=True)

    def test_every_cycle_loss_reach_interval_and_original_failure_preserved(self):
        self.assertEqual(self.summary,observation.observe(Path(self.summary['source_closure']['path'])))
        data=self.summary['observation'];evaluation=self.resume['evaluation']
        self.assertEqual(evaluation,data['original_walking_evaluation'])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],evaluation['false_walking_receipts'])
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(.16043077021547214,evaluation['forward_advance_m'])
        self.assertEqual(.11310028076953413,evaluation['maximum_tilt_rad'])
        self.assertEqual(0,evaluation['torso_contact_step_count'])
        cycles=[c for limb in data['per_limb'] for c in limb['contact_cycles']]
        self.assertEqual((15,8,9),(len(cycles),sum(not c['original_minimum_relocation_passed'] for c in cycles),sum(c['scheduled_swing_or_landing_command_overlap_count']==0 for c in cycles)))
        self.assertEqual([2,2,55,2],[limb['recontact_hold_intervals'][0]['count'] for limb in data['per_limb']])
        self.assertEqual((141,103,443),tuple(data[k] for k in ('lowering_requested_steps','empty_common_intersection_steps','lowering_participant_limb_commands')))
        timing=self.summary['contact_timing'];per={p['limb']:p for p in timing['per_limb']}
        self.assertEqual((27,22),tuple(timing[k] for k in ('contact_loss_count','contact_losses_starting_in_scheduled_stance')))
        self.assertEqual((False,'landing',72.),tuple(per['rear_left'][k] for k in ('terminal_contact','terminal_requested_activity','terminal_requested_phase')))
        self.assertEqual((297,None,True),tuple(per['rear_left']['contact_losses'][-1][k] for k in ('liftoff_local_step','touchdown_local_step','open_at_end')))
        self.assertTrue(all(p['terminal_contact'] for limb,p in per.items() if limb!='rear_left'))
        self.assertEqual(0,timing['amplitude_decrease_command_count'])
        self.assertTrue(timing['terminal_still_requests_maximum_walking_amplitude'])
        self.assertEqual(0,self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])

    def test_corrupt_added_selector_provenance_targets_and_claims_refuse(self):
        index=next(i for i,row in enumerate(self.entries) if any(l['full_reference_rate_selected'] and l['scheduled_phase_step']>72 for l in row['native_output']['actuation']['receipt']['recovery_support_plane']['airborne_reference']['ordered_limbs']))
        for mutation in ('selector','contact','source_step','source_time','full_rate','comparison','target','motor','floor','memory'):
            rows=list(self.entries);row=copy.deepcopy(rows[index]);rows[index]=row
            act=row['native_output']['actuation'];support=act['receipt']['recovery_support_plane'];air=support['airborne_reference']
            limb=next(l for l in air['ordered_limbs'] if l['full_reference_rate_selected'] and l['scheduled_phase_step']>72)
            if mutation=='selector': limb['full_reference_rate_selected']=False
            elif mutation=='contact': limb['precommand_contact']['presence']=True
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
        with mock.patch.object(observation.base,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'REPORT_DRIFT'): observation.observe(self.path)
        for key in ('successful_recovery_proven','complete_route_proven','physical_acceptance_authority','release_authority','repeat_consumed_attempt_permitted'):
            with self.subTest(key=key),self.assertRaises(ValueError): closure.smoke.validate_checkpoint(dict(self.record,**{key:True}),self.observed)

    def test_preserved_predecessor_r173_failed_checker_and_no_new_physics(self):
        for path,sha in (
            ('sdk/development/recovery_attempts/681e45b2b4784caba4018cac4e6c2b61.json','514c9331dd7117890a2f83141d9b88cbca83ffd431dceb92b28c2618a591f185'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json','c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:'+sha,closure.smoke.sha(ROOT/path))
        failed=closure.smoke.read(COLD_ROOT/'observation.execution.json')
        self.assertEqual(1,failed['exit_code']);self.assertTrue(failed['source_unchanged'])
        self.assertIn("NameError: name 'math' is not defined",(COLD_ROOT/'observation.stderr.log').read_text())
        before=(COLD_ROOT/'observation.before-import-fix.py').read_text()
        self.assertEqual(before.replace('import json\n','import json\nimport math\n'),(ROOT/'sdk/conformance/development_recovery_absent_contact_reference_observation.py').read_text())
        for key in ('new_world_build_count','new_solver_step_count','new_native_physics_read_count'):
            self.assertEqual(0,self.summary[key]);self.assertEqual(0,failed[key])
        for key in ('original_evaluation_changed','physical_cause_proven','alternate_outcome_predicted','physical_acceptance_authority','release_authority'): self.assertFalse(self.summary[key])


if __name__ == '__main__':
    unittest.main()
