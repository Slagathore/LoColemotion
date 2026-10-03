"""Independent reconstruction of the exact selected V25 compiled geometry."""
from pathlib import Path
import shutil
import sys
import unittest
import uuid
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10ai_gate_support as native
import r10ai_native_component as component

class ConcurrentGeometry(unittest.TestCase):
    def test_selected_weak_load_rise_and_terminal_geometry(self):
        out = native.EVIDENCE / ('r10ai-concurrent-geometry-' + uuid.uuid4().hex)
        out.mkdir(); print('R10AI_CONCURRENT_GEOMETRY_ROOT ' + out.as_posix(), flush=True)
        before = native.entry._source_snapshot(); native.write(out / 'source-before.json', before)
        binding, fixtures = native.runtime()
        source = native.verify(binding['compiled_fixtures'])
        shutil.copyfile(source, out / 'tests.stdout.txt')
        result = component.kernel.measurements(out)
        native.write(out / 'result.json', dict(measurements=result, source=native.diagnosis.binding(source),
            synthetic_geometry_only=True, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False))
        self.assertEqual(601, result['independent_geometry_reconstructions'])
        self.assertEqual(component.IDS, [row['id'] for row in fixtures])
        after = native.entry._source_snapshot(); native.write(out / 'source-after.json', after)
        self.assertEqual(before, after)

if __name__ == '__main__': unittest.main()
