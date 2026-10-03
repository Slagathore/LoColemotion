"""Cold V13 evidence and waypoint observations. No engine or replay rerun."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '6938c042f1a84754b926cb6d46de0e57'


class V13Checkpoint(unittest.TestCase):
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
        self.assertEqual(724148641, self.observed['retained_population']['byte_length'])
        self.assertTrue(self.observed['diagnostic_coverage_complete'])
        self.assertFalse(self.observed['complete_route_proven'])

    def test_preserved_entry_and_real_new_commands_still_lose_support(self):
        rows = {r['global_step']: r for r in self.observed['support_geometry']['samples']}
        prior = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts/00690ff0730f43aebb53bd35b6b87c81.json')
        self.assertEqual(next(r for r in prior['support_geometry']['samples'] if r['global_step'] == 410), rows[410])
        self.assertTrue(all(0 < speed < .013 for speed in rows[411]['requested_motor_velocities_rad_s']))
        self.assertEqual([410, 411], self.observed['metrics']['four_foot_support_global_steps'])
        self.assertEqual(412, self.observed['metrics']['first_support_loss_after_support_global_step'])
        self.assertEqual(['front_left_foot', 'front_right_foot'], rows[412]['qualifying_feet'])
        self.assertIn('distal_body_origins_world_m', rows[412])
        self.assertNotIn('foot_positions_world_m', rows[412])

    def test_waypoint_is_closely_approached_while_body_is_already_tipped(self):
        # Descriptive values of this trace, not new physical acceptance margins.
        waypoint = [-.6, 1.05] * 4
        events = []
        for step in (589, 590, 591):
            packet = self.packets[step]
            observation = json.loads(packet['collection_transport']['request']['utf8_text'])['observation']
            positions = [j['position_rad'] for j in observation['state']['ordered_joint_observations']]
            classification = packet['step_receipt']['classification']
            events.append(dict(global_step=step, joint_positions_rad=positions,
                maximum_waypoint_error_rad=max(abs(q-g) for q, g in zip(positions, waypoint)),
                torso_tilt_degrees=math.degrees(math.acos(classification['torso_up_dot'])),
                four_foot_support=classification['distal_support_gate'],
                raised_body=classification['raised_body_gate'],
                requested_speeds_rad_s=[i['canonical_target_velocity_rad_s'] for i in packet['application']['ordered_intents']]))
            self.assertEqual(step-1, packet['application']['source_control_semantic_step'])
        self.assertLess(events[1]['maximum_waypoint_error_rad'], .006)
        self.assertTrue(all(76 < e['torso_tilt_degrees'] < 77 for e in events))
        self.assertTrue(all(not e['four_foot_support'] and not e['raised_body'] for e in events))
        self.assertTrue(all(v < 0 for v in events[2]['requested_speeds_rad_s'][1::2]))
        metrics = self.observed['metrics']
        self.assertEqual(0, sum(p['raised_samples'] for p in metrics['phase_summary']))
        self.assertEqual(0, metrics['stable_stance_sample_count'])
        self.assertEqual(0, metrics['walking_resume_step_count'])
        self.assertEqual(0, metrics['terminal_sample']['feet_meeting_existing_support_requirement'])
        self.assertEqual('diagnostic_after_interaction_horizon', self.report['stop_reason'])
        self.assertEqual('raise_body', self.report['retained_arm']['recovery_memory']['phase'])
        self.assertIsNone(self.report['retained_arm']['recovery_memory']['terminal_failure_code'])
        print('V13_RETAINED_WAYPOINT_BOUNDARY', json.dumps(dict(
            source_report=self.record['kicked_report'], waypoint_rad=waypoint, samples=events,
            causal_attribution_proven=False, world_build_count=0, native_read_count=0, solver_step_count=0)))

    def test_altered_population_claims_labels_and_outcomes_refuse(self):
        for key, value in [('successful_recovery_proven', True), ('comparative_authority', True),
                           ('release_authority', True), ('world_count', 2), ('solver_step_count', 751),
                           ('status', 'passed'), ('repeat_consumed_attempt_permitted', True),
                           ('schema_version', 'sporespore_development_recovery_candidate_checkpoint_v1')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)


if __name__ == '__main__':
    unittest.main()
