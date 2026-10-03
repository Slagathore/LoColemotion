"""Fresh R10Q native entry, supervisor and retained original-entry controls."""
import unittest
import uuid
import test_development_r10q_startup_sweep as shared
import r10q_upright_native_component as component

class NativeControl(unittest.TestCase):
    def test_real_native_upright_and_original_entry_controls(self):
        out = shared.EVIDENCE / ('r10q-native-control-' + uuid.uuid4().hex)
        out.mkdir()
        print('R10Q_NATIVE_CONTROL_EVIDENCE ' + str(out), flush=True)
        before = shared._source_snapshot()
        shared.write(out / 'source_before.json', before)
        with (out / 'calls.jsonl').open('xb') as stream:
            result = component.run(stream)
        shared.write(out / 'result.json', result)
        after = shared._source_snapshot()
        shared.write(out / 'source_after.json', after)
        self.assertEqual(before, after)
        self.assertEqual(489, result['native_call_count'])
        self.assertEqual(6, len(result['negative_controls']))
        self.assertEqual(3, result['cold_fixture_count'])
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))

if __name__ == '__main__': unittest.main()
