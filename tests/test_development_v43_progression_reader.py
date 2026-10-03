"""Independent cold-reader rejection of rehashed V43 progression corruption."""
import copy
import hashlib
import json
import unittest

import test_development_v43_floor_adapter as shared
from test_development_passive_entry_replay import marker


class ProgressionReader(shared.SupportProgressionFloorAdapter):
    run_label = 'V43-guard'

    def test_progression_memory_and_rehashed_receipt_refusals(self):
        positive = dict(report=self.producer['result']['report'], policy_id=self.policy_id)
        rows = positive['report']['development_walking_entry']['rows']
        index = next(i for i, row in enumerate(rows) if i > 0 and
            row['native_output']['actuation']['receipt']['recovery_support_plane']['support_progression']['phase_progression_held'])
        names = ('missing_receipt', 'schema', 'enabled', 'held', 'source_step',
                 'incoming_count', 'next_count', 'clear_count', 'hold_limit', 'clear_limit',
                 'incoming_phase', 'proposed_phase', 'selected_phase', 'contact_truth', 'missing_support',
                 'missing_next_memory', 'next_memory_count', 'next_memory_kind',
                 'incoming_memory_count', 'missing_initial_memory')
        cases = {'positive': positive}
        api = self.native_api()
        for name in names:
            item = copy.deepcopy(positive)
            row = item['report']['development_walking_entry']['rows'][index]
            act = row['native_output']['actuation']
            support = act['receipt']['recovery_support_plane']
            guard = support['support_progression']
            limb = guard['ordered_limbs'][0]
            next_memory = row['native_output']['next_memory']
            if name == 'missing_receipt': del support['support_progression']
            elif name == 'schema': guard['schema_version'] = 'crossed-schema'
            elif name == 'enabled': guard['enabled'] = not guard['enabled']
            elif name == 'held': guard['phase_progression_held'] = False
            elif name == 'source_step': guard['source_semantic_step'] += 1
            elif name == 'incoming_count': guard['incoming_memory']['held_steps'] += 1
            elif name == 'next_count': guard['next_memory']['held_steps'] += 1
            elif name == 'clear_count': guard['next_memory']['clear_dwell_steps'] += 1
            elif name == 'hold_limit': guard['maximum_held_commands'] += 1
            elif name == 'clear_limit': guard['minimum_clear_dwell_steps'] += 1
            elif name == 'incoming_phase': limb['incoming_phase'] += 1
            elif name == 'proposed_phase': limb['proposed_phase'] += 1
            elif name == 'selected_phase': limb['selected_phase'] += 1
            elif name == 'contact_truth': limb['precommand_contact']['bears_support'] = not limb['precommand_contact']['bears_support']
            elif name == 'missing_support': guard['missing_support_limb_ids'] = ['crossed-limb']
            elif name == 'missing_next_memory': del next_memory['support_progression']
            elif name == 'next_memory_count': next_memory['support_progression']['held_steps'] += 1
            elif name == 'next_memory_kind': next_memory['support_progression']['held_steps'] = True
            elif name == 'incoming_memory_count': row['request']['memory']['support_progression']['held_steps'] += 1
            else: del item['report']['development_walking_entry']['rows'][0]['request']['memory']['support_progression']
            act['receipt_sha256'] = 'sha256:'+hashlib.sha256(api.canonical(act['receipt'])).hexdigest()
            cases[name] = item
        path = self.root/'support_progression_reader_inputs.json'
        with path.open('x', encoding='utf-8') as stream:
            json.dump(cases, stream, separators=(',', ':'), allow_nan=False)
        run = self._run_retained(self.fixture, ['--', str(path)], 'support_progression_cold_reader', 90)
        results = marker(run, 'V34_FLOOR_READER ')
        self.assertEqual(21, len(results))
        self.assertTrue(results['positive']['ok'])
        self.assertEqual(200, results['positive']['replayed_walking_steps'])
        for name, result in results.items():
            if name == 'positive': continue
            expected = ('READER_MEMORY_CHAIN' if name == 'incoming_memory_count' else
                        'READER_RAW_NATIVE_RESPONSE_MISMATCH' if name == 'missing_initial_memory' else
                        'READER_NATIVE_OUTPUT_MISMATCH')
            self.assertFalse(result['ok'], (name, result))
            self.assertEqual('DEVELOPMENT_WALKING_ENTRY_'+expected, result['failure_code'])
        print('V43_PROGRESSION_COLD_READER', json.dumps(dict(positive_steps=200,
            refused_cases={name:r['failure_code'] for name,r in results.items() if name != 'positive'},
            changed_receipts_rehashed=True, synthetic_inputs_only=True,
            world_build_count=0, solver_step_count=0)), flush=True)


def load_tests(_loader, _tests, _pattern):
    return unittest.TestSuite([ProgressionReader('test_progression_memory_and_rehashed_receipt_refusals')])


if __name__ == '__main__':
    unittest.main()
