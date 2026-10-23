"""Independent archived rows and adversarial measurement controls; zero worlds."""
import csv
import math
from pathlib import Path
import unittest

from actuation_measurement import scalar_implicitfast_step, rapier_impulse_summary


class MeasurementTests(unittest.TestCase):
    def test_archived_vh4_complete_cell_matches_scalar_oracle(self):
        # The source trace has its own immutable campaign identity. Reading it
        # checks this new oracle; it neither reruns nor reclassifies VH4.
        trace = Path(__file__).resolve().parents[1] / 'docs/figures/mujoco-force-sampling.csv'
        velocity = 0.0
        with trace.open(newline='') as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual(len(rows), 1800)
        for row in rows:
            predicted = scalar_implicitfast_step(velocity=velocity, target=-.75,
                inertia=1/60, damping=10., force_cap=6., dt=1/600)
            for key, source in (
                ('completed_step_force_nm', 'completed_step_force_nm'),
                ('post_state_force_nm', 'post_state_recomputed_force_nm'),
                ('effective_motor_impulse_nms', 'momentum_inferred_motor_impulse_nms'),
                ('velocity_next_rad_s', 'post_joint_velocity_rad_s'),
            ):
                self.assertAlmostEqual(predicted[key], float(row[source]), delta=2e-12)
            velocity = float(row['post_joint_velocity_rad_s'])

    def test_saturation_uses_completed_sample_not_recomputed_force(self):
        result = scalar_implicitfast_step(velocity=0., target=-.75,
            inertia=1/60, damping=10., force_cap=6., dt=1/600)
        self.assertTrue(result['force_clamped'])
        self.assertAlmostEqual(result['effective_motor_impulse_nms'], -.01)
        self.assertNotAlmostEqual(result['effective_motor_impulse_nms'], result['post_state_force_nm']/600)

    def test_limit_equality_omits_derivative(self):
        result = scalar_implicitfast_step(velocity=0., target=.6,
            inertia=1/60, damping=10., force_cap=6., dt=1/600)
        self.assertTrue(result['force_clamped'])
        self.assertAlmostEqual(result['velocity_next_rad_s'], .6)

    def test_invalid_numeric_inputs(self):
        valid = dict(velocity=0., target=.1, inertia=1., damping=10., force_cap=6., dt=1/600)
        for key in valid:
            for value in [math.nan, math.inf, -math.inf, True, '1']:
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    scalar_implicitfast_step(**(valid | {key: value}))
        for key in ['inertia', 'damping', 'force_cap', 'dt']:
            for value in [0., -1.]:
                with self.assertRaises(ValueError):
                    scalar_implicitfast_step(**(valid | {key: value}))

    def test_final_rapier_readback_does_not_invent_outer_total(self):
        result = rapier_impulse_summary(outer_budget_nms=.05, outer_dt_s=1/120,
            substeps=16, final_readback_nms=.003125)
        self.assertEqual(result['max_force_nm'], 6.)
        self.assertFalse(result['outer_impulse_measured'])
        self.assertIsNone(result['outer_signed_impulse_nms'])

    def test_varying_load_cannot_be_extrapolated_from_last_readback(self):
        sequence = [.001, -.002, .003]
        result = rapier_impulse_summary(outer_budget_nms=.05, outer_dt_s=1/120,
            substeps=3, final_readback_nms=sequence[-1], signed_substep_impulses=sequence)
        self.assertAlmostEqual(result['outer_signed_impulse_nms'], .002)
        self.assertAlmostEqual(result['outer_absolute_impulse_nms'], .006)
        self.assertNotEqual(result['outer_signed_impulse_nms'], 3 * sequence[-1])

    def test_missing_crossed_or_nonfinite_substep_stream_refused(self):
        for sequence in [[.1], [.1, .2], [.1, math.nan]]:
            with self.assertRaises(ValueError):
                rapier_impulse_summary(outer_budget_nms=.5, outer_dt_s=.01,
                    substeps=2, final_readback_nms=.1, signed_substep_impulses=sequence)


if __name__ == '__main__':
    unittest.main()
