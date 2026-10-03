"""Cold V37 closure: all saved commands and cycles, no new native calls or worlds."""
import math
from pathlib import Path
import unittest
from unittest import mock

import test_development_v27_recovery_checkpoint as prior
import development_recovery_feasible_support_observation as observation

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '8ceafcfb9d5c4439859aee7f959e2740'
SOURCE = '6cb28e642186bf60052a57b6875925716a2522b5'
POLICY = 'sporespore_balanced_wave_recovery_reference_velocity_v1'


class ReferenceVelocityCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json')
        cls.record = closure.smoke.read(cls.path)
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.entries = cls.report['development_walking_entry']['rows']
        cls.summary = closure.smoke.read(ROOT / 'sdk/development/recovery_reference_velocity_observation_v1.json')

    def test_complete_original_closure_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual((113, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((63, 1069818179), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:af82a4d5222812d0a9b32813751051384e186ae3b717a5a0cb02ac92dc066553', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:48c60a515f08c47100d28603763cf7dd2f3e049d44153703ad7436bccebe3440', self.record['kicked_report']['raw_sha256'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(POLICY, replay['walking_policy_validation']['policy_id'])
        for key in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertEqual(0, replay[key])

    def test_actual_standing_commands_and_same_body(self):
        # Reuse the independent standing-command/dwell audit unchanged.
        prior.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual(POLICY, self.resume['start_receipt']['selected_policy_id'])
        self.assertEqual({90}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual((859, 1258, 400), (self.entries[0]['commanded_global_step'], self.entries[-1]['commanded_global_step'], len(self.entries)))

    def test_all_lift_goals_floor_plans_memory_and_joint_bounds(self):
        source = self.resume['start_receipt']['development_floor_source']
        self.assertEqual(self.arm['model_instance_id'], source['geometry']['model_instance_id'])
        self.assertEqual(0., source['floor_reference']['height_world_m'])
        commands = lift_goals = lowering = empty = participants = 0
        maximum_lift_fraction_error = 0.
        for local, row in enumerate(self.entries, 1):
            request, output = row['request'], row['native_output']
            self.assertEqual(source, row['development_floor_source'])
            self.assertEqual(source['floor_reference'], request['floor_reference'])
            self.assertEqual('sporespore_recovery_reference_velocity_controller_step_receipt_v1', output['actuation']['receipt']['schema_version'])
            receipt = output['actuation']['receipt']['recovery_support_plane']
            self.assertEqual('phase_only_existing_loaded_peak_swing_lift_v1', receipt['swing_lift_mode_id'])
            self.assertEqual(request['floor_reference'], receipt['floor_reference'])
            self.assertFalse(receipt['all_limb_contact_claim'])
            self.assertEqual('bounded_slewed_reference_velocity_tracking_v1', receipt['reference_velocity_mode_id'])
            rates = receipt['ordered_reference_velocity_rad_s']
            self.assertEqual(8, len(rates))
            plan = receipt['feasible_support_plan']
            height = request['state']['base_pose_world']['position_m']['y'] - request['floor_reference']['height_world_m']
            self.assertAlmostEqual(height, plan['measured_torso_height_m'], delta=1e-14)
            lo = max(p['minimum_torso_height_m'] for p in plan['ordered_limb_intervals'])
            hi = min(p['maximum_torso_height_m'] for p in plan['ordered_limb_intervals'])
            self.assertEqual((lo, hi, lo <= hi), (plan['common_minimum_torso_height_m'], plan['common_maximum_torso_height_m'], plan['common_height_interval_nonempty']))
            target = min(height, hi) if lo <= hi and height >= lo else height
            self.assertAlmostEqual(target, plan['requested_stance_torso_height_m'], delta=1e-14)
            expected_participants = []
            for p in receipt['ordered_limb_proposals']:
                phase = p['scheduled_phase_step']
                amplitude = request['command']['gait_amplitude']
                expected = amplitude * (.82 * 1.75 + .4) * math.sin(math.pi * phase / 72) / 1.1 if phase < 72 else 0.
                error = abs(expected - p['walking_knee_fraction'])
                # Existing arithmetic allowance only; no behavioral tolerance.
                self.assertLessEqual(error, 1e-14)
                maximum_lift_fraction_error = max(maximum_lift_fraction_error, error)
                if phase == 0 or phase >= 72:
                    self.assertEqual(0., p['walking_knee_fraction'])
                self.assertAlmostEqual(target if phase > 72 else height, p['support_reference_torso_height_m'], delta=1e-14)
                if phase > 72 and plan['requested_lowering_m'] > 0:
                    expected_participants.append(p['limb_id'])
                lift_goals += 1
            self.assertEqual(expected_participants, plan['ordered_lowering_participant_limb_ids'])
            if local > 1:
                self.assertEqual(self.entries[local - 2]['native_output']['next_memory'], request['memory'])
            else:
                self.assertTrue(receipt['first_step_holds_neutral_reference'])
            for i, command in enumerate(output['actuation']['ordered_commands']):
                lower, upper = (-.72, .72) if i % 2 == 0 else (0., 1.1)
                value = command['requested_target_position_rad']
                self.assertLessEqual(lower, value); self.assertLessEqual(value, upper)
                self.assertEqual(value, command['clamped_target_position_rad'])
                old = request['memory']['support_reference']['ordered_target_positions_rad'][i]
                self.assertLessEqual(abs(value - old), command['maximum_target_speed_rad_s'] * receipt['reference_step_duration_s'] + 1e-14)
                dt, cap = receipt['reference_step_duration_s'], command['maximum_target_speed_rad_s']
                rate = max(-cap, min(cap, (value-old)/dt)) if dt > 0 else 0.
                self.assertAlmostEqual(rate, rates[i], delta=1e-13)
                self.assertLessEqual(abs(rates[i]), cap)
                joint = request['state']['ordered_joint_observations'][i]
                raw_velocity = 8.*(value-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
                self.assertAlmostEqual(-max(-cap, min(cap, raw_velocity)), command['target_velocity_rad_s'], delta=1e-13)
                self.assertEqual(abs(raw_velocity) > cap, command['velocity_saturated'])
                self.assertLessEqual(abs(command['target_velocity_rad_s']), cap)
                self.assertEqual(0., command['residual_contribution_rad_s'])
                if local == 1:
                    self.assertEqual(0., rate)
                    self.assertEqual(0., value)
                commands += 1
            lowering += plan['requested_lowering_m'] > 0
            empty += not plan['common_height_interval_nonempty']
            participants += len(expected_participants)
        self.assertEqual((3200, 1600, 45, 329, 137), (commands, lift_goals, lowering, empty, participants))
        print('V37_COLD_COMMAND_AUDIT', dict(commands=commands, lift_goals=lift_goals, maximum_lift_fraction_error=maximum_lift_fraction_error), flush=True)

    def test_all_original_cycles_and_backward_unstable_result_are_retained(self):
        self.assertEqual(self.summary, observation.observe(Path(self.summary['source_closure']['path'])))
        data = self.summary['observation']; evaluation = self.resume['evaluation']
        self.assertEqual(evaluation, data['original_walking_evaluation'])
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['bounded_tilt', 'every_limb_forward_relocation', 'minimum_evidence_forward_translation',
                          'minimum_final_forward_translation', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(-.24668451367012878, evaluation['forward_advance_m'])
        self.assertEqual(.8053270574987202, evaluation['maximum_tilt_rad'])
        self.assertEqual({'front_left': 7, 'front_right': 5, 'rear_left': 8, 'rear_right': 5}, evaluation['contact_cycle_count_by_limb'])
        per = {r['limb']: r for r in data['per_limb']}
        self.assertEqual({'front_left': 1, 'front_right': 186, 'rear_left': 282, 'rear_right': 96},
                         {k: v['first_scheduled_swing_command'] for k, v in per.items()})
        for limb, first in [('front_left', 88), ('front_right', 274), ('rear_left', 357), ('rear_right', 171)]:
            self.assertEqual([dict(first=first, last=first+1, count=2)], per[limb]['recontact_hold_intervals'])
        self.assertEqual({'front_left': False, 'front_right': False, 'rear_left': True, 'rear_right': True},
                         {k: v['terminal_contact'] for k, v in per.items()})
        cycles = [c for limb in per.values() for c in limb['contact_cycles']]
        self.assertEqual((25, 20, 17), (len(cycles), sum(not c['original_minimum_relocation_passed'] for c in cycles),
                         sum(c['scheduled_swing_or_landing_command_overlap_count'] == 0 for c in cycles)))
        self.assertTrue(evaluation['walking_gate_receipts']['every_limb_two_contact_cycles'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        diagnosis = self.record['walking_control_diagnosis']
        self.assertEqual(0, diagnosis['actual_native_gate_timeout_total'])
        self.assertEqual(1227, diagnosis['first_tilt_limit_exceeded_global_step'])
        self.assertEqual(1241, diagnosis['first_no_foot_contact_global_step'])

    def test_crossed_floor_report_and_claim_promotion_refuse(self):
        rows = list(self.entries)
        rows[10] = dict(rows[10], request=dict(rows[10]['request'], floor_reference=dict(rows[10]['request']['floor_reference'], height_world_m=1.)))
        changed = dict(self.report, development_walking_entry=dict(self.report['development_walking_entry'], rows=rows))
        with self.assertRaises(AssertionError):
            observation.summarize(changed)
        with mock.patch.object(observation, 'digest', return_value='sha256:' + '0' * 64), self.assertRaisesRegex(ValueError, 'REPORT_DRIFT'):
            observation.observe(self.path)
        for key in ('successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: True}), self.observed)

    def test_original_v36_and_r173_and_zero_world_scope(self):
        self.assertEqual('sha256:950aa372d1f15d72b92245c2f3ce472d51289356fbc823759fbdd021772c6777', closure.smoke.sha(ROOT / 'sdk/development/recovery_attempts/9959c99703944cbd80789ac00ed2d90c.json'))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        for key in ('new_world_build_count', 'new_solver_step_count', 'new_native_physics_read_count'):
            self.assertEqual(0, self.summary[key])
        for key in ('original_evaluation_changed', 'physical_cause_proven', 'alternate_outcome_predicted', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.summary[key])


if __name__ == '__main__':
    unittest.main()
