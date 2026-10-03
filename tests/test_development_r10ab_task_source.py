"""Real R10AB Godot source projection and additive legacy compatibility.

Run under the native-operation lock. Synthetic snapshots use uninserted body
identities; these tests never create a world or advance a solver.
"""
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10ab_native_component as native
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared


class R10ABTaskSource(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10ab-task-source-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        print('R10AB_TASK_SOURCE_ROOT ' + str(cls.out), flush=True)
        runtime, fixtures = native.runtime()
        cls.fixtures = native.verify(runtime['compiled_fixtures'])
        assert len(fixtures) == 5
        # The runtime's generic V20 fixture log is distinct from the original
        # partial entry/step component's six R10K_CONTROL_FIXTURE records.
        old = native.read(ROOT / 'sdk/recovery/r10k_partial_fall_component_implementation_v1.json')
        cls.original = native.verify(next(item for item in old['retained_evidence']
            if item['path'].endswith('development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log')))

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert cls.before == after, 'R10AB_SOURCE_DRIFT'

    def test_actual_partial_source_bridge_and_pre_read_refusals(self):
        result = self.run_godot('partial-source', 'test_development_r10ab_task_source.gd', self.fixtures, 180)
        for index in (0, 1, 2, 3, 5):
            self.assertTrue(result['checks']['select_' + str(index)])
        self.assertTrue(result['checks']['terminal_cannot_create_application'])
        self.assertTrue(result['checks']['crossed_original_entry_refused'])
        self.assertTrue(result['checks']['no_inserted_body'])

    def test_original_partial_source_on_new_dll(self):
        result = self.run_godot('original-partial-source', 'test_development_r10ab_original_partial_source.gd', self.original, 180)
        self.assertEqual(99, len(result['checks']))
        self.assertTrue(result['checks']['default_canonical'])


if __name__ == '__main__':
    unittest.main()
