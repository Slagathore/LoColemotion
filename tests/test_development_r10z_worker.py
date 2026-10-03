"""R10Z actual worker sequences on synthetic sources; run under operation lock."""
import json
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10z_native_component as native
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared

class R10ZWorker(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10z-worker-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        print('R10Z_WORKER_ROOT ' + str(cls.out), flush=True)
        native.runtime()
        record = native.read(ROOT / 'sdk/recovery/r10k_partial_fall_component_implementation_v1.json')
        cls.fixtures = native.verify(next(item for item in record['retained_evidence']
            if item['path'].endswith('development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log')))

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert cls.before == after, 'R10Z_WORKER_SOURCE_DRIFT'

    def run_worker(self, name, script, branch):
        output = self.out / (name + '.json')
        args = [str(shared.GODOT), '--headless', '--path', str(ROOT), '--script',
                'res://tests/' + script, '--', str(self.fixtures), str(output), branch]
        started = time.monotonic()
        with (self.out / (name + '.stdout.log')).open('xb') as stdout, (self.out / (name + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(args, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=180,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                shared.write(self.out / (name + '.execution.json'), dict(command=args, timed_out=True,
                    direct_process_killed_and_reaped=True))
                raise
        shared.write(self.out / (name + '.execution.json'), dict(command=args, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (name + '.stderr.log')).read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads(output.read_text(encoding='utf-8'))
        self.assertTrue(result['ok'], result.get('failure'))
        self.assertTrue(result['checks'] and all(result['checks'].values()))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])
        if branch == 'partial':
            self.assertEqual(63, len(result['partial_packets']))
            self.assertEqual(240, len(result['entry_packets']))
            self.assertEqual(60, result['final_partial_memory']['standing_samples_observed'])
        else:
            self.assertEqual(1, len(result['entry_packets']))
            self.assertEqual([], result['partial_packets'])
        return result

    def test_new_partial_worker(self):
        self.run_worker('new-partial', 'test_development_r10z_worker_hooks.gd', 'partial')

    def test_new_prone_worker(self):
        self.run_worker('new-prone', 'test_development_r10z_worker_hooks.gd', 'prone')

    def test_original_partial_worker(self):
        self.run_worker('original-partial', 'test_development_r10z_legacy_worker_hooks.gd', 'partial')

    def test_original_prone_worker(self):
        self.run_worker('original-prone', 'test_development_r10z_legacy_worker_hooks.gd', 'prone')

if __name__ == '__main__':
    unittest.main()
