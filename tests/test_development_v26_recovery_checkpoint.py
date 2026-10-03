"""Cold V26 observation: real zero-phase startup, two walking negatives retained."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '4ed1bcc619b64a4284505e44e122ee82'
SOURCE = 'f0498670c70fd2e90f4abc66b2bc1153b8684693'


class V26Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id') == cls.resume['session_id']]

    def test_complete_population_and_original_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        self.assertEqual((107, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((61, 1000249300), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:cc8000041189bd3547d822bfb154c9b9b1a7c5c4dcd7f7c9a81dd1f33692d3a9', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:b147debd22eb00dd1c75a2f51437bde96f5a50954e9cc921b027e9b271ec7757', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertTrue(self.record['diagnostic_coverage_complete'])  # Selected diagnostic, not an official route.
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 422, 119, 1), tuple(replay[k] for k in ('transition_count',
            'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(475, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(445, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(1, replay['walking_control_replay']['adapter_mode_transition_count'])
        self.assertEqual(1, replay['walking_start_validation']['validated_resume_sessions'])
        self.assertEqual('normal_full_authority_zero_phase_resume_v1', replay['walking_start_validation']['profile_id'])

    def test_actual_start_after_standing_preserves_body_and_original_seed(self):
        start = self.resume['start_receipt']
        prefix = next(s for s in self.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_prefix')
        self.assertEqual({240}, set(prefix['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual({0}, set(start['initial_gait_steps'].values()))
        self.assertEqual(40200, start['gait_phase_seed'])
        self.assertEqual(self.report['seed'], start['gait_phase_seed'])
        self.assertEqual((813, 814, 1258), (start['global_start_step'], self.rows[0]['global_semantic_step'], self.rows[-1]['global_semantic_step']))
        first = self.report['development_walking_entry']['rows'][0]
        self.assertEqual(self.resume['session_id'], first['session_id'])
        self.assertEqual(1, first['session_local_step'])
        self.assertIsNone(first['request']['memory']['last_semantic_step'])
        self.assertEqual({0}, {r['gait_step'] for r in first['request']['memory']['ordered_limb_memory']})
        self.assertEqual(0, first['request']['command']['gait_amplitude'])
        self.assertEqual(0.2524440884590149, self.record['walking_control_diagnosis']['maximum_first_command_target_jump_rad'])
        stance = [p for p in self.report['passive_entry']['canonical_packets'] if p['step_receipt']['prior_phase'] == 'stance_dwell']
        self.assertEqual((627, 813, 187), (stance[0]['global_semantic_step'], stance[-1]['global_semantic_step'], len(stance)))
        self.assertTrue(all(p['step_receipt']['classification']['stable_stance_gate'] for p in stance[-60:]))
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])
        self.assertFalse(self.arm['orchestrator_state']['force_aware_recovery'])

    def test_all_cycles_reconstruct_original_walking_negatives(self):
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(0.1615721188493282, evaluation['forward_advance_m'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        start = self.resume['start_receipt']
        initial = self.arm['trace_rows'][start['global_start_step'] - 1]['contact_by_limb']
        self.assertTrue(all(initial.values()))
        forward = start['task_frame_forward_axis_world_host_real']
        cycles, open_flights = [], {}
        for limb, bearing in initial.items():
            release = None
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current:
                    release = row
                elif not bearing and current and release is not None:
                    dwell = row['global_semantic_step'] - release['global_semantic_step']
                    if dwell >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        # The existing producer measures distal body origins, not sole centers.
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        displacement = sum((after[i] - before[i]) * forward[i] for i in range(3))
                        cycles.append(dict(limb=limb, release=release['walking_session_local_step'],
                            touchdown=row['walking_session_local_step'], forward_m=displacement))
                    release = None
                bearing = current
            selected = [c for c in cycles if c['limb'] == limb]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][limb], len(selected))
            # Floating-point arithmetic reproduction only; no new behavioral tolerance.
            self.assertLess(abs(min(c['forward_m'] for c in selected) - evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb]), 1e-15)
            open_flights[limb] = None if release is None else (release['walking_session_local_step'],
                self.rows[-1]['global_semantic_step'] - release['global_semantic_step'] + 1)
        self.assertEqual(11, len(cycles))
        failed = [c for c in cycles if c['forward_m'] < evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual(6, len(failed))
        self.assertTrue(all(c['touchdown'] <= 360 for c in failed))
        self.assertEqual({'front_left': None, 'front_right': (440, 6), 'rear_left': (298, 148), 'rear_right': None}, open_flights)
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])

    def test_promotion_refuses_and_earlier_results_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True),
                           ('physical_acceptance_authority', True), ('release_authority', True),
                           ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in (
            'sdk/development/recovery_attempts/51f490ed6eac47c4afc1b9b691103d83.json',
            'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json',
            'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json',
            'sdk/development/recovery_attempts/417a25fee80e4c618cd1a43252e7079c.json',
            'sdk/development/recovery_attempts/d8f05d136e4849248b7246e3e546ecf2.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
