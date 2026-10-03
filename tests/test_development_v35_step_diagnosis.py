"""Cold retained-data checks; never start a controller, engine, or world."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_v35_step_diagnosis as diagnosis

RECORD = ROOT / 'sdk/development/recovery_feasible_support_step_diagnosis_v1.json'
DECISION = ROOT / 'sdk/development/recovery_smooth_swing_selection_v1.json'


class V35StepDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.observed = diagnosis.observe()
        cls.record = json.loads(RECORD.read_bytes())
        cls.data = cls.observed['diagnosis']
        cls.report = json.loads(Path(cls.observed['source_report']['path']).read_bytes())
        cls.coefficients = cls.observed['frozen_lift_coefficients']

    def test_exact_retained_reconstruction_and_no_authority(self):
        # Sorted JSON text retains int/float and signed-zero distinctions.
        self.assertEqual(json.dumps(self.record, sort_keys=True), json.dumps(self.observed, sort_keys=True))
        self.assertEqual((400, 1600, 1600), tuple(self.data[k] for k in
            ('command_count', 'limb_command_count', 'measured_body_sample_count')))
        for key in ('new_world_build_count', 'new_solver_step_count',
                    'new_native_physics_read_count', 'native_controller_call_count'):
            self.assertEqual(0, self.record[key])
        for key in ('original_evaluation_changed', 'physical_cause_proven',
                    'alternative_physical_outcome_predicted', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(False, self.record[key])
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            diagnosis.digest((ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))

    def test_all_cycles_and_correct_command_response_alignment(self):
        cycles = self.data['all_original_contact_cycles']
        self.assertEqual(16, len(cycles))
        self.assertEqual(12, sum(not c['original_minimum_relocation_passed'] for c in cycles))
        stance = [c for c in cycles if c['scheduled_swing_or_landing_command_overlap_count'] == 0]
        self.assertEqual(10, len(stance))
        self.assertEqual(6, sum(c['lowering_participant_command_count'] > 0 for c in stance))
        for c in cycles:
            self.assertEqual(c['liftoff_local_step'], c['applied_command_first'])
            self.assertEqual(c['touchdown_local_step']-1, c['applied_command_last'])
            parts = c['decomposition']['forward_components_m']
            self.assertEqual(c['distal_body_origin_forward_relocation_m'], parts['actual'])
            self.assertAlmostEqual(parts['actual'], sum(v for k, v in parts.items() if k != 'actual'), delta=1e-14)
        evaluation = self.data['original_walking_evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles',
                          'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])

    def test_every_height_conflict_and_incomplete_stance_only_shortcut(self):
        summary = self.data['empty_height_intervals_summary']
        self.assertEqual((94, 86, 8, 0), tuple(summary[k] for k in ('count',
            'stance_only_nonempty_count', 'stance_only_still_empty_count', 'measured_height_below_common_minimum_count')))
        self.assertEqual([['front_right', 'rear_left']], summary['limiting_limb_pairs'])
        self.assertEqual(list(range(296, 362))+list(range(366, 385))+list(range(392, 401)),
            [c['command_local'] for c in self.data['empty_height_intervals']])

    def test_contact_sensitive_goals_are_not_identical_to_applied_references(self):
        transitions = self.data['contact_transitions_during_swing']
        self.assertEqual(8, len(transitions))
        releases = [t for t in transitions if not t['contact_after']]
        self.assertEqual([28, 43, 115, 257, 274], [t['input_command_local'] for t in releases])
        self.assertEqual(5, sum(t['observed_goal_knee_change_rad'] < 0 for t in releases))
        self.assertEqual(3, sum(t['observed_reference_knee_change_rad'] < 0 for t in releases))
        self.assertEqual(2, sum(t['amplitude_after'] > t['amplitude_before'] for t in releases))
        for t in transitions:
            self.assertGreater(t['same_input_loaded_minus_unloaded_goal_knee_rad'], 0)
            self.assertEqual(0., t['proposed_same_input_contact_only_lift_difference_rad'])
        self.assertLessEqual(self.data['existing_lift_fraction_reconstruction_maximum_error'], 1e-14)

    def test_prospective_lift_existing_peak_endpoints_and_domains(self):
        amplitude = 1.1/(.82*1.75+.4)
        for phase in (0, 72, 73, 359):
            self.assertEqual(0., diagnosis.smooth_lift(amplitude, phase, self.coefficients))
        self.assertEqual(1.1, diagnosis.smooth_lift(amplitude, 36, self.coefficients))
        for phase in range(360):
            lift = diagnosis.smooth_lift(amplitude, phase, self.coefficients)
            self.assertGreaterEqual(lift, 0.)
            self.assertLessEqual(lift, 1.1)
        for amplitude_bad, phase_bad in ((math.nan, 0), (math.inf, 1), (-1., 1), (amplitude, -1), (amplitude, 360), (amplitude, math.nan)):
            with self.subTest(amplitude=amplitude_bad, phase=phase_bad), self.assertRaisesRegex(ValueError, 'LIFT_DOMAIN'):
                diagnosis.smooth_lift(amplitude_bad, phase_bad, self.coefficients)

    def test_corrupt_source_alignment_floor_and_prospective_selection(self):
        with mock.patch.object(diagnosis, 'digest', return_value='sha256:'+'0'*64), self.assertRaisesRegex(ValueError, 'CLOSURE_DRIFT'):
            diagnosis.observe()
        with self.assertRaisesRegex(ValueError, 'SOURCE_CROSSED'):
            diagnosis.summarize(dict(self.report, source_commit='0'*40), self.coefficients)
        rows = list(self.report['development_walking_entry']['rows'])
        rows[10] = copy.deepcopy(rows[10])
        rows[10]['request']['floor_reference']['height_world_m'] += 1.
        altered = dict(self.report, development_walking_entry=dict(self.report['development_walking_entry'], rows=rows))
        with self.assertRaises(AssertionError):
            diagnosis.summarize(altered, self.coefficients)
        rows[10] = dict(self.report['development_walking_entry']['rows'][10], session_local_step=12)
        with self.assertRaises(AssertionError):
            diagnosis.summarize(altered, self.coefficients)
        decision = json.loads(DECISION.read_bytes())
        self.assertEqual(diagnosis.digest(RECORD.read_bytes()), decision['source_diagnosis']['raw_sha256'])
        self.assertEqual('V36', decision['selected_successor'])
        self.assertEqual(4, len(decision['finite_remaining_blockers']))
        for key in ('native_component_implemented', 'route_integrated', 'physical_attempt_authorized',
                    'behavioral_threshold_changed', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(False, decision[key])


if __name__ == '__main__':
    unittest.main()
