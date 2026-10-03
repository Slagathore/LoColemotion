"""Cold V31: fixed startup exercised, real contact timeout and walking negatives."""
from pathlib import Path
import unittest

import test_development_v27_recovery_checkpoint as v27
import development_recovery_v28_contact_geometry as geometry

closure = v27.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '72f7accb15c44d68a7ba817a61b3ac08'
SOURCE = '56d5ec64c87f261785405968cc598b8e966e0d27'


class V31Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id') == cls.resume['session_id']]
        cls.entries = {r['session_local_step']: r for r in cls.report['development_walking_entry']['rows']}

    def test_complete_population_original_replay_and_frozen_sources(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        self.assertEqual((99, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((57, 1052463319), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:a46c6a78689cbd91a7b25d6e1bfe2fdf4663529b261867cfcf7cfd9a4fd87276', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:76bf505328df4147ed5002b73add3d811cd6a289f8cdd25e00bbfd77a5bf498d', self.record['kicked_report']['raw_sha256'])
        self.assertEqual(32, len(self.record['rule_sources']))
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertNotIn('adapter_mode_transition_count', replay['walking_control_replay'])
        self.assertNotIn('memory_transition_profile_id', replay['walking_control_replay'])
        self.assertEqual('front_left_first_contact_gated_resume_v1', replay['walking_start_validation']['profile_id'])
        self.assertEqual(1, replay['walking_start_validation']['validated_resume_sessions'])
        for key in ('world_build_count', 'native_physics_read_count', 'solver_step_count'):
            self.assertEqual(0, replay[key])

    def test_own_standing_commands_phase_offset_and_actual_timeout(self):
        # Reconstruct V31's own 1,864 standing commands and measured completion;
        # the shared assertion is not a substitution of V27 physical evidence.
        v27.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual((859, 1258, 400), (self.rows[0]['global_semantic_step'], self.rows[-1]['global_semantic_step'], len(self.rows)))
        self.assertEqual({90}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        prefix = next(s for s in self.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_prefix')
        self.assertEqual({240}, set(prefix['start_receipt']['initial_gait_steps'].values()))
        maximum, knees = 1.1 / (.82*1.75+.4), []
        self.assertEqual(list(range(1, 401)), list(self.entries))
        for local, row in self.entries.items():
            t = min((local-1)/72, 1)
            self.assertAlmostEqual(maximum*t*t*(3-2*t), row['request']['command']['gait_amplitude'], places=14)
            self.assertEqual('contact_gated', row['request']['command']['phase_progression_mode'])
            if local > 1:
                self.assertEqual(self.entries[local-1]['native_output']['next_memory'], row['request']['memory'])
            knees.extend(c for c in row['native_output']['actuation']['ordered_commands'] if c['actuator_id'].endswith('_knee_motor'))
        first = {c['actuator_id']: c['requested_target_position_rad'] for c in self.entries[2]['native_output']['actuation']['ordered_commands'] if c['actuator_id'].endswith('_knee_motor')}
        self.assertGreater(first.pop('front_left_knee_motor'), 0)
        self.assertEqual({0}, set(first.values()))
        self.assertEqual((1600, 0, 1.0991812630882631), (len(knees), sum(c['position_saturated'] for c in knees), max(c['requested_target_position_rad'] for c in knees)))
        self.assertEqual(328, sum(r['request']['command']['gait_amplitude'] == maximum for r in self.entries.values()))
        final = self.entries[400]['native_output']['next_memory']['ordered_limb_memory']
        self.assertEqual([378, 367, 376, 376], [m['gait_step'] for m in final])
        self.assertEqual([109, 0, 109, 111], [m['phase_sync_hold_step_count'] for m in final])
        self.assertEqual([2, 120, 2, 0], [m['recontact_hold_step_count'] for m in final])
        self.assertEqual([0, 2, 2, 2], [m['release_hold_step_count'] for m in final])
        self.assertEqual([0, 1, 0, 0], [m['gate_timeout_count'] for m in final])
        self.assertEqual({1530}, {m['evidence_gait_step_limit'] for m in final})
        # Absolute clocks above 360 do not imply one full cycle after start 90.
        self.assertTrue(all(m['gait_step']-90 < 360 for m in final))
        before = next(m for m in self.entries[268]['request']['memory']['ordered_limb_memory'] if m['limb_id'] == 'front_left')
        after = next(m for m in self.entries[268]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == 'front_left')
        self.assertEqual((234, 120, 0), tuple(before[k] for k in ('gait_step', 'current_gate_hold_steps', 'gate_timeout_count')))
        self.assertEqual((235, 0, 1), tuple(after[k] for k in ('gait_step', 'current_gate_hold_steps', 'gate_timeout_count')))
        self.assertEqual(1, self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])
        self.assertTrue(self.record['walking_control_diagnosis']['original_evaluator_timeout_free_flag'])

    def test_all_counted_cycles_raw_contact_gaps_and_original_negatives(self):
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.057889645867921, evaluation['forward_advance_m'])
        self.assertEqual(.0017548201942294561, evaluation['absolute_lateral_drift_m'])
        self.assertEqual(.21141690241135402, evaluation['maximum_tilt_rad'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        cycles, gaps, first_loss = [], {}, {}
        for limb, index in {'rear_left': 0, 'front_left': 1, 'rear_right': 2, 'front_right': 3}.items():
            bearing, release = True, None
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current:
                    release = row
                    first_loss.setdefault(limb, row['walking_session_local_step'])
                elif not bearing and current and release is not None:
                    start, end = release['walking_session_local_step'], row['walking_session_local_step']
                    if end-start >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        advance = sum((after[i]-before[i])*axis[i] for i in range(3))
                        memory = next(m for m in self.entries[start]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)
                        phase = int((memory['gait_step']+360-index*90) % 360)
                        cycles.append((limb, start, end, phase, advance))
                    release = None
                bearing = current
            selected = [c for c in cycles if c[0] == limb]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][limb], len(selected))
            self.assertAlmostEqual(min(c[4] for c in selected), evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb], places=14)
            gaps[limb] = None if release is None else (release['walking_session_local_step'], 401-release['walking_session_local_step'])
        self.assertEqual({'rear_left': 36, 'front_left': 28, 'rear_right': 34, 'front_right': 310}, first_loss)
        self.assertEqual([
            ('rear_left', 293, 301, 271), ('rear_left', 319, 356, 297),
            ('front_left', 28, 34, 27), ('front_left', 41, 292, 40),
            ('rear_right', 34, 45, 303), ('rear_right', 53, 95, 322), ('rear_right', 111, 156, 20),
            ('rear_right', 216, 219, 66), ('rear_right', 222, 225, 66), ('rear_right', 226, 229, 66),
            ('rear_right', 230, 233, 66), ('rear_right', 234, 237, 66), ('rear_right', 238, 241, 66),
            ('rear_right', 242, 245, 66), ('rear_right', 246, 260, 66), ('rear_right', 261, 273, 66),
            ('rear_right', 290, 315, 88), ('front_right', 310, 320, 18)], [c[:4] for c in cycles])
        self.assertEqual(15, sum(c[4] < evaluation['fixed_thresholds']['minimum_foot_relocation_m'] for c in cycles))
        self.assertEqual({'rear_left': (395, 6), 'front_left': None, 'rear_right': None, 'front_right': (327, 74)}, gaps)
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])
        measured, frame_error = geometry.reconstruct(self.report)
        self.assertEqual(1600, len(measured))
        self.assertLess(frame_error, 1e-6)
        for start, end in ((28, 34), (41, 292)):
            interval = geometry.interval_summary(measured, 'front_left', start, end)
            self.assertEqual(end-start, interval['sample_count'])
            self.assertEqual(0, interval['raw_contact_sample_count'])
            self.assertGreater(interval['nominal_capsule_bottom_m']['minimum'], 0)
        self.assertAlmostEqual(.06699716687963071, geometry.interval_summary(measured, 'front_left', 41, 292)['nominal_capsule_bottom_m']['maximum'], places=14)

    def test_promotion_refuses_and_historical_records_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in ('sdk/development/recovery_attempts/f31bc1e0355244b1866629edd7122d81.json',
                         'sdk/development/recovery_attempts/66b2e79c43d3401285f7cdba0f607990.json',
                         'sdk/development/recovery_attempts/dd42319c12564b7ea402626dbaf8f845.json',
                         'sdk/development/recovery_attempts/4e43b57e644d47a78c1e80681361a24a.json',
                         'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json',
                         'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json',
                         'sdk/development/recovery_front_left_first_walking_entry_contract_v1.json',
                         'sdk/conformance/development_recovery_v28_contact_geometry.py',
                         'sdk/core/src/runtime.rs', 'sdk/core/src/recovery_runtime.rs',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
