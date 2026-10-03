"""Cold V10 closure and complete knee-preparation population; no native calls."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '2422bf09b7db4c1ebd39fa854a63593f'


class V10Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']))
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))

    def test_exact_original_population_publication_and_full_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(73, self.observed['safety_test_count'])
        self.assertEqual(1, self.observed['world_count'])
        self.assertEqual(626, self.observed['solver_step_count'])
        self.assertEqual(45, self.observed['retained_population']['file_count'])
        self.assertEqual(523797881, self.observed['retained_population']['byte_length'])
        self.assertIs(self.observed['comparative_authority'], False)
        self.assertIs(self.observed['baseline_reused'], False)

    def test_all_preparation_steps_use_preceding_observation_and_rear_foot_rises(self):
        previous = None
        preparation = []
        ready_steps = []
        maximum_hip_request = 0.0
        for packet in self.report['passive_entry']['canonical_packets']:
            observation = closure.entry.packet.parse_json(packet['collection_transport']['request']['utf8_text'])['observation']
            positions = [joint['position_rad'] for joint in observation['state']['ordered_joint_observations']]
            application = packet['application']
            intents = application.get('ordered_intents', [])
            if intents:
                self.assertIsNotNone(previous)
                self.assertEqual(previous[0], application['source_control_semantic_step'])
                self.assertEqual(8, len(intents))
                limits = [item['host_real_command_projection']['published_maximum_target_speed_rad_s'] for item in intents]
                self.assertEqual([4.0] * 8, limits)
                # Fixed inherited V9 destination, not a newly fitted threshold.
                ready = all(abs(1.05 - previous[1][index]) <= limits[index] * observation['outer_step_duration_s']
                            for index in (1, 3, 5, 7))
                if ready:
                    ready_steps.append(packet['global_semantic_step'])
                else:
                    preparation.append(packet['global_semantic_step'])
                    maximum_hip_request = max(maximum_hip_request,
                        *(abs(intents[index]['canonical_target_velocity_rad_s']) for index in (0, 2, 4, 6)))
            previous = (packet['global_semantic_step'], positions)
        self.assertEqual(list(range(387, 444)), preparation)
        self.assertEqual(list(range(444, 627)), ready_steps)
        # Observed serialization residual, not an acceptance tolerance.
        self.assertEqual(5.987210727198544e-11, maximum_hip_request)
        rows = self.report['retained_arm']['trace_rows']
        self.assertEqual(0.09776944667100906, rows[385]['foot_position_world_m_by_limb']['rear_left'][1])
        self.assertEqual(0.24682538211345673, rows[442]['foot_position_world_m_by_limb']['rear_left'][1])
        self.assertGreater(rows[442]['torso_position_world_m'][1], rows[385]['torso_position_world_m'][1])

    def test_unchanged_contact_rule_records_support_failure_not_recovery(self):
        metrics = self.observed['metrics']
        self.assertEqual([], metrics['four_foot_support_global_steps'])
        self.assertEqual(493, metrics['first_torso_up_vector_below_horizontal_global_step'])
        self.assertEqual(0, metrics['stable_stance_sample_count'])
        self.assertEqual(0, metrics['walking_resume_step_count'])
        self.assertEqual('phase_timeout:establish_distal_support', metrics['terminal_reason'])
        counts = {foot['contact_site_id']: foot['qualifying_sample_count']
                  for foot in self.observed['support_geometry']['per_foot_support']}
        self.assertEqual(dict(front_left_foot=91, front_right_foot=90, rear_left_foot=0, rear_right_foot=8), counts)

    def test_changed_results_claims_or_population_refuse(self):
        for key, value in [('successful_recovery_proven', True), ('comparative_authority', True),
                           ('release_authority', True), ('world_count', 2), ('solver_step_count', 625),
                           ('status', 'passed'), ('repeat_consumed_attempt_permitted', True)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)


if __name__ == '__main__':
    unittest.main()
