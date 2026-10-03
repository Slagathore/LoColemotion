"""The consumed R10J pair stays verifiable through its retained post-exposure replays; zero worlds."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import recovery_settled_hold_retained_replay as retained

NO_KICK = retained.EVIDENCE / 'r10j-settled-hold-retained-replay-7ed81384c7b145509477fe0ee698bd65'
KICKED = retained.EVIDENCE / 'r10j-settled-hold-retained-replay-01646fe215ab4695b9d7bf3dc516c28f'
DEVELOPMENT_FAILURES = ('r10j-settled-hold-retained-replay-684139b3d12d44689b4b0bf8f63d71d0',
                        'r10j-settled-hold-retained-replay-4db1384e2c9f4c60b09a39eb837583be')


class SettledHoldRetained(unittest.TestCase):
    def test_no_kick_retained_replay_verifies_ramp_hold_and_fresh_v50_walk(self):
        result = retained.consume(NO_KICK)
        self.assertTrue(result['ok'], result.get('failure_code'))
        self.assertEqual('matched_no_kick_continuation', result['role'])
        self.assertEqual(1706, result['transition_count'])
        stance = result['stance_entry_replay']
        self.assertEqual((164, 182, 346), (stance['replayed_neutral_commands'], stance['replayed_hold_commands'], stance['recomputed_readiness_samples']))
        self.assertEqual(64, result['stance_entry_independent_measurement']['ready_samples'])
        walking = result['finite_walking_measurement']
        self.assertEqual((1088, 968, 120), (walking['command_count'], walking['cycle_end_command'], walking['stopping_commands']))
        self.assertTrue(walking['planned_cycle_predicate'] and walking['complete_stop_predicate'] and walking['body_forward_predicate'])
        self.assertAlmostEqual(0.16501597589527936, walking['pre_first_to_post_last_body_forward_m'], places=12)
        self.assertTrue(result['finite_recovery_task']['cycle_and_stop_boundary_reached'])
        self.assertEqual('r10j_exact_descriptor_compilation_v1', result['post_exposure_reader']['profile_id'])
        self.assertFalse(result['post_exposure_reader']['original_attempt_reclassified'])
        self.assertEqual(0, result['world_build_count'])
        self.assertEqual(0, result['solver_step_count'])

    def test_kicked_retained_replay_verifies_unchanged_recovery_and_walk(self):
        result = retained.consume(KICKED)
        self.assertTrue(result['ok'], result.get('failure_code'))
        self.assertEqual('kick_passive_recovery_resume', result['role'])
        self.assertEqual(2015, result['transition_count'])
        walking = result['finite_walking_measurement']
        self.assertEqual((1157, 1037, 120), (walking['command_count'], walking['cycle_end_command'], walking['stopping_commands']))
        self.assertAlmostEqual(0.11979749426988978, walking['pre_first_to_post_last_body_forward_m'], places=12)
        self.assertEqual(1, result['stance_entry_independent_measurement']['ready_samples'])

    def test_reader_development_failures_are_retained_and_refused(self):
        for name in DEVELOPMENT_FAILURES:
            directory = retained.EVIDENCE / name
            execution = json.loads((directory / 'execution.json').read_text(encoding='utf-8'))
            self.assertEqual(1, execution['returncode'], name)
            with self.assertRaises(ValueError):
                retained.consume(directory)

    def test_consumer_refuses_rewritten_retained_output(self):
        with tempfile.TemporaryDirectory() as scratch:
            copy = Path(scratch) / NO_KICK.name
            shutil.copytree(NO_KICK, copy)
            with (copy / 'stdout.txt').open('ab') as stream:
                stream.write(b'\n')
            with self.assertRaisesRegex(ValueError, 'RETAINED_OUTPUT_BINDING'):
                retained.consume(copy)


if __name__ == '__main__':
    unittest.main()
