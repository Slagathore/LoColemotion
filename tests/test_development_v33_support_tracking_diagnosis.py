"""Audit V33's own measurements without invoking a model or native runtime."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_v33_support_tracking_diagnosis as diagnosis


class SupportTrackingDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = diagnosis.observe()

    def test_complete_population_geometry_and_unchanged_negative(self):
        r = self.result
        retained = json.loads((ROOT/'sdk/development/recovery_bounded_support_tracking_diagnosis_v1.json').read_bytes())
        self.assertEqual(retained,r)
        self.assertEqual((1600,3192),(r['measured_body_sample_count'],r['measured_response_joint_count']))
        # Geometry helper's existing frame conversion is single-precision
        # host data. This checks arithmetic, not native contact or behavior.
        self.assertLess(r['coordinate_conversion_maximum_axis_difference'],1e-6)
        self.assertLess(r['support_height_identity_maximum_error_m'],1e-6)
        self.assertEqual([326,326,363,326],[x['scheduled_stance_command_count'] for x in r['per_limb']])
        self.assertEqual([193,199,232,217],[x['stance_goal_above_floor_count'] for x in r['per_limb']])
        self.assertEqual([0,2,103,129],[x['floor_proposal_stance_unreachable_count'] for x in r['per_limb']])
        self.assertEqual([0,1,32,49],[x['stance_fixed_torso_unreachable_even_with_unrestricted_angles_count'] for x in r['per_limb']])
        self.assertEqual(279,r['geometric_proposal']['link_reach_projection_count'])
        self.assertEqual(0,r['geometric_proposal']['joint_projection_count'])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],r['original_false_walking_receipts'])

    def test_prior_command_response_timing_and_complete_cycles(self):
        r = self.result
        worst = r['maximum_knee_response_error_sample']
        self.assertEqual(('rear_left',397,398),(worst['limb'],worst['measured_trace_local'],worst['command_local']))
        self.assertEqual((33,34),(worst['applied_phase'],worst['command_phase']))
        self.assertEqual(.3911479711532593,worst['measured_joint_rad'][1])
        self.assertEqual(.8499999999999999,worst['preceding_reference_rad'][1])
        self.assertNotEqual(worst['preceding_reference_rad'],worst['current_reference_rad'])
        self.assertEqual(0,r['velocity_saturated_command_count'])
        self.assertEqual((15,10,7),(len(r['counted_cycles']),r['failed_cycle_count'],r['failed_cycles_released_outside_commanded_swing']))
        self.assertEqual(14,sum(c['decomposition']['available'] for c in r['counted_cycles']))
        for c in r['counted_cycles']:
            self.assertEqual(0,c['raw_contact_sample_count_during_gap'])
            if not c['decomposition']['available']:
                self.assertEqual(('front_right',400),(c['limb'],c['touchdown_trace_local']))
                continue
            for key in ('forward_components_m','clearance_change_components_m'):
                p = c['decomposition'][key]
                self.assertAlmostEqual(p['actual'],sum(v for k,v in p.items() if k!='actual'),places=14)
            self.assertAlmostEqual(c['forward_m'],c['decomposition']['forward_components_m']['actual'],places=14)
        bad = next(c for c in r['counted_cycles'] if c['limb']=='rear_right' and c['release_trace_local']==255)
        p = bad['decomposition']['forward_components_m']
        self.assertEqual((81,82),(bad['original_closure_input_phase'],bad['release_applied_command_phase']))
        self.assertAlmostEqual(-.035426868136948286,p['actual'],places=14)
        self.assertAlmostEqual(-.01767521351877821,p['torso_translation'],places=14)
        self.assertAlmostEqual(-.016937910198587713,p['torso_rotation_at_initial_joints'],places=14)
        short = next(c for c in r['counted_cycles'] if c['limb']=='front_left' and c['release_trace_local']==27)
        p = short['decomposition']['clearance_change_components_m']
        self.assertGreater(p['joint_change_at_final_pose'],0)
        self.assertLess(p['actual'],0)
        gap = r['terminal_contact_gaps']['rear_left']
        self.assertEqual((396,5,4),(gap['release_trace_local'],gap['observed_contact_samples'],gap['reconstructed_body_samples']))

    def test_explicit_floor_proposal_translation_reach_limits_and_refusals(self):
        dimensions = (.175,.175,.04,1.)
        pose = dict(position_m=dict(x=.2,y=.37,z=-.1),orientation_xyzw=dict(x=0.,y=0.,z=0.,w=1.))
        for limb in diagnosis.LIMBS:
            target = diagnosis.floor_referenced_target(pose,limb,.12,dimensions,0.)
            self.assertLess(abs(target['nominal_floor_residual_m']),1e-14)
            self.assertFalse(target['joint_projection_required'])
            self.assertFalse(target['link_reach_projection_required'])
            translated = copy.deepcopy(pose)
            translated['position_m'] = dict(x=11.2,y=7.37,z=-4.1)
            moved = diagnosis.floor_referenced_target(translated,limb,.12,dimensions,7.)
            for key in ('hip_rad','knee_rad','nominal_floor_residual_m'):
                self.assertAlmostEqual(target[key],moved[key],places=12)
            high = copy.deepcopy(pose)
            high['position_m']['y'] = .45
            unreachable = diagnosis.floor_referenced_target(high,limb,0.,dimensions,0.)
            self.assertTrue(unreachable['link_reach_projection_required'])
            # At full extension, cosine arithmetic may land one binary64 ULP
            # below 1; acos then returns a tiny nonzero angle. Check the
            # geometric limit and actual residual, not an exact-zero angle.
            self.assertGreaterEqual(math.cos(unreachable['knee_rad']),math.nextafter(1.,0.))
            self.assertAlmostEqual(.06,unreachable['nominal_floor_residual_m'],places=14)
            low = copy.deepcopy(pose)
            low['position_m']['y'] = .1
            projected = diagnosis.floor_referenced_target(low,limb,0.,dimensions,0.)
            self.assertTrue(projected['joint_projection_required'])
            self.assertEqual(1.1,projected['knee_rad'])
            self.assertLess(projected['nominal_floor_residual_m'],0)
        for limb,angle,dims,floor in [('unknown',0.,dimensions,0.),('front_left',math.pi,dimensions,0.),
                                     ('front_left',0.,dimensions,float('nan')),('front_left',0.,(0.,.2,.04,1.),0.)]:
            with self.assertRaises(ValueError):
                diagnosis.floor_referenced_target(pose,limb,angle,dims,floor)

    def test_original_source_refusal_and_no_new_authority(self):
        r = self.result
        read = Path.read_bytes
        for target,error in [(ROOT/r['source_closure']['path'],'V33_TRACKING_CLOSURE_DRIFT'),
                             (Path(r['source_report']['path']),'V33_TRACKING_REPORT_DRIFT')]:
            with patch.object(Path,'read_bytes',lambda p:b'{}' if p==target else read(p)),self.assertRaisesRegex(ValueError,error):
                diagnosis.observe()
        for key in ('world_build_count','solver_step_count','additional_native_physics_read_count'):
            self.assertEqual(0,r[key])
        for key in ('physical_cause_proven','alternate_physical_outcome_predicted','original_evaluation_changed','physical_acceptance_authority','release_authority'):
            self.assertFalse(r[key])
        self.assertFalse(r['geometric_proposal']['controller_ready'])
        self.assertFalse(r['geometric_proposal']['runtime_plane_observation_contract_exists'])
        self.assertEqual(diagnosis.CLOSURE_SHA,diagnosis.digest((ROOT/r['source_closure']['path']).read_bytes()))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            diagnosis.digest((ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))


if __name__=='__main__':
    unittest.main()
