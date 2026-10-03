"""Cold replay of the exact native R10R controls and their complete source key."""
import unittest
import uuid
import test_development_r10r_startup_sweep as shared
import r10r_native_component_audit as component

class NativeControl(unittest.TestCase):
    def test_real_native_upright_and_original_entry_controls(self):
        out = shared.EVIDENCE / ('r10r-native-control-' + uuid.uuid4().hex)
        out.mkdir()
        print('R10R_NATIVE_CONTROL_EVIDENCE ' + str(out), flush=True)
        before = shared._source_snapshot()
        shared.write(out / 'source_before.json', before)
        result = component.audit(cold=True)
        shared.write(out / 'result.json', result)
        after = shared._source_snapshot()
        shared.write(out / 'source_after.json', after)
        self.assertEqual(before, after)
        self.assertEqual((3191, 3191, 10), tuple(result[k] for k in ('native_calls', 'cold_replayed', 'negative_controls')))
        self.assertEqual(0, result['physical_world_count'])

if __name__ == '__main__': unittest.main()
