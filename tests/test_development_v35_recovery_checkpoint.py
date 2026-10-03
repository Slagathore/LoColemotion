"""Cold V35 physical closure and phase-aligned retained observation audit."""
import json
from pathlib import Path
import unittest
from unittest import mock

import test_development_v27_recovery_checkpoint as prior
import development_recovery_feasible_support_observation as observation

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '2d88c07d2ae0497a8fe9bc1fb60832e5'
SOURCE = '6a14d37a0d6d187a3453ad687534d9b004162eb1'
POLICY = 'sporespore_balanced_wave_recovery_feasible_support_v1'


class FeasibleSupportCheckpoint(unittest.TestCase):
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
        cls.summary = closure.smoke.read(ROOT / 'sdk/development/recovery_feasible_support_observation_v1.json')

    def test_complete_original_closure_and_claim_limits(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual((113, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((63, 1069954004), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:45320735fc0462483efc28b92e62e84be152a91f836fe696d3450100b4dc2845', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:1fc36eecd5b662e532aef2d8a66c99f515fe914830d4ddf197b29ff1995f3eb6', self.record['kicked_report']['raw_sha256'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258, 467, 119, 1), tuple(replay[k] for k in ('transition_count', 'canonical_observation_count', 'entry_observation_count', 'canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(POLICY, replay['walking_policy_validation']['policy_id'])
        for key in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertEqual(0, replay[key])
        for key in ('successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            self.assertFalse(self.record[key])
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', closure.smoke.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))

    def test_actual_standing_commands_and_same_body(self):
        # Reuse the existing independent stance-command/dwell audit, not a new fixture.
        prior.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual(POLICY, self.resume['start_receipt']['selected_policy_id'])
        self.assertEqual({90}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual((859, 1258, 400), (self.entries[0]['commanded_global_step'], self.entries[-1]['commanded_global_step'], len(self.entries)))

    def test_every_floor_context_plan_and_bounded_joint_command(self):
        source = self.resume['start_receipt']['development_floor_source']
        self.assertEqual(self.arm['model_instance_id'], source['geometry']['model_instance_id'])
        self.assertEqual([-10., 10.], source['geometry']['x_interval_m'])
        self.assertEqual([-10., 10.], source['geometry']['z_interval_m'])
        self.assertEqual(0., source['floor_reference']['height_world_m'])
        commands = lowering = empty = participants = 0
        for local, row in enumerate(self.entries, 1):
            request, output = row['request'], row['native_output']
            self.assertEqual(source, row['development_floor_source'])
            self.assertEqual(source['floor_reference'], request['floor_reference'])
            receipt = output['actuation']['receipt']['recovery_support_plane']
            plan = receipt['feasible_support_plan']
            self.assertEqual(request['floor_reference'], receipt['floor_reference'])
            self.assertFalse(receipt['all_limb_contact_claim'])
            height = request['state']['base_pose_world']['position_m']['y'] - request['floor_reference']['height_world_m']
            self.assertAlmostEqual(height, plan['measured_torso_height_m'], delta=1e-14)
            lower = max(p['minimum_torso_height_m'] for p in plan['ordered_limb_intervals'])
            upper = min(p['maximum_torso_height_m'] for p in plan['ordered_limb_intervals'])
            self.assertEqual(lower, plan['common_minimum_torso_height_m'])
            self.assertEqual(upper, plan['common_maximum_torso_height_m'])
            self.assertEqual(lower <= upper, plan['common_height_interval_nonempty'])
            target = min(height, upper) if lower <= upper and height >= lower else height
            self.assertAlmostEqual(target, plan['requested_stance_torso_height_m'], delta=1e-14)
            self.assertAlmostEqual(height-target, plan['requested_lowering_m'], delta=1e-14)
            expected = []
            for p in receipt['ordered_limb_proposals']:
                stance = p['scheduled_phase_step'] > 72
                self.assertAlmostEqual(target if stance else height, p['support_reference_torso_height_m'], delta=1e-14)
                if stance and plan['requested_lowering_m'] > 0:
                    expected.append(p['limb_id'])
            self.assertEqual(expected, plan['ordered_lowering_participant_limb_ids'])
            if local > 1:
                self.assertEqual(self.entries[local-2]['native_output']['next_memory'], request['memory'])
            else:
                self.assertTrue(receipt['first_step_holds_neutral_reference'])
            for i, command in enumerate(output['actuation']['ordered_commands']):
                lo, hi = (-.72, .72) if i % 2 == 0 else (0., 1.1)
                value = command['requested_target_position_rad']
                self.assertLessEqual(lo, value); self.assertLessEqual(value, hi)
                self.assertEqual(value, command['clamped_target_position_rad'])
                old = request['memory']['support_reference']['ordered_target_positions_rad'][i]
                # Existing arithmetic allowance only, not a new behavioral tolerance.
                self.assertLessEqual(abs(value-old), command['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']+1e-14)
                commands += 1
            lowering += plan['requested_lowering_m'] > 0
            empty += not plan['common_height_interval_nonempty']
            participants += len(expected)
        self.assertEqual((3200, 144, 94, 438), (commands, lowering, empty, participants))

    def test_recomputed_cycles_holds_and_original_negative(self):
        self.assertEqual(self.summary, observation.observe(Path(self.summary['source_closure']['path'])))
        data = self.summary['observation']
        self.assertEqual(self.resume['evaluation'], data['original_walking_evaluation'])
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.12746422657976403, evaluation['forward_advance_m'])
        self.assertEqual({'front_left': 7, 'front_right': 5, 'rear_left': 0, 'rear_right': 4}, evaluation['contact_cycle_count_by_limb'])
        per = {r['limb']: r for r in data['per_limb']}
        self.assertEqual((328, 400, 70, False), tuple(per['rear_left'][k] for k in ('first_scheduled_swing_command', 'last_scheduled_swing_command', 'terminal_scheduled_phase_step', 'terminal_contact')))
        for limb in per:
            before = self.entries[0]['request']['memory']['ordered_limb_memory']
            after = self.entries[-1]['native_output']['next_memory']['ordered_limb_memory']
            actual = next(m['recontact_hold_step_count'] for m in after if m['limb_id'] == limb) - next(m['recontact_hold_step_count'] for m in before if m['limb_id'] == limb)
            self.assertEqual(actual, sum(g['count'] for g in per[limb]['recontact_hold_intervals']))
            self.assertEqual(0, per[limb]['terminal_native_gate_timeout_count'])
        cycles = [c for limb in per.values() for c in limb['contact_cycles']]
        self.assertEqual((16, 12, 10), (len(cycles), sum(not c['original_minimum_relocation_passed'] for c in cycles), sum(c['scheduled_swing_or_landing_command_overlap_count'] == 0 for c in cycles)))
        self.assertEqual(0, self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])

    def test_source_context_corruption_and_claim_promotion_refuse(self):
        rows = list(self.entries)
        rows[10] = dict(rows[10], request=dict(rows[10]['request'], floor_reference=dict(rows[10]['request']['floor_reference'], height_world_m=1.)))
        changed = dict(self.report, development_walking_entry=dict(self.report['development_walking_entry'], rows=rows))
        with self.assertRaises(AssertionError):
            observation.summarize(changed)
        with mock.patch.object(observation, 'digest', return_value='sha256:' + '0'*64), self.assertRaisesRegex(ValueError, 'REPORT_DRIFT'):
            observation.observe(self.path)
        for key in ('successful_recovery_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: True}), self.observed)


if __name__ == '__main__':
    unittest.main()
