"""Bind V12's synthetic raising fixtures to V11's actual support-entry angles."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate


class MeasuredRiseEntry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = candidate.read(ROOT / 'sdk/development/recovery_attempts/06d98bc4777a4fa78ce854582bfa9637.json')
        source = Path(cls.record['kicked_report']['path'])
        if candidate.sha(source) != cls.record['kicked_report']['raw_sha256']:
            raise AssertionError('V12_RETAINED_ENTRY_REPORT_DRIFT')
        report = candidate.read(source)
        packets = {p['global_semantic_step']: p for p in report['passive_entry']['canonical_packets']}
        cls.positions = [j['position_rad'] for j in json.loads(packets[410]['collection_transport']['request']['utf8_text'])['observation']['state']['ordered_joint_observations']]
        cls.old_speeds = [i['canonical_target_velocity_rad_s'] for i in packets[411]['application']['ordered_intents']]
        binding = candidate.read(ROOT / 'sdk/development/recovery_candidates/v12-measured-pose-rise-v1.runtime.json')
        fixture_path = Path(binding['compiled_fixtures']['path'])
        if candidate.sha(fixture_path) != binding['compiled_fixtures']['raw_sha256']:
            raise AssertionError('V12_ENTRY_FIXTURE_DRIFT')
        fixtures = [json.loads(line.partition(' ')[2]) for line in fixture_path.read_text().splitlines()
                    if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        cls.fixtures = [f for f in fixtures if f['request']['collection']['phase'] == 'raise_body']

    def test_all_three_rise_inputs_match_actual_v11_support_entry(self):
        self.assertEqual(3, len(self.fixtures))
        for fixture in self.fixtures:
            request = fixture['request']
            self.assertEqual(0, request['phase_step'])
            self.assertEqual(self.positions, [j['position_rad'] for j in request['collection']['observation']['state']['ordered_joint_observations']])
            self.assertTrue(fixture['synthetic_native_shaped_observations_only'])
            self.assertEqual(0, fixture['world_build_count'])

    def test_calculated_new_first_step_does_not_request_old_saturated_speeds(self):
        self.assertEqual([4.0]*8, self.old_speeds)
        vectors = []
        for fixture in self.fixtures:
            dt = fixture['request']['collection']['observation']['outer_step_duration_s']
            commands = fixture['expected']['ordered_commands']
            speeds = [(c['target_position_rad']-q)/dt for c, q in zip(commands, self.positions)]
            self.assertTrue(all(0.0 < v < 0.005 for v in speeds))
            self.assertFalse(fixture['expected']['physical_acceptance_authority'])
            vectors.append(speeds)
        self.assertEqual(vectors[0], vectors[1])
        self.assertEqual(vectors[0], vectors[2])
        print('V12_SYNTHETIC_ENTRY_COMMAND_SPEEDS', json.dumps(dict(
            source_report=self.record['kicked_report'], source_step=410,
            observed_v11_first_raise_speeds=self.old_speeds,
            calculated_v12_first_raise_speeds=vectors[0],
            new_physical_observation=False, world_build_count=0, solver_step_count=0)))


if __name__ == '__main__':
    unittest.main()
