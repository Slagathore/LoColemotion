"""Cold V15 stance negative: actual commands, loaded feet and exact retention."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = 'e890db0576d94a2e9380186b56ac732b'


class V15Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.observations = {s: closure.entry.packet.parse_json(p['collection_transport']['request']['utf8_text'])['observation']
                            for s, p in cls.packets.items()}

    def test_complete_original_publication_replay_and_frozen_schedule(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual('closed_consumed_valid_development_behavior_negative', self.observed['status'])
        self.assertEqual((77, 1, 868), tuple(self.observed[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((47, 906758132), tuple(self.observed['retained_population'][k] for k in ('file_count', 'byte_length')))
        # The whole stance budget is observed, but the controller terminates
        # before the diagnostic tail/walking path can complete. Keep distinct.
        self.assertFalse(self.observed['diagnostic_coverage_complete'])
        self.assertIn('sdk/development/recovery_schedules/v15-smooth-stance-v1.json', [s['path'] for s in self.observed['rule_sources']])
        self.assertFalse(self.observed['complete_route_proven'])

    def test_standing_timeout_is_not_walking_or_an_improvement_claim(self):
        stable = [s for s,p in self.packets.items() if p['step_receipt']['classification']['stable_stance_gate']]
        self.assertEqual([750,774,775,776,777,778,797,798,799,815,821,822,823,824,825,826,832,833,837,843,844,845], stable)
        self.assertEqual(6, max(p['step_receipt']['memory']['stance_dwell_steps_observed'] for p in self.packets.values()))
        phase = self.observed['metrics']['phase_summary'][-1]
        self.assertEqual([629,868,240,69,218,22], [phase[k] for k in ('first_step','last_step','sample_count','support_samples','raised_samples','stable_samples')])
        self.assertEqual('phase_timeout:stance_dwell', self.observed['metrics']['terminal_reason'])
        self.assertEqual(0, self.observed['metrics']['walking_resume_step_count'])
        self.assertEqual('failed', self.report['retained_arm']['orchestrator_state']['phase'])
        self.assertFalse(self.record['comparative_authority'])

    def test_measured_stance_rule_and_quiet_but_unloaded_endpoint(self):
        stance = [s for s,p in self.packets.items() if p['step_receipt']['prior_phase'] == 'stance_dwell']
        count = 0
        maximum_error = 0.0
        for s in stance:
            application = self.packets[s]['application']
            self.assertEqual(s - 1, application['source_control_semantic_step'])
            self.assertEqual('sporespore_exact_s169_stance_handoff_controller_v2', application['stance_controller_id'])
            previous = self.observations[s - 1]['state']['ordered_joint_observations']
            for intent,joint in zip(application['ordered_intents'], previous):
                self.assertEqual(intent['joint_id'], joint['joint_id'])
                expected = max(-.75, min(.75, -joint['position_rad'] / .1))
                error = abs(intent['canonical_target_velocity_rad_s'] - expected)
                maximum_error = max(maximum_error, error)
                self.assertLess(error, 1e-10) # Guarded decimal transport, not a behavioral tolerance.
                self.assertLessEqual(abs(intent['canonical_target_velocity_rad_s']), .75)
                count += 1
        self.assertEqual(1920, count)
        terminal = self.observed['metrics']['terminal_sample']
        self.assertLess(terminal['linear_speed_m_s'], .1)
        self.assertLess(terminal['angular_speed_rad_s'], .2)
        self.assertEqual(2, terminal['feet_meeting_existing_support_requirement'])
        feet = self.observations[868]['ordered_foot_bearing_observations']
        loads = {f['contact_site_id']: f['bearing_normal_impulse_ns'] for f in feet}
        self.assertEqual(dict(front_left_foot=.20020315051078796, front_right_foot=.16550733149051666,
                              rear_left_foot=.017596598714590073, rear_right_foot=0.0), loads)
        self.assertLess(loads['rear_left_foot'], self.observed['metrics']['existing_per_foot_bearing_requirement_ns'])
        failures = {k: sum(not self.packets[s]['step_receipt']['classification'][k] for s in stance)
                    for k in ('distal_support_gate','raised_body_gate','safety_gate','exclusive_stance_handoff_gate','no_cheat_gate')}
        self.assertEqual([171,22,0,0,0], list(failures.values()))
        late = [j for s in stance if s >= 800 for j in self.observations[s]['state']['ordered_joint_observations']]
        self.assertEqual(.03518382087349892, max(abs(j['position_rad']) for j in late))
        self.assertEqual(1.3473230600357056, max(abs(j['velocity_rad_s']) for j in late))
        print('V15_RETAINED_STANCE_DIAGNOSTIC', json.dumps(dict(source_report=self.record['kicked_report'],
            stance_gate_failures=failures, terminal_foot_loads_ns=loads, terminal_sample=terminal,
            checked_commands=count, maximum_command_error_rad_s=maximum_error,
            next_question='supported foot placement and weight distribution during stance',
            causal_attribution_proven=False, world_build_count=0, solver_step_count=0)))

    def test_forged_claims_refuse_and_predecessors_remain_exact(self):
        for key,value in [('successful_recovery_proven',True), ('release_authority',True), ('world_count',2),
                          ('solver_step_count',867), ('repeat_consumed_attempt_permitted',True), ('status','passed')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key:value}), self.observed)
        for relative in ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json',
                         'sdk/development/recovery_attempts/f3761195cea64b7c9b58a34f04651173.json',
                         'sdk/development_recovery_candidate_schedules_v1.json'):
            self.assertEqual(closure.prior.committed(relative, self.record['source_snapshot']['head']), (ROOT / relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
