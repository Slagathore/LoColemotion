"""Reconstruct V56 native compatibility and boundaries on the exact R10V DLL."""
import unittest
import uuid
import sys
from pathlib import Path

# Each production stage starts a fresh interpreter with no inherited test path.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import v56_extended_preparation_audit as component
import r10s_startup_component as files
class NativeControl(unittest.TestCase):
    def test_actual_native_original_histories_and_v56_boundaries(self):
        out=files.EVIDENCE/('r10v-native-control-'+uuid.uuid4().hex);out.mkdir()
        print('R10V_NATIVE_CONTROL '+str(out),flush=True)
        before=files._source_snapshot();files.write(out/'source_before.json',before)
        result=component.audit(cold=True);files.write(out/'result.json',result)
        after=files._source_snapshot();files.write(out/'source_after.json',after)
        self.assertEqual(before,after)
        self.assertEqual((414,103,20594,20594),tuple(result[k] for k in ['core_tests','compiled_sources','native_step_calls','cold_replayed']))
        self.assertEqual(0,result['world_build_count'])
if __name__=='__main__':unittest.main()
