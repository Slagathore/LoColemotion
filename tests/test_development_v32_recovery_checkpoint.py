"""Cold V32 result: actual swing-end holds, no timeout, two walking negatives."""
from pathlib import Path
import unittest

import test_development_v27_recovery_checkpoint as v27

closure = v27.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '987a8848999d457a820c078eb9273dbb'
SOURCE = '10e6310b678d0aadaeb1bb64b1aae5d113c4f332'
POLICY = 'sporespore_balanced_wave_recovery_swing_end_recontact_v1'


class V32Checkpoint(unittest.TestCase):
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
        self.assertEqual((108, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((61, 1052203673), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:354866e384321894d0f4a553e701475fdda799d5ddfcda16158e4d6938822585', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:f85572e993169c913ecd979bc27fc46d377bc835b5db143ec1becb82f41d6830', self.record['kicked_report']['raw_sha256'])
        self.assertEqual(40, len(self.record['rule_sources']))
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertNotIn('adapter_mode_transition_count', replay['walking_control_replay'])
        self.assertNotIn('memory_transition_profile_id', replay['walking_control_replay'])
        self.assertEqual(POLICY, replay['walking_policy_validation']['policy_id'])
        self.assertEqual(1, replay['walking_policy_validation']['validated_resume_sessions'])
        self.assertEqual('swing_end_recontact_front_left_first_resume_v1', replay['walking_start_validation']['profile_id'])
        for key in ('world_build_count', 'native_physics_read_count', 'solver_step_count'):
            self.assertEqual(0, replay[key])

    def test_own_standing_commands_and_explicit_resume_only_policy(self):
        # Verify V32's own 1,864 retained stance commands and measured completion;
        # do not substitute old physical observations for this run's evidence.
        v27.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual((859, 1258, 400), (self.rows[0]['global_semantic_step'], self.rows[-1]['global_semantic_step'], len(self.rows)))
        self.assertEqual({90}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual(POLICY, self.resume['start_receipt']['selected_policy_id'])
        self.assertEqual(POLICY, self.resume['start_receipt']['development_walking_policy_id'])
        prefix = next(s for s in self.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_prefix')
        self.assertEqual({240}, set(prefix['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual('sporespore_balanced_wave_bw5r_b_v1', prefix['start_receipt']['selected_policy_id'])
        maximum = 1.1 / (.82*1.75+.4)
        self.assertEqual(list(range(1, 401)), list(self.entries))
        knees = []
        for local, row in self.entries.items():
            t = min((local-1)/72, 1)
            self.assertAlmostEqual(maximum*t*t*(3-2*t), row['request']['command']['gait_amplitude'], places=14)
            self.assertEqual('contact_gated', row['request']['command']['phase_progression_mode'])
            if local > 1:
                self.assertEqual(self.entries[local-1]['native_output']['next_memory'], row['request']['memory'])
            knees.extend(c for c in row['native_output']['actuation']['ordered_commands'] if c['actuator_id'].endswith('_knee_motor'))
        self.assertEqual(1600, len(knees))
        self.assertTrue(all(not c['position_saturated'] and c['requested_target_position_rad'] <= 1.1 for c in knees))
        self.assertEqual(328, sum(r['request']['command']['gait_amplitude'] == maximum for r in self.entries.values()))

    def test_measured_swing_end_holds_and_all_original_walking_negatives(self):
        indices = {'rear_left': 0, 'front_left': 1, 'rear_right': 2, 'front_right': 3}
        holds = {limb: [] for limb in indices}
        for local, row in self.entries.items():
            before = {m['limb_id']: m for m in row['request']['memory']['ordered_limb_memory']}
            for limb in row['native_output']['next_memory']['ordered_limb_memory']:
                name = limb['limb_id']
                self.assertEqual(0, limb['gate_timeout_count'])
                if limb['recontact_hold_step_count'] > before[name]['recontact_hold_step_count']:
                    self.assertEqual(72, (before[name]['gait_step'] + 360 - indices[name]*90) % 360)
                    holds[name].append(local)
        self.assertEqual({'rear_left': [], 'front_left': list(range(76, 147)), 'rear_right': [228, 229], 'front_right': list(range(318, 374))}, holds)
        final = self.entries[400]['native_output']['next_memory']['ordered_limb_memory']
        self.assertEqual([380, 380, 380, 369], [m['gait_step'] for m in final])
        self.assertTrue(all(m['gait_step']-90 < 360 for m in final))
        self.assertEqual(0, self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.054691217740539644, evaluation['forward_advance_m'])
        self.assertEqual(.01129419696802314, evaluation['absolute_lateral_drift_m'])
        self.assertEqual(.12478447678633481, evaluation['maximum_tilt_rad'])
        self.assertEqual(.19364722231554107, evaluation['yaw_drift_rad'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        cycles, gaps = [], {}
        for name in indices:
            previous, start = True, None
            for row in self.rows:
                contact = row['contact_by_limb'][name]
                if previous and not contact:
                    start = row
                elif not previous and contact and start is not None:
                    first, last = start['walking_session_local_step'], row['walking_session_local_step']
                    if last-first >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        advance = sum((row['foot_position_world_m_by_limb'][name][i]-start['foot_position_world_m_by_limb'][name][i])*axis[i] for i in range(3))
                        cycles.append((name, first, last, advance))
                    start = None
                previous = contact
            selected = [c for c in cycles if c[0] == name]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][name], len(selected))
            self.assertAlmostEqual(min(c[3] for c in selected), evaluation['minimum_cycle_forward_relocation_by_limb_m'][name], places=14)
            gaps[name] = None if start is None else (start['walking_session_local_step'], 401-start['walking_session_local_step'])
        self.assertEqual([('rear_left', 255, 268), ('rear_left', 284, 339),
            ('front_left', 28, 34), ('front_left', 41, 144), ('front_left', 162, 253), ('front_left', 278, 284),
            ('rear_right', 34, 45), ('rear_right', 53, 93), ('rear_right', 108, 226), ('rear_right', 249, 267),
            ('front_right', 234, 241), ('front_right', 269, 302), ('front_right', 318, 371)], [c[:3] for c in cycles])
        self.assertEqual(7, sum(c[3] < evaluation['fixed_thresholds']['minimum_foot_relocation_m'] for c in cycles))
        self.assertEqual({'rear_left': (352, 49), 'front_left': None, 'rear_right': None, 'front_right': (383, 18)}, gaps)
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])

    def test_promotion_refuses_and_historical_records_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in ('sdk/development/recovery_attempts/72f7accb15c44d68a7ba817a61b3ac08.json',
                         'sdk/development/recovery_attempts/dd42319c12564b7ea402626dbaf8f845.json',
                         'sdk/development/recovery_swing_end_recontact_component_v1.json',
                         'sdk/development/recovery_swing_end_walking_adapter_integration_v1.json',
                         'sdk/development/recovery_swing_end_route_integration_v1.json',
                         'sdk/development/recovery_front_left_first_walking_entry_contract_v1.json',
                         'sdk/core/src/runtime.rs', 'sdk/core/src/recovery_runtime.rs',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
