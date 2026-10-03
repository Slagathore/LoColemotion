"""Cold V29 closure: bounded commands, complete native replay, preserved negatives."""
from pathlib import Path
import unittest

import test_development_v27_recovery_checkpoint as v27

closure = v27.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '66b2e79c43d3401285f7cdba0f607990'
SOURCE = 'd24d394ba0eec042337ad3702a712b54fd4d9fd4'


class V29Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id') == cls.resume['session_id']]

    def test_complete_population_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        self.assertEqual((107, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((61, 1052717952), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:26139d373f23403e04234acb1d926de779e54f8bcc077d259ac51e8f8a2ab464', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:c6ecd396aaaad898b4d0c4cfa235429507559e680ebc2c00a4c27332067b24d9', self.record['kicked_report']['raw_sha256'])
        self.assertEqual(32, len(self.record['rule_sources']))
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(1, replay['walking_control_replay']['adapter_mode_transition_count'])
        self.assertEqual(1, replay['walking_start_validation']['validated_resume_sessions'])
        for key in ('world_build_count', 'native_physics_read_count', 'solver_step_count'):
            self.assertEqual(0, replay[key])

    def test_actual_standing_and_all_joint_bounded_walking_commands(self):
        # Reconstruct 1,864 V29 stance commands and the unchanged 60-sample
        # standing gate, using V29 measured inputs, not V27 physical evidence.
        v27.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        entries = self.report['development_walking_entry']['rows']
        self.assertEqual(list(range(1, 401)), [r['session_local_step'] for r in entries])
        maximum = 1.1 / (.82 * 1.75 + .4)
        knees = []
        for row in entries:
            local = row['session_local_step']
            t = min((local-1)/72, 1)
            self.assertAlmostEqual(maximum*t*t*(3-2*t), row['request']['command']['gait_amplitude'], places=14)
            self.assertEqual('clocked' if local <= 360 else 'contact_gated', row['request']['command']['phase_progression_mode'])
            knees.extend(c for c in row['native_output']['actuation']['ordered_commands'] if c['actuator_id'].endswith('_knee_motor'))
        self.assertEqual(1600, len(knees))
        self.assertEqual(0, sum(c['position_saturated'] for c in knees))
        self.assertEqual(1.1, max(c['requested_target_position_rad'] for c in knees))
        self.assertEqual(328, sum(r['request']['command']['gait_amplitude'] == maximum for r in entries))
        # The historical generic field counts amplitude == 1, not the new cap.
        self.assertEqual(0, self.record['walking_control_diagnosis']['full_amplitude_sample_count'])
        self.assertEqual({0}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual((859, 1258), (self.rows[0]['global_semantic_step'], self.rows[-1]['global_semantic_step']))

    def test_every_counted_cycle_and_terminal_negative_preserved(self):
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.18202034222863173, evaluation['forward_advance_m'])
        self.assertEqual(.0009707247369661332, evaluation['absolute_lateral_drift_m'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        cycles, open_gaps = [], {}
        for limb, phase_index in {'rear_left': 0, 'front_left': 1, 'rear_right': 2, 'front_right': 3}.items():
            bearing, release = True, None
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current:
                    release = row
                elif not bearing and current and release is not None:
                    if row['global_semantic_step']-release['global_semantic_step'] >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        advance = sum((after[i]-before[i])*axis[i] for i in range(3))
                        phase = (release['walking_session_local_step']-1+360-phase_index*90) % 360
                        cycles.append((limb, release['walking_session_local_step'], row['walking_session_local_step'], advance, phase))
                    release = None
                bearing = current
            selected = [c for c in cycles if c[0] == limb]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][limb], len(selected))
            self.assertAlmostEqual(min(c[3] for c in selected), evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb], places=14)
            open_gaps[limb] = None if release is None else (release['walking_session_local_step'], 401-release['walking_session_local_step'])
        self.assertEqual(13, len(cycles))
        self.assertEqual(('rear_left', 44, 81, .06821726822965099, 43), cycles[0])
        failed = [c for c in cycles if c[3] < evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual([('rear_left', 93, 111), ('rear_left', 286, 293), ('rear_left', 328, 343), ('rear_right', 98, 103)], [c[:3] for c in failed])
        self.assertTrue(all(c[4] >= 72 for c in failed))
        self.assertEqual({'rear_left': (378, 23), 'front_left': None, 'rear_right': None, 'front_right': None}, open_gaps)
        self.assertEqual({'front_left': True, 'front_right': True, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])
        self.assertTrue(evaluation['walking_gate_receipts']['every_limb_two_contact_cycles'])
        # Three short front-left flights happen within its FIRST scheduled
        # swing. More counted cycles do not prove two complete gait cycles.
        self.assertEqual([(111, 123), (127, 146), (156, 163)], [c[1:3] for c in cycles if c[0] == 'front_left' and c[1] < 163])

    def test_promotion_refuses_and_old_evidence_stays_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in ('sdk/development/recovery_attempts/dd42319c12564b7ea402626dbaf8f845.json',
                         'sdk/development/recovery_attempts/8f778946bed1448d80196dc57b446dda.json',
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
