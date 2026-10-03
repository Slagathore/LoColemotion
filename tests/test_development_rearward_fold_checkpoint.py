"""Cold full-population closure and independently recomputed support checks."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_rearward_fold_checkpoint as closure


class RearwardFoldCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(closure.RECORD)
        cls.observed = closure.observe()

    def test_whole_original_population_replay_and_negative_outcome(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual([752, 653], [child['solver_steps'] for child in self.observed['children']])
        self.assertEqual(1405, self.observed['solver_step_count'])
        self.assertEqual(294, self.observed['metrics']['canonical_observation_count'])
        self.assertEqual(6, len(self.observed['metrics']['four_foot_support_global_steps']))
        self.assertEqual(0, self.observed['metrics']['stable_stance_sample_count'])
        self.assertEqual('phase_timeout:stance_dwell', self.observed['metrics']['terminal_reason'])

    def test_record_rejects_extra_claims_changed_results_and_wrong_kinds(self):
        for key, value in [('successful_recovery_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True),
                           ('solver_step_count', True), ('status', 'passed'), ('new_claim', True)]:
            changed = dict(self.record, **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(changed, self.observed)

    def test_support_count_is_recomputed_from_native_contacts(self):
        original = closure.smoke.read(Path(self.record['kicked_report']['path']))
        # Shallow-copy the large immutable population; alter only one supplied
        # test classification. The original on-disk report is never written.
        changed = dict(original, passive_entry=dict(original['passive_entry']))
        packets = list(original['passive_entry']['canonical_packets'])
        index = next(i for i, packet in enumerate(packets) if packet['step_receipt']['classification']['distal_support_gate'])
        packet = dict(packets[index], step_receipt=copy.deepcopy(packets[index]['step_receipt']))
        packet['step_receipt']['classification']['distal_support_gate'] = False
        packets[index] = packet
        changed['passive_entry']['canonical_packets'] = packets
        with self.assertRaisesRegex(ValueError, 'SUPPORT_RECOMPUTATION'):
            closure.summarize(changed)


if __name__ == '__main__':
    unittest.main()
