"""Cold V16 negative: preserve the original attempt and explain interrupted dwell."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '16d22c82f50247f3be4fd349e76407a7'


class V16Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.requests = {s: closure.entry.packet.parse_json(p['collection_transport']['request']['utf8_text'])
                        for s, p in cls.packets.items()}
        cls.stance = [s for s, p in cls.packets.items() if p['step_receipt']['prior_phase'] == 'stance_dwell']
        source = cls.record['source_snapshot']['head']
        rule = closure.entry.packet.parse_json(closure.prior.committed(closure.prior.RULE, source).decode())
        cls.thresholds = {t['threshold_id']: t['value'] for t in rule['threshold_profile']['thresholds']}

    def test_original_publication_replay_retention_and_schedule(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual('closed_consumed_valid_development_behavior_negative', self.observed['status'])
        self.assertEqual((77, 1, 868), tuple(self.observed[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((47, 908318723), tuple(self.observed['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertIn('sdk/development/recovery_schedules/v16-flexed-stance-v1.json', [s['path'] for s in self.observed['rule_sources']])
        self.assertFalse(self.observed['diagnostic_coverage_complete'])
        self.assertFalse(self.observed['complete_route_proven'])
        self.assertEqual(1248.113, self.observed['elapsed_seconds']['whole_invocation'])

    def test_good_endpoint_does_not_replace_consecutive_standing(self):
        phase = self.observed['metrics']['phase_summary'][-1]
        self.assertEqual([629, 868, 240, 135, 232, 59],
                         [phase[k] for k in ('first_step', 'last_step', 'sample_count', 'support_samples', 'raised_samples', 'stable_samples')])
        dwell = maximum = 0
        for step in self.stance:
            p = self.packets[step]
            dwell = dwell + 1 if p['step_receipt']['classification']['stable_stance_gate'] else 0
            self.assertEqual(dwell, p['step_receipt']['memory']['stance_dwell_steps_observed'])
            maximum = max(maximum, dwell)
        self.assertEqual((13, 7, 60, 240), (maximum, dwell, self.thresholds['stance_dwell_steps'],
                                          self.thresholds['per_phase_timeout_steps']['stance_dwell']))
        self.assertEqual('phase_timeout:stance_dwell', self.observed['metrics']['terminal_reason'])
        self.assertEqual(0, self.observed['metrics']['walking_resume_step_count'])
        terminal = self.observed['metrics']['terminal_sample']
        self.assertTrue(terminal['stable_stance'])
        self.assertEqual(4, terminal['feet_meeting_existing_support_requirement'])
        self.assertEqual('failed', self.report['retained_arm']['orchestrator_state']['phase'])

    def test_actual_commands_and_complete_interruption_population(self):
        source = self.record['source_snapshot']['head']
        contract = closure.entry.packet.parse_json(closure.prior.committed(
            'sdk/core/contracts/recovery_candidate_stance_profiles_v2.json', source).decode())
        profile = contract['profiles'][0]
        fraction = self.requests[self.stance[0]]['descriptor']['upper_length_fraction']
        knee = profile['target_knee_angle_rad']
        hip = -math.atan2((1 - fraction) * math.sin(knee), fraction + (1 - fraction) * math.cos(knee))
        goals = [hip, knee] * 4
        count = 0
        maximum_error = 0.0
        for step in self.stance:
            applied = self.packets[step]['application']
            self.assertEqual(step - 1, applied['source_control_semantic_step'])
            self.assertEqual(profile['controller_id'], applied['stance_controller_id'])
            previous = self.requests[step - 1]['observation']['state']['ordered_joint_observations']
            for goal, intent, joint in zip(goals, applied['ordered_intents'], previous):
                self.assertEqual(intent['joint_id'], joint['joint_id'])
                expected = max(-.75, min(.75, (goal - joint['position_rad']) / profile['response_time_s']))
                error = abs(intent['canonical_target_velocity_rad_s'] - expected)
                maximum_error = max(maximum_error, error)
                self.assertLess(error, 1e-10)  # Guarded decimal transport, not a physical tolerance.
                self.assertLessEqual(abs(intent['canonical_target_velocity_rad_s']), .75)
                count += 1
        self.assertEqual(1920, count)
        rows = []
        for first in (629, 689, 749, 809):
            group = [self.packets[s]['step_receipt']['classification'] for s in self.stance if first <= s < first + 60]
            rows.append(dict(first_step=first, last_step=first + 59, sample_count=len(group),
                support_samples=sum(p['distal_support_gate'] for p in group),
                stable_samples=sum(p['stable_stance_gate'] for p in group),
                linear_speed_failures=sum(p['terminal_linear_speed_m_s'] > self.thresholds['maximum_terminal_linear_speed_m_s'] for p in group),
                angular_speed_failures=sum(p['terminal_angular_speed_rad_s'] > self.thresholds['maximum_terminal_angular_speed_rad_s'] for p in group)))
        self.assertEqual([[5, 0, 60, 56], [44, 15, 45, 11], [37, 18, 30, 1], [49, 26, 23, 1]],
            [[r[k] for k in ('support_samples', 'stable_samples', 'linear_speed_failures', 'angular_speed_failures')] for r in rows])
        failures = {k: sum(not self.packets[s]['step_receipt']['classification'][k] for s in self.stance)
                    for k in ('distal_support_gate', 'raised_body_gate', 'safety_gate', 'exclusive_stance_handoff_gate', 'no_cheat_gate')}
        self.assertEqual([105, 8, 0, 0, 0], list(failures.values()))
        print('V16_RETAINED_STANCE_DIAGNOSTIC', json.dumps(dict(source_report=self.record['kicked_report'],
            ordered_half_second_windows=rows, stance_gate_failures=failures,
            checked_commands=count, maximum_command_error_rad_s=maximum_error,
            next_question='Which measured body-velocity components and contact/load changes interrupt standing, and what bounded controller change addresses them?',
            causal_attribution_proven=False, world_build_count=0, solver_step_count=0), separators=(',', ':')))

    def test_forged_claims_refuse_and_predecessors_remain_exact(self):
        for key, value in [('successful_recovery_proven', True), ('release_authority', True), ('world_count', 2),
                           ('solver_step_count', 867), ('repeat_consumed_attempt_permitted', True), ('status', 'passed')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        for relative in ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json',
                         'sdk/development/recovery_attempts/e890db0576d94a2e9380186b56ac732b.json',
                         'sdk/core/contracts/recovery_candidate_stance_profiles_v1.json',
                         'sdk/development_recovery_candidate_schedules_v1.json'):
            self.assertEqual(closure.prior.committed(relative, self.record['source_snapshot']['head']), (ROOT / relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
