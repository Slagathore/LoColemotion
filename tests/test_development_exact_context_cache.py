"""Zero-world real-context/original-validator benchmark; no physical entrypoint."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'tests'))
import development_recovery_smoke as smoke
import qsdk_r10f_l14_runtime_binding as runtime
from test_development_recovery_smoke import native


class ExactContextCache(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        checkpoint = smoke.read(ROOT / 'sdk/development_recovery_step_cost_checkpoint_v1.json')
        smoke.validate_checkpoint(checkpoint, smoke.retained_checkpoint(Path(checkpoint['evidence_root'])))
        runtime.bind_runtime(Path(runtime.IMAGES['godot_console']['path']))
        run = native('tests/test_development_exact_context_cache.gd', timeout=90)
        sys.stdout.buffer.write(run.stdout)
        sys.stdout.buffer.flush()
        if run.returncode or b'ERROR:' in run.stdout + run.stderr:
            raise AssertionError((run.returncode, run.stdout[-5000:], run.stderr))
        prefix = 'DEVELOPMENT_EXACT_CONTEXT_CACHE '
        rows = [line[len(prefix):] for line in run.stdout.decode('utf-8').splitlines() if line.startswith(prefix)]
        if len(rows) != 1:
            raise AssertionError(('EXPECTED_ONE_BENCHMARK', rows))
        cls.report = json.loads(rows[0])

    def test_original_validators_and_all_invalidation_controls(self):
        self.assertIs(self.report['ok'], True)
        self.assertGreaterEqual(len(self.report['checks']), 60)
        self.assertTrue(all(value is True for value in self.report['checks'].values()), self.report['checks'])

    def test_retained_and_fresh_contexts_each_exercise_both_predicates(self):
        self.assertEqual(2, len(self.report['sources']))
        self.assertEqual(3, len(self.report['benchmarks']))
        for row in self.report['benchmarks']:
            self.assertEqual([0, 1], [method['predicate'] for method in row['methods']])
            for method in row['methods']:
                self.assertEqual(8, method['hits'])
                self.assertEqual(1, method['full_checks'])
                self.assertGreater(method['key_bytes'], 0)
                for field in ('full_total_us', 'cold_us', 'hit_total_us'):
                    self.assertIs(type(method[field]), int)
                    self.assertGreater(method[field], 0)
        # Timing is descriptive: a noisy machine must not change a correctness gate.

    def test_zero_world_and_no_authority(self):
        for key in ('model_construction_count', 'world_build_count', 'native_physics_read_count', 'solver_step_count'):
            self.assertIs(type(self.report[key]), int)
            self.assertEqual(0, self.report[key])
        for key in ('physical_path_cache_installed', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(self.report[key], False)


if __name__ == '__main__':
    unittest.main()
