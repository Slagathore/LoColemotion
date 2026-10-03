"""Cold V30 observation: real contact holds, strict replay, walking negatives."""
from pathlib import Path
import unittest

import test_development_v27_recovery_checkpoint as v27

closure = v27.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = 'f31bc1e0355244b1866629edd7122d81'
SOURCE = 'e61c0a1134bb855ff897b9fbf5a2174bea823fd9'


class V30Checkpoint(unittest.TestCase):
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
        self.assertEqual((57, 1052718834), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:8d714aae6feee01b14ce8063269e4077c564c9a01204a5022207c69d665a6f16', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:284285483ed8242d1c7b13a27118862465f71fa8ddba6c2067d2374ffcdc9359', self.record['kicked_report']['raw_sha256'])
        self.assertEqual(29, len(self.record['rule_sources']))
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertNotIn('memory_transition_profile_id', replay['walking_control_replay'])
        self.assertNotIn('adapter_mode_transition_count', replay['walking_control_replay'])
        self.assertEqual(1, replay['walking_start_validation']['validated_resume_sessions'])
        self.assertEqual('normal_zero_phase_contact_gated_resume_v1', replay['walking_start_validation']['profile_id'])
        for key in ('world_build_count', 'native_physics_read_count', 'solver_step_count'):
            self.assertEqual(0, replay[key])

    def test_standing_bounded_commands_and_actual_gate_holds(self):
        # Reconstruct this attempt's 1,864 handoff/dwell commands and original
        # final 60 stable samples. No V27 physical result is substituted.
        v27.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual(list(range(1, 401)), list(self.entries))
        maximum = 1.1 / (.82*1.75+.4)
        knees = []
        for local, row in self.entries.items():
            t = min((local-1)/72, 1)
            self.assertAlmostEqual(maximum*t*t*(3-2*t), row['request']['command']['gait_amplitude'], places=14)
            self.assertEqual('contact_gated', row['request']['command']['phase_progression_mode'])
            if local > 1:
                self.assertEqual(self.entries[local-1]['native_output']['next_memory'], row['request']['memory'])
            knees.extend(c for c in row['native_output']['actuation']['ordered_commands'] if c['actuator_id'].endswith('_knee_motor'))
        self.assertEqual(1600, len(knees))
        self.assertEqual(0, sum(c['position_saturated'] for c in knees))
        self.assertEqual(1.0991812630882631, max(c['requested_target_position_rad'] for c in knees))
        self.assertEqual(328, sum(r['request']['command']['gait_amplitude'] == maximum for r in self.entries.values()))
        self.assertEqual(0, self.record['walking_control_diagnosis']['full_amplitude_sample_count'])
        self.assertEqual({0}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual((859, 1258), (self.rows[0]['global_semantic_step'], self.rows[-1]['global_semantic_step']))
        guard = {m['limb_id']: m for m in self.entries[56]['native_output']['next_memory']['ordered_limb_memory']}
        self.assertEqual((54, 1, 0), tuple(guard['front_right'][k] for k in ('gait_step', 'recontact_hold_step_count', 'current_gate_transition_dwell_steps')))
        final = self.entries[400]['native_output']['next_memory']['ordered_limb_memory']
        self.assertEqual([347, 336, 345, 336], [m['gait_step'] for m in final])
        self.assertEqual([48, 50, 50, 0], [m['phase_sync_hold_step_count'] for m in final])
        self.assertEqual([2, 11, 2, 61], [m['recontact_hold_step_count'] for m in final])
        self.assertEqual([2, 2, 2, 2], [m['release_hold_step_count'] for m in final])
        self.assertEqual(0, sum(m['gate_timeout_count'] for m in final))
        self.assertEqual(0, self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])

    def test_every_counted_cycle_actual_phase_and_terminal_negative(self):
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.14915311594890523, evaluation['forward_advance_m'])
        self.assertEqual(.0048042890245509895, evaluation['absolute_lateral_drift_m'])
        self.assertEqual(.05004154296158737, evaluation['maximum_tilt_rad'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        cycles, open_gaps = [], {}
        for limb, index in {'rear_left': 0, 'front_left': 1, 'rear_right': 2, 'front_right': 3}.items():
            bearing, release = True, None
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current:
                    release = row
                elif not bearing and current and release is not None:
                    if row['global_semantic_step']-release['global_semantic_step'] >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        advance = sum((after[i]-before[i])*axis[i] for i in range(3))
                        local = release['walking_session_local_step']
                        # Contact-gated phase is actual retained limb memory,
                        # never the wall-clock formula used for a clocked gait.
                        memory = next(m for m in self.entries[local]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)
                        phase = int((memory['gait_step']+360-index*90) % 360)
                        cycles.append((limb, local, row['walking_session_local_step'], advance, phase))
                    release = None
                bearing = current
            selected = [c for c in cycles if c[0] == limb]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][limb], len(selected))
            self.assertAlmostEqual(min(c[3] for c in selected), evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb], places=14)
            open_gaps[limb] = None if release is None else (release['walking_session_local_step'], 401-release['walking_session_local_step'])
        self.assertEqual(11, len(cycles))
        failed = [c for c in cycles if c[3] < evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual([('rear_left', 353, 376), ('front_left', 279, 296), ('front_left', 308, 314), ('rear_right', 168, 206), ('front_right', 127, 146), ('front_right', 352, 355)], [c[:3] for c in failed])
        self.assertEqual([300, 136, 154, 297, 155, 20], [c[4] for c in failed])
        self.assertEqual({'rear_left': (393, 8), 'front_left': None, 'rear_right': None, 'front_right': (358, 43)}, open_gaps)
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])
        # The original counter passes, but interruptions inflate cycle counts.
        # No limb completed 360 gait-clock increments in these 400 wall steps.
        self.assertTrue(evaluation['walking_gate_receipts']['every_limb_two_contact_cycles'])
        self.assertTrue(all(m['gait_step'] < 360 for m in self.entries[400]['native_output']['next_memory']['ordered_limb_memory']))

    def test_promotion_refuses_and_old_records_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in ('sdk/development/recovery_attempts/66b2e79c43d3401285f7cdba0f607990.json',
                         'sdk/development/recovery_attempts/dd42319c12564b7ea402626dbaf8f845.json',
                         'sdk/development/recovery_attempts/8f778946bed1448d80196dc57b446dda.json',
                         'sdk/development/recovery_attempts/4e43b57e644d47a78c1e80681361a24a.json',
                         'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json',
                         'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json',
                         'sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json',
                         'sdk/core/src/runtime.rs', 'sdk/core/src/recovery_runtime.rs',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
