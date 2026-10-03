"""Retained-data diagnosis and one source-derived command cap; zero physics."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_v28_contact_geometry as geometry


class V29Design(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = candidate.read(candidate.JOINT_BOUNDED_ENTRY_PATH)
        cls.basis = cls.contract['diagnostic_basis']
        cls.record = candidate.read(ROOT / cls.basis['source_closure'])
        cls.report_path = Path(cls.record['kicked_report']['path'])
        cls.report = candidate.read(cls.report_path)
        cls.summary = geometry.summarize(cls.report, cls.basis)

    def test_exact_observation_raw_contact_gaps_and_requested_saturation(self):
        self.assertEqual(self.basis['source_closure_sha256'], candidate.sha(ROOT / self.basis['source_closure']))
        self.assertEqual(self.basis['source_report_sha256'], candidate.sha(self.report_path))
        gaps = self.summary['selected_failed_stance_gaps']
        self.assertEqual(45, sum(r['sample_count'] for r in gaps))
        self.assertEqual(0, sum(r['raw_contact_sample_count'] for r in gaps))
        self.assertEqual(107, self.summary['final_front_right_gap']['sample_count'])
        self.assertEqual(0, self.summary['final_front_right_gap']['raw_contact_sample_count'])
        self.assertEqual(self.basis['position_saturated_knee_commands_by_limb'], self.summary['position_saturated_knee_commands_by_limb'])
        self.assertEqual(148, sum(self.summary['position_saturated_knee_commands_by_limb'].values()))
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        print('V29_RETAINED_DIAGNOSIS', json.dumps(self.summary, separators=(',', ':')), flush=True)

    def test_native_frame_geometry_controls_and_explicit_approximation(self):
        torso = dict(position_m=dict(x=0, y=.38994872276483846, z=0),
                     orientation_xyzw=dict(x=0, y=0, z=0, w=1))
        args = (.182685, .167315, .03994872276483846, .9856413994169096)
        neutral, bottom = geometry.ideal_distal(torso, 'front_left', 0, 0, *args)
        self.assertAlmostEqual(0, bottom, places=14)
        flexed, raised = geometry.ideal_distal(torso, 'front_left', .3, 0, *args)
        self.assertGreater(flexed[0], neutral[0])
        self.assertAlmostEqual(.35*(1-math.cos(.3)), raised, places=14)
        turned = copy.deepcopy(torso)
        turned['orientation_xyzw'] = dict(x=0, y=math.sqrt(.5), z=0, w=math.sqrt(.5))
        rotated, same_bottom = geometry.ideal_distal(turned, 'front_left', .3, 0, *args)
        self.assertAlmostEqual(flexed[2], rotated[0], places=14)
        self.assertAlmostEqual(-flexed[0], rotated[2], places=14)
        self.assertAlmostEqual(raised, same_bottom, places=14)
        self.assertEqual(1600, self.summary['measured_body_samples'])
        # Numerical reconstruction checks, not contact/acceptance tolerances.
        self.assertLess(self.summary['coordinate_conversion_maximum_axis_vector_difference'], 1e-6)
        self.assertAlmostEqual(.000193347, self.summary['ideal_measured_bottom_error_mean_m'], places=9)
        self.assertAlmostEqual(.002412221, self.summary['ideal_measured_bottom_error_maximum_m'], places=9)
        self.assertAlmostEqual(.0829554714204264, self.summary['final_front_right_gap']['nominal_capsule_bottom_m']['maximum'], places=14)
        for key in ('causal_attribution_proven', 'physical_outcome_predicted', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(self.summary[key], False)

    def test_source_derived_knee_bound_is_not_a_new_physical_threshold(self):
        c = self.contract
        for source in c['bound_source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT / source['path']))
        maximum = c['knee_swing_flexion_rad']*c['knee_flexion_scale']+c['contact_clearance_assist_rad']
        self.assertEqual(1.835, maximum)
        self.assertEqual(c['knee_limit_rad']/maximum, c['maximum_amplitude'])
        self.assertEqual(1.1, maximum*c['maximum_amplitude'])
        self.assertGreater(maximum*math.nextafter(c['maximum_amplitude'], math.inf), 1.1)
        # Include the loaded release-gate apex override, not just sampled sine.
        for phase in range(360):
            for loaded in (False, True):
                knee = .82*1.75*math.sin(math.pi*phase/72) if phase < 72 else 0
                if loaded and phase < 72:
                    knee += .4
                if loaded and phase == 54:
                    knee = maximum
                self.assertLessEqual(c['maximum_amplitude']*knee, 1.1)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))

    def test_profile_reuses_exact_runtime_and_preserves_bounds_and_old_identities(self):
        old = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v28-first-swing-walking-warmup-v1.json'))
        new = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v29-joint-bounded-walking-amplitude-v1.json'))
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            self.assertEqual(old['candidate'][key], new['candidate'][key])
        for key in ('limits', 'controller_id', 'runtime_sha256', 'walking_resume_frame_id', 'walking_contact_profile_id', 'walking_replay_profile_id', 'walking_start_profile_id'):
            self.assertEqual(old['diagnostic_schedule'][key], new['diagnostic_schedule'][key])
        self.assertNotEqual(old['diagnostic_schedule']['walking_entry_profile_id'], new['diagnostic_schedule']['walking_entry_profile_id'])
        for entry_id in (old['diagnostic_schedule']['walking_entry_profile_id'], new['diagnostic_schedule']['walking_entry_profile_id']):
            self.assertEqual('one_cycle_ramp_clocked_then_contact_gated_v1', candidate.walking_entry_phase_family(entry_id))
        original_read = candidate.read
        for amplitude in (1., .5, None, True):
            bad = dict(self.contract, maximum_amplitude=amplitude)
            with patch.object(candidate, 'read', side_effect=lambda p: bad if p == candidate.JOINT_BOUNDED_ENTRY_PATH else original_read(p)):
                with self.assertRaisesRegex(ValueError, 'WALKING_ENTRY_AMPLITUDE_BOUND'):
                    candidate.walking_entry_phase_family(self.contract['profile_id'])


if __name__ == '__main__':
    unittest.main()
