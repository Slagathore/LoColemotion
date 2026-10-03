"""Cold original single-child closure, exact negatives, unchanged old defaults."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '46cc3bddeed5433d8c25f6f3ae16e11c'


class CandidateCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']))
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))

    def test_original_single_child_replay_and_complete_retention(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(73, self.observed['safety_test_count'])
        self.assertEqual(1, self.observed['world_count'])
        self.assertEqual(626, self.observed['solver_step_count'])
        self.assertEqual('single_kick_controller_diagnostic_v1', self.observed['execution_mode'])
        self.assertEqual([], self.observed['metrics']['four_foot_support_global_steps'])
        self.assertEqual(0, self.observed['metrics']['walking_resume_step_count'])
        self.assertEqual('phase_timeout:establish_distal_support', self.observed['metrics']['terminal_reason'])
        self.assertEqual(45, self.observed['retained_population']['file_count'])
        self.assertEqual(524053871, self.observed['retained_population']['byte_length'])

    def test_changed_claims_counts_and_types_are_refused(self):
        for key, value in [('successful_recovery_proven', True), ('comparative_authority', True),
                           ('baseline_reused', True), ('release_authority', True),
                           ('repeat_consumed_attempt_permitted', True), ('world_count', True),
                           ('solver_step_count', 627), ('status', 'passed'), ('extra_claim', True)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)

    def test_profile_identity_and_legacy_default_are_closed(self):
        with self.assertRaisesRegex(ValueError, 'SUMMARY_CONTROLLER'):
            closure.prior.summarize(self.report)
        changed = dict(self.report, candidate_profile=dict(self.report['candidate_profile'], raw_sha256='sha256:' + '0' * 64))
        with self.assertRaisesRegex(ValueError, 'SUMMARY_PROFILE_BINDING'):
            closure.prior.summarize(changed, source_commit=self.record['source_snapshot']['head'],
                profile_path=self.record['candidate_profile']['resource'].removeprefix('res://'))

    def test_support_recomputed_from_native_load_not_position(self):
        changed = dict(self.report, passive_entry=dict(self.report['passive_entry']))
        packets = list(self.report['passive_entry']['canonical_packets'])
        packets[27] = dict(packets[27], step_receipt=copy.deepcopy(packets[27]['step_receipt']))
        packets[27]['step_receipt']['classification']['distal_support_gate'] = True
        changed['passive_entry']['canonical_packets'] = packets
        with self.assertRaisesRegex(ValueError, 'SUPPORT_RECOMPUTATION'):
            closure.support_geometry(changed, self.observed['metrics'])

    def test_full_contact_counts_and_first_native_requests(self):
        geometry = self.observed['support_geometry']
        counts = {f['contact_site_id']: f['qualifying_sample_count'] for f in geometry['per_foot_support']}
        self.assertEqual(dict(front_left_foot=54, front_right_foot=53, rear_left_foot=0, rear_right_foot=8), counts)
        first = next(s for s in geometry['samples'] if s['global_step'] == 387)
        self.assertEqual(8, len(first['requested_motor_velocities_rad_s']))
        self.assertLess(first['requested_motor_velocities_rad_s'][1], 2.4)
        self.assertAlmostEqual(4.0, first['requested_motor_velocities_rad_s'][5], places=10)
        entry = next(s for s in geometry['samples'] if s['global_step'] == 386)
        self.assertEqual([], entry['requested_motor_velocities_rad_s'])
        self.assertGreater(entry['foot_positions_world_m']['rear_left'][1], 0.09)
        self.assertEqual(452, self.observed['metrics']['first_torso_up_vector_below_horizontal_global_step'])


if __name__ == '__main__':
    unittest.main()
