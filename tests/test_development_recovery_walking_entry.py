"""Retained V18 entry-state command probe; no speculative physics reconstruction."""
import json
import copy
from pathlib import Path
import unittest
import uuid
from unittest.mock import patch

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared


class WalkingEntry(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-walking-entry-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('DEVELOPMENT_WALKING_ENTRY_ROOT', cls.root, flush=True)
        cls.record = candidate.read(ROOT / 'sdk/development/recovery_attempts/88d86686f4d1421286b59eb03c7d8115.json')
        report_path = Path(cls.record['kicked_report']['path'])
        if candidate.sha(report_path) != cls.record['kicked_report']['raw_sha256']:
            raise AssertionError('V18_REPORT_DRIFT')
        cls.report = candidate.read(report_path)
        packet = cls.report['passive_entry']['canonical_packets'][-1]
        cls.native = shared.parse_json(packet['collection_transport']['request']['utf8_text'])['observation']['state']
        fixture = cls.root / 'retained_standing_input.json'
        fixture.write_text(json.dumps(dict(source_report=cls.record['kicked_report'], source_global_step=packet['global_semantic_step'],
            native_state=cls.native, original_request_reconstructed=False), separators=(',', ':')) + '\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_recovery_walking_entry.gd',
            ['--', *arguments(cls.selection), str(fixture)], 'native_command_probe', 60)
        cls.result = shared.marker(run, 'DEVELOPMENT_WALKING_ENTRY_PROBE ')
        if cls.selection.get('diagnostic_schedule', {}).get('walking_entry_profile_id'):
            good = cls.result['cases'][-1]['retention_probe']
            cases = {'positive': good}
            for name in ('missing_row', 'clock', 'amplitude', 'phase_mode', 'output', 'motor', 'authority', 'body_population', 'memory', 'step_hash', 'raw_response_hash'):
                bad = copy.deepcopy(good)
                retention = bad['development_walking_entry']
                row = retention['rows'][0]
                if name == 'missing_row':
                    retention['rows'].pop()
                    retention['sample_count'] -= 1
                elif name == 'clock':
                    row['measured_global_step'] += 1
                elif name == 'amplitude':
                    row['request']['command']['gait_amplitude'] = 1.
                elif name == 'phase_mode':
                    command = row['request']['command']
                    command['phase_progression_mode'] = 'clocked' if command['phase_progression_mode'] == 'contact_gated' else 'contact_gated'
                elif name == 'output':
                    row['native_output']['actuation']['ordered_commands'][0]['target_velocity_rad_s'] += .1
                elif name == 'motor':
                    row['ordered_motor_applications'][0]['host_applied_target_velocity_rad_s'] += .1
                elif name == 'authority':
                    retention['release_authority'] = True
                elif name == 'body_population':
                    row['ordered_body_states'].pop()
                elif name == 'memory':
                    retention['rows'][1]['request']['memory'] = row['request']['memory']
                elif name == 'step_hash':
                    row['full_step_receipt_sha256'] = 'sha256:' + '0'*64
                else:
                    row['raw_native_response_sha256'] = 'sha256:' + '0'*64
                cases[name] = bad
            inputs = cls.root / 'serialized_reader_cases.json'
            inputs.write_text(json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
            run = cls._run_retained('res://tests/test_development_recovery_walking_entry.gd',
                ['--', *arguments(cls.selection), str(inputs), 'independent-reader'], 'cold_walking_reader', 60)
            cls.replays = shared.marker(run, 'DEVELOPMENT_WALKING_ENTRY_REPLAY ')

    def test_real_controller_probe_and_distinct_command_only_authority(self):
        self.assertTrue(self.result['ok'], self.result)
        self.assertTrue(all(self.result['checks'].values()), self.result)
        self.assertEqual([1., 0.], [c['gait_amplitude'] for c in self.result['cases']])
        for key in ('exact_original_walking_request_replayed', 'physical_outcome_predicted', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.result[key])
        for key in ('model_construction_count', 'world_build_count', 'solver_step_count'):
            self.assertEqual(0, self.result[key])

    def test_complete_eight_joint_command_jump_population(self):
        summaries = []
        for case in self.result['cases']:
            commands = case['output']['value']['actuation']['ordered_commands']
            self.assertEqual(8, len(commands))
            rows = []
            for joint, command in zip(self.native['ordered_joint_observations'], commands):
                self.assertEqual(joint['joint_id'] + '_motor', command['actuator_id'])
                rows.append(dict(joint=joint['joint_id'], measured_position_rad=joint['position_rad'],
                    requested_target_position_rad=command['requested_target_position_rad'],
                    target_position_change_rad=command['requested_target_position_rad']-joint['position_rad'],
                    requested_motor_velocity_rad_s=command['target_velocity_rad_s'],
                    maximum_target_speed_rad_s=command['maximum_target_speed_rad_s'],
                    velocity_saturated=command['velocity_saturated']))
            summaries.append(dict(gait_amplitude=case['gait_amplitude'], joints=rows,
                maximum_absolute_target_jump_rad=max(abs(r['target_position_change_rad']) for r in rows)))
        (self.root / 'command_jump_diagnosis.json').write_text(json.dumps(dict(cases=summaries,
            exact_physical_first_command_replayed=False, physical_success_proven=False), indent=2) + '\n', encoding='utf-8')
        print('WALKING_ENTRY_COMMAND_JUMPS', json.dumps(summaries, separators=(',', ':')), flush=True)
        if candidate.walking_policy_id(self.selection['diagnostic_schedule']) in (candidate.read(p)['policy_id'] for p in (candidate.SUPPORT_POLICY_PATH, candidate.FLOOR_POLICY_PATH, candidate.FEASIBLE_POLICY_PATH, candidate.SMOOTH_POLICY_PATH, candidate.REFERENCE_POLICY_PATH, candidate.WAVE_POLICY_PATH, candidate.AIRBORNE_POLICY_PATH, candidate.ABSENT_POLICY_PATH, candidate.UPRIGHT_POLICY_PATH, candidate.STANCE_LATCH_POLICY_PATH, candidate.PROGRESSION_POLICY_PATH, candidate.POSTURE_POLICY_PATH)):
            # The new reference initializer deliberately holds neutral even
            # when the first requested amplitude is one. This is a new-policy
            # command probe, not a replay or repair of the old physical input.
            measured_max = max(abs(joint['position_rad']) for joint in self.native['ordered_joint_observations'])
            for case, summary in zip(self.result['cases'], summaries):
                self.assertTrue(all(row['requested_target_position_rad'] == 0. for row in summary['joints']))
                self.assertEqual(measured_max, summary['maximum_absolute_target_jump_rad'])
                receipt = case['output']['value']['actuation']['receipt']['recovery_support_plane']
                self.assertTrue(receipt['first_step_holds_neutral_reference'])
                self.assertEqual(0., receipt['reference_step_duration_s'])
        else:
            self.assertGreater(summaries[0]['maximum_absolute_target_jump_rad'], 1.)
        self.assertLess(summaries[1]['maximum_absolute_target_jump_rad'], .3)

    def test_retained_walking_payload_limit_and_original_negative_preserved(self):
        walk = self.report['retained_arm']['walking_sessions'][-1]
        self.assertEqual(93, len(walk['step_receipt_sha256s']))
        trace = walk['completion_receipt']['adapter_summary']['r23d2_oracle_trace']
        self.assertFalse(trace['enabled'])
        self.assertEqual([], trace['rows'])
        self.assertFalse(walk['evaluation']['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'], walk['evaluation']['false_walking_receipts'])

    def test_actual_ramp_producer_and_independent_serialized_native_reader(self):
        self.assertTrue(self.result['checks']['ramp_matches_established_function_all_warmup_steps'])
        self.assertTrue(self.result['checks']['same_process_pure_replay'], self.result['checks'])
        for check in ('selected_phase_mode_boundary', 'historical_and_prefix_phase_modes_unchanged', 'actual_facade_sampler_receives_selected_mode'):
            self.assertTrue(self.result['checks'][check], self.result['checks'])
        if candidate.walking_entry_phase_family(self.selection['diagnostic_schedule']['walking_entry_profile_id']) == 'one_cycle_ramp_clocked_then_contact_gated_v1':
            self.assertTrue(self.result['checks']['native_warmup_and_mode_switch_without_memory_reset'], self.result['checks'])
            self.assertTrue(self.result['checks']['native_contact_gate_active_after_warmup'], self.result['checks'])
        result = self.replays['positive']
        self.assertTrue(result['ok'], result)
        contact_start = self.selection['diagnostic_schedule']['walking_entry_profile_id'] in tuple(candidate.read(p)['profile_id'] for p in (candidate.CONTACT_GATED_ENTRY_PATH, candidate.ROTATED_ENTRY_PATH, candidate.SWING_END_ENTRY_PATH, candidate.SUPPORT_ENTRY_PATH, candidate.FLOOR_ENTRY_PATH, candidate.FEASIBLE_ENTRY_PATH, candidate.SMOOTH_ENTRY_PATH, candidate.REFERENCE_ENTRY_PATH, candidate.WAVE_ENTRY_PATH, candidate.AIRBORNE_ENTRY_PATH, candidate.ABSENT_ENTRY_PATH, candidate.UPRIGHT_ENTRY_PATH, candidate.STANCE_LATCH_ENTRY_PATH, candidate.PROGRESSION_ENTRY_PATH, candidate.POSTURE_ENTRY_PATH))
        self.assertEqual(100 if contact_start else 2, result['replayed_walking_steps'])
        if contact_start:
            for key in ('retained_contact_gate_exercised', 'retained_commands_respect_selected_joint_bound', 'actual_adapter_preserves_strict_memory_chain'):
                self.assertTrue(self.result['checks'][key])
        for key in ('additional_native_physics_read_count', 'world_build_count', 'solver_step_count'):
            self.assertEqual(0, result[key])
        self.assertFalse(result['physical_acceptance_authority'])
        self.assertFalse(result['release_authority'])

    def test_cold_reader_refuses_all_eleven_corruptions(self):
        self.assertEqual(12, len(self.replays))
        self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_COMMAND_SCHEDULE', self.replays['phase_mode']['failure_code'])
        for name, result in self.replays.items():
            if name != 'positive':
                with self.subTest(case=name):
                    self.assertIs(result['ok'], False, result)
                    self.assertTrue(result['failure_code'].startswith('DEVELOPMENT_WALKING_ENTRY_'))

    def test_unknown_profile_selection_refuses_without_changing_old_profiles(self):
        schedule_path = candidate.schedule_path(self.selection['candidate']['diagnostic_schedule_id'])
        original = candidate.read(schedule_path)
        original_read = candidate.read
        for bad in (True, None, 19, 'unknown'):
            changed = copy.deepcopy(original)
            changed['schedules'][self.selection['candidate']['diagnostic_schedule_id']]['walking_entry_profile_id'] = bad
            with self.subTest(value=bad), patch.object(candidate, 'read', side_effect=lambda p: changed if p == schedule_path else original_read(p)):
                with self.assertRaisesRegex(ValueError, 'WALKING_ENTRY_SELECTION'):
                    candidate.selection(self.selection['candidate_profile'])
        old = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v18-anatomical-walking-frame-v1.json'))
        ramp_only = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v19-ramped-walking-entry-v1.json'))
        self.assertNotIn('walking_entry_profile_id', old['diagnostic_schedule'])
        # V19's ramp-only change preserved V18's runtime. Later explicitly
        # bound recovery-controller successors need not share that old DLL.
        self.assertEqual(old['candidate']['runtime_sha256'], ramp_only['candidate']['runtime_sha256'])


if __name__ == '__main__':
    unittest.main()
