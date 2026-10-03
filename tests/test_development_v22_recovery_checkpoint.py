"""Cold V22 closure: standing completes; resumed walking remains negative."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '51f490ed6eac47c4afc1b9b691103d83'
SOURCE = '3b53ce2f8a612e2ecfb88c5fd7d9932fafce33c4'


class V22Checkpoint(unittest.TestCase):
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
        self.assertEqual((95, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((55, 1000097343), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:86d8130c969e73db47f8e9255b8c79b663ac1d56d948e86a30611603ef46dbc4', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:9022960086c6051ebf1176650aec22d0dfef0a660ce3ae5cf8ac3f53a7f5c503', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertTrue(self.record['diagnostic_coverage_complete'])
        child = self.record['children'][0]
        self.assertEqual('diagnostic_after_interaction_horizon', child['stop_reason'])
        replay = child['passive_entry_replay']
        self.assertTrue(replay['ok'])
        self.assertEqual((1258, 422, 119), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count')))
        self.assertEqual(475, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(30, replay['walking_contact_validation']['replayed_prefix_commands'])
        self.assertEqual(445, replay['walking_control_replay']['replayed_walking_steps'])

    def test_actual_support_and_standing_complete_without_body_replacement(self):
        support = self.diagnosis['support_establishment']
        self.assertEqual((6, 403, 408, 1, None), tuple(support[k] for k in
            ('sample_count', 'first_global_step', 'last_global_step', 'distal_support_gate_sample_count', 'first_inverted_global_step')))
        stance = [p for p in self.report['passive_entry']['canonical_packets']
                  if p['step_receipt']['prior_phase'] == 'stance_dwell']
        self.assertEqual((187, 627, 813), (len(stance), stance[0]['global_semantic_step'], stance[-1]['global_semantic_step']))
        self.assertTrue(all(p['step_receipt']['classification']['stable_stance_gate'] for p in stance[-60:]))
        self.assertEqual('complete', self.record['metrics']['phase_transitions'][-1]['next_phase'])
        self.assertEqual((391, 403, 445), tuple(self.record['metrics'][k] for k in
            ('prone_handoff_global_step', 'first_active_global_step', 'walking_resume_step_count')))
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])
        self.assertFalse(self.arm['orchestrator_state']['force_aware_recovery'])

    def test_walking_inputs_are_truthful_but_six_walking_checks_remain_negative(self):
        self.assertEqual(self.diagnosis, closure.native_walking_contact_diagnostics(self.report))
        self.assertTrue(self.diagnosis['retained_source_and_precommand_trace_links_exact'])
        self.assertEqual(475, self.diagnosis['sample_count'])
        for segment, counts in (
            ('walking_prefix', [3, 30, 30, 10]),
            ('walking_resume', [275, 314, 291, 296])):
            for limb, count in zip(('front_left', 'front_right', 'rear_left', 'rear_right'), counts):
                row = self.diagnosis['segments'][segment]['by_limb'][limb]
                self.assertEqual(count, row['controller_bears_support_count'])
                self.assertEqual(count, row['native_precommand_bears_support_count'])
                self.assertEqual(0, row['support_flag_disagreement_count'])
        for timeout in self.diagnosis['terminal_timeout_diagnostics_by_session'].values():
            self.assertEqual(0, timeout['actual_native_gate_timeout_total'])
            self.assertTrue(timeout['actual_native_contact_gating_without_timeout'])
            self.assertFalse(timeout['original_evaluator_replaced'])
        walk = next(s['evaluation'] for s in self.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        self.assertFalse(walk['behavior_passed'])
        self.assertEqual(['bounded_tilt', 'every_limb_forward_relocation', 'every_limb_two_contact_cycles',
            'minimum_evidence_forward_translation', 'minimum_final_forward_translation',
            'terminal_four_contact_recovery'], walk['false_walking_receipts'])
        self.assertEqual(445, walk['trace_row_count'])
        self.assertEqual(0.013933499863821641, walk['forward_advance_m'])
        self.assertEqual(0.6060450182557586, walk['maximum_tilt_rad'])
        self.assertEqual(0.02, walk['fixed_thresholds']['minimum_forward_advance_m'])
        self.assertEqual(0.6, walk['fixed_thresholds']['maximum_tilt_rad'])
        self.assertEqual(0, walk['torso_contact_step_count'])
        self.assertEqual(dict(front_left=1, front_right=7, rear_left=5, rear_right=2), walk['contact_cycle_count_by_limb'])

    def test_rejects_promotion_and_preserves_v21_and_r173(self):
        for key in ('successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority',
                    'release_authority', 'causal_attribution_proven', 'comparative_authority'):
            self.assertIs(self.record[key], False)
            crossed = copy.deepcopy(self.record)
            crossed[key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(crossed, self.observed)
        for relative, digest in (
            ('sdk/development/recovery_attempts/0b50a7ac1bc34180ac714bf950d2510b.json', '7152e0361c3130a376f2013b6bbd98073c398655c1a2b3a9a8678b6054b53e8d'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, closure.entry.runtime.file_identity(ROOT / relative)['raw_sha256'])


if __name__ == '__main__':
    unittest.main()
