"""Cold V28 closure: first counted swing, unchanged standing and walking negatives."""
from pathlib import Path
import unittest

import test_development_v27_recovery_checkpoint as v27

closure = v27.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = 'dd42319c12564b7ea402626dbaf8f845'
SOURCE = '276f95959964df52ba3ccab0c3642e8836f4f937'


class V28Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id') == cls.resume['session_id']]

    def test_complete_population_and_original_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        self.assertEqual((107, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((61, 1052965717), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:e19e479273a4906f795db2c06e2ffe7580f90dcf0df1d973ef44aab9a244e376', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:4dfc5c69f268e97a88d6d6c910f83691d9fb82b9757a610981d0ca761494b293', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertTrue(self.record['diagnostic_coverage_complete'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(1, replay['walking_control_replay']['adapter_mode_transition_count'])
        self.assertEqual(1, replay['walking_start_validation']['validated_resume_sessions'])

    def test_actual_stance_ramp_and_original_standing_gate(self):
        # Reuse the independent reconstruction, not V27's physical evidence.
        # It checks all 1864 V28 joint commands against measured inputs, the
        # reference ramp, speed cap, original 60-sample gate and same-body state.
        v27.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        first = self.report['development_walking_entry']['rows'][0]
        self.assertEqual((1, 858, 859), tuple(first[k] for k in ('session_local_step', 'measured_global_step', 'commanded_global_step')))
        self.assertEqual({0}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual(40200, self.resume['start_receipt']['gait_phase_seed'])

    def test_executed_ramp_and_all_contact_cycles_keep_original_negatives(self):
        entries = self.report['development_walking_entry']['rows']
        self.assertEqual(list(range(1, 401)), [r['session_local_step'] for r in entries])
        for row in entries:
            local = row['session_local_step']
            t = min((local - 1) / 72, 1)
            self.assertAlmostEqual(t * t * (3 - 2 * t), row['request']['command']['gait_amplitude'], places=14)
            self.assertEqual('clocked' if local <= 360 else 'contact_gated', row['request']['command']['phase_progression_mode'])
        self.assertEqual(328, sum(r['request']['command']['gait_amplitude'] == 1 for r in entries))
        self.assertEqual(34, sum(r['contact_by_limb']['rear_left'] for r in self.rows[:72]))
        self.assertEqual(32, next(r['walking_session_local_step'] for r in self.rows if not r['contact_by_limb']['rear_left']))
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(0.3191290686609283, evaluation['forward_advance_m'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        cycles, open_gaps = [], {}
        initial = self.arm['trace_rows'][857]['contact_by_limb']
        self.assertTrue(all(initial.values()))
        for limb, phase_index in {'rear_left': 0, 'front_left': 1, 'rear_right': 2, 'front_right': 3}.items():
            bearing, release = initial[limb], None
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current:
                    release = row
                elif not bearing and current and release is not None:
                    if row['global_semantic_step'] - release['global_semantic_step'] >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        advance = sum((after[i] - before[i]) * axis[i] for i in range(3))
                        phase = (release['walking_session_local_step'] - 1 + 360 - phase_index * 90) % 360
                        cycles.append(dict(limb=limb, release=release['walking_session_local_step'], touchdown=row['walking_session_local_step'], forward_m=advance, release_phase=phase))
                    release = None
                bearing = current
            selected = [c for c in cycles if c['limb'] == limb]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][limb], len(selected))
            self.assertAlmostEqual(min(c['forward_m'] for c in selected), evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb], places=14)
            open_gaps[limb] = None if release is None else (release['walking_session_local_step'], self.rows[-1]['global_semantic_step'] - release['global_semantic_step'] + 1)
        self.assertEqual(9, len(cycles))
        self.assertEqual((38, 87, 0.11340429609771685), tuple(cycles[0][k] for k in ('release', 'touchdown', 'forward_m')))
        failed = [c for c in cycles if c['forward_m'] < evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual(4, len(failed))
        self.assertTrue(all(c['release_phase'] >= 72 for c in failed))
        self.assertEqual({'rear_left': (394, 7), 'front_left': None, 'rear_right': None, 'front_right': (293, 108)}, open_gaps)
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])

    def test_promotion_refuses_and_all_earlier_results_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in ('sdk/development/recovery_attempts/8f778946bed1448d80196dc57b446dda.json',
                         'sdk/development/recovery_attempts/4e43b57e644d47a78c1e80681361a24a.json',
                         'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json',
                         'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json',
                         'sdk/development/recovery_attempts/d8f05d136e4849248b7246e3e546ecf2.json',
                         'sdk/development/recovery_attempts/4ed1bcc619b64a4284505e44e122ee82.json',
                         'sdk/core/src/runtime.rs', 'sdk/core/src/recovery_runtime.rs',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
