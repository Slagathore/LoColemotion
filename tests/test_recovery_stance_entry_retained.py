"""Regressions from the real R10H producer and both separately replayed reports."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import recovery_stance_entry_retained_replay as retained


class RetainedStanceEntry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = retained.consume(retained.EVIDENCE / 'r10h-stance-entry-retained-replay-283f9d0fb22246cdb6d96fbcd4eeb3aa')
        cls.kicked = retained.consume(retained.EVIDENCE / 'r10h-stance-entry-retained-replay-696c00ec05844f508c59d43287df1cd8')

    def test_original_pair_keeps_its_consumed_reader_failure(self):
        original = retained.entry.read(retained.ATTEMPT / 'supervisor_result.json')
        self.assertFalse(original['ok'])
        self.assertEqual('SMOKE_ENTRY_REPLAY_FAILED:matched_no_kick_continuation', original['failure_code'])
        self.assertIsNone(original['independent_audit'])
        self.assertEqual([0, 0], [c['exit_code'] for c in original['children']])
        self.assertEqual(161, sum(s['test_count'] for s in original['safety_stages']))

    def test_no_kick_replays_complete_timeline_and_remains_negative(self):
        r = self.baseline
        self.assertEqual(512, r['transition_count'])
        self.assertEqual(240, r['stance_entry_replay']['replayed_neutral_commands'])
        self.assertEqual(0, r['stance_entry_independent_measurement']['ready_samples'])
        self.assertEqual('walking_not_reached', r['finite_walking_measurement']['status'])
        self.assertFalse(r['original_attempt_reclassified'])

    def test_kicked_replays_complete_timeline_cycle_and_stop(self):
        r = self.kicked
        self.assertEqual(2015, r['transition_count'])
        self.assertEqual(1157, r['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(1, r['stance_entry_independent_measurement']['ready_samples'])
        self.assertTrue(r['finite_walking_measurement']['planned_cycle_predicate'])
        self.assertTrue(r['finite_walking_measurement']['complete_stop_predicate'])
        self.assertFalse(r['physical_acceptance_authority'])

    def test_actual_producer_rounding_reproduces_all_240_samples(self):
        path = retained.EVIDENCE / 'r10h-readiness-transport-diagnosis-f9e764f9c464469e8330fa9581951b7b/stdout.txt'
        marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
        rows = [json.loads(s[len(marker):]) for s in path.read_text(encoding='utf-8').splitlines() if s.startswith(marker)]
        self.assertEqual(1, len(rows))
        r = rows[0]
        self.assertEqual(240, r['default_compilation_matches'])
        self.assertEqual(0, r['exact_compilation_matches'])
        self.assertEqual(r['first_difference']['retained_sha256'], r['first_difference']['default_sha256'])
        self.assertEqual(r['first_difference']['retained']['checks'], r['first_difference']['exact']['checks'])

    def test_independent_measurement_rejects_changed_readiness_geometry_and_clock(self):
        report = retained.entry.read(retained.ATTEMPT / 'children/matched_no_kick_continuation/worker_report.json')
        row = report['stance_entry']['readiness_rows'][0]
        sys.path.insert(0, str(ROOT / 'sdk/python'))
        from sporespore_locomotion import LocomotionCore
        chosen = retained.selection_for_retained_report(report)
        compiled = LocomotionCore(retained.entry.binding(chosen)['runtime']['path']).compile_bounded_quadruped(report['configuration']['base_descriptor'])
        limits = retained.entry.read(ROOT / 'sdk/recovery/r10h_stance_entry_finite_cycle_contract_v1.json')['stance_entry']
        for kind in ('readiness', 'geometry', 'clock'):
            changed = copy.deepcopy(row)
            if kind == 'readiness': changed['source']['readiness']['ready'] = True
            elif kind == 'geometry': changed['source']['readiness']['ordered_legs'][0]['maximum_required_reach_m'] += .001
            else: changed['global_semantic_step'] += 1
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                retained.entry.verify_entry_measurements([changed], compiled, limits)


if __name__ == '__main__':
    unittest.main()
