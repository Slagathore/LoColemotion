"""Cold V17 mixed result: completed standing, same-body walking, negative gait."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '5436af3ddcad48dda0f2450ce0a9dd7b'


class V17Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.requests = {s: closure.entry.packet.parse_json(p['collection_transport']['request']['utf8_text'])
                        for s, p in cls.packets.items()}
        cls.stance = [s for s,p in cls.packets.items() if p['step_receipt']['prior_phase'] == 'stance_dwell']
        cls.walking = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')

    def test_original_replay_and_complete_diagnostic_population(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual('closed_consumed_valid_development_observation', self.observed['status'])
        self.assertEqual((77, 1, 898), tuple(self.observed[k] for k in ('safety_test_count','world_count','solver_step_count')))
        self.assertEqual((47, 813429767), tuple(self.observed['retained_population'][k] for k in ('file_count','byte_length')))
        self.assertTrue(self.observed['diagnostic_coverage_complete'])
        self.assertFalse(self.observed['complete_route_proven'])  # Not full official route authority.
        self.assertEqual(1214.274, self.observed['elapsed_seconds']['whole_invocation'])
        self.assertEqual('diagnostic_after_interaction_horizon', self.report['stop_reason'])
        self.assertEqual(626, self.report['after_interaction_step_count'])
        self.assertIn('sdk/development/recovery_schedules/v17-velocity-damped-stance-v1.json',
                      [s['path'] for s in self.observed['rule_sources']])

    def test_completed_standing_and_all_actual_damped_commands(self):
        source = self.record['source_snapshot']['head']
        contract = closure.entry.packet.parse_json(closure.prior.committed(
            'sdk/core/contracts/recovery_candidate_stance_profiles_v3.json', source).decode())
        profile = contract['profiles'][0]
        fraction = self.requests[self.stance[0]]['descriptor']['upper_length_fraction']
        knee = profile['target_knee_angle_rad']
        hip = -math.atan2((1-fraction)*math.sin(knee), fraction+(1-fraction)*math.cos(knee))
        dwell = maximum = count = 0
        maximum_command_error = 0.0
        for step in self.stance:
            p = self.packets[step]
            dwell = dwell+1 if p['step_receipt']['classification']['stable_stance_gate'] else 0
            self.assertEqual(dwell, p['step_receipt']['memory']['stance_dwell_steps_observed'])
            maximum = max(maximum, dwell)
            applied = p['application']
            self.assertEqual(step-1, applied['source_control_semantic_step'])
            self.assertEqual(profile['controller_id'], applied['stance_controller_id'])
            joints = self.requests[step-1]['observation']['state']['ordered_joint_observations']
            for goal,intent,joint in zip([hip,knee]*4, applied['ordered_intents'], joints):
                self.assertEqual(intent['joint_id'], joint['joint_id'])
                self.assertTrue(joint['validity']['velocity'])
                expected = max(-.75, min(.75, (goal-joint['position_rad'])/profile['response_time_s']
                                        - profile['measured_velocity_damping_gain']*joint['velocity_rad_s']))
                error = abs(expected-intent['canonical_target_velocity_rad_s'])
                maximum_command_error = max(maximum_command_error, error)
                self.assertLess(error, 1e-10)  # Guarded decimal transport only.
                self.assertLessEqual(abs(intent['canonical_target_velocity_rad_s']), .75)
                count += 1
        self.assertEqual((60,60,1416), (dwell,maximum,count))
        phase = self.observed['metrics']['phase_summary'][-1]
        self.assertEqual([629,805,177,98,170,68],
            [phase[k] for k in ('first_step','last_step','sample_count','support_samples','raised_samples','stable_samples')])
        self.assertTrue(all(self.packets[s]['step_receipt']['classification']['stable_stance_gate'] for s in range(746,806)))
        self.assertEqual('complete', self.packets[805]['step_receipt']['next_phase'])
        self.assertEqual('', self.observed['metrics']['terminal_reason'])
        print('V17_RETAINED_STANDING', json.dumps(dict(source_report=self.record['kicked_report'],
            observed_standing_completion_step=805, consecutive_stable_steps=[746,805],
            checked_commands=count, maximum_command_error_rad_s=maximum_command_error,
            official_recovery_acceptance=False, world_build_count=0, solver_step_count=0), separators=(',',':')))

    def test_same_body_walking_handoff_is_not_successful_walking(self):
        walk = self.walking
        evaluation = walk['evaluation']
        self.assertEqual(805, walk['start_receipt']['global_start_step'])
        self.assertEqual(93, len(walk['step_receipt_sha256s']))
        trace = [r for r in self.arm['trace_rows'] if r['walking_segment_id'] == 'walking_resume']
        self.assertEqual(list(range(806,899)), [r['global_semantic_step'] for r in trace])
        self.assertTrue(all(r['control_owner'] == 'walking_bw5r_b' for r in trace))
        self.assertEqual(93, self.observed['metrics']['walking_resume_step_count'])
        self.assertTrue(walk['completion_receipt']['ok'])
        for key in ('body_transform_write_count','body_velocity_write_count','solver_reset_count'):
            self.assertEqual(0, walk['start_receipt'][key])
            self.assertEqual(0, walk['completion_receipt'][key])
        same = self.report['terminal_same_body_identity_receipt']
        self.assertTrue(same['ok'])
        self.assertEqual(17, same['same_body_node_identity_count'])
        self.assertTrue(all(r['same_instance'] for r in same['ordered_node_identity_rows']))
        self.assertTrue(evaluation['ok'] and evaluation['evidence_valid'] and evaluation['outcome_complete'])
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(-.07224338988678158, evaluation['forward_advance_m'])
        self.assertEqual(dict(front_left=3,front_right=0,rear_left=1,rear_right=3), evaluation['contact_cycle_count_by_limb'])
        self.assertEqual(['every_limb_forward_relocation','every_limb_two_contact_cycles',
            'minimum_evidence_forward_translation','minimum_final_forward_translation','terminal_four_contact_recovery'],
            evaluation['false_walking_receipts'])
        self.assertEqual(0, evaluation['threshold_override_input_count'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        self.assertLess(evaluation['maximum_tilt_rad'], evaluation['fixed_thresholds']['maximum_tilt_rad'])
        print('V17_RETAINED_WALKING_NEGATIVE', json.dumps(dict(source_report=self.record['kicked_report'],
            original_walking_evaluation=evaluation, same_body_count=17,
            next_question='Audit retained walking task-frame/initial gait state and short-horizon limits before any controller or schedule successor.',
            long_horizon_walking_failure_proven=False, causal_attribution_proven=False,
            world_build_count=0, solver_step_count=0), separators=(',',':')))

    def test_forged_claims_refuse_and_predecessors_remain_exact(self):
        for key,value in [('successful_recovery_proven',True), ('release_authority',True), ('world_count',2),
                          ('solver_step_count',897), ('repeat_consumed_attempt_permitted',True), ('status','passed')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key:value}), self.observed)
        for relative in ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json',
                         'sdk/development/recovery_attempts/16d22c82f50247f3be4fd349e76407a7.json',
                         'sdk/core/contracts/recovery_candidate_stance_profiles_v2.json',
                         'sdk/development_recovery_candidate_schedules_v1.json'):
            self.assertEqual(closure.prior.committed(relative, self.record['source_snapshot']['head']), (ROOT/relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
