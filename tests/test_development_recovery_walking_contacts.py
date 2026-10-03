"""Actual recovery shape factory, semantic observer, adapter consumers and worker."""
import copy
import json
import unittest
import uuid
from unittest.mock import patch

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared


class WalkingContacts(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-walking-contacts-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('DEVELOPMENT_WALKING_CONTACT_ROOT', cls.root, flush=True)
        run = cls._run_retained('res://tests/test_development_recovery_walking_contacts.gd',
                                ['--', *arguments(cls.selection)], 'real_contacts', 60)
        cls.result = shared.marker(run, 'DEVELOPMENT_WALKING_CONTACT_CHECKS ')
        good = cls.result['report']
        cases = {'positive': good}
        for name in ('missing_row', 'shape', 'presence', 'provenance', 'stability', 'callback', 'clock', 'digest', 'session_selection', 'timeout_label', 'timeout_counter', 'authority'):
            bad = copy.deepcopy(good)
            retained = bad['development_walking_contacts']
            row = retained['rows'][-1]
            if name == 'missing_row': retained['rows'].pop()
            elif name == 'shape': row['sources'][0]['shape_id'] = 'rear_right_distal'
            elif name == 'presence': row['controller_contacts'][0]['presence'] = True
            elif name == 'provenance': row['controller_contacts'][1]['provenance']['engine_contact_ids'] = []
            elif name == 'stability': row['stability_contacts'][1]['bears_support'] = False
            elif name == 'callback': row['sources'][0]['callback_sequence'] = 0
            elif name == 'clock': row['commanded_global_step'] += 1
            elif name == 'digest': row['full_step_receipt_sha256'] = 'sha256:' + '0'*64
            elif name == 'session_selection': bad['retained_arm']['walking_sessions'][0]['start_receipt'] = {}
            elif name == 'timeout_label': retained['terminal_timeout_diagnostics_by_session']['walking_resume']['actual_native_contact_gating_without_timeout'] = False
            elif name == 'timeout_counter': row['native_limb_memory'][0]['gate_timeout_count'] = 2
            elif name == 'authority': retained['release_authority'] = True
            cases[name] = bad
        inputs = cls.root / 'reader_cases.json'
        inputs.write_text(json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_recovery_walking_contacts.gd',
                               ['--', *arguments(cls.selection), str(inputs)], 'independent_reader', 60)
        cls.replays = shared.marker(run, 'DEVELOPMENT_WALKING_CONTACT_READER ')

    def test_real_boundaries_and_unchanged_default(self):
        self.assertTrue(self.result['ok'], self.result)
        self.assertTrue(all(self.result['checks'].values()), self.result['checks'])
        self.assertTrue(self.result['synthetic_callback_samples'])
        self.assertTrue(self.result['synthetic_legacy_contact_branch'])
        self.assertFalse(self.result['on_disk_candidate_profile_modified'])
        self.assertEqual(self.selection['candidate']['runtime_binding'], self.result['selected_runtime_binding'])
        self.assertEqual(self.selection['diagnostic_schedule']['walking_contact_profile_id'],
                         self.result['selected_contact_profile_id'])
        self.assertEqual(candidate.read(ROOT / 'sdk/development/recovery_walking_contact_contract_v1.json')['profile_id'],
                         self.result['synthetic_contact_profile_id'])
        for key in ('model_construction_count', 'world_build_count', 'solver_step_count'):
            self.assertEqual(0, self.result[key])
        self.assertFalse(self.result['physical_acceptance_authority'])
        self.assertFalse(self.result['release_authority'])

    def test_independent_contact_reader_and_twelve_negative_controls(self):
        self.assertEqual(13, len(self.replays))
        self.assertTrue(self.replays['positive']['ok'], self.replays)
        self.assertEqual(2, self.replays['positive']['validated_contact_steps'])
        for name, result in self.replays.items():
            if name != 'positive':
                self.assertIs(result['ok'], False, (name, result))

    def test_profile_refuses_unknown_contact_selector_or_missing_entry_retention(self):
        path = candidate.schedule_path(self.selection['candidate']['diagnostic_schedule_id'])
        original = candidate.read(path)
        original_read = candidate.read
        for bad in (True, None, 20, 'unknown', 'missing_entry'):
            changed = copy.deepcopy(original)
            schedule = changed['schedules'][self.selection['candidate']['diagnostic_schedule_id']]
            if bad == 'missing_entry': schedule.pop('walking_entry_profile_id')
            else: schedule['walking_contact_profile_id'] = bad
            with self.subTest(value=bad), patch.object(candidate, 'read', side_effect=lambda p: changed if p == path else original_read(p)):
                with self.assertRaisesRegex(ValueError, 'WALKING_CONTACT_SELECTION'):
                    candidate.selection(self.selection['candidate_profile'])

    def test_consumed_v19_and_r173_remain_exact(self):
        for relative, digest in (
            ('sdk/development/recovery_attempts/013cf8e4b52a46e89e68336d4edb3203.json', '45c493a3713963600d13bbf0ba1aa9b33f7a134c45043de8f483efe57d54c2a4'),
            ('sdk/development/recovery_candidates/v19-ramped-walking-entry-v1.json', '70f4cb55a86a41a02206a729c5b6eb3ad28d52dd07a936cd04f2e9d385c0ff64'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, candidate.sha(ROOT / relative))


if __name__ == '__main__':
    unittest.main()
