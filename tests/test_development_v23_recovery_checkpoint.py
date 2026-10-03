"""V23 stays replay-invalid; physical measurements are explicitly provisional."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '92dd4a7de9124bd6bde70dd7a9042843'
SOURCE = '50f19c4edc2f16b84f0c87cd985f1115001e3b95'


class V23Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe_clocked_entry_replay_failure(Path(cls.record['evidence_root']))
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))

    def test_original_failure_and_entire_population_remain_exact(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual('closed_consumed_independent_replay_invalid', self.record['status'])
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual((95, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((54, 1000179864), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:cc53c1ad3db5c324255cf96a8b09a28dd3fcce0688856080f8f31fb669aaa4e0', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:334f447d01b1ac258d90a5d604576ffe6a92d3142842d5e72de7c96e92c6a7c2', self.record['kicked_report']['raw_sha256'])
        self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_MEMORY_CHAIN', self.record['failed_replay']['failure_code'])
        for key in ('original_independent_replay_passed', 'full_recovery_sequence_independently_replayed', 'original_supervisor_passed', 'original_independent_audit_present'):
            self.assertIs(self.record[key], False)

    def test_only_one_adapter_endpoint_transition_differs(self):
        diagnosis = self.record['memory_transition_diagnosis']
        self.assertEqual((445, 1), (diagnosis['sample_count'], diagnosis['mismatch_count']))
        transition = diagnosis['mismatches'][0]
        self.assertEqual((361, 1174), (transition['local_step'], transition['global_step']))
        expected = copy.deepcopy(transition['previous_output_memory'])
        for limb in expected['ordered_limb_memory']:
            self.assertEqual((599, 1680), (limb['gait_step'], limb['evidence_gait_step_limit']))
            limb['evidence_gait_step_limit'] = 2040
        self.assertEqual(expected, transition['next_request_memory'])
        self.assertFalse(diagnosis['actual_adapter_transition_independently_executed'])
        source = closure.prior.committed('scripts/lab/gait/sdk_godot_jolt_adapter.gd', SOURCE).decode()
        self.assertIn('const GAIT_CYCLE_STEPS := 360', source)
        self.assertIn('const CANDIDATE35_EVIDENCE_GAIT_STEPS := 4 * GAIT_CYCLE_STEPS', source)
        self.assertIn('int(limb_memory.get("gait_step", 0))', source)
        rows = self.report['development_walking_entry']['rows']
        self.assertEqual(['clocked'] * 360 + ['contact_gated'] * 85,
                         [r['request']['command']['phase_progression_mode'] for r in rows])

    def test_provisional_motion_keeps_two_negative_checks_and_same_body(self):
        arm = self.report['retained_arm']
        walk = next(s['evaluation'] for s in arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        self.assertFalse(walk['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], walk['false_walking_receipts'])
        self.assertEqual(0.1695505567112101, walk['forward_advance_m'])
        self.assertEqual(0.0012812295810644692, walk['absolute_lateral_drift_m'])
        self.assertEqual(0.1796004240043006, walk['maximum_tilt_rad'])
        self.assertEqual(dict(front_left=4, front_right=6, rear_left=7, rear_right=2), walk['contact_cycle_count_by_limb'])
        self.assertEqual((0.02, 0.012, 0.6), tuple(walk['fixed_thresholds'][k] for k in ('minimum_forward_advance_m', 'minimum_foot_relocation_m', 'maximum_tilt_rad')))
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, arm[key])
        stance = [p for p in self.report['passive_entry']['canonical_packets'] if p['step_receipt']['prior_phase'] == 'stance_dwell']
        self.assertEqual((187, 813), (len(stance), stance[-1]['global_semantic_step']))
        self.assertTrue(all(p['step_receipt']['classification']['stable_stance_gate'] for p in stance[-60:]))

    def test_no_promotion_and_prior_records_preserved(self):
        for key in ('successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority',
                    'comparative_authority', 'causal_attribution_proven', 'repeat_consumed_attempt_permitted', 'original_independent_replay_passed'):
            self.assertIs(self.record[key], False)
            bad = copy.deepcopy(self.record)
            bad[key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(bad, self.observed)
        for path, digest in (
            ('sdk/development/recovery_attempts/51f490ed6eac47c4afc1b9b691103d83.json', '580e4c1509536b7b9732e1863177bf4e2e23d1aa7988d34eab9f2a84e1791947'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, closure.entry.runtime.file_identity(ROOT / path)['raw_sha256'])


if __name__ == '__main__':
    unittest.main()
