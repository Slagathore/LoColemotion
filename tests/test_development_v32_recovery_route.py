"""Selected worker scheduler and cold event reader; no physical observations."""
import copy
import json
import unittest
import uuid

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared


class RecoveryRoute(unittest.TestCase):
    policy_id = 'sporespore_balanced_wave_recovery_swing_end_recontact_v1'
    run_label = 'V32'
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def arguments(cls, reader_input=None):
        args = ['--', *arguments(cls.selection), '--walking-policy='+cls.policy_id,
                '--test-label='+cls.run_label]
        return args if reader_input is None else args+[str(reader_input)]

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-'+cls.run_label.lower()+'-route-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print(cls.run_label+'_ROUTE_ROOT', cls.root, flush=True)
        run = cls._run_retained('res://tests/test_development_v32_recovery_route.gd',
                               cls.arguments(), 'producer', 60)
        if not any(line.startswith((cls.run_label+'_ROUTE_PRODUCER ').encode()) for line in run.stdout.splitlines()):
            raise AssertionError(dict(returncode=run.returncode, stderr=run.stderr.decode(errors='replace')[-5000:]))
        cls.producer = shared.marker(run, cls.run_label+'_ROUTE_PRODUCER ')
        cases = {'positive': cls.producer['replay_input']}
        for name in ('legacy_selection', 'unknown_selection', 'wrong_owner', 'missing_event', 'wrong_final_state'):
            item = copy.deepcopy(cases['positive'])
            if name == 'legacy_selection':
                item['policy_id'] = ''
            elif name == 'unknown_selection':
                item['policy_id'] = 'unknown'
            elif name == 'wrong_owner':
                item['events'][-1]['control_owner'] = 'walking_bw5r_b'
            elif name == 'missing_event':
                item['events'].pop()
            else:
                item['final_state']['walking_resume_step_count'] += 1
            cases[name] = item
        inputs = cls.root / 'event_reader_inputs.json'
        inputs.write_text(json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_v32_recovery_route.gd',
                               cls.arguments(inputs), 'cold_reader', 60)
        cls.reader = shared.marker(run, cls.run_label+'_ROUTE_READER ')

    def test_real_worker_scheduler_and_unchanged_prefix_recovery(self):
        self.assertTrue(self.producer['ok'], self.producer['checks'])
        self.assertTrue(all(self.producer['checks'].values()), self.producer['checks'])
        print(self.run_label+'_ROUTE_CHECKS', json.dumps(self.producer['checks'], separators=(',', ':')), flush=True)

    def test_independent_serialized_event_reader_and_five_refusals(self):
        self.assertEqual(49, self.reader['positive']['event_count'])
        self.assertTrue(self.reader['positive']['ok'])
        self.assertEqual(6, len(self.reader))
        for name, result in self.reader.items():
            if name != 'positive':
                self.assertFalse(result['ok'], (name, result))

    def test_python_policy_selection_requires_complete_explicit_pair(self):
        schedule = self.selection['diagnostic_schedule']
        policy = candidate.walking_policy_id(schedule)
        self.assertEqual(self.policy_id, policy)
        for key, value in [('walking_policy_id', ''), ('walking_policy_id', False), ('walking_policy_id', 'unknown'),
                           ('walking_entry_profile_id', ''), ('walking_start_profile_id', ''),
                           ('runtime_sha256', 'sha256:' + '0' * 64),
                           ('walking_policy_contract_sha256', 'sha256:' + '0' * 64),
                           ('walking_replay_profile_id', 'unexpected')]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                candidate.walking_policy_id(dict(schedule, **{key: value}))
        self.assertEqual('', candidate.walking_policy_id({}))

    def test_synthetic_scope_and_original_r173_preserved(self):
        self.assertTrue(self.producer['synthetic_events_only'])
        for key in ('world_build_count', 'solver_step_count'):
            self.assertEqual(0, self.producer[key])
        for key in ('physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.producer[key])
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
