"""Cold V12 result checks. Read original receipts; never rerun a world."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '00690ff0730f43aebb53bd35b6b87c81'


class V12Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))

    def test_exact_original_population_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual('sporespore_development_recovery_candidate_checkpoint_v2', self.observed['schema_version'])
        self.assertEqual('closed_consumed_valid_development_observation', self.observed['status'])
        self.assertEqual(73, self.observed['safety_test_count'])
        self.assertEqual(1, self.observed['world_count'])
        self.assertEqual(752, self.observed['solver_step_count'])
        self.assertEqual(45, self.observed['retained_population']['file_count'])
        self.assertEqual(724792307, self.observed['retained_population']['byte_length'])
        self.assertTrue(self.observed['diagnostic_coverage_complete'])
        self.assertFalse(self.observed['complete_route_proven'])

    def test_small_real_raise_request_does_not_preserve_four_foot_support(self):
        rows = {r['global_step']: r for r in self.observed['support_geometry']['samples']}
        prior = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts/06d98bc4777a4fa78ce854582bfa9637.json')
        old_entry = next(r for r in prior['support_geometry']['samples'] if r['global_step'] == 410)
        self.assertEqual(old_entry, rows[410])
        self.assertEqual('raise_body', rows[411]['phase'])
        self.assertTrue(all(0 < speed < .005 for speed in rows[411]['requested_motor_velocities_rad_s']))
        self.assertEqual([410, 411], self.observed['metrics']['four_foot_support_global_steps'])
        self.assertEqual(412, self.observed['metrics']['first_support_loss_after_support_global_step'])
        self.assertEqual(['front_left_foot', 'front_right_foot'], rows[412]['qualifying_feet'])
        packet = next(p for p in self.report['passive_entry']['canonical_packets'] if p['global_semantic_step'] == 411)
        self.assertEqual(410, packet['application']['source_control_semantic_step'])
        for step in (410, 411, 412):
            self.assertIn('distal_body_origins_world_m', rows[step])
            self.assertNotIn('foot_positions_world_m', rows[step])

    def test_near_standing_joint_angles_are_not_a_standing_body(self):
        metrics = self.observed['metrics']
        terminal = self.observed['support_geometry']['samples'][-1]
        self.assertEqual(752, terminal['global_step'])
        # Descriptions of this observed trace, never new physical gate thresholds.
        self.assertLess(max(abs(q) for q in terminal['joint_positions_rad']), .013)
        self.assertGreater(metrics['terminal_sample']['torso_tilt_degrees'], 86)
        self.assertLess(metrics['terminal_sample']['torso_tilt_degrees'], 87)
        self.assertIsNone(metrics['first_torso_up_vector_below_horizontal_global_step'])
        self.assertEqual(0, sum(p['raised_samples'] for p in metrics['phase_summary']))
        self.assertEqual(0, metrics['stable_stance_sample_count'])
        self.assertEqual(0, metrics['walking_resume_step_count'])
        self.assertEqual('diagnostic_after_interaction_horizon', self.report['stop_reason'])
        self.assertEqual('raise_body', self.report['retained_arm']['recovery_memory']['phase'])
        self.assertIsNone(self.report['retained_arm']['recovery_memory']['terminal_failure_code'])
        self.assertFalse(self.observed['causal_attribution_proven'])

    def test_altered_population_claims_labels_and_outcomes_refuse(self):
        for key, value in [('successful_recovery_proven', True), ('comparative_authority', True),
                           ('release_authority', True), ('world_count', 2), ('solver_step_count', 751),
                           ('status', 'passed'), ('repeat_consumed_attempt_permitted', True),
                           ('schema_version', 'sporespore_development_recovery_candidate_checkpoint_v1')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)


if __name__ == '__main__':
    unittest.main()
