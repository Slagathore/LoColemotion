"""Cold V27: executed reference ramp, stable neutral handoff, walking negatives."""
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '8f778946bed1448d80196dc57b446dda'
SOURCE = '45fb08a32f304bb68376647717792238eaf615fd'


class V27Checkpoint(unittest.TestCase):
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
        self.assertEqual((61, 1052968542), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:b4a587ad54c8a41ef9f70234dda7e3cc107e7594048bec88ea8e5af4e1e87c3f', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:0a5936d2745d1c92ce891edc5a0bcb24e63f289dd15e98ddb1483882d0855be1', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertTrue(self.record['diagnostic_coverage_complete'])  # Not official route or behavior acceptance.
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count',
            'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(1, replay['walking_control_replay']['adapter_mode_transition_count'])
        self.assertEqual(1, replay['walking_start_validation']['validated_resume_sessions'])

    def test_actual_reference_ramp_and_unchanged_standing_completion(self):
        observations = {s: closure.entry.packet.parse_json(p['collection_transport']['request']['utf8_text'])['observation']
                        for s, p in self.packets.items()}
        stance = {s: p for s, p in self.packets.items() if p['step_receipt']['prior_phase'] == 'stance_dwell'}
        self.assertEqual((627, 858, 232), (min(stance), max(stance), len(stance)))
        consecutive = best = 0
        for p in stance.values():
            consecutive = consecutive + 1 if p['step_receipt']['classification']['stable_stance_gate'] else 0
            self.assertEqual(consecutive, p['step_receipt']['memory']['stance_dwell_steps_observed'])
            best = max(best, consecutive)
        self.assertEqual((60, 60), (best, consecutive))
        self.assertEqual(73, sum(p['step_receipt']['classification']['stable_stance_gate'] for p in stance.values()))
        self.assertTrue(all(stance[s]['step_receipt']['classification']['stable_stance_gate'] for s in range(799, 859)))
        self.assertFalse(stance[798]['step_receipt']['classification']['stable_stance_gate'])
        rules = closure.entry.packet.parse_json(closure.prior.committed(closure.prior.RULE, SOURCE).decode())
        thresholds = {r['threshold_id']: r['value'] for r in rules['threshold_profile']['thresholds']}
        self.assertEqual((60, 240), (thresholds['stance_dwell_steps'], thresholds['per_phase_timeout_steps']['stance_dwell']))
        upper = self.report['configuration']['base_descriptor']['upper_length_fraction']
        knee = -0.25
        hip = -math.atan2((1 - upper) * math.sin(knee), upper + (1 - upper) * math.cos(knee))
        origin = [hip, knee] * 4
        checked = 0
        for step in range(626, 859):
            application = self.packets[step]['application']
            self.assertEqual(step - 1, application['source_control_semantic_step'])
            self.assertEqual('sporespore_exact_s169_stance_handoff_controller_v7', application['stance_controller_id'])
            t = min((step - 626) / 60, 1)
            blend = t * t * (3 - 2 * t)
            goals = [q * (1 - blend) for q in origin]
            if step >= 686:
                self.assertEqual([0.0] * 8, goals)
            previous = observations[step - 1]['state']['ordered_joint_observations']
            for goal, intent, joint in zip(goals, application['ordered_intents'], previous):
                self.assertEqual(intent['joint_id'], joint['joint_id'])
                expected = max(-.75, min(.75, (goal - joint['position_rad']) / .1 - .5 * joint['velocity_rad_s']))
                # Decimal transport projection only; no behavioral tolerance is changed.
                self.assertLess(abs(intent['canonical_target_velocity_rad_s'] - expected), 1e-10)
                self.assertLessEqual(abs(intent['canonical_target_velocity_rad_s']), .75)
                checked += 1
        self.assertEqual(1864, checked)
        # A neutral reference is not an already-neutral measured body.
        self.assertGreater(max(abs(j['position_rad']) for j in observations[686]['state']['ordered_joint_observations']), .6)
        self.assertEqual(0.0026744266506284475, max(abs(j['position_rad']) for j in observations[858]['state']['ordered_joint_observations']))
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])
        self.assertFalse(self.arm['orchestrator_state']['force_aware_recovery'])

    def test_start_and_all_cycles_preserve_three_walking_negatives(self):
        start = self.resume['start_receipt']
        prefix = next(s for s in self.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_prefix')
        self.assertEqual({240}, set(prefix['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual({0}, set(start['initial_gait_steps'].values()))
        self.assertEqual(40200, start['gait_phase_seed'])
        self.assertEqual((858, 859, 1258, 400), (start['global_start_step'], self.rows[0]['global_semantic_step'], self.rows[-1]['global_semantic_step'], len(self.rows)))
        self.assertEqual(0.0026744266506284475, self.record['walking_control_diagnosis']['maximum_first_command_target_jump_rad'])
        self.assertEqual(40, self.record['walking_control_diagnosis']['full_amplitude_sample_count'])
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(0.13511383533674404, evaluation['forward_advance_m'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        initial = self.arm['trace_rows'][start['global_start_step'] - 1]['contact_by_limb']
        self.assertTrue(all(initial.values()))
        axis = start['task_frame_forward_axis_world_host_real']
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
                        # Original evaluator uses distal body origins, not sole centers.
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        displacement = sum((after[i] - before[i]) * axis[i] for i in range(3))
                        cycles.append(dict(limb=limb, release=release['walking_session_local_step'],
                            touchdown=row['walking_session_local_step'], forward_m=displacement))
                    release = None
                bearing = current
            selected = [c for c in cycles if c['limb'] == limb]
            self.assertEqual(evaluation['contact_cycle_count_by_limb'][limb], len(selected))
            self.assertLess(abs(min(c['forward_m'] for c in selected) - evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb]), 1e-15)
            open_flights[limb] = None if release is None else (release['walking_session_local_step'],
                self.rows[-1]['global_semantic_step'] - release['global_semantic_step'] + 1)
        self.assertEqual(9, len(cycles))
        failed = [c for c in cycles if c['forward_m'] < evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual(6, len(failed))
        self.assertTrue(all(c['touchdown'] <= 360 for c in failed))
        self.assertEqual({'front_left': None, 'front_right': (374, 27), 'rear_left': (308, 93), 'rear_right': None}, open_flights)
        self.assertEqual({'front_left': True, 'front_right': False, 'rear_left': False, 'rear_right': True}, self.rows[-1]['contact_by_limb'])

    def test_promotion_refuses_and_earlier_results_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('complete_route_proven', True),
                           ('physical_acceptance_authority', True), ('release_authority', True),
                           ('repeat_consumed_attempt_permitted', True), ('status', 'passed'), ('solver_step_count', 1259)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in (
            'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json',
            'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json',
            'sdk/development/recovery_attempts/d8f05d136e4849248b7246e3e546ecf2.json',
            'sdk/development/recovery_attempts/4ed1bcc619b64a4284505e44e122ee82.json',
            'sdk/core/src/runtime.rs',
            'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, SOURCE), (ROOT / relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
