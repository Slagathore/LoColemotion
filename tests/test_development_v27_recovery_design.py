"""V27's retained-data basis and unchanged bounds; no runtime or physics launch."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_candidate_checkpoint as closure


class V27Design(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = candidate.read(ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v6.json')['profiles'][0]
        cls.basis = cls.profile['diagnostic_basis']
        cls.record = candidate.read(ROOT / cls.basis['v26_closure'])
        cls.path = Path(cls.record['kicked_report']['path'])
        cls.report = candidate.read(cls.path)

    def test_exact_original_record_and_report_identity(self):
        self.assertEqual(self.basis['v26_closure_sha256'], candidate.sha(ROOT / self.basis['v26_closure']))
        self.assertEqual(self.basis['v26_report_sha256'], candidate.sha(self.path))
        self.assertEqual(self.record['kicked_report']['raw_sha256'], self.basis['v26_report_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        self.assertFalse(self.record['physical_acceptance_authority'])

    def test_initial_target_mismatch_is_observed_not_a_new_angle_fit(self):
        first = self.report['development_walking_entry']['rows'][0]
        self.assertEqual((1, 813, 814), tuple(first[k] for k in ('session_local_step', 'measured_global_step', 'commanded_global_step')))
        positions = {j['joint_id']: j['position_rad'] for j in first['request']['state']['ordered_joint_observations']}
        commands = first['native_output']['actuation']['ordered_commands']
        self.assertEqual(8, len(commands))
        self.assertTrue(all(c['requested_target_position_rad'] == 0 for c in commands))
        jump = max(abs(c['requested_target_position_rad'] - positions[c['actuator_id'].removesuffix('_motor')]) for c in commands)
        self.assertEqual(0.2524440884590149, jump)
        self.assertEqual(jump, self.record['walking_control_diagnosis']['maximum_first_command_target_jump_rad'])
        self.assertEqual(0, first['request']['command']['gait_amplitude'])
        self.assertGreater(max(abs(c['target_velocity_rad_s']) for c in commands), 2.0)

    def test_rear_left_gap_has_no_native_distal_contact_in_available_samples(self):
        native = {r['session_local_step']: r for r in self.report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume'}
        traces = self.report['retained_arm']['trace_rows']
        checked = 0
        # Command n+1 carries the post-solve observation after command n.
        # The final trace has no later command input; do not invent that sample.
        for local in range(298, 445):
            source = native[local + 1]['native_source']
            self.assertEqual(813 + local, source['precommand_trace']['global_semantic_step'])
            self.assertFalse(traces[813 + local - 1]['contact_by_limb']['rear_left'])
            self.assertFalse(source['precommand_trace']['contact_by_limb']['rear_left'])
            self.assertEqual([], [r for r in source['contact_source_receipt']['ordered_contact_samples'] if r['body_id'] == 'rear_left_distal'])
            checked += 1
        self.assertEqual(147, checked)
        self.assertFalse(traces[-1]['contact_by_limb']['rear_left'])
        self.assertNotIn(446, native)

    def test_ramp_origin_and_schedule_preserve_existing_limits_and_records(self):
        old = candidate.read(ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v4.json')['profiles'][0]
        neutral = candidate.read(ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v5.json')['profiles'][0]
        ramp = self.profile['reference_ramp']
        self.assertEqual(old['controller_id'], ramp['initial_stance_controller_id'])
        self.assertEqual(-0.25, old['target_knee_angle_rad'])
        self.assertEqual(60, ramp['duration_steps'])
        for key in ('response_time_s', 'measured_velocity_damping_gain'):
            self.assertEqual(neutral[key], self.profile[key])
        before = candidate.read(ROOT / 'sdk/development/recovery_schedules/v26-normal-phase-walking-start-v1.json')['schedules']['v26-normal-phase-walking-start-v1']
        after = candidate.read(ROOT / 'sdk/development/recovery_schedules/v27-ramped-neutral-stance-v1.json')['schedules']['v27-ramped-neutral-stance-v1']
        for key in ('limits', 'walking_resume_frame_id', 'walking_entry_profile_id', 'walking_contact_profile_id', 'walking_replay_profile_id', 'walking_start_profile_id'):
            self.assertEqual(before[key], after[key])
        for relative in (self.basis['v26_closure'], self.basis['v25_closure'], 'sdk/core/src/runtime.rs',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, '138581dc9df220ce498e2cd2440697f05cc43412'), (ROOT / relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
