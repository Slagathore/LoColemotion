"""Frozen envelope boundaries and refusal controls; no native world."""
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10j_finite_task_audit as audit


def trace(step=1):
    return dict(global_semantic_step=step, source_measurement=True,
                torso_position_world_m=[0., .4, 0.], torso_forward_axis_world_unit=[1., 0., 0.],
                torso_tilt_rad=0., torso_contact=False, maximum_anchor_error_m=0., maximum_hinge_axis_error_rad=0.)


class FiniteTaskAudit(unittest.TestCase):
    def measure(self, rows):
        return audit.envelope(rows, [0., .4, 0.], [1., 0., 0.])

    def test_all_seven_frozen_envelope_bounds_and_exact_boundaries(self):
        limits = audit.contract()['whole_walking_envelope']
        row = trace()
        row['torso_position_world_m'] = [0., limits['minimum_torso_height_m'], limits['maximum_absolute_lateral_drift_m']]
        row['torso_forward_axis_world_unit'] = [math.cos(limits['maximum_yaw_drift_rad']), 0., math.sin(limits['maximum_yaw_drift_rad'])]
        row['torso_tilt_rad'] = limits['maximum_torso_tilt_rad']
        row['maximum_anchor_error_m'] = limits['maximum_joint_anchor_error_m']
        row['maximum_hinge_axis_error_rad'] = limits['maximum_hinge_axis_error_rad']
        result = self.measure([row])
        self.assertEqual(7, len(result['predicates']))
        self.assertTrue(result['passed'])

    def test_each_envelope_breach_remains_negative_after_return_to_normal(self):
        mutations = {
            'maximum_absolute_lateral_drift_m': {'torso_position_world_m': [0., .4, .251]},
            'maximum_yaw_drift_rad': {'torso_forward_axis_world_unit': [math.cos(.451), 0., math.sin(.451)]},
            'maximum_torso_tilt_rad': {'torso_tilt_rad': .601},
            'minimum_torso_height_m': {'torso_position_world_m': [0., .249, 0.]},
            'maximum_joint_anchor_error_m': {'maximum_anchor_error_m': .0251},
            'maximum_hinge_axis_error_rad': {'maximum_hinge_axis_error_rad': .201},
            'maximum_torso_contact_samples': {'torso_contact': True},
        }
        for key, update in mutations.items():
            with self.subTest(bound=key):
                rows = [trace(1), dict(trace(2), **update), trace(3)]
                result = self.measure(rows)
                self.assertFalse(result['passed'])
                self.assertFalse(result['predicates'][key])
                self.assertEqual(1, sum(not v for v in result['predicates'].values()))

    def test_incomplete_or_invalid_native_trace_is_refused(self):
        for rows in ([], [trace(1), trace(3)], [trace(1), trace(1)],
                     [dict(trace(), source_measurement=False)], [dict(trace(), torso_contact=0)],
                     [dict(trace(), maximum_anchor_error_m=-1.)],
                     [dict(trace(), torso_tilt_rad=float('nan'))],
                     [dict(trace(), torso_tilt_rad=True)],
                     [dict(trace(), torso_forward_axis_world_unit=[0., 1., 0.])]):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                self.measure(rows)

    def test_task_threshold_mutation_is_refused_before_measurement(self):
        changed = audit.TASK.read_bytes().replace(b'0.025', b'0.026')
        self.assertNotEqual(changed, audit.TASK.read_bytes())
        with mock.patch.object(Path, 'read_bytes', return_value=changed):
            with self.assertRaisesRegex(ValueError, 'CONTRACT_DRIFT'):
                self.measure([trace()])

    def test_world_heading_does_not_change_anatomical_lateral_measurement(self):
        row = trace()
        row['torso_position_world_m'] = [-.1, .4, .2]
        row['torso_forward_axis_world_unit'] = [0., 0., 1.]
        result = audit.envelope([row], [0., .4, 0.], [0., 0., 1.])
        self.assertAlmostEqual(.1, result['metrics']['maximum_absolute_lateral_drift_m'])
        self.assertEqual(0., result['metrics']['maximum_yaw_drift_rad'])


if __name__ == '__main__':
    unittest.main()
