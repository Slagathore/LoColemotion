"""Cold performance receipts only: never rebuild, rerun a reader, or step physics."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_passive_entry_profile as entry
import development_recovery_candidate as candidate


class RecoveryPerformance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = entry.read(ROOT / 'sdk/development/recovery_performance_v1.json')
        cls.receipts = {}
        for name, binding in cls.record['artifacts'].items():
            path = Path(binding['path'])
            if not path.resolve().is_relative_to(entry.EVIDENCE) or entry.runtime.file_identity(path) != binding:
                raise AssertionError(('PERFORMANCE_ARTIFACT_DRIFT', name))
            cls.receipts[name] = entry.read(path)

    def test_original_readers_remain_valid_without_adopting_slower_experiment(self):
        final_states = []
        for key in ['baseline', 'experimental']:
            receipt = self.receipts['reader_' + key]
            report = Path(receipt['original_replay_bindings'][0]['path']).parent.parent / 'worker_report.json'
            directory = Path(self.record['artifacts']['reader_' + key]['path']).parent
            replay = entry.consume_replay(report, diagnostic_directory=directory)
            self.assertEqual(626, replay['transition_count'])
            final_states.append(replay['final_state_sha256'])
            self.assertEqual(receipt['elapsed_seconds'], self.record['full_reader_observations_seconds'][key])
        self.assertEqual(final_states[0], final_states[1])
        reader = (ROOT / 'sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd').read_text()
        self.assertNotIn('development_exact_value_comparison_v1.gd', reader)
        self.assertTrue(self.record['decisions']['recursive_gdscript_comparison'].startswith('reject_'))

    def test_benchmark_populations_source_bindings_and_no_authority(self):
        for name in ['single_pass_benchmark', 'optimized_benchmark']:
            receipt = self.receipts[name]
            self.assertEqual(546, receipt['exact_output_case_count'])
            self.assertEqual(2, receipt['refusal_case_count'])
            self.assertEqual([0, 1, 1, 0], [row['runtime_index'] for row in receipt['timings']])
            for row in receipt['timings']:
                self.assertEqual(80, row['logical_calls'])
                self.assertGreater(row['elapsed_seconds'], 0)
            for field in ['declaration', 'source_snapshot', 'report']:
                binding = receipt[field]
                self.assertEqual(binding, entry.runtime.file_identity(Path(binding['path'])))
            self.assertIs(receipt['source_unchanged'], True)
            self.assertIs(receipt['complete_reader_replayed'], False)
            for field in ['world_build_count', 'native_physics_read_count', 'solver_step_count']:
                self.assertEqual(0, receipt[field])
            for field in ['original_attempt_reclassified', 'physical_acceptance_authority', 'release_authority']:
                self.assertIs(receipt[field], False)
        self.assertEqual(6, self.receipts['optimized_benchmark']['exact_control_fixture_count'])
        for field in ['physical_speedup_measured', 'physical_acceptance_authority', 'qualification_authority', 'release_authority']:
            self.assertIs(self.record[field], False)

    def test_connected_checks_and_immutable_build_artifacts(self):
        counts = dict(comparator_controls=3, comparator_integration=8, single_pass_runtime=4,
                      optimized_runtime=4, optimized_replay=8, build_mode_controls=3)
        for name, count in counts.items():
            receipt = self.receipts[name]
            self.assertIs(receipt['passed'], True)
            self.assertEqual(count, receipt['test_count'])
            self.assertEqual(0, receipt['exit_code'])
            self.assertIs(receipt['timed_out'], False)
            directory = Path(self.record['artifacts'][name]['path']).parent
            for stream in ['stdout', 'stderr']:
                self.assertEqual('sha256:' + receipt[stream + '_sha256'],
                                 entry.digest((directory / receipt[stream]).read_bytes()))
        for field in ['single_pass_profile', 'optimized_profile']:
            selected = candidate.selection(candidate.reference_for_path(ROOT / self.record[field]))
            binding = entry.binding(selected)
            self.assertEqual(220, binding['core_test_count'])
            for artifact in binding['build_evidence_files']:
                self.assertEqual(artifact, entry.runtime.file_identity(Path(artifact['path'])))
            for flag in ['default_godot_extension_changed', 'old_pinned_adapter_overwritten',
                         'qualification_authority', 'physical_acceptance_authority', 'release_authority']:
                self.assertIs(binding[flag], False)


if __name__ == '__main__':
    unittest.main()
