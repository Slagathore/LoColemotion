"""Cold V14 fold, handoff and brief stance observations; no engine rerun."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = 'f3e303d7b09146b0b23b33d6407da1d3'


class V14Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}

    def test_exact_original_population_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual('sporespore_development_recovery_candidate_checkpoint_v2', self.observed['schema_version'])
        self.assertEqual('closed_consumed_valid_development_observation', self.observed['status'])
        self.assertEqual(73, self.observed['safety_test_count'])
        self.assertEqual(1, self.observed['world_count'])
        self.assertEqual(752, self.observed['solver_step_count'])
        self.assertEqual(45, self.observed['retained_population']['file_count'])
        self.assertEqual(720507996, self.observed['retained_population']['byte_length'])
        self.assertTrue(self.observed['diagnostic_coverage_complete'])
        self.assertFalse(self.observed['complete_route_proven'])

    def test_preserved_entry_new_fold_and_actual_early_handoff(self):
        rows = {r['global_step']: r for r in self.observed['support_geometry']['samples']}
        prior = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts/6938c042f1a84754b926cb6d46de0e57.json')
        self.assertEqual(next(r for r in prior['support_geometry']['samples'] if r['global_step'] == 410), rows[410])
        self.assertTrue(all(abs(v) < 1e-9 for v in rows[411]['requested_motor_velocities_rad_s'][::2]))
        self.assertTrue(all(v < 0 for v in rows[411]['requested_motor_velocities_rad_s'][1::2]))
        self.assertIn('distal_body_origins_world_m', rows[411])
        self.assertNotIn('foot_positions_world_m', rows[411])
        events = []
        for step in (529, 530, 531, 626, 627, 628, 629, 650, 651):
            packet = self.packets[step]
            observation = json.loads(packet['collection_transport']['request']['utf8_text'])['observation']
            positions = [j['position_rad'] for j in observation['state']['ordered_joint_observations']]
            classification = packet['step_receipt']['classification']
            events.append(dict(global_step=step, phase=packet['step_receipt']['prior_phase'],
                joint_positions_rad=positions,
                maximum_folded_knee_error_rad=max(abs(q+1.05) for q in positions[1::2]),
                torso_tilt_degrees=math.degrees(math.acos(classification['torso_up_dot'])),
                four_foot_support=classification['distal_support_gate'],
                raised_body=classification['raised_body_gate'],
                any_nonfoot_contact=classification['any_nonfoot_contact'],
                requested_speeds_rad_s=[i['canonical_target_velocity_rad_s'] for i in packet['application']['ordered_intents']]))
            self.assertEqual(step-1, packet['application']['source_control_semantic_step'])
        by_step = {e['global_step']: e for e in events}
        self.assertLess(by_step[530]['maximum_folded_knee_error_rad'], .000003)
        self.assertLess(by_step[530]['torso_tilt_degrees'], .2)
        self.assertTrue(by_step[530]['any_nonfoot_contact'])
        self.assertTrue(all(v > 0 for v in by_step[531]['requested_speeds_rad_s'][::2]))
        self.assertFalse(by_step[626]['raised_body'])
        self.assertTrue(by_step[627]['raised_body'])
        self.assertFalse(by_step[627]['four_foot_support'])
        self.assertFalse(by_step[627]['any_nonfoot_contact'])
        self.assertEqual('stance_handoff', by_step[628]['phase'])
        self.assertEqual([-.75, .75]*4, by_step[628]['requested_speeds_rad_s'])
        self.assertEqual('stance_dwell', by_step[651]['phase'])
        self.assertEqual(627, max(s for s,p in self.packets.items() if p['step_receipt']['prior_phase'] == 'raise_body'))
        print('V14_RETAINED_FOLD_AND_HANDOFF', json.dumps(dict(
            source_report=self.record['kicked_report'], samples=events,
            third_recovery_reference_segment_executed=False,
            knee_supported_transfer_proven=False, causal_attribution_proven=False,
            world_build_count=0, native_read_count=0, solver_step_count=0)))

    def test_two_stable_samples_do_not_complete_dwell_or_walking(self):
        stable = [s for s,p in self.packets.items() if p['step_receipt']['classification']['stable_stance_gate']]
        self.assertEqual([749, 750], stable)
        self.assertEqual([0, 1, 2, 0, 0], [self.packets[s]['step_receipt']['memory']['stance_dwell_steps_observed'] for s in range(748, 753)])
        metrics = self.observed['metrics']
        self.assertEqual(103, sum(p['raised_samples'] for p in metrics['phase_summary']))
        self.assertEqual(2, metrics['stable_stance_sample_count'])
        self.assertEqual(0, metrics['walking_resume_step_count'])
        self.assertEqual([410, 411, 660, 661, 681, 682, 683, 733, 734, 748, 749, 750], metrics['four_foot_support_global_steps'])
        self.assertEqual(2, metrics['terminal_sample']['feet_meeting_existing_support_requirement'])
        self.assertLess(metrics['terminal_sample']['torso_tilt_degrees'], .2)
        memory = self.report['retained_arm']['recovery_memory']
        self.assertEqual('diagnostic_after_interaction_horizon', self.report['stop_reason'])
        self.assertEqual('stance_dwell', memory['phase'])
        self.assertEqual(124, memory['phase_steps_observed'])
        self.assertIsNone(memory['terminal_failure_code'])
        terminal = json.loads(self.packets[752]['collection_transport']['request']['utf8_text'])['observation']
        knees = [j['position_rad'] for j in terminal['state']['ordered_joint_observations']][1::2]
        self.assertTrue(all(-.28 < q < -.25 for q in knees))
        print('V14_RETAINED_STANCE_LIMIT', json.dumps(dict(
            source_report=self.record['kicked_report'], stable_global_steps=stable,
            consecutive_dwell_counts_748_to_752=[0, 1, 2, 0, 0], terminal_knees_rad=knees,
            terminal_sample=metrics['terminal_sample'], stance_phase_steps_observed=124,
            completed_recovery=False, longer_horizon_success_predicted=False,
            world_build_count=0, native_read_count=0, solver_step_count=0)))

    def test_altered_population_claims_labels_and_outcomes_refuse(self):
        for key, value in [('successful_recovery_proven', True), ('comparative_authority', True),
                           ('release_authority', True), ('world_count', 2), ('solver_step_count', 751),
                           ('status', 'passed'), ('repeat_consumed_attempt_permitted', True),
                           ('schema_version', 'sporespore_development_recovery_candidate_checkpoint_v1')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)


if __name__ == '__main__':
    unittest.main()
