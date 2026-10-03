"""Prospective selection, actual GDScript selector and frozen closure bindings."""
import copy
import json
import unittest
from unittest.mock import patch
import uuid

from development_recovery_candidate_test_support import ROOT, candidate, arguments, selected
import test_development_passive_entry_replay as shared
import development_recovery_candidate_checkpoint as closure


class ProspectiveWalkingReplay(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.schedule = cls.selection['diagnostic_schedule']
        cls.root = shared.entry.EVIDENCE / ('development-prospective-walking-replay-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('PROSPECTIVE_WALKING_REPLAY_TEST_ROOT', cls.root, flush=True)
        cls.cases = {'selected': cls.schedule, 'legacy': {}}
        for name, key, value in [('unknown', 'walking_replay_profile_id', 'unknown'),
                                 ('boolean', 'walking_replay_profile_id', False),
                                 ('crossed_entry', 'walking_entry_profile_id', 'normal_one_cycle_amplitude_ramp_with_control_trace_v1')]:
            cls.cases[name] = dict(cls.schedule, **{key: value})
        fixture = cls.root / 'selection_cases.json'
        fixture.write_text(json.dumps(dict(schedules=cls.cases), separators=(',', ':')), encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_prospective_walking_replay.gd',
            ['--', str(fixture), *arguments(cls.selection)], 'actual_selector', 60)
        cls.result = shared.marker(run, 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')

    def test_python_and_actual_godot_agree_on_all_selections(self):
        for name, schedule in self.cases.items():
            with self.subTest(case=name):
                if name in ('selected', 'legacy'):
                    value = candidate.walking_memory_transition_id(schedule)
                    self.assertEqual('production_adapter_clocked_warmup_v1' if name == 'selected' else '', value)
                else:
                    with self.assertRaises(ValueError):
                        candidate.walking_memory_transition_id(schedule)
                self.assertEqual(name in ('selected', 'legacy'), self.result['cases'][name])
        self.assertTrue(self.result['contract_drift_refused'])
        self.assertEqual('production_adapter_clocked_warmup_v1', self.result['memory_transition_profile_id'])
        self.assertEqual([0, 0, 0], [self.result[k] for k in ('world_build_count', 'native_physics_read_count', 'solver_step_count')])
        with patch.object(candidate, 'sha', return_value='sha256:' + '0'*64), self.assertRaisesRegex(ValueError, 'CONTRACT_DRIFT'):
            candidate.walking_memory_transition_id(self.schedule)

    def test_prospective_process_selection_is_not_a_post_exposure_override(self):
        select = shared.entry._effective_memory_transition_profile
        self.assertEqual('production_adapter_clocked_warmup_v1', select(self.selection, ''))
        with self.assertRaisesRegex(ValueError, 'AUTHORITY_CROSSED'):
            select(self.selection, 'production_adapter_clocked_warmup_v1')
        old = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v23-clocked-walking-warmup-v1.json'))
        self.assertEqual('', select(old, ''))
        self.assertEqual(old['reader'], self.selection['reader'])
        self.assertEqual(candidate.limits(old), candidate.limits(self.selection))
        integration = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v24-prospective-transition-reader-v1.json'))
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            self.assertEqual(old['candidate'][key], integration['candidate'][key])

    def test_closure_binds_clocked_selector_and_transition_from_its_source_tree(self):
        # This is an explicitly synthetic source provider, not a frozen-run receipt.
        source = 'synthetic_owned_source_projection'
        with patch.object(closure.prior, 'committed', side_effect=lambda relative, commit: (ROOT / relative).read_bytes()):
            sources = closure.walking_entry_rule_sources(self.schedule, source)
            extra_start_sources = [
                'sdk/development/recovery_walking_start_contract_v1.json',
                'scripts/lab/gait/physical_wave_gait_quadruped.gd',
                'sdk/adapters/godot/gdscript/development_recovery_walking_start_v1.gd',
                'sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd',
                'sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd',
                'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd',
            ] if self.schedule.get('walking_start_profile_id') else []
            limited = self.schedule['walking_entry_profile_id'] == candidate.read(candidate.JOINT_BOUNDED_ENTRY_PATH)['profile_id']
            first_swing = limited or self.schedule['walking_entry_profile_id'] == candidate.read(candidate.FIRST_SWING_ENTRY_PATH)['profile_id']
            entry_sources = (['sdk/development/recovery_first_swing_walking_entry_contract_v1.json',
                'sdk/development/recovery_clocked_walking_entry_contract_v1.json',
                'sdk/development/recovery_walking_entry_contract_v1.json',
                'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd',
                'sdk/adapters/godot/gdscript/development_recovery_walking_entry_v1.gd'] if first_swing else
                ['sdk/development/recovery_clocked_walking_entry_contract_v1.json'])
            if limited:
                bound = candidate.read(candidate.JOINT_BOUNDED_ENTRY_PATH)['bound_source_files']
                entry_sources = ['sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json'] + [r['path'] for r in bound] + entry_sources[1:]
            transition_sources = ['sdk/development/recovery_prospective_walking_replay_contract_v1.json',
                'sdk/development/recovery_walking_memory_transition_contract_v1.json',
                'sdk/adapters/godot/gdscript/development_walking_memory_transition_v1.gd',
                'sdk/trace_analysis/development_recovery_candidate_replay.gd']
            self.assertEqual(entry_sources + transition_sources + extra_start_sources, [item['path'] for item in sources])
            self.assertTrue(all(item['source_commit'] == source for item in sources))
            for item in sources:
                self.assertEqual(candidate.sha(ROOT / item['path']), item['raw_sha256'])
            self.assertEqual(entry_sources[0], sources[0]['path'])
            for key, value in [('walking_entry_profile_id', 'unknown'), ('walking_replay_profile_id', 'unknown'), ('walking_start_profile_id', 'unknown')]:
                with self.subTest(key=key), self.assertRaises(ValueError):
                    closure.walking_entry_rule_sources(dict(self.schedule, **{key: value}), source)
        # Actual historical Git tree still resolves its original single contract.
        old_source = '3b53ce2f8a612e2ecfb88c5fd7d9932fafce33c4'
        old = closure.walking_entry_rule_sources({'walking_entry_profile_id': 'normal_one_cycle_amplitude_ramp_with_control_trace_v1'}, old_source)
        self.assertEqual(1, len(old))
        self.assertEqual('sdk/development/recovery_walking_entry_contract_v1.json', old[0]['path'])

    def test_bound_prior_diagnostic_and_original_invalid_record_stay_exact(self):
        contract = candidate.read(ROOT / 'sdk/development/recovery_prospective_walking_replay_contract_v1.json')
        self.assertEqual(contract['qualification_diagnostic_sha256'], candidate.sha(ROOT / contract['qualification_diagnostic']))
        for key in ('original_attempt_reclassified', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(contract[key], False)
        self.assertEqual('sha256:e1fe74012d27269c081a36971e57e674df09c3d8640adc3ece1b5b70e21fd4f8', candidate.sha(ROOT / 'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json'))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
