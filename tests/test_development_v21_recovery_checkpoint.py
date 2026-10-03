"""Cold V21 closure: native inputs agree; support establishment rolls over."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '0b50a7ac1bc34180ac714bf950d2510b'
SOURCE = '66883dbfc5f2dbcc1fcfd5202d7d1c9f7bef4cc3'


class V21Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.diagnosis = cls.record['native_walking_contact_diagnosis']

    def test_complete_original_population_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual((95, 1, 642), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((55, 552475763), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:2cac442ce1f6dba2c017dfaf9b6a8135e05cf2f5c336fe579db8f5fe3bdf8c96', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:7f6efca7774ad6b417a43c970417b72bd0a12e599af182bf813fb4f99ae1b5fb', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertTrue(replay['ok'])
        self.assertEqual((642, 251, 119), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count')))
        self.assertEqual(30, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(30, replay['walking_contact_validation']['replayed_prefix_commands'])
        self.assertEqual(0, replay['walking_control_replay']['replayed_walking_steps'])

    def test_native_support_inputs_are_exact_on_exercised_prefix_only(self):
        self.assertEqual(self.diagnosis, closure.native_walking_contact_diagnostics(self.report))
        self.assertTrue(self.diagnosis['retained_source_and_precommand_trace_links_exact'])
        prefix = self.diagnosis['segments']['walking_prefix']
        self.assertEqual(30, prefix['sample_count'])
        for limb, count in [('front_left', 3), ('front_right', 30), ('rear_left', 30), ('rear_right', 10)]:
            row = prefix['by_limb'][limb]
            self.assertEqual(count, row['controller_contact_presence_count'])
            self.assertEqual(count, row['controller_bears_support_count'])
            self.assertEqual(count, row['native_precommand_bears_support_count'])
            self.assertEqual(0, row['support_flag_disagreement_count'])
        self.assertEqual(0, self.diagnosis['segments']['walking_resume']['sample_count'])
        self.assertEqual([], self.report['development_walking_entry']['rows'])
        timeout = next(iter(self.diagnosis['terminal_timeout_diagnostics_by_session'].values()))
        self.assertEqual(0, timeout['actual_native_gate_timeout_total'])
        self.assertTrue(timeout['actual_native_contact_gating_without_timeout'])
        self.assertFalse(timeout['original_evaluator_replaced'])

    def test_original_support_timeout_and_rollover_remain_negative(self):
        support = self.diagnosis['support_establishment']
        self.assertEqual((240, 403, 642, 0, 514), tuple(support[k] for k in
            ('sample_count', 'first_global_step', 'last_global_step', 'distal_support_gate_sample_count', 'first_inverted_global_step')))
        self.assertEqual('phase_timeout:establish_distal_support', self.arm['orchestrator_state']['terminal_reason'])
        self.assertEqual(-.9999999870444004, support['terminal_classification']['torso_up_dot'])
        self.assertFalse(support['terminal_classification']['all_four_distal_sites_bearing'])
        self.assertFalse(self.diagnosis['physical_cause_of_rollover_established'])
        self.assertEqual((391, 403, 0), tuple(self.record['metrics'][k] for k in
            ('prone_handoff_global_step', 'first_active_global_step', 'walking_resume_step_count')))
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])

    def test_rejects_promotion_and_preserves_v20_and_r173(self):
        for key in ('successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority',
                    'release_authority', 'causal_attribution_proven', 'diagnostic_coverage_complete'):
            self.assertIs(self.record[key], False)
            crossed = copy.deepcopy(self.record)
            crossed[key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(crossed, self.observed)
        for relative, digest in (
            ('sdk/development/recovery_attempts/a6ee7a70d3f4412f9ade65ab44e4148c.json', 'fe46db87e482123b6f94985aa5d0eda68b22d3fa561c8bf97535a1884f4de61d'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, closure.entry.runtime.file_identity(ROOT / relative)['raw_sha256'])


if __name__ == '__main__':
    unittest.main()
