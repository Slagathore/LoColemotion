"""Original V8 publication chain, native contact recomputation and claim limits."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_rate_limited_recovery_checkpoint as closure


class RateLimitedRecoveryCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(closure.RECORD)
        cls.observed = closure.observe()

    def test_original_pair_and_complete_replays_preserve_behavior_negative(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual([752, 626], [c['solver_steps'] for c in self.observed['children']])
        self.assertEqual(1378, self.observed['solver_step_count'])
        self.assertEqual([], self.observed['metrics']['four_foot_support_global_steps'])
        self.assertEqual(0, self.observed['metrics']['walking_resume_step_count'])
        self.assertEqual('phase_timeout:establish_distal_support', self.observed['metrics']['terminal_reason'])
        timing = self.observed['support_timing']
        rear_left = next(f for f in timing['per_foot_support'] if f['contact_site_id'] == 'rear_left_foot')
        self.assertEqual(0, rear_left['qualifying_sample_count'])
        self.assertEqual(240, timing['active_support_sample_count'])

    def test_changed_outcomes_extra_claims_and_wrong_types_are_refused(self):
        for key, value in [('successful_recovery_proven', True), ('physical_acceptance_authority', True),
                           ('release_authority', True), ('repeat_consumed_attempt_permitted', True),
                           ('solver_step_count', True), ('status', 'passed'), ('new_claim', True)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record, **{key: value}), self.observed)
        changed = copy.deepcopy(self.record)
        changed['support_timing']['cause_proven'] = True
        with self.assertRaises(ValueError):
            closure.smoke.validate_checkpoint(changed, self.observed)

    def test_native_support_recomputation_and_explicit_profile_selection(self):
        original = closure.smoke.read(Path(self.record['kicked_report']['path']))
        with self.assertRaisesRegex(ValueError, 'SUMMARY_CONTROLLER'):
            closure.prior.summarize(original)  # V7 defaults must not silently accept V8.
        changed = dict(original, passive_entry=dict(original['passive_entry']))
        packets = list(original['passive_entry']['canonical_packets'])
        packet = dict(packets[27], step_receipt=copy.deepcopy(packets[27]['step_receipt']))
        packet['step_receipt']['classification']['distal_support_gate'] = True
        packets[27] = packet
        changed['passive_entry']['canonical_packets'] = packets
        for summarize in (closure.summarize, closure.support_timing):
            with self.subTest(summarize=summarize.__name__), self.assertRaisesRegex(ValueError, 'SUPPORT_RECOMPUTATION'):
                summarize(changed)


if __name__ == '__main__':
    unittest.main()
