"""Fresh native partial-controller and orchestrator checks for the smoke gate."""
import unittest
import uuid

import test_development_r10aa_complete_report as shared
import test_development_r10q_source_orchestration as process
import r10aa_worker_component as worker


class R10AANativeSafetyComponents(unittest.TestCase):
    run_godot = process.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = shared.native.EVIDENCE / ('r10aa-native-safety-components-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        print('R10AA_NATIVE_SAFETY_COMPONENTS_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before

    def test_fresh_exact_native_calls_and_negative_controls(self):
        result = shared.native.audit(cold=True)
        self.assertEqual((42, 17, 20), (result['cold_replayed'], result['negative_controls'], result['original_partial_calls']))
        shared.write(self.out / 'native-result.json', result)

    def test_actual_orchestrator_crossed_clocks_sources_and_mutations(self):
        record = shared.native.read(worker.RECORD)
        binding = next(row for row in record['retained_evidence'] if row['path'].endswith('/orchestrator-input.json'))
        path = shared.native.verify(binding)
        shared.write(self.out / 'input-binding.json', binding)
        result = self.run_godot('orchestrator', 'test_development_r10aa_orchestrator_refusals.gd', path, 120)
        self.assertEqual(61, len(result['checks']))
        self.assertTrue(all(result['checks'].values()))


if __name__ == '__main__': unittest.main()
