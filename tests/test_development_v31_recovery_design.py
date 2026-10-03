"""Retained startup geometry, fixed first-swing choice and unchanged runtime."""
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
import development_recovery_v30_startup_diagnosis as diagnosis
import development_recovery_candidate_checkpoint as closure


class V31Design(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = candidate.read(candidate.ROTATED_ENTRY_PATH)
        cls.basis = cls.contract['diagnostic_basis']
        cls.record = candidate.read(ROOT / cls.basis['source_closure'])
        cls.report_path = Path(cls.record['kicked_report']['path'])
        cls.report = candidate.read(cls.report_path)
        cls.summary = diagnosis.summarize(cls.report)

    def test_retained_contact_loss_and_explicit_geometry_decomposition(self):
        self.assertEqual(self.basis['source_closure_sha256'], candidate.sha(ROOT / self.basis['source_closure']))
        self.assertEqual(self.basis['source_report_sha256'], candidate.sha(self.report_path))
        flight = self.summary['first_front_right_flight']
        self.assertEqual((80, 0), (flight['sample_count'], flight['raw_contact_sample_count']))
        self.assertAlmostEqual(.0004650275797562775, flight['nominal_capsule_bottom_m']['minimum'], places=14)
        self.assertAlmostEqual(.014306574778944328, flight['nominal_capsule_bottom_m']['maximum'], places=14)
        rows = {r['trace_local_step']: r for r in self.summary['front_right_vertical_change_decomposition']}
        fields = ('torso_height_change_m', 'orientation_change_at_initial_joints_m', 'joint_change_at_current_pose_m', 'ideal_constraint_residual_change_m')
        for row in rows.values():
            self.assertAlmostEqual(row['nominal_capsule_bottom_m']-rows[0]['nominal_capsule_bottom_m'], sum(row[k] for k in fields), places=14)
        self.assertAlmostEqual(.0003970973229650565, rows[34]['relaxed_minimum_ideal_bottom_at_measured_torso_m'], places=14)
        self.assertGreater(rows[34]['orientation_change_at_initial_joints_m'], rows[34]['joint_change_at_current_pose_m'])
        for key in ('online_foot_selection', 'physical_outcome_predicted', 'causal_attribution_proven', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.summary[key])
        print('V31_RETAINED_STARTUP_DIAGNOSIS', json.dumps(self.summary, separators=(',', ':')), flush=True)

    def test_all_four_raw_contact_triangles_and_single_source_derived_choice(self):
        observed = self.summary['startup_raw_contact_triangle_margins_m']
        self.assertEqual(self.basis['startup_raw_contact_triangle_margins_m'], observed)
        self.assertEqual('front_left', max(observed, key=observed.get))
        self.assertEqual(('front_left', 1, 90), tuple(self.summary[k] for k in ('largest_startup_static_margin_limb', 'corresponding_policy_phase_index', 'corresponding_initial_gait_step')))
        self.assertLess(observed['rear_left'], 0)
        self.assertGreater(observed['front_left'], 0)
        self.assertIsNone(self.summary['minimum_support_margin_required'])
        self.assertNotEqual(dict(x=0, y=0, z=0), self.summary['startup_measured_com_velocity_world_m_s'])
        # The actual nonzero velocity is retained, not hidden behind a claim
        # that the instantaneous support triangle predicts dynamic viability.
        self.assertLess(self.summary['coordinate_conversion_maximum_axis_vector_difference'], 1e-6)

    def test_geometry_controls_orientation_invariance_and_source_refusals(self):
        tri, point = [[0., 0.], [2., 0.], [0., 2.]], [.5, .5]
        self.assertEqual(.5, diagnosis.triangle_margin(tri, point))
        self.assertEqual(.5, diagnosis.triangle_margin(tri[::-1], point))
        transform = lambda p: [-p[1]+10, p[0]-3]
        self.assertAlmostEqual(.5, diagnosis.triangle_margin([transform(p) for p in tri], transform(point)), places=14)
        self.assertLess(diagnosis.triangle_margin(tri, [-.1, .5]), 0)
        for points in ([[0, 0], [0, 0], [0, 1]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [1, 0], [0, math.nan]]):
            with self.subTest(points=points), self.assertRaises(ValueError):
                diagnosis.triangle_margin(points, point)
        source = next(e['native_source'] for e in self.report['development_native_walking_contacts']['rows'] if e['segment_id'] == 'walking_resume')
        for mode in ('com', 'missing', 'duplicate'):
            bad = copy.deepcopy(source)
            if mode == 'com':
                bad['observation']['center_of_mass']['source_measurement'] = False
            elif mode == 'missing':
                bad['contact_source_receipt']['ordered_contact_samples'].pop()
            else:
                bad['contact_source_receipt']['ordered_contact_samples'].append(copy.deepcopy(bad['contact_source_receipt']['ordered_contact_samples'][0]))
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                diagnosis.startup_triangles(bad)

    def test_exact_runtime_limits_pairing_frozen_resolver_and_prior_evidence(self):
        def select(name):
            return candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates' / (name+'.json')))
        old, new = select('v30-contact-gated-walking-from-start-v1'), select('v31-front-left-first-walking-v1')
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            self.assertEqual(old['candidate'][key], new['candidate'][key])
        for key in ('limits', 'controller_id', 'runtime_sha256', 'walking_resume_frame_id', 'walking_contact_profile_id'):
            self.assertEqual(old['diagnostic_schedule'][key], new['diagnostic_schedule'][key])
        self.assertNotIn('walking_replay_profile_id', new['diagnostic_schedule'])
        for field in ('maximum_amplitude', 'warmup_steps', 'first_full_amplitude_local_step', 'first_contact_gated_local_step'):
            self.assertEqual(candidate.read(candidate.CONTACT_GATED_ENTRY_PATH)[field], self.contract[field])
        schedule = new['diagnostic_schedule']
        for change in ({'walking_start_profile_id': ''}, {'walking_start_profile_id': old['diagnostic_schedule']['walking_start_profile_id']}, {'walking_entry_profile_id': old['diagnostic_schedule']['walking_entry_profile_id']}):
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, 'WALKING_START_SELECTION'):
                candidate.walking_start_id(dict(schedule, **change))
        for source in self.contract['bound_source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT / source['path']))
        with patch.object(closure.prior, 'committed', side_effect=lambda relative, source: (ROOT / relative).read_bytes()):
            sources = closure.walking_entry_rule_sources(schedule, 'prospective-zero-world-fixture')
        paths = {s['path'] for s in sources}
        self.assertIn(candidate.ROTATED_START_PATH.relative_to(ROOT).as_posix(), paths)
        self.assertIn('sdk/conformance/development_recovery_v30_startup_diagnosis.py', paths)
        self.assertNotIn('sdk/development/recovery_prospective_walking_replay_contract_v1.json', paths)
        for relative in (self.basis['source_closure'], 'sdk/core/src/runtime.rs', 'sdk/core/src/recovery_runtime.rs',
                         'sdk/development/recovery_contact_gated_walking_entry_contract_v1.json',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative, 'c06e1773af00e532cf251e51c1f7902ab2bca7e2'), (ROOT / relative).read_bytes())


if __name__ == '__main__':
    unittest.main()
