"""Native contact records through the actual walking producer and cold reader.

The four retained observations are real, but the bridge containers, body
objects, callback normals and controller poses are explicitly synthetic.
This is not a reconstruction of V20's unretained global walking requests.
"""
import copy
import hashlib
import json
import unittest
import uuid
from unittest.mock import patch

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared


class NativeWalkingContacts(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-native-walking-contacts-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('DEVELOPMENT_NATIVE_WALKING_CONTACT_ROOT', cls.root, flush=True)
        source_path = shared.entry.EVIDENCE / ('development-recovery-smoke-a6ee7a70d3f4412f9ade65ab44e4148c/'
                                              'children/kick_passive_recovery_resume/worker_report.json')
        raw = source_path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != '6f07a600d793d9e35ef08a4d9fcbad5424190d97e5f440c183b6cf721a499ea5':
            raise AssertionError('retained V20 source changed')
        source_report = json.loads(raw)
        bounds = {}
        for packet in source_report['passive_entry']['canonical_packets']:
            text = packet['collection_transport']['source_links']['bound_observation']['utf8_text']
            if json.loads(text)['observation_v3']['semantic_step'] in (380, 381, 840, 841):
                bounds[str(json.loads(text)['observation_v3']['semantic_step'])] = text
        if len(bounds) != 4:
            raise AssertionError('four retained native observations required')
        fixture = cls.root / 'native_sources.json'
        fixture.write_text(json.dumps(dict(source_report_sha256=digest, bounds=bounds,
            synthetic_bridge=True, original_global_request_reconstructed=False), separators=(',', ':')) + '\n', encoding='utf-8')
        del raw, source_report
        run = cls._run_retained('res://tests/test_development_recovery_native_walking_contacts.gd',
            ['--', *arguments(cls.selection), str(fixture)], 'real_interfaces', 90)
        cls.result = shared.marker(run, 'DEVELOPMENT_NATIVE_WALKING_CONTACT_CHECKS ')
        good = cls.result['report']
        cases = {'positive': good}
        for name in ('missing_row', 'source_hash', 'source_model', 'source_body_population', 'native_clock',
                     'controller_contact', 'stability', 'clock', 'digest', 'session_selection',
                     'prefix_raw_response', 'prefix_memory', 'native_memory', 'timeout_label', 'authority'):
            bad = copy.deepcopy(good)
            retained = bad['development_native_walking_contacts']
            row = retained['rows'][1] # Second prefix command exercises real memory chaining.
            if name == 'missing_row': retained['rows'].pop()
            elif name == 'source_hash': row['native_source']['contact_source_sha256'] = 'sha256:' + '0'*64
            elif name == 'source_model': row['native_source']['model_instance_id'] = 'crossed'
            elif name == 'source_body_population': row['native_source']['body_population_instance_sha256'] = 'sha256:' + '0'*64
            elif name == 'native_clock': row['native_source']['observation']['semantic_step'] += 1
            elif name == 'controller_contact': row['controller_contacts'][0]['bears_support'] = not row['controller_contacts'][0]['bears_support']
            elif name == 'stability': row['stability_contacts'][0]['engine_contact_ids'] = ['crossed']
            elif name == 'clock': row['commanded_global_step'] += 1
            elif name == 'digest': row['full_step_receipt_sha256'] = 'sha256:' + '0'*64
            elif name == 'session_selection': bad['retained_arm']['walking_sessions'][0]['start_receipt'] = {}
            elif name == 'prefix_raw_response': row['prefix_control']['raw_native_response_sha256'] = 'sha256:' + '0'*64
            elif name == 'prefix_memory': row['prefix_control']['request']['memory'] = copy.deepcopy(retained['rows'][0]['prefix_control']['request']['memory'])
            elif name == 'native_memory': row['native_limb_memory'][0]['gate_timeout_count'] = -1
            elif name == 'timeout_label': retained['terminal_timeout_diagnostics_by_session']['walking_resume']['actual_native_contact_gating_without_timeout'] = False
            elif name == 'authority': retained['release_authority'] = True
            cases[name] = bad
        inputs = cls.root / 'reader_cases.json'
        inputs.write_text(json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_recovery_native_walking_contacts.gd',
            ['--', *arguments(cls.selection), str(inputs), 'reader'], 'independent_reader', 90)
        cls.replays = shared.marker(run, 'DEVELOPMENT_NATIVE_WALKING_CONTACT_READER ')

    def test_actual_producer_adapter_and_native_controller_boundaries(self):
        self.assertTrue(self.result['ok'], self.result['checks'])
        self.assertTrue(all(self.result['checks'].values()), self.result['checks'])
        self.assertTrue(self.result['synthetic_bridge_and_callback_geometry'])
        self.assertFalse(self.result['original_global_request_reconstructed'])
        for key in ('model_construction_count', 'world_build_count', 'solver_step_count', 'additional_native_physics_read_count'):
            self.assertEqual(0, self.result[key])
        self.assertFalse(self.result['physical_acceptance_authority'])
        self.assertFalse(self.result['release_authority'])

    def test_independent_reader_and_fifteen_negative_controls(self):
        self.assertEqual(16, len(self.replays))
        self.assertTrue(self.replays['positive']['ok'], self.replays)
        self.assertEqual(4, self.replays['positive']['validated_native_contact_steps'])
        self.assertEqual(2, self.replays['positive']['replayed_prefix_commands'])
        for name, result in self.replays.items():
            if name != 'positive':
                self.assertIs(result['ok'], False, (name, result))

    def test_profile_refuses_unknown_contact_selector_or_missing_entry_retention(self):
        path = candidate.schedule_path(self.selection['candidate']['diagnostic_schedule_id'])
        original = candidate.read(path)
        original_read = candidate.read
        for bad in (True, None, 21, 'unknown', 'missing_entry'):
            changed = copy.deepcopy(original)
            schedule = changed['schedules'][self.selection['candidate']['diagnostic_schedule_id']]
            if bad == 'missing_entry': schedule.pop('walking_entry_profile_id')
            else: schedule['walking_contact_profile_id'] = bad
            with self.subTest(value=bad), patch.object(candidate, 'read', side_effect=lambda p: changed if p == path else original_read(p)):
                with self.assertRaisesRegex(ValueError, 'WALKING_CONTACT_SELECTION'):
                    candidate.selection(self.selection['candidate_profile'])

    def test_consumed_v20_and_r173_remain_exact(self):
        for relative, digest in (
            ('sdk/development/recovery_attempts/a6ee7a70d3f4412f9ade65ab44e4148c.json', 'fe46db87e482123b6f94985aa5d0eda68b22d3fa561c8bf97535a1884f4de61d'),
            ('sdk/development/recovery_candidates/v20-bound-walking-contacts-v1.json', 'f85d7212dc89e575ffd552dc36fb1aaab7a5991f1e10605eb64e1c6c42bf6e42'),
            ('sdk/development/recovery_schedules/v20-bound-walking-contacts-v1.json', 'db162efbcd1300abcd963011dec54759db5648ff139515725268f2f372819050'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, candidate.sha(ROOT / relative))


if __name__ == '__main__':
    unittest.main()
