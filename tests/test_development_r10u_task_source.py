"""Real Godot source selection/projection, without inserted bodies or physics."""
import json
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10r_native_component as native
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared
write = shared.write


class R10UTaskSource(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10u-task-source-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10U_TASK_SOURCE_ROOT', cls.out, flush=True)
        runtime, old = native.read(ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json'), native.read(native.Q_BINDING)
        for item in runtime['source_files']:
            assert native.bind(ROOT / item['path'])['raw_sha256'] == item['raw_sha256']
        for item in [runtime['runtime'], runtime['compiled_fixtures'], old['compiled_fixtures']]:
            assert native.bind(item['path']) == item
        original = native.fixtures(old['compiled_fixtures']['path'], 'R10Q_UPRIGHT_FIXTURE')
        successor = native.fixtures(runtime['compiled_fixtures']['path'], 'R10R_UPRIGHT_FIXTURE')
        assert len(original) == len(successor) == 3
        cls.original = Path(old['compiled_fixtures']['path'])
        cls.fixtures = cls.out / 'source-fixtures.jsonl'
        with cls.fixtures.open('xb') as stream:
            for fixture in [original[0], *successor]:
                stream.write(('R10U_SOURCE_FIXTURE ' + json.dumps(fixture, allow_nan=False) + '\n').encode())

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        assert cls.before == after

    def test_direct_rise_identity_and_corruption_refuse_before_sampler_reads(self):
        result = self.run_godot('direct-task-source', 'test_development_r10u_task_source.gd', self.fixtures, 150)
        for index in (0, 1, 2, 4):
            self.assertTrue(result['checks']['select_' + str(index)])
        self.assertTrue(result['checks']['competing_upright_compositions_refused'])
        self.assertTrue(result['checks']['terminal_cannot_create_application'])

    def test_actual_worker_uses_contiguous_upright_direct_rise_and_standing(self):
        result = self.run_godot('direct-worker', 'test_development_r10u_worker_hooks.gd', self.fixtures, 420)
        self.assertEqual(240, len(result['entry_packets']))
        self.assertEqual(63, len(result['upright_packets']))
        self.assertEqual(60, result['final_upright_memory']['standing_samples_observed'])
        self.assertEqual('fresh_selected_policy_walking_resume', result['final_state']['phase'])
        self.assertFalse(result['selector_and_launcher_validation_exercised'])

    def test_original_q_source_still_passes_on_the_new_dll(self):
        result = self.run_godot('original-q-source', 'test_development_r10u_original_q_source.gd', self.original, 150)
        self.assertTrue(result['checks']['select_3'])
        self.assertTrue(result['checks']['competing_tasks_refused'])


if __name__ == '__main__': unittest.main()
