"""Actual zero-world phase startup, reader refusals, and immutable source diagnosis."""
import copy
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared


class WalkingStart(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-walking-start-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('DEVELOPMENT_WALKING_START_TEST_ROOT', cls.root, flush=True)

    def test_actual_start_worker_native_commands_and_reader(self):
        run = self._run_retained('res://tests/test_development_recovery_walking_start.gd',
            ['--', *arguments(self.selection)], 'actual_start', 90)
        result = shared.marker(run, 'DEVELOPMENT_WALKING_START_CHECKS ')
        self.assertTrue(result['ok'], result)
        self.assertTrue(all(result['checks'].values()), result)
        self.assertEqual(450, result['result']['command_probe_steps'])
        for key in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertEqual(0, result[key])

    def test_python_rejects_crossed_selection_kind_and_source(self):
        schedule = self.selection['diagnostic_schedule']
        expected = candidate.walking_start_contract(schedule['walking_start_profile_id'])
        self.assertEqual(expected['profile_id'], candidate.walking_start_id(schedule))
        self.assertEqual('', candidate.walking_start_id({}))
        for change in ({'walking_start_profile_id': False}, {'walking_start_profile_id': 0},
                       {'walking_start_profile_id': 'unknown'}, {'walking_entry_profile_id': ''}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                candidate.walking_start_id(dict(schedule, **change))
        drift = ('WALKING_ENTRY_CONTRACT_DRIFT' if schedule['walking_entry_profile_id'] in tuple(candidate.read(p)['profile_id'] for p in (candidate.FIRST_SWING_ENTRY_PATH, candidate.JOINT_BOUNDED_ENTRY_PATH, candidate.CONTACT_GATED_ENTRY_PATH, candidate.ROTATED_ENTRY_PATH, candidate.SWING_END_ENTRY_PATH, candidate.SUPPORT_ENTRY_PATH, candidate.FLOOR_ENTRY_PATH, candidate.FEASIBLE_ENTRY_PATH, candidate.SMOOTH_ENTRY_PATH, candidate.REFERENCE_ENTRY_PATH, candidate.WAVE_ENTRY_PATH, candidate.AIRBORNE_ENTRY_PATH, candidate.ABSENT_ENTRY_PATH, candidate.UPRIGHT_ENTRY_PATH, candidate.STANCE_LATCH_ENTRY_PATH, candidate.PROGRESSION_ENTRY_PATH, candidate.POSTURE_ENTRY_PATH))
                 else 'WALKING_START_LAUNCHER_DRIFT')
        with patch.object(candidate, 'sha', return_value='sha256:' + '0' * 64), self.assertRaisesRegex(ValueError, drift):
            candidate.walking_start_id(schedule)

    def test_retained_v23_start_is_240_without_regrading(self):
        record = candidate.read(ROOT / 'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json')
        self.assertEqual('closed_consumed_independent_replay_invalid', record['status'])
        path = Path(record['kicked_report']['path'])
        self.assertEqual(record['kicked_report']['raw_sha256'], candidate.sha(path))
        report = candidate.read(path)
        session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        self.assertEqual({240}, set(session['start_receipt']['initial_gait_steps'].values()))
        first = report['development_walking_entry']['rows'][0]
        self.assertEqual({240}, {p['gait_step'] for p in first['request']['memory']['ordered_limb_memory']})
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], session['evaluation']['false_walking_receipts'])
        self.assertFalse(record['original_independent_replay_passed'])

    def test_limits_policy_and_preserved_records_do_not_change(self):
        older = candidate.read(ROOT / 'sdk/development/recovery_schedules/v24-prospective-transition-reader-v1.json')['schedules']['v24-prospective-transition-reader-v1']
        schedule = self.selection['diagnostic_schedule']
        for key in ('limits', 'walking_resume_frame_id', 'walking_contact_profile_id'):
            self.assertEqual(older[key], schedule[key])
        if schedule['walking_entry_profile_id'] in tuple(candidate.read(p)['profile_id'] for p in (candidate.CONTACT_GATED_ENTRY_PATH, candidate.ROTATED_ENTRY_PATH, candidate.SWING_END_ENTRY_PATH, candidate.SUPPORT_ENTRY_PATH, candidate.FLOOR_ENTRY_PATH, candidate.FEASIBLE_ENTRY_PATH, candidate.SMOOTH_ENTRY_PATH, candidate.REFERENCE_ENTRY_PATH, candidate.WAVE_ENTRY_PATH, candidate.AIRBORNE_ENTRY_PATH, candidate.ABSENT_ENTRY_PATH, candidate.UPRIGHT_ENTRY_PATH, candidate.STANCE_LATCH_ENTRY_PATH, candidate.PROGRESSION_ENTRY_PATH, candidate.POSTURE_ENTRY_PATH)):
            self.assertNotIn('walking_replay_profile_id', schedule)
            self.assertEqual('', candidate.walking_memory_transition_id(schedule))
            self.assertEqual('normal_one_cycle_amplitude_ramp_with_control_trace_v1', candidate.walking_entry_phase_family(schedule['walking_entry_profile_id']))
            with self.assertRaisesRegex(ValueError, 'WALKING_REPLAY_SELECTION'):
                candidate.walking_memory_transition_id(dict(schedule, walking_replay_profile_id=older['walking_replay_profile_id']))
        else:
            self.assertEqual(older['walking_replay_profile_id'], schedule['walking_replay_profile_id'])
            self.assertEqual(older['walking_entry_profile_id'], candidate.walking_entry_phase_family(schedule['walking_entry_profile_id']))
        # A later recovery candidate can reuse this exact walking-start feature.
        # Its compiled runtime/fixtures verify the declared pre-stance preservation;
        # the startup test still pins walking code and every historical record.
        same_recovery = schedule['controller_id'] == older['controller_id']
        if not same_recovery:
            self.assertIs(schedule['coverage_basis'].get('new_controller_preserves_pre_stance_motion_and_limits'), True)
        self.assertEqual(986, schedule['limits']['after_interaction_steps'])
        self.assertEqual(1338, schedule['limits']['maximum_steps_per_child'])
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        import development_recovery_candidate_checkpoint as closure
        preserved = ['sdk/core/src/runtime.rs',
                         'sdk/development/recovery_attempts/d8f05d136e4849248b7246e3e546ecf2.json',
                         'sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json']
        if candidate.walking_policy_id(schedule):
            # V32 is an explicit native walking successor, not a claim of byte
            # preservation of V24 runtime source. Its compiled source is pinned.
            preserved.remove('sdk/core/src/runtime.rs')
            if schedule['walking_policy_id'] in (candidate.read(p)['policy_id'] for p in (candidate.SUPPORT_POLICY_PATH, candidate.FLOOR_POLICY_PATH, candidate.FEASIBLE_POLICY_PATH, candidate.SMOOTH_POLICY_PATH, candidate.REFERENCE_POLICY_PATH, candidate.WAVE_POLICY_PATH, candidate.AIRBORNE_POLICY_PATH, candidate.ABSENT_POLICY_PATH, candidate.UPRIGHT_POLICY_PATH, candidate.STANCE_LATCH_POLICY_PATH, candidate.PROGRESSION_POLICY_PATH, candidate.POSTURE_POLICY_PATH)):
                # V33 adds serialized bounded-support memory. Bind the compiled
                # source; its separate exported tests prove old-policy bytes.
                binding = candidate.read(candidate.resource_path(self.selection['candidate']['runtime_binding']))
                runtime = next(item for item in binding['source_files'] if item['path'] == 'sdk/core/src/runtime.rs')
                self.assertEqual(runtime['raw_sha256'], candidate.sha(ROOT / runtime['path']))
            else:
                self.assertEqual(closure.prior.committed('sdk/core/src/runtime.rs', '7317262bc8d5b4963585578bc7f75a8abdba0aa5'),
                                 (ROOT / 'sdk/core/src/runtime.rs').read_bytes())
        if same_recovery:
            preserved.append('sdk/core/src/recovery_runtime.rs')
        for relative in preserved:
            self.assertEqual(closure.prior.committed(relative, '260195a2916de63565dcdbb7e2b683d41a9e0ecd'), (ROOT / relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
