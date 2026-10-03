"""Separate successful replay never rewrites or promotes the invalid V23 run."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure


class TransitionDiagnosticCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json')
        cls.observed = closure.observe_transition_diagnostic(Path(cls.record['evidence_root']))

    def test_exact_diagnostic_files_and_original_failed_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        population = self.record['retained_population']
        self.assertEqual((4, 102561), (population['file_count'], population['byte_length']))
        self.assertEqual('sha256:1190f4d37313009660ddd15134d9a68dc244a9d93fb8e51f754fb53b21a99e38', population['inventory_sha256'])
        self.assertEqual('closed_consumed_independent_replay_invalid', self.record['original_attempt_status'])
        original = closure.smoke.read(Path(self.record['original_invalid_closure']['path']))
        self.assertFalse(original['original_independent_replay_passed'])
        self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_MEMORY_CHAIN', original['failed_replay']['failure_code'])

    def test_complete_retained_timeline_and_production_adapter_transition(self):
        result = self.record['diagnostic_result']
        self.assertTrue(result['ok'])
        self.assertTrue(result['complete_report_timeline_replayed'])
        self.assertEqual((1258, 422, 119, 1), tuple(result[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual((475, 30), tuple(result['walking_contact_validation'][k] for k in ('validated_native_contact_steps', 'replayed_prefix_commands')))
        self.assertEqual((445, 1), tuple(result['walking_control_replay'][k] for k in ('replayed_walking_steps', 'adapter_mode_transition_count')))
        self.assertEqual('production_adapter_clocked_warmup_v1', result['walking_control_replay']['memory_transition_profile_id'])
        self.assertTrue(self.record['exact_source_unchanged_during_replay'])
        for k in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertEqual(0, result[k])

    def test_original_walking_negatives_and_thresholds_not_regraded(self):
        walk = self.record['original_recorded_walking_evaluation']
        self.assertFalse(walk['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], walk['false_walking_receipts'])
        self.assertEqual((0.02, 0.012, 0.6), tuple(walk['fixed_thresholds'][k] for k in ('minimum_forward_advance_m', 'minimum_foot_relocation_m', 'maximum_tilt_rad')))
        self.assertEqual(0.1695505567112101, walk['forward_advance_m'])
        self.assertFalse(self.record['evaluation_regraded'])
        original = Path(self.record['original_report']['path'])
        with self.assertRaisesRegex(ValueError, 'MEMORY_TRANSITION_EXECUTION_SELECTION'):
            closure.entry.consume_replay(original, diagnostic_directory=Path(self.record['evidence_root']))

    def test_refuses_promotion_or_extra_claims_and_r173_is_exact(self):
        for key in ('original_attempt_reclassified', 'complete_route_proven', 'successful_recovery_proven',
                    'physical_acceptance_authority', 'release_authority', 'causal_attribution_proven'):
            self.assertIs(self.record[key], False)
            bad = copy.deepcopy(self.record)
            bad[key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(bad, self.observed)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
