"""Actual Godot comparator parity and bounded retained-record microbenchmark."""
import unittest
import uuid

import test_development_passive_entry_replay as shared
from development_recovery_candidate_test_support import selected, arguments

REPORT = shared.entry.EVIDENCE / 'development-recovery-smoke-46cc3bddeed5433d8c25f6f3ae16e11c/children/kick_passive_recovery_resume/worker_report.json'
REPORT_SHA = 'sha256:0cfacdd8cab241f50e9623168d6551f74ca04ae51fe6f723b059ec6a1126e267'


class ExactValueComparison(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        if shared.entry.runtime.file_identity(REPORT)['raw_sha256'] != REPORT_SHA:
            raise AssertionError('COMPARATOR_ORIGINAL_REPORT_DRIFT')
        cls.root = shared.entry.EVIDENCE / ('development-exact-value-comparison-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('EXACT_VALUE_COMPARISON_ROOT', cls.root, flush=True)
        selection = selected()
        run = cls._run_retained('res://tests/test_development_exact_value_comparison.gd',
            ['--', str(REPORT), *arguments(selection)], 'comparison', 180)
        cls.result = shared.marker(run, selection['replay_marker'])

    def test_scalar_container_and_depth_semantics_match_original_serializer(self):
        self.assertEqual(1225, self.result['unit_pair_count'])
        self.assertIs(self.result['depth_fallback_passed'], True)

    def test_complete_retained_transport_population_and_corruptions_agree(self):
        self.assertEqual(801, self.result['retained_pair_count'])
        self.assertEqual(REPORT_SHA, self.result['input_raw_sha256'])
        self.assertIs(self.result['original_attempt_reclassified'], False)
        self.assertEqual(0, self.result['world_build_count'])
        self.assertEqual(0, self.result['solver_step_count'])

    def test_benchmark_population_is_complete_without_performance_threshold(self):
        self.assertEqual([False, True, True, False], [t['optimized'] for t in self.result['timings']])
        for timing in self.result['timings']:
            self.assertEqual(80, timing['comparisons'])
            self.assertEqual(80, timing['accepted'])
            self.assertGreater(timing['elapsed_us'], 0)


if __name__ == '__main__':
    unittest.main()
