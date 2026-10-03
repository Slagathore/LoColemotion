"""Retained actual contact geometry, exact load joins, and ideal posture limits."""
import copy
import json
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_leg_geometry as geometry
import development_passive_entry_profile as entry


class StanceGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = geometry.observe_stance_v15()

    def test_complete_native_population_not_just_the_terminal_frame(self):
        r = self.result
        self.assertEqual((240,687,69), tuple(r[k] for k in ('observed_stance_steps','retained_foot_contact_point_count','late_centroid_sample_count')))
        self.assertEqual(dict(front_left_foot=188,front_right_foot=180,rear_left_foot=146,rear_right_foot=137),r['qualifying_load_counts_by_foot'])
        self.assertTrue(r['all_native_foot_load_sums_exact'])
        self.assertLess(r['late_front_rear_centroid_offset_min_m'],0)
        self.assertGreater(r['late_front_rear_centroid_offset_max_m'],0)
        self.assertEqual(36,r['late_positive_front_rear_offset_count'])
        self.assertAlmostEqual(.0018012482408512837,r['late_front_rear_centroid_offset_mean_m'],places=14)
        terminal = r['selected_samples'][-1]
        self.assertEqual(868,terminal['step'])
        self.assertEqual(3,len(terminal['actual_contact_samples']))
        self.assertTrue(all(abs(p['position_world_m']['y']) < .001 for p in terminal['actual_contact_samples']))
        print('V15_STANCE_GEOMETRY',json.dumps(r,separators=(',',':'),allow_nan=False),flush=True)

    def test_candidate_geometry_is_not_native_stability_evidence(self):
        r=self.result;g=r['ideal_candidate_geometry']
        self.assertAlmostEqual(.11948200043625823,g['hip_goal_rad'],places=15)
        self.assertEqual(-.25,g['knee_goal_rad'])
        self.assertAlmostEqual(.002725529521188652,g['leg_shortening_m'],places=15)
        self.assertLess(abs(g['foot_offset_from_hip_x_m']),1e-15)
        self.assertNotEqual(0,g['knee_to_foot_height_derivative_m_per_rad'])
        self.assertEqual([0.,0.],g['zero_pose_hip_and_knee_height_derivatives_m_per_rad'])
        for key in ('causal_attribution_proven','original_results_reclassified','physical_acceptance_authority','release_authority'):
            self.assertIs(r[key],False)
        for key in ('world_build_count','native_physics_read_count','solver_step_count'):
            self.assertEqual(0,r[key])

    def test_crossed_contact_identity_and_load_refuse(self):
        # Minimal retained-shaped seam; uses the real identity/load join.
        pair=dict(raw_engine_contact_id='foot:0|floor:0',portable_engine_contact_id='godot_contact_'+b'foot:0|floor:0'.hex())
        obs=dict(ordered_foot_bearing_observations=[dict(contact_site_id='foot',bearing_normal_impulse_ns=.1)],
                 state=dict(ordered_contact_observations=[dict(contact_site_id='foot',provenance=dict(engine_contact_ids=[pair['portable_engine_contact_id']]))]))
        source=dict(ordered_contact_samples=[dict(classified_as_foot=True,engine_contact_id=pair['raw_engine_contact_id'],normal_impulse_ns=.1)],
                    ordered_contact_identity_projections=[dict(bucket_kind='foot_site',bucket_id='foot',projection=dict(raw_to_portable_identity_pairs=[pair]))])
        self.assertEqual(1,len(geometry.stance_contact_points(obs,source)))
        for case in ('load','identity'):
            bad=copy.deepcopy(source)
            if case=='load':bad['ordered_contact_samples'][0]['normal_impulse_ns']=.2
            else:bad['ordered_contact_identity_projections'][0]['projection']['raw_to_portable_identity_pairs'][0]['portable_engine_contact_id']='unknown'
            with self.assertRaises(ValueError):geometry.stance_contact_points(obs,bad)


if __name__=='__main__':unittest.main()
