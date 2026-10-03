"""Cold V38 closure: all saved commands and cycles, no new native calls or worlds."""
import math
from pathlib import Path
import unittest
from unittest import mock

import test_development_v27_recovery_checkpoint as prior
import development_recovery_feasible_support_observation as observation
import development_recovery_v37_reference_diagnosis as algebra

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = 'db53de264ab04bc29157f8a1524e73d0'
SOURCE = '4931509b055fa0cc79012a6a3e1b868e23d02888'
POLICY = 'sporespore_balanced_wave_recovery_wave_velocity_v1'


class WaveVelocityCheckpoint(unittest.TestCase):
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
        cls.summary = closure.smoke.read(ROOT / 'sdk/development/recovery_wave_velocity_observation_v1.json')

    def test_complete_original_closure_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual((113, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((63, 1077346059), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:300db4643e916978c47b4fd0882cc855113f260da5f57f0233064d94456d853b', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:81161ab308fe3ad1c33574dcc5d61b83de0a6a2ec8ca2cd71e10bf98892440f2', self.record['kicked_report']['raw_sha256'])
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
        maximum_lift_fraction_error = maximum_comparison_error = 0.
        saturated = 0
        descriptor = self.report['configuration']['base_descriptor']
        upper_length = .35 * descriptor['upper_length_fraction']
        dimensions = (upper_length, .35-upper_length, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
        def wave(snapshot):
            return dict(active=snapshot['active'], limbs=[(p['nominal_leg_direction_rad'],
                p['walking_knee_fraction'], p['scheduled_phase_step']) for p in snapshot['ordered_limbs']])
        for local, row in enumerate(self.entries, 1):
            request, output = row['request'], row['native_output']
            self.assertEqual(source, row['development_floor_source'])
            self.assertEqual(source['floor_reference'], request['floor_reference'])
            self.assertEqual('sporespore_recovery_wave_velocity_controller_step_receipt_v1', output['actuation']['receipt']['schema_version'])
            receipt = output['actuation']['receipt']['recovery_support_plane']
            self.assertEqual('phase_only_existing_loaded_peak_swing_lift_v1', receipt['swing_lift_mode_id'])
            self.assertEqual(request['floor_reference'], receipt['floor_reference'])
            self.assertFalse(receipt['all_limb_contact_claim'])
            self.assertEqual('bounded_pose_separated_wave_velocity_tracking_v1', receipt['reference_velocity_mode_id'])
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
            wr = receipt['wave_velocity']
            self.assertEqual(request['memory']['support_reference'].get('previous_wave'), wr['previous_wave'])
            self.assertEqual(output['next_memory']['support_reference']['previous_wave'], wr['current_wave'])
            pose, current = algebra.inputs(row)
            self.assertEqual(current, wave(wr['current_wave']))
            caps = [c['maximum_target_speed_rad_s'] for c in output['actuation']['ordered_commands']]
            old_refs = request['memory']['support_reference']['ordered_target_positions_rad']
            dt = receipt['reference_step_duration_s']
            prior_wave = wave(wr['previous_wave']) if wr['previous_wave'] is not None else None
            active = prior_wave is not None and prior_wave['active'] and current['active']
            self.assertEqual(active, wr['feedforward_active'])
            actual = algebra.bounded_targets(algebra.goals(pose, current, dimensions)[0], old_refs, caps, dt)
            comparison = algebra.bounded_targets(algebra.goals(pose, prior_wave, dimensions)[0], old_refs, caps, dt) if active else actual
            for i, command in enumerate(output['actuation']['ordered_commands']):
                lower, upper = (-.72, .72) if i % 2 == 0 else (0., 1.1)
                value = command['requested_target_position_rad']
                self.assertLessEqual(lower, value); self.assertLessEqual(value, upper)
                self.assertEqual(value, command['clamped_target_position_rad'])
                old = request['memory']['support_reference']['ordered_target_positions_rad'][i]
                self.assertLessEqual(abs(value - old), command['maximum_target_speed_rad_s'] * receipt['reference_step_duration_s'] + 1e-14)
                dt, cap = receipt['reference_step_duration_s'], command['maximum_target_speed_rad_s']
                self.assertAlmostEqual(actual[i], value, delta=1e-12)
                error = abs(comparison[i] - wr['ordered_comparison_reference_rad'][i])
                maximum_comparison_error = max(maximum_comparison_error, error)
                self.assertLess(error, 1e-12)
                rate = max(-cap, min(cap, (value-comparison[i])/dt)) if active and dt > 0 else 0.
                self.assertAlmostEqual(rate, rates[i], delta=1e-10)
                self.assertLessEqual(abs(rates[i]), cap)
                joint = request['state']['ordered_joint_observations'][i]
                raw_velocity = 8.*(value-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
                self.assertAlmostEqual(-max(-cap, min(cap, raw_velocity)), command['target_velocity_rad_s'], delta=1e-10)
                self.assertEqual(abs(raw_velocity) > cap, command['velocity_saturated'])
                self.assertLessEqual(abs(command['target_velocity_rad_s']), cap)
                self.assertEqual(0., command['residual_contribution_rad_s'])
                if local == 1:
                    self.assertEqual(0., rate)
                    self.assertEqual(0., value)
                saturated += command['velocity_saturated']
                if local <= 2:
                    self.assertEqual(0., rate)
                commands += 1
            lowering += plan['requested_lowering_m'] > 0
            empty += not plan['common_height_interval_nonempty']
            participants += len(expected_participants)
        self.assertEqual((3200, 1600, 159, 46, 489), (commands, lift_goals, lowering, empty, participants))
        self.assertEqual(19, saturated)
        print('V38_COLD_COMMAND_AUDIT', dict(commands=commands, lift_goals=lift_goals,
            comparison_references=commands, velocity_saturated_commands=saturated,
            maximum_comparison_reference_error_rad=maximum_comparison_error,
            maximum_lift_fraction_error=maximum_lift_fraction_error), flush=True)

    def test_all_original_cycles_and_three_behavior_failures_are_retained(self):
        self.assertEqual(self.summary, observation.observe(Path(self.summary['source_closure']['path'])))
        data = self.summary['observation']; evaluation = self.resume['evaluation']
        self.assertEqual(evaluation, data['original_walking_evaluation'])
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles',
                          'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.12566751717286992, evaluation['forward_advance_m'])
        self.assertEqual(.12075144373236646, evaluation['maximum_tilt_rad'])
        self.assertEqual({'front_left': 7, 'front_right': 2, 'rear_left': 0, 'rear_right': 4}, evaluation['contact_cycle_count_by_limb'])
        per = {r['limb']: r for r in data['per_limb']}
        self.assertEqual({'front_left': 1, 'front_right': 262, 'rear_left': 352, 'rear_right': 91},
                         {k: v['first_scheduled_swing_command'] for k, v in per.items()})
        expected_holds = {'front_left': [dict(first=76,last=77,count=2)],
            'front_right': [dict(first=337,last=338,count=2)], 'rear_left': [],
            'rear_right': [dict(first=166,last=255,count=90)]}
        self.assertEqual(expected_holds, {k:v['recontact_hold_intervals'] for k,v in per.items()})
        self.assertEqual({'front_left': True, 'front_right': True, 'rear_left': False, 'rear_right': True},
                         {k: v['terminal_contact'] for k, v in per.items()})
        self.assertEqual((49,48), (per['rear_left']['scheduled_swing_command_count'],per['rear_left']['terminal_scheduled_phase_step']))
        cycles = [c for limb in per.values() for c in limb['contact_cycles']]
        self.assertEqual((13, 9, 9), (len(cycles), sum(not c['original_minimum_relocation_passed'] for c in cycles),
                         sum(c['scheduled_swing_or_landing_command_overlap_count'] == 0 for c in cycles)))
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        diagnosis = self.record['walking_control_diagnosis']
        self.assertEqual(0, diagnosis['actual_native_gate_timeout_total'])
        self.assertIsNone(diagnosis['first_tilt_limit_exceeded_global_step'])
        self.assertIsNone(diagnosis['first_no_foot_contact_global_step'])
        # The generic diagnostic's horizon flag does not establish complete scheduled cycles.
        self.assertTrue(self.record['diagnostic_coverage_complete'])
        self.assertFalse(self.record['complete_route_proven'])

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

    def test_original_v37_and_r173_and_zero_world_scope(self):
        self.assertEqual('sha256:8ab9f404dbdeaae05b447181b0b061ad85f625963ea59db634c82300ad47c4a1', closure.smoke.sha(ROOT / 'sdk/development/recovery_attempts/8ceafcfb9d5c4439859aee7f959e2740.json'))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        for key in ('new_world_build_count', 'new_solver_step_count', 'new_native_physics_read_count'):
            self.assertEqual(0, self.summary[key])
        for key in ('original_evaluation_changed', 'physical_cause_proven', 'alternate_outcome_predicted', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.summary[key])


if __name__ == '__main__':
    unittest.main()
