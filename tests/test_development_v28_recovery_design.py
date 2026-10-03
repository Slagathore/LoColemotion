"""Reproduce V28's retained-data basis without launching a runtime or world."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_candidate_checkpoint as closure


class V28Design(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = candidate.read(candidate.FIRST_SWING_ENTRY_PATH)
        cls.basis = cls.contract['diagnostic_basis']
        cls.record = candidate.read(ROOT / cls.basis['source_closure'])
        cls.path = Path(cls.record['kicked_report']['path'])
        cls.report = candidate.read(cls.path)
        cls.arm = cls.report['retained_arm']
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id') == cls.resume['session_id']]

    def test_exact_source_and_weak_first_scheduled_swing(self):
        self.assertEqual(self.basis['source_closure_sha256'], candidate.sha(ROOT / self.basis['source_closure']))
        self.assertEqual(self.basis['source_report_sha256'], candidate.sha(self.path))
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        first = self.report['development_walking_entry']['rows'][:72]
        self.assertEqual(list(range(1, 73)), [r['session_local_step'] for r in first])
        self.assertEqual(72, sum(r['contact_by_limb']['rear_left'] for r in self.rows[:72]))
        self.assertEqual(self.basis['maximum_first_swing_amplitude'], max(r['request']['command']['gait_amplitude'] for r in first))
        goals = [c['requested_target_position_rad'] for r in first
                 for c in r['native_output']['actuation']['ordered_commands'] if c['actuator_id'] == 'rear_left_knee_motor']
        self.assertEqual(self.basis['maximum_first_swing_rear_left_knee_target_rad'], max(goals))
        self.assertTrue(all(r['request']['command']['phase_progression_mode'] == 'clocked' for r in first))
        self.assertFalse(self.basis['causal_attribution_proven'])

    def test_inadequate_cycles_mostly_begin_during_commanded_stance(self):
        evaluation = self.resume['evaluation']
        # Same retained distal origins and frozen evaluator thresholds as V27.
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        cycles = []
        for limb, phase_index in {'rear_left': 0, 'front_left': 1, 'rear_right': 2, 'front_right': 3}.items():
            bearing, release = True, None
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current:
                    release = row
                elif not bearing and current and release is not None:
                    if row['global_semantic_step'] - release['global_semantic_step'] >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                        advance = sum((after[i] - before[i]) * axis[i] for i in range(3))
                        phase = (release['walking_session_local_step'] - 1 + 360 - phase_index * 90) % 360
                        cycles.append((advance, phase >= 72))
                    release = None
                bearing = current
        failed = [c for c in cycles if c[0] < evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual(9, len(cycles))
        self.assertEqual(self.basis['inadequate_completed_cycles'], len(failed))
        self.assertEqual(self.basis['inadequate_cycles_starting_in_commanded_stance'], sum(c[1] for c in failed))

    def test_final_gap_is_present_in_raw_native_contact_samples(self):
        native = {r['session_local_step']: r for r in self.report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume'}
        self.assertEqual(93, sum(not r['contact_by_limb']['rear_left'] for r in self.rows[307:]))
        checked = 0
        # Command n+1 contains observation n; the final trace has no next input.
        for local in range(308, 400):
            source = native[local + 1]['native_source']
            self.assertEqual(858 + local, source['precommand_trace']['global_semantic_step'])
            self.assertFalse(source['precommand_trace']['contact_by_limb']['rear_left'])
            self.assertEqual([], [r for r in source['contact_source_receipt']['ordered_contact_samples'] if r['body_id'] == 'rear_left_distal'])
            checked += 1
        self.assertEqual(self.basis['available_post_loss_native_samples_without_raw_distal_contact'], checked)
        self.assertNotIn(401, native)

    def test_one_amplitude_choice_preserves_runtime_and_other_schedules(self):
        before = candidate.read(ROOT / 'sdk/development/recovery_schedules/v27-ramped-neutral-stance-v1.json')['schedules']['v27-ramped-neutral-stance-v1']
        after = candidate.read(ROOT / 'sdk/development/recovery_schedules/v28-first-swing-walking-warmup-v1.json')['schedules']['v28-first-swing-walking-warmup-v1']
        for key in ('limits', 'controller_id', 'runtime_sha256', 'walking_resume_frame_id', 'walking_contact_profile_id', 'walking_replay_profile_id', 'walking_start_profile_id'):
            self.assertEqual(before[key], after[key])
        self.assertEqual(before['walking_entry_profile_id'], candidate.walking_entry_phase_family(after['walking_entry_profile_id']))
        self.assertEqual((72, 73, 361), tuple(self.contract[k] for k in ('warmup_steps', 'first_full_amplitude_local_step', 'first_contact_gated_local_step')))
        for relative in (self.basis['source_closure'], 'sdk/core/src/runtime.rs', 'sdk/core/src/recovery_runtime.rs',
                         'scripts/lab/gait/physical_wave_gait_quadruped.gd', 'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, '2e5e48eed57889bf83aaadc225ce45f62f27c7cf'), (ROOT / relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
