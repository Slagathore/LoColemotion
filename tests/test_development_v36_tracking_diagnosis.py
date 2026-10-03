"""Cold V36 diagnosis and bounded reference-rate algebra, without native calls."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_v36_tracking_diagnosis as d


class V36TrackingDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads((ROOT/'sdk/development/recovery_smooth_swing_tracking_diagnosis_v1.json').read_bytes())
        cls.observed = d.observe()
        cls.data = cls.observed['diagnosis']
        cls.report = json.loads(Path(cls.record['source_report']['path']).read_bytes())

    def test_exact_reconstruction_and_no_physical_authority(self):
        self.assertEqual(json.dumps(self.record, sort_keys=True), json.dumps(self.observed, sort_keys=True))
        self.assertEqual((400, 1600, 3200, 3192), tuple(self.data[k] for k in ('command_count', 'precommand_limb_sample_count', 'command_joint_count', 'postcommand_joint_response_count')))
        for key in ('native_controller_call_count', 'new_world_build_count', 'new_solver_step_count', 'new_native_physics_read_count'):
            self.assertEqual(0, self.record[key])
        for key in ('original_evaluation_changed', 'physical_cause_proven', 'alternate_physical_outcome_predicted', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.record[key])

    def test_all_native_hold_increments_and_reachable_goals(self):
        episodes = {e['limb']: e for e in self.data['landing_episodes']}
        self.assertEqual({'front_left': (76, 90, 15), 'front_right': (332, 400, 69), 'rear_right': (172, 250, 79)},
                         {k: tuple(v[f] for f in ('first_command', 'last_command', 'count')) for k, v in episodes.items()})
        self.assertEqual(163, sum(e['count'] for e in episodes.values()))
        for e in episodes.values():
            self.assertEqual(0, e['link_reach_projection_count'])
            self.assertEqual(0, e['joint_projection_count'])
            self.assertEqual(e['count'], e['knee_response_error_rad']['count'])
            self.assertEqual(e['first_command']-1, e['first_sample']['measured_trace_local'])
        front = episodes['front_right']
        self.assertEqual(0, front['raw_contact_sample_count'])
        self.assertEqual(0, front['native_support_sample_count'])
        self.assertGreater(front['nominal_actual_clearance_m']['minimum'], 0.)
        self.assertEqual(.0005171831656979042, front['last_sample']['nominal_actual_clearance_m'])
        self.assertEqual(.28910490230649066, front['first_sample']['knee_response_error_rad'])

    def test_original_cycles_stance_losses_and_decomposition(self):
        cycles = self.data['original_contact_cycles']
        self.assertEqual((10, 8, 6), (len(cycles), sum(not c['original_minimum_relocation_passed'] for c in cycles),
            sum(c['scheduled_swing_or_landing_command_overlap_count']==0 for c in cycles)))
        for c in cycles:
            parts = c['decomposition']['forward_components_m']
            self.assertEqual(c['distal_body_origin_forward_relocation_m'], parts['actual'])
            self.assertAlmostEqual(parts['actual'], sum(v for k,v in parts.items() if k!='actual'), delta=1e-15)
        self.assertEqual({'front_left': 37, 'front_right': 0, 'rear_left': 63, 'rear_right': 54},
                         {r['limb']: r['missing_precommand_native_support_count'] for r in self.data['scheduled_stance']})
        self.assertFalse(self.data['original_walking_evaluation']['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'],
                         self.data['original_walking_evaluation']['false_walking_receipts'])

    def test_command_reconstruction_and_proposal_caps_are_not_a_rollout(self):
        self.assertLess(self.data['existing_velocity_law_reconstruction_maximum_error_rad_s'], 1e-14)
        sketch = self.data['prospective_reference_velocity_sketch']
        self.assertEqual((3200, 3123, 8, 0, 280), tuple(sketch[k] for k in ('input_command_count',
            'changed_from_reconstructed_baseline_count', 'unchanged_first_command_count',
            'existing_velocity_saturated_count', 'proposed_velocity_saturated_count')))
        self.assertTrue(sketch['all_proposed_velocities_inside_existing_caps'])
        self.assertFalse(sketch['native_component_implemented'])
        self.assertFalse(sketch['alternate_physical_trajectory_evaluated'])
        for joint in self.data['per_joint']:
            self.assertEqual(399, joint['position_response_error_rad']['count'])
            self.assertEqual(399, joint['motor_velocity_response_error_rad_s']['count'])

    def test_reference_derivative_and_ideal_velocity_servo_identity(self):
        self.assertEqual(0., d.bounded_reference_velocity(.1, .1, 0., 3.5))
        self.assertEqual(3.5, d.bounded_reference_velocity(1., 0., .01, 3.5))
        self.assertEqual(-3.5, d.bounded_reference_velocity(0., 1., .01, 3.5))
        gain, damping = 8., .65
        for rate in (-3., -.2, 0., .2, 3.):
            # For a hypothetical ideal velocity-output actuator, q_dot equals
            # the unclamped geometric motor request. This is not native physics.
            for error in (-.01, 0., .01):
                velocity = rate + gain*error/(1+damping)
                proposed = (1+damping)*rate + gain*error - damping*velocity
                self.assertAlmostEqual(proposed, velocity, delta=1e-14)
        for args in ((1., 0., 0., 3.5), (0., 0., -.1, 3.5), (0., 0., .1, 0.),
                     (math.nan, 0., .1, 3.5), (0., 0., math.inf, 3.5)):
            with self.subTest(args=args), self.assertRaises(ValueError):
                d.bounded_reference_velocity(*args)

    def test_source_floor_and_missing_terminal_response_refuse(self):
        constants = self.record['frozen_servo_constants']
        with self.assertRaisesRegex(ValueError, 'SOURCE_CROSSED'):
            d.sample_rows(dict(self.report, source_commit='wrong'), constants)
        changed = dict(self.report)
        entries = list(self.report['development_walking_entry']['rows'])
        row = copy.deepcopy(entries[10]); row['request']['floor_reference']['height_world_m'] = 1.
        entries[10] = row
        changed['development_walking_entry'] = dict(self.report['development_walking_entry'], rows=entries)
        with self.assertRaises(AssertionError):
            d.sample_rows(changed, constants)
        with mock.patch.object(d, 'digest', return_value='sha256:'+'0'*64), self.assertRaisesRegex(ValueError, 'CLOSURE_DRIFT'):
            d.observe()
        self.assertFalse(d.decompose('front_right', 331, 400, {}, {}, (), [])['available'])


if __name__ == '__main__':
    unittest.main()
