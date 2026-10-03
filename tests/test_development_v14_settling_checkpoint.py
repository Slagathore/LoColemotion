"""Cold audit of publication failure and separately replayed captured trajectory."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_stdout_diagnostic as diagnostic


class V14SettlingCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = diagnostic.entry.read(ROOT / 'sdk/development/recovery_attempts/f3761195cea64b7c9b58a34f04651173.json')
        cls.original = Path(cls.record['retained_populations'][0]['root'])
        cls.derived = Path(cls.record['retained_populations'][1]['root'])
        cls.supervisor, cls.declaration, cls.stdout, cls.token, cls.report = diagnostic.extract(cls.original)
        cls.receipt = diagnostic.entry.read(cls.derived / 'diagnostic.json')

    def test_all_original_and_separate_derived_bytes_unchanged(self):
        for population in self.record['retained_populations']:
            root = Path(population['root'])
            self.assertEqual(population['file_count'], len(population['files']))
            self.assertEqual(population['byte_length'], sum(f['byte_length'] for f in population['files']))
            self.assertEqual({f['path'] for f in population['files']}, {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()})
            for item in population['files']:
                path = root / item['path']
                self.assertEqual(item['byte_length'], path.stat().st_size)
                self.assertEqual(item['raw_sha256'], 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertEqual(self.token, (self.derived / 'worker_report.json').read_bytes())
        self.assertEqual(self.record['source_snapshot'], self.supervisor['source_snapshot'])
        self.assertEqual(self.record['failure_code'], self.supervisor['failure_code'])
        self.assertEqual('c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         hashlib.sha256((ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()).hexdigest())

    def test_independent_replay_is_separate_from_failed_original_publication(self):
        self.assertFalse(self.supervisor['ok'])
        self.assertEqual([], self.supervisor['children'])
        self.assertIsNone(self.supervisor['independent_audit'])
        self.assertEqual(77, sum(s['test_count'] for s in self.supervisor['safety_stages']))
        self.assertTrue(all(s['passed'] for s in self.supervisor['safety_stages']))
        replay = diagnostic.entry.consume_replay(self.derived / 'worker_report.json')
        self.assertTrue(diagnostic.entry.packet.same(replay, self.receipt['replay']))
        self.assertEqual(868, replay['transition_count'])
        self.assertEqual(0, replay['world_build_count'])
        self.assertEqual(0, replay['native_physics_read_count'])
        self.assertEqual(0, replay['solver_step_count'])
        for key in ('original_attempt_reclassified', 'original_termination_protocol_proven',
                    'original_complete_route_proven', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(False, self.receipt[key])
            self.assertIs(False, self.record[key])
        self.assertIs(True, self.receipt['source_unchanged_during_diagnostic'])
        self.assertIs(True, self.receipt['original_stdout_unchanged'])

    def test_full_unchanged_stance_budget_times_out_without_walking(self):
        metrics = diagnostic.summary.summarize(self.report,
            source_commit=self.supervisor['source_snapshot']['head'],
            profile_path=self.declaration['candidate_profile']['resource'].removeprefix('res://'))
        self.assertTrue(diagnostic.entry.packet.same(metrics, self.receipt['descriptive_metrics']))
        stance = next(p for p in metrics['phase_summary'] if p['phase'] == 'stance_dwell')
        self.assertEqual((629, 868, 240, 57, 16), tuple(stance[k] for k in ('first_step', 'last_step', 'sample_count', 'support_samples', 'stable_samples')))
        self.assertEqual('phase_timeout:stance_dwell', metrics['terminal_reason'])
        self.assertEqual(0, metrics['walking_resume_step_count'])
        packets = self.report['passive_entry']['canonical_packets']
        stable = [p['global_semantic_step'] for p in packets if p['step_receipt']['classification']['stable_stance_gate']]
        self.assertEqual([749,750,770,771,772,773,774,787,788,789,790,810,813,814,815,830], stable)
        self.assertEqual(stable, self.receipt['stable_global_steps'])
        maximum = max(p['step_receipt']['memory']['stance_dwell_steps_observed'] for p in packets)
        self.assertEqual(5, maximum)
        self.assertEqual(maximum, self.receipt['maximum_consecutive_stance_dwell_count'])
        self.assertEqual(self.record['descriptive_result'], dict(replay_transition_count=868,
            stance_phase_sample_count=240, stable_sample_count=len(stable), maximum_consecutive_stable_samples=maximum,
            required_consecutive_stable_samples=60, walking_resume_step_count=0, terminal_reason=metrics['terminal_reason']))
        self.assertEqual(240, self.report['retained_arm']['recovery_memory']['phase_steps_observed'])
        self.assertEqual('failed', self.report['retained_arm']['recovery_memory']['phase'])

    def test_retained_stance_motion_and_loss_diagnostic(self):
        packets = self.report['passive_entry']['canonical_packets']
        by_step = {p['global_semantic_step']: p for p in packets}
        observations = {step: diagnostic.entry.packet.parse_json(p['collection_transport']['request']['utf8_text'])['observation']
                        for step, p in by_step.items()}
        stance = [p for p in packets if p['step_receipt']['prior_phase'] == 'stance_dwell']
        self.assertEqual(240, len(stance))
        failures = {key: sum(not p['step_receipt']['classification'][key] for p in stance)
                    for key in ('distal_support_gate', 'raised_body_gate', 'safety_gate', 'exclusive_stance_handoff_gate', 'no_cheat_gate')}
        self.assertEqual([183, 23, 0, 0, 0], list(failures.values()))
        breaks = []
        checked_commands = 0
        for p in stance:
            step = p['global_semantic_step']
            source = p['application']['source_control_semantic_step']
            self.assertEqual(step - 1, source)
            previous = observations[source]['state']['ordered_joint_observations']
            for intent, joint in zip(p['application']['ordered_intents'], previous):
                self.assertEqual(intent['joint_id'], joint['joint_id'])
                expected = max(-0.75, min(0.75, -joint['position_rad'] / (1 / 120)))
                self.assertAlmostEqual(expected, intent['canonical_target_velocity_rad_s'], delta=1e-10)
                checked_commands += 1
            classification = p['step_receipt']['classification']
            if by_step[source]['step_receipt']['classification']['stable_stance_gate'] and not classification['stable_stance_gate']:
                breaks.append(dict(step=step, foot_support=classification['distal_support_gate'],
                    linear_speed_m_s=classification['terminal_linear_speed_m_s'],
                    angular_speed_rad_s=classification['terminal_angular_speed_rad_s']))
        self.assertEqual(1920, checked_commands)
        self.assertEqual([751,775,791,811,816,831], [r['step'] for r in breaks])
        late = [p for p in stance if p['global_semantic_step'] >= 800]
        joints = [j for p in late for j in observations[p['global_semantic_step']]['state']['ordered_joint_observations']]
        maximum_position = max(abs(j['position_rad']) for j in joints)
        maximum_velocity = max(abs(j['velocity_rad_s']) for j in joints)
        self.assertEqual(69, len(late))
        self.assertEqual(0.025117002427577972, maximum_position)
        self.assertEqual(1.875051498413086, maximum_velocity)
        print('V14_STANCE_MOTION_DIAGNOSTIC', json.dumps(dict(
            source_report_sha256=diagnostic.entry.digest(self.token),
            authority_mode='descriptive_post_exposure_development', failures=failures,
            stable_streak_breaks=breaks, checked_previous_observation_commands=checked_commands,
            late_window_steps=[800,868], maximum_absolute_joint_position_rad=maximum_position,
            maximum_absolute_joint_velocity_rad_s=maximum_velocity,
            causal_explanation_proven=False, physical_acceptance_authority=False, release_authority=False)), flush=True)


if __name__ == '__main__':
    unittest.main()
