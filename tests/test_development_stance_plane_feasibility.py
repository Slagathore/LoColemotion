"""Reject an incomplete geometric proposal before another physical attempt."""
import json
import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_stance_plane_feasibility as plane


class StancePlaneFeasibility(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = plane.observe()

    def test_retained_complete_population_and_actual_joint_limit_rejection(self):
        result = self.result
        self.assertEqual(json.loads((ROOT/'sdk/development/recovery_stance_plane_feasibility_v1.json').read_bytes()), result)
        self.assertEqual(list(range(1, 401)), [r['command_local'] for r in result['rows']])
        self.assertEqual(15, result['target_count_outside_original_joint_limits'])
        self.assertEqual(1.1, result['original_joint_limits']['knee_upper_limit_rad'])
        self.assertEqual(.72, result['original_joint_limits']['hip_upper_limit_rad'])
        self.assertAlmostEqual(1.2210827432409743, result['maximum_proposed_knee_rad'], places=13)
        self.assertLess(result['maximum_absolute_proposed_hip_rad'], .72)
        self.assertLess(result['maximum_nominal_plane_residual_m'], 1e-14)
        self.assertEqual('reject_unclipped_proposal_as_ready_to_run_controller', result['decision'])

    def test_zero_amplitude_is_not_silently_a_safe_startup(self):
        first = self.result['rows'][0]
        self.assertEqual(0, first['original_amplitude'])
        self.assertTrue(any(t['proposed_knee_rad'] > 0 for t in first['proposed_targets']))
        for field in ('registered_controller', 'physical_attempt_authorized', 'physical_outcome_predicted',
                      'original_evaluation_changed', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.result[field])
        for field in ('world_build_count', 'solver_step_count', 'additional_native_physics_read_count'):
            self.assertEqual(0, self.result[field])

    def test_independent_endpoint_geometry_and_yaw_invariance(self):
        directions = dict.fromkeys(plane.original.LIMBS, 0.)
        for upper in (.168, .1925):
            dimensions = (upper, .35-upper, .04, 1.)
            for roll in (0., -.1, .1):
                q = dict(x=math.sin(roll/2), y=0., z=0., w=math.cos(roll/2))
                pose = dict(position_m=dict(x=0., y=.39, z=0.), orientation_xyzw=q)
                proposal = plane.propose(pose, directions, dimensions)
                posed = dict(pose, position_m=dict(x=0., y=proposal['proposed_torso_height_m'], z=0.))
                for target in proposal['proposed_targets']:
                    _, bottom = plane.original.geometry.ideal_distal(posed, target['limb'], target['proposed_hip_rad'], target['proposed_knee_rad'], *dimensions)
                    self.assertAlmostEqual(0, bottom, places=14)
                # Premultiply by a world-Y quarter turn. Geometry is yaw invariant.
                s = math.sqrt(.5)
                yaw_pose = dict(pose, orientation_xyzw=dict(x=s*q['x'], y=s*q['w'], z=-s*q['x'], w=s*q['w']))
                yaw = plane.propose(yaw_pose, directions, dimensions)
                self.assertAlmostEqual(proposal['proposed_torso_height_m'], yaw['proposed_torso_height_m'], places=14)
                for a, b in zip(proposal['proposed_targets'], yaw['proposed_targets']):
                    # Inverse cosine is ill-conditioned at a perfectly straight
                    # knee. Endpoint checks above remain at metric precision.
                    self.assertAlmostEqual(a['proposed_hip_rad'], b['proposed_hip_rad'], delta=1e-7)
                    self.assertAlmostEqual(a['proposed_knee_rad'], b['proposed_knee_rad'], delta=1e-7)

    def test_invalid_geometric_input_refuses(self):
        pose = dict(orientation_xyzw=dict(x=0., y=0., z=0., w=1.))
        for directions, dimensions in (({}, (.175, .175, .04, 1.)),
                ({'wrong_limb': 0.}, (.175, .175, .04, 1.)),
                ({'rear_left': float('nan')}, (.175, .175, .04, 1.)),
                ({'rear_left': 0.}, (0., .175, .04, 1.))):
            with self.assertRaisesRegex(ValueError, 'STANCE_PLANE_DOMAIN'):
                plane.propose(pose, directions, dimensions)
        with self.assertRaisesRegex(ValueError, 'STANCE_PLANE_NON_DOWNWARD_DIRECTION'):
            plane.propose(pose, {'rear_left': math.pi}, (.175, .175, .04, 1.))


if __name__ == '__main__':
    unittest.main()
