"""Cold V25 negative: full replay, measured stance commands, no walking claim."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = 'd8f05d136e4849248b7246e3e546ecf2'
SOURCE = '2bee626311f50cfbd8ffbfe025c8be490e40b469'


class V25Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.stance = {s: p for s, p in cls.packets.items() if p['step_receipt']['prior_phase'] == 'stance_dwell'}

    def test_complete_original_population_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual((103, 1, 866), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((59, 906052132), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:7a31025dfa423b4943dc73364ebf7a6fad493a4b832a3e6028442e34490e9212', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:7c0da74e1c3f26d59caa5b2b5266357a9a40ee4937063323c17e53ab2d2eec26', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertFalse(self.record['diagnostic_coverage_complete'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((866, 475, 119, 1), tuple(replay[k] for k in ('transition_count',
            'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(30, replay['walking_contact_validation']['replayed_prefix_commands'])
        self.assertEqual(0, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(0, replay['walking_control_replay']['adapter_mode_transition_count'])
        self.assertEqual('production_adapter_clocked_warmup_v1', replay['walking_control_replay']['memory_transition_profile_id'])

    def test_standing_timeout_preserves_the_consecutive_requirement(self):
        self.assertEqual('closed_consumed_valid_development_behavior_negative', self.record['status'])
        self.assertEqual('phase_timeout:stance_dwell', self.record['metrics']['terminal_reason'])
        self.assertEqual(0, self.record['metrics']['walking_resume_step_count'])
        self.assertEqual((627, 866, 240), (min(self.stance), max(self.stance), len(self.stance)))
        failures = {key: sum(not p['step_receipt']['classification'][key] for p in self.stance.values())
                    for key in ('distal_support_gate', 'raised_body_gate', 'stable_stance_gate', 'safety_gate',
                                'exclusive_stance_handoff_gate', 'no_cheat_gate')}
        self.assertEqual([174, 44, 199, 0, 0, 0], list(failures.values()))
        consecutive = best = 0
        for p in self.stance.values():
            consecutive = consecutive + 1 if p['step_receipt']['classification']['stable_stance_gate'] else 0
            self.assertEqual(consecutive, p['step_receipt']['memory']['stance_dwell_steps_observed'])
            best = max(best, consecutive)
        self.assertEqual((32, 32), (best, consecutive))
        self.assertTrue(all(self.stance[s]['step_receipt']['classification']['stable_stance_gate'] for s in range(835, 867)))
        self.assertFalse(self.stance[834]['step_receipt']['classification']['distal_support_gate'])
        rules = closure.entry.packet.parse_json(closure.prior.committed(closure.prior.RULE, SOURCE).decode())
        values = {r['threshold_id']: r['value'] for r in rules['threshold_profile']['thresholds']}
        self.assertEqual(60, values['stance_dwell_steps'])
        self.assertEqual(240, values['per_phase_timeout_steps']['stance_dwell'])

    def test_actual_damped_neutral_commands_and_same_body_identity(self):
        observations = {s: closure.entry.packet.parse_json(p['collection_transport']['request']['utf8_text'])['observation']
                        for s, p in self.packets.items()}
        checked = 0
        for step, packet in self.stance.items():
            application = packet['application']
            self.assertEqual(step - 1, application['source_control_semantic_step'])
            self.assertEqual('sporespore_exact_s169_stance_handoff_controller_v6', application['stance_controller_id'])
            previous = observations[step - 1]['state']['ordered_joint_observations']
            for intent, joint in zip(application['ordered_intents'], previous):
                self.assertEqual(intent['joint_id'], joint['joint_id'])
                expected = max(-.75, min(.75, -joint['position_rad'] / .1 - .5 * joint['velocity_rad_s']))
                # Decimal projection check only; this is not a behavioral tolerance.
                self.assertLess(abs(intent['canonical_target_velocity_rad_s'] - expected), 1e-10)
                self.assertLessEqual(abs(intent['canonical_target_velocity_rad_s']), .75)
                checked += 1
        self.assertEqual(1920, checked)
        arm = self.report['retained_arm']
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, arm[key])
        self.assertEqual(arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])
        self.assertFalse(arm['orchestrator_state']['force_aware_recovery'])

    def test_promotion_refuses_and_earlier_results_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True),
                           ('physical_acceptance_authority', True), ('release_authority', True),
                           ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 867)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in (
            'sdk/development/recovery_attempts/417a25fee80e4c618cd1a43252e7079c.json',
            'sdk/development/recovery_attempts/e890db0576d94a2e9380186b56ac732b.json',
            'sdk/development/recovery_attempts/51f490ed6eac47c4afc1b9b691103d83.json',
            'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json',
            'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
