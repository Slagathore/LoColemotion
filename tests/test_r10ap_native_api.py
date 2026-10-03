"""Exact candidate GDExtension forwarding under the native-operation lock."""
import sys
import unittest
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10ap_gate_support as native
import test_development_r10q_source_orchestration as shared


class R10APNativeApi(unittest.TestCase):
    run_godot = native.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10ap-native-api-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = native.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        runtime, fixtures = native.runtime()
        assert len(fixtures) == 7
        cls.fixtures = native.verify(native.interface.inputs()[1])
        print('R10AP_NATIVE_API_ROOT ' + cls.out.as_posix(), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = native.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert cls.before == after, 'R10AP_NATIVE_API_SOURCE_DRIFT'

    def test_actual_godot_forwarders_match_core_and_refuse_crossed_schema(self):
        result = self.run_godot('native-api', 'test_r10ap_native_api.gd', self.fixtures, 180)
        self.assertEqual(7, result['new_fixture_calls'])
        self.assertEqual(7, result['negative_calls'])
        self.assertTrue(result['checks']['partial_entry_exact_value'])
        self.assertTrue(result['checks']['partial_step_63_exact_value'])


if __name__ == '__main__':
    unittest.main()
