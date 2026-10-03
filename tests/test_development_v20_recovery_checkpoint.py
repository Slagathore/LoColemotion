"""Cold V20 closure: stance timeout, shape lookup, and distinct support channels."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = 'a6ee7a70d3f4412f9ade65ab44e4148c'
SOURCE = 'a7f2ebdad746734d411d238e5eceaea65d29903e'


def threshold(document, name):
    pending = [document]
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            if value.get('threshold_id') == name:
                return value['value']
            pending.extend(value.values())
        elif isinstance(value, list):
            pending.extend(value)
    raise AssertionError('Missing frozen threshold: ' + name)


class V20Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.diagnosis = cls.record['walking_contact_diagnosis']

    def test_full_original_population_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual((91, 1, 895), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((53, 941614146), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:4f7324eec0fd1608053d155c04cc87feb2c5a5c3a320e4acf9b57d4caba83581', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:6f07a600d793d9e35ef08a4d9fcbad5424190d97e5f440c183b6cf721a499ea5', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertFalse(self.record['diagnostic_coverage_complete'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertTrue(replay['ok'])
        self.assertEqual((895, 516, 107), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count')))
        self.assertEqual(30, replay['walking_contact_validation']['validated_contact_steps'])
        self.assertEqual(0, replay['walking_control_replay']['replayed_walking_steps'])

    def test_standing_near_miss_does_not_change_frozen_rule(self):
        rules = closure.entry.packet.parse_json(closure.prior.committed(closure.prior.RULE, SOURCE).decode())
        self.assertEqual(60, threshold(rules, 'stance_dwell_steps'))
        self.assertEqual(240, threshold(rules, 'per_phase_timeout_steps')['stance_dwell'])
        self.assertEqual(.1, threshold(rules, 'maximum_terminal_linear_speed_m_s'))
        state = self.arm['orchestrator_state']
        self.assertEqual('phase_timeout:stance_dwell', state['terminal_reason'])
        self.assertEqual(0, state['walking_resume_step_count'])
        self.assertEqual((240, 85, 56, 839), tuple(self.diagnosis[k] for k in
            ('stance_sample_count', 'stable_stance_sample_count', 'terminal_consecutive_stable_samples', 'last_unstable_global_step')))
        self.assertEqual(.10747790377059024, self.diagnosis['last_unstable_classification']['terminal_linear_speed_m_s'])
        packets = {p['global_semantic_step']: p for p in self.report['passive_entry']['canonical_packets']}
        self.assertTrue(all(packets[s]['step_receipt']['classification']['stable_stance_gate'] for s in range(840, 896)))
        self.assertEqual('failed', packets[895]['step_receipt']['next_phase'])
        self.assertEqual(56, packets[895]['step_receipt']['memory']['stance_dwell_steps_observed'])
        self.assertEqual([], self.report['development_walking_entry']['rows'])
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])

    def test_contact_lookup_is_not_promoted_to_load_bearing_equivalence(self):
        self.assertEqual(self.diagnosis, closure.walking_contact_diagnostics(self.report))
        prefix = self.diagnosis['segments']['walking_prefix']
        self.assertEqual(30, prefix['sample_count'])
        for limb, count in [('front_left', 3), ('front_right', 30), ('rear_left', 30), ('rear_right', 7)]:
            row = prefix['by_limb'][limb]
            self.assertEqual(30, row['controller_contact_presence_count'])
            self.assertEqual(30, row['controller_bears_support_count'])
            self.assertEqual(count, row['native_precommand_bears_support_count'])
            self.assertEqual(30-count, row['support_flag_disagreement_count'])
            self.assertTrue(row['callback_matches_precommand_clock'])
            self.assertEqual((241, 270), (row['callback_sequence_first'], row['callback_sequence_last']))
        self.assertFalse(self.diagnosis['contact_channels_equivalent'])
        self.assertFalse(self.diagnosis['shape_lookup_correction_proves_load_qualification'])
        self.assertEqual(0, self.diagnosis['segments']['walking_resume']['sample_count'])
        timeout = next(iter(self.diagnosis['terminal_timeout_diagnostics_by_session'].values()))
        self.assertEqual(0, timeout['actual_native_gate_timeout_total'])
        self.assertTrue(timeout['actual_native_contact_gating_without_timeout'])
        self.assertFalse(timeout['original_evaluator_replaced'])

    def test_rejects_promotion_and_preserves_prior_decisions(self):
        for key in ('successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority',
                    'causal_attribution_proven', 'diagnostic_coverage_complete'):
            self.assertIs(self.record[key], False)
            crossed = copy.deepcopy(self.record)
            crossed[key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(crossed, self.observed)
        for relative, digest in (
            ('sdk/development/recovery_attempts/013cf8e4b52a46e89e68336d4edb3203.json', '45c493a3713963600d13bbf0ba1aa9b33f7a134c45043de8f483efe57d54c2a4'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, closure.entry.runtime.file_identity(ROOT / relative)['raw_sha256'])


if __name__ == '__main__':
    unittest.main()
