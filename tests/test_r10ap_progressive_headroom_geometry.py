"""Independent reconstruction of the exact selected V28 progressive-headroom geometry."""
from pathlib import Path
import sys
import unittest
import uuid
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10ap_gate_support as native
import r10ap_native_component as component

class ProgressiveHeadroomGeometry(unittest.TestCase):
    def test_selected_joint_deficits_and_geometry_cost_tradeoff(self):
        out = native.EVIDENCE / ('r10ap-concurrent-geometry-' + uuid.uuid4().hex)
        out.mkdir(); print('R10AP_CONCURRENT_GEOMETRY_ROOT ' + out.as_posix(), flush=True)
        before = native.entry._source_snapshot(); native.write(out / 'source-before.json', before)
        binding, fixtures = native.runtime()
        source = native.verify(binding['compiled_fixtures'])
        result = component.geometry(binding)
        native.write(out / 'result.json', dict(measurements=result, source=native.diagnosis.binding(source),
            synthetic_geometry_only=True, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False))
        self.assertEqual(600, result['compiled_geometry_comparisons'])
        self.assertEqual(dict(recover_joint_headroom=593, raise_with_headroom=4, explicit_v23_fallback=3), result['modes'])
        self.assertEqual(492, result['geometry_cost_increases'])
        self.assertLess(result['maximum_target_error_rad'], 1e-10)
        self.assertEqual(component.IDS, [row['id'] for row in fixtures])
        after = native.entry._source_snapshot(); native.write(out / 'source-after.json', after)
        self.assertEqual(before, after)

if __name__ == '__main__': unittest.main()
