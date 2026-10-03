"""Cold retained-data diagnosis; no native runtime or physical rerun."""
import math
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_v32_placement_diagnosis as diagnosis


class PlacementDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = diagnosis.observe()

    def test_complete_measured_population_and_explicit_decomposition(self):
        result = self.result
        retained = json.loads((ROOT / 'sdk/development/recovery_swing_end_placement_diagnosis_v1.json').read_text())
        self.assertEqual(retained, result)
        self.assertEqual(1600, result['measured_body_sample_count'])
        self.assertLess(result['coordinate_conversion_maximum_axis_difference'], 1e-6)
        self.assertEqual((13, 7, 6), (len(result['counted_cycles']), result['failed_cycle_count'], result['failed_cycles_started_during_scheduled_stance']))
        self.assertEqual(['every_limb_forward_relocation', 'terminal_four_contact_recovery'], result['original_false_walking_receipts'])
        for cycle in result['counted_cycles']:
            for field in ('forward_components_m', 'clearance_change_components_m'):
                parts = cycle[field]
                self.assertAlmostEqual(parts['actual'], sum(v for k, v in parts.items() if k != 'actual'), places=14)
            self.assertEqual(0, cycle['raw_contact_sample_count'])
        bad = next(c for c in result['counted_cycles'] if c['limb'] == 'rear_right' and c['liftoff_trace_local'] == 249)
        self.assertEqual(92, bad['liftoff_command_phase'])
        for key, expected in {'actual': -.06026139352460369, 'torso_translation': -.01670620286749802,
                              'torso_rotation_at_initial_joints': -.03526222936337962,
                              'joint_change_at_final_pose': -.00715839971709118,
                              'ideal_constraint_residual': -.0011345615766348736}.items():
            self.assertAlmostEqual(expected, bad['forward_components_m'][key], places=14)

    def test_contact_switch_formula_without_claiming_touchdown_cause(self):
        result = self.result
        self.assertEqual(1600, result['verified_knee_command_count'])
        self.assertLess(result['maximum_knee_formula_error_rad'], 1e-12)
        self.assertEqual([('front_left', 28), ('front_left', 34), ('front_left', 41),
                          ('front_right', 269), ('front_right', 302)],
                         [(s['limb'], s['input_trace_local']) for s in result['swing_contact_target_discontinuities']])
        first = next(c for c in result['counted_cycles'] if c['limb'] == 'front_left' and c['liftoff_trace_local'] == 28)
        self.assertGreater(first['knee_start_end_rad'][1], first['knee_start_end_rad'][0])
        self.assertGreater(first['clearance_change_components_m']['joint_change_at_final_pose'], 0)
        self.assertLess(first['clearance_change_components_m']['actual'], 0)
        self.assertLess(first['nominal_floor_clearance_max_m'], .001)
        self.assertFalse(result['physical_cause_proven'])
        self.assertFalse(result['alternate_physical_outcome_predicted'])

    def test_relaxed_reach_bound_is_geometry_not_future_motion(self):
        dimensions = (.175, .175, .04, 1.)
        upright = dict(position_m=dict(x=0., y=.39, z=0.), orientation_xyzw=dict(x=0., y=0., z=0., w=1.))
        for limb in diagnosis.LIMBS:
            self.assertAlmostEqual(0, diagnosis.relaxed_fixed_torso_bottom(upright, limb, dimensions), places=14)
        for angle in (-.2, .2):
            pose = dict(upright, orientation_xyzw=dict(x=math.sin(angle/2), y=0., z=0., w=math.cos(angle/2)))
            for limb in diagnosis.LIMBS:
                bound = diagnosis.relaxed_fixed_torso_bottom(pose, limb, dimensions)
                for hip in (-.5, 0., .5):
                    for knee in (-.3, 0., .8):
                        actual = diagnosis.geometry.ideal_distal(pose, limb, hip, knee, *dimensions)[1]
                        self.assertGreaterEqual(actual + 1e-14, bound)

    def test_source_drift_refusal_and_no_claim_scope(self):
        result = self.result
        self.assertEqual('sha256:f85572e993169c913ecd979bc27fc46d377bc835b5db143ec1becb82f41d6830', result['source_report']['raw_sha256'])
        self.assertEqual('sha256:c686eb6a455941cefeb2435c2972fae01f8a7c9ccce32a48b0134e9c3f1ac91b', result['source_closure']['raw_sha256'])
        original = Path.read_bytes
        report_path = Path(result['source_report']['path'])
        with patch.object(Path, 'read_bytes', lambda p: b'{}' if p == report_path else original(p)), self.assertRaisesRegex(ValueError, 'V32_PLACEMENT_SOURCE_DRIFT'):
            diagnosis.observe()
        for key in ('world_build_count', 'solver_step_count', 'additional_native_physics_read_count'):
            self.assertEqual(0, result[key])
        for key in ('original_evaluation_changed', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(result[key])
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         diagnosis.digest((ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))


if __name__ == '__main__':
    unittest.main()
